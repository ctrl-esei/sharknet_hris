import 'package:flutter/material.dart';

import '../../services/admin_dashboard_service.dart';
import 'admin_dashboard_widgets.dart';

class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() =>
      _AdminAuditScreenState();
}

class _AdminAuditScreenState
    extends State<AdminAuditScreen> {
  final AdminDashboardService _service =
      AdminDashboardService();

  final TextEditingController _searchController =
      TextEditingController();

  String _searchText = '';
  String _categoryFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminActivityItem> _filter(
    List<AdminActivityItem> items,
  ) {
    return items.where(
      (AdminActivityItem item) {
        final bool categoryMatches =
            _categoryFilter == 'all' ||
                item.category ==
                    _categoryFilter;

        final String searchable =
            '${item.title} '
                    '${item.description} '
                    '${item.action} '
                    '${item.performedByName} '
                    '${item.targetId}'
                .toLowerCase();

        final bool searchMatches =
            _searchText.isEmpty ||
                searchable.contains(
                  _searchText,
                );

        return categoryMatches &&
            searchMatches;
      },
    ).toList();
  }

  void _showDetails(
    AdminActivityItem item,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (
        BuildContext context,
      ) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.48,
          maxChildSize: 0.92,
          builder: (
            BuildContext context,
            ScrollController controller,
          ) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius:
                    BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: ListView(
                controller: controller,
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  28,
                ),
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFD0D5DD,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Audit Event Details',
                    style: TextStyle(
                      color:
                          Color(0xFF101828),
                      fontSize: 22,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AuditDetailsCard(
                    children: <Widget>[
                      _AuditDetailRow(
                        label: 'Title',
                        value: item.title,
                      ),
                      _AuditDetailRow(
                        label: 'Action',
                        value: adminFormatLabel(
                          item.action,
                        ),
                      ),
                      _AuditDetailRow(
                        label: 'Category',
                        value: adminFormatLabel(
                          item.category,
                        ),
                      ),
                      _AuditDetailRow(
                        label: 'Performed By',
                        value:
                            item.performedByName,
                      ),
                      _AuditDetailRow(
                        label: 'Role',
                        value: adminFormatLabel(
                          item.performedByRole,
                        ),
                      ),
                      _AuditDetailRow(
                        label: 'Target ID',
                        value:
                            item.targetId.isEmpty
                                ? 'Not available'
                                : item.targetId,
                      ),
                      _AuditDetailRow(
                        label: 'Severity',
                        value: adminFormatLabel(
                          item.severity,
                        ),
                      ),
                      _AuditDetailRow(
                        label: 'Created',
                        value:
                            adminFormatDateTime(
                          item.createdAt,
                        ),
                      ),
                      _AuditDetailRow(
                        label: 'Description',
                        value:
                            item.description.isEmpty
                                ? 'No description'
                                : item.description,
                        showDivider: false,
                      ),
                    ],
                  ),
                  if (item.metadata
                      .isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    _AuditDetailsCard(
                      children: <Widget>[
                        const Text(
                          'Metadata',
                          style: TextStyle(
                            color:
                                Color(0xFF101828),
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          item.metadata.toString(),
                          style: const TextStyle(
                            color:
                                Color(0xFF475467),
                            height: 1.45,
                            fontFamily:
                                'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF2F6FC),
      child: SafeArea(
        bottom: false,
        child: StreamBuilder<
            List<AdminActivityItem>>(
          stream: _service.watchAuditLogs(),
          builder: (
            BuildContext context,
            AsyncSnapshot<
                    List<AdminActivityItem>>
                snapshot,
          ) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding:
                      const EdgeInsets.all(24),
                  child: Text(
                    'Unable to load audit logs: '
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            final List<AdminActivityItem> all =
                snapshot.data!;

            final List<AdminActivityItem> visible =
                _filter(all);

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                18,
                20,
                18,
                100,
              ),
              children: <Widget>[
                const Text(
                  'Audit Trail',
                  style: TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 25,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Review actions recorded throughout the HRIS.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _buildFilters(),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Audit Events',
                        style: TextStyle(
                          color:
                              Color(0xFF101828),
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${visible.length} event${visible.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color:
                            Color(0xFF667085),
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                if (visible.isEmpty)
                  const AdminSectionCard(
                    title: 'Activity',
                    child: AdminEmptyState(
                      icon:
                          Icons.history_outlined,
                      title: 'No audit events',
                      message:
                          'Logged actions will appear here.',
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                      border: Border.all(
                        color:
                            const Color(
                          0xFFE4E7EC,
                        ),
                      ),
                    ),
                    clipBehavior:
                        Clip.antiAlias,
                    child: Column(
                      children: <Widget>[
                        for (int index = 0;
                            index <
                                visible.length;
                            index++) ...<Widget>[
                          AdminActivityTile(
                            item:
                                visible[index],
                            onTap: () {
                              _showDetails(
                                visible[index],
                              );
                            },
                          ),
                          if (index !=
                              visible.length - 1)
                            const Divider(
                              height: 1,
                            ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        children: <Widget>[
          TextField(
            controller: _searchController,
            onChanged: (String value) {
              setState(() {
                _searchText =
                    value.trim().toLowerCase();
              });
            },
            decoration: const InputDecoration(
              labelText: 'Search Audit Logs',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue:
                _categoryFilter,
            isExpanded: true,
            decoration:
                const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(
                Icons.category_outlined,
              ),
              border: OutlineInputBorder(),
            ),
            items: const <
                DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'all',
                child:
                    Text('All Categories'),
              ),
              DropdownMenuItem<String>(
                value: 'users',
                child: Text('Users'),
              ),
              DropdownMenuItem<String>(
                value: 'auth',
                child:
                    Text('Authentication'),
              ),
              DropdownMenuItem<String>(
                value: 'attendance',
                child: Text('Attendance'),
              ),
              DropdownMenuItem<String>(
                value: 'leave',
                child: Text('Leave'),
              ),
              DropdownMenuItem<String>(
                value: 'payroll',
                child: Text('Payroll'),
              ),
              DropdownMenuItem<String>(
                value: 'system',
                child: Text('System'),
              ),
            ],
            onChanged: (String? value) {
              if (value == null) {
                return;
              }

              setState(() {
                _categoryFilter = value;
              });
            },
          ),
        ],
      ),
    );
  }
}

class _AuditDetailsCard
    extends StatelessWidget {
  const _AuditDetailsCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _AuditDetailRow extends StatelessWidget {
  const _AuditDetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 9,
      ),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(
                bottom: BorderSide(
                  color: Color(0xFFF2F4F7),
                ),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF101828),
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
