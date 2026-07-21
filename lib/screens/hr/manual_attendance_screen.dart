import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ManualAttendanceScreen extends StatefulWidget {
  const ManualAttendanceScreen({
    super.key,
    required this.employeeId,
    required this.fullName,
  });

  final String employeeId;
  final String fullName;

  @override
  State<ManualAttendanceScreen> createState() =>
      _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState
    extends State<ManualAttendanceScreen> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _lateMinutesController =
      TextEditingController(text: '0');

  final TextEditingController _overtimeHoursController =
      TextEditingController(text: '0');

  final TextEditingController _reasonController =
      TextEditingController();

  DateTime _attendanceDate = DateTime.now();

  TimeOfDay _timeIn = const TimeOfDay(
    hour: 8,
    minute: 0,
  );

  TimeOfDay _timeOut = const TimeOfDay(
    hour: 17,
    minute: 0,
  );

  String _status = 'present';
  bool _isSaving = false;

  bool get _requiresTimeIn {
    return _status == 'present' ||
        _status == 'incomplete';
  }

  bool get _requiresTimeOut {
    return _status == 'present';
  }

  @override
  void dispose() {
    _lateMinutesController.dispose();
    _overtimeHoursController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectAttendanceDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _attendanceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(days: 1),
      ),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _attendanceDate = selectedDate;
    });
  }

  Future<void> _selectTimeIn() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _timeIn,
    );

    if (selectedTime == null) {
      return;
    }

    setState(() {
      _timeIn = selectedTime;
    });
  }

  Future<void> _selectTimeOut() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _timeOut,
    );

    if (selectedTime == null) {
      return;
    }

    setState(() {
      _timeOut = selectedTime;
    });
  }

  DateTime _combineDateAndTime(
    DateTime date,
    TimeOfDay time,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }
  
  String _documentId() {
  final year = _attendanceDate.year.toString();

  final month =
      _attendanceDate.month.toString().padLeft(2, '0');

  final day =
      _attendanceDate.day.toString().padLeft(2, '0');

  return '${widget.employeeId}_$year$month$day';
  }

  Future<bool> _confirmOverwrite() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Attendance Already Exists'),
          content: Text(
            'An attendance record already exists for '
            '${widget.fullName} on ${_formatDate(_attendanceDate)}. '
            'Do you want to replace it with this manual entry?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Replace'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _saveAttendance() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final lateMinutes = int.tryParse(
          _lateMinutesController.text.trim(),
        ) ??
        0;

    final overtimeHours = double.tryParse(
          _overtimeHoursController.text.trim(),
        ) ??
        0;

    DateTime? timeInDateTime;
    DateTime? timeOutDateTime;
    double totalWorkHours = 0;

    if (_requiresTimeIn) {
      timeInDateTime = _combineDateAndTime(
        _attendanceDate,
        _timeIn,
      );
    }

    if (_requiresTimeOut) {
      timeOutDateTime = _combineDateAndTime(
        _attendanceDate,
        _timeOut,
      );

      if (timeInDateTime == null ||
          !timeOutDateTime.isAfter(timeInDateTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Time out must be later than time in.',
            ),
          ),
        );

        return;
      }

      totalWorkHours = timeOutDateTime
              .difference(timeInDateTime)
              .inMinutes /
          60;
    }

    final documentReference = FirebaseFirestore.instance
        .collection('attendance')
        .doc(_documentId());

    final existingDocument =
        await documentReference.get();

    if (existingDocument.exists) {
      final shouldReplace = await _confirmOverwrite();

      if (!shouldReplace) {
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final employeeReference = FirebaseFirestore.instance
          .collection('employee')
          .doc(widget.employeeId);

      final currentUser =
          FirebaseAuth.instance.currentUser;

      final existingData = existingDocument.data();

      final createdAt =
          existingData?['createdAt'] ??
              FieldValue.serverTimestamp();

      await documentReference.set({
        'employeeId': employeeReference,
        'attendanceDate': Timestamp.fromDate(
          DateTime(
            _attendanceDate.year,
            _attendanceDate.month,
            _attendanceDate.day,
          ),
        ),
        'timeIn': timeInDateTime == null
            ? null
            : Timestamp.fromDate(timeInDateTime),
        'timeOut': timeOutDateTime == null
            ? null
            : Timestamp.fromDate(timeOutDateTime),
        'status': _status,
        'lateMinutes':
            _requiresTimeIn ? lateMinutes : 0,
        'overtimeHours':
            _requiresTimeOut ? overtimeHours : 0,
        'totalWorkHours': double.parse(
          totalWorkHours.toStringAsFixed(2),
        ),

        // Manual attendance audit fields.
        'verificationMethod': 'manual',
        'faceVerified': false,
        'livenessPassed': null,
        'similarityScore': null,
        'manualReason':
            _reasonController.text.trim(),
        'enteredBy': currentUser?.uid,
        'createdAt': createdAt,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Manual attendance saved successfully.',
          ),
          backgroundColor: Color(0xFF2E7D32),
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
            error.message ??
                'Unable to save manual attendance.',
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
          content: Text(
            'Unable to save attendance: $error',
          ),
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
    final totalHours = _previewTotalHours();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Manual Attendance'),
        backgroundColor: const Color(0xFFF57C00),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFFFE0B2),
                      child: Icon(
                        Icons.person_outline,
                        color: Color(0xFFF57C00),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.fullName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.employeeId.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              InkWell(
                onTap: _selectAttendanceDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: _inputDecoration(
                    label: 'Attendance Date',
                    icon: Icons.calendar_month_outlined,
                  ),
                  child: Text(
                    _formatDate(_attendanceDate),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: _inputDecoration(
                  label: 'Attendance Status',
                  icon: Icons.fact_check_outlined,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'present',
                    child: Text('Present'),
                  ),
                  DropdownMenuItem(
                    value: 'incomplete',
                    child: Text('Incomplete'),
                  ),
                  DropdownMenuItem(
                    value: 'absent',
                    child: Text('Absent'),
                  ),
                  DropdownMenuItem(
                    value: 'on_leave',
                    child: Text('On Leave'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _status = value;
                    });
                  }
                },
              ),
              if (_requiresTimeIn) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectTimeIn,
                        borderRadius:
                            BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: _inputDecoration(
                            label: 'Time In',
                            icon: Icons.login,
                          ),
                          child: Text(
                            _timeIn.format(context),
                          ),
                        ),
                      ),
                    ),
                    if (_requiresTimeOut) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _selectTimeOut,
                          borderRadius:
                              BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: _inputDecoration(
                              label: 'Time Out',
                              icon: Icons.logout,
                            ),
                            child: Text(
                              _timeOut.format(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _lateMinutesController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    label: 'Late Minutes',
                    icon: Icons.timer_outlined,
                  ),
                  validator: (value) {
                    final number =
                        int.tryParse(value?.trim() ?? '');

                    if (number == null || number < 0) {
                      return 'Enter valid late minutes.';
                    }

                    return null;
                  },
                ),
              ],
              if (_requiresTimeOut) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _overtimeHoursController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDecoration(
                    label: 'Overtime Hours',
                    icon: Icons.more_time,
                  ),
                  validator: (value) {
                    final number = double.tryParse(
                      value?.trim() ?? '',
                    );

                    if (number == null || number < 0) {
                      return 'Enter valid overtime hours.';
                    }

                    return null;
                  },
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _reasonController,
                textCapitalization:
                    TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
                decoration: _inputDecoration(
                  label: 'Reason for Manual Entry',
                  icon: Icons.notes_outlined,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().length < 5) {
                    return 'Please enter a clear reason.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Calculated work hours: '
                        '${totalHours.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF0D47A1),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed:
                    _isSaving ? null : _saveAttendance,
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
                  _isSaving
                      ? 'Saving...'
                      : 'Save Manual Attendance',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _previewTotalHours() {
    if (!_requiresTimeOut) {
      return 0;
    }

    final timeIn = _combineDateAndTime(
      _attendanceDate,
      _timeIn,
    );

    final timeOut = _combineDateAndTime(
      _attendanceDate,
      _timeOut,
    );

    if (!timeOut.isAfter(timeIn)) {
      return 0;
    }

    return timeOut.difference(timeIn).inMinutes / 60;
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