import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'leave_request_form_screen.dart';

enum _LeaveScreenMode {
  hr,
  employee,
}

class HrLeaveScreen extends StatelessWidget {
  const HrLeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LeaveManagementScreen(
      mode: _LeaveScreenMode.hr,
    );
  }
}

class EmployeeLeaveScreen extends StatelessWidget {
  const EmployeeLeaveScreen({
    required this.employeeId,
    required this.fullName,
    super.key,
  });

  final String employeeId;
  final String fullName;

  @override
  Widget build(BuildContext context) {
    return _LeaveManagementScreen(
      mode: _LeaveScreenMode.employee,
      employeeId: employeeId,
      employeeName: fullName,
    );
  }
}

class _LeaveManagementScreen extends StatefulWidget {
  const _LeaveManagementScreen({
    required this.mode,
    this.employeeId,
    this.employeeName,
  });

  final _LeaveScreenMode mode;
  final String? employeeId;
  final String? employeeName;

  @override
  State<_LeaveManagementScreen> createState() =>
      _LeaveManagementScreenState();
}

class _LeaveManagementScreenState
    extends State<_LeaveManagementScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _statusFilter = 'all';
  String _searchText = '';

  bool get _isHr {
    return widget.mode == _LeaveScreenMode.hr;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      _requestStream() {
    final CollectionReference<Map<String, dynamic>>
        collection = FirebaseFirestore.instance
            .collection('leave_request');

    if (_isHr) {
      return collection.snapshots();
    }

    final String employeeId =
        widget.employeeId?.trim() ?? '';

    final DocumentReference<Map<String, dynamic>>
        employeeReference = FirebaseFirestore.instance
            .collection('employee')
            .doc(employeeId);

    return collection
        .where(
          'employeeId',
          isEqualTo: employeeReference,
        )
        .snapshots();
  }

  Future<void> _openRequestForm() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LeaveRequestFormScreen(
          filedByRole: _isHr ? 'hr' : 'employee',
          employeeId:
              _isHr ? null : widget.employeeId,
          employeeName:
              _isHr ? null : widget.employeeName,
        ),
      ),
    );
  }

  Future<void> _reviewRequest({
    required DocumentReference<Map<String, dynamic>>
        reference,
    required String employeeName,
    required String status,
  }) async {
    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage(
        'Your session has expired.',
        isError: true,
      );
      return;
    }

    String? remarks;

    if (status == 'rejected') {
      remarks = await _showRejectionDialog();

      if (remarks == null) {
        return;
      }
    }

    try {
      await reference.update({
        'status': status,
        'reviewedBy': currentUser.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewRemarks': remarks,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      _showMessage(
        status == 'approved'
            ? '$employeeName leave request approved.'
            : '$employeeName leave request rejected.',
        isError: false,
      );
    } on FirebaseException catch (error) {
      _showMessage(
        error.message ??
            'Unable to review the leave request.',
        isError: true,
      );
    }
  }

  Future<String?> _showRejectionDialog() async {
    final TextEditingController controller =
        TextEditingController();

    final String? result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Leave Request'),
          content: TextField(
            controller: controller,
            textCapitalization:
                TextCapitalization.sentences,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection',
              hintText:
                  'Explain why the request was rejected.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String remarks =
                    controller.text.trim();

                if (remarks.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(remarks);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD92D20),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return result;
  }

  void _showMessage(
    String message, {
    required bool isError,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFD92D20)
              : const Color(0xFF039855),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F8FC),
      child: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _requestStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LeaveMessageState(
              icon: Icons.error_outline,
              title: 'Unable to load leave requests',
              message: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState ==
                  ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final List<
                  QueryDocumentSnapshot<
                      Map<String, dynamic>>>
              allRequests =
              List.of(snapshot.data?.docs ?? []);

          allRequests.sort((first, second) {
            return _requestDate(second.data()).compareTo(
              _requestDate(first.data()),
            );
          });

          final List<
                  QueryDocumentSnapshot<
                      Map<String, dynamic>>>
              filteredRequests =
              allRequests.where(_matchesFilters).toList();

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
              _buildOverview(allRequests),
              const SizedBox(height: 18),
              _buildFilters(),
              const SizedBox(height: 20),
              _buildRequestHeader(
                filteredCount: filteredRequests.length,
                totalCount: allRequests.length,
              ),
              const SizedBox(height: 12),
              if (allRequests.isEmpty)
                const _LeaveMessageState(
                  icon: Icons.event_busy_outlined,
                  title: 'No leave requests',
                  message:
                      'No leave requests have been filed yet.',
                )
              else if (filteredRequests.isEmpty)
                const _LeaveMessageState(
                  icon: Icons.search_off,
                  title: 'No matching requests',
                  message:
                      'Try changing the status filter or search.',
                )
              else
                ...filteredRequests.map(
                  (document) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: 12),
                      child: _LeaveRequestCard(
                        documentId: document.id,
                        data: document.data(),
                        showEmployee: _isHr,
                        showReviewActions: _isHr,
                        onApprove: () {
                          _reviewRequest(
                            reference: document.reference,
                            employeeName: document
                                    .data()['employeeName']
                                    ?.toString() ??
                                'Employee',
                            status: 'approved',
                          );
                        },
                        onReject: () {
                          _reviewRequest(
                            reference: document.reference,
                            employeeName: document
                                    .data()['employeeName']
                                    ?.toString() ??
                                'Employee',
                            status: 'rejected',
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Widget title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isHr
                  ? 'Leave Management'
                  : 'My Leave Requests',
              style: const TextStyle(
                color: Color(0xFF101828),
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _isHr
                  ? 'File, approve, and review employee leave requests.'
                  : 'File a request and monitor its approval status.',
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 13,
              ),
            ),
          ],
        );

        final Widget button = FilledButton.icon(
          onPressed: _openRequestForm,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF04B0B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('File Leave Request'),
        );

        if (constraints.maxWidth < 570) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 15),
              button,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 15),
            button,
          ],
        );
      },
    );
  }

  Widget _buildOverview(
    List<QueryDocumentSnapshot<Map<String, dynamic>>>
        requests,
  ) {
    int pending = 0;
    int approved = 0;
    int rejected = 0;

    for (final document in requests) {
      final String status = document
              .data()['status']
              ?.toString()
              .toLowerCase() ??
          'pending';

      switch (status) {
        case 'pending':
          pending++;
          break;

        case 'approved':
          approved++;
          break;

        case 'rejected':
          rejected++;
          break;
      }
    }

    return Container(
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
            'Leave Overview',
            style: TextStyle(
              color: Color(0xFF101828),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final int columns;

              if (constraints.maxWidth >= 760) {
                columns = 4;
              } else if (constraints.maxWidth >= 350) {
                columns = 2;
              } else {
                columns = 1;
              }

              const double spacing = 12;

              final double width =
                  (constraints.maxWidth -
                          (spacing * (columns - 1))) /
                      columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: width,
                    child: _LeaveOverviewCard(
                      label: 'Total Requests',
                      value: requests.length,
                      icon: Icons.description_outlined,
                      accentColor:
                          const Color(0xFF1F5CF5),
                      backgroundColor:
                          const Color(0xFFF0F6FF),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _LeaveOverviewCard(
                      label: 'Pending',
                      value: pending,
                      icon: Icons.hourglass_top_outlined,
                      accentColor:
                          const Color(0xFFB54708),
                      backgroundColor:
                          const Color(0xFFFFF7ED),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _LeaveOverviewCard(
                      label: 'Approved',
                      value: approved,
                      icon: Icons.task_alt_outlined,
                      accentColor:
                          const Color(0xFF039855),
                      backgroundColor:
                          const Color(0xFFECFDF3),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _LeaveOverviewCard(
                      label: 'Rejected',
                      value: rejected,
                      icon: Icons.cancel_outlined,
                      accentColor:
                          const Color(0xFFD92D20),
                      backgroundColor:
                          const Color(0xFFFEF3F2),
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
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_statusFilter),
            initialValue: _statusFilter,
            decoration: const InputDecoration(
              labelText: 'Request Status',
              prefixIcon: Icon(
                Icons.filter_alt_outlined,
              ),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('All Statuses'),
              ),
              DropdownMenuItem(
                value: 'pending',
                child: Text('Pending'),
              ),
              DropdownMenuItem(
                value: 'approved',
                child: Text('Approved'),
              ),
              DropdownMenuItem(
                value: 'rejected',
                child: Text('Rejected'),
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
          if (_isHr) ...[
            const SizedBox(height: 13),
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchText =
                      value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                labelText: 'Search Employee',
                hintText: 'Employee name or ID',
                prefixIcon: const Icon(Icons.search),
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
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestHeader({
    required int filteredCount,
    required int totalCount,
  }) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Leave Requests',
            style: TextStyle(
              color: Color(0xFF101828),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          filteredCount == totalCount
              ? '$totalCount request'
                  '${totalCount == 1 ? '' : 's'}'
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

  bool _matchesFilters(
    QueryDocumentSnapshot<Map<String, dynamic>>
        document,
  ) {
    final Map<String, dynamic> data = document.data();

    final String status =
        data['status']?.toString().toLowerCase() ??
            'pending';

    if (_statusFilter != 'all' &&
        status != _statusFilter) {
      return false;
    }

    if (!_isHr || _searchText.isEmpty) {
      return true;
    }

    final String employeeName =
        data['employeeName']
                ?.toString()
                .toLowerCase() ??
            '';

    final String employeeId =
        _employeeIdFromValue(data['employeeId'])
            .toLowerCase();

    return employeeName.contains(_searchText) ||
        employeeId.contains(_searchText);
  }
}

class _LeaveRequestCard extends StatelessWidget {
  const _LeaveRequestCard({
    required this.documentId,
    required this.data,
    required this.showEmployee,
    required this.showReviewActions,
    required this.onApprove,
    required this.onReject,
  });

  final String documentId;
  final Map<String, dynamic> data;
  final bool showEmployee;
  final bool showReviewActions;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final String employeeName =
        data['employeeName']?.toString() ??
            'Employee';

    final String employeeId =
        _employeeIdFromValue(data['employeeId']);

    final String leaveType =
        _formatLabel(
          data['leaveType']?.toString() ?? 'leave',
        );

    final String status =
        data['status']?.toString() ?? 'pending';

    final int numberOfDays =
        (data['numberOfDays'] as num?)?.toInt() ?? 0;

    final DateTime? startDate =
        _dateTimeFromValue(data['startDate']);

    final DateTime? endDate =
        _dateTimeFromValue(data['endDate']);

    final String reason =
        data['reason']?.toString() ??
            'No reason provided.';

    final String filedByRole =
        _formatLabel(
          data['filedByRole']?.toString() ??
              'employee',
        );

    final String? reviewRemarks =
        data['reviewRemarks']?.toString();

    final bool isPending =
        status.toLowerCase() == 'pending';

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showEmployee) ...[
                CircleAvatar(
                  backgroundColor:
                      const Color(0xFFFFF1EA),
                  child: Text(
                    _initials(employeeName),
                    style: const TextStyle(
                      color: Color(0xFFF04B0B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    if (showEmployee)
                      Text(
                        employeeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (showEmployee)
                      Text(
                        employeeId.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 11,
                        ),
                      ),
                    if (!showEmployee)
                      Text(
                        '$leaveType Leave',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
              _LeaveStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          if (showEmployee)
            Text(
              '$leaveType Leave',
              style: const TextStyle(
                color: Color(0xFF101828),
                fontWeight: FontWeight.w800,
              ),
            ),
          if (showEmployee)
            const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 18,
                color: Color(0xFF667085),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${_formatDate(startDate)} – '
                  '${_formatDate(endDate)}',
                  style: const TextStyle(
                    color: Color(0xFF344054),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$numberOfDays '
                '${numberOfDays == 1 ? 'day' : 'days'}',
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reason,
            style: const TextStyle(
              color: Color(0xFF475467),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Filed by: $filedByRole',
            style: const TextStyle(
              color: Color(0xFF98A2B3),
              fontSize: 11,
            ),
          ),
          if (reviewRemarks != null &&
              reviewRemarks.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Review remarks: $reviewRemarks',
                style: const TextStyle(
                  color: Color(0xFF912018),
                  fontSize: 12,
                ),
              ),
            ),
          ],
          if (showReviewActions && isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF039855),
                      foregroundColor: Colors.white,
                    ),
                    icon:
                        const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          const Color(0xFFD92D20),
                      side: const BorderSide(
                        color: Color(0xFFD92D20),
                      ),
                    ),
                    icon:
                        const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              documentId,
              style: const TextStyle(
                color: Color(0xFF98A2B3),
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveOverviewCard extends StatelessWidget {
  const _LeaveOverviewCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: accentColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                value.toString(),
                style: TextStyle(
                  color: accentColor,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveStatusChip extends StatelessWidget {
  const _LeaveStatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;

    switch (status.toLowerCase()) {
      case 'approved':
        background = const Color(0xFFECFDF3);
        foreground = const Color(0xFF027A48);
        break;

      case 'rejected':
        background = const Color(0xFFFEF3F2);
        foreground = const Color(0xFFB42318);
        break;

      default:
        background = const Color(0xFFFFF7ED);
        foreground = const Color(0xFFB54708);
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
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LeaveMessageState extends StatelessWidget {
  const _LeaveMessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 45,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: const Color(0xFFE4E7EC),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

DateTime _requestDate(Map<String, dynamic> data) {
  return _dateTimeFromValue(data['filedAt']) ??
      _dateTimeFromValue(data['createdAt']) ??
      _dateTimeFromValue(data['startDate']) ??
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

String _formatDate(DateTime? date) {
  if (date == null) {
    return 'Not available';
  }

  const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
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
    return parts.first[0].toUpperCase();
  }

  return '${parts.first[0]}${parts.last[0]}'
      .toUpperCase();
}