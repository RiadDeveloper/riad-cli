#!/bin/sh

# Exit immediately if any command exits with non-zero exit status.
set -e

if ! command -v unzip >/dev/null; then
	echo 'err: `unzip` is required to install Riad. Please install it and try again.'
	exit 1
fi

if [[ -v Riad_HOME]]; then
  RiadHome="$Riad_HOME"
else
  if ! -v Riad >/dev/null; then
    RiadHome="$HOME/.Riad"
  else
    RiadHome="$(dirname $(dirname $(which Riad)))"
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

zipUrl="https://github.com/shreyashsaitwal/Riad-cli/releases/latest/download/Riad-$target.zip"
curl --location --progress-bar -o "$RiadHome/Riad-$target.zip" "$zipUrl"

unzip -oq "$RiadHome/Riad-$target.zip" -d "$RiadHome"/
rm "$RiadHome/Riad-$target.zip"

# Make the Riad binary executable on Unix systems. 
if [ ! "$OS" = "Windows_NT" ]; then
  chmod +x "$RiadHome/bin/Riad"
fi

echo
echo "Successfully downloaded the Riad CLI binary at $RiadHome/bin/Riad"

# Prompt user of they want to download dev dependencies now.
echo "Now, proceeding to download necessary Java libraries (approx size: 170 MB)."
read -p "Do you want to continue? (Y/n) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  if [ "$OS" = "Windows_NT" ]; then
    "./$RiadHome/bin/Riad.exe" deps sync --dev-deps --no-logo
  else
    "./$RiadHome/bin/Riad" deps sync --dev-deps --no-logo
  fi
fi

echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  echo "Success! Installed Riad at $RiadHome/bin/Riad"
else
  echo "Riad has been partially installed at $RiadHome/bin/Riad"
  echo 'Please run `Riad deps sync --dev-deps` to download the necessary Java libraries.'
fi

case $SHELL in
  /bin/zsh) shell_profile=".zshrc" ;;
  *) shell_profile=".bash_profile" ;;
esac

echo
echo "Now, add the following to your \$HOME/$shell_profile (or similar):"
echo "export PATH=\"\$PATH:$RiadHome/bin\""

echo
echo 'Run `Riad --help` to get started.'
