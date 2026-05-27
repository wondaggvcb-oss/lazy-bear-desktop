import "dart:io";

import "package:flutter/material.dart";
import "package:path_provider/path_provider.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../services/float_service.dart";
import "../models/skin_model.dart";
import "../widgets/skin_picker.dart";
import "settings_page.dart";
import "chat_page.dart";

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _bearEnabled = false;
  List<SkinModel> _skins = [];
  int _currentSkinIndex = 0;
  int _rotationInterval = 10;
  int _reminderHour = 0;
  int _reminderMinute = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bearEnabled = prefs.getBool("bear_enabled") ?? false;
      _currentSkinIndex = prefs.getInt("current_skin_index") ?? 0;
      _rotationInterval = prefs.getInt("rotation_interval") ?? 10;
      _reminderHour = prefs.getInt("reminder_hour") ?? 0;
      _reminderMinute = prefs.getInt("reminder_minute") ?? 0;
    });
    await _loadSkins();
  }

  Future<void> _loadSkins() async {
    final dir = Directory("${(await _appDir).path}/skins");
    if (!dir.existsSync()) return;

    final files = dir.listSync().whereType<File>().where((f) {
      final name = f.path.toLowerCase();
      return name.endsWith(".gif");
    }).toList();

    setState(() {
      _skins = files.map((f) {
        return SkinModel(
          path: f.path,
          name: f.uri.pathSegments.last,
          sizeBytes: f.lengthSync(),
        );
      }).toList();
    });
  }

  Future<Directory> get _appDir async {
    final dir = await _getSkinsDir();
    return dir.parent;
  }

  Future<Directory> _getSkinsDir() async {
    final appDir = Directory("${(await _getBaseDir()).path}/skins");
    if (!appDir.existsSync()) {
      appDir.createSync(recursive: true);
    }
    return appDir;
  }

  Future<Directory> _getBaseDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory("${appDir.path}/bear_data");
  }

  Future<void> _toggleBear(bool value) async {
    if (value) {
      final hasPermission = await FloatService.hasOverlayPermission();
      if (!hasPermission) {
        await FloatService.requestOverlayPermission();
        final granted = await FloatService.hasOverlayPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("请先授予悬浮窗权限，再开启熊～"),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      final paths = _skins.map((s) => s.path).toList();
      final ok = await FloatService.showBear(
        skinPaths: paths,
        placeholder: _skins.isEmpty,
      );
      if (ok && _skins.isNotEmpty && _skins.length > 1 && _rotationInterval > 0) {
        await FloatService.startRotation(_rotationInterval, skinPaths: paths);
      }
    } else {
      await FloatService.stopRotation();
      await FloatService.hideBear();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("bear_enabled", value);
    setState(() => _bearEnabled = value);
  }

  Future<void> _uploadGif() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("选择 GIF 文件（file_picker 将在真机/模拟器上运行）")),
      );
    }
  }

  Future<void> _selectSkin(int index) async {
    if (index >= _skins.length) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("current_skin_index", index);
    setState(() => _currentSkinIndex = index);

    if (_bearEnabled) {
      await FloatService.updateSkin(_skins[index].path);
    }
  }

  Future<void> _removeSkin(int index) async {
    if (index >= _skins.length) return;
    final file = File(_skins[index].path);
    if (file.existsSync()) {
      file.deleteSync();
    }
    await _loadSkins();
    if (_currentSkinIndex >= _skins.length) {
      final newIndex = _skins.isEmpty ? 0 : _skins.length - 1;
      await _selectSkin(newIndex);
    }
    if (_skins.isEmpty && _bearEnabled) {
      await FloatService.stopRotation();
      await FloatService.showPlaceholder();
    }
  }

  void _openSettings() async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => SettingsPage(rotationInterval: _rotationInterval)),
    );
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt("rotation_interval", result);
      setState(() => _rotationInterval = result);
      if (_bearEnabled && _skins.length > 1) {
        final paths = _skins.map((s) => s.path).toList();
        await FloatService.stopRotation();
        await FloatService.startRotation(result, skinPaths: paths);
      }
    }
  }

  void _openChat() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🐻 熊"),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: _openChat,
            tooltip: "和熊聊天",
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: "设置",
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── 悬浮熊开关 ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.pets, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("悬浮熊", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        Text(
                          _bearEnabled ? "熊正在桌面上" : "熊在休息",
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Switch(value: _bearEnabled, onChanged: _toggleBear),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── 皮肤管理 ──
          Text("我的皮肤", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          SkinPicker(
            skins: _skins,
            currentIndex: _currentSkinIndex,
            onSelect: _selectSkin,
            onRemove: _removeSkin,
            onUpload: _uploadGif,
          ),

          const SizedBox(height: 24),

          // ── 每日提醒 ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.alarm, size: 22),
                      const SizedBox(width: 10),
                      const Text("每日提醒", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _pickReminderTime(context),
                        child: Text(
                          _reminderHour == 0 && _reminderMinute == 0
                              ? "设置时间"
                              : "${_reminderHour.toString().padLeft(2, "0")}:${_reminderMinute.toString().padLeft(2, "0")}",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReminderTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
    );
    if (time == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("reminder_hour", time.hour);
    await prefs.setInt("reminder_minute", time.minute);
    setState(() {
      _reminderHour = time.hour;
      _reminderMinute = time.minute;
    });

    await FloatService.setReminder(time.hour, time.minute);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("每天 ${time.hour.toString().padLeft(2, "0")}:${time.minute.toString().padLeft(2, "0")} 熊会提醒你"),
        ),
      );
    }
  }
}
