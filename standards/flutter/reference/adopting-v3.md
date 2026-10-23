# Flutter House Standard v3 · Topic: adopting v3 in existing projects, and what changed in v3

> Part of the Flutter house standard v3: sections 23 and 24 in full. `../SKILL.md` lists every section
> and says when to read this file; the section numbers match it.

---

## 23. Existing Projects: Adopting v3

New code follows v3 from day one. Existing code changes **only through planned work items** (one topic each).
This is the recommended order, highest value first:
1. Network core: `DioClient` singleton + `AuthInterceptor` + `LoggingInterceptor` + `ApiRequest`; repositories
   become one call each.
2. `DioExceptions` without force-unwraps.
3. Storage: Future-based `SharedPreference` + `PrefKeys` + `SessionManager`; tokens to secure storage (with a
   one-time migration of the stored tokens so users stay logged in).
4. Remove GetX: `rootNavigatorKey`, `scaffoldMessengerKey`, `AppFeedback`, plain widgets instead of extensions.
5. Routing: `extraAs<T>()` instead of `state.extra as T`; the login redirect.
6. Lifecycle: dispose controllers; `mounted` checks after `await`; no provider writes in `build()`.
7. Split components over ~300 lines; move cross-feature models and providers to `global_features`.

The project analysis checks for these deviations (search patterns): `DioClient().dio` in repositories,
`'Authorization'` outside the interceptor, `Get.context` / `Get.key` / `package:get`, `statusCode == 200`,
`response!`, `state.extra as`, `static void .* async` in storage, `addPostFrameCallback` inside `build`,
imports from other features, `Color(0x` inside `lib/features/`, `http://` base URLs, keys in `main.dart`.
Existing route constants (including sub-routes written with a leading `/`) keep working: don't rename them
without a plan.

---

## 24. Changes in v3

| # | Change | Why (evidence from a production app analysis) |
|---|---|---|
| 1 | `AuthInterceptor` adds headers; `ApiRequest` handles errors; repositories shrink to one call | headers were written by hand 39–42 times; try/catch copied into 43 calls |
| 2 | `DioClient` is a real singleton with base URL and timeouts | a new Dio per call, no timeouts |
| 3 | Debug-only, masked `LoggingInterceptor` that never touches the real request | tokens logged in release builds; log fields leaked into request headers |
| 4 | Null-safe `DioExceptions` with `ApiErrorType` | `response!` crashed on connection errors |
| 5 | Working 401 handling: `SessionManager` + router redirect + provider reset | logout and maintenance handlers were empty stubs |
| 6 | No GetX: `app_keys.dart` + `AppFeedback` | `Get.context` / `Get.key` used 36 times |
| 7 | `issuccess == true` is the only success check | mixed with `statusCode == 200` |
| 8 | Controllers return results; pages navigate; `mounted` after `await` | context used across async gaps |
| 9 | Controllers disposed in State; no provider writes in `build()` | 14 controllers vs 3 disposes; writes from build |
| 10 | Cross-feature code in `global_features`; components ≤ ~300 lines | 22 cross-feature imports; components up to 1,361 lines |
| 11 | Future-based storage, `PrefKeys`, `SessionManager`, secure tokens | fire-and-forget writes; global token variable |
| 12 | Env files, `firebase_options.dart`, HTTPS | keys in source; `http://` API |
| 13 | `extraAs<T>()` and the login redirect | hard casts of `state.extra` |
| 14 | `RequestModel` naming; no empty placeholder files; JSON sample comments | mixed `RequestBody` / `RequestModel`; empty files and an empty demo feature |
| 15 | Complete, compile-checked core + reference features + tests (reference files) | agents had no complete example to copy |
| v2 | Riverpod 3 imports, snake_case files, testable controllers, `.notifier`, secure storage, UI-only features, testing and security sections | see the kit CHANGELOG |
