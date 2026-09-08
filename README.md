# NIO Radio

Flutter 原生客户端（Android 优先）。网站仍是 [nio-podcast-web](https://github.com/icekale/nio-podcast-web) / https://nio.k4le.top/

按网站 UI/功能做原生客户端：首页今日推荐、全部专辑、搜索、专辑页、播放器、播放列表（队列/最近听过/稍后播放）。不是 WebView 壳。

下载（arm64）：[NIO-Radio.apk](https://github.com/icekale/nio-podcast-app/releases/latest/download/NIO-Radio.apk)
32 位机型：[NIO-Radio-armv7.apk](https://github.com/icekale/nio-podcast-app/releases/latest/download/NIO-Radio-armv7.apk)

```bash
flutter analyze
flutter test
flutter build apk
```

`applicationId`: `top.k4le.nio_radio`。APK 由 GitHub Actions 打包。

## 发布签名

- Release keystore：`~/.keystores/nio-radio-release.jks`（alias `nio-radio`，密码见同目录 `nio-radio-release.env`）。**务必备份这两个文件**——丢失后新版本将无法覆盖安装。
- GitHub Actions 从 Secrets（`ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD`）读取签名；release tag 自动取 pubspec 的 `version`（`v1.0.0` 这类）。
- 本地出签名包：`source ~/.keystores/nio-radio-release.env && ANDROID_KEYSTORE_PATH=~/.keystores/nio-radio-release.jks ANDROID_KEYSTORE_PASSWORD=$ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS=$ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD=$ANDROID_KEYSTORE_PASSWORD flutter build apk`。不设环境变量时回退 debug 签名。
