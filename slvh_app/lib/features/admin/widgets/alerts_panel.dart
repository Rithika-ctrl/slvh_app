import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../payments/models/payment_model.dart';
import '../../products/models/product_model.dart';

class AlertsPanel extends StatelessWidget {
  final List<ProductModel> lowStockProducts;
  final List<PaymentModel> pendingPayments;
  final bool isLoadingStock;
  final bool isLoadingPayments;
  final Object? stockError;
  final Object? paymentsError;

  const AlertsPanel({
    super.key,
    required this.lowStockProducts,
    required this.pendingPayments,
    this.isLoadingStock = false,
    this.isLoadingPayments = false,
    this.stockError,
    this.paymentsError,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final stockPanel = _AlertSection(
          title: 'Low Stock Alerts',
          icon: Icons.inventory_2_outlined,
          color: AppColors.error,
          isLoading: isLoadingStock,
          error: stockError,
          emptyTitle: 'Stock is healthy',
          emptySubtitle: 'Products below threshold will be listed here.',
          children: [
            for (final product in lowStockProducts.take(5))
              _ProductAlertTile(product: product),
          ],
        );
        final paymentsPanel = _AlertSection(
          title: 'Pending Verifications',
          icon: Icons.verified_user_outlined,
          color: AppColors.orange,
          isLoading: isLoadingPayments,
          error: paymentsError,
          emptyTitle: 'No pending payments',
          emptySubtitle: 'Uploaded payment proofs will appear here.',
          children: [
            for (final payment in pendingPayments.take(5))
              _PaymentAlertTile(payment: payment),
          ],
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: stockPanel),
              const SizedBox(width: 16),
              Expanded(child: paymentsPanel),
            ],
          );
        }

        return Column(
          children: [
            stockPanel,
            const SizedBox(height: 16),
            paymentsPanel,
          ],
        );
      },
    );
  }
}

class _AlertSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final Object? error;
  final String emptyTitle;
  final String emptySubtitle;
  final List<Widget> children;

  const _AlertSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.error,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              if (isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: color),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (error != null)
            _PanelMessage(
              icon: Icons.error_outline,
              title: 'Unable to load',
              subtitle: error.toString(),
            )
          else if (!isLoading && children.isEmpty)
            _PanelMessage(
              icon: Icons.check_circle_outline,
              title: emptyTitle,
              subtitle: emptySubtitle,
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _ProductAlertTile extends StatelessWidget {
  final ProductModel product;

  const _ProductAlertTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return _AlertTile(
      title: product.name,
      subtitle:
          '${product.stock} ${product.unitType.isEmpty ? 'units' : product.unitType} left',
      trailing: product.stock == 0 ? 'Out' : 'Low',
      color: product.stock == 0 ? AppColors.error : AppColors.orange,
    );
  }
}

class _PaymentAlertTile extends StatelessWidget {
  final PaymentModel payment;

  const _PaymentAlertTile({required this.payment});

  @override
  Widget build(BuildContext context) {
    return _AlertTile(
      title:
          '#${payment.orderId.length <= 8 ? payment.orderId : payment.orderId.substring(0, 8)}',
      subtitle:
          '${payment.customerPhone} • Rs ${payment.amount.toStringAsFixed(0)}',
      trailing: 'Verify',
      color: AppColors.orange,
    );
  }
}

class _AlertTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final Color color;

  const _AlertTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              trailing,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PanelMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textHint, size: 34),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
