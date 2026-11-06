# ``CaptchaSolverInterface``

定义人机验证与交互式登录质询的公共接口协议。

## 概述

`CaptchaSolverInterface` 模块为宿主应用与动态加载的验证组件（如 `CaptchaSolver`）之间提供解耦的抽象边界，定义了统一的登录验证视图构建协议与质询数据模型。

## Topics

### 核心协议与模型

- ``CaptchaPresenting``
- ``LoginChallengeDetails``
