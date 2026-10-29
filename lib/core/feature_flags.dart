/// Test-build switches. Flip a value to `true` to restore that UI entry
/// point — nothing else is required.
///
/// Only ENTRY POINTS (buttons, nav items, menu tiles) are gated behind these
/// flags. Providers, repositories, sheets/screens and backend calls are all
/// untouched, so re-enabling a flag brings the feature back fully working.
abstract class FeatureFlags {
  /// "Plan a Trip" / "Find Planned Trips" (driver + passenger).
  static const plannedTrips = false;

  /// Promotions: the passenger "Offers" nav tab and the
  /// "Promotions & Rewards" account tiles.
  static const promotions = false;

  /// AI matching toggle + "Test AI" tile in the account sheets.
  static const aiControls = false;

  /// The amber "Reconnecting…" state of the top status pill.
  /// The red "No internet" state is always shown regardless of this flag.
  static const reconnectingPill = false;
}
