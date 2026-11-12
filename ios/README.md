# MyGo CloudMusic — iOS SwiftUI 移植预览版

这是原 Go/MyGo 桌面客户端的 **独立 iOS 原生迁移工程（第一阶段）**。原项目完整保留在仓库根目录。所有界面均使用 SwiftUI，没有 WebView。

## 打开工程

1. 使用 Xcode 16 或更新版本打开 `ios/MyGoCloudMusic.xcodeproj`。
2. 选择 MyGoCloudMusic scheme 和 iPhone 模拟器/真机。
3. 真机运行时在 Signing & Capabilities 中选择自己的 Apple Developer Team。
4. 在应用设置选择 Subsonic（如 Navidrome）或 Songloft，填写实际服务器地址和账号。

最低部署目标：iOS 17。工程未添加第三方 Swift 包依赖。

## 已实现的第一阶段

- 沿用原版的浅色/深色背景、侧栏配色、列表字号、卡片与播放器布局。
- iPhone 上将桌面 232pt 导航侧栏改为可弹出的导航面板；歌曲浏览、专辑/歌手卡片与播放器自动适配。
- 音乐源切换、服务器登录配置、Keychain 保存凭据。
- Subsonic / OpenSubsonic 的基础 Ping、专辑、歌手、歌单、搜索、歌曲播放 URL、封面、歌词和 Star API。
- Songloft 基础认证、歌曲查询、分类、歌单、流地址及歌词接口。
- AVPlayer 流播放、上一首/下一首/暂停/进度、背景音频和系统控制中心控制入口。
- 播放页包含封面、歌词文本、队列与进度条。

## 与原桌面版的差异与未完成事项

**这不是完成度等同于原 Go 客户端的完整移植版，尚未达到逐像素一致。**

- 网易云、QQ 音乐、飞牛音乐：暂未迁移 iOS 网络协议、登录流程和数据源，切换器仅显示迁移中的状态。
- Songloft 封面请求需要 Bearer 头，当前 SwiftUI AsyncImage 不具备此鉴权头，因此私有封面可能不显示；收藏也未迁移。
- Subsonic 的库首页通过最新专辑聚合（只取前 20 张专辑），不是完整歌曲分页；歌手详情、收藏列表、文件夹树、跨页分页仍不完整。
- 逐字歌词同步、翻译、封面动态着色、律动/烟雾背景、原版高度定制的交互动效未移植。
- Hi-Res/DSD/DTS/APE/CUE 解码、DLNA、下载缓存、缓存管理、歌单编辑、专辑编辑、音量均衡未移植。
- 新工程尚未在 macOS/Xcode 环境下实际构建、运行、进行像素对比或连接真实服务器测试，源码需要在 Xcode 中验证与继续修复。
- iOS 相比桌面有安全区域、触控热区及可用宽度限制，部分桌面结构必须适配，不能以 1180pt 桌面宽度直接渲染。

## 继续迁移的推荐顺序

1. 在 Xcode 构建并用真实 Songloft / Subsonic 服务测试连接、歌曲播放、封面和后台播放。
2. 按原 Go 的 `internal/app/ui_kit.go`、`ui_main.go`、`ui_player.go`、`ui_nowplaying.go` 对照录屏做视觉微调。
3. 逐步复刻完整导航、播放队列、收藏、文件夹、歌单 CRUD、逐字歌词。
4. 将 FN Music、网易云、QQ 音乐的协议与授权流程分别迁移并测试。
5. 完成 iPhone 多尺寸/深浅色视觉回归测试，再评估 App Store 合规与发布。

## 技术备注

- 网络访问使用 URLSession；私有认证数据存于设备 Keychain，避免硬编码在源码。
- 优先使用 HTTPS。Info.plist 为局域网连接声明了 Local Networking 例外，非局域网 HTTP 仍可能被 ATS 拦截。
- 原工程仍按 AGPL-3.0 授权；迁移项目须遵守原有许可证。
