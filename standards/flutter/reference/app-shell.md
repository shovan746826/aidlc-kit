# Flutter House Standard v3 · Topic: storage and session, entry point, design system, assets, global features and widgets

> Part of the Flutter house standard v3: sections 12, 13, 14, 15 and 16 in full. `../SKILL.md` lists every section
> and says when to read this file; the section numbers match it.

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
