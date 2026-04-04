[English](README.md) | [中文](README_CN.md)

# Quforia - Vuforia Driver for Meta Quest

![Status](https://img.shields.io/badge/Status-Experimental-orange)

Quforia enables Vuforia Engine's image tracking capabilities on Meta Quest devices. It feeds Quest's Passthrough camera frames to Vuforia through a custom C++ native plugin, enabling AR image recognition and tracking.

![Demo](/Media/image-target-demo.gif)

## Installation

Quforia is a Unity Package that can be imported via Unity Package Manager (UPM) using a Git URL.

### Prerequisites

| Dependency | Version |
|------------|---------|
| Unity | 2022.3 or later (recommended 6000.0.61f1) |
| Vuforia Engine | 11.4.4 |
| Meta XR SDK | 81.0.0 |

> **Note:** Vuforia and Meta XR SDK must be installed separately — Quforia does not pull them automatically.

### Step 1 — Import Quforia via UPM

1. Open your project in Unity
2. Go to **Window > Package Manager**
3. Click the **"+"** button in the top-left corner and select **"Add package from git URL..."**
4. Enter the following URL:

```
https://github.com/Shuaikx/Quforia.git?path=Assets/Quforia
```

5. Click **Add** and wait for the import to complete

> **Pin a version:** Append `#tag` to the URL to lock to a specific version, e.g.:
> ```
> https://github.com/Shuaikx/Quforia.git?path=Assets/Quforia#v0.1.0
> ```

### Step 2 — Install the Native Plugin

Quforia depends on a native Android plugin (`libquforia.so`). You need to add it to your project manually:

1. Download [`Assets/Plugins/Android/libs/arm64-v8a/libquforia.so`](Assets/Plugins/Android/libs/arm64-v8a/libquforia.so) from this repository
2. Place it in your project at `Assets/Plugins/Android/libs/arm64-v8a/`

### Step 3 — Configure Vuforia License Key

1. Get a License Key from the [Vuforia Developer Portal](https://developer.vuforia.com/home) (free tier works)
2. Create a file named `VuforiaLicenseKey.txt` in your project's `Assets/StreamingAssets/` directory
3. Paste your License Key into that file

### Step 4 — Configure AndroidManifest

Make sure your `AndroidManifest.xml` includes the following permissions and features:

```xml
<!-- Camera permission (Passthrough Camera) -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />

<!-- Passthrough -->
<uses-feature android:name="com.oculus.feature.PASSTHROUGH" android:required="true" />
<uses-permission android:name="com.oculus.permission.USE_SCENE" />

<!-- Quest VR support -->
<uses-feature android:name="android.hardware.vr.headtracking" android:required="true" />
```

### Step 5 — Import Samples (Optional)

After importing the Quforia package, find it in the Package Manager, expand the **Samples** section, and click **Import**:

- **Demo Models** — Sample 3D models, animations, and materials
- **Demo Scenes** — An Image Target demo scene

## Usage

### Image Target Tracking

1. Create an Image Target database on the [Vuforia Developer Portal](https://developer.vuforia.com/home) and export it to Unity
2. Open or create a scene
3. Add the following components to your scene:
   - **QuestVuforiaDriverInit** — Initializes the Quforia native driver
   - **MetaCameraProvider** — Captures Quest Passthrough camera frames and passes them to Vuforia
   - **Vuforia ImageTargetBehaviour** — Standard Vuforia Image Target component; configure your target database and image
4. Build and deploy to your Quest device

> If you imported the Demo Scenes sample, open `ImageTargetScene` to see a working setup.

## How It Works

Quforia uses a two-layer architecture:

```
Quest Passthrough Camera
        |
        v
+-----------------------------+
|  Unity C# Layer             |
|  MetaCameraProvider         |
|  - Capture camera frames    |
|  - Extract device pose      |
+-------------+---------------+
              | P/Invoke
              v
+-----------------------------+
|  Native C++ Plugin          |
|  libquforia.so              |
|  - Vuforia Driver Framework |
|  - Frame queue management   |
|  - Coordinate transforms    |
+-------------+---------------+
              |
              v
        Vuforia Engine
   (Image Recognition & Tracking)
```

**C# Layer** captures RGB frames and device poses from Quest's Passthrough camera via `PassthroughCameraAccess`, then passes them to the native plugin through P/Invoke.

**C++ Native Plugin** implements the Vuforia Driver Framework interface, handling frame queuing and coordinate system transformations between Unity/OpenXR and Vuforia CV conventions.

## Known Issues

- **Position Offset (~4-5cm)**: Tracked objects appear offset from their actual position. Rotation alignment is correct, but there is a positional shift. The offset direction flips when switching between left/right cameras. Root cause under investigation.
- **Model Target**: Not yet implemented, planned for future development.

## Building the Native Plugin from Source

If you need to modify the native plugin:

```bash
cd QuforiaPlugin
./build.sh
```

The built `libquforia.so` will be output to `Assets/Plugins/Android/libs/arm64-v8a/`.

## Project Structure

```
Assets/Quforia/              # UPM package
├── package.json              # Package manifest
├── Scripts/
│   ├── Quforia.asmdef        # Assembly definition
│   ├── QuestVuforiaDriverInit.cs   # Driver initialization
│   ├── MetaCameraProvider.cs       # Quest camera frame capture
│   ├── QuestVuforiaBridge.cs       # P/Invoke bridge
│   └── VuforiaKeyLoader.cs         # License Key loader
└── Samples~/
    ├── Models/               # Sample models & animations
    └── Scenes/               # Sample scenes

Assets/Plugins/Android/       # Native plugin
└── libs/arm64-v8a/
    └── libquforia.so

QuforiaPlugin/                # C++ native plugin source
├── src/
├── include/
├── CMakeLists.txt
└── build.sh
```

## Contributing

This is an experimental project. Issues, PRs, and suggestions are welcome.

## License

MIT License — see [LICENSE](LICENSE) for details.
