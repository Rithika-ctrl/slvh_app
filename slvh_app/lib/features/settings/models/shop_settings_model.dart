/// Model for shop operating & payment settings stored in
/// Firestore at: settings/default  (single document)
class ShopSettingsModel {
  final String id;

  // ── Operating hours ──────────────────────────────────────────
  final int openTime; // Hour (0-23)
  final int closeTime; // Hour (0-23)
  final int pickupStart; // Hour when pickups can begin (0-23)

  // ── Slot configuration ───────────────────────────────────────
  final int delayHours; // Min hours before pickup available
  final int slotDuration; // Duration per slot in minutes
  final int slotCapacity; // Max bookings per slot

  // ── Payment ──────────────────────────────────────────────────
  final String upiId; // UPI ID for payments
  final String upiQrImage; // URL / base64 of QR image

  // ── Operational toggles ──────────────────────────────────────
  final bool holidayMode; // No slots available when true
  final bool orderPause; // Pauses new orders when true

  // ── Inventory ────────────────────────────────────────────────
  final int lowStockThreshold; // Alert when stock <= this value

  final DateTime? updatedAt;

  const ShopSettingsModel({
    this.id = 'default',
    this.openTime = 9,
    this.closeTime = 21,
    this.pickupStart = 9,
    this.delayHours = 1,
    this.slotDuration = 30,
    this.slotCapacity = 5,
    this.upiId = '',
    this.upiQrImage = '',
    this.holidayMode = false,
    this.orderPause = false,
    this.lowStockThreshold = 5,
    this.updatedAt,
  });

  // ── Firestore serialisation ──────────────────────────────────

  Map<String, dynamic> toFirestore() => {
        'open_time': openTime,
        'close_time': closeTime,
        'pickup_start': pickupStart,
        'delay_hours': delayHours,
        'slot_duration': slotDuration,
        'slot_capacity': slotCapacity,
        'upi_id': upiId,
        'upi_qr_image': upiQrImage,
        'holiday_mode': holidayMode,
        'order_pause': orderPause,
        'low_stock_threshold': lowStockThreshold,
        // updatedAt is written by the service via FieldValue.serverTimestamp()
      };

  factory ShopSettingsModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) =>
      ShopSettingsModel(
        id: id,
        openTime: (data['open_time'] as num?)?.toInt() ?? 9,
        closeTime: (data['close_time'] as num?)?.toInt() ?? 21,
        pickupStart: (data['pickup_start'] as num?)?.toInt() ?? 9,
        delayHours: (data['delay_hours'] as num?)?.toInt() ?? 1,
        slotDuration: (data['slot_duration'] as num?)?.toInt() ?? 30,
        slotCapacity: (data['slot_capacity'] as num?)?.toInt() ?? 5,
        upiId: data['upi_id'] as String? ?? '',
        upiQrImage: data['upi_qr_image'] as String? ?? '',
        holidayMode: data['holiday_mode'] as bool? ?? false,
        orderPause: data['order_pause'] as bool? ?? false,
        lowStockThreshold: (data['low_stock_threshold'] as num?)?.toInt() ?? 5,
        updatedAt: data['updated_at'] != null
            ? (data['updated_at'] as dynamic).toDate()
            : null,
      );

  ShopSettingsModel copyWith({
    String? id,
    int? openTime,
    int? closeTime,
    int? pickupStart,
    int? delayHours,
    int? slotDuration,
    int? slotCapacity,
    String? upiId,
    String? upiQrImage,
    bool? holidayMode,
    bool? orderPause,
    int? lowStockThreshold,
    DateTime? updatedAt,
  }) =>
      ShopSettingsModel(
        id: id ?? this.id,
        openTime: openTime ?? this.openTime,
        closeTime: closeTime ?? this.closeTime,
        pickupStart: pickupStart ?? this.pickupStart,
        delayHours: delayHours ?? this.delayHours,
        slotDuration: slotDuration ?? this.slotDuration,
        slotCapacity: slotCapacity ?? this.slotCapacity,
        upiId: upiId ?? this.upiId,
        upiQrImage: upiQrImage ?? this.upiQrImage,
        holidayMode: holidayMode ?? this.holidayMode,
        orderPause: orderPause ?? this.orderPause,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  String toString() =>
      'ShopSettingsModel(open: $openTime–$closeTime, delay: ${delayHours}h, '
      'slot: ${slotDuration}min×$slotCapacity, holiday: $holidayMode, pause: $orderPause)';
}