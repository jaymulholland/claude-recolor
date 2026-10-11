<div align="center">

# claude-recolor

**Replace Claude Code's orange with any colour you want.**

<img src="assets/demo.gif" width="428" alt="The Claude Code panel in VS Code with its logo, mascot and tab icons cycling through an animated rainbow gradient">

<sub>Shown here in animated rainbow mode.</sub>

</div>

---

The Claude Code VS Code extension has no accent-colour setting. **claude-recolor** is a recipe your Claude agent follows: it helps you pick a colour, patches the extension, and re-applies it after every update.

## Features

- 🎨 **Any colour.** Describe it ("dusty teal"), pick a named preset, use VS Code's colour picker, or type a hex.
- 🌈 **Animated gradients.** A sliding rainbow, or a gradient through colours you choose.
- 🔁 **Survives updates.** Re-applies itself when the extension updates.
- ↩️ **Reversible.** Originals are backed up, and the recipe explains how to restore them.

## Use it

1. Save [`CLAUDE-CODE-RECOLOR.md`](CLAUDE-CODE-RECOLOR.md) somewhere and open Claude Code in that folder.
2. Say:
   ```
   follow CLAUDE-CODE-RECOLOR.md
   ```
3. Pick a colour.
4. Run **Developer: Reload Window** (<kbd>Ctrl</kbd>/<kbd>Cmd</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd>).

> [!TIP]
> If the Claude icons on editor tabs keep the old colour, quit VS Code completely and reopen it.

## Compatibility

| Editor | Linux | macOS | Windows |
| --- | :---: | :---: | :---: |
| VS Code, VS Code Insiders, Cursor, Windsurf | ✅ | ✅ | via Git Bash or WSL |

## Disclaimer

> [!WARNING]
> Unofficial, not affiliated with Anthropic. It edits installed extension files; use at your own risk.
