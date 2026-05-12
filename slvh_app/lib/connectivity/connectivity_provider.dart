import 'dart:async';
import 'package:flutter/foundation.dart';
import 'connectivity_service.dart';

/// ConnectivityProvider
///
/// Feature 11: Offline / No Internet Handling
///
/// ChangeNotifier that exposes [isOnline] to the widget tree.
/// Wrap [MaterialApp.router] (in app.dart) with a
/// ChangeNotifierProvider<ConnectivityProvider> so every screen can
/// listen without rebuilding the whole tree.
///
/// Screens that need the value:
///   final online = context.watch<ConnectivityProvider>().isOnline;
class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = ConnectivityService.instance.isOnline;
  StreamSubscription<bool>? _sub;

  ConnectivityProvider() {
    _sub = ConnectivityService.instance.onlineStream.listen((online) {
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    });
  }

  bool get isOnline => _isOnline;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
