---
description: Change (or re-apply) the Claude Code panel's accent colour — one colour, or separate tab icon / chat content / text field colours
argument-hint: [colour or "rainbow"]
---

Change the Claude Code VS Code extension's accent colour(s) based on: $ARGUMENTS

This is the fast path for someone who already has claude-recolor installed and just wants a new colour — not the full first-time walkthrough. Keep the exchange short. If `~/.local/bin/claude-recolor` doesn't exist yet, tell the user to run the full recipe first (`follow CLAUDE-CODE-RECOLOR.md`) instead of attempting any of this — this command only changes colour on an existing install.

**1. Count how many colour phrases are in `$ARGUMENTS`** — no keyword needed, just the count:

- **If it contains commas (or "and"/"&" joining clear items)**, split on those — trust this over any guessing. `navy, dusty grey, reddish purple` is unambiguously 3 phrases.
- **Watch for a *static* gradient request before counting phrases at all**: two-plus colour words followed by "gradient" with no animation language (no "animated", "cycling", "moving", "sliding", "rainbow") — e.g. `blue green gradient`, `blue green gradient left to right` — describes ONE blended static gradient between those colours, not separate colours for separate groups. This isn't built (see the recipe's "Beyond a single colour" → "Anything needing new rendering entirely"); say so and offer to extend it rather than ever splitting the named colours across tab icon/chat content/text field, which is not what was asked for. "Rainbow"/"animated gradient"/"cycling colours" is a different, already-built thing — see below.
- **Otherwise, judge word-by-word, but only commit to a split you're actually confident in**: "rainbow" (and "gradient" specifically when paired with animation language, e.g. "animated gradient") is always its own phrase (a mode keyword, never part of a hue), so `rainbow blue` is always two phrases, never a colour called "rainbow blue". Recognised adjective+hue compounds stay one phrase ("sky blue", "dusty teal", "frost white"). Don't force a clean split onto wording that doesn't cleanly support one — e.g. `navy teal dusty grey reddish purple orange haze` has no delimiters and no confident reading (is "navy teal" one stacked phrase or two bare colours with nothing between them? is "orange haze" a compound or "orange" plus a stray word?), and even the most generous reading exceeds three groups. When you're not confident — ambiguous wording, more than three phrases either way, or a reading you'd be guessing at — **stop and ask**: "Which colour(s), for which of tab icon / chat content / text field, in order, separated by commas?" Don't apply anything until the answer is unambiguous.
- **One phrase** — e.g. `blue`, `sky blue`, `rainbow`, `#5B9CF6`, `dusty teal`. **Auto mode**: a single `ACCENT` for the whole panel. This is the common case.
- **Two phrases** — e.g. `rainbow blue` or `navy, teal`. First → **tab icon + chat content together**, second → **text field** alone.
- **Three phrases** — e.g. `rainbow rainbow blue` or `coral, amber, sky blue`. In order: **tab icon**, **chat content**, **text field**.
- **Empty** — ask with AskUserQuestion: one colour for everything, or separate tab icon / chat content / text field colours? Then continue below with whichever count they imply.

For any phrase, resolve it to a hex the same way CLAUDE-CODE-RECOLOR.md's step 1 would (read that file first if it's present in this project for the full picker flow, preset table and palette-derivation formulas) — including "rainbow"/"gradient" meaning the animated gradient mode, not a solid hex.

**2. Derive each group's palette**: `ACCENT_DARK` (~20% darker, a touch more saturated, white text on it must reach ≥4.5:1 contrast), `ACCENT_SOFT` (~35% lighter tint), `ACCENT_BG` (~20% accent mixed into `#1E1E1E`), `DONE_DOT` (a hue clearly different from both `ACCENT` and the blue "working" dot `#3B82F6` — default green `#22C55E`, amber `#F59E0B` if the accent is itself green/teal). Show the values in one line per group before applying.

**3. Apply it to `~/.local/bin/claude-recolor`:**

- **Auto mode**: edit just the variable values at the top (`ACCENT`, `ACCENT_DARK`, `ACCENT_SOFT`, `ACCENT_BG`, `DONE_DOT`, and `RAINBOW`/`RAINBOW_COLOURS`/`RAINBOW_SECS` if a gradient was requested), leaving the rest of the script — and any of the user's own comments — untouched.
- **Two- or three-group mode**: if the script already has per-group variables from an earlier custom run, just update those groups' values. If not, this needs real engineering, not a guess — read CLAUDE-CODE-RECOLOR.md's "Custom" instructions in step 1 and follow them: inspect the real installed extension (`resources/*.svg` filenames, the CSS around `--app-claude-orange`, the input field's markup in `webview/index.js`) rather than assuming which patch line belongs to which group, since this varies by extension version. A group set to "rainbow" needs the animated-gradient treatment applied to just that group's elements, independently of the other groups' solid colours — follow the rainbow code's pattern for whichever group needs it. If chat content's background tint can't be cleanly separated from its highlight colour without inventing a selector that doesn't exist, say so and fold it into chat content rather than faking it. Add any new variables to the script's `WANT` stamp so re-runs invalidate correctly.

**4. Run it.** It should print `claude-recolor: patched anthropic.claude-code-<version>` for each installed extension version.

**5. Verify.** Grep the patched files for the old hex values the same way CLAUDE-CODE-RECOLOR.md's step 3 verify check does — all counts should be 0. For any group set to rainbow, also check `webview/index.js` has no leftover static accent hex or `var(--app-claude-...orange)` where it should have become `url(#rcRainbow)`.

**6. Tell the user to quit VS Code completely (File → Exit, every window) and reopen it.** A plain "Developer: Reload Window" isn't enough — other open windows keep the old files loaded, and VS Code's own window needs a full restart to drop cached tab icons. Their Claude conversations resume afterwards.

For anything beyond a plain colour or the rainbow — permission-mode colours (`MODE_COLOURS`), any other visual effect (judge by mechanism, not the word used — see the recipe's "Beyond a single colour", which also covers why rapid flashing/blinking-type effects need a safety check before ever being built), renaming Claude — point the user at the full recipe instead of trying to handle it here.
