# NIO Radio

Flutter 原生客户端（Android 优先）。网站仍是 [nio-podcast-web](https://github.com/icekale/nio-podcast-web) / https://nio.k4le.top/

按网站 UI/功能做原生客户端：首页今日推荐、全部专辑、搜索、专辑页、播放器、播放列表（队列/最近听过/稍后播放）。不是 WebView 壳。

下载：[NIO-Radio.apk](https://github.com/icekale/nio-podcast-app/releases/latest/download/NIO-Radio.apk)

```bash
flutter analyze
flutter test
flutter build apk
```

`applicationId`: `top.k4le.nio_radio`。APK 由 GitHub Actions 打包。
