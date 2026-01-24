import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class SyncStatusBanner extends StatefulWidget {
  const SyncStatusBanner({super.key});

  @override
  State<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends State<SyncStatusBanner> {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _init();
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      _setOffline(!_isOnline(results));
    });
  }

  Future<void> _init() async {
    final results = await _connectivity.checkConnectivity();
    _setOffline(!_isOnline(results));
  }

  bool _isOnline(List<ConnectivityResult> results) {
    // If any non-none connectivity is present, treat as online.
    return results.any((r) => r != ConnectivityResult.none);
  }

  void _setOffline(bool v) {
    if (_offline == v) return;
    if (!mounted) return;
    setState(() => _offline = v);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.wifi_off, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Offline — showing cached data when available',
                style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

