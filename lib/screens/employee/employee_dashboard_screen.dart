import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmployeeDashboardScreen extends StatelessWidget {
  const EmployeeDashboardScreen({
    required this.fullName,
    required this.employeeId,
    super.key,
  });

  final String fullName;
  final String employeeId;

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
          'Employee Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1554DC), Color(0xFF398CFA)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 38, color: Color(0xFF2878EC)),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Employee ID: $employeeId',
                        style: const TextStyle(color: Color(0xFFDCEAFF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _EmployeeSummaryCard(
                title: 'Attendance This Month',
                value: '20 Days',
                icon: Icons.calendar_month_outlined,
              ),
              _EmployeeSummaryCard(
                title: 'Late Occurrences',
                value: '1',
                icon: Icons.schedule_outlined,
              ),
              _EmployeeSummaryCard(
                title: 'Overtime',
                value: '8 Hours',
                icon: Icons.more_time_outlined,
              ),
              _EmployeeSummaryCard(
                title: 'Leave Balance',
                value: '5 Days',
                icon: Icons.event_available_outlined,
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Employee Services',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _EmployeeModule(
                title: 'Time In / Time Out',
                icon: Icons.fingerprint,
              ),
              _EmployeeModule(title: 'My Attendance', icon: Icons.history),
              _EmployeeModule(
                title: 'My Leave',
                icon: Icons.event_note_outlined,
              ),
              _EmployeeModule(
                title: 'My Payslips',
                icon: Icons.receipt_long_outlined,
              ),
              _EmployeeModule(
                title: 'My Evaluation',
                icon: Icons.assessment_outlined,
              ),
              _EmployeeModule(title: 'My Profile', icon: Icons.person_outline),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmployeeSummaryCard extends StatelessWidget {
  const _EmployeeSummaryCard({
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
      width: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE3E8EF)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFEAF3FF),
            child: Icon(icon, color: const Color(0xFF2878EC)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeModule extends StatelessWidget {
  const _EmployeeModule({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
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
                Icon(icon, color: const Color(0xFF2878EC), size: 31),
                const SizedBox(width: 15),
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
