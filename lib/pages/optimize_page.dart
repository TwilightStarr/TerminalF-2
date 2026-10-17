import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/profile.dart';
import '../models/tweak_model.dart';
import '../state/control_controller.dart';
import '../utils/tweak_status.dart';
import '../widgets/control_setup_sheet.dart';
import '../widgets/log_sheet.dart';
import '../widgets/ui.dart';

/// Optimize sayfası: önce hazır profiller (tek dokunuş), altında tek tek ayarlar.
class OptimizePage extends StatelessWidget {
  const OptimizePage({super.key, required this.control});

  final ControlController control;

  Future<void> _runProfile(BuildContext context, OptimizationProfile profile, {required bool apply}) async {
    if (!control.ready) {
      await showControlSetup(context, control);
      return;
    }
    final result = await control.runProfile(profile, apply: apply);
    if (result.applied + result.failed > 0) {
      control.reportDone(profile.title, result.summary, ok: result.failed == 0);
    }
    if (!context.mounted) return;
    showToast(context, '${profile.title}: ${result.summary}');
  }

  Future<void> _toggle(BuildContext context, Tweak tweak, bool apply) async {
    if (!control.ready) {
      await showControlSetup(context, control);
      return;
    }
    if (apply && tweak.dangerous) {
      final ok = await confirmDialog(
        context,
        title: tweak.title,
        message: '${tweak.description}\n\nBu işlem sistem bileşenlerini etkiler. Geri alınabilir, ama emin misiniz?',
        confirmLabel: 'Uygula',
        danger: true,
      );
      if (!ok || !context.mounted) return;
    }
    final outcome = await control.setTweak(tweak, apply: apply);
    if (!context.mounted) return;
    showOutcome(context, outcome);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: control,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Optimize', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    tooltip: 'İşlem günlüğü',
                    onPressed: () => showLogSheet(context, control),
                    icon: const Icon(Icons.receipt_long_rounded, color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _AccessCard(control: control),
              if (control.busy) ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(control.busyLabel ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      const ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                        child: LinearProgressIndicator(minHeight: 6),
                      ),
                    ],
                  ),
                ),
              ],
              const SectionHeader('Hazır Profiller'),
              for (final profile in kProfiles) ...[
                _ProfileCard(
                  profile: profile,
                  control: control,
                  onApply: () => _runProfile(context, profile, apply: true),
                  onRevert: () => _runProfile(context, profile, apply: false),
                ),
                const SizedBox(height: 12),
              ],
              const SectionHeader('Tüm Ayarlar'),
              for (final category in TweakCategory.values) ..._categorySection(context, category),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _categorySection(BuildContext context, TweakCategory category) {
    final items = control.tweaks.where((t) => t.category == category).toList();
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
        child: Text(
          category.label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _TweakRow(
                tweak: items[i],
                state: control.stateOf(items[i].id),
                working: control.isWorking(items[i].id),
                locked: control.busy,
                onChanged: (on) => _toggle(context, items[i], on),
              ),
              if (i != items.length - 1) const RowDivider(),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
    ];
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.control});

  final ControlController control;

  @override
  Widget build(BuildContext context) {
    final ready = control.ready;
    final color = control.checking ? AppColors.muted : (ready ? AppColors.good : AppColors.warn);
    return AppCard(
      borderColor: color.faded(0.4),
      onTap: () => showControlSetup(context, control),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.faded(0.14), borderRadius: BorderRadius.circular(12)),
            child: control.checking
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Icon(ready ? Icons.verified_rounded : Icons.lock_outline_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(control.headline, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  ready
                      ? 'Profiller ve ayarlar kullanıma hazır.'
                      : 'Optimizasyon için tek seferlik kurulum gerekiyor. Dokunun.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.control,
    required this.onApply,
    required this.onRevert,
  });

  final OptimizationProfile profile;
  final ControlController control;
  final VoidCallback onApply;
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) {
    final total = control.toggleCount(profile);
    final active = control.activeCount(profile);
    final allOn = profile.reversible && total > 0 && active == total;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.brand,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(profile.icon, color: AppColors.bg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(profile.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              if (control.ready && profile.reversible && total > 0)
                StatusPill(
                  label: allOn ? 'Etkin' : '$active/$total açık',
                  color: allOn ? AppColors.good : AppColors.muted,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            profile.description,
            style: const TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: profile.reversible ? (allOn ? 'Yeniden Uygula' : 'Uygula') : 'Çalıştır',
                  icon: Icons.play_arrow_rounded,
                  onPressed: control.busy ? null : onApply,
                ),
              ),
              if (profile.reversible) ...[
                const SizedBox(width: 10),
                SoftButton(
                  label: 'Geri Al',
                  icon: Icons.undo_rounded,
                  onPressed: control.busy ? null : onRevert,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TweakRow extends StatelessWidget {
  const _TweakRow({
    required this.tweak,
    required this.state,
    required this.working,
    required this.locked,
    required this.onChanged,
  });

  final Tweak tweak;
  final TweakState state;
  final bool working;
  final bool locked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final Widget trailing;
    if (working) {
      trailing = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      );
    } else if (tweak.isToggle) {
      trailing = Switch(
        value: state == TweakState.on,
        onChanged: locked ? null : onChanged,
      );
    } else {
      trailing = SoftButton(
        label: 'Çalıştır',
        onPressed: locked ? null : () => onChanged(true),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tweak.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 3),
                Text(
                  tweak.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35),
                ),
                if (tweak.isToggle && state == TweakState.unknown) ...[
                  const SizedBox(height: 4),
                  const Text('Durum okunamadı', style: TextStyle(color: AppColors.warn, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}
