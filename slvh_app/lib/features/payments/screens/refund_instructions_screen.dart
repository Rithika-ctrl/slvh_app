import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';
import 'package:slvh_app/features/payments/models/payment_model.dart';

/// Refund instructions screen shown when payment is rejected
/// Displays:
/// - Rejection reason
/// - Refund process and timeline
/// - Shop contact information
/// - Actions: Contact Support, Retry Payment, View Order
class RefundInstructionsScreen extends StatefulWidget {
  final OrderModel order;
  final PaymentModel payment;
  final VoidCallback? onRetryPayment;

  const RefundInstructionsScreen({
    Key? key,
    required this.order,
    required this.payment,
    this.onRetryPayment,
  }) : super(key: key);

  @override
  State<RefundInstructionsScreen> createState() =>
      _RefundInstructionsScreenState();
}

class _RefundInstructionsScreenState extends State<RefundInstructionsScreen> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Rejected'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.red[600],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rejection icon and message
            _buildRejectionHeader(),
            const SizedBox(height: 24),

            // Rejection reason
            _buildRejectionReasonCard(),
            const SizedBox(height: 20),

            // Refund process timeline
            _buildRefundProcessCard(),
            const SizedBox(height: 20),

            // Payment details
            _buildPaymentDetailsCard(),
            const SizedBox(height: 20),

            // Shop contact information
            _buildContactInformationCard(),
            const SizedBox(height: 20),

            // Action buttons
            _buildActionButtons(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Build rejection header with icon and message
  Widget _buildRejectionHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!, width: 2),
      ),
      child: Column(
        children: [
          Icon(
            Icons.close_circle_outline,
            size: 64,
            color: Colors.red[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Payment Rejected',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your payment screenshot was not accepted',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build rejection reason card
  Widget _buildRejectionReasonCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
              const SizedBox(width: 12),
              Text(
                'Reason for Rejection',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Text(
              widget.payment.rejectionReason ?? 'No reason provided',
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build refund process timeline
  Widget _buildRefundProcessCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Refund Process',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildProcessStep(
            number: '1',
            title: 'Automatic Refund',
            description:
                'Your payment will be automatically refunded to your original UPI/Bank account',
            icon: Icons.account_balance,
          ),
          const SizedBox(height: 12),
          _buildProcessStep(
            number: '2',
            title: '5-7 Business Days',
            description: 'Refund typically processes within 5-7 business days',
            icon: Icons.schedule,
          ),
          const SizedBox(height: 12),
          _buildProcessStep(
            number: '3',
            title: 'Confirmation',
            description:
                'You will receive a WhatsApp notification once refund is processed',
            icon: Icons.notifications_active,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No action needed from your side',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
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

  /// Build a single process step
  Widget _buildProcessStep({
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green[100],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green[300]!),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build payment details card
  Widget _buildPaymentDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Details',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showDetails = !_showDetails),
                child: Icon(
                  _showDetails ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (_showDetails) ...[
            const SizedBox(height: 12),
            _DetailRow(label: 'Order ID', value: widget.order.id),
            const SizedBox(height: 8),
            _DetailRow(label: 'Amount', value: '₹${widget.payment.amount}'),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Status',
              value: widget.payment.status.label,
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Rejection Date',
              value: _formatDate(widget.payment.updatedAt ?? DateTime.now()),
            ),
          ],
        ],
      ),
    );
  }

  /// Build contact information card
  Widget _buildContactInformationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contact_support, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Text(
                'Contact Support',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'If you haven\'t received your refund after 7 days or have any questions:',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          _ContactButton(
            icon: Icons.chat_bubble_outline,
            label: 'WhatsApp',
            onTap: () => _launchWhatsApp(),
          ),
          const SizedBox(height: 8),
          _ContactButton(
            icon: Icons.phone_outlined,
            label: 'Call Support',
            onTap: () => _launchPhone(),
          ),
          const SizedBox(height: 8),
          _ContactButton(
            icon: Icons.email_outlined,
            label: 'Email Support',
            onTap: () => _launchEmail(),
          ),
        ],
      ),
    );
  }

  /// Build action buttons
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: widget.onRetryPayment ?? () => Navigator.pop(context),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry Payment'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.receipt_long),
          label: const Text('View Order'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue[600],
            side: BorderSide(color: Colors.blue[600]!),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  /// Launch WhatsApp
  Future<void> _launchWhatsApp() async {
    // Replace with actual shop WhatsApp number
    final whatsappUrl = 'https://wa.me/919876543210?text=Payment%20Rejection%20Help';
    try {
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open WhatsApp: $e')),
      );
    }
  }

  /// Launch phone call
  Future<void> _launchPhone() async {
    final phoneUrl = 'tel:+919876543210';
    try {
      if (await canLaunchUrl(Uri.parse(phoneUrl))) {
        await launchUrl(Uri.parse(phoneUrl));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch phone: $e')),
      );
    }
  }

  /// Launch email
  Future<void> _launchEmail() async {
    final emailUrl = 'mailto:support@smartshop.com?subject=Payment%20Rejection%20Help';
    try {
      if (await canLaunchUrl(Uri.parse(emailUrl))) {
        await launchUrl(Uri.parse(emailUrl));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch email: $e')),
      );
    }
  }

  /// Format date
  String _formatDate(DateTime date) {
    final months = [
      '',
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
    return '${date.day} ${months[date.month]} ${date.year}';
  }
}

/// Detail row helper
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Contact button helper
class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue[200]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.blue[600]),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue[600],
                ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward, size: 16, color: Colors.blue[400]),
            ],
          ),
        ),
      ),
    );
  }
}
