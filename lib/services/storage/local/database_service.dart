import 'package:billbuddy/data/schema/receipt_schema.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Owns the single sqflite [Database] connection for the whole app.
class DatabaseService {
  static const _dbName = 'billbuddy.db';

  // v1: receipts + receipt_items
  // v2: + friends, groups, group_members
  // v5: + payments for receipt settlement
  static const _dbVersion = 6;

  Database? _database;

  Future<void> initialize() async {
    if (_database != null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, _dbName);

    _database = await openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // Brand-new install: create the full current schema directly.
        await db.execute(ReceiptSchema.createReceiptsTableCurrent);
        await db.execute(ReceiptSchema.createReceiptItemsTable);
        await db.execute(ReceiptSchema.createStatusIndex);
        await db.execute(ReceiptSchema.createReceiptItemsIndex);
        await db.execute(ReceiptSchema.createReceiptImagesTable);
        await db.execute(ReceiptSchema.createReceiptImagesIndex);
        await db.execute(ReceiptSchema.createPaymentsTable);
        await db.execute(ReceiptSchema.createPaymentsIndex);
        await db.execute(ReceiptSchema.createReceiptEventsTable);
        await db.execute(ReceiptSchema.createReceiptEventsIndex);
        await db.execute(ReceiptSchema.createItemAssignmentsTable);
        await db.execute(ReceiptSchema.createItemAssignmentsIndex);
        await db.execute(SocialSchema.createFriendsTable);
        await db.execute(SocialSchema.createGroupsTable);
        await db.execute(SocialSchema.createGroupMembersTable);
        await db.execute(SocialSchema.createGroupMembersGroupIndex);
        await db.execute(SocialSchema.createGroupMembersFriendIndex);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Each block is a one-way step, applied in order, so a device
        // jumping multiple versions at once (e.g. v1 straight to v3)
        // still runs every intermediate migration.
        if (oldVersion < 2) {
          await db.execute(SocialSchema.createFriendsTable);
          await db.execute(SocialSchema.createGroupsTable);
          await db.execute(SocialSchema.createGroupMembersTable);
          await db.execute(SocialSchema.createGroupMembersGroupIndex);
          await db.execute(SocialSchema.createGroupMembersFriendIndex);
        }
        if (oldVersion < 3) {
          await db.execute(ReceiptSchema.addGroupIdColumn);
          await db.execute(ReceiptSchema.addPaidByColumn);
          await db.execute(ReceiptSchema.createItemAssignmentsTable);
          await db.execute(ReceiptSchema.createItemAssignmentsIndex);
        }
        if (oldVersion < 4) {
          await db.execute(ReceiptSchema.createReceiptImagesTable);
          await db.execute(ReceiptSchema.createReceiptImagesIndex);
        }
        if (oldVersion < 5) {
          await db.execute(ReceiptSchema.createPaymentsTable);
          await db.execute(ReceiptSchema.createPaymentsIndex);
        }
        if (oldVersion < 6) {
          await db.execute(ReceiptSchema.createReceiptEventsTable);
          await db.execute(ReceiptSchema.createReceiptEventsIndex);
        }
      },
    );
  }

  Database get instance {
    final db = _database;
    if (db == null) {
      throw StateError(
        'DatabaseService.initialize() must be called before use. '
        'Check that main.dart awaits it before setupServiceLocator().',
      );
    }
    return db;
  }
}
