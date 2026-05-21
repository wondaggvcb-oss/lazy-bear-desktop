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
