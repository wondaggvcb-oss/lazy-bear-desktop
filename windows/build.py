"""
熊 / Lazy Bear Desktop - Windows 版打包脚本
使用 PyInstaller 生成独立的可执行文件
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path


def main():
    """主打包函数"""
    print("=" * 50)
    print("熊 / Lazy Bear Desktop - Windows 版打包工具")
    print("=" * 50)
    print()
    
    # 获取当前目录
    base_dir = Path(__file__).parent.resolve()
    os.chdir(base_dir)
    
    # 检查必要文件
    if not (base_dir / "bear_app.py").exists():
        print("[错误] 未找到 bear_app.py，请确保在正确的目录运行")
        sys.exit(1)
    
    # 检查 assets 文件夹
    assets_dir = base_dir / "assets"
    if not assets_dir.exists():
        print("[警告] assets 文件夹不存在，正在创建...")
        assets_dir.mkdir(exist_ok=True)
    
    gifs = list(assets_dir.glob("*.gif"))
    if not gifs:
        print("[警告] assets 文件夹中没有 .gif 文件")
        print("      建议先添加熊的 GIF 动画后再打包")
        response = input("是否继续打包? (y/n): ")
        if response.lower() != 'y':
            print("已取消打包")
            sys.exit(0)
    
    # 检查 PyInstaller
    print("[1/5] 检查 PyInstaller...")
    try:
        import PyInstaller
        print("      PyInstaller 已安装")
    except ImportError:
        print("      PyInstaller 未安装，正在安装...")
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "pyinstaller"],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            print(f"[错误] 安装 PyInstaller 失败:\n{result.stderr}")
            sys.exit(1)
        print("      PyInstaller 安装完成")
    
    # 清理旧的构建文件
    print("[2/5] 清理旧的构建文件...")
    dirs_to_clean = ['build', 'dist', '__pycache__']
    for dir_name in dirs_to_clean:
        dir_path = base_dir / dir_name
        if dir_path.exists():
            shutil.rmtree(dir_path)
            print(f"      已删除 {dir_name}/")
    
    # 清理 .spec 文件
    for spec_file in base_dir.glob("*.spec"):
        spec_file.unlink()
        print(f"      已删除 {spec_file.name}")
    
    # 构建命令
    print("[3/5] 配置打包选项...")
    
    # 收集资源文件
    datas = []
    if assets_dir.exists():
        datas.append(f"--add-data=assets{os.pathsep}assets")
    
    resources_dir = base_dir / "Resources"
    if resources_dir.exists():
        datas.append(f"--add-data=Resources{os.pathsep}Resources")
    
    # PyInstaller 参数
    cmd = [
        sys.executable, "-m", "PyInstaller",
        "--name=熊",
        "--onefile",
        "--windowed",
        "--noconfirm",
        "--clean",
        "--hidden-import=tkinter",
        "--hidden-import=tkinter.ttk",
    ] + datas + [
        "--icon=NONE",  # 使用默认图标，可以从 GIF 生成
        "bear_app.py"
    ]
    
    print(f"      命令: {' '.join(cmd)}")
    
    # 执行打包
    print("[4/5] 开始打包...")
    print("      这可能需要几分钟，请耐心等待...")
    print()
    
    result = subprocess.run(cmd, capture_output=False, text=True)
    
    if result.returncode != 0:
        print()
        print("[错误] 打包失败!")
        sys.exit(1)
    
    print()
    print("[5/5] 打包完成，整理输出文件...")
    
    # 创建发布目录
    dist_dir = base_dir / "dist"
    release_dir = dist_dir / "LazyBear-Windows"
    release_dir.mkdir(exist_ok=True)
    
    # 复制可执行文件
    exe_source = dist_dir / "熊.exe"
    exe_target = release_dir / "熊.exe"
    if exe_source.exists():
        shutil.copy2(exe_source, exe_target)
        print(f"      已复制: 熊.exe")
    
    # 复制 assets 文件夹（用于用户自定义）
    release_assets = release_dir / "assets"
    release_assets.mkdir(exist_ok=True)
    
    # 复制示例 GIF（如果有）
    if gifs:
        for gif in gifs:
            shutil.copy2(gif, release_assets / gif.name)
        print(f"      已复制 {len(gifs)} 个 GIF 到 assets/")
    
    # 创建启动脚本
    bat_content = '''@echo off
chcp 65001 >nul
title 熊
cd /d "%~dp0"
start "" "熊.exe"
'''
    (release_dir / "启动熊.bat").write_text(bat_content, encoding='utf-8')
    print("      已创建: 启动熊.bat")
    
    # 创建说明文件
    readme_content = '''熊 / Lazy Bear Desktop - Windows 版
================================

使用方法:
1. 双击 "启动熊.bat" 运行
   或直接双击 "熊.exe"

2. 自定义熊的动画:
   将自己的 .gif 文件放入 assets 文件夹
   支持多个 GIF 自动轮播

3. 快捷键:
   Ctrl+T - 聊天
   Ctrl+N - 换姿势
   Ctrl+M - 去右下角
   Ctrl+S - 设置
   Ctrl+Q 或 Esc - 退出

4. 右键熊可以打开菜单

注意:
- 首次聊天需要输入 DeepSeek API Key
- Key 会被加密保存在本地

版本: 1.1.0
'''
    (release_dir / "使用说明.txt").write_text(readme_content, encoding='utf-8')
    print("      已创建: 使用说明.txt")
    
    # 清理临时文件
    print("      清理临时文件...")
    if (dist_dir / "熊.exe").exists():
        (dist_dir / "熊.exe").unlink()
    
    # 创建压缩包
    print("      创建压缩包...")
    zip_path = dist_dir / "LazyBear-Windows"
    if zip_path.with_suffix('.zip').exists():
        zip_path.with_suffix('.zip').unlink()
    
    shutil.make_archive(
        str(zip_path),
        'zip',
        root_dir=dist_dir,
        base_dir='LazyBear-Windows'
    )
    
    print()
    print("=" * 50)
    print("打包完成!")
    print("=" * 50)
    print()
    print(f"输出目录: {release_dir}")
    print(f"压缩包:   {zip_path}.zip")
    print()
    print("文件列表:")
    for item in sorted(release_dir.iterdir()):
        size = item.stat().st_size if item.is_file() else ""
        size_str = f"({size / 1024:.1f} KB)" if size else ""
        print(f"  - {item.name} {size_str}")
    print()
    print("可以直接分发压缩包给用户!")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
        print("已取消")
        sys.exit(1)
    except Exception as e:
        print()
        print(f"[错误] {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
