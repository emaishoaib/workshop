# shell/

`init.zsh` is the single entry point sourced by `~/.zshrc`. It loads fzf, git functions, shell aliases, and (if present) `work_aliases.zsh` — everything in the repo that should be available in every shell session.

General aliases in `aliases.zsh`:

| Alias | Description |
|-------|-------------|
| `czsh` | Open `~/.zshrc` in VS Code |
| `rzsh` | Reload `~/.zshrc` |
| `mergeinv` | Merge paired invoice PDFs in the current directory (see [`scripts/`](../scripts/README.md)) |

`prompt.zsh` sets a green `PROMPT` (`user@host cwd %`) using zsh's portable `%F{color}` escapes, so it renders correctly in any terminal emulator without needing terminal-specific config.

## `work_aliases.zsh`

Work-project specific functions. Deliberately **not version controlled** (gitignored) since it's tied to a specific employer's tooling/repos — `init.zsh` sources it only if the file exists, so a fresh clone works fine without it.
