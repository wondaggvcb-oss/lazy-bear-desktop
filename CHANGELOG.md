# 更新日志

## 2026-05-21

- 增加 Windows 版：使用 Python/Tkinter 运行，支持聊天、记忆、性格和计时。
- 调整仓库结构：macOS 与 Windows 分开放在 `macos/` 和 `windows/`。
- 加入本机记忆：熊可以记录用户偏好，并在聊天时参考。
- 加入自定义性格：可以自己写熊的人设和说话方式。
- 加入简单计时：到点后熊会弹出提醒。
- 更新中文 README：补充记忆、性格、计时和快捷键说明。
- 补充环境要求：说明 macOS、Windows、AI 对话、屏幕权限和透明效果差异。
- Windows 版支持读取本地图标 `Resources/BearIcon.ico`，测试包可生成桌面快捷方式。
- macOS 构建时如果没有自定义 `.icns`，会自动从熊 GIF 生成 app 图标。
- 根目录 README 改成 macOS / Windows 双版本总入口。
- 调整熊的问候逻辑：只在打开聊天时先问好，后续回复和提醒不再每次重复固定开场白。

## 2026-05-22

- 修复 GIF 载入逻辑：`assets/` 里放多少 `.gif` 都会按文件名顺序轮播，不再要求固定文件名。
- macOS 构建脚本会把 `macos/assets/` 里的所有 GIF 打包进 `.app`。
- Windows 版换姿势时会重新扫描 `windows/assets/`，新增或替换同名 GIF 后会进入轮播序列。
- 修复 Windows 文件名数字排序，例如 `2.gif` 会排在 `10.gif` 前面。
- 调整默认性格：熊更温暖可爱，更像一只觉得自己领养了人的小熊。
- README 增加旧版本最小更新说明，提醒用户只替换代码文件并保留自己的 GIF 和图标。

## 2026-05-26

- 改进计时提醒：macOS 和 Windows 都会定期检查已过点提醒，减少睡眠、卡顿或弹窗导致的延迟。
- 修复询问当前时间时乱答的问题：熊会直接读取本机时间回答，并在普通聊天提示里带上当前时间。
- 修复 macOS 看屏幕不稳定：改为熊本体直接截图做 OCR，并在失败时显示具体原因。

## 2026-05-27

- 新增 Android 版：Flutter + Kotlin 原生悬浮桌宠，支持 GIF 皮肤管理、轮换和每日提醒。
- Android 版加入聊天功能：通过 DeepSeek API 和熊对话，API Key 保存在本地。
- Android 版通过 MethodChannel + 本地广播实现 Flutter 与原生悬浮窗通信。
- Android 版闹钟广播接收器添加 BOOT_COMPLETED 支持，重启后提醒不丢失。
- 修复 Android 多个安全隐患：移除不必要的电池优化权限、修复线程安全问题、补齐 ProGuard 规则。
- macOS 和 Windows 的 API Key 输入提示中补充了粘贴说明（⌘V / Ctrl+V）。
- 根目录 README 更新为三版本总入口（macOS + Windows + Android）。
- 创建三平台发布包：LazyBear-Android.apk / LazyBear-Windows.zip / LazyBear-macOS.zip，不含版权 GIF。
- macOS 和 Windows 版支持无 GIF 启动，显示占位提示界面，不再崩溃退出。
- macOS 构建脚本允许无 GIF 构建；Windows 版右键菜单新增「刷新 GIF」。
- 根目录 README 新增「普通用户下载」区块，引导用户去 Releases 页面而非 clone 源码。
- 每个发布包内含 README_普通用户版.md，覆盖下载、GIF 放置、启动和常见问题。
- 新增 Android APK 构建配置：compileSdk=36、disableCompileSdkChecks、coreLibraryDesugaring。
