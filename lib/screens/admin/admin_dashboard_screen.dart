import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/session_tracking_service.dart';
import '../../services/system_monitor_service.dart';
import 'admin_audit_screen.dart';
import 'admin_dashboard_home.dart';
import 'admin_monitor_screen.dart';
import 'admin_users_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    this.fullName = 'Admin',
    this.adminId = 'ADMIN',
    this.onLogout,
  });

  final String fullName;
  final String adminId;
  final VoidCallback? onLogout;

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    unawaited(
      SessionTrackingService.instance.start(
        role: 'admin',
      ),
    );

    SystemMonitorService.instance
        .startMonitoring();
  }

  @override
  void dispose() {
    SystemMonitorService.instance
        .stopMonitoring();

    unawaited(
      SessionTrackingService.instance.stop(),
    );

    super.dispose();
  }

  void _selectPage(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    await SessionTrackingService.instance
        .stop();

    SystemMonitorService.instance
        .stopMonitoring();

    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }

    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      AdminDashboardHome(
        fullName: widget.fullName,
        adminId: widget.adminId,
        onSelectPage: _selectPage,
        onLogout: () {
          unawaited(_logout());
        },
      ),
      const AdminUsersScreen(),
      const AdminMonitorScreen(),
      const AdminAuditScreen(),
    ];

    return Scaffold(
      backgroundColor:
          const Color(0xFFF2F6FC),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Color(0xFFE4E7EC),
              ),
            ),
          ),
          child: NavigationBar(
            height: 78,
            selectedIndex: _selectedIndex,
            onDestinationSelected:
                _selectPage,
            backgroundColor: Colors.white,
            indicatorColor:
                const Color(0xFFF5E8FF),
            labelBehavior:
                NavigationDestinationLabelBehavior
                    .alwaysShow,
            destinations: const <
                NavigationDestination>[
              NavigationDestination(
                icon: Icon(
                  Icons.monitor_heart_outlined,
                ),
                selectedIcon: Icon(
                  Icons.monitor_heart_rounded,
                ),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon:
                    Icon(Icons.group_outlined),
                selectedIcon:
                    Icon(Icons.group_rounded),
                label: 'Users',
              ),
              NavigationDestination(
                icon:
                    Icon(Icons.shield_outlined),
                selectedIcon:
                    Icon(Icons.shield_rounded),
                label: 'Monitor',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.description_outlined,
                ),
                selectedIcon: Icon(
                  Icons.description_rounded,
                ),
                label: 'Audit',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
