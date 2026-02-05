import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decidr_app/main.dart';
import 'package:decidr_app/models/preferences_model.dart';
import 'package:decidr_app/models/suggestions_repository.dart';
import 'package:decidr_app/models/activity_history_model.dart';
import 'package:decidr_app/models/feedback_model.dart';
import 'package:decidr_app/services/weather_service.dart';
import 'package:decidr_app/screens/splash_screen.dart';
import 'package:decidr_app/widgets/question_card.dart';

/// Widget tests for the Decidr app
///
/// Tests cover:
/// - App initialization and rendering
/// - Splash screen display
/// - Welcome page navigation
/// - Questionnaire page functionality
/// - Theme switching
/// - Widget interactions

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DecidrApp', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('should start with SplashScreen', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final preferencesModel = PreferencesModel(prefs);
      final suggestionsRepo = SuggestionsRepository(prefs);
      final feedbackModel = FeedbackModel(prefs);
      final weatherService = WeatherService();

      await tester.pumpWidget(
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

      expect(find.byType(SplashScreen), findsOneWidget);
    });

    testWidgets('should respect dark mode preference when system theme is off',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final preferencesModel = PreferencesModel(prefs);
      preferencesModel.useSystemTheme = false;
      preferencesModel.useDarkMode = true;

      final suggestionsRepo = SuggestionsRepository(prefs);
      final feedbackModel = FeedbackModel(prefs);
      final weatherService = WeatherService();

      await tester.pumpWidget(
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

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.dark);
    });

    testWidgets('should respect light mode preference when system theme is off',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final preferencesModel = PreferencesModel(prefs);
      preferencesModel.useSystemTheme = false;
      preferencesModel.useDarkMode = false;

      final suggestionsRepo = SuggestionsRepository(prefs);
      final feedbackModel = FeedbackModel(prefs);
      final weatherService = WeatherService();

      await tester.pumpWidget(
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

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.light);
    });
  });


  group('QuestionCard', () {
    testWidgets('should display question and description', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuestionCard(
              question: 'What is your preference?',
              description: 'Choose your preferred activity type',
              child: Text('Options go here'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('What is your preference?'), findsOneWidget);
      expect(find.text('Choose your preferred activity type'), findsOneWidget);
    });

    testWidgets('should display child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuestionCard(
              question: 'Test Question',
              description: 'Test Description',
              child: Text('Custom Child Widget'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Custom Child Widget'), findsOneWidget);
    });
  });

  group('ActivityOptionCard', () {
    testWidgets('should display title and description', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityOptionCard(
              title: 'Indoor',
              isSelected: false,
              icon: Icons.home,
              onTap: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Indoor'), findsOneWidget);
      expect(
          find.text('Activities to enjoy inside your home or other indoor spaces'),
          findsOneWidget);
    });

    testWidgets('should call onTap when tapped', (tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityOptionCard(
              title: 'Outdoor',
              isSelected: false,
              icon: Icons.park,
              onTap: () {
                wasTapped = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Outdoor'));
      await tester.pumpAndSettle();

      expect(wasTapped, true);
    });

    testWidgets('should show check icon when selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityOptionCard(
              title: 'Hybrid',
              isSelected: true,
              icon: Icons.sync_alt,
              onTap: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('should show outlined icon when not selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityOptionCard(
              title: 'Indoor',
              isSelected: false,
              icon: Icons.home,
              onTap: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    });
  });
}
