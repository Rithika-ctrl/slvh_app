/// Model for shop operating settings
class ShopSettingsModel {
  final String id;
  final int openTime; // Hour (0-23)
  final int closeTime; // Hour (0-23)
  final int pickupStartTime; // Hour when pickups can start
  final int delayHours; // Minimum hours before pickup available
  final int slotDurationMinutes; // Duration of each slot (e.g., 30)
  final int slotCapacity; // Max bookings per slot
  final bool isHolidayMode; // No slots available if true
  final List<String>? closedDates; // Dates when closed (YYYY-MM-DD format)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ShopSettingsModel({
    this.id = 'default',
    this.openTime = 9,
    this.closeTime = 21,
    this.pickupStartTime = 9,
    this.delayHours = 1,
    this.slotDurationMinutes = 30,
    this.slotCapacity = 5,
    this.isHolidayMode = false,
    this.closedDates,
    this.createdAt,
    this.updatedAt,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'openTime': openTime,
      'closeTime': closeTime,
      'pickupStartTime': pickupStartTime,
      'delayHours': delayHours,
      'slotDurationMinutes': slotDurationMinutes,
      'slotCapacity': slotCapacity,
      'isHolidayMode': isHolidayMode,
      'closedDates': closedDates ?? [],
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create from Firestore document
  factory ShopSettingsModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return ShopSettingsModel(
      id: id,
      openTime: data['openTime'] as int? ?? 9,
      closeTime: data['closeTime'] as int? ?? 21,
      pickupStartTime: data['pickupStartTime'] as int? ?? 9,
      delayHours: data['delayHours'] as int? ?? 1,
      slotDurationMinutes: data['slotDurationMinutes'] as int? ?? 30,
      slotCapacity: data['slotCapacity'] as int? ?? 5,
      isHolidayMode: data['isHolidayMode'] as bool? ?? false,
      closedDates: List<String>.from(data['closedDates'] ?? []),
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'].toString())
          : null,
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'].toString())
          : null,
    );
  }

  /// Create a copy with modifications
  ShopSettingsModel copyWith({
    String? id,
    int? openTime,
    int? closeTime,
    int? pickupStartTime,
    int? delayHours,
    int? slotDurationMinutes,
    int? slotCapacity,
    bool? isHolidayMode,
    List<String>? closedDates,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopSettingsModel(
      id: id ?? this.id,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      pickupStartTime: pickupStartTime ?? this.pickupStartTime,
      delayHours: delayHours ?? this.delayHours,
      slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
      slotCapacity: slotCapacity ?? this.slotCapacity,
      isHolidayMode: isHolidayMode ?? this.isHolidayMode,
      closedDates: closedDates ?? this.closedDates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'ShopSettingsModel(open: $openTime, close: $closeTime, delay: $delayHours hrs)';
}

/// Model for a pickup time slot
class PickupSlotModel {
  final String id;
  final String date; // YYYY-MM-DD format
  final int hour; // 0-23
  final int minute; // 0-59
  final int slotCapacity;
  late int bookingCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PickupSlotModel({
    required this.id,
    required this.date,
    required this.hour,
    required this.minute,
    required this.slotCapacity,
    this.bookingCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// Get display time (HH:MM format)
  String getDisplayTime() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Get full datetime for this slot
  DateTime getDateTime(DateTime baseDate) {
    return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
  }

  /// Check if slot is full
  bool isFull() {
    return bookingCount >= slotCapacity;
  }

  /// Check if slot is available
  bool isAvailable() {
    return !isFull();
  }

  /// Get remaining capacity
  int getRemainingCapacity() {
    return (slotCapacity - bookingCount).clamp(0, slotCapacity);
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'date': date,
      'hour': hour,
      'minute': minute,
      'slotCapacity': slotCapacity,
      'bookingCount': bookingCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create from Firestore document
  factory PickupSlotModel.fromFirestore(String id, Map<String, dynamic> data) {
    return PickupSlotModel(
      id: id,
      date: data['date'] ?? '',
      hour: data['hour'] ?? 0,
      minute: data['minute'] ?? 0,
      slotCapacity: data['slotCapacity'] ?? 5,
      bookingCount: data['bookingCount'] ?? 0,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'].toString())
          : null,
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'].toString())
          : null,
    );
  }

  /// Create a copy with modifications
  PickupSlotModel copyWith({
    String? id,
    String? date,
    int? hour,
    int? minute,
    int? slotCapacity,
    int? bookingCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PickupSlotModel(
      id: id ?? this.id,
      date: date ?? this.date,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      slotCapacity: slotCapacity ?? this.slotCapacity,
      bookingCount: bookingCount ?? this.bookingCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'PickupSlotModel($date ${getDisplayTime()}, $bookingCount/$slotCapacity)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PickupSlotModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date == other.date &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => id.hashCode ^ date.hashCode ^ hour.hashCode ^ minute.hashCode;
}
