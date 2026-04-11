import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../config/theme.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  bool _actionLoading = false;
  Map<String, dynamic>? _todayRecord;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getAttendance();
      final records = List<Map<String, dynamic>>.from(data['records'] ?? []);
      setState(() {
        _records = records;
        _todayRecord = records.isNotEmpty && records.first['date'] == DateTime.now().toIso8601String().split('T')[0]
            ? records.first
            : null;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _checkIn() async {
    setState(() => _actionLoading = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      await ApiService.checkIn(latitude: pos.latitude, longitude: pos.longitude);
      _load();
      _showSnack('Checked in successfully!', AppTheme.success);
    } catch (e) {
      _showSnack(e.toString().contains('Already') ? 'Already checked in today' : 'Check-in failed', AppTheme.error);
    }
    setState(() => _actionLoading = false);
  }

  Future<void> _checkOut() async {
    setState(() => _actionLoading = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      await ApiService.checkOut(latitude: pos.latitude, longitude: pos.longitude);
      _load();
      _showSnack('Checked out successfully!', AppTheme.success);
    } catch (_) {
      _showSnack('Check-out failed', AppTheme.error);
    }
    setState(() => _actionLoading = false);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkedIn = _todayRecord?['check_in_time'] != null;
    final checkedOut = _todayRecord?['check_out_time'] != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: Column(
        children: [
          // Today's status card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  _formatDate(DateTime.now()),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _timeChip('Check In', _todayRecord?['check_in_time'], Icons.login),
                    _timeChip('Check Out', _todayRecord?['check_out_time'], Icons.logout),
                  ],
                ),
                const SizedBox(height: 20),
                if (!checkedIn)
                  _actionButton('Check In', Icons.login, AppTheme.success, _checkIn)
                else if (!checkedOut)
                  _actionButton('Check Out', Icons.logout, Colors.orange, _checkOut)
                else
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Day Completed!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
              ],
            ),
          ),

          // History
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text('History', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _records.length,
                    itemBuilder: (ctx, i) {
                      final r = _records[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(r['status']).withOpacity(0.1),
                            child: Icon(Icons.calendar_today, color: _statusColor(r['status'])),
                          ),
                          title: Text(_formatDate2(r['date'])),
                          subtitle: Text(
                            'In: ${_formatTime(r['check_in_time'])}  •  Out: ${_formatTime(r['check_out_time'])}',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(r['status']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              r['status'] ?? 'present',
                              style: TextStyle(color: _statusColor(r['status']), fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _timeChip(String label, String? time, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(
          _formatTime(time),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 200,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: _actionLoading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        onPressed: _actionLoading ? null : onTap,
      ),
    );
  }

  String _formatDate(DateTime dt) => '${_weekday(dt.weekday)}, ${dt.day} ${_month(dt.month)} ${dt.year}';
  String _formatDate2(String? s) {
    if (s == null) return '-';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    return '${dt.day} ${_month(dt.month)} ${dt.year}';
  }
  String _formatTime(String? s) {
    if (s == null) return '--:--';
    final dt = DateTime.tryParse(s)?.toLocal();
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'present': return AppTheme.success;
      case 'absent': return AppTheme.error;
      case 'half_day': return AppTheme.warning;
      default: return Colors.grey;
    }
  }

  String _weekday(int d) => ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d - 1];
  String _month(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}
