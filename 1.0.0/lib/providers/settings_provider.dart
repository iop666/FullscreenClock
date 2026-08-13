import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/clock_settings.dart';

/// 设置状态管理:读写 shared_preferences 持久化,并广播变更通知 UI
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs, this._settings);

  final SharedPreferences _prefs;
  ClockSettings _settings;

  ClockSettings get settings => _settings;

  static const _kMode = 'mode';
  static const _kTheme = 'theme';
  static const _kPalette = 'palette';
  static const _kFontScale = 'font_scale';
  static const _kFontStyle = 'font_style';
  static const _kFontWeight = 'font_weight';
  static const _kFontColorMode = 'font_color_mode';
  static const _kFontColorLight = 'font_color_light';
  static const _kFontColorDark = 'font_color_dark';
  static const _kBgColorMode = 'bg_color_mode';
  static const _kBgColorLight = 'bg_color_light';
  static const _kBgColorDark = 'bg_color_dark';
  static const _kCustomFontFamily = 'custom_font_family';
  static const _kUse24 = 'use_24';
  static const _kShowSeconds = 'show_seconds';
  static const _kKeepAwake = 'keep_awake';
  static const _kAnalogStyle = 'analog_style';
  static const _kAnalogScale = 'analog_scale';
  static const _kCustomPalettes = 'custom_palettes';

  /// 从本地存储加载设置
  static Future<SettingsProvider> load() async {
    final prefs = await SharedPreferences.getInstance();
    const d = ClockSettings.defaults;
    return SettingsProvider(
      prefs,
      ClockSettings(
        mode: _enumByIndex(prefs.getInt(_kMode), ClockMode.values, d.mode),
        theme: _enumByIndex(prefs.getInt(_kTheme), ClockTheme.values, d.theme),
        paletteIndex: prefs.getInt(_kPalette) ?? d.paletteIndex,
        fontScale: prefs.getDouble(_kFontScale) ?? d.fontScale,
        fontStyle:
            _enumByIndex(prefs.getInt(_kFontStyle), FontStyleOption.values, d.fontStyle),
        fontWeight: prefs.getInt(_kFontWeight) ?? d.fontWeight,
        fontColorMode: _enumByIndex(
            prefs.getInt(_kFontColorMode), FontColorMode.values, d.fontColorMode),
        fontColorLight: _colorOrNull(prefs.getInt(_kFontColorLight)),
        fontColorDark: _colorOrNull(prefs.getInt(_kFontColorDark)),
        bgColorMode: _enumByIndex(
            prefs.getInt(_kBgColorMode), BackgroundColorMode.values, d.bgColorMode),
        bgColorLight: _colorOrNull(prefs.getInt(_kBgColorLight)),
        bgColorDark: _colorOrNull(prefs.getInt(_kBgColorDark)),
        customFontFamily: prefs.getString(_kCustomFontFamily),
        use24Hour: prefs.getBool(_kUse24) ?? d.use24Hour,
        showSeconds: prefs.getBool(_kShowSeconds) ?? d.showSeconds,
        keepAwake: prefs.getBool(_kKeepAwake) ?? d.keepAwake,
        analogStyle:
            _enumByIndex(prefs.getInt(_kAnalogStyle), AnalogClockStyle.values, d.analogStyle),
        analogScale: prefs.getDouble(_kAnalogScale) ?? d.analogScale,
        customPalettes:
            (prefs.getStringList(_kCustomPalettes) ?? const [])
                .map((s) => CustomPalette.fromJson(jsonDecode(s) as Map<String, dynamic>))
                .toList(),
      ),
    );
  }

  static T _enumByIndex<T extends Enum>(int? index, List<T> values, T fallback) {
    if (index == null || index < 0 || index >= values.length) return fallback;
    return values[index];
  }

  static Color? _colorOrNull(int? value) => value == null ? null : Color(value);

  void setMode(ClockMode value) =>
      _apply(_settings.copyWith(mode: value), _kMode, value.index);

  void setTheme(ClockTheme value) =>
      _apply(_settings.copyWith(theme: value), _kTheme, value.index);

  void setPaletteIndex(int value) =>
      _apply(_settings.copyWith(paletteIndex: value), _kPalette, value);

  void setFontScale(double value) =>
      _apply(_settings.copyWith(fontScale: value), _kFontScale, value);

  void setFontStyle(FontStyleOption value) =>
      _apply(_settings.copyWith(fontStyle: value), _kFontStyle, value.index);

  void setFontWeight(int value) =>
      _apply(_settings.copyWith(fontWeight: value), _kFontWeight, value);

  void setFontColorMode(FontColorMode value) =>
      _apply(_settings.copyWith(fontColorMode: value), _kFontColorMode, value.index);

  void setFontColorLight(Color c) {
    _settings = _settings.copyWith(fontColorLight: c);
    _prefs.setInt(_kFontColorLight, c.toARGB32());
    notifyListeners();
  }

  void setFontColorDark(Color c) {
    _settings = _settings.copyWith(fontColorDark: c);
    _prefs.setInt(_kFontColorDark, c.toARGB32());
    notifyListeners();
  }

  void setBgColorMode(BackgroundColorMode value) =>
      _apply(_settings.copyWith(bgColorMode: value), _kBgColorMode, value.index);

  void setBgColorLight(Color c) {
    _settings = _settings.copyWith(bgColorLight: c);
    _prefs.setInt(_kBgColorLight, c.toARGB32());
    notifyListeners();
  }

  void setBgColorDark(Color c) {
    _settings = _settings.copyWith(bgColorDark: c);
    _prefs.setInt(_kBgColorDark, c.toARGB32());
    notifyListeners();
  }

  void setCustomFontFamily(String? family) {
    _settings = _settings.copyWith(customFontFamily: family);
    if (family == null) {
      _prefs.remove(_kCustomFontFamily);
    } else {
      _prefs.setString(_kCustomFontFamily, family);
    }
    notifyListeners();
  }

  void setUse24Hour(bool value) =>
      _apply(_settings.copyWith(use24Hour: value), _kUse24, value);

  void setShowSeconds(bool value) =>
      _apply(_settings.copyWith(showSeconds: value), _kShowSeconds, value);

  void setAnalogStyle(AnalogClockStyle value) =>
      _apply(_settings.copyWith(analogStyle: value), _kAnalogStyle, value.index);

  void setAnalogScale(double value) =>
      _apply(_settings.copyWith(analogScale: value), _kAnalogScale, value);

  // ---- 自定义配色方案管理(最多 10 个) ----

  /// 新增一套自定义配色并选中它
  void addCustomPalette(CustomPalette palette) {
    var list = [..._settings.customPalettes, palette];
    if (list.length > 10) {
      list = list.sublist(list.length - 10);
    }
    final index = ClockSettings.presetPaletteCount + list.length - 1;
    _settings = _settings.copyWith(customPalettes: list, paletteIndex: index);
    _saveCustomPalettes();
    notifyListeners();
  }

  /// 更新某个自定义配色
  void updateCustomPalette(int index, CustomPalette palette) {
    final list = [..._settings.customPalettes];
    if (index < 0 || index >= list.length) return;
    list[index] = palette;
    _settings = _settings.copyWith(customPalettes: list);
    _saveCustomPalettes();
    notifyListeners();
  }

  /// 删除某个自定义配色,并修正当前索引
  void removeCustomPalette(int index) {
    final list = [..._settings.customPalettes];
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    var pi = _settings.paletteIndex;
    if (pi >= ClockSettings.presetPaletteCount) {
      final ci = pi - ClockSettings.presetPaletteCount;
      if (ci > index) {
        pi--;
      } else if (ci >= list.length) {
        pi = 0;
      }
    }
    _settings = _settings.copyWith(customPalettes: list, paletteIndex: pi);
    _saveCustomPalettes();
    notifyListeners();
  }

  void _saveCustomPalettes() {
    final list = _settings.customPalettes
        .map((p) => jsonEncode(p.toJson()))
        .toList();
    _prefs.setStringList(_kCustomPalettes, list);
  }

  void setKeepAwake(bool value) {
    _settings = _settings.copyWith(keepAwake: value);
    _prefs.setBool(_kKeepAwake, value);
    _applyWakelock(value);
    notifyListeners();
  }

  /// 恢复默认设置并清除本地存储
  Future<void> reset() async {
    _settings = ClockSettings.defaults;
    await _prefs.clear();
    _applyWakelock(_settings.keepAwake);
    notifyListeners();
  }

  void _apply(ClockSettings next, String key, Object value) {
    _settings = next;
    switch (value) {
      case final int i:
        _prefs.setInt(key, i);
      case final double d:
        _prefs.setDouble(key, d);
      case final bool b:
        _prefs.setBool(key, b);
      case final String s:
        _prefs.setString(key, s);
    }
    notifyListeners();
  }

  /// 切换屏幕常亮(跨平台,失败时静默忽略)
  void _applyWakelock(bool keep) {
    final future = keep ? WakelockPlus.enable() : WakelockPlus.disable();
    future.catchError((Object _) => false);
  }
}
