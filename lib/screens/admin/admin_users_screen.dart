import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/admin_dashboard_service.dart';
import '../../services/audit_log_service.dart';
import 'admin_dashboard_widgets.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() =>
      _AdminUsersScreenState();
}

class _AdminUsersScreenState
    extends State<AdminUsersScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  final AdminDashboardService _service =
      AdminDashboardService();

  final AuditLogService _auditLogService =
      AuditLogService();

  String _searchText = '';
  String _roleFilter = 'all';
  String _statusFilter = 'all';
  String? _processingUserId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminUserSummary> _filteredUsers(
    List<AdminUserSummary> users,
  ) {
    return users.where(
      (AdminUserSummary user) {
        final bool roleMatches =
            _roleFilter == 'all' ||
                user.role == _roleFilter;

        final bool statusMatches =
            _statusFilter == 'all' ||
                user.accountStatus ==
                    _statusFilter;

        final String searchable =
            '${user.fullName} '
                    '${user.email} '
                    '${user.employeeId}'
                .toLowerCase();

        final bool searchMatches =
            _searchText.isEmpty ||
                searchable.contains(
                  _searchText,
                );

        return roleMatches &&
            statusMatches &&
            searchMatches;
      },
    ).toList();
  }

  Future<void> _editUser(
    AdminUserSummary user,
  ) async {
    final String currentUserId =
        FirebaseAuth.instance.currentUser?.uid ??
            '';

    String selectedRole = user.role;
    String selectedStatus =
        user.accountStatus;

    final Map<String, String>? result =
        await showModalBottomSheet<
            Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (
        BuildContext bottomSheetContext,
      ) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            void Function(
              void Function(),
            ) setSheetState,
          ) {
            return Padding(
              padding:
                  MediaQuery.viewInsetsOf(context),
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  28,
                ),
                decoration:
                    const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius:
                      BorderRadius.only(
                    topLeft:
                        Radius.circular(24),
                    topRight:
                        Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
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
                        'Update User Account',
                        style: TextStyle(
                          color:
                              Color(0xFF101828),
                          fontSize: 22,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${user.fullName} • '
                        '${user.email}',
                        style: const TextStyle(
                          color:
                              Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<
                          String>(
                        initialValue:
                            selectedRole,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'User Role',
                          prefixIcon: Icon(
                            Icons
                                .admin_panel_settings_outlined,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                        items: const <
                            DropdownMenuItem<
                                String>>[
                          DropdownMenuItem<
                              String>(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                          DropdownMenuItem<
                              String>(
                            value: 'hr',
                            child: Text('HR'),
                          ),
                          DropdownMenuItem<
                              String>(
                            value: 'employee',
                            child:
                                Text('Employee'),
                          ),
                        ],
                        onChanged:
                            user.id == currentUserId
                                ? null
                                : (String? value) {
                                    if (value ==
                                        null) {
                                      return;
                                    }

                                    setSheetState(
                                      () {
                                        selectedRole =
                                            value;
                                      },
                                    );
                                  },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<
                          String>(
                        initialValue:
                            selectedStatus,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Account Status',
                          prefixIcon: Icon(
                            Icons
                                .verified_user_outlined,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                        items: const <
                            DropdownMenuItem<
                                String>>[
                          DropdownMenuItem<
                              String>(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem<
                              String>(
                            value: 'inactive',
                            child:
                                Text('Inactive'),
                          ),
                          DropdownMenuItem<
                              String>(
                            value: 'suspended',
                            child:
                                Text('Suspended'),
                          ),
                        ],
                        onChanged:
                            user.id == currentUserId
                                ? null
                                : (String? value) {
                                    if (value ==
                                        null) {
                                      return;
                                    }

                                    setSheetState(
                                      () {
                                        selectedStatus =
                                            value;
                                      },
                                    );
                                  },
                      ),
                      if (user.id ==
                          currentUserId) ...<Widget>[
                        const SizedBox(height: 13),
                        const Text(
                          'Your own admin role and status are protected from this screen.',
                          style: TextStyle(
                            color:
                                Color(0xFFB54708),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed:
                            user.id ==
                                    currentUserId
                                ? null
                                : () {
                                    Navigator.of(
                                      bottomSheetContext,
                                    ).pop(
                                      <String,
                                          String>{
                                        'role':
                                            selectedRole,
                                        'status':
                                            selectedStatus,
                                      },
                                    );
                                  },
                        style:
                            FilledButton.styleFrom(
                          backgroundColor:
                              const Color(
                            0xFF9810FA,
                          ),
                          foregroundColor:
                              Colors.white,
                          minimumSize:
                              const Size
                                  .fromHeight(
                            54,
                          ),
                        ),
                        icon: const Icon(
                          Icons.save_outlined,
                        ),
                        label: const Text(
                          'Save Account Changes',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    final String newRole =
        result['role'] ?? user.role;
    final String newStatus =
        result['status'] ??
            user.accountStatus;

    if (newRole == user.role &&
        newStatus == user.accountStatus) {
      return;
    }

    setState(() {
      _processingUserId = user.id;
    });

    try {
      final Map<String, dynamic> actor =
          await _auditLogService
              .currentActorSnapshot();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .update(
        <String, dynamic>{
          'userRole': newRole,
          'accountStatus': newStatus,
          'updatedAt':
              FieldValue.serverTimestamp(),
          'updatedBy': actor,
        },
      );

      await _auditLogService.logUserUpdate(
        targetUserId: user.id,
        targetName: user.fullName,
        oldRole: user.role,
        newRole: newRole,
        oldStatus: user.accountStatus,
        newStatus: newStatus,
      );

      _showMessage(
        'User account updated.',
        error: false,
      );
    } catch (error) {
      _showMessage(
        'Unable to update user: $error',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingUserId = null;
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
        child: StreamBuilder<
            List<AdminUserSummary>>(
          stream: _service.watchUsers(),
          builder: (
            BuildContext context,
            AsyncSnapshot<
                    List<AdminUserSummary>>
                snapshot,
          ) {
            if (snapshot.hasError) {
              return _UsersErrorState(
                message:
                    'Unable to load users: '
                    '${snapshot.error}',
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            final List<AdminUserSummary> users =
                snapshot.data!;

            final List<AdminUserSummary>
                filteredUsers =
                _filteredUsers(users);

            final int activeCount = users
                .where(
                  (
                    AdminUserSummary user,
                  ) =>
                      user.isActive,
                )
                .length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                18,
                20,
                18,
                100,
              ),
              children: <Widget>[
                const Text(
                  'User Management',
                  style: TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 25,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Review user roles and Firestore account access status.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFAEB),
                    borderRadius:
                        BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          const Color(0xFFFEC84B),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.info_outline,
                        color:
                            Color(0xFFB54708),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Changing accountStatus controls access only when your AuthGate checks the users document. It does not disable the Firebase Authentication account itself.',
                          style: TextStyle(
                            color:
                                Color(0xFFB54708),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _SmallSummaryCard(
                        label: 'Total Users',
                        value:
                            users.length.toString(),
                        color:
                            const Color(0xFF9810FA),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SmallSummaryCard(
                        label: 'Active Users',
                        value:
                            activeCount.toString(),
                        color:
                            const Color(0xFF039855),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFilters(),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Accounts',
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
                      '${filteredUsers.length} user${filteredUsers.length == 1 ? '' : 's'}',
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
                if (filteredUsers.isEmpty)
                  const AdminEmptyState(
                    icon:
                        Icons.group_off_outlined,
                    title: 'No users found',
                    message:
                        'Change the search or account filters.',
                  )
                else
                  ...filteredUsers.map(
                    (
                      AdminUserSummary user,
                    ) =>
                        Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 11,
                      ),
                      child: _UserCard(
                        user: user,
                        processing:
                            _processingUserId ==
                                user.id,
                        onEdit: () {
                          _editUser(user);
                        },
                      ),
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
              labelText: 'Search Users',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child:
                    DropdownButtonFormField<String>(
                  initialValue:
                      _roleFilter,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(
                    labelText: 'Role',
                    border:
                        OutlineInputBorder(),
                  ),
                  items: const <
                      DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'all',
                      child: Text('All'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'admin',
                      child: Text('Admin'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'hr',
                      child: Text('HR'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'employee',
                      child:
                          Text('Employee'),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _roleFilter = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    DropdownButtonFormField<String>(
                  initialValue:
                      _statusFilter,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(
                    labelText: 'Status',
                    border:
                        OutlineInputBorder(),
                  ),
                  items: const <
                      DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'all',
                      child: Text('All'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'active',
                      child: Text('Active'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'inactive',
                      child:
                          Text('Inactive'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'suspended',
                      child:
                          Text('Suspended'),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _statusFilter = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.processing,
    required this.onEdit,
  });

  final AdminUserSummary user;
  final bool processing;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 25,
            backgroundColor:
                const Color(0xFFF9F0FF),
            child: Text(
              _initials(user.fullName),
              style: const TextStyle(
                color: Color(0xFF9810FA),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user.fullName,
                  style: const TextStyle(
                    color:
                        Color(0xFF101828),
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.email.isEmpty
                      ? 'No email'
                      : user.email,
                  style: const TextStyle(
                    color:
                        Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: <Widget>[
                    AdminStatusChip(
                      status: user.role,
                    ),
                    AdminStatusChip(
                      status:
                          user.accountStatus,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          processing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : IconButton(
                  onPressed: onEdit,
                  tooltip: 'Edit account',
                  icon: const Icon(
                    Icons.edit_outlined,
                  ),
                ),
        ],
      ),
    );
  }
}

class _SmallSummaryCard extends StatelessWidget {
  const _SmallSummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.07,
        ),
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersErrorState extends StatelessWidget {
  const _UsersErrorState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

String _initials(String fullName) {
  final List<String> parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where(
        (String part) => part.isNotEmpty,
      )
      .toList();

  if (parts.isEmpty) {
    return '?';
  }

  if (parts.length == 1) {
    return parts.first[0].toUpperCase();
  }

  return '${parts.first[0]}${parts.last[0]}'
      .toUpperCase();
}
