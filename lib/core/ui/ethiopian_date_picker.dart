import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:flutter/material.dart';

/// Shows a simple Ethiopian date picker dialog.
/// Returns the selected ETDateTime or null if cancelled.
Future<ETDateTime?> showEthiopianDatePicker({
  required BuildContext context,
  required ETDateTime initialDate,
  required ETDateTime firstDate,
  required ETDateTime lastDate,
}) async {
  return showDialog<ETDateTime>(
    context: context,
    builder: (context) => _EthiopianDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _EthiopianDatePickerDialog extends StatefulWidget {
  final ETDateTime initialDate;
  final ETDateTime firstDate;
  final ETDateTime lastDate;

  const _EthiopianDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_EthiopianDatePickerDialog> createState() =>
      _EthiopianDatePickerDialogState();
}

class _EthiopianDatePickerDialogState
    extends State<_EthiopianDatePickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;

  // Ethiopian month names
  static const _monthNames = [
    'መስከረም',
    'ጥቅምት',
    'ኅዳር',
    'ታኅሣሥ',
    'ጥር',
    'የካቲት',
    'መጋቢት',
    'ሚያዝያ',
    'ግንቦት',
    'ሰኔ',
    'ሐምሌ',
    'ነሐሴ',
    'ጳጉሜ',
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
    _selectedDay = widget.initialDate.day;
  }

  int _daysInMonth(int year, int month) {
    if (month == 13) {
      // Pagume - 5 or 6 days depending on leap year
      // Ethiopian leap year: (year + 3) % 4 == 0
      final isLeap = (year + 3) % 4 == 0;
      return isLeap ? 6 : 5;
    }
    return 30; // All other months have 30 days
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Generate year range
    final years = List.generate(
      widget.lastDate.year - widget.firstDate.year + 1,
      (i) => widget.firstDate.year + i,
    );

    // Days in selected month
    final daysInMonth = _daysInMonth(_selectedYear, _selectedMonth);

    return AlertDialog(
      title: const Text('የቀን መምረጫ'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Year and Month Row
            Row(
              children: [
                // Year dropdown
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'ዓመት',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: years
                        .map(
                          (y) => DropdownMenuItem(value: y, child: Text('$y')),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedYear = v;
                          // Adjust day if needed
                          final maxDay = _daysInMonth(
                            _selectedYear,
                            _selectedMonth,
                          );
                          if (_selectedDay > maxDay) _selectedDay = maxDay;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Month dropdown
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'ወር',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: List.generate(
                      13,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_monthNames[i]),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedMonth = v;
                          // Adjust day if needed
                          final maxDay = _daysInMonth(
                            _selectedYear,
                            _selectedMonth,
                          );
                          if (_selectedDay > maxDay) _selectedDay = maxDay;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Day grid
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                ),
                itemCount: daysInMonth,
                itemBuilder: (context, index) {
                  final day = index + 1;
                  final isSelected = day == _selectedDay;

                  return InkWell(
                    onTap: () => setState(() => _selectedDay = day),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Selected date display
            Text(
              '$_selectedDay ${_monthNames[_selectedMonth - 1]} $_selectedYear',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ሰርዝ'),
        ),
        FilledButton(
          onPressed: () {
            final selected = ETDateTime(
              _selectedYear,
              _selectedMonth,
              _selectedDay,
              12,
            );
            Navigator.pop(context, selected);
          },
          child: const Text('ምረጥ'),
        ),
      ],
    );
  }
}
