import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../models/todo_model.dart';

class DatabaseHelper {
  // Singleton pattern - chỉ tạo 1 instance duy nhất
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // Tên database và bảng
  static const String _dbName = 'todo_app.db';
  static const String _tableName = 'todos';
  static const int _dbVersion = 1;

  // Getter database - tạo mới nếu chưa có
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Khởi tạo database
  Future<Database> _initDatabase() async {
    // ✅ Set factory TRƯỚC mọi thứ
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Tạo bảng khi lần đầu chạy app
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        category TEXT NOT NULL DEFAULT 'todo',
        color TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  // Nâng cấp database nếu version thay đổi
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      await db.execute('DROP TABLE IF EXISTS $_tableName');
      await _onCreate(db, newVersion);
    }
  }

  // ===================== CRUD OPERATIONS =====================

  // CREATE - Thêm todo mới
  Future<int> insertTodo(TodoModel todo) async {
    final db = await database;
    return await db.insert(
      _tableName,
      todo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // READ ALL - Lấy tất cả todos
  Future<List<TodoModel>> getAllTodos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'updatedAt DESC',
    );
    return maps.map((map) => TodoModel.fromMap(map)).toList();
  }

  // READ BY CATEGORY - Lấy theo loại (todo/note)
  Future<List<TodoModel>> getTodosByCategory(String category) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'updatedAt DESC',
    );
    return maps.map((map) => TodoModel.fromMap(map)).toList();
  }

  // READ BY ID - Lấy 1 todo theo id
  Future<TodoModel?> getTodoById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TodoModel.fromMap(maps.first);
  }

  // UPDATE - Cập nhật todo
  Future<int> updateTodo(TodoModel todo) async {
    final db = await database;
    return await db.update(
      _tableName,
      todo.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  // UPDATE - Toggle trạng thái hoàn thành
  Future<int> toggleComplete(int id, bool isCompleted) async {
    final db = await database;
    return await db.update(
      _tableName,
      {
        'isCompleted': isCompleted ? 1 : 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // DELETE - Xóa 1 todo
  Future<int> deleteTodo(int id) async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // DELETE ALL - Xóa tất cả todos đã hoàn thành
  Future<int> deleteCompleted() async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'isCompleted = ?',
      whereArgs: [1],
    );
  }

  // SEARCH - Tìm kiếm theo tiêu đề
  Future<List<TodoModel>> searchTodos(String keyword) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'title LIKE ? OR description LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
      orderBy: 'updatedAt DESC',
    );
    return maps.map((map) => TodoModel.fromMap(map)).toList();
  }

  // COUNT - Đếm số todo chưa hoàn thành
  Future<int> countPending() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE isCompleted = 0 AND category = "todo"',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Đóng database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}