import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/admin_dashboard_service.dart';
import 'admin_dashboard_widgets.dart';

class AdminDashboardHome extends StatelessWidget {
  const AdminDashboardHome({
    required this.onSelectPage,
    required this.onLogout,
    super.key,
    this.fullName = 'Admin',
    this.adminId = 'ADMIN',
  });

  final ValueChanged<int> onSelectPage;
  final VoidCallback onLogout;
  final String fullName;
  final String adminId;

  @override
  Widget build(BuildContext context) {
    final AdminDashboardService service =
        AdminDashboardService();

    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    final Stream<
            DocumentSnapshot<
                Map<String, dynamic>>>
        profileStream = currentUser == null
            ? const Stream<
                DocumentSnapshot<
                    Map<String, dynamic>>>.empty()
            : FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .snapshots();

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: profileStream,
      builder: (
        BuildContext context,
        AsyncSnapshot<
                DocumentSnapshot<
                    Map<String, dynamic>>>
            profileSnapshot,
      ) {
        final Map<String, dynamic> profile =
            profileSnapshot.data?.data() ??
                <String, dynamic>{};

        final String resolvedName =
            _text(
          profile['fullName'],
          fallback: fullName,
        );

        final String resolvedId =
            _text(
          profile['adminId'] ??
              profile['employeeId'],
          fallback: adminId,
        );

        return ColoredBox(
          color: const Color(0xFFF2F6FC),
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: AdminPortalHeader(
                  adminName:
                      _firstName(resolvedName),
                  adminId: resolvedId,
                  onLogout: onLogout,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  100,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      _buildMetrics(service),
                      const SizedBox(height: 18),
                      _buildSystemHealth(service),
                      const SizedBox(height: 18),
                      _buildRecentActivity(service),
                      const SizedBox(height: 18),
                      _buildAnomalyAlert(service),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetrics(
    AdminDashboardService service,
  ) {
    return StreamBuilder<
        AdminDashboardMetrics>(
      stream: service.watchDashboardMetrics(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                AdminDashboardMetrics>
            snapshot,
      ) {
        final AdminDashboardMetrics metrics =
            snapshot.data ??
                const AdminDashboardMetrics(
                  totalUsers: 0,
                  activeUsers: 0,
                  activeSessions: 0,
                  unresolvedAnomalies: 0,
                  auditEventsLastSevenDays: 0,
                );

        return LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
            final double width =
                (constraints.maxWidth - 14) / 2;

            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: <Widget>[
                SizedBox(
                  width: width,
                  child: AdminMetricCard(
                    value:
                        metrics.totalUsers.toString(),
                    label: 'Total Users',
                    subtitle:
                        '${metrics.activeUsers} active',
                    icon:
                        Icons.group_outlined,
                    accentColor:
                        const Color(0xFF9810FA),
                    onTap: () {
                      onSelectPage(1);
                    },
                  ),
                ),
                SizedBox(
                  width: width,
                  child: AdminMetricCard(
                    value: metrics.activeSessions
                        .toString(),
                    label: 'Active Sessions',
                    subtitle: 'Right now',
                    icon:
                        Icons.monitor_heart_outlined,
                    accentColor:
                        const Color(0xFF00A63E),
                    onTap: () {
                      onSelectPage(2);
                    },
                  ),
                ),
                SizedBox(
                  width: width,
                  child: AdminMetricCard(
                    value: metrics
                        .unresolvedAnomalies
                        .toString(),
                    label: 'Anomalies',
                    subtitle: 'Unresolved',
                    icon:
                        Icons.warning_amber_rounded,
                    accentColor:
                        const Color(0xFFE60012),
                    onTap: () {
                      onSelectPage(2);
                    },
                  ),
                ),
                SizedBox(
                  width: width,
                  child: AdminMetricCard(
                    value: metrics
                        .auditEventsLastSevenDays
                        .toString(),
                    label: 'Audit Events',
                    subtitle: 'Last 7 days',
                    icon:
                        Icons.description_outlined,
                    accentColor:
                        const Color(0xFF155EEF),
                    onTap: () {
                      onSelectPage(3);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSystemHealth(
    AdminDashboardService service,
  ) {
    return StreamBuilder<List<AdminHealthItem>>(
      stream: service.watchSystemHealth(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<AdminHealthItem>>
            snapshot,
      ) {
        final List<AdminHealthItem> health =
            snapshot.data ??
                <AdminHealthItem>[];

        return AdminSectionCard(
          title: 'System Health',
          child: health.isEmpty
              ? const AdminEmptyState(
                  icon:
                      Icons.monitor_heart_outlined,
                  title: 'No health checks yet',
                  message:
                      'The monitoring service will create live health records shortly.',
                )
              : Column(
                  children: <Widget>[
                    for (int index = 0;
                        index < health.length;
                        index++) ...<Widget>[
                      AdminHealthTile(
                        item: health[index],
                      ),
                      if (index !=
                          health.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildRecentActivity(
    AdminDashboardService service,
  ) {
    return StreamBuilder<
        List<AdminActivityItem>>(
      stream: service.watchAuditLogs(
        limit: 5,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                List<AdminActivityItem>>
            snapshot,
      ) {
        final List<AdminActivityItem> activities =
            snapshot.data ??
                <AdminActivityItem>[];

        return AdminSectionCard(
          title: 'Recent Activity',
          trailing: TextButton(
            onPressed: () {
              onSelectPage(3);
            },
            child: const Text(
              'View all →',
              style: TextStyle(
                color: Color(0xFFB037FF),
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),
          child: activities.isEmpty
              ? const AdminEmptyState(
                  icon:
                      Icons.history_outlined,
                  title: 'No audit activity yet',
                  message:
                      'Actions logged through AuditLogService will appear here.',
                )
              : Column(
                  children: <Widget>[
                    for (int index = 0;
                        index <
                            activities.length;
                        index++) ...<Widget>[
                      AdminActivityTile(
                        item: activities[index],
                      ),
                      if (index !=
                          activities.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildAnomalyAlert(
    AdminDashboardService service,
  ) {
    return StreamBuilder<
        List<AdminAnomalySummary>>(
      stream: service.watchAnomalies(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                List<AdminAnomalySummary>>
            snapshot,
      ) {
        final List<AdminAnomalySummary> unresolved =
            (snapshot.data ??
                    <AdminAnomalySummary>[])
                .where(
                  (
                    AdminAnomalySummary item,
                  ) =>
                      item.isUnresolved,
                )
                .toList();

        if (unresolved.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF3),
              borderRadius:
                  BorderRadius.circular(20),
              border: Border.all(
                color:
                    const Color(0xFFA6F4C5),
              ),
            ),
            child: const Row(
              children: <Widget>[
                Icon(
                  Icons.verified_outlined,
                  color: Color(0xFF039855),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No unresolved anomalies detected.',
                    style: TextStyle(
                      color:
                          Color(0xFF027A48),
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F1),
            borderRadius:
                BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFFFCDD2),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFE60012),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${unresolved.length} '
                      'Unresolved '
                      'Anomal${unresolved.length == 1 ? 'y' : 'ies'}',
                      style: const TextStyle(
                        color:
                            Color(0xFFC40010),
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...unresolved
                  .take(3)
                  .map(
                    (
                      AdminAnomalySummary item,
                    ) =>
                        Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 5,
                      ),
                      child: Text(
                        '• ${item.title}',
                        style: const TextStyle(
                          color:
                              Color(0xFFE60012),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 7),
              TextButton(
                onPressed: () {
                  onSelectPage(2);
                },
                child: const Text(
                  'View Monitor →',
                  style: TextStyle(
                    color: Color(0xFFE60012),
                    decoration:
                        TextDecoration.underline,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _firstName(String fullName) {
  final List<String> parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where(
        (String part) => part.isNotEmpty,
      )
      .toList();

  return parts.isEmpty
      ? 'Admin'
      : parts.first;
}

String _text(
  dynamic value, {
  required String fallback,
}) {
  final String text =
      value?.toString().trim() ?? '';

  return text.isEmpty ? fallback : text;
}
