# BillBuddy

BillBuddy is a Flutter bill-splitting app for capturing receipts, correcting
their parsed data, assigning items to people, and recording settlements. The
repository contains a working local-first implementation, automated
regression coverage, and an ongoing UI consistency pass.

## Current status

### Built and verified

- Receipt capture through camera scanning and gallery selection.
- OCR review and correction before a receipt is confirmed.
- Manual bills with itemized entries and no image.
- Group and individual item assignment.
- Deterministic cent-safe split calculations, including remainder cents and
  equal tax distribution.
- Settlement recording capped at the amount still outstanding.
- SQLite persistence, schema migrations through version 6, multi-page receipt
  images, activity events, and JSON export.
- Currency defaults for USD/CAD with a persisted user override.

The calculation, schema, navigation, and split-state behavior have automated
coverage in [`test/`](test/). Device-only database and release checks are
documented in [`docs/database-migration-qa.md`](docs/database-migration-qa.md).

### Built, with known limitations

- The dashboard, receipt lists, and split flow are implemented, but the UI
  redesign is still being consolidated across every screen.
- The current history format is richer for newly created events than for old
  deleted-receipt events, whose original records may no longer exist.
- Native SQLite integration and camera/OCR behavior still require Android/iOS
  device verification; Windows cannot exercise the native `sqflite` path.
- This is local-first storage. There is no account sync or cross-device
  conflict resolution.

### Planned, not started

- Cloud sync and multi-device account recovery.
- Push notifications and scheduled settlement reminders.
- A production signing/identity setup for store distribution.

## Features

- Scan receipts with the camera or choose pages from the gallery in one flow.
- Review and correct OCR results before saving a receipt.
- Create manual bills when no receipt image is available.
- Split itemized bills between individual people or groups.
- Track what you owe and what others owe you using stored assignments.
- Record settlements without allowing payments to exceed the remaining amount.
- View pending bills, completed bills, balances, and activity history.
- Store receipt data locally with SQLite and export account data as JSON.
- Use regional currency defaults with a user-selectable currency override.

Images are used for capture and review. They are not treated as a source of
invented account data; dashboard totals and balances come from stored
repositories.

## Screenshots

The committed screenshot below is an honest snapshot of the current UI, not a
marketing mockup. It also shows why the visual cleanup remains on the roadmap:
the older completed-bills view contains inconsistent merchant/date formatting.

![Current completed bills screen](flutter_01.png)

Additional camera, review, assignment, and split-summary captures should be
taken from a physical device and added as they are verified. They are not
represented here with fabricated or reference-image data.

## Product flow

1. Choose **Scan receipt** or create a **Manual bill**.
2. Review the receipt details and itemized entries.
3. Assign items and shared costs to people.
4. Confirm the split and return to the dashboard.
5. Use balances to edit a split or settle only the remaining amount owed.

## Engineering decisions

- **Layered boundaries:** `data` contains passive entities and schema,
  `processes` contains feature contracts and workflows, `services` contains
  platform and persistence implementations, and `presentation` coordinates
  screens through dependency injection. The rules are summarized in
  [`docs/codebase-structure.md`](docs/codebase-structure.md).
- **Explicit errors:** repository and service contracts return `Result<T>`
  values with typed failure information. Screens can show a meaningful error
  instead of treating a missing value as a successful operation.
- **Money in cents:** split and payment calculations convert monetary values to
  integer cents, distribute remainder cents deterministically, and preserve
  the existing equal-tax rule. This avoids binary floating-point rounding
  deciding who owes an extra cent.
- **Migration-first persistence:** SQLite upgrades are ordered from schema
  version 1 through 6 and cover receipts, assignments, images, payments, and
  events. The QA checklist calls for seeded prior-version data and a direct
  v1-to-v6 upgrade, not only a fresh-install test.
- **Local images are separate data:** multi-page image paths live in their own
  table and stale files are cleaned up when receipt pages are replaced or
  deleted.

## UI inspiration

The dashboard direction borrows visual ideas from neo-brutalist editorial
interfaces: strong borders, offset shadows, high-contrast type, and restrained
semantic accents. The current shared theme is moving the app toward consistent
cards, buttons, inputs, and light/dark contrast tokens rather than applying
decorative colors screen by screen.

The inspiration is limited to visual language and interaction emphasis. No
sample names, prices, balances, or other content from reference images is used
as application data. Flutter framework guidance is available in the
[Flutter documentation](https://docs.flutter.dev/).

## Known issues / roadmap

Known limitations are kept visible rather than presented as completed polish:

- Some older screens still have visual drift while the shared theme migration
  continues.
- Physical-device validation is still required for native camera, OCR, SQLite,
  and release-signing behavior.
- Deleted events created before denormalized history summaries cannot recover
  merchant or amount information after the receipt row is gone.

Planned work:

- Add verified workflow screenshots and a short device recording.
- Finish migrating all screens to the shared theme and semantic contrast
  tokens.
- Add cloud sync, authentication, and settlement reminders.
- Complete production signing, Firebase registration, and store-readiness
  checks.

## Project structure

The code is organized by responsibility:

- `lib/data`: entities and database schema.
- `lib/processes`: feature contracts and business workflows.
- `lib/services`: SQLite, OCR, camera, currency, and integrations.
- `lib/presentation`: screens and reusable UI.
- `docs`: architecture, migration, release, and security notes.

See [`docs/codebase-structure.md`](docs/codebase-structure.md) for dependency
and naming rules.

## Development

Install Flutter, then run:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

The app is configured as a private Flutter application and is not published
to pub.dev.

## Seven transparent milestones

These milestones describe the work as a reviewable sequence. They are intended
to be committed with the actual commit dates when the work is performed; they
must not be used to falsify GitHub history or backdate fake activity.

1. **Receipt capture** - combine camera scanning and gallery selection.
2. **Receipt review** - normalize OCR output and support correction before
   confirmation.
3. **Itemized splitting** - assign receipt items to individuals or groups with
   deterministic cent-safe calculations.
4. **Manual bills** - support bills and item entries without an image.
5. **Balances and settlements** - show owed totals and cap settlement payments
   at the amount still outstanding.
6. **Persistence and reliability** - add migrations, multi-page image storage,
   history, export, cleanup, and regression coverage.
7. **Dashboard redesign** - apply the reference-inspired visual system,
   reorganize navigation, and keep displayed values tied to stored data.
