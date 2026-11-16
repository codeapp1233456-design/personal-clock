import 'package:flutter/material.dart';
import '../widgets/analog_clock.dart';
import '../widgets/digital_clock.dart';

class ClockPage extends StatefulWidget {
  const ClockPage({super.key});

  @override
  State<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends State<ClockPage> {
  bool showAnalog = true;

  void scheduleNotification(){
      

  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: showAnalog
                  ? const AnalogClock(key: ValueKey('analog'))
                  : const DigitalClock(key: ValueKey('digital')),
            ),
          ),
        ),

        /// Toggle Buttons
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toggleButton(
                label: "Analog",
                selected: showAnalog,
                onTap: () => setState(() => showAnalog = true),
              ),
              _toggleButton(
                label: "Digital",
                selected: !showAnalog,
                onTap: () => setState(() => showAnalog = false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toggleButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    

 

  }
}
