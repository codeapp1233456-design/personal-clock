import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class QRCodeDisplayScreen extends StatefulWidget {
  const QRCodeDisplayScreen({Key? key}) : super(key: key);

  @override
  State<QRCodeDisplayScreen> createState() => _QRCodeDisplayScreenState();
}

class _QRCodeDisplayScreenState extends State<QRCodeDisplayScreen> {
  String? _userQRCode;
  bool _isLoading = true;
  static const platform = MethodChannel('qr_print_channel');

  @override
  void initState() {
    super.initState();
    _loadOrGenerateQRCode();
  }

  Future<void> _loadOrGenerateQRCode() async {
    final prefs = await SharedPreferences.getInstance();
    String? qrCode = prefs.getString('user_qr_code');
    
    if (qrCode == null) {
      const uuid = Uuid();
      qrCode = 'ALARM_QR_${uuid.v4()}';
      await prefs.setString('user_qr_code', qrCode);
    }
    
    setState(() {
      _userQRCode = qrCode;
      _isLoading = false;
    });
  }

  Future<void> _regenerateQRCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate QR Code?'),
        content: const Text(
          'This will create a new QR code. Your old printed QR codes will no longer work with your alarms.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      const uuid = Uuid();
      final newQRCode = 'ALARM_QR_${uuid.v4()}';
      await prefs.setString('user_qr_code', newQRCode);
      
      setState(() {
        _userQRCode = newQRCode;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ New QR code generated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _printQRCode() async {
    try {
      await platform.invokeMethod('printQRCode', {
        'qrData': _userQRCode ?? '',
      });
    } catch (e) {
      debugPrint('Error printing QR code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareQRCode() async {
    try {
      await platform.invokeMethod('shareQRCode', {
        'qrData': _userQRCode ?? '',
      });
    } catch (e) {
      debugPrint('Error sharing QR code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your QR Code'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _regenerateQRCode,
            tooltip: 'Regenerate QR Code',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.lightBlueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Your Unique QR Code',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        
                        const SizedBox(height: 10),
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Scan this code to dismiss your QR alarms',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // QR Code Display
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: _userQRCode ?? '',
                            version: QrVersions.auto,
                            size: 250,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Instructions
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: const [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.white),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Instructions',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 15),
                              Text(
                                '1. Print or share your QR code using the buttons below\n'
                                '2. Place it somewhere you need to go (bathroom, kitchen, etc.)\n'
                                '3. When your QR alarm rings, scan this code to turn it off!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Print and Share Buttons
                        Row(
                          children: [
                            // Print Button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _printQRCode,
                                icon: const Icon(Icons.print, size: 24),
                                label: const Text(
                                  'Print',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 5,
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 15),
                            
                            // Share Button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _shareQRCode,
                                icon: const Icon(Icons.share, size: 24),
                                label: const Text(
                                  'Share',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 15),
                        
                        const Text(
                          'Print to paper or share to other apps',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}