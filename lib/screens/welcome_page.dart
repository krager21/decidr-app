import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import '../models/preferences_model.dart';
import '../screens/questionnaire_page.dart';
import '../screens/main_tabs_page.dart';
import '../screens/settings_page.dart';
import '../widgets/animated_gradient_background.dart';

/// Welcome page with animated background and card
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Check if user has completed preferences before
    final preferencesModel = Provider.of<PreferencesModel>(context);
    final hasCompletedPreferences = preferencesModel.arePreferencesComplete;
    
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          const AnimatedGradientBackground(),
          
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo and title
                    const Icon(
                      Icons.shuffle_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome to Decidr!',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your personal decision assistant',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    
                    // Welcome card with animation
                    Animate(
                      effects: const [
                        SlideEffect(
                          begin: Offset(0, 0.1),
                          end: Offset.zero,
                          duration: Duration(milliseconds: 800),
                          curve: Curves.easeOutQuad,
                        ),
                        FadeEffect(
                          begin: 0.0,
                          end: 1.0,
                          duration: Duration(milliseconds: 800),
                          curve: Curves.easeOutQuad,
                        ),
                      ],
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Not sure what to do?',
                                style: theme.textTheme.headlineMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Let us help you decide. Tell us a little about yourself, and we\'ll deal you three personalised activity suggestions.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 32),
                              
                              // Get started or continue buttons
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) => 
                                        hasCompletedPreferences ? const MainTabsPage() : const QuestionnairePage(),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        return SharedAxisTransition(
                                          animation: animation,
                                          secondaryAnimation: secondaryAnimation,
                                          transitionType: SharedAxisTransitionType.horizontal,
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                },
                                icon: Icon(hasCompletedPreferences ? Icons.play_arrow : Icons.arrow_forward),
                                label: Text(
                                  hasCompletedPreferences ? 'Continue' : 'Get Started',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  minimumSize: const Size(200, 48),
                                ),
                              ),
                              
                              if (hasCompletedPreferences) ...[
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const QuestionnairePage(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.tune),
                                  label: const Text('Update Preferences'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Settings button
                    Animate(
                      effects: const [
                        FadeEffect(
                          delay: Duration(milliseconds: 500),
                          begin: 0.0,
                          end: 1.0,
                          duration: Duration(milliseconds: 800),
                        ),
                      ],
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.settings, color: Colors.white),
                        label: const Text(
                          'Settings',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}