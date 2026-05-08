import 'dart:io';
import 'package:flutter/material.dart';
import 'package:slvh_app/features/payments/models/payment_model.dart';
import 'package:slvh_app/features/payments/services/payment_service.dart';
import 'package:slvh_app/features/payments/widgets/qr_widget.dart';
import 'package:slvh_app/features/payments/widgets/upload_screenshot_widget.dart';
import 'package:slvh_app/features/pickup_slots/models/slot_model.dart';

/// Payment screen for displaying UPI QR code and handling screenshot upload
class PaymentScreen extends StatefulWidget {
  final String orderId;
  final double amount;
  final String customerPhone;
  final Map<String, dynamic>? cartSummary; // Optional cart summary

  const PaymentScreen({
    Key? key,
    required this.orderId,
    required this.amount,
    required this.customerPhone,
    this.cartSummary,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = PaymentService();

  late ShopSettingsModel _settings;
  late PaymentModel _payment;

  String? _selectedImagePath;
  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  /// Initialize payment screen by loading settings and creating payment record
  Future<void> _initializePayment() async {
    try {
      setState(() => _isLoading = true);

      // Fetch shop settings
      _settings = await _paymentService.getShopSettings();

      if (_settings.upiId == null || _settings.upiId!.isEmpty) {
        throw Exception('Shop UPI ID not configured');
      }

      // Create payment record
      final paymentId = await _paymentService.createPayment(
        orderId: widget.orderId,
        upiId: _settings.upiId!,
        amount: widget.amount,
        customerPhone: widget.customerPhone,
      );

      // Fetch payment record
      final payment = await _paymentService.getPayment(paymentId);
      if (payment == null) {
        throw Exception('Failed to create payment');
      }

      setState(() {
        _payment = payment;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize payment: $e';
        _isLoading = false;
      });
    }
  }

  /// Handle image selection
  void _handleImageSelected(File imageFile) {
    setState(() {
      _selectedImagePath = imageFile.path;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  /// Handle screenshot upload
  Future<void> _handleUploadScreenshot() async {
    if (_selectedImagePath == null) {
      setState(() => _errorMessage = 'Please select an image first');
      return;
    }

    try {
      setState(() => _isUploading = true);

      final imageFile = File(_selectedImagePath!);

      // Upload screenshot to Firebase Storage
      final downloadUrl = await _paymentService.uploadPaymentScreenshot(
        imageFile: imageFile,
        orderId: widget.orderId,
        paymentId: _payment.id,
      );

      // Update payment with screenshot URL
      await _paymentService.updatePaymentScreenshot(
        paymentId: _payment.id,
        screenshotUrl: downloadUrl,
      );

      // Update order status to 'Payment Verification Pending'
      await _paymentService.updateOrderPaymentStatus(widget.orderId);

      setState(() {
        _isUploading = false;
        _successMessage = '✅ Payment proof submitted successfully!';
        _payment = _payment.copyWith(
          screenshotUrl: downloadUrl,
          status: PaymentStatus.verificationPending,
        );
      });

      // Show success snackbar and optionally navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Payment proof submitted for verification'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Optional: Navigate back after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context, {
              'paymentId': _payment.id,
              'status': 'Payment Verification Pending',
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'Upload failed: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle upload start
  void _handleUploadStart() {
    _handleUploadScreenshot();
  }

  /// Handle error
  void _handleUploadError(String error) {
    setState(() => _errorMessage = error);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null && _payment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order summary card
            _buildOrderSummaryCard(),
            const SizedBox(height: 20),

            // Payment instructions card
            _buildPaymentInstructionsCard(),
            const SizedBox(height: 20),

            // QR code widget
            PaymentQRWidget(
              upiId: _settings.upiId!,
              recipientName: 'Smart Shop',
              amount: widget.amount,
              orderId: widget.orderId,
            ),
            const SizedBox(height: 20),

            // Screenshot upload widget
            if (_payment.status != PaymentStatus.verified)
              ScreenshotUploadWidget(
                onUploadStart: _handleUploadStart,
                onImageSelected: _handleImageSelected,
                onUploadSuccess: (url) {
                  // Handle success
                },
                onUploadError: _handleUploadError,
                isUploading: _isUploading,
                uploadedImagePath: _selectedImagePath,
              ),

            // Success message
            if (_payment.status == PaymentStatus.verificationPending)
              ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.green[300]!, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Submitted',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your payment proof is pending verification',
                              style: TextStyle(
                                color: Colors.green[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

            // Verified message
            if (_payment.status == PaymentStatus.verified)
              ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.green[300]!, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Verified',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your order is confirmed and will be prepared shortly',
                              style: TextStyle(
                                color: Colors.green[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: const Text('Continue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                    ),
                  ),
                ),
              ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Build order summary card
  Widget _buildOrderSummaryCard() {
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
            'Order Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Order ID',
            value: widget.orderId,
          ),
          const SizedBox(height: 8),
          if (widget.cartSummary != null) ...[
            _SummaryRow(
              label: 'Items',
              value: '${widget.cartSummary!['itemCount']}',
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Subtotal',
              value:
                  '₹${(widget.cartSummary!['subtotal'] as num).toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Tax',
              value:
                  '₹${(widget.cartSummary!['estimatedTax'] as num).toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            Container(
              height: 1,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 8),
          ],
          _SummaryRow(
            label: 'Total Amount',
            value: '₹${widget.amount.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  /// Build payment instructions card
  Widget _buildPaymentInstructionsCard() {
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
              Icon(
                Icons.info_outline,
                color: Colors.blue[700],
              ),
              const SizedBox(width: 8),
              Text(
                'How to Pay',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InstructionStep(
            number: '1',
            text: 'Scan the QR code with any UPI app (Google Pay, PhonePe, Paytm, etc.)',
          ),
          const SizedBox(height: 8),
          _InstructionStep(
            number: '2',
            text: 'Verify the amount and pay',
          ),
          const SizedBox(height: 8),
          _InstructionStep(
            number: '3',
            text: 'Screenshot the payment success screen',
          ),
          const SizedBox(height: 8),
          _InstructionStep(
            number: '4',
            text: 'Upload the screenshot below for verification',
          ),
        ],
      ),
    );
  }
}

/// Summary row helper widget
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
          style: TextStyle(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? Colors.black87 : Colors.black54,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal ? Colors.orange[700] : Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Instruction step helper widget
class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionStep({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue[700],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.blue[700],
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
