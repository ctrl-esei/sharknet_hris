import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/payslip_pdf_service.dart';

class PayslipsScreen extends StatefulWidget {
  const PayslipsScreen({super.key});

  @override
  State<PayslipsScreen> createState() =>
      _PayslipsScreenState();
}

class _PayslipsScreenState
    extends State<PayslipsScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _searchText = '';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _changeStatus({
    required DocumentReference<Map<String, dynamic>>
        payslipReference,
    required Map<String, dynamic> data,
    required String nextStatus,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final dynamic payrollValue = data['payrollId'];

    if (payrollValue
        is! DocumentReference<Map<String, dynamic>>) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The associated payroll reference is missing.',
          ),
        ),
      );
      return;
    }

    try {
      final WriteBatch batch =
          FirebaseFirestore.instance.batch();

      final Map<String, dynamic> update = {
        'status': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (nextStatus == 'approved') {
        update.addAll({
          'approvedBy': user.uid,
          'approvedAt': FieldValue.serverTimestamp(),
        });
      }

      if (nextStatus == 'released') {
        update.addAll({
          'releasedBy': user.uid,
          'releasedAt': FieldValue.serverTimestamp(),
        });
      }

      batch.update(
        payslipReference,
        update,
      );

      batch.update(
        payrollValue,
        update,
      );

      await batch.commit();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextStatus == 'approved'
                ? 'Payslip approved.'
                : 'Payslip released.',
          ),
          backgroundColor:
              const Color(0xFF039855),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update payslip: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _matches(
    QueryDocumentSnapshot<Map<String, dynamic>>
        document,
  ) {
    final data = document.data();

    final String status =
        data['status']?.toString().toLowerCase() ??
            'draft';

    if (_statusFilter != 'all' &&
        status != _statusFilter) {
      return false;
    }

    if (_searchText.isEmpty) {
      return true;
    }

    final String employeeName =
        data['employeeName']
                ?.toString()
                .toLowerCase() ??
            '';

    final String employeeId =
        _referenceId(data['employeeId'])
            .toLowerCase();

    return employeeName.contains(_searchText) ||
        employeeId.contains(_searchText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Payslips'),
        backgroundColor: const Color(0xFFF04B0B),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('payslips')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load payslips: '
                '${snapshot.error}',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final payslips = snapshot.data!.docs
              .where(_matches)
              .toList();

          payslips.sort((first, second) {
            final DateTime firstDate =
                _dateFromValue(
                      first.data()[
                          'payrollPeriodStart'],
                    ) ??
                    DateTime(2000);

            final DateTime secondDate =
                _dateFromValue(
                      second.data()[
                          'payrollPeriodStart'],
                    ) ??
                    DateTime(2000);

            return secondDate.compareTo(firstDate);
          });

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              30,
            ),
            children: [
              _buildFilters(),
              const SizedBox(height: 18),
              if (payslips.isEmpty)
                const _EmptyPayslips()
              else
                ...payslips.map(
                  (document) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: 12),
                    child: _PayslipCard(
                      payslipId: document.id,
                      reference: document.reference,
                      data: document.data(),
                      onStatusChange: _changeStatus,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _statusFilter,
            decoration: const InputDecoration(
              labelText: 'Payslip Status',
              prefixIcon:
                  Icon(Icons.filter_alt_outlined),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('All Statuses'),
              ),
              DropdownMenuItem(
                value: 'draft',
                child: Text('Draft'),
              ),
              DropdownMenuItem(
                value: 'approved',
                child: Text('Approved'),
              ),
              DropdownMenuItem(
                value: 'released',
                child: Text('Released'),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _statusFilter = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchText =
                    value.trim().toLowerCase();
              });
            },
            decoration: const InputDecoration(
              labelText: 'Search Employee',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  const _PayslipCard({
    required this.payslipId,
    required this.reference,
    required this.data,
    required this.onStatusChange,
  });

  final String payslipId;

  final DocumentReference<Map<String, dynamic>>
      reference;

  final Map<String, dynamic> data;

  final Future<void> Function({
    required DocumentReference<Map<String, dynamic>>
        payslipReference,
    required Map<String, dynamic> data,
    required String nextStatus,
  }) onStatusChange;

  @override
  Widget build(BuildContext context) {
    final String employeeName =
        data['employeeName']?.toString() ??
            'Employee';

    final String employeeId =
        _referenceId(data['employeeId']);

    final String status =
        data['status']?.toString().toLowerCase() ??
            'draft';

    final DateTime? periodStart =
        _dateFromValue(data['payrollPeriodStart']);

    final DateTime? periodEnd =
        _dateFromValue(data['payrollPeriodEnd']);

    final double netPay =
        (data['netPay'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    const Color(0xFFFFF1EA),
                child: Text(
                  _initials(employeeName),
                  style: const TextStyle(
                    color: Color(0xFFF04B0B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      employeeId.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 13),
          Text(
            '${_formatDate(periodStart)} – '
            '${_formatDate(periodEnd)}',
            style: const TextStyle(
              color: Color(0xFF475467),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Net Pay: PHP ${netPay.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Color(0xFFF04B0B),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  PayslipPdfService.sharePayslip(
                    data: data,
                    payslipId: payslipId,
                  );
                },
                icon: const Icon(
                  Icons.download_outlined,
                ),
                label: const Text('Download'),
              ),
              if (status == 'draft')
                FilledButton.icon(
                  onPressed: () {
                    onStatusChange(
                      payslipReference: reference,
                      data: data,
                      nextStatus: 'approved',
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF1F5CF5),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(
                    Icons.check_rounded,
                  ),
                  label: const Text('Approve'),
                ),
              if (status == 'approved')
                FilledButton.icon(
                  onPressed: () {
                    onStatusChange(
                      payslipReference: reference,
                      data: data,
                      nextStatus: 'released',
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF039855),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(
                    Icons.send_outlined,
                  ),
                  label: const Text('Release'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;

    switch (status) {
      case 'released':
        background = const Color(0xFFECFDF3);
        foreground = const Color(0xFF027A48);
        break;

      case 'approved':
        background = const Color(0xFFF0F6FF);
        foreground = const Color(0xFF1849A9);
        break;

      default:
        background = const Color(0xFFFFF7ED);
        foreground = const Color(0xFFB54708);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyPayslips extends StatelessWidget {
  const _EmptyPayslips();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 50),
      child: Column(
        children: [
          Icon(
            Icons.description_outlined,
            size: 60,
            color: Color(0xFF98A2B3),
          ),
          SizedBox(height: 12),
          Text(
            'No payslips found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _referenceId(dynamic value) {
  if (value is DocumentReference) {
    return value.id;
  }

  final String raw = value?.toString() ?? 'employee';

  return raw.contains('/')
      ? raw.split('/').last
      : raw;
}

DateTime? _dateFromValue(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  return null;
}

String _formatDate(DateTime? date) {
  if (date == null) {
    return 'Not available';
  }

  const months = [
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

String _initials(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
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