import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../core/theme.dart';
import '../services/apps_service.dart';
import '../services/settings_service.dart';
import '../state/control_controller.dart';
import '../utils/package_safety.dart';
import '../widgets/control_setup_sheet.dart';
import '../widgets/log_sheet.dart';
import '../widgets/ui.dart';

/// Uygulamalar: ara, filtrele, dokun, yönet. Yetki varsa gerçek zorla durdur,
/// önbellek temizleme, dondurma ve kaldırma; yoksa sistem ekranlarına yönlendirir.
class AppsPage extends StatefulWidget {
  const AppsPage({super.key, required this.control});

  final ControlController control;

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  final _service = AppsService();
  final _settings = SettingsService();
  final _searchController = TextEditingController();

  List<AppInfo> _apps = const [];
  bool _loading = true;
  bool _showSystem = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _showSystem = await _settings.getShowSystemApps();
    await _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final apps = await _service.list(includeSystemApps: _showSystem);
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loading = false;
    });
  }

  Future<void> _setShowSystem(bool value) async {
    setState(() => _showSystem = value);
    await _settings.setShowSystemApps(value);
    await _load();
  }

  List<AppInfo> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _apps;
    return _apps
        .where((a) => a.name.toLowerCase().contains(q) || a.packageName.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _openActions(AppInfo app) async {
    final reload = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _ActionsSheet(app: app, control: widget.control, service: _service),
    );
    if (reload == true) await _load();
  }

  Future<void> _openFrozen() async {
    if (!widget.control.ready) {
      await showControlSetup(context, widget.control);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _FrozenSheet(control: widget.control),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Uygulamalar', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'Dondurulmuş uygulamalar',
                  onPressed: _openFrozen,
                  icon: const Icon(Icons.ac_unit_rounded, color: AppColors.muted),
                ),
                IconButton(
                  tooltip: 'Yenile',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: AppColors.text),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: 'Uygulama ara',
                hintStyle: const TextStyle(color: AppColors.muted),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _loading ? 'Yükleniyor…' : '${list.length} uygulama',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
                const Text('Sistem uygulamaları', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(width: 6),
                Switch(value: _showSystem, onChanged: _setShowSystem),
              ],
            ),
          ),
          Expanded(child: _buildList(list)),
        ],
      ),
    );
  }

  Widget _buildList(List<AppInfo> list) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _apps.isEmpty
                ? 'Uygulama listesi alınamadı.\nBu özellik yalnızca Android\'de çalışır.'
                : 'Aramanızla eşleşen uygulama yok.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.45),
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceHigh,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: list.length,
        itemExtent: 68,
        itemBuilder: (context, i) {
          final app = list[i];
          return _AppTile(app: app, onTap: () => _openActions(app));
        },
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app, required this.onTap});

  final AppInfo app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            _AppIcon(bytes: app.icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_horiz_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.bytes, this.size = 44});

  final Uint8List? bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final b = bytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: SizedBox(
        width: size,
        height: size,
        child: (b == null || b.isEmpty)
            ? Container(
                color: AppColors.surfaceHigh,
                child: const Icon(Icons.android_rounded, color: AppColors.muted),
              )
            : Image.memory(b, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 96),
      ),
    );
  }
}

class _ActionsSheet extends StatefulWidget {
  const _ActionsSheet({required this.app, required this.control, required this.service});

  final AppInfo app;
  final ControlController control;
  final AppsService service;

  @override
  State<_ActionsSheet> createState() => _ActionsSheetState();
}

class _ActionsSheetState extends State<_ActionsSheet> {
  String? _working;

  String get _pkg => widget.app.packageName;

  Future<void> _do(String label, Future<TweakOutcome> Function() action, {bool reload = false}) async {
    setState(() => _working = label);
    final outcome = await action();
    if (!mounted) return;
    setState(() => _working = null);
    showOutcome(context, outcome);
    if (outcome.ok && reload) Navigator.of(context).pop(true);
  }

  bool _needControl() {
    if (widget.control.ready) return false;
    showControlSetup(context, widget.control);
    return true;
  }

  Future<void> _forceStop() async {
    if (!widget.control.ready) {
      await widget.service.openSystemSettings(_pkg);
      if (!mounted) return;
      showToast(context, 'Açılan ekranda "Zorla Durdur"a basın. Tek dokunuş için tam kontrolü etkinleştirin.');
      return;
    }
    await _do('Durdur', () => widget.control.forceStop(_pkg));
  }

  Future<void> _freeze() async {
    if (_needControl()) return;
    if (isProtectedPackage(_pkg)) {
      showToast(context, 'Bu uygulama sistem için kritik; dondurulamaz.');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: '${widget.app.name} dondurulsun mu?',
      message: 'Uygulama devre dışı kalır ve listeden/ekrandan kaybolur. '
          'Üstteki ❄ düğmesinden istediğiniz zaman tekrar etkinleştirebilirsiniz.',
      confirmLabel: 'Dondur',
    );
    if (!ok || !mounted) return;
    await _do('Dondur', () => widget.control.freeze(_pkg), reload: true);
  }

  Future<void> _uninstall() async {
    if (isProtectedPackage(_pkg)) {
      showToast(context, 'Bu uygulama sistem için kritik; kaldırılamaz.');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: '${widget.app.name} kaldırılsın mı?',
      message: widget.control.ready
          ? 'Uygulama bu kullanıcı için kaldırılır. Sistem uygulamalarını ileride geri yüklemek zor olabilir.'
          : 'Sistemin kaldırma onayı açılacak.',
      confirmLabel: 'Kaldır',
      danger: true,
    );
    if (!ok || !mounted) return;
    if (widget.control.ready) {
      await _do('Kaldır', () => widget.control.uninstallForUser(_pkg), reload: true);
    } else {
      final done = await widget.service.uninstall(_pkg);
      if (!mounted) return;
      if (done) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _AppIcon(bytes: app.icon, size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: [
                _ActionButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'Aç',
                  onTap: () async {
                    await widget.service.launch(_pkg);
                    if (context.mounted) Navigator.of(context).pop(false);
                  },
                ),
                _ActionButton(
                  icon: Icons.stop_circle_outlined,
                  label: 'Durdur',
                  busy: _working == 'Durdur',
                  onTap: _forceStop,
                ),
                _ActionButton(
                  icon: Icons.cleaning_services_rounded,
                  label: 'Önbellek Temizle',
                  busy: _working == 'Önbellek',
                  onTap: () {
                    if (_needControl()) return;
                    _do('Önbellek', () => widget.control.clearAppCache(_pkg));
                  },
                ),
                _ActionButton(
                  icon: Icons.info_outline_rounded,
                  label: 'Sistem Bilgisi',
                  onTap: () => widget.service.openSystemSettings(_pkg),
                ),
                _ActionButton(
                  icon: Icons.ac_unit_rounded,
                  label: 'Dondur',
                  busy: _working == 'Dondur',
                  onTap: _freeze,
                ),
                _ActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Kaldır',
                  danger: true,
                  busy: _working == 'Kaldır',
                  onTap: _uninstall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.text;
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dondurulmuş (devre dışı) uygulamaların listesi ve tek dokunuşla geri alma.
class _FrozenSheet extends StatefulWidget {
  const _FrozenSheet({required this.control});

  final ControlController control;

  @override
  State<_FrozenSheet> createState() => _FrozenSheetState();
}

class _FrozenSheetState extends State<_FrozenSheet> {
  List<String>? _packages;
  String? _error;
  String? _working;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await widget.control.exec('pm list packages -d');
      if (!mounted) return;
      setState(() {
        _packages = parsePackageList(result.output);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Liste okunamadı.');
    }
  }

  Future<void> _enable(String pkg) async {
    setState(() => _working = pkg);
    final outcome = await widget.control.unfreeze(pkg);
    if (!mounted) return;
    setState(() => _working = null);
    showOutcome(context, outcome);
    if (outcome.ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final packages = _packages;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scroll) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 16, 22, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Dondurulmuş Uygulamalar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.muted)))
                  : packages == null
                      ? const Center(child: CircularProgressIndicator())
                      : packages.isEmpty
                          ? const Center(
                              child: Text('Dondurulmuş uygulama yok.',
                                  style: TextStyle(color: AppColors.muted)),
                            )
                          : ListView.builder(
                              controller: scroll,
                              padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                              itemCount: packages.length,
                              itemBuilder: (context, i) {
                                final pkg = packages[i];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          pkg,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      _working == pkg
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(strokeWidth: 2.2),
                                            )
                                          : SoftButton(
                                              label: 'Etkinleştir',
                                              onPressed: () => _enable(pkg),
                                            ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}
