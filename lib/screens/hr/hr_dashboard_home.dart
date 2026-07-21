import 'package:flutter/material.dart';
import '../../services/hr_kpi_service.dart';
import 'hr_dashboard_widgets.dart';

class HrDashboardHome extends StatelessWidget {
  const HrDashboardHome({
    required this.onRunPayroll,
    required this.onAddEmployee,
    required this.onFaceAttendance,
    required this.onApproveLeaves,
    super.key,
  });

  final VoidCallback onRunPayroll;
  final VoidCallback onAddEmployee;
  final VoidCallback onFaceAttendance;
  final VoidCallback onApproveLeaves;

  static final HrKpiService _kpiService = HrKpiService();

  @override
  Widget build(BuildContext context) {
    final List<_KpiConfiguration> kpis = [
      _KpiConfiguration(
        stream: _kpiService.activeEmployees(),
        title: 'Total Employees',
        subtitleBuilder: (value) => '$value active',
        icon: Icons.people_outline_rounded,
        accentColor: const Color(0xFFF04B0B),
        iconBackground: const Color(0xFFFFF4E8),
      ),
      _KpiConfiguration(
        stream: _kpiService.presentToday(),
        title: 'Present Today',
        subtitleBuilder: (_) => 'face verified',
        icon: Icons.check_circle_outline_rounded,
        accentColor: const Color(0xFF00A83B),
        iconBackground: const Color(0xFFECFBF1),
      ),
      _KpiConfiguration(
        stream: _kpiService.pendingLeaves(),
        title: 'Pending Leaves',
        subtitleBuilder: (_) => 'need action',
        icon: Icons.calendar_today_outlined,
        accentColor: const Color(0xFFE36B00),
        iconBackground: const Color(0xFFFFF8E1),
      ),
      _KpiConfiguration(
        stream: _kpiService.draftPayslips(),
        title: 'Payslips Draft',
        subtitleBuilder: (_) => 'to release',
        icon: Icons.description_outlined,
        accentColor: const Color(0xFF1F5CF5),
        iconBackground: const Color(0xFFECF3FF),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool oneColumn = constraints.maxWidth < 340;
        final int columnCount = oneColumn ? 1 : 2;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            18,
            22,
            18,
            30,
          ),
          children: [
            const Text(
              'Dashboard Overview',
              style: TextStyle(
                color: Color(0xFF101828),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Review today’s HR and payroll information.',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            // KPI CARDS
            GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: kpis.length,
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: oneColumn ? 165 : 185,
                  ),
              itemBuilder: (context, index) {
                final _KpiConfiguration kpi = kpis[index];

                return _KpiCard(
                  stream: kpi.stream,
                  title: kpi.title,
                  subtitleBuilder: kpi.subtitleBuilder,
                  icon: kpi.icon,
                  accentColor: kpi.accentColor,
                  iconBackground: kpi.iconBackground,
                );
              },
            ),

            const SizedBox(height: 24),

            // QUICK ACTIONS
            QuickActionsCard(
              onRunPayroll: onRunPayroll,
              onAddEmployee: onAddEmployee,
              onFaceAttendance: onFaceAttendance,
              onApproveLeaves: onApproveLeaves,
            ),

            const SizedBox(height: 24),

            // LIVE PENDING LEAVE NOTIFICATIONS
            const PendingLeaveNotifications(),

            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.stream,
    required this.title,
    required this.subtitleBuilder,
    required this.icon,
    required this.accentColor,
    required this.iconBackground,
  });

  final Stream<int> stream;
  final String title;
  final String Function(int value) subtitleBuilder;
  final IconData icon;
  final Color accentColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final bool isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        final bool hasError = snapshot.hasError;
        final int value = snapshot.data ?? 0;

        if (hasError) {
          debugPrint(
            'Unable to load $title KPI: ${snapshot.error}',
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 25,
                ),
              ),

              const Spacer(),

              if (isLoading)
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: accentColor,
                  ),
                )
              else
                Text(
                  hasError ? '--' : '$value',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),

              const SizedBox(height: 8),

              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                hasError
                    ? 'unable to load'
                    : isLoading
                    ? 'loading...'
                    : subtitleBuilder(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF98A2B3),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KpiConfiguration {
  const _KpiConfiguration({
    required this.stream,
    required this.title,
    required this.subtitleBuilder,
    required this.icon,
    required this.accentColor,
    required this.iconBackground,
  });

  final Stream<int> stream;
  final String title;
  final String Function(int value) subtitleBuilder;
  final IconData icon;
  final Color accentColor;
  final Color iconBackground;
}