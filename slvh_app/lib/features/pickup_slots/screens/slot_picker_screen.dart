import 'package:flutter/material.dart';
import 'package:slvh_app/features/pickup_slots/models/slot_model.dart';
import 'package:slvh_app/features/pickup_slots/services/slot_service.dart';
import 'package:slvh_app/features/pickup_slots/widgets/slot_grid.dart';
import '../../../core/utils/secure_logger.dart';

/// Screen for selecting pickup date and time slot
class SlotPickerScreen extends StatefulWidget {
  final Function(DateTime date, PickupSlotModel slot)? onSlotSelected;

  const SlotPickerScreen({
    Key? key,
    this.onSlotSelected,
  }) : super(key: key);

  @override
  State<SlotPickerScreen> createState() => _SlotPickerScreenState();
}

class _SlotPickerScreenState extends State<SlotPickerScreen> {
  late final SlotService _slotService;
  late ShopSettingsModel _settings;
  late List<DateTime> _availableDates;

  DateTime? _selectedDate;
  PickupSlotModel? _selectedSlot;
  List<PickupSlotModel>? _slotsForSelectedDate;
  bool _isLoadingSettings = true;
  bool _isLoadingSlots = false;

  @override
  void initState() {
    super.initState();
    _slotService = SlotService();
    _initializeSettings();
  }

  /// Initialize shop settings and available dates
  Future<void> _initializeSettings() async {
    try {
      _settings = await _slotService.getShopSettings();

      // Set first available date as selected
      _availableDates = _slotService.getAvailableDates(daysToShow: 7);
      _selectedDate = _availableDates.first;

      setState(() {
        _isLoadingSettings = false;
      });

      // Load slots for first date
      await _loadSlotsForDate(_selectedDate!);
    } catch (e) {
      AppLogger.debug('Error initializing: $e');
      setState(() {
        _isLoadingSettings = false;
      });
    }
  }

  /// Load slots for selected date
  Future<void> _loadSlotsForDate(DateTime date) async {
    setState(() {
      _isLoadingSlots = true;
      _selectedSlot = null;
      _slotsForSelectedDate = null;
    });

    try {
      final slots =
          await _slotService.getAvailableSlotsForDate(date, _settings);
      setState(() {
        _slotsForSelectedDate = slots;
        _isLoadingSlots = false;
      });
    } catch (e) {
      AppLogger.debug('Error loading slots: $e');
      setState(() {
        _isLoadingSlots = false;
        _slotsForSelectedDate = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Pickup Time'),
        backgroundColor: Colors.orange[700],
        elevation: 0,
      ),
      body: _isLoadingSettings
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Shop info card
                  _buildShopInfoCard(context),

                  // Date selector
                  _buildDateSelector(context),

                  // Time slots
                  if (_selectedDate != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Times',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getDateDisplay(_selectedDate!),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SlotGrid(
                        slots: _slotsForSelectedDate ?? [],
                        selectedSlot: _selectedSlot,
                        isLoading: _isLoadingSlots,
                        onSlotSelected: (slot) {
                          setState(() {
                            _selectedSlot = slot;
                          });
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Selection summary and button
                  _buildSelectionSummary(context),

                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  /// Build shop info card
  Widget _buildShopInfoCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: Colors.orange[700], size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shop Hours',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange[700],
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_settings.openTime.toString().padLeft(2, '0')}:00 - ${_settings.closeTime.toString().padLeft(2, '0')}:00',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                ),
              ],
            ),
          ),
          if (_settings.isHolidayMode)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'CLOSED',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build date selector
  Widget _buildDateSelector(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Date',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableDates.length,
              itemBuilder: (context, index) {
                final date = _availableDates[index];
                final isSelected = _selectedDate?.day == date.day &&
                    _selectedDate?.month == date.month;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () async {
                      setState(() {
                        _selectedDate = date;
                      });
                      await _loadSlotsForDate(date);
                    },
                    child: Container(
                      width: 80,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? Colors.orange[700]!
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: isSelected ? Colors.orange[50] : Colors.white,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getWeekDay(date),
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            date.day.toString(),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.orange[700]
                                      : Colors.black,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getMonth(date),
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build selection summary and confirm button
  Widget _buildSelectionSummary(BuildContext context) {
    final hasSelection = _selectedDate != null && _selectedSlot != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          // Selected info
          if (hasSelection)
            Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pickup Scheduled',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_getDateDisplay(_selectedDate!)} at ${_selectedSlot!.getDisplayTime()}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Please select a date and time slot',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: hasSelection
                  ? () {
                      if (widget.onSlotSelected != null) {
                        widget.onSlotSelected!(_selectedDate!, _selectedSlot!);
                      }
                      Navigator.pop(context, {
                        'date': _selectedDate,
                        'slot': _selectedSlot,
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                disabledBackgroundColor: Colors.grey[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Confirm Pickup Time',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods

  String _getWeekDay(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String _getMonth(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[date.month - 1];
  }

  String _getDateDisplay(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}


