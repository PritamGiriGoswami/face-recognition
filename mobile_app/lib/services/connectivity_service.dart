import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'cloud_service.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  StreamSubscription<ConnectivityResult>? _subscription;

  static void init() {
    // static helper to be called from UI initState
    ConnectivityService()._startListening();
  }

  void _startListening() {
    _subscription = Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        // When we regain connectivity, attempt to sync pending records
        await CloudService().syncPending();
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
