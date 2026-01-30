import 'package:flutter/material.dart';

import '../settings/calendar_mode.dart';

class CalendarToggleBtn extends StatefulWidget {
  const CalendarToggleBtn({super.key});

  @override
  State<CalendarToggleBtn> createState() => _CalendarToggleBtnState();
}

class _CalendarToggleBtnState extends State<CalendarToggleBtn> {
  CalendarModeService? _service;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    final service = await CalendarModeService.getInstance();
    if (mounted) {
      setState(() => _service = service);
    }
  }

  void _toggle() {
    if (_service == null) return;
    final newMode = _service!.value == CalendarMode.gregorian
        ? CalendarMode.ethiopian
        : CalendarMode.gregorian;
    _service!.setMode(newMode);
  }

  @override
  Widget build(BuildContext context) {
    if (_service == null) return const SizedBox.shrink();

    return ValueListenableBuilder<CalendarMode>(
      valueListenable: _service!,
      builder: (context, mode, _) {
        final isEth = mode == CalendarMode.ethiopian;
        return IconButton(
          onPressed: _toggle,
          tooltip: isEth ? 'Switch to Gregorian' : 'Switch to Ethiopian',
          icon: Icon(
            isEth ? Icons.calendar_month : Icons.calendar_today,
            color: Theme.of(context).colorScheme.primary,
          ),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.3),
            padding: const EdgeInsets.all(8),
          ),
        );
      },
    );
  }
}
