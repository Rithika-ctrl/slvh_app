# WhatsApp Integration Deployment Checklist

## Phase 3b: WhatsApp Notifications

### Overview
Setting up WhatsApp notifications via Firebase Cloud Functions. Messages sent when orders are confirmed or ready for pickup.

---

## 1. Development Environment Setup

### 1.1 Node.js Setup
- [ ] Node.js 18+ installed
- [ ] npm or yarn available
- [ ] Firebase CLI installed: `npm install -g firebase-tools`
- [ ] Verified with: `firebase --version`

### 1.2 Firebase Functions Project
- [ ] Created `functions/` directory
- [ ] `package.json` with dependencies
- [ ] `tsconfig.json` for TypeScript compilation
- [ ] `.eslintrc.json` for code quality
- [ ] `.gitignore` for dependencies and builds

### 1.3 Code Files Created
- [ ] `functions/src/index.ts` - Main Cloud Functions
- [ ] `functions/src/notifications.ts` - WhatsApp sending logic
- [ ] `.env.example` - Environment variables template
- [ ] `firestore.rules` - Security rules

### 1.4 Installation
```bash
cd functions
npm install
npm run build
```
- [ ] No compilation errors
- [ ] TypeScript compiles to `lib/` directory

---

## 2. Twilio Setup (For Development)

### 2.1 Create Twilio Account
- [ ] Go to https://www.twilio.com
- [ ] Sign up for free account
- [ ] Verify email address
- [ ] Complete account setup

### 2.2 Get WhatsApp Sandbox
- [ ] Navigate to "Messaging" → "Sandbox" → "WhatsApp"
- [ ] Enable WhatsApp sandbox
- [ ] Copy sandbox WhatsApp number (e.g., `whatsapp:+1415224XXXX`)
- [ ] Save this as `TWILIO_WHATSAPP_NUMBER`

### 2.3 Get Twilio Credentials
- [ ] Go to Account Dashboard
- [ ] Copy **Account SID** (starts with AC)
- [ ] Copy **Auth Token** (keep secret!)
- [ ] Save as:
  - `TWILIO_ACCOUNT_SID`
  - `TWILIO_AUTH_TOKEN`

### 2.4 Configure Firebase
```bash
firebase functions:config:set twilio.account_sid="ACxxxxxxxxxxxxxxxxx"
firebase functions:config:set twilio.auth_token="your_auth_token"
firebase functions:config:set twilio.whatsapp_number="whatsapp:+1415224XXXX"
```
- [ ] Configuration set successfully
- [ ] Verified with: `firebase functions:config:get`

### 2.5 Twilio Sandbox Opt-In
- [ ] From test phone, send "join WORDWORD" message to sandbox number
- [ ] Wait for Twilio confirmation
- [ ] Phone now opted into sandbox messages

---

## 3. Firebase Setup

### 3.1 Firestore Configuration
- [ ] Firestore database created
- [ ] Database location selected
- [ ] Collections created:
  - [ ] orders
  - [ ] users
  - [ ] products
  - [ ] whatsapp_logs (will be auto-created by function)

### 3.2 Update Firestore Rules
- [ ] `firestore.rules` file created
- [ ] Deploy rules: `firebase deploy --only firestore:rules`
- [ ] Verified in Firestore Console

### 3.3 Users Collection Schema
Verify users have these fields:
```
users/{phoneNumber}
├── phone: String                  // +91XXXXXXXXXX
├── name: String                   // Customer name
├── fcmToken: String               // From Phase 3a
├── whatsappNotificationsEnabled: Boolean
└── ...
```
- [ ] Existing users have phone and name fields
- [ ] Create test user if needed

---

## 4. Cloud Functions Deployment

### 4.1 Local Testing
```bash
# In functions directory
npm run build

# Test with emulator (optional)
firebase emulators:start --only functions,firestore
```
- [ ] Build succeeds without errors
- [ ] TypeScript compiles to JavaScript

### 4.2 Deploy to Firebase
```bash
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:onOrderStatusChanged
```
- [ ] Deployment succeeds
- [ ] No errors in console
- [ ] Functions listed in Firebase Console

### 4.3 Verify Deployment
- [ ] Go to Firebase Console → Cloud Functions
- [ ] Verify these functions exist:
  - [ ] `onOrderStatusChanged` (Firestore trigger)
  - [ ] `sendTestWhatsApp` (HTTPS function)
  - [ ] `healthCheck` (HTTPS function)
- [ ] Status shows "OK" for all functions

---

## 5. Testing: Health Check

### 5.1 Test Basic Functionality
```bash
# Get function URLs from Firebase Console
# Copy the HTTPS trigger URL for healthCheck

curl https://region-projectid.cloudfunctions.net/healthCheck
```
- [ ] Response status: 200 OK
- [ ] JSON includes: `status: "ok"`, function list

### 5.2 View Logs
```bash
firebase functions:log
```
- [ ] Logs show function execution
- [ ] No error messages

---

## 6. Testing: WhatsApp Sending

### 6.1 Test via HTTPS (Manual)
```bash
# Replace with actual values
curl "https://region-projectid.cloudfunctions.net/sendTestWhatsApp?phoneNumber=%2B919876543210&status=confirmed"
```
- [ ] Response: `{"success": true, "message": "WhatsApp message sent successfully"}`
- [ ] Check Twilio Console for sent message
- [ ] Check Firebase Logs for execution

### 6.2 Verify Twilio Sent Message
- [ ] Go to Twilio Console
- [ ] Navigate to "Messaging" → "Log"
- [ ] Find sent message to test phone number
- [ ] Status shows "delivered" or "read"

### 6.3 Receive on Test Phone
- [ ] WhatsApp message arrives on test phone
- [ ] Message includes:
  - [ ] Customer greeting
  - [ ] Order ID
  - [ ] Status emoji/text
  - [ ] Pickup date
  - [ ] Total amount
  - [ ] Shop name

### 6.4 Check Firestore Logs
- [ ] Go to Firestore Console
- [ ] Open whatsapp_logs collection
- [ ] Find recent log entry with:
  - [ ] status: "success"
  - [ ] orderId: "TEST-ORDER-123"
  - [ ] messageId: (Twilio message SID)
  - [ ] sentVia: "twilio"

---

## 7. Testing: Order Trigger

### 7.1 Create Test Order
In Firestore Console, create test order:
```
orders/test-order-real-001
{
  "customerId": "+919876543210",
  "status": "pendingPayment",
  "subtotal": 500,
  "tax": 25,
  "total": 525,
  "items": [
    {
      "productId": "prod-1",
      "productName": "Test Product",
      "quantity": 1,
      "unitPrice": 500,
      "totalPrice": 500
    }
  ],
  "pickupSlot": {
    "date": "2026-05-10T10:00:00Z"
  }
}
```
- [ ] Order created successfully
- [ ] Has all required fields

### 7.2 Trigger WhatsApp by Status Change
- [ ] Edit order document
- [ ] Change status from "pendingPayment" to "confirmed"
- [ ] Save

### 7.3 Verify Notification Sent
- [ ] Wait 5-10 seconds for function to execute
- [ ] Check Firebase Logs: `firebase functions:log`
- [ ] Should see log: `"Order test-order-real-001 status changed from pendingPayment to confirmed"`
- [ ] Check test phone for WhatsApp message
- [ ] Check whatsapp_logs collection for new entry

### 7.4 Test Multiple Statuses
Repeat for each status:
- [ ] confirmed → Message sent ✅
- [ ] preparing → No message (status not in trigger list)
- [ ] readyForPickup → Message sent ✅
- [ ] completed → No message (status not in trigger list)
- [ ] cancelled → No message (status not in trigger list)

---

## 8. Testing: Error Scenarios

### 8.1 Invalid Phone Number
```bash
curl "https://region-projectid.cloudfunctions.net/sendTestWhatsApp?phoneNumber=invalid&status=confirmed"
```
- [ ] Response includes error message
- [ ] Function doesn't crash
- [ ] Firestore logs error

### 8.2 Missing Environment Variables
- [ ] Temporarily unset TWILIO_ACCOUNT_SID
- [ ] Try to send message
- [ ] Function gracefully handles missing config
- [ ] Returns error response (not 500)
- [ ] Re-enable TWILIO_ACCOUNT_SID

### 8.3 Network Error (Simulate)
- [ ] Disconnect internet during test
- [ ] Function should retry or gracefully fail
- [ ] whatsapp_logs should show failure
- [ ] Error message is descriptive

### 8.4 Retry Failed Messages
- [ ] Create a test scenario where message fails
- [ ] Call retry function (manual or scheduled)
- [ ] Failed message is attempted again
- [ ] Success count increases

---

## 9. Integration: With Flutter App

### 9.1 Update User Model in Firestore
When customer logs in via Flutter app:
- [ ] AuthService saves FCM token (Phase 3a)
- [ ] Users/{phoneNumber} document created
- [ ] Includes fields: phone, name, fcmToken

### 9.2 Create Real Order from App
- [ ] Login to Flutter app as customer
- [ ] Create real order (cart → checkout → payment)
- [ ] Verify order in Firestore
- [ ] Update order status to "confirmed" as admin
- [ ] Receive WhatsApp notification on customer phone

### 9.3 End-to-End Flow
- [ ] Customer creates order via app
- [ ] Order appears in Firestore
- [ ] Admin updates status
- [ ] WhatsApp notification arrives
- [ ] Push notification also arrives (Phase 3a)
- [ ] Both notifications stored in Firestore

---

## 10. Monitoring & Analytics

### 10.1 Set Up Monitoring
- [ ] Enable Cloud Logging alerts
- [ ] Set up error threshold
- [ ] Configure email notifications for errors

### 10.2 Track Metrics
- [ ] Messages sent count
- [ ] Success rate
- [ ] Average response time
- [ ] Error rate

### 10.3 Dashboard Queries
```bash
# Successful messages in last 24 hours
firebase firestore query whatsapp_logs --where status==success

# Failed messages
firebase firestore query whatsapp_logs --where status==failed

# Messages by status
firebase firestore query whatsapp_logs --where sentVia==twilio
```

---

## 11. Security Verification

### 11.1 Firestore Rules
- [ ] Cloud Function can write to whatsapp_logs
- [ ] Admin can read whatsapp_logs
- [ ] Users cannot write to whatsapp_logs
- [ ] Users cannot read other users' logs

Test with:
```bash
firebase auth:create-user test@example.com --password password123
```

### 11.2 Environment Variables
- [ ] Credentials NOT in code
- [ ] Credentials NOT in version control
- [ ] Using Firebase Functions:config:set
- [ ] .env.example shows structure only

### 11.3 API Keys
- [ ] Twilio Auth Token is secret
- [ ] WhatsApp access token is secret
- [ ] Rotate tokens periodically
- [ ] Use service account for production

---

## 12. Performance Testing

### 12.1 Load Test
- [ ] Create 100 test orders
- [ ] Update all to "confirmed" status
- [ ] Verify all 100 messages attempted
- [ ] Check function execution time
- [ ] Monitor memory usage

### 12.2 Latency
- [ ] Measure time from status change to message sent
- [ ] Should be < 10 seconds typically
- [ ] Document any delays

### 12.3 Timeout
- [ ] Current timeout: 300 seconds
- [ ] Sufficient for Twilio API calls (< 5 seconds typically)
- [ ] No timeout errors observed

---

## 13. Documentation & Handoff

### 13.1 Code Documentation
- [ ] WHATSAPP_INTEGRATION_GUIDE.md created ✅
- [ ] README in functions directory
- [ ] Inline code comments added
- [ ] Type definitions documented

### 13.2 Deployment Guide
- [ ] Step-by-step setup instructions
- [ ] Environment variable list
- [ ] Firebase console configuration steps
- [ ] Troubleshooting guide

### 13.3 Testing Guide
- [ ] Manual test procedures
- [ ] Expected outcomes documented
- [ ] Error scenarios covered
- [ ] Screenshots/examples provided

### 13.4 Monitoring Guide
- [ ] How to view logs
- [ ] How to check metrics
- [ ] Alert thresholds set
- [ ] On-call procedures documented

---

## 14. Migration Path: Twilio → WhatsApp Business API

### 14.1 When Ready for Production
- [ ] Twilio working reliably
- [ ] Ready to use WhatsApp Business API
- [ ] WhatsApp Business account created
- [ ] Phone number verified

### 14.2 Steps to Migrate
1. [ ] Create WhatsApp Business account with Meta
2. [ ] Get phone number ID and access token
3. [ ] Create message templates in Meta dashboard
4. [ ] Wait for Meta to approve templates
5. [ ] Configure Firebase functions:
   ```bash
   firebase functions:config:set \
     whatsapp.business_phone_id="102XXXXXXXXXXXX" \
     whatsapp.business_access_token="your_token"
   ```
6. [ ] Redeploy functions
7. [ ] Test with real phone number
8. [ ] Monitor whatsapp_logs.sentVia field (should show "whatsapp-business-api")

### 14.3 Fallback to Twilio
- [ ] Code automatically falls back to Twilio if WhatsApp Business API fails
- [ ] Ensures reliability during migration
- [ ] No downtime required

---

## 15. Production Readiness Checklist

### 15.1 Code Quality
- [ ] No console.error without logging
- [ ] Error handling for all paths
- [ ] Input validation on phone numbers
- [ ] Rate limiting (prevent abuse)
- [ ] Timeout handling

### 15.2 Performance
- [ ] Function execution time < 30 seconds
- [ ] Memory usage < 256 MB
- [ ] Cold start < 5 seconds
- [ ] No memory leaks

### 15.3 Compliance
- [ ] GDPR-compliant
- [ ] TRAI compliance (India)
- [ ] Opt-in/opt-out implemented
- [ ] Message templates approved by provider
- [ ] Audit logging in place

### 15.4 Reliability
- [ ] Retry logic tested
- [ ] Fallback mechanisms working
- [ ] Error notifications configured
- [ ] Backup authentication method ready
- [ ] Disaster recovery plan

### 15.5 Cost Management
- [ ] Cost estimates calculated
- [ ] Budget alerts configured
- [ ] Rate monitoring in place
- [ ] Escalation procedures defined

---

## Summary

### Deliverables
- ✅ Cloud Functions code (index.ts, notifications.ts)
- ✅ Firebase configuration (firebase.json, firestore.rules)
- ✅ Setup documentation (WHATSAPP_INTEGRATION_GUIDE.md)
- ✅ Environment configuration (.env.example)
- ✅ Project setup (package.json, tsconfig.json)

### Testing Completed
- [ ] Health check
- [ ] Manual HTTPS test
- [ ] Firestore trigger test
- [ ] Error scenario tests
- [ ] End-to-end app integration

### Status
- [ ] Development: Ready
- [ ] Testing: In Progress
- [ ] Staging: Pending
- [ ] Production: Blocked (Twilio sandbox limitations)

---

## Sign-Off

- Reviewed by: _______________
- Date: _______________
- Status: [ ] PASSED [ ] NEEDS WORK [ ] BLOCKED

---

## Contact & Support

- Documentation: See WHATSAPP_INTEGRATION_GUIDE.md
- Logs: Firebase Console → Cloud Functions → Logs
- Firestore: Firebase Console → Firestore Database → Collections
- Issues: Check troubleshooting section in guide

---

Last Updated: May 9, 2026
