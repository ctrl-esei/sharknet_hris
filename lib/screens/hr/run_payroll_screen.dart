import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/holiday_payroll_service.dart';
import '../../services/payroll_attendance_service.dart';
import '../../services/payroll_settings_service.dart';

class RunPayrollScreen extends StatefulWidget {
  const RunPayrollScreen({
    required this.employeeId,
    super.key,
  });

  final String employeeId;

  @override
  State<RunPayrollScreen> createState() =>
      _RunPayrollScreenState();
}

class _RunPayrollScreenState
    extends State<RunPayrollScreen> {
  static const double _workingDaysPerMonth = 22;
  static const double _requiredHoursPerDay = 8;
  static const double _ordinaryOvertimeMultiplier =
      1.25;

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _daysWorkedController =
      TextEditingController(text: '0');

  final TextEditingController _regularHoursController =
      TextEditingController(text: '0');

  final TextEditingController _overtimeHoursController =
      TextEditingController(text: '0');

  final TextEditingController _overtimeRateController =
      TextEditingController(text: '0');

  final TextEditingController _allowancesController =
      TextEditingController(text: '0');

  final TextEditingController _loanController =
      TextEditingController(text: '0');

  final TextEditingController _cashAdvanceController =
      TextEditingController(text: '0');

  final TextEditingController _miscellaneousController =
      TextEditingController(text: '0');

  DateTime _periodStart = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime _periodEnd = DateTime.now();

  Map<String, dynamic> _governmentCompliance =
      <String, dynamic>{};

  Map<String, dynamic> _holidayRules =
      <String, dynamic>{};

  PayrollAttendanceSummary? _attendanceSummary;

  HolidayPayrollSummary _holidaySummary =
      const HolidayPayrollSummary.empty();

  List<Map<String, dynamic>>
      _attendanceBreakdown =
      <Map<String, dynamic>>[];

  List<Map<String, dynamic>>
      _overtimeBreakdown =
      <Map<String, dynamic>>[];

  bool _isLoading = true;
  bool _isRefreshingAttendance = false;
  bool _isSaving = false;

  String? _errorMessage;

  String _fullName = '';
  String _position = '';
  String _salaryType = 'monthly';

  double _salaryRate = 0;

  List<TextEditingController> get _controllers {
    return <TextEditingController>[
      _allowancesController,
      _loanController,
      _cashAdvanceController,
      _miscellaneousController,
    ];
  }

  @override
  void initState() {
    super.initState();

    for (final TextEditingController controller
        in _controllers) {
      controller.addListener(_refreshCalculation);
    }

    _loadEmployeeAndSettings();
  }

  @override
  void dispose() {
    for (final TextEditingController controller
        in _controllers) {
      controller
        ..removeListener(_refreshCalculation)
        ..dispose();
    }

    _daysWorkedController.dispose();
    _regularHoursController.dispose();
    _overtimeHoursController.dispose();
    _overtimeRateController.dispose();

    super.dispose();
  }

  void _refreshCalculation() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadEmployeeAndSettings() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<dynamic> results =
          await Future.wait<dynamic>([
        FirebaseFirestore.instance
            .collection('employee')
            .doc(widget.employeeId)
            .get(),
        PayrollSettingsService
            .loadGovernmentCompliance(),
        PayrollSettingsService.loadHolidayRules(),
      ]);

      final DocumentSnapshot<Map<String, dynamic>>
          employeeDocument = results[0]
              as DocumentSnapshot<
                  Map<String, dynamic>>;

      if (!employeeDocument.exists) {
        throw StateError(
          'Employee record was not found.',
        );
      }

      final Map<String, dynamic> employeeData =
          employeeDocument.data() ??
              <String, dynamic>{};

      _fullName =
          employeeData['fullName']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? employeeData['fullName']
                  .toString()
                  .trim()
              : widget.employeeId.toUpperCase();

      _position =
          employeeData['position']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? employeeData['position']
                  .toString()
                  .trim()
              : 'Position not specified';

      _salaryType =
          employeeData['salaryType']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              'monthly';

      _salaryRate = _readNumber(
        employeeData['salaryRate'],
      );

      _governmentCompliance =
          results[1] as Map<String, dynamic>;

      _holidayRules =
          results[2] as Map<String, dynamic>;

      _overtimeRateController.text =
          _ordinaryOvertimeRate
              .toStringAsFixed(2);

      await _loadAttendanceAndHolidays(
        showProgress: false,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = null;
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

  Future<void> _loadAttendanceAndHolidays({
    bool showProgress = true,
  }) async {
    if (showProgress && mounted) {
      setState(() {
        _isRefreshingAttendance = true;
      });
    }

    try {
      final PayrollAttendanceSummary
          attendanceSummary =
          await PayrollAttendanceService.load(
        employeeId: widget.employeeId,
        periodStart: _periodStart,
        periodEnd: _periodEnd,
      );

      final HolidayPayrollSummary holidaySummary =
          await HolidayPayrollService.load(
        periodStart: _periodStart,
        periodEnd: _periodEnd,
        attendanceBreakdown:
            attendanceSummary.attendanceBreakdown,
        holidayRules: _holidayRules,
        hourlyRate: _defaultHourlyRate,
      );

      final double ordinaryDaysWorked =
          _calculateOrdinaryDaysWorked(
        attendanceSummary.attendanceBreakdown,
        holidaySummary.premiumDateKeys,
      );

      final double ordinaryRegularHours =
          _calculateOrdinaryRegularHours(
        attendanceSummary.attendanceBreakdown,
        holidaySummary.premiumDateKeys,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _attendanceSummary =
            attendanceSummary;

        _holidaySummary = holidaySummary;

        _attendanceBreakdown =
            attendanceSummary.attendanceBreakdown;

        _overtimeBreakdown =
            attendanceSummary.overtimeBreakdown;

        _daysWorkedController.text =
            ordinaryDaysWorked
                .toStringAsFixed(2);

        _regularHoursController.text =
            ordinaryRegularHours
                .toStringAsFixed(2);

        _overtimeHoursController.text =
            attendanceSummary.overtimeHours
                .toStringAsFixed(2);

        _overtimeRateController.text =
            _ordinaryOvertimeRate
                .toStringAsFixed(2);

        _isRefreshingAttendance = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRefreshingAttendance = false;
      });

      _showMessage(
        'Unable to load attendance and holidays: '
        '$error',
        isError: true,
      );
    }
  }

  // ============================================================
  // VALUES AND COMPUTATION
  // ============================================================

  double get _daysWorked =>
      _controllerNumber(_daysWorkedController);

  double get _regularHours =>
      _controllerNumber(_regularHoursController);

  double get _totalAttendanceOvertimeHours =>
      _controllerNumber(
        _overtimeHoursController,
      );

  double get _allowances =>
      _controllerNumber(_allowancesController);

  double get _loanDeduction =>
      _controllerNumber(_loanController);

  double get _cashAdvance =>
      _controllerNumber(
        _cashAdvanceController,
      );

  double get _miscellaneousDeduction =>
      _controllerNumber(
        _miscellaneousController,
      );

  double get _fixedSss {
    return PayrollSettingsService.number(
      _governmentCompliance,
      'sss',
    );
  }

  double get _fixedPhilHealth {
    return PayrollSettingsService.number(
      _governmentCompliance,
      'philHealth',
    );
  }

  double get _fixedPagIbig {
    return PayrollSettingsService.number(
      _governmentCompliance,
      'pagIbig',
    );
  }

  double get _fixedWithholdingTax {
    return PayrollSettingsService.number(
      _governmentCompliance,
      'withholdingTax',
    );
  }

  double get _governmentComplianceTotal {
    return PayrollSettingsService
        .governmentComplianceTotal(
      _governmentCompliance,
    );
  }

  double get _defaultHourlyRate {
    switch (_salaryType) {
      case 'daily':
        return _salaryRate /
            _requiredHoursPerDay;

      case 'hourly':
        return _salaryRate;

      default:
        return _salaryRate /
            _workingDaysPerMonth /
            _requiredHoursPerDay;
    }
  }

  double get _dailyRate {
    switch (_salaryType) {
      case 'daily':
        return _salaryRate;

      case 'hourly':
        return _salaryRate *
            _requiredHoursPerDay;

      default:
        return _salaryRate /
            _workingDaysPerMonth;
    }
  }

  double get _basicPay {
    switch (_salaryType) {
      case 'daily':
        return _salaryRate * _daysWorked;

      case 'hourly':
        return _salaryRate * _regularHours;

      default:
        return _dailyRate * _daysWorked;
    }
  }

  double get _ordinaryOvertimeRate {
    return _defaultHourlyRate *
        _ordinaryOvertimeMultiplier;
  }

  double get _holidayOvertimeHours {
    return _holidaySummary.holidayOvertimeHours;
  }

  double get _ordinaryOvertimeHours {
    return math.max(
      0,
      _totalAttendanceOvertimeHours -
          _holidayOvertimeHours,
    );
  }

  double get _ordinaryOvertimePay {
    return _ordinaryOvertimeHours *
        _ordinaryOvertimeRate;
  }

  double get _holidayOvertimePay {
    return _holidaySummary.holidayOvertimePay;
  }

  double get _overtimePay {
    return _ordinaryOvertimePay +
        _holidayOvertimePay;
  }

  double get _holidayPay {
    return _holidaySummary.holidayPay;
  }

  double get _grossPay {
    return _basicPay +
        _overtimePay +
        _holidayPay +
        _allowances;
  }

  double get _nonGovernmentDeductions {
    return _loanDeduction +
        _cashAdvance +
        _miscellaneousDeduction;
  }

  double get _otherDeductions {
    return _governmentComplianceTotal +
        _nonGovernmentDeductions;
  }

  double get _totalDeductions {
    return _otherDeductions;
  }

  double get _netPay {
    return _grossPay - _totalDeductions;
  }

  // ============================================================
  // DATE SELECTION
  // ============================================================

  Future<void> _selectPeriodStart() async {
    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate: _periodStart,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(days: 730),
      ),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _periodStart = selected;

      if (_periodEnd.isBefore(_periodStart)) {
        _periodEnd = selected;
      }
    });

    await _loadAttendanceAndHolidays();
  }

  Future<void> _selectPeriodEnd() async {
    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate:
          _periodEnd.isBefore(_periodStart)
              ? _periodStart
              : _periodEnd,
      firstDate: _periodStart,
      lastDate: DateTime.now().add(
        const Duration(days: 730),
      ),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _periodEnd = selected;
    });

    await _loadAttendanceAndHolidays();
  }

  // ============================================================
  // SAVE WORKFLOW
  // ============================================================

  Future<void> _savePayroll({
    required bool submitForApproval,
  }) async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_periodEnd.isBefore(_periodStart)) {
      _showMessage(
        'The payroll end date cannot be earlier '
        'than the start date.',
        isError: true,
      );
      return;
    }

    if (_netPay < 0) {
      _showMessage(
        'Total deductions cannot exceed gross pay.',
        isError: true,
      );
      return;
    }

    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage(
        'Your login session has expired.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Refresh every value immediately before writing.
      final List<Map<String, dynamic>>
          latestSettings =
          await Future.wait<
              Map<String, dynamic>>([
        PayrollSettingsService
            .loadGovernmentCompliance(),
        PayrollSettingsService
            .loadHolidayRules(),
      ]);

      _governmentCompliance =
          latestSettings[0];

      _holidayRules = latestSettings[1];

      await _loadAttendanceAndHolidays(
        showProgress: false,
      );

      final Map<String, dynamic>
          currentUserSnapshot =
          await _loadCurrentUserSnapshot();

      final String payrollId =
          '${widget.employeeId}_'
          '${_compactDate(_periodStart)}_'
          '${_compactDate(_periodEnd)}';

      final String payslipId =
          'ps_$payrollId';

      final DocumentReference<
              Map<String, dynamic>>
          employeeReference =
          FirebaseFirestore.instance
              .collection('employee')
              .doc(widget.employeeId);

      final DocumentReference<
              Map<String, dynamic>>
          payrollReference =
          FirebaseFirestore.instance
              .collection('payroll')
              .doc(payrollId);

      final DocumentReference<
              Map<String, dynamic>>
          payslipReference =
          FirebaseFirestore.instance
              .collection('payslips')
              .doc(payslipId);

      final List<
              DocumentSnapshot<
                  Map<String, dynamic>>>
          existingDocuments =
          await Future.wait<
              DocumentSnapshot<
                  Map<String, dynamic>>>([
        payrollReference.get(),
        payslipReference.get(),
      ]);

      final DocumentSnapshot<
              Map<String, dynamic>>
          existingPayroll =
          existingDocuments[0];

      final DocumentSnapshot<
              Map<String, dynamic>>
          existingPayslip =
          existingDocuments[1];

      final String existingPayrollStatus =
          existingPayroll
                  .data()?['status']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      final String existingPayslipStatus =
          existingPayslip
                  .data()?['status']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      const Set<String> lockedStatuses =
          <String>{
        'pending_approval',
        'approved',
        'released',
      };

      if (lockedStatuses.contains(
            existingPayrollStatus,
          ) ||
          lockedStatuses.contains(
            existingPayslipStatus,
          )) {
        throw StateError(
          'This payroll has already been submitted '
          'and can no longer be edited.',
        );
      }

      final String targetStatus =
          submitForApproval
              ? 'pending_approval'
              : 'draft';

      final Map<String, dynamic>
          governmentComplianceSnapshot =
          <String, dynamic>{
        'settingsReference':
            PayrollSettingsService
                .governmentComplianceReference,
        'mode':
            _governmentCompliance['mode'] ??
                'fixed',
        'fixedForAllEmployees':
            _governmentCompliance[
                    'fixedForAllEmployees'] !=
                false,
        'version':
            _governmentCompliance['version'] ??
                1,
        'sss': _round(_fixedSss),
        'philHealth':
            _round(_fixedPhilHealth),
        'pagIbig':
            _round(_fixedPagIbig),
        'withholdingTax':
            _round(_fixedWithholdingTax),
        'total': _round(
          _governmentComplianceTotal,
        ),
      };

      final Map<String, dynamic>
          holidayRulesSnapshot =
          <String, dynamic>{
        'settingsReference':
            PayrollSettingsService
                .holidayRulesReference,
        'version':
            _holidayRules['version'] ?? 1,
        ..._holidayRules,
      };

      final Map<String, dynamic>
          attendanceSummaryMap =
          <String, dynamic>{
        'ordinaryDaysWorked':
            _round(_daysWorked),
        'ordinaryRegularHours':
            _round(_regularHours),
        'totalAttendanceOvertimeHours':
            _round(
          _totalAttendanceOvertimeHours,
        ),
        'ordinaryOvertimeHours':
            _round(_ordinaryOvertimeHours),
        'holidayOvertimeHours':
            _round(_holidayOvertimeHours),
        'lateMinutes': _round(
          _attendanceSummary?.lateMinutes ??
              0,
        ),
        'undertimeMinutes': _round(
          _attendanceSummary
                  ?.undertimeMinutes ??
              0,
        ),
        'attendanceCount':
            _attendanceSummary
                    ?.attendanceCount ??
                0,
      };

      final Map<String, dynamic>
          earningsBreakdown =
          <String, dynamic>{
        'dailyRate': _round(_dailyRate),
        'hourlyRate':
            _round(_defaultHourlyRate),
        'basicPay': _round(_basicPay),
        'ordinaryOvertimePay':
            _round(_ordinaryOvertimePay),
        'holidayOvertimePay':
            _round(_holidayOvertimePay),
        'overtimePay':
            _round(_overtimePay),
        'holidayPay':
            _round(_holidayPay),
        'allowances':
            _round(_allowances),
        'grossPay': _round(_grossPay),
      };

      final Map<String, dynamic>
          deductionBreakdown =
          <String, dynamic>{
        'sss': _round(_fixedSss),
        'philHealth':
            _round(_fixedPhilHealth),
        'pagIbig':
            _round(_fixedPagIbig),
        'withholdingTax':
            _round(_fixedWithholdingTax),
        'loan':
            _round(_loanDeduction),
        'cashAdvance':
            _round(_cashAdvance),
        'miscellaneous':
            _round(
          _miscellaneousDeduction,
        ),
      };

      final Map<String, dynamic> payrollData =
          <String, dynamic>{
        'payrollType': 'regular',
        'payrollYear': _periodEnd.year,

        'employeeId': employeeReference,
        'employeeName': _fullName,
        'position': _position,

        'payrollPeriodStart':
            Timestamp.fromDate(
          DateTime(
            _periodStart.year,
            _periodStart.month,
            _periodStart.day,
          ),
        ),

        'payrollPeriodEnd':
            Timestamp.fromDate(
          DateTime(
            _periodEnd.year,
            _periodEnd.month,
            _periodEnd.day,
          ),
        ),

        'salaryType': _salaryType,
        'salaryRate':
            _round(_salaryRate),

        'workingDaysPerMonth':
            _round(_workingDaysPerMonth),

        'requiredHoursPerDay':
            _round(_requiredHoursPerDay),

        'ordinaryOvertimeMultiplier':
            _round(
          _ordinaryOvertimeMultiplier,
        ),

        'attendanceSummary':
            attendanceSummaryMap,

        'attendanceBreakdown':
            _attendanceBreakdown,

        'overtimeSource': 'attendance',

        'overtimeBreakdown':
            _buildFinalOvertimeBreakdown(),

        'daysWorked':
            _round(_daysWorked),

        'regularHours':
            _round(_regularHours),

        'dailyRate': _round(_dailyRate),

        'hourlyRate':
            _round(_defaultHourlyRate),

        'basicPay': _round(_basicPay),

        'overtimeHours': _round(
          _totalAttendanceOvertimeHours,
        ),

        'ordinaryOvertimeHours':
            _round(_ordinaryOvertimeHours),

        'holidayOvertimeHours':
            _round(_holidayOvertimeHours),

        'overtimeRate':
            _round(_ordinaryOvertimeRate),

        'ordinaryOvertimePay':
            _round(_ordinaryOvertimePay),

        'holidayOvertimePay':
            _round(_holidayOvertimePay),

        'overtimePay':
            _round(_overtimePay),

        'holidayCount':
            _holidaySummary.entries.length,

        'workedHolidayCount':
            _holidaySummary
                .workedPremiumDayCount,

        'holidayPay':
            _round(_holidayPay),

        'holidayPayBreakdown':
            _holidaySummary.toBreakdown(),

        'holidayRulesSnapshot':
            holidayRulesSnapshot,

        'holidayRulesSettingsRef':
            PayrollSettingsService
                .holidayRulesReference,

        'allowances':
            _round(_allowances),

        'earningsBreakdown':
            earningsBreakdown,

        'grossPay': _round(_grossPay),

        'sssContribution':
            _round(_fixedSss),

        'philHealthContribution':
            _round(_fixedPhilHealth),

        'pagIbigContribution':
            _round(_fixedPagIbig),

        'withholdingTax':
            _round(_fixedWithholdingTax),

        'governmentComplianceTotal':
            _round(
          _governmentComplianceTotal,
        ),

        'governmentComplianceSnapshot':
            governmentComplianceSnapshot,

        'governmentComplianceSettingsRef':
            PayrollSettingsService
                .governmentComplianceReference,

        'loanDeduction':
            _round(_loanDeduction),

        'cashAdvance':
            _round(_cashAdvance),

        'miscellaneousDeduction':
            _round(
          _miscellaneousDeduction,
        ),

        'deductionBreakdown':
            deductionBreakdown,

        'otherDeductions':
            _round(_otherDeductions),

        'totalDeductions':
            _round(_totalDeductions),

        'netPay': _round(_netPay),

        'status': targetStatus,

        'submittedForApproval':
            submitForApproval,

        'preparedBy':
            currentUserSnapshot,

        'preparedAt':
            FieldValue.serverTimestamp(),

        'updatedAt':
            FieldValue.serverTimestamp(),

        if (submitForApproval)
          'generatedBy':
              currentUserSnapshot,

        if (submitForApproval)
          'generatedAt':
              FieldValue.serverTimestamp(),

        if (submitForApproval)
          'submittedAt':
              FieldValue.serverTimestamp(),
      };

      final WriteBatch batch =
          FirebaseFirestore.instance.batch();

      batch.set(
        payrollReference,
        <String, dynamic>{
          ...payrollData,
          if (!existingPayroll.exists)
            'createdAt':
                FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Saving a draft creates only a payroll document.
      // A payslip is created only after submission.
      if (submitForApproval) {
        batch.set(
          payslipReference,
          <String, dynamic>{
            ...payrollData,
            'payrollId':
                payrollReference,
            'status':
                'pending_approval',
            'generatedBy':
                currentUserSnapshot,
            'generatedAt':
                FieldValue.serverTimestamp(),
            'approvedBy': null,
            'approvedAt': null,
            'approvalRemarks': null,
            if (!existingPayslip.exists)
              'createdAt':
                  FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (!mounted) {
        return;
      }

      _showMessage(
        submitForApproval
            ? 'Payroll saved and submitted '
                'for approval.'
            : 'Payroll saved as draft.',
        isError: false,
      );

      if (submitForApproval) {
        Navigator.of(context).pop();
      }
    } on FirebaseException catch (error) {
      _showMessage(
        error.message ??
            'Unable to save payroll.',
        isError: true,
      );
    } catch (error) {
      _showMessage(
        'Unable to save payroll: $error',
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

  Future<Map<String, dynamic>>
      _loadCurrentUserSnapshot() async {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'Your login session has expired.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>>
        userDocument =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    final Map<String, dynamic> userData =
        userDocument.data() ??
            <String, dynamic>{};

    return <String, dynamic>{
      'uid': user.uid,
      'fullName':
          userData['fullName']
                  ?.toString() ??
              user.displayName ??
              'Unknown user',
      'email':
          userData['email']
                  ?.toString() ??
              user.email ??
              '',
      'role':
          userData['userRole']
                  ?.toString() ??
              userData['role']
                  ?.toString() ??
              'hr',
    };
  }

  List<Map<String, dynamic>>
      _buildFinalOvertimeBreakdown() {
    final Map<String, HolidayPayrollEntry>
        holidayByDate =
        <String, HolidayPayrollEntry>{
      for (final HolidayPayrollEntry entry
          in _holidaySummary.entries)
        HolidayPayrollService.dateKey(
          entry.holidayDate,
        ): entry,
    };

    return _overtimeBreakdown.map(
      (Map<String, dynamic> overtime) {
        final DateTime? date =
            _dateFromValue(
          overtime['attendanceDate'],
        );

        final HolidayPayrollEntry? holiday =
            date == null
                ? null
                : holidayByDate[
                    HolidayPayrollService
                        .dateKey(date)];

        final double hours = _readNumber(
          overtime['overtimeHours'],
        );

        if (holiday != null &&
            holiday.holidayType !=
                'special_working_day') {
          return <String, dynamic>{
            ...overtime,
            'dayType':
                holiday.holidayType,
            'baseHourlyRate':
                _round(_defaultHourlyRate),
            'multiplier':
                _round(
              holiday.overtimeMultiplier,
            ),
            'overtimePay': _round(
              holiday.holidayOvertimePay,
            ),
          };
        }

        return <String, dynamic>{
          ...overtime,
          'dayType': 'ordinary',
          'baseHourlyRate':
              _round(_defaultHourlyRate),
          'multiplier': _round(
            _ordinaryOvertimeMultiplier,
          ),
          'overtimePay': _round(
            hours *
                _defaultHourlyRate *
                _ordinaryOvertimeMultiplier,
          ),
        };
      },
    ).toList();
  }

  double _calculateOrdinaryDaysWorked(
    List<Map<String, dynamic>>
        attendanceBreakdown,
    Set<String> premiumDateKeys,
  ) {
    double total = 0;

    for (final Map<String, dynamic> attendance
        in attendanceBreakdown) {
      if (attendance['worked'] != true) {
        continue;
      }

      final DateTime? date = _dateFromValue(
        attendance['attendanceDate'],
      );

      if (date == null) {
        continue;
      }

      if (!premiumDateKeys.contains(
        HolidayPayrollService.dateKey(date),
      )) {
        total += 1;
      }
    }

    return _round(total);
  }

  double _calculateOrdinaryRegularHours(
    List<Map<String, dynamic>>
        attendanceBreakdown,
    Set<String> premiumDateKeys,
  ) {
    double total = 0;

    for (final Map<String, dynamic> attendance
        in attendanceBreakdown) {
      if (attendance['worked'] != true) {
        continue;
      }

      final DateTime? date = _dateFromValue(
        attendance['attendanceDate'],
      );

      if (date == null ||
          premiumDateKeys.contains(
            HolidayPayrollService.dateKey(
              date,
            ),
          )) {
        continue;
      }

      final double workHours =
          _readNumber(
        attendance['totalWorkHours'],
      );

      final double overtimeHours =
          _readNumber(
        attendance['overtimeHours'],
      );

      total += math.min(
        8,
        math.max(
          0,
          workHours - overtimeHours,
        ),
      );
    }

    return _round(total);
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
          behavior:
              SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFD92D20)
              : const Color(0xFF039855),
        ),
      );
  }

  // ============================================================
  // USER INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Run Payroll'),
        backgroundColor:
            const Color(0xFFF04B0B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          _buildEmployeeHeader(),

          const SizedBox(height: 22),

          _buildSectionTitle(
            icon:
                Icons.calendar_month_outlined,
            title: 'Payroll Period',
          ),

          const SizedBox(height: 13),

          Row(
            children: <Widget>[
              Expanded(
                child: _buildDateField(
                  label: 'Start Date',
                  value: _periodStart,
                  onTap: _selectPeriodStart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(
                  label: 'End Date',
                  value: _periodEnd,
                  onTap: _selectPeriodEnd,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildAttendanceSection(),

          const SizedBox(height: 24),

          _buildSectionTitle(
            icon: Icons.payments_outlined,
            title: 'Other Earnings',
          ),

          const SizedBox(height: 13),

          _buildNumberField(
            controller:
                _allowancesController,
            label: 'Allowances',
            icon: Icons.add_card_outlined,
            prefixText: 'PHP ',
          ),

          const SizedBox(height: 24),

          _buildHolidaySection(),

          const SizedBox(height: 24),

          _buildGovernmentComplianceSection(),

          const SizedBox(height: 24),

          _buildSectionTitle(
            icon:
                Icons.receipt_long_outlined,
            title:
                'Other Employee Deductions',
          ),

          const SizedBox(height: 6),

          const Text(
            'These values may be different '
            'for each employee.',
            style: TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 13),

          _buildNumberField(
            controller: _loanController,
            label: 'Loan Deduction',
            icon:
                Icons.credit_score_outlined,
            prefixText: 'PHP ',
          ),

          const SizedBox(height: 13),

          _buildNumberField(
            controller:
                _cashAdvanceController,
            label: 'Cash Advance',
            icon: Icons.money_off_outlined,
            prefixText: 'PHP ',
          ),

          const SizedBox(height: 13),

          _buildNumberField(
            controller:
                _miscellaneousController,
            label:
                'Miscellaneous Deduction',
            icon:
                Icons.remove_circle_outline,
            prefixText: 'PHP ',
          ),

          const SizedBox(height: 24),

          _buildPayrollSummary(),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: _isSaving
                ? null
                : () {
                    _savePayroll(
                      submitForApproval: false,
                    );
                  },
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  const Color(0xFFF04B0B),
              minimumSize:
                  const Size.fromHeight(53),
              side: const BorderSide(
                color: Color(0xFFF04B0B),
              ),
            ),
            icon: const Icon(
              Icons.save_outlined,
            ),
            label: const Text(
              'Save as Draft',
            ),
          ),

          const SizedBox(height: 11),

          FilledButton.icon(
            onPressed: _isSaving
                ? null
                : () {
                    _savePayroll(
                      submitForApproval: true,
                    );
                  },
            style: FilledButton.styleFrom(
              backgroundColor:
                  const Color(0xFFF04B0B),
              foregroundColor: Colors.white,
              minimumSize:
                  const Size.fromHeight(53),
            ),
            icon: _isSaving
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
              _isSaving
                  ? 'Saving...'
                  : 'Save and Submit for Approval',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSection() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.schedule_outlined,
                color: Color(0xFF1F5CF5),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Attendance Computation',
                  style: TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed:
                    _isRefreshingAttendance
                        ? null
                        : () {
                            _loadAttendanceAndHolidays();
                          },
                tooltip:
                    'Reload attendance and holidays',
                icon:
                    _isRefreshingAttendance
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.refresh,
                          ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          const Text(
            'Days, hours, and overtime are '
            'loaded automatically from Firestore.',
            style: TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 14),

          _buildReadOnlyField(
            controller:
                _daysWorkedController,
            label: 'Ordinary Days Worked',
            helperText:
                'Worked holidays are excluded '
                'to prevent double counting.',
            icon:
                Icons.work_history_outlined,
          ),

          const SizedBox(height: 12),

          _buildReadOnlyField(
            controller:
                _regularHoursController,
            label: 'Ordinary Regular Hours',
            icon: Icons.access_time_outlined,
          ),

          const SizedBox(height: 12),

          _buildReadOnlyField(
            controller:
                _overtimeHoursController,
            label: 'Total Overtime Hours',
            helperText:
                'Automatically summed from '
                'attendance records.',
            icon: Icons.more_time_outlined,
          ),

          const SizedBox(height: 12),

          _buildReadOnlyField(
            controller:
                _overtimeRateController,
            label:
                'Ordinary Overtime Rate',
            icon:
                Icons.price_change_outlined,
            prefixText: 'PHP ',
          ),

          const SizedBox(height: 12),

          _buildReadOnlyCalculationRow(
            label: 'Ordinary OT Hours',
            value: _ordinaryOvertimeHours
                .toStringAsFixed(2),
          ),

          _buildReadOnlyCalculationRow(
            label: 'Holiday OT Hours',
            value: _holidayOvertimeHours
                .toStringAsFixed(2),
          ),

          _buildReadOnlyCalculationRow(
            label: 'Late Minutes',
            value:
                '${_attendanceSummary?.lateMinutes.toStringAsFixed(0) ?? '0'} min',
          ),

          _buildReadOnlyCalculationRow(
            label: 'Undertime Minutes',
            value:
                '${_attendanceSummary?.undertimeMinutes.toStringAsFixed(0) ?? '0'} min',
          ),
        ],
      ),
    );
  }

  Widget _buildHolidaySection() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFDDBD),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.celebration_outlined,
                color: Color(0xFFF04B0B),
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Detected Holidays',
                  style: TextStyle(
                    color: Color(0xFF9E3D00),
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          const Text(
            'Every holiday inside the payroll '
            'period is matched to attendance.',
            style: TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 14),

          if (_holidaySummary.entries.isEmpty)
            const _InformationMessage(
              icon:
                  Icons.event_busy_outlined,
              message:
                  'No holiday records were found '
                  'for this payroll period.',
            )
          else
            ..._holidaySummary.entries.map(
              _buildHolidayCard,
            ),

          const Divider(height: 24),

          _buildReadOnlyCalculationRow(
            label: 'Holiday Pay',
            value: _money(_holidayPay),
            bold: true,
          ),

          _buildReadOnlyCalculationRow(
            label: 'Holiday Overtime Pay',
            value:
                _money(_holidayOvertimePay),
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayCard(
    HolidayPayrollEntry entry,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFDDBD),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  entry.holidayName,
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: entry.worked
                      ? const Color(0xFFECFDF3)
                      : const Color(0xFFF2F4F7),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Text(
                  entry.worked
                      ? 'Worked'
                      : 'Not worked',
                  style: TextStyle(
                    color: entry.worked
                        ? const Color(0xFF027A48)
                        : const Color(0xFF667085),
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          Text(
            '${_formatDate(entry.holidayDate)} • '
            '${_formatLabel(entry.holidayType)}',
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 9),

          _buildReadOnlyCalculationRow(
            label: 'Regular Hours',
            value:
                entry.regularHours.toStringAsFixed(2),
          ),

          _buildReadOnlyCalculationRow(
            label: 'Multiplier',
            value:
                '${entry.multiplier.toStringAsFixed(2)}x',
          ),

          _buildReadOnlyCalculationRow(
            label: 'Holiday Pay',
            value: _money(entry.holidayPay),
          ),

          if (entry.overtimeHours > 0) ...<Widget>[
            _buildReadOnlyCalculationRow(
              label: 'Holiday OT Hours',
              value: entry.overtimeHours
                  .toStringAsFixed(2),
            ),
            _buildReadOnlyCalculationRow(
              label: 'Holiday OT Multiplier',
              value:
                  '${entry.overtimeMultiplier.toStringAsFixed(2)}x',
            ),
            _buildReadOnlyCalculationRow(
              label: 'Holiday OT Pay',
              value: _money(
                entry.holidayOvertimePay,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGovernmentComplianceSection() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD2E2FF),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.account_balance_outlined,
                color: Color(0xFF1F5CF5),
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Fixed Government Compliance',
                  style: TextStyle(
                    color: Color(0xFF1849A9),
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.lock_outline,
                color: Color(0xFF1F5CF5),
                size: 20,
              ),
            ],
          ),

          const SizedBox(height: 6),

          const Text(
            'Loaded from Firebase and applied '
            'equally to every employee.',
            style: TextStyle(
              color: Color(0xFF475467),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 16),

          _buildFixedDeductionRow(
            label: 'SSS',
            value: _fixedSss,
          ),

          _buildFixedDeductionRow(
            label: 'PhilHealth',
            value: _fixedPhilHealth,
          ),

          _buildFixedDeductionRow(
            label: 'Pag-IBIG',
            value: _fixedPagIbig,
          ),

          _buildFixedDeductionRow(
            label: 'Withholding Tax',
            value: _fixedWithholdingTax,
          ),

          const Divider(height: 24),

          _buildFixedDeductionRow(
            label:
                'Government Compliance Total',
            value:
                _governmentComplianceTotal,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        children: <Widget>[
          _buildSummaryRow(
            label: 'Basic Pay',
            value: _basicPay,
          ),

          _buildSummaryRow(
            label: 'Ordinary Overtime Pay',
            value: _ordinaryOvertimePay,
          ),

          _buildSummaryRow(
            label: 'Holiday Overtime Pay',
            value: _holidayOvertimePay,
          ),

          _buildSummaryRow(
            label: 'Holiday Pay',
            value: _holidayPay,
          ),

          _buildSummaryRow(
            label: 'Allowances',
            value: _allowances,
          ),

          const Divider(height: 24),

          _buildSummaryRow(
            label: 'Gross Pay',
            value: _grossPay,
            bold: true,
          ),

          _buildSummaryRow(
            label:
                'Government Compliance',
            value:
                _governmentComplianceTotal,
            negative: true,
          ),

          _buildSummaryRow(
            label:
                'Other Employee Deductions',
            value:
                _nonGovernmentDeductions,
            negative: true,
          ),

          const Divider(height: 24),

          _buildSummaryRow(
            label: 'Net Pay',
            value: _netPay,
            bold: true,
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
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
            mainAxisSize:
                MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                color: Color(0xFFD92D20),
                size: 60,
              ),
              const SizedBox(height: 14),
              const Text(
                'Unable to Load Payroll',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 19,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed:
                    _loadEmployeeAndSettings,
                icon:
                    const Icon(Icons.refresh),
                label:
                    const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeHeader() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Row(
        children: <Widget>[
          const CircleAvatar(
            radius: 28,
            backgroundColor:
                Color(0xFFFFF1EA),
            child: Icon(
              Icons.person_outline,
              color: Color(0xFFF04B0B),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _fullName,
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${widget.employeeId.toUpperCase()} '
                  '• $_position',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Salary: ${_money(_salaryRate)} '
                  '(${_salaryType.toUpperCase()})',
                  style: const TextStyle(
                    color: Color(0xFFF04B0B),
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedDeductionRow({
    required String label,
    required double value,
    bool bold = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color:
                    const Color(0xFF344054),
                fontWeight: bold
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
          Text(
            _money(value),
            style: TextStyle(
              color:
                  const Color(0xFF1849A9),
              fontWeight: bold
                  ? FontWeight.w800
                  : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyCalculationRow({
    required String label,
    required String value,
    bool bold = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color:
                    const Color(0xFF475467),
                fontWeight: bold
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color:
                  const Color(0xFF101828),
              fontWeight: bold
                  ? FontWeight.w800
                  : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required double value,
    bool negative = false,
    bool bold = false,
    bool highlight = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: highlight
                    ? const Color(
                        0xFFF04B0B,
                      )
                    : const Color(
                        0xFF475467,
                      ),
                fontWeight: bold
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${negative ? '- ' : ''}'
            '${_money(value)}',
            style: TextStyle(
              color: highlight
                  ? const Color(
                      0xFFF04B0B,
                    )
                  : const Color(
                      0xFF101828,
                    ),
              fontSize:
                  highlight ? 19 : 14,
              fontWeight: bold
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController
        controller,
    required String label,
    required IconData icon,
    String? prefixText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType:
          const TextInputType
              .numberWithOptions(
        decimal: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        prefixText: prefixText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
      ),
      validator: (String? value) {
        final double? number =
            double.tryParse(
          value?.trim() ?? '',
        );

        if (number == null || number < 0) {
          return 'Enter a valid '
              'non-negative number.';
        }

        return null;
      },
    );
  }

  Widget _buildReadOnlyField({
    required TextEditingController
        controller,
    required String label,
    required IconData icon,
    String? helperText,
    String? prefixText,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon),
        prefixText: prefixText,
        filled: true,
        fillColor:
            const Color(0xFFF2F4F7),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(
            Icons.calendar_today_outlined,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _formatDate(value),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: <Widget>[
        Icon(
          icon,
          color: const Color(0xFFF04B0B),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF101828),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  double _controllerNumber(
    TextEditingController controller,
  ) {
    return double.tryParse(
          controller.text.trim(),
        ) ??
        0;
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

  double _round(double value) {
    return double.parse(
      value.toStringAsFixed(2),
    );
  }

  DateTime? _dateFromValue(
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

  String _compactDate(DateTime date) {
    final String month = date.month
        .toString()
        .padLeft(2, '0');

    final String day = date.day
        .toString()
        .padLeft(2, '0');

    return '${date.year}$month$day';
  }

  String _formatDate(DateTime date) {
    const List<String> months =
        <String>[
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
    return value
        .split('_')
        .where(
          (String word) => word.isNotEmpty,
        )
        .map(
          (String word) =>
              '${word[0].toUpperCase()}'
              '${word.substring(1)}',
        )
        .join(' ');
  }

  String _money(double value) {
    return 'PHP ${value.toStringAsFixed(2)}';
  }
}

class _InformationMessage
    extends StatelessWidget {
  const _InformationMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            icon,
            color: const Color(0xFF98A2B3),
            size: 36,
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
    );
  }
}
