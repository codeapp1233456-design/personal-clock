import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class AnalogClock extends StatefulWidget {
  const AnalogClock({super.key});

  @override
  _AnalogClockState createState() => _AnalogClockState();
}

class _AnalogClockState extends State<AnalogClock> {
  late Timer timer;
  DateTime dateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => dateTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Colors.orange.shade100, Colors.deepOrange.shade400],
          center: Alignment(-0.2, -0.2),
          radius: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _ClockPainter(dateTime),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  final DateTime dateTime;
  _ClockPainter(this.dateTime);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paintBorder = Paint()
      ..color = Colors.orange.shade900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, paintBorder);

    // 🔹 Hour ticks
    for (int i = 0; i < 12; i++) {
      final angle = i * 30 * pi / 180;
      final outer = Offset(center.dx + radius * 0.9 * sin(angle),
          center.dy - radius * 0.9 * cos(angle));
      final inner = Offset(center.dx + radius * 0.75 * sin(angle),
          center.dy - radius * 0.75 * cos(angle));
      canvas.drawLine(inner, outer, Paint()..color = Colors.black..strokeWidth = 4);
    }

    // 🔹 Minute ticks
    for (int i = 0; i < 60; i++) {
      if (i % 5 == 0) continue; // Skip hour positions
      final angle = i * 6 * pi / 180;
      final outer = Offset(center.dx + radius * 0.9 * sin(angle),
          center.dy - radius * 0.9 * cos(angle));
      final inner = Offset(center.dx + radius * 0.85 * sin(angle),
          center.dy - radius * 0.85 * cos(angle));
      canvas.drawLine(inner, outer, Paint()..color = Colors.black45..strokeWidth = 2);
    }

    // 🔹 Hour hand
    final hourAngle =
        (dateTime.hour % 12 + dateTime.minute / 60) * 30 * pi / 180;
    final hourHandOffset = Offset(
      center.dx + radius * 0.5 * sin(hourAngle),
      center.dy - radius * 0.5 * cos(hourAngle),
    );
    canvas.drawLine(
        center,
        hourHandOffset,
        Paint()
          ..color = Colors.black87
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round);

    // 🔹 Minute hand
    final minAngle = (dateTime.minute + dateTime.second / 60) * 6 * pi / 180;
    final minHandOffset = Offset(
      center.dx + radius * 0.7 * sin(minAngle),
      center.dy - radius * 0.7 * cos(minAngle),
    );
    canvas.drawLine(
        center,
        minHandOffset,
        Paint()
          ..color = Colors.black87
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);

    // 🔹 Second hand
    final secAngle = dateTime.second * 6 * pi / 180;
    final secHandOffset = Offset(
      center.dx + radius * 0.85 * sin(secAngle),
      center.dy - radius * 0.85 * cos(secAngle),
    );
    canvas.drawLine(
        center,
        secHandOffset,
        Paint()
          ..color = Colors.red
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));

    // 🔹 Center pivot with glow
    canvas.drawCircle(
        center,
        6,
        Paint()
          ..color = Colors.black
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    // 🔹 Hour numbers
    final textPainter = TextPainter(
        textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    for (int i = 1; i <= 12; i++) {
      final angle = i * 30 * pi / 180;
      final offset = Offset(
        center.dx + radius * 0.6 * sin(angle),
        center.dy - radius * 0.6 * cos(angle),
      );
      textPainter.text = TextSpan(
        text: '$i',
        style: const TextStyle(
            color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(
          canvas, offset - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
