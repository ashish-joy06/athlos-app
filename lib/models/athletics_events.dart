/// Central source of truth for Athletics events.
/// Add or remove events here and every screen picks them up automatically.
class AthleticsEvents {
  static const Map<String, List<String>> grouped = {
    'Track': [
      '100m',
      '200m',
      '400m',
      '800m',
      '1500m',
      '3000m',
      '5000m',
      '10000m',
      '10000m Walk',
      '110m Hurdles',
      '400m Hurdles',
    ],
    'Jump': [
      'Long Jump',
      'Triple Jump',
      'High Jump',
    ],
    'Throw': [
      'Shot Put',
      'Discus Throw',
      'Javelin Throw',
      'Hammer Throw',
    ],
  };

  /// Flat list of every event, useful for validation.
  static List<String> get all => grouped.values.expand((e) => e).toList();

  /// Maximum number of events a user can select.
  static const int maxSelection = 5;

  /// Gender options.
  static const List<String> genders = ['Male', 'Female'];
}