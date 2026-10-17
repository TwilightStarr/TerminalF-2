import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/notification_service.dart';
import '../state/app_settings.dart';
import '../widgets/ui.dart';

/// Bildirimler, uyarı eşikleri ve geri bildirim tercihleri.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.settings, required this.notifier});

  final AppSettings settings;
  final Notifier notifier;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {
  bool _permitted = false;

  AppSettings get s => widget.settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kullanıcı sistem ayarlarından izni değiştirip dönmüş olabilir.
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final ok = await widget.notifier.hasPermission();
    if (mounted) setState(() => _permitted = ok);
  }

  Future<void> _requestPermission() async {
    final ok = await widget.notifier.requestPermission();
    if (!mounted) return;
    setState(() => _permitted = ok);
    if (!ok) {
      showToast(context, 'İzin verilmedi. Sistem ayarlarından açabilirsiniz.');
    }
  }

  Future<void> _sendTest() async {
    if (!_permitted) {
      await _requestPermission();
      if (!_permitted) return;
    }
    await widget.notifier.showTest();
    if (mounted) showToast(context, 'Test bildirimi gönderildi');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Bildirimler ve Uyarılar',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Icon(
                      _permitted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                      color: _permitted ? AppColors.good : AppColors.warn,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bildirim izni', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            _permitted ? 'Verildi' : 'Verilmedi: bildirim gönderilemez',
                            style: TextStyle(
                              color: _permitted ? AppColors.good : AppColors.warn,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_permitted) SoftButton(label: 'İzin Ver', onPressed: _requestPermission),
                  ],
                ),
              ),
              const SectionHeader('Bildirimler'),
              AppCard(
                child: Column(
                  children: [
                    _SwitchRow(
                      title: 'İşlem sonuçları',
                      subtitle: 'Optimizasyon bitince, uygulama arka plandaysa bildir.',
                      value: s.taskNotifications,
                      onChanged: s.setTaskNotifications,
                    ),
                    const RowDivider(),
                    _SwitchRow(
                      title: 'Sağlık uyarıları',
                      subtitle: 'Isınma, düşük pil, dolu depolama ve bellek. '
                          'Uygulama çalışırken izlenir.',
                      value: s.healthAlerts,
                      onChanged: s.setHealthAlerts,
                    ),
                    const SizedBox(height: 12),
                    SoftButton(
                      label: 'Test Bildirimi Gönder',
                      icon: Icons.send_rounded,
                      onPressed: _sendTest,
                    ),
                  ],
                ),
              ),
              const SectionHeader('Uyarı Eşikleri'),
              AppCard(
                child: Column(
                  children: [
                    _SliderRow(
                      title: 'Sıcaklık',
                      valueLabel: '${s.temperatureC.toStringAsFixed(0)} °C ve üstü',
                      value: s.temperatureC,
                      min: 35,
                      max: 50,
                      divisions: 15,
                      enabled: s.healthAlerts,
                      onChanged: s.setTemperature,
                    ),
                    _SliderRow(
                      title: 'Depolama doluluğu',
                      valueLabel: '%${s.storagePercent} ve üstü',
                      value: s.storagePercent.toDouble(),
                      min: 70,
                      max: 98,
                      divisions: 28,
                      enabled: s.healthAlerts,
                      onChanged: (v) => s.setStoragePercent(v.round()),
                    ),
                    _SliderRow(
                      title: 'Düşük pil',
                      valueLabel: '%${s.batteryPercent} ve altı',
                      value: s.batteryPercent.toDouble(),
                      min: 5,
                      max: 30,
                      divisions: 25,
                      enabled: s.healthAlerts,
                      onChanged: (v) => s.setBatteryPercent(v.round()),
                    ),
                    _SliderRow(
                      title: 'Bellek (RAM) doluluğu',
                      valueLabel: '%${s.memoryPercent} ve üstü',
                      value: s.memoryPercent.toDouble(),
                      min: 80,
                      max: 98,
                      divisions: 18,
                      enabled: s.healthAlerts,
                      onChanged: (v) => s.setMemoryPercent(v.round()),
                    ),
                  ],
                ),
              ),
              const SectionHeader('Geri Bildirim'),
              AppCard(
                child: _SwitchRow(
                  title: 'Dokunsal geri bildirim',
                  subtitle: 'Sekme geçişi ve işlem sonuçlarında hafif titreşim.',
                  value: s.haptics,
                  onChanged: s.setHaptics,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(valueLabel, style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
