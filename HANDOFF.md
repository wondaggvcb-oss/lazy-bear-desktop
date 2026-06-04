# 熊项目维护说明

这份文档记录项目结构、维护约定和最近改动，方便之后继续开发。

## 项目概况

- 项目名：熊 / lazy-bear-desktop
- GitHub 仓库：https://github.com/wondaggvcb-oss/lazy-bear-desktop
- 默认应用名：`熊`
- 当前主要平台：macOS、Windows
- 默认分支：`main`

仓库只放代码和说明文档，不内置个人 GIF、图标和构建产物。

## 熊的设定

熊是桌面宠物，不是传统工具软件。

默认性格：

- 懒懒的
- 温暖可爱
- 一针见血
- 喜欢人类
- 觉得人是被熊领养的
- 不一定很有用，但会认真照顾人
- 不热血，不油腻，不长篇说教

聊天入口第一句固定显示：

```text
你好你好，有什么可以帮您
```

后续回答不要机械重复这句。

## 当前功能

macOS 版：

- 桌面悬浮 GIF 熊
- 点击聊天，支持连续对话
- 拖动移动
- 双指点 / 右键打开菜单
- 换姿势
- 移到右下角
- 记住偏好
- 设置熊性格
- 查看 / 清空记忆
- 简单计时提醒
- 手动开启“看屏幕/停下”
- 使用 DeepSeek API 聊天
- API Key 存进 macOS 钥匙串
- DeepSeek key 失效时会清掉旧 key，并提示重新输入

Windows 版：

- Python/Tkinter 桌面熊
- 桌面悬浮 GIF 熊
- 点击聊天，支持连续对话
- 拖动移动
- 右键菜单
- 换姿势
- 记住偏好
- 设置熊性格
- 简单计时提醒
- 使用 DeepSeek API 聊天
- API Key 存本机用户数据目录
- 右键菜单支持“重设 API Key”
- `start-bear.bat` 检查 Python 版本并启动熊
- `create-desktop-shortcut.bat` 创建桌面快捷方式
- 暂时不做看屏幕 OCR

## 最近改动

2026-06-04：

- macOS 修复台前调度下的焦点问题。熊换姿势、显示气泡和计时检查时不再反复成为 key window。
- macOS 浮窗增加 `.stationary` 和 `.ignoresCycle` 行为，减少被台前调度收进后台的情况。
- macOS 只在主动打开聊天、确认框、计时设置等弹窗时激活应用。
- macOS 和 Windows 都支持连续聊天。回答后可以选择继续聊或关掉，继续时保留最近上下文。
- Windows 新增 `start-bear.bat`，避免误进 Python `>>>` 后把文件路径当代码输入。
- Windows 新增 `README_普通用户版.md`，说明解压、启动、放 GIF、安装新版 Python、重设 API Key。
- Windows 新增 `create-desktop-shortcut.bat`。
- Windows 右键菜单新增“重设 API Key”。

## 重要文件

```text
README.md
CHANGELOG.md
HANDOFF.md
macos/BearApp.swift
macos/build.sh
macos/entitlements.plist
macos/README.md
windows/bear_windows.py
windows/README.md
windows/README_普通用户版.md
windows/start-bear.bat
windows/create-desktop-shortcut.bat
```

本机素材目录：

```text
macos/assets/
macos/Resources/
windows/assets/
windows/Resources/
```

这些素材目录默认不提交。

## 素材规则

仓库不内置个人 GIF 和图标。

不要提交：

```text
*.gif
*.GIF
*.ico
*.icns
*.app
dist/
*.zip
```

使用者自己把 GIF 放进对应平台的 `assets/` 文件夹即可。

## GIF 读取逻辑

当前逻辑：

- macOS：构建时把 `macos/assets/` 里所有 `.gif` / `.GIF` 打包进 app。
- macOS：app 内按文件名顺序读取 `Contents/Resources/assets/` 里的所有 GIF。
- macOS：换姿势时会重新扫描 app bundle 里的 assets。
- Windows：运行时读取 `windows/assets/` 里所有 `.gif` / `.GIF`。
- Windows：换姿势或自动轮播时会重新扫描 assets。
- Windows：同名替换 GIF 后会根据修改时间和大小重新加载。
- Windows：数字排序已处理，`2.gif` 会排在 `10.gif` 前面。

控制轮播顺序可以给文件名前面加编号：

```text
001_idle.gif
002_eat.gif
003_lie.gif
```

## macOS 构建

```bash
cd macos
./build.sh
open dist/熊.app
```

如果只改 `macos/assets/`，也需要重新运行 `./build.sh`，因为 macOS app 使用的是打包进 `.app` 的资源。

覆盖本机桌面版时可以这样做：

```bash
osascript -e 'tell application "熊" to quit' >/dev/null 2>&1 || true
rm -rf ~/Desktop/熊.app
cp -R macos/dist/熊.app ~/Desktop/熊.app
open ~/Desktop/熊.app
```

## Windows 运行

源码目录里推荐：

```powershell
cd windows
start-bear.bat
```

也可以手动运行：

```powershell
python bear_windows.py
```

发布给非开发者时，建议结构：

```text
熊/
启动熊.bat
创建桌面快捷方式.bat
先看我.txt
app/
  bear_windows.py
  assets/
  Resources/
```

`start-bear.bat` 同时兼容源码目录和 `app/` 子目录结构。

## 旧版本最小更新

macOS：

```text
替换 macos/BearApp.swift 和 macos/build.sh，然后重新运行 ./build.sh
```

Windows：

```text
替换 windows/bear_windows.py、windows/start-bear.bat 和 windows/README_普通用户版.md，然后重新运行 start-bear.bat
```

不要删除：

```text
macos/assets/
macos/Resources/
windows/assets/
windows/Resources/
```

## 验证方式

macOS：

```bash
cd macos
./build.sh
open dist/熊.app
```

重点检查：

- 台前调度开启时点熊聊天，输入停留超过 5 秒不应丢焦点。
- 熊回答后点“继续聊”，应能接上上一句上下文。
- 点“关掉”后，熊回到桌面悬浮状态。
- 换姿势、气泡和计时检查不应抢走其他 app 的输入焦点。

Windows：

```bash
python3 -m py_compile windows/bear_windows.py
```

重点检查：

- 双击 `start-bear.bat` 能启动。
- Python 太旧时会给中文提示。
- 右键“重设 API Key”能重新保存 key。
- 回答后选择继续聊能带上下文。

## 提交注意

提交作者使用：

```text
wondaggvcb-oss <wondaggvcb-oss@users.noreply.github.com>
```

提交前检查：

```bash
git status
git diff --stat
git diff --cached --stat
```

只提交代码和文档，不提交本机素材、构建产物和密钥。

## 文案习惯

- 面向中文使用者，说明要具体。
- 少用抽象介绍，多写实际操作步骤。
- 不强调素材来源，只说明“自己放 GIF / 图标”。
- 不使用表情符号。
- 用「熊」称呼应用，不用额外拟物符号。
