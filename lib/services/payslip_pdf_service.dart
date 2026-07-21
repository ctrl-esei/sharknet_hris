import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_output.dart';

class PayslipPdfService {
  const PayslipPdfService._();

  static Future<void> sharePayslip({
    required Map<String, dynamic> data,
    required String payslipId,
  }) async {
    final pw.Document document = pw.Document();

    final String employeeName =
        data['employeeName']?.toString() ?? 'Employee';

    final String employeeId =
        _referenceId(data['employeeId']).toUpperCase();

    final String position =
        data['position']?.toString() ?? 'Not specified';

    final String status =
        data['status']?.toString().toUpperCase() ??
            'DRAFT';

    final DateTime? periodStart =
        _dateTimeFromValue(
      data['payrollPeriodStart'],
    );

    final DateTime? periodEnd =
        _dateTimeFromValue(
      data['payrollPeriodEnd'],
    );

    final double basicPay =
        _number(data['basicPay']);

    final double overtimePay =
        _number(data['overtimePay']);

    final double allowances =
        _number(data['allowances']);

    final double grossPay =
        _number(data['grossPay']);

    final double totalDeductions =
        _number(data['totalDeductions']);

    final double netPay =
        _number(data['netPay']);

    final Map<String, dynamic> deductions =
        _mapFromValue(
      data['deductionBreakdown'],
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (_) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(
              bottom: 14,
            ),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColors.orange700,
                  width: 2,
                ),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SHARKNET HRIS',
                      style: pw.TextStyle(
                        color: PdfColors.orange800,
                        fontSize: 20,
                        fontWeight:
                            pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Employee Payroll Payslip',
                      style: const pw.TextStyle(
                        color: PdfColors.grey700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: pw.BoxDecoration(
                    color:
                        _statusBackground(status),
                    borderRadius:
                        pw.BorderRadius.circular(12),
                  ),
                  child: pw.Text(
                    status,
                    style: pw.TextStyle(
                      color:
                          _statusForeground(status),
                      fontSize: 10,
                      fontWeight:
                          pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(
              top: 12,
            ),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(
                  color: PdfColors.grey300,
                ),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Payslip ID: $payslipId',
                  style: const pw.TextStyle(
                    color: PdfColors.grey600,
                    fontSize: 8,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of '
                  '${context.pagesCount}',
                  style: const pw.TextStyle(
                    color: PdfColors.grey600,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          );
        },
        build: (_) {
          return [
            pw.SizedBox(height: 20),

            _informationBox(
              title: 'Employee Information',
              rows: [
                [
                  'Employee Name',
                  employeeName,
                ],
                [
                  'Employee ID',
                  employeeId,
                ],
                [
                  'Position',
                  position,
                ],
                [
                  'Payroll Period',
                  '${_formatDate(periodStart)} - '
                      '${_formatDate(periodEnd)}',
                ],
              ],
            ),

            pw.SizedBox(height: 20),

            _sectionTitle('Earnings'),

            pw.SizedBox(height: 8),

            _moneyTable(
              rows: [
                [
                  'Basic Pay',
                  basicPay,
                ],
                [
                  'Overtime Pay',
                  overtimePay,
                ],
                [
                  'Allowances',
                  allowances,
                ],
              ],
              totalLabel: 'Gross Pay',
              totalValue: grossPay,
            ),

            pw.SizedBox(height: 20),

            _sectionTitle('Deductions'),

            pw.SizedBox(height: 8),

            _moneyTable(
              rows: [
                [
                  'SSS',
                  _number(
                    deductions['sss'],
                  ),
                ],
                [
                  'PhilHealth',
                  _number(
                    deductions['philHealth'],
                  ),
                ],
                [
                  'Pag-IBIG',
                  _number(
                    deductions['pagIbig'],
                  ),
                ],
                [
                  'Withholding Tax',
                  _number(
                    deductions[
                        'withholdingTax'],
                  ),
                ],
                [
                  'Loan Deduction',
                  _number(
                    deductions['loan'],
                  ),
                ],
                [
                  'Cash Advance',
                  _number(
                    deductions['cashAdvance'],
                  ),
                ],
                [
                  'Miscellaneous',
                  _number(
                    deductions[
                        'miscellaneous'],
                  ),
                ],
              ],
              totalLabel: 'Total Deductions',
              totalValue: totalDeductions,
            ),

            pw.SizedBox(height: 24),

            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColors.orange50,
                border: pw.Border.all(
                  color: PdfColors.orange300,
                ),
                borderRadius:
                    pw.BorderRadius.circular(12),
              ),
              child: pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment
                        .spaceBetween,
                children: [
                  pw.Text(
                    'NET PAY',
                    style: pw.TextStyle(
                      color: PdfColors.orange900,
                      fontSize: 16,
                      fontWeight:
                          pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    _money(netPay),
                    style: pw.TextStyle(
                      color: PdfColors.orange900,
                      fontSize: 22,
                      fontWeight:
                          pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            pw.Text(
              'This document was generated '
              'electronically by SharkNet HRIS.',
              style: const pw.TextStyle(
                color: PdfColors.grey600,
                fontSize: 9,
              ),
            ),
          ];
        },
      ),
    );

    final String fileName =
        'payslip_${employeeId.toLowerCase()}_'
        '${_compactDate(periodStart)}.pdf';

    final bytes = await document.save();

    await savePdfFile(
      bytes: bytes,
      fileName: fileName,
    );
  }

  static Future<void> sharePayrollSummary({
    required List<Map<String, dynamic>> payslips,
  }) async {
    final pw.Document document = pw.Document();

    double totalGross = 0;
    double totalDeductions = 0;
    double totalNet = 0;

    for (final Map<String, dynamic> payslip
        in payslips) {
      totalGross +=
          _number(payslip['grossPay']);

      totalDeductions +=
          _number(
        payslip['totalDeductions'],
      );

      totalNet +=
          _number(payslip['netPay']);
    }

    document.addPage(
      pw.MultiPage(
        pageFormat:
            PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        header: (_) {
          return pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SHARKNET HRIS',
                style: pw.TextStyle(
                  color: PdfColors.orange800,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Released Payroll Summary',
                style: const pw.TextStyle(
                  color: PdfColors.grey700,
                  fontSize: 12,
                ),
              ),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(
              top: 10,
            ),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(
                  color: PdfColors.grey300,
                ),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment
                      .spaceBetween,
              children: [
                pw.Text(
                  'Generated by SharkNet HRIS',
                  style: const pw.TextStyle(
                    color: PdfColors.grey600,
                    fontSize: 8,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of '
                  '${context.pagesCount}',
                  style: const pw.TextStyle(
                    color: PdfColors.grey600,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          );
        },
        build: (_) {
          return [
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.3),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(1.8),
                3: pw.FlexColumnWidth(1.4),
                4: pw.FlexColumnWidth(1.4),
                5: pw.FlexColumnWidth(1.4),
              },
              children: [
                _summaryHeaderRow(),
                ...payslips.map(
                  _summaryDataRow,
                ),
              ],
            ),

            pw.SizedBox(height: 22),

            pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.end,
              children: [
                _summaryTotalBox(
                  label: 'Gross',
                  value: totalGross,
                ),
                pw.SizedBox(width: 10),
                _summaryTotalBox(
                  label: 'Deductions',
                  value: totalDeductions,
                ),
                pw.SizedBox(width: 10),
                _summaryTotalBox(
                  label: 'Net Payroll',
                  value: totalNet,
                ),
              ],
            ),
          ];
        },
      ),
    );

    final String fileName =
        'sharknet_payroll_summary_'
        '${_compactDate(DateTime.now())}.pdf';

    final bytes = await document.save();

    await savePdfFile(
      bytes: bytes,
      fileName: fileName,
    );
  }

  static pw.Widget _informationBox({
    required String title,
    required List<List<String>> rows,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius:
            pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          ...rows.map(
            (row) => pw.Padding(
              padding: const pw.EdgeInsets.only(
                bottom: 6,
              ),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 125,
                    child: pw.Text(
                      row[0],
                      style:
                          const pw.TextStyle(
                        color:
                            PdfColors.grey700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      row[1],
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight:
                            pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(
    String title,
  ) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        color: PdfColors.grey900,
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  static pw.Widget _moneyTable({
    required List<List<dynamic>> rows,
    required String totalLabel,
    required double totalValue,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
      },
      children: [
        ...rows.map(
          (row) => pw.TableRow(
            children: [
              _tableCell(
                row[0].toString(),
              ),
              _tableCell(
                _money(
                  _number(row[1]),
                ),
                alignRight: true,
              ),
            ],
          ),
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
          ),
          children: [
            _tableCell(
              totalLabel,
              bold: true,
            ),
            _tableCell(
              _money(totalValue),
              bold: true,
              alignRight: true,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _tableCell(
    String value, {
    bool bold = false,
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      child: pw.Text(
        value,
        textAlign: alignRight
            ? pw.TextAlign.right
            : null,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold
              ? pw.FontWeight.bold
              : null,
        ),
      ),
    );
  }

  static pw.TableRow _summaryHeaderRow() {
    const List<String> headings = [
      'Employee',
      'Employee ID',
      'Period',
      'Gross',
      'Deductions',
      'Net Pay',
    ];

    return pw.TableRow(
      decoration: const pw.BoxDecoration(
        color: PdfColors.orange700,
      ),
      children: headings
          .map(
            (heading) => pw.Padding(
              padding:
                  const pw.EdgeInsets.all(8),
              child: pw.Text(
                heading,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  static pw.TableRow _summaryDataRow(
    Map<String, dynamic> data,
  ) {
    final DateTime? start =
        _dateTimeFromValue(
      data['payrollPeriodStart'],
    );

    final DateTime? end =
        _dateTimeFromValue(
      data['payrollPeriodEnd'],
    );

    final List<String> values = [
      data['employeeName']?.toString() ??
          'Employee',
      _referenceId(
        data['employeeId'],
      ).toUpperCase(),
      '${_formatDate(start)} - '
          '${_formatDate(end)}',
      _money(
        _number(data['grossPay']),
      ),
      _money(
        _number(
          data['totalDeductions'],
        ),
      ),
      _money(
        _number(data['netPay']),
      ),
    ];

    return pw.TableRow(
      children: values
          .map(
            (value) => pw.Padding(
              padding:
                  const pw.EdgeInsets.all(7),
              child: pw.Text(
                value,
                style:
                    const pw.TextStyle(
                  fontSize: 8,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _summaryTotalBox({
    required String label,
    required double value,
  }) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius:
            pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              color: PdfColors.grey700,
              fontSize: 9,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _money(value),
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static PdfColor _statusBackground(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'released':
        return PdfColors.green100;

      case 'approved':
        return PdfColors.blue100;

      default:
        return PdfColors.orange100;
    }
  }

  static PdfColor _statusForeground(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'released':
        return PdfColors.green800;

      case 'approved':
        return PdfColors.blue800;

      default:
        return PdfColors.orange800;
    }
  }

  static Map<String, dynamic> _mapFromValue(
    dynamic value,
  ) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return {};
  }

  static double _number(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static String _referenceId(
    dynamic value,
  ) {
    if (value is DocumentReference) {
      return value.id;
    }

    final String raw =
        value?.toString() ?? 'employee';

    if (raw.contains('/')) {
      return raw.split('/').last;
    }

    return raw;
  }

  static DateTime? _dateTimeFromValue(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static String _formatDate(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Not available';
    }

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

  static String _compactDate(
    DateTime? date,
  ) {
    final DateTime value =
        date ?? DateTime.now();

    final String month =
        value.month.toString().padLeft(
              2,
              '0',
            );

    final String day =
        value.day.toString().padLeft(
              2,
              '0',
            );

    return '${value.year}$month$day';
  }

  static String _money(
    double value,
  ) {
    return 'PHP ${value.toStringAsFixed(2)}';
  }
}