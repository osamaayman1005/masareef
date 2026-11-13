# Masareef — rules for anyone changing this code

Personal, offline expense tracker for Android. Reads bank SMS, sorts money
into categories, asks the user when unsure. No backend, no network, English UI.

These rules are enforced. CI blocks a build when formatting, the analyzer or
a test fails. Never weaken a rule to get a green build: fix the code.

## Layers

```
lib/
  domain/   Plain data types and money helpers. Imports nothing from the app.
  parser/   SMS text -> ParseOutcome. Pure Dart. Patterns live in
            assets/parser/patterns.json, not in code.
  data/     SQLite (database.dart, ledger_store.dart) and the SMS channel.
            The only place that knows SQL or platform channels.
  logic/    Pure functions and services: totals, inbox, sync.
  state/    AppController: the one object screens talk to.
  ui/       Screens and widgets. No business rules, no SQL.
  app.dart  Wires concrete classes together. main.dart only calls it.
```

Dependencies point down only: `ui -> state -> logic -> data/parser -> domain`.
A lower layer never imports a higher one.

## Hard rules

1. **Never lose data on update.**
   - `applicationId` is `app.masareef` forever. `ci/apply_android_overlay.py`
     fails the build if it changes.
   - `ci/signing.keystore` signs every build. CI checks the fingerprint in
     `ci/signing-cert-sha256.txt`. Never replace or regenerate the key.
   - Database changes are new steps appended to `_migrations` in
     `lib/data/database.dart`. Never edit or delete an existing step.
   - Enum `dbName` strings are stored. Never rename one.
2. **Never count money twice.** Every SMS has a stable `messageKey`; the store
   refuses a key it already has. Totals are computed fresh from the snapshot
   in `logic/spending.dart`, visiting each transaction once. Splits of cash
   or transfers can never exceed the amount (checked in `AppController.assign`).
3. **Ignore rules only hide unreadable messages.** The parser runs first; a
   message that parses as money is never ignored.
4. **New SMS format = data + fixture, not code.** Add or adjust a regex in
   `assets/parser/patterns.json`, add the real message (with card digits and
   balances changed) to `test/fixtures/sms_samples.json`, and bump
   `"version"` so old failures are re-read on the user's phone.
5. **Money is integer cents.** No `double` for stored amounts.
6. **One source of truth.** Screens read from `AppScope.of(context)` and call
   controller methods. They never keep their own copy of ledger data.

## Style

- `dart format lib test` before committing. CI rejects unformatted code.
- `flutter analyze --fatal-infos --fatal-warnings` must be clean.
  Rules are in `analysis_options.yaml` (strict casts, inference, raw types).
- Package imports only (`package:masareef/...`) inside `lib/`.
- Files stay under ~300 lines; split a widget out before that.
- Public classes and non-obvious functions get a one-line `///` doc saying
  why they exist, not what the code repeats.
- Names say what things are to the user: `Inbox`, `Log`, `split`, `ignore`.
- Colors and text styles come from `lib/ui/theme.dart` only.
- Catch specific exceptions (`on FormatException`), never bare `catch`.
- Every logic change comes with a test. UI-only changes may skip tests.

## Build and release

Every push to `main` runs `.github/workflows/build.yml`: format check,
analyze, test, generate `android/` with `flutter create`, apply the overlay,
build a signed release APK, verify the key, publish it as a GitHub Release.
A failed build opens an issue with the log.

The version code stays `1`; the visible version is `1.0.<build number>`.
Android allows reinstalling the same version code with the same key, and the
data stays.

## Running locally

```bash
flutter create . --project-name masareef --org app --platforms android
rm -f test/widget_test.dart
python3 ci/apply_android_overlay.py
flutter pub get
flutter test
flutter run
```
