#!/usr/bin/env bash
# Exports Cosmic Serpent for Linux and Windows and packages release archives in build/.
set -euo pipefail
cd "$(dirname "$0")"

GODOT="${GODOT:-godot}"
NAME=CosmicSerpent
rm -rf build
mkdir -p build/linux build/windows

"$GODOT" --headless --path . --export-release "Linux" "build/linux/$NAME.x86_64"
"$GODOT" --headless --path . --export-release "Windows" "build/windows/$NAME.exe"

# Linux: executable, icon, launcher-entry helper, readme, font licence.
LINUX_DIR="build/$NAME-linux-x86_64"
mkdir -p "$LINUX_DIR"
cp "build/linux/$NAME.x86_64" icon.svg README.md "$LINUX_DIR/"
cp assets/fonts/OFL.txt "$LINUX_DIR/Orbitron-OFL.txt"
cat > "$LINUX_DIR/install-desktop-entry.sh" <<'EOF'
#!/usr/bin/env bash
# Adds Cosmic Serpent to the application launcher, pointing at this folder.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/cosmic-serpent.desktop <<ENTRY
[Desktop Entry]
Type=Application
Name=Cosmic Serpent
Comment=A space snake game with power-ups
Exec="$DIR/CosmicSerpent.x86_64"
Path=$DIR
Icon=$DIR/icon.svg
Terminal=false
Categories=Game;ArcadeGame;
ENTRY
echo "Added Cosmic Serpent to your application launcher."
EOF
chmod +x "$LINUX_DIR/$NAME.x86_64" "$LINUX_DIR/install-desktop-entry.sh"
tar -C build -czf "build/$NAME-linux-x86_64.tar.gz" "$NAME-linux-x86_64"

# Windows: executable, readme (CRLF line endings for Notepad), font licence.
WIN_DIR="build/$NAME-windows-x86_64"
mkdir -p "$WIN_DIR"
cp "build/windows/$NAME.exe" "$WIN_DIR/"
sed 's/$/\r/' README.md > "$WIN_DIR/README.txt"
sed 's/$/\r/' assets/fonts/OFL.txt > "$WIN_DIR/Orbitron-OFL.txt"
(cd build && rm -f "$NAME-windows-x86_64.zip" && zip -qr "$NAME-windows-x86_64.zip" "$NAME-windows-x86_64")

ls -lh build/*.tar.gz build/*.zip
