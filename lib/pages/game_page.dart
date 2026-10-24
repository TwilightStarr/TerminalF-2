import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../state/control_controller.dart';
import '../state/game_mode_controller.dart';
import '../utils/game_mode.dart';
import '../utils/game_probe.dart';
import '../utils/nine_kings.dart';
import '../widgets/control_setup_sheet.dart';
import '../widgets/log_sheet.dart';
import '../widgets/ui.dart';

/// Oyun Modu sayfası: ağır oyunlarda GPU yükünü, ısınmayı ve pil
/// tüketimini azaltır; oyun bitince her şeyi eski haline getirir.
class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.control, required this.game});

  final ControlController control;
  final GameModeController game;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  ControlController get control => widget.control;
  GameModeController get game => widget.game;

  bool _probed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game.load();
    control.addListener(_probeWhenReady);
    _probeWhenReady();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    control.removeListener(_probeWhenReady);
    super.dispose();
  }

  /// Oyundan Terminal'e dönülünce izleyicinin yaptıklarını ve yeni ölçümleri oku.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && control.ready) {
      game.syncWatchdog();
      game.refreshStats();
    }
  }

  void _probeWhenReady() {
    if (_probed || !control.ready) return;
    _probed = true;
    game.checkInstalled();
    game.refreshDisplayHz();
    game.syncWatchdog();
    game.refreshStats();
    game.detectForeground();
  }

  Future<bool> _ensureReady() async {
    if (control.ready) return true;
    await showControlSetup(context, control);
    return false;
  }

  Future<void> _start({required bool launch}) async {
    if (!await _ensureReady()) return;
    if (game.config.method == ResolutionMethod.wholeScreen && game.config.reducesResolution) {
      if (!mounted) return;
      final ok = await confirmDialog(
        context,
        title: 'Tüm ekran çözünürlüğü düşürülecek',
        message: 'Telefonun tamamı düşük çözünürlükte çalışır (yazılar biraz bulanık görünür). '
            'Oyun bitince "Geri Al"a basmayı unutmayın; eski değerler kayıtlı olduğu için '
            'uygulamayı kapatsanız bile geri alınabilir.',
        confirmLabel: 'Uygula',
      );
      if (!ok) return;
    }
    final result = await game.start(launch: launch);
    control.reportDone('Oyun Modu', result.summary, ok: result.ok);
    if (!mounted) return;
    showToast(context, result.summary);
  }

  Future<void> _stop() async {
    final result = await game.stop();
    control.reportDone('Oyun Modu kapatıldı', result.summary, ok: result.ok);
    if (!mounted) return;
    showToast(context, result.ok ? 'Her şey eski haline döndü' : result.summary);
  }

  Future<void> _startNineKings() async {
    if (!await _ensureReady()) return;
    if (game.nineKings.wholeScreen) {
      if (!mounted) return;
      final ok = await confirmDialog(
        context,
        title: 'Tüm ekran çözünürlüğü düşürülecek',
        message: 'Telefonun tamamı oyun boyunca düşük çözünürlükte çalışır (yazılar bulanık görünür). '
            'Oyun kapanınca kendiliğinden eski haline döner; olmazsa Geri Al\'a basın.',
        confirmLabel: 'Başlat',
      );
      if (!ok) return;
    }
    final result = await game.startNineKings();
    control.reportDone('9Kings Modu', result.summary, ok: result.ok);
    if (!mounted) return;
    showToast(context, result.summary);
  }

  Future<void> _editPackage() async {
    final controller = TextEditingController(text: game.config.package);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text('Oyun paket adı', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autocorrect: false,
              decoration: const InputDecoration(hintText: kNineKingsPackage),
            ),
            const SizedBox(height: 8),
            Text(
              'Genel Oyun Modu için oyunun paket adını yazın (Uygulamalar sekmesinde görünür).',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, kNineKingsPackage),
            child: const Text('Varsayılan'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    if (!isSafePackage(value)) {
      if (mounted) showToast(context, 'Geçersiz paket adı.');
      return;
    }
    await game.updateConfig(game.config.copyWith(package: value));
    game.checkInstalled();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([control, game]),
        builder: (context, _) {
          final cfg = game.config;
          final busy = game.busy;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Oyun Modu', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    tooltip: 'İşlem günlüğü',
                    onPressed: () => showLogSheet(context, control),
                    icon: Icon(Icons.receipt_long_rounded, color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _NineKingsCard(
                control: control,
                game: game,
                onStart: _startNineKings,
                onStop: _stop,
              ),
              if (busy) ...[
                const SizedBox(height: 12),
                const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                  child: LinearProgressIndicator(minHeight: 6),
                ),
              ],
              const SectionHeader('Genel Oyun Modu'),
              _StatusCard(control: control, game: game, onEditPackage: _editPackage),
              const SizedBox(height: 12),
              ...[
              _PresetCard(game: game, busy: busy),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Kare hızı üst sınırı'),
                    const SizedBox(height: 8),
                    _Choices<int>(
                      values: const [30, 60, 90],
                      selected: cfg.targetFps,
                      label: (v) => '$v FPS',
                      onSelected: busy ? null : (v) => game.updateConfig(cfg.copyWith(targetFps: v)),
                    ),
                    const SizedBox(height: 16),
                    const _Label('Oyun çözünürlüğü'),
                    const SizedBox(height: 8),
                    _Choices<double>(
                      values: const [1.0, 0.75, 0.6, 0.5],
                      selected: cfg.scale,
                      label: (v) => v >= 1 ? 'Tam' : '%${(v * 100).round()}',
                      onSelected: busy ? null : (v) => game.updateConfig(cfg.copyWith(scale: v)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Düşük çözünürlük GPU yükünü, ısınmayı ve pil tüketimini en çok azaltan ayardır. '
                      'Piksel sanat oyunlarda görüntü kaybı azdır.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
                    ),
                    if (cfg.reducesResolution) ...[
                      const SizedBox(height: 16),
                      const _Label('Çözünürlük yöntemi'),
                      const SizedBox(height: 8),
                      _Choices<ResolutionMethod>(
                        values: ResolutionMethod.values,
                        selected: cfg.method,
                        label: (v) => v == ResolutionMethod.perGame ? 'Yalnız oyun' : 'Tüm ekran',
                        onSelected: busy ? null : (v) => game.updateConfig(cfg.copyWith(method: v)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cfg.method == ResolutionMethod.perGame
                            ? 'Güvenli yöntem. Bazı üreticiler/oyunlar desteklemeyebilir; uygulanamazsa '
                                'sonuç listesinde görürsünüz ve "Tüm ekran"ı deneyebilirsiniz.'
                            : 'Daha güçlü ve her cihazda çalışır, ama telefonun tamamı geçici olarak '
                                'düşük çözünürlüğe geçer. Oyun bitince Geri Al\'a basın.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    _SwitchRow(
                      title: 'Ekranı ${cfg.targetFps >= 60 ? cfg.targetFps : 60} Hz\'e kilitle',
                      subtitle: 'Değişken yenileme hızının oyun sırasında yükselmesini engeller; '
                          'ekran ve GPU daha az çalışır. Oyun bitince geri alınır.',
                      value: cfg.lockRefreshRate,
                      onChanged: busy ? null : (v) => game.updateConfig(cfg.copyWith(lockRefreshRate: v)),
                    ),
                    const RowDivider(),
                    _SwitchRow(
                      title: 'Arka planı temizle',
                      subtitle: 'Başlamadan önce RAM\'i boşaltır; işlemciye daha az rekabet kalır.',
                      value: cfg.killBackground,
                      onChanged: busy ? null : (v) => game.updateConfig(cfg.copyWith(killBackground: v)),
                    ),
                    const RowDivider(),
                    _SwitchRow(
                      title: 'Oyun kapanınca otomatik geri al',
                      subtitle: 'Cihazda küçük bir izleyici çalışır: oyun yaklaşık 40 saniye ön planda '
                          'olmazsa ayarlar kendiliğinden eski haline döner; oyun boyunca FPS/ısı/işlemci '
                          'hızı kaydedilir. Terminal kapansa da çalışır.',
                      value: cfg.autoRevert,
                      onChanged: busy ? null : (v) => game.updateConfig(cfg.copyWith(autoRevert: v)),
                    ),
                    const RowDivider(),
                    _SwitchRow(
                      title: 'Sistem animasyonlarını kapat',
                      subtitle: 'Oyun boyunca geçiş efektleri kalkar; ekran birleştirme yükü biraz azalır.',
                      value: cfg.animationsOff,
                      onChanged: busy ? null : (v) => game.updateConfig(cfg.copyWith(animationsOff: v)),
                    ),
                    const RowDivider(),
                    _SwitchRow(
                      title: 'Bildirimleri sustur',
                      subtitle: 'Oyun sırasında Rahatsız Etme (yalnızca öncelikliler) açılır; bildirimler '
                          'takılma ve ekran uyanması yaratmaz.',
                      value: cfg.dnd,
                      onChanged: busy ? null : (v) => game.updateConfig(cfg.copyWith(dnd: v)),
                    ),
                    const RowDivider(),
                    _SwitchRow(
                      title: 'Ekran parlaklığını kıs',
                      subtitle: 'Oyun boyunca parlaklık mevcut değerin %60\'ına iner. AMOLED ekranda '
                          'ısınmayı ve pili en çok etkileyen ayarlardan biridir.',
                      value: cfg.dimScreen,
                      onChanged: busy ? null : (v) => game.updateConfig(cfg.copyWith(dimScreen: v)),
                    ),
                    const RowDivider(),
                    _SwitchRow(
                      title: 'İşlemci hızını sınırla (root)',
                      subtitle: 'En güçlü iki çekirdek kümesi %70 hızla çalışır; ısı ve hız dalgalanması azalır. '
                          'Yalnızca root ile çalışır, Shizuku ile uygulanamaz.',
                      value: cfg.cpuCap,
                      onChanged: busy ? null : (v) => game.updateConfig(cfg.copyWith(cpuCap: v)),
                    ),
                  ],
                ),
              ),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                label: game.active ? 'Yeniden Uygula ve Başlat' : 'Genel Modu Aç ve Oyunu Başlat',
                icon: Icons.sports_esports_rounded,
                busy: busy,
                onPressed: busy ? null : () => _start(launch: true),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SoftButton(
                      label: 'Sadece Uygula',
                      icon: Icons.tune_rounded,
                      onPressed: busy ? null : () => _start(launch: false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SoftButton(
                      label: 'Geri Al',
                      icon: Icons.undo_rounded,
                      color: game.active ? AppColors.warn : null,
                      onPressed: busy || !game.active ? null : _stop,
                    ),
                  ),
                ],
              ),
              if (game.lastResult != null && game.lastResult!.steps.isNotEmpty) ...[
                const SectionHeader('Son İşlem'),
                _ResultCard(result: game.lastResult!),
              ],
              if (control.ready) ...[
                SectionHeader(
                  'Son oyun oturumu',
                  trailing: IconButton(
                    tooltip: 'Yenile',
                    onPressed: () {
                      game.syncWatchdog();
                      game.refreshStats();
                    },
                    icon: Icon(Icons.refresh_rounded, color: AppColors.muted),
                  ),
                ),
                _ReportCard(game: game),
              ],
              const SectionHeader('Bilmeniz gerekenler'),
              const _HonestyCard(),
            ],
          );
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5));
}

class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v)),
            selected: v == selected,
            onSelected: onSelected == null ? null : (_) => onSelected!(v),
          ),
      ],
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
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.control, required this.game, required this.onEditPackage});

  final ControlController control;
  final GameModeController game;
  final VoidCallback onEditPackage;

  @override
  Widget build(BuildContext context) {
    final ready = control.ready;
    final active = game.active;
    final installed = game.installed;
    final hz = game.displayHz;
    final color = !ready ? AppColors.warn : (active ? AppColors.good : AppColors.muted);

    return AppCard(
      borderColor: color.faded(0.4),
      onTap: ready ? onEditPackage : () => showControlSetup(context, control),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.faded(0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(ready ? Icons.sports_esports_rounded : Icons.lock_outline_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Genel Oyun Modu',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ready
                          ? game.config.package
                          : 'Oyun modu için tek seferlik kurulum gerekiyor. Dokunun.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(ready ? Icons.edit_rounded : Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
            ],
          ),
          if (ready) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(
                  label: active ? 'Oyun modu AÇIK' : 'Oyun modu kapalı',
                  color: active ? AppColors.good : AppColors.muted,
                ),
                if (installed != null)
                  StatusPill(
                    label: installed ? 'Oyun yüklü' : 'Oyun bulunamadı',
                    color: installed ? AppColors.good : AppColors.warn,
                  ),
                if (hz != null) StatusPill(label: 'Ekran ${hz.round()} Hz', color: AppColors.muted),
                if (active && game.watchdogAlive != null)
                  StatusPill(
                    label: game.watchdogAlive! ? 'Otomatik geri alma: izliyor' : 'Otomatik geri alma: kapalı',
                    color: game.watchdogAlive! ? AppColors.good : AppColors.warn,
                  ),
                StatusPill(
                  label: game.foregroundPackage != null ? 'Ön plan algılama çalışıyor' : 'Ön plan algılanamıyor',
                  color: game.foregroundPackage != null ? AppColors.muted : AppColors.warn,
                ),
              ],
            ),
            if (game.syncNote != null) ...[
              const SizedBox(height: 10),
              Text(game.syncNote!, style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
            ],
          ],
        ],
      ),
    );
  }
}

class _NineKingsCard extends StatelessWidget {
  const _NineKingsCard({
    required this.control,
    required this.game,
    required this.onStart,
    required this.onStop,
  });

  final ControlController control;
  final GameModeController game;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final profile = game.nineKings;
    final busy = game.busy;
    final active = game.nineKingsActive;
    final color = active ? AppColors.good : AppColors.primary;
    final suggestion = game.nineKingsSuggestion;

    return AppCard(
      borderColor: color.faded(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.faded(0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.local_fire_department_rounded, color: color),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('9Kings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              if (active) StatusPill(label: 'AÇIK', color: AppColors.good),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tek dokunuşla oyunu açar. Görüntü ayrıntısı düşürülür (hafif bulanıklık), kare hızı '
            'sınırlanır, ekran kısılır, bildirimler susar; telefon ısınırsa koruma kendiliğinden '
            'sıkılaşır. Oyun kapanınca her şey eski haline döner.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          const _Label('Görüntü ayrıntısı'),
          const SizedBox(height: 8),
          _Choices<DetailLevel>(
            values: DetailLevel.values,
            selected: profile.detail,
            label: (v) => v.label,
            onSelected: busy ? null : (v) => game.updateNineKings(profile.copyWith(detail: v)),
          ),
          const SizedBox(height: 6),
          Text(profile.detail.hint, style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 14),
          const _Label('Kare hızı'),
          const SizedBox(height: 8),
          _Choices<int>(
            values: const [30, 60],
            selected: profile.fps,
            label: (v) => v == 30 ? 'Serin · 30 FPS' : 'Akıcı · 60 FPS',
            onSelected: busy ? null : (v) => game.updateNineKings(profile.copyWith(fps: v)),
          ),
          _SwitchRow(
            title: 'Güçlü yöntem',
            subtitle: 'Bulanıklık hiç etki etmiyorsa açın: telefonun tamamı oyun boyunca düşük '
                'çözünürlüğe geçer (yazılar da bulanık görünür).',
            value: profile.wholeScreen,
            onChanged: busy ? null : (v) => game.updateNineKings(profile.copyWith(wholeScreen: v)),
          ),
          if (suggestion != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warn.faded(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Öneri', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(suggestion.reason, style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4)),
                  const SizedBox(height: 8),
                  SoftButton(
                    label: 'Uygula: ${suggestion.level.label}',
                    icon: Icons.auto_fix_high_rounded,
                    onPressed: busy ? null : game.applyNineKingsSuggestion,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          PrimaryButton(
            label: active ? '9Kings\'i Yeniden Başlat' : '9Kings\'i Başlat',
            icon: Icons.sports_esports_rounded,
            busy: busy,
            onPressed: busy ? null : onStart,
          ),
          if (active) ...[
            const SizedBox(height: 10),
            SoftButton(
              label: 'Geri Al',
              icon: Icons.undo_rounded,
              color: AppColors.warn,
              onPressed: busy ? null : onStop,
            ),
          ],
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('Oyun içi ipuçları', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              children: [
                for (final tip in kNineKingsTips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• $tip', style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.game, required this.busy});

  final GameModeController game;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cfg = game.config;
    GamePreset? matched;
    for (final p in kGamePresets) {
      if (p.matches(cfg)) matched = p;
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in kGamePresets)
                ChoiceChip(
                  label: Text(p.title),
                  selected: identical(p, matched),
                  onSelected: busy ? null : (_) => game.updateConfig(p.applyTo(cfg)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            matched?.subtitle ?? 'Özel ayar (aşağıdaki seçimlerinize göre).',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

String _fmtDuration(int seconds) {
  if (seconds < 60) return '$seconds sn';
  final m = seconds ~/ 60;
  if (m < 60) return '$m dk';
  return '${m ~/ 60} sa ${m % 60} dk';
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.game});

  final GameModeController game;

  @override
  Widget build(BuildContext context) {
    final s = game.stats;
    final d = game.diagnosis;
    if (s == null) {
      return AppCard(
        child: Text(
          'Henüz kayıt yok. Oyun Modu açıkken oynayın; oyun ön plandayken her 10 saniyede '
          'FPS, ısıl durum ve işlemci hızı kaydedilir. Bitince buraya dönün.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45),
        ),
      );
    }

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(color: AppColors.muted, fontSize: 13.5))),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        );

    final color = d == null
        ? AppColors.muted
        : (d.kind == DiagnosisKind.onTarget
            ? AppColors.good
            : (d.kind == DiagnosisKind.unknown ? AppColors.muted : AppColors.warn));

    return AppCard(
      borderColor: color.faded(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Süre', _fmtDuration(s.durationSec)),
          row('Ortalama FPS', s.avgFps == null ? 'ölçülemedi' : s.avgFps!.toStringAsFixed(1)),
          row('En düşük FPS', s.minFps == null ? 'ölçülemedi' : s.minFps!.toStringAsFixed(1)),
          row('En yüksek ısıl durum', s.maxThermal == null ? 'okunamadı' : thermalLabel(s.maxThermal!)),
          row(
            'Büyük çekirdek hızı',
            s.avgCpuRatio == null ? 'okunamadı' : '%${(s.avgCpuRatio! * 100).round()}',
          ),
          if (s.guardTriggered) row('Isı koruması', 'devreye girdi'),
          if (d != null) ...[
            const SizedBox(height: 10),
            Text(d.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
            const SizedBox(height: 4),
            Text(d.advice, style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45)),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final GameRunResult result;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < result.steps.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    result.steps[i].ok
                        ? Icons.check_circle_rounded
                        : (result.steps[i].optional ? Icons.remove_circle_outline_rounded : Icons.error_rounded),
                    size: 20,
                    color: result.steps[i].ok
                        ? AppColors.good
                        : (result.steps[i].optional ? AppColors.muted : AppColors.danger),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(result.steps[i].label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (!result.steps[i].ok)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              result.steps[i].optional
                                  ? 'Bu cihazda desteklenmiyor olabilir. ${result.steps[i].detail}'
                                  : result.steps[i].detail,
                              style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i != result.steps.length - 1) const RowDivider(),
          ],
        ],
      ),
    );
  }
}

class _HonestyCard extends StatelessWidget {
  const _HonestyCard();

  @override
  Widget build(BuildContext context) {
    Widget item(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(text, style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45)),
        );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item('Bir oyunun kare hızı dışarıdan YÜKSELTİLEMEZ; burada oyunun GPU yükü azaltılır ve '
              'kare hızına üst sınır konur. 90 FPS, ancak oyunun işlemcisi o hızı üretebiliyorsa görülür.'),
          item('Savaşlarda 10^30 gibi dev sayılar ve çok sayıda birim varsa yavaşlamanın büyük kısmı '
              'işlemciden gelir. Bu durumda çözünürlük düşürmek ısınmayı ve pili belirgin azaltır, '
              'akıcılığı ise sınırlı artırır.'),
          item('Ekran Hz\'si ve çözünürlük ayarları üreticiye (HyperOS) göre farklı davranabilir. '
              'Uygulanamayan adımlar sonuç listesinde açıkça işaretlenir; başarı uydurulmaz.'),
          item('FPS değeri, oyunun kare zamanlarından (SurfaceFlinger) cihazda ölçülür; okunamazsa '
              '"ölçülemedi" yazar. Teşhis sezgiseldir ve "olası" der, kesin hüküm vermez.'),
          item('Oyun bitince Geri Al\'a basın: ekran 90 Hz\'de kilitli kalırsa pil gereksiz harcanır. '
              'Eski değerler kayıtlıdır, uygulama kapansa bile geri alınır.'),
        ],
      ),
    );
  }
}
