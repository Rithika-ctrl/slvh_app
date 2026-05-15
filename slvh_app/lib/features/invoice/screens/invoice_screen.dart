import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../orders/models/order_model.dart';
import '../../orders/services/order_service.dart';
import '../../payments/models/payment_model.dart';
import '../../payments/services/payment_service.dart';
import '../../settings/models/shop_settings_model.dart';
import '../../settings/services/settings_service.dart';
import '../../auth/services/auth_service.dart';
import '../../profile/services/user_profile_service.dart';
import '../models/invoice_model.dart';
import '../services/invoice_service.dart';

/// Full-screen invoice / receipt viewer.
///
/// Route: /orders/:orderId/invoice
///
/// Loads order + payment + settings + user-profile in parallel, builds an
/// [InvoiceModel] and renders every billing field.  The floating "Share /
/// Download" button calls [InvoiceService.shareInvoice] which writes a PDF and
/// opens the OS share sheet.
class InvoiceScreen extends StatefulWidget {
  final String orderId;

  const InvoiceScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  // ── Services ─────────────────────────────────────────────────────────────
  final _orderService = OrderService();
  final _paymentService = PaymentService();
  final _settingsService = SettingsService.instance;
  final _authService = AuthService();
  final _profileService = UserProfileService();
  final _invoiceService = InvoiceService();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _loading = true;
  bool _generating = false;
  String? _error;
  InvoiceModel? _invoice;

  // ── Formatters ────────────────────────────────────────────────────────────
  final _rupee = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFmt = DateFormat('dd MMM yyyy');
  final _timeFmt = DateFormat('hh:mm a');

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data loading
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      // Fetch all data in parallel
      final results = await Future.wait<dynamic>([
        _orderService.getOrder(widget.orderId),
        _settingsService.getSettings(),
        _authService.getCurrentUserPhone().then((p) async {
          if (p == null) return ['', ''];
          final name = await _profileService.fetchName(p);
          return [p, name];
        }),
      ]);

      final order = results[0] as OrderModel?;
      final settings = results[1] as ShopSettingsModel;
      final userInfo = results[2] as List<dynamic>;
      final phone = userInfo[0] as String;
      final name = userInfo[1] as String;

      if (order == null) {
        setState(() {
          _error = 'Order not found.';
          _loading = false;
        });
        return;
      }

      // Optionally fetch payment
      PaymentModel? payment;
      if (order.paymentId != null) {
        try {
          payment = await _paymentService.getPayment(order.paymentId!);
        } catch (_) {}
      }

      final invoice = _invoiceService.buildInvoice(
        order: order,
        payment: payment,
        settings: settings,
        // ── Customise these per your Firestore shop-info document ──
        shopName: 'SLVH Smart Shop',
        shopAddress: '123, Main Road, Your City – 560001',
        shopPhone: settings.upiId.isNotEmpty ? settings.upiId : '+91-XXXXXXXXXX',
        shopEmail: 'support@slvhshop.in',
        shopLogoUrl: '',
        gstin: '', // fill when GST registered
        customerName: name,
        customerEmail: '',
      );

      setState(() {
        _invoice = invoice;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Share / Download
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _shareInvoice() async {
    if (_invoice == null) return;
    setState(() => _generating = true);
    try {
      await _invoiceService.shareInvoice(_invoice!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI helpers
  // ─────────────────────────────────────────────────────────────────────────

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(title),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
          const SizedBox(height: 16),
        ],
      );

  Widget _sectionHeader(String title) => Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );

  Widget _row(String label, String value,
      {bool valueBold = false,
      Color? valueColor,
      bool isLarge = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Text(label,
                  style: TextStyle(
                    fontSize: isLarge ? 13 : 12,
                    color: AppColors.textMid,
                  )),
            ),
            Expanded(
              flex: 5,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: isLarge ? 13 : 12,
                  fontWeight:
                      valueBold ? FontWeight.w700 : FontWeight.w500,
                  color: valueColor ?? AppColors.textDark,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );

  Widget _divider() => const Divider(
        thickness: 0.5,
        color: AppColors.cardBorder,
        height: 16,
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        title: const Text('Invoice / Receipt'),
        centerTitle: true,
        backgroundColor: AppColors.bgCream,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          if (_invoice != null && !_generating)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share PDF',
              onPressed: _shareInvoice,
            ),
          if (_generating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _invoice != null
          ? FloatingActionButton.extended(
              onPressed: _generating ? null : _shareInvoice,
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded),
              label: Text(_generating ? 'Generating…' : 'Download / Share PDF'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildInvoice(_invoice!),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Failed to load invoice',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: AppColors.textMid),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _load();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _buildInvoice(InvoiceModel inv) {
    final isVerified = inv.paymentStatus.toLowerCase() == 'verified';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── INVOICE HEADER CARD ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.orange, AppColors.orangeLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: AppColors.orange.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Logo placeholder
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: inv.storeLogoUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(inv.storeLogoUrl,
                                    fit: BoxFit.cover))
                            : Text(
                                inv.storeName.isNotEmpty
                                    ? inv.storeName[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inv.storeName,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(inv.invoiceTitle.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                    // Payment status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isVerified
                            ? AppColors.success
                            : AppColors.warning,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        inv.paymentStatus.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isVerified ? Colors.white : AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white30, thickness: 0.5),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _headerItem('Invoice No', inv.invoiceNumber),
                    _headerItem('Order ID', '#${inv.orderId.length > 8 ? inv.orderId.substring(inv.orderId.length - 8) : inv.orderId}'),
                    _headerItem('Date',
                        _dateFmt.format(inv.invoiceDate)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── SELLER INFO ────────────────────────────────────────────────
          _section('SELLER INFORMATION', [
            _row('Shop Name', inv.storeName, valueBold: true),
            _divider(),
            _row('Address', inv.sellerAddress),
            if (inv.sellerContactNumber.isNotEmpty) ...[
              _divider(),
              _row('Contact', inv.sellerContactNumber),
            ],
            if (inv.sellerEmail.isNotEmpty) ...[
              _divider(),
              _row('Email', inv.sellerEmail),
            ],
            if (inv.gstin.isNotEmpty) ...[
              _divider(),
              _row('GSTIN', inv.gstin),
            ],
          ]),

          // ── CUSTOMER INFO ──────────────────────────────────────────────
          _section('CUSTOMER INFORMATION', [
            _row('Name',
                inv.customerName.isNotEmpty ? inv.customerName : '—',
                valueBold: true),
            _divider(),
            _row('Phone', inv.customerPhone),
            if (inv.customerEmail.isNotEmpty) ...[
              _divider(),
              _row('Email', inv.customerEmail),
            ],
            _divider(),
            _row('Pickup Address', inv.deliveryAddress),
          ]),

          // ── ORDER DETAILS ──────────────────────────────────────────────
          _section('ORDER & PAYMENT DETAILS', [
            _row('Order ID', '#${inv.orderId}', valueBold: true),
            _divider(),
            _row('Invoice Number', inv.invoiceNumber),
            _divider(),
            _row('Invoice Date',
                DateFormat('dd MMM yyyy, hh:mm a').format(inv.invoiceDate)),
            _divider(),
            _row('Payment Method', inv.paymentMethod),
            _divider(),
            _row('Payment Status', inv.paymentStatus,
                valueColor:
                    isVerified ? AppColors.success : AppColors.warning,
                valueBold: true),
            if (inv.transactionId.isNotEmpty) ...[
              _divider(),
              _row('Transaction ID', inv.transactionId),
            ],
            _divider(),
            _row('Pickup Date', inv.pickupDate),
            _divider(),
            _row('Pickup Time', inv.pickupTime),
            if (inv.trackingId.isNotEmpty) ...[
              _divider(),
              _row('Tracking ID', inv.trackingId),
            ],
            if (inv.estimatedDeliveryTime.isNotEmpty) ...[
              _divider(),
              _row('Est. Pickup Time', inv.estimatedDeliveryTime),
            ],
            if (inv.couponCodeUsed.isNotEmpty) ...[
              _divider(),
              _row('Coupon Used', inv.couponCodeUsed,
                  valueColor: AppColors.success),
            ],
          ]),

          // ── PRODUCTS ───────────────────────────────────────────────────
          _sectionHeader('PRODUCTS ORDERED'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                // Column headers
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                          flex: 4,
                          child: Text('ITEM',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5))),
                      SizedBox(
                          width: 36,
                          child: Text('QTY',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white))),
                      Expanded(
                          flex: 2,
                          child: Text('PRICE',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white))),
                      Expanded(
                          flex: 2,
                          child: Text('TOTAL',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white))),
                    ],
                  ),
                ),
                // Item rows
                ...inv.items.asMap().entries.map((e) {
                  final idx = e.key;
                  final item = e.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: idx.isEven
                          ? Colors.white
                          : AppColors.bgCreamLight.withOpacity(0.4),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textDark)),
                                  if (item.variantOrSize.isNotEmpty)
                                    Text(item.variantOrSize,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMid)),
                                  if (item.discountPercent > 0)
                                    Text(
                                      '${item.discountPercent.toStringAsFixed(0)}% tier discount',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.success),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 36,
                              child: Text(
                                item.quantity.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _rupee.format(item.unitPrice),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMid),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _rupee.format(item.totalPrice),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── PRICE SUMMARY ──────────────────────────────────────────────
          _section('PRICE SUMMARY', [
            _row('Subtotal', _rupee.format(inv.subtotal)),
            if (inv.discountAmount > 0) ...[
              _divider(),
              _row('Discount',
                  '- ${_rupee.format(inv.discountAmount)}',
                  valueColor: AppColors.success),
            ],
            if (inv.deliveryCharges > 0) ...[
              _divider(),
              _row('Delivery Charges', _rupee.format(inv.deliveryCharges)),
            ],
            _divider(),
            _row('Tax (GST)', _rupee.format(inv.taxAmount)),
            if (inv.walletAmountUsed > 0) ...[
              _divider(),
              _row('Wallet Amount Used',
                  '- ${_rupee.format(inv.walletAmountUsed)}',
                  valueColor: AppColors.success),
            ],
            const Divider(thickness: 1, color: AppColors.orange, height: 20),
            _row('Grand Total', _rupee.format(inv.grandTotal),
                valueBold: true,
                valueColor: AppColors.orange,
                isLarge: true),
          ]),

          // ── RETURN / REFUND NOTE ───────────────────────────────────────
          if (inv.returnRefundNote.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.orangePale,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: AppColors.orange, width: 3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      inv.returnRefundNote,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMid),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── FOOTER ────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.bgCreamLight.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Text(
                  inv.thankYouMessage,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.orange,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'For support, contact: ${inv.supportContact}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMid),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Divider(thickness: 0.5, color: AppColors.cardBorder),
                const SizedBox(height: 8),
                const Text(
                  'This is a computer-generated invoice and does not '
                  'require a physical signature or seal.',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _headerItem(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white70,
                  letterSpacing: 0.4)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      );
}