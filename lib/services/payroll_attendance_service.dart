import 'package:cloud_firestore/cloud_firestore.dart';

class PayrollAttendanceSummary {
  const PayrollAttendanceSummary({
    required this.daysWorked,
    required this.regularHours,
    required this.overtimeHours,
    required this.overtimeMinutes,
    required this.lateMinutes,
    required this.undertimeMinutes,
    required this.attendanceCount,
    required this.overtimeBreakdown,
    required this.attendanceBreakdown,
  });

  final double daysWorked;
  final double regularHours;

  final double overtimeHours;
  final double overtimeMinutes;

  final double lateMinutes;
  final double undertimeMinutes;

  final int attendanceCount;

  final List<Map<String, dynamic>> overtimeBreakdown;
  final List<Map<String, dynamic>> attendanceBreakdown;

  Map<String, dynamic> toMap() {
    return {
      'daysWorked': daysWorked,
      'regularHours': regularHours,
      'overtimeHours': overtimeHours,
      'overtimeMinutes': overtimeMinutes,
      'lateMinutes': lateMinutes,
      'undertimeMinutes': undertimeMinutes,
      'attendanceCount': attendanceCount,
      'overtimeBreakdown': overtimeBreakdown,
      'attendanceBreakdown': attendanceBreakdown,
    };
  }
}

class PayrollAttendanceService {
  const PayrollAttendanceService._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  /// Loads attendance records for one employee within
  /// the selected payroll period.
  ///
  /// The employeeId field in Firestore is expected to be:
  ///
  /// employeeId: /employee/{employeeDocumentId}
  ///
  /// The service automatically computes:
  /// - days worked
  /// - total work hours
  /// - total overtime
  /// - total late minutes
  /// - total undertime minutes
  /// - overtime breakdown per attendance record
  static Future<PayrollAttendanceSummary> load({
    required String employeeId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final DateTime normalizedStart = DateTime(
      periodStart.year,
      periodStart.month,
      periodStart.day,
    );

    final DateTime normalizedEndExclusive = DateTime(
      periodEnd.year,
      periodEnd.month,
      periodEnd.day,
    ).add(
      const Duration(days: 1),
    );

    if (!normalizedEndExclusive.isAfter(
      normalizedStart,
    )) {
      throw ArgumentError(
        'Payroll end date must not be earlier '
        'than the start date.',
      );
    }

    final DocumentReference<Map<String, dynamic>>
        employeeReference = _firestore
            .collection('employee')
            .doc(employeeId);

    final List<QueryDocumentSnapshot<
            Map<String, dynamic>>>
        attendanceDocuments =
        await _loadAttendanceDocuments(
      employeeReference: employeeReference,
      employeeId: employeeId,
      periodStart: normalizedStart,
      periodEndExclusive:
          normalizedEndExclusive,
    );

    double daysWorked = 0;
    double regularHours = 0;

    double overtimeHours = 0;
    double overtimeMinutes = 0;

    double lateMinutes = 0;
    double undertimeMinutes = 0;

    final List<Map<String, dynamic>>
        overtimeBreakdown = [];

    final List<Map<String, dynamic>>
        attendanceBreakdown = [];

    for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        document in attendanceDocuments) {
      final Map<String, dynamic> data =
          document.data();

      final DateTime? attendanceDate =
          _dateFromValue(
        data['attendanceDate'],
      );

      if (attendanceDate == null) {
        continue;
      }

      final String status = data['status']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

      final bool worked =
          _isWorkedAttendance(
        status: status,
        data: data,
      );

      final double recordWorkHours =
          _number(
        data['totalWorkHours'],
      );

      final double recordLateMinutes =
          _number(
        data['lateMinutes'],
      );

      final double recordUndertimeMinutes =
          _number(
        data['undertimeMinutes'],
      );

      final double recordOvertimeHours =
          _readOvertimeHours(data);

      final double recordOvertimeMinutes =
          recordOvertimeHours * 60;

      if (worked) {
        daysWorked += 1;
      }

      regularHours += recordWorkHours;
      overtimeHours += recordOvertimeHours;
      overtimeMinutes += recordOvertimeMinutes;
      lateMinutes += recordLateMinutes;
      undertimeMinutes +=
          recordUndertimeMinutes;

      final Map<String, dynamic>
          attendanceEntry = {
        'attendanceId':
            document.reference,
        'attendanceDocumentId':
            document.id,
        'attendanceDate':
            Timestamp.fromDate(
          DateTime(
            attendanceDate.year,
            attendanceDate.month,
            attendanceDate.day,
          ),
        ),
        'status': status,
        'worked': worked,
        'timeIn': data['timeIn'],
        'timeOut': data['timeOut'],
        'totalWorkHours':
            _round(recordWorkHours),
        'lateMinutes':
            _round(recordLateMinutes),
        'undertimeMinutes':
            _round(recordUndertimeMinutes),
        'overtimeHours':
            _round(recordOvertimeHours),
        'overtimeMinutes':
            _round(recordOvertimeMinutes),
        'faceVerified':
            data['faceVerified'] == true,
        'verificationMethod':
            data['verificationMethod']
                    ?.toString() ??
                'legacy',
      };

      attendanceBreakdown.add(
        attendanceEntry,
      );

      if (recordOvertimeHours > 0) {
        overtimeBreakdown.add({
          'attendanceId':
              document.reference,
          'attendanceDocumentId':
              document.id,
          'attendanceDate':
              Timestamp.fromDate(
            DateTime(
              attendanceDate.year,
              attendanceDate.month,
              attendanceDate.day,
            ),
          ),
          'overtimeHours':
              _round(recordOvertimeHours),
          'overtimeMinutes':
              _round(recordOvertimeMinutes),

          // The Run Payroll screen can update these
          // after matching this date with a holiday.
          'dayType': 'ordinary',
          'multiplier': 1.25,
          'baseHourlyRate': 0.0,
          'overtimePay': 0.0,
        });
      }
    }

    attendanceBreakdown.sort(
      (
        Map<String, dynamic> first,
        Map<String, dynamic> second,
      ) {
        final DateTime firstDate =
            _dateFromValue(
                  first['attendanceDate'],
                ) ??
                DateTime(2000);

        final DateTime secondDate =
            _dateFromValue(
                  second['attendanceDate'],
                ) ??
                DateTime(2000);

        return firstDate.compareTo(
          secondDate,
        );
      },
    );

    overtimeBreakdown.sort(
      (
        Map<String, dynamic> first,
        Map<String, dynamic> second,
      ) {
        final DateTime firstDate =
            _dateFromValue(
                  first['attendanceDate'],
                ) ??
                DateTime(2000);

        final DateTime secondDate =
            _dateFromValue(
                  second['attendanceDate'],
                ) ??
                DateTime(2000);

        return firstDate.compareTo(
          secondDate,
        );
      },
    );

    return PayrollAttendanceSummary(
      daysWorked: _round(daysWorked),
      regularHours: _round(regularHours),
      overtimeHours:
          _round(overtimeHours),
      overtimeMinutes:
          _round(overtimeMinutes),
      lateMinutes: _round(lateMinutes),
      undertimeMinutes:
          _round(undertimeMinutes),
      attendanceCount:
          attendanceDocuments.length,
      overtimeBreakdown:
          overtimeBreakdown,
      attendanceBreakdown:
          attendanceBreakdown,
    );
  }

  /// Attempts the efficient date-range query first.
  ///
  /// If Firestore requires a composite index, it falls
  /// back to loading the employee attendance records and
  /// filtering the dates in Dart.
  static Future<
      List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>>
      _loadAttendanceDocuments({
    required DocumentReference<Map<String, dynamic>>
        employeeReference,
    required String employeeId,
    required DateTime periodStart,
    required DateTime periodEndExclusive,
  }) async {
    try {
      final QuerySnapshot<Map<String, dynamic>>
          snapshot = await _firestore
              .collection('attendance')
              .where(
                'employeeId',
                isEqualTo: employeeReference,
              )
              .where(
                'attendanceDate',
                isGreaterThanOrEqualTo:
                    Timestamp.fromDate(
                  periodStart,
                ),
              )
              .where(
                'attendanceDate',
                isLessThan:
                    Timestamp.fromDate(
                  periodEndExclusive,
                ),
              )
              .get();

      return snapshot.docs;
    } on FirebaseException catch (error) {
      if (error.code != 'failed-precondition') {
        rethrow;
      }

      return _loadWithClientDateFilter(
        employeeReference:
            employeeReference,
        employeeId: employeeId,
        periodStart: periodStart,
        periodEndExclusive:
            periodEndExclusive,
      );
    }
  }

  /// Fallback query used when the compound Firestore
  /// index has not yet been created.
  ///
  /// It also supports old attendance records where
  /// employeeId may have been stored as a string.
  static Future<
      List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>>
      _loadWithClientDateFilter({
    required DocumentReference<Map<String, dynamic>>
        employeeReference,
    required String employeeId,
    required DateTime periodStart,
    required DateTime periodEndExclusive,
  }) async {
    final Map<String,
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        uniqueDocuments = {};

    final QuerySnapshot<Map<String, dynamic>>
        referenceSnapshot = await _firestore
            .collection('attendance')
            .where(
              'employeeId',
              isEqualTo: employeeReference,
            )
            .get();

    for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        document in referenceSnapshot.docs) {
      uniqueDocuments[document.id] =
          document;
    }

    // Legacy support for attendance documents that
    // stored employeeId as a plain document ID.
    try {
      final QuerySnapshot<Map<String, dynamic>>
          stringSnapshot = await _firestore
              .collection('attendance')
              .where(
                'employeeId',
                isEqualTo: employeeId,
              )
              .get();

      for (final QueryDocumentSnapshot<
              Map<String, dynamic>>
          document in stringSnapshot.docs) {
        uniqueDocuments[document.id] =
            document;
      }
    } on FirebaseException {
      // Existing reference-based records are still valid,
      // so failure of the optional legacy query is ignored.
    }

    final List<QueryDocumentSnapshot<
            Map<String, dynamic>>>
        filteredDocuments = uniqueDocuments.values
            .where(
      (
        QueryDocumentSnapshot<
                Map<String, dynamic>>
            document,
      ) {
        final DateTime? attendanceDate =
            _dateFromValue(
          document.data()['attendanceDate'],
        );

        if (attendanceDate == null) {
          return false;
        }

        return !attendanceDate.isBefore(
              periodStart,
            ) &&
            attendanceDate.isBefore(
              periodEndExclusive,
            );
      },
    ).toList();

    return filteredDocuments;
  }

  static bool _isWorkedAttendance({
    required String status,
    required Map<String, dynamic> data,
  }) {
    if (status == 'absent' ||
        status == 'leave' ||
        status == 'day_off' ||
        status == 'rest_day') {
      return false;
    }

    if (status == 'present' ||
        status == 'late' ||
        status == 'half_day') {
      return true;
    }

    if (data['timeIn'] != null) {
      return true;
    }

    return _number(
          data['totalWorkHours'],
        ) >
        0;
  }

  static double _readOvertimeHours(
    Map<String, dynamic> data,
  ) {
    final double storedHours =
        _number(
      data['overtimeHours'],
    );

    if (storedHours > 0) {
      return storedHours;
    }

    final double storedMinutes =
        _number(
      data['overtimeMinutes'],
    );

    if (storedMinutes > 0) {
      return storedMinutes / 60;
    }

    return 0;
  }

  static DateTime? _dateFromValue(
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

  static double _number(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static double _round(
    double value,
  ) {
    return double.parse(
      value.toStringAsFixed(2),
    );
  }
}