import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import axios from 'axios';

// Load environment variables
const TWILIO_ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID || '';
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN || '';
const TWILIO_WHATSAPP_NUMBER = process.env.TWILIO_WHATSAPP_NUMBER || '';
const TWILIO_TEMPLATE_NAMESPACE = process.env.TWILIO_TEMPLATE_NAMESPACE || '';
const TWILIO_TEMPLATE_SID = process.env.TWILIO_TEMPLATE_SID || '';

// Alternative: WhatsApp Business API credentials
const WHATSAPP_BUSINESS_PHONE_ID = process.env.WHATSAPP_BUSINESS_PHONE_ID || '';
const WHATSAPP_BUSINESS_ACCESS_TOKEN = process.env.WHATSAPP_BUSINESS_ACCESS_TOKEN || '';
const WHATSAPP_BUSINESS_TEMPLATE_NAME = process.env.WHATSAPP_BUSINESS_TEMPLATE_NAME || '';

interface OrderData {
  id?: string;
  subtotal?: number;
  tax?: number;
  total?: number;
  items?: Array<{ productName: string; quantity: number }>;
  pickupSlot?: { date: string };
  [key: string]: any;
}

interface WhatsAppNotificationParams {
  orderId: string;
  phoneNumber: string;
  customerName: string;
  status: string;
  orderData?: OrderData;
}

interface NotificationResult {
  success: boolean;
  message: string;
  messageId?: string;
  error?: string;
}

/**
 * Get message template based on order status
 */
function getMessageTemplate(
  status: string,
  customerName: string,
  orderId: string,
  orderData?: OrderData
): string {
  const pickupDate = orderData?.pickupSlot?.date
    ? new Date(orderData.pickupSlot.date).toLocaleDateString('en-IN')
    : 'Soon';
  const total = orderData?.total || 0;

  switch (status.toLowerCase()) {
    case 'confirmed':
      return `Hi ${customerName},\n\n✅ Order Confirmed!\n\nYour payment has been verified.\n\nOrder ID: ${orderId}\nTotal Amount: ₹${total}\nPickup Date: ${pickupDate}\n\nWe'll start preparing your order now. You'll get another update when it's ready!\n\nThank you for ordering from SLVH Smart Shop!`;

    case 'readyforpickup':
    case 'ready':
      return `Hi ${customerName},\n\n📦 Ready for Pickup!\n\nYour order is ready and waiting for you.\n\nOrder ID: ${orderId}\nPickup Date: ${pickupDate}\n\nPlease come pick up your order at your earliest convenience.\n\nThank you!`;

    case 'preparing':
      return `Hi ${customerName},\n\n🍳 Preparing Your Order\n\nWe're currently preparing your order.\n\nOrder ID: ${orderId}\n\nWe'll notify you once it's ready for pickup.\n\nThank you!`;

    case 'completed':
      return `Hi ${customerName},\n\n✓ Order Completed\n\nThank you for your order!\n\nOrder ID: ${orderId}\n\nWe hope you enjoyed your experience at SLVH Smart Shop. Looking forward to seeing you again!\n\nFeedback? Reply to this message or visit our website.`;

    case 'cancelled':
      return `Hi ${customerName},\n\n❌ Order Cancelled\n\nYour order has been cancelled.\n\nOrder ID: ${orderId}\n\nIf you have any questions, please contact us.\n\nThank you!`;

    default:
      return `Hi ${customerName},\n\nOrder Update\n\nOrder ID: ${orderId}\nStatus: ${status}\n\nThank you!`;
  }
}

/**
 * Send WhatsApp message via Twilio
 * Twilio is recommended for development/testing
 */
async function sendViaTwilio(
  phoneNumber: string,
  message: string
): Promise<NotificationResult> {
  try {
    if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN) {
      console.warn('Twilio credentials not configured, skipping WhatsApp send');
      return {
        success: false,
        message: 'Twilio credentials not configured',
        error: 'TWILIO_ACCOUNT_SID or TWILIO_AUTH_TOKEN missing',
      };
    }

    // Normalize phone number (Twilio expects format: +country_code phone_number)
    let normalizedPhone = phoneNumber;
    if (!normalizedPhone.startsWith('+')) {
      normalizedPhone = '+91' + normalizedPhone.replace(/\D/g, '');
    }

    const url = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`;

    const response = await axios.post(
      url,
      {
        From: `whatsapp:${TWILIO_WHATSAPP_NUMBER}`,
        To: `whatsapp:${normalizedPhone}`,
        Body: message,
      },
      {
        auth: {
          username: TWILIO_ACCOUNT_SID,
          password: TWILIO_AUTH_TOKEN,
        },
      }
    );

    console.log(`WhatsApp message sent via Twilio to ${normalizedPhone}`, response.data.sid);

    return {
      success: true,
      message: 'WhatsApp message sent successfully',
      messageId: response.data.sid,
    };
  } catch (error) {
    console.error('Error sending via Twilio:', error);
    return {
      success: false,
      message: 'Failed to send WhatsApp via Twilio',
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Send WhatsApp message via WhatsApp Business API
 * More scalable for production use
 */
async function sendViaWhatsAppBusinessAPI(
  phoneNumber: string,
  message: string,
  customerName: string
): Promise<NotificationResult> {
  try {
    if (!WHATSAPP_BUSINESS_PHONE_ID || !WHATSAPP_BUSINESS_ACCESS_TOKEN) {
      console.warn(
        'WhatsApp Business API credentials not configured, trying Twilio instead'
      );
      return sendViaTwilio(phoneNumber, message);
    }

    // Normalize phone number (WhatsApp API expects without + sign)
    let normalizedPhone = phoneNumber.replace(/\D/g, '');
    if (!normalizedPhone.startsWith('91')) {
      normalizedPhone = '91' + normalizedPhone;
    }

    const url = `https://graph.instagram.com/v18.0/${WHATSAPP_BUSINESS_PHONE_ID}/messages`;

    // Note: For production, use pre-approved message templates
    // This example sends a simple text message for development
    const response = await axios.post(
      url,
      {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: normalizedPhone,
        type: 'text',
        text: {
          preview_url: false,
          body: message,
        },
      },
      {
        headers: {
          Authorization: `Bearer ${WHATSAPP_BUSINESS_ACCESS_TOKEN}`,
          'Content-Type': 'application/json',
        },
      }
    );

    console.log(
      `WhatsApp message sent via Business API to ${normalizedPhone}`,
      response.data.messages[0].id
    );

    return {
      success: true,
      message: 'WhatsApp message sent successfully',
      messageId: response.data.messages[0].id,
    };
  } catch (error) {
    console.error('Error sending via WhatsApp Business API:', error);

    // Fallback to Twilio if WhatsApp API fails
    console.log('Falling back to Twilio...');
    return sendViaTwilio(phoneNumber, message);
  }
}

/**
 * Main function to send WhatsApp notification
 * Handles both Twilio and WhatsApp Business API with fallback
 */
export async function sendWhatsAppNotification(
  params: WhatsAppNotificationParams
): Promise<NotificationResult> {
  const { orderId, phoneNumber, customerName, status, orderData } = params;

  try {
    console.log(`Sending WhatsApp notification for order ${orderId} to ${phoneNumber}`);

    // Generate message based on status
    const message = getMessageTemplate(status, customerName, orderId, orderData);

    // Try WhatsApp Business API first (if configured), fallback to Twilio
    let result: NotificationResult;

    if (WHATSAPP_BUSINESS_PHONE_ID && WHATSAPP_BUSINESS_ACCESS_TOKEN) {
      result = await sendViaWhatsAppBusinessAPI(phoneNumber, message, customerName);
    } else {
      result = await sendViaTwilio(phoneNumber, message);
    }

    // Log to Firestore for audit trail
    if (result.success) {
      await admin.firestore().collection('whatsapp_logs').add({
        orderId,
        phoneNumber,
        customerName,
        status,
        messageId: result.messageId,
        sentAt: new Date(),
        sentVia: WHATSAPP_BUSINESS_PHONE_ID ? 'whatsapp-business-api' : 'twilio',
        status: 'success',
      });
    } else {
      await admin.firestore().collection('whatsapp_logs').add({
        orderId,
        phoneNumber,
        customerName,
        status,
        sentAt: new Date(),
        sentVia: WHATSAPP_BUSINESS_PHONE_ID ? 'whatsapp-business-api' : 'twilio',
        status: 'failed',
        error: result.error,
      });
    }

    return result;
  } catch (error) {
    console.error('Error in sendWhatsAppNotification:', error);

    // Log error to Firestore
    await admin.firestore().collection('whatsapp_logs').add({
      orderId,
      phoneNumber,
      customerName,
      status,
      sentAt: new Date(),
      status: 'error',
      error: error instanceof Error ? error.message : 'Unknown error',
    });

    return {
      success: false,
      message: 'Failed to send WhatsApp notification',
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Retry failed WhatsApp messages
 * Can be called manually or scheduled via Cloud Scheduler
 */
export async function retryFailedWhatsAppMessages(): Promise<void> {
  try {
    const failedLogs = await admin
      .firestore()
      .collection('whatsapp_logs')
      .where('status', '==', 'failed')
      .where('retryCount', '<', 3)
      .limit(10)
      .get();

    console.log(`Found ${failedLogs.docs.length} failed messages to retry`);

    for (const doc of failedLogs.docs) {
      const logData = doc.data();

      const result = await sendWhatsAppNotification({
        orderId: logData.orderId,
        phoneNumber: logData.phoneNumber,
        customerName: logData.customerName,
        status: logData.status,
      });

      if (!result.success) {
        // Increment retry count
        await doc.ref.update({
          retryCount: (logData.retryCount || 0) + 1,
          lastRetryAt: new Date(),
        });
      } else {
        // Mark as successful
        await doc.ref.update({
          status: 'success',
          messageId: result.messageId,
        });
      }
    }
  } catch (error) {
    console.error('Error in retryFailedWhatsAppMessages:', error);
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// FCM (Firebase Cloud Messaging) PUSH NOTIFICATIONS
// ════════════════════════════════════════════════════════════════════════════════

interface FCMNotificationParams {
  title: string;
  body: string;
  orderId?: string;
  customerId?: string;
  [key: string]: any;
}

/**
 * Send FCM push notification to a specific device
 * Used for admin alerts and customer order updates
 */
export async function sendFCMNotification(
  fcmToken: string,
  params: FCMNotificationParams
): Promise<NotificationResult> {
  try {
    if (!fcmToken) {
      console.warn('FCM token is empty, cannot send notification');
      return {
        success: false,
        message: 'FCM token is empty',
        error: 'No FCM token provided',
      };
    }

    const { title, body, orderId, customerId, ...additionalData } = params;

    const message = {
      notification: {
        title,
        body,
      },
      data: {
        ...(orderId && { orderId }),
        ...(customerId && { customerId }),
        ...additionalData,
      },
      token: fcmToken,
    };

    const response = await admin.messaging().send(message);
    console.log(`FCM notification sent successfully: ${response}`);

    // Log to Firestore for audit trail
    await admin.firestore().collection('fcm_notifications_log').add({
      fcmToken: fcmToken.substring(0, 20) + '...', // Log partial token for privacy
      title,
      body,
      orderId,
      customerId,
      status: 'success',
      messageId: response,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: 'FCM notification sent successfully',
      messageId: response,
    };
  } catch (error) {
    console.error('Error sending FCM notification:', error);

    // Log error to Firestore
    await admin.firestore().collection('fcm_notifications_log').add({
      fcmToken: fcmToken.substring(0, 20) + '...',
      title: params.title,
      body: params.body,
      orderId: params.orderId,
      customerId: params.customerId,
      status: 'failed',
      error: error instanceof Error ? error.message : 'Unknown error',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: false,
      message: 'Failed to send FCM notification',
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Send FCM notification to admin for new order alert
 * Fetches admin's FCM token from users collection and sends alert
 */
export async function sendAdminNewOrderAlert(orderData: {
  orderId: string;
  customerId: string;
  customerName?: string;
  total?: number;
  itemCount?: number;
}): Promise<NotificationResult> {
  try {
    console.log(`Preparing admin alert for new order: ${orderData.orderId}`);

    // Find admin user (user with role: "admin")
    const adminQuery = await admin
      .firestore()
      .collection('users')
      .where('role', '==', 'admin')
      .limit(1)
      .get();

    if (adminQuery.empty) {
      console.warn('No admin user found in database');
      return {
        success: false,
        message: 'Admin user not found',
        error: 'No user with role=admin in database',
      };
    }

    const adminDoc = adminQuery.docs[0];
    const adminData = adminDoc.data();
    const adminFCMToken = adminData?.fcmToken;

    if (!adminFCMToken) {
      console.warn(`Admin user ${adminDoc.id} has no FCM token configured`);
      return {
        success: false,
        message: 'Admin FCM token not configured',
        error: 'Admin user does not have an FCM token',
      };
    }

    console.log(`Sending new order alert to admin ${adminDoc.id}`);

    // Prepare notification payload
    const title = '🆕 New Order Received!';
    const body = `Order ${orderData.orderId} from customer ${
      orderData.customerName || orderData.customerId
    } - ₹${orderData.total || 0}`;

    const result = await sendFCMNotification(adminFCMToken, {
      title,
      body,
      orderId: orderData.orderId,
      customerId: orderData.customerId,
      customerName: orderData.customerName,
      total: String(orderData.total || 0),
      itemCount: String(orderData.itemCount || 0),
      notificationType: 'new_order_alert',
    });

    if (result.success) {
      console.log(`✅ Admin alert sent for order ${orderData.orderId}`);
    } else {
      console.error(`❌ Failed to send admin alert for order ${orderData.orderId}`);
    }

    return result;
  } catch (error) {
    console.error('Error in sendAdminNewOrderAlert:', error);

    // Log error to Firestore
    await admin.firestore().collection('fcm_notifications_log').add({
      orderId: orderData.orderId,
      customerId: orderData.customerId,
      status: 'error',
      error: error instanceof Error ? error.message : 'Unknown error',
      notificationType: 'new_order_alert',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: false,
      message: 'Failed to send admin new order alert',
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}
