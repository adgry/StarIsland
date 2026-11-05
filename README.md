# 星岛 StarIsland

**星岛（StarIsland）** 是一款专为 Apple Silicon Mac 打造的 **100% 原生简体中文、零付费墙** 全功能灵动岛生产力工作台。

---

## 核心特性一览

### 1. 丝滑灵动岛与媒体空间音效（`MediaAudioKit`）
- **物理刘海与外接显示器自适应**：精准贴合 MacBook 刘海几何边缘，外接屏幕自动切换悬浮灵动胶囊，支持锁屏安全隐私视图。
- **全局媒体控制与同步歌词**：支持 Apple Music、Spotify 及主流播放器的进度跳转与封面流光配色，免 Key 对接 `LRCLIB` 呈现逐行同步歌词与桌面悬浮歌词。
- **实时频谱与空间音效**：32 段 FFT 声波可视化，内置**环绕声**与 **8D 旋转声场**音效引擎，并接管系统音量、屏幕亮度与键盘背光 HUD。

### 2. 智能通知、效率工具箱与原生视觉（`ProductivityKit`）
- **双因子智能验证码与快递单号识别**：语义词 + 格式双重判定，彻底杜绝普通群聊数字误触发；配合 `ConsumedEventStore` SHA-256 原子持久化去重，同一验证码绝不重复弹出。
- **可视化剪贴板历史与追踪链接净化**：快捷键 `⌥⌘V` 呼出历史面板（自动跳过密码管理器隐私条目），自动剥离 `utm_*`、`fbclid`、`spm`、`vd_source` 等追踪参数。
- **灵动暂存架与本地媒体压缩**：拖拽文件至屏幕顶部即刻入架，内置纯本地 PNG/JPEG/HEIC 图片压缩、PDF 瘦身与音视频转换。
- **Apple Vision 离线 OCR 与圈选识图**：快捷键 `⇧⌘2` 离线提取中英日繁文字与二维码，`⇧⌘S` 圈选屏幕内容一键翻译、AI 解答或以图搜图。

### 3. 窗口管理、Dock 实时预览与键鼠安全增强（`SystemEnhanceKit`）
- **边缘磁吸分屏与增强窗口切换器**：拖拽窗口至屏幕边缘或四角快速完成二分屏、三分屏、四分屏与全屏填满。
- **Dock 悬停实时窗口预览**：基于 `ScreenCaptureKit` 实时渲染应用窗口缩略图，支持点击激活、一键关窗与单击图标隐藏。
- **键鼠增强与生物识别应用锁**：长按 `⌘Q` 防误触退出、Finder `⌘X` 剪切粘贴、绿灯真最大化、鼠标平滑滚动与防连击消抖、`:关键词` 中文 Emoji 联想，以及 **Touch ID 指纹应用锁**。

### 4. 智能电池风扇管家与深度清理（`HardwareCleanKit`）
- **SMC 电池寿命保护**：自定义充电上限（如 80%）、巡航防微充模式与高温自动停充保护，退出或异常重启通过 `MutationJournal` 自动安全恢复。
- **风扇温控曲线**：支持自动、静音、均衡、全速及自定义温度转速曲线。
- **应用深度卸载与 DMG 一键安装**：精准扫描 `~/Library` 应用残留文件移入废纸篓，挂载 `.dmg` 时支持一键安装并清理源镜像。

### 5. 全景小组件与免 Key 实时活动（`LiveWidgetsKit`）
- **全套开箱即用数据源**：Open-Meteo 实时天气、ESPN 体育实时比分（NBA / 英超 / 欧冠等）、Yahoo Finance 美股港股与 Binance 加密货币分时火花线。
- **日常效率套件**：日历会议倒计时（一键加入腾讯会议 / 飞书 / Zoom）、提醒事项、蓝牙外设电量、多路计时器与 20-20-20 护眼提醒、前置高清随身镜、终端长耗时命令提醒及专注防分心屏蔽。

### 6. 星岛 AI 助手与手机扫码互联（`AIConnectKit`）
- **多引擎 AI 工作台**：支持 Google Gemini、OpenAI 兼容接口（OpenAI / DeepSeek / 通义千问等，密钥安全存储于 macOS `Keychain`）与本地离线 `Ollama`。
- **手机免装 App 扫码跨端互联**：手机相机扫描灵动岛二维码，在手机浏览器输入 6 位一次性安全配对码即可双向极速传文件、同步剪贴板与遥控 Mac 媒体播放。

### 7. GitHub 软件内一键自动更新（`SelfUpdater`）
- 内置连接 `https://github.com/adgry/StarIsland` Releases，发布新版本标签后应用内自动收到更新提醒并支持一键下载替换重启。

---

## 本地编译、测试与发布

```bash
# 1. 运行全量 7 大模块单元测试
cd Packages/StarIslandKit && swift test

# 2. 构建并签名发行包 dist/release-1.0.0/StarIsland-arm64.zip
./scripts/build_app.sh 1.0.0

# 3. 推送标签并发布至 GitHub Releases
./scripts/release.sh 1.0.0
```

## 系统要求

- **操作系统**：macOS 14.0 Sonoma 及更高版本（完美支持 macOS 15 Sequoia / macOS 26）
- **处理器**：Apple Silicon（M1 / M2 / M3 / M4 `arm64`）
