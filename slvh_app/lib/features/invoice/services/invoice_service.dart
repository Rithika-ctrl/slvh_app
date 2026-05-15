import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../orders/models/order_model.dart';
import '../../payments/models/payment_model.dart';
import '../../settings/models/shop_settings_model.dart';
import '../models/invoice_model.dart';

/// Builds an [InvoiceModel] from app data objects and renders it to a PDF
/// that can be shared via the system share sheet.
class InvoiceService {
  // ── Currency formatter ────────────────────────────────────────────────────
  static final _rupee = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Assembles an [InvoiceModel] from raw app objects.
  ///
  /// [shopName], [shopAddress], [shopPhone] come from your shop settings /
  /// remote-config; [customerName] from the user-profile Firestore doc.
  InvoiceModel buildInvoice({
    required OrderModel order,
    required PaymentModel? payment,
    required ShopSettingsModel settings,
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    required String shopEmail,
    required String shopLogoUrl,
    required String gstin,
    required String customerName,
    required String customerEmail,
  }) {
    // Build line items
    final items = order.items
        .map((i) => InvoiceItem(
              productName: i.productName,
              variantOrSize: i.selectedTierUnit ?? '',
              quantity: i.quantity,
              unitPrice: i.unitPrice,
              totalPrice: i.totalPrice,
              discountPercent: i.discountPercent ?? 0.0,
            ))
        .toList();

    // Invoice number: INV-YYYYMMDD-<last 6 of orderId>
    final datePart = DateFormat('yyyyMMdd').format(order.createdAt);
    final idSuffix = order.id.length >= 6
        ? order.id.substring(order.id.length - 6).toUpperCase()
        : order.id.toUpperCase();
    final invoiceNumber = 'INV-$datePart-$idSuffix';

    // Pickup address line
    final pickupAddress =
        'Pickup: ${order.pickupDate} at ${order.pickupTime}\n$shopAddress';

    return InvoiceModel(
      storeName: shopName,
      storeLogoUrl: shopLogoUrl,
      sellerAddress: shopAddress,
      sellerContactNumber: shopPhone,
      sellerEmail: shopEmail,
      gstin: gstin,
      supportContact: shopPhone,
      invoiceNumber: invoiceNumber,
      invoiceTitle: 'Tax Invoice',
      invoiceDate: order.createdAt,
      orderId: order.id,
      paymentMethod: 'UPI',
      paymentStatus: payment?.status.label ?? order.paymentStatus ?? 'Pending',
      transactionId: payment?.id ?? order.paymentReference ?? '',
      customerName: customerName,
      customerPhone: order.customerId,
      customerEmail: customerEmail,
      deliveryAddress: pickupAddress,
      items: items,
      subtotal: order.subtotal,
      discountAmount: 0.0, // extend when coupon support lands
      deliveryCharges: 0.0, // pickup app → no delivery charge
      taxAmount: order.tax,
      walletAmountUsed: 0.0,
      grandTotal: order.total,
      couponCodeUsed: '',
      pickupDate: order.pickupDate,
      pickupTime: order.pickupTime,
      trackingId: '',
      estimatedDeliveryTime: '',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PDF generation
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates a PDF [Uint8List] for [invoice].
  Future<Uint8List> generatePdf(InvoiceModel invoice) async {
    final doc = pw.Document(
      title: invoice.invoiceNumber,
      author: invoice.storeName,
      creator: invoice.storeName,
    );

    // Fonts
    final regularFont =
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldFont = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final ttfRegular = pw.Font.ttf(regularFont);
    final ttfBold = pw.Font.ttf(boldFont);

    // Optional logo
    pw.ImageProvider? logoImage;
    // (logo loaded elsewhere if stored as network asset — skipped here to keep
    //  the service offline-safe; UI layer can pass bytes if available)

    // Colour palette (mirrors AppColors)
    const primaryColor = PdfColor.fromInt(0xFFE07800); // orange
    const bgCream = PdfColor.fromInt(0xFFFDF6EB);
    const textDark = PdfColor.fromInt(0xFF2D1B00);
    const textMid = PdfColor.fromInt(0xFF6B4226);
    const textMuted = PdfColor.fromInt(0xFFA06010);
    const successGreen = PdfColor.fromInt(0xFF00B894);
    const errorRed = PdfColor.fromInt(0xFFE17055);
    const dividerColor = PdfColor.fromInt(0xFFDCA03C);

    // ── Helper styles ────────────────────────────────────────────────────
    pw.TextStyle style(
      double size, {
      bool bold = false,
      PdfColor color = textDark,
    }) =>
        pw.TextStyle(
          font: bold ? ttfBold : ttfRegular,
          fontSize: size,
          color: color,
        );

    pw.Widget _divider({double thickness = 0.5, PdfColor color = dividerColor}) =>
        pw.Divider(thickness: thickness, color: color);

    pw.Widget _labelValue(String label, String value,
        {bool valueBold = false, PdfColor valueColor = textDark}) =>
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: style(9, color: textMid)),
            pw.Text(value,
                style: style(9, bold: valueBold, color: valueColor)),
          ],
        );

    // ── Payment status chip ─────────────────────────────────────────────
    final isVerified = invoice.paymentStatus.toLowerCase() == 'verified';
    final statusColor = isVerified ? successGreen : errorRed;

    // ── Build page ──────────────────────────────────────────────────────
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (context) => [
          // ── HEADER ──────────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: bgCream,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: dividerColor),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Logo placeholder
                pw.Container(
                  width: 56,
                  height: 56,
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      invoice.storeName.isNotEmpty
                          ? invoice.storeName[0].toUpperCase()
                          : 'S',
                      style: style(28, bold: true,
                          color: const PdfColor(1, 1, 1)),
                    ),
                  ),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(invoice.storeName,
                          style: style(18, bold: true, color: primaryColor)),
                      pw.SizedBox(height: 2),
                      pw.Text(invoice.sellerAddress,
                          style: style(8, color: textMid)),
                      if (invoice.sellerContactNumber.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('📞 ${invoice.sellerContactNumber}',
                            style: style(8, color: textMid)),
                      ],
                      if (invoice.sellerEmail.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('✉ ${invoice.sellerEmail}',
                            style: style(8, color: textMid)),
                      ],
                      if (invoice.gstin.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('GSTIN: ${invoice.gstin}',
                            style: style(8, color: textMuted)),
                      ],
                    ],
                  ),
                ),
                // Invoice title block (right-aligned)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(invoice.invoiceTitle.toUpperCase(),
                        style: style(14, bold: true, color: primaryColor)),
                    pw.SizedBox(height: 4),
                    pw.Text(invoice.invoiceNumber,
                        style: style(9, bold: true, color: textDark)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      DateFormat('dd MMM yyyy, hh:mm a')
                          .format(invoice.invoiceDate),
                      style: style(8, color: textMid),
                    ),
                    pw.SizedBox(height: 6),
                    // Payment status chip
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: statusColor,
                        borderRadius: pw.BorderRadius.circular(20),
                      ),
                      child: pw.Text(
                        invoice.paymentStatus.toUpperCase(),
                        style: style(8, bold: true,
                            color: const PdfColor(1, 1, 1)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── ORDER + CUSTOMER INFO ─────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Order details
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: dividerColor),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ORDER DETAILS',
                          style: style(9, bold: true, color: textMuted)),
                      pw.SizedBox(height: 8),
                      _labelValue('Order ID', '#${invoice.orderId}',
                          valueBold: true),
                      pw.SizedBox(height: 4),
                      _labelValue('Invoice Date',
                          DateFormat('dd MMM yyyy').format(invoice.invoiceDate)),
                      pw.SizedBox(height: 4),
                      _labelValue('Payment Method', invoice.paymentMethod),
                      if (invoice.transactionId.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        _labelValue('Transaction ID', invoice.transactionId),
                      ],
                      pw.SizedBox(height: 4),
                      _labelValue('Pickup Date',
                          '${invoice.pickupDate}  ${invoice.pickupTime}'),
                      if (invoice.trackingId.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        _labelValue('Tracking ID', invoice.trackingId),
                      ],
                      if (invoice.estimatedDeliveryTime.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        _labelValue(
                            'Est. Pickup Time', invoice.estimatedDeliveryTime),
                      ],
                      if (invoice.couponCodeUsed.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        _labelValue('Coupon Used', invoice.couponCodeUsed,
                            valueColor: successGreen),
                      ],
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              // Customer details
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: dividerColor),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILLED TO',
                          style: style(9, bold: true, color: textMuted)),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        invoice.customerName.isNotEmpty
                            ? invoice.customerName
                            : 'Customer',
                        style: style(11, bold: true),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('📞 ${invoice.customerPhone}',
                          style: style(9, color: textMid)),
                      if (invoice.customerEmail.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('✉ ${invoice.customerEmail}',
                            style: style(9, color: textMid)),
                      ],
                      pw.SizedBox(height: 6),
                      _divider(),
                      pw.SizedBox(height: 6),
                      pw.Text('PICKUP ADDRESS',
                          style: style(8, bold: true, color: textMuted)),
                      pw.SizedBox(height: 4),
                      pw.Text(invoice.deliveryAddress,
                          style: style(8.5, color: textMid)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // ── ITEMS TABLE ───────────────────────────────────────────────────
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: dividerColor),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                // Table header
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(6),
                      topRight: pw.Radius.circular(6),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                          flex: 4,
                          child: pw.Text('PRODUCT',
                              style: style(9, bold: true,
                                  color: const PdfColor(1, 1, 1)))),
                      pw.SizedBox(
                          width: 60,
                          child: pw.Text('VARIANT',
                              style: style(9, bold: true,
                                  color: const PdfColor(1, 1, 1)),
                              textAlign: pw.TextAlign.center)),
                      pw.SizedBox(
                          width: 40,
                          child: pw.Text('QTY',
                              style: style(9, bold: true,
                                  color: const PdfColor(1, 1, 1)),
                              textAlign: pw.TextAlign.center)),
                      pw.SizedBox(
                          width: 60,
                          child: pw.Text('UNIT',
                              style: style(9, bold: true,
                                  color: const PdfColor(1, 1, 1)),
                              textAlign: pw.TextAlign.right)),
                      pw.SizedBox(
                          width: 65,
                          child: pw.Text('TOTAL',
                              style: style(9, bold: true,
                                  color: const PdfColor(1, 1, 1)),
                              textAlign: pw.TextAlign.right)),
                    ],
                  ),
                ),
                // Table rows
                ...invoice.items.asMap().entries.map((e) {
                  final idx = e.key;
                  final item = e.value;
                  final rowBg = idx.isEven
                      ? const PdfColor(1, 1, 1)
                      : bgCream;
                  return pw.Container(
                    color: rowBg,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 4,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(item.productName,
                                  style: style(9, bold: true)),
                              if (item.discountPercent > 0)
                                pw.Text(
                                    '${item.discountPercent.toStringAsFixed(0)}% tier discount',
                                    style: style(7.5, color: successGreen)),
                            ],
                          ),
                        ),
                        pw.SizedBox(
                          width: 60,
                          child: pw.Text(
                            item.variantOrSize.isEmpty ? '—' : item.variantOrSize,
                            style: style(8.5, color: textMid),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.SizedBox(
                          width: 40,
                          child: pw.Text(
                            item.quantity.toString(),
                            style: style(9),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.SizedBox(
                          width: 60,
                          child: pw.Text(
                            _rupee.format(item.unitPrice),
                            style: style(9),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.SizedBox(
                          width: 65,
                          child: pw.Text(
                            _rupee.format(item.totalPrice),
                            style: style(9, bold: true),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── TOTALS BLOCK ─────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 260,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: bgCream,
                  border: pw.Border.all(color: dividerColor),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    _labelValue('Subtotal', _rupee.format(invoice.subtotal)),
                    if (invoice.discountAmount > 0) ...[
                      pw.SizedBox(height: 5),
                      _labelValue('Discount',
                          '- ${_rupee.format(invoice.discountAmount)}',
                          valueColor: successGreen),
                    ],
                    if (invoice.deliveryCharges > 0) ...[
                      pw.SizedBox(height: 5),
                      _labelValue('Delivery Charges',
                          _rupee.format(invoice.deliveryCharges)),
                    ],
                    pw.SizedBox(height: 5),
                    _labelValue(
                        'Tax (GST)', _rupee.format(invoice.taxAmount)),
                    if (invoice.walletAmountUsed > 0) ...[
                      pw.SizedBox(height: 5),
                      _labelValue('Wallet Used',
                          '- ${_rupee.format(invoice.walletAmountUsed)}',
                          valueColor: successGreen),
                    ],
                    pw.SizedBox(height: 8),
                    _divider(thickness: 1.0, color: primaryColor),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('GRAND TOTAL',
                            style: style(12, bold: true, color: primaryColor)),
                        pw.Text(_rupee.format(invoice.grandTotal),
                            style: style(13, bold: true, color: primaryColor)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── NOTES ────────────────────────────────────────────────────────
          if (invoice.returnRefundNote.isNotEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                    left: pw.BorderSide(color: primaryColor, width: 3)),
                color: const PdfColor(1.0, 0.97, 0.93),
              ),
              child: pw.Text(
                '📦 Return / Refund: ${invoice.returnRefundNote}',
                style: style(8.5, color: textMid),
              ),
            ),
          pw.SizedBox(height: 10),

          // ── FOOTER ───────────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: bgCream,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: dividerColor),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  invoice.thankYouMessage,
                  style: style(11, bold: true, color: primaryColor),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Support: ${invoice.supportContact}',
                  style: style(8.5, color: textMid),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 8),
                _divider(),
                pw.SizedBox(height: 6),
                pw.Text(
                  'This is a computer-generated invoice and does not require a signature or seal.',
                  style: style(7.5, color: textMuted),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Share / Save
  // ─────────────────────────────────────────────────────────────────────────

  /// Saves PDF to a temp file and opens the OS share sheet.
  Future<void> shareInvoice(InvoiceModel invoice) async {
    final bytes = await generatePdf(invoice);
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/${invoice.invoiceNumber}.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: '${invoice.invoiceTitle} – ${invoice.invoiceNumber}',
    );
  }

  /// Returns raw PDF bytes (useful for preview widgets).
  Future<Uint8List> getPdfBytes(InvoiceModel invoice) =>
      generatePdf(invoice);
}