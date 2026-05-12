import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// ConnectivityService
///
/// Feature 11: Offline / No Internet Handling
///
/// Singleton that wraps connectivity_plus and exposes:
///   • [isOnline]   — current synchronous snapshot (updated in background)
///   • [onlineStream] — broadcast stream of bool (true = online)
///
/// Usage:
///   ConnectivityService.instance.isOnline
///   ConnectivityService.instance.onlineStream.listen(...)
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  bool _isOnline = true; // optimistic default until first check
  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Call once from main() before runApp()
  Future<void> initialize() async {
    // Perform an immediate check so [isOnline] is accurate before the
    // first connectivity-change event fires.
    final results = await _connectivity.checkConnectivity();
    _isOnline = _resultsOnline(results);
    _controller.add(_isOnline);

    // Subscribe to future changes (connectivity_plus ≥5.x returns a List)
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = _resultsOnline(results);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
      }
    });
  }

  /// true if any active interface is NOT "none"
  bool _resultsOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Synchronous snapshot — safe to read from build() without await
  bool get isOnline => _isOnline;

  /// Broadcast stream — [true] = connected, [false] = no internet
  Stream<bool> get onlineStream => _controller.stream;

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
