import "package:flutter/services.dart";

class FloatService {
  static const _channel = MethodChannel("com.example.bear/float_service");

  /// 显示悬浮熊
  static Future<bool> showBear({
    List<String> skinPaths = const [],
    bool placeholder = false,
  }) async {
    final result = await _channel.invokeMethod<bool>("showBear", {
      "skinPaths": skinPaths,
      "placeholder": placeholder,
    });
    return result ?? false;
  }

  /// 隐藏悬浮熊
  static Future<void> hideBear() async {
    await _channel.invokeMethod("hideBear");
  }

  /// 更换当前 GIF 皮肤
  static Future<void> updateSkin(String path) async {
    await _channel.invokeMethod("updateSkin", {"path": path});
  }

  /// 显示占位气泡（无 GIF 时）
  static Future<void> showPlaceholder() async {
    await _channel.invokeMethod("showPlaceholder");
  }

  /// 开始轮换（interval 为秒）
  static Future<void> startRotation(int intervalSeconds, {List<String> skinPaths = const []}) async {
    await _channel.invokeMethod("startRotation", {
      "interval": intervalSeconds,
      "skinPaths": skinPaths,
    });
  }

  /// 停止轮换
  static Future<void> stopRotation() async {
    await _channel.invokeMethod("stopRotation");
  }

  /// 设置每日提醒
  static Future<void> setReminder(int hour, int minute) async {
    await _channel.invokeMethod("setReminder", {
      "hour": hour,
      "minute": minute,
    });
  }

  /// 取消提醒
  static Future<void> cancelReminder() async {
    await _channel.invokeMethod("cancelReminder");
  }

  /// 检查悬浮窗权限是否已授予
  static Future<bool> hasOverlayPermission() async {
    final result = await _channel.invokeMethod<bool>("hasOverlayPermission");
    return result ?? false;
  }

  /// 请求悬浮窗权限（打开系统设置页面）
  static Future<void> requestOverlayPermission() async {
    await _channel.invokeMethod("requestOverlayPermission");
  }

  /// 与熊聊天（DeepSeek API）
  static Future<String?> chatWithBear({
    required String apiKey,
    required String question,
    String personality = "",
  }) async {
    try {
      final result = await _channel.invokeMethod<String>("chatWithBear", {
        "apiKey": apiKey,
        "question": question,
        "personality": personality,
      });
      return result;
    } on PlatformException catch (e) {
      return "熊说不出来：${e.message}";
    } catch (e) {
      return "熊短暂离线：$e";
    }
  }
}
