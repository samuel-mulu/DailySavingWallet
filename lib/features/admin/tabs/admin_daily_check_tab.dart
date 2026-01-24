import 'package:flutter/material.dart';

import '../record_daily_saving_screen.dart';

class AdminDailyCheckTab extends StatelessWidget {
  const AdminDailyCheckTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Reuse the existing screen, but as a tab body.
    return const RecordDailySavingScreen();
  }
}

