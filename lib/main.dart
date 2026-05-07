import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'models/preferences_model.dart';
import 'models/suggestions_repository.dart';
import 'models/activity_history_model.dart';
import 'models/feedback_model.dart';
import 'services/weather_service.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_page.dart';
import 'screens/questionnaire_page.dart';
import 'utils/decidr_theme.dart';

/// Global hook for surfacing uncaught errors to a logging service.
///
/// Currently logs to the console via [debugPrint]. Wire a crash reporter
/// here (e.g. Sentry, Firebase Crashlytics) by replacing the body. Both
/// Flutter framework errors and uncaught zone errors funnel through this.
void _reportError(Object error, StackTrace stack) {
  debugPrint('Uncaught error: $error\n$stack');
}

void main() {
  // Run the app inside a guarded zone so any uncaught async error is
  // captured rather than crashing silently.
  runZonedGuarded(_bootstrap, _reportError);
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Route Flutter framework errors through the same reporter. In release
  // builds we suppress the default console dump and rely on the reporter.
  FlutterError.onError = (FlutterErrorDetails details) {
    _reportError(details.exception, details.stack ?? StackTrace.empty);
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  // Initialize preferences
  final prefs = await SharedPreferences.getInstance();
  final preferencesModel = PreferencesModel(prefs);
  await preferencesModel.loadPreferences();

  // Initialize suggestions repository
  final suggestionsRepo = SuggestionsRepository(prefs);
  await suggestionsRepo.loadSuggestions();

  // Initialize feedback model
  final feedbackModel = FeedbackModel(prefs);

  // Initialize weather service
  final weatherService = WeatherService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => preferencesModel),
        ChangeNotifierProvider(create: (_) => suggestionsRepo),
        ChangeNotifierProvider(create: (_) => ActivityHistoryModel(prefs)),
        ChangeNotifierProvider(create: (_) => feedbackModel),
        ChangeNotifierProvider(create: (_) => weatherService),
      ],
      child: const DecidrApp(),
    ),
  );
}

/// The main application widget
class DecidrApp extends StatelessWidget {
  const DecidrApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the preferences model for theme settings
    final preferencesModel = Provider.of<PreferencesModel>(context);
    
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // Determine theme mode based on preferences
        ThemeMode themeMode = ThemeMode.system;
        if (!preferencesModel.useSystemTheme) {
          themeMode = preferencesModel.useDarkMode ? ThemeMode.dark : ThemeMode.light;
        }
        
        return MaterialApp(
          title: 'Decidr',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          
          // Light theme with dynamic colors if available
          theme: DecidrTheme.getThemeData(context, false, lightDynamic),
          
          // Dark theme with dynamic colors if available
          darkTheme: DecidrTheme.getThemeData(context, true, darkDynamic),
          
          // Home page
          home: const SplashScreen(),
          
          // Define routes
          routes: {
            '/questionnaire': (context) => const QuestionnairePage(),
            '/settings': (context) => const SettingsPage(),
          },
          
          // Handle unknown routes
          onUnknownRoute: (settings) {
            return MaterialPageRoute(
              builder: (context) => const SplashScreen(),
            );
          },
        );
      },
    );
  }
}