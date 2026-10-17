import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/theme.dart';
import '../models/tweak_model.dart';
import '../services/brightness_service.dart';
import '../services/catalog_service.dart';
import '../services/device_service.dart';
import '../services/network_service.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../state/app_settings.dart';
import '../state/live_stats.dart';
import '../utils/app_info.dart';
import '../utils/format_utils.dart';
import '../widgets/app_logo.dart';
import '../widgets/ui.dart';
import 'settings_page.dart';

/// Cihaz: bilgiler, ekran ve izin ayarları, sistem kısayolları, önerilen uygulamalar.
class DevicePage extends StatefulWidget {
  const DevicePage({
    super.key,
    required this.live,
    required this.settings,
    required this.notifier,
  });

  final LiveStats live;
  final AppSettings settings;
  final Notifier notifier;

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final _deviceService = DeviceService();
  final _networkService = NetworkService();
  final _storageService = StorageService();
  final _brightnessService = BrightnessService();
  final _settings = SettingsService();
  final _catalog = CatalogService();

  DeviceStaticInfo? _device;
  String _ip = '…';
  StorageReading? _storage;
  List<FeatureShortcut> _features = const [];
  List<RecommendedApp> _recommended = const [];

  bool _keepScreenOn = false;
  double _brightness = 1.0;
  PermissionStatus _notification = PermissionStatus.denied;
  bool _clearing = false;
  String _version = '…';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final version = await appVersion();
    final keepOn = await _settings.getKeepScreenOn();
    final savedBrightness = await _settings.getBrightness();
    final currentBrightness = savedBrightness ?? await _brightnessService.current();
    PermissionStatus notification = PermissionStatus.denied;
    try {
      notification = await Permission.notification.status;
    } catch (_) {
      // Sessizce yok say.
    }
    final device = await _deviceService.read();
    final ip = await _networkService.localIpAddress();
    final storage = await _storageService.read();
    List<FeatureShortcut> features = const [];
    List<RecommendedApp> recommended = const [];
    try {
      features = await _catalog.loadFeatures();
      recommended = await _catalog.loadApplications();
    } catch (_) {
      // Yapılandırma okunamazsa bu bölümler boş kalır.
    }
    if (!mounted) return;
    setState(() {
      _version = version;
      _keepScreenOn = keepOn;
      if (currentBrightness != null) _brightness = currentBrightness;
      _notification = notification;
      _device = device;
      _ip = ip;
      _storage = storage;
      _features = features;
      _recommended = recommended;
    });
  }

  Future<void> _setKeepScreenOn(bool value) async {
    setState(() => _keepScreenOn = value);
    try {
      if (value) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // Platform desteklemiyorsa sessizce yok say.
    }
    await _settings.setKeepScreenOn(value);
  }

  Future<void> _resetBrightness() async {
    await _brightnessService.reset();
    await _settings.clearBrightness();
    final current = await _brightnessService.current();
    if (!mounted) return;
    setState(() => _brightness = current ?? _brightness);
    showToast(context, 'Parlaklık sistem değerine döndü');
  }

  Future<void> _vibrate() async {
    try {
      await Vibration.vibrate(duration: 300);
    } catch (_) {
      // Titreşim donanımı yoksa sessizce yok say.
    }
  }

  Future<void> _openNotificationSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(settings: widget.settings, notifier: widget.notifier),
      ),
    );
    // Ayarlar sayfasında izin değişmiş olabilir.
    try {
      final status = await Permission.notification.status;
      if (mounted) setState(() => _notification = status);
    } catch (_) {
      // Sessizce yok say.
    }
  }

  Future<void> _requestNotification() async {
    try {
      final status = await Permission.notification.request();
      if (!mounted) return;
      setState(() => _notification = status);
      if (status.isPermanentlyDenied) await openAppSettings();
    } catch (_) {
      // Sessizce yok say.
    }
  }

  Future<void> _clearOwnCache() async {
    setState(() => _clearing = true);
    final freed = await _storageService.clearCache();
    final storage = await _storageService.read();
    if (!mounted) return;
    setState(() {
      _clearing = false;
      _storage = storage;
    });
    showToast(context, '${formatBytes(freed)} temizlendi');
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final dpr = mq.devicePixelRatio;
    final physW = (mq.size.width * dpr).round();
    final physH = (mq.size.height * dpr).round();
    final hz = View.of(context).display.refreshRate;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          const Text('Cihaz', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SectionHeader('Bu Telefon'),
          AppCard(
            child: ListenableBuilder(
              listenable: widget.live,
              builder: (context, _) {
                final sys = widget.live.snapshot.system;
                return Column(
                  children: [
                    InfoRow(label: 'Model', value: _device?.model ?? '…', copyable: _device != null),
                    const RowDivider(),
                    InfoRow(label: 'Sistem', value: _device?.os ?? '…'),
                    const RowDivider(),
                    InfoRow(label: 'İşlemci mimarisi', value: _device?.cpuArch ?? '…'),
                    const RowDivider(),
                    InfoRow(label: 'Çekirdek sayısı', value: '${_device?.coreCount ?? '…'}'),
                    const RowDivider(),
                    InfoRow(
                      label: 'Toplam bellek',
                      value: sys.memory == null ? '—' : formatBytes(sys.memory!.totalBytes),
                    ),
                    const RowDivider(),
                    InfoRow(
                      label: 'Toplam depolama',
                      value: sys.disk == null ? '—' : formatBytes(sys.disk!.totalBytes),
                    ),
                    const RowDivider(),
                    InfoRow(
                      label: 'Açık kalma süresi',
                      value: sys.uptime == null ? '—' : formatDuration(sys.uptime!),
                    ),
                  ],
                );
              },
            ),
          ),
          const SectionHeader('Ekran ve Ağ'),
          AppCard(
            child: Column(
              children: [
                InfoRow(label: 'Çözünürlük', value: '$physW × $physH'),
                const RowDivider(),
                InfoRow(label: 'Yoğunluk', value: '${(dpr * 160).round()} dpi'),
                const RowDivider(),
                InfoRow(label: 'Yenileme hızı', value: hz > 0 ? '${hz.round()} Hz' : 'Bilinmiyor'),
                const RowDivider(),
                InfoRow(label: 'Yerel IP', value: _ip, copyable: _ip != 'Bulunamadı' && _ip != '…'),
              ],
            ),
          ),
          const SectionHeader('Ayarlar'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Ekranı açık tut', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Switch(value: _keepScreenOn, onChanged: _setKeepScreenOn),
                  ],
                ),
                const RowDivider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.brightness_6_rounded, color: AppColors.muted, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Uygulama parlaklığı', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Text('%${(_brightness * 100).round()}',
                        style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
                Slider(
                  value: _brightness.clamp(0.0, 1.0),
                  onChanged: (v) {
                    setState(() => _brightness = v);
                    _brightnessService.setBrightness(v);
                  },
                  onChangeEnd: (v) => _settings.setBrightness(v),
                ),
                Row(
                  children: [
                    Expanded(
                      child: SoftButton(
                        label: 'Sisteme Sıfırla',
                        icon: Icons.restart_alt_rounded,
                        onPressed: _resetBrightness,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SoftButton(
                        label: 'Titreşim Testi',
                        icon: Icons.vibration_rounded,
                        onPressed: _vibrate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const RowDivider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: _openNotificationSettings,
                  leading: const Icon(Icons.notifications_rounded, color: AppColors.muted),
                  title: const Text('Bildirimler ve Uyarılar',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text(
                    'Isınma, pil, depolama uyarıları · eşikler · titreşim',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ),
                const RowDivider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bildirim izni', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            _notification.isGranted ? 'Verildi' : 'Verilmedi',
                            style: TextStyle(
                              color: _notification.isGranted ? AppColors.good : AppColors.warn,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_notification.isGranted)
                      SoftButton(label: 'İzin Ver', onPressed: _requestNotification),
                  ],
                ),
                const SizedBox(height: 14),
                const RowDivider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Uygulama önbelleği', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            formatBytes(_storage?.cacheBytes ?? 0),
                            style: const TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    SoftButton(
                      label: _clearing ? 'Temizleniyor…' : 'Temizle',
                      onPressed: _clearing ? null : _clearOwnCache,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_features.isNotEmpty) ...[
            const SectionHeader('Sistem Kısayolları'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < _features.length; i++) ...[
                    ListTile(
                      onTap: () => _catalog.openFeatureSettings(_features[i]),
                      title: Text(_features[i].title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      subtitle: Text(
                        _features[i].description,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    ),
                    if (i != _features.length - 1) const RowDivider(),
                  ],
                ],
              ),
            ),
          ],
          if (_recommended.isNotEmpty) ...[
            const SectionHeader('Önerilen Açık Kaynak Uygulamalar'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < _recommended.length; i++) ...[
                    ListTile(
                      onTap: () => _catalog.openUrl(_recommended[i].url),
                      title: Text(_recommended[i].name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      subtitle: Text(
                        '${_recommended[i].description}\n${_recommended[i].sourceLabel}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.open_in_new_rounded, color: AppColors.muted, size: 20),
                    ),
                    if (i != _recommended.length - 1) const RowDivider(),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                const AppLogo(size: 56),
                const SizedBox(height: 10),
                const Text('TerminalF', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text('Sürüm $_version',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
