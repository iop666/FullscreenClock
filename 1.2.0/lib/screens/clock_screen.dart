import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/clock_settings.dart';
import '../providers/plan_provider.dart';
import '../providers/settings_provider.dart';
import '../services/orientation_service.dart';
import '../services/refresh_controller.dart';
import '../services/window_service.dart';
import '../theme/app_theme.dart';
import '../widgets/analog_clock.dart';
import '../widgets/plan_overlay.dart';
import '../widgets/standard_clock.dart';
import 'settings_screen.dart';

/// 全屏时钟显示页(点击屏幕进入设置)
class ClockScreen extends StatefulWidget {
  const ClockScreen({
    super.key,
    required this.provider,
    required this.planProvider,
  });

  final SettingsProvider provider;
  final PlanProvider planProvider;

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  Timer? _timer;
  Timer? _overlayTimer;
  late DateTime _now;

  /// 控制按钮是否可见(无操作 3 秒隐藏)
  bool _showOverlay = true;

  /// Android 是否锁定横屏(跟随陀螺仪旋转)
  bool _landscapeLocked = false;

  /// 省电:标准模式无操作 N 秒后降刷新率
  DateTime _lastInteraction = DateTime.now();
  bool _powerSaving = false;

  bool get _isWindows => Platform.isWindows;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    // Windows 端计划提醒通过 SnackBar 呈现
    widget.planProvider.windowsNoticeCallback = _showPlanMessage;
    _enterImmersive();
    _applyKeepAwake();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    HardwareKeyboard.instance.addHandler(_keyHandler);
    _scheduleHideOverlay();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_keyHandler);
    _timer?.cancel();
    _overlayTimer?.cancel();
    if (_powerSaving) RefreshController.exitPowerSave();
    _leaveImmersive();
    super.dispose();
  }

  void _tick() {
    setState(() => _now = DateTime.now());
    _checkPowerSave();
    // 计划状态机心跳(每秒)
    widget.planProvider.onTick(_now);
  }

  // ---- 右上角控制按钮(全屏切换),无操作 3 秒隐藏 ----

  void _scheduleHideOverlay() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  void _handleInteraction() {
    _lastInteraction = DateTime.now();
    if (_powerSaving) {
      _powerSaving = false;
      RefreshController.exitPowerSave();
    }
    if (!_showOverlay) setState(() => _showOverlay = true);
    _scheduleHideOverlay();
  }

  Future<void> _toggleFullscreen() async {
    await WindowService.instance.toggle();
    if (mounted) setState(() {});
    _scheduleHideOverlay();
  }

  // ---- 省电(仅 Android 标准时钟模式) ----

  void _checkPowerSave() {
    final settings = widget.provider.settings;
    if (settings.mode != ClockMode.standard) {
      if (_powerSaving) {
        _powerSaving = false;
        RefreshController.exitPowerSave();
      }
      return;
    }
    if (Platform.isAndroid &&
        !_powerSaving &&
        DateTime.now().difference(_lastInteraction).inSeconds >= 5) {
      _powerSaving = true;
      RefreshController.enterPowerSave();
    }
  }

  // ---- Android 沉浸式 ----

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _leaveImmersive() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  // ---- 键盘(Windows:ESC 退出全屏 / F11 切换) ----

  bool _keyHandler(KeyEvent event) {
    if (event is! KeyDownEvent || !_isWindows) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      WindowService.instance.exit();
      setState(() {});
      _scheduleHideOverlay();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f11) {
      _toggleFullscreen();
      return true;
    }
    return false;
  }

  void _applyKeepAwake() {
    final keep = widget.provider.settings.keepAwake;
    final future = keep ? WakelockPlus.enable() : WakelockPlus.disable();
    future.catchError((Object _) => false);
  }

  /// 计划模块位置对齐(居中下 / 靠左下 / 靠右下 / 两端)。
  /// 非 stretch 时限定卡片宽度,避免 PlanOverlay 内部 Expanded 撑满全宽导致位置不生效。
  Widget _alignModule(Widget child) {
    final align = widget.planProvider.moduleAlign;
    if (align == 'stretch') return child;
    final maxW = MediaQuery.sizeOf(context).width - 32 < 520
        ? MediaQuery.sizeOf(context).width - 32
        : 520.0;
    return Align(
      alignment: switch (align) {
        'bottomLeft' => Alignment.bottomLeft,
        'bottomRight' => Alignment.bottomRight,
        _ => Alignment.bottomCenter,
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: child,
      ),
    );
  }

  /// 计划操作结果提示(加时重叠 / 减时自动完成等)
  void _showPlanMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _openSettings() async {
    await WindowService.instance.exit();
    if (!mounted) return;
    _leaveImmersive();
    if (_powerSaving) {
      _powerSaving = false;
      RefreshController.exitPowerSave();
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          provider: widget.provider,
          planProvider: widget.planProvider,
        ),
      ),
    );
    if (!mounted) return;
    _enterImmersive();
    _lastInteraction = DateTime.now();
    _applyKeepAwake();
    _showOverlay = true;
    _scheduleHideOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.provider, widget.planProvider]),
      builder: (context, _) {
        final settings = widget.provider.settings;
        final palette =
            resolvePalette(settings, MediaQuery.platformBrightnessOf(context));
        return Scaffold(
          backgroundColor: palette.background,
          body: Listener(
            onPointerDown: (_) => _handleInteraction(),
            onPointerMove: (_) => _handleInteraction(),
            onPointerHover: (_) => _handleInteraction(),
            child: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openSettings,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: widget.planProvider.moduleSplit
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width:
                                  MediaQuery.sizeOf(context).width * 2 / 3 - 24,
                              child: Center(child: _buildClock(settings)),
                            ),
                          )
                        : Center(child: _buildClock(settings)),
                  ),
                ),
                if (_isWindows)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: AnimatedOpacity(
                      opacity: _showOverlay ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: _buildFullscreenButton(palette),
                    ),
                  ),
                // Android 横屏:左上角横屏锁定/解锁按钮
                if (Platform.isAndroid &&
                    MediaQuery.orientationOf(context) == Orientation.landscape)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: AnimatedOpacity(
                      opacity: _showOverlay ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: _buildLandscapeLockButton(palette),
                    ),
                  ),
                // 计划模块(当前计划卡 / 下一计划倒计时)
                if (widget.planProvider.moduleSplit)
                  Positioned(
                    top: 56,
                    right: 12,
                    bottom: 12,
                    width: MediaQuery.sizeOf(context).width / 3 - 16,
                    child: SingleChildScrollView(
                      child: PlanOverlay(
                        planProvider: widget.planProvider,
                        palette: palette,
                        now: _now,
                        onMessage: _showPlanMessage,
                      ),
                    ),
                  )
                else
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _alignModule(
                      PlanOverlay(
                        planProvider: widget.planProvider,
                        palette: palette,
                        now: _now,
                        onMessage: _showPlanMessage,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 右上角方形圆角全屏按钮
  Widget _buildFullscreenButton(Palette palette) {
    final isFull = WindowService.instance.isFull;
    return Material(
      color: palette.background.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: palette.cardBorder),
      ),
      child: IconButton(
        tooltip: isFull ? '退出全屏 (ESC)' : '进入全屏 (F11)',
        onPressed: _toggleFullscreen,
        icon: Icon(
          isFull ? Icons.fullscreen_exit : Icons.fullscreen,
          color: palette.foreground,
        ),
      ),
    );
  }

  Widget _buildClock(ClockSettings settings) {
    return switch (settings.mode) {
      ClockMode.standard => StandardClock(time: _now, settings: settings),
      ClockMode.analog => AnalogClock(time: _now, settings: settings),
    };
  }

  /// Android 横屏:左上角方形圆角锁定/解锁按钮
  Widget _buildLandscapeLockButton(Palette palette) {
    return Material(
      color: palette.background.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: palette.cardBorder),
      ),
      child: IconButton(
        tooltip: _landscapeLocked ? '解锁横屏' : '锁定横屏',
        onPressed: _toggleLandscapeLock,
        icon: Icon(
          _landscapeLocked ? Icons.lock : Icons.screen_rotation,
          color: palette.foreground,
        ),
      ),
    );
  }

  Future<void> _toggleLandscapeLock() async {
    setState(() => _landscapeLocked = !_landscapeLocked);
    await OrientationService.setLandscapeLock(_landscapeLocked);
    _scheduleHideOverlay();
  }
}
