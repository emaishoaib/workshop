#!/bin/bash

WORKSHOP_DIR="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
GITCONFIG="$HOME/.gitconfig"

echo "-- workshop setup ----------------------------"

# --- Prerequisites ---
echo ""
echo "Checking prerequisites..."

if ! command -v brew &>/dev/null; then
  echo "  !! Homebrew not found -- install it first: https://brew.sh"
  exit 1
fi

if ! command -v fzf &>/dev/null; then
  echo "  Installing fzf..."
  brew install fzf && "$(brew --prefix)/opt/fzf/install" --all --no-bash --no-fish
else
  echo "  >> fzf"
fi

if ! command -v gh &>/dev/null; then
  echo "  Installing gh..."
  brew install gh
else
  echo "  >> gh"
fi

# --- zshrc ---
echo ""
echo "Configuring ~/.zshrc..."

SOURCE_LINE="source \"$WORKSHOP_DIR/shell/init.zsh\""

if grep -qF "$WORKSHOP_DIR/shell/init.zsh" "$ZSHRC" 2>/dev/null; then
  echo "  >> already sourced"
else
  echo "" >> "$ZSHRC"
  echo "# workshop" >> "$ZSHRC"
  echo "$SOURCE_LINE" >> "$ZSHRC"
  echo "  >> added source line to ~/.zshrc"
fi

# --- gitconfig ---
echo ""
echo "Configuring ~/.gitconfig..."

GITCONFIG_LINE="path = $WORKSHOP_DIR/git/aliases.gitconfig"

if grep -qF "$WORKSHOP_DIR/git/aliases.gitconfig" "$GITCONFIG" 2>/dev/null; then
  echo "  >> already included"
else
  echo "" >> "$GITCONFIG"
  echo "[include]" >> "$GITCONFIG"
  echo "    $GITCONFIG_LINE" >> "$GITCONFIG"
  echo "  >> added include to ~/.gitconfig"
fi

# --- Claude ---
echo ""
echo "Configuring ~/.claude/CLAUDE.md..."

mkdir -p "$HOME/.claude"

if [ -L "$HOME/.claude/CLAUDE.md" ] && [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$WORKSHOP_DIR/ai/CLAUDE.md" ]; then
  echo "  >> already symlinked"
else
  ln -sf "$WORKSHOP_DIR/ai/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  echo "  >> symlinked to $WORKSHOP_DIR/ai/CLAUDE.md"
fi

# --- VS Code ---
echo ""
echo "Configuring VS Code user settings..."

VSCODE_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$VSCODE_DIR"

for file in settings.json keybindings.json; do
  target="$VSCODE_DIR/$file"
  source="$WORKSHOP_DIR/vscode/$file"
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    echo "  >> $file already symlinked"
  else
    ln -sf "$source" "$target"
    echo "  >> symlinked $file"
  fi
done

# --- Done ---
echo ""
echo "-- done --------------------------------------"
echo "Reload your shell: source ~/.zshrc"
