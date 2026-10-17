import 'package:flutter/material.dart';

import '../core/theme.dart';

/// TerminalF logosu: komut istemi (`>`) + imleç (`_`). `assets/icon/icon.svg`
/// ve Android ikonlarıyla AYNI geometri (bkz. `branding/generate_logo.py`).
/// Rengi kullanıcı Cihaz > Görünüm bölümünden değiştirebilir; varsayılan
/// olarak seçili temanın renklerini izler (siyah-beyaz temada beyaz).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40, this.framed = true});

  final double size;

  /// `true` ise yuvarlatılmış koyu zemin üzerinde (uygulama ikonu gibi).
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.logoColors;
    return Semantics(
      label: 'TerminalF logosu',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _LogoPainter(
            framed: framed,
            markA: colors[0],
            markB: colors[1],
            frameA: AppColors.logoFrameA,
            frameB: AppColors.logoFrameB,
            cursor: framed ? const Color(0xFFF5F5F5) : AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({
    required this.framed,
    required this.markA,
    required this.markB,
    required this.frameA,
    required this.frameB,
    required this.cursor,
  });

  final bool framed;
  final Color markA;
  final Color markB;
  final Color frameA;
  final Color frameB;
  final Color cursor;

  @override
  void paint(Canvas canvas, Size size) {
    // Tüm geometri 1024 birimlik kareye göre tanımlı.
    final scale = size.width / 1024.0;
    canvas.save();
    canvas.scale(scale);

    if (framed) {
      const frame = Rect.fromLTWH(0, 0, 1024, 1024);
      final rrect = RRect.fromRectAndRadius(frame, const Radius.circular(232));
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [frameA, frameB],
          ).createShader(frame),
      );
      // İnce iç çerçeve: siyah zeminde de logonun kenarı seçilsin.
      canvas.drawRRect(
        RRect.fromRectAndRadius(frame.deflate(4), const Radius.circular(228)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = const Color(0x1FFFFFFF),
      );
    }

    // ">" işareti: kalın, uçları ve köşesi yuvarlak tek çizgi.
    final chevron = Path()
      ..moveTo(318, 316)
      ..lineTo(548, 512)
      ..lineTo(318, 708);
    canvas.drawPath(
      chevron,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 132
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [markA, markB],
        ).createShader(const Rect.fromLTRB(250, 250, 620, 780)),
    );

    // İmleç.
    canvas.drawRRect(
      RRect.fromLTRBR(598, 664, 790, 768, const Radius.circular(34)),
      Paint()..color = cursor,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) =>
      old.framed != framed ||
      old.markA != markA ||
      old.markB != markB ||
      old.frameA != frameA ||
      old.frameB != frameB ||
      old.cursor != cursor;
}
