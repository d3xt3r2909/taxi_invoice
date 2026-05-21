import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists appearance: theme mode and extra in-app text scale steps (0–2).
final class AppSettingsController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  int _textScaleStep = 0;
  bool _simpleMode = false;

  ThemeMode get themeMode => _themeMode;

  /// 0 = default, 1 = first boost, 2 = second boost (largest).
  int get textScaleStep => _textScaleStep;
  bool get simpleMode => _simpleMode;
  int get effectiveTextScaleStep =>
      _simpleMode && _textScaleStep == 0 ? 1 : _textScaleStep;

  static const _keyTheme = 'taxi_invoice_theme_mode';
  static const _keyTextStep = 'taxi_invoice_text_scale_step';
  static const _keyPdfDir = 'taxi_invoice_pdf_output_dir';
  static const _keySimpleMode = 'taxi_invoice_simple_mode';

  String? _pdfOutputDirectory;

  /// Folder where invoice PDFs are written (IO only; set in Postavke).
  String? get pdfOutputDirectory => _pdfOutputDirectory;
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = switch (prefs.getString(_keyTheme)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final raw = prefs.getInt(_keyTextStep);
    _textScaleStep = raw != null ? raw.clamp(0, 2) : 0;
    _simpleMode = prefs.getBool(_keySimpleMode) ?? false;
    final dir = prefs.getString(_keyPdfDir);
    _pdfOutputDirectory = (dir != null && dir.trim().isNotEmpty)
        ? dir.trim()
        : null;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  Future<void> setTextScaleStep(int step) async {
    final next = step.clamp(0, 2);
    if (_textScaleStep == next) {
      return;
    }
    _textScaleStep = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTextStep, _textScaleStep);
  }

  Future<void> setSimpleMode(bool enabled) async {
    if (_simpleMode == enabled) {
      return;
    }
    _simpleMode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySimpleMode, _simpleMode);
  }

  Future<void> setPdfOutputDirectory(String? directoryPath) async {
    final next = directoryPath?.trim();
    final normalized = (next == null || next.isEmpty) ? null : next;
    if (_pdfOutputDirectory == normalized) {
      return;
    }
    _pdfOutputDirectory = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (normalized == null) {
      await prefs.remove(_keyPdfDir);
    } else {
      await prefs.setString(_keyPdfDir, normalized);
    }
  }

  /// Multiplier for this step (combined with system text scale in [MaterialApp.builder]).
  static double textScaleFactorForStep(int step) {
    return switch (step.clamp(0, 2)) {
      0 => 1.0,
      1 => 1.12,
      _ => 1.24,
    };
  }
}
