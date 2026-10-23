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
- **Sections 1–24 (this file):** the rules and patterns. Read them before planning.
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

### 7.1 Controller
- Extends `BaseController`. The repository comes through an optional constructor parameter (tests pass a
  fake); `ItemsController()` still works.
- **No BuildContext and no navigation inside controllers.** Methods return a result (`bool`, a model or
  `null`); the page pops or navigates. Feedback (snackbar, loading) goes through `AppFeedback`.
```dart
class ItemsController extends BaseController {
  ItemsController({ItemsRepository? repository}) : repository = repository ?? ItemsRepository();

  final ItemsRepository repository;

  Future<bool> deleteItem(String id) async {
    final response = await AppFeedback.withLoading(() => repository.deleteItem(id));
    if (response.issuccess == true) {
      AppFeedback.showSuccess(response.message ?? 'Deleted');
      return true;
    }
    AppFeedback.showError(response.message ?? 'Something went wrong');
    return false;
  }
}
```

### 7.2 Repository (API calling)
One short method per endpoint. **No headers, no try/catch, no `DioClient()` calls**: `ApiRequest` and
`AuthInterceptor` do that once for the whole app.
```dart
Future<ItemListResponseModel> getItems({required int page, int limit = 20}) => ApiRequest.send(
      dio: dio,
      call: (client) => client.get(UrlUtils.itemsUrl, queryParameters: {'page': page, 'limit': limit}),
      fromJson: (json) => ItemListResponseModel.fromJson(json as Map<String, dynamic>),
      onError: (message, statusCode) => ItemListResponseModel(message: message, statusCode: statusCode),
    );
```

### 7.3 Provider
```dart
// ChangeNotifierProvider for the controller
var itemsControllerProvider = ChangeNotifierProvider((ref) {
  ItemsController controller = ItemsController();
  return controller;
});

// StateNotifierProvider for a data slice. `.notifier` = the controller WITHOUT listening to it.
final getItemsProvider = StateNotifierProvider<ItemsNotifier, AsyncValue<List<Item>>>((ref) {
  return ItemsNotifier(ref.watch(itemsControllerProvider.notifier));
});
```
> `ref.watch(itemsControllerProvider)` (without `.notifier`) inside another provider re-creates that
> provider, losing its data, every time the controller calls `notifyListeners()`. This is proven by a
> test. Pages may watch the controller provider itself when they must rebuild on controller changes.

### 7.4 Response Model
The standard shape, with the JSON sample comment (6.4). Numbers are read as `num` and converted, so `200`
and `200.0` both work. **Success check everywhere: `issuccess == true`** (never `statusCode == 200`). Error
models created by `ApiRequest` have `issuccess == null`.
```dart
/// issuccess : true
/// statusCode : 200
/// message : "OK"
/// payload : {"id": "1", "title": "Groceries", "description": "Milk and bread"}
class ItemResponseModel {
  ItemResponseModel({this.issuccess, this.statusCode, this.message, this.payload});

  ItemResponseModel.fromJson(Map<String, dynamic> json) {
    issuccess = json['issuccess'];
    statusCode = (json['statusCode'] as num?)?.toInt();
    message = json['message'];
    payload = json['payload'] != null ? Item.fromJson(json['payload']) : null;
  }

  bool? issuccess;
  int? statusCode;
  String? message;
  Item? payload;
}
```

### 7.5 Request Model
`toJson()` leaves out null fields:
```dart
Map<String, dynamic> toJson() {
  final Map<String, dynamic> data = {};
  if (title != null) data['title'] = title;
  if (description != null) data['description'] = description;
  return data;
}
```

### 7.6 Screen (Page) Pattern

> **⚠️ STRICT RULE — NO WIDGET FUNCTIONS IN PAGES**:
> Never write helper widget functions (e.g., `Widget _buildHeader()`, `Widget _buildItem()`, `Widget _buildFilterChip()`)
> inside any `*_screen.dart` or page file!
> Every UI sub-element must be a standalone `Widget` class (`StatelessWidget`, `StatefulWidget`, or `ConsumerWidget`)
> located inside `presentation/component/`.
> The page file in `presentation/page/` is strictly responsible for scaffolding, app bar, refresh indicators,
> scroll containers, and assembling the component classes.

Additional page rules:
- `TextEditingController`, `FocusNode` and `AnimationController` live in the page's `State` and are
  **disposed** in `dispose()` (`reference/feature-items.md`: `item_form_screen.dart`).
- After every `await`, check `mounted` (State) or `context.mounted` before using `context`.
- **Never write provider state from `build()`** (no `addPostFrameCallback` in `build`) and never call
  `ref.watch` inside callbacks: use `ref.read` there.
- Load data in `initState` with `Future.microtask(() => ref.read(...notifier).load())`.

### 7.7 Component Pattern
All UI pieces live in `lib/features/<feature>/presentation/component/` as self-contained widget classes:
data in through the constructor, events out through callbacks (`VoidCallback`, `ValueChanged<T>`).
Components may watch providers (`ConsumerWidget`) but never navigate to other pages on their own: they call
a callback or `context.push` with `RouterPath`.

### 7.8 Presentation Architecture Rules: Page vs Component

| Directory | Role | Allowed | Prohibited |
| --- | --- | --- | --- |
| `presentation/page/` | Screen-level orchestrator & router target | Scaffold, AppBar, top-level layout, composing Component classes, lifecycle (initState/dispose), calling controllers | ❌ `Widget _buildX(...)` helper methods<br>❌ Complex nested UI trees<br>❌ Feature-specific widgets declared inline |
| `presentation/component/` | Self-contained, modular UI building blocks | Dedicated `StatelessWidget`, `StatefulWidget`, or `ConsumerWidget` classes, one per file, ≤ ~300 lines | ❌ Monolithic screens<br>❌ Business logic or API calls |

#### Why Widget Classes Instead of Widget Functions?
1. **Rebuild Optimization**: Flutter cannot independently skip rebuilding a widget function. When `setState()` or `ref.watch()` fires in a page with widget functions, the entire tree and all function invocations run again.
2. **Clean Separation of Concerns**: Pages stay concise (< 150 lines), readable, and focused on lifecycle and coordination.
3. **Reusability & Testability**: Components can be tested in isolation with unit/widget tests and reused across different views or dialogs.

---

## 8. Routing Convention (full file: `reference/core.md`, `router_config.dart`)

### 8.1 Route Registration
1. Route constants at the top of `router_config.dart`. **Top-level routes start with `/`; sub-routes do not.**
   ```dart
   const String itemsScreen = '/itemsScreen';     // top level
   const String itemDetailScreen = 'itemDetailScreen'; // sub-route of itemsScreen
   ```
2. Add the `GoRoute` (top level) or a child `GoRoute` inside the parent's `routes:`.
3. Use `buildPageWithTransition()` for every page (`AppTransitionType`: slideFromRight (default), fade,
   slideFromBottom, slideFromLeft, scale).
4. Add the full path to `RouterPath`:
   ```dart
   static const String itemDetailScreenPath = '$itemsScreen/$itemDetailScreen';
   ```

### 8.2 Login redirect
`GoRouter(redirect: …, refreshListenable: SessionManager.instance)`: logged out → sign-in screen; logged in
and on sign-in → home. Login and logout need **no navigation code**: saving or clearing the session is
enough.

### 8.3 Navigation and data
- `context.go(RouterPath.xPath)` replaces; `context.push(RouterPath.xPath)` stacks; `context.pop()` returns.
- Pass objects with `extra` (`context.push(path, extra: item)`) and read them **safely** with
  `extraAs<Item>(state)`. It returns `null` after a deep link or app restore, and the page shows a fallback
  (`reference/feature-items.md`: `item_detail_screen.dart`). **Never `state.extra as T`.**
- Screens that can be opened from a link get an id (path or query parameter) and load the data themselves.
- Code outside widgets navigates with `rootNavigatorKey` / `goRouter`, never with GetX.

---

## 9. API Integration Convention

### 9.1 Adding a New API Endpoint
1. Add the URL to `UrlUtils` in `lib/core/config/api_config.dart`:
   ```dart
   static final String itemsUrl = '${baseUrl}items';         // fixed path
   static String itemUrl(String id) => '${baseUrl}items/$id'; // path parameter → function
   ```
2. Create the request model in `features/<feature>/model/request/` (if the call has a body).
3. Create the response model in `features/<feature>/model/response/` (JSON sample comment on top).
4. Add one repository method with `ApiRequest.send` (7.2).
5. Wire through controller → provider → screen.

### 9.2 Standard Headers
Added **once** by `AuthInterceptor` to every request: `module` (from the env file), `Authorization: Bearer
<token>` (when logged in), `Content-Type: application/json` (Dio base options). **Never write headers in a
repository.** Public calls (login, app config) opt out of the token:
```dart
client.post(UrlUtils.loginUrl, data: body.toJson(), options: Options(extra: {AuthInterceptor.skipAuth: true}))
```

### 9.3 Query parameters, uploads, downloads
- Query parameters: `dio.get(url, queryParameters: {'page': 1, 'limit': 20})`, never string concatenation.
- Uploads: build the `FormData` **inside** `call:` so a missing file becomes an error model, not a crash
  (`reference/core.md`: `GlobalRepository.uploadImage`).
- Downloads: `Options(responseType: ResponseType.bytes)`; write the file with `path_provider` (add the
  package through an approved plan).

---

## 10. State Management Rules

| Provider Type | When to Use |
| --- | --- |
| `ChangeNotifierProvider` | Controllers (business logic) |
| `StateNotifierProvider` | Data states: API responses, lists with pagination (`AsyncValue<List<T>>`) |
| `StateProvider` | Simple values (selected tab, flags, app-wide user name) |
| `AsyncValue<List<T>>` | Lists with loading / data / error |
| `.autoDispose` | Screen state that must reset when the screen closes (forms, filters, sign-in) |

- Providers are **hand-written**. Use `riverpod_generator` only if the project already uses it, never mixed
  within a feature.
- Riverpod is the only state-management library: **no GetX** (not for state, navigation, snackbars or
  widget extensions).
- Inside another provider: `ref.watch(<feature>ControllerProvider.notifier)` (7.3).
- In `build`: `ref.watch`. In callbacks: `ref.read`. Never write provider state from `build()`.
- Reading `AsyncValue` in code: `hasValue` + `requireValue` (1.1). In widgets: `asyncValue.when(...)`.
- After create, update or delete, update the list locally (`upsert`, `remove`) instead of reloading
  everything (`reference/feature-items.md`: `items_provider.dart`).

---

## 11. Error Handling Convention

1. Repositories call `ApiRequest.send`, which **never throws**. It returns a typed model, and on errors the
   `onError` model carries the message and status code.
2. `DioExceptions.fromDioError` maps every `DioExceptionType` to an `ApiErrorType` and a user-friendly
   message. It never force-unwraps (`response!`), because a response can be missing (no connection, bad
   certificate, unknown errors).
3. Success check: `response.issuccess == true`; anything else is a failure → `AppFeedback.showError(response.message ?? …)`.
4. **HTTP 401** → `AuthInterceptor` → `SessionManager.logout()` (or a token refresh when
   `SessionManager.refreshHandler` is set) → the router redirects to sign-in and `AppRoot` resets all providers.
5. **Timeouts and 5xx** → the screen shows `AppErrorView` with a retry button (lists) or a snackbar (actions).
6. Logging only through `AppLogger.d` / `LoggingInterceptor` (debug builds only). Never log tokens,
   passwords or personal data.
7. Every screen handles **loading, empty and error** states (`AppLoadingView`, `AppEmptyView`, `AppErrorView`).

---

## 12. Local Storage and Session

### SharedPreference (`reference/core.md`)
- Keys are constants in `PrefKeys`; never raw strings in calls.
- **Every method returns a `Future`, and every write is awaited** (`await SharedPreference.storeEmail(…)`).
  A write that is not awaited can still be running when the next read happens.
- **Tokens and secrets → `flutter_secure_storage`**, behind the same method names (`storeAccessToken` /
  `getAccessToken`). Everything else → SharedPreferences.
- `clearSession()` on logout removes tokens and user data, and keeps app settings (e.g. onboarding done).

### SessionManager (`reference/core.md`)
- Holds the tokens in memory for the interceptor (no global `accessToken` variable) and persists them.
- `SessionManager.init()` in `main()` before `runApp`; `saveTokens(...)` after login; `logout()` on logout or 401.
- It is a `ChangeNotifier`: the router (redirect) and `AppRoot` (provider reset) listen to it.

### Hive
- Initialized in `main.dart` via `Hive.initFlutter()`, only if the app stores structured offline data.

---

## 13. App Entry Point (`main.dart`, `reference/core.md`)

```
main() → WidgetsFlutterBinding.ensureInitialized()
       → SystemChrome (orientation, UI mode)
       → Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)   (only with Firebase)
       → ScreenUtil.ensureScreenSize()
       → Hive.initFlutter()                                                         (only with Hive)
       → SessionManager.init()                                                      (local, fast)
       → runApp(AppRoot)
       → after the first frame: AppDeviceInfo.init(), push token, remote config     (never before runApp)

AppRoot (StatefulWidget, listens to SessionManager)
  └── ProviderScope (keyed: a new key on logout resets every provider)
        └── MyApp
              └── ScreenUtilInit (designSize, minTextAdapt, splitScreenMode)
                    └── MaterialApp.router (routerConfig: goRouter, scaffoldMessengerKey)
```

---

## 14. Design System Reference

### 14.1 Colors
- All colors MUST be defined in `ColorConfig` class (`color_config.dart`).
- **Never hardcode hex colors** in widget code: always use `ColorConfig.<name>`.
- Gradients are also defined as static `Gradient` fields in `ColorConfig`.

### 14.2 Typography
- Font family is set globally via `ThemeData(fontFamily: "<FontName>")`.
- Font files are loaded from `assets/fonts/`.
- Use ScreenUtil extensions for responsive text: `14.sp`, `16.sp`, etc.

### 14.3 Spacing & Sizing
- Design size is configured in `ScreenUtilInit(designSize: Size(w, h))`.
- Use `.w` (width), `.h` (height), `.r` (radius), `.sp` (font) extensions.
- Standard card border radius: `16.r`.

### 14.4 Accessibility
- Icon-only buttons get a `tooltip` (it is also the screen-reader label).
- Tap targets are at least 48 × 48 logical pixels.
- Text must stay readable with the system text-scale setting (avoid fixed-height text containers).

---

## 15. Assets Convention

| Type | Directory | Registration in pubspec |
| --- | --- | --- |
| Icons | `assets/icons/` | `- assets/icons/` |
| Images | `assets/images/` | `- assets/images/` |
| Animations | `assets/animations/` | `- assets/animations/` |
| Fonts | `assets/fonts/` | `fonts:` section |

- Asset paths are referenced via an `AssetConfig` class or generated code; never as raw strings in widgets.
- Always register new asset directories in `pubspec.yaml` under `flutter.assets`.

---

## 16. Global Features and Global Widgets

### 16.1 Global features (`core/global/global_features/`, `reference/core.md`)
Same 5-folder structure as a feature.
- **BaseController**: every feature controller extends it. `onNotifyListeners()`, `onRefresh(ref)`,
  `getUserData(ref)`, `appConfig()`, `logout()`. Shared logic only: no widgets, no BuildContext.
- **GlobalRepository**: shared calls (`appConfig`, `uploadImage`, …) through `ApiRequest`.
- **Global providers**: app-wide user state (`nameProvider`, `emailProvider`, `avatarProvider`,
  `isPremiumUserProvider`).
- Models used by 2+ features live in `global_features/model/`.

### 16.2 Global widgets
Use these instead of building one-off versions in features. New projects start with the files in
`reference/core.md`, and the others are added when needed with the same contract.

| Widget | Contract |
|---|---|
| `GlobalAppBar` | `title`, `actions`, `showBack`; colors from ColorConfig |
| `PrimaryButton` | `text`, `onPressed`, `isLoading` (spinner, disabled while loading); height 48.h |
| `InputTextField` | `controller`, `label`, `validator`, `keyboardType`, `obscureText`, `maxLines`, `textInputAction` |
| `AppLoadingView` / `AppEmptyView` / `AppErrorView` | states for every list or screen; scrollable, so pull-to-refresh works |
| `showConfirmDialog()` | `title`, `message`, `confirmText`, `cancelText` → `Future<bool>` |
| `buildPageWithTransition()` | every `GoRoute` page; `AppTransitionType` |
| `CustomImageView` (project) | network / asset / file image with placeholder and error widget (cached for network) |
| `CommonListShimmer` (project) | loading placeholder for lists |
| `CustomBottomSheet` (project) | standard bottom sheet (rounded top, drag handle) |
| `CommonImagePicker` (project) | camera/gallery → crop → compress ≤ 1 MB → `GlobalRepository.uploadImage` |
| `CustomWidgetClickEffect` (project) | tap effect for custom tappable areas (min 48 × 48) |

Image picking, cropping, compressing and file downloads need extra packages (`image_picker`,
`image_cropper`, `flutter_image_compress`, `path_provider`, `open_filex`). Add them only through an approved
plan, and keep that logic in `BaseController` helpers or `core/global/util/`, never in widgets.

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
