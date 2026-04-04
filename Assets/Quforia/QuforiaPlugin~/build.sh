#!/bin/bash

# Quforia Plugin Build Script
# Builds libquforia.so and copies it to Unity's Plugins folder

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Building Quforia Plugin${NC}"
echo -e "${GREEN}=====================================${NC}"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
UNITY_PLUGINS_DIR="$SCRIPT_DIR/../../Plugins/Android/libs/arm64-v8a"

# Auto-detect NDK path (macOS / Windows / custom)
if [ -n "$ANDROID_NDK_ROOT" ]; then
    NDK_PATH="$ANDROID_NDK_ROOT"
elif [ -d "/Applications/Unity/Hub/Editor/6000.0.62f1/PlaybackEngines/AndroidPlayer/NDK" ]; then
    NDK_PATH="/Applications/Unity/Hub/Editor/6000.0.62f1/PlaybackEngines/AndroidPlayer/NDK"
elif [ -d "$PROGRAMFILES/Unity/Hub/Editor/6000.0.62f1/Editor/Data/PlaybackEngines/AndroidPlayer/NDK" ]; then
    NDK_PATH="$PROGRAMFILES/Unity/Hub/Editor/6000.0.62f1/Editor/Data/PlaybackEngines/AndroidPlayer/NDK"
elif [ -d "C:/Program Files/Unity/Hub/Editor/6000.0.62f1/Editor/Data/PlaybackEngines/AndroidPlayer/NDK" ]; then
    NDK_PATH="C:/Program Files/Unity/Hub/Editor/6000.0.62f1/Editor/Data/PlaybackEngines/AndroidPlayer/NDK"
else
    echo -e "${RED}ERROR: NDK not found. Set ANDROID_NDK_ROOT environment variable.${NC}"
    echo -e "${YELLOW}Example: export ANDROID_NDK_ROOT=\"C:/Program Files/Unity/Hub/Editor/6000.0.62f1/Editor/Data/PlaybackEngines/AndroidPlayer/NDK\"${NC}"
    exit 1
fi

# Check NDK exists
if [ ! -d "$NDK_PATH" ]; then
    echo -e "${RED}ERROR: NDK not found at $NDK_PATH${NC}"
    exit 1
fi

echo -e "${YELLOW}Using NDK: $NDK_PATH${NC}"

# Auto-detect CMake from Unity's Android SDK (fallback if cmake not in PATH)
if ! command -v cmake &> /dev/null; then
    ANDROID_SDK_DIR="$(dirname "$NDK_PATH")/SDK"
    CMAKE_BIN=$(find "$ANDROID_SDK_DIR/cmake" -name "cmake.exe" -type f 2>/dev/null | head -1)
    if [ -z "$CMAKE_BIN" ]; then
        CMAKE_BIN=$(find "$ANDROID_SDK_DIR/cmake" -name "cmake" -type f 2>/dev/null | head -1)
    fi
    if [ -n "$CMAKE_BIN" ]; then
        export PATH="$(dirname "$CMAKE_BIN"):$PATH"
        echo -e "${YELLOW}Using CMake: $CMAKE_BIN${NC}"
    else
        echo -e "${RED}ERROR: cmake not found. Install CMake or ensure Unity's Android SDK includes it.${NC}"
        exit 1
    fi
fi

# Clean previous build
if [ -d "$BUILD_DIR" ]; then
    echo -e "${YELLOW}Cleaning previous build...${NC}"
    rm -rf "$BUILD_DIR"
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure CMake
echo -e "${YELLOW}Configuring CMake for arm64-v8a...${NC}"
# Locate ninja alongside cmake
ANDROID_SDK_DIR="$(dirname "$NDK_PATH")/SDK"
NINJA_BIN=$(find "$ANDROID_SDK_DIR/cmake" -name "ninja.exe" -type f 2>/dev/null | head -1)
if [ -z "$NINJA_BIN" ]; then
    NINJA_BIN=$(find "$ANDROID_SDK_DIR/cmake" -name "ninja" -type f 2>/dev/null | head -1)
fi
if [ -z "$NINJA_BIN" ]; then
    echo -e "${RED}ERROR: ninja not found in Unity's CMake directory${NC}"
    exit 1
fi
echo -e "${YELLOW}Using Ninja: $NINJA_BIN${NC}"

cmake -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-29 \
  -DCMAKE_BUILD_TYPE=Release \
  -DANDROID_STL=c++_static \
  -DANDROID_USE_LEGACY_TOOLCHAIN_FILE=ON \
  -DCMAKE_MAKE_PROGRAM="$NINJA_BIN" \
  ..

# Build
echo -e "${YELLOW}Building libquforia.so...${NC}"
cmake --build . --config Release -j8

# Check if library was built
if [ ! -f "$BUILD_DIR/libquforia.so" ]; then
    echo -e "${RED}ERROR: libquforia.so not found after build${NC}"
    exit 1
fi

# Get library size
LIB_SIZE=$(du -h "$BUILD_DIR/libquforia.so" | awk '{print $1}')
echo -e "${GREEN}✓ libquforia.so built successfully ($LIB_SIZE)${NC}"

# Create Unity plugins directory if it doesn't exist
mkdir -p "$UNITY_PLUGINS_DIR"

# Copy to Unity
echo -e "${YELLOW}Copying to Unity Plugins...${NC}"
cp "$BUILD_DIR/libquforia.so" "$UNITY_PLUGINS_DIR/libquforia.so"

echo -e "${GREEN}✓ Copied to: $UNITY_PLUGINS_DIR/libquforia.so${NC}"

# Verify
if [ -f "$UNITY_PLUGINS_DIR/libquforia.so" ]; then
    echo -e "${GREEN}=====================================${NC}"
    echo -e "${GREEN}Build Complete!${NC}"
    echo -e "${GREEN}=====================================${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Refresh Unity (Assets → Refresh)"
    echo "2. Build and deploy your APK"
    echo ""
else
    echo -e "${RED}ERROR: Failed to copy library${NC}"
    exit 1
fi
