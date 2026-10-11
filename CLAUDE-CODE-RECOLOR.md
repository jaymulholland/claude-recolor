# Claude Code VS Code recolour (a recipe)

Swap the Claude Code VS Code extension's orange for a colour you choose. This file is written to be handed to a Claude Code agent: open Claude Code in VS Code and say **"follow CLAUDE-CODE-RECOLOR.md"**. The agent asks you for a colour, installs a small patch script, runs it, and sets it to re-run after extension updates.

Works in VS Code, VS Code Insiders, Cursor and Windsurf on Linux and macOS. On Windows, run the script from Git Bash or WSL, or have the agent port it to PowerShell.

The extension has no accent-colour setting (its orange is hardcoded), so the script patches the installed extension files. **Every extension update reinstalls the originals**, which is why the script is idempotent and can run automatically.

---

## Instructions for the agent

Work through the steps in order. Ask the user only where a step says to.

### 1. Pick the colour with the user

Use AskUserQuestion with these options:

| Option | What you do |
|---|---|
| **Pick from a palette** | Ask a second AskUserQuestion with named presets (below), each showing its hex in the description. |
| **Describe it** | User types something like "dusty teal", "my team's purple" or "match the Tokyo Night accent". You turn it into a hex, then confirm by showing the hex and a one-line description. |
| **Use VS Code's colour picker** | Write a scratch file `accent-picker.css` (in your scratchpad, or `/tmp`) containing the block below, then open it with `code <path>` (or `cursor <path>`). Tell the user: hover the little swatch next to the hex, pick a colour in the picker, save the file (Ctrl/Cmd+S), then tell you "done". Read the hex back from the file. |
| **I have a hex** | User types it. |

```css
/* Hover the swatch below, pick your colour, save this file, then tell Claude "done". */
:root {
  --accent: #5B9CF6;
}
```

Presets (mid-brightness so they read on both dark and light themes):

| Name | Hex |
|---|---|
| Sky blue | `#5B9CF6` |
| Teal | `#2DD4BF` |
| Mint | `#4ADE80` |
| Violet | `#A78BFA` |
| Pink | `#F472B6` |
| Amber | `#FBBF24` |
| Coral red | `#F87171` |
| Slate | `#94A3B8` |

### 2. Derive the rest of the palette

From the chosen `ACCENT`, compute (keep the same hue for the first three):

| Variable | Rule | Used for |
|---|---|---|
| `ACCENT` | the user's pick | logo, mascot, highlights, unread badge |
| `ACCENT_DARK` | ~20% darker, a little more saturated. White text on it must reach at least 4.5:1 contrast; darken further if not | filled "clay" buttons |
| `ACCENT_SOFT` | ~35% lighter tint | Jupyter banner text |
| `ACCENT_BG` | very dark shade, roughly 20% accent mixed into `#1E1E1E` | Jupyter banner background |
| `DONE_DOT` | a clearly different hue from both `ACCENT` and the blue "working" dot `#3B82F6`. Default green `#22C55E`; if the accent is green or teal, use amber `#F59E0B`; if it is blue, green is fine | dot on the tab icon when Claude has finished |

Show the user the five values in one line before installing.

### 3. Install the script

Write the script below to `~/.local/bin/claude-recolor`, filling in the five colours, and `chmod +x` it. Then run it. It should print `claude-recolor: patched anthropic.claude-code-<version>` for each installed version.

```bash
#!/usr/bin/env bash
# Recolour the Claude Code VS Code extension (brand orange -> your accent).
# Safe to re-run: already-patched versions are skipped. Always patches from the
# saved originals, so changing a colour below and re-running applies cleanly.
# Restore a version: copy *.bak / .orig-resources/* back over the patched files.
set -euo pipefail

ACCENT="#5B9CF6"       # replaces brand orange #D97757 (logo, mascot, highlights)
ACCENT_DARK="#3B7BE0"  # replaces clay button orange #C6613F (filled buttons)
ACCENT_SOFT="#93BDF8"  # replaces Jupyter banner text orange #F5A66A
ACCENT_BG="#1F2A3F"    # replaces Jupyter banner background brown #3F2A1F
DONE_DOT="#22C55E"     # tab icon "finished" dot; must differ from ACCENT and the blue "working" dot
CUSTOM_CSS="${XDG_CONFIG_HOME:-$HOME/.config}/claude-recolor/custom.css"  # optional, appended to the panel CSS

# Every VS Code-family extensions folder that exists gets patched
EXT_ROOTS=(
  "$HOME/.vscode/extensions"
  "$HOME/.vscode-insiders/extensions"
  "$HOME/.cursor/extensions"
  "$HOME/.windsurf/extensions"
)

STAMP=".recolor-stamp"
custom_sum=""
[[ -f "$CUSTOM_CSS" ]] && custom_sum="$(cksum < "$CUSTOM_CSS")"
WANT="$ACCENT $ACCENT_DARK $ACCENT_SOFT $ACCENT_BG $DONE_DOT $custom_sum"

# perl -pi works the same on Linux and macOS (sed -i does not)
sub() { perl -pi -e "$1" "${@:2}"; }

shopt -s nullglob
for root in "${EXT_ROOTS[@]}"; do
  for dir in "$root"/anthropic.claude-code-*/; do
    dir="${dir%/}"
    name="$(basename "$dir")"
    # Skip versions VS Code has marked for deletion
    if [[ -f "$root/.obsolete" ]] && grep -q "\"$name\"" "$root/.obsolete"; then
      continue
    fi
    [[ -f "$dir/$STAMP" && "$(cat "$dir/$STAMP")" == "$WANT" ]] && continue

    css="$dir/webview/index.css"
    js="$dir/webview/index.js"
    res="$dir/resources"
    # Extension may still be unpacking; the watcher will fire again later
    [[ -f "$css" && -f "$js" && -d "$res" ]] || continue

    # Back up originals once
    [[ -f "$css.bak" ]] || cp "$css" "$css.bak"
    [[ -f "$js.bak" ]] || cp "$js" "$js.bak"
    if [[ ! -d "$dir/.orig-resources" ]]; then
      mkdir -p "$dir/.orig-resources"
      cp "$res"/*.svg "$dir/.orig-resources/"
    fi

    cp "$css.bak" "$css"
    cp "$js.bak" "$js"
    cp "$dir/.orig-resources/"*.svg "$res/"

    # Done dot first, before the blanket logo replace swallows its orange
    [[ -f "$res/claude-logo-done.svg" ]] && \
      sub "s/r=\"4.5\" fill=\"#d97757\"/r=\"4.5\" fill=\"$DONE_DOT\"/gi" "$res/claude-logo-done.svg"
    sub "s/#d97757/$ACCENT/gi; s/#c6613f/$ACCENT_DARK/gi" "$css" "$js" "$res"/*.svg
    # Jupyter "connect" banner (also has alpha variants like #f3772633, which this keeps)
    sub "s/#f37726/$ACCENT/gi; s/#f5a66a/$ACCENT_SOFT/gi; s/#3f2a1f/$ACCENT_BG/gi" "$css"

    if [[ -f "$CUSTOM_CSS" ]]; then
      printf '\n/* claude-recolor custom.css */\n' >> "$css"
      cat "$CUSTOM_CSS" >> "$css"
    fi

    echo "$WANT" > "$dir/$STAMP"
    echo "claude-recolor: patched $name"
  done
done
```

**Verify:** grep the patched version folder for `#d97757`, `#c6613f`, `#f37726`, `#f5a66a` and `#3f2a1f` (case-insensitive) across `webview/index.css`, `webview/index.js` and `resources/*.svg`. All counts should be 0. If a newer extension version introduces a new orange, add it to the script rather than leaving it.

### 4. Make it re-run after extension updates

**Linux (systemd):** create both units, then enable. Add one `PathChanged=` line per extensions folder the user actually has.

`~/.config/systemd/user/claude-recolor.path`
```ini
[Unit]
Description=Re-apply Claude Code VS Code recolour after extension updates

[Path]
PathChanged=%h/.vscode/extensions

[Install]
WantedBy=default.target
```

`~/.config/systemd/user/claude-recolor.service`
```ini
[Unit]
Description=Recolour Claude Code VS Code extension

[Service]
Type=oneshot
# Give VS Code time to finish unpacking a new version
ExecStartPre=/bin/sleep 15
ExecStart=%h/.local/bin/claude-recolor
```

```bash
systemctl --user daemon-reload && systemctl --user enable --now claude-recolor.path
```

**macOS (launchd):** write `~/Library/LaunchAgents/com.user.claude-recolor.plist` (replace `USERNAME`; add a `<string>` per extensions folder), then `launchctl load ~/Library/LaunchAgents/com.user.claude-recolor.plist`.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.user.claude-recolor</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>-c</string><string>sleep 15; /Users/USERNAME/.local/bin/claude-recolor</string></array>
  <key>WatchPaths</key>
  <array><string>/Users/USERNAME/.vscode/extensions</string></array>
</dict>
</plist>
```

**Windows:** skip this step and tell the user to re-run the script after each extension update.

### 5. Optional settings

Offer to set `"claudeCode.hideOnboarding": true` in the VS Code user settings. It hides the "Learn Claude Code" checklist and the grad-cap mascot (a PNG the script can't recolour).

### 6. Tell the user how to see it

Tell them exactly this:

> Open the Command Palette (Ctrl+Shift+P, or Cmd+Shift+P on Mac) and run **Developer: Reload Window**. That applies the new colour to the Claude panel *and* the tab icons. If a tab icon still looks orange, reload once more or restart VS Code.
>
> VS Code may warn that the installation "appears to be corrupt" after patching. That's just its checksum noticing the edited files. It's harmless; dismiss it (or choose "Don't show again").

Then point them at the "What else you can customise" section below.

---

## What gets changed

All inside `<extensions folder>/anthropic.claude-code-<version>/`:

| File | Original | Becomes |
|---|---|---|
| `webview/index.css` | `--app-claude-orange` `#D97757` | `ACCENT` |
| `webview/index.css` | `--app-claude-clay-button-orange` `#C6613F` | `ACCENT_DARK` |
| `webview/index.css` | Jupyter banner `#F37726` / `#F5A66A` / `#3F2A1F` | `ACCENT` / `ACCENT_SOFT` / `ACCENT_BG` |
| `webview/index.js` | Mascot SVG (above "TODO: Everything") `#D97757` | `ACCENT` |
| `resources/*.svg` | Tab/bar/button logo, clawd, welcome art `#D97757` | `ACCENT` |
| `resources/claude-logo-done.svg` | Tab "finished" dot `#D97757` | `DONE_DOT` |

`--app-claude-orange` is a CSS variable used about 28 times across the panel (highlights, unread status, tinted backgrounds via `color-mix`), so replacing it once recolours all of those.

Originals are kept as `webview/index.css.bak`, `webview/index.js.bak` and `.orig-resources/*.svg` in each version folder.

**Left alone on purpose** (these are status colours, not branding): warning amber `#E5A54B`, error red `#C74E39`, success green, the blue "working" dot `#3B82F6`, chart colours, diff-editor colours and high-contrast theme highlights. Also untouched: `claude-logo.png` (the Extensions list icon) and `ClawdWithGradCap.png` (hidden by `hideOnboarding`).

## Changing colour later

Edit the variables at the top of `~/.local/bin/claude-recolor` and re-run it, then **Developer: Reload Window**. It always patches from the originals, so you can change colour as often as you like.

## Restoring the original orange

For a given version folder:

```bash
d=~/.vscode/extensions/anthropic.claude-code-<version>
cp $d/webview/index.css.bak $d/webview/index.css
cp $d/webview/index.js.bak  $d/webview/index.js
cp $d/.orig-resources/*.svg $d/resources/
rm $d/.recolor-stamp
```

Then disable the watcher, or it re-patches the next version:

```bash
systemctl --user disable --now claude-recolor.path                         # Linux
launchctl unload ~/Library/LaunchAgents/com.user.claude-recolor.plist      # macOS
```

Check the Linux watcher with `systemctl --user status claude-recolor.path` and `journalctl --user -u claude-recolor.service`.

---

## What else you can customise

*For you, not your agent. Ask Claude to set up any of these.*

**Supported settings (survive updates, no patching):**

- **Your own "thinking" words.** Replace the words shown while Claude works with your own in VS Code settings:
  ```json
  "claudeCode.spinnerVerbs": { "mode": "replace", "verbs": ["Brewing", "Scheming", "Vibing"] }
  ```
  Use `"mode": "append"` to mix yours in with the built-in ones.
- **Output style.** `/output-style` changes how Claude writes to you (e.g. more explanatory, or a teaching mode), and you can write your own.
- **Message timestamps** (`claudeCode.showMessageTimestamps`), **Focus view** (`claudeCode.focusView`, hides tool calls and shows only answers), **Ctrl/Cmd+Enter to send** (`claudeCode.useCtrlEnterToSend`).
- **A startup message** for yourself or your team: `"companyAnnouncements": ["..."]` in `~/.claude/settings.json`.
- **Hooks**: run anything when Claude does something. Popular ones: play a sound or show a desktop notification when Claude finishes or needs you.
- **Custom slash commands and skills**: turn your repeated prompts into `/your-command`.
- **VS Code-wide colours**: `workbench.colorCustomizations` (`button.background`, `focusBorder`, …) also tints some Claude panel buttons and checkboxes, but changes them everywhere in VS Code.

**Patch-based (re-applied by the same script after updates):**

- **Patterns, fonts and shapes.** Anything you put in `~/.config/claude-recolor/custom.css` is appended to the panel's stylesheet on every run. For example, a faint diagonal pattern in your accent colour:
  ```css
  body {
    background-image: repeating-linear-gradient(
      45deg,
      color-mix(in srgb, var(--app-claude-orange), transparent 94%) 0 2px,
      transparent 2px 14px
    );
  }
  ```
  (`--app-claude-orange` is the variable name; after patching it holds your colour.) The same file can set a different font, round or square off corners, or restyle message bubbles. Ask Claude to inspect the panel's classes and write the CSS.
- **Your own mascot or logo.** Replace `resources/clawd.svg`, `claude-logo.svg` and the welcome art with your own SVGs (keep the same size and viewBox). Have Claude extend the script to copy them in after patching.
- **Rename Claude.** The panel's wording ("Claude is working", "Ask Claude for help", …) lives as plain strings in `webview/index.js`, so the script can swap "Claude" for any name. Have the agent replace only quoted, user-facing strings, never code identifiers, and check the panel still loads after a reload.
