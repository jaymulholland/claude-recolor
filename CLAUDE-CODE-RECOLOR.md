# Claude Code VS Code recolour (a recipe)

Swap the Claude Code VS Code extension's orange for a colour you choose — either one colour for everything, or separate colours for the tab icon, the chat content and the message input field. This file is written to be handed to a Claude Code agent: open Claude Code in VS Code and say **"follow CLAUDE-CODE-RECOLOR.md"** (or more casually, "follow claude recolor" / "follow the recipe" — see the note at the top of "Instructions for the agent" below). The agent asks you for a colour (or colours), installs a small patch script, runs it, and sets it to re-run after extension updates.

Works in VS Code, VS Code Insiders, Cursor and Windsurf on Linux and macOS. On Windows, run the script from Git Bash or WSL, or have the agent port it to PowerShell.

The extension has no accent-colour setting (its orange is hardcoded), so the script patches the installed extension files. **Every extension update reinstalls the originals**, which is why the script is idempotent and can run automatically.

### Cost and upkeep

**Tokens.** the automatic re-runs after extension updates is free. Rough figures for one run of this recipe, on top of whatever Claude Code itself uses:
- **First install:** reading this file and copying the scripts from `scripts/` is roughly 10-15k tokens including the questions, checks and verification.
- **Changing colour later to a known preset, named colour or hex:** a few hundred tokens. `claude-recolor-resolve` (in `scripts/`) does the colour lookup and palette maths (real HSL arithmetic, not LLM estimation) and edits the installed script itself — the agent just calls it and relays the result. See `/recolor` below.
- **Changing colour later to a free-text description** ("dusty teal", "match the theme accent") **or a multi-group custom layout**: still needs an agent turn to turn the description into a hex, or to engineer the per-group split, roughly the same cost as before.

Type `/context` in Claude Code to see the real numbers for your session.

**The watcher.** It waits on file-system events (systemd path unit on Linux, launchd on macOS), so it uses no CPU while idle. It wakes when anything in the extensions folder changes, including other extensions' updates, waits 15 seconds, then runs the script. When there's nothing to patch the script finishes in about 0.02 s; a full patch takes about 0.1 s.

**A solid colour has no runtime cost.** The panel just uses a different hex.

**The animated gradient does.** While the Claude panel is visible it redraws everything that uses the accent colour, continuously, and the tab icons animate whenever they're on screen. That's minor on a desktop but worth knowing on a laptop on battery. It switches itself off when your OS has reduced motion turned on. To see what it costs on your machine, open **Help → Open Process Explorer** and compare the Claude webview's CPU with the gradient on and off.

**Upkeep.** Usually none. Two things can come back after an extension update: VS Code's "installation appears to be corrupt" notice (dismiss it), and, rarely, a new orange element the script doesn't know about yet. If you spot orange after an update, ask Claude to run the verify check in step 3 and add the new colour to the script.

---

## Instructions for the agent

**Recognising the invocation.** Don't require the user to type this file's exact name. If they say anything that clearly means "run this recipe" — "follow the recipe", "follow claude recolor", "run the colour recipe", "set up claude-recolor", or similar — and this file is the obvious match (e.g. it's the only recipe-shaped doc open or present in the project), treat that as "follow CLAUDE-CODE-RECOLOR.md" and just proceed. Don't insist on the literal filename, and don't refuse or stall waiting for more precise phrasing — ask only if there's a genuine ambiguity (e.g. more than one recipe-like file present and it's unclear which one they mean).

Work through the steps in order. Ask the user only where a step says to.

**Before step 1, warn the user** so they can get ready while you work:

> Heads up: when this is done you'll need to quit VS Code completely and reopen it to see the new colour, so save your work in any other VS Code windows now. Other open windows keep the old extension files loaded, and if any stay open it will look like the recolour didn't work.

### 1. Pick the colour(s) with the user

**Never ask a separate "auto or custom" question.** Grouping is inferred from how many colour phrases the user names, exactly the way `/recolor` reads its `$ARGUMENTS` — so a returning user gets identical behaviour whether they type a command or answer this question. Ask a single AskUserQuestion call whose question text invites either:

> Pick a colour for the Claude Code panel — or name up to three, separated by commas, to set the tab icon, chat content and text field separately (e.g. "navy, teal, coral"). (Don't see your colour? Type it under Other — a hex, name, or description.)

**Before building the options, check `~/.config/claude-recolor/dedicated.txt`.** If it exists, it holds four `Name = #HEX` lines — a user has swapped one of the default buttons for a saved colour before (see below) — and its four entries, in order, replace the table below. Otherwise use the defaults:

| Option | What it means |
|---|---|
| **Sky blue** (`#5B9CF6`) | Calm, reads well on both light and dark themes. |
| **Warm yellow** (`#FAE311`) | Bright and vivid; best on dark themes, faint on light ones. |
| **Rainbow (animated)** | Cycles through colours continuously; see "Animated gradient" below. |
| **Slate** (`#4A565C`) | Cool muted grey; reads best on dark themes. |

Frost white, Violet, Black, and "open VS Code's colour picker" aren't dedicated buttons (AskUserQuestion caps this question at four, and these four earn the slots more often) but all still resolve instantly through the automatic Other above — type the name, or type something like "open the colour picker"/"let me pick visually". For the picker: say up front that it opens a file in the editor, write a scratch file `accent-picker.css` (in your scratchpad, or `/tmp`) containing the block near the end of this step, open it with `code <path>` (or `cursor <path>`), and tell the user to hover the little swatch next to the hex, pick a colour, save the file (Ctrl/Cmd+S), then tell you "done" — read the hex back from the file.

**Never add your own "Other" row to the options list.** AskUserQuestion always appends one automatically — a hand-added one just produces two near-identical "other" buttons, which is a bug, not a feature. The automatic Other is where everything else comes in as typed text: a hex code, a description like "dusty teal" or "match the theme accent" (turn it into a hex, then confirm by showing the hex and a one-line description), the name of any preset from the table further down this step (Coral red, Amber, Neon yellow, Warm yellow, Pink, Mint, Teal, Sky blue, Violet, Frost white, Slate, Black, "colour picker", or their own rainbow colours), or several of the above separated by commas for separate groups (see below). If they describe more than one *blended* colour (a gradient, a pattern, an effect), see "Beyond a single colour" below; never quietly flatten it to one hex.

**If the Other answer isn't one of the named presets** — a bare hex, or a description you turned into one ("dusty teal", "match the theme accent") — after confirming the hex, ask one quick follow-up: "Save `<name>` (`<hex>`) as a preset for next time?" This is a separate round trip on purpose (you can't know whether it's needed until you see their answer — see "Batch independent questions" below). If yes, append a `Name = #HEX` line to `~/.config/claude-recolor/presets.txt` (create the directory/file if they don't exist yet). Before resolving a future Other answer, check that file by name alongside the built-in presets table below, same tier, no extra ceremony.

**If they say yes, also ask whether it should take one of the four dedicated buttons.** A second AskUserQuestion: list the four current dedicated names (from `dedicated.txt` if it exists, else the defaults above) as options, plus **Keep it in Other only** (recommended — swapping out Rainbow or a button they reuse often costs them a one-shot pick next time). If they choose a slot, write all four current entries as `Name = #HEX` lines to `~/.config/claude-recolor/dedicated.txt` (seed it from the defaults first if it doesn't exist yet), with that slot's line replaced by the new preset. The next colour question reads this file for its options instead of the hardcoded four.

The question UI can't show a colour picker or swatches, only text, so don't label any option as if it does. Resist splitting this into a family question followed by a specific-preset question — putting Sky blue, Warm yellow, Rainbow and Slate directly on the one question means the common cases resolve in a single round trip. The presets table further down is for resolving whatever the user types into Other, not for driving a second AskUserQuestion call.

**Counting colour phrases in the answer:**
- Commas (or "and"/"&" joining clear items) separate phrases — trust this over any guessing.
- Watch for a *static* gradient request before counting phrases at all: two-plus colour words followed by "gradient" with no animation language (no "animated", "cycling", "moving", "sliding", "rainbow") describes one blended static gradient, not separate colours for separate groups. This isn't built (see "Beyond a single colour" further down); say so and offer to extend it rather than splitting the named colours across tab icon/chat content/text field.
- Otherwise judge word-by-word, but only commit to a split you're confident in: "rainbow" (and "gradient" specifically when paired with animation language) is always its own phrase, never part of a hue — so "rainbow blue" is two phrases, never a colour called "rainbow blue". Recognised adjective+hue compounds stay one phrase ("sky blue", "dusty teal", "frost white").
- **One phrase** — **Auto mode**: a single `ACCENT` for the whole panel. The common case.
- **Two phrases** — first → **tab icon + chat content together**, second → **text field** alone.
- **Three phrases** — in order: **tab icon**, **chat content**, **text field**.
- Not confident (ambiguous wording, more than three phrases either way, or a reading you'd be guessing at) — don't force a split. Ask a follow-up instead: "Which colour(s), for which of tab icon / chat content / text field, in order, separated by commas?"

If Auto, skip ahead and follow the rest of the recipe unchanged with a single `ACCENT`. If Custom (two or three phrases), resolve each phrase to a hex the same way a single colour would (presets table, picker, or description) — a group can also be the animated gradient independently of the others; see "Animated gradient" below.

Before extending the script for Custom, inspect the real installed extension rather than guessing which patch line belongs to which group — `resources/*.svg` filenames, the CSS rules around `--app-claude-orange`, and the input field's markup in `webview/index.js` all vary by extension version. The chat content's "background" tint may not be cleanly separable from its highlight colour without new CSS; if it isn't, say so and fold it into chat content rather than inventing a selector that doesn't exist. Then, in "Install the script" below, replace the single blanket substitution (`s/#d97757/$ACCENT/gi` across css/js/svgs) with one targeted substitution per group, each pointing at its own variable (e.g. `ACCENT_TAB`, `ACCENT` for chat content, `ACCENT_FIELD`) — same inspect-patch-verify approach as "Beyond a single colour". Add the new variables to `WANT` (step 3) so the cache invalidates when any of them change, and verify every group visually in the real panel, not just by grepping for the old hex. The text field also sits near the permission-mode styling described in "Permission-mode colours" below — if the user wants the text field colour to apply in every permission mode too, that's the forced `MODE_COLOURS` question further down this step — when a custom install has its own text-field colour, wire that question's override option to `ACCENT_FIELD` instead of `ACCENT_DARK`, so forcing every mode to match actually matches the text field's own colour, not the chat content's.

If the script is already installed (step 3), read its current colour variables (`ACCENT`, and in a custom install `ACCENT_TAB`/`ACCENT_FIELD` too) and `RAINBOW` first, and mention them, so the user knows what they're changing from.

**Batch independent questions into one AskUserQuestion call.** The tool accepts up to four questions per call, shown to the user together in one bubble with no thinking step in between — that's the "series of questions all at once" behaviour you may have seen elsewhere, and this recipe should use it instead of several sequential calls. On a fresh install (no `~/.local/bin/claude-recolor` yet), the colour question above and the permission-mode-colours question below don't depend on each other's answers, so ask them as two questions in the *same* call. Don't split into multiple round trips unless a later question's content genuinely can't be known until an earlier answer comes back — there's no such case left in this recipe now that grouping comes from comma-counting instead of a separate auto/custom question.

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

**Permission-mode colours — ask explicitly, don't default silently.** The input box changes colour by permission mode: Plan, Auto-accept edits, Auto and Bypass permissions each style their send button, focus ring and icon from VS Code's own theme tokens (`errorForeground` for Auto/Bypass permissions, `focusBorder` for Plan, `foreground` for Auto-accept edits) instead of the extension's branding — a deliberate safety cue so the riskier modes stand out no matter what accent you pick. Because of this they're governed entirely by whichever VS Code colour theme is active, not by this script, and look different (sometimes very different, e.g. appearing black on one theme and orange-red on another) depending on it — so a user who switches themes often will see this drift independently of the recolour.

This is a real tradeoff (consistency vs. a built-in safety cue), so the user must actively decide it rather than have it defaulted for them. Ask it once per fresh install, as a second question in the *same* AskUserQuestion call as the colour pick in step 1 above (see "Batch independent questions" there) rather than a separate round trip — a later `/recolor` colour change doesn't re-ask this at all; it leaves whatever `MODE_COLOURS` is already set to:

> Plan, Auto-accept edits, Auto and Bypass permissions currently show VS Code's own built-in colours, not your accent — that's a deliberate safety cue so the riskier modes stand out. Keep that, or force every mode to show the exact same colour?

| Option | What it means |
|---|---|
| **Keep built-in** (recommended) | `MODE_COLOURS=0`. Riskier modes keep their own look and can drift if the user later switches VS Code themes, independently of this recolour. |
| **Force the same colour everywhere** | `MODE_COLOURS=1`. Every mode's send button, focus ring and icon is overridden to match the accent (`ACCENT_DARK` in an auto install; `ACCENT_FIELD` in a custom install with its own text-field colour, so the override matches the text field specifically — see step 1's custom instructions above) — which means losing the built-in safety cue. |

If the script is already installed, read its current `MODE_COLOURS` value first and tell the user what it's set to now, same as you would for colours, rather than asking as if from a blank slate.

Presets, by family — use this to resolve whatever the user types into **Other** above, not to drive a second AskUserQuestion call. Most are mid-brightness so they read on both dark and light themes; the ones that don't say so, and you should repeat that note to the user. Neutrals give all four shades because the derivation rules in step 2 don't suit near-white or near-black; use them as given, with the default `DONE_DOT`.

| Family | Name | Hex | Note |
|---|---|---|---|
| Animated gradient | Rainbow | `RAINBOW=1`, fallback `#A78BFA` | Ask for custom colours, see above |
| Warm | Coral red | `#F87171` | |
| Warm | Amber | `#FBBF24` | |
| Warm | Neon yellow | `#FFE01A` | Best on dark themes; faint on light ones |
| Warm | Warm yellow | `#FAE311` | Bright and vivid, like Neon yellow; best on dark themes, faint on light ones |
| Warm | Pink | `#F472B6` | |
| Cool | Mint | `#4ADE80` | |
| Cool | Teal | `#2DD4BF` | |
| Cool | Sky blue | `#5B9CF6` | |
| Cool | Violet | `#A78BFA` | |
| Neutral | Frost white | `#E3ECF5`, dark `#4A6A8A`, soft `#F3F7FB`, bg `#454749` | Dark themes only; nearly invisible on light ones |
| Neutral | Slate | `#4A565C` | Cool muted grey, close to gunmetal but a touch more washed out; darker than a typical pastel slate, reads best on dark themes |
| Neutral | Black | `#18181B`, dark `#3F3F46`, soft `#A1A1AA`, bg `#2A2A2E` | Light themes only; the logo and highlights nearly disappear on dark ones |

### 2. Derive the rest of the palette

In a custom install, this derivation only applies to the chat-content colour — the tab icon and text field colours are used as-is, with no derived shades. Derive `DONE_DOT` from whichever colour ends up on the tab icon (`ACCENT_TAB` in a custom install, `ACCENT` in auto).

From the chosen `ACCENT`, compute (keep the same hue for the first three):

| Variable | Rule | Used for |
|---|---|---|
| `ACCENT` | the user's pick | logo, mascot, highlights, unread badge |
| `ACCENT_DARK` | ~20% darker, a little more saturated. White text on it must reach at least 4.5:1 contrast; darken further if not — **except yellow-family hues** (roughly 45-65° hue), where chasing that contrast target darkens straight through "gold" into muddy olive/brown, which isn't a dark yellow at all. For those, skip the contrast-driven darken: keep `ACCENT_DARK` close to `ACCENT` itself (a small darken at most, hue and saturation preserved), staying vivid even though white text on it may now fall short of 4.5:1. That tradeoff matches how the undarkened accent is already used elsewhere in the panel | filled "clay" buttons |
| `ACCENT_SOFT` | ~35% lighter tint | Jupyter banner text |
| `ACCENT_BG` | very dark shade, roughly 20% accent mixed into `#1E1E1E` | Jupyter banner background |
| `DONE_DOT` | a clearly different hue from both `ACCENT` and the blue "working" dot `#3B82F6`. Default green `#22C55E`; if the accent is green or teal, use amber `#F59E0B`; if it is blue, green is fine | dot on the tab icon when Claude has finished |

Show the user the resulting values in one line before installing — five for auto; more for custom, grouped by tab icon / chat content / text field.

### 3. Install the script

The actual code lives in this repo's `scripts/` folder, not inline in this document — it's the single source of truth, so there's nothing here to retype or keep in sync:

- `scripts/claude-recolor.sh` — the patch script itself
- `scripts/claude-recolor-resolve.sh` — resolves a colour spec (preset/hex/rainbow) to a full palette and edits the installed script's variables; see "The `/recolor` slash command" below
- `scripts/palette.pl` — the palette derivation maths (`ACCENT_DARK`/`ACCENT_SOFT`/`ACCENT_BG`/`DONE_DOT`) used by the resolve script
- `scripts/presets.txt`, `scripts/presets-neutral.txt` — the named presets from the table in step 1

**Before installing, do all pre-install discovery in a single shell command**: confirm `$HOME`, create `~/.local/bin` if it doesn't exist yet, and list which of `claude-recolor.sh`'s `EXT_ROOTS` folders are actually present. One command, not one call per check — the same batching principle as the verify step below.

**Copy all five files from this repo's `scripts/` folder into `~/.local/bin/`**, then fill in the five colour variables, `RAINBOW` (0 or 1) and `MODE_COLOURS` (0 or 1, see "Permission-mode colours" above) at the top of the copied `claude-recolor` — don't change anything below that line. `chmod +x claude-recolor claude-recolor-resolve`. For a custom install, extend `claude-recolor` per step 1 first: add `ACCENT_TAB`/`ACCENT_FIELD` alongside the existing variables, include them in `WANT`, and split the blanket `#d97757` substitution into one per group before filling in values. Then run it. It should print `claude-recolor: patched anthropic.claude-code-<version>` for each installed version.

If this repo isn't available locally (the user only saved this one `.md` file), tell them you need the repo's `scripts/` folder to install from — either have them clone/download `claude-recolor`, or fetch the five files' raw contents yourself if you have network access, rather than retyping the script by hand into a new file (that recreates the duplicate-source-of-truth problem this structure exists to avoid).

**If `~/.local/bin/claude-recolor` already exists**, don't overwrite it. Compare it with `scripts/claude-recolor.sh`, ignoring the variable values and comment lines. If the logic matches, only edit the variable values, so the user's own comments (such as notes on old palettes) survive. If the logic differs, the recipe has changed since it was installed: carry the user's variables and comments over into the new script. Always copy `scripts/claude-recolor-resolve.sh` and `scripts/palette.pl` fresh (they're not user-edited).

**Verify, all in one shell command** (one tool call, not one per check — these checks have no dependency on each other and splitting them just costs extra round trips and extra permission prompts for no benefit):

- grep the patched version folder for `#d97757`, `#c6613f`, `#f37726`, `#f5a66a` and `#3f2a1f` (case-insensitive) across `webview/index.css`, `webview/index.js` and `resources/*.svg`. All counts should be 0. If a newer extension version introduces a new orange, add it to the script rather than leaving it.
- With `RAINBOW=1`, also check that `webview/index.js` contains no `var(--app-claude-…orange)` and no `ACCENT` or `ACCENT_DARK` hex. Every accent fill or stroke there should have become `url(#rcRainbow)`; anything left over shows as a static colour while the rest animates. Then run `node --check webview/index.js` if Node is available. `index.js` is a single minified line of several MB, so count matches (`grep -oic`, or a short Python script) rather than printing them with wide context.
- With `MODE_COLOURS=1`, **do not** grep the whole file for `--app-error-foreground`, `--app-primary-foreground`, `--app-primary-background`, `--app-button-foreground` or `--vscode-focusBorder` — those tokens legitimately appear dozens of times elsewhere in the CSS (real error text, disabled states, etc., per "Left alone on purpose" above), so a whole-file grep always finds "leftovers" that were never meant to be touched and is a false-positive trap, not a verification. Scope the check to only the `[data-permission-mode=...]` rule bodies, the same way the patch script itself does, e.g.:
  ```perl
  perl -ne '
    my @b = /([^{}]*\[data-permission-mode=[^{}]*)\{([^{}]*)\}/g;
    my $bad = 0;
    for (my $i=1; $i<@b; $i+=2) {
      $bad++ if $b[$i] =~ /--app-error-foreground|--app-primary-foreground|--app-primary-background|--app-button-foreground|--vscode-focusBorder/;
    }
    print "leftover permission-mode tokens: $bad\n";
  ' webview/index.css
  ```
  This should print 0. Switching modes with Shift-Tab in the real panel (or the mode picker) should now show the same accent colour in every mode instead of changing.

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
- The `[data-permission-mode=...]` rules for Plan, Auto-accept edits, Auto and Bypass permissions get their send button, focus ring and icon repointed from VS Code's theme tokens (`errorForeground`, `focusBorder`, `foreground`, `button-foreground`) to `ACCENT_DARK`/ivory, matching the default mode. Nothing else that uses those same tokens (genuine error messages, for instance) is touched — only these specific rules. In a custom install where the user asked for the text field's own colour to apply in every mode, point these rules at `ACCENT_FIELD` instead of `ACCENT_DARK`.

Originals are kept as `webview/index.css.bak`, `webview/index.js.bak` and `.orig-resources/*.svg` in each version folder.

**Left alone on purpose** (these are status colours, not branding): warning amber `#E5A54B`, error red `#C74E39`, success green, the blue "working" dot `#3B82F6`, chart colours, diff-editor colours and high-contrast theme highlights. Also untouched: `claude-logo.png` (the Extensions list icon) and `ClawdWithGradCap.png` (hidden by `hideOnboarding`).

**Permission-mode colours, by default** (`MODE_COLOURS=0`): Plan, Auto-accept edits, Auto and Bypass permissions deliberately style their send button/focus ring/icon from VS Code's own theme tokens rather than the extension's branding, as a safety cue for the riskier modes. This means they follow whichever colour theme is active and are *not* touched by `ACCENT` — on VS Code's stock dark theme Auto/Bypass permissions render in a reddish-orange (`errorForeground`); on a theme like Tokyo Day the same tokens can render as near-black. If a user reports the panel "snapping back to orange" after it briefly showed the right colour, check whether a permission-mode switch (often automatic, e.g. a default-to-Auto setting or a one-time mode notice) coincided with it before assuming a caching bug — this is almost always the actual cause. Set `MODE_COLOURS=1` for a consistent accent across every mode instead — step 1 asks this explicitly on every fresh install rather than leaving it as a silent default.

## Changing colour later

For a known preset name, a hex, or "rainbow": `~/.local/bin/claude-recolor-resolve "<spec>"` resolves it, derives the palette, edits the variables, and runs `claude-recolor` for you in one step — this is what `/recolor` calls (see below). For anything else (a free-text description, a multi-group split the script doesn't support yet), edit the variables at the top of `~/.local/bin/claude-recolor` by hand and re-run it. Either way, it always patches from the originals, so you can change colour as often as you like — then quit VS Code completely and reopen it.

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

A custom slash command at `.claude/commands/recolor.md` means changing colour later doesn't need "follow CLAUDE-CODE-RECOLOR.md" again — just `/recolor sky blue` or `/recolor rainbow` from inside any Claude Code session. It counts colour phrases rather than needing a keyword: one phrase recolours everything, two splits tab icon+chat content from the text field, three sets tab icon / chat content / text field separately (`/recolor rainbow rainbow blue`, no "custom" needed).

For the common case — every phrase is a known preset name, a hex, or "rainbow" — it just runs `~/.local/bin/claude-recolor-resolve "$ARGUMENTS"` and relays the result; that one call does the lookup, the palette maths and the re-run, so there's no LLM reasoning (and no repeat read of this file) on the hot path. It only falls back to deriving things itself — turning a free-text description into a hex, asking via `AskUserQuestion`, or engineering a new multi-group split — for whatever `claude-recolor-resolve` can't resolve on its own (it says so on exit, see `scripts/claude-recolor-resolve.sh`'s header comment for the exact exit codes). It only changes colour on an existing install — for first-time setup, or anything beyond colour (permission-mode colours, patterns, renaming), it defers back to this recipe.

`/recolor` doesn't collide with anything: Claude Code's built-in `/color` (US spelling only) is unrelated — it just tints the session's prompt bar (terminal/claude.ai-only, invisible inside the VS Code panel), not the extension.

**If `~/.claude/commands/recolor.md` (global) or this project's `.claude/commands/recolor.md` doesn't exist yet**, install it as part of following this recipe: copy the command file from the claude-recolor repo this recipe came from, or write one with the same five steps (resolve colour → derive palette → edit the installed script's variables → run it → remind to restart VS Code), into `~/.claude/commands/recolor.md` so it works in any project, not just this one.
