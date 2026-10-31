#!/bin/sh
# Install mvc by symlinking it into a bin dir (default ~/.local/bin).
# Usage: ./install.sh [BIN_DIR]     Uninstall: ./install.sh --uninstall [BIN_DIR]
set -e
here=$(cd "$(dirname "$0")" && pwd)
uninstall=0
if [ "$1" = "--uninstall" ]; then uninstall=1; shift; fi
bin=${1:-$HOME/.local/bin}
link=$bin/mvc

if [ "$uninstall" = 1 ]; then
  if [ -L "$link" ]; then rm "$link"; echo "removed $link"; else echo "nothing to remove at $link"; fi
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "install: python3 is required" >&2; exit 1; }
if [ -e "$link" ] && [ ! -L "$link" ]; then
  echo "install: $link exists and is not a symlink; refusing to overwrite" >&2
  exit 1
fi
chmod +x "$here/mvc"
mkdir -p "$bin"
ln -sf "$here/mvc" "$link"
echo "installed $link -> $here/mvc"
case ":$PATH:" in
  *":$bin:"*) ;;
  *) echo "note: $bin is not on your PATH; add it to your shell profile" ;;
esac
