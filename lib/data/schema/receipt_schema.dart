/// Raw SQL schema for the local database. Kept separate from repository
/// classes so schema changes are a one-file diff.
class ReceiptSchema {
  static const String receiptsTable = 'receipts';
  static const String receiptItemsTable = 'receipt_items';
  static const String receiptImagesTable = 'receipt_images';
  static const String paymentsTable = 'payments';
  static const String receiptEventsTable = 'receipt_events';

  static const String statusDraft = 'draft';
  static const String statusConfirmed = 'confirmed';

  // v1 shape — kept for reference in onCreate/onUpgrade history. Do not
  // edit this to add new columns; new columns are added via ALTER TABLE
  // in DatabaseService.onUpgrade, matching how the table actually looks
  // on a device that's been upgraded rather than freshly installed.
  static const String createReceiptsTableV1 =
      '''
    CREATE TABLE $receiptsTable (
      id TEXT PRIMARY KEY,
      merchantName TEXT,
      date TEXT,
      subtotal REAL,
      tax REAL,
      total REAL,
      imagePath TEXT,
      createdAt TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT '$statusDraft'
    )
  ''';

  /// Current full shape, used by onCreate for brand-new installs so a
  /// new user gets the final schema directly, without walking through
  /// ALTER TABLE history that only matters for upgrading devices.
  static const String createReceiptsTableCurrent =
      '''
    CREATE TABLE $receiptsTable (
      id TEXT PRIMARY KEY,
      merchantName TEXT,
      date TEXT,
      subtotal REAL,
      tax REAL,
      total REAL,
      imagePath TEXT,
      createdAt TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT '$statusDraft',
      groupId TEXT,
      paidBy TEXT
    )
  ''';

  static const String createReceiptItemsTable =
      '''
    CREATE TABLE $receiptItemsTable (
      id TEXT PRIMARY KEY,
      receiptId TEXT NOT NULL,
      name TEXT NOT NULL,
      quantity REAL,
      price REAL,
      FOREIGN KEY (receiptId) REFERENCES $receiptsTable (id) ON DELETE CASCADE
    )
  ''';

  static const String createStatusIndex =
      '''
    CREATE INDEX idx_receipts_status ON $receiptsTable (status)
  ''';

  static const String createReceiptItemsIndex =
      '''
    CREATE INDEX idx_receipt_items_receiptId ON $receiptItemsTable (receiptId)
  ''';

  static const String createReceiptImagesTable =
      '''
    CREATE TABLE $receiptImagesTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      receiptId TEXT NOT NULL,
      imagePath TEXT NOT NULL,
      pageNumber INTEGER NOT NULL,
      createdAt TEXT NOT NULL,
      FOREIGN KEY (receiptId) REFERENCES $receiptsTable (id) ON DELETE CASCADE
    )
  ''';

  static const String createReceiptImagesIndex =
      '''
    CREATE INDEX idx_receipt_images_receiptId
    ON $receiptImagesTable (receiptId, pageNumber)
  ''';

  static const String createPaymentsTable =
      '''
    CREATE TABLE $paymentsTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      receiptId TEXT NOT NULL,
      fromParticipantId TEXT NOT NULL,
      toParticipantId TEXT NOT NULL,
      amountCents INTEGER NOT NULL CHECK(amountCents > 0),
      paidAt TEXT NOT NULL,
      note TEXT,
      FOREIGN KEY (receiptId) REFERENCES $receiptsTable (id) ON DELETE CASCADE
    )
  ''';

  static const String createPaymentsIndex =
      '''
    CREATE INDEX idx_payments_receiptId ON $paymentsTable (receiptId)
  ''';

  static const String createReceiptEventsTable =
      '''
    CREATE TABLE $receiptEventsTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      receiptId TEXT NOT NULL,
      eventType TEXT NOT NULL,
      summary TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''';

  static const String createReceiptEventsIndex =
      '''
    CREATE INDEX idx_receipt_events_createdAt
    ON $receiptEventsTable (createdAt DESC)
  ''';

  // v3 additions
  static const String addGroupIdColumn =
      '''
    ALTER TABLE $receiptsTable ADD COLUMN groupId TEXT
  ''';

  static const String addPaidByColumn =
      '''
    ALTER TABLE $receiptsTable ADD COLUMN paidBy TEXT
  ''';

  static const String itemAssignmentsTable = 'item_assignments';

  /// Join table: one row per (item, participant) pair means that
  /// participant shares that item. friendId stores either a real
  /// Friend.id or the meParticipantId sentinel — SQLite doesn't need to
  /// know the difference, and enforcing that distinction at the
  /// database level would require a foreign key that "Me" can't satisfy
  /// (Me is never a row in the friends table). Validation that a given
  /// friendId is either a real friend or the Me sentinel happens in
  /// Dart, at the point assignments are created.
  static const String createItemAssignmentsTable =
      '''
    CREATE TABLE $itemAssignmentsTable (
      receiptItemId TEXT NOT NULL,
      friendId TEXT NOT NULL,
      PRIMARY KEY (receiptItemId, friendId),
      FOREIGN KEY (receiptItemId) REFERENCES $receiptItemsTable (id) ON DELETE CASCADE
    )
  ''';

  static const String createItemAssignmentsIndex =
      '''
    CREATE INDEX idx_item_assignments_receiptItemId ON $itemAssignmentsTable (receiptItemId)
  ''';
}

/// Schema for Friends and Groups.
class SocialSchema {
  static const String friendsTable = 'friends';
  static const String groupsTable = 'groups';
  static const String groupMembersTable = 'group_members';

  static const String createFriendsTable =
      '''
    CREATE TABLE $friendsTable (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''';

  static const String createGroupsTable =
      '''
    CREATE TABLE $groupsTable (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''';

  static const String createGroupMembersTable =
      '''
    CREATE TABLE $groupMembersTable (
      groupId TEXT NOT NULL,
      friendId TEXT NOT NULL,
      PRIMARY KEY (groupId, friendId),
      FOREIGN KEY (groupId) REFERENCES $groupsTable (id) ON DELETE CASCADE,
      FOREIGN KEY (friendId) REFERENCES $friendsTable (id) ON DELETE CASCADE
    )
  ''';

  static const String createGroupMembersGroupIndex =
      '''
    CREATE INDEX idx_group_members_groupId ON $groupMembersTable (groupId)
  ''';

  static const String createGroupMembersFriendIndex =
      '''
    CREATE INDEX idx_group_members_friendId ON $groupMembersTable (friendId)
  ''';
}
