#!/bin/sh

# Exit immediately if any command exits with non-zero exit status.
set -e

if ! command -v unzip >/dev/null; then
	echo 'err: `unzip` is required to install Rush. Please install it and try again.'
	exit 1
fi

if [[ -v RUSH_HOME]]; then
  rushHome="$RUSH_HOME"
else
  if ! -v rush >/dev/null; then
    rushHome="$HOME/.rush"
  else
    rushHome="$(dirname $(dirname $(which rush)))"
  fi
fi

if [ "$OS" = "Windows_NT" ]; then
  target="x86_64-windows"
else
  case $(uname -sm) in
  "Darwin x86_64") target="x86_64-apple-darwin" ;;
  "Darwin arm64") target="arm64-apple-darwin" ;;
  *) target="x86_64-linux" ;;
  esac
fi

zipUrl="https://github.com/shreyashsaitwal/rush-cli/releases/latest/download/rush-$target.zip"
curl --location --progress-bar -o "$rushHome/rush-$target.zip" "$zipUrl"

unzip -oq "$rushHome/rush-$target.zip" -d "$rushHome"/
rm "$rushHome/rush-$target.zip"

# Make the Rush binary executable on Unix systems. 
if [ ! "$OS" = "Windows_NT" ]; then
  chmod +x "$rushHome/bin/rush"
fi

echo
echo "Successfully downloaded the Rush CLI binary at $rushHome/bin/rush"

# Prompt user of they want to download dev dependencies now.
echo "Now, proceeding to download necessary Java libraries (approx size: 170 MB)."
read -p "Do you want to continue? (Y/n) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  if [ "$OS" = "Windows_NT" ]; then
    "./$rushHome/bin/rush.exe" deps sync --dev-deps --no-logo
  else
    "./$rushHome/bin/rush" deps sync --dev-deps --no-logo
  fi
fi

echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  echo "Success! Installed Rush at $rushHome/bin/rush"
else
  echo "Rush has been partially installed at $rushHome/bin/rush"
  echo 'Please run `rush deps sync --dev-deps` to download the necessary Java libraries.'
fi

case $SHELL in
  /bin/zsh) shell_profile=".zshrc" ;;
  *) shell_profile=".bash_profile" ;;
esac

echo
echo "Now, add the following to your \$HOME/$shell_profile (or similar):"
echo "export PATH=\"\$PATH:$rushHome/bin\""

echo
echo 'Run `rush --help` to get started.'