/// Unit Type Helper
///
/// Provides constants and utilities for product unit types.
/// Maps unit labels to human-readable display names.

class UnitType {
  // Common unit types
  static const String kilogram = 'kg';
  static const String gram = 'g';
  static const String piece = 'piece';
  static const String pieces = 'pieces';
  static const String litre = 'litre';
  static const String millilitre = 'ml';
  static const String dozen = 'dozen';
  static const String packet = 'packet';
  static const String box = 'box';
  static const String bottle = 'bottle';
  static const String can = 'can';
  static const String pack = 'pack';

  /// Get display name for a unit label
  /// e.g., 'kg' -> 'KG', 'piece' -> 'Piece'
  static String getDisplayName(String unitLabel) {
    final label = unitLabel.trim().toLowerCase();
    
    const unitDisplayNames = {
      'kg': 'KG',
      'kilogram': 'KG',
      'g': 'g',
      'gram': 'g',
      'piece': 'Piece',
      'pieces': 'Pieces',
      'pcs': 'Pcs',
      'litre': 'Litre',
      'liter': 'Litre',
      'l': 'L',
      'ml': 'ml',
      'millilitre': 'ml',
      'dozen': 'Dozen',
      'packet': 'Packet',
      'box': 'Box',
      'bottle': 'Bottle',
      'can': 'Can',
      'pack': 'Pack',
    };
    
    return unitDisplayNames[label] ?? label.toUpperCase();
  }

  /// Format quantity with unit label
  /// e.g., 5, 'kg' -> '5 KG'
  static String formatQuantityWithUnit(int quantity, String unitLabel) {
    if (unitLabel.isEmpty) {
      return quantity.toString();
    }
    return '$quantity ${getDisplayName(unitLabel)}';
  }

  /// Get all available unit types
  static const List<String> allUnits = [
    kilogram,
    gram,
    piece,
    pieces,
    litre,
    millilitre,
    dozen,
    packet,
    box,
    bottle,
    can,
    pack,
  ];
}
