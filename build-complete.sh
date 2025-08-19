#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}🔧 Building Complete OpenCode Binary${NC}"
echo "================================================"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v go &> /dev/null; then
    echo -e "${RED}❌ Go is not installed. Please install Go first.${NC}"
    exit 1
fi

if ! command -v bun &> /dev/null; then
    echo -e "${RED}❌ Bun is not installed. Please install Bun first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Platform detection
PLATFORM="linux"
ARCH="x64"

case "$(uname -s)" in
    Darwin) PLATFORM="darwin" ;;
    Linux) PLATFORM="linux" ;;
    MINGW*|CYGWIN*|MSYS*) PLATFORM="win32" ;;
    *) PLATFORM="linux" ;;
esac

case "$(uname -m)" in
    x86_64|amd64) ARCH="x64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l) ARCH="arm" ;;
    *) ARCH="x64" ;;
esac

TARGET_NAME="opencode-${PLATFORM}-${ARCH}"
echo -e "${BLUE}📦 Building for: ${TARGET_NAME}${NC}"

# Create dist directory
echo -e "${YELLOW}Creating distribution directory...${NC}"
mkdir -p "dist/${TARGET_NAME}/bin"

# Step 1: Build Go TUI component
echo -e "${YELLOW}🔨 Building Go TUI component...${NC}"
cd packages/tui

# Set Go build flags based on platform
GOOS="$PLATFORM"
GOARCH=""
case "$ARCH" in
    x64) GOARCH="amd64" ;;
    arm64) GOARCH="arm64" ;;
    arm) GOARCH="arm" ;;
    *) GOARCH="amd64" ;;
esac

# Adjust platform name for GOOS
case "$PLATFORM" in
    win32) GOOS="windows" ;;
esac

TUI_BINARY="dist/${TARGET_NAME}/bin/tui"
if [ "$PLATFORM" = "win32" ]; then
    TUI_BINARY="${TUI_BINARY}.exe"
fi

echo -e "${BLUE}  Building TUI: CGO_ENABLED=0 GOOS=${GOOS} GOARCH=${GOARCH}${NC}"
CGO_ENABLED=0 GOOS="$GOOS" GOARCH="$GOARCH" go build \
    -ldflags="-s -w" \
    -o "../../$TUI_BINARY" \
    ./cmd/opencode/main.go

# Check if TUI binary was built successfully (need to go back to script root to check)
cd "$SCRIPT_DIR"
if [ ! -f "$TUI_BINARY" ]; then
    echo -e "${RED}❌ Failed to build TUI component${NC}"
    exit 1
fi

echo -e "${GREEN}✅ TUI component built successfully${NC}"

# Step 2: Build main opencode binary with embedded TUI
cd "$SCRIPT_DIR"
echo -e "${YELLOW}🔨 Building main opencode binary with embedded TUI...${NC}"

MAIN_BINARY="dist/${TARGET_NAME}/bin/opencode"
if [ "$PLATFORM" = "win32" ]; then
    MAIN_BINARY="${MAIN_BINARY}.exe"
    TARGET_BUN="bun-windows-x64"
else
    TARGET_BUN="bun-${PLATFORM}-${ARCH}"
fi

echo -e "${BLUE}  Building opencode: bun build --compile --target=${TARGET_BUN}${NC}"
# Use the --define approach with absolute path (like the working manual build)
TUI_BINARY_ABS="$(pwd)/$TUI_BINARY"
bun build \
    --define OPENCODE_TUI_PATH="'$TUI_BINARY_ABS'" \
    --compile \
    --target="$TARGET_BUN" \
    --outfile="$MAIN_BINARY" \
    ./packages/opencode/src/index.ts

if [ ! -f "$MAIN_BINARY" ]; then
    echo -e "${RED}❌ Failed to build main opencode binary${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Main opencode binary built successfully${NC}"

# Step 3: Create final binary
FINAL_BINARY="opencode-complete"
if [ "$PLATFORM" = "win32" ]; then
    FINAL_BINARY="${FINAL_BINARY}.exe"
fi

echo -e "${YELLOW}📦 Creating final binary...${NC}"
cp "$MAIN_BINARY" "$FINAL_BINARY"
chmod +x "$FINAL_BINARY"

# Get binary size
BINARY_SIZE=$(du -h "$FINAL_BINARY" | cut -f1)

echo ""
echo -e "${GREEN}🎉 Build completed successfully!${NC}"
echo "================================================"
echo -e "${BLUE}📍 Binary location:${NC} ./$FINAL_BINARY"
echo -e "${BLUE}📏 Binary size:${NC} $BINARY_SIZE"
echo -e "${BLUE}🚀 Platform:${NC} $TARGET_NAME"
echo ""
echo -e "${YELLOW}Usage:${NC}"
echo "  ./$FINAL_BINARY --help"
echo "  ./$FINAL_BINARY --version"
echo ""
echo -e "${GREEN}✨ The binary can now be used from any directory!${NC}"

# Optional: Test the binary
echo -e "${YELLOW}🧪 Quick test...${NC}"
if "./$FINAL_BINARY" --version > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Binary test passed${NC}"
else
    echo -e "${RED}⚠️  Binary test failed - but binary was created${NC}"
fi

echo ""
echo -e "${BLUE}💡 Tip: You can copy this binary to your PATH:${NC}"
echo "  sudo cp $FINAL_BINARY /usr/local/bin/opencode"