/// Complete invoice data model containing all billing fields.
/// Populated from OrderModel + PaymentModel + ShopSettings + UserProfile.
class InvoiceModel {
  // ── Store / App Info ────────────────────────────────────────────
  final String storeName;
  final String storeLogoUrl; // empty → show placeholder icon
  final String sellerAddress;
  final String sellerContactNumber;
  final String sellerEmail; // optional
  final String gstin; // optional (future GST)
  final String supportContact;

  // ── Invoice Header ──────────────────────────────────────────────
  final String invoiceNumber; // e.g. "INV-20240601-0042"
  final String invoiceTitle; // "Tax Invoice" / "Order Receipt"
  final DateTime invoiceDate;

  // ── Order Info ──────────────────────────────────────────────────
  final String orderId;
  final String paymentMethod; // "UPI"
  final String paymentStatus; // "Verified" / "Pending" etc.
  final String transactionId; // UPI / payment reference

  // ── Customer Info ───────────────────────────────────────────────
  final String customerName;
  final String customerPhone;
  final String customerEmail; // optional
  final String deliveryAddress; // pickup address / slot info

  // ── Line Items ──────────────────────────────────────────────────
  final List<InvoiceItem> items;

  // ── Pricing Summary ─────────────────────────────────────────────
  final double subtotal;
  final double discountAmount;
  final double deliveryCharges;
  final double taxAmount;
  final double walletAmountUsed; // optional
  final double grandTotal;
  final String couponCodeUsed; // optional

  // ── Pickup / Delivery ───────────────────────────────────────────
  final String pickupDate;
  final String pickupTime;
  final String trackingId; // optional
  final String estimatedDeliveryTime; // optional

  // ── Notes ───────────────────────────────────────────────────────
  final String returnRefundNote;
  final String thankYouMessage;

  const InvoiceModel({
    required this.storeName,
    this.storeLogoUrl = '',
    required this.sellerAddress,
    required this.sellerContactNumber,
    this.sellerEmail = '',
    this.gstin = '',
    required this.supportContact,
    required this.invoiceNumber,
    this.invoiceTitle = 'Tax Invoice',
    required this.invoiceDate,
    required this.orderId,
    this.paymentMethod = 'UPI',
    required this.paymentStatus,
    this.transactionId = '',
    required this.customerName,
    required this.customerPhone,
    this.customerEmail = '',
    required this.deliveryAddress,
    required this.items,
    required this.subtotal,
    this.discountAmount = 0.0,
    this.deliveryCharges = 0.0,
    required this.taxAmount,
    this.walletAmountUsed = 0.0,
    required this.grandTotal,
    this.couponCodeUsed = '',
    required this.pickupDate,
    required this.pickupTime,
    this.trackingId = '',
    this.estimatedDeliveryTime = '',
    this.returnRefundNote =
        'Returns accepted within 24 hours with original packaging.',
    this.thankYouMessage = 'Thank you for shopping with us! 🛍️',
  });
}

/// A single line item on the invoice.
class InvoiceItem {
  final String productName;
  final String variantOrSize; // e.g. "1 KG", "Pack of 5"
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double discountPercent; // 0 if none

  const InvoiceItem({
    required this.productName,
    this.variantOrSize = '',
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.discountPercent = 0.0,
  });
}