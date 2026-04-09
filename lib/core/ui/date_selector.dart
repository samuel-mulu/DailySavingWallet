import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:flutter/material.dart';

import '../dates/date_formatters.dart';
import '../settings/calendar_mode.dart';
import 'ethiopian_date_picker.dart';

class DateSelector extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final bool showQuickSelect;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const DateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.showQuickSelect = true,
    this.firstDate,
    this.lastDate,
  });

  @override
  State<DateSelector> createState() => _DateSelectorState();
}

class _DateSelectorState extends State<DateSelector> {
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

  bool get _isToday {
    final now = DateTime.now();
    return widget.selectedDate.year == now.year &&
        widget.selectedDate.month == now.month &&
        widget.selectedDate.day == now.day;
  }

  String _formatDate(DateTime date, CalendarMode mode) {
    return formatDateTime(date, mode, locale: 'am');
  }

  Future<void> _pickDate(BuildContext context, CalendarMode mode) async {
    if (mode == CalendarMode.ethiopian) {
      final ETDateTime ethInitial = widget.selectedDate.convertToEthiopian();
      final ETDateTime ethFirst = (widget.firstDate ?? DateTime(2020, 1, 1))
          .convertToEthiopian();
      final ETDateTime ethLast = (widget.lastDate ?? DateTime.now())
          .convertToEthiopian();

      final picked = await showEthiopianDatePicker(
        context: context,
        initialDate: ethInitial,
        firstDate: ethFirst,
        lastDate: ethLast,
      );

      if (picked != null) {
        widget.onDateChanged(picked.convertToGregorian());
      }
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: widget.selectedDate,
        firstDate: widget.firstDate ?? DateTime(2020, 1, 1),
        lastDate: widget.lastDate ?? DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(
              context,
            ).copyWith(colorScheme: Theme.of(context).colorScheme),
            child: child!,
          );
        },
      );

      if (picked != null) {
        widget.onDateChanged(picked);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If service not loaded yet, default to gregorian
    if (_service == null) {
      return _buildContent(context, CalendarMode.gregorian);
    }

    return ValueListenableBuilder<CalendarMode>(
      valueListenable: _service!,
      builder: (context, mode, _) {
        return _buildContent(context, mode);
      },
    );
  }

  Widget _buildContent(BuildContext context, CalendarMode mode) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            mode == CalendarMode.ethiopian ? 'የግብይት ቀን' : 'Transaction Date',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Row(
          children: [
            _NavigationButton(
              icon: Icons.chevron_left_rounded,
              onTap: () => widget.onDateChanged(
                widget.selectedDate.subtract(const Duration(days: 1)),
              ),
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => _pickDate(context, mode),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        mode == CalendarMode.ethiopian
                            ? Icons.calendar_month
                            : Icons.calendar_today_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _formatDate(widget.selectedDate, mode),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _NavigationButton(
              icon: Icons.chevron_right_rounded,
              onTap: _isToday
                  ? null
                  : () => widget.onDateChanged(
                      widget.selectedDate.add(const Duration(days: 1)),
                    ),
              color: colorScheme.primary,
              isDisabled: _isToday,
            ),
          ],
        ),
      ],
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final bool isDisabled;

  const _NavigationButton({
    required this.icon,
    required this.onTap,
    required this.color,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDisabled ? Colors.grey.shade200 : color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDisabled ? Colors.transparent : color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: isDisabled ? Colors.grey.shade400 : color,
            size: 24,
          ),
        ),
      ),
    );
  }
}

int dateToTxMillis(DateTime date) {
  return DateTime(date.year, date.month, date.day, 12).millisecondsSinceEpoch;
}
