---
name: project-architecture
description: Flutter house architecture standard v3 (feature-first, Riverpod, GoRouter, Dio, ScreenUtil), built from a production app and compile-checked. Folder structure, naming, data flow, API calling (one interceptor + ApiRequest), session and secure storage, routing, error handling, design system and testing; complete copy-ready code in reference/. MANDATORY: read it before planning or writing any code.
---
<!-- aidlc-kit:standard=flutter · house standard v3 · project-owned copy: init-project.sh never overwrites it (use --update-architecture) -->

# Flutter Project Architecture: House Standard v3

> **⚠️ CRITICAL**: Every agent MUST read and follow this standard before writing any code, creating any
> file, or modifying any module. Violations break the project's consistency and are NOT acceptable.
> Workflow rules: `.agents/rules/00-aidlc-core.md`, `10-quality-gates.md`, `30-learning.md`.

**How to use this file**
- **This file: read it before planning.** Sections 1–6 and 17–19 are here in full. Every other section is
  a short entry that names its **topic file** and when to read it: open that file before you plan or write
  code in that area. The hard rules are always loaded (`.agents/rules/20-architecture.md`).
- **Topic files** in `.agents/skills/project-architecture/reference/` hold the full text of the other
  sections (same numbers): `patterns.md` (7, 10, 11) · `routing-api.md` (8, 9) · `app-shell.md` (12–16) ·
  `build-test-security.md` (20–22) · `adopting-v3.md` (23, 24).
- **Reference files** in `.agents/skills/project-architecture/reference/`: complete files. Open one only when
  you create or copy that code. Every code block whose first line is a path comment (`// lib/...` or
  `// test/...`) is a **whole file**: create it at that path. Replace `app` in `package:app/...` with your
  package name (`name:` in `pubspec.yaml`). Blocks without a path line are short examples.
  - `reference/core.md` (A): the core layer. Copy all of it when you start a new project.
  - `reference/feature-items.md` (B): the reference feature `items` (create, read, update, delete,
    pagination). Copy its patterns for every new feature.
  - `reference/feature-sign-in.md` (C): `sign_in` (login, tokens, session).
  - `reference/tests.md` (D): tests.
- The reference files are compiled and tested together: `flutter analyze` reports no issues and all tests
  pass on flutter_riverpod 2.6.1 and 3.3.2, go_router 14 and dio 5.

**Contents:** 1 Overview · 2 Directory structure · 3 Core module · 4 Feature module · 5 Data flow ·
6 Naming · 7 Patterns · 8 Routing · 9 API integration · 10 State management · 11 Error handling ·
12 Storage and session · 13 Entry point · 14 Design system · 15 Assets · 16 Global features and widgets ·
17 Imports · 18 New-feature checklist · 19 Placement rules · 20 Commands · 21 Testing · 22 Dependencies,
configuration and security · 23 Existing projects · 24 Changes in v3 · Reference files: `core.md` (A) ·
`feature-items.md` (B) · `feature-sign-in.md` (C) · `tests.md` (D)

---

## 1. Architecture Overview

| Layer | Technology |
|---|---|
| **State Management** | Flutter Riverpod (`flutter_riverpod`), hand-written providers |
| **Routing** | GoRouter (`go_router`) with a login redirect |
| **Networking** | Dio (`dio`): one client, `AuthInterceptor` + `LoggingInterceptor`, `ApiRequest` helper |
| **Session** | `SessionManager` (tokens in memory) + `flutter_secure_storage` |
| **Local Storage** | SharedPreferences (settings) + Hive (structured offline data, if needed) |
| **Responsive UI** | ScreenUtil (`flutter_screenutil`) |
| **Architecture** | Feature-First + Repository Pattern + Riverpod |
| **Testing** | `flutter_test` with a fake Dio adapter (no extra package) |

> **IMPORTANT**: Before doing any work, read `aidlc-docs/project-profile.md` (run
> `.agents/skills/project-analysis/SKILL.md` if it is missing or older than 30 days) and the brain
> (`30-learning.md`). The patterns below are the standard; adapt names to the actual project.

### 1.1 Version notes
- **flutter_riverpod 3.x:** `ChangeNotifierProvider`, `StateNotifierProvider`, `StateProvider` and
  `StateNotifier` live in `package:flutter_riverpod/legacy.dart`, and `Override` (used in tests) in
  `package:flutter_riverpod/misc.dart`. The reference files contain these imports as commented lines marked
  `// flutter_riverpod 3.x: uncomment`. On 3.x, uncomment them, then run
  `dart fix --apply --code=unused_import`.
- **AsyncValue on Riverpod 2:** `.value` **throws** when the state is an error without data. Use
  `hasValue` + `requireValue` (works on 2.x and 3.x), or `when(...)`.
- **go_router:** top-level route paths start with `/`; sub-route paths do not. `RouterPath` builds the full
  path (section 8).
- Use the versions the project resolves (`pubspec.lock`). New projects use current stable versions with
  `^` constraints (section 22).

---

## 2. Top-Level Directory Structure

```
project_root/
├── android/ · ios/ · web/ …        # platform code
├── assets/
│   ├── animations/                 # Lottie / animation files
│   ├── fonts/                      # Custom font families
│   ├── icons/                      # App icons, SVG icons
│   └── images/                     # Static images
├── env/                            # dev.json, prod.json (git-ignored) + example.json (committed)
├── lib/
│   ├── main.dart                   # App entry point (reference/core.md)
│   ├── core/                       # Shared core infrastructure (section 3)
│   ├── features/                   # Feature modules (section 4)
│   └── generated/                  # Auto-generated files (assets, l10n)
├── test/                           # Mirrors lib/ (section 21)
├── pubspec.yaml
└── analysis_options.yaml
```

---

## 3. Core Module Structure (`lib/core/`)

The `core/` module contains all **shared infrastructure** used across features. Feature-specific code MUST
NOT go here. All files below are in `reference/core.md`.

```
lib/core/
├── config/
│   ├── env.dart                     # Env: flavor, base URL, app module (from --dart-define-from-file)
│   ├── api_config.dart              # UrlUtils: every API URL (path parameters as functions)
│   ├── app_constant_config.dart     # appName, `module` header value
│   ├── app_keys.dart                # rootNavigatorKey, scaffoldMessengerKey (instead of GetX)
│   ├── color_config.dart            # ColorConfig: all colors and gradients
│   ├── router_config.dart           # route constants, GoRouter (+ login redirect), RouterPath, extraAs()
│   ├── size_config.dart             # SizeConfig: screen size holders
│   ├── theme_config.dart            # theme(): ThemeData
│   └── network/
│       ├── dio_client.dart          # DioClient: ONE Dio (singleton): base URL, timeouts, interceptors
│       ├── auth_interceptor.dart    # standard headers + 401 (logout or optional token refresh)
│       ├── logging_interceptor.dart # debug-only, masked request/response log
│       ├── dio_exceptions.dart      # DioException → ApiErrorType + message (never crashes)
│       └── api_request.dart         # ApiRequest.send: one try/catch for every API call
└── global/
    ├── util/
    │   ├── app_device_info.dart     # app version, platform (initialized after the first frame)
    │   ├── app_feedback.dart        # snackbars + loading dialog without BuildContext
    │   ├── app_logger.dart          # debug-only logging
    │   ├── global_validation.dart   # form validators
    │   ├── session_manager.dart     # login session: tokens, logout, notifies the router
    │   └── shared_preferences.dart  # SharedPreference (all methods return Future) + PrefKeys
    ├── widgets/                     # reusable widgets (section 16)
    │   ├── app_state_views.dart     # AppLoadingView, AppEmptyView, AppErrorView
    │   ├── confirm_dialog.dart      # showConfirmDialog()
    │   ├── custom_appbar.dart       # GlobalAppBar
    │   ├── custom_transition_page.dart  # buildPageWithTransition() + AppTransitionType
    │   ├── input_text_field.dart    # InputTextField
    │   ├── primary_button.dart      # PrimaryButton
    │   └── ...                      # project widgets (image view, shimmer, bottom sheet, …)
    └── global_features/             # shared feature layer (same 5 folders as a feature)
        ├── controller/base_controller.dart
        ├── model/request/app_config_request_model.dart
        ├── model/response/basic_response_model.dart · app_config_response_model.dart · image_upload_response_model.dart
        ├── provider/provider.dart   # app-wide providers (user name, email, premium, …)
        └── repository/repository.dart  # GlobalRepository: app config, image upload, …
```

---

## 4. Feature Module Structure (`lib/features/`)

Every feature module MUST follow this **exact** 5-folder internal structure:

```
lib/features/<feature_name>/
├── controller/
│   └── <feature_name>_controller.dart        # Extends BaseController
├── model/
│   ├── request/                              # Request models (toJson)
│   │   └── <name>_request_model.dart
│   └── response/                             # Response models (fromJson)
│       └── <name>_response_model.dart
├── presentation/
│   ├── page/                                 # Full screens (router targets)
│   │   └── <feature_name>_screen.dart
│   └── component/                            # Widget classes used by the pages
│       └── <feature_name>_<part>_component.dart
├── provider/
│   └── <feature_name>_provider.dart          # Riverpod providers for this feature
└── repository/
    └── <feature_name>_repository.dart        # API calls through ApiRequest
```

- **UI-only features** (no API, no data model) may leave out `model/` and `repository/`. Folder names never
  change: no `widget/`, `widgets/`, `screens/`, `views/` or `services/` inside a feature.
- **No empty placeholder files** (`request.dart`, `response.dart`, empty demo features). Create a file when
  it has content. The reference feature is `reference/feature-items.md`.
- **One widget class per component file, at most ~300 lines.** Split bigger components into smaller widget
  classes.
- **Never import another feature's model, provider, controller or repository.** Models and providers used
  by 2+ features move to `core/global/global_features/`.

### 4.1 Feature Discovery
Before starting any work, know all existing features. The feature registry in
`aidlc-docs/project-profile.md` (section 5) lists them with screens, routes and endpoints. If it is missing
or out of date, list `lib/features/` and read the key files (controller, provider).

---

## 5. Architecture Pattern: Data Flow

```
┌─────────────────────────────── PRESENTATION ───────────────────────────────┐
│  Page (scaffold + composition) ── Components (widget classes, no helpers)    │
│     │ ref.watch(dataProvider)                      ▲ new state               │
│     ▼ ref.read(controllerProvider) / notifier      │                         │
│  Providers: ChangeNotifierProvider(controller) · StateNotifierProvider(data) │
└─────┼──────────────────────────────────────────────┼────────────────────────┘
      ▼ calls                                         │ typed model
┌──────────────────────────────── BUSINESS LOGIC ─────┴───────────────────────┐
│  Controller (extends BaseController): rules, AppFeedback, no BuildContext    │
└─────┼──────────────────────────────────────────────▲────────────────────────┘
      ▼                                               │ never throws
┌──────────────────────────────────── DATA ───────────┴───────────────────────┐
│  Repository → ApiRequest.send(call, fromJson, onError)                       │
│  DioClient (one Dio) → AuthInterceptor (headers, 401) → LoggingInterceptor   │
│  Request model (toJson) · Response model (fromJson, JSON sample comment)     │
│  SharedPreference + secure storage · SessionManager · Hive · Firebase        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Data Flow Step-by-Step
1. **Page / Component**: `ref.watch(provider)` to rebuild on state changes; `ref.read(provider)` (or
   `.notifier`) inside callbacks to trigger actions.
2. **Provider**: `ChangeNotifierProvider` holds the controller; `StateNotifierProvider` holds data slices
   (lists, details) and gets the controller with `ref.watch(<feature>ControllerProvider.notifier)`.
3. **Controller**: extends `BaseController`. Business rules, calls the repository, shows feedback through
   `AppFeedback`. It returns results; the page decides navigation.
4. **Repository**: one short method per endpoint using `ApiRequest.send`. No headers, no try/catch: the
   interceptor and `ApiRequest` do that.
5. **Models**: `request/` → `toJson()`; `response/` → `fromJson()`, with the JSON sample comment on top.

---

## 6. Naming Conventions

### 6.1 File Naming (all new files are snake_case)

| Type | Pattern | Example |
|---|---|---|
| Feature folder | `snake_case` | `manage_income_expense/` |
| Controller | `<feature>_controller.dart` | `home_controller.dart` |
| Repository | `<feature>_repository.dart` | `home_repository.dart` |
| Provider | `<feature>_provider.dart` | `home_provider.dart` |
| Screen (Page) | `<feature>_screen.dart` (+ `<feature>_<name>_screen.dart`) | `item_form_screen.dart` |
| Component | `<feature>_<part>_component.dart` | `home_header_component.dart` |
| Request model | `<name>_request_model.dart` | `login_request_model.dart` |
| Response model | `<name>_response_model.dart` | `home_page_config_response_model.dart` |
| Config files | `<purpose>_config.dart` | `color_config.dart` |
| Global widgets | `<widget_name>.dart` | `custom_appbar.dart` |
| Tests | `<file_under_test>_test.dart` | `home_controller_test.dart` |

> PascalCase file names fail `flutter analyze` (`file_names` lint). Class names stay PascalCase:
> `login_request_model.dart` contains `class LoginRequestModel`. Existing files are renamed only through an
> approved plan, together with every import.

### 6.2 Class Naming

| Type | Pattern | Example |
|---|---|---|
| Controller class | `<Feature>Controller` | `HomeController` |
| Repository class | `<Feature>Repository` | `HomeRepository` |
| Screen class | `<Feature>Screen` | `HomeScreen` |
| Component class | `<Feature><Part>Component` | `HomeHeaderComponent` |
| Request model | `<Name>RequestModel` (not `RequestBody`) | `LoginRequestModel` |
| Response model | `<Name>ResponseModel` | `HomePageConfigResponseModel` |
| Controller provider | `<feature>ControllerProvider` | `homeControllerProvider` |
| StateNotifier | `<Purpose>Notifier` | `HomePageDataNotifier` |
| StateNotifier provider | `get<Purpose>Provider` | `getHomePageDataProvider` |

### 6.3 Variable & Method Naming
- `camelCase` for variables, methods and providers; `PascalCase` for classes.
- `SCREAMING_SNAKE_CASE` only for truly global compile-time constants.
- Prefix booleans with `is` / `has` (e.g. `isPremiumUserProvider`, `hasMore`).

### 6.4 JSON sample comment (every model)
Every request and response model starts with the JSON it maps, as `///` lines. Agents and humans see the
contract without opening the API docs:
```dart
/// issuccess : true
/// statusCode : 200
/// message : "OK"
/// payload : {"id": "1", "title": "Groceries"}
class ItemResponseModel { /* … */ }
```

---

## 7. Class Implementation Patterns (full files: `reference/feature-items.md`)

→ `reference/patterns.md` · read it before you write a controller, repository, provider, model, page or component.

---

## 8. Routing Convention (full file: `reference/core.md`, `router_config.dart`)

→ `reference/routing-api.md` · read it when you add or change a route or navigation.

---

## 9. API Integration Convention

→ `reference/routing-api.md` · read it when you add or change an API call.

---

## 10. State Management Rules

→ `reference/patterns.md` · read it when you add or change providers or state.

---

## 11. Error Handling Convention

→ `reference/patterns.md` · read it when you handle errors, logging, or loading, empty and error states.

---

## 12. Local Storage and Session

→ `reference/app-shell.md` · read it when you store data or touch the session (login, logout, tokens).

---

## 13. App Entry Point (`main.dart`, `reference/core.md`)

→ `reference/app-shell.md` · read it when you change `main.dart` or what happens at app start.

---

## 14. Design System Reference

→ `reference/app-shell.md` · read it when you build UI: colors, typography, spacing, accessibility.

---

## 15. Assets Convention

→ `reference/app-shell.md` · read it when you add assets.

---

## 16. Global Features and Global Widgets

→ `reference/app-shell.md` · read it when you use or add a global feature or a shared widget.

---

## 17. Import Convention

**Package imports** across modules (feature → core, core → core/global):
```dart
import 'package:app/core/config/color_config.dart';
import 'package:app/core/global/util/app_feedback.dart';
```
**Relative imports** inside the same feature (or the same core folder):
```dart
import '../repository/items_repository.dart';
import '../model/response/item_list_response_model.dart';
```
> **Rule**: Never import another feature (section 4). Never use relative paths like `../../../core/`; use the
> package import.

---

## 18. Adding a New Feature: Step-by-Step Checklist

This is also the order of the implementation plan's task phases (`reference/feature-items.md` is the full example):

- [ ] 1. Create `lib/features/<feature_name>/` with the folders it needs (UI-only: no `model/`, `repository/`)
- [ ] 2. Response model(s) with `fromJson` + JSON sample comment in `model/response/`
- [ ] 3. Request model(s) with `toJson` in `model/request/` (if needed)
- [ ] 4. URL(s) in `UrlUtils` (`api_config.dart`)
- [ ] 5. Repository: one `ApiRequest.send` method per endpoint
- [ ] 6. Controller extending `BaseController` (repository via constructor; returns results; `AppFeedback`)
- [ ] 7. Provider(s): controller provider + data notifiers (`.notifier`, pagination, `upsert` / `remove`)
- [ ] 8. Page(s) in `presentation/page/`: scaffolding and orchestration only; controllers disposed; mounted checks
- [ ] 9. Component widget classes in `presentation/component/` (one per file, ≤ ~300 lines)
- [ ] 10. Route constant + `GoRoute` in `router_config.dart`; full path in `RouterPath`; `extraAs<T>()` for data
- [ ] 11. Navigation from the calling screen
- [ ] 12. Tests: models, controller (fake repository), notifier, components and page states (section 21)
- [ ] 13. Update the feature registry in `aidlc-docs/project-profile.md`

### 18.1 Phased Task Plan Execution & Status Tracking
Every feature starts with an approved `implementation_plan.md` in `aidlc-docs/work/<id>/`
(`.agents/skills/aidlc-feature/SKILL.md`). While executing it, the agent **MUST** update task items in real time:
- **Active Task**: `- [ ] 🔄 **[IN PROGRESS]** Task description` when starting the task.
- **Finished Task**: `- [x] ✅ **[COMPLETED]** Task description` as soon as the task completes.
- **Pending Tasks**: `- [ ] ⏳ **[PENDING]** Task description`.
- **Live Artifact Updates**: continually update `implementation_plan.md` so the user can inspect progress.

---

## 19. Placement Rules: Where Does Code Go?

| What You're Adding | Where It Goes |
| --- | --- |
| New feature (screen + logic) | `lib/features/<feature_name>/` (5 folders) |
| New API URL | `lib/core/config/api_config.dart` (`UrlUtils`) |
| Base URL, flavor, app key | `env/<flavor>.json` → `lib/core/config/env.dart` |
| New color / gradient | `lib/core/config/color_config.dart` |
| New app constant | `lib/core/config/app_constant_config.dart` |
| New route | `lib/core/config/router_config.dart` (+ `RouterPath`) |
| Header, token or 401 logic | `lib/core/config/network/auth_interceptor.dart` |
| Error message mapping | `lib/core/config/network/dio_exceptions.dart` |
| Snackbar / loading dialog | `AppFeedback` (`lib/core/global/util/app_feedback.dart`) |
| Stored value | `SharedPreference` + a `PrefKeys` constant (tokens → secure storage) |
| Reusable widget (cross-feature) | `lib/core/global/widgets/` |
| Shared utility function | `lib/core/global/util/` |
| Shared API call (2+ features) | `lib/core/global/global_features/repository/` |
| Shared model or provider (2+ features) | `lib/core/global/global_features/model/` or `/provider/` |
| Feature-specific sub-widget (card, chip, dialog) | `lib/features/<feature>/presentation/component/` (dedicated Widget class, NEVER inline function) |
| Feature-specific API call | `lib/features/<feature>/repository/` |
| Feature-specific state | `lib/features/<feature>/provider/` |
| Tests | `test/` mirroring the `lib/` path |

---

## 20. Build & Run Commands

→ `reference/build-test-security.md` · read it for build, run and code-generation commands.

---

## 21. Testing Standard (complete files: `reference/tests.md`)

→ `reference/build-test-security.md` · read it before you plan or write tests.

---

## 22. Dependencies, Configuration and Security

→ `reference/build-test-security.md` · read it when you add a package or touch configuration, Firebase or security.

---

## 23. Existing Projects: Adopting v3

→ `reference/adopting-v3.md` · read it when you plan changes to code that does not follow v3 yet, and during project analysis.

---

## 24. Changes in v3

→ `reference/adopting-v3.md` · read it to see why v3 differs from older code.
