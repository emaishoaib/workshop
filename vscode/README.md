# vscode/

VS Code user settings, kept here so they're version-controlled and consistent across machines. Both files are symlinked into the VS Code user config directory so any changes are tracked in git.

This is handled automatically by `setup.sh`, but to wire it up manually:

```bash
ln -sf ~/Documents_Public/repos/workshop/vscode/settings.json \
  ~/Library/Application\ Support/Code/User/settings.json

ln -sf ~/Documents_Public/repos/workshop/vscode/keybindings.json \
  ~/Library/Application\ Support/Code/User/keybindings.json
```

## `vscode/extensions.txt`

A list of installed marketplace extensions, one ID per line. Maintained automatically by the `workshop-sync` extension — any install or uninstall updates this file immediately. Commit the change to keep the repo current.

`setup.sh` reads this file on a new machine and installs everything via `code --install-extension`.

## `vscode/extensions/workshop-sync/`

A custom VS Code extension that keeps `vscode/extensions.txt` in sync automatically. Writes the full list of non-built-in extensions on startup and on every install/uninstall.

To build and install:

```bash
cd vscode/extensions/workshop-sync
npm install
npm run compile
npx vsce package
code --uninstall-extension emaishoaib.workshop-sync 2>/dev/null; true
code --install-extension "$(ls workshop-sync-*.vsix | tail -1)"
```

Config:

| Setting | Default | Description |
|---------|---------|-------------|
| `workshopSync.repoPath` | `~/Documents_Public/repos/workshop` | Path to the workshop repo |

## `vscode/extensions/python-codelens/`

A custom VS Code extension that shows reference counts inline above Python classes and methods — the equivalent of PyCharm's "N usages" indicator. Pylance doesn't support this natively, so this fills the gap.

Built with the VS Code `CodeLensProvider` API: scans for `class` and `def` lines, then resolves counts lazily via Pylance's reference provider. Results are cached per symbol and invalidated on save.

To build and install:

```bash
cd vscode/extensions/python-codelens
npm install
npm run compile
npx vsce package
code --uninstall-extension emaishoaib.python-codelens 2>/dev/null; true
code --install-extension "$(ls python-codelens-*.vsix | tail -1)"
```

Config options (in `vscode/settings.json`):

| Setting | Default | Description |
|---------|---------|-------------|
| `pythonCodelens.enabled` | `true` | Toggle the extension on/off |
| `pythonCodelens.showZeroReferences` | `false` | Show lens even when count is 0 |

## Markdown behaviour

`formatOnSave` and `trimTrailingWhitespace` are both disabled for Markdown via a `[markdown]` language override in `settings.json`. This prevents Prettier (or any active Markdown formatter) from reflowing content on every `⌘S`, and preserves intentional trailing spaces (which are valid line-break syntax in Markdown).
