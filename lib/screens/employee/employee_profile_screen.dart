import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({
    required this.employeeId,
    required this.fullName,
    required this.position,
    super.key,
    this.onLogout,
  });

  final String employeeId;
  final String fullName;
  final String position;
  final VoidCallback? onLogout;

  @override
  State<EmployeeProfileScreen> createState() =>
      _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState
    extends State<EmployeeProfileScreen> {
  late final Future<
          DocumentReference<Map<String, dynamic>>>
      _employeeReferenceFuture;

  @override
  void initState() {
    super.initState();
    _employeeReferenceFuture =
        _resolveEmployeeReference();
  }

  Future<DocumentReference<Map<String, dynamic>>>
      _resolveEmployeeReference() async {
    final FirebaseFirestore firestore =
        FirebaseFirestore.instance;

    final String suppliedId =
        widget.employeeId.trim();

    if (suppliedId.isEmpty) {
      throw StateError(
        'The signed-in account has no employee ID.',
      );
    }

    final DocumentReference<Map<String, dynamic>>
        directReference =
        firestore.collection('employee').doc(suppliedId);

    final DocumentSnapshot<Map<String, dynamic>>
        directSnapshot =
        await directReference.get();

    if (directSnapshot.exists) {
      return directReference;
    }

    final QuerySnapshot<Map<String, dynamic>>
        employeeIdQuery = await firestore
            .collection('employee')
            .where(
              'employeeId',
              isEqualTo: suppliedId,
            )
            .limit(1)
            .get();

    if (employeeIdQuery.docs.isNotEmpty) {
      return employeeIdQuery.docs.first.reference;
    }

    final QuerySnapshot<Map<String, dynamic>>
        employeeCodeQuery = await firestore
            .collection('employee')
            .where(
              'employeeCode',
              isEqualTo: suppliedId,
            )
            .limit(1)
            .get();

    if (employeeCodeQuery.docs.isNotEmpty) {
      return employeeCodeQuery.docs.first.reference;
    }

    throw StateError(
      'No employee record matches "$suppliedId".',
    );
  }

  Future<String> _resolveDepartmentName(
    Map<String, dynamic> employeeData,
  ) async {
    final String directName =
        _text(
          employeeData['departmentName'],
          fallback: '',
        );

    if (directName.isNotEmpty) {
      return directName;
    }

    final dynamic departmentValue =
        employeeData['departmentId'];

    if (departmentValue is DocumentReference) {
      try {
        final DocumentSnapshot<Object?> snapshot =
            await departmentValue.get();

        final Object? rawData = snapshot.data();

        if (rawData is Map<String, dynamic>) {
          return _text(
            rawData['departmentName'] ??
                rawData['name'],
            fallback: departmentValue.id,
          );
        }

        if (rawData is Map) {
          final Map<String, dynamic> data =
              rawData.map<String, dynamic>(
            (
              dynamic key,
              dynamic value,
            ) =>
                MapEntry<String, dynamic>(
              key.toString(),
              value,
            ),
          );

          return _text(
            data['departmentName'] ??
                data['name'],
            fallback: departmentValue.id,
          );
        }

        return departmentValue.id;
      } catch (_) {
        return departmentValue.id;
      }
    }

    final String raw =
        _text(
          departmentValue,
          fallback: '',
        );

    if (raw.isEmpty) {
      return 'Not assigned';
    }

    return raw.contains('/')
        ? raw.split('/').last
        : raw;
  }

  Future<void> _logout() async {
    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }

    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF2F6FC),
      child: SafeArea(
        bottom: false,
        child: FutureBuilder<
            DocumentReference<Map<String, dynamic>>>(
          future: _employeeReferenceFuture,
          builder: (
            BuildContext context,
            AsyncSnapshot<
                    DocumentReference<
                        Map<String, dynamic>>>
                employeeReferenceSnapshot,
          ) {
            if (employeeReferenceSnapshot
                    .connectionState !=
                ConnectionState.done) {
              return const _ProfileLoadingState();
            }

            if (employeeReferenceSnapshot.hasError ||
                !employeeReferenceSnapshot.hasData) {
              return _ProfileErrorState(
                message:
                    employeeReferenceSnapshot.error
                            ?.toString() ??
                        'Unable to resolve your employee record.',
              );
            }

            final DocumentReference<
                    Map<String, dynamic>>
                employeeReference =
                employeeReferenceSnapshot.data!;

            return StreamBuilder<
                DocumentSnapshot<Map<String, dynamic>>>(
              stream: employeeReference.snapshots(),
              builder: (
                BuildContext context,
                AsyncSnapshot<
                        DocumentSnapshot<
                            Map<String, dynamic>>>
                    employeeSnapshot,
              ) {
                if (employeeSnapshot.hasError) {
                  return _ProfileErrorState(
                    message:
                        'Unable to load your profile: '
                        '${employeeSnapshot.error}',
                  );
                }

                if (!employeeSnapshot.hasData) {
                  return const _ProfileLoadingState();
                }

                if (!employeeSnapshot.data!.exists) {
                  return const _ProfileErrorState(
                    message:
                        'Your employee record no longer exists.',
                  );
                }

                final Map<String, dynamic> employeeData =
                    employeeSnapshot.data!.data() ??
                        <String, dynamic>{};

                final User? currentUser =
                    FirebaseAuth.instance.currentUser;

                final Stream<
                        DocumentSnapshot<
                            Map<String, dynamic>>>
                    userStream = currentUser == null
                        ? const Stream<
                            DocumentSnapshot<
                                Map<String,
                                    dynamic>>>.empty()
                        : FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser.uid)
                            .snapshots();

                return StreamBuilder<
                    DocumentSnapshot<Map<String, dynamic>>>(
                  stream: userStream,
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<
                            DocumentSnapshot<
                                Map<String, dynamic>>>
                        userSnapshot,
                  ) {
                    final Map<String, dynamic> userData =
                        userSnapshot.data?.data() ??
                            <String, dynamic>{};

                    final String currentUserId =
                        currentUser?.uid ?? '';

                    final Stream<
                            QuerySnapshot<
                                Map<String, dynamic>>>
                        notificationStream =
                        currentUserId.isEmpty
                            ? const Stream<
                                QuerySnapshot<
                                    Map<String,
                                        dynamic>>>.empty()
                            : FirebaseFirestore.instance
                                .collection(
                                  'notifications',
                                )
                                .where(
                                  'userId',
                                  isEqualTo:
                                      currentUserId,
                                )
                                .snapshots();

                    return StreamBuilder<
                        QuerySnapshot<
                            Map<String, dynamic>>>(
                      stream: notificationStream,
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<
                                QuerySnapshot<
                                    Map<String,
                                        dynamic>>>
                            notificationSnapshot,
                      ) {
                        final int unreadNotifications =
                            notificationSnapshot
                                    .data?.docs
                                    .where(
                                      (
                                        QueryDocumentSnapshot<
                                                Map<String,
                                                    dynamic>>
                                            document,
                                      ) =>
                                          document
                                                  .data()[
                                              'isRead'] !=
                                          true,
                                    )
                                    .length ??
                                0;

                        return FutureBuilder<String>(
                          future: _resolveDepartmentName(
                            employeeData,
                          ),
                          builder: (
                            BuildContext context,
                            AsyncSnapshot<String>
                                departmentSnapshot,
                          ) {
                            final String departmentName =
                                departmentSnapshot.data ??
                                    'Loading...';

                            return _buildProfile(
                              employeeReference:
                                  employeeReference,
                              employeeData:
                                  employeeData,
                              userData: userData,
                              departmentName:
                                  departmentName,
                              unreadNotifications:
                                  unreadNotifications,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfile({
    required DocumentReference<Map<String, dynamic>>
        employeeReference,
    required Map<String, dynamic> employeeData,
    required Map<String, dynamic> userData,
    required String departmentName,
    required int unreadNotifications,
  }) {
    final String fullName =
        _text(
          employeeData['fullName'],
          fallback: widget.fullName,
        );

    final String employeeCode =
        _text(
          employeeData['employeeId'] ??
              employeeData['employeeCode'],
          fallback: employeeReference.id,
        ).toUpperCase();

    final String position =
        _text(
          employeeData['position'],
          fallback: widget.position,
        );

    final String employmentStatus =
        _text(
          employeeData['employmentStatus'],
          fallback: 'active',
        ).toLowerCase();

    final String employmentType =
        _text(
          employeeData['employmentType'],
          fallback: 'Not specified',
        );

    final String salaryType =
        _text(
          employeeData['salaryType'],
          fallback: 'monthly',
        ).toLowerCase();

    final double salaryRate =
        _number(employeeData['salaryRate']);

    final double explicitDailyRate =
        _number(employeeData['dailyRate']);

    final double workDaysPerMonth =
        _number(
      employeeData['workDaysPerMonth'] ??
          employeeData['monthlyWorkDays'],
    );

    final double? dailyRate =
        explicitDailyRate > 0
            ? explicitDailyRate
            : salaryType == 'monthly' &&
                    salaryRate > 0 &&
                    workDaysPerMonth > 0
                ? salaryRate /
                    workDaysPerMonth
                : salaryType == 'daily' &&
                        salaryRate > 0
                    ? salaryRate
                    : null;

    final DateTime? dateHired =
        _date(
      employeeData['dateHired'] ??
          employeeData['hiredDate'],
    );

    final String email =
        _text(
          employeeData['email'] ??
              userData['email'] ??
              FirebaseAuth.instance.currentUser?.email,
          fallback: 'Not provided',
        );

    final String phone =
        _text(
          employeeData['phoneNumber'] ??
              employeeData['contactNumber'] ??
              employeeData['mobileNumber'],
          fallback: 'Not provided',
        );

    final String address =
        _text(
          employeeData['address'] ??
              employeeData['homeAddress'],
          fallback: 'Not provided',
        );

    final String workSchedule =
        _text(
          employeeData['workSchedule'] ??
              employeeData['scheduleName'],
          fallback: 'Not assigned',
        );

    final String profilePhotoUrl =
        _text(
          employeeData['profilePhotoUrl'] ??
              employeeData['photoUrl'],
          fallback: '',
        );

    final bool faceRegistered =
        employeeData['faceRegistered'] == true;

    final bool faceActive =
        employeeData['faceActive'] != false &&
            faceRegistered;

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _buildHeader(
            fullName: fullName,
            position: position,
            employeeCode: employeeCode,
            unreadNotifications:
                unreadNotifications,
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
                _buildIdentityCard(
                  fullName: fullName,
                  position: position,
                  employmentStatus:
                      employmentStatus,
                  profilePhotoUrl:
                      profilePhotoUrl,
                ),
                const SizedBox(height: 18),
                _buildEmploymentCard(
                  employeeCode: employeeCode,
                  departmentName:
                      departmentName,
                  position: position,
                  salaryType: salaryType,
                  salaryRate: salaryRate,
                  dailyRate: dailyRate,
                  employmentType:
                      employmentType,
                  dateHired: dateHired,
                ),
                const SizedBox(height: 18),
                _buildContactCard(
                  email: email,
                  phone: phone,
                  address: address,
                ),
                const SizedBox(height: 18),
                _buildWorkAndSecurityCard(
                  workSchedule: workSchedule,
                  faceRegistered:
                      faceRegistered,
                  faceActive: faceActive,
                ),
                const SizedBox(height: 18),
                _buildReadOnlyNotice(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({
    required String fullName,
    required String position,
    required String employeeCode,
    required int unreadNotifications,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        22,
        20,
        22,
        28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF2455DB),
            Color(0xFF3D7DF3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${_greeting(DateTime.now())},',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _firstName(fullName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight:
                        FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$position • $employeeCode',
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD8E7FF),
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              _ProfileHeaderButton(
                icon:
                    Icons.notifications_none_rounded,
                onTap: () {
                  _showInfo(
                    unreadNotifications == 0
                        ? 'You have no unread notifications.'
                        : 'You have $unreadNotifications unread notification${unreadNotifications == 1 ? '' : 's'}.',
                  );
                },
              ),
              if (unreadNotifications > 0)
                Positioned(
                  top: -7,
                  right: -4,
                  child: _ProfileNotificationBadge(
                    count: unreadNotifications,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          _ProfileHeaderButton(
            icon: Icons.logout_rounded,
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard({
    required String fullName,
    required String position,
    required String employmentStatus,
    required String profilePhotoUrl,
  }) {
    final bool active =
        employmentStatus == 'active';

    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        28,
        20,
        28,
      ),
      decoration: _cardDecoration(),
      child: Column(
        children: <Widget>[
          _ProfileAvatar(
            fullName: fullName,
            photoUrl: profilePhotoUrl,
          ),
          const SizedBox(height: 18),
          Text(
            fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            position,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF98A2B3),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFF2F4F7),
              borderRadius:
                  BorderRadius.circular(30),
              border: Border.all(
                color: active
                    ? const Color(0xFFD1E0FF)
                    : const Color(0xFFE4E7EC),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF53B1FD)
                        : const Color(0xFF98A2B3),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  active
                      ? 'Active Employee'
                      : _formatLabel(
                          employmentStatus,
                        ),
                  style: TextStyle(
                    color: active
                        ? const Color(0xFF155EEF)
                        : const Color(0xFF475467),
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmploymentCard({
    required String employeeCode,
    required String departmentName,
    required String position,
    required String salaryType,
    required double salaryRate,
    required double? dailyRate,
    required String employmentType,
    required DateTime? dateHired,
  }) {
    final String salaryLabel;

    switch (salaryType) {
      case 'daily':
        salaryLabel = 'Daily Salary';
        break;

      case 'hourly':
        salaryLabel = 'Hourly Salary';
        break;

      default:
        salaryLabel = 'Monthly Salary';
    }

    return _ProfileSectionCard(
      title: 'Employment Information',
      icon: Icons.badge_outlined,
      children: <Widget>[
        _ProfileInformationRow(
          label: 'Employee ID',
          value: employeeCode,
          valueMonospace: true,
        ),
        _ProfileInformationRow(
          label: 'Department',
          value: departmentName,
        ),
        _ProfileInformationRow(
          label: 'Position',
          value: position,
        ),
        _ProfileInformationRow(
          label: salaryLabel,
          value: salaryRate > 0
              ? _formatCurrency(salaryRate)
              : 'Not set',
          valueColor: salaryRate > 0
              ? const Color(0xFF00A63E)
              : null,
          valueMonospace: salaryRate > 0,
        ),
        _ProfileInformationRow(
          label: 'Daily Rate',
          value: dailyRate == null
              ? 'Not set'
              : _formatCurrency(dailyRate),
          valueMonospace: dailyRate != null,
        ),
        _ProfileInformationRow(
          label: 'Employment Type',
          value: _formatLabel(
            employmentType,
          ),
        ),
        _ProfileInformationRow(
          label: 'Date Hired',
          value: _formatLongDate(dateHired),
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildContactCard({
    required String email,
    required String phone,
    required String address,
  }) {
    return _ProfileSectionCard(
      title: 'Contact Information',
      icon: Icons.contact_mail_outlined,
      children: <Widget>[
        _ProfileInformationRow(
          label: 'Email Address',
          value: email,
        ),
        _ProfileInformationRow(
          label: 'Phone Number',
          value: phone,
        ),
        _ProfileInformationRow(
          label: 'Home Address',
          value: address,
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildWorkAndSecurityCard({
    required String workSchedule,
    required bool faceRegistered,
    required bool faceActive,
  }) {
    return _ProfileSectionCard(
      title: 'Work & Biometric Status',
      icon: Icons.security_outlined,
      children: <Widget>[
        _ProfileInformationRow(
          label: 'Work Schedule',
          value: workSchedule,
        ),
        _ProfileInformationRow(
          label: 'Face Registered',
          value: faceRegistered ? 'Yes' : 'No',
          valueColor: faceRegistered
              ? const Color(0xFF039855)
              : const Color(0xFFD92D20),
        ),
        _ProfileInformationRow(
          label: 'Face Attendance',
          value: faceActive
              ? 'Active'
              : 'Inactive',
          valueColor: faceActive
              ? const Color(0xFF039855)
              : const Color(0xFFD92D20),
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildReadOnlyNotice() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD7E7FF),
        ),
      ),
      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF2979FF),
            size: 25,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Profile information is read-only and can only be updated by HR. Contact your HR Manager to request any correction or change.',
              style: TextStyle(
                color: Color(0xFF155EEF),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: const Color(0xFFE4E7EC),
      ),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x120F172A),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    );
  }

  void _showInfo(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.fullName,
    required this.photoUrl,
  });

  final String fullName;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      height: 145,
      decoration: BoxDecoration(
        color: const Color(0xFFDCEAFF),
        borderRadius:
            BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl.isEmpty
          ? _buildPlaceholder()
          : Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) {
                return _buildPlaceholder();
              },
            ),
    );
  }

  Widget _buildPlaceholder() {
    final String initials =
        _initials(fullName);

    if (initials.isNotEmpty) {
      return Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Color(0xFF2979FF),
            fontSize: 42,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return const Icon(
      Icons.person_outline_rounded,
      color: Color(0xFF2979FF),
      size: 76,
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              18,
              16,
              18,
              14,
            ),
            color: const Color(0xFFF9FAFB),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  color: const Color(0xFF2979FF),
                  size: 22,
                ),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileInformationRow
    extends StatelessWidget {
  const _ProfileInformationRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueMonospace = false,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool valueMonospace;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
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
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF98A2B3),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ??
                    const Color(0xFF101828),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFamily:
                    valueMonospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderButton
    extends StatelessWidget {
  const _ProfileHeaderButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(
        alpha: 0.18,
      ),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _ProfileNotificationBadge
    extends StatelessWidget {
  const _ProfileNotificationBadge({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final String label =
        count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(
        minWidth: 25,
        minHeight: 25,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
      ),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFFF3347),
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProfileLoadingState
    extends StatelessWidget {
  const _ProfileLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _ProfileErrorState
    extends StatelessWidget {
  const _ProfileErrorState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 520,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFDA29B),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                color: Color(0xFFD92D20),
                size: 58,
              ),
              const SizedBox(height: 14),
              const Text(
                'Unable to Load Profile',
                style: TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _greeting(DateTime value) {
  if (value.hour < 12) {
    return 'Good morning';
  }

  if (value.hour < 18) {
    return 'Good afternoon';
  }

  return 'Good evening';
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
      ? 'Employee'
      : parts.first;
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
    return '';
  }

  if (parts.length == 1) {
    return parts.first[0].toUpperCase();
  }

  return '${parts.first[0]}${parts.last[0]}'
      .toUpperCase();
}

String _formatLabel(String value) {
  if (value.trim().isEmpty) {
    return 'Not specified';
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

String _formatLongDate(DateTime? value) {
  if (value == null) {
    return 'Not provided';
  }

  const List<String> months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${months[value.month - 1]} '
      '${value.day}, ${value.year}';
}

String _formatCurrency(double value) {
  final String fixed =
      value.toStringAsFixed(2);

  final List<String> parts =
      fixed.split('.');

  final String whole = parts.first;
  final StringBuffer grouped =
      StringBuffer();

  for (int index = 0;
      index < whole.length;
      index++) {
    final int remaining =
        whole.length - index;

    grouped.write(whole[index]);

    if (remaining > 1 &&
        remaining % 3 == 1) {
      grouped.write(',');
    }
  }

  return '₱${grouped.toString()}.${parts.last}';
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

String _text(
  dynamic value, {
  required String fallback,
}) {
  final String text =
      value?.toString().trim() ?? '';

  return text.isEmpty
      ? fallback
      : text;
}
