<div align="center">
<img width="220" height="220" alt="Group 31" src="https://github.com/user-attachments/assets/1e3ef88f-9849-4896-88d2-5294841a0062" />

  <h1>Sapphire</h1>
  <p><b>重新定义灵动岛的全能型 Mac 应用</b></p>
  <a href="https://sapphire-app.tech" style="text-decoration: none; margin-right: 10px;">
    <div style="background-color: #007aff; color: white; padding: 10px 20px; border-radius: 8px; display: inline-block; font-weight: bold;">
      官方网站
    </div>
  </a>
  <a href="https://github.com/adgry/Sapphire-CN/releases/latest" style="text-decoration: none;">
    <div style="background-color: #007aff; color: white; padding: 10px 20px; border-radius: 8px; display: inline-block; font-weight: bold;">
      下载最新版本
    </div>
  </a>
  <a href="https://discord.gg/Ryuea8vM2h" style="text-decoration: none;">
    <div style="background-color: #007aff; color: white; padding: 10px 20px; border-radius: 8px; display: inline-block; font-weight: bold;">
      加入 Discord
    </div>
  </a>
</div>

<br>

Sapphire 是一款精致优雅的灵动岛应用，可在新款 MacBook 的灵动岛区域整洁地展示当前活动状态。同时它还内置了一系列实用功能，从支持便捷文件传输的附近分享兼容能力，到灵活多样的窗口磁吸分区系统，应有尽有。

## 安装指南

1.  **下载：** 从 [版本发布页面](https://github.com/adgry/Sapphire-CN/releases/latest) 下载最新的 `Sapphire-arm64.zip` 安装包。
2.  **安装：** 解压后将 `Sapphire.app` 拖入 `/Applications`（应用程序）文件夹并打开。
3.  **权限配置：** 首次启动时，你可能需要在 `系统设置` 中授予辅助功能及其他相关权限，以确保所有功能正常运行。

## 软件内自动更新与版本发布说明

本仓库（`adgry/Sapphire-CN`）已接入软件内自动更新通道。每当本仓库发布高于当前客户端版本的新 GitHub Release（附带 `Sapphire-arm64.zip`）后，已安装的客户端会在后台定时检查、唤醒检查或手动点击 **“设置 → 关于 → 检查更新”** 时收到更新提醒，并支持一键下载、覆盖安装与自动重启。

后续修改代码后发布新版本有两种方式：

1. **本地一键编译发版（推荐，速度最快）：**
   ```bash
   ./scripts/release.sh 3.6 "本次更新说明"
   ```
   脚本会自动更新 `VERSION` 与 Xcode 工程中的主应用版本号、编译 `Release` 版 `Sapphire.app`、完成签名与 `Sapphire-arm64.zip` 打包、推送代码与 `v3.6` 标签，并直接发布到 GitHub Releases。

2. **GitHub 云端自动构建发版（GitHub Actions）：**
   - 在本地或网页端创建并推送以 `v` 开头的版本标签（例如 `v3.6`），或在仓库 **Actions → Build and Publish Sapphire Release → Run workflow** 中填入版本号触发，工作流会自动完成构建并将 `Sapphire-arm64.zip` 上传至对应的 GitHub Release。

## 功能特性

<div style="display: flex; flex-wrap: wrap; gap: 16px; justify-content: center;">

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">附近分享</h3>
    <p>支持将文件、图片、视频、网页等内容从 Android 设备轻松分享至你的 Mac！</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">正在播放</h3>
    <p>在灵动岛中展示当前正在播放的各类媒体内容（同样兼容 macOS 15.5）及更多功能。</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">高级音频功能（测试版）</h3>
    <p>直接在灵动岛中独立调节单个应用音量、设备音量、应用均衡器（EQ）以及设备均衡器。</p>
  </div>
  
  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">护眼休息</h3>
    <p>健康始终是第一位的。借助精致的灵动岛界面，每 20 分钟提醒你注视 20 英尺（约 6 米）外的地方 20 秒，并提供更多贴心设置。</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">天气</h3>
    <p>在灵动岛中常驻显示当前天气状况，让你随时掌握周边天气变化及更多气象信息。</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">Gemini</h3>
    <p>通过 Gemini Live 便捷地共享屏幕并探讨各类话题，解锁更多智能交互体验。</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">日历</h3>
    <p>查看即将到来的日程安排，并获取正在进行事项的实时提醒及更多功能。</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">锁定屏幕</h3>
    <p>在 Mac 锁屏界面直观查看天气、正在播放的音乐以及即将到来的日历日程等内容。</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">文件暂存架</h3>
    <p>随时调用文件暂存架来便捷存储文件或通过隔空投送（AirDrop）快速分享，并提供更多实用操作。</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">窗口磁吸分区</h3>
    <p>macOS 内置的窗口排列工具功能有限，且会在窗口之间留有缝隙。Sapphire 提供了灵活多样且高度可定制的窗口磁吸分区系统及更多功能。</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">音乐</h3>
    <p>在灵动岛上查看正在播放的媒体，展开后可浏览更多详细信息并进行播放控制。</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">蓝牙</h3>
    <p>当蓝牙设备连接到你的 Mac 时获取连接提示及更多信息。</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">保持唤醒</h3>
    <p>只需轻按一下按钮即可让你的 Mac 保持唤醒状态，并提供更多实用选项。</p>
  </div>

</div>
