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
from tkinter import messagebox, simpledialog
from urllib import error, request


DEEPSEEK_URL = "https://api.deepseek.com/chat/completions"
APP_DIR = Path(os.getenv("APPDATA", Path.home())) / "LazyBearDesktop"
MEMORY_FILE = APP_DIR / "bear-memory.json"
CONFIG_FILE = APP_DIR / "config.json"
BASE_DIR = Path(sys.executable).resolve().parent if getattr(sys, "frozen", False) else Path(__file__).resolve().parent
ASSET_DIR = BASE_DIR / "assets"
ICON_PATH = BASE_DIR / "Resources" / "BearIcon.ico"
TRANSPARENT_COLOR = "#00ff00"
MAX_SIDE = 170


# ── Windows DPAPI 加密 ──────────────────────────────────────────
# 用当前用户身份加密/解密，不需要额外 pip 包。
# https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata

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
    desc = ctypes.c_void_p()
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


SYSTEM_PROMPT = """你的名字叫熊，是一只懒懒但很温暖、很可爱的桌面小熊。
你非常喜欢人类，你觉得用户是被你领养的人：你要负责把他照顾好。
你不一定很有用，但你会认真、稳定地陪着，帮用户把事说清楚、做下去。
用户打开聊天时，界面会先替你问好：“你好你好，有什么可以帮您。”
你的回答不要机械重复这句问候，除非用户主动要求。
回答要一针见血，少废话，但语气软一点、可爱一点。
不要热血，不要油腻，不要长篇安慰或说教；像刚睡醒但很聪明、很护短的小熊。
可以偶尔带一点颜文字。"""

def _natural_key(text):
    return [int(part) if part.isdigit() else part for part in re.split(r"(\d+)", text.lower())]


class BearStore:
    def __init__(self):
        APP_DIR.mkdir(parents=True, exist_ok=True)
        self.data = {"memories": [], "personality": "", "reminders": []}
        if MEMORY_FILE.exists():
            try:
                loaded = json.loads(MEMORY_FILE.read_text(encoding="utf-8"))
                self.data.update({k: loaded.get(k, self.data[k]) for k in self.data})
            except Exception:
                pass

    def save(self):
        APP_DIR.mkdir(parents=True, exist_ok=True)
        MEMORY_FILE.write_text(json.dumps(self.data, ensure_ascii=False, indent=2), encoding="utf-8")

    def add_memory(self, text):
        self.data["memories"].append(text)
        self.save()

    def clear_memories(self):
        self.data["memories"] = []
        self.save()

    def set_personality(self, text):
        self.data["personality"] = text
        self.save()

    def clear_personality(self):
        self.data["personality"] = ""
        self.save()


class BearApp:
    def __init__(self):
        self.store = BearStore()
        self.root = tk.Tk()
        self.root.title("熊")
        self.apply_window_icon()
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)
        self.root.configure(bg=TRANSPARENT_COLOR)
        try:
            self.root.attributes("-transparentcolor", TRANSPARENT_COLOR)
        except tk.TclError:
            pass

        self.label = tk.Label(self.root, bg=TRANSPARENT_COLOR, bd=0, highlightthickness=0)
        self.label.pack()

        self.menu = tk.Menu(self.root, tearoff=0)
        self.menu.add_command(label="聊天", command=self.start_chat)
        self.menu.add_command(label="换姿势", command=self.next_state)
        self.menu.add_command(label="去右下角", command=self.move_to_bottom_right)
        self.menu.add_separator()
        self.menu.add_command(label="记住偏好", command=self.remember_preference)
        self.menu.add_command(label="设置性格", command=self.set_personality)
        self.menu.add_command(label="查看性格", command=self.show_personality)
        self.menu.add_command(label="清空性格", command=self.clear_personality)
        self.menu.add_command(label="查看记忆", command=self.show_memory)
        self.menu.add_command(label="清空记忆", command=self.clear_memory)
        self.menu.add_separator()
        self.menu.add_command(label="开始计时", command=self.start_timer)
        self.menu.add_command(label="查看计时", command=self.show_timers)
        self.menu.add_command(label="清空计时", command=self.clear_timers)
        self.menu.add_separator()
        self.menu.add_command(label="刷新 GIF", command=self.reload_all)
        self.menu.add_separator()
        self.menu.add_command(label="退出熊", command=self.quit)

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
        self.asset_paths = self.resolve_assets(show_error=True)
        self.load_state(0)
        self.move_to_bottom_right()
        self.bind_events()
        self.schedule_saved_reminders()
        self.schedule_due_timer_check()
        self.root.after(16000, self.auto_next_state)

    def apply_window_icon(self):
        if not ICON_PATH.exists():
            return
        try:
            self.root.iconbitmap(default=str(ICON_PATH))
        except tk.TclError:
            try:
                self.root.iconbitmap(str(ICON_PATH))
            except tk.TclError:
                pass

    def discover_assets(self):
        ASSET_DIR.mkdir(parents=True, exist_ok=True)
        gifs = [path for path in ASSET_DIR.iterdir() if path.is_file() and path.suffix.lower() == ".gif"]
        gifs.sort(key=lambda path: _natural_key(path.name))
        return gifs

    def resolve_assets(self, show_error=False):
        gifs = self.discover_assets()
        if not gifs and show_error:
            messagebox.showinfo("熊还没有 GIF", "请把自己的 .gif 放进 assets 文件夹。\n放好后右键熊 → 刷新即可。")
        return gifs

    def refresh_assets(self):
        gifs = self.discover_assets()
        if not gifs:
            return False
        if gifs != self.asset_paths:
            self.asset_paths = gifs
            self.state_index %= len(self.asset_paths)
        return True

    def bind_events(self):
        self.label.bind("<ButtonPress-1>", self.start_drag)
        self.label.bind("<B1-Motion>", self.drag)
        self.label.bind("<ButtonRelease-1>", self.end_drag)
        self.label.bind("<Button-3>", self.show_menu)
        self.root.bind("<Escape>", lambda _event: self.quit())
        self.root.bind("<Control-q>", lambda _event: self.quit())
        self.root.bind("<Control-t>", lambda _event: self.start_chat())
        self.root.bind("<Control-n>", lambda _event: self.next_state())
        self.root.bind("<Control-m>", lambda _event: self.move_to_bottom_right())
        self.root.bind("<Control-r>", lambda _event: self.remember_preference())
        self.root.bind("<Control-p>", lambda _event: self.set_personality())
        self.root.bind("<Control-l>", lambda _event: self.show_memory())
        self.root.bind("<Control-i>", lambda _event: self.start_timer())

    def load_gif_frames(self, path):
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
        self.refresh_assets()
        if not self.asset_paths:
            self.show_empty_placeholder()
            return
        self.state_index = index % len(self.asset_paths)
        last_error = None
        for offset in range(len(self.asset_paths)):
            candidate_index = (self.state_index + offset) % len(self.asset_paths)
            try:
                self.current_frames = self.load_gif_frames(self.asset_paths[candidate_index])
                self.state_index = candidate_index
                break
            except Exception as exc:
                last_error = exc
        else:
            self.show_empty_placeholder()
            return
        self.frame_index = 0
        if self.after_id:
            self.root.after_cancel(self.after_id)
        self.animate()

    def animate(self):
        frame = self.current_frames[self.frame_index % len(self.current_frames)]
        self.label.configure(image=frame)
        self.label.image = frame
        self.root.geometry(f"{frame.width()}x{frame.height()}")
        self.frame_index += 1
        self.after_id = self.root.after(90, self.animate)

    def show_empty_placeholder(self):
        if self.after_id:
            self.root.after_cancel(self.after_id)
        self.root.geometry("170x170")
        self.label.configure(image="", text="熊\n请把 GIF\n放进 assets 文件夹", font=("Microsoft YaHei", 12), fg="#8B6914", bg=TRANSPARENT_COLOR, compound="center")
        self.move_to_bottom_right()

    def reload_all(self):
        """重新扫描 assets 并刷新显示（用户放好 GIF 后使用）"""
        self.frames.clear()
        self.asset_paths = self.resolve_assets(show_error=True)
        if self.asset_paths:
            self.load_state(0)
        else:
            self.show_empty_placeholder()

    def next_state(self):
        if self.asset_paths:
            self.load_state(self.state_index + 1)

    def auto_next_state(self):
        self.next_state()
        self.root.after(16000, self.auto_next_state)

    def move_to_bottom_right(self):
        self.root.update_idletasks()
        width = self.root.winfo_width()
        height = self.root.winfo_height()
        screen_w = self.root.winfo_screenwidth()
        screen_h = self.root.winfo_screenheight()
        self.root.geometry(f"+{screen_w - width - 32}+{screen_h - height - 80}")

    def start_drag(self, event):
        self.root.lift()
        self.drag_start = (event.x_root, event.y_root, self.root.winfo_x(), self.root.winfo_y())
        self.did_drag = False

    def drag(self, event):
        if not self.drag_start:
            return
        start_x, start_y, win_x, win_y = self.drag_start
        dx = event.x_root - start_x
        dy = event.y_root - start_y
        if abs(dx) + abs(dy) > 4:
            self.did_drag = True
        self.root.geometry(f"+{win_x + dx}+{win_y + dy}")

    def end_drag(self, _event):
        if not self.did_drag:
            self.start_chat()
        self.drag_start = None

    def show_menu(self, event):
        self.menu.tk_popup(event.x_root, event.y_root)

    def start_chat(self):
        question = simpledialog.askstring("熊", "你好你好，有什么可以帮您", parent=self.root)
        if not question or not question.strip():
            return
        question = question.strip()
        if self.is_time_question(question):
            self.next_state()
            messagebox.showinfo("熊说：", self.local_time_answer())
            return
        key = self.ensure_api_key()
        if not key:
            return
        self.next_state()
        threading.Thread(target=self.ask_deepseek, args=(key, question, False), daemon=True).start()

    def ensure_api_key(self):
        key = self._get_api_key()
        if key:
            return key
        key = simpledialog.askstring("DeepSeek API Key", "第一次聊天需要输入 key。可直接粘贴 (Ctrl+V)。", show="*", parent=self.root)
        if key:
            config = self.read_config()
            config["api_key"] = key  # write_config 会自动加密
            self.write_config(config)
        return key

    def read_config(self):
        """读取 config，自动解密 api_key_enc / 迁移旧明文。"""
        if not CONFIG_FILE.exists():
            return {}
        try:
            data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
        except Exception:
            return {}
        # ── 迁移旧明文 api_key ──
        if "api_key" in data and data["api_key"] and "api_key_enc" not in data:
            try:
                data["api_key_enc"] = _dpapi_encrypt_str(data["api_key"])
                del data["api_key"]
                self.write_config_raw(data)
            except Exception:
                pass
        return data

    def write_config(self, config):
        """保存 config，api_key 自动加密为 api_key_enc 后删除明文。"""
        if "api_key" in config and config["api_key"]:
            try:
                config["api_key_enc"] = _dpapi_encrypt_str(config["api_key"])
            except Exception:
                config["api_key_enc"] = config["api_key"]
            del config["api_key"]
        self.write_config_raw(config)

    def write_config_raw(self, data):
        """不加密直接写入（仅 read_config 迁移用）。"""
        APP_DIR.mkdir(parents=True, exist_ok=True)
        CONFIG_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    def _get_api_key(self):
        """优先环境变量，其次加密 config。"""
        env_key = os.getenv("DEEPSEEK_API_KEY")
        if env_key:
            return env_key
        data = self.read_config()
        enc = data.get("api_key_enc", "")
        if not enc:
            return ""
        try:
            return _dpapi_decrypt_str(enc)
        except Exception:
            return ""

    def local_datetime_text(self):
        now = datetime.now().astimezone()
        weekdays = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
        timezone_name = now.tzname() or ""
        return f"{now.year}年{now.month}月{now.day}日 {weekdays[now.weekday()]} {now:%H:%M:%S} {timezone_name}".strip()

    def local_time_answer(self):
        return f"现在是 {self.local_datetime_text()}。熊看的是你电脑时间，没瞎猜。"

    def is_time_question(self, text):
        normalized = text.lower().replace(" ", "").replace("？", "?")
        patterns = [
            "几点",
            "几号",
            "星期几",
            "礼拜几",
            "日期",
            "现在时间",
            "当前时间",
            "当地时间",
            "现在是几",
            "今天几",
            "今天星期",
            "今天礼拜",
            "today",
            "date",
            "time",
            "whatday",
            "whattime",
        ]
        return any(pattern in normalized for pattern in patterns)

    def system_prompt_with_memory(self):
        parts = [
            SYSTEM_PROMPT,
            "当前本机时间：\n"
            f"{self.local_datetime_text()}\n"
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

    def ask_deepseek(self, api_key, question, bubble):
        payload = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": self.system_prompt_with_memory()},
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
            self.root.after(0, lambda: self.finish_answer(answer, bubble))
        except error.HTTPError as exc:
            text = exc.read().decode("utf-8", errors="ignore")
            self.root.after(0, lambda: messagebox.showerror("熊说不出来", text))
        except Exception as exc:
            self.root.after(0, lambda: messagebox.showerror("熊说不出来", str(exc)))

    def finish_answer(self, answer, bubble):
        if bubble:
            self.show_bubble(answer)
        else:
            messagebox.showinfo("熊说：", answer)

    def remember_preference(self):
        text = simpledialog.askstring("熊记一下", "写一条你的偏好或要求。", parent=self.root)
        if text and text.strip():
            self.store.add_memory(text.strip())
            self.show_bubble("记住了，熊的小本本+1。")

    def show_memory(self):
        memories = self.store.data.get("memories", [])
        if not memories:
            messagebox.showinfo("熊的记忆", "还没有记忆。熊脑袋空空，但很轻。")
            return
        messagebox.showinfo("熊的记忆", "\n".join(f"{i + 1}. {item}" for i, item in enumerate(memories)))

    def clear_memory(self):
        if messagebox.askyesno("清空记忆？", "熊会忘掉已记录的偏好。"):
            self.store.clear_memories()
            self.show_bubble("记忆清空了，熊重新开机。")

    def set_personality(self):
        current = self.store.data.get("personality", "").strip()
        prompt = "写一段熊的人设/语气。比如：懒懒的，一针见血，但不要刻薄。"
        if current:
            prompt = f"当前性格：{current}\n\n写新的性格；留空就不改。"
        text = simpledialog.askstring("熊的性格", prompt, parent=self.root)
        if text and text.strip():
            self.store.set_personality(text.strip())
            self.show_bubble("性格改好了，熊会照着演。")

    def show_personality(self):
        personality = self.store.data.get("personality", "").strip()
        messagebox.showinfo("熊的性格", personality or "还没有自定义性格。熊先按默认懒懒版本活着。")

    def clear_personality(self):
        if messagebox.askyesno("清空性格？", "熊会回到默认懒懒版本。"):
            self.store.clear_personality()
            self.show_bubble("性格清空了，熊回默认档。")

    def start_timer(self):
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
        reminder = {"id": str(time.time()), "title": title.strip(), "fire_at": time.time() + minutes * 60}
        self.reminders.append(reminder)
        self.schedule_timer(reminder)
        self.show_bubble(f"好，{minutes:g} 分钟后叫你。")

    def schedule_saved_reminders(self):
        self.reminders = self.store.data.get("reminders", [])
        for reminder in list(self.reminders):
            if reminder.get("fire_at", 0) <= time.time():
                self.fire_timer(reminder)
            else:
                self.schedule_timer(reminder)

    def schedule_timer(self, reminder):
        self.store.data["reminders"] = self.reminders
        self.store.save()
        ms = max(100, int((reminder["fire_at"] - time.time()) * 1000))
        self.reminder_after_ids[reminder["id"]] = self.root.after(ms, lambda: self.fire_timer(reminder))

    def schedule_due_timer_check(self):
        self.check_due_timers()
        self.timer_sweep_after_id = self.root.after(5000, self.schedule_due_timer_check)

    def check_due_timers(self):
        now = time.time()
        for reminder in list(self.reminders):
            if reminder.get("fire_at", 0) <= now:
                self.fire_timer(reminder)

    def fire_timer(self, reminder):
        rid = reminder.get("id")
        if not any(item.get("id") == rid for item in self.reminders):
            return
        if rid in self.reminder_after_ids:
            self.root.after_cancel(self.reminder_after_ids.pop(rid))
        self.reminders = [item for item in self.reminders if item.get("id") != rid]
        self.store.data["reminders"] = self.reminders
        self.store.save()
        self.next_state()
        messagebox.showinfo("熊提醒你", f"{reminder.get('title', '到点了')}，到点了。")

    def show_timers(self):
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
        if not messagebox.askyesno("清空计时？", "熊会取消所有还没到点的提醒。"):
            return
        for after_id in self.reminder_after_ids.values():
            self.root.after_cancel(after_id)
        self.reminder_after_ids.clear()
        self.reminders = []
        self.store.data["reminders"] = []
        self.store.save()
        self.show_bubble("计时都撤了，熊继续躺。")

    def show_bubble(self, text):
        if self.last_bubble and self.last_bubble.winfo_exists():
            self.last_bubble.destroy()
        bubble = tk.Toplevel(self.root)
        bubble.overrideredirect(True)
        bubble.attributes("-topmost", True)
        bubble.configure(bg="#111111")
        label = tk.Label(bubble, text=text, bg="#111111", fg="white", padx=12, pady=8, wraplength=280, justify="left")
        label.pack()
        x = max(20, self.root.winfo_x() - 310)
        y = max(20, self.root.winfo_y())
        bubble.geometry(f"+{x}+{y}")
        self.last_bubble = bubble
        bubble.after(8000, bubble.destroy)

    def quit(self):
        self.store.data["reminders"] = self.reminders
        self.store.save()
        if self.timer_sweep_after_id:
            self.root.after_cancel(self.timer_sweep_after_id)
        self.root.destroy()

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    BearApp().run()
