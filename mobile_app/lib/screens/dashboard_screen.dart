import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final String token;

  const DashboardScreen({super.key, required this.token});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<dynamic>> _attendanceFuture;

  @override
  void initState() {
    super.initState();
    _attendanceFuture = ApiService.getAttendance(widget.token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              _attendanceFuture = ApiService.getAttendance(widget.token);
            }),
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _attendanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text("No attendance records found.",
                    style: TextStyle(fontSize: 18)));
          }

          final records = snapshot.data!;
          return ListView.builder(
            itemCount: records.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final record = records[index];
              final isPresent = record['status'] == 'Present';
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: isPresent
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.2),
                    child: Icon(isPresent ? Icons.check : Icons.exit_to_app,
                        color: isPresent ? Colors.green : Colors.grey,
                        size: 28),
                  ),
                  title: Text(record['name'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Date: ${record['date']}"),
                        Text("Check-in: ${record['check_in_time']}"),
                        Text("Check-out: ${record['check_out_time'] ?? '--'}"),
                      ],
                    ),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: isPresent ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(record['status'],
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
