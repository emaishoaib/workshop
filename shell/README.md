# shell/

`init.zsh` is the single entry point sourced by `~/.zshrc`. It loads fzf, git functions, shell aliases, the [`db/`](../db/README.md) DB tooling, and (if present) its gitignored employer-specific companion file — everything in the repo that should be available in every shell session.

General aliases in `aliases.zsh`:

| Alias | Description |
|-------|-------------|
| `czsh` | Open `~/.zshrc` in VS Code |
| `rzsh` | Reload `~/.zshrc` |
| `mergeinv` | Merge paired invoice PDFs in the current directory (see [`scripts/`](../scripts/README.md)) |

`prompt.zsh` sets a green `PROMPT` (`user@host cwd %`) using zsh's portable `%F{color}` escapes, so it renders correctly in any terminal emulator without needing terminal-specific config.
