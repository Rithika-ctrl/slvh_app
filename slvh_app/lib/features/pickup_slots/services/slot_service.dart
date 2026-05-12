import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:slvh_app/features/pickup_slots/models/slot_model.dart';

/// Service for managing pickup slot scheduling
/// Handles slot creation, booking, and capacity management with Firestore transactions
class SlotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _settingsCollection = 'settings';
  static const String _slotsCollection = 'slots';
  static const String _defaultSettingsDoc = 'default';

  /// Get shop settings
  Future<ShopSettingsModel> getShopSettings() async {
    try {
      final doc = await _firestore
          .collection(_settingsCollection)
          .doc(_defaultSettingsDoc)
          .get();

      if (!doc.exists) {
        // Return default settings if not found
        return ShopSettingsModel();
      }

      return ShopSettingsModel.fromFirestore(doc.id, doc.data()!);
    } catch (e) {
      print('Error fetching shop settings: $e');
      return ShopSettingsModel(); // Return defaults
    }
  }

  /// Watch shop settings in real-time
  Stream<ShopSettingsModel> watchShopSettings() {
    return _firestore
        .collection(_settingsCollection)
        .doc(_defaultSettingsDoc)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return ShopSettingsModel();
          return ShopSettingsModel.fromFirestore(doc.id, doc.data()!);
        })
        .handleError((e) {
          print('Error watching shop settings: $e');
          return ShopSettingsModel();
        });
  }

  /// Update shop settings (admin only)
  Future<void> updateShopSettings(ShopSettingsModel settings) async {
    try {
      await _firestore
          .collection(_settingsCollection)
          .doc(_defaultSettingsDoc)
          .set({
            ...settings.toFirestore(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      print('✅ Shop settings updated');
    } catch (e) {
      print('Error updating shop settings: $e');
      rethrow;
    }
  }

  /// Generate available slots for a specific date
  /// This creates time slots if they don't exist
  Future<List<PickupSlotModel>> generateSlotsForDate(
    DateTime date,
    ShopSettingsModel settings,
  ) async {
    try {
      final dateStr = _formatDate(date);
      final slotsRef = _firestore
          .collection(_slotsCollection)
          .doc(dateStr)
          .collection('times');

      // Check if slots already exist for this date
      final snapshot = await slotsRef.get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => PickupSlotModel.fromFirestore(doc.id, doc.data()))
            .toList()
          ..sort((a, b) {
            final timeA = a.hour * 60 + a.minute;
            final timeB = b.hour * 60 + b.minute;
            return timeA.compareTo(timeB);
          });
      }

      // Generate new slots
      final slots = <PickupSlotModel>[];
      final now = DateTime.now();
      final isToday = _isSameDay(date, now);

      // Calculate start hour
      int startHour = settings.pickupStartTime;
      if (isToday) {
        // If today, account for delay_hours
        final earliestHour = now.hour + settings.delayHours;
        startHour = earliestHour > startHour ? earliestHour : startHour;
      }

      // Generate slots from startHour to closeTime
      for (int hour = startHour; hour < settings.closeTime; hour++) {
        for (int minute = 0;
            minute < 60;
            minute += settings.slotDurationMinutes) {
          // Skip if it's today and this time has passed
          if (isToday) {
            final slotDateTime = DateTime(date.year, date.month, date.day, hour, minute);
            if (slotDateTime.isBefore(now)) continue;
          }

          final slotId = '$hour-$minute';
          final slot = PickupSlotModel(
            id: slotId,
            date: dateStr,
            hour: hour,
            minute: minute,
            slotCapacity: settings.slotCapacity,
            bookingCount: 0,
          );

          slots.add(slot);

          // Save to Firestore
          await slotsRef.doc(slotId).set(slot.toFirestore());
        }
      }

      print('✅ Generated ${slots.length} slots for $dateStr');
      return slots;
    } catch (e) {
      print('Error generating slots: $e');
      return [];
    }
  }

  /// Get available slots for a date
  Future<List<PickupSlotModel>> getAvailableSlotsForDate(
    DateTime date,
    ShopSettingsModel settings,
  ) async {
    try {
      // Check if date is closed
      if (_isDateClosed(date, settings)) {
        return [];
      }

      final dateStr = _formatDate(date);
      final snapshot = await _firestore
          .collection(_slotsCollection)
          .doc(dateStr)
          .collection('times')
          .get();

      if (snapshot.docs.isEmpty) {
        // Generate slots if they don't exist
        return await generateSlotsForDate(date, settings);
      }

      final slots = snapshot.docs
          .map((doc) => PickupSlotModel.fromFirestore(doc.id, doc.data()))
          .toList();

      // Filter available slots
      final availableSlots = slots.where((slot) => slot.isAvailable()).toList();

      // Sort by time
      availableSlots.sort((a, b) {
        final timeA = a.hour * 60 + a.minute;
        final timeB = b.hour * 60 + b.minute;
        return timeA.compareTo(timeB);
      });

      return availableSlots;
    } catch (e) {
      print('Error fetching available slots: $e');
      return [];
    }
  }

  /// Get all slots for a date (including full ones)
  Future<List<PickupSlotModel>> getAllSlotsForDate(DateTime date) async {
    try {
      final dateStr = _formatDate(date);
      final snapshot = await _firestore
          .collection(_slotsCollection)
          .doc(dateStr)
          .collection('times')
          .orderBy('hour')
          .orderBy('minute')
          .get();

      return snapshot.docs
          .map((doc) => PickupSlotModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching all slots: $e');
      return [];
    }
  }

  /// Book a slot using Firestore transaction (prevents double-booking)
  Future<bool> bookSlot(
    DateTime date,
    PickupSlotModel slot,
  ) async {
    return bookSlotById(date, slot.id);
  }

  /// Book a slot by ID using Firestore transaction
  Future<bool> bookSlotById(
    DateTime date,
    String slotId,
  ) async {
    try {
      final dateStr = _formatDate(date);
      final slotRef = _firestore
          .collection(_slotsCollection)
          .doc(dateStr)
          .collection('times')
          .doc(slotId);

      // Use transaction for atomic operation
      final result = await _firestore.runTransaction((transaction) async {
        // Get current slot state
        final slotDoc = await transaction.get(slotRef);

        if (!slotDoc.exists) {
          throw Exception('Slot not found');
        }

        final currentSlot = PickupSlotModel.fromFirestore(
          slotDoc.id,
          slotDoc.data()!,
        );

        // Check if slot is still available
        if (currentSlot.isFull()) {
          return false; // Slot is full
        }

        // Increment booking count
        transaction.update(slotRef, {
          'bookingCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true; // Successfully booked
      });

      if (result) {
        print('✅ Slot booked: $slotId');
      } else {
        print('❌ Slot is full: $slotId');
      }

      return result;
    } catch (e) {
      print('Error booking slot: $e');
      return false;
    }
  }

  /// Cancel a slot booking (decrement count)
  Future<bool> cancelSlotBooking(DateTime date, String slotId) async {
    try {
      final dateStr = _formatDate(date);
      final slotRef = _firestore
          .collection(_slotsCollection)
          .doc(dateStr)
          .collection('times')
          .doc(slotId);

      await _firestore.runTransaction((transaction) async {
        final slotDoc = await transaction.get(slotRef);

        if (!slotDoc.exists) {
          throw Exception('Slot not found');
        }

        final currentCount = slotDoc['bookingCount'] as int? ?? 0;
        final newCount = (currentCount - 1).clamp(0, double.infinity).toInt();

        transaction.update(slotRef, {
          'bookingCount': newCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      print('✅ Slot booking cancelled');
      return true;
    } catch (e) {
      print('Error cancelling booking: $e');
      return false;
    }
  }

  /// Get earliest available slot starting from today
  Future<PickupSlotModel?> getEarliestAvailableSlot(
    ShopSettingsModel settings,
  ) async {
    try {
      var checkDate = DateTime.now();

      // Try next 7 days
      for (int i = 0; i < 7; i++) {
        final slots = await getAvailableSlotsForDate(checkDate, settings);
        if (slots.isNotEmpty) {
          return slots.first; // First available is earliest
        }
        checkDate = checkDate.add(const Duration(days: 1));
      }

      return null; // No available slots in next 7 days
    } catch (e) {
      print('Error getting earliest slot: $e');
      return null;
    }
  }

  /// Delete slots for a date (admin cleanup)
  Future<void> deleteSlotsForDate(DateTime date) async {
    try {
      final dateStr = _formatDate(date);
      final batch = _firestore.batch();

      final snapshot = await _firestore
          .collection(_slotsCollection)
          .doc(dateStr)
          .collection('times')
          .get();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete date document if empty
      batch.delete(_firestore
          .collection(_slotsCollection)
          .doc(dateStr));

      await batch.commit();
      print('✅ Slots deleted for $dateStr');
    } catch (e) {
      print('Error deleting slots: $e');
      rethrow;
    }
  }

  // Helper methods

  /// Format date to YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Check if a date is closed
  bool _isDateClosed(DateTime date, ShopSettingsModel settings) {
    if (settings.isHolidayMode) return true;

    final dateStr = _formatDate(date);
    return settings.closedDates?.contains(dateStr) ?? false;
  }

  /// Get list of dates to show in date picker
  List<DateTime> getAvailableDates({int daysToShow = 7}) {
    final dates = <DateTime>[];
    var currentDate = DateTime.now();

    for (int i = 0; i < daysToShow; i++) {
      dates.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return dates;
  }
}
