# Shared Brain: Index

Lessons that apply to every project. Read before every plan (`.agents/rules/30-learning.md`).
This is a read-only copy in each project; the source is `~/.aidlc-kit/brain/`. Keep under 6 KB.
Line format: `- [ID](lessons/<file>.md) · type · stack · tags · the lesson in one line · ✓helpful ✗harmful`

## Rules and pitfalls
- [S-001](lessons/S-001-riverpod3-legacy-import.md) · pitfall · flutter · riverpod, versions · Riverpod 3: import legacy.dart for ChangeNotifierProvider, StateNotifierProvider and StateProvider · ✓0 ✗0
- [S-002](lessons/S-002-riverpod3-override-misc.md) · pitfall · flutter · riverpod, testing, versions · Riverpod 3 tests: the Override type is in misc.dart · ✓0 ✗0
- [S-004](lessons/S-004-screenutil-init-in-tests.md) · pitfall · flutter · testing, screenutil · Widget tests need ScreenUtilInit above widgets that use .w .h .r .sp · ✓0 ✗0
- [S-005](lessons/S-005-snake-case-file-names.md) · rule · flutter · naming, lint · New Dart files use snake_case names; PascalCase file names fail flutter analyze · ✓0 ✗0
- [S-007](lessons/S-007-guard-rm-rf.md) · pitfall · any · shell, safety · Never rm -rf a computed path without guarding empty, / and $HOME · ✓0 ✗0
- [S-008](lessons/S-008-bash-pipe-subshell.md) · pitfall · any · shell, bash · Piping into a bash function runs it in a subshell; its variable changes are lost · ✓0 ✗0
- [S-009](lessons/S-009-dio-response-null-safe.md) · pitfall · flutter · networking, dio, errors · Never force-unwrap DioException.response; it is null for connection, certificate and unknown errors · ✓0 ✗0
- [S-011](lessons/S-011-debug-only-redacted-logging.md) · pitfall · flutter · networking, security, logging · HTTP logging must be debug-only and redact secrets; never copy log fields into request headers · ✓0 ✗0
- [S-013](lessons/S-013-await-prefs-writes.md) · pitfall · flutter · storage, async · Await SharedPreferences writes: return Future<void>, never `static void ... async` · ✓0 ✗0
- [S-014](lessons/S-014-dispose-controllers.md) · pitfall · flutter · lifecycle, memory · Dispose every TextEditingController, FocusNode and AnimationController · ✓0 ✗0
- [S-015](lessons/S-015-mounted-after-await.md) · pitfall · flutter · async, context · Check context.mounted after every await before using context · ✓0 ✗0
- [S-016](lessons/S-016-no-state-writes-in-build.md) · pitfall · flutter · riverpod, build · Never write provider state from build() and never ref.watch inside callbacks · ✓0 ✗0
- [S-017](lessons/S-017-safe-go-router-extra.md) · pitfall · flutter · navigation, go_router · Never hard-cast GoRouterState.extra; it is null after a deep link or app restore · ✓0 ✗0
- [S-018](lessons/S-018-shared-code-in-global-features.md) · rule · flutter · architecture, features · Models and providers used by two or more features belong in core/global/global_features · ✓0 ✗0
- [S-019](lessons/S-019-no-getx-with-riverpod.md) · rule · flutter · architecture, navigation, dependencies · Don't use GetX in Riverpod + GoRouter apps; use navigator and messenger keys · ✓0 ✗0
- [S-020](lessons/S-020-no-keys-in-source.md) · pitfall · flutter · security, config · No API keys, auth keys or Firebase options in source; HTTPS only · ✓0 ✗0
- [S-021](lessons/S-021-asyncvalue-value-throws-riverpod2.md) · pitfall · flutter · riverpod, asyncvalue · Riverpod 2: AsyncValue.value throws on an error state without data; use hasValue + requireValue · ✓0 ✗0
- [S-022](lessons/S-022-asyncvalue-extensions-import.md) · pitfall · flutter · riverpod, testing · AsyncValue getters like requireValue and hasError need the flutter_riverpod import (they are extensions in 2.x) · ✓0 ✗0
- [S-023](lessons/S-023-dio-transform-timeout-switch.md) · pitfall · flutter · networking, dio, versions · dio 5.10 added DioExceptionType.transformTimeout: exhaustive switches break across dio versions · ✓0 ✗0
- [S-024](lessons/S-024-test-binding-for-global-keys.md) · pitfall · flutter · testing · Plain test() files that touch GlobalKeys (navigator, messenger) need TestWidgetsFlutterBinding.ensureInitialized() · ✓0 ✗0
- [S-025](lessons/S-025-statenotifier-state-in-tests.md) · rule · flutter · testing, riverpod · In tests read StateNotifier.state; debugState is deprecated · ✓0 ✗0

## Patterns and decisions
- [S-003](lessons/S-003-watch-controller-notifier.md) · pattern · flutter · riverpod, state · Inside another provider use ref.watch(controllerProvider.notifier), not the provider itself · ✓0 ✗0
- [S-010](lessons/S-010-central-headers-api-request.md) · pattern · flutter · networking, dio, architecture · Add standard headers in one interceptor and handle errors in one ApiRequest helper · ✓0 ✗0
- [S-012](lessons/S-012-one-dio-instance.md) · pattern · flutter · networking, dio, performance · Reuse one Dio instance configured with BaseOptions (base URL, timeouts) · ✓0 ✗0
- [S-027](lessons/S-027-quiet-test-output.md) · pattern · any · tokens, tests, output · Run checks with quiet output; read the full output only for failures · ✓0 ✗0

## Facts
- [S-006](lessons/S-006-antigravity-rule-frontmatter.md) · fact · any · agents, antigravity, rules · Antigravity reads .agents/rules/*.md only when the file has a trigger: frontmatter · ✓0 ✗0
- [S-026](lessons/S-026-context-is-the-token-cost.md) · fact · any · tokens, context, sessions · Most tokens are the context read again on every call; keep it small and sessions short · ✓0 ✗0
