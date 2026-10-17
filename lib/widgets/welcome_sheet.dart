import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/notification_service.dart';
import 'app_logo.dart';
import 'ui.dart';

/// İlk açılışta bir kez gösterilen kısa karşılama. Bildirim izni burada,
/// nedeniyle birlikte istenir (bağlamsız izin penceresi yerine).
Future<void> showWelcomeSheet(BuildContext context, Notifier notifier) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _WelcomeBody(notifier: notifier),
  );
}

class _WelcomeBody extends StatefulWidget {
  const _WelcomeBody({required this.notifier});

  final Notifier notifier;

  @override
  State<_WelcomeBody> createState() => _WelcomeBodyState();
}

class _WelcomeBodyState extends State<_WelcomeBody> {
  bool _busy = false;

  Future<void> _start({required bool askPermission}) async {
    if (askPermission) {
      setState(() => _busy = true);
      await widget.notifier.requestPermission();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: AppLogo(size: 84)),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'TerminalF\'e hoş geldiniz',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 20),
            const _Point(
              icon: Icons.monitor_heart_rounded,
              title: 'Gerçek ölçümler',
              text: 'RAM, depolama, pil ve sıcaklık doğrudan cihazdan okunur.',
            ),
            const _Point(
              icon: Icons.bolt_rounded,
              title: 'Tek dokunuşla optimizasyon',
              text: 'Hazır profiller ve akıllı öneriler karmaşık ayarları sizin yerinize halleder.',
            ),
            const _Point(
              icon: Icons.notifications_active_rounded,
              title: 'Haberdar olun',
              text: 'İşlem bitince ya da telefon ısınınca, pil azalınca, depolama dolunca bildirim alın.',
            ),
            const _Point(
              icon: Icons.lock_rounded,
              title: 'Verileriniz cihazda kalır',
              text: 'Hiçbir veri dışarı gönderilmez. Bildirimleri istediğiniz zaman Cihaz > Bildirimler ve Uyarılar bölümünden kapatabilirsiniz.',
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Bildirimlere İzin Ver ve Başla',
              icon: Icons.notifications_rounded,
              busy: _busy,
              onPressed: () => _start(askPermission: true),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => _start(askPermission: false),
                child: Text('Şimdilik geç', style: TextStyle(color: AppColors.muted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.faded(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
