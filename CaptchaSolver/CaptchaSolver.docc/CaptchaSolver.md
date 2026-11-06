# ``CaptchaSolver``

提供基于 WebKit 的交互式网页登录与人机验证组件实现。

## 概述

`CaptchaSolver` 模块实现了 `CaptchaSolverInterface` 所定义的验证视图展示协议，利用内嵌的 `WKWebView` 引导用户完成网页登录、人机验证（CAPTCHA）及双重认证（2FA），并在检测到有效会话 Cookie 后将凭据回调给宿主应用。

## Topics

### 创建验证展示器

- ``createCaptchaPresenter()``
