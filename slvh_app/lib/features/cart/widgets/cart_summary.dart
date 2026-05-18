import 'package:flutter/material.dart';
import 'package:slvh_app/features/cart/providers/cart_provider.dart';
import 'package:slvh_app/features/settings/services/settings_service.dart';
import 'minimum_order_banner.dart';
import '../../../core/utils/secure_logger.dart';

/// Cart summary widget showing totals and checkout button
class CartSummary extends StatefulWidget {
  final CartProvider cartProvider;
  final VoidCallback onCheckout;

  const CartSummary({
    Key? key,
    required this.cartProvider,
    required this.onCheckout,
  }) : super(key: key);

  @override
  State<CartSummary> createState() => _CartSummaryState();
}

class _CartSummaryState extends State<CartSummary> {
  final SettingsService _settingsService = SettingsService.instance;
  double _minOrderValue = 0.0;

  @override
  void initState() {
    super.initState();
    _loadMinOrderValue();
  }

  Future<void> _loadMinOrderValue() async {
    try {
      final settings = await _settingsService.getSettings();
      setState(() {
        _minOrderValue = settings.minOrderValue;
      });
    } catch (e) {
      AppLogger.debug('Error loading min order value: $e');
    }
  }

  /// Check if checkout is allowed
  bool get _canCheckout => _minOrderValue == 0 || widget.cartProvider.total >= _minOrderValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minimum order warning banner
        if (!_canCheckout)
          MinimumOrderBanner(
            cartTotal: widget.cartProvider.total,
            minOrderValue: _minOrderValue,
            onShoppingContinued: () => Navigator.pop(context),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
            color: Colors.grey[50],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary details
              _SummaryRow(
                label: 'Subtotal',
                value: '₹${widget.cartProvider.subtotal.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'Estimated Tax (5%)',
                value: '₹${widget.cartProvider.estimatedTax.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 12),

              // Total
              _SummaryRow(
                label: 'Total',
                value: '₹${widget.cartProvider.total.toStringAsFixed(2)}',
                isTotal: true,
              ),
              const SizedBox(height: 16),

              // Checkout button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _canCheckout ? widget.onCheckout : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canCheckout ? Colors.orange[700] : Colors.grey[400],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _canCheckout 
                      ? 'Proceed to Checkout'
                      : 'Minimum Order: ₹${_minOrderValue.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Continue shopping button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.orange[700]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Continue Shopping',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Summary row showing label and value
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isTotal ? FontWeight.bold : null,
                color: isTotal ? Colors.orange[700] : null,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isTotal ? Colors.orange[700] : null,
                fontSize: isTotal ? 18 : null,
              ),
        ),
      ],
    );
  }
}


