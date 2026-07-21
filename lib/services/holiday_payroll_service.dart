import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

class HolidayPayrollEntry {
  const HolidayPayrollEntry({
    required this.holidayReference,
    required this.holidayDocumentId,
    required this.holidayDate,
    required this.holidayName,
    required this.holidayType,
    required this.worked,
    required this.isRestDay,
    required this.regularHours,
    required this.overtimeHours,
    required this.hourlyRate,
    required this.multiplier,
    required this.overtimeMultiplier,
    required this.holidayPay,
    required this.holidayOvertimePay,
  });

  final DocumentReference<Map<String, dynamic>> holidayReference;
  final String holidayDocumentId;
  final DateTime holidayDate;
  final String holidayName;
  final String holidayType;

  final bool worked;
  final bool isRestDay;

  final double regularHours;
  final double overtimeHours;
  final double hourlyRate;

  final double multiplier;
  final double overtimeMultiplier;

  final double holidayPay;
  final double holidayOvertimePay;

  double get totalEarnings {
    return holidayPay + holidayOvertimePay;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'holidayReference': holidayReference,
      'holidayDocumentId': holidayDocumentId,
      'holidayDate': Timestamp.fromDate(
        DateTime(
          holidayDate.year,
          holidayDate.month,
          holidayDate.day,
        ),
      ),
      'holidayName': holidayName,
      'holidayType': holidayType,
      'worked': worked,
      'isRestDay': isRestDay,
      'regularHours': _round(regularHours),
      'overtimeHours': _round(overtimeHours),
      'hourlyRate': _round(hourlyRate),
      'multiplier': _round(multiplier),
      'overtimeMultiplier': _round(overtimeMultiplier),
      'holidayPay': _round(holidayPay),
      'holidayOvertimePay': _round(holidayOvertimePay),
      'totalEarnings': _round(totalEarnings),
    };
  }

  static double _round(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}

class HolidayPayrollSummary {
  const HolidayPayrollSummary({
    required this.entries,
  });

  const HolidayPayrollSummary.empty()
      : entries = const <HolidayPayrollEntry>[];

  final List<HolidayPayrollEntry> entries;

  double get holidayPay {
    return entries.fold<double>(
      0,
      (
        double total,
        HolidayPayrollEntry entry,
      ) {
        return total + entry.holidayPay;
      },
    );
  }

  double get holidayOvertimePay {
    return entries.fold<double>(
      0,
      (
        double total,
        HolidayPayrollEntry entry,
      ) {
        return total + entry.holidayOvertimePay;
      },
    );
  }

  double get holidayOvertimeHours {
    return entries.fold<double>(
      0,
      (
        double total,
        HolidayPayrollEntry entry,
      ) {
        return total + entry.overtimeHours;
      },
    );
  }

  /// Special working days remain ordinary working days.
  /// Other worked holiday/rest-day entries are excluded from
  /// ordinary days so their base pay is not counted twice.
  int get workedPremiumDayCount {
    return entries.where(
      (HolidayPayrollEntry entry) {
        return entry.worked &&
            entry.holidayType != 'special_working_day';
      },
    ).length;
  }

  Set<String> get premiumDateKeys {
    return entries
        .where(
          (HolidayPayrollEntry entry) =>
              entry.holidayType != 'special_working_day',
        )
        .map(
          (HolidayPayrollEntry entry) =>
              HolidayPayrollService.dateKey(entry.holidayDate),
        )
        .toSet();
  }

  List<Map<String, dynamic>> toBreakdown() {
    return entries
        .map(
          (HolidayPayrollEntry entry) => entry.toMap(),
        )
        .toList();
  }
}

class HolidayPayrollService {
  const HolidayPayrollService._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  /// Reads every active holiday inside the selected payroll
  /// period and matches it to the employee attendance breakdown.
  ///
  /// Expected holiday document fields:
  /// - holidayDate: Timestamp
  /// - name: String
  /// - holidayType: String
  /// - active: bool
  /// - isRestDay: bool (optional)
  ///
  /// Supported holidayType values:
  /// - rest_day
  /// - special_non_working
  /// - special_non_working_rest_day
  /// - regular_holiday
  /// - regular_holiday_rest_day
  /// - double_holiday
  /// - double_holiday_rest_day
  /// - special_working_day
  static Future<HolidayPayrollSummary> load({
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<Map<String, dynamic>> attendanceBreakdown,
    required Map<String, dynamic> holidayRules,
    required double hourlyRate,
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
    ).add(const Duration(days: 1));

    final QuerySnapshot<Map<String, dynamic>> holidaySnapshot =
        await _firestore.collection('holidays').get();

    final Map<String, Map<String, dynamic>> attendanceByDate =
        <String, Map<String, dynamic>>{};

    for (final Map<String, dynamic> attendance
        in attendanceBreakdown) {
      final DateTime? attendanceDate = _dateFromValue(
        attendance['attendanceDate'],
      );

      if (attendanceDate == null) {
        continue;
      }

      attendanceByDate[dateKey(attendanceDate)] = attendance;
    }

    final List<HolidayPayrollEntry> entries =
        <HolidayPayrollEntry>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>>
        holidayDocument in holidaySnapshot.docs) {
      final Map<String, dynamic> holidayData =
          holidayDocument.data();

      if (holidayData['active'] == false) {
        continue;
      }

      final DateTime? holidayDate = _dateFromValue(
        holidayData['holidayDate'] ?? holidayData['date'],
      );

      if (holidayDate == null) {
        continue;
      }

      if (holidayDate.isBefore(normalizedStart) ||
          !holidayDate.isBefore(normalizedEndExclusive)) {
        continue;
      }

      final Map<String, dynamic>? attendance =
          attendanceByDate[dateKey(holidayDate)];

      final bool worked =
          attendance?['worked'] == true ||
              _number(attendance?['totalWorkHours']) > 0;

      final double totalWorkHours =
          _number(attendance?['totalWorkHours']);

      final double attendanceOvertimeHours =
          _number(attendance?['overtimeHours']);

      final String rawHolidayType =
          holidayData['holidayType']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              'regular_holiday';

      final bool isRestDay =
          holidayData['isRestDay'] == true ||
              rawHolidayType.contains('rest_day');

      final String holidayType = _normalizeHolidayType(
        rawHolidayType,
        isRestDay: isRestDay,
      );

      final double multiplier = _holidayMultiplier(
        holidayType,
        holidayRules,
      );

      // Special working days remain ordinary workdays.
      // Their ordinary pay and ordinary overtime are handled
      // by the standard payroll computation.
      final bool isSpecialWorkingDay =
          holidayType == 'special_working_day';

      final double regularHours = worked &&
              !isSpecialWorkingDay
          ? math.min(
              8,
              math.max(
                0,
                totalWorkHours - attendanceOvertimeHours,
              ),
            )
          : 0;

      final double holidayOvertimeHours = worked &&
              !isSpecialWorkingDay
          ? math.max(0, attendanceOvertimeHours)
          : 0;

      final double holidayPay = worked &&
              !isSpecialWorkingDay
          ? hourlyRate * regularHours * multiplier
          : 0;

      final double overtimeMultiplier = worked &&
              !isSpecialWorkingDay
          ? multiplier * 1.30
          : 0;

      final double holidayOvertimePay = worked &&
              !isSpecialWorkingDay
          ? hourlyRate *
              holidayOvertimeHours *
              overtimeMultiplier
          : 0;

      entries.add(
        HolidayPayrollEntry(
          holidayReference: holidayDocument.reference,
          holidayDocumentId: holidayDocument.id,
          holidayDate: holidayDate,
          holidayName:
              holidayData['name']?.toString() ??
                  holidayData['holidayName']?.toString() ??
                  _formatHolidayType(holidayType),
          holidayType: holidayType,
          worked: worked,
          isRestDay: isRestDay,
          regularHours: _round(regularHours),
          overtimeHours:
              _round(holidayOvertimeHours),
          hourlyRate: _round(hourlyRate),
          multiplier: _round(multiplier),
          overtimeMultiplier:
              _round(overtimeMultiplier),
          holidayPay: _round(holidayPay),
          holidayOvertimePay:
              _round(holidayOvertimePay),
        ),
      );
    }

    entries.sort(
      (
        HolidayPayrollEntry first,
        HolidayPayrollEntry second,
      ) {
        return first.holidayDate.compareTo(
          second.holidayDate,
        );
      },
    );

    return HolidayPayrollSummary(entries: entries);
  }

  static double _holidayMultiplier(
    String holidayType,
    Map<String, dynamic> rules,
  ) {
    switch (holidayType) {
      case 'rest_day':
        return _number(
          rules['restDayMultiplier'],
          fallback: 1.30,
        );

      case 'special_non_working':
        return _number(
          rules['specialNonWorkingMultiplier'],
          fallback: 1.30,
        );

      case 'special_non_working_rest_day':
        return _number(
          rules[
              'specialNonWorkingRestDayMultiplier'],
          fallback: 1.50,
        );

      case 'regular_holiday':
        return _number(
          rules['regularHolidayMultiplier'],
          fallback: 2.00,
        );

      case 'regular_holiday_rest_day':
        return _number(
          rules[
              'regularHolidayRestDayMultiplier'],
          fallback: 2.60,
        );

      case 'double_holiday':
        return _number(
          rules['doubleHolidayMultiplier'],
          fallback: 3.00,
        );

      case 'double_holiday_rest_day':
        return _number(
          rules[
              'doubleHolidayRestDayMultiplier'],
          fallback: 3.90,
        );

      case 'special_working_day':
        return _number(
          rules['specialWorkingDayMultiplier'],
          fallback: 1.00,
        );

      default:
        return 1.00;
    }
  }

  static String _normalizeHolidayType(
    String value, {
    required bool isRestDay,
  }) {
    final String normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_');

    if (isRestDay) {
      switch (normalized) {
        case 'regular_holiday':
          return 'regular_holiday_rest_day';

        case 'special_non_working':
        case 'special_non_working_day':
          return 'special_non_working_rest_day';

        case 'double_holiday':
          return 'double_holiday_rest_day';
      }
    }

    switch (normalized) {
      case 'special_non_working_day':
        return 'special_non_working';

      case 'regular':
        return 'regular_holiday';

      case 'special':
        return 'special_non_working';

      default:
        return normalized;
    }
  }

  static String _formatHolidayType(String value) {
    return value
        .split('_')
        .where((String word) => word.isNotEmpty)
        .map(
          (String word) =>
              '${word[0].toUpperCase()}'
              '${word.substring(1)}',
        )
        .join(' ');
  }

  static String dateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _dateFromValue(dynamic value) {
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
    dynamic value, {
    double fallback = 0,
  }) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }

  static double _round(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}
