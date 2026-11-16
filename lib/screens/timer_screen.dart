import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numberpicker/numberpicker.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  Timer? timer;
  int hours = 0, minutes = 0, seconds = 0;
  int totalSeconds = 0;
  bool running = false;
  static const platform = MethodChannel('timer_channel');

  void startTimer() {
    if (running) return;
    totalSeconds = hours * 3600 + minutes * 60 + seconds;
    if (totalSeconds <= 0) return;
    setState(() => running = true);

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (totalSeconds > 0) {
        setState(() {
          totalSeconds--;
          hours = totalSeconds ~/ 3600;
          minutes = (totalSeconds % 3600) ~/ 60;
          seconds = totalSeconds % 60;
        });
      } else {
        pauseTimer();
        _showTimerComplete();
      }
    });
  }

  void pauseTimer() {
    timer?.cancel();
    setState(() => running = false);
  }

  void resetTimer() {
    timer?.cancel();
    setState(() {
      hours = 0;
      minutes = 0;
      seconds = 0;
      totalSeconds = 0;
      running = false;
    });
  }

  Future<void> _showTimerComplete() async {
    // Show notification
    try {
      await platform.invokeMethod('showTimerNotification', {
        'title': 'Timer Complete!',
        'message': 'Your timer has finished.',
      });
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }

    // Play notification sound
    try {
      await platform.invokeMethod('playNotificationSound');
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }

    // Show dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: const [
              Icon(Icons.alarm, color: Color(0xFF6448FE), size: 28),
              SizedBox(width: 12),
              Text(
                'Timer Complete!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Your timer has finished.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                resetTimer();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6448FE),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }

  String formatTime(int h, int m, int s) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

  double get progress {
    final initialTotal = hours * 3600 + minutes * 60 + seconds;
    if (initialTotal == 0 || !running) return 0;
    return totalSeconds / initialTotal;
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
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.top - 
                         MediaQuery.of(context).padding.bottom - 
                         kBottomNavigationBarHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // ✅ COMPACT: Timer Display Container
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6448FE), Color(0xFF5FC6FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6448FE).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // ✅ COMPACT: Timer icon with progress (smaller)
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            if (running)
                              SizedBox(
                                width: 70,
                                height: 70,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 3,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.hourglass_bottom,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // ✅ COMPACT: Time display (smaller font)
                        Text(
                          formatTime(hours, minutes, seconds),
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          running ? 'Running...' : (totalSeconds > 0 ? 'Paused' : 'Set Timer'),
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

                  // ✅ COMPACT: Time Picker (only show when not running)
                  if (!running)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Set Duration',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildTimePicker('Hours', hours, 0, 23, (val) => setState(() => hours = val)),
                              Container(width: 1, height: 60, color: Colors.grey[200]),
                              _buildTimePicker('Min', minutes, 0, 59, (val) => setState(() => minutes = val)),
                              Container(width: 1, height: 60, color: Colors.grey[200]),
                              _buildTimePicker('Sec', seconds, 0, 59, (val) => setState(() => seconds = val)),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ✅ COMPACT: Control Buttons (smaller)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // Start/Pause Button
                        Expanded(
                          child: _buildControlButton(
                            label: running ? 'Pause' : 'Start',
                            icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: running ? const Color(0xFFFF6B6B) : const Color(0xFF4CAF50),
                            onPressed: running ? pauseTimer : startTimer,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Reset Button
                        Expanded(
                          child: _buildControlButton(
                            label: 'Reset',
                            icon: Icons.refresh_rounded,
                            color: const Color(0xFF9E9E9E),
                            onPressed: resetTimer,
                            isSecondary: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ✅ COMPACT: Quick Set Buttons
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Quick Set',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildQuickButton('1 min', 0, 1, 0),
                            _buildQuickButton('5 min', 0, 5, 0),
                            _buildQuickButton('10 min', 0, 10, 0),
                            _buildQuickButton('15 min', 0, 15, 0),
                            _buildQuickButton('30 min', 0, 30, 0),
                            _buildQuickButton('1 hour', 1, 0, 0),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimePicker(String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        NumberPicker(
          value: value,
          minValue: min,
          maxValue: max,
          textStyle: const TextStyle(color: Colors.black26, fontSize: 16),
          selectedTextStyle: const TextStyle(
            color: Color(0xFF6448FE),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          onChanged: onChanged,
          itemHeight: 40,
          itemWidth: 60,
          axis: Axis.vertical,
        ),
      ],
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSecondary ? Colors.white : color,
            borderRadius: BorderRadius.circular(14),
            border: isSecondary ? Border.all(color: color.withOpacity(0.3), width: 2) : null,
            boxShadow: isSecondary
                ? null
                : [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24,
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

  Widget _buildQuickButton(String label, int h, int m, int s) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: running
            ? null
            : () {
                setState(() {
                  hours = h;
                  minutes = m;
                  seconds = s;
                });
              },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: running ? Colors.grey[200] : const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: running ? Colors.grey[300]! : const Color(0xFF6448FE).withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: running ? Colors.grey[400] : const Color(0xFF6448FE),
            ),
          ),
        ),
      ),
    );
  }
}