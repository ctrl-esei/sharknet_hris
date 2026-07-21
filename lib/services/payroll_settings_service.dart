import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PayrollSettingsService {
  const PayrollSettingsService._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>>
      get governmentComplianceReference {
    return _firestore
        .collection('payroll_settings')
        .doc('government_compliance');
  }

  static DocumentReference<Map<String, dynamic>>
      get holidayRulesReference {
    return _firestore
        .collection('payroll_settings')
        .doc('holiday_rules');
  }

  /// These are project-wide fixed deductions.
  ///
  /// Change these values here before the first initialization,
  /// or edit the Firestore document later.
  static const Map<String, dynamic>
      defaultGovernmentCompliance = {
    'mode': 'fixed',
    'fixedForAllEmployees': true,

    'sss': 500.0,
    'philHealth': 500.0,
    'pagIbig': 200.0,
    'withholdingTax': 0.0,

    'version': 1,
    'status': 'active',
    'description':
        'Fixed government compliance deductions applied '
        'to every employee payroll.',
  };

  static const Map<String, dynamic>
      defaultHolidayRules = {
    'restDayMultiplier': 1.30,

    'specialNonWorkingMultiplier': 1.30,
    'specialNonWorkingRestDayMultiplier': 1.50,

    'regularHolidayMultiplier': 2.00,
    'regularHolidayRestDayMultiplier': 2.60,

    'doubleHolidayMultiplier': 3.00,
    'doubleHolidayRestDayMultiplier': 3.90,

    'specialWorkingDayMultiplier': 1.00,

    'version': 1,
    'status': 'active',
    'description':
        'Holiday multipliers used during payroll '
        'computation.',
  };

  /// Automatically creates both payroll settings documents
  /// when they do not exist.
  ///
  /// Existing documents are left unchanged.
  static Future<void> ensureInitialized() async {
    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw StateError(
        'A signed-in HR or administrator is required '
        'to initialize payroll settings.',
      );
    }

    await _firestore.runTransaction(
      (Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>>
            governmentDocument =
            await transaction.get(
          governmentComplianceReference,
        );

        final DocumentSnapshot<Map<String, dynamic>>
            holidayRulesDocument =
            await transaction.get(
          holidayRulesReference,
        );

        if (!governmentDocument.exists) {
          transaction.set(
            governmentComplianceReference,
            {
              ...defaultGovernmentCompliance,
              'createdAt':
                  FieldValue.serverTimestamp(),
              'createdBy': currentUser.uid,
              'updatedAt':
                  FieldValue.serverTimestamp(),
              'updatedBy': currentUser.uid,
            },
          );
        }

        if (!holidayRulesDocument.exists) {
          transaction.set(
            holidayRulesReference,
            {
              ...defaultHolidayRules,
              'createdAt':
                  FieldValue.serverTimestamp(),
              'createdBy': currentUser.uid,
              'updatedAt':
                  FieldValue.serverTimestamp(),
              'updatedBy': currentUser.uid,
            },
          );
        }
      },
    );
  }

  /// Loads the fixed government-compliance settings.
  ///
  /// The document is automatically initialized first
  /// when it does not exist.
  static Future<Map<String, dynamic>>
      loadGovernmentCompliance() async {
    await ensureInitialized();

    final DocumentSnapshot<Map<String, dynamic>>
        document =
        await governmentComplianceReference.get(
      const GetOptions(
        source: Source.serverAndCache,
      ),
    );

    return {
      ...defaultGovernmentCompliance,
      ...?document.data(),
    };
  }

  /// Loads the fixed holiday multipliers.
  ///
  /// The document is automatically initialized first
  /// when it does not exist.
  static Future<Map<String, dynamic>>
      loadHolidayRules() async {
    await ensureInitialized();

    final DocumentSnapshot<Map<String, dynamic>>
        document = await holidayRulesReference.get(
      const GetOptions(
        source: Source.serverAndCache,
      ),
    );

    return {
      ...defaultHolidayRules,
      ...?document.data(),
    };
  }

  static double number(
    Map<String, dynamic> data,
    String fieldName, {
    double fallback = 0,
  }) {
    final dynamic value = data[fieldName];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }

  static double governmentComplianceTotal(
    Map<String, dynamic> settings,
  ) {
    return number(settings, 'sss') +
        number(settings, 'philHealth') +
        number(settings, 'pagIbig') +
        number(settings, 'withholdingTax');
  }
}