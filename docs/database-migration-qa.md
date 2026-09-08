# Database migration QA

The current SQLite schema version is 6. Migrations are one-way and must run
in order from versions 1 through 6:

1. v1: receipts and receipt items
2. v2: friends, groups, and group members
3. v3: item assignments plus `receipts.groupId` and `receipts.paidBy`
4. v4: multi-page `receipt_images`
5. v5: `payments`
6. v6: confirmed `receipt_events`

## Upgrade test

On an Android emulator or iOS simulator/device:

1. Install a build at the prior schema version.
2. Seed realistic data:
   - A draft and confirmed receipt with items.
   - Friends, groups, group membership, and assignments.
   - Receipt image paths.
   - Payments and activity events where supported by the starting version.
3. Install the new build over the existing app without clearing data.
4. Confirm startup completes and all existing rows are readable.
5. Confirm new tables are writable:
   - Scan or create a multi-page receipt.
   - Record a settlement.
   - Confirm activity history.
6. Export JSON from Settings and verify every current table is present.

Also test a direct v1-to-v6 upgrade because `onUpgrade` is intentionally
ordered to apply every intermediate migration when a device skips releases.
Fresh install testing must separately confirm `onCreate` creates the complete
current schema without running upgrade blocks.

The Windows environment cannot run the native sqflite database integration
used by Android/iOS, so this checklist must be executed as part of release
device QA.
