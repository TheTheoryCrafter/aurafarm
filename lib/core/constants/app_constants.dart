class AppConstants {
  AppConstants._();

  // Face recognition
  static const double recognitionThreshold = 0.7;
  static const double recognitionMargin = 0.08; // best match must beat runner-up by this much
  static const int requiredConsecutiveMatches = 3; // consecutive frames before switching person
  static const int frameThrottle = 10; // process every Nth frame
  static const int faceCaptures = 5;   // captures per registration
  static const int lossTimeoutMs = 2000; // ms before dismissing recognition badge

  // Audio
  static const int minSnippetMs = 2000;
  static const int maxSnippetMs = 30000;
  static const int defaultSnippetMs = 10000;

  // UI
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
  static const double pagePadding = 20.0;

  // Storage keys
  static const String peopleFileName = 'people.json';
}
