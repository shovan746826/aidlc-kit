---
trigger: always_on
description: Native iOS house architecture hard rules (Swift, SwiftUI, MVVM, async/await, feature-first). The full standard is in .agents/skills/project-architecture/SKILL.md.
---
<!-- aidlc-kit:standard=ios · project-owned: init-project.sh never overwrites this file (use --update-architecture) -->

# Architecture Rules: native iOS house standard (mandatory)

Full standard with patterns and examples: `.agents/skills/project-architecture/SKILL.md`. Read it before
planning or coding. Project facts: `aidlc-docs/project-profile.md`.

## Structure
1. Every feature lives in `Features/<FeatureName>/` with `ViewModel/`, `Model/Request/`, `Model/Response/`,
   `View/Screen/`, `View/Component/`, `Repository/`. UI-only features may leave out `Model/` and
   `Repository/`. Never invent other folder names.
2. Never put feature code in `Core/`: it is shared infrastructure only. Never mix features.
3. Cross-feature views → `Core/Components/`. Design tokens → `Core/DesignSystem/` + asset catalog.

## Patterns
4. MVVM: one `@MainActor` view model per screen (`@Observable`; `ObservableObject` below iOS 17) with a
   `State` enum (loading · empty · data · error). Dependencies come through `init`.
5. Repositories are protocols with a `Live…` implementation that uses `APIClient`. View models catch every
   error and map it to a state; nothing throws into views. 401 → `SessionManager` logout.
6. Screens only switch on state and compose components. **Every sub-UI is its own `View` struct in
   `View/Component/`** with a `#Preview`. No `@ViewBuilder` helper functions or computed `some View`
   properties in screens.
7. Navigation: `Route` enum + `Router` + `NavigationStack`. Screens get closures, never the router.

## Conventions
8. Endpoint paths only in `APIConfig`; standard headers only in `AuthHeaderProvider`.
9. Colors from the asset catalog via `AppColor`; fonts via `AppFont` (Dynamic Type); text in the string
   catalog; no hardcoded colors or user-facing strings.
10. Swift files are named after their main type (PascalCase).
11. Tokens in the Keychain only; no secrets in code; never log tokens or personal data.
12. New packages only through an approved plan (SPM).
13. Every new feature has tests (view model states with a fake repository) and handles loading, empty and
    error states.
