import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/battery_service.dart';
import '../services/storage_service.dart';
import '../state/control_controller.dart';
import '../state/live_stats.dart';
import '../utils/advisor.dart';
import '../utils/format_utils.dart';
import '../widgets/app_logo.dart';
import '../widgets/control_setup_sheet.dart';
import '../widgets/log_sheet.dart';
import '../widgets/ui.dart';
import '../models/profile.dart';

/// Ana Sayfa: cihaz sağlığı, öneriler, canlı durum ve hızlı işlemler.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.live, required this.control});

  final LiveStats live;
  final ControlController control;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _storage = StorageService();
  String? _running;

  Future<void> _run(String label, Future<TweakOutcome> Function() action) async {
    if (_running != null) return;
    if (!widget.control.ready) {
      await showControlSetup(context, widget.control);
      return;
    }
    setState(() => _running = label);
    final outcome = await action();
    await widget.live.refresh();
    if (!mounted) return;
    setState(() => _running = null);
    widget.control.reportDone(label, outcome.message, ok: outcome.ok);
    showOutcome(context, outcome);
  }

  Future<void> _smartOptimize() async {
    if (_running != null) return;
    if (!widget.control.ready) {
      // Yetki yoksa bile yapılabilecek tek gerçek temizlik: kendi önbelleğimiz.
      setState(() => _running = 'Akıllı optimizasyon');
      final freed = await _storage.clearCache();
      if (!mounted) return;
      setState(() => _running = null);
      showToast(context,
          '${formatBytes(freed)} uygulama önbelleği temizlendi. Tam optimizasyon için kontrolü etkinleştirin.');
      await showControlSetup(context, widget.control);
      return;
    }
    setState(() => _running = 'Akıllı optimizasyon');
    final a = await widget.control.freeMemory();
    final b = await widget.control.trimAllCaches();
    await widget.live.refresh();
    if (!mounted) return;
    setState(() => _running = null);
    final allOk = a.ok && b.ok;
    final message = allOk
        ? 'Optimizasyon tamamlandı: bellek boşaltıldı, önbellekler temizlendi.'
        : 'Optimizasyon kısmen tamamlandı. Ayrıntılar için günlüğe bakın.';
    widget.control.reportDone('Akıllı optimizasyon', message, ok: allOk);
    showToast(context, message);
  }

  Future<void> _onAdvice(AdviceAction action) async {
    switch (action) {
      case AdviceAction.freeMemory:
      case AdviceAction.coolDown:
        await _run('Hızlandır', widget.control.freeMemory);
        break;
      case AdviceAction.cleanStorage:
        await _run('Önbellek', widget.control.trimAllCaches);
        break;
      case AdviceAction.saveBattery:
        if (!widget.control.ready) {
          await showControlSetup(context, widget.control);
          return;
        }
        final result = await widget.control.runProfile(profileById('battery')!, apply: true);
        if (result.applied + result.failed > 0) {
          widget.control.reportDone('Pil Tasarrufu', result.summary, ok: result.failed == 0);
        }
        if (!mounted) return;
        showToast(context, 'Pil Tasarrufu: ${result.summary}');
        break;
      case AdviceAction.enableControl:
        await showControlSetup(context, widget.control);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([widget.live, widget.control]),
        builder: (context, _) {
          final snap = widget.live.snapshot;
          final battery = snap.battery;
          final ram = snap.system.memory;
          final disk = snap.system.disk;
          final charging =
              battery.state == BatteryState.charging || battery.state == BatteryState.full;
          final temp = battery.temperatureCelsius;

          final score = computeHealthScore(
            ramUsedRatio: ram?.usedRatio,
            storageUsedRatio: disk?.usedRatio,
            batteryPercent: battery.percent,
            charging: charging,
            temperatureCelsius: temp,
          );
          final advice = buildAdvice(
            ramUsedRatio: ram?.usedRatio,
            storageUsedRatio: disk?.usedRatio,
            batteryPercent: battery.percent,
            charging: charging,
            temperatureCelsius: temp,
            controlReady: widget.control.ready,
          );

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceHigh,
            onRefresh: widget.live.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                FadeSlideIn(key: const ValueKey('h'), index: 0, child: _Header(control: widget.control)),
                const SizedBox(height: 18),
                FadeSlideIn(
                  key: const ValueKey('health'),
                  index: 1,
                  child: _HealthCard(
                  score: score,
                  hasData: ram != null || disk != null || battery.percent != null,
                  busy: _running == 'Akıllı optimizasyon',
                  onOptimize: _smartOptimize,
                ),
                ),
                const SizedBox(height: 14),
                for (final item in advice) ...[
                  _AdviceCard(advice: item, onTap: () => _onAdvice(item.action)),
                  const SizedBox(height: 10),
                ],
                if (advice.isEmpty) const _AllGoodCard(),
                FadeSlideIn(
                  key: const ValueKey('stats'),
                  index: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                const SectionHeader('Anlık Durum'),
                _StatGrid(
                  fitContent: true,
                  children: [
                    StatTile(
                      icon: Icons.memory_rounded,
                      label: 'Bellek (RAM)',
                      value: ram == null ? '—' : '%${(ram.usedRatio * 100).round()}',
                      caption: ram == null
                          ? 'Okunamadı'
                          : '${formatBytes(ram.usedBytes)} / ${formatBytes(ram.totalBytes)}',
                      ratio: ram?.usedRatio,
                      color: AppColors.forUsage(ram?.usedRatio ?? 0),
                    ),
                    StatTile(
                      icon: Icons.sd_storage_rounded,
                      label: 'Depolama',
                      value: disk == null ? '—' : '%${(disk.usedRatio * 100).round()}',
                      caption: disk == null
                          ? 'Okunamadı'
                          : '${formatBytes(disk.freeBytes)} boş',
                      ratio: disk?.usedRatio,
                      color: AppColors.forUsage(disk?.usedRatio ?? 0),
                    ),
                    StatTile(
                      icon: charging ? Icons.battery_charging_full_rounded : Icons.battery_full_rounded,
                      label: 'Pil',
                      value: battery.percent == null ? '—' : '%${battery.percent}',
                      caption: _batteryCaption(battery),
                      ratio: battery.percent == null ? null : battery.percent! / 100.0,
                      color: battery.percent == null
                          ? AppColors.muted
                          : _batteryColor(battery.percent!, charging),
                    ),
                    StatTile(
                      icon: Icons.thermostat_rounded,
                      label: 'Sıcaklık',
                      value: temp == null ? '—' : '${temp.toStringAsFixed(1)}°C',
                      caption: snap.system.uptime == null
                          ? null
                          : 'Açık: ${formatDuration(snap.system.uptime!)}',
                      ratio: temp == null ? null : ((temp - 20) / 30).clamp(0.0, 1.0),
                      color: temp == null
                          ? AppColors.muted
                          : (temp >= 45
                              ? AppColors.danger
                              : temp >= 40
                                  ? AppColors.warn
                                  : AppColors.primary),
                    ),
                  ],
                ),
                    ],
                  ),
                ),
                FadeSlideIn(
                  key: const ValueKey('quick'),
                  index: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                const SectionHeader('Hızlı İşlemler'),
                _StatGrid(
                  aspect: 1.9,
                  children: [
                    _QuickAction(
                      icon: Icons.rocket_launch_rounded,
                      label: 'Hızlandır',
                      busy: _running == 'Hızlandır',
                      onTap: () => _run('Hızlandır', widget.control.freeMemory),
                    ),
                    _QuickAction(
                      icon: Icons.cleaning_services_rounded,
                      label: 'Önbellek Temizle',
                      busy: _running == 'Önbellek',
                      onTap: () => _run('Önbellek', widget.control.trimAllCaches),
                    ),
                    _QuickAction(
                      icon: Icons.receipt_long_rounded,
                      label: 'İşlem Günlüğü',
                      onTap: () => showLogSheet(context, widget.control),
                    ),
                    _QuickAction(
                      icon: Icons.verified_user_rounded,
                      label: 'Kontrol Durumu',
                      onTap: () => showControlSetup(context, widget.control),
                    ),
                  ],
                ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _batteryCaption(BatteryReading b) {
    switch (b.state) {
      case BatteryState.charging:
        return b.estimatedRemaining == null
            ? 'Şarj oluyor'
            : '${formatDuration(b.estimatedRemaining!)} doluma';
      case BatteryState.full:
        return 'Dolu';
      case BatteryState.discharging:
        return b.estimatedRemaining == null
            ? 'Pil kullanılıyor'
            : '${formatDuration(b.estimatedRemaining!)} kaldı';
      default:
        return 'Durum bilinmiyor';
    }
  }

  static Color _batteryColor(int percent, bool charging) {
    if (charging) return AppColors.good;
    if (percent <= 20) return AppColors.danger;
    if (percent <= 50) return AppColors.warn;
    return AppColors.primary;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.control});

  final ControlController control;

  @override
  Widget build(BuildContext context) {
    final ready = control.ready;
    final color = control.checking
        ? AppColors.muted
        : (ready ? AppColors.good : AppColors.warn);
    return Row(
      children: [
        const AppLogo(size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TerminalF',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ),
              Text('Telefon yönetim merkezi', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => showControlSetup(context, control),
          child: StatusPill(
            label: control.checking ? 'Denetleniyor' : (ready ? 'Kontrol açık' : 'Kontrol kapalı'),
            color: color,
            icon: ready ? Icons.verified_rounded : Icons.lock_outline_rounded,
          ),
        ),
      ],
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.score,
    required this.hasData,
    required this.busy,
    required this.onOptimize,
  });

  final int score;
  final bool hasData;
  final bool busy;
  final VoidCallback onOptimize;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          HealthRing(score: score),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cihaz Sağlığı', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  hasData ? healthLabel(score) : 'Ölçülüyor…',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: hasData ? AppColors.forHealth(score) : AppColors.muted,
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'Akıllı Optimizasyon',
                  icon: Icons.auto_fix_high_rounded,
                  busy: busy,
                  onPressed: onOptimize,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice, required this.onTap});

  final Advice advice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = advice.level == AdviceLevel.critical
        ? AppColors.danger
        : advice.level == AdviceLevel.warning
            ? AppColors.warn
            : AppColors.secondary;
    return AppCard(
      borderColor: color.faded(0.45),
      child: Row(
        children: [
          Icon(
            advice.level == AdviceLevel.info ? Icons.info_outline_rounded : Icons.warning_amber_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(advice.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  advice.detail,
                  style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SoftButton(label: advice.actionLabel, onPressed: onTap, color: color),
        ],
      ),
    );
  }
}

class _AllGoodCard extends StatelessWidget {
  const _AllGoodCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.good),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Her şey yolunda. Yapmanız gereken bir şey yok.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// İki sütunlu, sabit oranlı ızgara (kaydırma dış ListView'da).
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children, this.aspect = 1.1, this.fitContent = false});

  final List<Widget> children;
  final double aspect;

  /// `true` ise kartlar sabit en-boy oranı yerine içeriğine göre yükselir (aynı
  /// satırdaki iki kart eşit boyda); kartların altında boş alan kalmaz.
  final bool fitContent;

  @override
  Widget build(BuildContext context) {
    if (fitContent) {
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += 2) {
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: 12),
                Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
              ],
            ),
          ),
        );
        if (i + 2 < children.length) rows.add(const SizedBox(height: 12));
      }
      return Column(children: rows);
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: aspect,
      children: children,
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap, this.busy = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: busy ? null : onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.faded(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Icon(icon, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
