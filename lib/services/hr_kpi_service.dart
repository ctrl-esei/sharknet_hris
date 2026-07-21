import 'package:cloud_firestore/cloud_firestore.dart';

class HrKpiService {
  HrKpiService({
    FirebaseFirestore? firestore,
  }) : _firestore =
            firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Counts every document in the `employee` collection.
  ///
  /// This fixes the dashboard total because newly added employee records
  /// are counted even when no Firebase Authentication user exists yet.
  Stream<int> totalEmployees() {
    return _firestore
        .collection('employee')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Counts active employee records from the `employee` collection.
  Stream<int> activeEmployees() {
    return _firestore
        .collection('employee')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((document) {
        final Map<String, dynamic> data =
            document.data();

        final String employmentStatus =
            (data['employmentStatus'] ?? 'active')
                .toString()
                .trim()
                .toLowerCase();

        return employmentStatus == 'active';
      }).length;
    });
  }

  /// Counts employees with a face-verified time-in record today.
  Stream<int> presentToday() {
    final DateTime now = DateTime.now();

    final DateTime startOfToday = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime startOfTomorrow =
        startOfToday.add(const Duration(days: 1));

    return _firestore
        .collection('attendance')
        .where(
          'attendanceDate',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(startOfToday),
        )
        .where(
          'attendanceDate',
          isLessThan:
              Timestamp.fromDate(startOfTomorrow),
        )
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((document) {
        final Map<String, dynamic> data =
            document.data();

        final String status =
            (data['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        final bool faceVerified =
            data['faceVerified'] == true;

        final bool hasTimeIn =
            data['timeIn'] != null;

        final bool excludedStatus =
            status == 'absent' ||
            status == 'leave' ||
            status == 'rejected' ||
            status == 'void';

        return hasTimeIn &&
            faceVerified &&
            !excludedStatus;
      }).length;
    });
  }

  /// Counts pending leave requests in real time.
  Stream<int> pendingLeaves() {
    return _firestore
        .collection('leave_request')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((document) {
        final String status =
            (document.data()['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        return status == 'pending';
      }).length;
    });
  }

  /// Counts draft payslip records in real time.
  Stream<int> draftPayslips() {
    return _firestore
        .collection('payslips')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((document) {
        final String status =
            (document.data()['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        return status == 'draft';
      }).length;
    });
  }
}
