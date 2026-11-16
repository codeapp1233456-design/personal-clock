import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../model/alram_model.dart';
import '../theme/colors.dart';

class AddEditAlarmScreen extends StatefulWidget {
  final AlarmModel? alarm;
  final bool isQRAlarm;

  const AddEditAlarmScreen({
    Key? key,
    this.alarm,
    this.isQRAlarm = false,
  }) : super(key: key);

  @override
  State<AddEditAlarmScreen> createState() => _AddEditAlarmScreenState();
}

class _AddEditAlarmScreenState extends State<AddEditAlarmScreen> {
  late TextEditingController _titleController;
  late TimeOfDay _selectedTime;
  late List<String> _selectedDays;
  late List<Color> _selectedGradient;
  late bool _isQRAlarm;
  late bool _requireUniqueQR;  // NEW
  String? _selectedRingtone;
  String _ringtoneDisplayName = 'Default Alarm';
  
  static const platform = MethodChannel('ringtone_channel');

  final List<String> _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  
  final List<Map<String, dynamic>> _gradientOptions = [
    {'name': 'Sky', 'colors': GradientColors.sky},
    {'name': 'Sea', 'colors': GradientColors.sea},
    {'name': 'Mango', 'colors': GradientColors.mango},
    {'name': 'Fire', 'colors': GradientColors.fire},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.alarm?.title ?? '',
    );
    _selectedTime = widget.alarm?.time ?? TimeOfDay.now();
    _selectedDays = widget.alarm?.days ?? [];
    _selectedGradient = widget.alarm?.gradientColors ?? GradientColors.sky;
    _isQRAlarm = widget.alarm?.isQRAlarm ?? widget.isQRAlarm;
    _requireUniqueQR = widget.alarm?.requireUniqueQR ?? false;  // NEW
    _selectedRingtone = widget.alarm?.customRingtone ?? 'default';
    
    _setupRingtoneChannel();
  }

  void _setupRingtoneChannel() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'ringtoneSelected') {
        final uri = call.arguments as String?;
        if (uri != null) {
          setState(() {
            _selectedRingtone = uri;
            _ringtoneDisplayName = 'Custom Ringtone';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  Future<void> _showRingtoneOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Alarm Sound',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Default ringtone option
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('Default Alarm'),
              trailing: _selectedRingtone == 'default' 
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                setState(() {
                  _selectedRingtone = 'default';
                  _ringtoneDisplayName = 'Default Alarm';
                });
                Navigator.pop(context);
              },
            ),
            
            const Divider(),
            
            // Pick from device
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('Choose from Device'),
              subtitle: const Text('Select any ringtone from your phone'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await platform.invokeMethod('pickRingtone');
                } catch (e) {
                  debugPrint('Error picking ringtone: $e');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _saveAlarm() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter alarm title')),
      );
      return;
    }

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    final alarm = AlarmModel(
      id: widget.alarm?.id,
      title: _titleController.text,
      time: _selectedTime,
      days: _selectedDays,
      isActive: widget.alarm?.isActive ?? true,
      gradientColors: _selectedGradient,
      isQRAlarm: _isQRAlarm,
      customRingtone: _selectedRingtone,
      requireUniqueQR: _requireUniqueQR,  // NEW
    );

    Navigator.pop(context, alarm);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.alarm == null 
            ? (_isQRAlarm ? 'Add QR Alarm' : 'Add Alarm')
            : 'Edit Alarm'
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveAlarm,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // QR Alarm indicator
            if (_isQRAlarm)
              Container(
                padding: const EdgeInsets.all(15),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.qr_code_2, color: Colors.deepPurple),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This is a QR Alarm. You\'ll need to scan a QR code to dismiss it.',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Title Input
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Alarm Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 30),

            // Time Picker
            const Text(
              'Time',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _selectTime,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 30),
                        const SizedBox(width: 15),
                        Text(
                          _selectedTime.format(context),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ],
                    ),
                    const Icon(Icons.edit),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Ringtone Selector
            const Text(
              'Alarm Sound',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _showRingtoneOptions,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.music_note, size: 30),
                        const SizedBox(width: 15),
                        Text(
                          _ringtoneDisplayName,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // NEW: QR Code Security Option (only show if it's a QR alarm)
            if (_isQRAlarm) ...[
              const Text(
                'QR Code Security',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Require My Unique QR Code',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        _requireUniqueQR 
                            ? '🔒 Only your specific QR code will work'
                            : '🔓 Any QR code will turn off the alarm',
                        style: TextStyle(
                          fontSize: 13,
                          color: _requireUniqueQR ? Colors.orange : Colors.green,
                        ),
                      ),
                      value: _requireUniqueQR,
                      onChanged: (value) {
                        setState(() {
                          _requireUniqueQR = value;
                        });
                      },
                      activeColor: Colors.deepPurple,
                    ),
                    if (_requireUniqueQR)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline, size: 18, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Make sure to print your QR code first!',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],

            // Days Selection
            const Text(
              'Repeat Days',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: _allDays.map((day) {
                final isSelected = _selectedDays.contains(day);
                return ChoiceChip(
                  label: Text(day),
                  selected: isSelected,
                  onSelected: (_) => _toggleDay(day),
                  selectedColor: _isQRAlarm ? Colors.deepPurple : Colors.blue,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),

            // Gradient Color Selection
            const Text(
              'Theme Color',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _gradientOptions.length,
                itemBuilder: (context, index) {
                  final option = _gradientOptions[index];
                  final colors = option['colors'] as List<Color>;
                  final isSelected = _selectedGradient == colors;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedGradient = colors;
                      });
                    },
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 15),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: colors[0].withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          option['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}