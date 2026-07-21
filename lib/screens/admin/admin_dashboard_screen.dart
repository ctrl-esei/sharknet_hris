import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({required this.fullName, super.key});

  final String fullName;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                fullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            onPressed: _logout,
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Welcome, $fullName',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          const Text(
            'System overview and administrative controls',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 25),
          const Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _AdminCard(
                title: 'Total Users',
                value: '12',
                icon: Icons.groups_outlined,
              ),
              _AdminCard(
                title: 'Active Users',
                value: '10',
                icon: Icons.person_outline,
              ),
              _AdminCard(
                title: 'Admin Users',
                value: '2',
                icon: Icons.admin_panel_settings_outlined,
              ),
              _AdminCard(
                title: 'HR Users',
                value: '3',
                icon: Icons.badge_outlined,
              ),
              _AdminCard(
                title: 'Employee Users',
                value: '7',
                icon: Icons.work_outline,
              ),
              _AdminCard(
                title: 'Active Sessions',
                value: '4',
                icon: Icons.computer_outlined,
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Administrative Modules',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _AdminModule(
                title: 'User Management',
                icon: Icons.manage_accounts_outlined,
              ),
              _AdminModule(
                title: 'Role Management',
                icon: Icons.security_outlined,
              ),
              _AdminModule(
                title: 'System Monitoring',
                icon: Icons.monitor_heart_outlined,
              ),
              _AdminModule(title: 'Audit Logs', icon: Icons.history_outlined),
              _AdminModule(
                title: 'System Settings',
                icon: Icons.settings_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFEAF3FF),
            child: Icon(icon, color: const Color(0xFF2878EC)),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminModule extends StatelessWidget {
  const _AdminModule({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 110,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title will be developed next.')),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(icon, size: 32, color: const Color(0xFF2878EC)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
