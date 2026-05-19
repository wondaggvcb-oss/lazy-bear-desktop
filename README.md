# 熊

一个 macOS 桌面宠物。GitHub 仓库叫 `lazy-bear-desktop`，生成出来的应用叫 **熊**。

熊会飘在桌面上，可以聊天、换姿势、移动到角落。你手动开启后，它也可以看屏幕文字，然后主动说一句短话。

## 一分钟开始

先把自己的熊 GIF 放进 `assets/` 文件夹：

```bash
mkdir -p assets
cp ~/Downloads/your-bear.gif assets/
```

然后构建：

```bash
./build.sh
```

打开熊：

```bash
open dist/熊.app
```

如果 `assets/` 里只有一个 GIF，熊的所有姿势都会用这一个 GIF。

## 多个姿势

想让熊有不同状态，可以把 GIF 按下面这些名字放进 `assets/`：

```text
assets/jokebear_idle.gif
assets/jokebear_eat.gif
assets/jokebear_love.gif
assets/jokebear_car.gif
assets/jokebear_kiss.gif
assets/jokebear_lie.gif
assets/jokebear_wave.gif
```

不需要全部都有。缺少的状态会自动复用已有 GIF。

## 桌面图标

图标自己放。

如果你有 `.icns` 图标文件，把它放到：

```text
Resources/BearIcon.icns
```

没有图标也没关系，app 仍然叫 **熊**。

## 需要什么

- macOS
- Xcode Command Line Tools

如果还没装过，可以运行：

```bash
xcode-select --install
```

## 聊天

第一次聊天时，熊会让你输入 DeepSeek API Key，并保存到系统钥匙串。

之后再打开熊，一般不需要重复输入。

## 看屏幕

“看屏幕/停下”默认关闭。

只有你手动开启后，熊才会申请屏幕录制权限。开启后，它会隔一段时间读一次当前屏幕文字，然后主动说一句短话。

## 快捷键

- `⌘Q`：退出熊
- `Esc`：退出熊
- `⌘T`：聊天
- `⌘N`：换姿势
- `⌘M`：去右下角
- `⌘S`：看屏幕 / 停下

## 触控板

- 点一下熊：聊天
- 按住拖动：移动熊
- 双指点熊：打开菜单

## 生成位置

构建完成后，应用会出现在：

```text
dist/熊.app
```

你可以把它拖到桌面、应用程序文件夹，或者直接在当前位置打开。

## 常见问题

### 没有 GIF 怎么办？

把自己的 `.gif` 放进 `assets/` 再运行 `./build.sh`。

### 没有图标怎么办？

不用管。app 仍然叫 **熊**。

### 怎么退出？

按 `⌘Q` 或 `Esc`。也可以双指点熊，选择“退出熊”。
