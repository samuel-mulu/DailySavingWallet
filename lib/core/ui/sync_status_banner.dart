import 'package:flutter/material.dart';

import '../network/reachability_host.dart';

/// Device offline vs server unreachable (e.g. cold Render), plus Retry for health probe.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ReachabilityHost.instance,
      builder: (context, _) {
        final host = ReachabilityHost.instance;
        if (!host.deviceOnline) {
          return _BannerChrome(
            background: Theme.of(context).colorScheme.errorContainer,
            foreground: Theme.of(context).colorScheme.onErrorContainer,
            icon: Icons.wifi_off_rounded,
            title: 'No internet connection',
            subtitle:
                'Reconnect to use the app. Saved data may still show until refreshed.',
            action: null,
          );
        }
        if (host.serverReachable == false) {
          return _BannerChrome(
            background: Theme.of(context).colorScheme.tertiaryContainer,
            foreground: Theme.of(context).colorScheme.onTertiaryContainer,
            icon: Icons.cloud_off_rounded,
            title: 'Cannot reach server',
            subtitle:
                'Free hosting may sleep after idle time — wait 30–60s and tap Retry, '
                'or try again in a moment.',
            action: TextButton(
              onPressed: () => ReachabilityHost.instance.probeServer(),
              child: const Text('Retry'),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _BannerChrome extends StatelessWidget {
  const _BannerChrome({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: foreground.withValues(alpha: 0.92),
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}
