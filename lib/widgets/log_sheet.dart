import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../state/control_controller.dart';
import 'ui.dart';

/// İşlem günlüğü: arayüzü kalabalıklaştırmadan, gerektiğinde açılan alt sayfa.
Future<void> showLogSheet(BuildContext context, ControlController control) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => ListenableBuilder(
        listenable: control,
        builder: (ctx, _) {
          final lines = control.log.reversed.toList();
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
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 12, 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'İşlem Günlüğü',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton(
                      onPressed: lines.isEmpty ? null : control.clearLog,
                      child: const Text('Temizle'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: lines.isEmpty
                    ? Center(
                        child: Text(
                          'Henüz bir işlem yapılmadı.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                        itemCount: lines.length,
                        itemBuilder: (ctx, i) {
                          final line = lines[i];
                          final color = line.contains('✗')
                              ? AppColors.danger
                              : line.contains('✓')
                                  ? AppColors.good
                                  : AppColors.muted;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(
                              line,
                              style: TextStyle(color: color, fontSize: 12.5, height: 1.35),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// Sonuç için kısa bildirim (başarı/hata ayrımı yok, metin zaten açık).
void showOutcome(BuildContext context, TweakOutcome outcome) {
  showToast(context, outcome.message);
}
