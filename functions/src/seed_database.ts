/**
 * SLVH Firestore Seed Script
 *
 * Field names are taken directly from the Dart model fromFirestore() methods
 * in the Flutter source. Do NOT change field names here without also changing
 * the corresponding Dart model.
 *
 * Usage:
 *   cd functions
 *   npm install
 *   $env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\service-account.json"
 *   npm run seed:database          # full seed (all collections)
 *   npm run seed:database:core     # core only (settings, app_settings, categories)
 *
 * Add to functions/package.json scripts:
 *   "seed:database": "npm run build && node lib/seed_database.js",
 *   "seed:database:core": "npm run build && node lib/seed_database.js --core-only"
 */

import * as admin from 'firebase-admin';

const args = process.argv.slice(2);
const coreOnly = args.includes('--core-only');
const projectOverride = args.find(a => a.startsWith('--project='))?.split('=')[1];

const PROJECT_ID = projectOverride ?? 'slvh-b707f';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const db = admin.firestore();
const now = admin.firestore.FieldValue.serverTimestamp();

// ─── Helpers ────────────────────────────────────────────────────────────────

async function upsert(
  ref: admin.firestore.DocumentReference,
  data: Record<string, unknown>,
  label: string
) {
  await ref.set(data, { merge: true });
  console.log(`  ✅  ${label}`);
}

// ─── Core seed ──────────────────────────────────────────────────────────────

async function seedCore() {
  console.log('\n── Core collections ─────────────────────────────────────');

  // settings/default
  // Fields match ShopSettingsModel.fromFirestore() in:
  //   lib/features/settings/models/shop_settings_model.dart
  await upsert(db.collection('settings').doc('default'), {
    open_time: 9,
    close_time: 21,
    pickup_start: 9,
    delay_hours: 1,
    slot_duration: 30,
    slot_capacity: 5,
    upi_id: '',           // ← fill in your UPI ID before going live
    upi_qr_image: '',     // ← fill in QR image URL before going live
    min_order_value: 100,
    holiday_mode: false,
    order_pause: false,
    low_stock_threshold: 10,
    cancel_window_minutes: 30,
    updated_at: now,
  }, 'settings/default');

  // app_settings/inventory
  // Fields match InventoryService.getLowStockThreshold() in:
  //   lib/features/inventory/services/inventory_service.dart
  await upsert(db.collection('app_settings').doc('inventory'), {
    lowStockThreshold: 10,
  }, 'app_settings/inventory');

  // categories — at least one required before products can be added
  // Fields match CategoryModel.fromFirestore() in:
  //   lib/features/categories/models/category_model.dart
  const catRef = db.collection('categories');
  const sampleCategories = [
    { name: 'Groceries',  description: 'Daily grocery items', imageUrl: '', sortOrder: 1 },
    { name: 'Dairy',      description: 'Milk, curd, paneer',  imageUrl: '', sortOrder: 2 },
    { name: 'Vegetables', description: 'Fresh vegetables',   imageUrl: '', sortOrder: 3 },
    { name: 'Fruits',     description: 'Fresh fruits',       imageUrl: '', sortOrder: 4 },
  ];
  for (const cat of sampleCategories) {
    const existing = await catRef.where('name', '==', cat.name).limit(1).get();
    if (existing.empty) {
      await catRef.add({ ...cat, createdAt: now, updatedAt: now });
      console.log(`  ✅  categories/${cat.name}`);
    } else {
      console.log(`  ⏭   categories/${cat.name} already exists`);
    }
  }
}

// ─── Full schema seed ────────────────────────────────────────────────────────

async function seedFullSchema() {
  console.log('\n── Schema placeholder documents ─────────────────────────');
  console.log('    (isSchemaPlaceholder: true — safe to delete after going live)\n');

  const PLACEHOLDER = { isSchemaPlaceholder: true, createdAt: now };

  // products + pricing_tiers subcollection
  // Fields match ProductModel.fromFirestore() in:
  //   lib/features/products/models/product_model.dart
  const productRef = db.collection('products').doc('_schema_placeholder');
  await upsert(productRef, {
    ...PLACEHOLDER,
    name: '_schema_placeholder',
    name_lowercase: '_schema_placeholder',
    description: '',
    price: 0,
    discountPrice: null,
    images: [],
    categoryId: '',
    stock: 0,
    unitType: '',
    unit_label: '',
    max_order_qty: null,
    isActive: false,
    rating: null,
    reviewCount: null,
    updatedAt: now,
  }, 'products/_schema_placeholder');

  // pricing_tiers subcollection
  // Fields match PricingTierModel.fromFirestore() in:
  //   lib/features/products/models/pricing_tier_model.dart
  await upsert(productRef.collection('pricing_tiers').doc('_schema_placeholder'), {
    ...PLACEHOLDER,
    quantity: 0,
    unit: '',
    price: 0,
    isDefault: false,
    updatedAt: now,
  }, 'products/_schema_placeholder/pricing_tiers/_schema_placeholder');

  // banners
  // Fields match BannerModel.fromFirestore() in:
  //   lib/features/banners/models/banner_model.dart
  await upsert(db.collection('banners').doc('_schema_placeholder'), {
    ...PLACEHOLDER,
    imageUrl: '',
    deeplink: null,
    isActive: false,
    sortOrder: 999,
    updatedAt: now,
  }, 'banners/_schema_placeholder');

  // orders
  // Fields match OrderModel.fromFirestore() in:
  //   lib/features/orders/models/order_model.dart
  await upsert(db.collection('orders').doc('_schema_placeholder'), {
    ...PLACEHOLDER,
    customerId: '',
    items: [],
    subtotal: 0,
    tax: 0,
    total: 0,
    status: 'pendingPayment',
    paymentId: null,
    paymentStatus: null,
    paymentReference: null,
    retryCount: 0,
    pickupDate: '',
    pickupTime: '',
    pickupSlotId: '',
    cancellationReason: null,
    updatedAt: now,
    lastRetryAt: null,
    cancelledAt: null,
    completedAt: null,
  }, 'orders/_schema_placeholder');

  // payments
  // Fields match PaymentModel.fromFirestore() in:
  //   lib/features/payments/models/payment_model.dart
  await upsert(db.collection('payments').doc('_schema_placeholder'), {
    ...PLACEHOLDER,
    orderId: '',
    upiId: '',
    amount: 0,
    customerPhone: '',
    screenshotUrl: null,
    status: 'pending',
    rejectionReason: null,
    verifiedAt: null,
    updatedAt: now,
  }, 'payments/_schema_placeholder');

  // slots/{date}/times subcollection
  // NOTE: The Flutter app uses collection name 'slots' (NOT 'pickup_slots').
  // See: lib/features/pickup_slots/services/slot_service.dart
  //      static const String _slotsCollection = 'slots';
  // Fields match PickupSlotModel.fromFirestore() in:
  //   lib/features/pickup_slots/models/slot_model.dart
  const slotDateRef = db.collection('slots').doc('_schema_placeholder');
  await upsert(slotDateRef, { ...PLACEHOLDER }, 'slots/_schema_placeholder');
  await upsert(slotDateRef.collection('times').doc('_schema_placeholder'), {
    ...PLACEHOLDER,
    date: '',
    hour: 0,
    minute: 0,
    slotCapacity: 5,
    bookingCount: 0,
    updatedAt: now,
  }, 'slots/_schema_placeholder/times/_schema_placeholder');

  // notifications
  // Fields match NotificationModel.fromFirestore() in:
  //   lib/features/notifications/models/notification_model.dart
  await upsert(db.collection('notifications').doc('_schema_placeholder'), {
    ...PLACEHOLDER,
    id: '_schema_placeholder',
    userId: '',
    title: '',
    body: '',
    orderId: null,
    orderStatus: null,
    isRead: false,
    actionUrl: null,
  }, 'notifications/_schema_placeholder');

  // reviews
  // Fields match ReviewModel.fromFirestore() in:
  //   lib/features/reviews/models/review_model.dart
  //   NOTE: uses snake_case keys (product_id, user_id, order_id, created_at, updated_at)
  await upsert(db.collection('reviews').doc('_schema_placeholder'), {
    ...PLACEHOLDER,
    product_id: '',
    user_id: '',
    order_id: '',
    rating: 0,
    comment: '',
    created_at: now,
    updated_at: null,
  }, 'reviews/_schema_placeholder');

  // analytics
  // Fields match analytics_aggregator.ts Cloud Function output
  await upsert(db.collection('analytics').doc('_schema_placeholder'), {
    ...PLACEHOLDER,
    revenue: 0,
    orderCount: 0,
    avgOrderValue: 0,
    bestSellers: [],
    categoryRevenue: {},
    updatedAt: now,
  }, 'analytics/_schema_placeholder');

  // analytics monthly subcollection
  await upsert(
    db.collection('analytics').doc('_meta')
      .collection('monthly').doc('_schema_placeholder'),
    { ...PLACEHOLDER, revenue: 0, orderCount: 0, avgOrderValue: 0, updatedAt: now },
    'analytics/_meta/monthly/_schema_placeholder'
  );

  // low_stock_alerts
  // Fields match src/index.ts Cloud Function output
  await upsert(db.collection('low_stock_alerts').doc('_schema_placeholder'), {
    ...PLACEHOLDER,
    productId: '',
    productName: '',
    currentStock: 0,
    threshold: 10,
    isOutOfStock: false,
    previousStock: 0,
    alertSentAt: now,
    alertLevel: 'low_stock',
  }, 'low_stock_alerts/_schema_placeholder');

  // fcm_notifications_log
  // Fields match src/notifications.ts Cloud Function output
  await upsert(db.collection('fcm_notifications_log').doc('_schema_placeholder'), {
    ...PLACEHOLDER,
    fcmToken: '',
    title: '',
    body: '',
    orderId: '',
    customerId: '',
    status: 'success',
    messageId: null,
    sentAt: now,
  }, 'fcm_notifications_log/_schema_placeholder');

  // whatsapp_logs
  // Fields match src/notifications.ts Cloud Function output
  await upsert(db.collection('whatsapp_logs').doc('_schema_placeholder'), {
    ...PLACEHOLDER,
    orderId: '',
    phoneNumber: '',
    customerName: '',
    status: '',
    sentAt: now,
    sentVia: 'whatsapp-business-api',
    messageId: null,
    error: null,
  }, 'whatsapp_logs/_schema_placeholder');

  // stock_adjustments
  // Fields match InventoryService.adjustStock() in:
  //   lib/features/inventory/services/inventory_service.dart
  await upsert(db.collection('stock_adjustments').doc('_schema_placeholder'), {
    ...PLACEHOLDER,
    productId: '',
    quantityChange: 0,
    reason: '',
    adminId: '',
    timestamp: now,
  }, 'stock_adjustments/_schema_placeholder');
}

// ─── Main ────────────────────────────────────────────────────────────────────

async function main() {
  console.log(`\nSLVH Firestore seed — project: ${PROJECT_ID}`);
  if (coreOnly) {
    console.log('Mode: core only');
  } else {
    console.log('Mode: full schema');
  }

  try {
    await seedCore();
    if (!coreOnly) {
      await seedFullSchema();
    }
    console.log('\n✅  Seed complete.\n');

    if (!coreOnly) {
      console.log('⚠️   Placeholder docs have isSchemaPlaceholder: true.');
      console.log('     Delete them once real data exists, or leave them — they are harmless.\n');
    }

    console.log('⚠️   Before going live, update these fields in settings/default:');
    console.log('     upi_id      — your actual UPI ID (e.g. yourshop@upi)');
    console.log('     upi_qr_image — Firebase Storage URL of your QR code image\n');

  } catch (err) {
    console.error('\n❌  Seed failed:', err);
    process.exit(1);
  }
}

main();