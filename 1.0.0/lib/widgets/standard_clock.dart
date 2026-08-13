import 'package:flutter/material.dart';

import '../models/clock_settings.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';

/// 标准数字时钟
class StandardClock extends StatelessWidget {
  const StandardClock({super.key, required this.time, required this.settings});

  final DateTime time;
  final ClockSettings settings;

  @override
  Widget build(BuildContext context) {
    final palette =
        resolvePalette(settings, MediaQuery.platformBrightnessOf(context));
    final text = formatClockText(time, settings);
    final parts = buildTimeParts(time, settings);
    final weight = FontWeight(settings.fontWeight);

    final timeStyle = TextStyle(
      color: palette.foreground,
      fontSize: 120 * settings.fontScale,
      fontFamily: settings.fontFamily,
      fontWeight: weight,
      letterSpacing: 2,
      height: 1.0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // AM/PM:位于时间右上角,小字号、次要色、不突出
    final ampmStyle = TextStyle(
      color: palette.secondary,
      fontSize: 26 * settings.fontScale,
      fontFamily: settings.fontFamily,
      fontWeight: weight,
      height: 1.0,
      letterSpacing: 1,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: timeStyle),
          if (parts.ampm.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                left: 10,
                top: (timeStyle.fontSize ?? 120) * 0.03,
              ),
              child: Text(parts.ampm, style: ampmStyle),
            ),
        ],
      ),
    );
  }
}
