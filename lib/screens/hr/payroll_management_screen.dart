import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/payroll_settings_service.dart';
import '../../services/payslip_pdf_service.dart';
import 'payslips_screen.dart';
import 'run_payroll_screen.dart';
import 'thirteenth_month_screen.dart';

class PayrollManagementScreen extends StatefulWidget {
  const PayrollManagementScreen({
    super.key,
  });

  @override
  State<PayrollManagementScreen> createState() =>
      _PayrollManagementScreenState();
}

class _PayrollManagementScreenState
    extends State<PayrollManagementScreen> {
  final GlobalKey _employeeSectionKey = GlobalKey();

  bool _isDownloadingReport = false;

  bool _isInitializingSettings = true;

  String? _settingsInitializationError;

  @override
  void initState() {
    super.initState();

    _initializePayrollSettings();
  }

  Future<void> _initializePayrollSettings() async {
    if (mounted) {
      setState(() {
        _isInitializingSettings = true;
        _settingsInitializationError = null;
      });
    }

    try {
      await PayrollSettingsService.ensureInitialized();

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializingSettings = false;
        _settingsInitializationError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializingSettings = false;
        _settingsInitializationError = error.toString();
      });
    }
  }

  void _scrollToEmployees() {
    final BuildContext? employeeContext =
        _employeeSectionKey.currentContext;

    if (employeeContext == null) {
      return;
    }

    Scrollable.ensureVisible(
      employeeContext,
      duration: const Duration(
        milliseconds: 450,
      ),
      curve: Curves.easeOut,
      alignment: 0.05,
    );
  }

  Future<void> _openPayslips() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PayslipsScreen(),
      ),
    );
  }

  Future<void> _downloadReport() async {
    if (_isDownloadingReport) {
      return;
    }

    setState(() {
      _isDownloadingReport = true;
    });

    try {
      final QuerySnapshot<Map<String, dynamic>>
          snapshot = await FirebaseFirestore.instance
              .collection('payslips')
              .where(
                'status',
                isEqualTo: 'released',
              )
              .get();

      final List<Map<String, dynamic>> payslips =
          snapshot.docs.map(
        (
          QueryDocumentSnapshot<Map<String, dynamic>>
              document,
        ) {
          return document.data();
        },
      ).toList();

      if (!mounted) {
        return;
      }

      if (payslips.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'There are no released payslips '
                'to include in the report.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );

        return;
      }

      await PayslipPdfService.sharePayrollSummary(
        payslips: payslips,
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
              'Unable to generate payroll report: '
              '$error',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(
              0xFFD92D20,
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingReport = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializingSettings) {
      return const _PayrollLoadingState();
    }

    if (_settingsInitializationError != null) {
      return _PayrollSettingsErrorState(
        message: _settingsInitializationError!,
        onRetry: _initializePayrollSettings,
      );
    }

    return Container(
      color: const Color(0xFFF2F6FC),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          18,
          18,
          18,
          100,
        ),
        children: [
          const Text(
            'Payroll & Reports',
            style: TextStyle(
              color: Color(0xFF101828),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Compute payroll, manage payslips, '
            'and generate payroll reports.',
            style: TextStyle(
              color: Color(0xFF667085),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),

          _PayrollSettingsStatusCard(
            onRefresh: _initializePayrollSettings,
          ),

          const SizedBox(height: 16),

          _PayrollFeatureCard(
            title: 'Payroll Run',
            description: 'Compute payroll for employees',
            icon: Icons.calculate_outlined,
            iconColor: const Color(0xFFF04B0B),
            iconBackground: const Color(0xFFFFF7ED),
            onTap: _scrollToEmployees,
          ),

          const SizedBox(height: 13),

          _PayrollFeatureCard(
            title: 'Payslips',
            description:
                'View, approve, release, and download payslips',
            icon: Icons.description_outlined,
            iconColor: const Color(0xFF1F5CF5),
            iconBackground: const Color(0xFFF0F6FF),
            onTap: _openPayslips,
          ),

          const SizedBox(height: 13),

          _PayrollFeatureCard(
            title: 'Reports',
            description:
                'Download a released payroll summary',
            icon: Icons.bar_chart_outlined,
            iconColor: const Color(0xFF039855),
            iconBackground: const Color(0xFFECFDF3),
            loading: _isDownloadingReport,
            onTap: _downloadReport,
          ),

          const SizedBox(height: 13),

          _PayrollFeatureCard(
            title: '13th-Month Pay',
            description:
                'Calculate annual 13th-month benefits',
            icon: Icons.card_giftcard_outlined,
            iconColor: const Color(0xFF7F56D9),
            iconBackground: const Color(0xFFF4F3FF),
            onTap: _scrollToEmployees,
          ),

          const SizedBox(height: 22),

          Container(
            key: _employeeSectionKey,
            padding: const EdgeInsets.only(
              top: 2,
            ),
            child: const Text(
              'Run Payroll Per Employee',
              style: TextStyle(
                color: Color(0xFF101828),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Select an active employee to calculate '
            'their payroll.',
            style: TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 12),

          _buildEmployeeList(),
        ],
      ),
    );
  }

  Widget _buildEmployeeList() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('employee')
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                QuerySnapshot<Map<String, dynamic>>>
            snapshot,
      ) {
        if (snapshot.hasError) {
          return _MessageCard(
            icon: Icons.error_outline,
            title: 'Unable to Load Employees',
            message:
                'Unable to load employees: '
                '${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final List<
                QueryDocumentSnapshot<
                    Map<String, dynamic>>>
            employees = snapshot.data!.docs.where(
          (
            QueryDocumentSnapshot<Map<String, dynamic>>
                document,
          ) {
            final String status =
                document
                        .data()['employmentStatus']
                        ?.toString()
                        .trim()
                        .toLowerCase() ??
                    'active';

            return status == 'active';
          },
        ).toList();

        employees.sort(
          (
            QueryDocumentSnapshot<Map<String, dynamic>>
                first,
            QueryDocumentSnapshot<Map<String, dynamic>>
                second,
          ) {
            final String firstName =
                first.data()['fullName']?.toString() ??
                    first.id;

            final String secondName =
                second.data()['fullName']?.toString() ??
                    second.id;

            return firstName
                .toLowerCase()
                .compareTo(
                  secondName.toLowerCase(),
                );
          },
        );

        if (employees.isEmpty) {
          return const _MessageCard(
            icon: Icons.people_outline,
            title: 'No Active Employees',
            message:
                'Add or activate an employee before '
                'running payroll.',
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFE4E7EC),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: List.generate(
              employees.length,
              (int index) {
                final QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    document = employees[index];

                final Map<String, dynamic> data =
                    document.data();

                final String fullName =
                    data['fullName']?.toString() ??
                        document.id.toUpperCase();

                final String position =
                    data['position']?.toString() ??
                        'Position not specified';

                final String salaryType =
                    data['salaryType']
                            ?.toString()
                            .toLowerCase() ??
                        'monthly';

                final double salaryRate =
                    _readNumber(
                  data['salaryRate'],
                );

                return Column(
                  children: [
                    _EmployeePayrollRow(
                      employeeId: document.id,
                      fullName: fullName,
                      position: position,
                      salaryType: salaryType,
                      salaryRate: salaryRate,
                    ),
                    if (index <
                        employees.length - 1)
                      const Divider(
                        height: 1,
                        color: Color(0xFFEAECF0),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// SETTINGS STATUS
// ============================================================

class _PayrollSettingsStatusCard
    extends StatelessWidget {
  const _PayrollSettingsStatusCard({
    required this.onRefresh,
  });

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD2E2FF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFDCEAFF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.settings_suggest_outlined,
              color: Color(0xFF1F5CF5),
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Payroll Settings Ready',
                  style: TextStyle(
                    color: Color(0xFF1849A9),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Government compliance and holiday '
                  'rules are connected to Firebase.',
                  style: TextStyle(
                    color: Color(0xFF475467),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Reload payroll settings',
            icon: const Icon(
              Icons.refresh,
              color: Color(0xFF1F5CF5),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FEATURE CARD
// ============================================================

class _PayrollFeatureCard extends StatelessWidget {
  const _PayrollFeatureCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
    this.loading = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFE4E7EC),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A101828),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 63,
                height: 63,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: iconColor.withValues(
                      alpha: 0.15,
                    ),
                  ),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFD0D5DD),
                  size: 30,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EMPLOYEE PAYROLL ROW
// ============================================================

class _EmployeePayrollRow extends StatelessWidget {
  const _EmployeePayrollRow({
    required this.employeeId,
    required this.fullName,
    required this.position,
    required this.salaryType,
    required this.salaryRate,
  });

  final String employeeId;
  final String fullName;
  final String position;
  final String salaryType;
  final double salaryRate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFFFF7ED),
            child: Text(
              _initials(fullName),
              style: const TextStyle(
                color: Color(0xFFF04B0B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  position,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatMoney(salaryRate)} • '
                  '${_formatLabel(salaryType)}',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 112,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RunPayrollScreen(
                          employeeId: employeeId,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF04B0B),
                    backgroundColor: const Color(0xFFFFF7ED),
                    side: const BorderSide(
                      color: Color(0xFFFFDDBD),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(
                    Icons.calculate_outlined,
                    size: 18,
                  ),
                  label: const Text('Run'),
                ),
              ),
              const SizedBox(height: 7),
              SizedBox(
                width: 112,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ThirteenthMonthScreen(
                          employeeId: employeeId,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7F56D9),
                    backgroundColor: const Color(0xFFF4F3FF),
                    side: const BorderSide(
                      color: Color(0xFFD9D6FE),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(
                    Icons.card_giftcard_outlined,
                    size: 18,
                  ),
                  label: const Text('13th'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LOADING AND ERROR STATES
// ============================================================

class _PayrollLoadingState extends StatelessWidget {
  const _PayrollLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F6FC),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Color(0xFFF04B0B),
              ),
              SizedBox(height: 16),
              Text(
                'Initializing payroll settings...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF475467),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayrollSettingsErrorState
    extends StatelessWidget {
  const _PayrollSettingsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F6FC),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 520,
            ),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFDA29B),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Color(0xFFD92D20),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Unable to Initialize Payroll Settings',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 19),
                FilledButton.icon(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFF04B0B),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
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
        vertical: 35,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 50,
            color: const Color(0xFF98A2B3),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 17,
              fontWeight: FontWeight.w800,
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

// ============================================================
// HELPERS
// ============================================================

double _readNumber(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
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

String _formatMoney(double value) {
  return 'PHP ${value.toStringAsFixed(2)}';
}

String _formatLabel(String value) {
  if (value.trim().isEmpty) {
    return 'Not specified';
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