import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/alram_model.dart';

class AlarmRingingScreen extends StatefulWidget {
  final AlarmModel alarm;

  const AlarmRingingScreen({Key? key, required this.alarm}) : super(key: key);

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  static const platform = MethodChannel('alarm_sound_channel');
  bool _isScanning = false;
  
  MobileScannerController? _scannerController;
  bool _isFlashOn = false;
  bool _isProcessing = false; // Prevent multiple scans

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAlarmSound();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startAlarmSound() async {
    try {
      await platform.invokeMethod('playAlarmSound', {
        'customRingtone': widget.alarm.customRingtone,
      });
    } catch (e) {
      debugPrint('Error playing alarm sound: $e');
    }
  }

  Future<void> _stopAlarmSound() async {
    try {
      await platform.invokeMethod('stopAlarmSound');
    } catch (e) {
      debugPrint('Error stopping alarm sound: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController?.dispose();
    _stopAlarmSound();
    super.dispose();
  }

  Future<void> _dismissAlarm() async {
    await _stopAlarmSound();
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _snoozeAlarm() async {
    await _stopAlarmSound();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏰ Alarm snoozed for 5 minutes'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _scanQRCode() async {
    // Initialize scanner controller when starting scan
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    setState(() {
      _isScanning = true;
      _isProcessing = false;
    });
  }

  Future<void> _toggleFlash() async {
    if (_scannerController != null) {
      await _scannerController!.toggleTorch();
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    }
  }

  Future<void> _onQRCodeDetected(BarcodeCapture capture) async {
    // Prevent processing multiple scans at once
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    
    if (barcodes.isEmpty) return;
    
    final scannedCode = barcodes.first.rawValue;
    
    if (scannedCode == null) return;

    // Mark as processing
    setState(() => _isProcessing = true);

    // Turn off flash before dismissing
    if (_isFlashOn && _scannerController != null) {
      await _scannerController!.toggleTorch();
    }

    // Check if unique QR is required
    if (widget.alarm.requireUniqueQR) {
      // STRICT MODE: Only accept the user's unique QR code
      final prefs = await SharedPreferences.getInstance();
      final userQRCode = prefs.getString('user_qr_code');

      if (scannedCode == userQRCode) {
        // ✅ Correct unique QR code scanned!
        await _stopAlarmSound();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Correct QR code! Alarm dismissed'),
              backgroundColor: Colors.green,
            ),
          );
          
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        // ❌ Wrong QR code
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Wrong QR code! Scan your unique alarm QR code'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
          setState(() {
            _isScanning = false;
            _isProcessing = false;
          });
        }
      }
    } else {
      // RELAXED MODE: Any QR code works!
      await _stopAlarmSound();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ QR code scanned! Alarm dismissed'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isScanning) {
      return _buildQRScanner();
    }

    return WillPopScope(
      // Block back button for QR alarms
      onWillPop: () async {
        if (widget.alarm.isQRAlarm) {
          // Show message that they must scan QR code
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ You must scan a QR code to dismiss this alarm!'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
          return false; // Don't allow back
        } else {
          // Normal alarm - allow back after stopping sound
          await _stopAlarmSound();
          return true;
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.alarm.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                
                // Animated alarm icon
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.alarm.isQRAlarm ? Icons.qr_code_2 : Icons.alarm,
                            size: 120,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                // Alarm title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    widget.alarm.title,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 20),

                // Time display
                Text(
                  widget.alarm.time.format(context),
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 10),

                // Days display
                Text(
                  widget.alarm.days.join(', '),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    letterSpacing: 1,
                  ),
                ),
                
                // Warning for QR alarms
                if (widget.alarm.isQRAlarm) ...[
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    margin: const EdgeInsets.symmetric(horizontal: 30),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.alarm.requireUniqueQR ? Icons.lock : Icons.lock_open,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.alarm.requireUniqueQR
                                ? 'Scan your unique QR code to dismiss'
                                : 'Scan any QR code to dismiss',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: widget.alarm.isQRAlarm
                      ? _buildQRAlarmButtons()
                      : _buildNormalAlarmButtons(),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNormalAlarmButtons() {
    return Row(
      children: [
        // Snooze button
        Expanded(
          child: GestureDetector(
            onTap: _snoozeAlarm,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.snooze, size: 40, color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    'Snooze',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '5 min',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 20),

        // Dismiss button
        Expanded(
          child: GestureDetector(
            onTap: _dismissAlarm,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.alarm_off,
                    size: 40,
                    color: widget.alarm.gradientColors[0],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dismiss',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.alarm.gradientColors[0],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQRAlarmButtons() {
    return Column(
      children: [
        // Scan QR Code button (primary) - ONLY way to dismiss
        GestureDetector(
          onTap: _scanQRCode,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 50,
                  color: widget.alarm.gradientColors[0],
                ),
                const SizedBox(height: 10),
                Text(
                  'Scan QR Code to Dismiss',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.alarm.gradientColors[0],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.alarm.requireUniqueQR 
                      ? 'Only your unique QR code works'
                      : 'Any QR code will work',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQRScanner() {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // QR Scanner
            MobileScanner(
              controller: _scannerController,
              onDetect: _onQRCodeDetected,
            ),
            
            // ✅ IMPROVED: Modern gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // ✅ IMPROVED: Top bar with title and close button
            SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Close button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 28),
                            onPressed: () async {
                              if (_isFlashOn && _scannerController != null) {
                                await _scannerController!.toggleTorch();
                              }
                              setState(() {
                                _isScanning = false;
                                _isFlashOn = false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 15),
                        // Title
                        Expanded(
                          child: Text(
                            widget.alarm.requireUniqueQR 
                                ? 'Scan Your Unique QR Code'
                                : 'Scan Any QR Code',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Flash toggle button
                        Container(
                          decoration: BoxDecoration(
                            color: _isFlashOn 
                                ? Colors.yellow.withOpacity(0.3)
                                : Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isFlashOn ? Colors.yellow : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isFlashOn ? Icons.flash_on : Icons.flash_off,
                              color: _isFlashOn ? Colors.yellow : Colors.white,
                              size: 32,
                            ),
                            onPressed: _toggleFlash,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ✅ IMPROVED: Instructions card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.alarm.gradientColors[0].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.qr_code_scanner,
                            color: widget.alarm.gradientColors[0],
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.alarm.requireUniqueQR
                                    ? 'Point at YOUR QR code'
                                    : 'Point at ANY QR code',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Align the code in the center',
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ✅ IMPROVED: Scanning frame with animation
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        // Corner decorations
                        ...List.generate(4, (index) {
                          return Positioned(
                            top: index < 2 ? 0 : null,
                            bottom: index >= 2 ? 0 : null,
                            left: index % 2 == 0 ? 0 : null,
                            right: index % 2 == 1 ? 0 : null,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: index < 2 ? BorderSide(color: widget.alarm.gradientColors[0], width: 5) : BorderSide.none,
                                  bottom: index >= 2 ? BorderSide(color: widget.alarm.gradientColors[0], width: 5) : BorderSide.none,
                                  left: index % 2 == 0 ? BorderSide(color: widget.alarm.gradientColors[0], width: 5) : BorderSide.none,
                                  right: index % 2 == 1 ? BorderSide(color: widget.alarm.gradientColors[0], width: 5) : BorderSide.none,
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: index == 0 ? const Radius.circular(20) : Radius.zero,
                                  topRight: index == 1 ? const Radius.circular(20) : Radius.zero,
                                  bottomLeft: index == 2 ? const Radius.circular(20) : Radius.zero,
                                  bottomRight: index == 3 ? const Radius.circular(20) : Radius.zero,
                                ),
                              ),
                            ),
                          );
                        }),
                        // Center icon
                        Center(
                          child: Icon(
                            Icons.qr_code_2,
                            size: 80,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ✅ IMPROVED: Flash status indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: _isFlashOn 
                          ? Colors.yellow.withOpacity(0.95)
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flashlight_off,
                          color: _isFlashOn ? Colors.black87 : Colors.black54,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isFlashOn ? 'Flash is ON' : 'Tap flash to turn on',
                          style: TextStyle(
                            color: _isFlashOn ? Colors.black87 : Colors.black54,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}