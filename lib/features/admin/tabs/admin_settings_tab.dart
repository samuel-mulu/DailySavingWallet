import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/routes.dart';
import '../../../core/settings/calendar_mode.dart';
import '../../auth/providers/auth_providers.dart';
import '../../data/repository_providers.dart';

class AdminSettingsTab extends ConsumerStatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  ConsumerState<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends ConsumerState<AdminSettingsTab> {
  CalendarModeService? _calendarService;
  bool _logoutLoading = false;
  int? _autoFreezeAfterDays;
  bool _autoFreezeLoading = false;
  Future<void> _logout() async {
    if (_logoutLoading) return;
    setState(() => _logoutLoading = true);
    try {
      await ref.read(authClientProvider).signOut();
      if (mounted) {
        AppRoutes.goToAuthGate(context);
      }
    } finally {
      if (mounted) setState(() => _logoutLoading = false);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var saving = false;
        var obscureCurrent = true;
        var obscureNew = true;
        var obscureConfirm = true;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              setDialogState(() => saving = true);
              try {
                await ref.read(authClientProvider).changePassword(
                      currentPassword: currentCtrl.text,
                      newPassword: newCtrl.text,
                    );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password changed. Please login again.'),
                  ),
                );
                await ref.read(authClientProvider).signOut();
                if (mounted) {
                  AppRoutes.goToAuthGate(context);
                }
              } catch (e) {
                if (!dialogContext.mounted) return;
                setDialogState(() => saving = false);
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text('$e')));
              }
            }

            InputDecoration deco(String label, bool obscure, VoidCallback toggle) {
              return InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  ),
                  onPressed: toggle,
                ),
              );
            }

            return AlertDialog(
              title: const Text('Change Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentCtrl,
                      obscureText: obscureCurrent,
                      decoration: deco(
                        'Current Password',
                        obscureCurrent,
                        () => setDialogState(() => obscureCurrent = !obscureCurrent),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 8) {
                          return 'Current password is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newCtrl,
                      obscureText: obscureNew,
                      decoration: deco(
                        'New Password',
                        obscureNew,
                        () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                      validator: (value) {
                        final v = value ?? '';
                        if (v.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: obscureConfirm,
                      decoration: deco(
                        'Confirm New Password',
                        obscureConfirm,
                        () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                      validator: (value) {
                        if ((value ?? '') != newCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!saving) {
                          submit();
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCalendarMode();
    _loadWalletStatusPolicy();
  }

  Future<void> _loadCalendarMode() async {
    final service = await CalendarModeService.getInstance();
    if (!mounted) return;
    setState(() {
      _calendarService = service;
    });
  }

  Future<void> _loadWalletStatusPolicy() async {
    setState(() => _autoFreezeLoading = true);
    try {
      final policy = await ref.read(walletRepoProvider).fetchWalletStatusPolicy();
      if (!mounted) return;
      setState(() {
        _autoFreezeAfterDays = policy.autoFreezeAfterDays;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load wallet freeze setting')),
      );
    } finally {
      if (mounted) setState(() => _autoFreezeLoading = false);
    }
  }

  Future<void> _showAutoFreezeDaysDialog() async {
    final current = _autoFreezeAfterDays ?? 5;
    final ctrl = TextEditingController(text: '$current');
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var saving = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final parsed = int.parse(ctrl.text.trim());
              setDialogState(() => saving = true);
              try {
                final updated = await ref
                    .read(walletRepoProvider)
                    .updateWalletStatusPolicy(autoFreezeAfterDays: parsed);
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                setState(() => _autoFreezeAfterDays = updated.autoFreezeAfterDays);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Auto-freeze updated to ${updated.autoFreezeAfterDays} day(s)',
                    ),
                  ),
                );
              } catch (e) {
                if (!dialogContext.mounted) return;
                setDialogState(() => saving = false);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('$e')),
                );
              }
            }

            return AlertDialog(
              title: const Text('Auto-freeze Days'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Days without daily saving',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null || parsed < 1 || parsed > 60) {
                      return 'Enter a number from 1 to 60';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!saving) submit();
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_calendarService == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ValueListenableBuilder<CalendarMode>(
      valueListenable: _calendarService!,
      builder: (context, mode, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Calendar Mode Card
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Calendar',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SegmentedButton<CalendarMode>(
                        segments: const [
                          ButtonSegment(
                            value: CalendarMode.gregorian,
                            label: Text('Gregorian'),
                            icon: Icon(Icons.calendar_today),
                          ),
                          ButtonSegment(
                            value: CalendarMode.ethiopian,
                            label: Text('Ethiopian'),
                            icon: Icon(Icons.calendar_month),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (Set<CalendarMode> selected) {
                          _calendarService?.setMode(selected.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.av_timer_outlined),
                  title: const Text('Wallet Auto-freeze Days'),
                  subtitle: Text(
                    _autoFreezeAfterDays == null
                        ? 'Load policy'
                        : 'Freeze wallets after $_autoFreezeAfterDays day(s) without daily saving',
                  ),
                  trailing: _autoFreezeLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit_outlined),
                  onTap: _autoFreezeLoading ? null : _showAutoFreezeDaysDialog,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.password),
                  title: const Text('Change Password'),
                  subtitle: const Text('Update your admin password'),
                  onTap: _showChangePasswordDialog,
                ),
              ),
              const SizedBox(height: 8),
              // Logout Card
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  trailing: _logoutLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _logoutLoading ? null : _logout,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
