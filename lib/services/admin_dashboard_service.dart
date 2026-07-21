import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUserSummary {
  const AdminUserSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.accountStatus,
    required this.lastLogin,
    required this.employeeId,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final String accountStatus;
  final DateTime? lastLogin;
  final String employeeId;

  bool get isActive =>
      accountStatus.toLowerCase() == 'active';
}

class AdminSessionSummary {
  const AdminSessionSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.platform,
    required this.isOnline,
    required this.lastActiveAt,
    required this.signedInAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final String platform;
  final bool isOnline;
  final DateTime? lastActiveAt;
  final DateTime? signedInAt;

  bool get isCurrentlyActive {
    final DateTime? lastActive = lastActiveAt;

    if (!isOnline || lastActive == null) {
      return false;
    }

    return DateTime.now()
            .difference(lastActive)
            .inMinutes <=
        5;
  }
}

class AdminAnomalySummary {
  const AdminAnomalySummary({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    required this.occurrenceCount,
    required this.detectedAt,
    required this.resolvedAt,
    required this.userId,
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final String severity;
  final String status;
  final int occurrenceCount;
  final DateTime? detectedAt;
  final DateTime? resolvedAt;
  final String userId;

  bool get isUnresolved =>
      status.toLowerCase() != 'resolved';
}

class AdminActivityItem {
  const AdminActivityItem({
    required this.id,
    required this.action,
    required this.category,
    required this.title,
    required this.description,
    required this.performedByName,
    required this.performedByRole,
    required this.targetId,
    required this.severity,
    required this.createdAt,
    required this.metadata,
  });

  final String id;
  final String action;
  final String category;
  final String title;
  final String description;
  final String performedByName;
  final String performedByRole;
  final String targetId;
  final String severity;
  final DateTime? createdAt;
  final Map<String, dynamic> metadata;
}

class AdminHealthItem {
  const AdminHealthItem({
    required this.id,
    required this.serviceName,
    required this.description,
    required this.status,
    required this.averageResponseMs,
    required this.uptimePercentage,
    required this.message,
    required this.lastCheckedAt,
    required this.sortOrder,
  });

  final String id;
  final String serviceName;
  final String description;
  final String status;
  final double averageResponseMs;
  final double? uptimePercentage;
  final String message;
  final DateTime? lastCheckedAt;
  final int sortOrder;
}

class AdminDashboardMetrics {
  const AdminDashboardMetrics({
    required this.totalUsers,
    required this.activeUsers,
    required this.activeSessions,
    required this.unresolvedAnomalies,
    required this.auditEventsLastSevenDays,
  });

  final int totalUsers;
  final int activeUsers;
  final int activeSessions;
  final int unresolvedAnomalies;
  final int auditEventsLastSevenDays;
}

class AdminDashboardService {
  AdminDashboardService({
    FirebaseFirestore? firestore,
  }) : _firestore =
            firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AdminUserSummary>> watchUsers() {
    return _firestore
        .collection('users')
        .snapshots()
        .map(
      (
        QuerySnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        final List<AdminUserSummary> users =
            snapshot.docs.map(
          (
            QueryDocumentSnapshot<
                    Map<String, dynamic>>
                document,
          ) {
            final Map<String, dynamic> data =
                document.data();

            return AdminUserSummary(
              id: document.id,
              fullName: _text(
                data['fullName'],
                fallback: 'Unnamed User',
              ),
              email: _text(
                data['email'],
                fallback: '',
              ),
              role: _normalized(
                data['userRole'] ?? data['role'],
                fallback: 'employee',
              ),
              accountStatus: _normalized(
                data['accountStatus'],
                fallback: 'active',
              ),
              lastLogin: _date(
                data['lastLogin'] ??
                    data['lastLoginAt'],
              ),
              employeeId: _referenceId(
                data['employeeId'],
              ),
            );
          },
        ).toList();

        users.sort(
          (
            AdminUserSummary first,
            AdminUserSummary second,
          ) =>
              first.fullName
                  .toLowerCase()
                  .compareTo(
                    second.fullName.toLowerCase(),
                  ),
        );

        return users;
      },
    );
  }

  Stream<List<AdminSessionSummary>>
      watchSessions() {
    return _firestore
        .collection('user_sessions')
        .snapshots()
        .map(
      (
        QuerySnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        final List<AdminSessionSummary> sessions =
            snapshot.docs.map(
          (
            QueryDocumentSnapshot<
                    Map<String, dynamic>>
                document,
          ) {
            final Map<String, dynamic> data =
                document.data();

            return AdminSessionSummary(
              id: document.id,
              fullName: _text(
                data['fullName'],
                fallback: 'Unknown User',
              ),
              email: _text(
                data['email'],
                fallback: '',
              ),
              role: _normalized(
                data['role'],
                fallback: 'user',
              ),
              platform: _text(
                data['platform'],
                fallback: 'unknown',
              ),
              isOnline:
                  data['isOnline'] == true,
              lastActiveAt: _date(
                data['lastActiveAt'],
              ),
              signedInAt: _date(
                data['signedInAt'],
              ),
            );
          },
        ).toList();

        sessions.sort(
          (
            AdminSessionSummary first,
            AdminSessionSummary second,
          ) {
            return _milliseconds(
              second.lastActiveAt,
            ).compareTo(
              _milliseconds(
                first.lastActiveAt,
              ),
            );
          },
        );

        return sessions;
      },
    );
  }

  Stream<List<AdminAnomalySummary>>
      watchAnomalies() {
    return _firestore
        .collection('system_anomalies')
        .snapshots()
        .map(
      (
        QuerySnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        final List<AdminAnomalySummary> anomalies =
            snapshot.docs.map(
          (
            QueryDocumentSnapshot<
                    Map<String, dynamic>>
                document,
          ) {
            final Map<String, dynamic> data =
                document.data();

            return AdminAnomalySummary(
              id: document.id,
              type: _normalized(
                data['type'],
                fallback: 'system',
              ),
              title: _text(
                data['title'],
                fallback: 'System Anomaly',
              ),
              description: _text(
                data['description'] ??
                    data['message'],
                fallback: '',
              ),
              severity: _normalized(
                data['severity'],
                fallback: 'medium',
              ),
              status: _normalized(
                data['status'],
                fallback: 'unresolved',
              ),
              occurrenceCount: _integer(
                data['occurrenceCount'],
                fallback: 1,
              ),
              detectedAt: _date(
                data['detectedAt'] ??
                    data['createdAt'],
              ),
              resolvedAt: _date(
                data['resolvedAt'],
              ),
              userId: _text(
                data['userId'],
                fallback: '',
              ),
            );
          },
        ).toList();

        anomalies.sort(
          (
            AdminAnomalySummary first,
            AdminAnomalySummary second,
          ) {
            if (first.isUnresolved !=
                second.isUnresolved) {
              return first.isUnresolved ? -1 : 1;
            }

            return _milliseconds(
              second.detectedAt,
            ).compareTo(
              _milliseconds(
                first.detectedAt,
              ),
            );
          },
        );

        return anomalies;
      },
    );
  }

  Stream<List<AdminActivityItem>>
      watchAuditLogs({
    int limit = 250,
  }) {
    return _firestore
        .collection('audit_logs')
        .snapshots()
        .map(
      (
        QuerySnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        final List<AdminActivityItem> items =
            snapshot.docs.map(
          (
            QueryDocumentSnapshot<
                    Map<String, dynamic>>
                document,
          ) {
            final Map<String, dynamic> data =
                document.data();
            final Map<String, dynamic> actor =
                _map(data['performedBy']);

            return AdminActivityItem(
              id: document.id,
              action: _normalized(
                data['action'],
                fallback: 'activity',
              ),
              category: _normalized(
                data['category'],
                fallback: 'system',
              ),
              title: _text(
                data['title'],
                fallback: _titleFromAction(
                  data['action'],
                ),
              ),
              description: _text(
                data['description'],
                fallback: '',
              ),
              performedByName: _text(
                actor['fullName'] ??
                    actor['email'] ??
                    data['performedByName'],
                fallback: 'System',
              ),
              performedByRole: _normalized(
                actor['role'] ??
                    data['performedByRole'],
                fallback: 'system',
              ),
              targetId: _text(
                data['targetId'],
                fallback: '',
              ),
              severity: _normalized(
                data['severity'],
                fallback: 'info',
              ),
              createdAt: _date(
                data['createdAt'],
              ),
              metadata: _map(
                data['metadata'],
              ),
            );
          },
        ).toList();

        items.sort(
          (
            AdminActivityItem first,
            AdminActivityItem second,
          ) =>
              _milliseconds(
                second.createdAt,
              ).compareTo(
                _milliseconds(
                  first.createdAt,
                ),
              ),
        );

        if (items.length <= limit) {
          return items;
        }

        return items.take(limit).toList();
      },
    );
  }

  Stream<List<AdminHealthItem>>
      watchSystemHealth() {
    return _firestore
        .collection('system_health')
        .snapshots()
        .map(
      (
        QuerySnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        final List<AdminHealthItem> items =
            snapshot.docs.map(
          (
            QueryDocumentSnapshot<
                    Map<String, dynamic>>
                document,
          ) {
            final Map<String, dynamic> data =
                document.data();
            final dynamic uptimeValue =
                data['uptimePercentage'];

            return AdminHealthItem(
              id: document.id,
              serviceName: _text(
                data['serviceName'],
                fallback: document.id,
              ),
              description: _text(
                data['description'],
                fallback: '',
              ),
              status: _normalized(
                data['status'],
                fallback: 'unknown',
              ),
              averageResponseMs: _number(
                data['averageResponseMs'],
              ),
              uptimePercentage:
                  uptimeValue is num
                      ? uptimeValue.toDouble()
                      : double.tryParse(
                          uptimeValue
                                  ?.toString() ??
                              '',
                        ),
              message: _text(
                data['message'],
                fallback: '',
              ),
              lastCheckedAt: _date(
                data['lastCheckedAt'],
              ),
              sortOrder: _integer(
                data['sortOrder'],
              ),
            );
          },
        ).toList();

        items.sort(
          (
            AdminHealthItem first,
            AdminHealthItem second,
          ) =>
              first.sortOrder
                  .compareTo(second.sortOrder),
        );

        return items;
      },
    );
  }

  Stream<AdminDashboardMetrics>
      watchDashboardMetrics() {
    late final StreamSubscription<
            List<AdminUserSummary>>
        usersSubscription;
    late final StreamSubscription<
            List<AdminSessionSummary>>
        sessionsSubscription;
    late final StreamSubscription<
            List<AdminAnomalySummary>>
        anomaliesSubscription;
    late final StreamSubscription<
            List<AdminActivityItem>>
        auditSubscription;

    final StreamController<
            AdminDashboardMetrics>
        controller =
        StreamController<AdminDashboardMetrics>();

    List<AdminUserSummary> users =
        <AdminUserSummary>[];
    List<AdminSessionSummary> sessions =
        <AdminSessionSummary>[];
    List<AdminAnomalySummary> anomalies =
        <AdminAnomalySummary>[];
    List<AdminActivityItem> auditLogs =
        <AdminActivityItem>[];

    bool usersReady = false;
    bool sessionsReady = false;
    bool anomaliesReady = false;
    bool auditReady = false;

    void emit() {
      if (!usersReady ||
          !sessionsReady ||
          !anomaliesReady ||
          !auditReady ||
          controller.isClosed) {
        return;
      }

      final DateTime sevenDaysAgo =
          DateTime.now().subtract(
        const Duration(days: 7),
      );

      controller.add(
        AdminDashboardMetrics(
          totalUsers: users.length,
          activeUsers: users
              .where(
                (
                  AdminUserSummary user,
                ) =>
                    user.isActive,
              )
              .length,
          activeSessions: sessions
              .where(
                (
                  AdminSessionSummary session,
                ) =>
                    session.isCurrentlyActive,
              )
              .length,
          unresolvedAnomalies: anomalies
              .where(
                (
                  AdminAnomalySummary anomaly,
                ) =>
                    anomaly.isUnresolved,
              )
              .length,
          auditEventsLastSevenDays: auditLogs
              .where(
                (
                  AdminActivityItem activity,
                ) {
                  final DateTime? createdAt =
                      activity.createdAt;

                  return createdAt != null &&
                      !createdAt.isBefore(
                        sevenDaysAgo,
                      );
                },
              )
              .length,
        ),
      );
    }

    controller.onListen = () {
      usersSubscription =
          watchUsers().listen(
        (
          List<AdminUserSummary> value,
        ) {
          users = value;
          usersReady = true;
          emit();
        },
        onError: controller.addError,
      );

      sessionsSubscription =
          watchSessions().listen(
        (
          List<AdminSessionSummary> value,
        ) {
          sessions = value;
          sessionsReady = true;
          emit();
        },
        onError: controller.addError,
      );

      anomaliesSubscription =
          watchAnomalies().listen(
        (
          List<AdminAnomalySummary> value,
        ) {
          anomalies = value;
          anomaliesReady = true;
          emit();
        },
        onError: controller.addError,
      );

      auditSubscription =
          watchAuditLogs().listen(
        (
          List<AdminActivityItem> value,
        ) {
          auditLogs = value;
          auditReady = true;
          emit();
        },
        onError: controller.addError,
      );
    };

    controller.onCancel = () async {
      await usersSubscription.cancel();
      await sessionsSubscription.cancel();
      await anomaliesSubscription.cancel();
      await auditSubscription.cancel();
    };

    return controller.stream;
  }
}

DateTime? adminDateFromValue(dynamic value) {
  return _date(value);
}

String adminFormatLabel(String value) {
  return _formatLabel(value);
}

String adminFormatDateTime(DateTime? value) {
  if (value == null) {
    return 'Not available';
  }

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

  final int hour =
      value.hour % 12 == 0
          ? 12
          : value.hour % 12;

  final String minute =
      value.minute.toString().padLeft(2, '0');

  final String period =
      value.hour >= 12 ? 'PM' : 'AM';

  return '${months[value.month - 1]} '
      '${value.day}, ${value.year} • '
      '$hour:$minute $period';
}

String adminTimeAgo(DateTime? value) {
  if (value == null) {
    return 'Unknown';
  }

  final Duration difference =
      DateTime.now().difference(value);

  if (difference.isNegative ||
      difference.inSeconds < 60) {
    return 'Just now';
  }

  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  }

  if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  }

  if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  }

  return adminFormatDateTime(value);
}

String _titleFromAction(dynamic value) {
  return _formatLabel(
    _normalized(
      value,
      fallback: 'activity',
    ),
  );
}

String _formatLabel(String value) {
  if (value.trim().isEmpty) {
    return 'Unknown';
  }

  return value
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(' ')
      .where(
        (String word) => word.isNotEmpty,
      )
      .map(
        (String word) =>
            '${word[0].toUpperCase()}'
            '${word.substring(1).toLowerCase()}',
      )
      .join(' ');
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

String _referenceId(dynamic value) {
  if (value is DocumentReference) {
    return value.id;
  }

  final String raw =
      value?.toString().trim() ?? '';

  if (raw.isEmpty) {
    return '';
  }

  return raw.contains('/')
      ? raw.split('/').last
      : raw;
}

DateTime? _date(dynamic value) {
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

double _number(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}

int _integer(
  dynamic value, {
  int fallback = 0,
}) {
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
        value?.toString() ?? '',
      ) ??
      fallback;
}

int _milliseconds(DateTime? value) {
  return value?.millisecondsSinceEpoch ?? 0;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map<String, dynamic>(
      (
        dynamic key,
        dynamic item,
      ) =>
          MapEntry<String, dynamic>(
        key.toString(),
        item,
      ),
    );
  }

  return <String, dynamic>{};
}
