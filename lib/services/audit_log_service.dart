import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditLogService {
  AuditLogService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore =
            firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<Map<String, dynamic>>
      currentActorSnapshot() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return <String, dynamic>{
        'uid': '',
        'fullName': 'System',
        'email': '',
        'role': 'system',
      };
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>>
          userDocument = await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

      final Map<String, dynamic> data =
          userDocument.data() ??
              <String, dynamic>{};

      return <String, dynamic>{
        'uid': user.uid,
        'fullName': _text(
          data['fullName'] ??
              user.displayName,
          fallback: 'Authenticated User',
        ),
        'email': _text(
          data['email'] ?? user.email,
          fallback: '',
        ),
        'role': _normalized(
          data['userRole'] ?? data['role'],
          fallback: 'user',
        ),
      };
    } catch (_) {
      return <String, dynamic>{
        'uid': user.uid,
        'fullName': _text(
          user.displayName,
          fallback: 'Authenticated User',
        ),
        'email': user.email ?? '',
        'role': 'user',
      };
    }
  }

  Future<DocumentReference<Map<String, dynamic>>>
      log({
    required String action,
    required String category,
    required String title,
    required String description,
    String targetId = '',
    String severity = 'info',
    DocumentReference<Object?>? targetReference,
    Map<String, dynamic> metadata =
        const <String, dynamic>{},
  }) async {
    final Map<String, dynamic> actor =
        await currentActorSnapshot();

    return _firestore
        .collection('audit_logs')
        .add(
      <String, dynamic>{
        'action': _normalized(
          action,
          fallback: 'activity',
        ),
        'category': _normalized(
          category,
          fallback: 'system',
        ),
        'title': title.trim(),
        'description': description.trim(),
        'targetId': targetId.trim(),
        'targetReference': targetReference,
        'severity': _normalized(
          severity,
          fallback: 'info',
        ),
        'performedBy': actor,
        'performedByUid':
            actor['uid']?.toString() ?? '',
        'metadata': metadata,
        'createdAt':
            FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> logUserUpdate({
    required String targetUserId,
    required String targetName,
    required String oldRole,
    required String newRole,
    required String oldStatus,
    required String newStatus,
  }) async {
    await log(
      action: 'user_updated',
      category: 'users',
      title: 'User Account Updated',
      description:
          'Updated $targetName: role $oldRole → '
          '$newRole, status $oldStatus → '
          '$newStatus.',
      targetId: targetUserId,
      metadata: <String, dynamic>{
        'oldRole': oldRole,
        'newRole': newRole,
        'oldStatus': oldStatus,
        'newStatus': newStatus,
      },
    );
  }
}

String _normalized(
  dynamic value, {
  required String fallback,
}) {
  final String text =
      value?.toString().trim().toLowerCase() ??
          '';

  if (text.isEmpty) {
    return fallback;
  }

  return text
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
}

String _text(
  dynamic value, {
  required String fallback,
}) {
  final String text =
      value?.toString().trim() ?? '';

  return text.isEmpty ? fallback : text;
}
