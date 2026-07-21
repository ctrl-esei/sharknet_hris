import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/admin/admin_dashboard_screen.dart' as admin_screen;
import '../screens/employee/employee_dashboard_screen.dart'
    as employee_screen;
import '../screens/hr/hr_dashboard_screen.dart' as hr_screen;
import '../screens/login_screen.dart' as login_screen;

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(
            message: 'Checking authentication...',
          );
        }

        if (authSnapshot.hasError) {
          return _ErrorScreen(
            title: 'Authentication error',
            message:
                authSnapshot.error?.toString() ??
                'Unable to check your authentication status.',
          );
        }

        final User? currentUser = authSnapshot.data;

        if (currentUser == null) {
          return const login_screen.LoginScreen();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const _LoadingScreen(
                message: 'Loading your profile...',
              );
            }

            if (profileSnapshot.hasError) {
              return _ErrorScreen(
                title: 'Unable to load profile',
                message:
                    profileSnapshot.error?.toString() ??
                    'An error occurred while loading your profile.',
              );
            }

            final DocumentSnapshot<Map<String, dynamic>>? document =
                profileSnapshot.data;

            if (document == null || !document.exists) {
              return const _ErrorScreen(
                title: 'Profile not found',
                message:
                    'Your Firebase Authentication account exists, but no '
                    'matching document was found in the Firestore users '
                    'collection. The users document ID must match your '
                    'Firebase Authentication UID.',
              );
            }

            final Map<String, dynamic> data =
                document.data() ?? <String, dynamic>{};

            final String fullName = _readString(
              data['fullName'],
              fallback: 'User',
            );

            final String role = _readString(
              data['role'],
            ).toLowerCase();

            final String accountStatus = _readString(
              data['accountStatus'],
            ).toLowerCase();

            final String? employeeId = _readNullableString(
              data['employeeId'],
            );

            if (accountStatus != 'active') {
              return const _ErrorScreen(
                title: 'Account inactive',
                message:
                    'This account is currently inactive. Please contact '
                    'the system administrator.',
              );
            }

            switch (role) {
              case 'admin':
                return admin_screen.AdminDashboardScreen(
                  fullName: fullName,
                );

              case 'hr':
                return hr_screen.HrDashboardScreen(
                  fullName: fullName,
                  employeeId: employeeId,
                );

              case 'employee':
                if (employeeId == null) {
                  return const _ErrorScreen(
                    title: 'Employee ID missing',
                    message:
                        'This employee account does not have an employeeId '
                        'in its Firestore users profile.',
                  );
                }

                return employee_screen.EmployeeDashboardScreen(
                  fullName: fullName,
                  employeeId: employeeId,
                );

              default:
                return _ErrorScreen(
                  title: 'Invalid user role',
                  message:
                      'The role "$role" is not recognized. Use admin, hr, '
                      'or employee.',
                );
            }
          },
        );
      },
    );
  }

  static String _readString(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    final String result = value.toString().trim();

    if (result.isEmpty || result.toLowerCase() == 'null') {
      return fallback;
    }

    return result;
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final String result = value.toString().trim();

    if (result.isEmpty || result.toLowerCase() == 'null') {
      return null;
    }

    return result;
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 14,
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

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  Future<void> _returnToLogin() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE4E7EC),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 55,
                      color: Color(0xFFD92D20),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _returnToLogin,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Return to login'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}