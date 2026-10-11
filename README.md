<div align="center">

# Recolor for Claude Code

**Replace Claude Code's orange with any color you want within Visual Studio Code.**

<img src="https://github.com/user-attachments/assets/3536968c-f991-4d00-bac1-a6152376cf47" width="428" alt="The Claude Code panel in VS Code with its logo, mascot and tab icons cycling through an animated rainbow gradient">

<sub>Shown here in animated rainbow mode.</sub>

</div>

---

The Claude Code VS Code extension has no accent-colour setting. **claude-recolor** is a recipe your Claude agent follows: it helps you pick a colour, patches the extension, and re-applies it after every update.

> [!NOTE]
> **For devs:** The extension's CSS, JS and SVGs are already plain text (just minified) — this is a series of regex find-and-replace passes swapping hex colour values in those files. The actual code lives in [`scripts/`](scripts/): [`claude-recolor.sh`](scripts/claude-recolor.sh) does the patching, [`claude-recolor-resolve.sh`](scripts/claude-recolor-resolve.sh) + [`palette.pl`](scripts/palette.pl) resolve a colour name/hex to a full palette with real HSL/contrast maths (not an LLM estimating it), and [`CLAUDE-CODE-RECOLOR.md`](CLAUDE-CODE-RECOLOR.md) is the recipe that installs and drives them.

## Features

- 🎨 **Any colour.** Describe it ("dusty teal"), pick a named preset, use VS Code's colour picker, or type a hex.
- 🌈 **Animated gradients.** A sliding rainbow, or a gradient through colours you choose.
- 🔁 **Survives updates.** Re-applies itself when the extension updates.
- ↩️ **Reversible.** Originals are backed up, and the recipe explains how to restore them.
- ⚡ **`/recolor` command.** Change colour again later without re-running the whole recipe — for a known preset or hex it's a single deterministic script call, not an LLM re-deriving colour maths each time.

## Use it

1. Clone or download this repo (the install step copies real files from its [`scripts/`](scripts/) folder, so just the one `.md` file isn't enough anymore) and open Claude Code in it.
2. Say:
   ```
   follow CLAUDE-CODE-RECOLOR.md
   ```
   or just:
   ```
   follow claude recolor
   ```
   Casual phrasing works too ("follow the recipe", "set up claude recolor") — the file tells the agent not to insist on the exact filename.
3. Pick a colour.
4. Run **Developer: Reload Window** (<kbd>Ctrl</kbd>/<kbd>Cmd</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd>), then quit VS Code completely and reopen it. Tab icons are cached for as long as VS Code's background process keeps running, so a full restart is what actually clears them — reload alone gets you most of the way there, the restart finishes the job. Your Claude conversations pick back up right where you left off.

## `/recolor`: changing colour later

Once the recipe's installed, you don't need to re-run it to change colour — just ask Claude:

```
/recolor sky blue
/recolor rainbow
/recolor #5B9CF6
```

Following the recipe installs this globally (`~/.claude/commands/recolor.md`), along with `claude-recolor-resolve`, `palette.pl` and the presets files next to `claude-recolor` in `~/.local/bin/` — that's what makes `/recolor` fast for known colours rather than re-deriving a palette from scratch. To get the command without running the full recipe, you'd also need those files in `~/.local/bin/`, so it's easier to just run the recipe once.

It works out tab icon / chat content / text field colours from how many you give it — no keyword needed:

| You type | What happens |
| --- | --- |
| `/recolor blue` | One colour for the whole panel. |
| `/recolor rainbow blue` | First colour (or "rainbow") → tab icon + chat content together, second → text field. |
| `/recolor rainbow rainbow blue` | Three colours, in order: tab icon, chat content, text field. |
| `/recolor navy, dusty grey, reddish purple` | Commas disambiguate when colour names are themselves multi-word. |

It only changes colour on an existing install — run the full recipe first if you haven't. For anything beyond a plain colour or the rainbow (patterns, glows, permission-mode colours, renaming Claude), it hands off to the full recipe rather than guessing.

## Compatibility

| Editor | Linux | macOS | Windows |
| --- | :---: | :---: | :---: |
| VS Code, VS Code Insiders, Cursor, Windsurf | ✅ | ✅ | via Git Bash or WSL |

## Disclaimer

> [!WARNING]
> Unofficial, not affiliated with Anthropic. It edits installed extension files; use at your own risk.
