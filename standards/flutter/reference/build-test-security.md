# Flutter House Standard v3 · Topic: commands, testing, dependencies, configuration and security

> Part of the Flutter house standard v3: sections 20, 21 and 22 in full. `../SKILL.md` lists every section
> and says when to read this file; the section numbers match it.

---

## 20. Build & Run Commands

```bash
flutter pub get                                              # dependencies
flutter run --dart-define-from-file=env/dev.json             # run with the dev environment
dart run build_runner build --delete-conflicting-outputs     # only if the project uses code generation
flutter analyze                                              # must report no new issues
flutter test                                                 # all tests
flutter build apk --debug --dart-define-from-file=env/dev.json          # AI-DLC build check
flutter build ios --debug --no-codesign --dart-define-from-file=env/dev.json  # macOS, iOS targets
flutter build appbundle --release --dart-define-from-file=env/prod.json
flutter build ipa --release --dart-define-from-file=env/prod.json
dart fix --apply --code=unused_import                        # after uncommenting Riverpod 3 imports
```
Use `fvm flutter …` instead of `flutter …` when the project has `.fvmrc` or `.fvm/`.

---

## 21. Testing Standard (complete files: `reference/tests.md`)

Every new feature ships with tests. `test/` mirrors `lib/`.

| What | Test type | How |
|---|---|---|
| Request / response models | unit | `fromJson` with full, partial and missing fields; `toJson` skips nulls |
| Repository | unit | `ItemsRepository(dio: fakeDio(adapter))` with `FakeAdapter`: success, server error, no connection, wrong JSON shape |
| Controller | unit | a fake repository through the constructor |
| Notifier | unit | first page, next page, `hasMore`, error state, `upsert` / `remove` |
| Components | widget | inputs rendered, taps call callbacks, validation messages |
| Pages / list states | widget | loading, empty, error, data, with provider overrides |
| Router | widget | login redirect, sub-route paths, `extraAs` fallback |
| Network core | unit | headers added, 401 → logout / refresh + retry, masked logs, null-safe errors |

Rules:
- **No real network, no real Firebase.** Use `FakeAdapter` (`reference/tests.md`) on a `Dio`.
- ScreenUtil widgets need `ScreenUtilInit`: use the `wrap()` helper (`reference/tests.md`).
- Storage in tests: `SharedPreferences.setMockInitialValues({})` and `FlutterSecureStorage.setMockInitialValues({})`.
- Plain `test()` files that call controllers (they use `AppFeedback`) start `main()` with
  `TestWidgetsFlutterBinding.ensureInitialized();`.
- Keep plugin calls out of `build()` so pages can be tested.
- Run: `flutter test` (all) or `flutter test test/features/<feature>` (one feature).

---

## 22. Dependencies, Configuration and Security

1. New packages only through an approved plan. Constraints use `^` (e.g. `dio: ^5.9.0`). Never `any`. Exact
   pins only with a comment explaining why.
2. One library per job: Riverpod (state), GoRouter (navigation), Dio (HTTP). No GetX.
3. **Configuration** comes from `env/<flavor>.json` (git-ignored; commit `env/example.json` with dummy
   values) through `--dart-define-from-file`, read only in `env.dart`.
4. **Firebase:** run `flutterfire configure` and use `DefaultFirebaseOptions.currentPlatform`
   (`firebase_options.dart`). Never paste Firebase options into `main.dart`.
5. **HTTPS only.** No `http://` base URLs (Android blocks cleartext by default, iOS ATS too; keep it that way).
6. No API keys, secrets or tokens in Dart files or committed files. An app-side key (like the `module`
   header) can be extracted from the app, so the backend must not rely on it alone.
7. Tokens in secure storage (section 12). Logs are debug-only and masked (section 11).
8. Release builds: `--obfuscate --split-debug-info=<dir>` when the project wants it; upload the symbols to
   crash reporting.
