<div align="center">

  <h1>星岛 StarIsland</h1>
  <p><b>专为 macOS 打造的全功能旗舰版灵动岛工作台（100% 原生简体中文 · 全特性永久解锁）</b></p>
  <p>
    <a href="https://github.com/adgry/StarIsland/releases/latest"><b>下载最新版本 (StarIsland-arm64.zip)</b></a>
    ·
    <a href="https://github.com/adgry/StarIsland/releases"><b>版本发布历史</b></a>
  </p>

</div>

---

**星岛 (`StarIsland.app`)** 是面向 Apple Silicon Mac 深度重构与增强的全能型灵动岛应用。完整保留原厂级 60/120fps 流体刘海动画、11 步沉浸式开机向导、250pt 毛玻璃分层设置中心与可视化拖拽工作区编辑器，同时将全部 **48 项旗舰级特性** 替换为无需登录、无订阅墙、开箱即用的本地真实引擎，并彻底修复权限授权、后台辅助服务与验证码误报痛点。

## 核心亮点

- **100% 原厂级交互与视觉体验**：完整保留灵动岛流体形变引擎、实时活动双翼、可视化小组件与顶栏拖拽编排器、14 段实机功能预览动画与 41 个精细化中文设置面板。
- **全功能永久解锁（零付费墙 / 零账号绑定）**：
  - **多通道 AI 灵动助手与画圈搜屏 OCR**：内置 Gemini、DeepSeek、通义千问、OpenRouter、OpenAI、Claude 及免 Key 本地 Ollama 通道，搭配离线中英双语 Vision 框选识屏。
  - **免 Key 体育记分牌与实时财经行情**：直连 ESPN 多联赛实时比分与 Yahoo Finance / Binance 股票加密货币迷你走势折线。
  - **应用级 8D 环绕声与全景声场扩展**：基于 CoreAudio Process Tap 的单应用独立音量、多段均衡器（EQ）、8D 旋转声场与双耳互馈环绕声。
  - **智能收件箱双因子验证码识别**：上下文语义 + 强排除规则精准提取短信/邮件验证码，彻底杜绝 Discord 频道消息（如 `3068`）、年份与订单号误弹窗，支持 SHA-256 持久化去重。
  - **Touch ID 应用隐私锁护盾**：基于 `LocalAuthentication` 生物识别与加盐 SHA-256 备用密码的全屏毛玻璃遮蔽保护。
  - **局域网扫码快传门户（6 位一次性配对码）**：手机或平板浏览器扫码即可双向同步剪贴板、快传照片文件至「下载」目录并遥控媒体播放，无需安装手机端 App。
  - **效率与系统增强全家桶**：磁盘空间扫描与安全回收工作区、图片/PDF 瘦身与文字提取、DMG 静默挂载安装、程序坞布局快照、链接追踪参数净化、文本片段展开及键鼠防抖优化。
- **四大核心痛点根治**：
  - **本地网络授权**：主动发起 `_starisland._tcp` Bonjour 局域网探测触发 macOS 原生系统弹窗，并支持一键跳转系统设置与重试。
  - **自动化权限按需温和请求**：不再强行拉起已禁用的「音乐.app」，彻底消除系统报错弹窗。
  - **后台辅助服务优雅降级**：支持本地开发证书双层签名，未安装特权守护进程时亦可一键跳过并流畅使用全部主程序功能。
  - **软件内 GitHub 自动更新**：原生接入 `adgry/StarIsland` Releases 标准 SemVer 检查，支持一键下载 `StarIsland-arm64.zip`、SHA-256 校验、覆盖安装与自动重启。

## 安装指南

1. 前往 [GitHub Releases](https://github.com/adgry/StarIsland/releases/latest) 下载最新的 `StarIsland-arm64.zip`。
2. 解压后将 `StarIsland.app` 拖入 `/Applications`（应用程序）目录并打开。
3. 按照首次启动向导按需授予辅助功能、通知与屏幕录制等权限即可开始使用。

## 本地构建与一键发版

环境要求：macOS 14.2+（Apple Silicon `arm64`）、Xcode 16+、GitHub CLI (`gh`)。

```bash
# 仅本地编译并双层签名生成 dist/release-2.0.0/StarIsland.app 与安装包
./scripts/release.sh 2.0.0 --build-only

# 一键更新版本号、编译签名、推送代码并发布至 GitHub Releases
./scripts/release.sh 2.0.0 "星岛 StarIsland v2.0.0 全功能旗舰版发布"
```

## 开源许可与致谢

本项目基于 [GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE) 开源发布。灵动岛基础窗口框架与部分基础服务衍生自开源项目 [Sapphire](https://github.com/shariqcharolia/Sapphire)（作者 Shariq Charolia，AGPL-3.0），特此致谢。
