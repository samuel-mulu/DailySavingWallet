import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String text;
  final Color? color;
  const StatusChip({super.key, required this.text, this.color});

  factory StatusChip.pending() {
    return const StatusChip(
      text: 'PENDING',
      color: Color(0xFFF57C00), // Amber
    );
  }

  factory StatusChip.approved() {
    return const StatusChip(
      text: 'APPROVED',
      color: Color(0xFF2E7D32), // Green
    );
  }

  factory StatusChip.rejected() {
    return const StatusChip(
      text: 'REJECTED',
      color: Color(0xFFC62828), // Red
    );
  }

  factory StatusChip.active() {
    return const StatusChip(
      text: 'ACTIVE',
      color: Color(0xFF1565C0), // Blue
    );
  }

  factory StatusChip.inactive() {
    return const StatusChip(
      text: 'INACTIVE',
      color: Colors.grey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.secondaryContainer;
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

