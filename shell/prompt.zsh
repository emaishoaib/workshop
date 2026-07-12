# Custom prompt: user@host cwd %, colored green.
# %F{green} / %f are zsh's portable color escapes -- work in any terminal
# emulator (Terminal.app, iTerm2, Ghostty/cmux, etc.) without extra config.
PROMPT="%F{green}%n@%m %1~ %#%f "
