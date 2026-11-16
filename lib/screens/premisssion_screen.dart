import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionHandler {
  static const platform = MethodChannel('permission_channel');

  static Future<void> requestAllPermissions(BuildContext context) async {
    // Request essential permissions that need user interaction
    final permissions = [
      {
        'title': 'Notifications',
        'description': 'Show alarm notifications and alerts',
        'icon': Icons.notifications,
        'method': 'requestNotificationPermission',
      },
      {
        'title': 'Exact Alarms',
        'description': 'Ring alarms at precise times',
        'icon': Icons.alarm,
        'method': 'requestExactAlarmPermission',
      },
      {
        'title': 'Display Over Apps',
        'description': 'Show alarm screen when phone is locked',
        'icon': Icons.phone_android,
        'method': 'requestOverlayPermission',
      },
      {
        'title': 'Camera',
        'description': 'Scan QR codes to dismiss alarms',
        'icon': Icons.camera_alt,
        'method': 'requestCameraPermission',
      },
    ];

    for (var permission in permissions) {
      final shouldRequest = await _showPermissionDialog(
        context,
        permission['title'] as String,
        permission['description'] as String,
        permission['icon'] as IconData,
      );

      if (shouldRequest) {
        try {
          await platform.invokeMethod(permission['method'] as String);
          await Future.delayed(const Duration(milliseconds: 800));
        } catch (e) {
          debugPrint('Error requesting ${permission['title']}: $e');
        }
      }
    }
  }

  static Future<bool> _showPermissionDialog(
    BuildContext context,
    String title,
    String description,
    IconData icon,
  ) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.blue, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Required for core alarm features',
                      style: TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            child: const Text('Skip', style: TextStyle(fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Allow', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ) ?? false;
  }

  // ✅ FIX: Clear permission flag - call this when app is uninstalled/reinstalled
  static Future<void> resetPermissionFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('has_seen_permissions');
    await prefs.remove('app_install_time');
  }

  // ✅ FIX: Check if permissions need to be shown - handles reinstall case
  static Future<bool> shouldShowPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      // Get app install time from native
      final currentInstallTime = await platform.invokeMethod<int>('getInstallTime');
      final savedInstallTime = prefs.getInt('app_install_time');
      
      // If install times don't match, this is a fresh install/reinstall
      if (currentInstallTime != null && savedInstallTime != currentInstallTime) {
        // Clear old permission flag and save new install time
        await prefs.remove('has_seen_permissions');
        await prefs.setInt('app_install_time', currentInstallTime);
        debugPrint('✅ Fresh install detected, showing permissions');
        return true;
      }
      
      // Check if user has seen permissions for this install
      final hasSeenPermissions = prefs.getBool('has_seen_permissions') ?? false;
      return !hasSeenPermissions;
      
    } catch (e) {
      debugPrint('Error checking install time: $e');
      // Fallback to old behavior
      final hasSeenPermissions = prefs.getBool('has_seen_permissions') ?? false;
      return !hasSeenPermissions;
    }
  }

  // ✅ Mark permissions as seen
  static Future<void> markPermissionsAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_permissions', true);
    
    // Also save install time if not already saved
    try {
      final currentInstallTime = await platform.invokeMethod<int>('getInstallTime');
      if (currentInstallTime != null) {
        await prefs.setInt('app_install_time', currentInstallTime);
      }
    } catch (e) {
      debugPrint('Error saving install time: $e');
    }
    
    debugPrint('✅ Permissions marked as seen');
  }
}

class PermissionIntroScreen extends StatelessWidget {
  final VoidCallback onComplete;

  const PermissionIntroScreen({Key? key, required this.onComplete}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6448FE), Color(0xFF5FC6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        // ✅ FIX: Wrap with SingleChildScrollView to prevent overflow
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                           MediaQuery.of(context).padding.top - 
                           MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 1),
                      
                      // App Icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.alarm,
                          size: 80,
                          color: Color(0xFF6448FE),
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      const Text(
                        'Welcome to Classic Clock',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      
                      const Text(
                        'To ensure your alarms work perfectly, we need a few permissions.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 35),
                      
                      // Permission items
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: const [
                            _PermissionItem(
                              icon: Icons.notifications,
                              title: 'Notifications',
                              description: 'Show alarm alerts',
                            ),
                            SizedBox(height: 16),
                            _PermissionItem(
                              icon: Icons.alarm,
                              title: 'Exact Alarms',
                              description: 'Ring at precise times',
                            ),
                            SizedBox(height: 16),
                            _PermissionItem(
                              icon: Icons.phone_android,
                              title: 'Display Over Apps',
                              description: 'Show on lock screen',
                            ),
                            SizedBox(height: 16),
                            _PermissionItem(
                              icon: Icons.camera_alt,
                              title: 'Camera',
                              description: 'Scan QR codes',
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(flex: 1),
                      
                      // Get Started Button
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ElevatedButton(
                          onPressed: () async {
                            await PermissionHandler.requestAllPermissions(context);
                            await PermissionHandler.markPermissionsAsSeen();
                            onComplete();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF6448FE),
                            elevation: 8,
                            shadowColor: Colors.black.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}