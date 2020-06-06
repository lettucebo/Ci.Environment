# Install HomeBrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

# Install cask
brew tap homebrew/cask-cask

# Install software
brew install node
brew install nvm
brew install git
brew install azure-cli

# Install cask software
brew cask install google-chrome
brew cask install microsoft-office
brew cask install microsoft-teams
brew cask install microsoft-azure-storage-explorer
brew cask install microsoft-edge-beta
brew cask install iina
brew cask install spotify
brew cask install firefox-developer-edition
brew cask install snagit
brew cask install fork
brew cask install tunnelblick
brew cask install visual-studio
brew cask install visual-studio-code
brew cask install azure-data-studio   
brew cask install filezilla
brew cask install docker-edge
brew cask install adobe-acrobat-reader 
brew cask install teamviewer
brew cask install obs
brew cask install scroll-reverser
brew cask install onedrive
brew cask install the-unarchiver
brew cask install telegram
brew cask install xmind-zen
brew cask install smcfancontrol
brew cask install rider

# Install .NET Core SDK
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 3.1
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 3.0
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 2.2
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 2.1
