import 'package:flutter/material.dart';

/// Theme configuration for Decidr app
class DecidrTheme {
  DecidrTheme._(); // Private constructor to prevent instantiation

  // Color schemes
  static final lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Colors.blue,
    onPrimary: Colors.white,
    primaryContainer: Colors.blue.shade100,
    onPrimaryContainer: Colors.blue.shade900,
    secondary: Colors.orange,
    onSecondary: Colors.white,
    secondaryContainer: Colors.orange.shade100,
    onSecondaryContainer: Colors.orange.shade900,
    tertiary: Colors.purple,
    onTertiary: Colors.white,
    tertiaryContainer: Colors.purple.shade100,
    onTertiaryContainer: Colors.purple.shade900,
    error: Colors.red,
    onError: Colors.white,
    errorContainer: Colors.red.shade100,
    onErrorContainer: Colors.red.shade900,
    surface: Colors.white,
    onSurface: Colors.grey.shade900,
    surfaceContainerHighest: Colors.grey.shade100,
    onSurfaceVariant: Colors.grey.shade700,
    outline: Colors.grey.shade400,
    shadow: Colors.black.withOpacity(0.1),
    inverseSurface: Colors.grey.shade900,
    onInverseSurface: Colors.grey.shade50,
    inversePrimary: Colors.blue.shade200,
  );

  static final darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Colors.blue.shade300,
    onPrimary: Colors.grey.shade900,
    primaryContainer: Colors.blue.shade800,
    onPrimaryContainer: Colors.blue.shade100,
    secondary: Colors.orange.shade300,
    onSecondary: Colors.grey.shade900,
    secondaryContainer: Colors.orange.shade800,
    onSecondaryContainer: Colors.orange.shade100,
    tertiary: Colors.purple.shade300,
    onTertiary: Colors.grey.shade900,
    tertiaryContainer: Colors.purple.shade800,
    onTertiaryContainer: Colors.purple.shade100,
    error: Colors.red.shade300,
    onError: Colors.grey.shade900,
    errorContainer: Colors.red.shade800,
    onErrorContainer: Colors.red.shade100,
    surface: Colors.grey.shade800,
    onSurface: Colors.grey.shade100,
    surfaceContainerHighest: Colors.grey.shade700,
    onSurfaceVariant: Colors.grey.shade300,
    outline: Colors.grey.shade500,
    shadow: Colors.black.withOpacity(0.3),
    inverseSurface: Colors.grey.shade100,
    onInverseSurface: Colors.grey.shade900,
    inversePrimary: Colors.blue.shade700,
  );

  // Generate theme based on preferences
static ThemeData getThemeData(BuildContext context, bool isDark, ColorScheme? dynamicScheme) {
  final baseScheme = isDark 
      ? (dynamicScheme?.brightness == Brightness.dark ? dynamicScheme : darkColorScheme)
      : (dynamicScheme?.brightness == Brightness.light ? dynamicScheme : lightColorScheme);
  
  return ThemeData(
    useMaterial3: true,
    colorScheme: baseScheme,
    brightness: isDark ? Brightness.dark : Brightness.light,
    
    // Text themes
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontWeight: FontWeight.bold, 
        fontSize: 32,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontWeight: FontWeight.bold, 
        fontSize: 28,
      ),
      displaySmall: TextStyle(
        fontWeight: FontWeight.bold, 
        fontSize: 24,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.bold, 
        fontSize: 20,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.bold, 
        fontSize: 18,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
      ),
    ),
    
    // Card theme
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    
    // Button themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 3,
      ),
    ),
    
    // AppBar theme
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
      ),
    ),
    
    // Bottom navigation theme
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: baseScheme?.primary,
      unselectedItemColor: baseScheme?.onSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    
    // Dialog theme
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 5,
    ),
  );
}}