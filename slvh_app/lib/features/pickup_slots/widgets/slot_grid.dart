import 'package:flutter/material.dart';
import 'package:slvh_app/features/pickup_slots/models/slot_model.dart';

/// Widget to display pickup time slots in a grid
class SlotGrid extends StatelessWidget {
  final List<PickupSlotModel> slots;
  final PickupSlotModel? selectedSlot;
  final Function(PickupSlotModel)? onSlotSelected;
  final bool isLoading;

  const SlotGrid({
    Key? key,
    required this.slots,
    this.selectedSlot,
    this.onSlotSelected,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading available slots...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    if (slots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_outlined,
                  size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No slots available',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Shop is closed or all slots are full',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isSelected = selectedSlot?.id == slot.id;

        return _SlotButton(
          slot: slot,
          isSelected: isSelected,
          onTap: onSlotSelected != null ? () => onSlotSelected!(slot) : null,
        );
      },
    );
  }
}

/// Individual slot button
class _SlotButton extends StatelessWidget {
  final PickupSlotModel slot;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SlotButton({
    required this.slot,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = slot.isFull();

    return GestureDetector(
      onTap: isFull ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Colors.orange[700]!
                : isFull
                    ? Colors.grey[400]!
                    : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? Colors.orange[50]
              : isFull
                  ? Colors.grey[100]
                  : Colors.white,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isFull ? null : onTap,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Time
                Text(
                  slot.getDisplayTime(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isFull
                            ? Colors.grey[500]
                            : isSelected
                                ? Colors.orange[700]
                                : Colors.black,
                      ),
                ),
                const SizedBox(height: 4),

                // Capacity indicator
                Text(
                  '${slot.getRemainingCapacity()}/${slot.slotCapacity}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 4),

                // Status
                if (isFull)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'FULL',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'OPEN',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact horizontal slot list (scrollable)
class SlotListHorizontal extends StatelessWidget {
  final List<PickupSlotModel> slots;
  final PickupSlotModel? selectedSlot;
  final Function(PickupSlotModel)? onSlotSelected;

  const SlotListHorizontal({
    Key? key,
    required this.slots,
    this.selectedSlot,
    this.onSlotSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No available slots',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      );
    }

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: slots.length,
        itemBuilder: (context, index) {
          final slot = slots[index];
          final isSelected = selectedSlot?.id == slot.id;
          final isFull = slot.isFull();

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: isFull ? null : () => onSlotSelected?.call(slot),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? Colors.orange[700]!
                        : isFull
                            ? Colors.grey[400]!
                            : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected
                      ? Colors.orange[50]
                      : isFull
                          ? Colors.grey[100]
                          : Colors.white,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      slot.getDisplayTime(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isFull
                                ? Colors.grey[500]
                                : isSelected
                                    ? Colors.orange[700]
                                    : Colors.black,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${slot.getRemainingCapacity()} slots',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
    );
  }
}
