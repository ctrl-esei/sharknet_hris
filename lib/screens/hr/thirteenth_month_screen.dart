import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/thirteenth_month_service.dart';

class ThirteenthMonthScreen extends StatefulWidget {
  const ThirteenthMonthScreen({required this.employeeId, super.key});

  final String employeeId;

  @override
  State<ThirteenthMonthScreen> createState() => _ThirteenthMonthScreenState();
}

class _ThirteenthMonthScreenState extends State<ThirteenthMonthScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;

  String _employeeName = '';
  String _position = '';

  int _selectedYear = DateTime.now().year;

  ThirteenthMonthSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<dynamic> results = await Future.wait<dynamic>([
        FirebaseFirestore.instance
            .collection('employee')
            .doc(widget.employeeId)
            .get(),
        ThirteenthMonthService.calculate(
          employeeId: widget.employeeId,
          calendarYear: _selectedYear,
        ),
      ]);

      final DocumentSnapshot<Map<String, dynamic>> employeeDocument =
          results[0] as DocumentSnapshot<Map<String, dynamic>>;

      final Map<String, dynamic> employeeData =
          employeeDocument.data() ?? <String, dynamic>{};

      if (!employeeDocument.exists) {
        throw StateError('Employee record was not found.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _employeeName =
            employeeData['fullName']?.toString() ??
            widget.employeeId.toUpperCase();

        _position =
            employeeData['position']?.toString() ?? 'Position not specified';

        _summary = results[1] as ThirteenthMonthSummary;

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _save({required bool submitForApproval}) async {
    final ThirteenthMonthSummary? summary = _summary;

    if (summary == null) {
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage('Your login session has expired.', isError: true);
      return;
    }

    if (summary.eligiblePayrollCount == 0) {
      _showMessage(
        'There are no approved or released '
        'regular payroll records for '
        '$_selectedYear.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final Map<String, dynamic> userSnapshot =
          await _loadCurrentUserSnapshot();

      final String payrollId =
          '13th_${widget.employeeId}_'
          '$_selectedYear';

      final String payslipId = 'ps_$payrollId';

      final DocumentReference<Map<String, dynamic>> payrollReference =
          FirebaseFirestore.instance.collection('payroll').doc(payrollId);

      final DocumentReference<Map<String, dynamic>> payslipReference =
          FirebaseFirestore.instance.collection('payslips').doc(payslipId);

      final DocumentSnapshot<Map<String, dynamic>> existingPayroll =
          await payrollReference.get();

      final DocumentSnapshot<Map<String, dynamic>> existingPayslip =
          await payslipReference.get();

      final String existingStatus =
          existingPayroll.data()?['status']?.toString().toLowerCase() ?? '';

      if (<String>{
        'pending_approval',
        'approved',
        'released',
      }.contains(existingStatus)) {
        throw StateError(
          'This 13th-month payroll has already '
          'been submitted and is locked.',
        );
      }

      final String targetStatus = submitForApproval
          ? 'pending_approval'
          : 'draft';

      final DateTime yearStart = DateTime(_selectedYear);

      final DateTime yearEnd = DateTime(_selectedYear, 12, 31);

      final Map<String, dynamic> data = <String, dynamic>{
        'payrollType': 'thirteenth_month',

        'payrollYear': _selectedYear,

        'employeeId': summary.employeeReference,

        'employeeName': _employeeName,

        'position': _position,

        'payrollPeriodStart': Timestamp.fromDate(yearStart),

        'payrollPeriodEnd': Timestamp.fromDate(yearEnd),

        'basicPay': 0.0,

        'overtimePay': 0.0,

        'holidayPay': 0.0,

        'allowances': 0.0,

        'thirteenthMonthPay': summary.thirteenthMonthPay,

        'grossPay': summary.thirteenthMonthPay,

        'totalDeductions': 0.0,

        'netPay': summary.thirteenthMonthPay,

        'thirteenthMonthBreakdown': summary.toMap(),

        'status': targetStatus,

        'submittedForApproval': submitForApproval,

        'preparedBy': userSnapshot,

        'preparedAt': FieldValue.serverTimestamp(),

        'updatedAt': FieldValue.serverTimestamp(),

        if (submitForApproval) 'generatedBy': userSnapshot,

        if (submitForApproval) 'generatedAt': FieldValue.serverTimestamp(),

        if (submitForApproval) 'submittedAt': FieldValue.serverTimestamp(),
      };

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.set(payrollReference, <String, dynamic>{
        ...data,
        if (!existingPayroll.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (submitForApproval) {
        batch.set(payslipReference, <String, dynamic>{
          ...data,
          'payrollId': payrollReference,
          'status': 'pending_approval',
          'generatedBy': userSnapshot,
          'generatedAt': FieldValue.serverTimestamp(),
          'approvedBy': null,
          'approvedAt': null,
          'approvalRemarks': null,
          if (!existingPayslip.exists)
            'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) {
        return;
      }

      _showMessage(
        submitForApproval
            ? '13th-month pay submitted '
                  'for approval.'
            : '13th-month pay saved as draft.',
        isError: false,
      );

      if (submitForApproval) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showMessage(
        'Unable to save 13th-month pay: '
        '$error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _loadCurrentUserSnapshot() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Your login session has expired.');
    }

    final DocumentSnapshot<Map<String, dynamic>> userDocument =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    final Map<String, dynamic> userData =
        userDocument.data() ?? <String, dynamic>{};

    return <String, dynamic>{
      'uid': user.uid,
      'fullName':
          userData['fullName']?.toString() ??
          user.displayName ??
          'Unknown user',
      'email': userData['email']?.toString() ?? user.email ?? '',
      'role':
          userData['userRole']?.toString() ??
          userData['role']?.toString() ??
          'hr',
    };
  }

  void _showMessage(String message, {required bool isError}) {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('13th-Month Pay'),
        backgroundColor: const Color(0xFFF04B0B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                color: Color(0xFFD92D20),
                size: 58,
              ),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final ThirteenthMonthSummary summary = _summary!;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _employeeName,
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.employeeId.toUpperCase()} '
                '• $_position',
                style: const TextStyle(color: Color(0xFF667085)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        DropdownButtonFormField<int>(
          initialValue: _selectedYear,
          decoration: InputDecoration(
            labelText: 'Calendar Year',
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items:
              List<int>.generate(5, (int index) => DateTime.now().year - index)
                  .map(
                    (int year) => DropdownMenuItem<int>(
                      value: year,
                      child: Text(year.toString()),
                    ),
                  )
                  .toList(),
          onChanged: (int? year) async {
            if (year == null || year == _selectedYear) {
              return;
            }

            setState(() {
              _selectedYear = year;
            });

            await _load();
          },
        ),

        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFDDBD)),
          ),
          child: Column(
            children: <Widget>[
              _summaryRow(
                label: 'Eligible Payroll Records',
                value: summary.eligiblePayrollCount.toString(),
              ),
              _summaryRow(
                label: 'Total Eligible Basic Salary',
                value: _money(summary.totalEligibleBasicSalary),
              ),
              _summaryRow(label: 'Divisor', value: '12'),
              const Divider(height: 24),
              _summaryRow(
                label: '13th-Month Pay',
                value: _money(summary.thirteenthMonthPay),
                bold: true,
                highlight: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'Only approved or released regular '
          'payroll records for the selected year '
          'are included.',
          style: TextStyle(color: Color(0xFF667085), fontSize: 12, height: 1.4),
        ),

        const SizedBox(height: 24),

        OutlinedButton.icon(
          onPressed: _isSaving
              ? null
              : () {
                  _save(submitForApproval: false);
                },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF04B0B),
            minimumSize: const Size.fromHeight(53),
            side: const BorderSide(color: Color(0xFFF04B0B)),
          ),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save as Draft'),
        ),

        const SizedBox(height: 11),

        FilledButton.icon(
          onPressed: _isSaving
              ? null
              : () {
                  _save(submitForApproval: true);
                },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF04B0B),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(53),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_outlined),
          label: Text(_isSaving ? 'Saving...' : 'Save and Submit for Approval'),
        ),
      ],
    );
  }

  Widget _summaryRow({
    required String label,
    required String value,
    bool bold = false,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFF475467),
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight
                  ? const Color(0xFFF04B0B)
                  : const Color(0xFF101828),
              fontSize: highlight ? 19 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _money(double value) {
    return 'PHP ${value.toStringAsFixed(2)}';
  }
}
