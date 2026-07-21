import 'package:cloud_firestore/cloud_firestore.dart';

class ThirteenthMonthSummary {
  const ThirteenthMonthSummary({
    required this.employeeReference,
    required this.calendarYear,
    required this.eligiblePayrollCount,
    required this.totalEligibleBasicSalary,
    required this.thirteenthMonthPay,
    required this.payrollReferences,
  });

  final DocumentReference<Map<String, dynamic>>
      employeeReference;

  final int calendarYear;
  final int eligiblePayrollCount;

  final double totalEligibleBasicSalary;
  final double thirteenthMonthPay;

  final List<DocumentReference<Map<String, dynamic>>>
      payrollReferences;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'calendarYear': calendarYear,
      'eligiblePayrollCount':
          eligiblePayrollCount,
      'totalEligibleBasicSalary':
          totalEligibleBasicSalary,
      'divisor': 12,
      'thirteenthMonthPay':
          thirteenthMonthPay,
      'payrollReferences':
          payrollReferences,
      'formula':
          'totalEligibleBasicSalary / 12',
    };
  }
}

class ThirteenthMonthService {
  const ThirteenthMonthService._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static Future<ThirteenthMonthSummary> calculate({
    required String employeeId,
    required int calendarYear,
  }) async {
    final DocumentReference<Map<String, dynamic>>
        employeeReference = _firestore
            .collection('employee')
            .doc(employeeId);

    // Query by employee only, then apply year, payroll type,
    // and approval status filters in Dart. This keeps the
    // project usable without requiring another composite index.
    final QuerySnapshot<Map<String, dynamic>>
        payrollSnapshot = await _firestore
            .collection('payroll')
            .where(
              'employeeId',
              isEqualTo: employeeReference,
            )
            .get();

    double totalEligibleBasicSalary = 0;

    final List<DocumentReference<Map<String, dynamic>>>
        eligibleReferences =
        <DocumentReference<Map<String, dynamic>>>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>>
        payrollDocument in payrollSnapshot.docs) {
      final Map<String, dynamic> data =
          payrollDocument.data();

      final String payrollType =
          data['payrollType']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              'regular';

      if (payrollType != 'regular') {
        continue;
      }

      final String status =
          data['status']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      if (status != 'approved' &&
          status != 'released') {
        continue;
      }

      final int recordYear =
          _readPayrollYear(data);

      if (recordYear != calendarYear) {
        continue;
      }

      totalEligibleBasicSalary +=
          _number(data['basicPay']);

      eligibleReferences.add(
        payrollDocument.reference,
      );
    }

    final double roundedBasicSalary =
        _round(totalEligibleBasicSalary);

    return ThirteenthMonthSummary(
      employeeReference: employeeReference,
      calendarYear: calendarYear,
      eligiblePayrollCount:
          eligibleReferences.length,
      totalEligibleBasicSalary:
          roundedBasicSalary,
      thirteenthMonthPay:
          _round(roundedBasicSalary / 12),
      payrollReferences:
          eligibleReferences,
    );
  }

  static int _readPayrollYear(
    Map<String, dynamic> data,
  ) {
    final dynamic storedYear =
        data['payrollYear'];

    if (storedYear is num) {
      return storedYear.toInt();
    }

    final DateTime? periodEnd =
        _dateFromValue(
      data['payrollPeriodEnd'],
    );

    final DateTime? periodStart =
        _dateFromValue(
      data['payrollPeriodStart'],
    );

    return periodEnd?.year ??
        periodStart?.year ??
        0;
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

  static double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static double _round(double value) {
    return double.parse(
      value.toStringAsFixed(2),
    );
  }
}
