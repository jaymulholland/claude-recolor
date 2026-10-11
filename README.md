<div align="center">

# Recolor for Claude Code

**Replace Claude Code's orange with any color you want within Visual Studio Code.**

<img src="https://github.com/user-attachments/assets/3536968c-f991-4d00-bac1-a6152376cf47" width="428" alt="The Claude Code panel in VS Code with its logo, mascot and tab icons cycling through an animated rainbow gradient">

<sub>Shown here in animated rainbow mode.</sub>

</div>

---

The Claude Code VS Code extension has no accent-colour setting. **claude-recolor** is a recipe your Claude agent follows: it helps you pick a colour, patches the extension, and re-applies it after every update.

> [!NOTE]
> **For devs:** The extension's CSS, JS and SVGs are already plain text (just minified) — this is a series of regex find-and-replace passes swapping hex colour values in those files. See the script in [`CLAUDE-CODE-RECOLOR.md`](CLAUDE-CODE-RECOLOR.md) for the exact substitutions.

## Features

- 🎨 **Any colour.** Describe it ("dusty teal"), pick a named preset, use VS Code's colour picker, or type a hex.
- 🌈 **Animated gradients.** A sliding rainbow, or a gradient through colours you choose.
- 🔁 **Survives updates.** Re-applies itself when the extension updates.
- ↩️ **Reversible.** Originals are backed up, and the recipe explains how to restore them.
- ⚡ **`/recolor` command.** Change colour again later without re-running the whole recipe.

## Use it

1. Save [`CLAUDE-CODE-RECOLOR.md`](CLAUDE-CODE-RECOLOR.md) somewhere and open Claude Code in that folder.
2. Say:
   ```
   follow CLAUDE-CODE-RECOLOR.md
   ```
3. Pick a colour.
4. Run **Developer: Reload Window** (<kbd>Ctrl</kbd>/<kbd>Cmd</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd>), then quit VS Code completely and reopen it. Tab icons are cached for as long as VS Code's background process keeps running, so a full restart is what actually clears them — reload alone gets you most of the way there, the restart finishes the job. Your Claude conversations pick back up right where you left off.

## `/recolor`: changing colour later

Once the recipe's installed, you don't need to re-run it to change colour — just ask Claude:

```
/recolor sky blue
/recolor rainbow
/recolor #5B9CF6
```

It works out tab icon / chat content / text field colours from how many you give it — no keyword needed:

| You type | What happens |
| --- | --- |
| `/recolor blue` | One colour for the whole panel. |
| `/recolor rainbow blue` | First colour (or "rainbow") → tab icon + chat content together, second → text field. |
| `/recolor rainbow rainbow blue` | Three colours, in order: tab icon, chat content, text field. |
| `/recolor navy, dusty grey, reddish purple` | Commas disambiguate when colour names are themselves multi-word. |

It only changes colour on an existing install — run the full recipe first if you haven't. For anything beyond a plain colour or the rainbow (patterns, glows, permission-mode colours, renaming Claude), it hands off to the full recipe rather than guessing.

**Installing it:** already in this repo at [`.claude/commands/recolor.md`](.claude/commands/recolor.md), so it works immediately in a clone of claude-recolor. Copy it to `~/.claude/commands/recolor.md` to use `/recolor` in *any* project — custom commands load at session start, so restart Claude Code after copying it.

## Compatibility

| Editor | Linux | macOS | Windows |
| --- | :---: | :---: | :---: |
| VS Code, VS Code Insiders, Cursor, Windsurf | ✅ | ✅ | via Git Bash or WSL |

## Disclaimer

> [!WARNING]
> Unofficial, not affiliated with Anthropic. It edits installed extension files; use at your own risk.
