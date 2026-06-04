import 'login_screen.dart';
import '../theme/tesla_theme.dart';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'student_dashboard_screen.dart';
import 'registration_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  final String token;
  final String email;

  const AdminPanelScreen({
    super.key,
    required this.token,
    required this.email,
  });

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late Future<_AdminPanelData> _panelFuture;
  int _currentIndex = 0;
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _classController = TextEditingController();
  final _departmentController = TextEditingController();
  final _lateAfterController = TextEditingController(text: '09:15');
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _panelFuture = _loadPanelData();
  }

  Future<_AdminPanelData> _loadPanelData() async {
    final filters = _currentFilters();
    final results = await Future.wait([
      ApiService.getAdminStats(widget.token, filters: filters),
      ApiService.getAttendance(widget.token, filters: filters),
      ApiService.getUsers(widget.token),
    ]);
    return _AdminPanelData(
      stats: results[0] as Map<String, dynamic>,
      attendance: results[1] as List<dynamic>,
      users: results[2] as List<dynamic>,
    );
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _classController.dispose();
    _departmentController.dispose();
    _lateAfterController.dispose();
    super.dispose();
  }

  Map<String, String> _currentFilters() {
    return {
      if (_startDateController.text.trim().isNotEmpty)
        'start_date': _startDateController.text.trim(),
      if (_endDateController.text.trim().isNotEmpty)
        'end_date': _endDateController.text.trim(),
      if (_classController.text.trim().isNotEmpty)
        'class_name': _classController.text.trim(),
      if (_departmentController.text.trim().isNotEmpty)
        'department': _departmentController.text.trim(),
      if (_lateAfterController.text.trim().isNotEmpty)
        'late_after': _lateAfterController.text.trim(),
      if (_statusFilter.isNotEmpty) 'status_filter': _statusFilter,
    };
  }

  String _filterSummary() {
    final filters = _currentFilters();
    if (filters.isEmpty ||
        (filters.length == 1 && filters.containsKey('late_after'))) {
      return 'All records';
    }
    return filters.entries
        .where((entry) => entry.key != 'late_after')
        .map((entry) => '${entry.key.replaceAll('_', ' ')}: ${entry.value}')
        .join('  |  ');
  }

  void _refresh() {
    setState(() => _panelFuture = _loadPanelData());
  }

  void _setTodayFilter() {
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _startDateController.text = today;
    _endDateController.text = today;
    _refresh();
  }

  void _setMonthFilter() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    _startDateController.text =
        '${firstDay.year.toString().padLeft(4, '0')}-${firstDay.month.toString().padLeft(2, '0')}-${firstDay.day.toString().padLeft(2, '0')}';
    _endDateController.text =
        '${lastDay.year.toString().padLeft(4, '0')}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';
    _refresh();
  }

  void _clearFilters() {
    _startDateController.clear();
    _endDateController.clear();
    _classController.clear();
    _departmentController.clear();
    _lateAfterController.text = '09:15';
    _statusFilter = '';
    _refresh();
  }

  Future<void> _openFilterDialog() async {
    var dialogStatus = _statusFilter;
    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Filters'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FilterTextField(
                  controller: _startDateController,
                  label: 'Start Date',
                  hint: 'YYYY-MM-DD',
                  icon: Icons.calendar_today_outlined,
                ),
                const SizedBox(height: 12),
                _FilterTextField(
                  controller: _endDateController,
                  label: 'End Date',
                  hint: 'YYYY-MM-DD',
                  icon: Icons.event_outlined,
                ),
                const SizedBox(height: 12),
                _FilterTextField(
                  controller: _classController,
                  label: 'Class',
                  icon: Icons.school_outlined,
                ),
                const SizedBox(height: 12),
                _FilterTextField(
                  controller: _departmentController,
                  label: 'Department',
                  icon: Icons.business_outlined,
                ),
                const SizedBox(height: 12),
                _FilterTextField(
                  controller: _lateAfterController,
                  label: 'Late After',
                  hint: '09:15',
                  icon: Icons.schedule,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: dialogStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(Icons.filter_alt_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Any')),
                    DropdownMenuItem(value: 'Present', child: Text('Present')),
                    DropdownMenuItem(
                        value: 'Checked Out', child: Text('Checked Out')),
                    DropdownMenuItem(value: 'Late', child: Text('Late')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => dialogStatus = value ?? '');
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _clearFilters();
                Navigator.pop(context, false);
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (applied == true) {
      setState(() {
        _statusFilter = dialogStatus;
        _panelFuture = _loadPanelData();
      });
    }
  }

  Future<void> _exportReport(String format) async {
    try {
      final response = await ApiService.downloadAttendanceReport(
        widget.token,
        format,
        filters: _currentFilters(),
      );
      if (response.statusCode != 200) {
        throw Exception('Export failed with status ${response.statusCode}');
      }
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/attendance_report_${DateTime.now().millisecondsSinceEpoch}.$format';
      final file = File(path);
      await file.writeAsBytes(response.bodyBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${format.toUpperCase()} report saved: $path'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      await ApiService.adminLogout(widget.token);
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('admin_token');
      await prefs.remove('admin_email');
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete ${user['name']} and their attendance records?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteUser(widget.token, user['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user['name']} deleted')),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final nameController = TextEditingController(text: user['name'] ?? '');
    final emailController = TextEditingController(text: user['email'] ?? '');
    final classController =
        TextEditingController(text: user['class_name'] ?? '');
    final departmentController =
        TextEditingController(text: user['department'] ?? '');

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: classController,
              decoration: const InputDecoration(
                labelText: 'Class',
                prefixIcon: Icon(Icons.school_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: departmentController,
              decoration: const InputDecoration(
                labelText: 'Department',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != true) {
      nameController.dispose();
      emailController.dispose();
      classController.dispose();
      departmentController.dispose();
      return;
    }

    try {
      final name = nameController.text.trim();
      final email = emailController.text.trim();
      await ApiService.updateUser(
        widget.token,
        user['id'],
        name,
        email,
        className: classController.text.trim(),
        department: departmentController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name updated')),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: ${e.toString()}')),
        );
      }
    } finally {
      nameController.dispose();
      emailController.dispose();
      classController.dispose();
      departmentController.dispose();
    }
  }

  Future<void> _toggleUserActive(Map<String, dynamic> user) async {
    final nextStatus = user['is_active'] != true;
    try {
      await ApiService.setUserActive(widget.token, user, nextStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextStatus
                  ? '${user['name']} activated'
                  : '${user['name']} deactivated',
            ),
          ),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status update failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TeslaTheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12, 
            left: 24, 
            right: 16, 
            bottom: 12
          ),
          decoration: const BoxDecoration(
            color: TeslaTheme.surface,
            border: Border(bottom: BorderSide(color: TeslaTheme.surfaceHighest, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Admin Panel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: TeslaTheme.onSurface, letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text(
                    widget.email,
                    style: const TextStyle(fontSize: 12, color: TeslaTheme.onSurfaceVariant),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTopIconButton(Icons.filter_list_rounded, _openFilterDialog),
                  const SizedBox(width: 12),
                  _buildTopIconButton(Icons.refresh_rounded, _refresh),
                  const SizedBox(width: 12),
                  _buildTopIconButton(Icons.logout_rounded, _logout, color: TeslaTheme.error),
                ],
              ),
            ],
          ),
        ),
      ),
      body: FutureBuilder<_AdminPanelData>(
        future: _panelFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: TeslaTheme.primary));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: ', style: const TextStyle(color: TeslaTheme.error)),
              ),
            );
          }
          final data = snapshot.data!;
          final tabs = [
            _OverviewTab(
              stats: data.stats,
              filterSummary: _filterSummary(),
              onToday: _setTodayFilter,
              onThisMonth: _setMonthFilter,
            ),
            _AttendanceTab(
              records: data.attendance,
              filterSummary: _filterSummary(),
              onExportCsv: () => _exportReport('csv'),
              onExportPdf: () => _exportReport('pdf'),
              onExportExcel: () => _exportReport('xlsx'),
            ),
            _UsersTab(
              users: data.users,
              onEditUser: _editUser,
              onToggleUserActive: _toggleUserActive,
              onDeleteUser: _deleteUser,
              onRefresh: _refresh,
            ),
            _LiveCameraTab(token: widget.token),
            _OrganizationTab(token: widget.token),
            _DevicesTab(token: widget.token),
            _SettingsTab(token: widget.token),
          ];
          return IndexedStack(
            index: _currentIndex,
            children: tabs,
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 85,
          decoration: const BoxDecoration(
            color: TeslaTheme.surface,
            border: Border(top: BorderSide(color: TeslaTheme.surfaceHighest, width: 1)),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            children: [
              _buildNavItem(0, Icons.insights_rounded, 'Overview'),
              _buildNavItem(1, Icons.event_available_rounded, 'Attendance'),
              _buildNavItem(2, Icons.people_alt_rounded, 'Users'),
              _buildNavItem(3, Icons.camera_outdoor_rounded, 'Camera'),
              _buildNavItem(4, Icons.business_rounded, 'Organization'),
              _buildNavItem(5, Icons.devices_rounded, 'Devices'),
              _buildNavItem(6, Icons.settings_rounded, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopIconButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: TeslaTheme.surfaceHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color ?? TeslaTheme.onSurface),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCirc,
        margin: const EdgeInsets.only(right: 12),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 20 : 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? TeslaTheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? TeslaTheme.primary.withOpacity(0.3) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? TeslaTheme.primary : TeslaTheme.onSurfaceVariant,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: TeslaTheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );  }
}

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  final String filterSummary;
  final VoidCallback onToday;
  final VoidCallback onThisMonth;

  const _OverviewTab({
    required this.stats,
    required this.filterSummary,
    required this.onToday,
    required this.onThisMonth,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatTileData('Total Users', stats['total_users'], Icons.people),
      _StatTileData('Present', stats['today_present'], Icons.task_alt),
      _StatTileData('Absent', stats['today_absent'], Icons.person_off),
      _StatTileData('Late', stats['late_arrivals'], Icons.schedule),
      _StatTileData(
        'Checked In',
        stats['currently_checked_in'],
        Icons.login,
      ),
      _StatTileData(
        'Records',
        stats['total_attendance_records'],
        Icons.receipt_long,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportToolbar(
          filterSummary: filterSummary,
          actions: [
            OutlinedButton.icon(
              onPressed: onToday,
              icon: const Icon(Icons.today),
              label: const Text('Today'),
            ),
            OutlinedButton.icon(
              onPressed: onThisMonth,
              icon: const Icon(Icons.calendar_month),
              label: const Text('Month'),
            ),
          ],
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemCount: tiles.length,
            itemBuilder: (context, index) {
              final tile = tiles[index];
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        tile.icon,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      Text(
                        '${tile.value ?? 0}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(tile.label),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  final List<dynamic> records;
  final String filterSummary;
  final VoidCallback onExportCsv;
  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;

  const _AttendanceTab({
    required this.records,
    required this.filterSummary,
    required this.onExportCsv,
    required this.onExportPdf,
    required this.onExportExcel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportToolbar(
          filterSummary: filterSummary,
          actions: [
            FilledButton.icon(
              onPressed: onExportCsv,
              icon: const Icon(Icons.table_view),
              label: const Text('CSV'),
            ),
            FilledButton.icon(
              onPressed: onExportPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onExportExcel,
              icon: const Icon(Icons.grid_on_outlined),
              label: const Text('EXCEL'),
            ),
          ],
        ),
        Expanded(
          child: records.isEmpty
              ? const Center(child: Text('No attendance records found.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final isPresent = record['status'] == 'Present';
                    final isLate = record['is_late'] == true;
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPresent
                              ? Colors.green.withValues(alpha: 0.16)
                              : Colors.blueGrey.withValues(alpha: 0.16),
                          child: Icon(
                            isPresent ? Icons.check : Icons.logout,
                            color: isPresent ? Colors.green : Colors.blueGrey,
                          ),
                        ),
                        title: Text(record['name'] ?? 'Unknown'),
                        subtitle: Text(
                          'Date: ${record['date']}\n'
                          'Class: ${record['class_name'] ?? '--'}  Department: ${record['department'] ?? '--'}\n'
                          'In: ${record['check_in_time']}  Out: ${record['check_out_time'] ?? '--'}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Chip(label: Text(record['status'] ?? '--')),
                            if (isLate)
                              const Text(
                                'Late',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ReportToolbar extends StatelessWidget {
  final String filterSummary;
  final List<Widget> actions;

  const _ReportToolbar({
    required this.filterSummary,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(
            avatar: const Icon(Icons.filter_alt_outlined, size: 18),
            label: Text(filterSummary),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _FilterTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;

  const _FilterTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  final List<dynamic> users;
  final ValueChanged<Map<String, dynamic>> onEditUser;
  final ValueChanged<Map<String, dynamic>> onToggleUserActive;
  final ValueChanged<Map<String, dynamic>> onDeleteUser;
  final VoidCallback onRefresh;

  const _UsersTab({
    required this.users,
    required this.onEditUser,
    required this.onToggleUserActive,
    required this.onDeleteUser,
    required this.onRefresh,
  });

  void _showFacePreview(BuildContext context, Map<String, dynamic> user) {
    final imageBytes = _decodeFaceImage(user['face_image_base64']);
    if (imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No registered face image available.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Image.memory(imageBytes, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                user['name'] ?? 'Registered Face',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (users.isEmpty) {
      content = const Center(child: Text('No registered users found.'));
    } else {
      content = ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final user = users[index] as Map<String, dynamic>;
          final isActive = user['is_active'] == true;
          final faceBytes = _decodeFaceImage(user['face_image_base64']);
          return Card(
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: ListTile(
              leading: GestureDetector(
                onTap: () => _showFacePreview(context, user),
                child: CircleAvatar(
                  backgroundImage:
                      faceBytes == null ? null : MemoryImage(faceBytes),
                  child: faceBytes == null ? const Icon(Icons.person) : null,
                ),
              ),
              title: Row(
                children: [
                  Expanded(child: Text(user['name'] ?? 'Unknown')),
                  Chip(
                    label: Text(isActive ? 'Active' : 'Inactive'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: isActive
                        ? Colors.green.withValues(alpha: 0.14)
                        : Colors.grey.withValues(alpha: 0.18),
                  ),
                ],
              ),
              subtitle: Text(
                '${user['email']}\n'
                'Class: ${user['class_name'] ?? '--'}  Department: ${user['department'] ?? '--'}\n'
                'Joined: ${user['created_at']}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'View Dashboard',
                    icon: const Icon(Icons.analytics_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentDashboardScreen(
                              email: user['email'] ?? ''),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Edit user',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => onEditUser(user),
                  ),
                  IconButton(
                    tooltip: isActive ? 'Deactivate user' : 'Activate user',
                    icon: Icon(isActive
                        ? Icons.person_off_outlined
                        : Icons.person_add_alt_1_outlined),
                    onPressed: () => onToggleUserActive(user),
                  ),
                  IconButton(
                    tooltip: 'Delete user',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onDeleteUser(user),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      );
    }
    return Scaffold(
      body: content,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Push to RegistrationScreen
          // Wait for result and refresh
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegistrationScreen()),
          );
          onRefresh();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
      ),
    );
  }
}

Uint8List? _decodeFaceImage(dynamic rawImage) {
  if (rawImage is! String || rawImage.isEmpty) return null;
  final normalized =
      rawImage.contains(',') ? rawImage.split(',').last : rawImage;
  try {
    return base64Decode(normalized);
  } catch (_) {
    return null;
  }
}

class _AdminPanelData {
  final Map<String, dynamic> stats;
  final List<dynamic> attendance;
  final List<dynamic> users;

  const _AdminPanelData({
    required this.stats,
    required this.attendance,
    required this.users,
  });
}

class _StatTileData {
  final String label;
  final dynamic value;
  final IconData icon;

  const _StatTileData(this.label, this.value, this.icon);
}

class _SettingsTab extends StatefulWidget {
  final String token;

  const _SettingsTab({required this.token});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  late TextEditingController _radiusController;
  late TextEditingController _lateAfterController;
  late TextEditingController _webhookUrlController;
  bool _purgeRawImages = false;
  bool _strictGeofence = false;

  @override
  void initState() {
    super.initState();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
    _radiusController = TextEditingController();
    _lateAfterController = TextEditingController();
    _webhookUrlController = TextEditingController();
    _fetchSettings();
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    _lateAfterController.dispose();
    _webhookUrlController.dispose();
    super.dispose();
  }

  Future<void> _fetchSettings() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final data = await ApiService.getSettings(widget.token);
      setState(() {
        _latitudeController.text = (data['office_latitude'] ?? '').toString();
        _longitudeController.text = (data['office_longitude'] ?? '').toString();
        _radiusController.text = (data['office_radius'] ?? '').toString();
        _lateAfterController.text = (data['late_after'] ?? '09:15').toString();
        _webhookUrlController.text = (data['webhook_url'] ?? '').toString();
        _purgeRawImages = data['purge_raw_images'] == true;
        _strictGeofence = data['strict_geofence'] == true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load settings: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });

      final payload = {
        'office_latitude': double.tryParse(_latitudeController.text) ?? 22.5726,
        'office_longitude':
            double.tryParse(_longitudeController.text) ?? 88.3639,
        'office_radius': double.tryParse(_radiusController.text) ?? 100.0,
        'late_after': _lateAfterController.text.trim(),
        'webhook_url': _webhookUrlController.text.trim(),
        'purge_raw_images': _purgeRawImages,
        'strict_geofence': _strictGeofence,
      };

      await ApiService.updateSettings(widget.token, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Workspace configurations saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save settings: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _latitudeController.text.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchSettings,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // Geofence & Office Location Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Office Geofence Parameters',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitudeController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              hintText: 'e.g. 22.5726',
                              prefixIcon: Icon(Icons.map_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Invalid number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _longitudeController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              hintText: 'e.g. 88.3639',
                              prefixIcon: Icon(Icons.map_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Invalid number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _radiusController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Radius (Meters)',
                        hintText: 'e.g. 100.0',
                        prefixIcon: Icon(Icons.radar),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Strict Geofencing'),
                      subtitle: const Text(
                          'Reject check-in if GPS coordinate is invalid or absent'),
                      value: _strictGeofence,
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() => _strictGeofence = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Compliance & Working Hours Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'GDPR & Compliance Settings',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    TextFormField(
                      controller: _lateAfterController,
                      decoration: const InputDecoration(
                        labelText: 'Late Threshold Time (HH:MM)',
                        hintText: 'e.g. 09:15',
                        prefixIcon: Icon(Icons.alarm),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        final parts = value.split(':');
                        if (parts.length != 2) return 'Must be HH:MM format';
                        final h = int.tryParse(parts[0]);
                        final m = int.tryParse(parts[1]);
                        if (h == null ||
                            m == null ||
                            h < 0 ||
                            h > 23 ||
                            m < 0 ||
                            m > 59) {
                          return 'Invalid time';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('GDPR Biometric Compliance'),
                      subtitle: const Text(
                          'Purge raw face photographs immediately after vector embeddings extraction to satisfy biometric regulations'),
                      value: _purgeRawImages,
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() => _purgeRawImages = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Integrations & Webhooks Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.webhook,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Workspace Integrations',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    TextFormField(
                      controller: _webhookUrlController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Webhook URL (Slack or Discord)',
                        hintText: 'e.g. https://discord.com/api/webhooks/...',
                        prefixIcon: Icon(Icons.link),
                      ),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final uri = Uri.tryParse(value.trim());
                          if (uri == null ||
                              !uri.hasScheme ||
                              !uri.hasAuthority) {
                            return 'Invalid URL';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving
                  ? 'Saving Configurations...'
                  : 'Save Configurations'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizationTab extends StatefulWidget {
  final String token;
  const _OrganizationTab({required this.token});

  @override
  State<_OrganizationTab> createState() => _OrganizationTabState();
}

class _OrganizationTabState extends State<_OrganizationTab> {
  List<dynamic> _classes = [];
  List<dynamic> _departments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getClasses(widget.token),
        ApiService.getDepartments(widget.token),
      ]);
      if (mounted) {
        setState(() {
          _classes = results[0];
          _departments = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load organization data: $e')));
      }
    }
  }

  Future<void> _addClass() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Class'),
        content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Class Name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (result == true && controller.text.trim().isNotEmpty) {
      try {
        await ApiService.createClass(widget.token, controller.text.trim());
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add class: $e')),
          );
        }
      }
    }
  }

  Future<void> _addDepartment() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Department'),
        content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Department Name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (result == true && controller.text.trim().isNotEmpty) {
      try {
        await ApiService.createDepartment(widget.token, controller.text.trim());
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add department: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteClass(int id) async {
    try {
      await ApiService.deleteClass(widget.token, id);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete class: $e')),
        );
      }
    }
  }

  Future<void> _deleteDepartment(int id) async {
    try {
      await ApiService.deleteDepartment(widget.token, id);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete department: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              ListTile(
                title: const Text('Classes',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                trailing: IconButton(
                    icon: const Icon(Icons.add), onPressed: _addClass),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _classes.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(_classes[i]['name']),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteClass(_classes[i]['id'])),
                  ),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              ListTile(
                title: const Text('Departments',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                trailing: IconButton(
                    icon: const Icon(Icons.add), onPressed: _addDepartment),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _departments.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(_departments[i]['name']),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () =>
                            _deleteDepartment(_departments[i]['id'])),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DevicesTab extends StatefulWidget {
  final String token;
  const _DevicesTab({required this.token});

  @override
  State<_DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<_DevicesTab> {
  List<dynamic> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await ApiService.getDevices(widget.token);
      if (mounted) {
        setState(() {
          _devices = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load devices: $e')));
      }
    }
  }

  Future<void> _performAction(String deviceId, String action) async {
    try {
      await ApiService.performDeviceAction(widget.token, deviceId, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action $action sent successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_devices.isEmpty) {
      return const Center(child: Text('No devices registered.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _devices.length,
      itemBuilder: (_, i) {
        final dev = _devices[i];
        return Card(
          child: ListTile(
            leading: Icon(Icons.camera_alt,
                color: dev['status'] == 'Online' ? Colors.green : Colors.red),
            title: Text(dev['name']),
            subtitle: Text(
                'ID: ${dev['device_id']}\nStatus: ${dev['status']} | Battery: ${dev['battery_level']}% | Temp: ${dev['temperature']}°C\nLast Active: ${dev['last_active']}'),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (action) => _performAction(dev['device_id'], action),
              itemBuilder: (context) => const [
                PopupMenuItem(
                    value: 'restart_camera', child: Text('Restart Camera')),
                PopupMenuItem(value: 'force_sync', child: Text('Force Sync')),
                PopupMenuItem(value: 'wipe_cache', child: Text('Wipe Cache')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LiveCameraTab extends StatefulWidget {
  final String token;
  const _LiveCameraTab({required this.token});

  @override
  State<_LiveCameraTab> createState() => _LiveCameraTabState();
}

class _LiveCameraTabState extends State<_LiveCameraTab> {
  List<dynamic> _alerts = [];
  bool _isDisposed = false;
  int _alertsFingerprint = 0;

  @override
  void initState() {
    super.initState();
    _fetchAlertsLoop();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _fetchAlertsLoop() async {
    while (!_isDisposed) {
      try {
        final alerts = await ApiService.getAlerts(widget.token);

        // Lightweight fingerprint to avoid unnecessary rebuilds.
        // Fingerprint includes length + (id,is_read) pairs.
        var fp = alerts.length;
        for (final a in alerts) {
          fp = (fp * 31) ^ ((a['id'] ?? 0) as int);
          fp = (fp * 31) ^ ((a['is_read'] == true) ? 1 : 0);
        }

        if (mounted && fp != _alertsFingerprint) {
          _alertsFingerprint = fp;
          setState(() => _alerts = alerts);
        }
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Future<void> _markRead(int id) async {
    try {
      await ApiService.markAlertRead(widget.token, id);
      if (mounted) {
        setState(() {
          _alerts = _alerts.map((a) {
            if (a['id'] == id) a['is_read'] = true;
            return a;
          }).toList();
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Live Feed',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      '${ApiService.baseUrl}/admin/live_camera',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                              child: Text('Camera Feed Offline',
                                  style: TextStyle(color: Colors.white))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              const ListTile(
                title: Text('Recent Alerts',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                leading: Icon(Icons.warning, color: Colors.orange),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _alerts.length,
                  itemBuilder: (context, index) {
                    final alert = _alerts[index];
                    final isRead = alert['is_read'] == true;

                    return ListTile(
                      tileColor:
                          isRead ? null : Colors.red.withValues(alpha: 0.1),
                      leading: Icon(Icons.person_off,
                          color: isRead ? Colors.grey : Colors.red),
                      title: Text(alert['message']),
                      subtitle: Text(alert['timestamp']),
                      trailing: isRead
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.check),
                              onPressed: () => _markRead(alert['id']),
                              tooltip: 'Mark as resolved',
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
