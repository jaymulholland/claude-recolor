# Claude Code VS Code recolour (a recipe)

Swap the Claude Code VS Code extension's orange for a colour you choose — either one colour for everything, or separate colours for the tab icon, the chat content and the message input field. This file is written to be handed to a Claude Code agent: open Claude Code in VS Code and say **"follow CLAUDE-CODE-RECOLOR.md"**. The agent asks you for a colour (or colours), installs a small patch script, runs it, and sets it to re-run after extension updates.

Works in VS Code, VS Code Insiders, Cursor and Windsurf on Linux and macOS. On Windows, run the script from Git Bash or WSL, or have the agent port it to PowerShell.

The extension has no accent-colour setting (its orange is hardcoded), so the script patches the installed extension files. **Every extension update reinstalls the originals**, which is why the script is idempotent and can run automatically.

### Cost and upkeep

**Tokens.** the automatic re-runs after extension updates is free. Rough figures for one run of this recipe, on top of whatever Claude Code itself uses:
- **First install:** reading this file is about 6k tokens, writing the script about 2.5k output tokens, and the questions, checks and verification bring the whole run to roughly 15–25k tokens of context.
- **Changing colour later:** about half that, because the script is only edited, not rewritten. You can skip the agent entirely by editing the variables at the top of the script yourself (see "Changing colour later").

Type `/context` in Claude Code to see the real numbers for your session.

**The watcher.** It waits on file-system events (systemd path unit on Linux, launchd on macOS), so it uses no CPU while idle. It wakes when anything in the extensions folder changes, including other extensions' updates, waits 15 seconds, then runs the script. When there's nothing to patch the script finishes in about 0.02 s; a full patch takes about 0.1 s.

**A solid colour has no runtime cost.** The panel just uses a different hex.

**The animated gradient does.** While the Claude panel is visible it redraws everything that uses the accent colour, continuously, and the tab icons animate whenever they're on screen. That's minor on a desktop but worth knowing on a laptop on battery. It switches itself off when your OS has reduced motion turned on. To see what it costs on your machine, open **Help → Open Process Explorer** and compare the Claude webview's CPU with the gradient on and off.

**Upkeep.** Usually none. Two things can come back after an extension update: VS Code's "installation appears to be corrupt" notice (dismiss it), and, rarely, a new orange element the script doesn't know about yet. If you spot orange after an update, ask Claude to run the verify check in step 3 and add the new colour to the script.

---

## Instructions for the agent

Work through the steps in order. Ask the user only where a step says to.

**Before step 1, warn the user** so they can get ready while you work:

> Heads up: when this is done you'll need to quit VS Code completely and reopen it to see the new colour, so save your work in any other VS Code windows now. Other open windows keep the old extension files loaded, and if any stay open it will look like the recolour didn't work.

### 1. Pick the colour(s) with the user

**First, ask auto or custom.** Use AskUserQuestion:

> Recolour everything the same, or pick different colours for different parts of the panel?

| Option | What it means |
|---|---|
| **Auto** (recommended) | One colour for the whole panel — the rest of this recipe, exactly as written, with a single `ACCENT`. |
| **Custom** | Separate colours for the **tab icon** (what VS Code shows on the tab and in the activity bar, including the "finished" dot), the **chat content** (the header logo/wordmark, the mascot/creature, and the panel's highlights and tinted backgrounds), and the **text field** (the message input box's border/focus colour). |

If Auto, skip ahead and follow the rest of the recipe unchanged.

If Custom, run the colour-picking flow below once per group — tab icon, then chat content, then text field — letting the user answer "same as [group]" to reuse a colour instead of repeating the question. Each group's colour uses the same four methods and presets as a single `ACCENT` would, including the animated-gradient option (a group can be animated independently of the others; see "Animated gradient" below).

Before extending the script, inspect the real installed extension rather than guessing which patch line belongs to which group — `resources/*.svg` filenames, the CSS rules around `--app-claude-orange`, and the input field's markup in `webview/index.js` all vary by extension version. The chat content's "background" tint may not be cleanly separable from its highlight colour without new CSS; if it isn't, say so and fold it into chat content rather than inventing a selector that doesn't exist. Then, in "Install the script" below, replace the single blanket substitution (`s/#d97757/$ACCENT/gi` across css/js/svgs) with one targeted substitution per group, each pointing at its own variable (e.g. `ACCENT_TAB`, `ACCENT` for chat content, `ACCENT_FIELD`) — same inspect-patch-verify approach as "Beyond a single colour". Add the new variables to `WANT` (step 3) so the cache invalidates when any of them change, and verify every group visually in the real panel, not just by grepping for the old hex. The text field also sits near the permission-mode styling described in "Permission-mode colours" below — if the user wants the text field colour to apply in every permission mode too, that needs `MODE_COLOURS` pointed at `ACCENT_FIELD` instead of `ACCENT_DARK`; ask rather than assuming.

Use AskUserQuestion with these options, in this order, for each colour you need (once for Auto, once per group for Custom). The question UI can't show a colour picker or swatches, only text, so don't label any option as if it does.

| Option | What you do |
|---|---|
| **Describe it** | User types something like "dusty teal", "frost white" or "match the theme accent". You turn it into a hex, then confirm by showing the hex and a one-line description. If they describe more than one colour (a gradient, a pattern, an effect), see "Beyond a single colour" below; never quietly flatten it to one hex. |
| **Choose a named preset** | Ask a second AskUserQuestion for the family: **Animated gradient**, **Warm**, **Cool**, **Neutral**. Animated gradient needs no third question. For the others, ask a third AskUserQuestion listing that family's presets (below), with the hex and any theme note in each description. |
| **Open VS Code's colour picker** | Say up front that this opens a file in the editor. Write a scratch file `accent-picker.css` (in your scratchpad, or `/tmp`) containing the block below, then open it with `code <path>` (or `cursor <path>`). Tell the user: hover the little swatch next to the hex, pick a colour in the picker, save the file (Ctrl/Cmd+S), then tell you "done". Read the hex back from the file. |
| **I have a hex** | User types it. |

If the script is already installed (step 3), read its current colour variables (`ACCENT`, and in a custom install `ACCENT_TAB`/`ACCENT_FIELD` too) and `RAINBOW` first, and mention them, so the user knows what they're changing from.

**Animated gradient.** This is the script's `RAINBOW` mode: a gradient that slides through a list of colours (`RAINBOW_COLOURS`, rainbow by default). If the user picks it, or asks for a rainbow, a gradient through several colours or an animated colour under any option, set `RAINBOW=1` in step 3. Ask whether they want the default rainbow or their own colours; for their own, set `RAINBOW_COLOURS` (2–6 colours work best) and, if they mention speed, `RAINBOW_SECS`. For any other choice, set `RAINBOW=0`, even if it is currently 1. The gradient still needs an `ACCENT`, used as the static fallback when the OS has reduced motion turned on and for filled buttons. Default to Violet `#A78BFA`, or a middle colour of their list, unless the user names one. Tell the user it keeps redrawing while the panel is open, so it uses some CPU and battery (see "Cost and upkeep"). On at least one Windows machine this redraw cost was severe enough to freeze VS Code while the panel was in active use (not just idle animation), forcing a restart; the same setup was fine on Linux. If a user on any platform reports freezing or heavy lag after enabling `RAINBOW=1`, set `RAINBOW=0` (keep `ACCENT` as a solid colour) as the immediate fix, and treat the animated gradient as higher-risk until this is root-caused further.

**Beyond a single colour.** The script can only do two things to the panel's accent: one solid colour, or the animated gradient above. For anything else the user describes, classify it by the *mechanism* it needs, not by the specific word they used — "strobing", "throbbing", "shimmering", "morphing" and every other synonym map onto one of these the same way the examples do; don't treat the examples as an exhaustive keyword list:

| The mechanism | Examples (not exhaustive) | What to do |
|---|---|---|
| A static visual layered on a solid colour — filter, shadow, background, border, font | glow, halo, drop shadow, texture, stripes, dots, tinted backdrop, rounded/square corners | Pick a solid `ACCENT` with them, then write the effect into `~/.config/claude-recolor/custom.css` (see "What else you can customise") — a glow is just `filter: drop-shadow(...)` or `box-shadow` in the accent colour, no new script logic needed. The script appends it on every run. |
| Continuous colour motion — hue shifts smoothly over time, never goes dark or blank | rainbow, flowing colour, shifting hues, colour-cycling, colours "morphing" into each other | Animated gradient with their colours in `RAINBOW_COLOURS`. This is already built and already respects `prefers-reduced-motion`. |
| Rapid changes in brightness or visibility — something toggles, pulses, or appears/disappears repeatedly | flashing, blinking, strobing, pulsating, throbbing, flickering | Not built, and higher-risk than the other rows regardless of which of these words (or a synonym) was used: rapid luminance/visibility change is a known photosensitive-seizure trigger (WCAG's general threshold is no more than 3 such changes per second; stay well under that). If the user wants it anyway, agree a safe rate with them explicitly, cap it in whatever `@keyframes` you write, and still respect `prefers-reduced-motion`. Offer it, don't default to it. |
| Anything needing new rendering entirely | a gradient that doesn't move, a radial gradient, a patterned logo or tab icon | The script doesn't support it yet. Before building anything, tell the user what can carry the effect (the SVG icons, the mascot, brand text) and what can't: borders, focus rings, highlights and tinted backgrounds all come from one colour variable, so they stay a solid `ACCENT`. Then offer to extend the script, following the rainbow code's pattern, and test it in the real panel. |

When a request doesn't clearly fit one mechanism, ask rather than assume — the same "don't force a guess" rule as phrase-splitting in `/recolor`.

```css
/* Hover the swatch below, pick your colour, save this file, then tell Claude "done". */
:root {
  --accent: #5B9CF6;
}
```

**Permission-mode colours.** The input box changes colour by permission mode: Plan, Auto-accept edits, Auto and Bypass permissions each style their send button, focus ring and icon from VS Code's own theme tokens (`errorForeground` for Auto/Bypass permissions, `focusBorder` for Plan, `foreground` for Auto-accept edits) instead of the extension's branding — a deliberate safety cue so the riskier modes stand out no matter what accent you pick. Because of this they're governed entirely by whichever VS Code colour theme is active, not by this script, and look different (sometimes very different, e.g. appearing black on one theme and orange-red on another) depending on it — so a user who switches themes often will see this drift independently of the recolour. Ask whether they want to keep that built-in theming (default, `MODE_COLOURS=0`) or have every mode match their chosen accent instead for a fully consistent look (`MODE_COLOURS=1`). Default to keeping it unless they ask for consistent colouring.

Presets, by family. Most are mid-brightness so they read on both dark and light themes; the ones that don't say so, and you should repeat that note to the user. Neutrals give all four shades because the derivation rules in step 2 don't suit near-white or near-black; use them as given, with the default `DONE_DOT`.

| Family | Name | Hex | Note |
|---|---|---|---|
| Animated gradient | Rainbow | `RAINBOW=1`, fallback `#A78BFA` | Ask for custom colours, see above |
| Warm | Coral red | `#F87171` | |
| Warm | Amber | `#FBBF24` | |
| Warm | Neon yellow | `#FFE01A` | Best on dark themes; faint on light ones |
| Warm | Pink | `#F472B6` | |
| Cool | Mint | `#4ADE80` | |
| Cool | Teal | `#2DD4BF` | |
| Cool | Sky blue | `#5B9CF6` | |
| Cool | Violet | `#A78BFA` | |
| Neutral | White | `#E3ECF5`, dark `#4A6A8A`, soft `#F3F7FB`, bg `#454749` | Dark themes only; nearly invisible on light ones |
| Neutral | Slate | `#94A3B8` | |
| Neutral | Black | `#18181B`, dark `#3F3F46`, soft `#A1A1AA`, bg `#2A2A2E` | Light themes only; the logo and highlights nearly disappear on dark ones |

### 2. Derive the rest of the palette

In a custom install, this derivation only applies to the chat-content colour — the tab icon and text field colours are used as-is, with no derived shades. Derive `DONE_DOT` from whichever colour ends up on the tab icon (`ACCENT_TAB` in a custom install, `ACCENT` in auto).

From the chosen `ACCENT`, compute (keep the same hue for the first three):

| Variable | Rule | Used for |
|---|---|---|
| `ACCENT` | the user's pick | logo, mascot, highlights, unread badge |
| `ACCENT_DARK` | ~20% darker, a little more saturated. White text on it must reach at least 4.5:1 contrast; darken further if not | filled "clay" buttons |
| `ACCENT_SOFT` | ~35% lighter tint | Jupyter banner text |
| `ACCENT_BG` | very dark shade, roughly 20% accent mixed into `#1E1E1E` | Jupyter banner background |
| `DONE_DOT` | a clearly different hue from both `ACCENT` and the blue "working" dot `#3B82F6`. Default green `#22C55E`; if the accent is green or teal, use amber `#F59E0B`; if it is blue, green is fine | dot on the tab icon when Claude has finished |

Show the user the resulting values in one line before installing — five for auto; more for custom, grouped by tab icon / chat content / text field.

### 3. Install the script

Write the script below to `~/.local/bin/claude-recolor`, filling in the five colours, `RAINBOW` (0 or 1) and `MODE_COLOURS` (0 or 1, see "Permission-mode colours" above), and `chmod +x` it. Copy it exactly otherwise, since every line handles a spot that otherwise stays the old colour. For a custom install, extend it per step 1 first: add `ACCENT_TAB`/`ACCENT_FIELD` alongside the existing variables, include them in `WANT`, and split the blanket `#d97757` substitution into one per group before filling in values. Then run it. It should print `claude-recolor: patched anthropic.claude-code-<version>` for each installed version.

**If `~/.local/bin/claude-recolor` already exists**, don't overwrite it. Compare it with the script below, ignoring the variable values and comment lines. If the logic matches, only edit the variable values, so the user's own comments (such as notes on old palettes) survive. If the logic differs, the recipe has changed since it was installed: carry the user's variables and comments over into the new script.

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
RAINBOW=0              # 1 = animated rainbow gradient on top of ACCENT (ACCENT stays as the reduced-motion fallback)
RAINBOW_COLOURS=("#FF4D4D" "#FF9F1A" "#FFE03B" "#4ADE80" "#3B9BFF" "#A66BFF")
RAINBOW_SECS=6         # one full trip through the colours
MODE_COLOURS=0         # 1 = also make Plan/Auto-accept-edits/Auto/Bypass-permissions match ACCENT_DARK; 0 leaves them on VS Code's own theme tokens (Anthropic's built-in safety colours, see "Permission-mode colours")

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
WANT="$ACCENT $ACCENT_DARK $ACCENT_SOFT $ACCENT_BG $DONE_DOT $custom_sum rainbow=$RAINBOW ${RAINBOW_COLOURS[*]} $RAINBOW_SECS mode_colours=$MODE_COLOURS"

# perl -pi works the same on Linux and macOS (sed -i does not)
sub() { perl -pi -e "$1" "${@:2}"; }

# Rainbow pieces, built once from RAINBOW_COLOURS (first colour repeated at the end so the loop is seamless)
if [[ "$RAINBOW" == 1 ]]; then
  loop=("${RAINBOW_COLOURS[@]}" "${RAINBOW_COLOURS[0]}")
  n=$(( ${#loop[@]} - 1 ))
  stops="" bands=""
  for i in "${!loop[@]}"; do
    stops+="<stop offset=\"$(awk "BEGIN{print $i/$n}")\" stop-color=\"${loop[$i]}\"/>"
    bands+="${bands:+, }${loop[$i]} $(( i * 40 ))px"
  done
  # SVG gradient that slides sideways forever; fills reference it as url(#rcRainbow)
  export RC_DEFS="<defs><linearGradient id=\"rcRainbow\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"0\" spreadMethod=\"repeat\">$stops<animateTransform attributeName=\"gradientTransform\" type=\"translate\" from=\"0 0\" to=\"1 0\" dur=\"${RAINBOW_SECS}s\" repeatCount=\"indefinite\"/></linearGradient></defs>"
  # Only these few elements animate directly, each on its own background-position.
  # Earlier versions instead registered --app-claude-orange as an animated custom
  # property inherited by ~28 descendants (every border, focus ring and tint that
  # reads it) — elegant, but it forced Chromium to recompute style for all of them
  # every frame, which froze VS Code outright on at least one Windows machine.
  # Scoping the animation to a handful of concrete elements avoids that; borders,
  # rings and tints stay a solid ACCENT instead of cycling.
  RAINBOW_CSS="
/* claude-recolor rainbow */
@keyframes rc-slide { to { background-position: $(( n * 40 ))px 0; } }
@media (prefers-reduced-motion: no-preference) {
  [class^=\"brand_\"], [class*=\" brand_\"], [class^=\"orbChar_\"], [class*=\" orbChar_\"],
  [class^=\"worktreeBannerButton_\"], [class*=\" worktreeBannerButton_\"],
  [class^=\"usageFillHigh_\"], [class*=\" usageFillHigh_\"], [class^=\"orbDot_\"], [class*=\" orbDot_\"] {
    background-image: repeating-linear-gradient(90deg, $bands);
    background-size: $(( n * 40 ))px 100%;
    animation: rc-slide ${RAINBOW_SECS}s linear infinite;
  }
  [class^=\"brand_\"], [class*=\" brand_\"], [class^=\"orbChar_\"], [class*=\" orbChar_\"] {
    -webkit-background-clip: text; background-clip: text; color: transparent;
  }
}
"
  # Inline panel SVGs (mascot) need the gradient defined somewhere in the page
  RAINBOW_JS=";(()=>{const a=()=>{if(document.getElementById(\"rcRainbowDefs\"))return;document.body.insertAdjacentHTML(\"beforeend\",'<svg id=\"rcRainbowDefs\" width=\"0\" height=\"0\" style=\"position:absolute\" aria-hidden=\"true\">$RC_DEFS</svg>')};document.body?a():document.addEventListener(\"DOMContentLoaded\",a)})();"
fi

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

    if [[ "$RAINBOW" == 1 ]]; then
      # Tab/bar icons, clawd and welcome art: add the gradient, point accent fills at it
      perl -pi -e 's{(<svg\b[^>]*>)}{$1$ENV{RC_DEFS}}' "$res"/*.svg
      sub "s/(fill|stroke)=\"$ACCENT\"/\$1=\"url(#rcRainbow)\"/gi" "$res"/*.svg
      # Panel mascot (inline SVG in the JS bundle)
      sub "s/fill:\"$ACCENT\"/fill:\"url(#rcRainbow)\"/gi" "$js"
      # Header wordmark starburst and effort gauge use the *button* variable, not the main accent
      sub 's/(fill|stroke):"var\(--app-claude-(?:clay-button-)?orange\)"/$1:"url(#rcRainbow)"/g' "$js"
      printf '\n%s\n' "$RAINBOW_JS" >> "$js"
      printf '%s' "$RAINBOW_CSS" >> "$css"
    fi

    if [[ "$MODE_COLOURS" == 1 ]]; then
      # Plan / Auto-accept edits / Auto / Bypass permissions style their send button,
      # focus ring and icon from VS Code's own theme tokens, not the extension's
      # branding (see "Permission-mode colours"). This makes them match ACCENT_DARK
      # and ivory instead, same as the default mode already does. Scoped to just
      # these [data-permission-mode=...] rules so real error text elsewhere keeps
      # its actual error colour.
      perl -pi -e '
        s/([^{}]*\[data-permission-mode=[^{}]*)\{([^{}]*)\}/
          my ($sel,$body) = ($1,$2);
          $body =~ s{var\(--vscode-focusBorder,var\(--app-button-background\)\)}{var(--app-claude-clay-button-orange)}g;
          $body =~ s{--app-error-foreground}{--app-claude-clay-button-orange}g;
          $body =~ s{--app-primary-foreground}{--app-claude-clay-button-orange}g;
          $body =~ s{--app-primary-background}{--app-claude-ivory}g;
          $body =~ s{--app-button-foreground}{--app-claude-ivory}g;
          "$sel\{$body\}"
        /gex
      ' "$css"
    fi

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

With `RAINBOW=1`, also check that `webview/index.js` contains no `var(--app-claude-…orange)` and no `ACCENT` or `ACCENT_DARK` hex. Every accent fill or stroke there should have become `url(#rcRainbow)`; anything left over shows as a static colour while the rest animates. Then run `node --check webview/index.js` if Node is available. `index.js` is a single minified line of several MB, so count matches (`grep -oic`, or a short Python script) rather than printing them with wide context.

With `MODE_COLOURS=1`, grep `webview/index.css` for `[data-permission-mode=` and confirm none of those rule bodies still contain `--app-error-foreground`, `--app-primary-foreground`, `--app-primary-background`, `--app-button-foreground` or `--vscode-focusBorder`. Switching modes with Shift-Tab in the real panel (or the mode picker) should now show the same accent colour in every mode instead of changing.

### 4. Make it re-run after extension updates

Check first: if the watcher is already set up (Linux: `systemctl --user is-enabled claude-recolor.path` prints `enabled`; macOS: the plist exists), skip this step. On Linux, still check that the `.path` unit has a `PathChanged=` line for every extensions folder the user has now.

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

If the user's VS Code `settings.json` doesn't already contain it, offer to set `"claudeCode.hideOnboarding": true` there. It hides the "Learn Claude Code" checklist and the grad-cap mascot (a PNG the script can't recolour).

### 6. Tell the user how to see it

Tell them exactly this:

> Quit VS Code completely (File → Exit, which closes every window), then reopen it. **Developer: Reload Window isn't enough on its own, and if you only reload, it will look like the recolour didn't work.** VS Code's background process keeps the old tab icons cached for as long as it runs, and any other open window keeps the old extension files loaded. A full quit clears both. Your Claude conversations can be resumed afterwards.
>
> A blue dot on the tab icon while Claude is working is expected; that one is left alone on purpose.
>
> VS Code may warn that the installation "appears to be corrupt" after patching. That's just its checksum noticing the edited files. It's harmless; dismiss it (or choose "Don't show again").

Then point them at the "What else you can customise" section below.

---

## What gets changed

This is the auto-mode mapping (a single `ACCENT`). A custom install repoints a subset of these at `ACCENT_TAB` or `ACCENT_FIELD` instead, per the groups in step 1.

All inside `<extensions folder>/anthropic.claude-code-<version>/`:

| File | Original | Becomes |
|---|---|---|
| `webview/index.css` | `--app-claude-orange` `#D97757` | `ACCENT` |
| `webview/index.css` | `--app-claude-clay-button-orange` `#C6613F` | `ACCENT_DARK` |
| `webview/index.css` | Jupyter banner `#F37726` / `#F5A66A` / `#3F2A1F` | `ACCENT` / `ACCENT_SOFT` / `ACCENT_BG` |
| `webview/index.js` | Mascot SVG (above "TODO: Everything") `#D97757` | `ACCENT` |
| `webview/index.js` | "✻ Claude Code" header wordmark starburst and effort gauge, drawn with `var(--app-claude-clay-button-orange)` | `ACCENT_DARK` (via the variable) |
| `resources/*.svg` | Tab/bar/button logo, clawd, welcome art `#D97757` | `ACCENT` |
| `resources/claude-logo-done.svg` | Tab "finished" dot `#D97757` | `DONE_DOT` |

`--app-claude-orange` is a CSS variable used about 28 times across the panel (highlights, unread status, tinted backgrounds via `color-mix`), so replacing it once recolours all of those.

**With `RAINBOW=1`**, on top of the above:
- The SVGs in `resources/` and the JS (mascot, wordmark starburst, effort gauge) get a sliding SVG gradient (`url(#rcRainbow)`). The JS also gets a few lines appended that add the gradient definition to the page.
- In the CSS, `--app-claude-orange` is registered with `@property` and animated, so everything that uses it cycles through the colours. Faded hex copies of the accent (like `#5B9CF61a`) are turned back into the variable at the same opacity.
- Brand text, the orb, the usage bar and the worktree button get a moving left-to-right gradient.
- Filled buttons keep the solid `ACCENT_DARK` so their white text stays readable. The "finished" dot stays `DONE_DOT`.

**With `MODE_COLOURS=1`**, on top of the above:
- The `[data-permission-mode=...]` rules for Plan, Auto-accept edits, Auto and Bypass permissions get their send button, focus ring and icon repointed from VS Code's theme tokens (`errorForeground`, `focusBorder`, `foreground`, `button-foreground`) to `ACCENT_DARK`/ivory, matching the default mode. Nothing else that uses those same tokens (genuine error messages, for instance) is touched — only these specific rules.

Originals are kept as `webview/index.css.bak`, `webview/index.js.bak` and `.orig-resources/*.svg` in each version folder.

**Left alone on purpose** (these are status colours, not branding): warning amber `#E5A54B`, error red `#C74E39`, success green, the blue "working" dot `#3B82F6`, chart colours, diff-editor colours and high-contrast theme highlights. Also untouched: `claude-logo.png` (the Extensions list icon) and `ClawdWithGradCap.png` (hidden by `hideOnboarding`).

**Permission-mode colours, by default** (`MODE_COLOURS=0`): Plan, Auto-accept edits, Auto and Bypass permissions deliberately style their send button/focus ring/icon from VS Code's own theme tokens rather than the extension's branding, as a safety cue for the riskier modes. This means they follow whichever colour theme is active and are *not* touched by `ACCENT` — on VS Code's stock dark theme Auto/Bypass permissions render in a reddish-orange (`errorForeground`); on a theme like Tokyo Day the same tokens can render as near-black. If a user reports the panel "snapping back to orange" after it briefly showed the right colour, check whether a permission-mode switch (often automatic, e.g. a default-to-Auto setting or a one-time mode notice) coincided with it before assuming a caching bug — this is almost always the actual cause. Set `MODE_COLOURS=1` for a consistent accent across every mode instead.

## Changing colour later

Edit the variables at the top of `~/.local/bin/claude-recolor` and re-run it, then quit VS Code completely and reopen it. It always patches from the originals, so you can change colour as often as you like.

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

## The `/recolor` slash command

A custom slash command at `.claude/commands/recolor.md` means changing colour later doesn't need "follow CLAUDE-CODE-RECOLOR.md" again — just `/recolor sky blue` or `/recolor rainbow` from inside any Claude Code session. It counts colour phrases rather than needing a keyword: one phrase recolours everything, two splits tab icon+chat content from the text field, three sets tab icon / chat content / text field separately (`/recolor rainbow rainbow blue`, no "custom" needed). It reads the phrase(s), derives the palette the same way step 1–2 above do, edits the variables at the top of `~/.local/bin/claude-recolor` (same as "Changing colour later", extending it for per-group variables the same way step 1's Custom instructions describe if it hasn't been already), re-runs it, and reminds the user to quit and reopen VS Code. It only changes colour on an existing install — for first-time setup, or anything beyond colour (permission-mode colours, patterns, renaming), it defers back to this recipe.

`/recolor` doesn't collide with anything: Claude Code's built-in `/color` (US spelling only) is unrelated — it just tints the session's prompt bar (terminal/claude.ai-only, invisible inside the VS Code panel), not the extension.

**If `~/.claude/commands/recolor.md` (global) or this project's `.claude/commands/recolor.md` doesn't exist yet**, install it as part of following this recipe: copy the command file from the claude-recolor repo this recipe came from, or write one with the same five steps (resolve colour → derive palette → edit the installed script's variables → run it → remind to restart VS Code), into `~/.claude/commands/recolor.md` so it works in any project, not just this one.
