import 'package:flutter/material.dart';

/// Supported Daily Club themes.
enum AppThemeType { pastelGreen, lightBlue, pink, orange }

/// Immutable theme data used across the app (gradients, accents, chips, etc.).
class AppThemeData {
  const AppThemeData({
    required this.type,
    required this.label,
    required this.gradientTop,
    required this.backgroundGradientColors,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.buyNowButtonBg,
    required this.upgradeButtonBg,
    required this.gridContainerBg,
    required this.searchBarBg,
    required this.chipBg,
    required this.hintWhite,
    required this.loginGradient, // Specific 3-color dark gradient
    required this.blobColors,    // List of colors for animated blobs
  });

  final AppThemeType type;
  final String label;
  final Color gradientTop;
  final List<Color> backgroundGradientColors;
  final Color primaryAccent;
  final Color secondaryAccent;
  final Color buyNowButtonBg;
  final Color upgradeButtonBg;
  final Color gridContainerBg;
  final Color searchBarBg;
  final Color chipBg;
  final Color hintWhite;
  final List<Color> loginGradient;
  final List<Color> blobColors;
}

/// Central theme registry with concrete color values for each variant.
abstract final class AppThemes {
  static const AppThemeData pastelGreen = AppThemeData(
    type: AppThemeType.pastelGreen,
    label: 'Green',
    gradientTop: Color(0xFF0F2F1A),
    backgroundGradientColors: [Color(0xFF153C33), Color(0xFF2F6F50), Color(0xFF4F916A)],
    primaryAccent: Color(0xFF4ECA6A),
    secondaryAccent: Color(0xFF3DA855),
    buyNowButtonBg: Color(0xFFFFD84D),
    upgradeButtonBg: Color(0xFF3FAF7B),
    gridContainerBg: Color(0xFFE6EFE8),
    searchBarBg: Color(0x26FFFFFF),
    chipBg: Color(0x1AFFFFFF),
    hintWhite: Color(0xB3FFFFFF),
    loginGradient: [Color(0xFF0F2F1A), Color(0xFF1A5C2A), Color(0xFF0A1F10)],
    blobColors: [Color(0xFF4ECA6A), Color(0xFF7C3AED), Color(0xFFFBBF24)],
  );

  static const AppThemeData lightBlue = AppThemeData(
    type: AppThemeType.lightBlue,
    label: 'Blue',
    gradientTop: Color(0xFF0F172A),
    backgroundGradientColors: [Color(0xFF102A43), Color(0xFF275A9A), Color(0xFF5DA9FF)],
    primaryAccent: Color(0xFF38BDF8),
    secondaryAccent: Color(0xFF2F8DE0),
    buyNowButtonBg: Color(0xFFFFD84D),
    upgradeButtonBg: Color(0xFF2F8DE0),
    gridContainerBg: Color(0xFFE4F1FF),
    searchBarBg: Color(0x29FFFFFF),
    chipBg: Color(0x1FFFFFFF),
    hintWhite: Color(0xCCFFFFFF),
    loginGradient: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0F172A)],
    blobColors: [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFF2DD4BF)],
  );

  static const AppThemeData pink = AppThemeData(
    type: AppThemeType.pink,
    label: 'Pink',
    gradientTop: Color(0xFF3D102A),
    backgroundGradientColors: [Color(0xFF3D102A), Color(0xFFB03F82), Color(0xFFFF9ECF)],
    primaryAccent: Color(0xFFF472B6),
    secondaryAccent: Color(0xFFE74C9B),
    buyNowButtonBg: Color(0xFFFFF0F6),
    upgradeButtonBg: Color(0xFFE74C9B),
    gridContainerBg: Color(0xFFFFE3F2),
    searchBarBg: Color(0x29FFFFFF),
    chipBg: Color(0x1AFFFFFF),
    hintWhite: Color(0xCCFFFFFF),
    loginGradient: [Color(0xFF1F0F1A), Color(0xFF5C1A3E), Color(0xFF1F0F1A)],
    blobColors: [Color(0xFFF472B6), Color(0xFFFB7185), Color(0xFFFACC15)],
  );

  static const AppThemeData orange = AppThemeData(
    type: AppThemeType.orange,
    label: 'Orange',
    gradientTop: Color(0xFF3F1B00),
    backgroundGradientColors: [Color(0xFF3F1B00), Color(0xFFBF5C00), Color(0xFFFFB067)],
    primaryAccent: Color(0xFFFB923C),
    secondaryAccent: Color(0xFFFF7A00),
    buyNowButtonBg: Color(0xFFFFE29F),
    upgradeButtonBg: Color(0xFFFF7A00),
    gridContainerBg: Color(0xFFFFF2E0),
    searchBarBg: Color(0x29FFFFFF),
    chipBg: Color(0x1AFFFFFF),
    hintWhite: Color(0xCCFFFFFF),
    loginGradient: [Color(0xFF2B1000), Color(0xFF7C2D12), Color(0xFF1C0900)],
    blobColors: [Color(0xFFFB923C), Color(0xFFF87171), Color(0xFF4ADE80)],
  );

  static const List<AppThemeData> all = [pastelGreen, lightBlue, pink, orange];

  static AppThemeData byType(AppThemeType type) {
    switch (type) {
      case AppThemeType.pastelGreen: return pastelGreen;
      case AppThemeType.lightBlue: return lightBlue;
      case AppThemeType.pink: return pink;
      case AppThemeType.orange: return orange;
    }
  }
}

/// Controller that holds the active [AppThemeData] and notifies listeners.
class AppThemeController extends ChangeNotifier {
  AppThemeController({AppThemeType initialTheme = AppThemeType.pastelGreen})
    : _themeType = initialTheme;

  AppThemeType _themeType;

  AppThemeType get type => _themeType;

  AppThemeData get theme => AppThemes.byType(_themeType);

  void setTheme(AppThemeType type) {
    if (type == _themeType) return;
    _themeType = type;
    notifyListeners();
  }

  /// Cycles to the next theme in [AppThemes.all].
  void cycleTheme() {
    final currentIndex = AppThemes.all.indexWhere((t) => t.type == _themeType);
    final nextIndex = (currentIndex + 1) % AppThemes.all.length;
    _themeType = AppThemes.all[nextIndex].type;
    notifyListeners();
  }
}

/// Inherited notifier so widgets can read and react to theme changes.
class AppThemeScope extends InheritedNotifier<AppThemeController> {
  const AppThemeScope({
    super.key,
    required AppThemeController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static AppThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope not found in widget tree.');
    return scope!.notifier!;
  }

  static AppThemeData themeOf(BuildContext context) => of(context).theme;
}
