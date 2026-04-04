# QuforiaPlugin - Vuforia Driver Framework Native Plugin

A C++ native plugin (`libquforia.so`) that implements the Vuforia Driver Framework, enabling Meta Quest passthrough camera frames and device poses to be consumed by the Vuforia Engine for AR tracking.

## Architecture

```
[Unity C# Layer]
       |
       | P/Invoke (nativeFeedDevicePose / nativeFeedCameraFrame)
       |
[quforia_jni.cpp] ─── Unity ↔ Native Bridge
       |
[QuestVuforiaDriver] ─── Central Hub (frame/pose buffering)
       |
       ├── [QuestExternalCamera] ─── Frame delivery to Vuforia (30fps thread)
       |
       └── [QuestExternalTracker] ─── Pose delivery + coordinate transform
```

## Source Files

### `src/vuforia_driver.h / .cpp` - Core Driver

Main driver implementing `VuforiaDriver::Driver` interface. Manages thread-safe frame and pose buffering.

- **Frame queue**: Circular buffer, max 3 frames
- **Pose queue**: Circular buffer, max 90 poses (~3s at 30fps)
- **Thread safety**: `std::mutex` with RAII `lock_guard`
- **API version**: 7 (`VUFORIA_DRIVER_API_VERSION`)

Key entry points (C linkage, loaded by Vuforia Engine):
- `vuforiaDriver_init()` / `vuforiaDriver_deinit()` - Driver lifecycle
- `vuforiaDriver_getAPIVersion()` - Returns 7
- `vuforiaDriver_getLibraryVersion()` - Returns `"QuestVuforiaDriver 1.0.0"`

### `src/external_camera.h / .cpp` - Camera Frame Delivery

Implements `VuforiaDriver::ExternalCamera`. Spawns a background thread that polls for new frames and delivers them to Vuforia via `CameraCallback::onNewCameraFrame()`.

- **Supported mode**: 1280x960 @ 30fps, RGB888
- **Exposure/Focus**: Continuous auto only (passthrough camera controlled by Meta SDK)
- **Frame buffer**: Pre-allocated ~3.6MB (1280 x 960 x 3 bytes)

### `src/external_tracker.h / .cpp` - Pose Delivery & Coordinate Transform

Implements `VuforiaDriver::ExternalPositionalDeviceTracker`. Delivers 6DoF device poses synchronized with camera frames.

**Coordinate system transformation** (critical for correct tracking):

| Axis | OpenXR/Unity (input) | Vuforia CV (output) |
|------|---------------------|---------------------|
| X    | Right               | Right (unchanged)   |
| Y    | Up                  | Down (negated)      |
| Z    | Back (toward user)  | Forward (negated)   |

- Applies 180deg rotation around X-axis to flip Y and Z
- Quaternion transformed to 3x3 rotation matrix (row-major) for Vuforia
- **Pose delivered before frame** (Vuforia framework requirement)

### `src/quforia_jni.cpp` - Unity P/Invoke Bridge

Exports C functions callable from Unity C# via P/Invoke:

| Function | Purpose |
|----------|---------|
| `nativeSetCameraIntrinsics(float*, int)` | Set camera calibration (called once) |
| `nativeFeedDevicePose(float*, float*, long long)` | Feed position + quaternion + timestamp |
| `nativeFeedCameraFrame(byte*, int, int, float*, int, long long)` | Feed RGB888 pixels |
| `nativeIsDriverInitialized()` | Check driver readiness |

**Intrinsics array format** (14 floats):
`[width, height, fx, fy, cx, cy, d0, d1, d2, d3, d4, d5, d6, d7]`

### `include/VuforiaEngine/` - Vuforia Driver Framework Headers

Official Vuforia SDK headers defining the driver interface:
- `Driver/Driver.h` - Core interfaces (`ExternalCamera`, `ExternalPositionalDeviceTracker`, `Driver`)
- `Engine/DriverConfig.h` - Driver configuration structures
- `Core/Basic.h` - Vector/matrix types

## Build

### Prerequisites

- Android NDK (bundled with Unity 6000.0.61f1)
- CMake 3.22.1+
- Target: Android ARM64 (`arm64-v8a`), API level 29+

### Build & Deploy

```bash
./build.sh
```

This will:
1. Configure CMake with Android NDK toolchain
2. Build `libquforia.so` (C++17, Release mode)
3. Copy to `../Assets/Plugins/Android/libs/arm64-v8a/`

> **Note**: The NDK path in `build.sh` defaults to macOS Unity Hub path. Adjust `NDK_PATH` for other platforms.

### Manual Build

```bash
mkdir build && cd build
cmake \
  -DCMAKE_TOOLCHAIN_FILE="<NDK_PATH>/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-29 \
  -DCMAKE_BUILD_TYPE=Release \
  -DANDROID_STL=c++_static \
  ..
cmake --build . --config Release -j8
```

## Unity C# Integration (Counterpart)

The C# side lives in `Assets/Vuforia_ForQuest/Scripts/`:

| Script | Execution Order | Role |
|--------|----------------|------|
| `QuestVuforiaDriverInit.cs` | -100 | Initialize Vuforia with custom driver |
| `MetaCameraProvider.cs` | -50 | Capture Quest camera frames, feed to native |
| `QuestVuforiaBridge.cs` | - | P/Invoke wrapper for native functions |
| `VuforiaKeyLoader.cs` | - | Load license key from StreamingAssets |

### Data Flow (per frame)

1. `MetaCameraProvider` captures `Color32[]` from `PassthroughCameraAccess`
2. Converts to RGB888 `byte[]`, optionally flips vertically
3. Gets device pose and timestamp (nanoseconds)
4. Calls `QuestVuforiaBridge.FeedDevicePose()` (pose first!)
5. Calls `QuestVuforiaBridge.FeedCameraFrame()` (same timestamp)
6. Native driver buffers frame and pose
7. `QuestExternalTracker` transforms pose (OpenXR -> CV) and delivers to Vuforia
8. `QuestExternalCamera` delivers frame to Vuforia
9. Vuforia performs image recognition and tracking

## Known Issues

- **Position offset (~4-5cm)**: Tracked objects appear offset from real position. Likely related to camera lens extrinsics or coordinate system handling.
- Distortion coefficients from Meta SDK are not available; currently passed as zeros.

## License

MIT License - see [LICENSE](../LICENSE)
