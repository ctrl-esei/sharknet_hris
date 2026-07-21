import 'package:cloud_firestore/cloud_firestore.dart';

class HrKpiService {
  HrKpiService({
    FirebaseFirestore? firestore,
  }) : _firestore =
            firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Counts active users whose role is employee.
  ///
  /// Admin and HR accounts are excluded.
  Stream<int> activeEmployees() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((document) {
        final Map<String, dynamic> data =
            document.data();

        final String accountStatus =
            (data['accountStatus'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        return accountStatus == 'active';
      }).length;
    });
  }

  /// Counts today's attendance records that are:
  /// status = present
  /// faceVerified = true
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

        return status == 'present' &&
            faceVerified;
      }).length;
    });
  }

  /// Counts pending leave requests.
  Stream<int> pendingLeaves() {
    return _firestore
        .collection('leave_request')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Counts draft payslips.
  Stream<int> draftPayslips() {
    return _firestore
        .collection('payslips')
        .where('status', isEqualTo: 'draft')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}