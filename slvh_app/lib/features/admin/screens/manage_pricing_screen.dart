import 'package:flutter/material.dart';
import 'package:slvh_app/features/products/models/pricing_tier_model.dart';
import 'package:slvh_app/features/products/services/pricing_service.dart';

/// Admin screen to manage pricing tiers for a product
/// Allows adding, editing, deleting, and setting default pricing tiers
class ManagePricingScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final double basePrice;

  const ManagePricingScreen({
    Key? key,
    required this.productId,
    required this.productName,
    required this.basePrice,
  }) : super(key: key);

  @override
  State<ManagePricingScreen> createState() => _ManagePricingScreenState();
}

class _ManagePricingScreenState extends State<ManagePricingScreen> {
  late final PricingService _pricingService;

  @override
  void initState() {
    super.initState();
    _pricingService = PricingService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pricing Tiers - ${widget.productName}'),
        backgroundColor: Colors.orange[700],
        elevation: 0,
      ),
      body: StreamBuilder<List<PricingTierModel>>(
        stream: _pricingService.watchPricingTiers(widget.productId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final tiers = snapshot.data ?? [];

          return SingleChildScrollView(
            child: Column(
              children: [
                // Price info card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Base Price',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.orange[700],
                                  ),
                            ),
                            Text(
                              '₹${widget.basePrice.toStringAsFixed(2)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddTierDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Tier'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tiers list
                if (tiers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.layers_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No pricing tiers yet',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first pricing tier to enable bulk purchases',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tiers.length,
                    itemBuilder: (context, index) {
                      final tier = tiers[index];
                      final savings = tier.calculateSavings(widget.basePrice);

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: tier.isDefault
                                ? Colors.green[400]!
                                : Colors.grey[300]!,
                            width: tier.isDefault ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color:
                              tier.isDefault ? Colors.green[50] : Colors.white,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tier.quantity.toStringAsFixed(0),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                tier.unit,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${tier.price.toStringAsFixed(2)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                '₹${tier.getPricePerUnit().toStringAsFixed(2)}/unit',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                if (savings > 0)
                                  Chip(
                                    label: Text(
                                        'Save ${savings.toStringAsFixed(1)}%'),
                                    backgroundColor: Colors.red[100],
                                    labelStyle: TextStyle(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                if (tier.isDefault)
                                  Chip(
                                    label: const Text('Default'),
                                    backgroundColor: Colors.green,
                                    labelStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                child: const Row(
                                  children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                                onTap: () => _showEditTierDialog(context, tier),
                              ),
                              if (!tier.isDefault)
                                PopupMenuItem(
                                  child: const Row(
                                    children: [
                                      Icon(Icons.check_circle_outline,
                                          size: 18),
                                      SizedBox(width: 8),
                                      Text('Set as Default'),
                                    ],
                                  ),
                                  onTap: () => _setDefaultTier(tier.id),
                                ),
                              PopupMenuItem(
                                child: const Row(
                                  children: [
                                    Icon(Icons.delete,
                                        size: 18, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete',
                                        style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                                onTap: () => _deleteTier(tier.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Show dialog to add a new pricing tier
  void _showAddTierDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _PricingTierDialog(
        productId: widget.productId,
        basePrice: widget.basePrice,
        onSave: (tier) {
          Navigator.pop(context);
          _pricingService.createPricingTier(widget.productId, tier);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Pricing tier added')),
          );
        },
      ),
    );
  }

  /// Show dialog to edit a pricing tier
  void _showEditTierDialog(BuildContext context, PricingTierModel tier) {
    showDialog(
      context: context,
      builder: (context) => _PricingTierDialog(
        productId: widget.productId,
        basePrice: widget.basePrice,
        tier: tier,
        isEdit: true,
        onSave: (updatedTier) {
          Navigator.pop(context);
          _pricingService.updatePricingTier(
            widget.productId,
            tier.id,
            {
              'quantity': updatedTier.quantity,
              'unit': updatedTier.unit,
              'price': updatedTier.price,
            },
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Pricing tier updated')),
          );
        },
      ),
    );
  }

  /// Delete a pricing tier
  void _deleteTier(String tierId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tier?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pricingService.deletePricingTier(widget.productId, tierId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Pricing tier deleted')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Set a tier as default
  void _setDefaultTier(String tierId) {
    _pricingService.setDefaultTier(widget.productId, tierId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Default tier updated')),
    );
  }
}

/// Dialog for adding/editing pricing tiers
class _PricingTierDialog extends StatefulWidget {
  final String productId;
  final double basePrice;
  final PricingTierModel? tier;
  final bool isEdit;
  final Function(PricingTierModel) onSave;

  const _PricingTierDialog({
    required this.productId,
    required this.basePrice,
    this.tier,
    this.isEdit = false,
    required this.onSave,
  });

  @override
  State<_PricingTierDialog> createState() => __PricingTierDialogState();
}

class __PricingTierDialogState extends State<_PricingTierDialog> {
  late TextEditingController _quantityController;
  late TextEditingController _unitController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.tier?.quantity.toStringAsFixed(0) ?? '',
    );
    _unitController = TextEditingController(
      text: widget.tier?.unit ?? '',
    );
    _priceController = TextEditingController(
      text: widget.tier?.price.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    final pricePerUnit = quantity > 0 ? price / quantity : 0;
    final savings = (widget.basePrice - pricePerUnit) / widget.basePrice * 100;

    return AlertDialog(
      title: Text(widget.isEdit ? 'Edit Pricing Tier' : 'Add Pricing Tier'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quantity input
            TextField(
              controller: _quantityController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Quantity',
                hintText: 'e.g., 1, 5, 10',
                prefixIcon: const Icon(Icons.category),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),

            // Unit input
            TextField(
              controller: _unitController,
              decoration: InputDecoration(
                labelText: 'Unit',
                hintText: 'e.g., KG, L, ML, Pack',
                prefixIcon: const Icon(Icons.straighten),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Price input
            TextField(
              controller: _priceController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Price',
                hintText: '₹0.00',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),

            // Price summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[300]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Price per Unit:',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '₹${pricePerUnit.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Savings vs Base:',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${savings > 0 ? '+' : ''}${savings.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  savings > 0 ? Colors.green[700] : Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[700],
          ),
          onPressed: () {
            final quantity = double.tryParse(_quantityController.text) ?? 0;
            final price = double.tryParse(_priceController.text) ?? 0;

            if (quantity <= 0 || _unitController.text.isEmpty || price <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Please fill all fields with valid values'),
                ),
              );
              return;
            }

            final tier = PricingTierModel(
              id: widget.tier?.id ?? '',
              quantity: quantity,
              unit: _unitController.text,
              price: price,
              isDefault: widget.tier?.isDefault ?? false,
            );

            widget.onSave(tier);
          },
          child: Text(widget.isEdit ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
