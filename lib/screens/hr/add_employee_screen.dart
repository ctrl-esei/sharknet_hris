import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() =>
      _AddEmployeeScreenState();
}

class _AddEmployeeScreenState
    extends State<AddEmployeeScreen> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _fullNameController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  final TextEditingController _positionController =
      TextEditingController();

  final TextEditingController _salaryRateController =
      TextEditingController();

  DocumentReference<Map<String, dynamic>>?
      _selectedDepartment;

  DateTime _dateHired = DateTime.now();

  String _employmentType = 'regular';
  String _employmentStatus = 'active';
  String _salaryType = 'monthly';

  bool _isSaving = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _salaryRateController.dispose();
    super.dispose();
  }

  Future<String> _generateEmployeeId() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('employee')
        .get();

    int highestNumber = 0;

    final pattern = RegExp(
      r'^emp(\d+)$',
      caseSensitive: false,
    );

    for (final document in snapshot.docs) {
      final match = pattern.firstMatch(document.id);

      if (match == null) {
        continue;
      }

      final number = int.tryParse(match.group(1) ?? '');

      if (number != null && number > highestNumber) {
        highestNumber = number;
      }
    }

    final nextNumber = highestNumber + 1;

    return 'emp${nextNumber.toString().padLeft(3, '0')}';
  }

  Future<void> _selectDateHired() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _dateHired,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _dateHired = selectedDate;
    });
  }

  Future<void> _saveEmployee() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a department.'),
        ),
      );

      return;
    }

    final salaryRate = double.tryParse(
      _salaryRateController.text.trim(),
    );

    if (salaryRate == null || salaryRate < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid salary rate.'),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final employeeId = await _generateEmployeeId();

      final employeeReference = FirebaseFirestore.instance
          .collection('employee')
          .doc(employeeId);

      await employeeReference.set({
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'departmentId': _selectedDepartment,
        'position': _positionController.text.trim(),
        'employmentStatus': _employmentStatus,
        'employmentType': _employmentType,
        'dateHired': Timestamp.fromDate(_dateHired),
        'salaryRate': salaryRate,
        'salaryType': _salaryType,

        // The employee does not automatically receive
        // an Authentication account.
        'userUid': null,

        // Face-registration defaults.
        'faceRegistered': false,
        'biometricStatus': 'not_enrolled',
        'faceEmbedding': <double>[],
        'faceModelVersion': null,
        'faceEnrolledAt': null,
        'faceUpdatedAt': null,
        'consentAccepted': false,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Employee $employeeId was added successfully.',
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );

      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to add employee.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to add employee: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Add Employee'),
        backgroundColor: const Color(0xFFF57C00),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionHeader(
                icon: Icons.badge_outlined,
                title: 'Employee Information',
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _fullNameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(
                  label: 'Full Name',
                  icon: Icons.person_outline,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Full name is required.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _positionController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(
                  label: 'Position',
                  icon: Icons.work_outline,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Position is required.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 14),
              _buildDepartmentDropdown(),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _employmentType,
                decoration: _inputDecoration(
                  label: 'Employment Type',
                  icon: Icons.assignment_ind_outlined,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'regular',
                    child: Text('Regular'),
                  ),
                  DropdownMenuItem(
                    value: 'probationary',
                    child: Text('Probationary'),
                  ),
                  DropdownMenuItem(
                    value: 'contractual',
                    child: Text('Contractual'),
                  ),
                  DropdownMenuItem(
                    value: 'part_time',
                    child: Text('Part Time'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _employmentType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _employmentStatus,
                decoration: _inputDecoration(
                  label: 'Employment Status',
                  icon: Icons.toggle_on_outlined,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'active',
                    child: Text('Active'),
                  ),
                  DropdownMenuItem(
                    value: 'inactive',
                    child: Text('Inactive'),
                  ),
                  DropdownMenuItem(
                    value: 'suspended',
                    child: Text('Suspended'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _employmentStatus = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _selectDateHired,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: _inputDecoration(
                    label: 'Date Hired',
                    icon: Icons.calendar_month_outlined,
                  ),
                  child: Text(
                    _formatDate(_dateHired),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(
                icon: Icons.payments_outlined,
                title: 'Salary Information',
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _salaryRateController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _inputDecoration(
                  label: 'Salary Rate',
                  icon: Icons.currency_exchange,
                  prefixText: '₱ ',
                ),
                validator: (value) {
                  final salary =
                      double.tryParse(value?.trim() ?? '');

                  if (salary == null || salary < 0) {
                    return 'Enter a valid salary rate.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _salaryType,
                decoration: _inputDecoration(
                  label: 'Salary Type',
                  icon: Icons.schedule_outlined,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'monthly',
                    child: Text('Monthly'),
                  ),
                  DropdownMenuItem(
                    value: 'daily',
                    child: Text('Daily'),
                  ),
                  DropdownMenuItem(
                    value: 'hourly',
                    child: Text('Hourly'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _salaryType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 25),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.face_outlined,
                      color: Color(0xFF1565C0),
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'The employee will initially be marked as '
                        'Not Enrolled. Face registration can be '
                        'completed from the Employees page.',
                        style: TextStyle(
                          color: Color(0xFF0D47A1),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveEmployee,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF57C00),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save Employee',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('departments')
          .orderBy('departmentName')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Unable to load departments.',
            style: TextStyle(color: Colors.red),
          );
        }

        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final departments = snapshot.data!.docs;

        return DropdownButtonFormField<
            DocumentReference<Map<String, dynamic>>>(
          initialValue: _selectedDepartment,
          decoration: _inputDecoration(
            label: 'Department',
            icon: Icons.apartment_outlined,
          ),
          items: departments.map((document) {
            final name =
                document.data()['departmentName']?.toString() ??
                    document.id;

            return DropdownMenuItem(
              value: document.reference,
              child: Text(name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedDepartment = value;
            });
          },
          validator: (value) {
            if (value == null) {
              return 'Department is required.';
            }

            return null;
          },
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFFF57C00),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      prefixText: prefixText,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
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

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year}';
  }
}