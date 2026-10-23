---
trigger: always_on
description: Native Android house architecture hard rules (Kotlin, Compose, MVVM, Hilt, Retrofit, feature-first). The full standard is in .agents/skills/project-architecture/SKILL.md.
---
<!-- aidlc-kit:standard=android · project-owned: init-project.sh never overwrites this file (use --update-architecture) -->

# Architecture Rules: native Android house standard (mandatory)

Full standard with patterns and examples: `.agents/skills/project-architecture/SKILL.md`. Read it before
planning or coding. Project facts: `aidlc-docs/project-profile.md`.

## Structure
1. Every feature lives in `feature/<feature_name>/` with `viewmodel/`, `model/request/`, `model/response/`,
   `presentation/screen/`, `presentation/component/`, `di/`, `repository/`. UI-only features may leave out
   `model/` and `repository/`. Never invent other package names.
2. Never put feature code in `core/`: it is shared infrastructure only. Never mix features.
3. Cross-feature composables → `core/ui/component/`. Design tokens → `core/designsystem/`.

## Patterns
4. MVVM: one `@HiltViewModel` per screen exposing `StateFlow<<Feature>UiState>` (Loading · Empty · Data · Error).
5. Repositories call the Retrofit API, catch errors (rethrow `CancellationException`) and return
   `ApiResult<T>`. They never throw to the UI. 401 → `SessionManager` logout.
6. Screen files contain only `<Feature>Route` (collects state with `collectAsStateWithLifecycle()`) and the
   stateless `<Feature>Screen`. **Every sub-UI is its own composable file in `presentation/component/`**
   with a `@Preview`. No private composable helpers in screen files.
7. Screens never receive `NavController`; navigation happens through callbacks. Routes are type-safe
   `@Serializable` destinations in `core/navigation/Routes.kt`.
8. Dependencies are injected with Hilt (constructor injection); no manual singletons.

## Conventions
9. Endpoint paths only in `ApiConfig`; standard headers only in `AuthInterceptor`.
10. Colors, typography and spacing only from the design system (`MaterialTheme`, `core/designsystem`); no
    hardcoded colors. User-facing text in `strings.xml`.
11. Kotlin files PascalCase, named after their main declaration; packages lowercase.
12. Tokens in encrypted storage; no secrets in code; never log tokens or personal data.
13. New libraries only through an approved plan, declared in `gradle/libs.versions.toml`.
14. Every new feature has tests (ViewModel with a fake repository, UI states) and handles loading, empty
    and error states.
