import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../core/theme.dart';
import '../services/apps_service.dart';
import '../state/control_controller.dart';
import '../state/game_mode_controller.dart';
import '../utils/game_mode.dart';
import '../utils/game_probe.dart';
import '../widgets/control_setup_sheet.dart';
import '../widgets/log_sheet.dart';
import '../widgets/ui.dart';

/// Oyun Modu sayfası: istenen HER oyun için tek dokunuşla ısıyı, GPU yükünü ve
/// pil tüketimini azaltır; oyun bitince her şeyi eski haline getirir. Her oyunun
/// ayarı ayrı saklanır.
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
    game.load().then((_) {
      if (mounted) game.checkInstalled();
    });
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
    final cfg = game.config;
    if (cfg.method == ResolutionMethod.wholeScreen && cfg.reducesResolution) {
      if (!mounted) return;
      final ok = await confirmDialog(
        context,
        title: 'Tüm ekran çözünürlüğü düşürülecek',
        message: 'Telefonun tamamı oyun boyunca düşük çözünürlükte çalışır (yazılar bulanık görünür). '
            'Oyun kapanınca kendiliğinden eski haline döner; olmazsa Geri Al\'a basın. Eski '
            'değerler kayıtlı olduğu için uygulamayı kapatsanız bile geri alınabilir.',
        confirmLabel: 'Uygula',
      );
      if (!ok) return;
    }
    final result = await game.startSelected(launch: launch);
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

  Future<void> _pickGame() async {
    final picked = await showModalBottomSheet<SavedGame>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _GamePicker(existing: {for (final g in game.games) g.package}),
    );
    if (picked == null) return;
    final ok = await game.addGame(picked.package, picked.name);
    if (!mounted) return;
    if (!ok) showToast(context, 'Geçersiz paket adı.');
  }

  Future<void> _removeSelected() async {
    final pkg = game.selectedPackage;
    if (pkg == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Oyunu listeden çıkar',
      message: '"${game.selectedName}" için kayıtlı Oyun Modu ayarları silinir. Oyunun kendisine '
          'dokunulmaz.',
      confirmLabel: 'Çıkar',
      danger: true,
    );
    if (!ok) return;
    await game.removeGame(pkg);
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
          final has = game.hasGame;
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
              const SizedBox(height: 8),
              if (!has)
                _EmptyHero(onAdd: _pickGame)
              else ...[
                _GameStrip(game: game, busy: busy, onAdd: _pickGame),
                const SizedBox(height: 12),
                _HeroCard(
                  control: control,
                  game: game,
                  onStart: () => _start(launch: true),
                  onApply: () => _start(launch: false),
                  onStop: _stop,
                ),
                if (busy) ...[
                  const SizedBox(height: 12),
                  const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                    child: LinearProgressIndicator(minHeight: 6),
                  ),
                ],
                const SectionHeader('Mod seç'),
                _PresetList(game: game, busy: busy),
                if (game.suggestion != null) ...[
                  const SizedBox(height: 12),
                  _SuggestionCard(game: game, busy: busy),
                ],
                const SectionHeader('Ayrıntılı ayarlar'),
                ..._groups(cfg, busy),
                if (game.lastResult != null && game.lastResult!.steps.isNotEmpty) ...[
                  const SectionHeader('Son işlem'),
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
                const SizedBox(height: 14),
                Center(
                  child: TextButton.icon(
                    onPressed: busy ? null : _removeSelected,
                    icon: Icon(Icons.delete_outline_rounded, color: AppColors.muted, size: 20),
                    label: Text('Bu oyunu listeden çıkar', style: TextStyle(color: AppColors.muted)),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _scaleLabel(double v) => v >= 0.999 ? 'Tam çözünürlük' : '%${(v * 100).round()} çözünürlük';

  List<Widget> _groups(GameModeConfig cfg, bool busy) {
    void set(GameModeConfig next) => game.updateConfig(next);
    final screenOn = <String>[
      if (cfg.lockHz != null) 'Ekran ${cfg.lockHz} Hz',
      if (cfg.dimScreen) 'parlaklık kısık',
      if (cfg.animationsOff) 'animasyon kapalı',
    ];
    final systemOn = <String>[
      if (cfg.killBackground) 'arka plan temiz',
      if (cfg.dnd) 'bildirim sessiz',
      if (cfg.batterySaver) 'pil tasarrufu',
      if (cfg.cpuCap) 'işlemci sınırı',
    ];
    return [
      _Group(
        icon: Icons.speed_rounded,
        title: 'Performans',
        summary: '${cfg.targetFps} FPS · ${_scaleLabel(cfg.scale)} · ${cfg.powerProfile.label}',
        children: [
          const _Label('Kare hızı üst sınırı'),
          const SizedBox(height: 8),
          _Choices<int>(
            values: const [30, 60, 90],
            selected: cfg.targetFps,
            label: (v) => '$v FPS',
            onSelected: busy ? null : (v) => set(cfg.copyWith(targetFps: v)),
          ),
          const SizedBox(height: 16),
          const _Label('Oyun çözünürlüğü'),
          const SizedBox(height: 8),
          _Choices<double>(
            values: kScaleSteps,
            selected: cfg.scale,
            label: (v) => v >= 1 ? 'Tam' : '%${(v * 100).round()}',
            onSelected: busy ? null : (v) => set(cfg.copyWith(scale: v)),
          ),
          const SizedBox(height: 6),
          const _Hint('Düşük çözünürlük GPU yükünü, ısınmayı ve pil tüketimini en çok azaltan ayardır. '
              'Piksel sanat oyunlarda görüntü kaybı azdır.'),
          if (cfg.reducesResolution) ...[
            const SizedBox(height: 16),
            const _Label('Çözünürlük yöntemi'),
            const SizedBox(height: 8),
            _Choices<ResolutionMethod>(
              values: ResolutionMethod.values,
              selected: cfg.method,
              label: (v) => v == ResolutionMethod.perGame ? 'Yalnız oyun' : 'Tüm ekran',
              onSelected: busy ? null : (v) => set(cfg.copyWith(method: v)),
            ),
            const SizedBox(height: 6),
            _Hint(cfg.method == ResolutionMethod.perGame
                ? 'Güvenli yöntem. Bazı üreticiler/oyunlar desteklemeyebilir; uygulanamazsa '
                    'sonuç listesinde görürsünüz ve "Tüm ekran"ı deneyebilirsiniz.'
                : 'Daha güçlü ve her cihazda çalışır, ama telefonun tamamı geçici olarak '
                    'düşük çözünürlüğe geçer. Oyun bitince Geri Al\'a basın.'),
          ],
          const SizedBox(height: 16),
          const _Label('Güç profili'),
          const SizedBox(height: 8),
          _Choices<GamePower>(
            values: GamePower.values,
            selected: cfg.powerProfile,
            label: (v) => v.label,
            onSelected: busy ? null : (v) => set(cfg.copyWith(powerProfile: v)),
          ),
          const SizedBox(height: 6),
          _Hint(cfg.powerProfile.hint),
        ],
      ),
      const SizedBox(height: 10),
      _Group(
        icon: Icons.smartphone_rounded,
        title: 'Ekran',
        summary: screenOn.isEmpty ? 'Ekrana dokunulmaz' : screenOn.join(' · '),
        children: [
          _SwitchRow(
            title: 'Ekranı ${cfg.targetFps >= 60 ? cfg.targetFps : 60} Hz\'e kilitle',
            subtitle: 'Değişken yenileme hızının oyun sırasında yükselmesini engeller; '
                'ekran ve GPU daha az çalışır. Oyun bitince geri alınır.',
            value: cfg.lockRefreshRate,
            onChanged: busy ? null : (v) => set(cfg.copyWith(lockRefreshRate: v)),
          ),
          const RowDivider(),
          _SwitchRow(
            title: 'Ekran parlaklığını kıs',
            subtitle: 'Oyun boyunca parlaklık mevcut değerin %60\'ına iner. AMOLED ekranda '
                'ısınmayı ve pili en çok etkileyen ayarlardan biridir.',
            value: cfg.dimScreen,
            onChanged: busy ? null : (v) => set(cfg.copyWith(dimScreen: v)),
          ),
          const RowDivider(),
          _SwitchRow(
            title: 'Sistem animasyonlarını kapat',
            subtitle: 'Oyun boyunca geçiş efektleri kalkar; ekran birleştirme yükü biraz azalır.',
            value: cfg.animationsOff,
            onChanged: busy ? null : (v) => set(cfg.copyWith(animationsOff: v)),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _Group(
        icon: Icons.memory_rounded,
        title: 'Sistem',
        summary: systemOn.isEmpty ? 'Sisteme dokunulmaz' : systemOn.join(' · '),
        children: [
          _SwitchRow(
            title: 'Arka planı temizle',
            subtitle: 'Başlamadan önce RAM\'i boşaltır; işlemciye daha az rekabet kalır.',
            value: cfg.killBackground,
            onChanged: busy ? null : (v) => set(cfg.copyWith(killBackground: v)),
          ),
          const RowDivider(),
          _SwitchRow(
            title: 'Bildirimleri sustur',
            subtitle: 'Oyun sırasında Rahatsız Etme (yalnızca öncelikliler) açılır; bildirimler '
                'takılma ve ekran uyanması yaratmaz.',
            value: cfg.dnd,
            onChanged: busy ? null : (v) => set(cfg.copyWith(dnd: v)),
          ),
          const RowDivider(),
          _SwitchRow(
            title: 'Pil Tasarrufu\'nu aç',
            subtitle: 'Sistemin Pil Tasarrufu modu oyun boyunca açık kalır; çoğu cihazda '
                'işlemciyi ve arka plan işlerini kısar. Oyun bitince eski haline döner.',
            value: cfg.batterySaver,
            onChanged: busy ? null : (v) => set(cfg.copyWith(batterySaver: v)),
          ),
          const RowDivider(),
          _SwitchRow(
            title: 'İşlemci hızını sınırla (root)',
            subtitle: 'En güçlü iki çekirdek kümesi %70 hızla çalışır; ısı ve hız dalgalanması azalır. '
                'Yalnızca root ile çalışır, Shizuku ile uygulanamaz.',
            value: cfg.cpuCap,
            onChanged: busy ? null : (v) => set(cfg.copyWith(cpuCap: v)),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _Group(
        icon: Icons.shield_moon_rounded,
        title: 'Isı ve güvenlik',
        summary: [
          cfg.autoRevert ? 'otomatik geri alma' : 'geri alma elle',
          if (cfg.autoRevert) (cfg.guardTempC == 0 ? 'ısı koruması kapalı' : 'koruma ${cfg.guardTempC} °C'),
        ].join(' · '),
        children: [
          _SwitchRow(
            title: 'Oyun kapanınca otomatik geri al',
            subtitle: 'Cihazda küçük bir izleyici çalışır: oyun yaklaşık 40 saniye ön planda '
                'olmazsa ayarlar kendiliğinden eski haline döner; oyun boyunca FPS/ısı/işlemci '
                'hızı kaydedilir. Terminal kapansa da çalışır.',
            value: cfg.autoRevert,
            onChanged: busy ? null : (v) => set(cfg.copyWith(autoRevert: v)),
          ),
          const RowDivider(),
          const SizedBox(height: 12),
          const _Label('Isı koruması eşiği (pil sıcaklığı)'),
          const SizedBox(height: 8),
          _Choices<int>(
            values: kGuardTempChoices,
            selected: cfg.guardTempC,
            label: (v) => v == 0 ? 'Kapalı' : '$v °C',
            onSelected: busy || !cfg.autoRevert ? null : (v) => set(cfg.copyWith(guardTempC: v)),
          ),
          const SizedBox(height: 6),
          _Hint(cfg.autoRevert
              ? 'Pil sıcaklığı (ya da sistemin ısıl durumu) art arda iki ölçümde eşiğe ulaşırsa '
                  'izleyici bir kez daha sıkılaştırır: parlaklığı daha çok kısar, Pil Tasarrufu\'nu '
                  'açar (seçiliyse) ve root varsa işlemciyi daha çok sınırlar. Oyun bitince hepsi geri alınır.'
              : 'Isı koruması izleyiciye bağlıdır; açmak için otomatik geri almayı açın.'),
        ],
      ),
    ];
  }
}

IconData _presetIcon(int i) {
  switch (i) {
    case 0:
      return Icons.ac_unit_rounded;
    case 1:
      return Icons.eco_rounded;
    case 2:
      return Icons.speed_rounded;
    default:
      return Icons.bolt_rounded;
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4));
}

class _Group extends StatelessWidget {
  const _Group({
    required this.icon,
    required this.title,
    required this.summary,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String summary;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Icon(icon, color: AppColors.muted),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ),
          children: children,
        ),
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.faded(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.sports_esports_rounded, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          const Text('Bir oyun seçin', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            'Yüklü herhangi bir oyunu ekleyin. Her oyunun ayarı ayrı saklanır; tek dokunuşla '
            'ısıyı, GPU yükünü ve pil tüketimini azaltıp oyunu açarız. Oyun kapanınca her şey '
            'eski haline döner.',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Oyun Seç', icon: Icons.add_rounded, onPressed: onAdd),
        ],
      ),
    );
  }
}

class _GameStrip extends StatelessWidget {
  const _GameStrip({required this.game, required this.busy, required this.onAdd});

  final GameModeController game;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final g in game.games)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                selected: g.package == game.selectedPackage,
                onSelected: busy ? null : (_) => game.selectGame(g.package),
              ),
            ),
          ActionChip(
            avatar: Icon(Icons.add_rounded, size: 18, color: AppColors.text),
            label: const Text('Oyun ekle'),
            onPressed: busy ? null : onAdd,
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.control,
    required this.game,
    required this.onStart,
    required this.onApply,
    required this.onStop,
  });

  final ControlController control;
  final GameModeController game;
  final VoidCallback onStart;
  final VoidCallback onApply;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final ready = control.ready;
    final busy = game.busy;
    final here = game.activeForSelected;
    final otherActive = game.active && !here;
    final installed = game.installed;
    final hz = game.displayHz;
    final color = !ready ? AppColors.warn : (here ? AppColors.good : AppColors.primary);
    final name = game.selectedName;
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    return AppCard(
      borderColor: color.faded(0.45),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color.faded(0.14), borderRadius: BorderRadius.circular(14)),
                child: Text(letter, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      game.config.package,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                label: here ? 'Oyun modu AÇIK' : 'Oyun modu kapalı',
                color: here ? AppColors.good : AppColors.muted,
              ),
              if (otherActive) StatusPill(label: 'Başka bir oyunda açık', color: AppColors.warn),
              if (ready && installed != null)
                StatusPill(
                  label: installed ? 'Oyun yüklü' : 'Oyun bulunamadı',
                  color: installed ? AppColors.good : AppColors.warn,
                ),
              if (hz != null) StatusPill(label: 'Ekran ${hz.round()} Hz', color: AppColors.muted),
              if (here && game.watchdogAlive != null)
                StatusPill(
                  label: game.watchdogAlive! ? 'Otomatik geri alma: izliyor' : 'Otomatik geri alma: kapalı',
                  color: game.watchdogAlive! ? AppColors.good : AppColors.warn,
                ),
            ],
          ),
          if (!ready) ...[
            const SizedBox(height: 10),
            Text(
              'Oyun modu için tek seferlik kurulum gerekiyor. Başlat\'a basınca kurulum açılır.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
            ),
          ],
          if (game.syncNote != null) ...[
            const SizedBox(height: 10),
            Text(game.syncNote!, style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: here ? 'Yeniden Uygula ve Başlat' : 'Başlat',
            icon: Icons.play_arrow_rounded,
            busy: busy,
            onPressed: busy ? null : onStart,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SoftButton(
                  label: 'Sadece Uygula',
                  icon: Icons.tune_rounded,
                  onPressed: busy ? null : onApply,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SoftButton(
                  label: 'Geri Al',
                  icon: Icons.undo_rounded,
                  color: game.active ? AppColors.warn : null,
                  onPressed: busy || !game.active ? null : onStop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetList extends StatelessWidget {
  const _PresetList({required this.game, required this.busy});

  final GameModeController game;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cfg = game.config;
    GamePreset? matched;
    for (final p in kGamePresets) {
      if (p.matches(cfg)) matched = p;
    }
    return Column(
      children: [
        for (final p in kGamePresets)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: busy ? null : () => game.applyPreset(p),
              borderColor: identical(p, matched) ? AppColors.primary.faded(0.6) : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (identical(p, matched) ? AppColors.primary : AppColors.muted).faded(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _presetIcon(p.icon),
                      size: 20,
                      color: identical(p, matched) ? AppColors.primary : AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                        const SizedBox(height: 3),
                        _Hint(p.subtitle),
                      ],
                    ),
                  ),
                  if (identical(p, matched))
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
                    ),
                ],
              ),
            ),
          ),
        if (matched == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: const _Hint('Özel ayar: aşağıdaki ayrıntılı ayarlarda değişiklik yaptınız.'),
          ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.game, required this.busy});

  final GameModeController game;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final sug = game.suggestion;
    if (sug == null) return const SizedBox.shrink();
    final label = sug.fps == null
        ? 'Uygula: ${sug.scale >= 1 ? 'Tam' : '%${(sug.scale * 100).round()}'} çözünürlük'
        : 'Uygula: %${(sug.scale * 100).round()} · ${sug.fps} FPS';
    return AppCard(
      borderColor: AppColors.warn.faded(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Öneri', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          const SizedBox(height: 4),
          _Hint(sug.reason),
          const SizedBox(height: 10),
          SoftButton(
            label: label,
            icon: Icons.auto_fix_high_rounded,
            onPressed: busy ? null : game.applySuggestion,
          ),
        ],
      ),
    );
  }
}

/// Yüklü uygulamalardan oyun seçme sayfası.
class _GamePicker extends StatefulWidget {
  const _GamePicker({required this.existing});

  final Set<String> existing;

  @override
  State<_GamePicker> createState() => _GamePickerState();
}

class _GamePickerState extends State<_GamePicker> {
  List<AppInfo> _apps = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final apps = await AppsService().list(includeSystemApps: false);
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loading = false;
    });
  }

  List<AppInfo> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _apps;
    return _apps
        .where((a) => a.name.toLowerCase().contains(q) || a.packageName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(4)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 14, 22, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Oyun seç', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autocorrect: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Oyun ara',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? Center(child: Text('Uygulama bulunamadı.', style: TextStyle(color: AppColors.muted)))
                      : ListView.builder(
                          controller: scroll,
                          itemCount: list.length,
                          itemBuilder: (ctx, i) {
                            final a = list[i];
                            final added = widget.existing.contains(a.packageName);
                            final icon = a.icon;
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: (icon == null || icon.isEmpty)
                                      ? Icon(Icons.android_rounded, color: AppColors.muted)
                                      : Image.memory(icon, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 96),
                                ),
                              ),
                              title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                a.packageName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.muted, fontSize: 12),
                              ),
                              trailing: added ? Icon(Icons.check_rounded, color: AppColors.good) : null,
                              onTap: () => Navigator.pop(context, SavedGame(a.packageName, a.name)),
                            );
                          },
                        ),
            ),
          ],
        ),
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
          item('Çok sayıda birim, büyük hesaplar ya da yoğun fizik içeren oyunlarda yavaşlamanın büyük '
              'kısmı işlemciden gelir. Bu durumda çözünürlük düşürmek ısınmayı ve pili belirgin azaltır, '
              'akıcılığı ise sınırlı artırır.'),
          item('Ana sayfadaki sıcaklık PİL sıcaklığıdır. Oyun bittikten sonra da bir süre yüksek kalır; '
              'şarj olurken oynamak, kılıf ve sıcak ortam üstüne ekler. \"Buz\" modu ve 38 °C ısı koruması '
              'ısıyı en çok düşüren seçimdir; yine de oyun işlemci kaynaklıysa sıcaklık tamamen önlenemez.'),
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
