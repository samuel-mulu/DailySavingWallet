import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/ui/app_header.dart';

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_index) {
      0 => const _SuperAdminDashboard(),
      1 => const _AdminManagement(),
      _ => const _SuperAdminSettings(),
    };

    return Scaffold(
      backgroundColor: const Color(0xFFFEFBFF),
      body: SafeArea(child: body),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF8B5CF6).withOpacity(0.15),
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: Color(0xFF8B5CF6)),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings, color: Color(0xFF8B5CF6)),
              label: 'Admins',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings, color: Color(0xFF8B5CF6)),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class _SuperAdminDashboard extends StatelessWidget {
  const _SuperAdminDashboard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppHeader(
          title: 'Super Admin',
          subtitle: 'System Overview',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total', 'Admins', '—',
                      Icons.admin_panel_settings_rounded,
                      const Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Active', 'Users', '—',
                      Icons.people_rounded,
                      const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              const SizedBox(height: 12),
              _buildActionTile(
                context,
                Icons.person_add_rounded,
                'Add Admin',
                'Create a new admin account',
                const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 8),
              _buildActionTile(
                context,
                Icons.analytics_rounded,
                'View Reports',
                'System-wide analytics',
                const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 24),
              _buildInfoCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String subtitle, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shadowColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
            const SizedBox(height: 4),
            Text('$title\n$subtitle', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, IconData icon, String title, String subtitle, Color color) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title coming soon'))),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF2D2D2D))),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF6B7280)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF8B5CF6).withOpacity(0.1), const Color(0xFF7C3AED).withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.shield_rounded, color: Color(0xFF8B5CF6), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Super Admin Access', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6), fontSize: 14)),
                SizedBox(height: 4),
                Text('You have full system access.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminManagement extends StatelessWidget {
  const _AdminManagement();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppHeader(title: 'Admin Management', subtitle: 'Manage administrators'),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.admin_panel_settings_rounded, size: 40, color: Color(0xFF8B5CF6)),
                ),
                const SizedBox(height: 20),
                const Text('Admin Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
                const SizedBox(height: 8),
                const Text('Coming soon...', style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SuperAdminSettings extends StatelessWidget {
  const _SuperAdminSettings();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppHeader(title: 'Settings', subtitle: 'System configuration'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 1,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () => FirebaseAuth.instance.signOut(),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: const Color(0xFFC62828).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.logout_rounded, color: Color(0xFFC62828), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Logout', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFFC62828))),
                              SizedBox(height: 2),
                              Text('Sign out of your account', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
