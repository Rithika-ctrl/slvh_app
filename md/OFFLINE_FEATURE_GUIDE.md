# Feature 11 — Offline / No Internet Handling

## Files delivered

```
lib/
  connectivity/
    connectivity_service.dart     ← Singleton wrapping connectivity_plus
    connectivity_provider.dart    ← ChangeNotifier for the widget tree
    pending_write_queue.dart      ← Hive-backed write queue + PendingWrite model
  shared/widgets/
    no_internet_overlay.dart      ← Animated banner shown on every screen
  features/cart/services/
    cart_service.dart             ← UPDATED: offline-aware saveCart / clearCart
  main.dart                       ← UPDATED: Hive + ConnectivityService init
  app.dart                        ← UPDATED: ConnectivityProvider + builder wrap
pubspec.yaml                      ← UPDATED: +connectivity_plus, +hive_flutter
```

---

## What each file does

### `connectivity_service.dart`
Singleton. Initialised once in `main()`. Wraps `connectivity_plus` and exposes:
- `isOnline` — synchronous bool (safe to read in `build()`)
- `onlineStream` — broadcast stream of bool

### `connectivity_provider.dart`
`ChangeNotifier` that listens to `ConnectivityService.onlineStream` and calls `notifyListeners()` on change. Added to `MultiProvider` in `app.dart`.

### `no_internet_overlay.dart`
Wraps any widget tree. Placed in `MaterialApp.router`'s `builder:` parameter so it covers **every screen with zero per-screen changes**. Slides in from the top when offline; shows a green "back online" flash then slides away.

### `pending_write_queue.dart`
- Persists writes to a Hive box (`pending_writes`) as JSON strings
- Survives app restarts
- Auto-flushes in FIFO order when connectivity is restored
- Each `PendingWrite` has: `id`, `collection`, `docId`, `subCollection?`, `subDocId?`, `data`, `operation` (set/update/delete), `merge`

### `cart_service.dart` (updated)
- `saveCart()` now checks `ConnectivityService.instance.isOnline`
  - Online → Firestore write (unchanged)  
  - Offline → `PendingWriteQueue.instance.enqueue(...)` with cart payload
- `clearCart()` same pattern
- `loadCart()` returns `[]` early when offline (CartProvider falls back to SharedPreferences)

---

## What gets queued vs what doesn't

| Action | Queued? | Reason |
|---|---|---|
| Cart save (add/remove/qty change) | ✅ Yes | Low risk, user expects it to "just work" |
| Cart clear | ✅ Yes | Low risk |
| Profile name update | ✅ Yes (add yourself) | Low risk |
| **Order creation** | ❌ No | Needs stock reservation + real-time feedback |
| **Payment upload** | ❌ No | Needs real-time confirmation |
| **OTP / auth** | ❌ No | Can't work offline by nature |

For order creation and payment, show an error dialog when offline. Those screens already have error handling — just add an early connectivity check:

```dart
if (!ConnectivityService.instance.isOnline) {
  setState(() => _errorMessage = 'No internet. Please reconnect to place an order.');
  return;
}
```

---

## Adding offline awareness to other screens

### Blocking actions (checkout, payment)
```dart
// At the top of the submit handler:
if (!ConnectivityService.instance.isOnline) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('No internet connection')),
  );
  return;
}
```

### Reading connectivity reactively in a widget
```dart
final isOnline = context.watch<ConnectivityProvider>().isOnline;

if (!isOnline) {
  return const Text('You\'re offline — showing cached data');
}
```

### Queueing a custom write (e.g. profile name)
```dart
// In a service, when Firestore fails or device is offline:
await PendingWriteQueue.instance.enqueue(PendingWrite(
  id: const Uuid().v4(),
  collection: 'users',
  docId: userPhone,
  data: {'name': newName},
  operation: PendingWriteOp.update,
  createdAt: DateTime.now(),
));
```

Then add the executor in `main.dart` (or extend `cartQueueExecutor` to handle all write types by checking `write.collection`).

---

## Android permissions

Add to `android/app/src/main/AndroidManifest.xml` (inside `<manifest>`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
```

The INTERNET permission is almost certainly already present (Firebase needs it). The other two are needed by `connectivity_plus`.

---

## iOS

No permission entries needed for connectivity checking on iOS.

---

## Testing offline behaviour

1. Run app on emulator or device
2. Enable airplane mode
3. Banner slides in from top within ~1 second
4. Add/remove cart items — they save locally to SharedPreferences immediately
5. Check Hive box has queued entries (add a debug print or breakpoint in `enqueue()`)
6. Re-enable wifi/data
7. Banner slides away, queue flushes, Firestore receives the cart update
