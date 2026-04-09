import 'package:flutter/material.dart';

import 'calendar_toggle_btn.dart';

/// Reusable modern app header with user info and actions.
///
/// [userName] is shown in the avatar chip; when null, `'User'` is used.
/// When [showLogout] is true, pass [onLogout] for sign-out (e.g. from a
/// parent [Consumer] that reads [authClientProvider]).
class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? userName;
  final bool showLogout;
  final VoidCallback? onLogout;
  final List<Widget>? actions;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.userName,
    this.showLogout = true,
    this.onLogout,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final displayName =
        (userName != null && userName!.isNotEmpty) ? userName! : 'User';
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
              ],
            ),
          ),

          const CalendarToggleBtn(),

          if (actions != null) const SizedBox(width: 8),
          if (actions != null) ...actions!,

          if (showLogout)
            IconButton(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Logout',
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dashboard stat card widget
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? const Color(0xFF8B5CF6);

    return Card(
      elevation: 2,
      shadowColor: cardColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: cardColor, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick action button for dashboard
class DashboardAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const DashboardAction({
    super.key,
    required this.label,
    required this.icon,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final actionColor = color ?? const Color(0xFF8B5CF6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: actionColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: actionColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: actionColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: actionColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
