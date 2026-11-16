import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../model/alram_model.dart';

class AlarmDatabase {
  static final AlarmDatabase instance = AlarmDatabase._init();
  static Database? _database;

  AlarmDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('alarms.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      // ✅ FIX: Add onOpen to ensure database integrity
      onOpen: (db) async {
        // Verify table exists and has correct structure
        await _verifyDatabaseIntegrity(db);
      },
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE alarms (
        id $idType,
        title $textType,
        time $textType,
        days $textType,
        isActive $integerType,
        gradientColorStart $textType,
        gradientColorEnd $textType,
        isQRAlarm $integerType DEFAULT 0,
        customRingtone TEXT,
        requireUniqueQR $integerType DEFAULT 0
      )
    ''');
  }

  // Migration for existing databases
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE alarms ADD COLUMN isQRAlarm INTEGER DEFAULT 0');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE alarms ADD COLUMN customRingtone TEXT');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE alarms ADD COLUMN requireUniqueQR INTEGER DEFAULT 0');
      } catch (e) {
        // Column might already exist
      }
    }
  }

  // ✅ FIX: Verify database integrity
  Future<void> _verifyDatabaseIntegrity(Database db) async {
    try {
      // Check if table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='alarms'"
      );
      
      if (tables.isEmpty) {
        // Table doesn't exist, create it
        await _createDB(db, 4);
      }
    } catch (e) {
      print('Error verifying database integrity: $e');
    }
  }

  // ✅ FIX: Better error handling for create operation
  Future<int> createAlarm(AlarmModel alarm) async {
    try {
      final db = await instance.database;
      final id = await db.insert(
        'alarms',
        alarm.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return id;
    } catch (e) {
      print('❌ Error creating alarm: $e');
      rethrow;
    }
  }

  // ✅ FIX: Better error handling for read operation
  Future<List<AlarmModel>> readAllAlarms() async {
    try {
      final db = await instance.database;
      const orderBy = 'time ASC';
      final result = await db.query('alarms', orderBy: orderBy);
      return result.map((json) => AlarmModel.fromMap(json)).toList();
    } catch (e) {
      print('❌ Error reading alarms: $e');
      return []; // Return empty list instead of crashing
    }
  }

  // ✅ FIX: Better error handling for update operation
  Future<int> updateAlarm(AlarmModel alarm) async {
    try {
      final db = await instance.database;
      return db.update(
        'alarms',
        alarm.toMap(),
        where: 'id = ?',
        whereArgs: [alarm.id],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ Error updating alarm: $e');
      rethrow;
    }
  }

  // ✅ FIX: Better error handling for delete operation
  Future<int> deleteAlarm(int id) async {
    try {
      final db = await instance.database;
      return await db.delete(
        'alarms',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ Error deleting alarm: $e');
      rethrow;
    }
  }

  // ✅ FIX: Add method to get single alarm by ID
  Future<AlarmModel?> getAlarmById(int id) async {
    try {
      final db = await instance.database;
      final result = await db.query(
        'alarms',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        return AlarmModel.fromMap(result.first);
      }
      return null;
    } catch (e) {
      print('❌ Error getting alarm by ID: $e');
      return null;
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}