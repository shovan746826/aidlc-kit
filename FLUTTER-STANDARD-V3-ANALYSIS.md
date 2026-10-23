# Flutter House Standard v3: analysis behind the changes

The v3 standard was rebuilt from a production Flutter app that follows the house architecture
(**263 Dart files, 31,755 lines**). The analysis was read-only. No project names, URLs or keys from that
app are in this kit.

## What the real code does well (kept)
- Feature-first folders; `core/config` + `core/global` (`util`, `widgets`, `global_features`).
- Controllers (`ChangeNotifier`) + `StateNotifier` data slices + `StateProvider` UI state, with `autoDispose`
  for screen state.
- `GlobalRepository` for shared calls and `BaseController` helpers.
- A JSON sample comment at the top of every model. It is now a rule.
- GoRouter route constants + `RouterPath` + nested routes + `buildPageWithTransition` with
  `AppTransitionType`.
- `AppRoot` with a keyed `ProviderScope` that resets every provider on logout.
- `ScreenUtilInit` (design size, `minTextAdapt`, `splitScreenMode`) + `SizeConfig`.
- A global widget library (app bar, buttons, inputs, popups, image view, shimmer, bottom sheet, image picker).

## Problems found and how v3 fixes them
| # | Real code (evidence) | Risk | v3 |
|---|---|---|---|
| 1 | 43 API calls; `Authorization` written by hand 39×, `module` 42×; the same try/catch in every method | duplication, a forgotten header | `AuthInterceptor` + `ApiRequest`; one short repository method per endpoint |
| 2 | A new Dio for every call; empty `BaseOptions` (no timeouts) | slow; requests can hang | `DioClient` singleton with base URL and timeouts |
| 3 | Logger prints tokens and bodies in release builds and copies log fields into the real request headers; deprecated `DioError` | data leaks; junk headers | debug-only, masked `LoggingInterceptor` that never changes the request |
| 4 | `response!.statusCode!` in the error mapper | crash when there is no response | null-safe `DioExceptions` with `ApiErrorType` |
| 5 | 401 logout and maintenance handlers are empty stubs | an expired session is never handled | `SessionManager` + login redirect + provider reset; optional refresh hook |
| 6 | GetX for navigation, context and snackbars (36 uses) next to Riverpod and GoRouter | two frameworks; `Get.context!` crashes | `rootNavigatorKey`, `scaffoldMessengerKey`, `AppFeedback`; no GetX |
| 7 | Success checked as `statusCode == 200` (13×) and `issuccess` (19×) | inconsistent | `issuccess == true` only |
| 8 | `context` used after `await` almost everywhere (3 mounted checks) | crash after leaving a screen | mounted checks; controllers return results and pages navigate |
| 9 | 14 `TextEditingController`s, 3 `dispose()` methods | memory leaks | controllers live in `State` and are disposed |
| 10 | `addPostFrameCallback` inside `build()` writing providers; `ref.watch` inside callbacks | rebuild loops, stale data | derive with providers; `ref.read` in callbacks |
| 11 | 22 imports from one feature into another | features tied together | shared code in `global_features` |
| 12 | Imports into core: 333 relative vs 172 package | inconsistent | package imports across modules |
| 13 | Storage writes are fire-and-forget (`static void … async`); raw key strings; a fake fallback value | a write can land after the next read | `Future` methods, always awaited; `PrefKeys` |
| 14 | A global mutable `accessToken`; tokens in plain SharedPreferences | stale token; readable data | `SessionManager` + secure storage |
| 15 | Firebase options and an auth key in source; API over `http://` to an IP | key exposure; unencrypted tokens; iOS config missing | `firebase_options.dart`, env files, HTTPS |
| 16 | `state.extra as Type`; time-based `ValueKey` to force rebuilds | crash on deep link or restore | `extraAs<T>()` with a fallback screen; refresh through providers |
| 17 | 8 component files of 586–1,361 lines; 18 `_buildX` helpers in 2 pages | hard to read and test | one widget per file, about 300 lines at most |
| 18 | Empty placeholder files and an empty `_demo` feature (7 files, 0 lines) | nothing to copy | complete reference feature in the standard |
| 19 | Wrong OTP validator message; startup waits for network work before `runApp` | wrong UX; slow start | tested validators; slow work after the first frame |
| 20 | `RequestBody` and `RequestModel`, PascalCase and snake_case file names mixed | inconsistent | `RequestModel`; snake_case files |

## Decisions
| # | Decision |
|---|---|
| B-D1 | API calling: one interceptor for headers + one `ApiRequest` helper for errors |
| B-D2 | Request models are named `<Name>RequestModel` in `<name>_request_model.dart` |
| B-D3 | No GetX in new projects |
| B-D4 | 401 → logout by default; optional refresh-token hook |

## Verification
All code blocks in the standard's `reference/` files (core layer, reference features `items` and `sign_in`,
tests: 67 files) are extracted into a fresh app by `tests/flutter-standard-check.sh`:
- flutter_riverpod **2.6.1**: `flutter analyze`: no issues · `flutter test`: **39 passed**
- flutter_riverpod **3.3.2** (legacy imports switched on): `flutter analyze`: no issues · `flutter test`: **39 passed**

The check also found 5 issues in the first draft. All are fixed, and each one is now a shared-brain lesson
(S-021 to S-025): `AsyncValue.value` throws in Riverpod 2, an extension import, dio 5.10's
`transformTimeout`, the test binding for GlobalKeys, and the deprecated `debugState`.

## Existing projects
New code follows v3. Existing code changes only through planned work items. Section 23 of the standard gives
the order and the search patterns the project analysis uses to find each deviation.
