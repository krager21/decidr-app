import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/activity_history_model.dart';
import '../models/feedback_model.dart';
import '../models/preferences_model.dart';
import '../models/suggestion.dart';
import '../models/suggestions_repository.dart';
import '../services/weather_service.dart';
import '../widgets/decision_card.dart';

/// Stages of the card-reveal animation flow.
enum _RevealStage {
  /// Pre-deal — three placeholder cards waiting for "Decide" tap.
  idle,

  /// All three cards are cycling through candidates; locks roll in
  /// left-to-right with haptic taps.
  dealing,

  /// All cards locked; the chosen middle card is elevated and the
  /// description / actions are revealed below.
  settled,

  /// User's preferences yield no candidates — show a friendly empty
  /// state instead of the cards.
  empty,
}

/// Card-reveal alternative to the spinning wheel.
///
/// Three cards animate "thinking" by cycling through real candidates
/// from the suggestions catalog. They lock left-to-right with light
/// haptics; the middle card becomes the chosen recommendation. The
/// flanking pair stay visible as honestly-considered alternatives.
class CardRevealPage extends StatefulWidget {
  const CardRevealPage({super.key});

  @override
  State<CardRevealPage> createState() => _CardRevealPageState();
}

class _CardRevealPageState extends State<CardRevealPage> {
  // ─── animation timing knobs ───────────────────────────────────
  // Each card swap during cycling.
  static const _cycleInterval = Duration(milliseconds: 280);

  // When each card locks (offset from the start of the deal).
  static const _lockDelay1 = Duration(milliseconds: 1200);
  static const _lockDelay2 = Duration(milliseconds: 1600);
  static const _lockDelay3 = Duration(milliseconds: 2000);
  static const _settleDelay = Duration(milliseconds: 2300);

  // ─── state ────────────────────────────────────────────────────
  _RevealStage _stage = _RevealStage.idle;

  /// Pool of candidates fetched at the start of each deal. The first
  /// three become the locked values for cards 0–2; the rest fuel the
  /// cycling animation.
  List<Suggestion> _pool = [];

  /// Currently displayed Suggestion per card slot (changes during cycling).
  final List<Suggestion?> _displayed = [null, null, null];

  /// Which cards have locked (no longer cycle).
  final Set<int> _locked = {};

  // Timers driving the animation.
  Timer? _cycleTimer;
  final List<Timer?> _lockTimers = [null, null, null];
  Timer? _settleTimer;

  /// The chosen suggestion is always [_pool[1]] (the middle card)
  /// once we're in [_RevealStage.settled].
  Suggestion? get _chosen =>
      _stage == _RevealStage.settled && _pool.length >= 2 ? _pool[1] : null;

  @override
  void initState() {
    super.initState();
    // Defer initial preferences-loaded check to next frame so providers
    // are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Just trigger a rebuild so the empty/idle distinction is correct.
      setState(() {});
    });
  }

  @override
  void dispose() {
    _cancelAllTimers();
    super.dispose();
  }

  void _cancelAllTimers() {
    _cycleTimer?.cancel();
    _cycleTimer = null;
    for (var i = 0; i < _lockTimers.length; i++) {
      _lockTimers[i]?.cancel();
      _lockTimers[i] = null;
    }
    _settleTimer?.cancel();
    _settleTimer = null;
  }

  /// Build the candidate pool for a fresh deal. Returns null if the
  /// user's preferences don't yield enough candidates.
  List<Suggestion>? _buildPool() {
    final prefs = Provider.of<PreferencesModel>(context, listen: false);
    final repo =
        Provider.of<SuggestionsRepository>(context, listen: false);
    final weather =
        Provider.of<WeatherService>(context, listen: false).currentWeather;
    final feedback = Provider.of<FeedbackModel>(context, listen: false);

    if (!prefs.arePreferencesComplete) return null;

    final activityType =
        ActivityType.values.firstWhere((e) => e.label == prefs.activityPreference);
    final mood = Mood.values.firstWhere((e) => e.label == prefs.mood);
    final timeOfDay = TimeOfDayPref.values
        .firstWhere((e) => e.label == prefs.effectiveTimeOfDay);
    final socialContext = prefs.socialContext == null
        ? null
        : SocialContext.values
            .firstWhere((e) => e.label == prefs.socialContext);

    final pool = repo.getStructuredSuggestions(
      activityType: activityType,
      mood: mood,
      timeOfDay: timeOfDay,
      energyLevel: prefs.energyLevel,
      socialContext: socialContext,
      duration: prefs.duration,
      weather: weather,
      feedback: feedback,
      favoriteIds: prefs.favoriteActivities,
      count: 9,
    );

    if (pool.length < 3) return null;
    return pool;
  }

  void _deal() {
    if (_stage == _RevealStage.dealing) return; // already dealing
    _cancelAllTimers();

    final pool = _buildPool();
    if (pool == null) {
      setState(() => _stage = _RevealStage.empty);
      return;
    }

    setState(() {
      _stage = _RevealStage.dealing;
      _pool = pool;
      _locked.clear();
      // Seed cycling slots with non-final candidates so the animation
      // doesn't briefly show the answer before it cycles.
      _displayed[0] = pool[(3) % pool.length];
      _displayed[1] = pool[(5) % pool.length];
      _displayed[2] = pool[(7) % pool.length];
    });

    // Periodic cycler — each tick advances every unlocked card to a new
    // pool item. Stops automatically when all three are locked.
    final rng = Random();
    _cycleTimer = Timer.periodic(_cycleInterval, (timer) {
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < 3; i++) {
          if (_locked.contains(i)) continue;
          // Pick something from the pool that isn't card i's final pick
          // and isn't what's currently shown — keeps cycling visible.
          final candidates = pool
              .where((s) => s.id != pool[i].id && s.id != _displayed[i]?.id)
              .toList();
          if (candidates.isEmpty) continue;
          _displayed[i] = candidates[rng.nextInt(candidates.length)];
        }
      });
    });

    // Lock cards left-to-right.
    _lockTimers[0] = Timer(_lockDelay1, () => _lockCard(0, soft: true));
    _lockTimers[1] = Timer(_lockDelay2, () => _lockCard(1, soft: true));
    _lockTimers[2] = Timer(_lockDelay3, () => _lockCard(2, soft: false));

    // Final settle: marks middle card as chosen, reveals description.
    _settleTimer = Timer(_settleDelay, _settle);
  }

  void _lockCard(int index, {required bool soft}) {
    if (!mounted) return;
    setState(() {
      _locked.add(index);
      _displayed[index] = _pool[index];
    });
    final prefs = Provider.of<PreferencesModel>(context, listen: false);
    if (prefs.enableHaptics) {
      if (soft) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }
  }

  void _settle() {
    if (!mounted) return;
    _cycleTimer?.cancel();
    _cycleTimer = null;
    setState(() => _stage = _RevealStage.settled);

    final prefs = Provider.of<PreferencesModel>(context, listen: false);
    if (prefs.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
  }

  void _resetToIdle() {
    _cancelAllTimers();
    setState(() {
      _stage = _RevealStage.idle;
      _pool = [];
      _displayed[0] = null;
      _displayed[1] = null;
      _displayed[2] = null;
      _locked.clear();
    });
  }

  void _markCompleted() {
    final chosen = _chosen;
    if (chosen == null) return;
    Provider.of<ActivityHistoryModel>(context, listen: false)
        .recordActivity(chosen.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${chosen.title}" to history'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    _resetToIdle();
  }

  void _showNotThisOptions() {
    final chosen = _chosen;
    if (chosen == null) return;
    final theme = Theme.of(context);
    final feedback = Provider.of<FeedbackModel>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Why not this activity?',
              style: theme.textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Not right now'),
            subtitle: const Text('Show me less often for a while'),
            onTap: () {
              feedback.rejectActivity(chosen.id);
              Navigator.pop(context);
              _deal();
            },
          ),
          ListTile(
            leading: const Icon(Icons.thumb_down),
            title: const Text('I don\'t like this'),
            subtitle: const Text('Don\'t show me this again'),
            onTap: () {
              feedback.dislikeActivity(chosen.id);
              Navigator.pop(context);
              _deal();
            },
          ),
          ListTile(
            leading: const Icon(Icons.cancel),
            title: const Text('Cancel'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ─── build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = Provider.of<PreferencesModel>(context);

    if (!prefs.arePreferencesComplete) {
      return Scaffold(
        appBar: AppBar(title: const Text('Decide')),
        body: _buildPreferencesIncomplete(theme),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Decide')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildContextChips(theme, prefs),
              const SizedBox(height: 16),
              // Content scrolls so the settled-state description doesn't
              // overflow on shorter windows (macOS, small phones).
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildCardsRow(),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.15),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              )),
                              child: child,
                            ),
                          );
                        },
                        child: _buildBottomSection(theme),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextChips(ThemeData theme, PreferencesModel prefs) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        _ContextChip(
          icon: Icons.home_work,
          label: prefs.activityPreference ?? '—',
        ),
        _ContextChip(icon: Icons.mood, label: prefs.mood ?? '—'),
        _ContextChip(
          icon: Icons.access_time,
          label: prefs.effectiveTimeOfDay,
        ),
        _ContextChip(
          icon: Icons.bolt,
          label: 'Energy ${prefs.energyLevel.toStringAsFixed(1)}',
        ),
        if (prefs.socialContext != null)
          _ContextChip(icon: Icons.people, label: prefs.socialContext!),
        if (prefs.duration != null)
          _ContextChip(icon: Icons.timer, label: prefs.duration!),
      ],
    );
  }

  Widget _buildCardsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (i) {
        final state = _stateForCard(i);
        return DecisionCard(
          state: state,
          suggestion: _displayed[i],
        );
      }),
    );
  }

  DecisionCardState _stateForCard(int index) {
    switch (_stage) {
      case _RevealStage.idle:
      case _RevealStage.empty:
        return DecisionCardState.idle;
      case _RevealStage.dealing:
        return _locked.contains(index)
            ? DecisionCardState.locked
            : DecisionCardState.cycling;
      case _RevealStage.settled:
        return index == 1
            ? DecisionCardState.chosen
            : DecisionCardState.locked;
    }
  }

  Widget _buildBottomSection(ThemeData theme) {
    switch (_stage) {
      case _RevealStage.idle:
        return _buildIdleCallToAction(theme);
      case _RevealStage.dealing:
        return _buildDealingHint(theme);
      case _RevealStage.settled:
        return _buildSettledResult(theme);
      case _RevealStage.empty:
        return _buildEmptyState(theme);
    }
  }

  Widget _buildIdleCallToAction(ThemeData theme) {
    return Column(
      key: const ValueKey('idle'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'We\'ll consider three options for you.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _deal,
          icon: const Icon(Icons.style),
          label: const Text('Deal cards'),
          style: FilledButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDealingHint(ThemeData theme) {
    return Padding(
      key: const ValueKey('dealing'),
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Considering options…',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildSettledResult(ThemeData theme) {
    final chosen = _chosen;
    if (chosen == null) return const SizedBox.shrink();
    final flanking = [
      if (_pool.isNotEmpty) _pool[0],
      if (_pool.length >= 3) _pool[2],
    ];

    return Column(
      key: const ValueKey('settled'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title + description card.
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chosen.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (chosen.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  chosen.description,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _MetaChip(
                    icon: Icons.timer,
                    label: _formatDuration(chosen.durationMinutes),
                  ),
                  _MetaChip(
                    icon: Icons.bolt,
                    label: 'Energy ${chosen.energyLevel.toStringAsFixed(1)}',
                  ),
                  if (chosen.tags.isNotEmpty)
                    for (final tag in chosen.tags.take(3))
                      _MetaChip(icon: Icons.tag, label: tag),
                ],
              ),
            ],
          ),
        ),
        if (flanking.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Also considered:  ${flanking.map((s) => s.title).join('  ·  ')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _markCompleted,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Did it!'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showNotThisOptions,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Not this'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _deal,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Deal again'),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      key: const ValueKey('empty'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.style_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No matching activities',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your filters and dealing again.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _resetToIdle,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesIncomplete(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tune,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Tell us about your mood first',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'A quick questionnaire so we can deal you good cards.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, '/questionnaire'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Get started'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int mins) {
    if (mins < 60) return '$mins min';
    final hrs = mins / 60;
    if (hrs == hrs.floor()) return '${hrs.floor()} hr';
    return '${hrs.toStringAsFixed(1)} hr';
  }
}

/// Pill-shaped chip showing a contextual filter at the top of the page.
class _ContextChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ContextChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Small chip for showing a piece of metadata about the chosen suggestion.
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
