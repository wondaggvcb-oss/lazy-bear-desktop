# 熊 / lazy-bear-desktop

一个桌面宠物项目。GitHub 仓库叫 `lazy-bear-desktop`，应用默认叫 **熊**。

熊会飘在桌面上，可以聊天、换姿势、移动到角落，也可以记住用户偏好、设置自己的性格、做简单计时。macOS 版还可以在你手动开启后读取屏幕文字，然后主动说一句短话。

这个仓库分成两个版本：

- [macOS 版](macos/README.md)
- [Windows 版](windows/README.md)

仓库默认不自带熊图。使用前，把自己的 GIF 放到对应系统的 `assets/` 文件夹里即可。

## 快速领养熊

### macOS

```bash
cd macos
mkdir -p assets
cp ~/Downloads/your-bear.gif assets/
./build.sh
open dist/熊.app
```

macOS 版会生成：

```text
macos/dist/熊.app
```

如果没有单独准备图标，构建时会自动从 GIF 抽第一帧生成 app 图标。

### Windows

```powershell
cd windows
mkdir assets
copy C:\Users\你的名字\Downloads\your-bear.gif assets\
python bear_windows.py
```

如果你的电脑用的是 Python 启动器，也可以：

```powershell
py bear_windows.py
```

Windows 版也可以放本地图标：

```text
windows/Resources/BearIcon.ico
```

## 环境要求

### macOS

- macOS
- Xcode Command Line Tools
- 聊天需要用户自己的 DeepSeek API Key
- “看屏幕/停下”需要手动开启屏幕录制权限

如果还没装过 Xcode Command Line Tools，可以运行：

```bash
xcode-select --install
```

### Windows

- Windows 10 / 11
- Python 3
- 聊天需要用户自己的 DeepSeek API Key

Windows 版暂时不做看屏幕 OCR，先保持简单可跑。

## 多个姿势

只放一个 GIF 也可以，熊的所有姿势都会用这一个 GIF。

想让熊有不同状态，可以把 GIF 按下面这些名字放进对应系统的 `assets/`：

```text
jokebear_idle.gif
jokebear_eat.gif
jokebear_love.gif
jokebear_car.gif
jokebear_kiss.gif
jokebear_lie.gif
jokebear_wave.gif
```

不需要全部都有。缺少的状态会自动复用已有 GIF。

## 图标

### macOS

默认不用额外准备图标。运行 `./build.sh` 时，如果没有 `Resources/BearIcon.icns`，脚本会自动从熊 GIF 生成 app 图标。

如果你有自己的 `.icns` 图标，把它放到：

```text
macos/Resources/BearIcon.icns
```

### Windows

Windows 图标是可选的。如果你有自己的 `.ico` 图标，把它放到：

```text
windows/Resources/BearIcon.ico
```

没有图标也能运行，只是快捷方式或窗口图标可能会使用默认样式。

## 功能

- 桌面悬浮熊
- GIF 动图状态
- 聊天
- 记住用户偏好
- 自定义熊的性格
- 简单计时提醒
- macOS 手动开启看屏幕

## 聊天

第一次聊天时，熊会让你输入 DeepSeek API Key。

- macOS 版会保存到系统钥匙串。
- Windows 版会保存到本机用户数据目录。

之后再打开熊，一般不需要重复输入。

## 记忆

菜单里选择 **记住偏好**，可以让熊记下一条用户偏好或要求。

比如：

```text
回答短一点
提醒我别熬夜
语气懒一点，不要太热血
```

之后聊天时，熊会参考这些记忆。也可以用 **查看记忆**、**清空记忆** 管理它。

## 自定义性格

菜单里选择 **设置性格**，可以自己写熊的人设和说话方式。

比如：

```text
懒懒的，一针见血，少废话，但不要刻薄。
```

之后聊天时，熊会按这个性格说话。也可以用 **查看性格**、**清空性格** 管理它。

## 计时

菜单里选择 **开始计时**，输入提醒内容和分钟数即可。

到点后熊会弹出提醒。也可以用 **查看计时**、**清空计时** 管理还没到点的计时。

## 看屏幕

这个功能目前只在 macOS 版里做了。

“看屏幕/停下”默认关闭。只有你手动开启后，熊才会申请屏幕录制权限。开启后，它会隔一段时间读一次当前屏幕文字，然后主动说一句短话。

不开权限也可以使用熊，只是不能读取屏幕内容。

## 快捷键

macOS 使用 `⌘`，Windows 使用 `Ctrl`。

- `Q`：退出熊
- `T`：聊天
- `N`：换姿势
- `M`：去右下角
- `R`：记住偏好
- `P`：设置性格
- `L`：查看记忆
- `I`：开始计时

macOS 版额外支持：

- `⌘S`：看屏幕 / 停下

## 鼠标 / 触控板

- 点一下熊：聊天
- 按住拖动：移动熊
- macOS 双指点熊：打开菜单
- Windows 右键熊：打开菜单

## 常见问题

### 没有 GIF 怎么办？

把自己的 `.gif` 放进对应系统的 `assets/` 再运行。

```text
macos/assets/
windows/assets/
```

### 没有图标怎么办？

macOS 不用管，会自动从 GIF 生成图标。Windows 可以不放图标，也可以自己放 `windows/Resources/BearIcon.ico`。

### 怎么退出？

macOS 按 `⌘Q` 或 `Esc`。Windows 按 `Ctrl+Q` 或 `Esc`。也可以打开熊的菜单，选择“退出熊”。
