# macOS 版

生成出来的应用叫 **熊**。

## 环境要求

- 适合 macOS 用户。
- 需要能运行本机 `.app`，或能在终端里运行 `./build.sh`。
- 聊天需要用户自己的 DeepSeek API Key。
- “看屏幕/停下”需要手动开启屏幕录制权限。
- 熊图请自己放到 `macos/assets/`。
- 默认会从 GIF 自动生成 app 图标；也可以自己放 `.icns` 图标覆盖。

## 使用

把自己的熊 GIF 放进 `macos/assets/`：

```bash
mkdir -p assets
cp ~/Downloads/your-bear.gif assets/
```

构建：

```bash
./build.sh
```

打开：

```bash
open dist/熊.app
```

## 多个姿势

把 GIF 放进 `assets/` 就行。熊会把 `assets/` 里所有 `.gif` 按文件名顺序读进来，然后循环播放。

只放一个 GIF 也可以；放多个 GIF 就会按顺序轮播。

改完 `assets/` 后重新运行 `./build.sh`，新的 GIF 就会打包进 `dist/熊.app`。

想控制轮播顺序，给文件名前面加编号最省事，比如：

```text
001_idle.gif
002_eat.gif
003_lie.gif
```

## App 图标

默认不用额外准备图标。

运行 `./build.sh` 时，如果没有 `Resources/BearIcon.icns`，脚本会自动从 `assets/` 里的熊 GIF 抽第一帧，生成 app 图标。

如果你有 `.icns` 图标文件，把它放到：

```text
Resources/BearIcon.icns
```

这样会优先使用你自己的图标。

## 权限

第一次使用“看屏幕/停下”时，macOS 可能会要求开启屏幕录制权限。

路径一般是：

```text
系统设置 -> 隐私与安全性 -> 屏幕录制
```

不开这个权限也可以使用熊，只是不能读取屏幕内容。

## 功能

- 聊天
- 记住偏好
- 自定义熊的性格
- 简单计时
- 手动开启看屏幕

打开聊天时，熊会先问一句“你好你好，有什么可以帮您”。后续回答不会每次重复这句固定问候。

## 快捷键

- `⌘Q`：退出熊
- `Esc`：退出熊
- `⌘T`：聊天
- `⌘N`：换姿势
- `⌘M`：去右下角
- `⌘S`：看屏幕 / 停下
- `⌘R`：记住偏好
- `⌘P`：设置性格
- `⌘L`：查看记忆
- `⌘I`：开始计时

## 触控板

- 点一下熊：聊天
- 按住拖动：移动熊
- 双指点熊：打开菜单
