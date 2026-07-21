import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/admin_dashboard_service.dart';
import '../../services/audit_log_service.dart';
import '../../services/system_monitor_service.dart';
import 'admin_dashboard_widgets.dart';

class AdminMonitorScreen extends StatefulWidget {
  const AdminMonitorScreen({super.key});

  @override
  State<AdminMonitorScreen> createState() =>
      _AdminMonitorScreenState();
}

class _AdminMonitorScreenState
    extends State<AdminMonitorScreen> {
  final AdminDashboardService _service =
      AdminDashboardService();

  final AuditLogService _auditLogService =
      AuditLogService();

  String _anomalyFilter = 'unresolved';
  String? _processingAnomalyId;
  bool _checkingHealth = false;

  Future<void> _runHealthChecks() async {
    if (_checkingHealth) {
      return;
    }

    setState(() {
      _checkingHealth = true;
    });

    try {
      await SystemMonitorService.instance
          .runHealthChecks();

      _showMessage(
        'System health checks completed.',
        error: false,
      );
    } catch (error) {
      _showMessage(
        'Health check failed: $error',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _checkingHealth = false;
        });
      }
    }
  }

  Future<void> _resolveAnomaly(
    AdminAnomalySummary anomaly,
  ) async {
    if (_processingAnomalyId != null) {
      return;
    }

    final TextEditingController controller =
        TextEditingController();

    final String? remarks =
        await showDialog<String>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Resolve Anomaly',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                anomaly.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 13),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 5,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Resolution remarks',
                  alignLabelWithHint: true,
                  border:
                      OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(
                  controller.text.trim(),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFF039855),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(
                Icons.check_circle_outline,
              ),
              label: const Text('Resolve'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (remarks == null) {
      return;
    }

    setState(() {
      _processingAnomalyId = anomaly.id;
    });

    try {
      final Map<String, dynamic> actor =
          await _auditLogService
              .currentActorSnapshot();

      await FirebaseFirestore.instance
          .collection('system_anomalies')
          .doc(anomaly.id)
          .update(
        <String, dynamic>{
          'status': 'resolved',
          'resolvedAt':
              FieldValue.serverTimestamp(),
          'resolvedBy': actor,
          'resolutionRemarks': remarks,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
      );

      await _auditLogService.log(
        action: 'anomaly_resolved',
        category: 'system',
        title: 'Anomaly Resolved',
        description:
            'Resolved ${anomaly.title}.',
        targetId: anomaly.id,
        metadata: <String, dynamic>{
          'remarks': remarks,
          'severity': anomaly.severity,
        },
      );

      _showMessage(
        'Anomaly marked as resolved.',
        error: false,
      );
    } catch (error) {
      _showMessage(
        'Unable to resolve anomaly: $error',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingAnomalyId = null;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    required bool error,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error
              ? const Color(0xFFD92D20)
              : const Color(0xFF039855),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF2F6FC),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            18,
            20,
            18,
            100,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'System Monitor',
                        style: TextStyle(
                          color:
                              Color(0xFF101828),
                          fontSize: 25,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Live sessions, service health, and system anomalies.',
                        style: TextStyle(
                          color:
                              Color(0xFF667085),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _checkingHealth
                      ? null
                      : _runHealthChecks,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF9810FA),
                    foregroundColor: Colors.white,
                  ),
                  icon: _checkingHealth
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                        ),
                  label: const Text('Check'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildHealth(),
            const SizedBox(height: 18),
            _buildSessions(),
            const SizedBox(height: 18),
            _buildAnomalies(),
          ],
        ),
      ),
    );
  }

  Widget _buildHealth() {
    return StreamBuilder<
        List<AdminHealthItem>>(
      stream: _service.watchSystemHealth(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                List<AdminHealthItem>>
            snapshot,
      ) {
        final List<AdminHealthItem> items =
            snapshot.data ??
                <AdminHealthItem>[];

        return AdminSectionCard(
          title: 'Service Health',
          child: items.isEmpty
              ? const AdminEmptyState(
                  icon:
                      Icons.monitor_heart_outlined,
                  title: 'No health data',
                  message:
                      'Press Check to run the first service health scan.',
                )
              : Column(
                  children: <Widget>[
                    for (int index = 0;
                        index < items.length;
                        index++) ...<Widget>[
                      AdminHealthTile(
                        item: items[index],
                      ),
                      if (index !=
                          items.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSessions() {
    return StreamBuilder<
        List<AdminSessionSummary>>(
      stream: _service.watchSessions(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                List<AdminSessionSummary>>
            snapshot,
      ) {
        final List<AdminSessionSummary> sessions =
            snapshot.data ??
                <AdminSessionSummary>[];

        final List<AdminSessionSummary> active =
            sessions
                .where(
                  (
                    AdminSessionSummary session,
                  ) =>
                      session.isCurrentlyActive,
                )
                .toList();

        return AdminSectionCard(
          title:
              'Active Sessions (${active.length})',
          child: active.isEmpty
              ? const AdminEmptyState(
                  icon:
                      Icons.devices_other_outlined,
                  title: 'No active sessions',
                  message:
                      'Sessions appear after SessionTrackingService starts in each portal.',
                )
              : Column(
                  children: <Widget>[
                    for (int index = 0;
                        index < active.length;
                        index++) ...<Widget>[
                      _SessionTile(
                        session: active[index],
                      ),
                      if (index !=
                          active.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildAnomalies() {
    return StreamBuilder<
        List<AdminAnomalySummary>>(
      stream: _service.watchAnomalies(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                List<AdminAnomalySummary>>
            snapshot,
      ) {
        final List<AdminAnomalySummary> all =
            snapshot.data ??
                <AdminAnomalySummary>[];

        final List<AdminAnomalySummary> visible =
            _anomalyFilter == 'all'
                ? all
                : all
                    .where(
                      (
                        AdminAnomalySummary item,
                      ) =>
                          item.status ==
                          _anomalyFilter,
                    )
                    .toList();

        return AdminSectionCard(
          title: 'Anomalies',
          trailing: SizedBox(
            width: 135,
            child:
                DropdownButtonFormField<String>(
              initialValue:
                  _anomalyFilter,
              isDense: true,
              decoration:
                  const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              items: const <
                  DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'unresolved',
                  child: Text('Unresolved'),
                ),
                DropdownMenuItem<String>(
                  value: 'resolved',
                  child: Text('Resolved'),
                ),
                DropdownMenuItem<String>(
                  value: 'all',
                  child: Text('All'),
                ),
              ],
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _anomalyFilter = value;
                });
              },
            ),
          ),
          child: visible.isEmpty
              ? const AdminEmptyState(
                  icon:
                      Icons.verified_outlined,
                  title: 'No anomalies',
                  message:
                      'No records match the selected status.',
                )
              : Column(
                  children: <Widget>[
                    for (int index = 0;
                        index < visible.length;
                        index++) ...<Widget>[
                      _AnomalyTile(
                        anomaly: visible[index],
                        processing:
                            _processingAnomalyId ==
                                visible[index].id,
                        onResolve: () {
                          _resolveAnomaly(
                            visible[index],
                          );
                        },
                      ),
                      if (index !=
                          visible.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
  });

  final AdminSessionSummary session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 15,
      ),
      child: Row(
        children: <Widget>[
          const CircleAvatar(
            backgroundColor:
                Color(0xFFECFDF3),
            child: Icon(
              Icons.devices_outlined,
              color: Color(0xFF039855),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.fullName,
                  style: const TextStyle(
                    color:
                        Color(0xFF101828),
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${adminFormatLabel(session.role)} • '
                  '${adminFormatLabel(session.platform)} • '
                  '${adminTimeAgo(session.lastActiveAt)}',
                  style: const TextStyle(
                    color:
                        Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const AdminStatusChip(
            status: 'active',
          ),
        ],
      ),
    );
  }
}

class _AnomalyTile extends StatelessWidget {
  const _AnomalyTile({
    required this.anomaly,
    required this.processing,
    required this.onResolve,
  });

  final AdminAnomalySummary anomaly;
  final bool processing;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final Color severityColor =
        adminHealthColor(
      anomaly.severity,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 15,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.warning_amber_rounded,
                color: severityColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  anomaly.title,
                  style: const TextStyle(
                    color:
                        Color(0xFF101828),
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
              AdminStatusChip(
                status: anomaly.status,
              ),
            ],
          ),
          if (anomaly.description
              .isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              anomaly.description,
              style: const TextStyle(
                color: Color(0xFF667085),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Severity: ${adminFormatLabel(anomaly.severity)} • '
            'Occurrences: ${anomaly.occurrenceCount} • '
            '${adminTimeAgo(anomaly.detectedAt)}',
            style: const TextStyle(
              color: Color(0xFF98A2B3),
              fontSize: 11,
            ),
          ),
          if (anomaly.isUnresolved) ...<Widget>[
            const SizedBox(height: 11),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed:
                    processing ? null : onResolve,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF039855),
                  foregroundColor:
                      Colors.white,
                ),
                icon: processing
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons
                            .check_circle_outline,
                        size: 18,
                      ),
                label: Text(
                  processing
                      ? 'Resolving'
                      : 'Resolve',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
