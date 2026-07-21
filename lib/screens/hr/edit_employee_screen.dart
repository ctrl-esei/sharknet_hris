import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditEmployeeScreen extends StatefulWidget {
  const EditEmployeeScreen({
    required this.employeeId,
    super.key,
  });

  final String employeeId;

  @override
  State<EditEmployeeScreen> createState() =>
      _EditEmployeeScreenState();
}

class _EditEmployeeScreenState
    extends State<EditEmployeeScreen> {
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

  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;
  String? _selectedDepartmentId;

  String _employmentType = 'regular';
  String _employmentStatus = 'active';
  String _salaryType = 'monthly';

  DateTime _dateHired = DateTime.now();

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
      _departments = [];

  DocumentReference<Map<String, dynamic>>
      get _employeeReference {
    return FirebaseFirestore.instance
        .collection('employee')
        .doc(widget.employeeId);
  }

  @override
  void initState() {
    super.initState();
    _loadEmployee();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _salaryRateController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployee() async {
    try {
      final employeeDocument =
          await _employeeReference.get();

      final departmentSnapshot =
          await FirebaseFirestore.instance
              .collection('departments')
              .orderBy('departmentName')
              .get();

      if (!employeeDocument.exists) {
        throw StateError(
          'The employee record was not found.',
        );
      }

      final Map<String, dynamic> data =
          employeeDocument.data() ?? {};

      _fullNameController.text =
          data['fullName']?.toString() ?? '';

      _phoneController.text =
          data['phoneNumber']?.toString() ?? '';

      _positionController.text =
          data['position']?.toString() ?? '';

      final salaryRate = data['salaryRate'];

      if (salaryRate is num) {
        _salaryRateController.text =
            salaryRate.toString();
      } else {
        _salaryRateController.text =
            salaryRate?.toString() ?? '';
      }

      _employmentType =
          data['employmentType']?.toString() ??
              'regular';

      _employmentStatus =
          data['employmentStatus']?.toString() ??
              'active';

      _salaryType =
          data['salaryType']?.toString() ??
              'monthly';

      final dateHiredValue = data['dateHired'];

      if (dateHiredValue is Timestamp) {
        _dateHired = dateHiredValue.toDate();
      }

      _selectedDepartmentId =
          _extractDepartmentId(
        data['departmentId'],
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _departments = departmentSnapshot.docs;
        _isLoading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            error.message ??
            'Unable to load employee information.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  String? _extractDepartmentId(dynamic value) {
    if (value is DocumentReference) {
      return value.id;
    }

    if (value is String && value.trim().isNotEmpty) {
      final cleanedValue = value.trim();

      if (cleanedValue.contains('/')) {
        return cleanedValue.split('/').last;
      }

      return cleanedValue;
    }

    return null;
  }

  Future<void> _selectDateHired() async {
    final DateTime? selectedDate =
        await showDatePicker(
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

    if (_selectedDepartmentId == null) {
      _showMessage(
        'Please select a department.',
        isError: true,
      );
      return;
    }

    final double? salaryRate = double.tryParse(
      _salaryRateController.text.trim(),
    );

    if (salaryRate == null || salaryRate < 0) {
      _showMessage(
        'Enter a valid salary rate.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final departmentReference =
          FirebaseFirestore.instance
              .collection('departments')
              .doc(_selectedDepartmentId);

      await _employeeReference.update({
        'fullName':
            _fullNameController.text.trim(),
        'phoneNumber':
            _phoneController.text.trim(),
        'position':
            _positionController.text.trim(),
        'departmentId': departmentReference,
        'employmentType': _employmentType,
        'employmentStatus': _employmentStatus,
        'dateHired': Timestamp.fromDate(
          DateTime(
            _dateHired.year,
            _dateHired.month,
            _dateHired.day,
          ),
        ),
        'salaryRate': salaryRate,
        'salaryType': _salaryType,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Employee information updated successfully.',
          ),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );

      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      _showMessage(
        error.message ??
            'Unable to update employee information.',
        isError: true,
      );
    } catch (error) {
      _showMessage(
        'Unable to update employee: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    required bool isError,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? const Color(0xFFC62828)
              : const Color(0xFF2E7D32),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Edit Employee'),
        backgroundColor: const Color(0xFFF04B0B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Color(0xFFC62828),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });

                  _loadEmployee();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildEmployeeHeader(),
          const SizedBox(height: 22),
          _buildSectionTitle(
            icon: Icons.badge_outlined,
            title: 'Employee Information',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _fullNameController,
            textCapitalization:
                TextCapitalization.words,
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
            textCapitalization:
                TextCapitalization.words,
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
              if (value == null) {
                return;
              }

              setState(() {
                _employmentType = value;
              });
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
              DropdownMenuItem(
                value: 'resigned',
                child: Text('Resigned'),
              ),
              DropdownMenuItem(
                value: 'terminated',
                child: Text('Terminated'),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _employmentStatus = value;
              });
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
          _buildSectionTitle(
            icon: Icons.payments_outlined,
            title: 'Salary Information',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _salaryRateController,
            keyboardType:
                const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: _inputDecoration(
              label: 'Salary Rate',
              icon: Icons.currency_exchange,
              prefixText: '₱ ',
            ),
            validator: (value) {
              final double? salary = double.tryParse(
                value?.trim() ?? '',
              );

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
              if (value == null) {
                return;
              }

              setState(() {
                _salaryType = value;
              });
            },
          ),
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed:
                _isSaving ? null : _saveEmployee,
            style: FilledButton.styleFrom(
              backgroundColor:
                  const Color(0xFFF04B0B),
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
              _isSaving
                  ? 'Saving Changes...'
                  : 'Save Changes',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeHeader() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFFFF1EA),
            child: Icon(
              Icons.manage_accounts_outlined,
              color: Color(0xFFF04B0B),
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Editing Employee',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.employeeId.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    if (_departments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No departments are available.',
          style: TextStyle(
            color: Color(0xFFEF6C00),
          ),
        ),
      );
    }

    final bool departmentExists =
        _departments.any(
      (document) =>
          document.id == _selectedDepartmentId,
    );

    if (!departmentExists) {
      _selectedDepartmentId = null;
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedDepartmentId,
      decoration: _inputDecoration(
        label: 'Department',
        icon: Icons.apartment_outlined,
      ),
      items: _departments.map((document) {
        final Map<String, dynamic> data =
            document.data();

        final String departmentName =
            data['departmentName']?.toString() ??
                document.id;

        return DropdownMenuItem<String>(
          value: document.id,
          child: Text(departmentName),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedDepartmentId = value;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Department is required.';
        }

        return null;
      },
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFFF04B0B),
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
    const List<String> months = [
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