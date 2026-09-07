# NIO Radio

Flutter 原生客户端（Android 优先）。网站仍是 [nio-podcast-web](https://github.com/icekale/nio-podcast-web) / https://nio.k4le.top/

复用网站色板、Logo 和同一套 NIO 接口，不是 WebView 壳。

```bash
flutter analyze
flutter test
JAVA_HOME=/opt/homebrew/opt/openjdk@17 flutter build apk
```

`applicationId`: `top.k4le.nio_radio`。打包需要 JDK 17 + Android SDK；本机若 `sdkmanager` 拉 NDK 失败，以 `flutter analyze` / `flutter test` 为准。
