import 'package:flutter/material.dart';

import '../models/clock_settings.dart';

/// 一套具体配色(对应某个明暗)
@immutable
class Palette {
  const Palette({
    required this.background,
    required this.foreground,
    required this.secondary,
    required this.accent,
    required this.card,
    required this.cardBorder,
  });

  /// 页面背景色
  final Color background;

  /// 主文字/指针颜色
  final Color foreground;

  /// 次要文字/刻度颜色
  final Color secondary;

  /// 强调色(秒针、AM/PM、冒号等)
  final Color accent;

  /// 翻页钟卡片底色
  final Color card;

  /// 翻页钟卡片描边/分隔线
  final Color cardBorder;
}

/// 一套配色方案:含白天(light)与黑夜(dark)两版
@immutable
class PalettePreset {
  const PalettePreset({required this.name, required this.light, required this.dark});

  final String name;
  final Palette light;
  final Palette dark;
}

/// 内置配色方案(参考 zhongguose / color.adobe 等流行色板)
const List<PalettePreset> kPalettePresets = [
  // 1. 经典:纯黑白 + 警示红
  PalettePreset(
    name: '经典',
    light: Palette(
      background: Color(0xFFFFFFFF),
      foreground: Color(0xFF1B1B1F),
      secondary: Color(0xFF8A8A93),
      accent: Color(0xFFE53935),
      card: Color(0xFFF2F2F5),
      cardBorder: Color(0xFFE0E0E6),
    ),
    dark: Palette(
      background: Color(0xFF000000),
      foreground: Color(0xFFFFFFFF),
      secondary: Color(0xFF80808A),
      accent: Color(0xFFFF5252),
      card: Color(0xFF1C1C20),
      cardBorder: Color(0xFF2E2E34),
    ),
  ),
  // 2. 墨蓝:沉稳蓝黑
  PalettePreset(
    name: '墨蓝',
    light: Palette(
      background: Color(0xFFF5F7FA),
      foreground: Color(0xFF1F2937),
      secondary: Color(0xFF9CA3AF),
      accent: Color(0xFF2563EB),
      card: Color(0xFFEDF0F5),
      cardBorder: Color(0xFFD8DEE8),
    ),
    dark: Palette(
      background: Color(0xFF0F172A),
      foreground: Color(0xFFF8FAFC),
      secondary: Color(0xFF64748B),
      accent: Color(0xFF60A5FA),
      card: Color(0xFF1E293B),
      cardBorder: Color(0xFF334155),
    ),
  ),
  // 3. 翡翠:青绿雅致
  PalettePreset(
    name: '翡翠',
    light: Palette(
      background: Color(0xFFFBFDFB),
      foreground: Color(0xFF134E4A),
      secondary: Color(0xFF94A3A0),
      accent: Color(0xFF059669),
      card: Color(0xFFF0F7F4),
      cardBorder: Color(0xFFDCEAE4),
    ),
    dark: Palette(
      background: Color(0xFF042F2E),
      foreground: Color(0xFFECFDF5),
      secondary: Color(0xFF6B9C92),
      accent: Color(0xFF34D399),
      card: Color(0xFF0B3B38),
      cardBorder: Color(0xFF14532D),
    ),
  ),
  // 4. 暖阳:琥珀暖橙
  PalettePreset(
    name: '暖阳',
    light: Palette(
      background: Color(0xFFFFFBF5),
      foreground: Color(0xFF4A3728),
      secondary: Color(0xFFB89B83),
      accent: Color(0xFFD97706),
      card: Color(0xFFFDF2E3),
      cardBorder: Color(0xFFF3E0C8),
    ),
    dark: Palette(
      background: Color(0xFF1C1108),
      foreground: Color(0xFFFFF7ED),
      secondary: Color(0xFFA98A6E),
      accent: Color(0xFFF59E0B),
      card: Color(0xFF2A1A0E),
      cardBorder: Color(0xFF4A3520),
    ),
  ),
  // 5. 紫罗兰:梦幻紫
  PalettePreset(
    name: '紫罗兰',
    light: Palette(
      background: Color(0xFFF8F7FD),
      foreground: Color(0xFF2E2A4D),
      secondary: Color(0xFF9B95C0),
      accent: Color(0xFF7C3AED),
      card: Color(0xFFF0EDFB),
      cardBorder: Color(0xFFE1DCF3),
    ),
    dark: Palette(
      background: Color(0xFF191530),
      foreground: Color(0xFFF3F1FF),
      secondary: Color(0xFF8B83C4),
      accent: Color(0xFFA78BFA),
      card: Color(0xFF251F45),
      cardBorder: Color(0xFF3A3161),
    ),
  ),
  // 6. 中国红:传统绛红
  PalettePreset(
    name: '中国红',
    light: Palette(
      background: Color(0xFFFDF6F2),
      foreground: Color(0xFF3D1B12),
      secondary: Color(0xFFB08A7C),
      accent: Color(0xFFC0392B),
      card: Color(0xFFFAEDE8),
      cardBorder: Color(0xFFF0DCD4),
    ),
    dark: Palette(
      background: Color(0xFF1A0A06),
      foreground: Color(0xFFFDF0EA),
      secondary: Color(0xFFA07464),
      accent: Color(0xFFE74C3C),
      card: Color(0xFF2B140D),
      cardBorder: Color(0xFF4A2418),
    ),
  ),
];

/// 根据设置与系统亮度解析最终配色(含多自定义方案与字体颜色覆盖)
Palette resolvePalette(ClockSettings settings, Brightness systemBrightness) {
  final useDark = switch (settings.theme) {
    ClockTheme.dark => true,
    ClockTheme.light => false,
    ClockTheme.system => systemBrightness == Brightness.dark,
  };
  Palette palette;
  if (settings.paletteIndex >= ClockSettings.presetPaletteCount) {
    final idx = settings.paletteIndex - ClockSettings.presetPaletteCount;
    if (idx < settings.customPalettes.length) {
      palette = _buildCustomPalette(settings.customPalettes[idx], useDark);
    } else {
      palette = useDark ? kPalettePresets[0].dark : kPalettePresets[0].light;
    }
  } else {
    final index =
        settings.paletteIndex.clamp(0, kPalettePresets.length - 1);
    palette =
        useDark ? kPalettePresets[index].dark : kPalettePresets[index].light;
  }
  // 自定义背景颜色:覆盖背景色(白天/黑夜各自独立)
  if (settings.bgColorMode == BackgroundColorMode.custom) {
    final bg = useDark
        ? (settings.bgColorDark ?? palette.background)
        : (settings.bgColorLight ?? palette.background);
    palette = Palette(
      background: bg,
      foreground: palette.foreground,
      secondary: palette.secondary,
      accent: palette.accent,
      card: palette.card,
      cardBorder: palette.cardBorder,
    );
  }
  // 自定义字体颜色:覆盖前景色(白天/黑夜各自独立)
  if (settings.fontColorMode == FontColorMode.custom) {
    final fg = useDark
        ? (settings.fontColorDark ?? palette.foreground)
        : (settings.fontColorLight ?? palette.foreground);
    palette = Palette(
      background: palette.background,
      foreground: fg,
      secondary: palette.secondary,
      accent: palette.accent,
      card: palette.card,
      cardBorder: palette.cardBorder,
    );
  }
  return palette;
}

/// 由用户输入的三色(背景/文字/强调)构建一套配色,其余颜色自动派生
Palette _buildCustomPalette(CustomPalette custom, bool dark) {
  final bg = custom.bg;
  final fg = custom.fg;
  final accent = custom.accent;
  return Palette(
    background: bg,
    foreground: fg,
    secondary: fg.withValues(alpha: dark ? 0.5 : 0.45),
    accent: accent,
    card: dark
        ? Color.lerp(bg, Colors.white, 0.08)!
        : Color.lerp(bg, Colors.black, 0.05)!,
    cardBorder: dark
        ? Color.lerp(bg, Colors.white, 0.18)!
        : Color.lerp(bg, Colors.black, 0.12)!,
  );
}
