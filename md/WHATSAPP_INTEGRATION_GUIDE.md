# WhatsApp Notifications Integration Guide

## Overview
This guide covers setting up WhatsApp notifications for the SLVH Smart Shop app. When an order is confirmed or ready for pickup, customers receive a WhatsApp message via Firebase Cloud Functions.

## Architecture

```
Order Status Updated (Firestore)
         ↓
Firestore Trigger
         ↓
Firebase Cloud Function (onOrderStatusChanged)
         ↓
Check Status (confirmed or readyForPickup?)
         ↓
Fetch customer phone number from users collection
         ↓
Send WhatsApp message (Twilio or WhatsApp Business API)
         ↓
Log to whatsapp_logs collection for audit trail
         ↓
Success/Failure handling with retry logic
```

## File Structure

```
functions/
├── package.json           # Node.js dependencies
├── tsconfig.json          # TypeScript configuration
├── .env.example          # Environment variables template
├── src/
│   ├── index.ts          # Main entry point with Cloud Functions
│   └── notifications.ts  # WhatsApp sending logic
└── lib/                  # Compiled JavaScript (auto-generated)
```

## Prerequisites

### 1. Firebase Project Setup
- Firebase project created and Cloud Functions enabled
- Firestore database initialized
- Service account key downloaded

### 2. Node.js Environment
- Node.js 18+ installed
- npm or yarn package manager
- Firebase CLI installed: `npm install -g firebase-tools`

### 3. Twilio Account (For Development)
- Create free account at https://www.twilio.com
- Get Twilio WhatsApp sandbox number
- Note: Twilio sandbox requires sender to opt-in to messages

### 4. WhatsApp Business API (For Production)
- Facebook/Meta Business account
- WhatsApp Business App registered
- Business phone number verified
- Access token generated
- Message templates approved by Meta

---

## Setup Guide

### Step 1: Set Up Firebase Functions Locally

```bash
# Navigate to project root
cd C:\Users\sanja\OneDrive\Desktop\SLVH

# Initialize Firebase Functions (if not done)
firebase init functions --project=your-project-id

# Install dependencies
cd functions
npm install

# Build TypeScript
npm run build
```

### Step 2: Configure Twilio (Easiest for Development)

#### 2.1 Create Twilio Account
1. Go to https://www.twilio.com/console
2. Sign up for free account
3. Navigate to "Messaging" → "Sandbox" → "WhatsApp"
4. Copy your sandbox phone number (e.g., `whatsapp:+1415224XXXX`)

#### 2.2 Get Twilio Credentials
1. Go to Account Settings
2. Copy:
   - **Account SID**: Found in main console (acXXXXXXX...)
   - **Auth Token**: Found in main console
3. These are your `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN`

#### 2.3 Set Environment Variables
```bash
# In functions/.env (Firebase Functions config)
firebase functions:config:set twilio.account_sid="your_account_sid"
firebase functions:config:set twilio.auth_token="your_auth_token"
firebase functions:config:set twilio.whatsapp_number="whatsapp:+1415224XXXX"
```

Or for local testing, create `.env.local`:
```
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_WHATSAPP_NUMBER=whatsapp:+1415224XXXX
```

### Step 3: Configure WhatsApp Business API (Production)

#### 3.1 Register WhatsApp Business Account
1. Go to Meta for Developers: https://developers.facebook.com
2. Create Meta Business account if needed
3. Go to "Apps" → "Create App" → Select "WhatsApp Business" template
4. Register your business phone number
5. Complete verification steps

#### 3.2 Get WhatsApp Credentials
1. In App Dashboard, go to "WhatsApp" → "Getting Started"
2. Copy:
   - **Phone Number ID**: Format like `102XXXXXXXXXXXX`
   - **Business Account ID**: Format like `w_XXXXXXXXXXXXX`
3. Create Access Token:
   - Go to "Settings" → "User Tokens"
   - Create token with `whatsapp_business_messaging` permission
   - Copy the **Access Token**

#### 3.3 Create Message Templates
1. In WhatsApp App Dashboard, go to "Message Templates"
2. Create template named "order_status_update"
3. Example template:
   ```
   Hi {{1}},
   
   Your order {{2}} status is now: {{3}}
   ```
4. Submit for Meta approval (usually approved within 1 hour)
5. Once approved, note the template SID

#### 3.4 Set Environment Variables
```bash
firebase functions:config:set whatsapp.business_phone_id="102XXXXXXXXXXXX"
firebase functions:config:set whatsapp.business_access_token="your_access_token"
firebase functions:config:set whatsapp.business_template_name="order_status_update"
```

---

## Firestore Schema

### whatsapp_logs Collection
Stores audit trail of all WhatsApp messages sent:

```
whatsapp_logs/{logId}
├── orderId: String              # Reference to order
├── phoneNumber: String          # Customer phone
├── customerName: String         # Customer name
├── status: String               # Order status
├── messageId: String            # Twilio/WhatsApp message ID
├── sentAt: Timestamp            # When message was sent
├── sentVia: String              # "twilio" or "whatsapp-business-api"
├── status: String               # "success", "failed", "error"
├── error: String                # Error message if failed
├── retryCount: Number           # Number of retry attempts
└── lastRetryAt: Timestamp       # Last retry time
```

### Required Fields in users Collection
```
users/{phoneNumber}
├── phone: String                # Phone number (includes country code)
├── name: String                 # Customer name
├── fcmToken: String             # For push notifications
├── whatsappNotificationsEnabled: Boolean  # User preference
└── ...
```

---

## Cloud Functions Reference

### 1. onOrderStatusChanged
**Trigger:** Firestore `orders/{orderId}` document update
**What it does:**
- Listens for order status changes
- Sends WhatsApp when status is "confirmed" or "readyForPickup"
- Logs to whatsapp_logs collection
- Handles errors gracefully

**Parameters from Firestore:**
```
orders/{orderId}
├── status: String               # "confirmed", "readyForPickup", etc.
├── customerId: String           # User phone number
├── subtotal, tax, total: Number
├── items: Array
└── pickupSlot: Object
```

### 2. sendTestWhatsApp
**Trigger:** HTTPS POST request
**What it does:**
- Allows manual testing of WhatsApp function
- Does not require an actual order

**Usage:**
```bash
curl "https://region-projectid.cloudfunctions.net/sendTestWhatsApp?phoneNumber=%2B919876543210&status=confirmed"
```

**Response:**
```json
{
  "success": true,
  "message": "WhatsApp message sent successfully",
  "messageId": "wamid.XXXX"
}
```

### 3. healthCheck
**Trigger:** HTTPS GET request
**What it does:**
- Verifies Cloud Functions deployment is working

**Usage:**
```bash
curl https://region-projectid.cloudfunctions.net/healthCheck
```

---

## Message Templates

Messages are automatically generated based on order status:

### Confirmed
```
Hi [Customer Name],

✅ Order Confirmed!

Your payment has been verified.

Order ID: [ID]
Total Amount: ₹[Amount]
Pickup Date: [Date]

We'll start preparing your order now. You'll get another update when it's ready!

Thank you for ordering from SLVH Smart Shop!
```

### Ready for Pickup
```
Hi [Customer Name],

📦 Ready for Pickup!

Your order is ready and waiting for you.

Order ID: [ID]
Pickup Date: [Date]

Please come pick up your order at your earliest convenience.

Thank you!
```

### Preparing
```
Hi [Customer Name],

🍳 Preparing Your Order

We're currently preparing your order.

Order ID: [ID]

We'll notify you once it's ready for pickup.

Thank you!
```

### Completed
```
Hi [Customer Name],

✓ Order Completed

Thank you for your order!

Order ID: [ID]

We hope you enjoyed your experience at SLVH Smart Shop. Looking forward to seeing you again!

Feedback? Reply to this message or visit our website.
```

### Cancelled
```
Hi [Customer Name],

❌ Order Cancelled

Your order has been cancelled.

Order ID: [ID]

If you have any questions, please contact us.

Thank you!
```

---

## Deployment

### Deploy to Firebase

```bash
# From functions directory
npm run build

# Deploy to Firebase
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:onOrderStatusChanged

# View logs
firebase functions:log
```

### Verify Deployment

1. **Check Cloud Functions:**
   ```bash
   firebase functions:list
   ```

2. **Test WhatsApp function:**
   - Make API call to sendTestWhatsApp
   - Check whatsapp_logs in Firestore
   - Verify message received on phone

3. **Monitor execution:**
   ```bash
   firebase functions:log --region=us-central1
   ```

---

## Testing

### Local Development with Emulator

```bash
# Start Firebase emulators
firebase emulators:start --only functions,firestore

# In another terminal, deploy functions locally
firebase deploy --only functions
```

### Manual Testing

#### Test 1: Send Test Message via HTTP
```bash
curl "https://region-projectid.cloudfunctions.net/sendTestWhatsApp?phoneNumber=%2B919876543210&status=confirmed"
```

#### Test 2: Create Test Order and Change Status
1. Create test order in Firestore:
   ```
   orders/test-order-123
   {
     "customerId": "+919876543210",
     "status": "pendingPayment",
     "subtotal": 500,
     "tax": 25,
     "total": 525,
     "items": [...],
     "pickupSlot": {...}
   }
   ```

2. Update status to "confirmed":
   ```
   Update status field from "pendingPayment" to "confirmed"
   ```

3. Within 10 seconds, WhatsApp message should arrive

#### Test 3: Check Audit Logs
```bash
# In Firestore Console, check whatsapp_logs collection
# Should show:
# - orderId: "test-order-123"
# - phoneNumber: "+919876543210"
# - status: "success"
# - messageId: "wamid.XXXX"
```

### Troubleshooting

#### Issue: Message not sent
**Causes:**
1. Environment variables not set
2. Phone number format incorrect
3. Twilio sandbox - sender not opted in
4. WhatsApp API - template not approved
5. Firestore security rules too restrictive

**Solution:**
1. Verify env vars: `firebase functions:config:get`
2. Ensure phone number includes +91 country code
3. For Twilio: Send "join WORDWORD" from phone to sandbox number first
4. For WhatsApp API: Check template approval status in Meta dashboard
5. Update Firestore rules to allow function access

#### Issue: Function not triggering
**Causes:**
1. Function not deployed properly
2. Status field doesn't match trigger conditions
3. Firestore trigger not firing

**Solution:**
1. Check function deployment: `firebase functions:list`
2. Verify status is exactly "confirmed" or "readyForPickup"
3. Check function logs: `firebase functions:log`

#### Issue: Error: "TWILIO_ACCOUNT_SID not found"
**Solution:**
```bash
firebase functions:config:set twilio.account_sid="ACxxxxxxxxxxxxxxxxx"
firebase deploy --only functions
```

---

## Production Checklist

- [ ] Twilio/WhatsApp credentials configured in Firebase
- [ ] Message templates created and approved
- [ ] Firestore security rules updated for function access
- [ ] whatsapp_logs collection created and indexed
- [ ] users collection includes phone and name fields
- [ ] Retry logic tested with failed messages
- [ ] Error handling verified
- [ ] Load testing done (check Twilio/WhatsApp limits)
- [ ] Monitoring set up (Cloud Logging)
- [ ] Backup/recovery plan in place
- [ ] Documentation updated
- [ ] Team trained on monitoring and troubleshooting

---

## Monitoring & Analytics

### View Sent Messages
```bash
# Firebase Cloud Logging
firebase functions:log --region=us-central1

# Firestore Queries
db.collection('whatsapp_logs').where('status', '==', 'success').count()
db.collection('whatsapp_logs').where('status', '==', 'failed').count()
```

### Success Rate
```javascript
// In Cloud Logging or custom dashboard
total_sent = whatsapp_logs.count()
successful = whatsapp_logs.where('status', '==', 'success').count()
success_rate = (successful / total_sent) * 100
```

### Cost Estimation
- **Twilio:** Free tier: 100 messages/month; $0.0079 per outbound message after
- **WhatsApp Business API:** $0.0055 per outbound message (prices vary by country)

---

## Migration from Twilio to WhatsApp Business API

When ready to move to production:

1. **Keep Twilio as fallback:**
   - Code automatically tries WhatsApp Business API first
   - Falls back to Twilio if WhatsApp API fails
   - Ensures reliability during transition

2. **Set WhatsApp credentials:**
   ```bash
   firebase functions:config:set \
     whatsapp.business_phone_id="102XXXXXXXXXXXX" \
     whatsapp.business_access_token="your_token"
   ```

3. **Create message templates:**
   - Create approved templates in Meta dashboard
   - Update WHATSAPP_BUSINESS_TEMPLATE_NAME in code

4. **Update security rules:**
   - Ensure Cloud Function can write to whatsapp_logs

5. **Monitor transition:**
   - Check whatsapp_logs.sentVia field
   - Should gradually shift from "twilio" to "whatsapp-business-api"

---

## Compliance & Best Practices

### WhatsApp Policy Compliance
- ✅ Only send notifications for transactional messages (order updates)
- ✅ Include opt-out instructions if required by jurisdiction
- ✅ Don't send spam or unsolicited messages
- ✅ Respect quiet hours if applicable in target regions
- ✅ Implement opt-in/opt-out mechanism

### GDPR Compliance (EU Customers)
- Store phone number securely in Firestore
- Allow customers to opt out from WhatsApp notifications
- Implement data deletion on request
- Log all messages sent (for audit trail)

### India-Specific Rules (TRAI)
- Use DLT-registered sender IDs
- Include "TRANSACTIONAL" in message template classification
- Implement opt-in verification
- Send only between 9 AM - 9 PM IST when possible

### Implementation
```dart
// In Flutter app, add user preference
users/{phoneNumber}
├── whatsappNotificationsEnabled: Boolean
└── whatsappOptedInAt: Timestamp
```

---

## Summary

### What Gets Sent
- Order Confirmed
- Order Preparing (optional)
- Order Ready for Pickup
- Order Completed (optional)

### What's NOT Sent
- Marketing/promotional messages
- Unsolicited offers
- Messages to unverified numbers
- Messages outside quiet hours

### Audit Trail
- Every message logged to whatsapp_logs
- Includes phone number, order ID, status, message ID, timestamp
- Supports compliance audits and troubleshooting

---

## Next Steps

1. **Set up Twilio account** (for immediate testing)
2. **Configure Firebase functions** with Twilio credentials
3. **Deploy and test** with sendTestWhatsApp
4. **Verify orders** trigger notifications correctly
5. **Plan WhatsApp Business API** setup for production
6. **Train support team** on monitoring and troubleshooting

---

Last Updated: May 9, 2026
Status: Ready for Development Testing
Next Phase: Production Deployment
