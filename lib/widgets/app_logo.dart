import 'package:flutter/material.dart';

import '../core/theme.dart';

/// TerminalF logosu: komut istemi (`>`) + imleç (`_`). `assets/icon/icon.svg`
/// ve Android ikonlarıyla AYNI geometri (bkz. `branding/generate_logo.py`),
/// bu yüzden uygulama içi logo ile ana ekran ikonu birebir aynı görünür.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40, this.framed = true});

  final double size;

  /// `true` ise yuvarlatılmış koyu zemin üzerinde (uygulama ikonu gibi).
  final bool framed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'TerminalF logosu',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LogoPainter(framed: framed)),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.framed});

  final bool framed;

  @override
  void paint(Canvas canvas, Size size) {
    // Tüm geometri 1024 birimlik kareye göre tanımlı.
    final scale = size.width / 1024.0;
    canvas.save();
    canvas.scale(scale);

    if (framed) {
      const frame = Rect.fromLTWH(0, 0, 1024, 1024);
      canvas.drawRRect(
        RRect.fromRectAndRadius(frame, const Radius.circular(232)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E14), Color(0xFF151E2C)],
          ).createShader(frame),
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
        ..shader = AppColors.brand.createShader(const Rect.fromLTRB(250, 250, 620, 780)),
    );

    // İmleç.
    canvas.drawRRect(
      RRect.fromLTRBR(598, 664, 790, 768, const Radius.circular(34)),
      Paint()..color = AppColors.text,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.framed != framed;
}
