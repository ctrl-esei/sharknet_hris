import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GovernmentComplianceSettings {
  const GovernmentComplianceSettings({
    required this.sss,
    required this.philHealth,
    required this.pagIbig,
    required this.withholdingTax,
    required this.fixedForAllEmployees,
    required this.version,
  });

  final double sss;
  final double philHealth;
  final double pagIbig;
  final double withholdingTax;

  final bool fixedForAllEmployees;
  final int version;

  double get total {
    return sss +
        philHealth +
        pagIbig +
        withholdingTax;
  }

  Map<String, dynamic> toMap() {
    return {
      'sss': sss,
      'philHealth': philHealth,
      'pagIbig': pagIbig,
      'withholdingTax': withholdingTax,
      'fixedForAllEmployees': fixedForAllEmployees,
      'version': version,
    };
  }

  factory GovernmentComplianceSettings.fromMap(
    Map<String, dynamic> data,
  ) {
    return GovernmentComplianceSettings(
      sss: _readNumber(
        data['sss'],
        fallback: 500,
      ),
      philHealth: _readNumber(
        data['philHealth'],
        fallback: 500,
      ),
      pagIbig: _readNumber(
        data['pagIbig'],
        fallback: 200,
      ),
      withholdingTax: _readNumber(
        data['withholdingTax'],
        fallback: 0,
      ),
      fixedForAllEmployees:
          data['fixedForAllEmployees'] != false,
      version: _readInteger(
        data['version'],
        fallback: 1,
      ),
    );
  }

  static double _readNumber(
    dynamic value, {
    required double fallback,
  }) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }

  static int _readInteger(
    dynamic value, {
    required int fallback,
  }) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }
}

class GovernmentComplianceService {
  const GovernmentComplianceService._();

  static final DocumentReference<Map<String, dynamic>>
      _reference = FirebaseFirestore.instance
          .collection('payroll_settings')
          .doc('government_compliance');

  static const GovernmentComplianceSettings defaults =
      GovernmentComplianceSettings(
    sss: 500,
    philHealth: 500,
    pagIbig: 200,
    withholdingTax: 0,
    fixedForAllEmployees: true,
    version: 1,
  );

  static DocumentReference<Map<String, dynamic>>
      get reference => _reference;

  /// Loads the fixed settings from Firebase.
  ///
  /// When payroll_settings/government_compliance does not
  /// exist, this method automatically creates it.
  static Future<GovernmentComplianceSettings>
      loadOrInitialize() async {
    final DocumentSnapshot<Map<String, dynamic>>
        document = await _reference.get();

    if (document.exists) {
      return GovernmentComplianceSettings.fromMap(
        document.data() ?? {},
      );
    }

    final String? currentUserUid =
        FirebaseAuth.instance.currentUser?.uid;

    await _reference.set({
      ...defaults.toMap(),
      'mode': 'fixed',
      'description':
          'Company-wide fixed government compliance '
          'deductions used by every employee payroll.',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': currentUserUid,
    });

    return defaults;
  }

  /// Use this later when HR needs to update the fixed values.
  static Future<void> update({
    required double sss,
    required double philHealth,
    required double pagIbig,
    required double withholdingTax,
  }) async {
    final String? currentUserUid =
        FirebaseAuth.instance.currentUser?.uid;

    await _reference.set({
      'sss': _round(sss),
      'philHealth': _round(philHealth),
      'pagIbig': _round(pagIbig),
      'withholdingTax': _round(withholdingTax),
      'fixedForAllEmployees': true,
      'mode': 'fixed',
      'version': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': currentUserUid,
    }, SetOptions(merge: true));
  }

  static double _round(double value) {
    return double.parse(
      value.toStringAsFixed(2),
    );
  }
}