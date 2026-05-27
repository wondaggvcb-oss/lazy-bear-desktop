import "package:flutter/material.dart";

class SettingsPage extends StatefulWidget {
  final int rotationInterval;

  const SettingsPage({super.key, this.rotationInterval = 10});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _rotationInterval;

  static const _options = {5: "5 秒", 10: "10 秒", 30: "30 秒", 60: "60 秒"};

  @override
  void initState() {
    super.initState();
    _rotationInterval = widget.rotationInterval;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("设置"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text("GIF 轮换间隔", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._options.entries.map((entry) {
            return RadioListTile<int>(
              title: Text(entry.value),
              subtitle: _rotationInterval == 0 ? const Text("当前：不轮换") : null,
              value: entry.key,
              groupValue: _rotationInterval,
              onChanged: (val) {
                if (val != null) {
                  setState(() => _rotationInterval = val);
                }
              },
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _rotationInterval = 0);
            },
            icon: const Icon(Icons.pause_circle_outline),
            label: const Text("不轮换"),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop(_rotationInterval);
            },
            icon: const Icon(Icons.check),
            label: const Text("保存"),
          ),
        ],
      ),
    );
  }
}
