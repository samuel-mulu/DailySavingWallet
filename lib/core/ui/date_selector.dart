import 'package:flutter/material.dart';

/// A modern chip-style date selector inspired by banking apps.
/// 
/// Features:
/// - Main date chip showing selected date
/// - Quick select chips for "Today" and "Yesterday"
/// - Material 3 styling with primary container colors
class DateSelector extends StatelessWidget {
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

  bool get _isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  bool get _isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return selectedDate.year == yesterday.year &&
        selectedDate.month == yesterday.month &&
        selectedDate.day == yesterday.day;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Transaction Date',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        
        // Date selector row
        Row(
          children: [
            // Main date chip
            Expanded(
              child: InkWell(
                onTap: () => _pickDate(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _formatDate(selectedDate),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Quick select chips
            if (showQuickSelect) ...[
              const SizedBox(width: 12),
              _QuickChip(
                label: 'Today',
                isSelected: _isToday,
                onTap: () => onDateChanged(DateTime.now()),
              ),
              const SizedBox(width: 8),
              _QuickChip(
                label: 'Yesterday',
                isSelected: _isYesterday,
                onTap: () => onDateChanged(
                  DateTime.now().subtract(const Duration(days: 1)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected ? colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected 
                  ? colorScheme.primary 
                  : colorScheme.outline.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected 
                  ? colorScheme.onPrimary 
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper to convert DateTime to txDateMillis for API calls.
/// Sets time to noon to avoid timezone issues.
int dateToTxMillis(DateTime date) {
  return DateTime(date.year, date.month, date.day, 12).millisecondsSinceEpoch;
}
