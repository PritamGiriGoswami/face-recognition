import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/tesla_theme.dart';

class StudentDashboardScreen extends StatefulWidget {
  final String email;

  const StudentDashboardScreen({super.key, required this.email});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = ApiService.getStudentDashboard(widget.email);
  }

  void _refresh() {
    setState(() {
      _dashboardFuture = ApiService.getStudentDashboard(widget.email);
    });
  }

  Uint8List? _decodeBase64Image(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    final normalized =
        base64Str.contains(',') ? base64Str.split(',').last : base64Str;
    try {
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TeslaTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('My Dashboard',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: TeslaTheme.onSurfaceVariant),
            onPressed: _refresh,
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 80, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    const Text(
                      'Oops! User Not Found',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please ensure that "${widget.email}" is registered.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: TeslaTheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    TeslaButton(
                      isSecondary: true,
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final user = data['user'] as Map<String, dynamic>;
          final stats = data['stats'] as Map<String, dynamic>;
          final dailyRecords = data['daily_records'] as List<dynamic>;
          final monthlyAnalytics = data['monthly_analytics'] as List<dynamic>;

          final faceBytes = _decodeBase64Image(user['face_image_base64']);
          final percent = (stats['attendance_percentage'] as num).toDouble();
          final isGoodStanding = percent >= 75.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Minimalist User Header
                TeslaCard(
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isGoodStanding ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: TeslaTheme.surfaceHigh,
                          backgroundImage:
                              faceBytes == null ? null : MemoryImage(faceBytes),
                          child: faceBytes == null
                              ? const Icon(Icons.person, size: 36, color: TeslaTheme.onSurfaceVariant)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Info Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name'] ?? 'Unknown Name',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user['email'] ?? '',
                              style: const TextStyle(color: TeslaTheme.onSurfaceVariant, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (user['class_name'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: TeslaTheme.surfaceHighlight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.school, size: 12, color: TeslaTheme.onSurfaceVariant),
                                        const SizedBox(width: 4),
                                        Text(user['class_name'], style: const TextStyle(fontSize: 11, color: TeslaTheme.onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                if (user['department'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: TeslaTheme.surfaceHighlight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.business, size: 12, color: TeslaTheme.onSurfaceVariant),
                                        const SizedBox(width: 4),
                                        Text(user['department'], style: const TextStyle(fontSize: 11, color: TeslaTheme.onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Radial Stats HUD Row
                Row(
                  children: [
                    // Circular Progress Performance
                    Expanded(
                      flex: 4,
                      child: TeslaCard(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          height: 140,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: CircularProgressIndicator(
                                      value: percent / 100,
                                      strokeWidth: 6,
                                      backgroundColor: TeslaTheme.surfaceHighlight,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isGoodStanding ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "${percent.toStringAsFixed(0)}%",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isGoodStanding
                                    ? 'Good Standing'
                                    : 'Needs Attention',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isGoodStanding ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Stats Columns
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 172,
                        child: Column(
                          children: [
                            _buildStatBadge(
                              title: 'Present Days',
                              value: '${stats['present_days']}',
                              icon: Icons.check_circle_outline,
                              color: const Color(0xFF4ADE80),
                            ),
                            const SizedBox(height: 12),
                            _buildStatBadge(
                              title: 'Late Entries',
                              value: '${stats['late_days']}',
                              icon: Icons.warning_amber_rounded,
                              color: const Color(0xFFFBBF24),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Heatmap Calendar Section
                _buildSectionHeader(title: 'Attendance Heatmap', icon: Icons.calendar_month_outlined),
                const SizedBox(height: 16),
                _buildCalendarHeatmap(context, dailyRecords),
                const SizedBox(height: 32),

                // Monthly Analytics Section
                _buildSectionHeader(title: 'Monthly Analytics', icon: Icons.bar_chart_outlined),
                const SizedBox(height: 16),
                _buildMonthlyAnalytics(context, monthlyAnalytics),
                const SizedBox(height: 32),

                // Daily Reports Timeline Section
                _buildSectionHeader(title: 'Daily Reports', icon: Icons.timeline_outlined),
                const SizedBox(height: 16),
                _buildDailyTimeline(context, dailyRecords),
                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatBadge({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: TeslaCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(color: TeslaTheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: TeslaTheme.primary, size: 20),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarHeatmap(
      BuildContext context, List<dynamic> dailyRecords) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstDayOfWeek = DateTime(now.year, now.month, 1).weekday;

    // Create index to status mappings
    final Map<int, String> recordStatusMap = {};
    final Map<int, bool> recordLateMap = {};

    for (var r in dailyRecords) {
      try {
        final date = DateTime.parse(r['date']);
        if (date.year == now.year && date.month == now.month) {
          recordStatusMap[date.day] = r['status'];
          recordLateMap[date.day] = r['is_late'] == true;
        }
      } catch (_) {}
    }

    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final currentMonthName = monthNames[now.month - 1];

    return TeslaCard(
      child: Column(
        children: [
          // Month Header title
          Text(
            "$currentMonthName ${now.year}",
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Weekdays labels
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('M', style: TextStyle(fontWeight: FontWeight.w500, color: TeslaTheme.onSurfaceVariant, fontSize: 12)),
              Text('T', style: TextStyle(fontWeight: FontWeight.w500, color: TeslaTheme.onSurfaceVariant, fontSize: 12)),
              Text('W', style: TextStyle(fontWeight: FontWeight.w500, color: TeslaTheme.onSurfaceVariant, fontSize: 12)),
              Text('T', style: TextStyle(fontWeight: FontWeight.w500, color: TeslaTheme.onSurfaceVariant, fontSize: 12)),
              Text('F', style: TextStyle(fontWeight: FontWeight.w500, color: TeslaTheme.onSurfaceVariant, fontSize: 12)),
              Text('S', style: TextStyle(fontWeight: FontWeight.w500, color: TeslaTheme.outlineVariant, fontSize: 12)),
              Text('S', style: TextStyle(fontWeight: FontWeight.w500, color: TeslaTheme.outlineVariant, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),

          // Days Heatmap Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: daysInMonth + (firstDayOfWeek - 1),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final dayNum = index - (firstDayOfWeek - 2);
              if (dayNum <= 0) {
                return const SizedBox.shrink();
              }

              final status = recordStatusMap[dayNum];
              final isLate = recordLateMap[dayNum] == true;

              Color cellColor = TeslaTheme.surfaceHigh;
              Color textColor = TeslaTheme.onSurface;

              final cellDate = DateTime(now.year, now.month, dayNum);
              final isFuture = cellDate.isAfter(now);
              final isWeekend = cellDate.weekday == DateTime.saturday ||
                  cellDate.weekday == DateTime.sunday;

              if (isFuture) {
                cellColor = TeslaTheme.surface;
                textColor = TeslaTheme.outlineVariant;
              } else if (status != null) {
                if (isLate) {
                  cellColor = const Color(0xFFFBBF24).withValues(alpha: 0.2);
                  textColor = const Color(0xFFFBBF24);
                } else {
                  cellColor = const Color(0xFF4ADE80).withValues(alpha: 0.2);
                  textColor = const Color(0xFF4ADE80);
                }
              } else if (!isWeekend) {
                cellColor = const Color(0xFFEF4444).withValues(alpha: 0.1);
                textColor = const Color(0xFFEF4444);
              } else {
                cellColor = TeslaTheme.surfaceHighlight;
                textColor = TeslaTheme.onSurfaceVariant;
              }

              return Tooltip(
                message: status != null
                    ? "Day $dayNum: ${isLate ? 'Late Arrival' : 'Present'}"
                    : (isFuture
                        ? "Future"
                        : (isWeekend ? "Weekend" : "Absent")),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "$dayNum",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('Present', const Color(0xFF4ADE80)),
              _buildLegendItem('Late', const Color(0xFFFBBF24)),
              _buildLegendItem('Absent', const Color(0xFFEF4444)),
              _buildLegendItem('Weekend', TeslaTheme.outlineVariant),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 10, color: TeslaTheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildMonthlyAnalytics(
      BuildContext context, List<dynamic> monthlyAnalytics) {
    if (monthlyAnalytics.isEmpty) {
      return const TeslaCard(
        child: Center(
            child: Text('No monthly analytical history.', style: TextStyle(color: TeslaTheme.onSurfaceVariant))),
      );
    }

    return TeslaCard(
      child: Column(
        children: monthlyAnalytics.map<Widget>((m) {
          final present = m['present'] as int;
          final lateCount = m['late'] as int;
          final total = present + lateCount;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      m['month'] ?? 'Unknown Month',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                    Text(
                      "$present Pres. | $lateCount Late",
                      style: const TextStyle(color: TeslaTheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Visual Bar progress
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        if (present - lateCount > 0)
                          Expanded(
                            flex: present - lateCount,
                            child: Container(color: const Color(0xFF4ADE80)),
                          ),
                        if (lateCount > 0)
                          Expanded(
                            flex: lateCount,
                            child: Container(color: const Color(0xFFFBBF24)),
                          ),
                        if (total == 0)
                          Expanded(
                            child: Container(color: TeslaTheme.surfaceHighlight),
                          )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDailyTimeline(BuildContext context, List<dynamic> dailyRecords) {
    if (dailyRecords.isEmpty) {
      return const TeslaCard(
        child: Center(child: Text('No check-in records logged.', style: TextStyle(color: TeslaTheme.onSurfaceVariant))),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dailyRecords.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final record = dailyRecords[index];
        final isPresent = record['status'] == 'Present';
        final isLate = record['is_late'] == true;

        String checkInStr = '--:--';
        String checkOutStr = '--:--';

        try {
          if (record['check_in_time'] != null) {
            final t = DateTime.parse(record['check_in_time']).toLocal();
            checkInStr =
                "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
          }
          if (record['check_out_time'] != null) {
            final t = DateTime.parse(record['check_out_time']).toLocal();
            checkOutStr =
                "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
          }
        } catch (_) {}

        return TeslaCard(
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              // Icon representing check type
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isLate ? const Color(0xFFFBBF24) : const Color(0xFF4ADE80))
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPresent ? Icons.login : Icons.check_circle_outline,
                  color: isLate ? const Color(0xFFFBBF24) : const Color(0xFF4ADE80),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),

              // Date & Sub details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record['date'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "In: $checkInStr  •  Out: $checkOutStr",
                      style: const TextStyle(color: TeslaTheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Badges representing Late / Present status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    (record['status'] ?? '').toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isPresent ? const Color(0xFF4ADE80) : TeslaTheme.onSurfaceVariant,
                    ),
                  ),
                  if (isLate) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'LATE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Color(0xFFFBBF24),
                      ),
                    ),
                  ]
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
