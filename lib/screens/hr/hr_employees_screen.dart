import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'edit_employee_screen.dart';
import 'add_employee_screen.dart';
import 'face_attendance_screen.dart';
import 'register_face_screen.dart';

class HrEmployeesScreen extends StatefulWidget {
  const HrEmployeesScreen({super.key});

  @override
  State<HrEmployeesScreen> createState() => _HrEmployeesScreenState();
}

class _HrEmployeesScreenState extends State<HrEmployeesScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAddEmployee() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddEmployeeScreen()));
  }

  Future<void> _openFaceAttendance() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FaceAttendanceScreen()));
  }

  bool _matchesSearch(String employeeId, Map<String, dynamic> data) {
    if (_searchText.trim().isEmpty) {
      return true;
    }

    final query = _searchText.trim().toLowerCase();

    final fullName = data['fullName']?.toString().toLowerCase() ?? '';

    final position = data['position']?.toString().toLowerCase() ?? '';

    return employeeId.toLowerCase().contains(query) ||
        fullName.contains(query) ||
        position.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddEmployee,
        backgroundColor: const Color(0xFFF57C00),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Employee'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildSearchField(),
            const SizedBox(height: 18),
            Expanded(child: _buildEmployeeList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Employee Management',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202124),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Add employees, register faces, and manage attendance.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: _openFaceAttendance,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          icon: const Icon(Icons.face_retouching_natural),
          label: const Text('Face Attendance'),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchText = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search employee ID, name, or position',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchText.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchText = '';
                  });
                },
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFF57C00), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildEmployeeList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('employee')
          .orderBy('fullName')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MessageState(
            icon: Icons.error_outline,
            title: 'Unable to load employees',
            message: snapshot.error.toString(),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = snapshot.data?.docs ?? [];

        final filteredDocuments = documents.where((document) {
          return _matchesSearch(document.id, document.data());
        }).toList();

        if (documents.isEmpty) {
          return const _MessageState(
            icon: Icons.groups_outlined,
            title: 'No employees yet',
            message: 'Press Add Employee to create the first record.',
          );
        }

        if (filteredDocuments.isEmpty) {
          return const _MessageState(
            icon: Icons.search_off,
            title: 'No matching employee',
            message: 'Try a different search keyword.',
          );
        }

        return ListView.separated(
          itemCount: filteredDocuments.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final document = filteredDocuments[index];

            return _EmployeeCard(
              employeeId: document.id,
              data: document.data(),
            );
          },
        );
      },
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employeeId, required this.data});

  final String employeeId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final fullName = data['fullName']?.toString().trim().isNotEmpty == true
        ? data['fullName'].toString()
        : 'Unnamed Employee';

    final position = data['position']?.toString().trim().isNotEmpty == true
        ? data['position'].toString()
        : 'Position not assigned';

    final employmentStatus = data['employmentStatus']?.toString() ?? 'unknown';

    final employmentType =
        data['employmentType']?.toString() ?? 'Not specified';

    final bool faceRegistered = data['faceRegistered'] == true;

    final biometricStatus =
        data['biometricStatus']?.toString() ??
        (faceRegistered ? 'active' : 'not_enrolled');

    final departmentValue = data['departmentId'];

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(
                  0xFFF57C00,
                ).withValues(alpha: 0.12),
                child: Text(
                  _initials(fullName),
                  style: const TextStyle(
                    color: Color(0xFFF57C00),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      employeeId.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      position,
                      style: const TextStyle(color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 3),
                    if (departmentValue is DocumentReference)
                      _DepartmentName(departmentReference: departmentValue)
                    else
                      const Text(
                        'Department not assigned',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusChip(
                    text: employmentStatus,
                    active: employmentStatus.toLowerCase() == 'active',
                  ),
                  const SizedBox(height: 8),
                  _FaceStatusChip(
                    faceRegistered: faceRegistered,
                    biometricStatus: biometricStatus,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 13),
          const Divider(height: 1),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Employment: ${_formatValue(employmentType)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RegisterFaceScreen(
                        employeeId: employeeId,
                        fullName: fullName,
                      ),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: faceRegistered
                      ? const Color(0xFF455A64)
                      : const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                ),
                icon: Icon(
                  faceRegistered
                      ? Icons.face_retouching_natural
                      : Icons.add_a_photo_outlined,
                  size: 19,
                ),
                label: Text(faceRegistered ? 'Update Face' : 'Register Face'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          EditEmployeeScreen(employeeId: employeeId),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF04B0B),
                  side: const BorderSide(color: Color(0xFFF04B0B)),
                ),
                icon: const Icon(Icons.edit_outlined, size: 19),
                label: const Text('Edit Employee'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static String _formatValue(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class _DepartmentName extends StatelessWidget {
  const _DepartmentName({required this.departmentReference});

  final DocumentReference departmentReference;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: departmentReference.get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text(
            'Loading department...',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          );
        }

        final rawData = snapshot.data?.data();

        if (rawData is! Map<String, dynamic>) {
          return const Text(
            'Department unavailable',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          );
        }

        final departmentName =
            rawData['departmentName']?.toString() ?? departmentReference.id;

        return Text(
          departmentName,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.active});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final background = active
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFEBEE);

    final foreground = active
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatLabel(text),
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FaceStatusChip extends StatelessWidget {
  const _FaceStatusChip({
    required this.faceRegistered,
    required this.biometricStatus,
  });

  final bool faceRegistered;
  final String biometricStatus;

  @override
  Widget build(BuildContext context) {
    final background = faceRegistered
        ? const Color(0xFFE3F2FD)
        : const Color(0xFFFFF3E0);

    final foreground = faceRegistered
        ? const Color(0xFF1565C0)
        : const Color(0xFFEF6C00);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            faceRegistered ? Icons.verified_user_outlined : Icons.face_outlined,
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 5),
          Text(
            faceRegistered ? _formatLabel(biometricStatus) : 'Not Enrolled',
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 55, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 13),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatLabel(String value) {
  if (value.trim().isEmpty) {
    return 'Unknown';
  }

  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}
