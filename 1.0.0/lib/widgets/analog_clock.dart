import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/clock_settings.dart';
import '../theme/app_theme.dart';

/// 圆盘时钟:模拟表盘,支持多种样式
class AnalogClock extends StatelessWidget {
  const AnalogClock({super.key, required this.time, required this.settings});

  final DateTime time;
  final ClockSettings settings;

  @override
  Widget build(BuildContext context) {
    final palette =
        resolvePalette(settings, MediaQuery.platformBrightnessOf(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        final size =
            math.min(constraints.maxWidth, constraints.maxHeight) * settings.analogScale;
        return Center(
          child: CustomPaint(
            size: Size.square(size),
            painter: _AnalogPainter(
              time: time,
              palette: palette,
              showSeconds: settings.showSeconds,
              style: settings.analogStyle,
            ),
          ),
        );
      },
    );
  }
}

class _AnalogPainter extends CustomPainter {
  _AnalogPainter({
    required this.time,
    required this.palette,
    required this.showSeconds,
    required this.style,
  });

  final DateTime time;
  final Palette palette;
  final bool showSeconds;
  final AnalogClockStyle style;

  static const _roman = [
    'XII', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    switch (style) {
      case AnalogClockStyle.classic:
        _paintClassic(canvas, center, radius);
      case AnalogClockStyle.minimal:
        _paintMinimal(canvas, center, radius);
      case AnalogClockStyle.roman:
        _paintRoman(canvas, center, radius);
      case AnalogClockStyle.dots:
        _paintDots(canvas, center, radius);
    }

    _drawHands(canvas, center, radius);
  }

  // ---- 各样式表盘 ----

  void _paintClassic(Canvas canvas, Offset center, double radius) {
    // 外圈 + 内圈
    canvas.drawCircle(
      center,
      radius * 0.965,
      Paint()
        ..color = palette.foreground
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, radius * 0.012),
    );
    canvas.drawCircle(
      center,
      radius * 0.925,
      Paint()
        ..color = palette.secondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, radius * 0.005),
    );
    _drawTicksAndNumbers(canvas, center, radius, showNumbers: true, roman: false);
  }

  void _paintMinimal(Canvas canvas, Offset center, double radius) {
    // 细外圈
    canvas.drawCircle(
      center,
      radius * 0.97,
      Paint()
        ..color = palette.foreground.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, radius * 0.006),
    );
    _drawTicksAndNumbers(canvas, center, radius, showNumbers: false, roman: false);
  }

  void _paintRoman(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 0.965,
      Paint()
        ..color = palette.foreground
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, radius * 0.012),
    );
    _drawTicksAndNumbers(canvas, center, radius, showNumbers: true, roman: true);
  }

  void _paintDots(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 0.975,
      Paint()
        ..color = palette.secondary.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, radius * 0.004),
    );
    _drawTicksAndNumbers(canvas, center, radius, showNumbers: false, roman: false, dots: true);
  }

  /// 刻度与数字;dots=true 时整点/分钟均画圆点
  void _drawTicksAndNumbers(
    Canvas canvas,
    Offset center,
    double radius, {
    required bool showNumbers,
    required bool roman,
    bool dots = false,
  }) {
    for (var i = 0; i < 60; i++) {
      final angle = i * 2 * math.pi / 60 - math.pi / 2;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final isHour = i % 5 == 0;

      if (dots) {
        final r = isHour ? radius * 0.025 : radius * 0.012;
        canvas.drawCircle(
          center + dir * (radius * 0.87),
          r,
          Paint()..color = isHour ? palette.foreground : palette.secondary,
        );
        continue;
      }

      // 普通刻度
      if (!roman || !isHour) {
        final len = isHour ? radius * 0.085 : radius * 0.04;
        canvas.drawLine(
          center + dir * (radius * 0.85),
          center + dir * (radius * 0.85 + len),
          Paint()
            ..color = isHour ? palette.foreground : palette.secondary
            ..strokeWidth =
                isHour ? math.max(2, radius * 0.018) : math.max(1, radius * 0.007)
            ..strokeCap = StrokeCap.round,
        );
      }

      if (isHour && showNumbers) {
        final label = roman ? _roman[i ~/ 5] : (i == 0 ? '12' : '${i ~/ 5}');
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: palette.foreground,
              fontSize: roman ? radius * 0.095 : radius * 0.13,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          center + dir * (radius * 0.70) - Offset(tp.width / 2, tp.height / 2),
        );
      }
    }
  }

  // ---- 指针 ----

  void _drawHands(Canvas canvas, Offset center, double radius) {
    final hourAngle = ((time.hour % 12) + time.minute / 60) * math.pi / 6 - math.pi / 2;
    final minuteAngle = (time.minute + time.second / 60) * math.pi / 30 - math.pi / 2;
    final secondAngle = time.second * math.pi / 30 - math.pi / 2;

    switch (style) {
      case AnalogClockStyle.minimal:
        _drawArrowHand(canvas, center, hourAngle, radius * 0.46, radius * 0.030, palette.foreground);
        _drawArrowHand(canvas, center, minuteAngle, radius * 0.70, radius * 0.018, palette.foreground);
      default:
        _drawBarHand(canvas, center, hourAngle, radius * 0.48, radius * 0.030, palette.foreground);
        _drawBarHand(canvas, center, minuteAngle, radius * 0.70, radius * 0.018, palette.foreground);
    }

    if (showSeconds) {
      _drawBarHand(canvas, center, secondAngle, radius * 0.82, radius * 0.008, palette.accent);
      // 秒针尾部小圆点
      final tail = center - Offset(math.cos(secondAngle), math.sin(secondAngle)) * radius * 0.10;
      canvas.drawCircle(tail, radius * 0.012, Paint()..color = palette.accent);
    }

    // 中心点
    canvas.drawCircle(center, radius * 0.05, Paint()..color = palette.accent);
    canvas.drawCircle(center, radius * 0.018, Paint()..color = palette.background);
  }

  void _drawBarHand(
    Canvas canvas,
    Offset center,
    double angle,
    double length,
    double width,
    Color color,
  ) {
    final end = center + Offset(math.cos(angle), math.sin(angle)) * length;
    canvas.drawLine(
      center,
      end,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  /// 箭头(三角形)指针,用于极简样式
  void _drawArrowHand(
    Canvas canvas,
    Offset center,
    double angle,
    double length,
    double width,
    Color color,
  ) {
    final dir = Offset(math.cos(angle), math.sin(angle));
    final perp = Offset(-dir.dy, dir.dx);
    final tip = center + dir * length;
    final path = Path()
      ..moveTo(center.dx + perp.dx * width, center.dy + perp.dy * width)
      ..lineTo(center.dx - perp.dx * width, center.dy - perp.dy * width)
      ..lineTo(tip.dx, tip.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AnalogPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.palette != palette ||
      oldDelegate.showSeconds != showSeconds ||
      oldDelegate.style != style;
}
