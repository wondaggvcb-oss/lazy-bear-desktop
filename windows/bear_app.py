"""
熊 / Lazy Bear Desktop - Windows 版
桌面宠物应用 - 优化版本
"""

import base64
import ctypes
import json
import os
import re
import sys
import threading
import time
import tkinter as tk
from ctypes import wintypes
from datetime import datetime
from pathlib import Path
from tkinter import messagebox, simpledialog, ttk
from urllib import error, request


# ───────────────────────────────────────────────────────────────
# 常量定义
# ───────────────────────────────────────────────────────────────

DEEPSEEK_URL = "https://api.deepseek.com/chat/completions"
APP_NAME = "熊"
APP_NAME_EN = "LazyBear"
VERSION = "1.1.0"

# 路径配置
APP_DIR = Path(os.getenv("APPDATA", Path.home())) / APP_NAME_EN
MEMORY_FILE = APP_DIR / "bear-memory.json"
CONFIG_FILE = APP_DIR / "config.json"
BASE_DIR = Path(sys.executable).resolve().parent if getattr(sys, "frozen", False) else Path(__file__).resolve().parent
ASSET_DIR = BASE_DIR / "assets"
ICON_PATH = BASE_DIR / "Resources" / "BearIcon.ico"

# 界面配置
TRANSPARENT_COLOR = "#00ff00"
MAX_SIDE = 170

# GIF 速度档位 (倍速 -> 基础延迟的除数)
SPEED_PRESETS = {
    "0.5x (慢速)": 0.5,
    "0.8x": 0.8,
    "1x (正常)": 1.0,
    "1.25x": 1.25,
    "1.5x": 1.5,
    "2x (快速)": 2.0,
}
DEFAULT_SPEED = "1x (正常)"
BASE_ANIMATION_DELAY = 90  # 基础动画延迟（毫秒）

# 系统提示词
SYSTEM_PROMPT = """你的名字叫熊，是一只懒懒但很温暖、很可爱的桌面小熊。
你非常喜欢人类，你觉得用户是被你领养的人：你要负责把他照顾好。
你不一定很有用，但你会认真、稳定地陪着，帮用户把事说清楚、做下去。
用户打开聊天时，界面会先替你问好："你好你好，有什么可以帮您。"
你的回答不要机械重复这句问候，除非用户主动要求。
回答要一针见血，少废话，但语气软一点、可爱一点。
不要热血，不要油腻，不要长篇安慰或说教；像刚睡醒但很聪明、很护短的小熊。
可以偶尔带一点颜文字。"""


# ───────────────────────────────────────────────────────────────
# Windows DPAPI 加密
# ───────────────────────────────────────────────────────────────

class _DATA_BLOB(ctypes.Structure):
    _fields_ = [("cbData", wintypes.DWORD), ("pbData", ctypes.POINTER(ctypes.c_ubyte))]


_crypt32 = ctypes.windll.crypt32
_crypt32.CryptProtectData.restype = wintypes.BOOL
_crypt32.CryptUnprotectData.restype = wintypes.BOOL
_kernel32 = ctypes.windll.kernel32
_kernel32.LocalFree.restype = ctypes.c_void_p

_CRYPTPROTECT_UI_FORBIDDEN = 0x1
_CRYPTPROTECT_LOCAL_MACHINE = 0x4


def _dpapi_encrypt(plain: bytes) -> bytes:
    data_in = _DATA_BLOB(len(plain), ctypes.cast(
        ctypes.create_string_buffer(plain, len(plain)), ctypes.POINTER(ctypes.c_ubyte)))
    data_out = _DATA_BLOB()
    ok = _crypt32.CryptProtectData(
        ctypes.byref(data_in), None, None, None, None,
        _CRYPTPROTECT_UI_FORBIDDEN | _CRYPTPROTECT_LOCAL_MACHINE,
        ctypes.byref(data_out),
    )
    if not ok:
        raise OSError("CryptProtectData failed")
    raw = ctypes.string_at(data_out.pbData, data_out.cbData)
    _kernel32.LocalFree(data_out.pbData)
    return raw


def _dpapi_decrypt(cipher: bytes) -> bytes:
    data_in = _DATA_BLOB(len(cipher), ctypes.cast(
        ctypes.create_string_buffer(cipher, len(cipher)), ctypes.POINTER(ctypes.c_ubyte)))
    data_out = _DATA_BLOB()
    ok = _crypt32.CryptUnprotectData(
        ctypes.byref(data_in), None, None, None, None,
        _CRYPTPROTECT_UI_FORBIDDEN | _CRYPTPROTECT_LOCAL_MACHINE,
        ctypes.byref(data_out),
    )
    if not ok:
        raise OSError("CryptUnprotectData failed")
    raw = ctypes.string_at(data_out.pbData, data_out.cbData)
    _kernel32.LocalFree(data_out.pbData)
    return raw


def _dpapi_encrypt_str(plain: str) -> str:
    return base64.b64encode(_dpapi_encrypt(plain.encode("utf-8"))).decode("ascii")


def _dpapi_decrypt_str(encoded: str) -> str:
    return _dpapi_decrypt(base64.b64decode(encoded.encode("ascii"))).decode("utf-8")


# ───────────────────────────────────────────────────────────────
# 工具函数
# ───────────────────────────────────────────────────────────────

def _natural_key(text):
    """自然排序键函数"""
    return [int(part) if part.isdigit() else part for part in re.split(r"(\d+)", text.lower())]


def check_environment():
    """检查运行环境是否满足要求"""
    errors = []
    warnings = []
    
    # 检查 Python 版本
    if sys.version_info < (3, 7):
        errors.append(f"Python 版本过低: {sys.version_info.major}.{sys.version_info.minor}，需要 3.7+")
    
    # 检查 tkinter
    try:
        import tkinter as tk
        tk.Tcl().eval("info patchlevel")
    except Exception as e:
        errors.append(f"tkinter 不可用: {e}")
    
    # 检查 assets 文件夹
    if not ASSET_DIR.exists():
        try:
            ASSET_DIR.mkdir(parents=True, exist_ok=True)
            warnings.append(f"已创建 assets 文件夹: {ASSET_DIR}")
        except Exception as e:
            errors.append(f"无法创建 assets 文件夹: {e}")
    
    # 检查 GIF 文件
    gifs = list(ASSET_DIR.glob("*.gif")) if ASSET_DIR.exists() else []
    if not gifs:
        warnings.append("assets 文件夹中没有 .gif 文件，熊将显示占位符")
    
    return errors, warnings


def show_error_dialog(title, message, details=""):
    """显示详细的错误对话框"""
    full_message = message
    if details:
        full_message += f"\n\n详细信息:\n{details}"
    
    try:
        root = tk.Tk()
        root.withdraw()
        messagebox.showerror(title, full_message)
        root.destroy()
    except Exception:
        # 如果连 tkinter 都不可用，使用 Windows MessageBox
        ctypes.windll.user32.MessageBoxW(0, full_message, title, 0x10)


# ───────────────────────────────────────────────────────────────
# 数据存储类
# ───────────────────────────────────────────────────────────────

class BearStore:
    """熊的数据存储管理器"""
    
    def __init__(self):
        self._ensure_app_dir()
        self.data = {
            "memories": [],
            "personality": "",
            "reminders": [],
            "config": {
                "gif_speed": DEFAULT_SPEED,
                "auto_switch": True,
                "auto_switch_interval": 16,  # 秒
            }
        }
        self._load()
    
    def _ensure_app_dir(self):
        """确保应用数据目录存在"""
        try:
            APP_DIR.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            print(f"警告: 无法创建应用目录 {APP_DIR}: {e}")
    
    def _load(self):
        """从文件加载数据"""
        if MEMORY_FILE.exists():
            try:
                loaded = json.loads(MEMORY_FILE.read_text(encoding="utf-8"))
                # 合并数据，保留默认值
                for key in self.data:
                    if key in loaded:
                        if isinstance(self.data[key], dict) and isinstance(loaded[key], dict):
                            self.data[key].update(loaded[key])
                        else:
                            self.data[key] = loaded[key]
            except json.JSONDecodeError as e:
                print(f"警告: 数据文件损坏，使用默认值: {e}")
            except Exception as e:
                print(f"警告: 无法读取数据文件: {e}")
    
    def save(self):
        """保存数据到文件"""
        try:
            self._ensure_app_dir()
            MEMORY_FILE.write_text(json.dumps(self.data, ensure_ascii=False, indent=2), encoding="utf-8")
        except Exception as e:
            print(f"错误: 无法保存数据: {e}")
    
    # 记忆管理
    def add_memory(self, text):
        self.data["memories"].append(text)
        self.save()
    
    def clear_memories(self):
        self.data["memories"] = []
        self.save()
    
    # 性格管理
    def set_personality(self, text):
        self.data["personality"] = text
        self.save()
    
    def clear_personality(self):
        self.data["personality"] = ""
        self.save()
    
    # 配置管理
    def get_config(self, key, default=None):
        return self.data["config"].get(key, default)
    
    def set_config(self, key, value):
        self.data["config"][key] = value
        self.save()
    
    # 计时器管理
    def get_reminders(self):
        return self.data.get("reminders", [])
    
    def set_reminders(self, reminders):
        self.data["reminders"] = reminders
        self.save()


# ───────────────────────────────────────────────────────────────
# 设置对话框
# ───────────────────────────────────────────────────────────────

class SettingsDialog:
    """设置对话框"""
    
    def __init__(self, parent, store, on_apply=None):
        self.store = store
        self.on_apply = on_apply
        
        self.dialog = tk.Toplevel(parent)
        self.dialog.title("熊的设置")
        self.dialog.geometry("350x250")
        self.dialog.resizable(False, False)
        self.dialog.transient(parent)
        self.dialog.grab_set()
        
        # 居中显示
        self.dialog.update_idletasks()
        x = parent.winfo_x() + (parent.winfo_width() - self.dialog.winfo_width()) // 2
        y = parent.winfo_y() + (parent.winfo_height() - self.dialog.winfo_height()) // 2
        self.dialog.geometry(f"+{x}+{y}")
        
        self._create_widgets()
        self._load_settings()
    
    def _create_widgets(self):
        """创建界面元素"""
        padding = {"padx": 15, "pady": 10}
        
        # GIF 速度设置
        tk.Label(self.dialog, text="GIF 播放速度:", font=("Microsoft YaHei", 10)).pack(anchor="w", **padding)
        
        self.speed_var = tk.StringVar()
        self.speed_combo = ttk.Combobox(
            self.dialog, 
            textvariable=self.speed_var,
            values=list(SPEED_PRESETS.keys()),
            state="readonly",
            width=20
        )
        self.speed_combo.pack(anchor="w", padx=15, pady=(0, 10))
        
        # 自动切换设置
        self.auto_switch_var = tk.BooleanVar()
        tk.Checkbutton(
            self.dialog,
            text="自动切换姿势",
            variable=self.auto_switch_var,
            font=("Microsoft YaHei", 10)
        ).pack(anchor="w", **padding)
        
        # 按钮
        btn_frame = tk.Frame(self.dialog)
        btn_frame.pack(fill="x", side="bottom", pady=15)
        
        tk.Button(btn_frame, text="确定", command=self._on_ok, width=10).pack(side="right", padx=5)
        tk.Button(btn_frame, text="取消", command=self.dialog.destroy, width=10).pack(side="right", padx=5)
    
    def _load_settings(self):
        """加载当前设置"""
        speed = self.store.get_config("gif_speed", DEFAULT_SPEED)
        if speed in SPEED_PRESETS:
            self.speed_var.set(speed)
        else:
            self.speed_var.set(DEFAULT_SPEED)
        
        self.auto_switch_var.set(self.store.get_config("auto_switch", True))
    
    def _on_ok(self):
        """确定按钮回调"""
        # 保存设置
        self.store.set_config("gif_speed", self.speed_var.get())
        self.store.set_config("auto_switch", self.auto_switch_var.get())
        
        # 应用设置
        if self.on_apply:
            self.on_apply()
        
        self.dialog.destroy()


# ───────────────────────────────────────────────────────────────
# 主应用类
# ───────────────────────────────────────────────────────────────

class BearApp:
    """熊桌面宠物主应用"""
    
    def __init__(self):
        self.store = BearStore()
        self.root = tk.Tk()
        self.root.title(APP_NAME)
        self._apply_window_icon()
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)
        self.root.configure(bg=TRANSPARENT_COLOR)
        
        # 设置透明色
        try:
            self.root.attributes("-transparentcolor", TRANSPARENT_COLOR)
        except tk.TclError:
            pass
        
        # 创建 UI
        self.label = tk.Label(self.root, bg=TRANSPARENT_COLOR, bd=0, highlightthickness=0)
        self.label.pack()
        
        # 创建菜单
        self._create_menu()
        
        # 初始化状态
        self.drag_start = None
        self.did_drag = False
        self.state_index = 0
        self.frames = {}
        self.frame_index = 0
        self.after_id = None
        self.timer_sweep_after_id = None
        self.reminder_after_ids = {}
        self.reminders = []
        self.last_bubble = None
        self.asset_paths = []
        self.first_run_tip_shown = False  # 是否已显示首次运行提示
        self.last_asset_count = 0  # 上次检测到的 GIF 数量
        
        # 加载资源（初始化时不显示错误提示）
        self.asset_paths = self._resolve_assets(show_error=False)
        self.last_asset_count = len(self.asset_paths)
        self.load_state(0)
        
        # 首次运行时如果没有 GIF，显示提示
        if not self.asset_paths:
            self._show_first_run_tip()
        
        self.move_to_bottom_right()
        self._bind_events()
        self._schedule_saved_reminders()
        self._schedule_due_timer_check()
        
        # 启动自动切换
        if self.store.get_config("auto_switch", True):
            self._schedule_auto_switch()
        
        # 启动 assets 文件夹监听
        self._schedule_asset_check()
    
    def _show_first_run_tip(self):
        """显示首次运行提示（只显示一次）"""
        if self.first_run_tip_shown:
            return
        self.first_run_tip_shown = True
        self.root.after(500, lambda: messagebox.showinfo(
            "欢迎使用熊 🐻",
            "请将自己的 .gif 动画文件放入 assets 文件夹，\n"
            "程序会自动检测并加载。\n\n"
            "支持多个 GIF 自动轮播！"
        ))
    
    def _schedule_asset_check(self):
        """调度 assets 文件夹检查（每 2 秒检查一次）"""
        self.root.after(2000, self._check_assets_change)
    
    def _check_assets_change(self):
        """检查 assets 文件夹是否有变化"""
        current_gifs = self._discover_assets()
        current_count = len(current_gifs)
        
        # 检测到新文件
        if current_count > self.last_asset_count and current_count > 0:
            # 如果之前没有 GIF，现在有了，自动加载
            if self.last_asset_count == 0:
                self._show_bubble("检测到 GIF 文件，正在加载...")
                self.reload_all()
            else:
                # 有新 GIF 添加
                self._show_bubble(f"检测到 {current_count - self.last_asset_count} 个新 GIF")
                self.reload_all()
        
        self.last_asset_count = current_count
        
        # 继续调度检查
        self._schedule_asset_check()
    
    def _apply_window_icon(self):
        """应用窗口图标"""
        if not ICON_PATH.exists():
            return
        try:
            self.root.iconbitmap(default=str(ICON_PATH))
        except tk.TclError:
            try:
                self.root.iconbitmap(str(ICON_PATH))
            except tk.TclError:
                pass
    
    def _create_menu(self):
        """创建右键菜单"""
        self.menu = tk.Menu(self.root, tearoff=0)
        
        # 主要功能
        self.menu.add_command(label="💬 聊天", command=self.start_chat)
        self.menu.add_command(label="🔄 换姿势", command=self.next_state)
        self.menu.add_command(label="↘️ 去右下角", command=self.move_to_bottom_right)
        self.menu.add_separator()
        
        # 记忆与性格
        self.menu.add_command(label="📝 记住偏好", command=self.remember_preference)
        self.menu.add_command(label="🎭 设置性格", command=self.set_personality)
        self.menu.add_command(label="👤 查看性格", command=self.show_personality)
        self.menu.add_command(label="🗑️ 清空性格", command=self.clear_personality)
        self.menu.add_command(label="📋 查看记忆", command=self.show_memory)
        self.menu.add_command(label="🗑️ 清空记忆", command=self.clear_memory)
        self.menu.add_separator()
        
        # 计时器
        self.menu.add_command(label="⏱️ 开始计时", command=self.start_timer)
        self.menu.add_command(label="⏰ 查看计时", command=self.show_timers)
        self.menu.add_command(label="🗑️ 清空计时", command=self.clear_timers)
        self.menu.add_separator()
        
        # 设置
        self.menu.add_command(label="⚙️ 设置", command=self.open_settings)
        self.menu.add_command(label="🔄 刷新 GIF", command=self.reload_all)
        self.menu.add_separator()
        
        # 退出
        self.menu.add_command(label="❌ 退出熊", command=self.quit)
    
    def _bind_events(self):
        """绑定事件处理"""
        self.label.bind("<ButtonPress-1>", self._start_drag)
        self.label.bind("<B1-Motion>", self._drag)
        self.label.bind("<ButtonRelease-1>", self._end_drag)
        self.label.bind("<Button-3>", self._show_menu)
        
        # 快捷键
        self.root.bind("<Escape>", lambda _event: self.quit())
        self.root.bind("<Control-q>", lambda _event: self.quit())
        self.root.bind("<Control-t>", lambda _event: self.start_chat())
        self.root.bind("<Control-n>", lambda _event: self.next_state())
        self.root.bind("<Control-m>", lambda _event: self.move_to_bottom_right())
        self.root.bind("<Control-r>", lambda _event: self.remember_preference())
        self.root.bind("<Control-p>", lambda _event: self.set_personality())
        self.root.bind("<Control-l>", lambda _event: self.show_memory())
        self.root.bind("<Control-i>", lambda _event: self.start_timer())
        self.root.bind("<Control-s>", lambda _event: self.open_settings())
    
    # ───────────────────────────────────────────────────────────
    # 资源管理
    # ───────────────────────────────────────────────────────────
    
    def _discover_assets(self):
        """发现 assets 文件夹中的 GIF 文件"""
        ASSET_DIR.mkdir(parents=True, exist_ok=True)
        gifs = [path for path in ASSET_DIR.iterdir() if path.is_file() and path.suffix.lower() == ".gif"]
        gifs.sort(key=lambda path: _natural_key(path.name))
        return gifs
    
    def _resolve_assets(self, show_error=False):
        """解析并返回可用的 GIF 资源"""
        gifs = self._discover_assets()
        if not gifs and show_error:
            messagebox.showinfo(
                "熊还没有 GIF", 
                "请把自己的 .gif 放进 assets 文件夹。\n放好后右键熊 → 刷新即可。"
            )
        return gifs
    
    def _refresh_assets(self):
        """刷新资源列表"""
        gifs = self._discover_assets()
        if not gifs:
            return False
        if gifs != self.asset_paths:
            self.asset_paths = gifs
            self.state_index %= len(self.asset_paths)
        return True
    
    def _load_gif_frames(self, path):
        """加载 GIF 的所有帧"""
        stat = path.stat()
        cache_key = (str(path), stat.st_mtime_ns, stat.st_size)
        if cache_key in self.frames:
            return self.frames[cache_key]
        
        raw_frames = []
        index = 0
        while True:
            try:
                raw_frames.append(tk.PhotoImage(file=str(path), format=f"gif -index {index}"))
                index += 1
            except tk.TclError:
                break
        
        if not raw_frames:
            raise RuntimeError(f"Cannot load GIF: {path}")
        
        first = raw_frames[0]
        factor = max(1, int(max(first.width(), first.height()) / MAX_SIDE + 0.999))
        frames = [frame.subsample(factor, factor) for frame in raw_frames]
        self.frames[cache_key] = frames
        return frames
    
    def load_state(self, index):
        """加载指定状态的 GIF"""
        self._refresh_assets()
        if not self.asset_paths:
            self._show_empty_placeholder()
            return
        
        self.state_index = index % len(self.asset_paths)
        last_error = None
        
        for offset in range(len(self.asset_paths)):
            candidate_index = (self.state_index + offset) % len(self.asset_paths)
            try:
                self.current_frames = self._load_gif_frames(self.asset_paths[candidate_index])
                self.state_index = candidate_index
                break
            except Exception as exc:
                last_error = exc
        else:
            self._show_empty_placeholder()
            return
        
        self.frame_index = 0
        if self.after_id:
            self.root.after_cancel(self.after_id)
        self._animate()
    
    def _animate(self):
        """播放 GIF 动画"""
        if not hasattr(self, 'current_frames') or not self.current_frames:
            return
        
        num_frames = len(self.current_frames)
        current_idx = self.frame_index % num_frames
        
        try:
            frame = self.current_frames[current_idx]
            self.label.configure(image=frame)
            self.label.image = frame
            self.root.geometry(f"{frame.width()}x{frame.height()}")
        except (IndexError, tk.TclError) as e:
            pass
        
        self.frame_index += 1
        if self.frame_index >= num_frames * 1000:
            self.frame_index = self.frame_index % num_frames
        
        speed_preset = self.store.get_config("gif_speed", DEFAULT_SPEED)
        speed_multiplier = SPEED_PRESETS.get(speed_preset, 1.0)
        delay = int(BASE_ANIMATION_DELAY / speed_multiplier)
        
        self.after_id = self.root.after(delay, self._animate)
    
    def _show_empty_placeholder(self):
        """显示空状态占位符"""
        if self.after_id:
            self.root.after_cancel(self.after_id)
        self.root.geometry("200x120")
        self.label.configure(
            image="", 
            text="🐻\n\n请把 .gif 文件\n放入 assets 文件夹\n\n右键 → 刷新 GIF", 
            font=("Microsoft YaHei", 10), 
            fg="#8B6914", 
            bg=TRANSPARENT_COLOR, 
            compound="center"
        )
        self.move_to_bottom_right()
    
    def reload_all(self):
        """重新扫描 assets 并刷新显示"""
        self.frames.clear()
        self.asset_paths = self._resolve_assets(show_error=True)
        if self.asset_paths:
            self.load_state(0)
        else:
            self._show_empty_placeholder()
    
    def next_state(self):
        """切换到下一个姿势"""
        if self.asset_paths:
            self.load_state(self.state_index + 1)
    
    def _schedule_auto_switch(self):
        """调度自动切换"""
        if not self.store.get_config("auto_switch", True):
            return
        interval = self.store.get_config("auto_switch_interval", 16) * 1000  # 转换为毫秒
        self.root.after(interval, self._auto_switch)
    
    def _auto_switch(self):
        """自动切换姿势"""
        if self.store.get_config("auto_switch", True):
            self.next_state()
            self._schedule_auto_switch()
    
    # ───────────────────────────────────────────────────────────
    # 交互功能
    # ───────────────────────────────────────────────────────────
    
    def _start_drag(self, event):
        """开始拖动"""
        self.root.lift()
        self.drag_start = (event.x_root, event.y_root, self.root.winfo_x(), self.root.winfo_y())
        self.did_drag = False
    
    def _drag(self, event):
        """拖动中"""
        if not self.drag_start:
            return
        start_x, start_y, win_x, win_y = self.drag_start
        dx = event.x_root - start_x
        dy = event.y_root - start_y
        if abs(dx) + abs(dy) > 4:
            self.did_drag = True
        self.root.geometry(f"+{win_x + dx}+{win_y + dy}")
    
    def _end_drag(self, _event):
        """结束拖动"""
        if not self.did_drag:
            self.start_chat()
        self.drag_start = None
    
    def _show_menu(self, event):
        """显示右键菜单"""
        self.menu.tk_popup(event.x_root, event.y_root)
    
    def move_to_bottom_right(self):
        """移动到屏幕右下角"""
        self.root.update_idletasks()
        width = self.root.winfo_width()
        height = self.root.winfo_height()
        screen_w = self.root.winfo_screenwidth()
        screen_h = self.root.winfo_screenheight()
        self.root.geometry(f"+{screen_w - width - 32}+{screen_h - height - 80}")
    
    # ───────────────────────────────────────────────────────────
    # 聊天功能
    # ───────────────────────────────────────────────────────────
    
    def start_chat(self):
        """开始聊天"""
        question = simpledialog.askstring("熊", "你好你好，有什么可以帮您", parent=self.root)
        if not question or not question.strip():
            return
        question = question.strip()
        if self._is_time_question(question):
            self.next_state()
            messagebox.showinfo("熊说：", self._local_time_answer())
            return
        key = self._ensure_api_key()
        if not key:
            return
        self.next_state()
        threading.Thread(target=self._ask_deepseek, args=(key, question, False), daemon=True).start()
    
    def _ensure_api_key(self):
        """确保 API Key 已配置"""
        key = self._get_api_key()
        if key:
            return key
        key = simpledialog.askstring(
            "DeepSeek API Key", 
            "第一次聊天需要输入 key。可直接粘贴 (Ctrl+V)。", 
            show="*", 
            parent=self.root
        )
        if key:
            config = self._read_config()
            config["api_key"] = key
            self._write_config(config)
        return key
    
    def _read_config(self):
        """读取配置"""
        if not CONFIG_FILE.exists():
            return {}
        try:
            data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
        except Exception:
            return {}
        # 迁移旧明文 api_key
        if "api_key" in data and data["api_key"] and "api_key_enc" not in data:
            try:
                data["api_key_enc"] = _dpapi_encrypt_str(data["api_key"])
                del data["api_key"]
                self._write_config_raw(data)
            except Exception:
                pass
        return data
    
    def _write_config(self, config):
        """写入配置（自动加密）"""
        if "api_key" in config and config["api_key"]:
            try:
                config["api_key_enc"] = _dpapi_encrypt_str(config["api_key"])
            except Exception:
                config["api_key_enc"] = config["api_key"]
            del config["api_key"]
        self._write_config_raw(config)
    
    def _write_config_raw(self, data):
        """直接写入配置"""
        APP_DIR.mkdir(parents=True, exist_ok=True)
        CONFIG_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    
    def _get_api_key(self):
        """获取 API Key"""
        env_key = os.getenv("DEEPSEEK_API_KEY")
        if env_key:
            return env_key
        data = self._read_config()
        enc = data.get("api_key_enc", "")
        if not enc:
            return ""
        try:
            return _dpapi_decrypt_str(enc)
        except Exception:
            return ""
    
    def _local_datetime_text(self):
        """获取本地时间文本"""
        now = datetime.now().astimezone()
        weekdays = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
        timezone_name = now.tzname() or ""
        return f"{now.year}年{now.month}月{now.day}日 {weekdays[now.weekday()]} {now:%H:%M:%S} {timezone_name}".strip()
    
    def _local_time_answer(self):
        """获取时间回答"""
        return f"现在是 {self._local_datetime_text()}。熊看的是你电脑时间，没瞎猜。"
    
    def _is_time_question(self, text):
        """判断是否是时间相关问题"""
        normalized = text.lower().replace(" ", "").replace("？", "?")
        patterns = [
            "几点", "几号", "星期几", "礼拜几", "日期", "现在时间",
            "当前时间", "当地时间", "现在是几", "今天几", "今天星期", "今天礼拜",
            "today", "date", "time", "whatday", "whattime",
        ]
        return any(pattern in normalized for pattern in patterns)
    
    def _system_prompt_with_memory(self):
        """构建带记忆的系统提示词"""
        parts = [
            SYSTEM_PROMPT,
            "当前本机时间：\n"
            f"{self._local_datetime_text()}\n"
            "如果用户询问时间、日期、星期或计时相关问题，必须以这个本机时间为准，不要猜测。",
        ]
        personality = self.store.data.get("personality", "").strip()
        memories = self.store.data.get("memories", [])[-20:]
        if personality:
            parts.append(f"用户自定义熊性格：\n{personality}")
        if memories:
            parts.append("用户偏好记忆：\n" + "\n".join(f"- {item}" for item in memories))
        parts.append("自定义性格优先于默认性格，但必须保留名字叫熊、回答简短、不要机械重复问候这几条底线。")
        return "\n\n".join(parts)
    
    def _ask_deepseek(self, api_key, question, bubble):
        """调用 DeepSeek API"""
        payload = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": self._system_prompt_with_memory()},
                {"role": "user", "content": question},
            ],
        }
        data = json.dumps(payload).encode("utf-8")
        req = request.Request(
            DEEPSEEK_URL,
            data=data,
            headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
            method="POST",
        )
        try:
            with request.urlopen(req, timeout=30) as response:
                result = json.loads(response.read().decode("utf-8"))
            answer = result["choices"][0]["message"]["content"]
            self.root.after(0, lambda: self._finish_answer(answer, bubble))
        except error.HTTPError as exc:
            text = exc.read().decode("utf-8", errors="ignore")
            self.root.after(0, lambda: messagebox.showerror("熊说不出来", text))
        except Exception as exc:
            self.root.after(0, lambda: messagebox.showerror("熊说不出来", str(exc)))
    
    def _finish_answer(self, answer, bubble):
        """完成回答"""
        if bubble:
            self._show_bubble(answer)
        else:
            messagebox.showinfo("熊说：", answer)
    
    # ───────────────────────────────────────────────────────────
    # 记忆与性格
    # ───────────────────────────────────────────────────────────
    
    def remember_preference(self):
        """记住用户偏好"""
        text = simpledialog.askstring("熊记一下", "写一条你的偏好或要求。", parent=self.root)
        if text and text.strip():
            self.store.add_memory(text.strip())
            self._show_bubble("记住了，熊的小本本+1。")
    
    def show_memory(self):
        """显示记忆"""
        memories = self.store.data.get("memories", [])
        if not memories:
            messagebox.showinfo("熊的记忆", "还没有记忆。熊脑袋空空，但很轻。")
            return
        messagebox.showinfo("熊的记忆", "\n".join(f"{i + 1}. {item}" for i, item in enumerate(memories)))
    
    def clear_memory(self):
        """清空记忆"""
        if messagebox.askyesno("清空记忆？", "熊会忘掉已记录的偏好。"):
            self.store.clear_memories()
            self._show_bubble("记忆清空了，熊重新开机。")
    
    def set_personality(self):
        """设置性格"""
        current = self.store.data.get("personality", "").strip()
        prompt = "写一段熊的人设/语气。比如：懒懒的，一针见血，但不要刻薄。"
        if current:
            prompt = f"当前性格：{current}\n\n写新的性格；留空就不改。"
        text = simpledialog.askstring("熊的性格", prompt, parent=self.root)
        if text and text.strip():
            self.store.set_personality(text.strip())
            self._show_bubble("性格改好了，熊会照着演。")
    
    def show_personality(self):
        """显示性格"""
        personality = self.store.data.get("personality", "").strip()
        messagebox.showinfo("熊的性格", personality or "还没有自定义性格。熊先按默认懒懒版本活着。")
    
    def clear_personality(self):
        """清空性格"""
        if messagebox.askyesno("清空性格？", "熊会回到默认懒懒版本。"):
            self.store.clear_personality()
            self._show_bubble("性格清空了，熊回默认档。")
    
    # ───────────────────────────────────────────────────────────
    # 计时器
    # ───────────────────────────────────────────────────────────
    
    def start_timer(self):
        """开始计时"""
        title = simpledialog.askstring("熊计时", "要提醒什么？比如：喝水、休息、看锅。", parent=self.root)
        if not title or not title.strip():
            return
        minutes_text = simpledialog.askstring("熊计时", "几分钟后提醒？只填数字，比如 25。", parent=self.root)
        try:
            minutes = float((minutes_text or "").strip().replace("，", "."))
            if minutes <= 0:
                raise ValueError
        except ValueError:
            messagebox.showerror("熊没看懂", "分钟数填数字就好。比如 10 或 25。")
            return
        reminder = {
            "id": str(time.time()),
            "title": title.strip(),
            "fire_at": time.time() + minutes * 60
        }
        self.reminders.append(reminder)
        self._schedule_timer(reminder)
        self._show_bubble(f"好，{minutes:g} 分钟后叫你。")
    
    def _schedule_saved_reminders(self):
        """调度已保存的提醒"""
        self.reminders = self.store.get_reminders()
        for reminder in list(self.reminders):
            if reminder.get("fire_at", 0) <= time.time():
                self._fire_timer(reminder)
            else:
                self._schedule_timer(reminder)
    
    def _schedule_timer(self, reminder):
        """调度单个提醒"""
        self.store.set_reminders(self.reminders)
        ms = max(100, int((reminder["fire_at"] - time.time()) * 1000))
        self.reminder_after_ids[reminder["id"]] = self.root.after(ms, lambda: self._fire_timer(reminder))
    
    def _schedule_due_timer_check(self):
        """调度到期检查"""
        self._check_due_timers()
        self.timer_sweep_after_id = self.root.after(5000, self._schedule_due_timer_check)
    
    def _check_due_timers(self):
        """检查到期的计时器"""
        now = time.time()
        for reminder in list(self.reminders):
            if reminder.get("fire_at", 0) <= now:
                self._fire_timer(reminder)
    
    def _fire_timer(self, reminder):
        """触发提醒"""
        rid = reminder.get("id")
        if not any(item.get("id") == rid for item in self.reminders):
            return
        if rid in self.reminder_after_ids:
            self.root.after_cancel(self.reminder_after_ids.pop(rid))
        self.reminders = [item for item in self.reminders if item.get("id") != rid]
        self.store.set_reminders(self.reminders)
        self.next_state()
        messagebox.showinfo("熊提醒你", f"{reminder.get('title', '到点了')}，到点了。")
    
    def show_timers(self):
        """显示计时器"""
        active = [item for item in self.reminders if item.get("fire_at", 0) > time.time()]
        if not active:
            messagebox.showinfo("熊的计时", "现在没有计时。熊也没被安排。")
            return
        lines = []
        for item in sorted(active, key=lambda value: value["fire_at"]):
            minutes = max(1, int((item["fire_at"] - time.time() + 59) // 60))
            lines.append(f"- {item['title']}：约 {minutes} 分钟后")
        messagebox.showinfo("熊的计时", "\n".join(lines))
    
    def clear_timers(self):
        """清空计时器"""
        if not messagebox.askyesno("清空计时？", "熊会取消所有还没到点的提醒。"):
            return
        for after_id in self.reminder_after_ids.values():
            self.root.after_cancel(after_id)
        self.reminder_after_ids.clear()
        self.reminders = []
        self.store.set_reminders([])
        self._show_bubble("计时都撤了，熊继续躺。")
    
    # ───────────────────────────────────────────────────────────
    # 设置
    # ───────────────────────────────────────────────────────────
    
    def open_settings(self):
        """打开设置对话框"""
        def on_apply():
            # 重新启动动画以应用新速度
            if self.after_id:
                self.root.after_cancel(self.after_id)
            self._animate()
            # 重新调度自动切换
            if hasattr(self, '_auto_switch_id') and self._auto_switch_id:
                self.root.after_cancel(self._auto_switch_id)
            self._schedule_auto_switch()
        
        SettingsDialog(self.root, self.store, on_apply)
    
    # ───────────────────────────────────────────────────────────
    # 气泡提示
    # ───────────────────────────────────────────────────────────
    
    def _show_bubble(self, text):
        """显示气泡提示"""
        if self.last_bubble and self.last_bubble.winfo_exists():
            self.last_bubble.destroy()
        bubble = tk.Toplevel(self.root)
        bubble.overrideredirect(True)
        bubble.attributes("-topmost", True)
        bubble.configure(bg="#111111")
        label = tk.Label(
            bubble, 
            text=text, 
            bg="#111111", 
            fg="white", 
            padx=12, 
            pady=8, 
            wraplength=280, 
            justify="left",
            font=("Microsoft YaHei", 9)
        )
        label.pack()
        x = max(20, self.root.winfo_x() - 310)
        y = max(20, self.root.winfo_y())
        bubble.geometry(f"+{x}+{y}")
        self.last_bubble = bubble
        bubble.after(8000, bubble.destroy)
    
    # ───────────────────────────────────────────────────────────
    # 生命周期
    # ───────────────────────────────────────────────────────────
    
    def quit(self):
        """退出应用"""
        self.store.set_reminders(self.reminders)
        self.store.save()
        if self.timer_sweep_after_id:
            self.root.after_cancel(self.timer_sweep_after_id)
        self.root.destroy()
    
    def run(self):
        """运行应用"""
        self.root.mainloop()


# ───────────────────────────────────────────────────────────────
# 启动器
# ───────────────────────────────────────────────────────────────

def main():
    """主入口函数"""
    # 检查环境
    errors, warnings = check_environment()
    
    # 显示警告
    for warning in warnings:
        print(f"[警告] {warning}")
    
    # 显示错误并退出
    if errors:
        error_details = "\n".join(f"- {e}" for e in errors)
        show_error_dialog(
            "启动失败",
            "熊无法启动，请检查以下问题:",
            error_details
        )
        sys.exit(1)
    
    # 启动应用
    try:
        app = BearApp()
        app.run()
    except Exception as e:
        import traceback
        show_error_dialog(
            "运行错误",
            "熊遇到了意外错误:",
            f"{e}\n\n{traceback.format_exc()}"
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
