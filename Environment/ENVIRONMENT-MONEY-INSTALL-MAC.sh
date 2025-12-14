# Install HomeBrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install command-line tools
brew install node
brew install nvm
brew install git
brew install azure-cli

# Install GUI applications (using --cask syntax as 'brew cask' is deprecated)
brew install --cask google-chrome
brew install --cask microsoft-office
brew install --cask microsoft-teams
brew install --cask microsoft-azure-storage-explorer
brew install --cask microsoft-edge
brew install --cask iina
brew install --cask spotify
brew install --cask firefox-developer-edition
brew install --cask snagit
brew install --cask fork
brew install --cask tunnelblick
brew install --cask visual-studio
brew install --cask visual-studio-code
brew install --cask azure-data-studio
brew install --cask filezilla
brew install --cask docker
brew install --cask adobe-acrobat-reader
brew install --cask teamviewer
brew install --cask obs
brew install --cask scroll-reverser
brew install --cask onedrive
brew install --cask the-unarchiver
brew install --cask telegram
brew install --cask xmind
brew install --cask smcfancontrol
brew install --cask rider

# Install .NET SDK (current LTS and STS versions)
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 9.0
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 8.0
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 7.0
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 6.0
