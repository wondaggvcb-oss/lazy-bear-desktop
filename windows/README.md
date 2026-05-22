# Windows 版

Windows 版是一个 Python/Tkinter 桌面熊。

## 环境要求

- 适合 Windows 10 / 11 用户。
- 需要安装 Python 3。
- 聊天需要用户自己的 DeepSeek API Key。
- 熊图请自己放到 `windows/assets/`。
- 图标可选，放到 `windows/Resources/BearIcon.ico`。
- Windows 版暂时不做看屏幕 OCR。

## 使用

先进入 Windows 版本目录：

```powershell
cd windows
```

把自己的熊 GIF 放进 `windows/assets/`：

```powershell
mkdir assets
copy C:\Users\你的名字\Downloads\your-bear.gif assets\
```

运行：

```powershell
python bear_windows.py
```

如果你的电脑用的是 Python 启动器，也可以：

```powershell
py bear_windows.py
```

也可以双击测试包里的 `start-bear.bat`。

## 更新旧版本

如果你已经有旧版熊，最小更新只需要替换这个文件：

```text
windows/bear_windows.py
```

不要删除自己的素材：

```text
windows/assets/
windows/Resources/
```

替换后重新运行：

```powershell
cd windows
python bear_windows.py
```

如果你是用 Git 下载的，直接运行：

```powershell
git pull
cd windows
python bear_windows.py
```

## 多个姿势

把 GIF 放进 `assets/` 就行。熊会把 `assets/` 里所有 `.gif` 按文件名顺序读进来，然后循环播放。

只放一个 GIF 也可以；放多个 GIF 就会按顺序轮播。

运行中新增或替换 GIF 后，下次“换姿势”或自动轮播时会重新读取。

想控制轮播顺序，给文件名前面加编号最省事，比如：

```text
001_idle.gif
002_eat.gif
003_lie.gif
```

## 桌面图标

如果你有 `.ico` 图标文件，把它放到：

```text
Resources/BearIcon.ico
```

测试包里如果带了 `create-desktop-shortcut.bat`，双击它可以在桌面生成一个带图标的 **熊** 快捷方式。

## 功能

- 聊天
- 记住偏好
- 自定义熊的性格
- 简单计时
- 右键菜单
- 拖动移动

Windows 版暂时不做看屏幕 OCR，先保持开箱简单。

打开聊天时，熊会先问一句“你好你好，有什么可以帮您”。后续回答不会每次重复这句固定问候。

## 透明效果

Windows 版会尽量把窗口背景做成透明。

如果某些电脑上透明效果不完全一致，通常不是 GIF 放错了，而是 Windows 显示环境差异导致的。换一个透明背景 GIF 通常会更稳定。

## 快捷键

- `Ctrl+Q`：退出熊
- `Esc`：退出熊
- `Ctrl+T`：聊天
- `Ctrl+N`：换姿势
- `Ctrl+M`：去右下角
- `Ctrl+R`：记住偏好
- `Ctrl+P`：设置性格
- `Ctrl+L`：查看记忆
- `Ctrl+I`：开始计时

## 鼠标 / 触控板

- 点一下熊：聊天
- 按住拖动：移动熊
- 右键熊：打开菜单
