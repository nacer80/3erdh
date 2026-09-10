import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── App Constants & Metrics ──────────────────────────────────────────────────

class AppConstants {
  AppConstants._();

  static const String appName = 'Ayat - آيات';
  static const String appDescription = 'Real-time Quran Recitation Tracker';
  static const String hafsFontFamily = 'HafsSmart';

  static const double defaultFontSize = 30.0;
  static const double minFontSize = 18.0;
  static const double maxFontSize = 48.0;
  static const double desktopMaxWidth = 850.0;

  static const List<int> surahAyahCounts = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109,
    123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
    112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
    34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
    54, 53, 89, 59, 37, 35, 38, 29, 18, 45,
    60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
    14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
    28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
    29, 19, 36, 25, 22, 17, 19, 26, 30, 20,
    15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
    11, 8, 3, 9, 5, 4, 7, 3, 6, 3,
    5, 4, 5, 6,
  ];

  static int getSurahAyahCount(int surahNumber) {
    if (surahNumber >= 1 && surahNumber <= surahAyahCounts.length) {
      return surahAyahCounts[surahNumber - 1];
    }
    return 0;
  }
}

// ── In-Memory Logger ─────────────────────────────────────────────────────────

class AppLogger {
  AppLogger._();

  static final List<String> sessionLogs = [];

  static void addLog(String message) {
    sessionLogs.add('[${DateTime.now().toIso8601String()}] $message');
    if (sessionLogs.length > 5000) sessionLogs.removeRange(0, 1000);
  }

  static void log(String tag, String message) {
    final entry = '[$tag] $message';
    addLog(entry);
    debugPrint(entry);
  }

  static Future<void> copyLogsToClipboard(BuildContext context) async {
    final text = sessionLogs.isNotEmpty ? sessionLogs.join('\n') : 'No logs recorded.';
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ السجلات إلى الحافظة', textDirection: TextDirection.rtl),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// ── Theme Design Tokens ──────────────────────────────────────────────────────

class ThemeColors {
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color gold;
  final Color green;
  final Color red;
  final Color muted;
  final Color currentWord;
  final Color text;
  final bool isDark;

  const ThemeColors({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.gold,
    required this.green,
    required this.red,
    required this.muted,
    required this.currentWord,
    required this.text,
    required this.isDark,
  });

  Color get goldFade => gold.withValues(alpha: 0.25);
  Color get accent => gold;

  static const ThemeColors darkTheme = ThemeColors(
    bg: Color(0xFF070B14),          // Deep Velvety Obsidian Night
    surface: Color(0xFF0F172A),     // Card surface / Sidebars
    surfaceHigh: Color(0xFF1E293B), // Elevated containers / buttons
    border: Color(0xFF22324E),      // Sleek subtle border
    gold: Color(0xFFF5B738),        // Luminous Imperial Gold
    green: Color(0xFF10B981),       // Vivid Emerald Green (Success)
    red: Color(0xFFEF4444),         // Clear Coral Red (Errors)
    muted: Color(0xFF94A3B8),       // Slate Muted Gray
    currentWord: Color(0xFFFDE047), // Vibrant Warning Amber
    text: Color(0xFFF8FAFC),        // Pure Soft White
    isDark: true,
  );

  static const ThemeColors lightTheme = ThemeColors(
    bg: Color(0xFFFDFBF7),          // Warm Quranic Cream Manuscript
    surface: Color(0xFFFFFFFF),     // Pure White Card
    surfaceHigh: Color(0xFFF5EFE6), // Elevated Cream Sand
    border: Color(0xFFE2D7C3),      // Delicate Warm Border
    gold: Color(0xFFC59A3F),        // Imperial Gold
    green: Color(0xFF059669),       // Deep Emerald Green
    red: Color(0xFFDC2626),         // Crimson Red
    muted: Color(0xFF64748B),       // Slate Muted
    currentWord: Color(0xFFD97706), // Warm Amber
    text: Color(0xFF0F172A),        // Deep Obsidian Charcoal Text
    isDark: false,
  );

  static const ThemeColors sepiaTheme = ThemeColors(
    bg: Color(0xFFF5EFEB),          // Desert Sand Parchment
    surface: Color(0xFFFAF5EE),     // Warm Paper Card
    surfaceHigh: Color(0xFFEAE0D0), // Elevated Sand
    border: Color(0xFFDECFC0),      // Soft Paper Border
    gold: Color(0xFFB45309),        // Burnished Brass Gold
    green: Color(0xFF15803D),       // Forest Olive Green
    red: Color(0xFFB91C1C),         // Terracotta Crimson
    muted: Color(0xFF78716C),       // Warm Earth Muted
    currentWord: Color(0xFFD97706), // Earth Amber
    text: Color(0xFF292524),        // Deep Espresso Earth Text
    isDark: false,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData buildTheme(ThemeColors c) {
    final Brightness brightness = c.isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.gold,
        onPrimary: c.isDark ? Colors.black : Colors.white,
        secondary: c.accent,
        onSecondary: Colors.white,
        error: c.red,
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.text,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.border, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surface,
        contentTextStyle: TextStyle(color: c.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.border, width: 1),
        ),
      ),
    );
  }
}

// ── Arabic Utilities & Extensions ────────────────────────────────────────────

class ArabicUtils {
  ArabicUtils._();

  static String cleanPhonetic(String input) {
    return input
        .replaceAll('\u06e5', 'و')
        .replaceAll('\u06e6', 'ي')
        .replaceAll('\u06ba', 'ن')
        .replaceAll('\u06fe', 'م')
        .replaceAll('\u0687', '')
        .replaceAll('ڇ', '')
        .replaceAll('ۜ', '')
        .replaceAll('۪', '')
        .replaceAll('ؙ', '')
        .replaceAll('ٲ', 'أ')
        .replaceAll('\u0640', '');
  }
}

extension ArabicDigitsExtension on int {
  String toArabicDigits() {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return toString()
        .split('')
        .map((char) => digits[int.tryParse(char) ?? 0])
        .join('');
  }
}

extension ArabicStringExtension on String {
  String normalizeArabic() {
    return replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
  }
}

// ── App State Singleton ──────────────────────────────────────────────────────

enum AppLanguage { ar, en }
enum AppMode { wordChecker, tajweed }
enum AppThemeMode { light, dark, sepia }
enum MushafViewMode { madina15Line, adaptiveFlow }

class AppState extends ChangeNotifier {
  AppState._() {
    _lang = AppLanguage.ar; // Arabic as absolute default
  }

  static final AppState instance = AppState._();

  // Mushaf View Mode (15-line vs adaptive reading flow)
  MushafViewMode viewMode = MushafViewMode.madina15Line;

  Future<void> setViewMode(MushafViewMode mode) async {
    if (viewMode != mode) {
      viewMode = mode;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('view_mode', mode.name);
    }
  }

  Future<void> toggleViewMode() async {
    final next = viewMode == MushafViewMode.madina15Line
        ? MushafViewMode.adaptiveFlow
        : MushafViewMode.madina15Line;
    await setViewMode(next);
  }

  // Language
  late AppLanguage _lang;
  AppLanguage get lang => _lang;
  bool get isArabic => _lang == AppLanguage.ar;

  Future<void> toggleLanguage() async {
    _lang = _lang == AppLanguage.ar ? AppLanguage.en : AppLanguage.ar;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', _lang.name);
  }

  // Mode
  AppMode currentMode = AppMode.wordChecker;
  int tajweedClickCount = 0;
  bool get hasClickedTajweedWord => tajweedClickCount >= 10;

  void setMode(AppMode mode) {
    if (currentMode != mode) {
      currentMode = mode;
      notifyListeners();
    }
  }

  Future<void> markTajweedWordClicked() async {
    if (tajweedClickCount < 10) {
      tajweedClickCount++;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('tajweed_click_count', tajweedClickCount);
    }
  }

  // Theme
  AppThemeMode _theme = AppThemeMode.dark;
  AppThemeMode get theme => _theme;
  bool get isDarkMode => _theme == AppThemeMode.dark;
  bool hasChosenTheme = false;

  Future<void> setTheme(AppThemeMode t) async {
    _theme = t;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', _theme.name);
  }

  Future<void> cycleTheme() async {
    final next = switch (_theme) {
      AppThemeMode.dark => AppThemeMode.light,
      AppThemeMode.light => AppThemeMode.sepia,
      AppThemeMode.sepia => AppThemeMode.dark,
    };
    await setTheme(next);
  }

  Future<void> markThemeChosen() async {
    hasChosenTheme = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_chosen_theme', true);
  }

  // Blur Mode
  bool isBlurMode = false;

  Future<void> toggleBlurMode() async {
    isBlurMode = !isBlurMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('blurMode', isBlurMode);
  }

  // Font Size
  double fontSize = 30.0;

  Future<void> setFontSize(double size) async {
    fontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', fontSize);
  }

  ThemeColors get colors => switch (_theme) {
    AppThemeMode.dark => ThemeColors.darkTheme,
    AppThemeMode.light => ThemeColors.lightTheme,
    AppThemeMode.sepia => ThemeColors.sepiaTheme,
  };

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('lang')) {
        _lang = prefs.getString('lang') == 'en' ? AppLanguage.en : AppLanguage.ar;
      }
      final savedTheme = prefs.getString('theme');
      _theme = switch (savedTheme) {
        'light' => AppThemeMode.light,
        'sepia' => AppThemeMode.sepia,
        _ => AppThemeMode.dark,
      };
      hasChosenTheme = prefs.getBool('has_chosen_theme') ?? false;
      isBlurMode = prefs.getBool('blurMode') ?? false;
      fontSize = prefs.getDouble('fontSize') ?? 30.0;
      tajweedClickCount = prefs.getInt('tajweed_click_count') ?? 0;
      if (tajweedClickCount == 0 && (prefs.getBool('has_clicked_tajweed_word') ?? false)) {
        tajweedClickCount = 10;
      }
      notifyListeners();
    } catch (e) {
      AppLogger.log('AppState', "Error loading settings: $e");
    }
  }

  Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await load();
  }
}
