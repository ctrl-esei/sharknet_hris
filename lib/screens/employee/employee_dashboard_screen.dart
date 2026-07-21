import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'employee_attendance_screen.dart';
import 'employee_payslips_screen.dart';
import 'employee_leave_screen.dart';
import 'employee_profile_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({
    super.key,
    required this.fullName,
    required this.employeeId,
    this.position = 'Employee',
    this.onLogout,
  });

  final String fullName;
  final String employeeId;
  final String position;
  final VoidCallback? onLogout;

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState
    extends State<EmployeeDashboardScreen> {
  int _selectedIndex = 0;

  void _selectPage(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      _EmployeeHomePage(
        fullName: widget.fullName,
        employeeId: widget.employeeId,
        position: widget.position,
        onOpenAttendance: () => _selectPage(1),
        onOpenPayslips: () => _selectPage(2),
        onOpenLeave: () => _selectPage(3),
        onOpenProfile: () => _selectPage(4),
        onLogout: widget.onLogout,
      ),
      EmployeeAttendanceScreen(
        employeeId: widget.employeeId,
        fullName: widget.fullName,
      ),
      EmployeePayslipsScreen(
        employeeId: widget.employeeId,
        fullName: widget.fullName,
      ),
      EmployeeLeaveScreen(
        employeeId: widget.employeeId,
        fullName: widget.fullName,
      ),
      EmployeeProfileScreen(
        employeeId: widget.employeeId,
        fullName: widget.fullName,
        position: widget.position,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FC),
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
            onDestinationSelected: _selectPage,
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFEAF2FF),
            labelBehavior:
                NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.fingerprint_outlined),
                selectedIcon: Icon(Icons.fingerprint),
                label: 'Attendance',
              ),
              NavigationDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description_rounded),
                label: 'Payslips',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded),
                label: 'Leave',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeHomePage extends StatefulWidget {
  const _EmployeeHomePage({
    required this.fullName,
    required this.employeeId,
    required this.position,
    required this.onOpenAttendance,
    required this.onOpenPayslips,
    required this.onOpenLeave,
    required this.onOpenProfile,
    this.onLogout,
  });

  final String fullName;
  final String employeeId;
  final String position;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenPayslips;
  final VoidCallback onOpenLeave;
  final VoidCallback onOpenProfile;
  final VoidCallback? onLogout;

  @override
  State<_EmployeeHomePage> createState() =>
      _EmployeeHomePageState();
}

class _EmployeeHomePageState
    extends State<_EmployeeHomePage> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  late final Future<
          DocumentReference<Map<String, dynamic>>>
      _employeeReferenceFuture;

  @override
  void initState() {
    super.initState();

    _employeeReferenceFuture =
        _resolveEmployeeReference();

    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _now = DateTime.now();
        });
      },
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<DocumentReference<Map<String, dynamic>>>
      _resolveEmployeeReference() async {
    final FirebaseFirestore firestore =
        FirebaseFirestore.instance;

    final String suppliedId =
        widget.employeeId.trim();

    if (suppliedId.isEmpty) {
      throw StateError(
        'The employee ID is missing from the signed-in account.',
      );
    }

    final DocumentReference<Map<String, dynamic>>
        directReference =
        firestore.collection('employee').doc(suppliedId);

    final DocumentSnapshot<Map<String, dynamic>>
        directSnapshot =
        await directReference.get();

    if (directSnapshot.exists) {
      return directReference;
    }

    final QuerySnapshot<Map<String, dynamic>>
        employeeIdQuery = await firestore
            .collection('employee')
            .where('employeeId', isEqualTo: suppliedId)
            .limit(1)
            .get();

    if (employeeIdQuery.docs.isNotEmpty) {
      return employeeIdQuery.docs.first.reference;
    }

    final QuerySnapshot<Map<String, dynamic>>
        employeeCodeQuery = await firestore
            .collection('employee')
            .where('employeeCode', isEqualTo: suppliedId)
            .limit(1)
            .get();

    if (employeeCodeQuery.docs.isNotEmpty) {
      return employeeCodeQuery.docs.first.reference;
    }

    throw StateError(
      'No employee record matches "$suppliedId".',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        DocumentReference<Map<String, dynamic>>>(
      future: _employeeReferenceFuture,
      builder: (
        BuildContext context,
        AsyncSnapshot<
                DocumentReference<Map<String, dynamic>>>
            referenceSnapshot,
      ) {
        if (referenceSnapshot.connectionState !=
            ConnectionState.done) {
          return const _DashboardLoadingState();
        }

        if (referenceSnapshot.hasError ||
            !referenceSnapshot.hasData) {
          return _DashboardErrorState(
            message: referenceSnapshot.error?.toString() ??
                'Unable to resolve the employee record.',
          );
        }

        final DocumentReference<Map<String, dynamic>>
            employeeReference =
            referenceSnapshot.data!;

        return StreamBuilder<
            DocumentSnapshot<Map<String, dynamic>>>(
          stream: employeeReference.snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<
                    DocumentSnapshot<
                        Map<String, dynamic>>>
                employeeSnapshot,
          ) {
            if (!employeeSnapshot.hasData) {
              return const _DashboardLoadingState();
            }

            if (!employeeSnapshot.data!.exists) {
              return const _DashboardErrorState(
                message:
                    'The employee record no longer exists.',
              );
            }

            final Map<String, dynamic> employeeData =
                employeeSnapshot.data!.data() ??
                    <String, dynamic>{};

            return StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('attendance')
                  .where(
                    'employeeId',
                    isEqualTo: employeeReference,
                  )
                  .snapshots(),
              builder: (
                BuildContext context,
                AsyncSnapshot<
                        QuerySnapshot<
                            Map<String, dynamic>>>
                    attendanceSnapshot,
              ) {
                final List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    attendanceDocuments =
                    attendanceSnapshot.data?.docs ??
                        <QueryDocumentSnapshot<
                            Map<String, dynamic>>>[];

                final _AttendanceDashboardSummary
                    attendanceSummary =
                    _buildAttendanceSummary(
                  attendanceDocuments,
                );

                final String currentUserId =
                    FirebaseAuth.instance.currentUser?.uid ??
                        '';

                final Stream<
                        QuerySnapshot<
                            Map<String, dynamic>>>
                    notificationStream =
                    currentUserId.isEmpty
                        ? const Stream<
                            QuerySnapshot<
                                Map<String,
                                    dynamic>>>.empty()
                        : FirebaseFirestore.instance
                            .collection('notifications')
                            .where(
                              'userId',
                              isEqualTo: currentUserId,
                            )
                            .snapshots();

                return StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: notificationStream,
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<
                            QuerySnapshot<
                                Map<String, dynamic>>>
                        notificationSnapshot,
                  ) {
                    final _NotificationSummary
                        notificationSummary =
                        _buildNotificationSummary(
                      notificationSnapshot.data?.docs ??
                          <QueryDocumentSnapshot<
                              Map<String, dynamic>>>[],
                    );

                    return _buildDashboard(
                      employeeReference:
                          employeeReference,
                      employeeData: employeeData,
                      attendanceSummary:
                          attendanceSummary,
                      notificationSummary:
                          notificationSummary,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDashboard({
    required DocumentReference<Map<String, dynamic>>
        employeeReference,
    required Map<String, dynamic> employeeData,
    required _AttendanceDashboardSummary
        attendanceSummary,
    required _NotificationSummary notificationSummary,
  }) {
    final String fullName =
        _readText(
          employeeData['fullName'],
          fallback: widget.fullName,
        );

    final String position =
        _readText(
          employeeData['position'],
          fallback: widget.position,
        );

    final String employeeCode =
        _readText(
          employeeData['employeeId'],
          fallback: employeeReference.id,
        ).toUpperCase();

    return ColoredBox(
      color: const Color(0xFFF2F6FC),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _buildHeader(
                fullName: fullName,
                position: position,
                employeeCode: employeeCode,
                unreadNotifications:
                    notificationSummary.unreadCount,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                30,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    _buildAttendanceCard(
                      attendanceSummary,
                    ),
                    const SizedBox(height: 18),
                    _buildMonthlySummary(
                      attendanceSummary,
                    ),
                    const SizedBox(height: 18),
                    _buildLeaveBalanceCard(
                      employeeReference:
                          employeeReference,
                      employeeData: employeeData,
                    ),
                    const SizedBox(height: 18),
                    _buildLatestPayslipCard(
                      employeeReference,
                    ),
                    const SizedBox(height: 18),
                    _buildNotificationCard(
                      notificationSummary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({
    required String fullName,
    required String position,
    required String employeeCode,
    required int unreadNotifications,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        22,
        28,
        22,
        32,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF2455DB),
            Color(0xFF3D7DF3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${_greeting(_now)},',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _firstName(fullName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$position • $employeeCode',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD8E7FF),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              _HeaderIconButton(
                icon:
                    Icons.notifications_none_rounded,
                onTap: () {
                  _showTemporaryMessage(
                    unreadNotifications == 0
                        ? 'You have no unread notifications.'
                        : 'You have $unreadNotifications unread notification${unreadNotifications == 1 ? '' : 's'}.',
                  );
                },
              ),
              if (unreadNotifications > 0)
                Positioned(
                  top: -8,
                  right: -5,
                  child: _NotificationBadge(
                    count: unreadNotifications,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          _HeaderIconButton(
            icon: Icons.logout_rounded,
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(
    _AttendanceDashboardSummary summary,
  ) {
    final _TodayAttendance? today =
        summary.todayAttendance;

    final bool hasTimeIn = today?.timeIn != null;
    final bool hasTimeOut = today?.timeOut != null;

    final String statusLabel;

    if (!hasTimeIn) {
      statusLabel = 'Not clocked in';
    } else if (!hasTimeOut) {
      statusLabel =
          'Clocked in ${_formatClockTime(today!.timeIn!)}';
    } else {
      statusLabel = 'Attendance completed';
    }

    final String buttonLabel;

    if (!hasTimeIn) {
      buttonLabel =
          'Clock In via Face Recognition';
    } else if (!hasTimeOut) {
      buttonLabel =
          'Clock Out via Face Recognition';
    } else {
      buttonLabel = 'Attendance Completed';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _formatDate(_now),
                  style: const TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: hasTimeOut
                      ? const Color(0xFFECFDF3)
                      : const Color(0xFFF9FAFB),
                  borderRadius:
                      BorderRadius.circular(30),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: hasTimeOut
                        ? const Color(0xFF039855)
                        : const Color(0xFF98A2B3),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatTime(_now),
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          if (hasTimeIn) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              hasTimeOut
                  ? 'Time in: ${_formatClockTime(today!.timeIn!)}  •  Time out: ${_formatClockTime(today.timeOut!)}'
                  : 'Time in: ${_formatClockTime(today!.timeIn!)}',
              style: const TextStyle(
                color: Color(0xFF667085),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              onPressed:
                  hasTimeOut ? null : widget.onOpenAttendance,
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFF08B844),
                disabledBackgroundColor:
                    const Color(0xFFD0D5DD),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(28),
                ),
              ),
              icon: Icon(
                hasTimeOut
                    ? Icons.check_circle_outline
                    : Icons.fingerprint,
                size: 28,
              ),
              label: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummary(
    _AttendanceDashboardSummary summary,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _MetricCard(
            value:
                summary.daysPresent.toString(),
            label: 'Days Present',
            valueColor:
                const Color(0xFF155EEF),
            backgroundColor:
                const Color(0xFFF2F6FC),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            value: _formatHours(
              summary.totalHoursWorked,
            ),
            label: 'Hours Worked',
            valueColor:
                const Color(0xFF00A63E),
            backgroundColor:
                const Color(0xFFEEFFF4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            value: summary.lateCount.toString(),
            label: 'Late Count',
            valueColor:
                const Color(0xFFE66A00),
            backgroundColor:
                const Color(0xFFFFFAE8),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveBalanceCard({
    required DocumentReference<Map<String, dynamic>>
        employeeReference,
    required Map<String, dynamic> employeeData,
  }) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('leave_request')
          .where(
            'employeeId',
            isEqualTo: employeeReference,
          )
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                QuerySnapshot<Map<String, dynamic>>>
            leaveSnapshot,
      ) {
        final _LeaveBalanceSummary balance =
            _calculateLeaveBalance(
          employeeData: employeeData,
          leaveDocuments:
              leaveSnapshot.data?.docs ??
                  <QueryDocumentSnapshot<
                      Map<String, dynamic>>>[],
        );

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Leave Balance',
                      style: TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onOpenLeave,
                    child: const Text(
                      'File Leave →',
                      style: TextStyle(
                        color: Color(0xFF2979FF),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _LeaveBalanceItem(
                      value: _formatLeaveDays(
                        balance.vacation,
                      ),
                      label: 'Vacation',
                      backgroundColor:
                          const Color(0xFFEFF5FF),
                      valueColor:
                          const Color(0xFF155EEF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LeaveBalanceItem(
                      value: _formatLeaveDays(
                        balance.sick,
                      ),
                      label: 'Sick',
                      backgroundColor:
                          const Color(0xFFFFF1F1),
                      valueColor:
                          const Color(0xFFF04438),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LeaveBalanceItem(
                      value: _formatLeaveDays(
                        balance.emergency,
                      ),
                      label: 'Emergency',
                      backgroundColor:
                          const Color(0xFFFFF7E8),
                      valueColor:
                          const Color(0xFFF79009),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLatestPayslipCard(
    DocumentReference<Map<String, dynamic>>
        employeeReference,
  ) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('payslips')
          .where(
            'employeeId',
            isEqualTo: employeeReference,
          )
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                QuerySnapshot<Map<String, dynamic>>>
            payslipSnapshot,
      ) {
        final QueryDocumentSnapshot<
                Map<String, dynamic>>?
            latestPayslip =
            _findLatestReleasedPayslip(
          payslipSnapshot.data?.docs ??
              <QueryDocumentSnapshot<
                  Map<String, dynamic>>>[],
        );

        if (latestPayslip == null) {
          return _EmptyDashboardCard(
            icon: Icons.receipt_long_outlined,
            title: 'No Released Payslip',
            message:
                'Your latest released payslip will appear here.',
            onTap: widget.onOpenPayslips,
          );
        }

        final Map<String, dynamic> data =
            latestPayslip.data();

        final DateTime? periodDate =
            _readDateTime(
                  data['payrollPeriodEnd'],
                ) ??
                _readDateTime(
                  data['generatedAt'],
                );

        final double netPay =
            _readNumber(data['netPay']);

        return Material(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(22),
          child: InkWell(
            onTap: widget.onOpenPayslips,
            borderRadius:
                BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(
                includeColor: false,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration:
                        const BoxDecoration(
                      color: Color(0xFFEFF5FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: Color(0xFF2979FF),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          periodDate == null
                              ? 'Latest Payslip'
                              : '${_monthName(periodDate.month)} ${periodDate.year} Payslip',
                          style: const TextStyle(
                            color: Color(0xFF101828),
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              const TextSpan(
                                text: 'Net pay: ',
                                style: TextStyle(
                                  color:
                                      Color(0xFF98A2B3),
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text:
                                    _formatCurrency(netPay),
                                style: const TextStyle(
                                  color:
                                      Color(0xFF00A63E),
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1),
                    size: 30,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(
    _NotificationSummary summary,
  ) {
    if (summary.unreadCount == 0) {
      return const _EmptyDashboardCard(
        icon: Icons.notifications_none_rounded,
        title: 'No Unread Notifications',
        message:
            'You are all caught up.',
      );
    }

    return Material(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () {
          _showTemporaryMessage(
            'You have ${summary.unreadCount} unread notification${summary.unreadCount == 1 ? '' : 's'}.',
          );
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFD7E7FF),
            ),
          ),
          child: Row(
            children: <Widget>[
              const CircleAvatar(
                radius: 29,
                backgroundColor:
                    Color(0xFF2979FF),
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'You have ${summary.unreadCount} unread notification${summary.unreadCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Color(0xFF21439C),
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.latestTitle,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2979FF),
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF2979FF),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _AttendanceDashboardSummary
      _buildAttendanceSummary(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        documents,
  ) {
    final DateTime monthStart = DateTime(
      _now.year,
      _now.month,
      1,
    );

    final DateTime nextMonthStart =
        DateTime(
      _now.year,
      _now.month + 1,
      1,
    );

    final Set<String> presentDates =
        <String>{};

    double totalHours = 0;
    int lateCount = 0;
    _TodayAttendance? todayAttendance;

    for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        document in documents) {
      final Map<String, dynamic> data =
          document.data();

      final DateTime? attendanceDate =
          _readDateTime(
                data['attendanceDate'],
              ) ??
              _readDateTime(data['timeIn']);

      if (attendanceDate == null) {
        continue;
      }

      final DateTime dateOnly = DateTime(
        attendanceDate.year,
        attendanceDate.month,
        attendanceDate.day,
      );

      final DateTime? timeIn =
          _readDateTime(data['timeIn']);

      final DateTime? timeOut =
          _readDateTime(data['timeOut']);

      if (_isSameDay(dateOnly, _now)) {
        final _TodayAttendance candidate =
            _TodayAttendance(
          timeIn: timeIn,
          timeOut: timeOut,
          status: _readText(
            data['status'],
            fallback: '',
          ),
        );

        if (todayAttendance == null ||
            _dateSortValue(candidate.timeIn) >
                _dateSortValue(
                  todayAttendance.timeIn,
                )) {
          todayAttendance = candidate;
        }
      }

      if (dateOnly.isBefore(monthStart) ||
          !dateOnly.isBefore(nextMonthStart)) {
        continue;
      }

      if (timeIn != null) {
        presentDates.add(
          '${dateOnly.year}-${dateOnly.month}-${dateOnly.day}',
        );
      }

      totalHours +=
          _readNumber(data['totalWorkHours']);

      if (_readNumber(data['lateMinutes']) > 0) {
        lateCount++;
      }
    }

    return _AttendanceDashboardSummary(
      daysPresent: presentDates.length,
      totalHoursWorked: totalHours,
      lateCount: lateCount,
      todayAttendance: todayAttendance,
    );
  }

  _LeaveBalanceSummary _calculateLeaveBalance({
    required Map<String, dynamic> employeeData,
    required List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        leaveDocuments,
  }) {
    final Map<String, dynamic> directBalances =
        _readMap(employeeData['leaveBalances']);

    if (directBalances.isNotEmpty) {
      return _LeaveBalanceSummary(
        vacation: _readNumber(
          directBalances['vacation'],
        ),
        sick: _readNumber(
          directBalances['sick'],
        ),
        emergency: _readNumber(
          directBalances['emergency'],
        ),
      );
    }

    final Map<String, dynamic> entitlements =
        _readMap(
      employeeData['leaveEntitlements'],
    );

    double vacationUsed = 0;
    double sickUsed = 0;
    double emergencyUsed = 0;

    for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        document in leaveDocuments) {
      final Map<String, dynamic> data =
          document.data();

      final String status =
          _readText(
            data['status'],
            fallback: '',
          ).toLowerCase();

      if (status != 'approved') {
        continue;
      }

      final DateTime? startDate =
          _readDateTime(data['startDate']);

      if (startDate != null &&
          startDate.year != _now.year) {
        continue;
      }

      final String leaveType =
          _readText(
            data['leaveType'],
            fallback: '',
          ).toLowerCase();

      final double days =
          _readNumber(data['totalDays']) > 0
              ? _readNumber(data['totalDays'])
              : _inclusiveLeaveDays(
                  _readDateTime(
                    data['startDate'],
                  ),
                  _readDateTime(
                    data['endDate'],
                  ),
                );

      if (leaveType.contains('vacation')) {
        vacationUsed += days;
      } else if (leaveType.contains('sick')) {
        sickUsed += days;
      } else if (leaveType.contains(
        'emergency',
      )) {
        emergencyUsed += days;
      }
    }

    final double vacationEntitlement =
        _readNumber(
      entitlements['vacation'] ??
          employeeData['vacationLeaveBalance'],
    );

    final double sickEntitlement =
        _readNumber(
      entitlements['sick'] ??
          employeeData['sickLeaveBalance'],
    );

    final double emergencyEntitlement =
        _readNumber(
      entitlements['emergency'] ??
          employeeData['emergencyLeaveBalance'],
    );

    return _LeaveBalanceSummary(
      vacation:
          (vacationEntitlement - vacationUsed)
              .clamp(0, double.infinity)
              .toDouble(),
      sick: (sickEntitlement - sickUsed)
          .clamp(0, double.infinity)
          .toDouble(),
      emergency:
          (emergencyEntitlement - emergencyUsed)
              .clamp(0, double.infinity)
              .toDouble(),
    );
  }

  QueryDocumentSnapshot<Map<String, dynamic>>?
      _findLatestReleasedPayslip(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        documents,
  ) {
    final List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        released = documents.where(
      (
        QueryDocumentSnapshot<Map<String, dynamic>>
            document,
      ) {
        return _readText(
              document.data()['status'],
              fallback: '',
            ).toLowerCase() ==
            'released';
      },
    ).toList();

    released.sort(
      (
        QueryDocumentSnapshot<Map<String, dynamic>>
            first,
        QueryDocumentSnapshot<Map<String, dynamic>>
            second,
      ) {
        final DateTime? firstDate =
            _readDateTime(
                  first.data()['payrollPeriodEnd'],
                ) ??
                _readDateTime(
                  first.data()['generatedAt'],
                );

        final DateTime? secondDate =
            _readDateTime(
                  second.data()['payrollPeriodEnd'],
                ) ??
                _readDateTime(
                  second.data()['generatedAt'],
                );

        return _dateSortValue(secondDate)
            .compareTo(
          _dateSortValue(firstDate),
        );
      },
    );

    return released.isEmpty ? null : released.first;
  }

  _NotificationSummary _buildNotificationSummary(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        documents,
  ) {
    final List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        unread = documents.where(
      (
        QueryDocumentSnapshot<Map<String, dynamic>>
            document,
      ) {
        return document.data()['isRead'] != true;
      },
    ).toList();

    unread.sort(
      (
        QueryDocumentSnapshot<Map<String, dynamic>>
            first,
        QueryDocumentSnapshot<Map<String, dynamic>>
            second,
      ) {
        return _dateSortValue(
          _readDateTime(
            second.data()['createdAt'],
          ),
        ).compareTo(
          _dateSortValue(
            _readDateTime(
              first.data()['createdAt'],
            ),
          ),
        );
      },
    );

    return _NotificationSummary(
      unreadCount: unread.length,
      latestTitle: unread.isEmpty
          ? 'No unread notifications'
          : _readText(
              unread.first.data()['title'],
              fallback: _readText(
                unread.first.data()['message'],
                fallback: 'New notification',
              ),
            ),
    );
  }

  Future<void> _logout() async {
    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }

    await FirebaseAuth.instance.signOut();
  }

  BoxDecoration _cardDecoration({
    bool includeColor = true,
  }) {
    return BoxDecoration(
      color: includeColor ? Colors.white : null,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: const Color(0xFFE4E7EC),
      ),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x120F172A),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    );
  }

  void _showTemporaryMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _greeting(DateTime value) {
    if (value.hour < 12) {
      return 'Good morning';
    }

    if (value.hour < 18) {
      return 'Good afternoon';
    }

    return 'Good evening';
  }

  String _firstName(String fullName) {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where(
          (String part) => part.isNotEmpty,
        )
        .toList();

    return parts.isEmpty
        ? 'Employee'
        : parts.first;
  }

  String _formatDate(DateTime value) {
    const List<String> weekdays =
        <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return '${weekdays[value.weekday - 1]}, '
        '${_monthName(value.month)} '
        '${value.day}, ${value.year}';
  }

  String _formatTime(DateTime value) {
    final int hour = value.hour % 12 == 0
        ? 12
        : value.hour % 12;

    final String minute =
        value.minute.toString().padLeft(2, '0');

    final String second =
        value.second.toString().padLeft(2, '0');

    final String period =
        value.hour >= 12 ? 'PM' : 'AM';

    return '${hour.toString().padLeft(2, '0')}:'
        '$minute:$second $period';
  }

  String _formatClockTime(DateTime value) {
    final int hour = value.hour % 12 == 0
        ? 12
        : value.hour % 12;

    final String minute =
        value.minute.toString().padLeft(2, '0');

    final String period =
        value.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String _formatHours(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  String _formatLeaveDays(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  String _formatCurrency(double value) {
    final String fixed =
        value.toStringAsFixed(2);

    final List<String> parts =
        fixed.split('.');

    final String whole = parts.first;

    final StringBuffer formatted =
        StringBuffer();

    for (int index = 0;
        index < whole.length;
        index++) {
      final int remaining =
          whole.length - index;

      formatted.write(whole[index]);

      if (remaining > 1 &&
          remaining % 3 == 1) {
        formatted.write(',');
      }
    }

    return '₱${formatted.toString()}.${parts.last}';
  }

  String _monthName(int month) {
    const List<String> months =
        <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    if (month < 1 || month > 12) {
      return '';
    }

    return months[month - 1];
  }

  double _inclusiveLeaveDays(
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate == null ||
        endDate == null) {
      return 0;
    }

    final DateTime start = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final DateTime end = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );

    if (end.isBefore(start)) {
      return 0;
    }

    return end.difference(start).inDays + 1;
  }

  bool _isSameDay(
    DateTime first,
    DateTime second,
  ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  int _dateSortValue(DateTime? value) {
    return value?.millisecondsSinceEpoch ?? 0;
  }

  DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  double _readNumber(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _readText(
    dynamic value, {
    required String fallback,
  }) {
    final String text =
        value?.toString().trim() ?? '';

    return text.isEmpty ? fallback : text;
  }

  Map<String, dynamic> _readMap(
    dynamic value,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map<String, dynamic>(
        (
          dynamic key,
          dynamic item,
        ) =>
            MapEntry<String, dynamic>(
          key.toString(),
          item,
        ),
      );
    }

    return <String, dynamic>{};
  }
}

class _AttendanceDashboardSummary {
  const _AttendanceDashboardSummary({
    required this.daysPresent,
    required this.totalHoursWorked,
    required this.lateCount,
    required this.todayAttendance,
  });

  final int daysPresent;
  final double totalHoursWorked;
  final int lateCount;
  final _TodayAttendance? todayAttendance;
}

class _TodayAttendance {
  const _TodayAttendance({
    required this.timeIn,
    required this.timeOut,
    required this.status,
  });

  final DateTime? timeIn;
  final DateTime? timeOut;
  final String status;
}

class _LeaveBalanceSummary {
  const _LeaveBalanceSummary({
    required this.vacation,
    required this.sick,
    required this.emergency,
  });

  final double vacation;
  final double sick;
  final double emergency;
}

class _NotificationSummary {
  const _NotificationSummary({
    required this.unreadCount,
    required this.latestTitle,
  });

  final int unreadCount;
  final String latestTitle;
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(
        alpha: 0.18,
      ),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final String label =
        count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(
        minWidth: 26,
        minHeight: 26,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
      ),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFFF3347),
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.backgroundColor,
  });

  final String value;
  final String label;
  final Color valueColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 124,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 31,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveBalanceItem extends StatelessWidget {
  const _LeaveBalanceItem({
    required this.value,
    required this.label,
    required this.backgroundColor,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color backgroundColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 112,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDashboardCard extends StatelessWidget {
  const _EmptyDashboardCard({
    required this.icon,
    required this.title,
    required this.message,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFE4E7EC),
            ),
          ),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    const Color(0xFFEFF5FF),
                child: Icon(
                  icon,
                  color: const Color(0xFF2979FF),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardLoadingState
    extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF2F6FC),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF2F6FC),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 520,
            ),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFFDA29B),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFD92D20),
                  size: 58,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Unable to Load Dashboard',
                  style: TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    height: 1.4,
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
