# APK 构建产物

这里存放本地构建的安装包，**不进入版本控制**（见仓库根 `.gitignore`）。

## app-release.apk

| 项 | 值 |
|---|---|
| 包名 | `fan.x0.para` |
| 版本 | 1.0.2 (versionCode 3) |
| 大小 | 80,112,158 字节（约 76.4 MB） |
| SHA-256 | `116a413227cbfa74f07be0d9b35cdeabc5c850e0d5cd669cf072c3ce7dd470d9` |
| 签名 | Android Debug 证书（V2/V3 有效） |
| 构建模式 | release |
| 构建工具 | Flutter 3.47.6 / Dart 3.13.5 / AGP 9.1.0 / Gradle 9.3.1 |
| compileSdk | 37（platform `android-37.0`） |
| NDK | 28.2.13676358 |
| CMake | 3.22.1 |

### 这个包包含什么

分支 `perf-streaming-smoothness` 上的全部改动：

1. 流式/滚动热路径优化与持久化数据安全修复（见 PR 描述）
2. **OpenAI 格式画图**：`generate_image` 工具，走 `/v1/images/generations`
3. **语音合成**：`speak` 工具，两种引擎 —— 设备 TTS（`flutter_tts`，离线）
   和 OpenAI 兼容 `/v1/audio/speech`（`just_audio` 播放返回的 mp3）
4. 每个智能体（Persona）在角色卡里**单独设置**画图与语音，包括引擎、端点、
   模型、音色、自动朗读

### 测试要点

- 设置 → AI 回复 → 最下方「语音与画图」：配置默认的画图接口/模型/尺寸，
  以及语音引擎（设备语音 / 语音接口）、模型、默认音色、语速。
- 打开某个角色的角色卡 → 最下方「语音与画图」：打开画图或语音开关，
  可覆盖上面配的默认端点。开关关闭时模型不会拿到对应工具。
- 开启后对角色说「画一只猫」/「用语音说晚安」，模型会调用工具。

### 关于签名

仓库没有提交 `android/key.properties`，所以 release 构建回退到 debug 签名配置
（见 `android/app/build.gradle.kts` 的 `signingConfigs`）。这个包**只适合自测安装**，
不能用于分发：debug 证书不是发布证书，且同一包名的正式版会因签名不同而无法覆盖安装。

要出正式包，在 `android/` 下创建 `key.properties`（格式见 `key.properties.example`）
后重新执行 `flutter build apk --release`。

### 重新构建

```bash
flutter pub get
cd android && ./gradlew --stop && cd ..
flutter build apk --release
```

注意三点环境要求，缺任何一个都会在 `assembleRelease` 阶段失败：

1. **typst_flutter 预编译原生库**：该插件不从 pub 分发 `.so`，首次构建前需要
   `dart run typst_flutter:setup`（或手动把 4 个 ABI 的 `libtypst_flutter.so`
   放进 pub 缓存的 `.typst_flutter_prebuilt/android/<abi>/`）。
2. **proot 原生库**：`tool/fetch_proot.sh` 会在 `preBuild` 时拉取，
   需要 bash + python3 + curl + tar 可用。
3. **Android SDK 平台目录名**：AGP 找的是 `platforms/android-37`，而
   `sdkmanager` 安装 `platforms;android-37.0` 会创建 `platforms/android-37.0`。
   需要建一个目录联接：`mklink /J android-37 android-37.0`（或安装
   `platforms;android-36.1` 并把 compileSdk 降到 36）。

### 构建产物未包含的内容

这个 APK 是用本地改动构建的（分支 `perf-streaming-smoothness`），
相对 `Celvra/paradise@main` 多了流式/滚动优化、持久化数据安全修复、
以及画图与语音功能。
