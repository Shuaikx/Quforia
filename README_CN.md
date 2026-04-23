[English](README.md) | [中文](README_CN.md)

# Quforia - Vuforia Driver for Meta Quest

![Status](https://img.shields.io/badge/Status-Experimental-orange)

Quforia 让 Vuforia Engine 的图像追踪能力在 Meta Quest 设备上运行。它通过一个自定义的 C++ 原生插件，将 Quest 的 Passthrough 摄像头画面喂给 Vuforia，从而实现 AR 图像识别和追踪。

![Demo](/Media/Quforia_sample.gif)

## 安装

Quforia 是一个 Unity Package，可以通过 Unity Package Manager (UPM) 的 Git URL 方式导入。

### 前置要求

| 依赖 | 版本 |
|------|------|
| Unity | 2022.3 或更高 (推荐 6000.0.61f1) |
| Vuforia Engine | 11.4.4 |
| Meta XR SDK | 81.0.0 |

> **注意：** Vuforia 和 Meta XR SDK 需要你在导入 Quforia 之前（或之后）自行安装，Quforia 不会自动拉取它们。

### 步骤 1 — 通过 UPM 导入 Quforia

1. 在 Unity 中打开你的项目
2. 打开菜单 **Window > Package Manager**
3. 点击左上角 **"+"** 按钮，选择 **"Add package from git URL..."**
4. 输入以下 URL：

```
https://github.com/Shuaikx/Quforia.git?path=Assets/Quforia
```

5. 点击 **Add**，等待导入完成

> **指定版本：** 如果你想锁定某个版本，可以在 URL 末尾加上 `#tag`，例如：
> ```
> https://github.com/Shuaikx/Quforia.git?path=Assets/Quforia#v0.1.0
> ```

### 步骤 2 — 安装原生插件

Quforia 依赖一个原生 Android 插件 (`libquforia.so`)。你需要手动将它放入你的项目：

1. 从本仓库的 [`Assets/Plugins/Android/libs/arm64-v8a/libquforia.so`](Assets/Plugins/Android/libs/arm64-v8a/libquforia.so) 下载该文件
2. 将它放到你项目的 `Assets/Plugins/Android/libs/arm64-v8a/` 目录下

### 步骤 3 — 配置 Vuforia License Key

1. 前往 [Vuforia 开发者门户](https://developer.vuforia.com/home) 获取一个 License Key（免费版即可）
2. 在 Unity 中，选中任意挂有 **Vuforia Behaviour** 组件的 GameObject，点击 **Open Vuforia Engine configuration**
3. 在打开的 **Vuforia Configuration** 面板中，将 License Key 粘贴到 **App License Key** 字段中

### 步骤 4 — 配置 AndroidManifest

确保你的 `AndroidManifest.xml` 包含以下权限和特性声明：

```xml
<!-- 摄像头权限（Passthrough Camera） -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />

<!-- Passthrough 相关 -->
<uses-feature android:name="com.oculus.feature.PASSTHROUGH" android:required="true" />
<uses-permission android:name="com.oculus.permission.USE_SCENE" />

<!-- Quest VR 支持 -->
<uses-feature android:name="android.hardware.vr.headtracking" android:required="true" />
```

### 步骤 5 — 导入示例（可选）

导入 Quforia 包后，你可以在 Package Manager 中找到它，展开 **Samples** 部分，点击 **Import** 导入：

- **Demo Models** — 示例 3D 模型、动画和材质
- **Demo Scenes** — 包含一个 Image Target 演示场景

## 使用方法

### Image Target 追踪

1. 在 [Vuforia 开发者门户](https://developer.vuforia.com/home) 创建一个 Image Target 数据库，并导出到 Unity
2. 打开或创建一个场景
3. 场景中需要包含以下组件：
   - **QuestVuforiaDriverInit** — 初始化 Quforia 原生驱动
   - **MetaCameraProvider** — 从 Quest Passthrough 摄像头获取画面并传递给 Vuforia
   - **Vuforia ImageTargetBehaviour** — 标准的 Vuforia Image Target 组件，配置你的目标数据库和图片
4. 构建并部署到 Quest 设备运行

> 如果你导入了 Demo Scenes 示例，可以直接打开 `ImageTargetScene` 查看完整配置。

## 工作原理

Quforia 采用两层架构：

```
Quest Passthrough Camera
        │
        ▼
┌─────────────────────────────┐
│  Unity C# Layer             │
│  MetaCameraProvider          │
│  - 获取摄像头画面 (RGB)       │
│  - 获取设备位姿 (Pose)        │
└──────────┬──────────────────┘
           │ P/Invoke
           ▼
┌─────────────────────────────┐
│  Native C++ Plugin          │
│  libquforia.so              │
│  - Vuforia Driver Framework │
│  - 帧队列管理                │
│  - 坐标系转换                │
└──────────┬──────────────────┘
           │
           ▼
     Vuforia Engine
     (图像识别 & 追踪)
```

**C# 层** 通过 `PassthroughCameraAccess` 获取 Quest 摄像头的 RGB 画面和设备位姿，然后通过 P/Invoke 传给原生插件。

**C++ 原生插件** 实现了 Vuforia Driver Framework 接口，负责将画面帧排入队列、处理 Unity/OpenXR 和 Vuforia CV 之间的坐标系转换。

## 已知问题

- **位置偏移 (~4-5cm)**：追踪物体相对于真实位置存在偏移，旋转对齐正确但位置有偏差。切换左/右摄像头时偏移方向会翻转。原因正在排查中。
- **Model Target**：尚未实现，计划中。

## 从源码构建原生插件

如果你需要修改原生插件：

```bash
cd Assets/Quforia/QuforiaPlugin~
./build.sh
```

构建产物 `libquforia.so` 会输出到 `Assets/Plugins/Android/libs/arm64-v8a/`。

## 项目结构

```
Assets/Quforia/                    # UPM 包
├── package.json                    # 包描述文件
├── Scripts/
│   ├── Quforia.asmdef              # 程序集定义
│   ├── QuestVuforiaDriverInit.cs   # 驱动初始化
│   ├── MetaCameraProvider.cs       # Quest 摄像头画面获取
│   ├── QuestVuforiaBridge.cs       # P/Invoke 桥接
│   └── VuforiaKeyLoader.cs         # License Key 加载
├── Samples~/
│   ├── Models/                     # 示例模型和动画
│   └── Scenes/                     # 示例场景
└── QuforiaPlugin~/                 # C++ 原生插件源码（Unity 不可见）
    ├── src/
    ├── include/
    ├── CMakeLists.txt
    └── build.sh

Assets/Plugins/Android/             # 原生插件二进制
└── libs/arm64-v8a/
    └── libquforia.so
```

## Contributing

这是一个实验性项目，欢迎提交 Issue、PR 或建议。

## License

MIT License — 详见 [LICENSE](LICENSE)。
