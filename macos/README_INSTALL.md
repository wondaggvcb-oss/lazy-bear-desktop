# LazyBear macOS 安装说明

## 先打开 App

解压 `LazyBear-macOS.zip` 后，双击整个 `LazyBear.app`。

不要进入下面这个位置直接双击 `LazyBear`：

```text
LazyBear.app/Contents/MacOS/LazyBear
```

那个是给 macOS 运行的程序文件，不是给人手动打开的入口。

## 如果提示无法验证开发者

1. 右键 `LazyBear.app`。
2. 选择 `打开`。
3. 再点一次 `打开`。

如果仍然打不开，到 `系统设置 -> 隐私与安全性`，在页面底部选择允许打开。

## 如果提示已损坏

打开终端，运行：

```bash
xattr -cr ~/Downloads/LazyBear-macOS/LazyBear.app
open ~/Downloads/LazyBear-macOS/LazyBear.app
```

如果你把 app 放到了别的位置，把命令里的路径换成实际位置。

## 放自己的 GIF

右键 `LazyBear.app`，选择 `显示包内容`，进入：

```text
Contents/Resources/assets
```

把自己的 `.gif` 放进去，然后重新打开 `LazyBear.app`。

可以只放一个 GIF，也可以放多个 GIF。多个 GIF 会按文件名顺序轮播。

## 聊天 Key

第一次聊天需要填自己的 DeepSeek API Key。Key 会保存在本机钥匙串里。

## 退出

按 `Command + Q`，或者右键熊选择退出。
