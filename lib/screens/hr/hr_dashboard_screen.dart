import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'hr_attendance_screen.dart';
import 'hr_dashboard_home.dart';
import 'hr_employees_screen.dart';
import 'leave_management_screen.dart';
import 'payroll_management_screen.dart';

class HrDashboardScreen extends StatefulWidget {
  const HrDashboardScreen({required this.fullName, this.employeeId, super.key});

  final String fullName;
  final String? employeeId;

  @override
  State<HrDashboardScreen> createState() => _HrDashboardScreenState();
}

class _HrDashboardScreenState extends State<HrDashboardScreen> {
  int _selectedIndex = 0;

  Future<void> _logout() async {
    final bool shouldLogout = await _showLogoutConfirmation() ?? false;

    if (!shouldLogout) {
      return;
    }

    await FirebaseAuth.instance.signOut();
  }

  Future<bool?> _showLogoutConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text(
            'Are you sure you want to sign out of the HR portal?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD94305),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  String get _displayedName {
    final String cleanedName = widget.fullName.trim();

    if (cleanedName.isEmpty) {
      return 'Sharknet HR Admin';
    }

    return cleanedName;
  }

  String? get _displayedEmployeeId {
    final String? cleanedId = widget.employeeId?.trim();

    if (cleanedId == null ||
        cleanedId.isEmpty ||
        cleanedId.toLowerCase() == 'null') {
      return null;
    }

    return cleanedId.toUpperCase();
  }

  void _selectPage(int index) {
    if (index < 0 || index > 4) {
      return;
    }

    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildDashboardHome() {
    return HrDashboardHome(
      onRunPayroll: () => _selectPage(4),
      onAddEmployee: () => _selectPage(1),
      onFaceAttendance: () => _selectPage(2),
      onApproveLeaves: () => _selectPage(3),
    );
  }

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardHome();

      case 1:
        return const HrEmployeesScreen();

      case 2:
        return const HrAttendanceScreen();

      case 3:
        return const HrLeaveScreen();

      case 4:
        return const PayrollManagementScreen();

      default:
        return _buildDashboardHome();
    }
  }

  String get _currentPageName {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';

      case 1:
        return 'Employees';

      case 2:
        return 'Attendance';

      case 3:
        return 'Leave';

      case 4:
        return 'Payroll';

      default:
        return 'Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FC),
      body: Column(
        children: [
          _HrHeader(
            fullName: _displayedName,
            employeeId: _displayedEmployeeId,
            currentPageName: _currentPageName,
            onLogout: _logout,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedIndex),
                child: _buildSelectedPage(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _HrBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectPage,
      ),
    );
  }
}

// ============================================================
// HR HEADER
// ============================================================

class _HrHeader extends StatelessWidget {
  const _HrHeader({
    required this.fullName,
    required this.employeeId,
    required this.currentPageName,
    required this.onLogout,
  });

  final String fullName;
  final String? employeeId;
  final String currentPageName;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;

        final bool compactLayout = availableWidth < 410;
        final bool veryCompactLayout = availableWidth < 350;

        final double horizontalPadding = veryCompactLayout ? 16 : 22;

        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFD94305), Color(0xFFFF5A08)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
                horizontalPadding,
                23,
              ),
              child: compactLayout
                  ? _buildCompactHeader(veryCompactLayout: veryCompactLayout)
                  : _buildWideHeader(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWideHeader() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _PortalTitle(
            titleFontSize: 28,
            currentPageName: currentPageName,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: _UserInformation(
            fullName: fullName,
            employeeId: employeeId,
            alignment: CrossAxisAlignment.end,
          ),
        ),
        const SizedBox(width: 12),
        _LogoutButton(onPressed: onLogout),
      ],
    );
  }

  Widget _buildCompactHeader({required bool veryCompactLayout}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PortalTitle(
                titleFontSize: veryCompactLayout ? 23 : 26,
                currentPageName: currentPageName,
              ),
            ),
            const SizedBox(width: 10),
            _LogoutButton(onPressed: onLogout),
          ],
        ),
        const SizedBox(height: 17),
        _UserInformation(
          fullName: fullName,
          employeeId: employeeId,
          alignment: CrossAxisAlignment.start,
        ),
      ],
    );
  }
}

class _PortalTitle extends StatelessWidget {
  const _PortalTitle({
    required this.titleFontSize,
    required this.currentPageName,
  });

  final double titleFontSize;
  final String currentPageName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HR PORTAL',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFFFFD5C4),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Payroll & HR',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleFontSize,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          currentPageName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFFFE7DD),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _UserInformation extends StatelessWidget {
  const _UserInformation({
    required this.fullName,
    required this.employeeId,
    required this.alignment,
  });

  final String fullName;
  final String? employeeId;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final bool alignRight = alignment == CrossAxisAlignment.end;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (employeeId != null) ...[
          const SizedBox(height: 3),
          Text(
            employeeId!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              color: Color(0xFFFFD5C4),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else ...[
          const SizedBox(height: 3),
          const Text(
            'HR Administrator',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFFFFD5C4),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x33FFFFFF),
      shape: const CircleBorder(side: BorderSide(color: Color(0x66FFFFFF))),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'Sign out',
        iconSize: 24,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.logout_rounded, color: Colors.white),
      ),
    );
  }
}

// ============================================================
// CUSTOM BOTTOM NAVIGATION
// ============================================================

class _HrBottomNavigationBar extends StatelessWidget {
  const _HrBottomNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    const List<_HrNavigationDestination> destinations = [
      _HrNavigationDestination(
        label: 'Dashboard',
        icon: Icons.bar_chart_rounded,
      ),
      _HrNavigationDestination(label: 'Employees', icon: Icons.groups_outlined),
      _HrNavigationDestination(label: 'Attendance', icon: Icons.fingerprint),
      _HrNavigationDestination(
        label: 'Leave',
        icon: Icons.calendar_month_outlined,
      ),
      _HrNavigationDestination(
        label: 'Payroll',
        icon: Icons.calculate_outlined,
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE4E7EC))),
        boxShadow: [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool veryNarrow = constraints.maxWidth < 350;

            return SizedBox(
              height: veryNarrow ? 72 : 78,
              child: Row(
                children: List.generate(destinations.length, (index) {
                  final _HrNavigationDestination destination =
                      destinations[index];

                  return Expanded(
                    child: _HrNavigationItem(
                      label: destination.label,
                      icon: destination.icon,
                      selected: selectedIndex == index,
                      compact: veryNarrow,
                      onTap: () {
                        onDestinationSelected(index);
                      },
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HrNavigationItem extends StatelessWidget {
  const _HrNavigationItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  static const Color _selectedColor = Color(0xFFF04B0B);

  static const Color _unselectedColor = Color(0xFF98A2B3);

  @override
  Widget build(BuildContext context) {
    final Color itemColor = selected ? _selectedColor : _unselectedColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          selected: selected,
          button: true,
          label: label,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: compact ? 23 : 25, color: itemColor),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: itemColor,
                        fontSize: compact ? 10.5 : 12,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 6 : 0,
                  height: selected ? 6 : 0,
                  decoration: const BoxDecoration(
                    color: _selectedColor,
                    shape: BoxShape.circle,
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

class _HrNavigationDestination {
  const _HrNavigationDestination({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
