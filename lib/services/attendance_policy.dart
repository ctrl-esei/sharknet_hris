import 'dart:math' as math;

class AttendancePolicy {
  AttendancePolicy._();

  static DateTime dayStart(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime scheduledStart(DateTime value) {
    return DateTime(value.year, value.month, value.day, 7);
  }

  static DateTime lateCutoff(DateTime value) {
    return DateTime(value.year, value.month, value.day, 7, 30);
  }

  static DateTime overtimeStart(DateTime value) {
    return DateTime(value.year, value.month, value.day, 17, 30);
  }

  static String punctualityStatus(DateTime timeIn) {
    if (timeIn.isBefore(scheduledStart(timeIn))) {
      return 'early';
    }

    if (timeIn.isAfter(lateCutoff(timeIn))) {
      return 'late';
    }

    return 'on_time';
  }

  static int lateMinutes(DateTime timeIn) {
    return math.max(
      0,
      timeIn.difference(lateCutoff(timeIn)).inMinutes,
    );
  }

  static int overtimeMinutes(DateTime timeOut) {
    return math.max(
      0,
      timeOut.difference(overtimeStart(timeOut)).inMinutes,
    );
  }

  static int undertimeMinutes(DateTime timeOut) {
    return math.max(
      0,
      overtimeStart(timeOut).difference(timeOut).inMinutes,
    );
  }

  static double hoursFromMinutes(int minutes) {
    return double.parse((minutes / 60).toStringAsFixed(4));
  }
}
