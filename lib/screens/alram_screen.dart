import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import '../model/alram_model.dart';
import '../database/alarm_database.dart';
import 'add_edit_alarm_screen.dart';
import 'alarm_ringing_screen.dart';
import 'qr_alarm_options_screen.dart';

class AlramScreen extends StatefulWidget {
  const AlramScreen({Key? key}) : super(key: key);

  @override
  State<AlramScreen> createState() => _AlramScreenState();
}

class _AlramScreenState extends State<AlramScreen> {
  List<AlarmModel> _alarms = [];
  bool _isLoading = true;
  static const platform = MethodChannel('alarm_channel');

  @override
  void initState() {
    super.initState();
    _loadAlarms();
    _setupAlarmReceiver();
  }

  void _setupAlarmReceiver() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'triggerAlarm') {
        final Map<dynamic, dynamic> args = call.arguments;
        final alarmId = args['alarmId'] as int;
        await _openAlarmScreen(alarmId);
      }
    });
  }

  Future<void> _openAlarmScreen(int alarmId) async {
    final alarms = await AlarmDatabase.instance.readAllAlarms();
    if (alarms.isEmpty) return;

    final alarm = alarms.firstWhere(
      (a) => a.id == alarmId,
      orElse: () => alarms.first,
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AlarmRingingScreen(alarm: alarm),
          fullscreenDialog: true,
        ),
      );
    }
  }

  Future<void> _loadAlarms() async {
    setState(() => _isLoading = true);
    final alarms = await AlarmDatabase.instance.readAllAlarms();
    setState(() {
      _alarms = alarms;
      _isLoading = false;
    });
  }

  // Check if alarm is within 1 hour
  bool _isAlarmWithinOneHour(AlarmModel alarm) {
    if (!alarm.isActive) return false;
    
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      alarm.time.hour,
      alarm.time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final difference = scheduledDate.difference(now);
    return difference.inMinutes <= 60 && difference.inMinutes > 0;
  }

  Future<void> _addOrEditAlarm([AlarmModel? alarm]) async {
    // Check if trying to edit QR alarm within 1 hour
    if (alarm != null && alarm.isQRAlarm && _isAlarmWithinOneHour(alarm)) {
      _showCannotEditDialog(alarm);
      return;
    }

    final result = await Navigator.push<AlarmModel>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditAlarmScreen(alarm: alarm),
      ),
    );

    if (result != null) {
      if (alarm == null) {
        final id = await AlarmDatabase.instance.createAlarm(result);
        final newAlarm = result.copy(id: id);
        await _scheduleAlarm(newAlarm);
      } else {
        await AlarmDatabase.instance.updateAlarm(result);
        await _scheduleAlarm(result);
      }
      _loadAlarms();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(alarm == null ? 'Alarm added!' : 'Alarm updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showCannotEditDialog(AlarmModel alarm) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      alarm.time.hour,
      alarm.time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final minutesLeft = scheduledDate.difference(now).inMinutes;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.red),
            SizedBox(width: 10),
            Text('Cannot Edit QR Alarm'),
          ],
        ),
        content: Text(
          'This QR alarm is locked because it\'s scheduled to ring in $minutesLeft minutes.\n\n'
          'QR alarms cannot be edited within 1 hour of their scheduled time to prevent accidental changes.\n\n'
          'You can:\n'
          '• Wait for the alarm to ring\n'
          '• Turn it off and create a new one\n'
          '• Edit it after it rings',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _openQROptions() async {
    final result = await Navigator.push<AlarmModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const QRAlarmOptionsScreen(),
      ),
    );

    if (result != null) {
      final id = await AlarmDatabase.instance.createAlarm(result);
      final newAlarm = result.copy(id: id);
      await _scheduleAlarm(newAlarm);
      _loadAlarms();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR Alarm added!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteAlarm(AlarmModel alarm) async {
    // Check if trying to delete QR alarm within 1 hour
    if (alarm.isQRAlarm && _isAlarmWithinOneHour(alarm)) {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        alarm.time.hour,
        alarm.time.minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final minutesLeft = scheduledDate.difference(now).inMinutes;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Cannot delete QR alarm! It rings in $minutesLeft minutes.\nTurn it off first.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    await AlarmDatabase.instance.deleteAlarm(alarm.id!);
    await _cancelAlarm(alarm.id!);
    _loadAlarms();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alarm deleted!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleAlarm(AlarmModel alarm) async {
    final updatedAlarm = alarm.copy(isActive: !alarm.isActive);
    await AlarmDatabase.instance.updateAlarm(updatedAlarm);

    if (updatedAlarm.isActive) {
      await _scheduleAlarm(updatedAlarm);
    } else {
      await _cancelAlarm(updatedAlarm.id!);
    }

    _loadAlarms();
  }

  Future<void> _scheduleAlarm(AlarmModel alarm) async {
    if (!alarm.isActive || alarm.id == null) return;

    try {
      await _cancelAlarm(alarm.id!);

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        alarm.time.hour,
        alarm.time.minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final triggerTimeMillis = scheduledDate.millisecondsSinceEpoch;

      await platform.invokeMethod('scheduleAlarm', {
        'alarmId': alarm.id,
        'triggerTime': triggerTimeMillis,
        'title': alarm.title,
        'customRingtone': alarm.customRingtone,
      });

      final minutesUntil = scheduledDate.difference(now).inMinutes;
      final hoursUntil = (minutesUntil / 60).floor();
      final minsRemaining = minutesUntil % 60;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${alarm.isQRAlarm ? "📱 QR" : "⏰"} Alarm set for ${alarm.time.format(context)}\n'
              '⏳ In ${hoursUntil}h ${minsRemaining}m'
            ),
            backgroundColor: alarm.isQRAlarm ? Colors.deepPurple : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error scheduling alarm: $e');
    }
  }

  Future<void> _cancelAlarm(int id) async {
    try {
      await platform.invokeMethod('cancelAlarm', {'alarmId': id});
    } catch (e) {
      debugPrint('❌ Error cancelling alarm: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // QR Alarm Button
          FloatingActionButton(
            heroTag: 'qr_alarm',
            backgroundColor: Colors.deepPurple,
            child: const Icon(Icons.qr_code_2, size: 28, color: Colors.white),
            onPressed: _openQROptions,
          ),
          const SizedBox(height: 15),
          // Regular Alarm Button
          FloatingActionButton(
            heroTag: 'regular_alarm',
            backgroundColor: Colors.blue,
            child: const Icon(Icons.add, size: 30, color: Colors.white),
            onPressed: () => _addOrEditAlarm(),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_alarms.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.alarm_off, size: 80, color: Colors.grey),
                    SizedBox(height: 20),
                    Text(
                      'No alarms set',
                      style: TextStyle(fontSize: 20, color: Colors.grey),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Tap + for regular alarm\nTap QR for QR alarm',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _alarms.length,
                padding: const EdgeInsets.all(10),
                itemBuilder: (context, index) {
                  final alarm = _alarms[index];
                  final isLocked = alarm.isQRAlarm && _isAlarmWithinOneHour(alarm);
                  
                  return Dismissible(
                    key: Key(alarm.id.toString()),
                    background: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      // If locked, don't allow swipe delete
                      if (isLocked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ Cannot delete locked QR alarm!'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return false;
                      }
                      return true;
                    },
                    onDismissed: (_) => _deleteAlarm(alarm),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: alarm.gradientColors,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: alarm.gradientColors[0].withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: isLocked 
                          ? Border.all(color: Colors.yellow, width: 3)
                          : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    alarm.isQRAlarm ? Icons.qr_code_2 : Icons.alarm,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                  if (isLocked)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 5),
                                      child: Icon(
                                        Icons.lock,
                                        color: Colors.yellow,
                                        size: 20,
                                      ),
                                    ),
                                  const SizedBox(width: 15),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alarm.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 25,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          if (alarm.isQRAlarm)
                                            const Text(
                                              'QR Alarm',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          if (isLocked) ...[
                                            const Text(
                                              ' • ',
                                              style: TextStyle(
                                                color: Colors.yellow,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const Text(
                                              'Locked',
                                              style: TextStyle(
                                                color: Colors.yellow,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch(
                                value: alarm.isActive,
                                onChanged: (_) => _toggleAlarm(alarm),
                                activeColor: Colors.white,
                              ),
                            ],
                          ),
                          Text(
                            alarm.days.join(', '),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                alarm.time.format(context),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isLocked ? Icons.lock : Icons.keyboard_arrow_down,
                                  size: 30,
                                  color: isLocked ? Colors.yellow : Colors.white,
                                ),
                                onPressed: () => _addOrEditAlarm(alarm),
                              ),
                            ],
                          ),
                        ],
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
}