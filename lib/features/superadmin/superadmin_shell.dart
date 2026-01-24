import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SuperAdminShell extends StatelessWidget {
  const SuperAdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SuperAdmin'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('SuperAdmin tools will appear here.'),
            ),
          ),
        ],
      ),
    );
  }
}

