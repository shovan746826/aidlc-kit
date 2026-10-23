# Flutter House Standard v3 · Topic: class patterns, state management and error handling

> Part of the Flutter house standard v3: sections 7, 10 and 11 in full. `../SKILL.md` lists every section
> and says when to read this file; the section numbers match it.

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
