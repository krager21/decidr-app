import 'package:flutter/material.dart';

/// A place category we know how to query in OpenStreetMap via the
/// Overpass API. Each variant carries a human label plus the OSM tag
/// expression used to fetch it (`amenity=cafe`, `leisure=park`, etc).
///
/// Categories are intentionally a fixed, type-safe set rather than
/// free-form strings — the interest-to-category map and the OSM query
/// builder both lean on the exhaustive switch.
enum PlaceCategory {
  cafe('Cafe', 'amenity', 'cafe'),
  restaurant('Restaurant', 'amenity', 'restaurant'),
  bar('Bar', 'amenity', 'bar'),
  pub('Pub', 'amenity', 'pub'),
  park('Park', 'leisure', 'park'),
  garden('Garden', 'leisure', 'garden'),
  playground('Playground', 'leisure', 'playground'),
  viewpoint('Viewpoint', 'tourism', 'viewpoint'),
  library('Library', 'amenity', 'library'),
  bookstore('Bookstore', 'shop', 'books'),
  museum('Museum', 'tourism', 'museum'),
  gallery('Gallery', 'tourism', 'gallery'),
  musicVenue('Music venue', 'amenity', 'music_venue'),
  theatre('Theatre', 'amenity', 'theatre'),
  cinema('Cinema', 'amenity', 'cinema'),
  gym('Gym', 'leisure', 'fitness_centre'),
  sportsCentre('Sports centre', 'leisure', 'sports_centre'),
  swimmingPool('Swimming pool', 'leisure', 'swimming_pool'),
  ;

  /// Human-readable label shown in the bottom sheet group headers.
  final String label;

  /// OSM tag key — typically `amenity`, `leisure`, `tourism`, or `shop`.
  final String osmKey;

  /// OSM tag value — e.g. `cafe`, `park`, `museum`.
  final String osmValue;

  const PlaceCategory(this.label, this.osmKey, this.osmValue);

  /// Material icon for this category. Kept as a method (not a
  /// constructor field) so Flutter's icon tree-shaker can statically
  /// prove which icons are referenced.
  IconData get icon {
    switch (this) {
      case PlaceCategory.cafe:
        return Icons.local_cafe;
      case PlaceCategory.restaurant:
        return Icons.restaurant;
      case PlaceCategory.bar:
        return Icons.local_bar;
      case PlaceCategory.pub:
        return Icons.sports_bar;
      case PlaceCategory.park:
        return Icons.park;
      case PlaceCategory.garden:
        return Icons.local_florist;
      case PlaceCategory.playground:
        return Icons.child_friendly;
      case PlaceCategory.viewpoint:
        return Icons.landscape;
      case PlaceCategory.library:
        return Icons.local_library;
      case PlaceCategory.bookstore:
        return Icons.menu_book;
      case PlaceCategory.museum:
        return Icons.museum;
      case PlaceCategory.gallery:
        return Icons.brush;
      case PlaceCategory.musicVenue:
        return Icons.music_note;
      case PlaceCategory.theatre:
        return Icons.theater_comedy;
      case PlaceCategory.cinema:
        return Icons.movie;
      case PlaceCategory.gym:
        return Icons.fitness_center;
      case PlaceCategory.sportsCentre:
        return Icons.sports_handball;
      case PlaceCategory.swimmingPool:
        return Icons.pool;
    }
  }
}
