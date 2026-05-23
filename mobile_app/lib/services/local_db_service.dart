import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/attendance.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendance.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        image_base64 TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        synced INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertAttendance(Attendance attendance) async {
    final db = await _database;
    return await db.insert('attendance', attendance.toMap());
  }

  Future<List<Attendance>> getPendingAttendances() async {
    final db = await _database;
    final maps = await db.query('attendance', where: 'synced = ?', whereArgs: [0]);
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }

  Future<int> markAsSynced(int id) async {
    final db = await _database;
    return await db.update('attendance', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
