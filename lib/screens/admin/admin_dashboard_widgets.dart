import 'package:flutter/material.dart';

import '../../services/admin_dashboard_service.dart';

class AdminPortalHeader extends StatelessWidget {
  const AdminPortalHeader({
    required this.adminName,
    required this.adminId,
    required this.onLogout,
    super.key,
    this.title = 'System Control',
  });

  final String adminName;
  final String adminId;
  final String title;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        24,
        22,
        24,
        30,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF7928E8),
            Color(0xFF8E4DF4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'ADMIN PORTAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    letterSpacing: 1.6,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    height: 1,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                adminName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                adminId.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFE7D7FF),
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.white.withValues(
              alpha: 0.20,
            ),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onLogout,
              customBorder:
                  const CircleBorder(),
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    super.key,
    this.onTap,
  });

  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 205,
          ),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFE4E7EC),
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: accentColor.withValues(
                    alpha: 0.08,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 29,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                value,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 36,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF98A2B3),
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminSectionCard extends StatelessWidget {
  const AdminSectionCard({
    required this.title,
    required this.child,
    super.key,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              16,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color:
                          Color(0xFF101828),
                      fontSize: 19,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

class AdminHealthTile extends StatelessWidget {
  const AdminHealthTile({
    required this.item,
    super.key,
  });

  final AdminHealthItem item;

  @override
  Widget build(BuildContext context) {
    final Color color =
        adminHealthColor(item.status);

    final String detail =
        item.uptimePercentage != null
            ? 'Uptime ${item.uptimePercentage!.toStringAsFixed(1)}% • '
                '${item.averageResponseMs.toStringAsFixed(0)}ms avg'
            : '${item.averageResponseMs.toStringAsFixed(0)}ms last check';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 15,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFF9F0FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _healthIcon(item.id),
              color: const Color(0xFFB037FF),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.serviceName,
                  style: const TextStyle(
                    color:
                        Color(0xFF101828),
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    color:
                        Color(0xFF98A2B3),
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: 0.55,
              ),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            adminFormatLabel(item.status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  IconData _healthIcon(String id) {
    switch (id) {
      case 'authentication':
        return Icons.shield_outlined;
      case 'firestore':
        return Icons.storage_outlined;
      case 'face_recognition':
        return Icons.remove_red_eye_outlined;
      default:
        return Icons.wifi_rounded;
    }
  }
}

class AdminActivityTile extends StatelessWidget {
  const AdminActivityTile({
    required this.item,
    super.key,
    this.onTap,
  });

  final AdminActivityItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color color =
        adminCategoryColor(item.category);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: 0.08,
                ),
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: Text(
                adminFormatLabel(
                  item.category,
                ),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w900,
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
                    item.title,
                    style: const TextStyle(
                      color:
                          Color(0xFF101828),
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  if (item.description
                      .isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      item.description,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color:
                            Color(0xFF98A2B3),
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              adminTimeAgo(item.createdAt),
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({
    required this.status,
    super.key,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color color =
        adminHealthColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.09,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        adminFormatLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 36,
      ),
      child: Column(
        children: <Widget>[
          Icon(
            icon,
            size: 52,
            color: const Color(0xFF98A2B3),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
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

Color adminCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'payroll':
      return const Color(0xFF00A63E);
    case 'leave':
      return const Color(0xFF155EEF);
    case 'attendance':
      return const Color(0xFF009688);
    case 'users':
    case 'user_mgmt':
      return const Color(0xFF9810FA);
    case 'auth':
      return const Color(0xFFEF6C00);
    default:
      return const Color(0xFF667085);
  }
}

Color adminHealthColor(String status) {
  switch (status.toLowerCase()) {
    case 'online':
    case 'active':
    case 'resolved':
    case 'approved':
      return const Color(0xFF00A63E);
    case 'warning':
    case 'pending':
    case 'unresolved':
      return const Color(0xFFEF6C00);
    case 'offline':
    case 'inactive':
    case 'disabled':
    case 'suspended':
    case 'high':
    case 'critical':
      return const Color(0xFFD92D20);
    default:
      return const Color(0xFF667085);
  }
}