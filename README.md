# 熊 / lazy-bear-desktop

一个桌面宠物项目。GitHub 仓库叫 `lazy-bear-desktop`，应用默认叫 **熊**。

熊会飘在桌面上，可以聊天、换姿势、移动到角落，也可以记住用户偏好、设置自己的性格、做简单计时。macOS 版还可以在你手动开启后读取屏幕文字，然后主动说一句短话。

这个仓库分成三个版本：

- [macOS 版](macos/README.md)
- [Windows 版](windows/README.md)
- [Android 版](android_bear/README.md)

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

### Android

Android 版需要用 Android Studio 打开 `android_bear/` 构建：

```bash
cd android_bear
flutter pub get
flutter build apk --debug
```

把生成的 APK 装到手机上，打开 App 按引导授予悬浮窗权限即可。

> **注意：** 聊天功能第一版不做，先做悬浮宠 + 每日提醒。悬浮窗需要手动在系统设置里开启。

## 旧版本如何更新

如果你已经有旧版熊，不想重新折腾全部文件，可以只更新代码，自己的熊图和图标不用动。

会用 Git 的用户，在仓库目录运行：

```bash
git pull
```

macOS 用户拉完后需要重新构建：

```bash
cd macos
./build.sh
open dist/熊.app
```

Windows 用户拉完后直接重新运行：

```powershell
cd windows
python bear_windows.py
```

不会用 Git 的用户，可以最小替换这些文件：

```text
macOS：替换 macos/BearApp.swift 和 macos/build.sh，然后重新运行 ./build.sh
Windows：替换 windows/bear_windows.py，然后重新运行 python bear_windows.py
```

不要删除自己的这些文件夹：

```text
macos/assets/
macos/Resources/
windows/assets/
windows/Resources/
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

### Android

- Android 8.0 及以上
- 电脑上需要 Flutter + Android SDK 才能构建
- 手机上需要手动开启「悬浮窗权限」
- 聊天功能 v1 不做

## 多个姿势

把 GIF 放进 `assets/` 就行。熊会把 `assets/` 里所有 `.gif` 按文件名顺序读进来，然后循环播放。

只放一个 GIF 也可以；放多个 GIF 就会按顺序轮播。

macOS 改完 GIF 后重新运行 `./build.sh`。Windows 运行中新增或替换 GIF 后，下次“换姿势”或自动轮播时会重新读取。

想控制轮播顺序，最简单的方法是给文件名前面加编号，比如：

```text
001_发呆.gif
002_吃饭.gif
003_躺平.gif
```

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

打开聊天时，熊会先问一句“你好你好，有什么可以帮您”。后续回答不会每次重复这句固定问候。

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

Android 版没有键盘快捷键，所有操作通过主页面按钮和触摸完成。

## 鼠标 / 触控板

- 点一下熊：聊天
- 按住拖动：移动熊
- macOS 双指点熊：打开菜单
- Windows 右键熊：打开菜单
- Android 点击悬浮熊：打开 App 主页
- Android 拖动悬浮熊：移动位置

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

macOS 按 `⌘Q` 或 `Esc`。Windows 按 `Ctrl+Q` 或 `Esc`。也可以打开熊的菜单，选择"退出熊"。

Android 在 App 主页关闭「悬浮熊」开关即可隐藏。要彻底退出，在 App 内返回退出或从最近任务中划掉。

### Android 悬浮窗权限在哪里开？

通常路径是：系统设置 → 应用 → 熊 → 权限 → 悬浮窗 / 在其他应用上层显示。不同手机路径略有差异，第一次打开 App 时也会有引导。

### Android 聊天什么时候做？

v1 先不做。后续版本考虑加上，届时会和 macOS/Windows 一样使用 DeepSeek API。
