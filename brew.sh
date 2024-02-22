###########################
# My basic install script #
###########################

###########################
# Update brew
###########################

brew update && brew upgrade
brew tap homebrew/cask-versions
brew tap isen-ng/dotnet-sdk-versions

###########################
# Brew packages
###########################

# Databases
brew install sqlite

# Tools
brew install git
brew install node
brew install neofetch
brew install ncdu
brew install tmux
brew install smartmontools

###########################
# Brew casks
###########################

brew install --cask google-chrome
brew install --cask google-drive
brew install --cask spotify
brew install --cask coconutbattery

brew install --cask temurin17
brew install --cask dotnet-sdk8-0-100 # LTS
brew install --cask visual-studio-code
brew install --cask git-credential-manager

###########################
# Brew cleanup
###########################

brew cleanup
