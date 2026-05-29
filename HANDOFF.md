# 熊项目交接文档

这份文档给新的 Codex / ChatGPT 窗口快速接手用。

## 当前项目

- 项目名：熊 / lazy-bear-desktop
- GitHub 仓库：https://github.com/entity-cc/lazy-bear-desktop
- 本机路径：`/Users/liuliuliu/Documents/Codex/2026-05-13/cd/lazy-bear-desktop`
- 当前分支：`main`
- 当前本地状态：已与 `origin/main` 同步
- 最新提交：`0fd3999 Document minimal update steps`
- 应用名：`熊`

## 用户想要的熊

熊是一个桌面宠物，不是普通工具软件。

核心气质：

- 懒懒的
- 温暖可爱
- 一针见血
- 喜欢人类
- 觉得用户是被熊领养的人
- 熊不一定很有用，但会努力照顾好人
- 不要热血，不要油腻，不要长篇说教

聊天入口第一句固定显示：

```text
你好你好，有什么可以帮您
```

但后续回答不要每次机械重复这句。

## 当前功能

macOS 版：

- 桌面悬浮 GIF 熊
- 点击聊天
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

Windows 版：

- Python/Tkinter 桌面熊
- 桌面悬浮 GIF 熊
- 点击聊天
- 拖动移动
- 右键菜单
- 换姿势
- 记住偏好
- 设置熊性格
- 简单计时提醒
- 使用 DeepSeek API 聊天
- API Key 存本机用户数据目录
- 暂时不做看屏幕 OCR

## 重要目录

```text
README.md
CHANGELOG.md
macos/BearApp.swift
macos/build.sh
macos/README.md
macos/assets/
macos/Resources/
windows/bear_windows.py
windows/README.md
windows/assets/
windows/Resources/
```

## 素材规则

仓库不应该上传用户自己的 GIF 和图标。

这些目录是本机素材目录：

```text
macos/assets/
macos/Resources/
windows/assets/
windows/Resources/
```

当前本机状态：

- `macos/assets/` 有 35 个 GIF
- `windows/assets/` 有 35 个 GIF
- 桌面版 app 在 `/Users/liuliuliu/Desktop/熊.app`
- 桌面版 app 已经用这 35 个 GIF 重建过

`.gitignore` 已经忽略素材和构建产物。不要把 GIF、`.icns`、`.ico`、`.app`、`dist/` 上传到 GitHub。

## GIF 读取逻辑

之前的 bug：只支持固定文件名 `jokebear_idle.gif` 等，用户把新 GIF 拖进文件夹不会自动进入轮播。

现在的逻辑：

- macOS：构建时把 `macos/assets/` 里所有 `.gif` / `.GIF` 打包进 app。
- macOS：app 内按文件名顺序读取 `Contents/Resources/assets/` 里的所有 GIF。
- macOS：换姿势时会重新扫描 app bundle 里的 assets。
- Windows：运行时读取 `windows/assets/` 里所有 `.gif` / `.GIF`。
- Windows：换姿势或自动轮播时会重新扫描 assets。
- Windows：同名替换 GIF 后会根据修改时间和大小重新加载，不会卡旧缓存。
- Windows：数字排序已修复，`2.gif` 会排在 `10.gif` 前面。

控制轮播顺序的建议：

```text
001_idle.gif
002_eat.gif
003_lie.gif
```

## 本机 macOS 构建

构建：

```bash
cd /Users/liuliuliu/Documents/Codex/2026-05-13/cd/lazy-bear-desktop/macos
./build.sh
```

打开构建产物：

```bash
open dist/熊.app
```

覆盖桌面版：

```bash
pkill -f LazyBear || true
rm -rf /Users/liuliuliu/Desktop/熊.app
ditto /Users/liuliuliu/Documents/Codex/2026-05-13/cd/lazy-bear-desktop/macos/dist/熊.app /Users/liuliuliu/Desktop/熊.app
open /Users/liuliuliu/Desktop/熊.app
```

注意：如果只改 `macos/assets/`，也需要重新运行 `./build.sh`，因为 macOS app 使用的是打包进 `.app` 的资源。

## Windows 运行

Windows 版核心文件：

```text
windows/bear_windows.py
```

运行：

```powershell
cd windows
python bear_windows.py
```

如果用户是从测试包运行，确保 `assets/` 和 `Resources/` 与 `bear_windows.py` 在同级目录。

## 最小更新说明

README 已经补了“更新旧版本”。

给旧用户的最小替换：

```text
macOS：替换 macos/BearApp.swift 和 macos/build.sh，然后重新运行 ./build.sh
Windows：替换 windows/bear_windows.py，然后重新运行 python bear_windows.py
```

明确提醒用户不要删除：

```text
macos/assets/
macos/Resources/
windows/assets/
windows/Resources/
```

## GitHub 注意事项

已经成功推到 GitHub。

提交作者已经改成：

```text
wondaggvcb-oss <wondaggvcb-oss@users.noreply.github.com>
```

不要再用真实姓名提交。

本仓库本地 Git 配置已经设置：

```bash
git config user.name "wondaggvcb-oss"
git config user.email "wondaggvcb-oss@users.noreply.github.com"
```

如果之后要推更新：

```bash
cd /Users/liuliuliu/Documents/Codex/2026-05-13/cd/lazy-bear-desktop
git status
git add README.md CHANGELOG.md macos/BearApp.swift macos/build.sh macos/README.md windows/bear_windows.py windows/README.md
git commit -m "简短说明"
git push origin main
```

不要提交本机素材。

## 安全提醒

用户之前把 GitHub token 发到聊天里过。那个 token 应该视为泄露，需要在 GitHub 里 revoke。

以后不要让用户把 token、DeepSeek API Key 或其他密钥发到聊天窗口。

## 用户偏好

- 用户喜欢中文说明，面向中文用户。
- 说明要具体，不要只说“更新文件”，要告诉替换哪个文件、保留哪个文件夹。
- 用户很在意桌面美观，不能随便删 icon、GIF、桌面 app。
- 用户不喜欢像素丑熊，倾向使用自己下载的 GIF。
- 用户希望熊“像真的桌面宠物”，可爱、懒、暖，但不要烦人。
- 用户希望触控板可用，所以交互说明要包含点按、拖动、双指点/右键。
- 用户不想在 GitHub README 里强调版权问题，只说自己放 GIF / 图标。
- 用户不喜欢在 UI 和文案里用 emoji（比如 🐻），统一用纯文字「熊」代替。

## 发布包（2026-05-27 已完成）

发布包已创建，放在 `~/Desktop/lazy-bear-release/`：

| 目录 | 内容 |
|------|------|
| `LazyBear-Windows/` | `bear_windows.py` + `启动熊.bat` + `assets/占位文件` + `README_普通用户版.md` |
| `LazyBear-macOS/` | `熊.app`（占位模式，无 GIF）+ `README_普通用户版.md` |

桌面也有打好的 zip：
- `~/Desktop/LazyBear-Windows.zip`（10K）
- `~/Desktop/LazyBear-macOS.zip`（338K）

这些包**不含版权 GIF**，只有占位文件。用户拿到后自己放 GIF 进 assets 即可。

### 发布包要点

- **macOS 和 Windows 版都支持无 GIF 启动**，会显示占位提示而不是崩溃
- macOS 占位界面：棕色圆角方块 + "熊：请把你的 GIF 放进 assets 文件夹"
- Windows 占位界面：透明窗口 + 棕色文字提示，右键菜单有"刷新 GIF"
- 每个包内都有 `README_普通用户版.md`，写明了下载、GIF 放置、启动、API Key、常见问题

### 代码修改总结（本次发布相关）

- `macos/BearApp.swift`：`loadAssets()` 无 GIF 时不再退出，显示 `showPlaceholderBear()`
- `macos/build.sh`：允许无 GIF 构建，不再 `exit 1`
- `windows/bear_windows.py`：`resolve_assets()` 不抛异常，`show_empty_placeholder()` + `reload_all()` + 右键"刷新 GIF"
- 根 `README.md`：新增 📦 普通用户下载 区块，指向 GitHub Releases

### GitHub Release 创建步骤

1. Push 所有变更到 GitHub
2. 在 https://github.com/entity-cc/lazy-bear-desktop/releases 点 "Draft a new release"
3. Tag 版本号（如 `v1.1.0`），Release title 写 `熊 v1.1.0`
4. 上传文件：
   - `~/Desktop/LazyBear-Windows.zip`
   - `~/Desktop/LazyBear-macOS.zip`
5. 发布

## 下一步可能任务

可能会继续做：

- macOS app 快捷键更稳定，尤其是退出快捷键。
- "按熊心情换图"功能。可以先做开关，接 DeepSeek 让模型返回一个短心情标签，再映射到 GIF 文件名或随机图。
- 更自然的主动互动，不要频繁打扰。
- GitHub Release 自动化（GitHub Actions 构建 + 发布）。

先修 bug 优先，复杂 AI 心情功能可以后做。
