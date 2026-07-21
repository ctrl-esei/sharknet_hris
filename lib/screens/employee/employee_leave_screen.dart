import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmployeeLeaveScreen extends StatefulWidget {
  const EmployeeLeaveScreen({
    required this.employeeId,
    required this.fullName,
    super.key,
  });

  final String employeeId;
  final String fullName;

  @override
  State<EmployeeLeaveScreen> createState() =>
      _EmployeeLeaveScreenState();
}

class _EmployeeLeaveScreenState
    extends State<EmployeeLeaveScreen> {
  late final Future<
          DocumentReference<Map<String, dynamic>>>
      _employeeReferenceFuture;

  String _statusFilter = 'all';
  String _typeFilter = 'all';
  int? _selectedYear;
  String? _processingRequestId;

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

  Future<void> _openLeaveForm({
    required DocumentReference<Map<String, dynamic>>
        employeeReference,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>>
        employeeSnapshot =
        await employeeReference.get();

    if (!mounted) {
      return;
    }

    final Map<String, dynamic> employeeData =
        employeeSnapshot.data() ??
            <String, dynamic>{};

    final String employeeName =
        _text(
          employeeData['fullName'],
          fallback: widget.fullName,
        );

    final bool? created =
        await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (
        BuildContext bottomSheetContext,
      ) {
        return _LeaveRequestFormSheet(
          employeeReference: employeeReference,
          employeeName: employeeName,
          employeeCode: _text(
            employeeData['employeeId'],
            fallback: employeeReference.id,
          ),
        );
      },
    );

    if (created == true && mounted) {
      _showMessage(
        'Leave request submitted to HR.',
        error: false,
      );
    }
  }

  Future<void> _cancelRequest({
    required String requestId,
    required DocumentReference<Map<String, dynamic>>
        requestReference,
    required Map<String, dynamic> data,
  }) async {
    if (_processingRequestId != null) {
      return;
    }

    final String status =
        _normalizeStatus(data['status']);

    if (status != 'pending') {
      _showMessage(
        'Only pending leave requests can be cancelled.',
        error: true,
      );
      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Cancel Leave Request',
          ),
          content: const Text(
            'Cancel this pending leave request? '
            'HR will no longer be able to approve it.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false);
              },
              child: const Text('Keep Request'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFFD92D20),
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel Request'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _processingRequestId = requestId;
    });

    try {
      await requestReference.update(
        <String, dynamic>{
          'status': 'cancelled',
          'cancelledBy':
              FirebaseAuth.instance.currentUser?.uid,
          'cancelledAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
      );

      _showMessage(
        'Leave request cancelled.',
        error: false,
      );
    } catch (error) {
      _showMessage(
        'Unable to cancel leave request: $error',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestId = null;
        });
      }
    }
  }

  void _showRequestDetails({
    required String requestId,
    required Map<String, dynamic> data,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (
        BuildContext context,
      ) {
        return _LeaveRequestDetailsSheet(
          requestId: requestId,
          data: data,
        );
      },
    );
  }

  void _showMessage(
    String message, {
    required bool error,
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
          backgroundColor: error
              ? const Color(0xFFD92D20)
              : const Color(0xFF039855),
        ),
      );
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
              return const _LeaveLoadingState();
            }

            if (employeeReferenceSnapshot.hasError ||
                !employeeReferenceSnapshot.hasData) {
              return _LeaveErrorState(
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
                  .collection('leave_request')
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
                    leaveSnapshot,
              ) {
                if (leaveSnapshot.hasError) {
                  return _LeaveErrorState(
                    message:
                        'Unable to load your leave requests: '
                        '${leaveSnapshot.error}',
                  );
                }

                if (!leaveSnapshot.hasData) {
                  return const _LeaveLoadingState();
                }

                final List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    allRequests =
                    leaveSnapshot.data!.docs.toList();

                allRequests.sort(
                  (
                    QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        first,
                    QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        second,
                  ) {
                    return _sortDate(
                      second.data(),
                    ).compareTo(
                      _sortDate(first.data()),
                    );
                  },
                );

                final List<int> years =
                    _availableYears(allRequests);

                if (_selectedYear != null &&
                    !years.contains(_selectedYear)) {
                  _selectedYear = null;
                }

                final List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    filteredRequests =
                    _filteredRequests(
                  allRequests,
                );

                final _LeaveSummary summary =
                    _calculateSummary(
                  allRequests,
                );

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
                      _buildHeader(
                        employeeReference,
                      ),
                      const SizedBox(height: 18),
                      _buildSummary(summary),
                      const SizedBox(height: 18),
                      _buildFilters(years),
                      const SizedBox(height: 20),
                      _buildRequestHeader(
                        count:
                            filteredRequests.length,
                      ),
                      const SizedBox(height: 12),
                      if (allRequests.isEmpty)
                        const _LeaveMessageState(
                          icon:
                              Icons.calendar_month_outlined,
                          title:
                              'No leave requests yet',
                          message:
                              'Tap File Leave to send your first request to HR.',
                        )
                      else if (filteredRequests.isEmpty)
                        const _LeaveMessageState(
                          icon:
                              Icons.filter_alt_off,
                          title:
                              'No matching requests',
                          message:
                              'Try choosing another status, leave type, or year.',
                        )
                      else
                        ...filteredRequests.map(
                          (
                            QueryDocumentSnapshot<
                                    Map<String, dynamic>>
                                document,
                          ) {
                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom: 12,
                              ),
                              child:
                                  _EmployeeLeaveRequestCard(
                                requestId:
                                    document.id,
                                data: document.data(),
                                processing:
                                    _processingRequestId ==
                                        document.id,
                                onView: () {
                                  _showRequestDetails(
                                    requestId:
                                        document.id,
                                    data:
                                        document.data(),
                                  );
                                },
                                onCancel: () {
                                  _cancelRequest(
                                    requestId:
                                        document.id,
                                    requestReference:
                                        document.reference,
                                    data:
                                        document.data(),
                                  );
                                },
                              ),
                            );
                          },
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

  Widget _buildHeader(
    DocumentReference<Map<String, dynamic>>
        employeeReference,
  ) {
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
              'My Leave',
              style: TextStyle(
                color: Color(0xFF101828),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'File leave requests and track HR approval decisions.',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        );

        final Widget fileButton =
            FilledButton.icon(
          onPressed: () {
            _openLeaveForm(
              employeeReference:
                  employeeReference,
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor:
                const Color(0xFF2979FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(
            Icons.add_circle_outline,
          ),
          label: const Text('File Leave'),
        );

        if (compact) {
          return Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: <Widget>[
              title,
              const SizedBox(height: 14),
              fileButton,
            ],
          );
        }

        return Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: title),
            const SizedBox(width: 14),
            fileButton,
          ],
        );
      },
    );
  }

  Widget _buildSummary(
    _LeaveSummary summary,
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
              child: _LeaveSummaryCard(
                label: 'Pending',
                value: summary.pending.toString(),
                icon: Icons.schedule_outlined,
                backgroundColor:
                    const Color(0xFFFFF3E0),
                foregroundColor:
                    const Color(0xFFEF6C00),
              ),
            ),
            SizedBox(
              width: width,
              child: _LeaveSummaryCard(
                label: 'Approved',
                value:
                    summary.approved.toString(),
                icon:
                    Icons.check_circle_outline,
                backgroundColor:
                    const Color(0xFFE8F5E9),
                foregroundColor:
                    const Color(0xFF2E7D32),
              ),
            ),
            SizedBox(
              width: width,
              child: _LeaveSummaryCard(
                label: 'Rejected',
                value:
                    summary.rejected.toString(),
                icon: Icons.cancel_outlined,
                backgroundColor:
                    const Color(0xFFFFEBEE),
                foregroundColor:
                    const Color(0xFFC62828),
              ),
            ),
            SizedBox(
              width: width,
              child: _LeaveSummaryCard(
                label: 'Approved Days',
                value:
                    _formatDays(summary.approvedDays),
                icon:
                    Icons.event_available_outlined,
                backgroundColor:
                    const Color(0xFFE3F2FD),
                foregroundColor:
                    const Color(0xFF1565C0),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilters(
    List<int> years,
  ) {
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
          DropdownButtonFormField<int?>(
            initialValue: _selectedYear,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Leave Year',
              prefixIcon: const Icon(
                Icons.calendar_today_outlined,
              ),
              filled: true,
              fillColor:
                  const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
            items: <DropdownMenuItem<int?>>[
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('All Years'),
              ),
              ...years.map(
                (int year) =>
                    DropdownMenuItem<int?>(
                  value: year,
                  child: Text(year.toString()),
                ),
              ),
            ],
            onChanged: (int? value) {
              setState(() {
                _selectedYear = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child:
                    DropdownButtonFormField<String>(
                  initialValue:
                      _statusFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    prefixIcon: const Icon(
                      Icons.filter_alt_outlined,
                    ),
                    filled: true,
                    fillColor:
                        const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  items: const <
                      DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'all',
                      child: Text('All'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'pending',
                      child: Text('Pending'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'approved',
                      child: Text('Approved'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'rejected',
                      child: Text('Rejected'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'cancelled',
                      child: Text('Cancelled'),
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
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    DropdownButtonFormField<String>(
                  initialValue:
                      _typeFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    prefixIcon: const Icon(
                      Icons.category_outlined,
                    ),
                    filled: true,
                    fillColor:
                        const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  items: const <
                      DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'all',
                      child: Text('All'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'vacation',
                      child: Text('Vacation'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'sick',
                      child: Text('Sick'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'emergency',
                      child: Text('Emergency'),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _typeFilter = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestHeader({
    required int count,
  }) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Text(
            'Leave Requests',
            style: TextStyle(
              color: Color(0xFF101828),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          '$count request${count == 1 ? '' : 's'}',
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
      _filteredRequests(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        requests,
  ) {
    return requests.where(
      (
        QueryDocumentSnapshot<Map<String, dynamic>>
            document,
      ) {
        final Map<String, dynamic> data =
            document.data();

        final String status =
            _normalizeStatus(data['status']);

        final String leaveType =
            _normalizeLeaveType(
          data['leaveType'],
        );

        final int? year =
            _requestYear(data);

        final bool statusMatches =
            _statusFilter == 'all' ||
                status == _statusFilter;

        final bool typeMatches =
            _typeFilter == 'all' ||
                leaveType == _typeFilter;

        final bool yearMatches =
            _selectedYear == null ||
                year == _selectedYear;

        return statusMatches &&
            typeMatches &&
            yearMatches;
      },
    ).toList();
  }

  List<int> _availableYears(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        requests,
  ) {
    final Set<int> years = <int>{};

    for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        document in requests) {
      final int? year =
          _requestYear(document.data());

      if (year != null) {
        years.add(year);
      }
    }

    final List<int> sorted =
        years.toList()
          ..sort(
            (
              int first,
              int second,
            ) =>
                second.compareTo(first),
          );

    return sorted;
  }

  _LeaveSummary _calculateSummary(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        requests,
  ) {
    int pending = 0;
    int approved = 0;
    int rejected = 0;
    double approvedDays = 0;

    for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        document in requests) {
      final Map<String, dynamic> data =
          document.data();

      final String status =
          _normalizeStatus(data['status']);

      if (status == 'pending') {
        pending++;
      } else if (status == 'approved') {
        approved++;
        approvedDays +=
            _requestDays(data);
      } else if (status == 'rejected') {
        rejected++;
      }
    }

    return _LeaveSummary(
      pending: pending,
      approved: approved,
      rejected: rejected,
      approvedDays: approvedDays,
    );
  }
}

class _LeaveRequestFormSheet
    extends StatefulWidget {
  const _LeaveRequestFormSheet({
    required this.employeeReference,
    required this.employeeName,
    required this.employeeCode,
  });

  final DocumentReference<Map<String, dynamic>>
      employeeReference;

  final String employeeName;
  final String employeeCode;

  @override
  State<_LeaveRequestFormSheet> createState() =>
      _LeaveRequestFormSheetState();
}

class _LeaveRequestFormSheetState
    extends State<_LeaveRequestFormSheet> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _reasonController =
      TextEditingController();

  String _leaveType = 'vacation';

  DateTime _startDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int get _numberOfDays {
    final DateTime start = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );

    final DateTime end = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
    );

    if (end.isBefore(start)) {
      return 0;
    }

    return end.difference(start).inDays + 1;
  }

  Future<void> _pickStartDate() async {
    final DateTime today = DateTime.now();

    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(
        today.year - 1,
      ),
      lastDate: DateTime(
        today.year + 2,
      ),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _startDate = selected;

      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate)
          ? _startDate
          : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(
        _startDate.year + 2,
      ),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _endDate = selected;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final bool valid =
        _formKey.currentState?.validate() ??
            false;

    if (!valid) {
      return;
    }

    if (_numberOfDays <= 0) {
      return;
    }

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Your login session has expired.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('leave_request')
          .add(
        <String, dynamic>{
          'employeeId':
              widget.employeeReference,
          'employeeName':
              widget.employeeName,
          'employeeCode':
              widget.employeeCode,

          'leaveType': _leaveType,

          'startDate':
              Timestamp.fromDate(_startDate),
          'endDate':
              Timestamp.fromDate(_endDate),

          // Both names are saved for compatibility
          // with existing HR screens and reports.
          'numberOfDays': _numberOfDays,
          'totalDays':
              _numberOfDays.toDouble(),

          'reason':
              _reasonController.text.trim(),

          'status': 'pending',

          'submittedBy': <String, dynamic>{
            'uid': user.uid,
            'email': user.email ?? '',
            'fullName':
                widget.employeeName,
            'role': 'employee',
          },
          'submittedByUid': user.uid,
          'submittedAt':
              FieldValue.serverTimestamp(),

          'reviewedBy': null,
          'reviewedAt': null,
          'reviewRemarks': null,
          'rejectionReason': null,

          'createdAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Unable to submit leave request: $error',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor:
                const Color(0xFFD92D20),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets keyboardPadding =
        MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: keyboardPadding,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              28,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFD0D5DD),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'File Leave Request',
                    style: TextStyle(
                      color: Color(0xFF101828),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${widget.employeeName} • '
                    '${widget.employeeCode.toUpperCase()}',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: _leaveType,
                    decoration: InputDecoration(
                      labelText: 'Leave Type',
                      prefixIcon: const Icon(
                        Icons.category_outlined,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),
                    ),
                    items: const <
                        DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'vacation',
                        child:
                            Text('Vacation Leave'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'sick',
                        child: Text('Sick Leave'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'emergency',
                        child:
                            Text('Emergency Leave'),
                      ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (String? value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _leaveType = value;
                            });
                          },
                  ),
                  const SizedBox(height: 14),
                  _DateField(
                    label: 'Start Date',
                    value:
                        _formatLongDate(_startDate),
                    icon:
                        Icons.event_available_outlined,
                    onTap:
                        _isSubmitting
                            ? null
                            : _pickStartDate,
                  ),
                  const SizedBox(height: 14),
                  _DateField(
                    label: 'End Date',
                    value:
                        _formatLongDate(_endDate),
                    icon:
                        Icons.event_busy_outlined,
                    onTap:
                        _isSubmitting
                            ? null
                            : _pickEndDate,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFEFF6FF),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Number of days: $_numberOfDays',
                      style: const TextStyle(
                        color:
                            Color(0xFF1849A9),
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller:
                        _reasonController,
                    minLines: 3,
                    maxLines: 6,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      labelText: 'Reason',
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding:
                            EdgeInsets.only(
                          bottom: 72,
                        ),
                        child: Icon(
                          Icons.notes_outlined,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),
                    ),
                    validator: (String? value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Please provide a reason.';
                      }

                      if (value.trim().length < 5) {
                        return 'Please enter a clearer reason.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed:
                        _isSubmitting
                            ? null
                            : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xFF2979FF,
                      ),
                      foregroundColor:
                          Colors.white,
                      minimumSize:
                          const Size.fromHeight(
                        54,
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_outlined,
                          ),
                    label: Text(
                      _isSubmitting
                          ? 'Submitting...'
                          : 'Submit to HR',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployeeLeaveRequestCard
    extends StatelessWidget {
  const _EmployeeLeaveRequestCard({
    required this.requestId,
    required this.data,
    required this.processing,
    required this.onView,
    required this.onCancel,
  });

  final String requestId;
  final Map<String, dynamic> data;
  final bool processing;
  final VoidCallback onView;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final String status =
        _normalizeStatus(data['status']);

    final String leaveType =
        _normalizeLeaveType(data['leaveType']);

    final DateTime? startDate =
        _date(data['startDate']);

    final DateTime? endDate =
        _date(data['endDate']);

    final double numberOfDays =
        _requestDays(data);

    final String reason =
        _text(
          data['reason'],
          fallback: 'No reason provided',
        );

    final String decisionReason =
        _decisionReason(data);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onView,
        borderRadius:
            BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(18),
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
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color:
                          _leaveTypeBackground(
                        leaveType,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child: Icon(
                      _leaveTypeIcon(leaveType),
                      color: _leaveTypeColor(
                        leaveType,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _formatLeaveType(
                            leaveType,
                          ),
                          style: const TextStyle(
                            color:
                                Color(0xFF101828),
                            fontSize: 17,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _periodLabel(
                            startDate,
                            endDate,
                          ),
                          style: const TextStyle(
                            color:
                                Color(0xFF667085),
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _LeaveStatusChip(
                    status: status,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 13),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _LeaveDetail(
                      label: 'Days',
                      value:
                          _formatDays(numberOfDays),
                      icon:
                          Icons.date_range_outlined,
                    ),
                  ),
                  Expanded(
                    child: _LeaveDetail(
                      label: 'Submitted',
                      value: _shortDate(
                        _date(
                              data['submittedAt'],
                            ) ??
                            _date(
                              data['createdAt'],
                            ),
                      ),
                      icon:
                          Icons.upload_outlined,
                    ),
                  ),
                  Expanded(
                    child: _LeaveDetail(
                      label: 'Reviewed',
                      value: _shortDate(
                        _date(
                          data['reviewedAt'],
                        ),
                      ),
                      icon:
                          Icons.fact_check_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF475467),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if ((status == 'rejected' ||
                      status == 'returned') &&
                  decisionReason.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFFFF4ED),
                    borderRadius:
                        BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          const Color(0xFFFFD6AE),
                    ),
                  ),
                  child: Text(
                    'HR remarks: $decisionReason',
                    style: const TextStyle(
                      color: Color(0xFFB54708),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onView,
                      icon: const Icon(
                        Icons.visibility_outlined,
                        size: 18,
                      ),
                      label: const Text('View'),
                    ),
                  ),
                  if (status == 'pending') ...<Widget>[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            processing
                                ? null
                                : onCancel,
                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              const Color(
                            0xFFD92D20,
                          ),
                          side: const BorderSide(
                            color:
                                Color(0xFFD92D20),
                          ),
                        ),
                        icon: processing
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .cancel_outlined,
                                size: 18,
                              ),
                        label: Text(
                          processing
                              ? 'Cancelling'
                              : 'Cancel',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveRequestDetailsSheet
    extends StatelessWidget {
  const _LeaveRequestDetailsSheet({
    required this.requestId,
    required this.data,
  });

  final String requestId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final String status =
        _normalizeStatus(data['status']);

    final String leaveType =
        _normalizeLeaveType(data['leaveType']);

    final DateTime? startDate =
        _date(data['startDate']);

    final DateTime? endDate =
        _date(data['endDate']);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (
        BuildContext context,
        ScrollController scrollController,
      ) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              30,
            ),
            children: <Widget>[
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFD0D5DD),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Leave Request Details',
                      style: TextStyle(
                        color:
                            Color(0xFF101828),
                        fontSize: 22,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),
                  _LeaveStatusChip(
                    status: status,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _LeaveDetailsSection(
                title: 'Request',
                children: <Widget>[
                  _TextDetailRow(
                    label: 'Leave Type',
                    value: _formatLeaveType(
                      leaveType,
                    ),
                  ),
                  _TextDetailRow(
                    label: 'Start Date',
                    value: _formatLongDate(
                      startDate,
                    ),
                  ),
                  _TextDetailRow(
                    label: 'End Date',
                    value: _formatLongDate(
                      endDate,
                    ),
                  ),
                  _TextDetailRow(
                    label: 'Number of Days',
                    value: _formatDays(
                      _requestDays(data),
                    ),
                  ),
                  _TextDetailRow(
                    label: 'Reason',
                    value: _text(
                      data['reason'],
                      fallback:
                          'No reason provided',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _LeaveDetailsSection(
                title: 'HR Review',
                children: <Widget>[
                  _TextDetailRow(
                    label: 'Status',
                    value:
                        _formatLabel(status),
                  ),
                  _TextDetailRow(
                    label: 'Reviewed By',
                    value: _reviewerLabel(
                      data['reviewedBy'],
                    ),
                  ),
                  _TextDetailRow(
                    label: 'Reviewed At',
                    value:
                        _formatDateTime(
                      _date(
                        data['reviewedAt'],
                      ),
                    ),
                  ),
                  _TextDetailRow(
                    label: 'Remarks',
                    value: _decisionReason(data)
                            .isEmpty
                        ? 'No remarks'
                        : _decisionReason(data),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _LeaveDetailsSection(
                title: 'Submission Information',
                children: <Widget>[
                  _TextDetailRow(
                    label: 'Submitted At',
                    value:
                        _formatDateTime(
                      _date(
                            data['submittedAt'],
                          ) ??
                          _date(
                            data['createdAt'],
                          ),
                    ),
                  ),
                  _TextDetailRow(
                    label: 'Request ID',
                    value: requestId,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: Color(0xFF101828),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LeaveDetailsSection
    extends StatelessWidget {
  const _LeaveDetailsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
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
          const SizedBox(height: 11),
          ...children,
        ],
      ),
    );
  }
}

class _TextDetailRow extends StatelessWidget {
  const _TextDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF101828),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveSummaryCard
    extends StatelessWidget {
  const _LeaveSummaryCard({
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

class _LeaveDetail extends StatelessWidget {
  const _LeaveDetail({
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
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaveStatusChip
    extends StatelessWidget {
  const _LeaveStatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;

    switch (status) {
      case 'approved':
        background =
            const Color(0xFFE8F5E9);
        foreground =
            const Color(0xFF2E7D32);
        break;

      case 'rejected':
        background =
            const Color(0xFFFFEBEE);
        foreground =
            const Color(0xFFC62828);
        break;

      case 'cancelled':
        background =
            const Color(0xFFF2F4F7);
        foreground =
            const Color(0xFF475467);
        break;

      default:
        background =
            const Color(0xFFFFF3E0);
        foreground =
            const Color(0xFFEF6C00);
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
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LeaveMessageState
    extends StatelessWidget {
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

class _LeaveLoadingState
    extends StatelessWidget {
  const _LeaveLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _LeaveErrorState
    extends StatelessWidget {
  const _LeaveErrorState({
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
                'Unable to Load Leave',
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

class _LeaveSummary {
  const _LeaveSummary({
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.approvedDays,
  });

  final int pending;
  final int approved;
  final int rejected;
  final double approvedDays;
}

String _normalizeStatus(dynamic value) {
  final String status =
      value?.toString().trim().toLowerCase() ??
          'pending';

  return status
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
}

String _normalizeLeaveType(dynamic value) {
  final String type =
      value?.toString().trim().toLowerCase() ??
          'vacation';

  final String cleaned = type
      .replaceAll('-', '_')
      .replaceAll(' ', '_')
      .replaceAll('_leave', '')
      .replaceAll('leave_', '');

  if (cleaned.contains('sick')) {
    return 'sick';
  }

  if (cleaned.contains('emergency')) {
    return 'emergency';
  }

  return 'vacation';
}

double _requestDays(
  Map<String, dynamic> data,
) {
  final double numberOfDays =
      _number(data['numberOfDays']);

  if (numberOfDays > 0) {
    return numberOfDays;
  }

  final double totalDays =
      _number(data['totalDays']);

  if (totalDays > 0) {
    return totalDays;
  }

  final DateTime? start =
      _date(data['startDate']);

  final DateTime? end =
      _date(data['endDate']);

  if (start == null || end == null) {
    return 0;
  }

  final DateTime startOnly = DateTime(
    start.year,
    start.month,
    start.day,
  );

  final DateTime endOnly = DateTime(
    end.year,
    end.month,
    end.day,
  );

  if (endOnly.isBefore(startOnly)) {
    return 0;
  }

  return endOnly.difference(startOnly).inDays + 1;
}

int? _requestYear(
  Map<String, dynamic> data,
) {
  return _date(data['startDate'])?.year ??
      _date(data['submittedAt'])?.year ??
      _date(data['createdAt'])?.year;
}

int _sortDate(
  Map<String, dynamic> data,
) {
  final DateTime? value =
      _date(data['submittedAt']) ??
          _date(data['createdAt']) ??
          _date(data['startDate']);

  return value?.millisecondsSinceEpoch ?? 0;
}

String _decisionReason(
  Map<String, dynamic> data,
) {
  return _text(
    data['rejectionReason'] ??
        data['reviewRemarks'] ??
        data['remarks'] ??
        data['returnReason'],
    fallback: '',
  );
}

String _reviewerLabel(dynamic value) {
  if (value is Map<String, dynamic>) {
    return _text(
      value['fullName'] ??
          value['email'] ??
          value['uid'],
      fallback: 'Not available',
    );
  }

  if (value is Map) {
    return _reviewerLabel(
      value.map<String, dynamic>(
        (
          dynamic key,
          dynamic item,
        ) =>
            MapEntry<String, dynamic>(
          key.toString(),
          item,
        ),
      ),
    );
  }

  return _text(
    value,
    fallback: 'Not available',
  );
}

DateTime? _date(dynamic value) {
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

String _text(
  dynamic value, {
  required String fallback,
}) {
  final String text =
      value?.toString().trim() ?? '';

  return text.isEmpty ? fallback : text;
}

String _periodLabel(
  DateTime? start,
  DateTime? end,
) {
  if (start == null && end == null) {
    return 'Dates unavailable';
  }

  if (start == null) {
    return _formatLongDate(end);
  }

  if (end == null) {
    return _formatLongDate(start);
  }

  return '${_shortDate(start)} – '
      '${_shortDate(end)}';
}

String _shortDate(DateTime? value) {
  if (value == null) {
    return '--';
  }

  return '${_monthShortName(value.month)} '
      '${value.day}, ${value.year}';
}

String _formatLongDate(DateTime? value) {
  if (value == null) {
    return 'Not available';
  }

  return '${_monthName(value.month)} '
      '${value.day}, ${value.year}';
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'Not available';
  }

  final int hour =
      value.hour % 12 == 0
          ? 12
          : value.hour % 12;

  final String minute =
      value.minute.toString().padLeft(2, '0');

  final String period =
      value.hour >= 12 ? 'PM' : 'AM';

  return '${_shortDate(value)} • '
      '$hour:$minute $period';
}

String _formatDays(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(1);
}

String _formatLeaveType(String value) {
  final String label =
      _formatLabel(value);

  return label.toLowerCase().endsWith('leave')
      ? label
      : '$label Leave';
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

Color _leaveTypeBackground(
  String type,
) {
  switch (type) {
    case 'sick':
      return const Color(0xFFFFF1F1);

    case 'emergency':
      return const Color(0xFFFFF7E8);

    default:
      return const Color(0xFFEFF5FF);
  }
}

Color _leaveTypeColor(
  String type,
) {
  switch (type) {
    case 'sick':
      return const Color(0xFFF04438);

    case 'emergency':
      return const Color(0xFFF79009);

    default:
      return const Color(0xFF155EEF);
  }
}

IconData _leaveTypeIcon(
  String type,
) {
  switch (type) {
    case 'sick':
      return Icons.medical_services_outlined;

    case 'emergency':
      return Icons.warning_amber_rounded;

    default:
      return Icons.beach_access_outlined;
  }
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

String _monthShortName(int month) {
  const List<String> months = <String>[
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

  if (month < 1 || month > 12) {
    return '';
  }

  return months[month - 1];
}
