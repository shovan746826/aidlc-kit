---
trigger: always_on
description: Flutter house architecture hard rules v3 (feature-first, Riverpod, GoRouter, Dio with one interceptor and ApiRequest, SessionManager). The full standard with complete code is in .agents/skills/project-architecture/SKILL.md.
---
<!-- aidlc-kit:standard=flutter · house standard v3 · project-owned: init-project.sh never overwrites this file (use --update-architecture) -->

# Architecture Rules: Flutter house standard v3 (mandatory)

Full standard: `.agents/skills/project-architecture/SKILL.md` (read it before planning; it names the topic file in
`reference/` to open for each area). Complete, compile-checked code: `reference/core.md` (core layer),
`feature-items.md` (reference feature), `feature-sign-in.md` and `tests.md`. Open them only when you copy their
code. Project facts: `aidlc-docs/project-profile.md`.

## Structure
1. Features live in `lib/features/<feature>/`: `controller/`, `model/request/`, `model/response/`,
   `presentation/page/`, `presentation/component/`, `provider/`, `repository/`. UI-only features skip
   `model/` and `repository/`. No other folder names and no empty placeholder files.
2. No feature code in `lib/core/`. Never import another feature: shared models and providers go to
   `core/global/global_features/`; cross-feature widgets go to `core/global/widgets/`.

## API calling
3. Repositories: one `ApiRequest.send(...)` per endpoint. No headers, no try/catch, no `DioClient()` there.
4. Headers and 401 handling only in `AuthInterceptor`; logging only in the debug-only `LoggingInterceptor`;
   one Dio (`DioClient` singleton with timeouts).
5. URLs only in `UrlUtils` (path parameters as functions, query parameters through `queryParameters`).
   Base URL and app keys only from the env files through `Env`. HTTPS only. No keys in source.
6. Success means `issuccess == true`. Errors are mapped by `DioExceptions` (never `response!`); feedback
   goes through `AppFeedback`.

## State and UI
7. Controllers extend `BaseController`, get their repository through the constructor, return results, and
   never hold a BuildContext or navigate.
8. `ChangeNotifierProvider` for controllers, `StateNotifierProvider` for data (lists as `AsyncValue`),
   `StateProvider` for simple values. Inside providers use `ref.watch(<feature>ControllerProvider.notifier)`.
   flutter_riverpod 3.x: import `legacy.dart` (and `misc.dart` for `Override` in tests). No GetX.
9. Pages only scaffold and compose. **NO `Widget _buildX()` helpers.** Components: one widget class per
   file, about 300 lines at most.
10. Text, focus and animation controllers live in `State` and are disposed. Check `mounted` /
    `context.mounted` after every `await`. No provider writes in `build()`; use `ref.read` in callbacks.
11. Routes: constants + `GoRoute` + `RouterPath`; top level `/x`, sub-routes `x`. Read `extra` with
    `extraAs<T>()`, never `state.extra as T`. The login redirect follows `SessionManager`.

## Data and conventions
12. Storage through `SharedPreference` (every method returns a Future and is awaited; keys in `PrefKeys`).
    Tokens live in secure storage; the session lives in `SessionManager`.
13. Colors from `ColorConfig`; sizes with ScreenUtil (`.w .h .r .sp`); icon-only buttons have a tooltip.
14. New files are snake_case; request models are `<Name>RequestModel`; every model starts with its JSON
    sample comment; use package imports across modules.
15. New packages only through an approved plan, with `^` constraints.
16. Every feature has tests (patterns in `reference/tests.md`) and loading, empty and error states.
