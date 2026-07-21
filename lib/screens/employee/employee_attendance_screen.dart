import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../hr/face_attendance_screen.dart';

class EmployeeAttendanceScreen extends StatefulWidget {
  const EmployeeAttendanceScreen({
    required this.employeeId,
    required this.fullName,
    super.key,
  });

  final String employeeId;
  final String fullName;

  @override
  State<EmployeeAttendanceScreen> createState() =>
      _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState
    extends State<EmployeeAttendanceScreen> {
  late final Future<
          DocumentReference<Map<String, dynamic>>>
      _employeeReferenceFuture;

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _employeeReferenceFuture =
        _resolveEmployeeReference();
  }

  Future<DocumentReference<Map<String, dynamic>>>
      _resolveEmployeeReference() async {
    final FirebaseFirestore firestore =
        FirebaseFirestore.instance;

    final String suppliedId =
        widget.employeeId.trim();

    if (suppliedId.isEmpty) {
      throw StateError(
        'The signed-in account has no employee ID.',
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
            .where(
              'employeeId',
              isEqualTo: suppliedId,
            )
            .limit(1)
            .get();

    if (employeeIdQuery.docs.isNotEmpty) {
      return employeeIdQuery.docs.first.reference;
    }

    final QuerySnapshot<Map<String, dynamic>>
        employeeCodeQuery = await firestore
            .collection('employee')
            .where(
              'employeeCode',
              isEqualTo: suppliedId,
            )
            .limit(1)
            .get();

    if (employeeCodeQuery.docs.isNotEmpty) {
      return employeeCodeQuery.docs.first.reference;
    }

    throw StateError(
      'No employee record matches "$suppliedId".',
    );
  }

  Future<void> _openFaceAttendance() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const FaceAttendanceScreen(),
      ),
    );
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      );
    });
  }

  void _nextMonth() {
    final DateTime currentMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month,
    );

    final DateTime nextMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
    );

    if (nextMonth.isAfter(currentMonth)) {
      return;
    }

    setState(() {
      _selectedMonth = nextMonth;
    });
  }

  bool get _canGoNext {
    final DateTime currentMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month,
    );

    final DateTime nextMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
    );

    return !nextMonth.isAfter(currentMonth);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF2F6FC),
      child: SafeArea(
        bottom: false,
        child: FutureBuilder<
            DocumentReference<Map<String, dynamic>>>(
          future: _employeeReferenceFuture,
          builder: (
            BuildContext context,
            AsyncSnapshot<
                    DocumentReference<
                        Map<String, dynamic>>>
                employeeReferenceSnapshot,
          ) {
            if (employeeReferenceSnapshot
                    .connectionState !=
                ConnectionState.done) {
              return const _AttendanceLoadingState();
            }

            if (employeeReferenceSnapshot.hasError ||
                !employeeReferenceSnapshot.hasData) {
              return _AttendanceErrorState(
                message:
                    employeeReferenceSnapshot.error
                            ?.toString() ??
                        'Unable to resolve your employee record.',
              );
            }

            final DocumentReference<
                    Map<String, dynamic>>
                employeeReference =
                employeeReferenceSnapshot.data!;

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
                if (attendanceSnapshot.hasError) {
                  return _AttendanceErrorState(
                    message:
                        'Unable to load your attendance: '
                        '${attendanceSnapshot.error}',
                  );
                }

                if (!attendanceSnapshot.hasData) {
                  return const _AttendanceLoadingState();
                }

                final List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    monthRecords =
                    _recordsForSelectedMonth(
                  attendanceSnapshot.data!.docs,
                );

                final List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    filteredRecords =
                    _filterRecords(monthRecords);

                final _AttendanceSummary summary =
                    _calculateSummary(monthRecords);

                return RefreshIndicator(
                  onRefresh: () async {
                    await Future<void>.delayed(
                      const Duration(
                        milliseconds: 350,
                      ),
                    );
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      18,
                      18,
                      100,
                    ),
                    children: <Widget>[
                      _buildHeader(),
                      const SizedBox(height: 18),
                      _buildMonthAndStatusFilters(),
                      const SizedBox(height: 18),
                      _buildSummary(summary),
                      const SizedBox(height: 20),
                      _buildRecordsHeader(
                        filteredCount:
                            filteredRecords.length,
                        totalCount:
                            monthRecords.length,
                      ),
                      const SizedBox(height: 12),
                      if (monthRecords.isEmpty)
                        _AttendanceMessageState(
                          icon:
                              Icons.event_busy_outlined,
                          title:
                              'No attendance records',
                          message:
                              'No attendance was recorded for '
                              '${_monthName(_selectedMonth.month)} '
                              '${_selectedMonth.year}.',
                        )
                      else if (filteredRecords.isEmpty)
                        const _AttendanceMessageState(
                          icon: Icons.filter_alt_off,
                          title:
                              'No matching records',
                          message:
                              'Try choosing a different attendance status.',
                        )
                      else
                        ...filteredRecords.map(
                          (
                            QueryDocumentSnapshot<
                                    Map<String, dynamic>>
                                document,
                          ) =>
                              Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child:
                                _EmployeeAttendanceRecordCard(
                              data: document.data(),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final bool compact =
            constraints.maxWidth < 520;

        final Widget title = Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'My Attendance',
              style: TextStyle(
                color: Color(0xFF101828),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'View attendance records for '
              '${widget.fullName.trim().isEmpty ? 'your account' : widget.fullName}.',
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        );

        final Widget faceButton =
            FilledButton.icon(
          onPressed: _openFaceAttendance,
          style: FilledButton.styleFrom(
            backgroundColor:
                const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(
            Icons.face_retouching_natural,
          ),
          label:
              const Text('Face Attendance'),
        );

        if (compact) {
          return Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: <Widget>[
              title,
              const SizedBox(height: 14),
              faceButton,
            ],
          );
        }

        return Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: title),
            const SizedBox(width: 14),
            faceButton,
          ],
        );
      },
    );
  }

  Widget _buildMonthAndStatusFilters() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton.filledTonal(
                onPressed: _previousMonth,
                tooltip: 'Previous month',
                icon: const Icon(
                  Icons.chevron_left_rounded,
                ),
              ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    const Text(
                      'Attendance Month',
                      style: TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_monthName(_selectedMonth.month)} '
                      '${_selectedMonth.year}',
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed:
                    _canGoNext ? _nextMonth : null,
                tooltip: 'Next month',
                icon: const Icon(
                  Icons.chevron_right_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _statusFilter,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Attendance Status',
              prefixIcon: const Icon(
                Icons.filter_alt_outlined,
              ),
              filled: true,
              fillColor:
                  const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
            items: const <
                DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'all',
                child:
                    Text('All Attendance Records'),
              ),
              DropdownMenuItem<String>(
                value: 'present',
                child: Text('Present'),
              ),
              DropdownMenuItem<String>(
                value: 'incomplete',
                child: Text('Incomplete'),
              ),
              DropdownMenuItem<String>(
                value: 'absent',
                child: Text('Absent'),
              ),
              DropdownMenuItem<String>(
                value: 'on_leave',
                child: Text('On Leave'),
              ),
            ],
            onChanged: (String? value) {
              if (value == null) {
                return;
              }

              setState(() {
                _statusFilter = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(
    _AttendanceSummary summary,
  ) {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final double width =
            (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            SizedBox(
              width: width,
              child: _EmployeeAttendanceSummaryCard(
                label: 'Days Present',
                value:
                    summary.daysPresent.toString(),
                icon:
                    Icons.how_to_reg_outlined,
                backgroundColor:
                    const Color(0xFFE8F5E9),
                foregroundColor:
                    const Color(0xFF2E7D32),
              ),
            ),
            SizedBox(
              width: width,
              child: _EmployeeAttendanceSummaryCard(
                label: 'Hours Worked',
                value: _formatNumber(
                  summary.totalHours,
                ),
                icon: Icons.schedule_outlined,
                backgroundColor:
                    const Color(0xFFE3F2FD),
                foregroundColor:
                    const Color(0xFF1565C0),
              ),
            ),
            SizedBox(
              width: width,
              child: _EmployeeAttendanceSummaryCard(
                label: 'Late Count',
                value:
                    summary.lateCount.toString(),
                icon: Icons.timer_outlined,
                backgroundColor:
                    const Color(0xFFFFF3E0),
                foregroundColor:
                    const Color(0xFFEF6C00),
              ),
            ),
            SizedBox(
              width: width,
              child: _EmployeeAttendanceSummaryCard(
                label: 'Overtime Hours',
                value: _formatNumber(
                  summary.overtimeHours,
                ),
                icon:
                    Icons.more_time_outlined,
                backgroundColor:
                    const Color(0xFFF4F3FF),
                foregroundColor:
                    const Color(0xFF7F56D9),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecordsHeader({
    required int filteredCount,
    required int totalCount,
  }) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Text(
            'Attendance Records',
            style: TextStyle(
              color: Color(0xFF101828),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          filteredCount == totalCount
              ? '$totalCount record${totalCount == 1 ? '' : 's'}'
              : '$filteredCount of $totalCount',
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>
      _recordsForSelectedMonth(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        documents,
  ) {
    final DateTime monthStart = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );

    final DateTime nextMonthStart = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      1,
    );

    final List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        records = documents.where(
      (
        QueryDocumentSnapshot<Map<String, dynamic>>
            document,
      ) {
        final DateTime? date =
            _attendanceDate(document.data());

        if (date == null) {
          return false;
        }

        return !date.isBefore(monthStart) &&
            date.isBefore(nextMonthStart);
      },
    ).toList();

    records.sort(
      (
        QueryDocumentSnapshot<Map<String, dynamic>>
            first,
        QueryDocumentSnapshot<Map<String, dynamic>>
            second,
      ) {
        final DateTime firstDate =
            _attendanceDate(first.data()) ??
                DateTime(1970);

        final DateTime secondDate =
            _attendanceDate(second.data()) ??
                DateTime(1970);

        return secondDate.compareTo(firstDate);
      },
    );

    return records;
  }

  List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>
      _filterRecords(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        records,
  ) {
    if (_statusFilter == 'all') {
      return records;
    }

    return records.where(
      (
        QueryDocumentSnapshot<Map<String, dynamic>>
            document,
      ) {
        final String status =
            document
                    .data()['status']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                'unknown';

        return status == _statusFilter;
      },
    ).toList();
  }

  _AttendanceSummary _calculateSummary(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        records,
  ) {
    final Set<String> presentDates =
        <String>{};

    double totalHours = 0;
    double overtimeHours = 0;
    int lateCount = 0;

    for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        document in records) {
      final Map<String, dynamic> data =
          document.data();

      final DateTime? attendanceDate =
          _attendanceDate(data);

      final DateTime? timeIn =
          _dateTimeFromValue(data['timeIn']);

      if (attendanceDate != null &&
          timeIn != null) {
        presentDates.add(
          '${attendanceDate.year}-'
          '${attendanceDate.month}-'
          '${attendanceDate.day}',
        );
      }

      totalHours +=
          _number(data['totalWorkHours']);

      overtimeHours +=
          _number(data['overtimeHours']);

      if (_number(data['lateMinutes']) > 0) {
        lateCount++;
      }
    }

    return _AttendanceSummary(
      daysPresent: presentDates.length,
      totalHours: totalHours,
      lateCount: lateCount,
      overtimeHours: overtimeHours,
    );
  }
}

class _EmployeeAttendanceRecordCard
    extends StatelessWidget {
  const _EmployeeAttendanceRecordCard({
    required this.data,
  });

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final DateTime? attendanceDate =
        _attendanceDate(data);

    final DateTime? timeIn =
        _dateTimeFromValue(data['timeIn']);

    final DateTime? timeOut =
        _dateTimeFromValue(data['timeOut']);

    final String status =
        data['status']?.toString() ?? 'unknown';

    final double totalHours =
        _number(data['totalWorkHours']);

    final double overtimeHours =
        _number(data['overtimeHours']);

    final int lateMinutes =
        _number(data['lateMinutes']).round();

    final String verificationMethod =
        _verificationMethod(data);

    final bool faceVerified =
        verificationMethod == 'face' &&
            data['faceVerified'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D101828),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFEFF5FF),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: Color(0xFF2979FF),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      attendanceDate == null
                          ? 'Unknown date'
                          : _longDate(
                              attendanceDate,
                            ),
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _weekdayName(
                        attendanceDate?.weekday,
                      ),
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _AttendanceStatusChip(
                status: status,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _AttendanceDetail(
                  label: 'Time In',
                  value: _formatTime(timeIn),
                  icon: Icons.login_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AttendanceDetail(
                  label: 'Time Out',
                  value: _formatTime(timeOut),
                  icon: Icons.logout_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AttendanceDetail(
                  label: 'Work Hours',
                  value:
                      _formatNumber(totalHours),
                  icon:
                      Icons.schedule_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  lateMinutes > 0
                      ? 'Late: $lateMinutes min'
                      : 'On time',
                  style: TextStyle(
                    color: lateMinutes > 0
                        ? const Color(0xFFC62828)
                        : const Color(0xFF2E7D32),
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'OT: ${_formatNumber(overtimeHours)} hr',
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Align(
            alignment: Alignment.centerLeft,
            child: _VerificationChip(
              method: verificationMethod,
              faceVerified: faceVerified,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceDetail extends StatelessWidget {
  const _AttendanceDetail({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF667085),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF98A2B3),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceStatusChip
    extends StatelessWidget {
  const _AttendanceStatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;

    switch (status.trim().toLowerCase()) {
      case 'present':
        background =
            const Color(0xFFE8F5E9);
        foreground =
            const Color(0xFF2E7D32);
        break;

      case 'absent':
        background =
            const Color(0xFFFFEBEE);
        foreground =
            const Color(0xFFC62828);
        break;

      case 'on_leave':
        background =
            const Color(0xFFE3F2FD);
        foreground =
            const Color(0xFF1565C0);
        break;

      case 'incomplete':
        background =
            const Color(0xFFFFF3E0);
        foreground =
            const Color(0xFFEF6C00);
        break;

      default:
        background =
            const Color(0xFFF2F4F7);
        foreground =
            const Color(0xFF475467);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        _formatLabel(status),
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _VerificationChip extends StatelessWidget {
  const _VerificationChip({
    required this.method,
    required this.faceVerified,
  });

  final String method;
  final bool faceVerified;

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;
    IconData icon;
    String label;

    switch (method) {
      case 'face':
        background = faceVerified
            ? const Color(0xFFE3F2FD)
            : const Color(0xFFFFEBEE);

        foreground = faceVerified
            ? const Color(0xFF1565C0)
            : const Color(0xFFC62828);

        icon = faceVerified
            ? Icons.verified_user_outlined
            : Icons.face_retouching_off;

        label = faceVerified
            ? 'Face Verified'
            : 'Face Not Verified';
        break;

      case 'manual':
        background =
            const Color(0xFFFFF3E0);
        foreground =
            const Color(0xFFEF6C00);
        icon = Icons.edit_calendar_outlined;
        label = 'Manual Entry';
        break;

      default:
        background =
            const Color(0xFFF2F4F7);
        foreground =
            const Color(0xFF475467);
        icon = Icons.history;
        label = 'Legacy Record';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeAttendanceSummaryCard
    extends StatelessWidget {
  const _EmployeeAttendanceSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            color: foregroundColor,
            size: 24,
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceMessageState
    extends StatelessWidget {
  const _AttendanceMessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 45,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            icon,
            size: 55,
            color: const Color(0xFF98A2B3),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
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
    );
  }
}

class _AttendanceLoadingState
    extends StatelessWidget {
  const _AttendanceLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _AttendanceErrorState
    extends StatelessWidget {
  const _AttendanceErrorState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
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
                BorderRadius.circular(20),
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
                'Unable to Load Attendance',
                style: TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 19,
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
    );
  }
}

class _AttendanceSummary {
  const _AttendanceSummary({
    required this.daysPresent,
    required this.totalHours,
    required this.lateCount,
    required this.overtimeHours,
  });

  final int daysPresent;
  final double totalHours;
  final int lateCount;
  final double overtimeHours;
}

DateTime? _attendanceDate(
  Map<String, dynamic> data,
) {
  return _dateTimeFromValue(
        data['attendanceDate'],
      ) ??
      _dateTimeFromValue(data['timeIn']);
}

DateTime? _dateTimeFromValue(
  dynamic value,
) {
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

double _number(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}

String _verificationMethod(
  Map<String, dynamic> data,
) {
  final String explicit =
      data['verificationMethod']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

  if (explicit.isNotEmpty) {
    return explicit;
  }

  if (data['faceVerified'] == true) {
    return 'face';
  }

  if (data['manualEntry'] == true ||
      data['manualReason'] != null) {
    return 'manual';
  }

  return 'legacy';
}

String _formatTime(DateTime? value) {
  if (value == null) {
    return '--';
  }

  final int hour =
      value.hour % 12 == 0 ? 12 : value.hour % 12;

  final String minute =
      value.minute.toString().padLeft(2, '0');

  final String period =
      value.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(2);
}

String _longDate(DateTime value) {
  return '${_monthName(value.month)} '
      '${value.day}, ${value.year}';
}

String _weekdayName(int? weekday) {
  const List<String> names = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  if (weekday == null ||
      weekday < 1 ||
      weekday > 7) {
    return '';
  }

  return names[weekday - 1];
}

String _monthName(int month) {
  const List<String> months = <String>[
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

String _formatLabel(String value) {
  if (value.trim().isEmpty) {
    return 'Unknown';
  }

  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where(
        (String word) => word.isNotEmpty,
      )
      .map(
        (String word) =>
            '${word[0].toUpperCase()}'
            '${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}
