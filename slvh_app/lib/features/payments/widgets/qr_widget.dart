import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Widget to display UPI QR code for payment
class PaymentQRWidget extends StatelessWidget {
  final String upiId;
  final String recipientName;
  final double amount;
  final String? orderId;

  const PaymentQRWidget({
    Key? key,
    required this.upiId,
    required this.recipientName,
    required this.amount,
    this.orderId,
  }) : super(key: key);

  /// Generate UPI string for QR code
  /// Format: upi://pay?pa=UPI_ID&pn=NAME&am=AMOUNT&tn=NOTE
  String get _upiString {
    String upi = 'upi://pay?pa=$upiId&pn=${_urlEncode(recipientName)}';
    if (amount > 0) {
      upi += '&am=$amount';
    }
    if (orderId != null) {
      upi += '&tn=Order%20${_urlEncode(orderId!)}';
    }
    return upi;
  }

  /// URL encode string for UPI format
  String _urlEncode(String text) {
    return text.replaceAll(' ', '%20');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Title
          Text(
            'Scan to Pay',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          // QR Code
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrImage(
              data: _upiString,
              version: QrVersions.auto,
              size: 250,
              backgroundColor: Colors.white,
              errorCorrectLevel: QrErrorCorrectLevel.H,
              errorStateBuilder: (context, error) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'Failed to generate QR code',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Payment details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!, width: 1),
            ),
            child: Column(
              children: [
                _DetailRow(
                  label: 'UPI ID',
                  value: upiId,
                  isCopyable: true,
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Amount',
                  value: '₹${amount.toStringAsFixed(2)}',
                ),
                if (orderId != null) ...[
                  const SizedBox(height: 8),
                  _DetailRow(
                    label: 'Order ID',
                    value: orderId!,
                    isCopyable: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue[700],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Scan the QR code with any UPI app or pay using the UPI ID above',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper widget for displaying QR details
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCopyable;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isCopyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        if (isCopyable) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              // Copy to clipboard
              // ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(content: Text('Copied to clipboard')),
              // );
            },
            child: Icon(
              Icons.copy_outlined,
              size: 16,
              color: Colors.orange[700],
            ),
          ),
        ],
      ],
    );
  }
}
