import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
                        size: 80, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Oops! User Not Found',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please ensure that "${widget.email}" is registered in Gurukul School Attendance.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Glassmorphic User Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primaryContainer.withOpacity(0.4),
                        theme.colorScheme.secondaryContainer.withOpacity(0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      // Avatar with Neon border status
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isGoodStanding
                                      ? Colors.green
                                      : Colors.orange)
                                  .withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ],
                          border: Border.all(
                            color:
                                isGoodStanding ? Colors.green : Colors.orange,
                            width: 2.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundImage:
                              faceBytes == null ? null : MemoryImage(faceBytes),
                          child: faceBytes == null
                              ? const Icon(Icons.person, size: 40)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 18),
                      // Info Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name'] ?? 'Unknown Name',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user['email'] ?? '',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (user['class_name'] != null)
                                  Chip(
                                    avatar: const Icon(Icons.school, size: 14),
                                    label: Text(user['class_name']),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (user['department'] != null)
                                  Chip(
                                    avatar:
                                        const Icon(Icons.business, size: 14),
                                    label: Text(user['department']),
                                    visualDensity: VisualDensity.compact,
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
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        height: 170,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: CircularProgressIndicator(
                                    value: percent / 100,
                                    strokeWidth: 8,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isGoodStanding
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ),
                                Text(
                                  "${percent.toStringAsFixed(0)}%",
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isGoodStanding
                                  ? 'Good Standing'
                                  : 'Needs Attention',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isGoodStanding
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Stats Columns
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 170,
                        child: Column(
                          children: [
                            _buildStatBadge(
                              context,
                              title: 'Present Days',
                              value: '${stats['present_days']}',
                              icon: Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 8),
                            _buildStatBadge(
                              context,
                              title: 'Late Entries',
                              value: '${stats['late_days']}',
                              icon: Icons.warning_amber_rounded,
                              color: Colors.amber[700]!,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Heatmap Calendar Section
                _buildSectionHeader(context,
                    title: 'Attendance Heatmap', icon: Icons.calendar_month),
                const SizedBox(height: 10),
                _buildCalendarHeatmap(context, dailyRecords),
                const SizedBox(height: 24),

                // Monthly Analytics Section
                _buildSectionHeader(context,
                    title: 'Monthly Analytics', icon: Icons.bar_chart),
                const SizedBox(height: 10),
                _buildMonthlyAnalytics(context, monthlyAnalytics),
                const SizedBox(height: 24),

                // Daily Reports Timeline Section
                _buildSectionHeader(context,
                    title: 'Daily Reports Timeline', icon: Icons.timeline),
                const SizedBox(height: 10),
                _buildDailyTimeline(context, dailyRecords),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatBadge(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    title,
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context,
      {required String title, required IconData icon}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarHeatmap(
      BuildContext context, List<dynamic> dailyRecords) {
    final theme = Theme.of(context);
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
      'December'
    ];
    final currentMonthName = monthNames[now.month - 1];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Month Header title
            Text(
              "$currentMonthName ${now.year}",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),

            // Weekdays labels
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('M', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('T', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('W', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('T', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('F', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('S',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
                Text('S',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),

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

                Color cellColor = Colors.grey[200]!;
                Color textColor = Colors.black87;

                final cellDate = DateTime(now.year, now.month, dayNum);
                final isFuture = cellDate.isAfter(now);
                final isWeekend = cellDate.weekday == DateTime.saturday ||
                    cellDate.weekday == DateTime.sunday;

                if (isFuture) {
                  cellColor = Colors.grey[100]!;
                  textColor = Colors.grey[400]!;
                } else if (status != null) {
                  if (isLate) {
                    cellColor = Colors.orange[300]!;
                    textColor = Colors.white;
                  } else {
                    cellColor = Colors.green[400]!;
                    textColor = Colors.white;
                  }
                } else if (!isWeekend) {
                  cellColor = Colors.red[100]!;
                  textColor = Colors.red[800]!;
                } else {
                  cellColor = Colors.grey[300]!;
                  textColor = Colors.grey[600]!;
                }

                return Tooltip(
                  message: status != null
                      ? "Day $dayNum: ${isLate ? 'Late Arrival' : 'Present'}"
                      : (isFuture
                          ? "Future"
                          : (isWeekend ? "Weekend" : "Absent")),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "$dayNum",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('Present', Colors.green[400]!),
                _buildLegendItem('Late', Colors.orange[300]!),
                _buildLegendItem('Absent', Colors.red[100]!),
                _buildLegendItem('Weekend', Colors.grey[300]!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMonthlyAnalytics(
      BuildContext context, List<dynamic> monthlyAnalytics) {
    final theme = Theme.of(context);
    if (monthlyAnalytics.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
            child: Text('No monthly analytical history registered.')),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "$present Pres. | $lateCount Late",
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Visual Bar progress
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 16,
                      child: Row(
                        children: [
                          if (present - lateCount > 0)
                            Expanded(
                              flex: present - lateCount,
                              child: Container(color: Colors.green),
                            ),
                          if (lateCount > 0)
                            Expanded(
                              flex: lateCount,
                              child: Container(color: Colors.orange),
                            ),
                          if (total == 0)
                            Expanded(
                              child: Container(color: Colors.grey[200]),
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
      ),
    );
  }

  Widget _buildDailyTimeline(BuildContext context, List<dynamic> dailyRecords) {
    final theme = Theme.of(context);
    if (dailyRecords.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('No check-in records logged.')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dailyRecords.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
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

        return Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                // Icon representing check type
                CircleAvatar(
                  backgroundColor:
                      (isLate ? Colors.orange : Colors.green).withOpacity(0.12),
                  child: Icon(
                    isPresent ? Icons.login : Icons.check_circle,
                    color: isLate ? Colors.orange : Colors.green,
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
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Check In: $checkInStr | Check Out: $checkOutStr",
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                // Badges representing Late / Present status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPresent
                            ? Colors.green.withOpacity(0.15)
                            : Colors.blueGrey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        record['status'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isPresent ? Colors.green : Colors.blueGrey,
                        ),
                      ),
                    ),
                    if (isLate) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'LATE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
