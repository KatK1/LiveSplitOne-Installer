#!/usr/bin/env sh

# POSIX-compliant script to download and install LiveSplit One
# shoutouts to katkiai

# some app info
APP_NAME_SHORT="LiveSplitOne"
APP_NAME="LiveSplit One"
APP_DISPLAY_NAME="LiveSplit One"
APP_VERSION="1.0"
BUNDLE_ID="com.LiveSplit.LiveSplitOne"

# make sure don't accidentally leave any temp files behind
trap 'rm -f /tmp/$APP_NAME.* /tmp/icons.iconset 2>/dev/null' EXIT

# detect if running interactively, or through curl
if ! [ -t 0 ]; then
    # not running interactively
    echo "Bootstrapping installer..."
    tmpfile=$(mktemp /tmp/installer.XXXXXX)
    curl -s -o "$tmpfile" https://katk1.dev/lso || {
        echo "Download failed, try installing script and running manually from https://github.com/KatK1/LiveSplitOne-Installer"
        rm -f "$tmpfile"
        exit 1
    }

    chmod +x "$tmpfile"
    echo  # newline
    exec "$tmpfile" "$@" < /dev/tty # run script again, interactively
    exit
fi

# if reached here, running interactively

# platform-specific download link
LINUX_URL="https://github.com/LiveSplit/LiveSplitOne/releases/download/latest/LiveSplitOne-x86_64-linux.tar.gz"
MAC_URL="https://github.com/LiveSplit/LiveSplitOne/releases/download/latest/LiveSplitOne-arm64-macos.tar.gz"
IMAGE_URL="https://raw.githubusercontent.com/LiveSplit/LiveSplit/refs/heads/master/res/Icon.png"

move_to_applications() {
    TARGET="/Applications/$APP_DIR"
    
    # check if already exists
    if [ -d "$TARGET" ]; then
        echo  # newline
        echo "Warning: $APP_NAME already exists in Applications folder"
        echo "Choose an option:"
        echo "1) Replace existing version"
        echo "2) Don't install to Applications"
        echo "3) Cancel installation"
        echo  # newline
        
        while true; do
            read -p "Enter your choice [1-3]: " choice  # -n 1 only reads a single input
            case $choice in
                1)  # replace
                    echo "Removing existing version..."
                    rm -rf "$TARGET"
                    mv "$APP_DIR" "/Applications/"
                    echo "Successfully replaced existing version"
                    break
                    ;;
                2)  # don't move move
                    echo "Leaving $APP_NAME in current directory"
                    break
                    ;;
                3)  # cancel
                    echo "Installation cancelled"
                    if [ "$APP_DIR" != "/" ]; then
                        if [ "$APP_DIR" != "$HOME" ]; then
                            rm -rf "$APP_DIR"
                        fi
                    fi
                    exit 0
                    ;;
                *)
                    echo "Invalid option, try again"
                    ;;
            esac
        done
    else
        # no conflict, procede normally
        mv "$APP_DIR" "/Applications/"
        echo "Successfully installed to Applications"
    fi
}

detect_rosetta() {
    if [ "$ARCHITECTURE" = "amd64" ] && [ "$PLATFORM" = "MacOS" ]; then
        if [ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" = "1" ]; then
            ARCHITECTURE="arm64"  # Rosetta 2
        fi
    fi
}

detect_platform() {
    case "$(uname -s)" in 
        Linux*)  echo "Linux" ;;
        Darwin*) echo "MacOS" ;;
        *)       echo ""      ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "amd64" ;;
        arm64|aarch64) echo "arm64" ;;
        *)             echo ""      ;;
    esac
}

linux_install() {
    if [ "$ARCHITECTURE" != "amd64" ]; then
        echo "LiveSplit One only releases for Linux with x86_64 / amd64 processors."
        echo "Would you like to install anyway? [y/N]"

        while :; do
            read yn
            case $yn in
                [Yy]*)
                    break 
                    ;;
                *)
                    echo "Installation aborted."
                    exit
                    ;;
            esac
        done
    fi

    echo "Installing for Linux (amd64)..."

    BINARY_DIR="$HOME/.local/bin/$APP_NAME_SHORT"
    mkdir -p "$BINARY_DIR"

    echo "Downloading Files..."
    curl -L "$LINUX_URL" -o "/tmp/$APP_NAME.tar.gz" || {
        echo "Downloading executable failed."
        exit 1
    }

    curl -L "$IMAGE_URL" -o "/tmp/$APP_NAME.png" || {
        echo "Downloading icon failed."
        exit 1
    }

    echo "Extracting..."
    tar -xzf "/tmp/$APP_NAME.tar.gz" -C "$BINARY_DIR" || {
        echo "Extraction failed"
        exit 1
    }

    # desktop entry
    echo "Creating Desktop Entry..."
    DESKTOP_DIR="$HOME/.local/share/applications/$APP_NAME_SHORT"

    if [ -d "$DESKTOP_DIR/$APP_NAME.desktop" ]; then
        rm "$DESKTOP_DIR/$APP_NAME.desktop"
    fi

    mkdir -p "$DESKTOP_DIR"
    mv "/tmp/$APP_NAME.png" "$DESKTOP_DIR/icon.png"

    cat > "$DESKTOP_DIR/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Version=$APP_VERSION
Type=Application
Name=$APP_DISPLAY_NAME
Exec="$BINARY_DIR/$APP_NAME"
Icon="$DESKTOP_DIR/icon.png"
Terminal=false
Categories=Utility;
EOF

    chmod +x "$DESKTOP_DIR/$APP_NAME.desktop"
    chmod +x "$BINARY_DIR/$APP_NAME"

    echo "Installation complete!"
}

mac_install() {
    if ! command -v iconutil >/dev/null; then
        echo "Error: Xcode command-line tools are required."
        echo "Please run:"
        echo "    xcode-select --install"
        echo "before running this script."
        exit 1
    fi

    if ! command -v sips >/dev/null; then
        echo "Error: Xcode command-line tools are required."
        echo "Please run:"
        echo "    xcode-select --install"
        echo "before running this script."
        exit 1
    fi

    if [ "$ARCHITECTURE" != "arm64" ]; then
        echo "LiveSplit One version only supports Macs with Intel Silicon processors."
        echo "Would you like to install anyway? [y/N]"

        while :; do
            read yn
            case $yn in
                [Yy]*)
                    break 
                    ;;
                *)
                    echo "Installation aborted."
                    exit
                    ;;
            esac
        done
    fi

    echo "Installing on MacOS (Apple Silicon)..."

    APP_DIR="$APP_DISPLAY_NAME.app"
    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR/Contents/MacOS"
    mkdir -p "$APP_DIR/Contents/Resources"

    echo "Downloading Files..."
    curl -L "$MAC_URL" -o "/tmp/$APP_NAME.tar.gz" || {
        echo "Downloading executable failed."
        exit 1
    }

    curl -L "$IMAGE_URL" -o "/tmp/$APP_NAME.png" || {
        echo "Downloading icon failed."
        exit 1
    }

    echo "Extracting..."
    tar -xzf "/tmp/$APP_NAME.tar.gz" -C "$APP_DIR/Contents/MacOS" || {
        echo "Extraction failed"
        exit 1
    }

    echo "Creating icons..."
    mkdir -p "/tmp/icons.iconset"
    rm -rf "/tmp/icons.iconset/*"
    sips -z 16 16 "/tmp/$APP_NAME.png" --out "/tmp/icons.iconset/icon_16x16.png"

    sips -z 32 32 "/tmp/$APP_NAME.png" --out "/tmp/icons.iconset/icon_16x16@2x.png"
    sips -z 32 32 "/tmp/$APP_NAME.png" --out "/tmp/icons.iconset/icon_32x32.png"

    sips -z 64 64 "/tmp/$APP_NAME.png" --out "/tmp/icons.iconset/icon_64x64.png"

    sips -z 128 128 "/tmp/$APP_NAME.png" --out "/tmp/icons.iconset/icon_128x128.png"

    sips -z 256 256 "/tmp/$APP_NAME.png" --out "/tmp/icons.iconset/icon_128x128@2x.png"
    sips -z 256 256 "/tmp/$APP_NAME.png" --out "/tmp/icons.iconset/icon_256x256.png"
    
    sips -z 512 512 "/tmp/$APP_NAME.png" --out "/tmp/icons.iconset/icon_256x256@2x.png"
    sips -z 512 512 "/tmp/$APP_NAME.png" --out "/tmp/icons.iconset/icon_512x512.png"

    sips -z 1024 1024 "/tmp/$APP_NAME.png" --out "/tmp/icons.iconset/icon_512x512@2x.png"

    iconutil -c icns "/tmp/icons.iconset" -o "$APP_DIR/Contents/Resources/AppIcon.icns"

    cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_DISPLAY_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>$APP_VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
EOF

    chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

    # try to move to applications folder
    echo "Moving to Applications folder..."
    if [ -d "/Applications" ]; then
        move_to_applications
    else
        echo ".app created at current directory, couldn't move to /Applications or $HOME/Applications"
        echo "to install, manually move $APP_DIR to one of those two locations."
    fi
}

PLATFORM=$(detect_platform)
ARCHITECTURE=$(detect_arch)

echo "Detected platform: $PLATFORM"
echo "Detected architecture: $ARCHITECTURE"

case "$PLATFORM" in 
    Linux)
        linux_install
        ;;
    MacOS)
        mac_install
        ;;
    *)
        echo "Your platform isn't supported by this script! Sorry!"
        exit 1
        ;;
esac

exit 0
