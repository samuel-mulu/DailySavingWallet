import 'package:flutter/material.dart';

import 'app_brand.dart';
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
  final Future<void> Function()? onLogout;
  final bool logoutLoading;
  final List<Widget>? actions;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.userName,
    this.showLogout = true,
    this.onLogout,
    this.logoutLoading = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = (userName != null && userName!.isNotEmpty)
        ? userName!
        : 'User';
    final compact = MediaQuery.sizeOf(context).width < 380;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppBrand.primary.withValues(alpha: 0.08)),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppBrand.primary.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const AppLogo(
            size: 52,
            borderRadius: 16,
            padding: 5,
            showShadow: false,
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
                      color: AppBrand.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppBrand.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          if (userName != null && userName!.trim().isNotEmpty) ...<Widget>[
            Container(
              constraints: BoxConstraints(maxWidth: compact ? 52 : 156),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppBrand.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppBrand.primary.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: AppBrand.primary,
                  ),
                  if (!compact) ...<Widget>[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppBrand.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          const CalendarToggleBtn(),
          if (actions != null) const SizedBox(width: 8),
          if (actions != null) ...actions!,
          if (showLogout)
            IconButton(
              onPressed: logoutLoading || onLogout == null ? null : () => onLogout!.call(),
              icon: logoutLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout_rounded),
              tooltip: 'Logout',
              style: IconButton.styleFrom(foregroundColor: AppBrand.textMuted),
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
    final cardColor = color ?? AppBrand.primary;

    return Card(
      elevation: 2,
      shadowColor: cardColor.withValues(alpha: 0.2),
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
                  color: cardColor.withValues(alpha: 0.1),
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
                  color: AppBrand.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(fontSize: 13, color: AppBrand.textMuted),
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
    final actionColor = color ?? AppBrand.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: actionColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: actionColor.withValues(alpha: 0.2)),
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
