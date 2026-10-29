import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Görünüm tercihleri (tema, tutarları gizleme).
class AppPrefs extends ChangeNotifier {
  AppPrefs([this._prefs]);
  SharedPreferences? _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  bool _hideAmounts = false;
  int _seedColor = 0xFF00796B;

  ThemeMode get themeMode => _themeMode;
  bool get hideAmounts => _hideAmounts;
  int get seedColor => _seedColor;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final p = _prefs!;
    _themeMode = ThemeMode.values[(p.getInt('themeMode') ?? 0).clamp(0, 2)];
    _hideAmounts = p.getBool('hideAmounts') ?? false;
    _seedColor = p.getInt('seedColor') ?? _seedColor;
    notifyListeners();
  }

  set themeMode(ThemeMode m) {
    _themeMode = m;
    _prefs?.setInt('themeMode', m.index);
    notifyListeners();
  }

  set hideAmounts(bool v) {
    _hideAmounts = v;
    _prefs?.setBool('hideAmounts', v);
    notifyListeners();
  }

  set seedColor(int v) {
    _seedColor = v;
    _prefs?.setInt('seedColor', v);
    notifyListeners();
  }
}
