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

# --- Done ---
echo ""
echo "-- done --------------------------------------"
echo "Reload your shell: source ~/.zshrc"
