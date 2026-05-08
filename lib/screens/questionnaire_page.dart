import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/preferences_model.dart';
import '../widgets/question_card.dart';
import 'main_tabs_page.dart';

/// Enhanced questionnaire page with multiple questions
class QuestionnairePage extends StatelessWidget {
  const QuestionnairePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Preferences'),
        elevation: 0,
      ),
      body: const QuestionnaireForm(),
    );
  }
}

/// Questionnaire form with animated transitions between questions
class QuestionnaireForm extends StatefulWidget {
  const QuestionnaireForm({super.key});

  @override
  _QuestionnaireFormState createState() => _QuestionnaireFormState();
}

class _QuestionnaireFormState extends State<QuestionnaireForm> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLastPage = false;

  // Calculate total pages based on auto-detect time setting
  int _getTotalPages(PreferencesModel model) {
    return model.autoDetectTime ? 2 : 3;
  }

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_pageListener);
  }

  void _pageListener() {
    final model = Provider.of<PreferencesModel>(context, listen: false);
    final totalPages = _getTotalPages(model);

    if (_pageController.page == totalPages - 1 && !_isLastPage) {
      setState(() {
        _isLastPage = true;
      });
    } else if (_pageController.page != totalPages - 1 && _isLastPage) {
      setState(() {
        _isLastPage = false;
      });
    }

    if (_pageController.page?.round() != _currentPage) {
      setState(() {
        _currentPage = _pageController.page!.round();
      });
    }
  }
  
  @override
  void dispose() {
    _pageController.removeListener(_pageListener);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preferencesModel = Provider.of<PreferencesModel>(context);
    final totalPages = _getTotalPages(preferencesModel);

    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step ${_currentPage + 1} of $totalPages',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_currentPage + 1) / totalPages,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
                minHeight: 8,
              ),
            ],
          ),
        ),
        
        // Question pages
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // Disable swiping
            children: _buildPages(theme, preferencesModel),
          ),
        ),
        
        // Navigation buttons
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button (hidden on first page)
              _currentPage > 0
                  ? ElevatedButton.icon(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : const SizedBox(width: 100),
              
              // Next or Continue button
              ElevatedButton.icon(
                onPressed: _canContinue(preferencesModel, _currentPage)
                    ? () {
                        if (_isLastPage) {
                          // Navigate to the main tabs (cards-deal page)
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MainTabsPage(),
                            ),
                            (route) => false,
                          );
                        } else {
                          // Go to next question
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      }
                    : null,
                icon: Icon(_isLastPage ? Icons.check : Icons.arrow_forward),
                label: Text(_isLastPage ? 'Continue' : 'Next'),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Build pages conditionally based on auto-detect time setting
  List<Widget> _buildPages(ThemeData theme, PreferencesModel preferencesModel) {
    final pages = <Widget>[
      // Page 1: Activity preference + mood
      QuestionCard(
        question: 'Where and how are you?',
        description:
            'Pick your environment and your current mood. Both shape what we deal you.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Environment:',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...preferencesModel.activityOptions.map((option) {
              return ActivityOptionCard(
                title: option,
                isSelected: preferencesModel.activityPreference == option,
                icon: _getActivityIcon(option),
                onTap: () {
                  preferencesModel.updatePreference(
                    'activityPreference',
                    option,
                  );
                },
              );
            }),
            const SizedBox(height: 20),
            Text(
              'Current mood:',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: preferencesModel.moodOptions.map((option) {
                return ChoiceChip(
                  label: Text(option),
                  selected: preferencesModel.mood == option,
                  onSelected: (selected) {
                    if (selected) {
                      preferencesModel.updatePreference('mood', option);
                    }
                  },
                  avatar: Icon(
                    _getMoodIcon(option),
                    size: 18,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),

      // Page 2: Energy level + weirdness tolerance
      QuestionCard(
        question: 'How adventurous are you feeling?',
        description:
            'Energy is how much oomph you have. Weirdness is how off-the-wall you want the suggestions.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Energy level slider
            Text(
              'Energy level:',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.battery_1_bar,
                    color: theme.colorScheme.onSurfaceVariant),
                Expanded(
                  child: Column(
                    children: [
                      Slider(
                        value: preferencesModel.energyLevel,
                        min: 1.0,
                        max: 5.0,
                        divisions: 4,
                        label: _getEnergyLabel(preferencesModel.energyLevel),
                        onChanged: (value) {
                          preferencesModel.updatePreference(
                            'energyLevel',
                            value,
                          );
                        },
                      ),
                      Align(
                        alignment: Alignment(
                          (preferencesModel.energyLevel - 3.0) / 2.0,
                          0.0,
                        ),
                        child: Text(
                          _getEnergyLabel(preferencesModel.energyLevel),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.battery_full, color: theme.colorScheme.primary),
              ],
            ),

            const SizedBox(height: 24),

            // Weirdness tolerance slider
            Text(
              'Weirdness:',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.local_cafe,
                    color: theme.colorScheme.onSurfaceVariant),
                Expanded(
                  child: Column(
                    children: [
                      Slider(
                        value: preferencesModel.weirdnessTolerance,
                        min: 0.0,
                        max: 1.0,
                        label: _getWeirdnessLabel(
                          preferencesModel.weirdnessTolerance,
                        ),
                        onChanged: (value) {
                          preferencesModel.setPreference(
                            PreferenceKey.weirdnessTolerance,
                            value,
                          );
                        },
                      ),
                      Align(
                        alignment: Alignment(
                          // Map 0..1 to -1..1
                          preferencesModel.weirdnessTolerance * 2 - 1,
                          0.0,
                        ),
                        child: Text(
                          _getWeirdnessLabel(
                            preferencesModel.weirdnessTolerance,
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
              ],
            ),
          ],
        ),
      ),
    ];

    // Only add time of day page if auto-detect is disabled
    if (!preferencesModel.autoDetectTime) {
      pages.add(
        QuestionCard(
          question: 'When are you planning to do this activity?',
          description: 'We\'ll suggest activities appropriate for this time of day.',
          child: Column(
            children: preferencesModel.timeOptions.map((option) {
              return TimeOptionCard(
                title: option,
                isSelected: preferencesModel.timeOfDay == option,
                icon: _getTimeIcon(option),
                description: _getTimeDescription(option),
                onTap: () {
                  preferencesModel.updatePreference('timeOfDay', option);
                },
              );
            }).toList(),
          ),
        ),
      );
    }

    return pages;
  }

  // Check if user can continue based on current page
  bool _canContinue(PreferencesModel model, int page) {
    switch (page) {
      case 0:
        // Page 1 now combines activity and mood — both required.
        return model.activityPreference != null && model.mood != null;
      case 1:
        // Energy and weirdness both default to sensible values, so
        // page 2 has no required field — the user can advance any time.
        return true;
      case 2:
        // Only validate time selection if auto-detect is disabled
        return model.autoDetectTime || model.timeOfDay != null;
      default:
        return false;
    }
  }
  
  // Get icon for activity type
  IconData _getActivityIcon(String activity) {
    switch (activity) {
      case 'Indoor':
        return Icons.home;
      case 'Outdoor':
        return Icons.terrain;
      case 'Hybrid':
        return Icons.sync_alt;
      default:
        return Icons.help_outline;
    }
  }
  
  // Get icon for mood
  IconData _getMoodIcon(String mood) {
    switch (mood) {
      case 'Relaxed':
        return Icons.spa;
      case 'Productive':
        return Icons.trending_up;
      case 'Creative':
        return Icons.palette;
      case 'Social':
        return Icons.people;
      default:
        return Icons.help_outline;
    }
  }
  
  // Get icon for time of day
  IconData _getTimeIcon(String time) {
    switch (time) {
      case 'Morning':
        return Icons.wb_sunny;
      case 'Afternoon':
        return Icons.wb_twighlight;
      case 'Evening':
        return Icons.nights_stay;
      case 'Night':
        return Icons.dark_mode;
      default:
        return Icons.access_time;
    }
  }
  
  // Get description for time of day
  String _getTimeDescription(String time) {
    switch (time) {
      case 'Morning':
        return 'Start your day off right';
      case 'Afternoon':
        return 'Make the most of your day';
      case 'Evening':
        return 'Wind down after a busy day';
      case 'Night':
        return 'Late night activities';
      default:
        return '';
    }
  }
  
  // Get label for energy level
  String _getEnergyLabel(double level) {
    if (level < 1.5) return 'Very Low';
    if (level < 2.5) return 'Low';
    if (level < 3.5) return 'Medium';
    if (level < 4.5) return 'High';
    return 'Very High';
  }

  // Get label for weirdness tolerance
  String _getWeirdnessLabel(double level) {
    if (level < 0.15) return 'Comfort food';
    if (level < 0.35) return 'A little novel';
    if (level < 0.55) return 'Mix it up';
    if (level < 0.75) return 'Lean weird';
    return 'Surprise me';
  }
}