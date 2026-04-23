import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/preferences_model.dart';
import '../models/suggestions_repository.dart';
import '../models/activity_history_model.dart';
import '../models/feedback_model.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../widgets/custom_painters.dart';
import '../utils/decidr_theme.dart';
import '../utils/constants.dart';
import '../utils/wheel_math.dart';
import '../screens/welcome_page.dart';

/// Enhanced wheel page with improved visualization
class WheelPage extends StatefulWidget {
  const WheelPage({super.key});

  @override
  _WheelPageState createState() => _WheelPageState();
}

class _WheelPageState extends State<WheelPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  /// Current wheel rotation in radians. Exposed as a [ValueNotifier] so the
  /// rotating subtree can rebuild on each frame via [ValueListenableBuilder]
  /// without forcing a rebuild of the whole Scaffold.
  final ValueNotifier<double> _rotation = ValueNotifier<double>(0.0);

  bool _isSpinning = false;
  int? _selectedSegment;
  List<String> _suggestions = [];
  List<IconData> _suggestionIcons = const [];
  String? _selectedSuggestion;

  // For manual spinning with gesture
  double _startDragPosition = 0.0;
  double _previousRotation = 0.0;
  double _dragVelocity = 0.0;
  DateTime? _lastDragTime;
  
  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _controller = AnimationController(
      vsync: this,
      duration: WheelConstants.minSpinDuration,
    );

    // Handle the animation completion
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _rotation.value = _animation.value;
        setState(() {
          _isSpinning = false;

          if (_suggestions.isNotEmpty) {
            _selectedSegment = WheelMath.selectedSegment(
              _rotation.value,
              _suggestions.length,
            );
            _selectedSuggestion = _suggestions[_selectedSegment!];

            // Trigger haptic feedback for better user experience
            _triggerStopHaptics();

            // Record the activity in history
            _recordActivity();
          }
        });
      }
    });

    // Weather feature disabled for initial release
    // To enable: uncomment the weather fetch and configure API key in weather_service.dart
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final weatherService = Provider.of<WeatherService>(context, listen: false);
    //   weatherService.fetchWeather();
    // });

    // Load suggestions based on preferences
    _loadSuggestions();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSuggestions();
  }
  
  // Load suggestions based on user preferences
  void _loadSuggestions() {
    if (!mounted) return;
    final preferencesModel = Provider.of<PreferencesModel>(context, listen: false);
    final suggestionsRepo = Provider.of<SuggestionsRepository>(context, listen: false);
    final weatherService = Provider.of<WeatherService>(context, listen: false);
    final feedbackModel = Provider.of<FeedbackModel>(context, listen: false);

    if (preferencesModel.arePreferencesComplete) {
      _suggestions = suggestionsRepo.getSuggestions(
        activity: preferencesModel.activityPreference!,
        mood: preferencesModel.mood!,
        timeOfDay: preferencesModel.effectiveTimeOfDay,  // Use effectiveTimeOfDay for auto-detect
        energyLevel: preferencesModel.energyLevel,
        favorites: preferencesModel.favoriteActivities,
        weather: weatherService.currentWeather,
        feedback: feedbackModel,
        socialContext: preferencesModel.socialContext,
        duration: preferencesModel.duration,
      );
    } else {
      // Default suggestions if preferences not complete
      _suggestions = suggestionsRepo.getSuggestions(
        activity: 'Hybrid',
        mood: 'Relaxed',
        timeOfDay: 'Afternoon',
        energyLevel: 3.0,
        weather: weatherService.currentWeather,
        feedback: feedbackModel,
      );
    }

    // Resolve icons once per suggestions list so the painter doesn't have
    // to call back into the provider for every segment on every frame.
    _suggestionIcons = _suggestions
        .map(suggestionsRepo.getIconForSuggestion)
        .toList(growable: false);

    setState(() {});
  }
  
  // Record selected activity in history
  void _recordActivity() {
    if (_selectedSuggestion != null) {
      final historyModel = Provider.of<ActivityHistoryModel>(context, listen: false);
      historyModel.recordActivity(_selectedSuggestion!);
    }
  }
  
  // Create haptic feedback cascade for wheel stopping
  void _triggerStopHaptics() async {
    final preferencesModel = Provider.of<PreferencesModel>(context, listen: false);
    if (!preferencesModel.enableHaptics) return;

    HapticFeedback.heavyImpact();
    await Future.delayed(WheelConstants.hapticDelayHeavy);
    HapticFeedback.mediumImpact();
    await Future.delayed(WheelConstants.hapticDelayMedium);
    HapticFeedback.lightImpact();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _rotation.dispose();
    super.dispose();
  }
  
  // Start spinning the wheel
  void _spinWheel() {
    if (_isSpinning || _suggestions.isEmpty) return;
    
    // Trigger haptic feedback
    final preferencesModel = Provider.of<PreferencesModel>(context, listen: false);
    if (preferencesModel.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    
    setState(() {
      _isSpinning = true;
      _selectedSegment = null;
      _selectedSuggestion = null;
    });
    
    // Determine a random target segment
    int n = _suggestions.length;
    int targetSegment = Random().nextInt(n);
    
    // Calculate spin details for realistic physics
    int fullSpins = WheelConstants.minSpinRotations +
        Random().nextInt(WheelConstants.maxSpinRotations - WheelConstants.minSpinRotations + 1);
    double segmentAngle = 2 * pi / n;

    // Add randomness to final position within segment
    double segmentRandomness = Random().nextDouble() * 0.5 * segmentAngle;
    double finalRotation = 2 * pi * fullSpins + targetSegment * segmentAngle + segmentRandomness;

    // Randomize spin duration for unpredictability
    int minSeconds = WheelConstants.minSpinDuration.inSeconds;
    int maxSeconds = WheelConstants.maxSpinDuration.inSeconds;
    int randomDuration = minSeconds + Random().nextInt(maxSeconds - minSeconds + 1);
    _controller.duration = Duration(seconds: randomDuration);
    
    // Configure animation with custom curve for realistic physics
    _animation = Tween<double>(
      begin: _rotation.value,
      end: _rotation.value + finalRotation,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutExpo, // More realistic spin-down
      ),
    )..addListener(() {
        // Update the notifier only — avoids rebuilding the whole Scaffold
        // every animation frame.
        _rotation.value = _animation.value;
      });

    // Start the spin
    _controller.reset();
    _controller.forward();
  }

  // Handle pan start for manual spinning
  void _handlePanStart(DragStartDetails details) {
    if (_isSpinning) return;

    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final center = box.size.center(Offset.zero);
    final touchPosition = box.globalToLocal(details.globalPosition);

    // Calculate the angle of touch relative to center
    _startDragPosition = WheelMath.angleFromPosition(center, touchPosition);
    _previousRotation = _rotation.value;
    _lastDragTime = DateTime.now();
  }

  // Handle pan update for manual spinning
  void _handlePanUpdate(DragUpdateDetails details) {
    if (_isSpinning) return;

    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final center = box.size.center(Offset.zero);
    final touchPosition = box.globalToLocal(details.globalPosition);

    // Calculate new angle and update rotation
    final currentAngle = WheelMath.angleFromPosition(center, touchPosition);
    final angleDifference = currentAngle - _startDragPosition;

    // Notifier update avoids rebuilding the full Scaffold per drag event.
    _rotation.value = _previousRotation + angleDifference;

    // Calculate velocity for momentum
    final now = DateTime.now();
    final timeDiff = now.difference(_lastDragTime!).inMilliseconds;
    if (timeDiff > 0) {
      _dragVelocity = angleDifference / timeDiff * 100; // Scale for effect
      _lastDragTime = now;
    }
  }
  
  // Handle pan end for manual spinning
  void _handlePanEnd(DragEndDetails details) {
    if (_isSpinning) return;

    // If drag was fast enough, continue spinning with momentum
    if (_dragVelocity.abs() > WheelConstants.minVelocityForMomentum) {
      _spinWithMomentum(_dragVelocity);
    } else {
      // Snap to nearest segment
      _snapToNearestSegment();
    }
  }
  
  // Spin the wheel with momentum based on user's drag gesture
  void _spinWithMomentum(double velocity) {
    setState(() {
      _isSpinning = true;
      _selectedSegment = null;
      _selectedSuggestion = null;
    });

    // Calculate spin based on velocity - more velocity = more spins
    final spinAmount = velocity.abs() * WheelConstants.velocityMultiplier;
    final spinDuration = Duration(
        seconds: 2 + (velocity.abs() * WheelConstants.velocityDurationFactor).toInt());
    
    _controller.duration = spinDuration;
    
    _animation = Tween<double>(
      begin: _rotation.value,
      end: _rotation.value + (velocity > 0 ? spinAmount : -spinAmount),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    )..addListener(() {
        _rotation.value = _animation.value;
      });

    // Start the spin with momentum
    _controller.reset();
    _controller.forward();
  }

  // Snap the wheel to the nearest segment
  void _snapToNearestSegment() {
    if (_suggestions.isEmpty) return;

    final start = _rotation.value;
    final delta = WheelMath.snapDelta(start, _suggestions.length);

    // Small animation to snap to nearest segment
    _controller.duration = WheelConstants.snapDuration;

    _animation = Tween<double>(
      begin: start,
      end: start + delta,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
      ),
    )..addListener(() {
        _rotation.value = _animation.value;
      });

    _controller.reset();
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preferencesModel = Provider.of<PreferencesModel>(context);
    final wheelColors = DecidrTheme.getWheelColors(preferencesModel.colorTheme);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decidr'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Start Over?'),
                  content: const Text('Would you like to go back to the welcome screen?'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                      },
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WelcomePage(),
                          ),
                          (route) => false, // Remove all previous routes
                        );
                      },
                      child: const Text('Start Over'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Start Over',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () {
              _loadSuggestions();
              setState(() {
                _selectedSegment = null;
                _selectedSuggestion = null;
              });
            },
            tooltip: 'Refresh suggestions',
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              Navigator.pushNamed(context, '/questionnaire').then((_) => _loadSuggestions());
            },
            tooltip: 'Update preferences',
          ),
        ],
      ),
      body: _suggestions.isEmpty
          ? _buildEmptySuggestionsView()
          : Column(
              children: [
                // Weather info and quick-pick filters
                _buildHeaderSection(),

                // Wheel
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onPanStart: _handlePanStart,
                      onPanUpdate: _handlePanUpdate,
                      onPanEnd: _handlePanEnd,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Shadow for 3D effect
                          Container(
                            width: WheelConstants.wheelShadowSize,
                            height: WheelConstants.wheelShadowSize,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                          ),

                          // The wheel
                          AnimatedContainer(
                            duration: UIConstants.mediumAnimationDuration,
                            width: WheelConstants.wheelSize,
                            height: WheelConstants.wheelSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: _isSpinning
                                  ? [] // No shadow while spinning for performance
                                  : [
                                      const BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 10,
                                        spreadRadius: 0,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                            ),
                            child: ValueListenableBuilder<double>(
                              valueListenable: _rotation,
                              builder: (context, angle, child) {
                                return Transform.rotate(
                                  angle: angle,
                                  child: child,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.white,
                                      Colors.grey.shade100,
                                    ],
                                    center: const Alignment(0.0, 0.0),
                                    radius: 0.7,
                                  ),
                                ),
                                child: CustomPaint(
                                  painter: EnhancedWheelPainter(
                                    suggestions: _suggestions,
                                    selectedSegment: _selectedSegment,
                                    colors: wheelColors,
                                    icons: _suggestionIcons,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          // Center knob
                          Container(
                            width: WheelConstants.centerKnobSize,
                            height: WheelConstants.centerKnobSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 5,
                                  spreadRadius: 0,
                                  offset: Offset(0, 1),
                                ),
                              ],
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.grey.shade200,
                                  Colors.grey.shade400,
                                ],
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: WheelConstants.centerKnobInnerSize,
                                height: WheelConstants.centerKnobInnerSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          
                          // Pointer
                          Positioned(
                            top: 15,
                            child: SizedBox(
                              width: WheelConstants.pointerSize,
                              height: WheelConstants.pointerSize,
                              child: CustomPaint(
                                painter: EnhancedPointerPainter(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Result card with feedback buttons
                if (_selectedSuggestion != null)
                  _buildResultCardWithFeedback(),
                
                // Spin button
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: ElevatedButton.icon(
                    onPressed: _isSpinning ? null : _spinWheel,
                    icon: Icon(_selectedSuggestion == null ? Icons.shuffle : Icons.refresh),
                    label: Text(
                      _selectedSuggestion == null ? 'Spin the Wheel' : 'Spin Again',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      minimumSize: const Size(200, 56),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
  
  // Build empty suggestions view
  Widget _buildEmptySuggestionsView() {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sentiment_neutral,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No suggestions available',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Update your preferences or try refreshing to get personalized suggestions.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/questionnaire').then((_) => _loadSuggestions());
              },
              icon: const Icon(Icons.tune),
              label: const Text('Update Preferences'),
            ),
          ],
        ),
      ),
    );
  }

  // Build header section with weather and quick-pick filters
  Widget _buildHeaderSection() {
    final weatherService = Provider.of<WeatherService>(context);
    final preferencesModel = Provider.of<PreferencesModel>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Weather chip
          if (weatherService.currentWeather != null)
            _buildWeatherChip(weatherService.currentWeather!),

          const SizedBox(height: 8),

          // Quick-pick filters
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  icon: Icons.people,
                  label: preferencesModel.socialContext ?? 'Anyone',
                  options: preferencesModel.socialOptions,
                  currentValue: preferencesModel.socialContext,
                  onSelected: (value) {
                    preferencesModel.updatePreference('socialContext', value);
                    _loadSuggestions();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterDropdown(
                  icon: Icons.timer,
                  label: preferencesModel.duration ?? 'Any time',
                  options: preferencesModel.durationOptions,
                  currentValue: preferencesModel.duration,
                  onSelected: (value) {
                    preferencesModel.updatePreference('duration', value);
                    _loadSuggestions();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build weather chip
  Widget _buildWeatherChip(WeatherData weather) {
    final theme = Theme.of(context);

    IconData weatherIcon;
    Color chipColor;

    if (weather.isRainy) {
      weatherIcon = Icons.water_drop;
      chipColor = Colors.blue.shade100;
    } else if (weather.isSnowy) {
      weatherIcon = Icons.ac_unit;
      chipColor = Colors.lightBlue.shade50;
    } else if (weather.condition == 'clear') {
      weatherIcon = Icons.wb_sunny;
      chipColor = Colors.amber.shade100;
    } else {
      weatherIcon = Icons.cloud;
      chipColor = Colors.grey.shade200;
    }

    return Chip(
      avatar: Icon(weatherIcon, size: 18),
      label: Text(
        '${weather.temperature.round()}° ${weather.condition}',
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: chipColor,
      visualDensity: VisualDensity.compact,
    );
  }

  // Build filter dropdown
  Widget _buildFilterDropdown({
    required IconData icon,
    required String label,
    required List<String> options,
    required String? currentValue,
    required Function(String?) onSelected,
  }) {
    final theme = Theme.of(context);

    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: null,
          child: Text('Clear filter', style: TextStyle(color: theme.colorScheme.error)),
        ),
        ...options.map((option) => PopupMenuItem<String>(
              value: option,
              child: Text(option),
            )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // Build result card with feedback buttons
  Widget _buildResultCardWithFeedback() {
    final theme = Theme.of(context);
    final historyModel = Provider.of<ActivityHistoryModel>(context, listen: false);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _selectedSuggestion!,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // "Did it!" button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      historyModel.recordActivity(_selectedSuggestion!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added "${_selectedSuggestion!}" to history'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Did it!'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // "Not this" button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showNotThisOptions(),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Not this'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Show "Not This" options dialog
  void _showNotThisOptions() {
    final theme = Theme.of(context);
    final feedbackModel = Provider.of<FeedbackModel>(context, listen: false);

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
              feedbackModel.rejectActivity(_selectedSuggestion!);
              Navigator.pop(context);
              _spinWheel(); // Automatically respin
            },
          ),
          ListTile(
            leading: const Icon(Icons.thumb_down),
            title: const Text('I don\'t like this'),
            subtitle: const Text('Don\'t show me this again'),
            onTap: () {
              feedbackModel.dislikeActivity(_selectedSuggestion!);
              Navigator.pop(context);
              _spinWheel(); // Automatically respin
            },
          ),
          ListTile(
            leading: const Icon(Icons.cancel),
            title: const Text('Cancel'),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}