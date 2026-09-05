import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase(this._db);

  static const _fileName = 'opomemo.db';
  static const schemaVersion = 4;
  final Database _db;

  Database get db => _db;

  static Future<AppDatabase> open() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _fileName);
    return AppDatabase(await _open(path));
  }

  @visibleForTesting
  static Future<AppDatabase> openInMemory() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    return AppDatabase(await _open(inMemoryDatabasePath));
  }

  static Future<Database> _open(String path) {
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE decks (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        domain TEXT NOT NULL,
        group_name TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL DEFAULT 'user',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE facts (
        id TEXT PRIMARY KEY,
        deck_id TEXT NOT NULL,
        prompt TEXT NOT NULL,
        answer TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT '',
        kind TEXT NOT NULL DEFAULT 'pregunta',
        cloze_text TEXT NOT NULL DEFAULT '',
        distractors TEXT NOT NULL DEFAULT '[]',
        flagged INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (deck_id) REFERENCES decks(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_facts_deck ON facts(deck_id)');
    await db.execute('''
      CREATE TABLE review_states (
        fact_id TEXT PRIMARY KEY,
        box INTEGER NOT NULL,
        next_due TEXT NOT NULL,
        last_grade TEXT,
        review_count INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (fact_id) REFERENCES facts(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute("ALTER TABLE decks ADD COLUMN group_name TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE decks ADD COLUMN source TEXT NOT NULL DEFAULT 'user'");
    }
    if (from < 3) {
      await db.execute('ALTER TABLE facts ADD COLUMN flagged INTEGER NOT NULL DEFAULT 0');
    }
    if (from < 4) {
      await db.execute("ALTER TABLE facts ADD COLUMN kind TEXT NOT NULL DEFAULT 'pregunta'");
      await db.execute("ALTER TABLE facts ADD COLUMN cloze_text TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE facts ADD COLUMN distractors TEXT NOT NULL DEFAULT '[]'");
    }
  }

  Future<void> close() => _db.close();
}
