import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/payslip_pdf_service.dart';

class EmployeePayslipsScreen extends StatefulWidget {
  const EmployeePayslipsScreen({
    required this.employeeId,
    required this.fullName,
    super.key,
  });

  final String employeeId;
  final String fullName;

  @override
  State<EmployeePayslipsScreen> createState() =>
      _EmployeePayslipsScreenState();
}

class _EmployeePayslipsScreenState
    extends State<EmployeePayslipsScreen> {
  late final Future<
          DocumentReference<Map<String, dynamic>>>
      _employeeReferenceFuture;

  String _statusFilter = 'all';
  String _typeFilter = 'all';
  int? _selectedYear;

  String? _downloadingPayslipId;

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

  Future<void> _downloadPayslip({
    required String payslipId,
    required Map<String, dynamic> data,
  }) async {
    if (_downloadingPayslipId != null) {
      return;
    }

    setState(() {
      _downloadingPayslipId = payslipId;
    });

    try {
      await PayslipPdfService.sharePayslip(
        data: data,
        payslipId: payslipId,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Unable to generate payslip PDF: $error',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor:
                const Color(0xFFD92D20),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingPayslipId = null;
        });
      }
    }
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
              return const _PayslipLoadingState();
            }

            if (employeeReferenceSnapshot.hasError ||
                !employeeReferenceSnapshot.hasData) {
              return _PayslipErrorState(
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
                QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('payslips')
                  .where(
                    'employeeId',
                    isEqualTo: employeeReference,
                  )
                  .snapshots(),
              builder: (
                BuildContext context,
                AsyncSnapshot<
                        QuerySnapshot<
                            Map<String, dynamic>>>
                    payslipSnapshot,
              ) {
                if (payslipSnapshot.hasError) {
                  return _PayslipErrorState(
                    message:
                        'Unable to load your payslips: '
                        '${payslipSnapshot.error}',
                  );
                }

                if (!payslipSnapshot.hasData) {
                  return const _PayslipLoadingState();
                }

                final List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    visiblePayslips =
                    _visiblePayslips(
                  payslipSnapshot.data!.docs,
                );

                final List<int> years =
                    _availableYears(visiblePayslips);

                if (_selectedYear != null &&
                    !years.contains(_selectedYear)) {
                  _selectedYear = null;
                }

                final List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    filteredPayslips =
                    _filteredPayslips(
                  visiblePayslips,
                );

                final _PayslipSummary summary =
                    _calculateSummary(
                  filteredPayslips,
                );

                return RefreshIndicator(
                  onRefresh: () async {
                    await Future<void>.delayed(
                      const Duration(
                        milliseconds: 350,
                      ),
                    );

                    if (mounted) {
                      setState(() {});
                    }
                  },
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      18,
                      18,
                      100,
                    ),
                    children: <Widget>[
                      _buildHeader(),
                      const SizedBox(height: 18),
                      _buildFilters(years),
                      const SizedBox(height: 18),
                      _buildSummary(summary),
                      const SizedBox(height: 20),
                      _buildListHeader(
                        count:
                            filteredPayslips.length,
                      ),
                      const SizedBox(height: 12),
                      if (visiblePayslips.isEmpty)
                        const _PayslipMessageState(
                          icon:
                              Icons.receipt_long_outlined,
                          title:
                              'No approved payslips yet',
                          message:
                              'Payslips will appear here after HR approves or releases them.',
                        )
                      else if (filteredPayslips.isEmpty)
                        const _PayslipMessageState(
                          icon:
                              Icons.filter_alt_off,
                          title:
                              'No matching payslips',
                          message:
                              'Try choosing a different year, status, or payroll type.',
                        )
                      else
                        ...filteredPayslips.map(
                          (
                            QueryDocumentSnapshot<
                                    Map<String, dynamic>>
                                document,
                          ) {
                            final bool downloading =
                                _downloadingPayslipId ==
                                    document.id;

                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom: 12,
                              ),
                              child:
                                  _EmployeePayslipCard(
                                payslipId:
                                    document.id,
                                data: document.data(),
                                downloading:
                                    downloading,
                                onView: () {
                                  _showPayslipDetails(
                                    payslipId:
                                        document.id,
                                    data:
                                        document.data(),
                                  );
                                },
                                onDownload: () {
                                  _downloadPayslip(
                                    payslipId:
                                        document.id,
                                    data:
                                        document.data(),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'My Payslips',
          style: TextStyle(
            color: Color(0xFF101828),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Approved and released payslips for '
          '${widget.fullName.trim().isEmpty ? 'your account' : widget.fullName}.',
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius:
                BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFD7E7FF),
            ),
          ),
          child: const Row(
            children: <Widget>[
              Icon(
                Icons.verified_outlined,
                color: Color(0xFF2979FF),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Draft and pending-approval payslips are hidden from employees.',
                  style: TextStyle(
                    color: Color(0xFF344054),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(
    List<int> years,
  ) {
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
          DropdownButtonFormField<int?>(
            initialValue: _selectedYear,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Payroll Year',
              prefixIcon: const Icon(
                Icons.calendar_today_outlined,
              ),
              filled: true,
              fillColor:
                  const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
            items: <DropdownMenuItem<int?>>[
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('All Years'),
              ),
              ...years.map(
                (int year) =>
                    DropdownMenuItem<int?>(
                  value: year,
                  child: Text(year.toString()),
                ),
              ),
            ],
            onChanged: (int? value) {
              setState(() {
                _selectedYear = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child:
                    DropdownButtonFormField<String>(
                  initialValue:
                      _statusFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    prefixIcon: const Icon(
                      Icons.verified_user_outlined,
                    ),
                    filled: true,
                    fillColor:
                        const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  items: const <
                      DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'all',
                      child: Text('All'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'approved',
                      child: Text('Approved'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'released',
                      child: Text('Released'),
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
              const SizedBox(width: 12),
              Expanded(
                child:
                    DropdownButtonFormField<String>(
                  initialValue:
                      _typeFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    prefixIcon: const Icon(
                      Icons.category_outlined,
                    ),
                    filled: true,
                    fillColor:
                        const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  items: const <
                      DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'all',
                      child: Text('All'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'regular',
                      child: Text('Regular'),
                    ),
                    DropdownMenuItem<String>(
                      value:
                          'thirteenth_month',
                      child:
                          Text('13th Month'),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _typeFilter = value;
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

  Widget _buildSummary(
    _PayslipSummary summary,
  ) {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final double width =
            (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            SizedBox(
              width: width,
              child: _PayslipSummaryCard(
                label: 'Payslips',
                value: summary.count.toString(),
                icon:
                    Icons.description_outlined,
                backgroundColor:
                    const Color(0xFFE3F2FD),
                foregroundColor:
                    const Color(0xFF1565C0),
              ),
            ),
            SizedBox(
              width: width,
              child: _PayslipSummaryCard(
                label: 'Total Net Pay',
                value: _formatCompactMoney(
                  summary.totalNetPay,
                ),
                icon:
                    Icons.account_balance_wallet_outlined,
                backgroundColor:
                    const Color(0xFFE8F5E9),
                foregroundColor:
                    const Color(0xFF2E7D32),
              ),
            ),
            SizedBox(
              width: width,
              child: _PayslipSummaryCard(
                label: 'Latest Net Pay',
                value: _formatCompactMoney(
                  summary.latestNetPay,
                ),
                icon:
                    Icons.payments_outlined,
                backgroundColor:
                    const Color(0xFFFFF3E0),
                foregroundColor:
                    const Color(0xFFEF6C00),
              ),
            ),
            SizedBox(
              width: width,
              child: _PayslipSummaryCard(
                label: 'Released',
                value:
                    summary.releasedCount.toString(),
                icon:
                    Icons.task_alt_outlined,
                backgroundColor:
                    const Color(0xFFF4F3FF),
                foregroundColor:
                    const Color(0xFF7F56D9),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListHeader({
    required int count,
  }) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Text(
            'Payslip Records',
            style: TextStyle(
              color: Color(0xFF101828),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          '$count record${count == 1 ? '' : 's'}',
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>
      _visiblePayslips(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        documents,
  ) {
    final List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        visible = documents.where(
      (
        QueryDocumentSnapshot<Map<String, dynamic>>
            document,
      ) {
        final String status =
            _text(
              document.data()['status'],
              fallback: '',
            ).toLowerCase();

        return status == 'approved' ||
            status == 'released';
      },
    ).toList();

    visible.sort(
      (
        QueryDocumentSnapshot<Map<String, dynamic>>
            first,
        QueryDocumentSnapshot<Map<String, dynamic>>
            second,
      ) {
        return _sortDate(
          second.data(),
        ).compareTo(
          _sortDate(first.data()),
        );
      },
    );

    return visible;
  }

  List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>
      _filteredPayslips(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        payslips,
  ) {
    return payslips.where(
      (
        QueryDocumentSnapshot<Map<String, dynamic>>
            document,
      ) {
        final Map<String, dynamic> data =
            document.data();

        final String status =
            _text(
              data['status'],
              fallback: '',
            ).toLowerCase();

        final String payrollType =
            _payrollType(data);

        final int? payrollYear =
            _payslipYear(data);

        final bool statusMatches =
            _statusFilter == 'all' ||
                status == _statusFilter;

        final bool typeMatches =
            _typeFilter == 'all' ||
                payrollType == _typeFilter;

        final bool yearMatches =
            _selectedYear == null ||
                payrollYear == _selectedYear;

        return statusMatches &&
            typeMatches &&
            yearMatches;
      },
    ).toList();
  }

  List<int> _availableYears(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        documents,
  ) {
    final Set<int> years = <int>{};

    for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        document in documents) {
      final int? year =
          _payslipYear(document.data());

      if (year != null) {
        years.add(year);
      }
    }

    final List<int> sorted =
        years.toList()
          ..sort(
            (
              int first,
              int second,
            ) =>
                second.compareTo(first),
          );

    return sorted;
  }

  _PayslipSummary _calculateSummary(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        documents,
  ) {
    double totalNetPay = 0;
    double latestNetPay = 0;
    int releasedCount = 0;

    if (documents.isNotEmpty) {
      latestNetPay =
          _number(documents.first.data()['netPay']);
    }

    for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        document in documents) {
      final Map<String, dynamic> data =
          document.data();

      totalNetPay +=
          _number(data['netPay']);

      if (_text(
            data['status'],
            fallback: '',
          ).toLowerCase() ==
          'released') {
        releasedCount++;
      }
    }

    return _PayslipSummary(
      count: documents.length,
      totalNetPay: totalNetPay,
      latestNetPay: latestNetPay,
      releasedCount: releasedCount,
    );
  }

  void _showPayslipDetails({
    required String payslipId,
    required Map<String, dynamic> data,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (
        BuildContext bottomSheetContext,
      ) {
        return _PayslipDetailsSheet(
          payslipId: payslipId,
          data: data,
          downloading:
              _downloadingPayslipId == payslipId,
          onDownload: () {
            Navigator.of(
              bottomSheetContext,
            ).pop();

            _downloadPayslip(
              payslipId: payslipId,
              data: data,
            );
          },
        );
      },
    );
  }
}

class _EmployeePayslipCard
    extends StatelessWidget {
  const _EmployeePayslipCard({
    required this.payslipId,
    required this.data,
    required this.downloading,
    required this.onView,
    required this.onDownload,
  });

  final String payslipId;
  final Map<String, dynamic> data;
  final bool downloading;
  final VoidCallback onView;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final String status =
        _text(
          data['status'],
          fallback: 'approved',
        ).toLowerCase();

    final String payrollType =
        _payrollType(data);

    final DateTime? periodStart =
        _date(data['payrollPeriodStart']);

    final DateTime? periodEnd =
        _date(data['payrollPeriodEnd']);

    final int? payrollYear =
        _payslipYear(data);

    final String title =
        payrollType == 'thirteenth_month'
            ? '13th-Month Pay ${payrollYear ?? ''}'
                .trim()
            : periodEnd == null
                ? 'Approved Payslip'
                : '${_monthName(periodEnd.month)} '
                    '${periodEnd.year} Payslip';

    final double grossPay =
        _number(data['grossPay']);

    final double totalDeductions =
        _number(data['totalDeductions']);

    final double netPay =
        _number(data['netPay']);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onView,
        borderRadius:
            BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE4E7EC),
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0D101828),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color:
                          payrollType ==
                                  'thirteenth_month'
                              ? const Color(
                                  0xFFF4F3FF,
                                )
                              : const Color(
                                  0xFFEFF5FF,
                                ),
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child: Icon(
                      payrollType ==
                              'thirteenth_month'
                          ? Icons
                              .card_giftcard_outlined
                          : Icons
                              .receipt_long_outlined,
                      color:
                          payrollType ==
                                  'thirteenth_month'
                              ? const Color(
                                  0xFF7F56D9,
                                )
                              : const Color(
                                  0xFF2979FF,
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
                          title,
                          style: const TextStyle(
                            color:
                                Color(0xFF101828),
                            fontSize: 17,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          payrollType ==
                                  'thirteenth_month'
                              ? 'Annual benefit'
                              : _periodLabel(
                                  periodStart,
                                  periodEnd,
                                ),
                          style: const TextStyle(
                            color:
                                Color(0xFF667085),
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _PayslipStatusChip(
                    status: status,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Divider(height: 1),
              const SizedBox(height: 15),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MoneyDetail(
                      label: 'Gross Pay',
                      value:
                          _formatMoney(grossPay),
                    ),
                  ),
                  Expanded(
                    child: _MoneyDetail(
                      label: 'Deductions',
                      value: _formatMoney(
                        totalDeductions,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _MoneyDetail(
                      label: 'Net Pay',
                      value:
                          _formatMoney(netPay),
                      highlight: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onView,
                      icon: const Icon(
                        Icons
                            .visibility_outlined,
                        size: 18,
                      ),
                      label: const Text(
                        'View',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: downloading
                          ? null
                          : onDownload,
                      style:
                          FilledButton.styleFrom(
                        backgroundColor:
                            const Color(
                          0xFF2979FF,
                        ),
                        foregroundColor:
                            Colors.white,
                      ),
                      icon: downloading
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .download_outlined,
                              size: 18,
                            ),
                      label: Text(
                        downloading
                            ? 'Preparing'
                            : 'PDF',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayslipDetailsSheet
    extends StatelessWidget {
  const _PayslipDetailsSheet({
    required this.payslipId,
    required this.data,
    required this.downloading,
    required this.onDownload,
  });

  final String payslipId;
  final Map<String, dynamic> data;
  final bool downloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final String status =
        _text(
          data['status'],
          fallback: 'approved',
        ).toLowerCase();

    final String payrollType =
        _payrollType(data);

    final DateTime? periodStart =
        _date(data['payrollPeriodStart']);

    final DateTime? periodEnd =
        _date(data['payrollPeriodEnd']);

    final DateTime? approvedAt =
        _date(data['approvedAt']);

    final DateTime? generatedAt =
        _date(data['generatedAt']);

    final Map<String, dynamic> approvedBy =
        _map(data['approvedBy']);

    final String approver =
        _text(
          approvedBy['fullName'],
          fallback: _text(
            approvedBy['email'],
            fallback: _text(
              data['approvedByName'],
              fallback: 'HR/Admin',
            ),
          ),
        );

    final Map<String, dynamic> deductions =
        _map(data['deductionBreakdown']);

    final double basicPay =
        _number(data['basicPay']);

    final double overtimePay =
        _number(data['overtimePay']);

    final double holidayPay =
        _number(data['holidayPay']);

    final double allowances =
        _number(data['allowances']);

    final double thirteenthMonthPay =
        _number(data['thirteenthMonthPay']);

    final double grossPay =
        _number(data['grossPay']);

    final double totalDeductions =
        _number(data['totalDeductions']);

    final double netPay =
        _number(data['netPay']);

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.65,
      maxChildSize: 0.96,
      builder: (
        BuildContext context,
        ScrollController scrollController,
      ) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              30,
            ),
            children: <Widget>[
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFD0D5DD),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Payslip Details',
                      style: TextStyle(
                        color:
                            Color(0xFF101828),
                        fontSize: 22,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),
                  _PayslipStatusChip(
                    status: status,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                payrollType ==
                        'thirteenth_month'
                    ? '13th-Month Pay'
                    : _periodLabel(
                        periodStart,
                        periodEnd,
                      ),
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              _DetailsSection(
                title: 'Earnings',
                children: <Widget>[
                  _DetailMoneyRow(
                    label: 'Basic Pay',
                    value: basicPay,
                  ),
                  _DetailMoneyRow(
                    label: 'Overtime Pay',
                    value: overtimePay,
                  ),
                  _DetailMoneyRow(
                    label: 'Holiday Pay',
                    value: holidayPay,
                  ),
                  _DetailMoneyRow(
                    label: 'Allowances',
                    value: allowances,
                  ),
                  if (thirteenthMonthPay > 0)
                    _DetailMoneyRow(
                      label:
                          '13th-Month Pay',
                      value:
                          thirteenthMonthPay,
                    ),
                  const Divider(height: 22),
                  _DetailMoneyRow(
                    label: 'Gross Pay',
                    value: grossPay,
                    bold: true,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DetailsSection(
                title: 'Deductions',
                children: <Widget>[
                  _DetailMoneyRow(
                    label: 'SSS',
                    value: _number(
                      deductions['sss'] ??
                          data[
                              'sssContribution'],
                    ),
                  ),
                  _DetailMoneyRow(
                    label: 'PhilHealth',
                    value: _number(
                      deductions[
                              'philHealth'] ??
                          data[
                              'philHealthContribution'],
                    ),
                  ),
                  _DetailMoneyRow(
                    label: 'Pag-IBIG',
                    value: _number(
                      deductions['pagIbig'] ??
                          data[
                              'pagIbigContribution'],
                    ),
                  ),
                  _DetailMoneyRow(
                    label:
                        'Withholding Tax',
                    value: _number(
                      deductions[
                              'withholdingTax'] ??
                          data[
                              'withholdingTax'],
                    ),
                  ),
                  _DetailMoneyRow(
                    label: 'Loan',
                    value: _number(
                      deductions['loan'] ??
                          data[
                              'loanDeduction'],
                    ),
                  ),
                  _DetailMoneyRow(
                    label: 'Cash Advance',
                    value: _number(
                      deductions[
                              'cashAdvance'] ??
                          data['cashAdvance'],
                    ),
                  ),
                  _DetailMoneyRow(
                    label: 'Miscellaneous',
                    value: _number(
                      deductions[
                              'miscellaneous'] ??
                          data[
                              'miscellaneousDeduction'],
                    ),
                  ),
                  const Divider(height: 22),
                  _DetailMoneyRow(
                    label:
                        'Total Deductions',
                    value:
                        totalDeductions,
                    bold: true,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFECFDF3),
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        const Color(0xFFA6F4C5),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'NET PAY',
                        style: TextStyle(
                          color:
                              Color(0xFF027A48),
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      _formatMoney(netPay),
                      style: const TextStyle(
                        color:
                            Color(0xFF027A48),
                        fontSize: 22,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _DetailsSection(
                title: 'Approval Information',
                children: <Widget>[
                  _TextDetailRow(
                    label: 'Generated',
                    value: _formatDateTime(
                      generatedAt,
                    ),
                  ),
                  _TextDetailRow(
                    label: 'Approved By',
                    value: approver,
                  ),
                  _TextDetailRow(
                    label: 'Approved',
                    value: _formatDateTime(
                      approvedAt,
                    ),
                  ),
                  _TextDetailRow(
                    label: 'Payslip ID',
                    value: payslipId,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed:
                    downloading ? null : onDownload,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF2979FF),
                  foregroundColor: Colors.white,
                  minimumSize:
                      const Size.fromHeight(54),
                ),
                icon: downloading
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.download_outlined,
                      ),
                label: Text(
                  downloading
                      ? 'Preparing PDF...'
                      : 'Download / Share PDF',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailsSection
    extends StatelessWidget {
  const _DetailsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 11),
          ...children,
        ],
      ),
    );
  }
}

class _DetailMoneyRow
    extends StatelessWidget {
  const _DetailMoneyRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color:
                    const Color(0xFF667085),
                fontWeight: bold
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
          Text(
            _formatMoney(value),
            style: TextStyle(
              color:
                  const Color(0xFF101828),
              fontWeight: bold
                  ? FontWeight.w900
                  : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextDetailRow
    extends StatelessWidget {
  const _TextDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF101828),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyDetail extends StatelessWidget {
  const _MoneyDetail({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF98A2B3),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: highlight
                  ? const Color(0xFF039855)
                  : const Color(0xFF344054),
              fontSize: highlight ? 14 : 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _PayslipStatusChip
    extends StatelessWidget {
  const _PayslipStatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final bool released =
        status.toLowerCase() == 'released';

    final Color background = released
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFE3F2FD);

    final Color foreground = released
        ? const Color(0xFF2E7D32)
        : const Color(0xFF1565C0);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        _formatLabel(status),
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PayslipSummaryCard
    extends StatelessWidget {
  const _PayslipSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            color: foregroundColor,
            size: 24,
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayslipMessageState
    extends StatelessWidget {
  const _PayslipMessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 45,
      ),
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
          Icon(
            icon,
            size: 55,
            color: const Color(0xFF98A2B3),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
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
    );
  }
}

class _PayslipLoadingState
    extends StatelessWidget {
  const _PayslipLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _PayslipErrorState
    extends StatelessWidget {
  const _PayslipErrorState({
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
                'Unable to Load Payslips',
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

class _PayslipSummary {
  const _PayslipSummary({
    required this.count,
    required this.totalNetPay,
    required this.latestNetPay,
    required this.releasedCount,
  });

  final int count;
  final double totalNetPay;
  final double latestNetPay;
  final int releasedCount;
}

String _payrollType(
  Map<String, dynamic> data,
) {
  final String type =
      _text(
        data['payrollType'],
        fallback: 'regular',
      ).toLowerCase();

  if (type == '13th_month' ||
      type == 'thirteenthmonth') {
    return 'thirteenth_month';
  }

  return type;
}

int? _payslipYear(
  Map<String, dynamic> data,
) {
  final dynamic explicitYear =
      data['payrollYear'];

  if (explicitYear is num) {
    return explicitYear.toInt();
  }

  final int? parsedYear =
      int.tryParse(
    explicitYear?.toString() ?? '',
  );

  if (parsedYear != null) {
    return parsedYear;
  }

  return _date(data['payrollPeriodEnd'])
          ?.year ??
      _date(data['generatedAt'])?.year;
}

int _sortDate(
  Map<String, dynamic> data,
) {
  final DateTime? date =
      _date(data['payrollPeriodEnd']) ??
          _date(data['approvedAt']) ??
          _date(data['generatedAt']);

  return date?.millisecondsSinceEpoch ?? 0;
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

  return text.isEmpty ? fallback : text;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map<String, dynamic>(
      (
        dynamic key,
        dynamic item,
      ) =>
          MapEntry<String, dynamic>(
        key.toString(),
        item,
      ),
    );
  }

  return <String, dynamic>{};
}

String _periodLabel(
  DateTime? start,
  DateTime? end,
) {
  if (start == null && end == null) {
    return 'Payroll period unavailable';
  }

  if (start == null) {
    return _longDate(end);
  }

  if (end == null) {
    return _longDate(start);
  }

  return '${_shortDate(start)} – '
      '${_shortDate(end)}';
}

String _shortDate(DateTime value) {
  return '${_monthShortName(value.month)} '
      '${value.day}, ${value.year}';
}

String _longDate(DateTime? value) {
  if (value == null) {
    return 'Not available';
  }

  return '${_monthName(value.month)} '
      '${value.day}, ${value.year}';
}

String _formatDateTime(
  DateTime? value,
) {
  if (value == null) {
    return 'Not available';
  }

  final int hour =
      value.hour % 12 == 0
          ? 12
          : value.hour % 12;

  final String minute =
      value.minute.toString().padLeft(2, '0');

  final String period =
      value.hour >= 12 ? 'PM' : 'AM';

  return '${_shortDate(value)} • '
      '$hour:$minute $period';
}

String _formatMoney(double value) {
  return '₱${_groupedNumber(value)}';
}

String _formatCompactMoney(
  double value,
) {
  if (value.abs() >= 1000000) {
    return '₱${(value / 1000000).toStringAsFixed(1)}M';
  }

  if (value.abs() >= 1000) {
    return '₱${(value / 1000).toStringAsFixed(1)}K';
  }

  return '₱${value.toStringAsFixed(0)}';
}

String _groupedNumber(double value) {
  final bool negative = value < 0;

  final String fixed =
      value.abs().toStringAsFixed(2);

  final List<String> parts =
      fixed.split('.');

  final String whole = parts.first;

  final StringBuffer result =
      StringBuffer();

  for (int index = 0;
      index < whole.length;
      index++) {
    final int remaining =
        whole.length - index;

    result.write(whole[index]);

    if (remaining > 1 &&
        remaining % 3 == 1) {
      result.write(',');
    }
  }

  return '${negative ? '-' : ''}'
      '${result.toString()}.${parts.last}';
}

String _monthName(int month) {
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

  if (month < 1 || month > 12) {
    return '';
  }

  return months[month - 1];
}

String _monthShortName(int month) {
  const List<String> months = <String>[
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

  if (month < 1 || month > 12) {
    return '';
  }

  return months[month - 1];
}

String _formatLabel(String value) {
  if (value.trim().isEmpty) {
    return 'Unknown';
  }

  return value
      .replaceAll('_', ' ')
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
