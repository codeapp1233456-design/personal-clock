import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personalclock_app/screens/premisssion_screen.dart';
import 'screens/home_screen.dart';
import 'screens/alarm_ringing_screen.dart';
import 'database/alarm_database.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const platform = MethodChannel('alarm_channel');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Karachi'));

  // Setup method channel to receive alarm triggers from native
  platform.setMethodCallHandler((call) async {
    if (call.method == 'triggerAlarm') {
      final Map<dynamic, dynamic> args = call.arguments;
      final alarmId = args['alarmId'] as int;
      await _handleAlarmTrigger(alarmId);
    }
  });

  runApp(const ClassicClockApp());
}

// Handle alarm trigger from native code
Future<void> _handleAlarmTrigger(int alarmId) async {
  try {
    final alarms = await AlarmDatabase.instance.readAllAlarms();
    if (alarms.isEmpty) return;

    final alarm = alarms.firstWhere(
      (a) => a.id == alarmId,
      orElse: () => alarms.first,
    );

    // Wait for navigator to be ready
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (navigatorKey.currentState != null) {
      await navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => AlarmRingingScreen(alarm: alarm),
          fullscreenDialog: true,
        ),
      );
    }
  } catch (e) {
    debugPrint('Error handling alarm trigger: $e');
  }
}

class ClassicClockApp extends StatefulWidget {
  const ClassicClockApp({super.key});

  @override
  State<ClassicClockApp> createState() => _ClassicClockAppState();
}

class _ClassicClockAppState extends State<ClassicClockApp> with WidgetsBindingObserver {
  bool _permissionsChecked = false;
  bool _showPermissionScreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ✅ FIX: When app comes to foreground, check if any alarms need rescheduling
    if (state == AppLifecycleState.resumed) {
      _checkAndRescheduleAlarms();
    }
  }

  // ✅ FIX: Better initialization flow
  Future<void> _initializeApp() async {
    try {
      // Check if we should show permissions
      final shouldShow = await PermissionHandler.shouldShowPermissions();
      
      setState(() {
        _showPermissionScreen = shouldShow;
        _permissionsChecked = true;
      });

      // ✅ FIX: Always reschedule alarms on app start
      // This ensures alarms work even after app updates or device restarts
      await _checkAndRescheduleAlarms();
    } catch (e) {
      debugPrint('Error initializing app: $e');
      setState(() {
        _permissionsChecked = true;
      });
    }
  }

  // ✅ FIX: Improved alarm rescheduling with better error handling
  Future<void> _checkAndRescheduleAlarms() async {
    try {
      final alarms = await AlarmDatabase.instance.readAllAlarms();
      if (alarms.isEmpty) {
        debugPrint('No alarms to reschedule');
        return;
      }

      final now = tz.TZDateTime.now(tz.local);
      int rescheduledCount = 0;
      
      for (var alarm in alarms) {
        if (alarm.isActive && alarm.id != null) {
          try {
            var scheduledDate = tz.TZDateTime(
              tz.local,
              now.year,
              now.month,
              now.day,
              alarm.time.hour,
              alarm.time.minute,
            );

            // If alarm time has passed today, schedule for tomorrow
            if (scheduledDate.isBefore(now) || scheduledDate.difference(now).inSeconds < 5) {
              scheduledDate = scheduledDate.add(const Duration(days: 1));
            }

            // ✅ FIX: Cancel existing alarm first to prevent duplicates
            await platform.invokeMethod('cancelAlarm', {'alarmId': alarm.id});
            
            // Then reschedule with new time
            await platform.invokeMethod('scheduleAlarm', {
              'alarmId': alarm.id,
              'triggerTime': scheduledDate.millisecondsSinceEpoch,
              'title': alarm.title,
              'customRingtone': alarm.customRingtone,
            });

            rescheduledCount++;
            debugPrint('✅ Rescheduled alarm ${alarm.id}: ${alarm.title} at ${alarm.time.format(navigatorKey.currentContext!)}');
          } catch (e) {
            debugPrint('❌ Error rescheduling alarm ${alarm.id}: $e');
          }
        }
      }

      if (rescheduledCount > 0) {
        debugPrint('✅ Successfully rescheduled $rescheduledCount active alarm(s)');
      }
    } catch (e) {
      debugPrint('❌ Error in checkAndRescheduleAlarms: $e');
    }
  }

  void _onPermissionsComplete() {
    setState(() {
      _showPermissionScreen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Classic Clock',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6448FE),
        brightness: Brightness.light,
      ),
      home: !_permissionsChecked
          ? const Scaffold(
              backgroundColor: Color(0xFFF7F9FC),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6448FE),
                ),
              ),
            )
          : _showPermissionScreen
              ? PermissionIntroScreen(onComplete: _onPermissionsComplete)
              : const HomeScreen(),
    );
  }
}