import 'package:flutter/material.dart';
import 'package:personalclock_app/screens/alram_screen.dart';
import 'package:personalclock_app/screens/clock_page.dart';
import 'package:personalclock_app/screens/stopwatch_screen.dart';
import 'package:personalclock_app/screens/timer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ClockPage(),
    const StopwatchScreen(),
    const TimerScreen(),
    AlramScreen(),
  ];

  final List<String> _titles = const [
    "Clock",
    "Stopwatch",
    "Timer",
    "Alarm",
  ];

  final List<IconData> _icons = const [
    Icons.access_time_rounded,
    Icons.timer_rounded,
    Icons.hourglass_bottom_rounded,
    Icons.alarm_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      // 🧠 PROFESSIONAL APP BAR
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: false,
        toolbarHeight: 64,

        title: Row(
          children: [
            Icon(
              _icons[_selectedIndex],
              size: 26,
              color: Colors.black87,
            ),
            const SizedBox(width: 12),
            Text(
              _titles[_selectedIndex],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.black12,
          ),
        ),
      ),

      // 📄 BODY
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),

      // 🔻 CLEAN BOTTOM NAV
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black45,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time_rounded),
            label: "Clock",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_rounded),
            label: "Stopwatch",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hourglass_bottom_rounded),
            label: "Timer",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.alarm_rounded),
            label: "Alarm",
          ),
        ],
      ),
    );
  }
}