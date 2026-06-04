# 熊 Windows 版使用说明

这是一只 Windows 桌面熊。不要在 Python 的 `>>>` 窗口里输入文件路径，那样会报 `SyntaxError`。

## 第一次打开

1. 先把压缩包完整解压。
2. 打开解压出来的文件夹。
3. 双击 `启动熊.bat`。
4. 如果熊出现了，就成功了。

如果想放到桌面，双击 `创建桌面快捷方式.bat`，以后从桌面的“熊”打开就行。

## 如果打开后出现 Python 3.2.2 和 >>>

这不是熊坏了，是电脑打开到了很旧的 Python 交互窗口。

请直接关掉那个黑窗口，然后回到熊的文件夹，双击：

```text
启动熊.bat
```

如果 `启动熊.bat` 提示 Python 太旧，请安装 Python 3.10 或更新版本：

```text
https://www.python.org/downloads/windows/
```

安装时记得勾选：

```text
Add python.exe to PATH
```

装好以后再双击 `启动熊.bat`。

## 如果聊天说不出来

先看弹窗提示。

如果提示 API Key 可能输错、过期，或者余额/权限不对：

1. 右键熊。
2. 点 `重设 API Key`。
3. 粘贴新的 DeepSeek API Key。
4. 再点熊聊天。

如果只是临时网络错误，等一下再问就行。

## 熊图在哪里

熊的 GIF 放在：

```text
app/assets/
```

想换熊图，把自己的 `.gif` 放进去就行。放多个 GIF 时，熊会按文件名顺序轮播。

想控制顺序，可以这样命名：

```text
001_idle.gif
002_eat.gif
003_lie.gif
```

## 图标在哪里

图标放在：

```text
app/Resources/BearIcon.ico
```

没有图标也能用，只是快捷方式图标可能比较普通。

## 怎么用

- 点一下熊：聊天
- 按住熊拖动：移动熊
- 右键熊：打开菜单
- 右键菜单里的 `重设 API Key`：key 输错或过期时用
- `Ctrl + Q`：退出熊
- `Esc`：退出熊
- `Ctrl + N`：换姿势
- `Ctrl + T`：聊天
- `Ctrl + I`：开始计时

第一次聊天时，需要输入自己的 DeepSeek API Key。这个 key 会保存在本机。

熊回答后会问要不要继续聊。点“是”继续，点“否”关掉这一轮聊天。
