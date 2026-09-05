# ai/

Claude Code configuration shared across machines via `setup.sh`.

- **`CLAUDE.md`** — global instructions, symlinked to `~/.claude/CLAUDE.md`.
- **`settings.json`** — permission allowlist, merged into `~/.claude/settings.json`
  (union of `allow` entries, not an overwrite — see `step_claude_permissions`).
- **`skills/`** — skills available in every Claude Code session.
- **[claude-video-vision](https://github.com/jordanrendric/claude-video-vision) MCP server** —
  used by the `video-archive` skill. `setup.sh` (`step_video_vision_mcp`)
  pins a specific reviewed npm release (see `VIDEO_VISION_VERSION` near the
  top of that step) and extracts it to `~/.claude-video-vision/vendor/<version>/`
  — outside this repo, not version controlled — then registers
  `~/.claude.json`'s `claude-video-vision` MCP entry to run that local copy
  directly via `node`, not `npx`. Deliberate: once set up, running it never
  needs npm/network access again, and it never silently picks up a new
  release — bumping the pinned version is a one-line edit to `setup.sh`,
  made only after reviewing what changed upstream.
- **`local.env`** — machine-specific secrets sourced by `shell/init.zsh`
  (e.g. `GEMINI_API_KEY`). **Not version controlled** — see `.gitignore`.
  Create it yourself; nothing here fails loudly if it's missing, individual
  tools that need a given variable will just fail with their own error when
  they reach for it.
