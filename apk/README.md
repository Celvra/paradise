# APK 构建产物

这里存放本地构建的安装包，**不进入版本控制**（见仓库根 `.gitignore`）。

## app-release.apk

| 项 | 值 |
|---|---|
| 包名 | `fan.x0.para` |
| 版本 | 1.0.2 (versionCode 3) |
| 大小 | 79,171,626 字节（约 75.5 MB） |
| SHA-256 | `d607d28052601594e6e3a740e02c7056bb63877bf91741218a58556fb3cf8599` |
| 签名 | Android Debug 证书（V2 有效） |
| 构建模式 | release |
| 构建工具 | Flutter 3.47.6 / Dart 3.13.5 / AGP 9.1.0 / Gradle 9.3.1 |
| compileSdk | 37（platform `android-37.0`） |
| NDK | 28.2.13676358 |
| CMake | 3.22.1 |

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

注意两点环境要求，缺任何一个都会在 `assembleRelease` 阶段失败：

1. **typst_flutter 预编译原生库**：该插件不从 pub 分发 `.so`，首次构建前需要
   `dart run typst_flutter:setup`（或手动把 4 个 ABI 的 `libtypst_flutter.so`
   放进 pub 缓存的 `.typst_flutter_prebuilt/android/<abi>/`）。
2. **proot 原生库**：`tool/fetch_proot.sh` 会在 `preBuild` 时拉取，
   需要 bash + python3 + curl + tar 可用。

### 构建产物未包含的内容

这个 APK 是用本地改动构建的（分支 `perf-streaming-smoothness`），
相对 `Celvra/paradise@main` 多了流式/滚动优化与持久化数据安全修复。
