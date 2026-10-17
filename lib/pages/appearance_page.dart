import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../state/app_settings.dart';
import '../utils/haptics.dart';
import '../widgets/app_logo.dart';
import '../widgets/ui.dart';

/// Görünüm: tema seçimi ve logo rengi. Varsayılan tema siyah-beyazdır.
class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  AppSettings get s => widget.settings;

  late double _hue;
  late double _light;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    final hsl = HSLColor.fromColor(Color(s.logoCustom));
    _hue = hsl.hue;
    _light = hsl.lightness.clamp(0.35, 0.85);
  }

  Color get _customColor => HSLColor.fromAHSL(1, _hue, 0.85, _light).toColor();

  void _commitCustom() {
    setState(() => _dragging = false);
    Haptics.tap();
    s.setLogoCustom(_customColor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
        title: const Text('Görünüm', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              const SectionHeader('Tema'),
              LayoutBuilder(
                builder: (context, c) {
                  const gap = 12.0;
                  final w = (c.maxWidth - gap) / 2;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final p in AppPalettes.all)
                        SizedBox(
                          width: w,
                          child: _ThemeTile(
                            palette: p,
                            selected: s.themeId == p.id,
                            onTap: () {
                              Haptics.tap();
                              s.setTheme(p.id);
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SectionHeader('Logo Rengi'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 16),
                        child: AppLogo(size: 84),
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 12,
                      children: [
                        for (final style in LogoStyle.presets)
                          _LogoSwatch(
                            label: style.name,
                            colors: style.colors.isEmpty
                                ? [AppColors.palette.logoA, AppColors.palette.logoB]
                                : (style.colors.length == 1
                                    ? [style.colors[0], style.colors[0]]
                                    : style.colors),
                            isAuto: style.id == LogoStyle.autoId,
                            selected: s.logoId == style.id,
                            onTap: () {
                              Haptics.tap();
                              s.setLogo(style.id);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const RowDivider(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _dragging || s.logoId == LogoStyle.customId
                                ? (_dragging ? _customColor : Color(s.logoCustom))
                                : AppColors.surfaceHigh,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.outline),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s.logoId == LogoStyle.customId ? 'Özel renk (seçili)' : 'Özel renk',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _HueSlider(
                      value: _hue,
                      onChanged: (v) => setState(() {
                        _hue = v;
                        _dragging = true;
                      }),
                      onChangeEnd: (_) => _commitCustom(),
                    ),
                    Slider(
                      min: 0.35,
                      max: 0.85,
                      value: _light,
                      onChanged: (v) => setState(() {
                        _light = v;
                        _dragging = true;
                      }),
                      onChangeEnd: (_) => _commitCustom(),
                    ),
                    Text(
                      'Üstteki çubuk rengi, alttaki açıklığı belirler.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SoftButton(
                label: 'Varsayılana Dön (Siyah & Beyaz)',
                icon: Icons.restart_alt_rounded,
                onPressed: () async {
                  Haptics.tap();
                  await s.setTheme(AppPalettes.defaultId);
                  await s.setLogo(LogoStyle.autoId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.palette, required this.selected, required this.onTap});

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final radius = BorderRadius.circular(20);
    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Küçük önizleme: o temanın gerçek renkleriyle.
              Container(
                height: 66,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.outline),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: p.outline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [p.primary, p.secondary],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 5,
                              width: 34,
                              decoration: BoxDecoration(
                                color: p.text,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              height: 4,
                              width: 22,
                              decoration: BoxDecoration(
                                color: p.muted,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoSwatch extends StatelessWidget {
  const _LogoSwatch({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onTap,
    this.isAuto = false,
  });

  final String label;
  final List<Color> colors;
  final bool selected;
  final bool isAuto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Logo rengi: $label',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 56,
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.text : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.outline),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                  ),
                  child: isAuto
                      ? const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF111111))
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? AppColors.text : AppColors.muted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gökkuşağı renk çubuğu (ton seçici).
class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.value, required this.onChanged, required this.onChangeEnd});

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final rainbow = [
      for (var h = 0; h <= 360; h += 30) HSLColor.fromAHSL(1, h.toDouble(), 0.85, 0.55).toColor(),
    ];
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(colors: rainbow),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 10,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: const Color(0xFFFFFFFF),
              overlayColor: const Color(0x22FFFFFF),
            ),
            child: Slider(
              min: 0,
              max: 360,
              value: value.clamp(0.0, 360.0),
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}
