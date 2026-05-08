import 'dart:async';

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
  /// Pre-deal — three face-down cards waiting for "Deal cards" tap.
  idle,

  /// Cards are flipping face-up one at a time (left → right → middle).
  dealing,

  /// All cards face-up; the chosen middle card is elevated and the
  /// description / actions are revealed below.
  settled,

  /// User's preferences yield no candidates — show a friendly empty
  /// state instead of the cards.
  empty,
}

/// Tarot-style card reveal screen.
///
/// Three face-down cards are dealt; they flip up one at a time in a
/// dramatic sequence — left first, right second, middle last (the
/// chosen recommendation, saved for the end). The flanking pair stay
/// visible after the reveal as honestly-considered alternatives.
class CardRevealPage extends StatefulWidget {
  const CardRevealPage({super.key});

  @override
  State<CardRevealPage> createState() => _CardRevealPageState();
}

class _CardRevealPageState extends State<CardRevealPage>
    with SingleTickerProviderStateMixin {
  // ─── animation timing knobs ───────────────────────────────────
  //
  // Full sequence:
  //   0–700ms        Cards deal in from above (staggered: L → R → M)
  //   +250ms         Settle breath
  //   +100ms         Card 0 (left) flips up   · light haptic
  //   +650ms more    Card 2 (right) flips up  · light haptic
  //   +650ms more    Card 1 (middle) flips up · medium haptic — chosen
  //   +850ms more    Settle: chosen scales+glows, description slides up
  //
  // Total ~3.2s. Each timing knob can be tuned independently.
  static const _dealInDuration = Duration(milliseconds: 700);
  static const _dealInBreath = Duration(milliseconds: 250);

  /// Flip delays, measured from end of [_dealInBreath].
  static const _firstFlipDelay = Duration(milliseconds: 100);
  static const _secondFlipDelay = Duration(milliseconds: 750);
  static const _thirdFlipDelay = Duration(milliseconds: 1400);
  static const _settleDelay = Duration(milliseconds: 2250);

  /// Landing-haptic offsets, measured from start of deal-in.
  /// One subtle tap per card as it touches down.
  static const _land0Delay = Duration(milliseconds: 315);
  static const _land2Delay = Duration(milliseconds: 490);
  static const _land1Delay = Duration(milliseconds: 665);

  /// When re-dealing from the settled state, give the existing cards
  /// a moment to flip back down before the new pool is staged.
  static const _redealResetDelay = Duration(milliseconds: 450);

  /// Per-slot deal-in window within `_dealInController.value` (0..1).
  /// Indexed by slot (0 = left, 1 = middle, 2 = right).
  /// Slot 0 lands first, slot 2 second, slot 1 last — the chosen
  /// middle card is the final piece of the pre-flip choreography.
  static const _slotDealStart = <double>[0.00, 0.50, 0.25];
  static const _slotDealEnd = <double>[0.45, 0.95, 0.70];

  /// Per-slot starting offset and rotation for the deal-in.
  /// Cards arrive from above-and-outside, fanning toward their slots.
  static const _slotStartOffsets = <Offset>[
    Offset(70, -210),   // slot 0 (left) starts above-right of its slot
    Offset(0, -240),    // slot 1 (middle) drops straight down
    Offset(-70, -210),  // slot 2 (right) starts above-left of its slot
  ];
  static const _slotStartRotations = <double>[
    0.30,   // slot 0 — tilted right
    0.0,    // slot 1
    -0.30,  // slot 2 — tilted left
  ];

  late final AnimationController _dealInController;

  // ─── state ────────────────────────────────────────────────────
  _RevealStage _stage = _RevealStage.idle;

  /// The three suggestions assigned to the three card slots, in order.
  /// Slot 1 (the middle card) is always the chosen recommendation.
  List<Suggestion?> _slotSuggestions = [null, null, null];

  /// Flanking alternatives shown in the "also considered" line.
  List<Suggestion> _flanking = [];

  /// Which slots have flipped face-up so far during the dealing stage.
  /// Slot 1 (middle) is always the last to be added.
  final Set<int> _revealedSlots = {};

  // Timers driving the reveal sequence.
  final List<Timer?> _flipTimers = [null, null, null];
  Timer? _settleTimer;

  /// The chosen suggestion is always [_slotSuggestions[1]] (the middle
  /// card) once we're in [_RevealStage.settled].
  Suggestion? get _chosen =>
      _stage == _RevealStage.settled ? _slotSuggestions[1] : null;

  @override
  void initState() {
    super.initState();
    _dealInController = AnimationController(
      vsync: this,
      duration: _dealInDuration,
    );
    // Trigger a rebuild after first frame so the empty/idle distinction
    // is correct based on currently-loaded preferences.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _cancelAllTimers();
    _dealInController.dispose();
    super.dispose();
  }

  void _cancelAllTimers() {
    for (var i = 0; i < _flipTimers.length; i++) {
      _flipTimers[i]?.cancel();
      _flipTimers[i] = null;
    }
    _settleTimer?.cancel();
    _settleTimer = null;
  }

  /// Build the candidate pool for a fresh deal. Returns null if the
  /// user's preferences don't yield enough candidates.
  List<Suggestion>? _buildPool() {
    final prefs = Provider.of<PreferencesModel>(context, listen: false);
    final repo = Provider.of<SuggestionsRepository>(context, listen: false);
    final weather =
        Provider.of<WeatherService>(context, listen: false).currentWeather;
    final feedback = Provider.of<FeedbackModel>(context, listen: false);

    if (!prefs.arePreferencesComplete) return null;

    final activityType = ActivityType.values
        .firstWhere((e) => e.label == prefs.activityPreference);
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

  /// Kick off a fresh deal — cards flip back if applicable, deal in
  /// from above, then flip up sequentially with new candidates.
  Future<void> _deal() async {
    if (_stage == _RevealStage.dealing) return;
    _cancelAllTimers();

    final pool = _buildPool();
    if (pool == null) {
      setState(() => _stage = _RevealStage.empty);
      return;
    }

    // If we were settled, flip the cards back to face-down before
    // re-dealing so the visual transition is smooth.
    if (_stage == _RevealStage.settled) {
      setState(() {
        _stage = _RevealStage.idle;
        _revealedSlots.clear();
      });
      await Future.delayed(_redealResetDelay);
      if (!mounted) return;
    }

    setState(() {
      _stage = _RevealStage.dealing;
      _slotSuggestions = [pool[0], pool[1], pool[2]];
      _flanking = [pool[0], pool[2]];
      _revealedSlots.clear();
    });

    // Stage 1: deal-in. Cards animate from off-screen to their slots.
    _dealInController.value = 0.0;
    _scheduleLandingHaptic(_land0Delay);
    _scheduleLandingHaptic(_land2Delay);
    _scheduleLandingHaptic(_land1Delay);
    await _dealInController.forward();
    if (!mounted) return;

    // Stage 2: a brief breath after the cards land.
    await Future.delayed(_dealInBreath);
    if (!mounted) return;

    // Stage 3: reveal sequence — left → right → middle (chosen).
    // Delays are measured from now (end of breath).
    _flipTimers[0] =
        Timer(_firstFlipDelay, () => _revealSlot(0, soft: true));
    _flipTimers[1] =
        Timer(_secondFlipDelay, () => _revealSlot(2, soft: true));
    _flipTimers[2] =
        Timer(_thirdFlipDelay, () => _revealSlot(1, soft: false));
    _settleTimer = Timer(_settleDelay, _settle);
  }

  /// Schedule a subtle haptic for when a card touches down during deal-in.
  void _scheduleLandingHaptic(Duration delay) {
    Timer(delay, () {
      if (!mounted) return;
      final prefs = Provider.of<PreferencesModel>(context, listen: false);
      if (prefs.enableHaptics) {
        HapticFeedback.selectionClick();
      }
    });
  }

  void _revealSlot(int slot, {required bool soft}) {
    if (!mounted) return;
    setState(() => _revealedSlots.add(slot));
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
    setState(() => _stage = _RevealStage.settled);
    final prefs = Provider.of<PreferencesModel>(context, listen: false);
    if (prefs.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
  }

  void _resetToIdle() {
    _cancelAllTimers();
    // Snap cards back to their pre-deal off-screen position so the next
    // deal can animate them in fresh.
    _dealInController.reset();
    setState(() {
      _stage = _RevealStage.idle;
      _slotSuggestions = [null, null, null];
      _flanking = [];
      _revealedSlots.clear();
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
              const SizedBox(height: 18),
              // Content scrolls so the settled-state description doesn't
              // overflow on shorter windows (macOS, small phones).
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildCardsRow(),
                      const SizedBox(height: 28),
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
      children: List.generate(3, _buildSlot),
    );
  }

  /// Per-slot wrapper: applies the deal-in transform (translate + rotate
  /// + opacity) on top of the [DecisionCard]'s own internal flip animation.
  ///
  /// At `_dealInController.value == 0` the card sits off-screen above its
  /// slot, rotated, fully transparent. As the controller advances, the
  /// card translates into place and fades in. Each slot has its own
  /// staggered window in [_slotDealRanges] so cards arrive sequentially.
  Widget _buildSlot(int slot) {
    return AnimatedBuilder(
      animation: _dealInController,
      builder: (context, _) {
        final progress = _slotProgress(slot, _dealInController.value);
        final eased = Curves.easeOutQuart.transform(progress);

        final start = _slotStartOffsets[slot];
        final dx = start.dx * (1 - eased);
        final dy = start.dy * (1 - eased);
        final rotation = _slotStartRotations[slot] * (1 - eased);
        // Cards fade in faster than they finish travelling so they feel
        // more present as they arrive.
        final opacity = Curves.easeOut.transform(progress).clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(dx, dy, 0, 1)
              ..rotateZ(rotation),
            child: DecisionCard(
              state: _stateForSlot(slot),
              suggestion: _slotSuggestions[slot],
            ),
          ),
        );
      },
    );
  }

  /// Map the global deal-in controller value to this slot's local
  /// 0..1 progress, given its staggered window.
  double _slotProgress(int slot, double t) {
    final start = _slotDealStart[slot];
    final end = _slotDealEnd[slot];
    if (t <= start) return 0.0;
    if (t >= end) return 1.0;
    return ((t - start) / (end - start)).clamp(0.0, 1.0);
  }

  /// Map the page's overall stage + per-slot reveal status to the card's
  /// own visual state.
  DecisionCardState _stateForSlot(int slot) {
    if (_stage == _RevealStage.idle || _stage == _RevealStage.empty) {
      return DecisionCardState.faceDown;
    }
    if (_stage == _RevealStage.dealing) {
      return _revealedSlots.contains(slot)
          ? DecisionCardState.revealed
          : DecisionCardState.faceDown;
    }
    // settled
    return slot == 1
        ? DecisionCardState.chosen
        : DecisionCardState.revealed;
  }

  Widget _buildBottomSection(ThemeData theme) {
    switch (_stage) {
      case _RevealStage.idle:
        return _buildIdleCallToAction(theme);
      case _RevealStage.dealing:
        // No hint needed — the flips themselves are the visual feedback.
        return const SizedBox(key: ValueKey('dealing'), height: 12);
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
          'We\'ll deal three cards. The middle one is yours.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
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

  Widget _buildSettledResult(ThemeData theme) {
    final chosen = _chosen;
    if (chosen == null) return const SizedBox.shrink();

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
        if (_flanking.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Also considered:  ${_flanking.map((s) => s.title).join('  ·  ')}',
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
