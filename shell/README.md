# shell/

`init.zsh` is the single entry point sourced by `~/.zshrc`. It loads fzf, git functions, shell aliases, and (if present) `local_aliases.zsh` — everything in the repo that should be available in every shell session.

General aliases in `aliases.zsh`:

| Alias | Description |
|-------|-------------|
| `czsh` | Open `~/.zshrc` in VS Code |
| `rzsh` | Reload `~/.zshrc` |

`prompt.zsh` sets a green `PROMPT` (`user@host cwd %`) using zsh's portable `%F{color}` escapes, so it renders correctly in any terminal emulator without needing terminal-specific config.

## `local_aliases.zsh`

Machine-specific functions. Deliberately **not version controlled** (gitignored) since it's tied to private tooling — `init.zsh` sources it only if the file exists, so a fresh clone works fine without it.
