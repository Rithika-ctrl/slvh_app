import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { sendWhatsAppNotification } from './notifications';

// Initialize Firebase Admin SDK
admin.initializeApp();

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
 * Cloud Function: Manual trigger for testing
 * POST /sendTestWhatsApp?phoneNumber=+91XXXXXXXXXX&status=confirmed
 */
export const sendTestWhatsApp = functions.https.onRequest(async (req, res) => {
  try {
    const { phoneNumber, status } = req.query;

    if (!phoneNumber || !status) {
      return res.status(400).json({
        success: false,
        message: 'Missing phoneNumber or status parameter',
      });
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

    return res.json(result);
  } catch (error) {
    console.error('Error in sendTestWhatsApp:', error);
    return res.status(500).json({
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
    functions: ['onOrderStatusChanged', 'sendTestWhatsApp', 'healthCheck'],
  });
});
