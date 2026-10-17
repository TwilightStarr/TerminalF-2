import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/alert_rules.dart';

/// Bildirim gönderen katmanın arayüzü (testlerde sahtesi kullanılır).
abstract class Notifier {
  Future<void> init();
  Future<bool> hasPermission();
  Future<bool> requestPermission();

  /// Bir işlem bitince gönderilir. Uygulama ön plandayken gönderilmez
  /// (kullanıcı sonucu zaten ekranda görüyor).
  Future<void> showTask({required String title, required String body});

  /// Sağlık uyarısı (ısınma, depolama, pil, bellek).
  Future<void> showAlert(AlertEvent event);

  /// Kullanıcının "bildirimi dene" düğmesi için: ön planda da gösterilir.
  Future<void> showTest();
}

const String _taskChannelId = 'tasks';
const String _alertChannelId = 'alerts';
const String _statIcon = '@drawable/ic_stat_notify';

/// `flutter_local_notifications` tabanlı gerçek uygulama. Her çağrı
/// hataya karşı korunur: bildirim gönderilemezse uygulama etkilenmez.
class NotificationService implements Notifier {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  @override
  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings(_statIcon),
        ),
      );
      _ready = true;
    } catch (_) {
      // Platform desteklemiyorsa (test, masaüstü) sessizce yok say.
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      return await Permission.notification.isGranted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  bool get _inForeground =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  Future<void> showTask({required String title, required String body}) async {
    if (_inForeground) return;
    await _show(1, title, body, _taskChannelId, 'İşlem sonuçları',
        'Optimizasyon ve temizlik işlemleri bittiğinde bildirir.');
  }

  @override
  Future<void> showAlert(AlertEvent event) async {
    await _show(100 + event.kind.index, event.title, event.body, _alertChannelId,
        'Sağlık uyarıları', 'Isınma, düşük pil, dolu depolama ve bellek uyarıları.',
        important: true);
  }

  @override
  Future<void> showTest() => _show(2, 'Bildirimler çalışıyor',
      'TerminalF bu cihazda bildirim gönderebiliyor.', _taskChannelId, 'İşlem sonuçları',
      'Optimizasyon ve temizlik işlemleri bittiğinde bildirir.');

  Future<void> _show(
    int id,
    String title,
    String body,
    String channelId,
    String channelName,
    String channelDescription, {
    bool important = false,
  }) async {
    try {
      if (!_ready) await init();
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: important ? Importance.high : Importance.defaultImportance,
            priority: important ? Priority.high : Priority.defaultPriority,
            icon: _statIcon,
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
      );
    } catch (_) {
      // Bildirim gönderilemezse uygulama akışı bozulmaz.
    }
  }
}
