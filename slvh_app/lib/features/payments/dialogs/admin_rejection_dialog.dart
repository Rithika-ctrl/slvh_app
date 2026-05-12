import 'package:flutter/material.dart';
import 'package:slvh_app/features/payments/models/payment_model.dart';

/// Predefined rejection reasons
const List<String> rejectionReasons = [
  'Screenshot blurry or unclear',
  'Payment amount mismatch',
  'Wrong UPI ID used',
  'Payment reference not visible',
  'Transaction time not visible',
  'Screenshot appears edited',
];

/// Admin dialog to reject payment with reason selection
class AdminRejectionDialog extends StatefulWidget {
  final PaymentModel payment;
  final Function(String reason) onConfirm;

  const AdminRejectionDialog({
    Key? key,
    required this.payment,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<AdminRejectionDialog> createState() => _AdminRejectionDialogState();
}

class _AdminRejectionDialogState extends State<AdminRejectionDialog> {
  String? selectedReason;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment: ${widget.payment.id}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Amount: ₹${widget.payment.amount}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Rejection Reason:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: selectedReason,
                hint: const Text('  Choose reason...'),
                isExpanded: true,
                underline: Container(),
                items: rejectionReasons.map((reason) {
                  return DropdownMenuItem(
                    value: reason,
                    child: Text(reason),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => selectedReason = value);
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason will be sent to customer via WhatsApp',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: selectedReason == null || isLoading
              ? null
              : () async {
                  setState(() => isLoading = true);
                  try {
                    widget.onConfirm(selectedReason!);
                    if (mounted) Navigator.pop(context);
                  } finally {
                    if (mounted) setState(() => isLoading = false);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            disabledBackgroundColor: Colors.grey[300],
          ),
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Reject Payment'),
        ),
      ],
    );
  }
}
