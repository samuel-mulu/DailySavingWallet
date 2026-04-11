import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/network/reachability_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ReachabilityHost.instance.init();
  runApp(const ProviderScope(child: App()));
}
