# BillBuddy

BillBuddy is a Flutter app for scanning, creating, and splitting bills with
friends. It keeps stored receipt and payment data authoritative while making
the flow from receipt capture to settlement easy to follow.

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

## Product flow

1. Choose **Scan receipt** or create a **Manual bill**.
2. Review the receipt details and itemized entries.
3. Assign items and shared costs to people.
4. Confirm the split and return to the dashboard.
5. Use balances to edit a split or settle only the remaining amount owed.

Images are used for capture and review. They are not treated as a source of
invented account data; dashboard totals and balances come from stored
repositories.

## UI inspiration

The dashboard takes visual inspiration from neo-brutalist editorial
interfaces: a warm yellow canvas, cream paper-like cards, thick black borders,
offset shadows, bold typography, and bright accent colors. This direction was
chosen to make actions and money summaries easy to scan at a glance.

The inspiration is limited to visual language and interaction emphasis. No
sample names, prices, balances, or other content from reference images are
used as application data. For Flutter framework and platform guidance, see
the [Flutter documentation](https://docs.flutter.dev/).

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
should not be used to falsify GitHub history.

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
