import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Recuerda tamaño, posición y maximizado de la ventana en escritorio.
abstract final class WindowPlacement {
  static const minSize = Size(720, 520);
  static const defaultSize = Size(1100, 760);
  static const _x = 'window_x';
  static const _y = 'window_y';
  static const _w = 'window_w';
  static const _h = 'window_h';
  static const _max = 'window_maximized';

  static final _watcher = _WindowPlacementWatcher();

  static bool get _desktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  static Future<void> restore() async {
    if (!_desktop) return;
    await windowManager.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final frame = decodeFrame(
      x: prefs.getDouble(_x),
      y: prefs.getDouble(_y),
      width: prefs.getDouble(_w),
      height: prefs.getDouble(_h),
    );
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        minimumSize: minSize,
        title: 'OpoMemo',
      ),
      () async {
        if (frame != null) {
          await windowManager.setBounds(frame);
        } else {
          await windowManager.setSize(defaultSize);
          await windowManager.center();
        }
        if (prefs.getBool(_max) == true) {
          await windowManager.maximize();
        }
        await windowManager.show();
        await windowManager.focus();
      },
    );
    _watcher.attach();
  }

  @visibleForTesting
  static Rect? decodeFrame({
    required double? x,
    required double? y,
    required double? width,
    required double? height,
  }) {
    if (x == null || y == null || width == null || height == null) return null;
    if (width.isNaN || height.isNaN || x.isNaN || y.isNaN) return null;
    return Rect.fromLTWH(
      x,
      y,
      width.clamp(minSize.width, 4000),
      height.clamp(minSize.height, 3000),
    );
  }
}

class _WindowPlacementWatcher with WindowListener {
  Timer? _debounce;
  var _attached = false;

  void attach() {
    if (_attached) return;
    _attached = true;
    windowManager.addListener(this);
  }

  @override
  void onWindowMove() => _scheduleSave();

  @override
  void onWindowResize() => _scheduleSave();

  @override
  void onWindowMaximize() => _save();

  @override
  void onWindowUnmaximize() => _save();

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _save);
  }

  Future<void> _save() async {
    if (await windowManager.isMinimized()) return;
    final prefs = await SharedPreferences.getInstance();
    final maximized = await windowManager.isMaximized();
    await prefs.setBool(WindowPlacement._max, maximized);
    if (maximized) return;
    final bounds = await windowManager.getBounds();
    await prefs.setDouble(WindowPlacement._x, bounds.left);
    await prefs.setDouble(WindowPlacement._y, bounds.top);
    await prefs.setDouble(WindowPlacement._w, bounds.width);
    await prefs.setDouble(WindowPlacement._h, bounds.height);
  }
}
