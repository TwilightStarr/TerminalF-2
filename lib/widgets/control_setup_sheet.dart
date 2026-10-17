import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/apps_service.dart';
import '../services/catalog_service.dart';
import '../state/control_controller.dart';
import 'ui.dart';

const String _shizukuPackage = 'moe.shizuku.privileged.api';
const String _shizukuUrl = 'https://shizuku.rikka.app/download/';

/// "Tam Kontrolü Etkinleştir" sihirbazı. Kullanıcı yol seçmez: kök varsa
/// otomatik kullanılır, yoksa Shizuku adım adım hazırlanır.
Future<void> showControlSetup(BuildContext context, ControlController control) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _SetupBody(control: control),
  );
}

class _SetupBody extends StatelessWidget {
  const _SetupBody({required this.control});

  final ControlController control;

  Future<void> _openShizuku(BuildContext context) async {
    await AppsService().launch(_shizukuPackage);
    if (!context.mounted) return;
    showToast(context, 'Shizuku açılıyor… Açılmazsa önce indirin.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: control,
      builder: (context, _) {
        final running = control.shizukuRunning || control.path == AccessPath.root;
        final permitted = control.shizukuPermitted || control.path == AccessPath.root;
        final ready = control.ready;

        Widget primary;
        if (ready) {
          primary = PrimaryButton(
            label: 'Hazır — Kapat',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.of(context).pop(),
          );
        } else if (!running) {
          primary = PrimaryButton(
            label: 'Shizuku\'yu Aç',
            icon: Icons.open_in_new_rounded,
            onPressed: () => _openShizuku(context),
          );
        } else {
          primary = PrimaryButton(
            label: 'İzin Ver ve Bitir',
            icon: Icons.lock_open_rounded,
            busy: control.settingUp,
            onPressed: control.setUp,
          );
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 14, 22, 18 + MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
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
                  const Text(
                    'Tam Kontrolü Etkinleştir',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Telefonu gerçekten yönetebilmek (uygulamaları durdurmak, '
                    'önbellek temizlemek, sistem ayarlarını optimize etmek) için '
                    'sistem yetkisi gerekir. Root varsa otomatik kullanılır; yoksa '
                    'ücretsiz Shizuku uygulaması yeterlidir. Bilgisayar gerekmez.',
                    style: TextStyle(color: AppColors.muted, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  _Step(
                    index: 1,
                    done: running,
                    title: 'Shizuku çalışıyor',
                    detail: 'Shizuku\'yu açın ve "Kablosuz hata ayıklama ile başlat" '
                        'seçeneğini kullanın (Android 11+).',
                  ),
                  _Step(
                    index: 2,
                    done: permitted,
                    title: 'TerminalF\'e izin ver',
                    detail: 'Aşağıdaki düğme izin penceresini açar.',
                  ),
                  _Step(
                    index: 3,
                    done: ready,
                    title: 'Test komutu başarılı',
                    detail: 'Gerçek bir komut çalıştırılarak doğrulanır.',
                    last: true,
                  ),
                  if (!ready && control.error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      control.error!,
                      style: const TextStyle(color: AppColors.warn, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 18),
                  primary,
                  if (!ready) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SoftButton(
                            label: 'Shizuku\'yu İndir',
                            icon: Icons.download_rounded,
                            onPressed: () => CatalogService().openUrl(_shizukuUrl),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SoftButton(
                            label: 'Yeniden Denetle',
                            icon: Icons.refresh_rounded,
                            onPressed: control.checking ? null : control.detect,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.done,
    required this.title,
    required this.detail,
    this.last = false,
  });

  final int index;
  final bool done;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.good : AppColors.muted;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.faded(0.16),
              border: Border.all(color: color),
            ),
            child: done
                ? Icon(Icons.check_rounded, size: 17, color: color)
                : Text('$index', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(detail, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
