import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/preference_profile.dart';
import '../models/preferences_model.dart';
import '../widgets/question_card.dart';
import '../widgets/save_profile_dialog.dart';
import 'main_tabs_page.dart';
import 'welcome_page.dart';

/// Enhanced questionnaire page with multiple questions
class QuestionnairePage extends StatelessWidget {
  const QuestionnairePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Preferences'),
        elevation: 0,
        // Always exit to the Welcome page. After the first completed
        // questionnaire the Welcome route is removed from the stack
        // (Continue uses pushAndRemoveUntil), so a plain pop would
        // land wherever the questionnaire was opened from instead.
        leading: BackButton(
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomePage()),
            (route) => false,
          ),
        ),
      ),
      body: const QuestionnaireForm(),
    );
  }
}

/// Questionnaire form with animated transitions between questions
class QuestionnaireForm extends StatefulWidget {
  const QuestionnaireForm({super.key});

  @override
  State<QuestionnaireForm> createState() => _QuestionnaireFormState();
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
        // Quick start: saved profiles apply in one tap and go straight
        // to the deal — the whole point of saving them.
        if (preferencesModel.savedProfiles.isNotEmpty)
          _buildQuickStartRow(theme, preferencesModel),

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
        
        // On the last page with complete answers, offer to snapshot
        // them as a reusable profile.
        if (_isLastPage && preferencesModel.arePreferencesComplete)
          TextButton.icon(
            onPressed: () => showSaveProfileDialog(context),
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('Save these answers as a profile'),
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
  
  /// Horizontal chip row applying a saved profile and jumping straight
  /// to the deal.
  Widget _buildQuickStartRow(ThemeData theme, PreferencesModel model) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick start',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            // Scales with the user's text size so large accessibility
            // settings don't clip the chips.
            height: 40 * MediaQuery.textScalerOf(context).scale(14) / 14,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: model.savedProfiles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final profile = model.savedProfiles[i];
                return ActionChip(
                  avatar: const Icon(Icons.bolt, size: 16),
                  label: Text(profile.name),
                  tooltip: profile.summary,
                  onPressed: () => _applyProfileAndDeal(profile),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyProfileAndDeal(PreferenceProfile profile) async {
    final model = Provider.of<PreferencesModel>(context, listen: false);
    await model.applyProfile(profile);
    if (!mounted) return;
    // A profile saved without a mood (or manual time) can't deal yet —
    // stay here with the answers filled in so the user completes the
    // rest, instead of landing them on a dead Decide tab.
    if (!model.arePreferencesComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Applied "${profile.name}" — answer the remaining '
            'questions to deal.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainTabsPage()),
      (route) => false,
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

      // Page 2: Energy level + weirdness tolerance + social context
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

            const SizedBox(height: 24),

            // Social context — optional, tap the selected chip to
            // clear. The catalog tags hundreds of entries by company
            // (partner/small group/large group); without this question
            // that whole filter dimension sat dormant.
            Text(
              'Who’s with you?',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              'Optional — skip it and we’ll deal for any company.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: preferencesModel.socialOptions.map((option) {
                final selected = preferencesModel.socialContext == option;
                return ChoiceChip(
                  label: Text(option),
                  selected: selected,
                  avatar: Icon(_getSocialIcon(option), size: 18),
                  onSelected: (nowSelected) {
                    preferencesModel.setPreference(
                      PreferenceKey.socialContext,
                      nowSelected ? option : null,
                    );
                  },
                );
              }).toList(),
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
  
  // Get icon for social context
  IconData _getSocialIcon(String social) {
    switch (social) {
      case 'Solo':
        return Icons.person;
      case 'Partner':
        return Icons.favorite_outline;
      case 'Small Group':
        return Icons.group;
      case 'Large Group':
        return Icons.groups;
      default:
        return Icons.person_outline;
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