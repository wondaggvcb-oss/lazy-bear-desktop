import "package:flutter/material.dart";

import "../models/skin_model.dart";

class SkinPicker extends StatelessWidget {
  final List<SkinModel> skins;
  final int currentIndex;
  final void Function(int index) onSelect;
  final void Function(int index) onRemove;
  final VoidCallback onUpload;

  const SkinPicker({
    super.key,
    required this.skins,
    required this.currentIndex,
    required this.onSelect,
    required this.onRemove,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Row(
        children: [
          // 已上传的皮肤
          ...skins.asMap().entries.take(3).map((entry) {
            final i = entry.key;
            final skin = entry.value;
            final isSelected = i == currentIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => onSelect(i),
                onLongPress: () => _confirmRemove(context, i, skin.name),
                child: Container(
                  width: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                      width: isSelected ? 2.5 : 1,
                    ),
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                        : Colors.grey.shade50,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.gif_box, size: 36, color: Color(0xFF8B6914)),
                      const SizedBox(height: 6),
                      Text(
                        skin.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        skin.sizeDisplay,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                      if (isSelected)
                        Text(
                          "当前皮肤",
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // 上传按钮
          if (skins.length < 3)
            GestureDetector(
              onTap: onUpload,
              child: Container(
                width: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 32, color: Colors.grey.shade400),
                    const SizedBox(height: 6),
                    Text(
                      "上传一个你喜欢的GIF 吧～",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, int index, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("删除皮肤"),
        content: Text("确定要删除「$name」吗？"),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("算了")),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onRemove(index);
            },
            child: const Text("删除"),
          ),
        ],
      ),
    );
  }
}
