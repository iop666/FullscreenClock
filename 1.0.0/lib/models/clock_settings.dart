import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

/// 时钟模式:标准 / 圆盘(翻页模式已删除)
enum ClockMode { standard, analog }

/// 明暗模式:白天 / 黑夜 / 跟随系统
enum ClockTheme { light, dark, system }

/// 内置字体样式(含打包的 HarmonyOS Sans 与 MiSans,以及运行时导入字体)
enum FontStyleOption { normal, mono, serif, harmonyos, misans, custom }

/// 字体颜色模式:跟随主题 / 自定义
enum FontColorMode { follow, custom }

/// 背景颜色模式:跟随主题 / 自定义
enum BackgroundColorMode { follow, custom }

/// 圆盘时钟样式
enum AnalogClockStyle { minimal, classic, roman, dots }

/// 一套自定义配色
@immutable
class CustomPalette {
  const CustomPalette({required this.bg, required this.fg, required this.accent});

  final Color bg;
  final Color fg;
  final Color accent;

  Map<String, int> toJson() => {
        'bg': bg.toARGB32(),
        'fg': fg.toARGB32(),
        'accent': accent.toARGB32(),
      };

  factory CustomPalette.fromJson(Map<String, dynamic> json) => CustomPalette(
        bg: Color(json['bg'] as int),
        fg: Color(json['fg'] as int),
        accent: Color(json['accent'] as int),
      );
}

/// 时钟全部设置项(不可变对象,通过 copyWith 派生新实例)
@immutable
class ClockSettings {
  const ClockSettings({
    this.mode = ClockMode.standard,
    this.theme = ClockTheme.dark,
    this.paletteIndex = 0,
    this.fontScale = 1.0,
    this.fontStyle = FontStyleOption.normal,
    this.fontWeight = 400,
    this.fontColorMode = FontColorMode.follow,
    this.fontColorLight,
    this.fontColorDark,
    this.bgColorMode = BackgroundColorMode.follow,
    this.bgColorLight,
    this.bgColorDark,
    this.customFontFamily,
    this.use24Hour = true,
    this.showSeconds = true,
    this.keepAwake = true,
    this.analogStyle = AnalogClockStyle.minimal,
    this.analogScale = 1.0,
    this.customPalettes = const [],
  });

  final ClockMode mode;

  /// 明暗:白天 / 黑夜 / 跟随系统
  final ClockTheme theme;

  /// 配色方案索引:0~5 为内置预设,6 及以上为自定义方案(customPalettes[i-6])
  final int paletteIndex;

  /// 时钟缩放(0.1 ~ 10.0,即 10% ~ 1000%)
  final double fontScale;
  final FontStyleOption fontStyle;

  /// 字体粗细(100 ~ 900,步进 100)
  final int fontWeight;

  /// 字体颜色:跟随主题或自定义
  final FontColorMode fontColorMode;

  /// 自定义字体颜色(仅 fontColorMode == custom 时生效)
  final Color? fontColorLight;
  final Color? fontColorDark;

  /// 背景颜色:跟随主题或自定义
  final BackgroundColorMode bgColorMode;

  /// 自定义背景颜色(仅 bgColorMode == custom 时生效)
  final Color? bgColorLight;
  final Color? bgColorDark;

  /// 运行时导入的自定义字体族名(仅 fontStyle == custom 时生效)
  final String? customFontFamily;
  final bool use24Hour;
  final bool showSeconds;
  final bool keepAwake;
  final AnalogClockStyle analogStyle;

  /// 圆盘时钟缩放(0.1 ~ 3.0,即 10% ~ 300%)
  final double analogScale;

  /// 自定义配色方案(最多 10 个)
  final List<CustomPalette> customPalettes;

  /// 内置配色方案数量
  static const presetPaletteCount = 6;

  /// 默认设置
  static const defaults = ClockSettings();

  /// 对应 Flutter 的 fontFamily;null 表示使用默认字体
  String? get fontFamily => switch (fontStyle) {
        FontStyleOption.normal => null,
        FontStyleOption.mono => 'monospace',
        FontStyleOption.serif => 'serif',
        FontStyleOption.harmonyos => 'HarmonyOS Sans',
        FontStyleOption.misans => 'MiSans',
        FontStyleOption.custom => customFontFamily,
      };

  ClockSettings copyWith({
    ClockMode? mode,
    ClockTheme? theme,
    int? paletteIndex,
    double? fontScale,
    FontStyleOption? fontStyle,
    int? fontWeight,
    FontColorMode? fontColorMode,
    Color? fontColorLight,
    Color? fontColorDark,
    BackgroundColorMode? bgColorMode,
    Color? bgColorLight,
    Color? bgColorDark,
    String? customFontFamily,
    bool? use24Hour,
    bool? showSeconds,
    bool? keepAwake,
    AnalogClockStyle? analogStyle,
    double? analogScale,
    List<CustomPalette>? customPalettes,
  }) {
    return ClockSettings(
      mode: mode ?? this.mode,
      theme: theme ?? this.theme,
      paletteIndex: paletteIndex ?? this.paletteIndex,
      fontScale: fontScale ?? this.fontScale,
      fontStyle: fontStyle ?? this.fontStyle,
      fontWeight: fontWeight ?? this.fontWeight,
      fontColorMode: fontColorMode ?? this.fontColorMode,
      fontColorLight: fontColorLight ?? this.fontColorLight,
      fontColorDark: fontColorDark ?? this.fontColorDark,
      bgColorMode: bgColorMode ?? this.bgColorMode,
      bgColorLight: bgColorLight ?? this.bgColorLight,
      bgColorDark: bgColorDark ?? this.bgColorDark,
      customFontFamily: customFontFamily ?? this.customFontFamily,
      use24Hour: use24Hour ?? this.use24Hour,
      showSeconds: showSeconds ?? this.showSeconds,
      keepAwake: keepAwake ?? this.keepAwake,
      analogStyle: analogStyle ?? this.analogStyle,
      analogScale: analogScale ?? this.analogScale,
      customPalettes: customPalettes ?? this.customPalettes,
    );
  }
}
