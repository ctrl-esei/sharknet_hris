import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'face_attendance_screen.dart';
import 'manual_attendance_screen.dart';

class HrAttendanceScreen extends StatefulWidget {
  const HrAttendanceScreen({super.key});

  @override
  State<HrAttendanceScreen> createState() =>
      _HrAttendanceScreenState();
}

class _HrAttendanceScreenState
    extends State<HrAttendanceScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  DateTime _selectedDate = DateTime.now();

  String _statusFilter = 'all';
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime get _startOfSelectedDay {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
  }

  DateTime get _endOfSelectedDay {
    return _startOfSelectedDay.add(
      const Duration(days: 1),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      _attendanceStream() {
    return FirebaseFirestore.instance
        .collection('attendance')
        .where(
          'attendanceDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            _startOfSelectedDay,
          ),
        )
        .where(
          'attendanceDate',
          isLessThan: Timestamp.fromDate(
            _endOfSelectedDay,
          ),
        )
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      _employeeStream() {
    return FirebaseFirestore.instance
        .collection('employee')
        .snapshots();
  }

  Future<void> _selectDate() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(days: 1),
      ),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = selectedDate;
    });
  }

  Future<void> _openFaceAttendance() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FaceAttendanceScreen(),
      ),
    );
  }

  Future<void> _openManualAttendance() async {
    final _EmployeeSelection? selectedEmployee =
        await showModalBottomSheet<_EmployeeSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return const _EmployeePickerSheet();
      },
    );

    if (!mounted || selectedEmployee == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManualAttendanceScreen(
          employeeId: selectedEmployee.employeeId,
          fullName: selectedEmployee.fullName,
        ),
      ),
    );
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
  }

  bool _isToday(DateTime date) {
    final DateTime today = DateTime.now();

    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F8FC),
      child: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _employeeStream(),
        builder: (context, employeeSnapshot) {
          if (employeeSnapshot.hasError) {
            return _ErrorState(
              message:
                  'Unable to load employees: ${employeeSnapshot.error}',
            );
          }

          final Map<String, String> employeeNames = {};

          for (final employee
              in employeeSnapshot.data?.docs ?? []) {
            employeeNames[employee.id] =
                employee.data()['fullName']?.toString() ??
                    employee.id.toUpperCase();
          }

          return StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: _attendanceStream(),
            builder: (context, attendanceSnapshot) {
              if (attendanceSnapshot.hasError) {
                return _ErrorState(
                  message:
                      'Unable to load attendance: ${attendanceSnapshot.error}',
                );
              }

              if (attendanceSnapshot.connectionState ==
                      ConnectionState.waiting ||
                  employeeSnapshot.connectionState ==
                      ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final List<
                      QueryDocumentSnapshot<
                          Map<String, dynamic>>>
                  allRecords = List.of(
                attendanceSnapshot.data?.docs ?? [],
              );

              allRecords.sort((first, second) {
                final DateTime firstTime =
                    _recordSortDate(first.data());

                final DateTime secondTime =
                    _recordSortDate(second.data());

                return secondTime.compareTo(firstTime);
              });

              final filteredRecords =
                  allRecords.where((record) {
                return _matchesFilters(
                  record: record,
                  employeeNames: employeeNames,
                );
              }).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  100,
                ),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildFilters(),
                  const SizedBox(height: 18),
                  _buildSummary(allRecords),
                  const SizedBox(height: 20),
                  _buildRecordsHeader(
                    filteredCount: filteredRecords.length,
                    totalCount: allRecords.length,
                  ),
                  const SizedBox(height: 12),
                  if (allRecords.isEmpty)
                    _buildEmptyAttendance()
                  else if (filteredRecords.isEmpty)
                    _buildNoMatchingAttendance()
                  else
                    ...filteredRecords.map(
                      (record) {
                        final Map<String, dynamic> data =
                            record.data();

                        final String employeeId =
                            _employeeIdFromValue(
                          data['employeeId'],
                        );

                        final String employeeName =
                            employeeNames[employeeId] ??
                                employeeId.toUpperCase();

                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 12),
                          child: _AttendanceRecordCard(
                            documentId: record.id,
                            employeeId: employeeId,
                            employeeName: employeeName,
                            data: data,
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 620;

        final Widget title = const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Management',
              style: TextStyle(
                color: Color(0xFF101828),
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Review records and manage face or manual attendance.',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        );

        final Widget buttons = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _openFaceAttendance,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 13,
                ),
              ),
              icon: const Icon(
                Icons.face_retouching_natural,
              ),
              label: const Text('Face Attendance'),
            ),
            OutlinedButton.icon(
              onPressed: _openManualAttendance,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF04B0B),
                side: const BorderSide(
                  color: Color(0xFFF04B0B),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 13,
                ),
              ),
              icon: const Icon(
                Icons.edit_calendar_outlined,
              ),
              label: const Text('Manual Attendance'),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 15),
              buttons,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            buttons,
          ],
        );
      },
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _inputDecoration(
                      label: 'Attendance Date',
                      icon: Icons.calendar_month_outlined,
                    ),
                    child: Text(
                      _formatLongDate(_selectedDate),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              if (!_isToday(_selectedDate)) ...[
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: _goToToday,
                  tooltip: 'Go to today',
                  icon: const Icon(Icons.today),
                ),
              ],
            ],
          ),
          const SizedBox(height: 13),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_statusFilter),
            initialValue: _statusFilter,
            decoration: _inputDecoration(
              label: 'Status',
              icon: Icons.filter_alt_outlined,
            ),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('All Statuses'),
              ),
              DropdownMenuItem(
                value: 'present',
                child: Text('Present'),
              ),
              DropdownMenuItem(
                value: 'incomplete',
                child: Text('Incomplete'),
              ),
              DropdownMenuItem(
                value: 'absent',
                child: Text('Absent'),
              ),
              DropdownMenuItem(
                value: 'on_leave',
                child: Text('On Leave'),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _statusFilter = value;
              });
            },
          ),
          const SizedBox(height: 13),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchText = value.trim().toLowerCase();
              });
            },
            decoration: _inputDecoration(
              label: 'Search Employee',
              icon: Icons.search,
            ).copyWith(
              hintText: 'Employee ID or name',
              suffixIcon: _searchText.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();

                        setState(() {
                          _searchText = '';
                        });
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
        ],
      ),
    );
  }
Widget _buildSummary(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> records,
) {
  final int totalRecords = records.length;

  int presentCount = 0;
  int faceVerifiedCount = 0;
  int manualCount = 0;

  for (final record in records) {
    final Map<String, dynamic> data = record.data();

    final String status =
        data['status']?.toString().trim().toLowerCase() ??
            'unknown';

    final String verificationMethod =
        _verificationMethod(data);

    if (status == 'present') {
      presentCount++;
    }

    // This also supports your older sample records that have
    // faceVerified but do not yet have verificationMethod.
    if (data['faceVerified'] == true) {
      faceVerifiedCount++;
    }

    if (verificationMethod == 'manual') {
      manualCount++;
    }
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(
      20,
      22,
      20,
      24,
    ),
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
          'Attendance Overview',
          style: TextStyle(
            color: Color(0xFF101828),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatLongDate(_selectedDate),
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final int columnCount;

            if (constraints.maxWidth >= 760) {
              columnCount = 4;
            } else if (constraints.maxWidth >= 350) {
              columnCount = 2;
            } else {
              columnCount = 1;
            }

            const double spacing = 12;

            final double totalSpacing =
                spacing * (columnCount - 1);

            final double cardWidth =
                (constraints.maxWidth - totalSpacing) /
                    columnCount;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _AttendanceOverviewCard(
                    label: 'Total Records',
                    description: 'Recorded for this date',
                    value: totalRecords,
                    icon: Icons.assignment_outlined,
                    accentColor: const Color(0xFFF04B0B),
                    iconBackgroundColor:
                        const Color(0xFFFFF1EA),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _AttendanceOverviewCard(
                    label: 'Present',
                    description: 'Employees marked present',
                    value: presentCount,
                    icon: Icons.how_to_reg_outlined,
                    accentColor: const Color(0xFF039855),
                    iconBackgroundColor:
                        const Color(0xFFECFDF3),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _AttendanceOverviewCard(
                    label: 'Face Verified',
                    description: 'Successful face records',
                    value: faceVerifiedCount,
                    icon: Icons.verified_user_outlined,
                    accentColor: const Color(0xFF1F5CF5),
                    iconBackgroundColor:
                        const Color(0xFFF0F6FF),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _AttendanceOverviewCard(
                    label: 'Manual Entries',
                    description: 'Entered by HR or Admin',
                    value: manualCount,
                    icon: Icons.edit_calendar_outlined,
                    accentColor: const Color(0xFF9A22FF),
                    iconBackgroundColor:
                        const Color(0xFFFAF2FF),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

  Widget _buildRecordsHeader({
    required int filteredCount,
    required int totalCount,
  }) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Attendance Records',
            style: TextStyle(
              color: Color(0xFF101828),
              fontSize: 18,
              fontWeight: FontWeight.w800,
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

  Widget _buildEmptyAttendance() {
    return _AttendanceMessageState(
      icon: Icons.event_busy_outlined,
      title: 'No attendance records',
      message:
          'No attendance has been recorded for ${_formatLongDate(_selectedDate)}.',
    );
  }

  Widget _buildNoMatchingAttendance() {
    return const _AttendanceMessageState(
      icon: Icons.search_off,
      title: 'No matching records',
      message:
          'Try changing the employee search or attendance status filter.',
    );
  }

  bool _matchesFilters({
    required QueryDocumentSnapshot<Map<String, dynamic>>
        record,
    required Map<String, String> employeeNames,
  }) {
    final Map<String, dynamic> data = record.data();

    final String status =
        data['status']?.toString().toLowerCase() ??
            'unknown';

    if (_statusFilter != 'all' &&
        status != _statusFilter) {
      return false;
    }

    if (_searchText.isEmpty) {
      return true;
    }

    final String employeeId = _employeeIdFromValue(
      data['employeeId'],
    );

    final String employeeName =
        employeeNames[employeeId]?.toLowerCase() ?? '';

    return employeeId.toLowerCase().contains(
          _searchText,
        ) ||
        employeeName.contains(_searchText);
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFD0D5DD),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFD0D5DD),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFF04B0B),
          width: 1.5,
        ),
      ),
    );
  }
}

// ============================================================
// ATTENDANCE RECORD CARD
// ============================================================

class _AttendanceRecordCard extends StatelessWidget {
  const _AttendanceRecordCard({
    required this.documentId,
    required this.employeeId,
    required this.employeeName,
    required this.data,
  });

  final String documentId;
  final String employeeId;
  final String employeeName;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final String status =
        data['status']?.toString() ?? 'unknown';

    final String verificationMethod =
        _verificationMethod(data);

    final bool isFaceVerified =
        verificationMethod == 'face' &&
            data['faceVerified'] == true;

    final DateTime? timeIn =
        _dateTimeFromValue(data['timeIn']);

    final DateTime? timeOut =
        _dateTimeFromValue(data['timeOut']);

    final int lateMinutes =
        (data['lateMinutes'] as num?)?.toInt() ?? 0;

    final double overtimeHours =
        (data['overtimeHours'] as num?)
                ?.toDouble() ??
            0;

    final double totalWorkHours =
        (data['totalWorkHours'] as num?)
                ?.toDouble() ??
            0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D101828),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: const Color(0xFFFFF1EA),
                child: Text(
                  _initials(employeeName),
                  style: const TextStyle(
                    color: Color(0xFFF04B0B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      employeeId.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _AttendanceStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AttendanceDetail(
                  label: 'Time In',
                  value: _formatTime(timeIn),
                  icon: Icons.login,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AttendanceDetail(
                  label: 'Time Out',
                  value: _formatTime(timeOut),
                  icon: Icons.logout,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AttendanceDetail(
                  label: 'Hours',
                  value: totalWorkHours.toStringAsFixed(2),
                  icon: Icons.schedule,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  lateMinutes > 0
                      ? 'Late: $lateMinutes minutes'
                      : 'On time',
                  style: TextStyle(
                    color: lateMinutes > 0
                        ? const Color(0xFFC62828)
                        : const Color(0xFF2E7D32),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'OT: ${overtimeHours.toStringAsFixed(2)} hours',
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              _VerificationChip(
                method: verificationMethod,
                faceVerified: isFaceVerified,
              ),
              const Spacer(),
              Text(
                documentId,
                style: const TextStyle(
                  color: Color(0xFF98A2B3),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          if (verificationMethod == 'manual' &&
              data['manualReason']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Reason: ${data['manualReason']}',
                style: const TextStyle(
                  color: Color(0xFF7A4F01),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
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
      children: [
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
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceStatusChip extends StatelessWidget {
  const _AttendanceStatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;

    switch (status.toLowerCase()) {
      case 'present':
        background = const Color(0xFFE8F5E9);
        foreground = const Color(0xFF2E7D32);
        break;

      case 'absent':
        background = const Color(0xFFFFEBEE);
        foreground = const Color(0xFFC62828);
        break;

      case 'on_leave':
        background = const Color(0xFFE3F2FD);
        foreground = const Color(0xFF1565C0);
        break;

      case 'incomplete':
        background = const Color(0xFFFFF3E0);
        foreground = const Color(0xFFEF6C00);
        break;

      default:
        background = const Color(0xFFF2F4F7);
        foreground = const Color(0xFF475467);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatLabel(status),
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
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
            : 'Face Failed';
        break;

      case 'manual':
        background = const Color(0xFFFFF3E0);
        foreground = const Color(0xFFEF6C00);
        icon = Icons.edit_calendar_outlined;
        label = 'Manual Entry';
        break;

      default:
        background = const Color(0xFFF2F4F7);
        foreground = const Color(0xFF475467);
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SUMMARY AND MESSAGE WIDGETS
// ============================================================


class _AttendanceOverviewCard extends StatelessWidget {
  const _AttendanceOverviewCard({
    required this.label,
    required this.description,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.iconBackgroundColor,
  });

  final String label;
  final String description;
  final int value;
  final IconData icon;
  final Color accentColor;
  final Color iconBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 138,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEAECF0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const Spacer(),
              Text(
                value.toString(),
                style: TextStyle(
                  color: accentColor,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceMessageState extends StatelessWidget {
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        children: [
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
              fontWeight: FontWeight.w800,
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFC62828),
              size: 60,
            ),
            const SizedBox(height: 15),
            const Text(
              'Unable to Load Attendance',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// EMPLOYEE PICKER FOR MANUAL ATTENDANCE
// ============================================================

class _EmployeePickerSheet extends StatefulWidget {
  const _EmployeePickerSheet();

  @override
  State<_EmployeePickerSheet> createState() =>
      _EmployeePickerSheetState();
}

class _EmployeePickerSheetState
    extends State<_EmployeePickerSheet> {
  final TextEditingController _searchController =
      TextEditingController();

  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F8FC),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(25),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  5,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_search_outlined,
                      color: Color(0xFFF04B0B),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Select Employee',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  12,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchText =
                          value.trim().toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search employee ID or name',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFD0D5DD),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('employee')
                      .orderBy('fullName')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Unable to load employees: '
                          '${snapshot.error}',
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final employees =
                        snapshot.data!.docs.where(
                      (employee) {
                        final Map<String, dynamic> data =
                            employee.data();

                        final String status =
                            data['employmentStatus']
                                    ?.toString()
                                    .toLowerCase() ??
                                'active';

                        if (status != 'active') {
                          return false;
                        }

                        final String fullName =
                            data['fullName']
                                    ?.toString()
                                    .toLowerCase() ??
                                '';

                        return _searchText.isEmpty ||
                            employee.id
                                .toLowerCase()
                                .contains(_searchText) ||
                            fullName.contains(_searchText);
                      },
                    ).toList();

                    if (employees.isEmpty) {
                      return const Center(
                        child: Text(
                          'No active employees found.',
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        5,
                        16,
                        25,
                      ),
                      itemCount: employees.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final employee = employees[index];

                        final Map<String, dynamic> data =
                            employee.data();

                        final String fullName =
                            data['fullName']?.toString() ??
                                employee.id.toUpperCase();

                        final String position =
                            data['position']?.toString() ??
                                'Position not assigned';

                        return Material(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(13),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(13),
                            onTap: () {
                              Navigator.of(context).pop(
                                _EmployeeSelection(
                                  employeeId: employee.id,
                                  fullName: fullName,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        const Color(0xFFFFF1EA),
                                    child: Text(
                                      _initials(fullName),
                                      style: const TextStyle(
                                        color:
                                            Color(0xFFF04B0B),
                                        fontWeight:
                                            FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          fullName,
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${employee.id.toUpperCase()} • $position',
                                          style:
                                              const TextStyle(
                                            color:
                                                Color(0xFF667085),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFF98A2B3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmployeeSelection {
  const _EmployeeSelection({
    required this.employeeId,
    required this.fullName,
  });

  final String employeeId;
  final String fullName;
}

// ============================================================
// SHARED HELPERS
// ============================================================

String _employeeIdFromValue(dynamic value) {
  if (value is DocumentReference) {
    return value.id;
  }

  if (value is String && value.trim().isNotEmpty) {
    final String cleaned = value.trim();

    if (cleaned.contains('/')) {
      return cleaned.split('/').last;
    }

    return cleaned;
  }

  return 'unknown';
}

String _verificationMethod(
  Map<String, dynamic> data,
) {
  final String? method = data['verificationMethod']
      ?.toString()
      .trim()
      .toLowerCase();

  if (method == null || method.isEmpty) {
    return 'legacy';
  }

  return method;
}

DateTime _recordSortDate(
  Map<String, dynamic> data,
) {
  return _dateTimeFromValue(data['timeIn']) ??
      _dateTimeFromValue(data['attendanceDate']) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _dateTimeFromValue(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  return null;
}

String _formatTime(DateTime? value) {
  if (value == null) {
    return '--:--';
  }

  final int hour =
      value.hour == 0 ? 12 : value.hour > 12
          ? value.hour - 12
          : value.hour;

  final String minute =
      value.minute.toString().padLeft(2, '0');

  final String period =
      value.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
}

String _formatLongDate(DateTime date) {
  const List<String> months = [
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

  return '${months[date.month - 1]} '
      '${date.day}, ${date.year}';
}

String _formatLabel(String value) {
  if (value.trim().isEmpty) {
    return 'Unknown';
  }

  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map(
        (word) =>
            '${word[0].toUpperCase()}'
            '${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _initials(String fullName) {
  final List<String> parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return '?';
  }

  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return '${parts.first[0]}${parts.last[0]}'
      .toUpperCase();
}