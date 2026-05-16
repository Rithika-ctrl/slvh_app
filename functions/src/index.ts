import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { sendWhatsAppNotification } from './notifications';
import { sendAdminNewOrderAlert } from './notifications';

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Cloud Function: Trigger on new order creation
 * Sends FCM push notification to admin when a new order arrives
 * 
 * Purpose: Alert vendor immediately of new orders to enable quick verification
 * and order processing, preventing customer dissatisfaction from delayed response
 */
export const onOrderCreate = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    try {
      const orderData = snap.data();
      const orderId = context.params.orderId;

      console.log(`📦 New order created: ${orderId}`);
      console.log(`   Customer: ${orderData.customerId}`);
      console.log(`   Total: ₹${orderData.total}`);

      // Get customer details for the alert message
      const customerDoc = await admin
        .firestore()
        .collection('users')
        .doc(orderData.customerId)
        .get();

      const customerName = customerDoc.data()?.name || orderData.customerId;

      // Send FCM notification to admin
      const result = await sendAdminNewOrderAlert({
        orderId,
        customerId: orderData.customerId,
        customerName,
        total: orderData.total,
        itemCount: (orderData.items?.length || 0),
      });

      if (result.success) {
        console.log(`✅ Admin notification sent for order ${orderId}`);
        return {
          success: true,
          message: `Admin notified of new order ${orderId}`,
          orderId,
        };
      } else {
        console.error(`❌ Failed to notify admin for order ${orderId}: ${result.error}`);
        return {
          success: false,
          message: `Failed to notify admin: ${result.error}`,
          orderId,
        };
      }
    } catch (error) {
      console.error('Error in onOrderCreate:', error);
      return {
        success: false,
        message: 'Error processing new order notification',
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  });

/**
 * Cloud Function: Trigger on order status change
 * Sends WhatsApp message to customer when order is confirmed or ready for pickup
 */
export const onOrderStatusChanged = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const orderId = context.params.orderId;

      // Only proceed if status changed
      if (before.status === after.status) {
        return { success: false, message: 'Status did not change' };
      }

      console.log(`Order ${orderId} status changed from ${before.status} to ${after.status}`);

      // Get customer details from users collection
      const userDoc = await admin
        .firestore()
        .collection('users')
        .doc(after.customerId)
        .get();

      if (!userDoc.exists) {
        console.error(`User ${after.customerId} not found`);
        return { success: false, message: 'User not found' };
      }

      const userData = userDoc.data();
      const phoneNumber = userData?.phone || after.customerId;
      const userName = userData?.name || 'Customer';

      // Send WhatsApp notification for specific statuses
      const statuses = ['confirmed', 'readyForPickup'];
      if (!statuses.includes(after.status)) {
        return { success: false, message: `Status ${after.status} does not trigger WhatsApp` };
      }

      const result = await sendWhatsAppNotification({
        orderId,
        phoneNumber,
        customerName: userName,
        status: after.status,
        orderData: after,
      });

      return result;
    } catch (error) {
      console.error('Error in onOrderStatusChanged:', error);
      return {
        success: false,
        message: 'Error sending WhatsApp notification',
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  });

/**
 * Cloud Function: Trigger on product stock change
 * Sends alert notification when product stock falls below threshold
 */
export const onProductStockLow = functions.firestore
  .document('products/{productId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const productId = context.params.productId;

      // Only proceed if stock changed
      if (before.stock === after.stock) {
        return { success: false, message: 'Stock did not change' };
      }

      console.log(
        `Product ${productId} stock changed from ${before.stock} to ${after.stock}`
      );

      // Get low stock threshold from app_settings
      const settingsDoc = await admin
        .firestore()
        .collection('app_settings')
        .doc('inventory')
        .get();

      const lowStockThreshold = settingsDoc.data()?.lowStockThreshold || 10;

      // Check if stock crossed threshold (either falling below or rising above)
      const wasBelowThreshold = before.stock <= lowStockThreshold;
      const isNowBelowThreshold = after.stock <= lowStockThreshold;
      const isOutOfStock = after.stock === 0;

      // Only alert if stock is now low or out of stock
      if (isNowBelowThreshold && after.stock !== before.stock) {
        // Log low stock event
        await admin.firestore().collection('low_stock_alerts').add({
          productId,
          productName: after.name,
          currentStock: after.stock,
          threshold: lowStockThreshold,
          isOutOfStock,
          previousStock: before.stock,
          alertSentAt: admin.firestore.FieldValue.serverTimestamp(),
          alertLevel: isOutOfStock ? 'out_of_stock' : 'low_stock',
        });

        console.log(
          `Low stock alert created for product ${productId}: ${after.stock} units remaining`
        );

        // TODO: Send notification to admin via push notification or WhatsApp
        // This can be extended to send admin alerts via FCM or WhatsApp
      }

      return { success: true, message: 'Stock update processed' };
    } catch (error) {
      console.error('Error in onProductStockLow:', error);
      return {
        success: false,
        message: 'Error processing stock change',
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  });

/**
 * Cloud Function: Manual trigger for testing
 * POST /sendTestWhatsApp?phoneNumber=+91XXXXXXXXXX&status=confirmed
 */
export const sendTestWhatsApp = functions.https.onRequest(async (req, res) => {
  try {
    const { phoneNumber, status } = req.query;

    if (!phoneNumber || !status) {
      res.status(400).json({
        success: false,
        message: 'Missing phoneNumber or status parameter',
      });
      return;
    }

    const result = await sendWhatsAppNotification({
      orderId: 'TEST-ORDER-123',
      phoneNumber: phoneNumber as string,
      customerName: 'Test Customer',
      status: status as string,
      orderData: {
        id: 'TEST-ORDER-123',
        subtotal: 500,
        tax: 25,
        total: 525,
        items: [{ productName: 'Test Product', quantity: 1 }],
        pickupSlot: { date: new Date().toISOString() },
      },
    });

    res.json(result);
  } catch (error) {
    console.error('Error in sendTestWhatsApp:', error);
    res.status(500).json({
      success: false,
      message: 'Error sending test WhatsApp',
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

/**
 * Cloud Function: Health check
 */
export const healthCheck = functions.https.onRequest(async (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    functions: ['onOrderStatusChanged', 'onProductStockLow', 'sendTestWhatsApp', 'healthCheck'],
  });
});
