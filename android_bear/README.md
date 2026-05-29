# Android 版（暂不可用debug中勿下载）

Android 版是一个 Flutter 安卓桌面宠物熊。

## 环境要求

- 适合 Android 8.0 及以上用户。
- 需要在电脑上安装 Flutter 和 Android SDK 才能构建。
- 熊图由用户自己上传，不内置任何第三方 GIF。
- 支持聊天：通过 DeepSeek API 和熊对话，API Key 保存在本地。
- 悬浮窗功能需要手动开启悬浮窗权限。

## 技术栈

- Flutter (Dart) — 主页面 UI
- Android 原生 (Kotlin) — 悬浮窗 + 前台服务 + 闹钟
- MethodChannel — Flutter ↔ 原生通信
- Glide — GIF 加载

## 代码结构

```text
android_bear/
├── android/app/src/main/kotlin/com/example/bear/
│   ├── MainActivity.kt        # Flutter 入口
│   ├── FloatService.kt        # 前台服务 + 悬浮窗 + GIF 轮换
│   ├── BearPlugin.kt          # MethodChannel 注册
│   ├── ReminderReceiver.kt    # 闹钟广播接收器
│   └── GifHelper.kt           # GIF 校验 + 占位图绘制
├── lib/
│   ├── main.dart              # App 入口
│   ├── pages/
│   │   ├── home_page.dart     # 主页（开关、皮肤、提醒、聊天入口）
│   │   ├── settings_page.dart # 设置（轮换间隔）
│   │   └── chat_page.dart     # 聊天页面（DeepSeek API）
│   ├── services/
│   │   └── float_service.dart # MethodChannel Dart 封装
│   ├── models/
│   │   └── skin_model.dart    # 皮肤数据模型
│   └── widgets/
│       └── skin_picker.dart   # 皮肤选择器
├── pubspec.yaml
└── README.md
```

## 使用

先进入 Android 版目录：

```bash
cd android_bear
```

安装依赖：

```bash
flutter pub get
```

构建 APK：

```bash
flutter build apk
```

安装到手机（开发者模式已开启）：

```bash
flutter install
```

也可以用 `flutter run` 直接调试运行。

## 旧版本如何更新

如果你已经有旧版熊，最小更新只需要替换这些文件：

```text
android_bear/lib/
android_bear/android/app/src/main/kotlin/com/example/bear/
android_bear/pubspec.yaml
android_bear/android/app/build.gradle
```

不要删除自己的素材和配置：

```text
android_bear/assets/
```

替换后重新构建：

```bash
flutter pub get
flutter build apk
```

如果你是用 Git 下载的，直接运行：

```bash
git pull
cd android_bear
flutter pub get
flutter build apk
```

## 上传皮肤

打开熊 App 后，进入主页，在「我的皮肤」区域点击「上传一个你喜欢的GIF 吧～」，从手机相册或文件管理器选择 GIF。

要求：
- 必须是 `.gif` 文件
- 单个 GIF 不超过 5MB
- 最多保存 3 个 GIF

上传后，皮肤卡片会显示文件名和大小。点击卡片可以切换到该皮肤，长按卡片可以删除。

## 多个姿势

上传多个 GIF 后，熊会自动轮换。

在设置页面可以设置轮换时间：
- 5 秒
- 10 秒（默认）
- 30 秒
- 60 秒

如果只上传 1 个 GIF，则不会轮换。

轮换逻辑在原生 FloatService 中通过 Handler.postDelayed() 实现，不需要 Flutter 端持续通信。

## 每日提醒

在主页可以设置每日提醒时间。熊会在设定的时间发送通知。

提醒通过 Android AlarmManager + BroadcastReceiver 实现，Flutter 端通过 MethodChannel 调用 `setReminder(hour, minute)` 设置。

通知文案是随机的小熊语气，比如：
- 熊：到点啦，该休息一下哦～
- 熊：熊提醒你喝水了
- 熊：别太累了，站起来走走～

点击通知会打开熊 App。

## 权限

第一次开启悬浮熊时，App 会引导你打开悬浮窗权限。

需要的权限：
| 权限 | 用途 |
|------|------|
| 悬浮窗 | 在其他 App 上方显示熊 |
| 前台服务 | 保持悬浮熊不被系统杀掉 |
| 精确闹钟 | 每日提醒准时触发 |
| 通知 | 发送提醒通知 |
| 读取媒体文件 | 用户选择 GIF 文件 |

路径一般是：

```text
设置 → 应用 → 熊 → 悬浮窗权限（或「显示在其他应用上层」）
```

部分手机可能需要额外开启：
- 允许自启动
- 忽略电池优化

如果不开启悬浮窗权限，悬浮熊不会显示。

## 功能

- 悬浮 GIF 熊（可拖动）
- 用户上传 GIF 皮肤（最多 3 个）
- 切换皮肤
- GIF 自动轮换
- 每日提醒
- 聊天（DeepSeek API，和 macOS/Windows 版一致）
- 占位气泡（没有 GIF 时显示）

## 触控

- 点一下悬浮熊：打开熊主页面
- 按住拖动：移动熊位置

## MethodChannel 接口

Flutter 端通过 `com.example.bear/float_service` 通道调用原生方法：

```
showBear()                    → 显示悬浮熊
hideBear()                    → 隐藏悬浮熊
updateSkin(path)              → 更换当前 GIF
showPlaceholder()             → 显示占位气泡
startRotation(interval)       → 开始轮换（秒）
stopRotation()                → 停止轮换
setReminder(hour, minute)     → 设置每日提醒
cancelReminder()              → 取消提醒
chatWithBear(apiKey, question)→ 聊天（DeepSeek API）
hasOverlayPermission()        → 检查悬浮窗权限
requestOverlayPermission()    → 请求悬浮窗权限
```

## 本地存储

| 内容 | 方式 | 键 |
|------|------|-----|
| GIF 文件 | 私有目录 `skins/skin_0.gif` ~ `skin_2.gif` | — |
| 当前皮肤索引 | SharedPreferences | `current_skin_index` |
| 轮换间隔 | SharedPreferences | `rotation_interval` |
| 提醒时间 | SharedPreferences | `reminder_hour`, `reminder_minute` |
| 悬浮熊开关 | SharedPreferences | `bear_enabled` |

## 版本兼容

- minSdkVersion: 26 (Android 8.0)
- targetSdkVersion: 34 (Android 14)
