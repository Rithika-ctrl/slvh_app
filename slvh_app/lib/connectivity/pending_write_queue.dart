import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../connectivity/connectivity_service.dart';

/// PendingWriteQueue
///
/// Feature 11: Offline / No Internet Handling — Write Queue
///
/// When the device is offline, Firestore writes (cart saves, profile
/// updates, etc.) may silently fail. This queue:
///
///   1. Accepts a write descriptor (collection + docId + data)
///   2. Persists it to a Hive box so it survives app restarts
///   3. Replays all pending writes in FIFO order when connectivity is
///      restored, then clears them
///
/// ── WHAT GETS QUEUED vs WHAT DOESN'T ──────────────────────────────
///
/// Queue:  cart saves, profile name updates, notification-read marks
/// Don't:  order creation, payment uploads — these need an explicit
///         user action with real-time feedback (show error + retry UI)
///
/// ── USAGE ─────────────────────────────────────────────────────────
///
/// Initialise once in main() after Hive.initFlutter():
///   await PendingWriteQueue.instance.initialize();
///
/// Queue a write from any service:
///   await PendingWriteQueue.instance.enqueue(PendingWrite(
///     id: const Uuid().v4(),
///     collection: 'users',
///     docId: uid,
///     subCollection: 'cart',
///     subDocId: 'data',
///     data: cartJson,
///     operation: PendingWriteOp.set,
///     createdAt: DateTime.now(),
///   ));
///
/// The queue auto-flushes when connectivity is restored. You can also
/// call [flush()] manually (e.g. on app foreground).
class PendingWriteQueue {
  PendingWriteQueue._();
  static final PendingWriteQueue instance = PendingWriteQueue._();

  static const String _boxName = 'pending_writes';

  Box<String>? _box;
  StreamSubscription<bool>? _connectivitySub;
  bool _isFlushing = false;

  // Injected Firestore executor — swap in tests with a mock
  Future<void> Function(PendingWrite write)? _executor;

  /// Must be called once from main() after Hive.initFlutter() and
  /// ConnectivityService.instance.initialize().
  ///
  /// [executor] — async function that actually performs the Firestore
  /// write. Pass null to use the default FirestoreExecutor.
  Future<void> initialize({
    Future<void> Function(PendingWrite write)? executor,
  }) async {
    _box = await Hive.openBox<String>(_boxName);
    _executor = executor ?? _defaultExecutor;

    // Flush anything that was queued before the last app session ended
    if (ConnectivityService.instance.isOnline) {
      unawaited(flush());
    }

    // Auto-flush whenever we come back online
    _connectivitySub =
        ConnectivityService.instance.onlineStream.listen((online) {
      if (online) unawaited(flush());
    });
  }

  /// Add a write to the queue and **verify** it was persisted.
  ///
  /// Returns `true` if the write was successfully stored in Hive.
  /// Returns `false` if the queue was not initialised or the Hive write
  /// failed (e.g. disk full). Callers should surface an error to the user
  /// when this returns `false` so the change is not silently lost.
  ///
  /// Use this instead of [enqueue] for cart saves and order-related writes
  /// where silent data loss is unacceptable.
  Future<bool> enqueueWithConfirmation(PendingWrite write) async {
    final box = _box;
    if (box == null) {
      print('⚠️ PendingWriteQueue not initialised — write dropped: ${write.path}');
      return false;
    }

    try {
      await box.put(write.id, jsonEncode(write.toJson()));

      // Verify the entry was actually persisted
      final stored = box.get(write.id);
      if (stored == null) {
        print('❌ Verification failed — write not found after put: ${write.id}');
        return false;
      }

      print('📥 Queued+verified write [${write.id}] → ${write.path} '
          '(queue depth: ${box.length})');

      if (ConnectivityService.instance.isOnline) {
        unawaited(flush());
      }
      return true;
    } catch (e) {
      print('❌ Failed to queue write [${write.id}] → ${write.path}: $e');
      return false;
    }
  }

  /// Returns true if a specific write ID is still pending (not yet flushed).
  bool isPending(String writeId) => _box?.containsKey(writeId) ?? false;

  /// Add a write to the persistent queue.
  /// Safe to call when offline — the write will survive app restarts.
  Future<void> enqueue(PendingWrite write) async {
    final box = _box;
    if (box == null) {
      print('⚠️ PendingWriteQueue not initialised — write dropped');
      return;
    }
    await box.put(write.id, jsonEncode(write.toJson()));
    print('📥 Queued write [${write.id}] → ${write.path}');

    // Flush immediately if we happen to be online right now
    if (ConnectivityService.instance.isOnline) {
      unawaited(flush());
    }
  }

  /// Replay all queued writes in FIFO order.
  /// Called automatically when connectivity is restored.
  Future<void> flush() async {
    final box = _box;
    if (box == null || _isFlushing || box.isEmpty) return;

    _isFlushing = true;
    print('🔄 Flushing ${box.length} pending write(s)...');

    // Snapshot keys to avoid concurrent-modification issues
    final keys = box.keys.cast<String>().toList();

    for (final key in keys) {
      if (!ConnectivityService.instance.isOnline) {
        print('⚡ Went offline mid-flush — pausing');
        break;
      }

      final raw = box.get(key);
      if (raw == null) continue;

      try {
        final write = PendingWrite.fromJson(jsonDecode(raw));
        await _executor!(write);
        await box.delete(key);
        print('✅ Flushed write [${write.id}] → ${write.path}');
      } catch (e) {
        print('❌ Failed to flush write [$key]: $e');
        // Leave it in the box — it will retry next flush cycle
      }
    }

    _isFlushing = false;
    print('✅ Flush complete. Remaining: ${box.length}');
  }

  /// Number of writes currently waiting to be synced
  int get pendingCount => _box?.length ?? 0;

  void dispose() {
    _connectivitySub?.cancel();
    _box?.close();
  }
}

// ── Default Firestore executor ────────────────────────────────────────────────

Future<void> _defaultExecutor(PendingWrite write) async {
  // Intentionally left unimplemented to avoid pulling Firestore into unit tests.
  // Real executors are injected by services (see CartService for examples).
  throw UnimplementedError(
    'Inject an executor via PendingWriteQueue.instance.initialize(executor:). '
    'See CartService for an example.',
  );
}

// ── Data model ────────────────────────────────────────────────────────────────

enum PendingWriteOp { set, update, delete }

/// Describes a single Firestore write that must be replayed when online.
class PendingWrite {
  final String id;

  /// Top-level collection, e.g. 'users'
  final String collection;

  /// Document ID, e.g. the user's uid
  final String docId;

  /// Optional sub-collection, e.g. 'cart'
  final String? subCollection;

  /// Optional sub-document ID, e.g. 'data'
  final String? subDocId;

  /// The data payload (JSON-encodable map)
  final Map<String, dynamic> data;

  final PendingWriteOp operation;
  final DateTime createdAt;

  /// Whether to merge (true) or overwrite (false) on set operations
  final bool merge;

  PendingWrite({
    required this.id,
    required this.collection,
    required this.docId,
    this.subCollection,
    this.subDocId,
    required this.data,
    required this.operation,
    required this.createdAt,
    this.merge = true,
  });

  /// Firestore path string for logging
  String get path {
    if (subCollection != null && subDocId != null) {
      return '$collection/$docId/$subCollection/$subDocId';
    }
    return '$collection/$docId';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'collection': collection,
        'docId': docId,
        'subCollection': subCollection,
        'subDocId': subDocId,
        'data': data,
        'operation': operation.name,
        'createdAt': createdAt.toIso8601String(),
        'merge': merge,
      };

  factory PendingWrite.fromJson(Map<String, dynamic> json) => PendingWrite(
        id: json['id'] as String,
        collection: json['collection'] as String,
        docId: json['docId'] as String,
        subCollection: json['subCollection'] as String?,
        subDocId: json['subDocId'] as String?,
        data: (json['data'] as Map<String, dynamic>),
        operation: PendingWriteOp.values
            .firstWhere((e) => e.name == json['operation']),
        createdAt: DateTime.parse(json['createdAt'] as String),
        merge: json['merge'] as bool? ?? true,
      );
}