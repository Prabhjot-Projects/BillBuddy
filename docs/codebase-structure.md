# BillBuddy codebase structure

The project follows a layered Flutter structure. Dependencies should point
inward toward stable contracts and domain data; platform-specific code stays
at the edges.

```text
lib/
  app/                         App-wide composition and presentation theme
    di/                        Dependency injection/service registration
    theme/                     Theme state and persistence
  core/                        Reusable primitives with no feature ownership
    utils/                     Result/error handling
  data/                        Passive domain models and database schema
    entities/                  Receipt, friend, group, payment, and event models
    schema/                    SQLite table definitions and indexes
  processes/                   Feature contracts and business workflows
    receipt/                   Receipt repositories, OCR pipeline, splitting
    social/                    Friend and group repository contracts
  services/                    External integrations and concrete persistence
    ai/                        Receipt parsing integrations
    camera/                    Camera abstraction and implementation
    currency/                  Currency state and formatting
    ocr/                       Android/iOS OCR implementations
    storage/local/             SQLite, preferences, files, and export
  presentation/
    screens/
      dashboard/               Home/dashboard entry point
      receipts/                Scan, review, split, bill, balance, history
      people/                  Friends and groups
      account/                 Profile, settings, notifications
    widgets/                   Reusable UI components and shared flows
```

## Dependency rules

- `data` must not import `presentation` or platform services.
- `processes` may use `data` and `core`, and exposes feature contracts.
- `services` implements process contracts and may depend on platform packages.
- `presentation` coordinates UI and calls process contracts through
  dependency injection; it should not contain SQLite or OCR implementation
  details.
- `app/di` is the composition root. New services are registered there rather
  than constructed inside screens.
- Prefer `package:billbuddy/...` imports between feature folders. Relative
  imports are acceptable only for files that live in the same small feature
  folder.

## Naming

- Use `snake_case.dart` for files.
- Name screens with a `*_screen.dart` suffix.
- Name interfaces by responsibility (`ReceiptRepository`) and concrete
  implementations with an infrastructure prefix (`SqliteReceiptRepository`).
- Keep comments focused on decisions, invariants, or non-obvious tradeoffs;
  do not comment straightforward assignments.

When adding a feature, place its domain entities in `data/entities`, its
contracts/workflows in the appropriate `processes` feature, its integrations
in `services`, and its screens under the matching `presentation/screens`
feature folder.
