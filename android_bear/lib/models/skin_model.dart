import "dart:io";

class SkinModel {
  final String path;
  final String name;
  final int sizeBytes;

  const SkinModel({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  String get sizeDisplay {
    final mb = sizeBytes / (1024 * 1024);
    if (mb >= 1) {
      return "${mb.toStringAsFixed(1)} MB";
    }
    final kb = sizeBytes / 1024;
    return "${kb.toStringAsFixed(0)} KB";
  }

  bool get exists => File(path).existsSync();
}
