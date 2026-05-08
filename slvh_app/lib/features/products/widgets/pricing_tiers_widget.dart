import 'package:flutter/material.dart';
import 'package:slvh_app/features/products/models/pricing_tier_model.dart';

/// Widget to display pricing tiers in a table format
/// Shows quantity, unit, price, and savings percentage
class PricingTiersWidget extends StatelessWidget {
  final List<PricingTierModel> tiers;
  final double basePrice;
  final String? bestValueTierId;
  final VoidCallback? onTierSelected;
  final bool isEditable;

  const PricingTiersWidget({
    Key? key,
    required this.tiers,
    required this.basePrice,
    this.bestValueTierId,
    this.onTierSelected,
    this.isEditable = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (tiers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No pricing tiers available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          horizontalMargin: 16,
          columnSpacing: 24,
          headingRowColor: MaterialStateColor.resolveWith(
            (states) => Colors.orange[50]!,
          ),
          headingRowHeight: 48,
          dataRowHeight: 56,
          columns: [
            DataColumn(
              label: Text(
                'Quantity',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
              ),
            ),
            DataColumn(
              label: Text(
                'Unit',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
              ),
            ),
            DataColumn(
              label: Text(
                'Price',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
              ),
            ),
            DataColumn(
              label: Text(
                'Per Unit',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
              ),
            ),
            DataColumn(
              label: Text(
                'Savings',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
              ),
            ),
          ],
          rows: tiers.map((tier) {
            final savings = tier.calculateSavings(basePrice);
            final isBestValue = tier.id == bestValueTierId;

            return DataRow(
              selected: isBestValue,
              color: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.green[50]!;
                }
                return Colors.transparent;
              }),
              onSelectChanged: isEditable
                  ? (_) => onTierSelected?.call()
                  : null,
              cells: [
                DataCell(
                  Text(
                    tier.quantity.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isBestValue ? FontWeight.bold : null,
                        ),
                  ),
                ),
                DataCell(
                  Text(
                    tier.unit,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isBestValue ? FontWeight.bold : null,
                        ),
                  ),
                ),
                DataCell(
                  Text(
                    '₹${tier.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                  ),
                ),
                DataCell(
                  Text(
                    '₹${tier.getPricePerUnit().toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ),
                DataCell(
                  savings > 0
                      ? Chip(
                          label: Text(
                            '${savings.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: isBestValue
                              ? Colors.green
                              : Colors.lightGreen[300],
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                        )
                      : Text(
                          'Base',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[500],
                          ),
                        ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Compact card view for pricing tiers
class PricingTierCard extends StatelessWidget {
  final PricingTierModel tier;
  final double basePrice;
  final bool isBestValue;
  final VoidCallback? onTap;

  const PricingTierCard({
    Key? key,
    required this.tier,
    required this.basePrice,
    this.isBestValue = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final savings = tier.calculateSavings(basePrice);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isBestValue ? Colors.green : Colors.grey[300]!,
            width: isBestValue ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isBestValue ? Colors.green[50] : Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${tier.quantity.toStringAsFixed(0)} ${tier.unit}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (isBestValue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Best Value',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Price
            Text(
              '₹${tier.price.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),

            // Per unit price
            Text(
              '₹${tier.getPricePerUnit().toStringAsFixed(2)}/unit',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),

            // Savings
            if (savings > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Save ${savings.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal scrollable pricing tiers list
class PricingTiersScroll extends StatelessWidget {
  final List<PricingTierModel> tiers;
  final double basePrice;
  final String? bestValueTierId;
  final Function(PricingTierModel)? onTierSelected;

  const PricingTiersScroll({
    Key? key,
    required this.tiers,
    required this.basePrice,
    this.bestValueTierId,
    this.onTierSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (tiers.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tiers.map((tier) {
          final isBestValue = tier.id == bestValueTierId;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 140,
              child: PricingTierCard(
                tier: tier,
                basePrice: basePrice,
                isBestValue: isBestValue,
                onTap: onTierSelected != null
                    ? () => onTierSelected!(tier)
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
