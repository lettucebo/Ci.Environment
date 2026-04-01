#!/bin/bash
set -e

# =========================
# macOS Environment Setup Script
# =========================

# Ask for sudo password upfront and keep sudo alive throughout the script
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo "=========================================="
echo "Starting macOS Environment Setup..."
echo "=========================================="

# Install Homebrew (if not already installed)
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "Homebrew already installed, updating..."
    brew update
fi

# ==================
# Xcode (Required for iOS / React Native builds)
# ==================
echo "Installing Xcode and related tools..."

# Install Xcode Command Line Tools
xcode-select --install 2>/dev/null || true

# Install Xcode from Mac App Store via mas
brew install mas
mas install 497799835  # Xcode

# Switch active developer directory to Xcode.app
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Accept Xcode license
sudo xcodebuild -license accept

# Install CocoaPods (React Native iOS dependency manager)
brew install cocoapods

# Install Watchman (React Native file watcher)
brew install watchman

# ==================
# CLI Tools
# ==================
echo "Installing CLI tools..."
brew install git
brew install gh
brew install nvm
brew install python
brew install azure-cli
brew install starship
brew install gpg

# GitHub Copilot CLI extension (requires gh auth login first)
gh extension install github/gh-copilot || echo "WARNING: gh-copilot install failed. Run 'gh auth login' first, then 'gh extension install github/gh-copilot'"

# ==================
# Node.js via nvm (LTS + Latest)
# ==================
echo "Setting up nvm and Node.js..."

# Ensure nvm directory exists
export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR"

# Load nvm (Homebrew installs nvm as a script, not a binary)
[ -s "$(brew --prefix nvm)/nvm.sh" ] && \. "$(brew --prefix nvm)/nvm.sh"

# Add nvm initialization to shell profile if not already present
NVM_INIT='export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix nvm)/nvm.sh" ] && \. "$(brew --prefix nvm)/nvm.sh"
[ -s "$(brew --prefix nvm)/etc/bash_completion.d/nvm" ] && \. "$(brew --prefix nvm)/etc/bash_completion.d/nvm"'

if ! grep -q 'NVM_DIR' ~/.zshrc 2>/dev/null; then
    echo "" >> ~/.zshrc
    echo "# nvm" >> ~/.zshrc
    echo "$NVM_INIT" >> ~/.zshrc
fi

# Install Node.js LTS and Latest
echo "Installing Node.js LTS..."
nvm install --lts
echo "Installing Node.js Latest..."
nvm install node

# Set LTS as default
nvm alias default lts/*
echo "Node.js LTS set as default."

# ==================
# Python setup
# ==================
echo "Setting up Python..."
# Install pipx for managing Python CLI tools in isolated environments
brew install pipx
pipx ensurepath

# Install uv (fast Python package manager, includes uvx)
brew install uv

# Add python -> python3 alias to PATH
if ! grep -q 'python@3' ~/.zshrc 2>/dev/null; then
    echo "" >> ~/.zshrc
    echo "# Python: make 'python' point to 'python3'" >> ~/.zshrc
    echo 'export PATH="$(brew --prefix python)/libexec/bin:$PATH"' >> ~/.zshrc
fi

# ==================
# GUI Applications (Casks)
# ==================
echo "Installing GUI applications..."
apps=(
    google-chrome
    microsoft-office
    microsoft-edge
    iina
    spotify
    visual-studio-code
    visual-studio-code@insiders
    scroll-reverser
    the-unarchiver
    1password
    claude
    fork
    openinterminal
)

for app in "${apps[@]}"; do
    brew install --cask "$app" || echo "WARNING: Failed to install $app, skipping..."
done

# ==================
# Fonts
# ==================
echo "Installing fonts..."
brew install --cask font-fira-code || true
brew install --cask font-hack-nerd-font || true
brew install --cask font-noto-sans-cjk-tc || true

# Install YaHei Consolas (not available via Homebrew, install from repo)
YAHEI_FONT_URL="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/YaHei%20Consolas.ttf"
YAHEI_FONT_FILE="$HOME/Library/Fonts/YaHei Consolas.ttf"
if [ ! -f "$YAHEI_FONT_FILE" ]; then
    echo "Installing YaHei Consolas font..."
    curl -fsSL "$YAHEI_FONT_URL" -o "$YAHEI_FONT_FILE"
fi

# ==================
# Git Configuration
# ==================
echo "Configuring Git..."
git config --global user.name "Money Yu"
git config --global user.email abc12207@gmail.com
git config --global user.signingkey 871B1DD4A0830BA9897A6AF37240ACACFF6EDB8D
git config --global commit.gpgsign true
git config --global gpg.program "$(which gpg)"
git config --global core.editor "code --wait"
# 設定 git status 若有中文不會顯示亂碼
git config --global core.quotepath false
echo "Git configured."

# ==================
# GPG Configuration
# ==================
echo "Configuring GPG agent..."

# Create gnupg directory if not exists
mkdir -p ~/.gnupg
chmod 700 ~/.gnupg

# Set GPG agent config (cache passphrase for 7 days)
GPG_AGENT_CONF="$HOME/.gnupg/gpg-agent.conf"
cat > "$GPG_AGENT_CONF" << 'EOF'
default-cache-ttl 604800
max-cache-ttl 604800
pinentry-program /usr/local/bin/pinentry-mac
EOF
chmod 600 "$GPG_AGENT_CONF"

# Set GPG to use UTF-8
GPG_CONF="$HOME/.gnupg/gpg.conf"
if ! grep -q 'no-tty' "$GPG_CONF" 2>/dev/null; then
    echo "no-tty" >> "$GPG_CONF"
fi

# Install pinentry-mac for GUI passphrase prompt
brew install pinentry-mac

# Restart gpg-agent to apply config
gpgconf --kill gpg-agent

# Add GPG_TTY to shell profile for terminal signing
if ! grep -q 'GPG_TTY' ~/.zshrc 2>/dev/null; then
    echo "" >> ~/.zshrc
    echo "# GPG" >> ~/.zshrc
    echo 'export GPG_TTY=$(tty)' >> ~/.zshrc
fi

echo "GPG configured."
echo "NOTE: Import your GPG private key with: gpg --import <your-private-key.asc>"

# ==================
# macOS System Preferences
# ==================
echo "Configuring macOS system preferences..."

# Remove "Recents" from Finder sidebar
brew install mysides || true
mysides remove "最近項目" 2>/dev/null || mysides remove "Recents" 2>/dev/null || true

# Show Bluetooth icon in menu bar
defaults write com.apple.controlcenter "NSStatusItem Visible Bluetooth" -bool true
open /System/Library/CoreServices/ControlCenter.app 2>/dev/null || true

# Prevent system sleep (system stays awake, display can still turn off)
sudo pmset -a disablesleep 1
sudo pmset -a sleep 0

# Allow display to turn off after 10 minutes (does not affect RustDesk remote access)
sudo pmset -a displaysleep 10

# Finder: sort folders first, then files, sorted by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder FXArrangeGroupViewBy -string "Name"
killall Finder 2>/dev/null || true

echo "=========================================="
echo "macOS Environment Setup Complete!"
echo "Please restart your terminal to apply all changes."
echo "=========================================="

