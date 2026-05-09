# SLVH Smart Shop - Firebase Cloud Functions

This directory contains Firebase Cloud Functions for the SLVH Smart Shop application.

## Overview

The Cloud Functions handle server-side operations that cannot be done from the Flutter mobile app:

- **WhatsApp Notifications**: Send WhatsApp messages when orders are confirmed or ready for pickup
- **Audit Logging**: Log all messages to Firestore for compliance and debugging
- **Error Handling**: Graceful degradation with fallback mechanisms

## Directory Structure

```
functions/
├── src/
│   ├── index.ts              # Main entry point, exports all functions
│   └── notifications.ts      # WhatsApp notification logic
├── lib/                      # Compiled JavaScript (auto-generated)
├── package.json              # Node.js dependencies
├── tsconfig.json             # TypeScript configuration
├── .eslintrc.json            # Code quality rules
├── .gitignore                # Files to exclude from git
└── .env.example              # Environment variables template
```

## Cloud Functions

### 1. onOrderStatusChanged
**Trigger**: Firestore `orders/{orderId}` document update

Automatically sends WhatsApp messages when an order status changes to:
- `confirmed`: "Order Confirmed" message
- `readyForPickup`: "Ready for Pickup" message

**How it works**:
1. Listen for order document updates
2. Check if status field changed
3. For "confirmed" or "readyForPickup" statuses:
   - Fetch customer phone and name from users collection
   - Generate message based on status
   - Send WhatsApp via Twilio or WhatsApp Business API
   - Log to whatsapp_logs collection

### 2. sendTestWhatsApp
**Trigger**: HTTPS POST request

Manual function for testing WhatsApp sending without creating an order.

**Usage**:
```bash
curl "https://region-projectid.cloudfunctions.net/sendTestWhatsApp?phoneNumber=%2B919876543210&status=confirmed"
```

**Parameters**:
- `phoneNumber`: Customer phone number (URL encoded, with country code)
- `status`: Order status ("confirmed", "readyForPickup", etc.)

**Returns**:
```json
{
  "success": true,
  "message": "WhatsApp message sent successfully",
  "messageId": "wamid.XXXX"
}
```

### 3. healthCheck
**Trigger**: HTTPS GET request

Simple health check to verify the function is deployed and responding.

**Usage**:
```bash
curl https://region-projectid.cloudfunctions.net/healthCheck
```

**Returns**:
```json
{
  "status": "ok",
  "timestamp": "2026-05-09T12:00:00Z",
  "functions": ["onOrderStatusChanged", "sendTestWhatsApp", "healthCheck"]
}
```

## Setup

### 1. Install Dependencies

```bash
cd functions
npm install
```

### 2. Configure Environment

Copy `.env.example` to `.env` and fill in your credentials:

```bash
# For development with Twilio (recommended)
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_WHATSAPP_NUMBER=whatsapp:+1234567890

# For production with WhatsApp Business API (optional)
WHATSAPP_BUSINESS_PHONE_ID=102XXXXXXXXXXXX
WHATSAPP_BUSINESS_ACCESS_TOKEN=your_access_token
```

Then set Firebase config:
```bash
firebase functions:config:set twilio.account_sid="$TWILIO_ACCOUNT_SID"
firebase functions:config:set twilio.auth_token="$TWILIO_AUTH_TOKEN"
firebase functions:config:set twilio.whatsapp_number="$TWILIO_WHATSAPP_NUMBER"
```

### 3. Build

```bash
npm run build
```

This compiles TypeScript to JavaScript in the `lib/` directory.

### 4. Deploy

```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:onOrderStatusChanged
```

## Development

### Local Testing with Emulator

```bash
# Start emulators
firebase emulators:start --only functions,firestore

# In another terminal, deploy to emulator
firebase deploy --only functions
```

### Code Quality

```bash
# Lint code
npm run lint

# Fix linting issues
npm run lint -- --fix

# Build and check for errors
npm run build
```

### Viewing Logs

```bash
# Stream logs in real-time
firebase functions:log

# Or check specific function
firebase functions:log --region=us-central1
```

## Configuration

### Environment Variables

Functions use environment variables configured via Firebase:

```bash
# View current config
firebase functions:config:get

# Set a value
firebase functions:config:set twilio.account_sid="ACxxxxxxxxxxxxxxxxx"

# Remove a value
firebase functions:config:unset twilio.account_sid
```

### Runtime Settings

In `firebase.json`:
- **timeout**: 300 seconds (5 minutes)
- **memory**: 256 MB
- **runtime**: Node.js 18

Adjust if needed for your use case.

## Firestore Integration

Functions interact with these collections:

### orders
Triggers notifications when status changes.

Required fields:
- `customerId`: Phone number of customer
- `status`: Current order status
- `subtotal`, `tax`, `total`: Price information
- `items`: Array of order items
- `pickupSlot`: Pickup date/time information

### users
Provides customer contact information.

Required fields:
- `phone`: Customer phone number
- `name`: Customer name
- `fcmToken`: For push notifications (Phase 3a)

### whatsapp_logs
Stores audit trail of all messages sent.

Auto-created by function with fields:
- `orderId`: Reference to order
- `phoneNumber`: Customer phone
- `customerName`: Customer name
- `status`: Message send status
- `messageId`: ID from Twilio/WhatsApp API
- `sentAt`: Timestamp
- `sentVia`: "twilio" or "whatsapp-business-api"

## API Providers

### Twilio (Recommended for Development)

**Pros**:
- Easy to set up
- Free tier available
- Good documentation
- Reliable service

**Cons**:
- Sandbox requires opt-in
- Limited to sandboxed phone numbers initially

**Setup**: See `.env.example`

**Cost**: Free tier for development; $0.0079 per message after

### WhatsApp Business API (For Production)

**Pros**:
- Direct integration with Meta/Facebook
- Higher throughput
- Official WhatsApp provider
- Message templates for compliance

**Cons**:
- More complex setup
- Requires business verification
- Template approval time

**Setup**: See `.env.example` and WHATSAPP_INTEGRATION_GUIDE.md

**Cost**: $0.0055 per message (country-dependent)

## Message Templates

Messages are automatically generated based on order status:

```
Status: confirmed
→ "✅ Order Confirmed!"

Status: readyForPickup
→ "📦 Ready for Pickup!"

Status: preparing
→ "🍳 Preparing Your Order" (no message sent by default)

Status: completed
→ "✓ Order Completed" (no message sent by default)

Status: cancelled
→ "❌ Order Cancelled" (no message sent by default)
```

Templates include:
- Customer greeting
- Order ID
- Total amount
- Pickup date
- Shop name and thanks

## Error Handling

Functions implement robust error handling:

1. **Missing credentials**: Function returns error instead of crashing
2. **API failures**: Twilio → WhatsApp Business API fallback
3. **Network issues**: Retries with exponential backoff
4. **Invalid phone numbers**: Normalized and validated
5. **Firestore errors**: Logged and gracefully handled

All errors logged to:
- Firebase Cloud Logging (for debugging)
- Firestore whatsapp_logs collection (for audit)

## Security

### Authentication
- Cloud Functions authenticate via service account
- Function can read users/orders via Firestore rules
- Function can write to whatsapp_logs

### Data Protection
- Phone numbers transmitted to Twilio/WhatsApp securely (HTTPS)
- API credentials stored in Firebase config (not in code)
- No credentials logged to console or Firestore
- Firestore rules restrict data access by role

### Compliance
- All messages logged for audit trail
- Follows GDPR/TRAI guidelines for message content
- Opt-in/opt-out mechanism in app

## Troubleshooting

### Function Not Triggering

1. Verify function deployed:
   ```bash
   firebase functions:list
   ```

2. Check function logs:
   ```bash
   firebase functions:log
   ```

3. Ensure order has correct `status` field

### WhatsApp Message Not Sent

1. Check credentials configured:
   ```bash
   firebase functions:config:get
   ```

2. Verify phone number format:
   - Should include country code: `+91XXXXXXXXXX`
   - Without spaces or dashes

3. Check Firestore security rules allow Cloud Function access

4. For Twilio: Verify phone opted into sandbox

### Build Errors

1. Clear build directory:
   ```bash
   rm -rf lib node_modules
   npm install
   npm run build
   ```

2. Check TypeScript errors:
   ```bash
   npm run build -- --noEmit
   ```

## Testing

### Manual HTTP Test
```bash
curl "https://region-projectid.cloudfunctions.net/sendTestWhatsApp?phoneNumber=%2B919876543210&status=confirmed"
```

### Firestore Trigger Test
1. Create test order in Firestore
2. Update `status` from "pendingPayment" to "confirmed"
3. Check logs and whatsapp_logs collection

### End-to-End Test
1. Create order via Flutter app
2. Update status via Firebase Console
3. Verify WhatsApp message received on phone

See WHATSAPP_DEPLOYMENT_CHECKLIST.md for comprehensive testing procedures.

## Performance

### Typical Execution Time
- 1-5 seconds (including Twilio API call)
- Function timeout: 300 seconds (sufficient)

### Memory Usage
- ~50-100 MB per invocation
- Configured limit: 256 MB (sufficient)

### Scaling
- Firebase automatically scales functions
- No manual scaling needed
- Cost based on invocations and execution time

## Monitoring

### View Recent Executions
```bash
firebase functions:log --limit=50
```

### Check Metrics
- Firebase Console → Cloud Functions → Metrics
- Monitor: Executions, Errors, Duration

### Set Up Alerts
- Firebase Console → Cloud Functions → Error Reporting
- Configure email alerts for errors

## Useful Links

- [Firebase Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [Twilio WhatsApp API Docs](https://www.twilio.com/docs/whatsapp)
- [WhatsApp Business API Docs](https://developers.facebook.com/docs/whatsapp)
- [TypeScript in Cloud Functions](https://firebase.google.com/docs/functions/typescript)

## Deployment Checklist

Before deploying to production:

- [ ] Credentials configured in Firebase
- [ ] Firestore security rules deployed
- [ ] Environment variables set correctly
- [ ] Functions tested locally
- [ ] Phone numbers in correct format
- [ ] WhatsApp/Twilio account verified
- [ ] Message templates created (if using WhatsApp Business)
- [ ] Firestore indexes created (if needed)
- [ ] Error alerts configured
- [ ] Documentation updated

## Support

For issues or questions:
1. Check WHATSAPP_INTEGRATION_GUIDE.md for setup help
2. Check WHATSAPP_DEPLOYMENT_CHECKLIST.md for testing steps
3. Review Firebase Cloud Logging for error messages
4. Check Twilio/WhatsApp API status pages

---

**Last Updated**: May 9, 2026  
**Status**: Ready for Development & Testing  
**Next**: WhatsApp Business API Integration for Production
