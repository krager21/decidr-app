import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'weather_model.dart';
import 'feedback_model.dart';

/// Enhanced repository for managing activity suggestions with more variety
class SuggestionsRepository extends ChangeNotifier {
  final SharedPreferences _prefs;
  
  // Map of all available suggestions
  Map<String, Map<String, List<String>>> _suggestionsMap = {};
  
  // User custom suggestions
  List<String> customSuggestions = [];
  
  // Popular activities that should appear more frequently
  final List<String> _popularActivities = [
    'Take a walk',
    'Read a book',
    'Watch a movie',
    'Listen to music',
    'Call a friend',
    'Cook a meal',
    'Go for a run',
    'Meditate for 15 minutes',
    'Play a video game',
    'Try a new recipe',
    'Do a workout',
    'Take photos',
    'Write in a journal',
  ];
  
  SuggestionsRepository(this._prefs);
  
  // Load suggestions including custom ones
  Future<void> loadSuggestions() async {
    // Initialize with default suggestions
    _initializeDefaultSuggestions();
    
    // Load custom suggestions
    customSuggestions = _prefs.getStringList('customSuggestions') ?? [];
    notifyListeners();
  }
  
  // Save custom suggestions
  Future<void> saveCustomSuggestions() async {
    await _prefs.setStringList('customSuggestions', customSuggestions);
    notifyListeners();
  }
  
  /// Add a custom user-defined suggestion.
  ///
  /// Trims whitespace, enforces a max length of
  /// [SuggestionConstants.customSuggestionMaxLength], deduplicates
  /// case-insensitively, and caps the total count at
  /// [SuggestionConstants.customSuggestionMaxCount].
  ///
  /// Returns `true` if the suggestion was added, `false` if it was
  /// rejected (empty, too long, duplicate, or list is full).
  bool addCustomSuggestion(String suggestion) {
    final trimmed = suggestion.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > SuggestionConstants.customSuggestionMaxLength) {
      return false;
    }
    if (customSuggestions.length >=
        SuggestionConstants.customSuggestionMaxCount) {
      return false;
    }
    // Case-insensitive duplicate check.
    final lower = trimmed.toLowerCase();
    final isDuplicate = customSuggestions.any(
      (s) => s.toLowerCase() == lower,
    );
    if (isDuplicate) return false;

    customSuggestions.add(trimmed);
    saveCustomSuggestions();
    return true;
  }
  
  // Remove a custom suggestion
  void removeCustomSuggestion(String suggestion) {
    if (customSuggestions.contains(suggestion)) {
      customSuggestions.remove(suggestion);
      saveCustomSuggestions();
    }
  }
  
  // Get suggestions based on preferences
  List<String> getSuggestions({
    required String activity,
    required String mood,
    required String timeOfDay,
    required double energyLevel,
    bool includeCustom = true,
    bool includeFavorites = true,
    List<String> favorites = const [],
    WeatherData? weather,
    FeedbackModel? feedback,
    String? socialContext,
    String? duration,
  }) {
    // Get base suggestions
    List<String> suggestions = [];

    // Add suggestions from predefined categories
    if (_suggestionsMap.containsKey(activity) &&
        _suggestionsMap[activity]!.containsKey(mood)) {
      suggestions.addAll(_suggestionsMap[activity]![mood]!);
    } else {
      // Fallback suggestions if exact match not found
      suggestions.addAll(_getDefaultSuggestions());
    }

    // Filter by weather conditions if available
    if (weather != null) {
      suggestions = _filterByWeather(suggestions, weather);
      // Add weather-appropriate suggestions
      suggestions.addAll(_addWeatherSuggestions(weather));
    }

    // Filter by social context if specified
    if (socialContext != null) {
      suggestions = _filterBySocialContext(suggestions, socialContext);
    }

    // Filter by duration if specified
    if (duration != null) {
      suggestions = _filterByDuration(suggestions, duration);
    }

    // Filter by time of day
    suggestions = _filterByTimeOfDay(suggestions, timeOfDay);

    // Filter by energy level
    suggestions = _filterByEnergyLevel(suggestions, energyLevel);

    // Apply feedback weighting if available
    if (feedback != null) {
      suggestions = _applyFeedbackWeights(suggestions, feedback);
    }

    // Add custom suggestions if requested
    if (includeCustom && customSuggestions.isNotEmpty) {
      suggestions.addAll(customSuggestions);
    }
    
    // Always prioritize favorites if requested
    if (includeFavorites && favorites.isNotEmpty) {
      // Remove favorites from the main list to avoid duplicates
      suggestions.removeWhere((item) => favorites.contains(item));
      // Add favorites at the beginning
      suggestions.insertAll(0, favorites);
    }
    
    // Add popular activities with higher probability (if not already in list)
    List<String> popularToAdd = _popularActivities
        .where((popular) => !suggestions.contains(popular))
        .toList();
        
    // Add 30% of the missing popular activities
    int numPopularToAdd = max(1, (popularToAdd.length * 0.3).round());
    popularToAdd.shuffle(Random());
    suggestions.addAll(popularToAdd.take(numPopularToAdd));
    
    // Shuffle and ensure we have enough suggestions
    suggestions.shuffle(Random());
    
    // If we don't have enough suggestions, add some random ones from other categories
    if (suggestions.length < 8) {
      List<String> allSuggestions = _getAllSuggestions();
      allSuggestions.shuffle(Random());
      
      for (String suggestion in allSuggestions) {
        if (!suggestions.contains(suggestion)) {
          suggestions.add(suggestion);
          if (suggestions.length >= 12) { // Get a few extra for variety
            break;
          }
        }
      }
    }
    
    // Shuffle again for randomness
    suggestions.shuffle(Random());
    
    // Return at least 8 suggestions or up to 8 if we have fewer
    return suggestions.take(min(8, suggestions.length)).toList();
  }
  
  // Get all available suggestions across all categories
  List<String> _getAllSuggestions() {
    Set<String> allSuggestions = {};
    
    _suggestionsMap.forEach((activityType, moodMap) {
      moodMap.forEach((mood, suggestions) {
        allSuggestions.addAll(suggestions);
      });
    });
    
    allSuggestions.addAll(_getDefaultSuggestions());
    allSuggestions.addAll(customSuggestions);
    
    return allSuggestions.toList();
  }
  
  // Filter suggestions by time of day
  List<String> _filterByTimeOfDay(List<String> suggestions, String timeOfDay) {
    // Simple filtering logic - could be more sophisticated
    final timeSpecificSuggestions = suggestions.where((s) {
      final lower = s.toLowerCase();

      switch (timeOfDay) {
        case 'Morning':
          return !lower.contains('night') && !lower.contains('evening');
        case 'Afternoon':
          return !lower.contains('night') && !lower.contains('sleep');
        case 'Evening':
          return !lower.contains('morning') && !lower.contains('breakfast');
        case 'Night':
          return !lower.contains('breakfast') && !lower.contains('morning run');
      }
      return true;
    }).toList();

    // If we filtered too aggressively, return original
    if (timeSpecificSuggestions.length < 5) {
      return suggestions;
    }
    return timeSpecificSuggestions;
  }

  // Filter suggestions by weather conditions
  List<String> _filterByWeather(List<String> suggestions, WeatherData weather) {
    return suggestions.where((s) {
      final lower = s.toLowerCase();

      // Block outdoor activities in bad weather
      if (weather.isRainy || weather.isSnowy) {
        if (lower.contains('hike') ||
            lower.contains('picnic') ||
            lower.contains('park') ||
            lower.contains('outdoor') ||
            lower.contains('bike') ||
            lower.contains('run') && lower.contains('outdoor') ||
            lower.contains('walk') && lower.contains('park')) {
          return false;
        }
      }

      // Block strenuous outdoor activities in extreme heat
      if (weather.isHot) {
        if (lower.contains('run') ||
            lower.contains('hike') ||
            lower.contains('bike') ||
            lower.contains('workout') && lower.contains('outdoor')) {
          return false;
        }
      }

      // Block outdoor activities in extreme cold
      if (weather.isCold) {
        if (lower.contains('picnic') ||
            lower.contains('swim') ||
            lower.contains('park') && !lower.contains('indoor')) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Add weather-appropriate suggestions
  List<String> _addWeatherSuggestions(WeatherData weather) {
    final suggestions = <String>[];

    if (weather.isRainy) {
      suggestions.addAll([
        'Cozy movie marathon',
        'Bake something warm',
        'Read by the window',
        'Listen to rain sounds',
        'Indoor photography project',
      ]);
    } else if (weather.isSnowy) {
      suggestions.addAll([
        'Make hot chocolate',
        'Watch the snow fall',
        'Plan a winter activity',
        'Organize winter gear',
      ]);
    } else if (weather.condition == 'clear' && !weather.isHot && !weather.isCold) {
      suggestions.addAll([
        'Perfect day for a walk',
        'Have a picnic',
        'Outdoor photography',
        'Visit a local park',
        'Enjoy nature',
      ]);
    } else if (weather.isHot) {
      suggestions.addAll([
        'Find a cool spot indoors',
        'Make a cold drink',
        'Go for a swim',
        'Visit an air-conditioned place',
      ]);
    } else if (weather.isCold) {
      suggestions.addAll([
        'Make a warm meal',
        'Bundle up and explore',
        'Hot beverage time',
        'Indoor cozy activity',
      ]);
    }

    return suggestions;
  }

  // Apply feedback weighting to filter and sort suggestions
  List<String> _applyFeedbackWeights(List<String> suggestions, FeedbackModel feedback) {
    // Remove completely disliked activities
    suggestions = suggestions.where((s) =>
        feedback.getActivityWeight(s) > 0.0
    ).toList();

    // Create weighted list where activities appear more or less frequently based on weight
    final weightedSuggestions = <String>[];

    for (final suggestion in suggestions) {
      final weight = feedback.getActivityWeight(suggestion);

      // Add suggestion multiple times based on weight
      // Weight ranges from 0.1 to 1.0
      // We'll add 1-10 copies based on weight
      final copies = (weight * 10).round().clamp(1, 10);

      for (int i = 0; i < copies; i++) {
        weightedSuggestions.add(suggestion);
      }
    }

    // Shuffle the weighted list
    weightedSuggestions.shuffle(Random());

    // Remove duplicates while maintaining shuffled order
    return weightedSuggestions.toSet().toList();
  }

  // Filter suggestions by social context
  List<String> _filterBySocialContext(List<String> suggestions, String context) {
    return suggestions.where((s) {
      final lower = s.toLowerCase();

      switch (context) {
        case 'Solo':
          // Exclude explicitly group-only activities
          return !lower.contains('group') &&
              !lower.contains('team') &&
              !lower.contains('party') &&
              !lower.contains('multiplayer');

        case 'Partner':
          // Exclude solo-specific and large group activities
          return !lower.contains('solo meditation') &&
              !lower.contains('alone') &&
              !lower.contains('group') &&
              !lower.contains('team');

        case 'Small Group':
        case 'Large Group':
          // Prefer social activities, exclude solo-specific ones
          return !lower.contains('solo meditation') &&
              !lower.contains('alone time') &&
              !lower.contains('personal reflection');

        default:
          return true;
      }
    }).toList();
  }

  // Filter suggestions by duration
  List<String> _filterByDuration(List<String> suggestions, String dur) {
    return suggestions.where((s) {
      final lower = s.toLowerCase();

      if (dur.startsWith('Quick')) {
        // Quick activities (15 min)
        // Exclude long-duration keywords
        return !lower.contains('marathon') &&
            !lower.contains('day trip') &&
            !lower.contains('all day') &&
            !lower.contains('binge') &&
            !lower.contains('hike');
      } else if (dur.startsWith('Medium')) {
        // Medium activities (1 hr)
        // Most activities fit here, just exclude extremes
        return !lower.contains('quick') &&
            !lower.contains('5 minutes') &&
            !lower.contains('all day') &&
            !lower.contains('day trip');
      } else if (dur.startsWith('Half Day')) {
        // Half day activities
        // Exclude very quick activities
        return !lower.contains('quick') &&
            !lower.contains('15 min') &&
            !lower.contains('5 minutes') &&
            !lower.contains('brief');
      } else if (dur.startsWith('Full Day')) {
        // Full day activities
        // Only include activities that can take a long time
        return lower.contains('trip') ||
            lower.contains('adventure') ||
            lower.contains('marathon') ||
            lower.contains('project') ||
            lower.contains('day') ||
            lower.contains('explore') ||
            lower.contains('visit') ||
            !lower.contains('quick') && !lower.contains('15 min');
      }

      return true;
    }).toList();
  }

  /// Check if suggestion contains very low energy keywords
  bool _hasVeryLowEnergyKeywords(String lowerSuggestion) {
    return lowerSuggestion.contains('relax') ||
        lowerSuggestion.contains('meditate') ||
        lowerSuggestion.contains('sleep') ||
        lowerSuggestion.contains('rest') ||
        lowerSuggestion.contains('nap') ||
        lowerSuggestion.contains('bath');
  }

  /// Check if suggestion contains low energy keywords
  bool _hasLowEnergyKeywords(String lowerSuggestion) {
    return lowerSuggestion.contains('watch') ||
        lowerSuggestion.contains('listen') ||
        lowerSuggestion.contains('read') ||
        lowerSuggestion.contains('journal') ||
        lowerSuggestion.contains('podcast');
  }

  /// Check if suggestion contains medium energy keywords
  bool _hasMediumEnergyKeywords(String lowerSuggestion) {
    return lowerSuggestion.contains('walk') ||
        lowerSuggestion.contains('cook') ||
        lowerSuggestion.contains('bake') ||
        lowerSuggestion.contains('craft') ||
        lowerSuggestion.contains('garden');
  }

  /// Check if suggestion contains high energy keywords
  bool _hasHighEnergyKeywords(String lowerSuggestion) {
    return lowerSuggestion.contains('exercise') ||
        lowerSuggestion.contains('dance') ||
        lowerSuggestion.contains('clean') ||
        lowerSuggestion.contains('bike') ||
        lowerSuggestion.contains('workout');
  }

  /// Check if suggestion contains very high energy keywords
  bool _hasVeryHighEnergyKeywords(String lowerSuggestion) {
    return lowerSuggestion.contains('run') ||
        lowerSuggestion.contains('hike') ||
        lowerSuggestion.contains('adventure') ||
        lowerSuggestion.contains('challenge') ||
        lowerSuggestion.contains('sport') ||
        lowerSuggestion.contains('gym');
  }

  /// Calculate the energy level required for a suggestion based on keywords
  ///
  /// Returns a value from 1.0 (very low energy) to 5.0 (very high energy).
  /// Defaults to 3.0 (medium energy) if no keywords match.
  double _calculateSuggestionEnergy(String suggestion) {
    final lower = suggestion.toLowerCase();

    if (_hasVeryLowEnergyKeywords(lower)) return 1.0;
    if (_hasLowEnergyKeywords(lower)) return 2.0;
    if (_hasMediumEnergyKeywords(lower)) return 3.0;
    if (_hasHighEnergyKeywords(lower)) return 4.0;
    if (_hasVeryHighEnergyKeywords(lower)) return 5.0;

    return SuggestionConstants.energyLevelDefault;
  }

  /// Check if suggestion is in the popular activities list
  bool _isPopularActivity(String suggestion) {
    return _popularActivities.contains(suggestion);
  }

  /// Filter suggestions by energy level using weighted sampling
  ///
  /// Suggestions closer to the user's energy level get weighted more heavily.
  /// Popular activities get an additional boost.
  /// Returns a deduplicated list of suggestions.
  List<String> _filterByEnergyLevel(List<String> suggestions, double energyLevel) {
    List<String> result = [];

    for (final suggestion in suggestions) {
      final suggestionEnergy = _calculateSuggestionEnergy(suggestion);

      // Match user's energy with suggestion energy
      // The closer the match, the more copies we add to weight it
      final match = 5.0 - (suggestionEnergy - energyLevel).abs();

      // Add suggestion potentially multiple times based on match (weighting)
      int copies = max(1, match.round());
      for (int i = 0; i < copies; i++) {
        result.add(suggestion);
      }

      // Add popular activities more frequently
      if (_isPopularActivity(suggestion)) {
        result.add(suggestion);
      }
    }

    // Shuffle to avoid clumps of the same suggestion
    result.shuffle(Random());

    // Remove duplicates while maintaining order
    return result.toSet().toList();
  }
  
  // Initialize default suggestions
  void _initializeDefaultSuggestions() {
    _suggestionsMap = {
      'Indoor': {
        'Relaxed': [
          'Read a book',
          'Watch a movie',
          'Listen to calming music',
          'Take a nap',
          'Meditate for 15 minutes',
          'Do a jigsaw puzzle',
          'Have a warm bath',
          'Write in a journal',
          'Try a new tea variety',
          'Browse art online',
          'Call an old friend',
          'Practice deep breathing',
          'Stretch gently',
          'Listen to a podcast',
          'Create a cozy corner',
          'Try adult coloring books',
          'Write a letter',
          'Make a warm drink',
          'Look through old photos',
          'Practice mindfulness',
          'Read poetry',
          'Make a scrapbook',
          'Take a tech-free hour',
          'Try aromatherapy',
          'Watch the sunset',
        ],
        'Energetic': [
          'Do a home workout',
          'Dance to upbeat music',
          'Try an online fitness class',
          'Do jumping jacks for 2 minutes',
          'Create an indoor obstacle course',
          'Follow a HIIT workout video',
          'Do a plank challenge',
          'Indoor jump rope',
          'Try shadow boxing',
          'Dance like nobody is watching',
          'Practice yoga',
          'Do bodyweight exercises',
          'Have a solo dance party',
          'Try an indoor cardio routine',
          'Rearrange your furniture',
          'Clean your living space',
          'Do a speed cleaning challenge',
          'Practice kickboxing moves',
          'Play an active video game',
          'Try a stair workout',
        ],
        'Productive': [
          'Learn a new skill online',
          'Organize your digital files',
          'Deep clean a room',
          'Start a personal project',
          'Create a to-do list',
          'Declutter your closet',
          'Organize your bookshelf',
          'Take an online course',
          'Update your resume',
          'Meal prep for the week',
          'Create a budget',
          'Organize your photos',
          'Research something you are curious about',
          'Plan your goals for the month',
          'Back up your important files',
          'Write a blog post',
          'Read an educational book',
          'Fix something that is broken',
          'Learn a new language',
          'Create a vision board',
        ],
        'Creative': [
          'Draw or paint something',
          'Write a short story',
          'Try a new recipe',
          'Learn origami',
          'Start a DIY project',
          'Write a poem',
          'Create a playlist',
          'Design a digital art piece',
          'Start knitting or crocheting',
          'Try hand lettering',
          'Make homemade greeting cards',
          'Design a t-shirt',
          'Upcycle old items',
          'Create a photo collage',
          'Try food photography',
          'Make a dreamcatcher',
          'Create a digital slideshow',
          'Design a meme',
          'Write song lyrics',
          'Try blackout poetry',
        ],
        'Social': [
          'Host a virtual game night',
          'Start a book club',
          'Call a family member',
          'Message an old friend',
          'Join an online forum',
          'Have a video chat dinner',
          'Plan a future gathering',
          'Write postcards to friends',
          'Join a virtual meetup',
          'Create a group playlist',
          'Host a virtual movie night',
          'Play online multiplayer games',
          'Join a social media challenge',
          'Set up a virtual coffee date',
          'Host a virtual quiz night',
          'Join an online community class',
          'Create a group chat',
          'Participate in a forum discussion',
          'Organize a charity event',
          'Start a collaborative project',
        ],
      },
      'Outdoor': {
        'Relaxed': [
          'Take a leisurely walk',
          'Have a picnic in the park',
          'Sit and read outside',
          'Cloud watching',
          'Visit a botanical garden',
          'Feed birds in the park',
          'Find a quiet spot to journal',
          'Do gentle stretches outside',
          'Go stargazing',
          'Walk barefoot on grass',
          'Take outdoor photos',
          'Find a hammock spot',
          'Sit by a lake or river',
          'Practice outdoor meditation',
          'Find a quiet bench to people-watch',
          'Sketch landscapes',
          'Smell different flowers',
          'Look for wildlife',
          'Listen to nature sounds',
          'Watch the sunrise',
        ],
        'Energetic': [
          'Go for a run',
          'Ride a bike',
          'Try a trail run',
          'Play outdoor sports',
          'Go swimming',
          'Try rock climbing',
          'Parkour training',
          'Find outdoor gym equipment',
          'Go rollerblading',
          'Play frisbee',
          'Try outdoor HIIT',
          'Go kayaking',
          'Try paddleboarding',
          'Play tag with friends',
          'Outdoor yoga',
          'Try geocaching',
          'Go for a hike',
          'Outdoor bootcamp',
          'Play pickup basketball',
          'Try a new sport',
        ],
        'Productive': [
          'Garden work',
          'Clean your car',
          'Organize the garage',
          'Set up a compost system',
          'Clean the yard',
          'Wash windows',
          'Paint outdoor furniture',
          'Clear gutters',
          'Fix outdoor items',
          'Start growing vegetables',
          'Prune plants',
          'Clean outdoor areas',
          'Build something outdoors',
          'Set up a bird feeder',
          'Repair garden tools',
          'Plan garden layout',
          'Pressure wash surfaces',
          'Organize outdoor storage',
          'Install outdoor lighting',
          'Set up a rain barrel',
        ],
        'Creative': [
          'Outdoor sketching',
          'Sidewalk chalk art',
          'Nature photography',
          'Land art with found items',
          'Build a sandcastle',
          'Outdoor flower arranging',
          'Stone stacking art',
          'Leaf rubbings art',
          'Paint landscapes',
          'Create a fairy garden',
          'Natural dyeing with plants',
          'Design a garden layout',
          'Take macro photos of flowers',
          'Create a nature mandala',
          'Cloud photography',
          'Make a pinecone wreath',
          'Shoot a short outdoor film',
          'Create a natural sculpture',
          'Try plein air painting',
          'Collect interesting pebbles',
        ],
        'Social': [
          'Meet a friend for coffee',
          'Outdoor yoga class',
          'Join a running group',
          'Play team sports',
          'Volunteer outdoors',
          'Join a hiking group',
          'Have a BBQ with friends',
          'Attend an outdoor event',
          'Go to a farmers market',
          'Join a community garden',
          'Visit a dog park',
          'Attend an outdoor concert',
          'Join a walking tour',
          'Attend an outdoor class',
          'Play outdoor games with friends',
          'Join a bird watching group',
          'Attend a street festival',
          'Join a cycling group',
          'Visit a community center',
          'Play tennis with a friend',
        ],
      },
      'Hybrid': {
        'Relaxed': [
          'Listen to music in a park',
          'Read in a coffee shop',
          'Journal at a cafe',
          'Gentle yoga (indoors or out)',
          'Meditation anywhere',
          'Listen to audiobooks',
          'Sit in a botanical garden',
          'Drink tea on the balcony',
          'Watch videos in a garden',
          'Read outside or in',
          'Stretching routine anywhere',
          'Phone call with a friend',
          'Light walking indoors or out',
          'Breathing exercises',
          'Listen to a podcast anywhere',
          'Mindfulness practice',
          'Star/cloud gazing (app or real)',
          'Drawing or coloring',
          'Listen to nature sounds recordings',
          'Write poetry anywhere',
        ],
        'Energetic': [
          'Follow workout videos (indoor/outdoor)',
          'HIIT workouts anywhere',
          'Dancing (inside or at park)',
          'Jump rope routine',
          'Running (treadmill or outside)',
          'Bodyweight workouts',
          'Stair climbing',
          'Fitness challenge',
          'Sports training drills',
          'Exercise to a playlist',
          'Skateboarding',
          'Kickboxing practice',
          'Training with fitness apps',
          'Split workouts (indoor/outdoor)',
          'Tabata workouts',
          'Animal movement exercises',
          'Speed walking',
          'Circuit training',
          'Plyometric exercises',
          'Portable equipment workout',
        ],
        'Productive': [
          'Mobile work at a cafe',
          'Podcasts while walking',
          'Learn new skills via app',
          'Audiobooks during commute',
          'Plan tasks in a park',
          'Clean indoor & outdoor spaces',
          'Organize digital files anywhere',
          'Job applications from anywhere',
          'Home maintenance checklist',
          'Manage finance apps',
          'Research topics of interest',
          'Remote work from anywhere',
          'Set goals at a coffee shop',
          'Plan trips while traveling',
          'Study in different locations',
          'Audio learning while exercising',
          'Multi-location productivity',
          'Video meetings from anywhere',
          'Email management',
          'Task batching anywhere',
        ],
        'Creative': [
          'Photography (any location)',
          'Drawing indoors or in nature',
          'Digital art anywhere',
          'Write stories on the go',
          'Craft projects (portable)',
          'Design ideas in various settings',
          'Video content creation',
          'Mobile music production',
          'Sing or play an instrument anywhere',
          'Creative writing prompts',
          'Practice dance moves',
          'Design clothing ideas',
          'Plan art projects',
          'Sketch people/scenes',
          'Take creative photos',
          'Mix music playlists',
          'Create social media content',
          'Plan DIY projects',
          'Write in different locations',
          'Practice photographic techniques',
        ],
        'Social': [
          'Meet friends (flexible location)',
          'Video calls from anywhere',
          'Social media engagement',
          'Group chats while mobile',
          'Join online/in-person groups',
          'Coffee dates (in-person/virtual)',
          'Multiplayer games anywhere',
          'Group fitness (in-person/online)',
          'Co-working sessions',
          'Book clubs (virtual/in-person)',
          'Language exchange meetups',
          'Social dining experiences',
          'Board games anywhere',
          'Networking events',
          'Collaborative projects',
          'Group walks with calls',
          'Virtual/in-person workshops',
          'Outdoor/indoor social gatherings',
          'Team challenges anywhere',
          'Plan social events',
        ],
      },
    };
  }
  
  // Get default suggestions if no matches
  List<String> _getDefaultSuggestions() {
    return [
      'Take a walk',
      'Read a book',
      'Call a friend',
      'Listen to music',
      'Try meditation',
      'Cook a new recipe',
      'Go for a bike ride',
      'Watch a documentary',
      'Take photos',
      'Write in a journal',
      'Try a new hobby',
      'Visit a local attraction',
      'Do a workout',
      'Plan your week',
      'Learn something new online',
      'Go to a coffee shop',
      'Clean your space',
      'Visit a museum',
      'Try a puzzle',
      'Have a picnic',
      'Go window shopping',
      'Watch the sunset',
      'Video chat with family',
      'Try gardening',
      'Draw or paint',
      'Listen to a podcast',
      'Visit a bookstore',
      'Play a board game',
      'Try yoga',
      'Go to a park',
      'Watch a classic movie',
      'Listen to a new album',
      'Bake something sweet',
      'Volunteer locally',
      'Try a new restaurant',
      'Visit a farmers market',
      'Plant something',
      'Go stargazing',
      'Start a blog',
      'Make a vision board',
    ];
  }
  
  // Get suggestion details
  Map<String, String> getSuggestionDetails(String suggestion) {
    // Basic implementation - could be expanded with a database
    final Map<String, String> details = {
      'description': 'A great way to spend your time!',
      'benefits': 'Can help you relax and enjoy the moment.',
      'tips': 'Start small and work your way up.',
    };
    
    // Customize based on keywords in suggestion
    final lower = suggestion.toLowerCase();
    
    if (lower.contains('read')) {
      details['description'] = 'Immerse yourself in a good book.';
      details['benefits'] = 'Reading improves focus, reduces stress, and expands your vocabulary.';
      details['tips'] = 'Try setting aside 20-30 minutes of uninterrupted reading time.';
    } else if (lower.contains('walk')) {
      details['description'] = 'Enjoy the outdoors with a refreshing walk.';
      details['benefits'] = 'Walking boosts your mood, improves cardiovascular health, and helps clear your mind.';
      details['tips'] = 'Try a new route or bring a friend along for company.';
    } else if (lower.contains('meditat')) {
      details['description'] = 'Take time to calm your mind through meditation.';
      details['benefits'] = 'Meditation reduces stress, improves concentration, and promotes emotional health.';
      details['tips'] = 'Start with just 5 minutes of focused breathing in a quiet space.';
    } else if (lower.contains('cook') || lower.contains('recipe') || lower.contains('bake')) {
      details['description'] = 'Create something delicious in the kitchen.';
      details['benefits'] = 'Cooking is creative, satisfying, and results in a tasty reward for your efforts.';
      details['tips'] = 'Try a recipe slightly outside your comfort zone to build new skills.';
    } else if (lower.contains('journal') || lower.contains('write')) {
      details['description'] = 'Express your thoughts and feelings through writing.';
      details['benefits'] = 'Journaling can reduce stress, improve mood, and help process emotions.';
      details['tips'] = 'Do not worry about perfect writing - just let your thoughts flow freely.';
    } else if (lower.contains('run') || lower.contains('jog')) {
      details['description'] = 'Get your heart pumping with a run or jog.';
      details['benefits'] = 'Running improves cardiovascular health, builds endurance, and releases endorphins.';
      details['tips'] = 'Start with intervals of running and walking if you are a beginner.';
    } else if (lower.contains('yoga') || lower.contains('stretch')) {
      details['description'] = 'Move your body with mindful yoga or stretching.';
      details['benefits'] = 'Improves flexibility, balance, strength, and can reduce stress.';
      details['tips'] = 'Follow along with a beginner-friendly video if you are new to yoga.';
    } else if (lower.contains('clean') || lower.contains('organize')) {
      details['description'] = 'Create a more pleasant environment by cleaning or organizing.';
      details['benefits'] = 'A tidy space can reduce stress and increase productivity.';
      details['tips'] = 'Focus on one small area at a time rather than trying to do everything at once.';
    } else if (lower.contains('friend') || lower.contains('call') || lower.contains('chat')) {
      details['description'] = 'Connect with others through conversation.';
      details['benefits'] = 'Social connections boost mood and provide emotional support.';
      details['tips'] = 'Ask open-ended questions to have deeper conversations.';
    } else if (lower.contains('music') || lower.contains('listen')) {
      details['description'] = 'Enjoy your favorite tunes or discover new music.';
      details['benefits'] = 'Music can improve mood, reduce stress, and boost cognitive performance.';
      details['tips'] = 'Create different playlists for various moods or activities.';
    }
    
    return details;
  }
  
  // Get icon for suggestion
  IconData getIconForSuggestion(String suggestion) {
    final lower = suggestion.toLowerCase();
    
    if (lower.contains('read')) return Icons.book;
    if (lower.contains('walk') || lower.contains('hike')) return Icons.directions_walk;
    if (lower.contains('run')) return Icons.directions_run;
    if (lower.contains('meditat') || lower.contains('yoga')) return Icons.self_improvement;
    if (lower.contains('cook') || lower.contains('bake') || lower.contains('recipe')) return Icons.restaurant;
    if (lower.contains('music') || lower.contains('listen')) return Icons.music_note;
    if (lower.contains('movie') || lower.contains('watch')) return Icons.movie;
    if (lower.contains('call') || lower.contains('friend')) return Icons.phone;
    if (lower.contains('game')) return Icons.sports_esports;
    if (lower.contains('art') || lower.contains('draw') || lower.contains('paint')) return Icons.palette;
    if (lower.contains('bike')) return Icons.pedal_bike;
    if (lower.contains('swim')) return Icons.pool;
    if (lower.contains('garden')) return Icons.yard;
    if (lower.contains('clean') || lower.contains('organize')) return Icons.cleaning_services;
    if (lower.contains('workout') || lower.contains('exercise')) return Icons.fitness_center;
    if (lower.contains('photo')) return Icons.photo_camera;
    if (lower.contains('write') || lower.contains('journal')) return Icons.edit;
    if (lower.contains('coffee')) return Icons.coffee;
    if (lower.contains('shop')) return Icons.shopping_bag;
    if (lower.contains('puzzle')) return Icons.extension;
    if (lower.contains('picnic')) return Icons.lunch_dining;
    if (lower.contains('park')) return Icons.park;
    if (lower.contains('podcast')) return Icons.headphones;
    if (lower.contains('museum') || lower.contains('art')) return Icons.museum;
    if (lower.contains('dance')) return Icons.nightlife;
    if (lower.contains('sleep') || lower.contains('nap')) return Icons.bedtime;
    if (lower.contains('video') || lower.contains('chat')) return Icons.video_call;
    if (lower.contains('sunset') || lower.contains('sunrise')) return Icons.wb_twilight;
    if (lower.contains('star')) return Icons.stars;
    
    // Default icon
    return Icons.emoji_objects;
  }
}