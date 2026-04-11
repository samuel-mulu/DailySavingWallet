import 'package:flutter/material.dart';

/// Root [MaterialApp] navigator — used for reachability SnackBars without a local [BuildContext].
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
