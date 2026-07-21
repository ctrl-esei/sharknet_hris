import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({
    required this.onRunPayroll,
    required this.onAddEmployee,
    required this.onFaceAttendance,
    required this.onApproveLeaves,
    super.key,
  });

  final VoidCallback onRunPayroll;
  final VoidCallback onAddEmployee;
  final VoidCallback onFaceAttendance;
  final VoidCallback onApproveLeaves;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: Color(0xFF101828),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool oneColumn =
                  constraints.maxWidth < 330;

              final double buttonWidth = oneColumn
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _QuickActionButton(
                    width: buttonWidth,
                    title: 'Run Payroll',
                    icon: Icons.calculate_outlined,
                    foregroundColor: const Color(0xFFF04B0B),
                    backgroundColor: const Color(0xFFFFF7ED),
                    borderColor: const Color(0xFFFFDDBD),
                    onTap: onRunPayroll,
                  ),
                  _QuickActionButton(
                    width: buttonWidth,
                    title: 'Add Employee',
                    icon: Icons.add_rounded,
                    foregroundColor: const Color(0xFF1F5CF5),
                    backgroundColor: const Color(0xFFF0F6FF),
                    borderColor: const Color(0xFFD2E2FF),
                    onTap: onAddEmployee,
                  ),
                  _QuickActionButton(
                    width: buttonWidth,
                    title: 'Face Attendance',
                    icon: Icons.fingerprint,
                    foregroundColor: const Color(0xFF00A83B),
                    backgroundColor: const Color(0xFFEEFCF3),
                    borderColor: const Color(0xFFC8F1D5),
                    onTap: onFaceAttendance,
                  ),
                  _QuickActionButton(
                    width: buttonWidth,
                    title: 'Approve Leaves',
                    icon: Icons.task_alt_outlined,
                    foregroundColor: const Color(0xFF9A22FF),
                    backgroundColor: const Color(0xFFFAF2FF),
                    borderColor: const Color(0xFFEBD8FF),
                    onTap: onApproveLeaves,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.width,
    required this.title,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
  });

  final double width;
  final String title;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 60,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: foregroundColor,
                  size: 24,
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
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

class PendingLeaveNotifications extends StatelessWidget {
  const PendingLeaveNotifications({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _pendingLeaves() {
    return FirebaseFirestore.instance
        .collection('leave_request')
        .where('status', isEqualTo: 'pending')
        .limit(2)
        .snapshots();
  }

  Future<void> _changeStatus({
    required BuildContext context,
    required DocumentReference<Map<String, dynamic>> reference,
    required String employeeName,
    required String status,
  }) async {
    try {
      final String? userUid =
          FirebaseAuth.instance.currentUser?.uid;

      await reference.update({
        'status': status,
        'reviewedBy': userUid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      final bool approved = status == 'approved';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? '$employeeName leave request approved.'
                : '$employeeName leave request rejected.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: approved
              ? const Color(0xFF039855)
              : const Color(0xFFD92D20),
        ),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ??
                'Unable to update the leave request.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFD92D20),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pendingLeaves(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildContainer(
            child: const SizedBox(
              height: 130,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint(
            'Unable to load pending leaves: ${snapshot.error}',
          );

          return _buildContainer(
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'Unable to load pending leave requests.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFD92D20),
                  ),
                ),
              ),
            ),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        return _buildContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pending Leave Requests',
                      style: TextStyle(
                        color: Color(0xFF9E3D00),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (documents.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE8B5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${documents.length}',
                        style: const TextStyle(
                          color: Color(0xFF9E3D00),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (documents.isEmpty)
                const _NoPendingLeaves()
              else
                ...List.generate(
                  documents.length,
                  (index) {
                    final document = documents[index];
                    final data = document.data();

                    final String employeeName =
                        (data['employeeName'] ?? 'Employee')
                            .toString();

                    final String leaveType = _formatLeaveType(
                      (data['leaveType'] ?? 'Leave').toString(),
                    );

                    final int numberOfDays = _readDays(
                      data['numberOfDays'],
                    );

                    return Column(
                      children: [
                        _PendingLeaveRow(
                          employeeName: employeeName,
                          leaveDetails:
                              '$leaveType · $numberOfDays '
                              '${numberOfDays == 1 ? 'day' : 'days'}',
                          onApprove: () {
                            _changeStatus(
                              context: context,
                              reference: document.reference,
                              employeeName: employeeName,
                              status: 'approved',
                            );
                          },
                          onReject: () {
                            _changeStatus(
                              context: context,
                              reference: document.reference,
                              employeeName: employeeName,
                              status: 'rejected',
                            );
                          },
                        ),
                        if (index < documents.length - 1)
                          const Divider(
                            height: 1,
                            color: Color(0xFFFFE0A1),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContainer({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFE3A1),
        ),
      ),
      child: child,
    );
  }

  static int _readDays(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatLeaveType(String value) {
    final String cleaned =
        value.trim().replaceAll('_', ' ');

    if (cleaned.isEmpty) {
      return 'Leave';
    }

    final String formatted = cleaned
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}'
              '${word.substring(1).toLowerCase()}',
        )
        .join(' ');

    if (formatted.toLowerCase().endsWith('leave')) {
      return formatted;
    }

    return '$formatted Leave';
  }
}

class _PendingLeaveRow extends StatelessWidget {
  const _PendingLeaveRow({
    required this.employeeName,
    required this.leaveDetails,
    required this.onApprove,
    required this.onReject,
  });

  final String employeeName;
  final String leaveDetails;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  leaveDetails,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _DecisionButton(
            icon: Icons.check_rounded,
            tooltip: 'Approve leave',
            foregroundColor: const Color(0xFF008F38),
            backgroundColor: const Color(0xFFD6FBE4),
            onTap: onApprove,
          ),
          const SizedBox(width: 9),
          _DecisionButton(
            icon: Icons.close_rounded,
            tooltip: 'Reject leave',
            foregroundColor: const Color(0xFFE11D48),
            backgroundColor: const Color(0xFFFFE1E7),
            onTap: onReject,
          ),
        ],
      ),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    required this.icon,
    required this.tooltip,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 43,
            height: 43,
            child: Icon(
              icon,
              color: foregroundColor,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoPendingLeaves extends StatelessWidget {
  const _NoPendingLeaves();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.task_alt_rounded,
              color: Color(0xFF039855),
              size: 38,
            ),
            SizedBox(height: 10),
            Text(
              'No pending leave requests',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}