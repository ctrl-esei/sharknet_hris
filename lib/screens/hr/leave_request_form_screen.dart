import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LeaveRequestFormScreen extends StatefulWidget {
  const LeaveRequestFormScreen({
    required this.filedByRole,
    this.employeeId,
    this.employeeName,
    super.key,
  });

  final String filedByRole;

  // When these are null, HR must select an employee.
  // When provided, the employee is fixed.
  final String? employeeId;
  final String? employeeName;

  @override
  State<LeaveRequestFormScreen> createState() =>
      _LeaveRequestFormScreenState();
}

class _LeaveRequestFormScreenState
    extends State<LeaveRequestFormScreen> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _reasonController =
      TextEditingController();

  String? _selectedEmployeeId;

  String _leaveType = 'vacation';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  bool _isSaving = false;

  bool get _employeeIsFixed {
    return widget.employeeId != null &&
        widget.employeeId!.trim().isNotEmpty;
  }

  int get _numberOfDays {
    final DateTime start = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );

    final DateTime end = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
    );

    if (end.isBefore(start)) {
      return 0;
    }

    return end.difference(start).inDays + 1;
  }

  @override
  void initState() {
    super.initState();

    _selectedEmployeeId = widget.employeeId;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(
        const Duration(days: 30),
      ),
      lastDate: DateTime.now().add(
        const Duration(days: 730),
      ),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _startDate = selectedDate;

      if (_endDate.isBefore(_startDate)) {
        _endDate = selectedDate;
      }
    });
  }

  Future<void> _selectEndDate() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate)
          ? _startDate
          : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(
        const Duration(days: 730),
      ),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _endDate = selectedDate;
    });
  }

  Future<void> _saveRequest() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String? employeeId =
        _selectedEmployeeId?.trim();

    if (employeeId == null || employeeId.isEmpty) {
      _showMessage(
        'Please select an employee.',
        isError: true,
      );
      return;
    }

    if (_numberOfDays <= 0) {
      _showMessage(
        'The end date must not be earlier than the start date.',
        isError: true,
      );
      return;
    }

    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage(
        'Your session has expired. Please sign in again.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final DocumentReference<Map<String, dynamic>>
          employeeReference = FirebaseFirestore.instance
              .collection('employee')
              .doc(employeeId);

      final DocumentSnapshot<Map<String, dynamic>>
          employeeDocument =
          await employeeReference.get();

      if (!employeeDocument.exists) {
        throw StateError(
          'The selected employee record was not found.',
        );
      }

      final Map<String, dynamic> employeeData =
          employeeDocument.data() ?? {};

      final String employeeName =
          employeeData['fullName']
                  ?.toString()
                  .trim()
                  .isNotEmpty ==
              true
          ? employeeData['fullName'].toString()
          : widget.employeeName ?? employeeId.toUpperCase();

      final DateTime normalizedStart = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
      );

      final DateTime normalizedEnd = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
      );

      await FirebaseFirestore.instance
          .collection('leave_request')
          .add({
        'employeeId': employeeReference,
        'employeeName': employeeName,
        'leaveType': _leaveType,
        'startDate': Timestamp.fromDate(normalizedStart),
        'endDate': Timestamp.fromDate(normalizedEnd),
        'numberOfDays': _numberOfDays,
        'reason': _reasonController.text.trim(),

        'status': 'pending',

        'filedByUid': currentUser.uid,
        'filedByRole':
            widget.filedByRole.trim().toLowerCase(),
        'filedAt': FieldValue.serverTimestamp(),

        'reviewedBy': null,
        'reviewedAt': null,
        'reviewRemarks': null,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Leave request for $employeeName was submitted.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF039855),
        ),
      );

      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      _showMessage(
        error.message ??
            'Unable to submit the leave request.',
        isError: true,
      );
    } catch (error) {
      _showMessage(
        'Unable to submit leave request: $error',
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
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFD92D20)
              : const Color(0xFF039855),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('File Leave Request'),
        backgroundColor: const Color(0xFFF04B0B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(),
              const SizedBox(height: 22),
              _buildSectionTitle(
                icon: Icons.person_outline,
                title: 'Employee',
              ),
              const SizedBox(height: 13),
              if (_employeeIsFixed)
                _buildFixedEmployee()
              else
                _buildEmployeeDropdown(),
              const SizedBox(height: 24),
              _buildSectionTitle(
                icon: Icons.event_note_outlined,
                title: 'Leave Information',
              ),
              const SizedBox(height: 13),
              DropdownButtonFormField<String>(
                initialValue: _leaveType,
                decoration: _inputDecoration(
                  label: 'Leave Type',
                  icon: Icons.category_outlined,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'vacation',
                    child: Text('Vacation Leave'),
                  ),
                  DropdownMenuItem(
                    value: 'sick',
                    child: Text('Sick Leave'),
                  ),
                  DropdownMenuItem(
                    value: 'emergency',
                    child: Text('Emergency Leave'),
                  ),
                  DropdownMenuItem(
                    value: 'maternity',
                    child: Text('Maternity Leave'),
                  ),
                  DropdownMenuItem(
                    value: 'paternity',
                    child: Text('Paternity Leave'),
                  ),
                  DropdownMenuItem(
                    value: 'bereavement',
                    child: Text('Bereavement Leave'),
                  ),
                  DropdownMenuItem(
                    value: 'unpaid',
                    child: Text('Unpaid Leave'),
                  ),
                  DropdownMenuItem(
                    value: 'other',
                    child: Text('Other Leave'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _leaveType = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectStartDate,
                      borderRadius:
                          BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: _inputDecoration(
                          label: 'Start Date',
                          icon:
                              Icons.calendar_today_outlined,
                        ),
                        child: Text(
                          _formatDate(_startDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _selectEndDate,
                      borderRadius:
                          BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: _inputDecoration(
                          label: 'End Date',
                          icon:
                              Icons.event_available_outlined,
                        ),
                        child: Text(
                          _formatDate(_endDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F6FF),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: const Color(0xFFD2E2FF),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.date_range_outlined,
                      color: Color(0xFF1F5CF5),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Requested duration: $_numberOfDays '
                        '${_numberOfDays == 1 ? 'day' : 'days'}',
                        style: const TextStyle(
                          color: Color(0xFF1849A9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _reasonController,
                textCapitalization:
                    TextCapitalization.sentences,
                minLines: 4,
                maxLines: 7,
                decoration: _inputDecoration(
                  label: 'Reason for Leave',
                  icon: Icons.notes_outlined,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().length < 5) {
                    return 'Please provide a clear reason.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEA),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: const Color(0xFFFFE3A1),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFFB54708),
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'The request will be marked as pending '
                        'until HR approves or rejects it.',
                        style: TextStyle(
                          color: Color(0xFF7A2E0E),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              FilledButton.icon(
                onPressed:
                    _isSaving ? null : _saveRequest,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF04B0B),
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
                    : const Icon(Icons.send_outlined),
                label: Text(
                  _isSaving
                      ? 'Submitting...'
                      : 'Submit Leave Request',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFFFF1EA),
            child: Icon(
              Icons.event_note_outlined,
              color: Color(0xFFF04B0B),
              size: 29,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Leave Request',
                  style: TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Complete the information below.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedEmployee() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFFD0D5DD),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFF0F6FF),
            child: Icon(
              Icons.person_outline,
              color: Color(0xFF1F5CF5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.employeeName ??
                      widget.employeeId!.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.employeeId!.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeDropdown() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('employee')
          .orderBy('fullName')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Unable to load employees: ${snapshot.error}',
            style: const TextStyle(
              color: Color(0xFFD92D20),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final List<
                QueryDocumentSnapshot<
                    Map<String, dynamic>>>
            employees = snapshot.data!.docs.where(
          (document) {
            final String status =
                document.data()['employmentStatus']
                        ?.toString()
                        .toLowerCase() ??
                    'active';

            return status == 'active';
          },
        ).toList();

        return DropdownButtonFormField<String>(
          initialValue: _selectedEmployeeId,
          isExpanded: true,
          decoration: _inputDecoration(
            label: 'Select Employee',
            icon: Icons.person_search_outlined,
          ),
          items: employees.map((document) {
            final Map<String, dynamic> data =
                document.data();

            final String fullName =
                data['fullName']?.toString() ??
                    document.id.toUpperCase();

            return DropdownMenuItem<String>(
              value: document.id,
              child: Text(
                '$fullName (${document.id.toUpperCase()})',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedEmployeeId = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select an employee.';
            }

            return null;
          },
        );
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
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const List<String> months = [
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

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year}';
  }
}