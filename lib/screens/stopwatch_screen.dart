import 'dart:async';
import 'package:flutter/material.dart';

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  Timer? timer;
  int milliseconds = 0;
  bool running = false;
  List<String> laps = [];

  void startStopwatch() {
    if (running) return;
    setState(() => running = true);
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() => milliseconds += 100);
    });
  }

  void pauseStopwatch() {
    timer?.cancel();
    setState(() => running = false);
  }

  void resetStopwatch() {
    timer?.cancel();
    setState(() {
      milliseconds = 0;
      running = false;
      laps.clear();
    });
  }

  void lap() {
    if (milliseconds == 0) return;
    final sec = (milliseconds ~/ 1000);
    final min = sec ~/ 60;
    final s = sec % 60;
    final ms = (milliseconds % 1000) ~/ 10;
    setState(() {
      laps.insert(0, '${min.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}');
    });
  }

  String formatTime(int ms) {
    final sec = ms ~/ 1000;
    final min = sec ~/ 60;
    final s = sec % 60;
    final msDisplay = (ms % 1000) ~/ 10;
    return '${min.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${msDisplay.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // ⏱ Stopwatch Display Container
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5DCD), Color(0xFFFF8484)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5DCD).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Timer icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.timer,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Time display
                  Text(
                    formatTime(milliseconds),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    running ? 'Running...' : (milliseconds > 0 ? 'Paused' : 'Ready'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 🔘 Control Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Start/Pause Button
                  Expanded(
                    child: _buildControlButton(
                      label: running ? 'Pause' : 'Start',
                      icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: running ? const Color(0xFFFF6B6B) : const Color(0xFF4CAF50),
                      onPressed: running ? pauseStopwatch : startStopwatch,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Lap Button
                  Expanded(
                    child: _buildControlButton(
                      label: 'Lap',
                      icon: Icons.flag_rounded,
                      color: const Color(0xFF2196F3),
                      onPressed: lap,
                      isSecondary: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Reset Button
                  Expanded(
                    child: _buildControlButton(
                      label: 'Reset',
                      icon: Icons.refresh_rounded,
                      color: const Color(0xFF9E9E9E),
                      onPressed: resetStopwatch,
                      isSecondary: true,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 📝 Laps Section - Fixed to be flexible and scrollable
            Flexible(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Laps',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (laps.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5DCD).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${laps.length} lap${laps.length > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFF5DCD),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                    Flexible(
                      child: laps.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.flag_outlined,
                                      size: 64,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No laps recorded yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[400],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Press "Lap" to record lap times',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                              itemCount: laps.length,
                              separatorBuilder: (context, index) => const Divider(
                                height: 1,
                                thickness: 1,
                                indent: 70,
                                color: Color(0xFFF0F0F0),
                              ),
                              itemBuilder: (context, index) {
                                final lapNumber = laps.length - index;
                                final isFirst = index == 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  child: Row(
                                    children: [
                                      // Lap number badge
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          gradient: isFirst
                                              ? const LinearGradient(
                                                  colors: [Color(0xFFFF5DCD), Color(0xFFFF8484)],
                                                )
                                              : null,
                                          color: isFirst ? null : const Color(0xFFF7F9FC),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$lapNumber',
                                            style: TextStyle(
                                              color: isFirst ? Colors.white : Colors.black87,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Lap time
                                      Expanded(
                                        child: Text(
                                          laps[index],
                                          style: TextStyle(
                                            fontWeight: isFirst ? FontWeight.bold : FontWeight.w600,
                                            fontSize: isFirst ? 19 : 17,
                                            color: isFirst ? Colors.black87 : Colors.black54,
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                      ),
                                      // Best/Latest indicator
                                      if (isFirst)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF5DCD).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Latest',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFFF5DCD),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isSecondary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSecondary ? Colors.white : color,
            borderRadius: BorderRadius.circular(16),
            border: isSecondary ? Border.all(color: color.withOpacity(0.3), width: 2) : null,
            boxShadow: isSecondary
                ? null
                : [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 26,
                color: isSecondary ? color : Colors.white,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSecondary ? color : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}