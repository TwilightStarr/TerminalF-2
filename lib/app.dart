import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'pages/apps_page.dart';
import 'pages/device_page.dart';
import 'pages/home_page.dart';
import 'pages/optimize_page.dart';
import 'services/notification_service.dart';
import 'services/startup_service.dart';
import 'state/alert_monitor.dart';
import 'state/app_settings.dart';
import 'state/control_controller.dart';
import 'state/live_stats.dart';
import 'utils/haptics.dart';
import 'utils/motion.dart';
import 'widgets/welcome_sheet.dart';

class TerminalApp extends StatefulWidget {
  const TerminalApp({super.key, this.live, this.control, this.settings, this.notifier});

  /// Testlerde sahte (fake) nesne vermek için; üretimde `null` bırakılır.
  final LiveStats? live;
  final ControlController? control;
  final AppSettings? settings;
  final Notifier? notifier;

  @override
  State<TerminalApp> createState() => _TerminalAppState();
}

class _TerminalAppState extends State<TerminalApp> with SingleTickerProviderStateMixin {
  /// Tema/logo değişince arayüz yumuşakça belirir.
  late final AnimationController _themeFade =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);

  late final LiveStats _live = widget.live ?? LiveStats();
  late final ControlController _control = widget.control ?? ControlController();
  late final AppSettings _settings = widget.settings ?? AppSettings();
  late final Notifier _notifier = widget.notifier ?? NotificationService();
  late final AlertMonitor _monitor =
      AlertMonitor(live: _live, notifier: _notifier, settings: _settings);

  @override
  void initState() {
    super.initState();
    _control.notifier = _notifier;
    _control.taskNotificationsEnabled = () => _settings.taskNotifications;
    _live.start();
    _control.init();
    _appearanceKey = _settings.appearanceKey;
    _settings.addListener(_onSettingsChanged);
    _settings.load();
    _notifier.init();
    _monitor.start();
  }

  String _appearanceKey = '';

  /// Tema ya da logo rengi değişince bütün arayüzü, durumunu (sekme, kaydırma
  /// vb.) bozmadan yeniden çizer. Renkler `AppColors` üzerinden okunduğu için
  /// yalnızca `ThemeData` değişimi yetmez.
  void _onSettingsChanged() {
    final key = _settings.appearanceKey;
    if (key == _appearanceKey) return;
    _appearanceKey = key;
    AppTheme.applySystemChrome();
    setState(() {});
    if (Motion.enabled) _themeFade.forward(from: 0.25);
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _themeFade.dispose();
    _monitor.dispose();
    _live.dispose();
    _control.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TerminalF',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      builder: (context, child) => FadeTransition(
        opacity: _themeFade,
        child: child ?? const SizedBox.shrink(),
      ),
      home: AppShell(
        live: _live,
        control: _control,
        settings: _settings,
        notifier: _notifier,
      ),
    );
  }
}

/// Alt gezinme çubuğu + sayfalar. Sayfalar ilk açıldıklarında oluşturulur
/// (uygulama hızlı açılır) ve sonra bellekte tutulur (sekme değişince
/// yeniden yüklenmez, uygulama listesi yeniden taranmaz).
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.live,
    required this.control,
    required this.settings,
    required this.notifier,
  });

  final LiveStats live;
  final ControlController control;
  final AppSettings settings;
  final Notifier notifier;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _tabFade =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 240), value: 1);

  @override
  void dispose() {
    _tabFade.dispose();
    super.dispose();
  }

  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();
    applySavedPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeWelcome());
  }

  /// İlk açılışta bir kez karşılama ve bildirim izni.
  Future<void> _maybeWelcome() async {
    await widget.settings.load();
    if (!mounted || widget.settings.onboarded) return;
    await widget.settings.markOnboarded();
    if (!mounted) return;
    await showWelcomeSheet(context, widget.notifier);
  }

  Widget _pageAt(int i) {
    if (!_visited.contains(i)) return const SizedBox.shrink();
    switch (i) {
      case 0:
        return HomePage(live: widget.live, control: widget.control);
      case 1:
        return OptimizePage(control: widget.control);
      case 2:
        return AppsPage(control: widget.control);
      default:
        return DevicePage(
          live: widget.live,
          settings: widget.settings,
          notifier: widget.notifier,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Geri tuşu: önce Ana Sayfa'ya döner, orada uygulamadan çıkar.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (Motion.enabled) _tabFade.forward(from: 0.0);
          setState(() => _index = 0);
        }
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AnimatedBuilder(
        animation: _tabFade,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_tabFade.value);
          return Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: child),
          );
        },
        child: IndexedStack(
          index: _index,
          children: [for (var i = 0; i < 4; i++) _pageAt(i)],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i != _index) {
            Haptics.tap();
            if (Motion.enabled) _tabFade.forward(from: 0.0);
          }
          setState(() {
            _index = i;
            _visited.add(i);
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Optimize',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps_rounded),
            label: 'Uygulamalar',
          ),
          NavigationDestination(
            icon: Icon(Icons.smartphone_outlined),
            selectedIcon: Icon(Icons.smartphone_rounded),
            label: 'Cihaz',
          ),
        ],
      ),
    );
  }
}
