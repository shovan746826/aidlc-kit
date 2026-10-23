# Flutter House Standard v3 · Topic: routing and API integration

> Part of the Flutter house standard v3: sections 8 and 9 in full. `../SKILL.md` lists every section
> and says when to read this file; the section numbers match it.

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
