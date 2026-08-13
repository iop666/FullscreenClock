import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fullscreen_clock/app.dart';
import 'package:fullscreen_clock/models/clock_settings.dart';
import 'package:fullscreen_clock/providers/settings_provider.dart';
import 'package:fullscreen_clock/widgets/standard_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App builds and shows the standard clock', (tester) async {
    // 关闭常亮以避免测试环境访问平台通道
    SharedPreferences.setMockInitialValues({'keep_awake': false});
    final provider = await SettingsProvider.load();

    await tester.pumpWidget(FullscreenClockApp(provider: provider));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(StandardClock), findsOneWidget);
    expect(find.byType(FullscreenClockApp), findsOneWidget);

    // 卸载组件,触发 Timer 清理
    await tester.pumpWidget(const SizedBox());
  });

  test('Settings provider persists and resets', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = await SettingsProvider.load();
    expect(provider.settings.mode, ClockMode.standard);

    provider.setShowSeconds(false);
    expect(provider.settings.showSeconds, isFalse);

    await provider.reset();
    expect(provider.settings.showSeconds, isTrue);
  });
}
