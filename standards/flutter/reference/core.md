# Flutter House Standard v3 · Reference A: core layer, complete files (new project)

> Part of the Flutter house standard v3. The rules are in `../SKILL.md` (sections 1–24): read them first.
> Open this file only when you need its complete code. Every code block whose first line is a path comment
> (`// lib/...` or `// test/...`) is a **whole file**: create it at that path and replace `app` in
> `package:app/...` with your package name (`name:` in `pubspec.yaml`). The four reference files
> (`core.md`, `feature-items.md`, `feature-sign-in.md`, `tests.md`) compile and pass their tests together
> on flutter_riverpod 2.6.1 and 3.3.2 (`tests/flutter-standard-check.sh` in the kit).

Create these files when a project starts (work item `001-setup-project-scaffold`). Replace `app` in
`package:app/...` with your package name.

### A.0 Dependencies and environment files
```yaml
# pubspec.yaml (dependencies to add; keep the versions `flutter pub add` chooses)
dependencies:
  flutter_riverpod: ^2.6.1          # 3.x works too: see section 1.1
  go_router: ^14.8.1
  dio: ^5.9.0
  flutter_screenutil: ^5.9.3
  shared_preferences: ^2.5.3
  flutter_secure_storage: ^9.2.4
  package_info_plus: ^8.3.1
  # hive_flutter: ^1.1.0            # only for structured offline data
  # firebase_core: …                # only with Firebase (`flutterfire configure`)
```
```json
{"FLAVOR": "dev", "BASE_URL": "https://api.dev.example.com/", "APP_MODULE": "replace-me"}
```
Save the JSON as `env/dev.json` (and `env/prod.json`), add `env/*.json` to `.gitignore`, and commit a copy
with dummy values as `env/example.json`. Run with `flutter run --dart-define-from-file=env/dev.json`.

### A.1 Configuration
```dart
// lib/core/config/env.dart
/// Build-time settings from a git-ignored JSON file:
///   flutter run --dart-define-from-file=env/dev.json
/// Only this file reads them. Never hardcode URLs or keys anywhere else.
class Env {
  Env._();

  static const String flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  static const String baseUrl =
      String.fromEnvironment('BASE_URL', defaultValue: 'https://api.example.com/');
  static const String appModule = String.fromEnvironment('APP_MODULE');

  static bool get isProduction => flavor == 'prod';
}
```

```dart
// lib/core/config/api_config.dart
import 'env.dart';

/// Every API URL lives here. Path parameters are functions; query parameters go in Dio's
/// `queryParameters`, never into the URL string.
class UrlUtils {
  UrlUtils._();

  static final String baseUrl = Env.baseUrl;

  /// Auth
  static final String loginUrl = '${baseUrl}auth/login';
  static final String refreshTokenUrl = '${baseUrl}auth/refresh';

  /// Global
  static final String appConfigUrl = '${baseUrl}app-config';
  static final String imageUploadUrl = '${baseUrl}upload/image';

  /// Items (reference feature)
  static final String itemsUrl = '${baseUrl}items';
  static String itemUrl(String id) => '${baseUrl}items/$id';
}
```

```dart
// lib/core/config/app_constant_config.dart
import 'env.dart';

const String appName = 'App';

/// Value of the `module` header that identifies this app to the backend (from the env file).
/// An app-side key can be extracted from the app: the backend must not rely on it alone.
String get module => Env.appModule;
```

```dart
// lib/core/config/app_keys.dart
import 'package:flutter/material.dart';

/// Navigation and snackbars without a BuildContext (instead of GetX's Get.key / Get.context).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
```

```dart
// lib/core/config/color_config.dart
import 'package:flutter/material.dart';

/// All app colors. Widgets never use Color(0x…) directly.
class ColorConfig {
  ColorConfig._();

  static const Color primaryColor = Color(0xFF3D5AFE);
  static const Color backgroundColor = Color(0xFFF7F8FA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textColorPrimary = Color(0xFF1F2430);
  static const Color textColorSecondary = Color(0xFF6B7280);
  static const Color whiteColor = Color(0xFFFFFFFF);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color dividerColor = Color(0xFFE5E7EB);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3D5AFE), Color(0xFF00B0FF)],
  );
}
```

```dart
// lib/core/config/theme_config.dart
import 'package:flutter/material.dart';

import 'color_config.dart';

ThemeData theme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: ColorConfig.primaryColor),
    scaffoldBackgroundColor: ColorConfig.backgroundColor,
    // fontFamily: 'YourFont', // files in assets/fonts/, registered in pubspec.yaml
    appBarTheme: const AppBarTheme(
      backgroundColor: ColorConfig.primaryColor,
      foregroundColor: ColorConfig.whiteColor,
      centerTitle: false,
    ),
  );
}
```

```dart
// lib/core/config/size_config.dart
/// Screen size holders, set in MyApp's ScreenUtilInit builder.
class SizeConfig {
  SizeConfig._();

  static double screenWidth = 0;
  static double screenHeight = 0;
}
```

### A.2 Network
```dart
// lib/core/config/network/dio_client.dart
import 'package:dio/dio.dart';

import 'package:app/core/config/api_config.dart';
import 'auth_interceptor.dart';
import 'logging_interceptor.dart';

/// ONE Dio for the whole app, with base URL, timeouts and interceptors.
/// `DioClient().dio` still works and returns the same instance.
class DioClient {
  DioClient._internal() : dio = createDio();

  static final DioClient instance = DioClient._internal();

  factory DioClient() => instance;

  final Dio dio;

  static Dio createDio({String? baseUrl}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? UrlUtils.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    dio.interceptors.addAll([AuthInterceptor(dio), LoggingInterceptor()]);
    return dio;
  }
}
```

```dart
// lib/core/config/network/auth_interceptor.dart
import 'package:dio/dio.dart';

import 'package:app/core/config/app_constant_config.dart';
import 'package:app/core/global/util/session_manager.dart';

/// Adds the standard headers to every request and handles 401 (expired session) in one place.
/// Repositories never write headers. Public calls (login, app config) opt out of the token with
/// `Options(extra: {AuthInterceptor.skipAuth: true})`.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio);

  static const String skipAuth = 'skipAuth';
  static const String _retried = 'aidlcRetried';

  final Dio _dio;
  Future<String?>? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (module.isNotEmpty) options.headers['module'] = module;
    final token = SessionManager.instance.accessToken;
    if (token.isNotEmpty && options.extra[skipAuth] != true) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || options.extra[skipAuth] == true) {
      handler.next(err);
      return;
    }
    final session = SessionManager.instance;
    final refresh = session.refreshHandler;
    if (refresh != null && options.extra[_retried] != true && session.refreshToken.isNotEmpty) {
      // One refresh for all requests that fail at the same time.
      _refreshing ??= refresh(session.refreshToken).whenComplete(() => _refreshing = null);
      final newToken = await _refreshing;
      if (newToken != null && newToken.isNotEmpty) {
        await session.saveTokens(accessToken: newToken, refreshToken: session.refreshToken);
        options.extra[_retried] = true;
        try {
          handler.resolve(await _dio.fetch<dynamic>(options));
        } on DioException catch (e) {
          handler.next(e);
        }
        return;
      }
    }
    await session.logout();
    handler.next(err);
  }
}
```

```dart
// lib/core/config/network/logging_interceptor.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only HTTP log. Secrets are masked, and the real request is never changed.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({bool? enabled, this.maxLength = 1500, void Function(String message)? log})
      : enabled = enabled ?? kDebugMode,
        _log = log ?? ((message) => debugPrint(message));

  final bool enabled;
  final int maxLength;
  final void Function(String message) _log;

  static const Set<String> _secretHeaders = {
    'authorization',
    'module',
    'cookie',
    'set-cookie',
    'x-api-key',
  };
  static const Set<String> _secretFields = {
    'password',
    'token',
    'access_token',
    'refresh_token',
    'accesstoken',
    'refreshtoken',
    'otp',
    'pin',
    'secret',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      _log('→ ${options.method} ${options.uri}');
      _log('  headers: ${maskHeaders(options.headers)}');
      if (options.data != null) _log('  body: ${_shorten(maskBody(options.data))}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (enabled) {
      _log('← ${response.statusCode} ${response.requestOptions.uri}');
      _log('  body: ${_shorten(maskBody(response.data))}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      _log('✕ ${err.type.name} ${err.response?.statusCode ?? ''} ${err.requestOptions.uri}');
      final data = err.response?.data;
      if (data != null) _log('  body: ${_shorten(maskBody(data))}');
    }
    handler.next(err);
  }

  /// A masked copy of the headers. The request keeps its real headers.
  static Map<String, dynamic> maskHeaders(Map<String, dynamic> headers) => {
        for (final entry in headers.entries)
          entry.key: _secretHeaders.contains(entry.key.toLowerCase()) ? '***' : entry.value,
      };

  /// A masked copy of a JSON body. Form data shows only its field names.
  static Object? maskBody(Object? data) {
    if (data is Map) {
      return {
        for (final entry in data.entries)
          '${entry.key}':
              _secretFields.contains('${entry.key}'.toLowerCase()) ? '***' : maskBody(entry.value),
      };
    }
    if (data is List) return data.map(maskBody).toList();
    if (data is FormData) {
      return 'FormData(fields: ${data.fields.map((field) => field.key).toList()}, '
          'files: ${data.files.length})';
    }
    return data;
  }

  String _shorten(Object? data) {
    String text;
    try {
      text = data is String ? data : jsonEncode(data);
    } catch (_) {
      text = '$data';
    }
    return text.length <= maxLength ? text : '${text.substring(0, maxLength)}… (${text.length} chars)';
  }
}
```

```dart
// lib/core/config/network/dio_exceptions.dart
import 'dart:io';

import 'package:dio/dio.dart';

enum ApiErrorType {
  cancelled,
  timeout,
  noConnection,
  badCertificate,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  server,
  unknown,
}

/// Turns any DioException into an [ApiErrorType] and a user-friendly message.
/// Never throws: the response is often missing (no connection, bad certificate, unknown errors).
class DioExceptions implements Exception {
  DioExceptions.fromDioError(DioException error) : statusCode = error.response?.statusCode {
    final serverMessage = _serverMessage(error.response?.data);
    final kind = error.type;
    if (kind == DioExceptionType.cancel) {
      type = ApiErrorType.cancelled;
      message = 'The request was cancelled.';
    } else if (kind == DioExceptionType.connectionTimeout ||
        kind == DioExceptionType.sendTimeout ||
        kind == DioExceptionType.receiveTimeout ||
        kind.name == 'transformTimeout') {
      // transformTimeout exists from dio 5.10; compared by name so dio 5.9 compiles too.
      type = ApiErrorType.timeout;
      message = 'The server took too long to respond. Please try again.';
    } else if (kind == DioExceptionType.connectionError) {
      type = ApiErrorType.noConnection;
      message = _noConnection;
    } else if (kind == DioExceptionType.badCertificate) {
      type = ApiErrorType.badCertificate;
      message = 'A secure connection to the server could not be made.';
    } else if (kind == DioExceptionType.badResponse) {
      type = _typeForStatus(statusCode);
      message = serverMessage ?? _messageForStatus(statusCode);
    } else {
      final offline = error.error is SocketException;
      type = offline ? ApiErrorType.noConnection : ApiErrorType.unknown;
      message = offline ? _noConnection : (serverMessage ?? _somethingWentWrong);
    }
  }

  static const String _noConnection = 'No internet connection. Please check your network.';
  static const String _somethingWentWrong = 'Something went wrong. Please try again.';

  final int? statusCode;
  late final ApiErrorType type;
  late final String message;

  static String? _serverMessage(Object? data) {
    if (data is Map) {
      final value = data['message'];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  static ApiErrorType _typeForStatus(int? code) => switch (code) {
        401 => ApiErrorType.unauthorized,
        403 => ApiErrorType.forbidden,
        404 => ApiErrorType.notFound,
        final int c when c >= 500 => ApiErrorType.server,
        final int c when c >= 400 => ApiErrorType.badRequest,
        _ => ApiErrorType.unknown,
      };

  static String _messageForStatus(int? code) => switch (_typeForStatus(code)) {
        ApiErrorType.unauthorized => 'Your session has expired. Please sign in again.',
        ApiErrorType.forbidden => 'You do not have permission to do this.',
        ApiErrorType.notFound => 'This was not found.',
        ApiErrorType.server => 'The server has a problem. Please try again later.',
        ApiErrorType.badRequest => 'The request could not be completed. Please check the data.',
        _ => _somethingWentWrong,
      };

  @override
  String toString() => message;
}
```

```dart
// lib/core/config/network/api_request.dart
import 'package:dio/dio.dart';

import 'package:app/core/global/util/app_logger.dart';
import 'dio_client.dart';
import 'dio_exceptions.dart';

/// Runs one API call and ALWAYS returns a typed model: it never throws to the caller.
/// Repositories use it instead of writing try/catch (and headers) in every method.
class ApiRequest {
  ApiRequest._();

  static Future<T> send<T>({
    required Future<Response<dynamic>> Function(Dio dio) call,
    required T Function(dynamic json) fromJson,
    required T Function(String message, int? statusCode) onError,
    Dio? dio,
  }) async {
    try {
      final response = await call(dio ?? DioClient.instance.dio);
      return fromJson(response.data);
    } on DioException catch (e) {
      final error = DioExceptions.fromDioError(e);
      AppLogger.d('API ${error.type.name}: ${error.message}');
      return onError(error.message, error.statusCode);
    } catch (e) {
      AppLogger.d('API response could not be read: $e');
      return onError('Unexpected response from the server.', null);
    }
  }
}
```

### A.3 Storage, session, feedback, utilities
```dart
// lib/core/global/util/shared_preferences.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage keys in one place: never raw strings in calls.
class PrefKeys {
  PrefKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String fullName = 'full_name';
  static const String email = 'email';
  static const String isOnboardingDone = 'is_onboarding_done';
}

/// Typed storage. Every method returns a Future: always `await` writes.
/// Tokens and secrets → secure storage; everything else → SharedPreferences.
class SharedPreference {
  SharedPreference._();

  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  // Sensitive values (secure storage)
  static Future<void> storeAccessToken(String value) =>
      _secure.write(key: PrefKeys.accessToken, value: value);

  static Future<String> getAccessToken() async =>
      await _secure.read(key: PrefKeys.accessToken) ?? '';

  static Future<void> storeRefreshToken(String value) =>
      _secure.write(key: PrefKeys.refreshToken, value: value);

  static Future<String> getRefreshToken() async =>
      await _secure.read(key: PrefKeys.refreshToken) ?? '';

  // Other values (SharedPreferences)
  static Future<void> storeFullName(String value) => _setString(PrefKeys.fullName, value);

  static Future<String> getFullName() => _getString(PrefKeys.fullName);

  static Future<void> storeEmail(String value) => _setString(PrefKeys.email, value);

  static Future<String> getEmail() => _getString(PrefKeys.email);

  static Future<void> storeIsOnboardingDone(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.isOnboardingDone, value);
  }

  static Future<bool> getIsOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PrefKeys.isOnboardingDone) ?? false;
  }

  /// Logout: removes tokens and user data, keeps app settings (e.g. onboarding done).
  static Future<void> clearSession() async {
    await _secure.delete(key: PrefKeys.accessToken);
    await _secure.delete(key: PrefKeys.refreshToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefKeys.fullName);
    await prefs.remove(PrefKeys.email);
  }

  static Future<void> _setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String> _getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? '';
  }
}
```

```dart
// lib/core/global/util/session_manager.dart
import 'package:flutter/foundation.dart';

import 'shared_preferences.dart';

/// The login session: tokens in memory (for the interceptor) and in secure storage (persistent).
/// It is a ChangeNotifier: the router redirects and AppRoot resets providers when it changes.
class SessionManager extends ChangeNotifier {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  String _accessToken = '';
  String _refreshToken = '';

  String get accessToken => _accessToken;
  String get refreshToken => _refreshToken;
  bool get isLoggedIn => _accessToken.isNotEmpty;

  /// Optional: set it (e.g. in main.dart) when the backend supports refresh tokens.
  /// Return the new access token, or null to log out.
  Future<String?> Function(String refreshToken)? refreshHandler;

  /// Loads the saved session. Call once in main() before runApp().
  static Future<void> init() async {
    instance._accessToken = await SharedPreference.getAccessToken();
    instance._refreshToken = await SharedPreference.getRefreshToken();
  }

  Future<void> saveTokens({required String accessToken, String refreshToken = ''}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await SharedPreference.storeAccessToken(accessToken);
    await SharedPreference.storeRefreshToken(refreshToken);
    notifyListeners();
  }

  Future<void> logout() async {
    final wasLoggedIn = isLoggedIn;
    _accessToken = '';
    _refreshToken = '';
    await SharedPreference.clearSession();
    if (wasLoggedIn) notifyListeners();
  }
}
```

```dart
// lib/core/global/util/app_feedback.dart
import 'package:flutter/material.dart';

import 'package:app/core/config/app_keys.dart';
import 'package:app/core/config/color_config.dart';

/// Snackbars and the loading dialog without a BuildContext (usable from controllers).
class AppFeedback {
  AppFeedback._();

  static bool _loadingVisible = false;

  static void showError(String message) => _showSnackBar(message, ColorConfig.errorColor);

  static void showSuccess(String message) => _showSnackBar(message, ColorConfig.successColor);

  static void _showSnackBar(String message, Color color) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
      );
  }

  static void showLoading() {
    final context = rootNavigatorKey.currentContext;
    if (context == null || _loadingVisible) return;
    _loadingVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  static void hideLoading() {
    if (!_loadingVisible) return;
    _loadingVisible = false;
    rootNavigatorKey.currentState?.pop();
  }

  /// Shows the loading dialog while [task] runs and always hides it, even on errors.
  static Future<T> withLoading<T>(Future<T> Function() task) async {
    showLoading();
    try {
      return await task();
    } finally {
      hideLoading();
    }
  }
}
```

```dart
// lib/core/global/util/app_logger.dart
import 'package:flutter/foundation.dart';

/// Debug-only logging. Never log tokens, passwords or personal data.
class AppLogger {
  AppLogger._();

  static void d(String message) {
    if (kDebugMode) debugPrint(message);
  }
}
```

```dart
// lib/core/global/util/app_device_info.dart
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// App and device facts for API calls (app config, analytics).
/// init() runs after the first frame (main.dart): it never delays the app start.
class AppDeviceInfo {
  AppDeviceInfo._();

  static String appVersion = '';
  static String buildNumber = '';
  static String platform = Platform.isIOS
      ? 'ios'
      : Platform.isAndroid
          ? 'android'
          : Platform.operatingSystem;
  static String osVersion = Platform.operatingSystemVersion;

  static Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    appVersion = info.version;
    buildNumber = info.buildNumber;
    // Device model or id: add device_info_plus only if the backend needs them.
    // Push token: ask for permission and get the token here, never before runApp().
  }
}
```

```dart
// lib/core/global/util/global_validation.dart
/// Form validators: null when valid, otherwise the message to show.
String? isValidEmail(String? email) {
  final value = email?.trim() ?? '';
  return RegExp(r'^[\w.%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(value)
      ? null
      : 'Please enter a valid email address';
}

String? isValidPassword(String? password, {int minLength = 6}) {
  return (password ?? '').length >= minLength
      ? null
      : 'Password must be at least $minLength characters';
}

String? isValidName(String? name) {
  return (name?.trim().length ?? 0) >= 2 ? null : 'Please enter a valid name';
}

String? isValidPhoneNumber(String? number) {
  return RegExp(r'^\+?[0-9]{9,15}$').hasMatch(number?.trim() ?? '')
      ? null
      : 'Please enter a valid phone number';
}

String? isValidOTP(String? otp, {int length = 6}) {
  return RegExp('^[0-9]{$length}\$').hasMatch(otp ?? '')
      ? null
      : 'Please enter the $length-digit code';
}

String? isRequired(String? value, {String field = 'This field'}) {
  return (value?.trim().isNotEmpty ?? false) ? null : '$field is required';
}
```

### A.4 Global widgets
```dart
// lib/core/global/widgets/custom_transition_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum AppTransitionType { fade, slideFromRight, slideFromLeft, slideFromBottom, scale }

CustomTransitionPage<T> buildPageWithTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  int durationMilliseconds = 350,
  AppTransitionType transitionType = AppTransitionType.slideFromRight,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration(milliseconds: durationMilliseconds),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      switch (transitionType) {
        case AppTransitionType.fade:
          return FadeTransition(opacity: animation, child: child);
        case AppTransitionType.slideFromLeft:
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(animation),
            child: child,
          );
        case AppTransitionType.slideFromBottom:
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
            child: child,
          );
        case AppTransitionType.scale:
          return ScaleTransition(scale: animation, child: child);
        case AppTransitionType.slideFromRight:
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
            child: child,
          );
      }
    },
  );
}
```

```dart
// lib/core/global/widgets/custom_appbar.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:app/core/config/color_config.dart';

/// The app bar used by every page.
class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlobalAppBar({super.key, required this.title, this.actions, this.showBack = true});

  final String title;
  final List<Widget>? actions;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBack,
      backgroundColor: ColorConfig.primaryColor,
      foregroundColor: ColorConfig.whiteColor,
      title: Text(title, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
      actions: actions,
    );
  }
}
```

```dart
// lib/core/global/widgets/primary_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:app/core/config/color_config.dart';

/// The main action button. Shows a spinner and is disabled while [isLoading].
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.text, required this.onPressed, this.isLoading = false});

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: ColorConfig.primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 20.r,
                height: 20.r,
                child: const CircularProgressIndicator(strokeWidth: 2, color: ColorConfig.whiteColor),
              )
            : Text(text, style: TextStyle(fontSize: 16.sp, color: ColorConfig.whiteColor)),
      ),
    );
  }
}
```

```dart
// lib/core/global/widgets/input_text_field.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The standard text field for forms.
class InputTextField extends StatelessWidget {
  const InputTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLines: obscureText ? 1 : maxLines,
        textInputAction: textInputAction,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      ),
    );
  }
}
```

```dart
// lib/core/global/widgets/app_state_views.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:app/core/config/color_config.dart';

/// Loading state for lists and screens.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

/// Empty state. Scrollable, so pull-to-refresh still works.
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _ScrollableCenter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48.r, color: ColorConfig.textColorSecondary),
          SizedBox(height: 12.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15.sp, color: ColorConfig.textColorSecondary),
          ),
        ],
      ),
    );
  }
}

/// Error state with an optional retry button. Scrollable, so pull-to-refresh still works.
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.message, this.onRetry, this.retryText = 'Try again'});

  final String message;
  final VoidCallback? onRetry;
  final String retryText;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
    return _ScrollableCenter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48.r, color: ColorConfig.errorColor),
          SizedBox(height: 12.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15.sp, color: ColorConfig.textColorPrimary),
          ),
          if (retry != null) ...[
            SizedBox(height: 16.h),
            OutlinedButton(onPressed: retry, child: Text(retryText)),
          ],
        ],
      ),
    );
  }
}

/// Centers [child] and stays scrollable (needed inside RefreshIndicator).
class _ScrollableCenter extends StatelessWidget {
  const _ScrollableCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: Padding(padding: EdgeInsets.all(24.r), child: child)),
        ),
      ),
    );
  }
}
```

```dart
// lib/core/global/widgets/confirm_dialog.dart
import 'package:flutter/material.dart';

import 'package:app/core/config/color_config.dart';

/// Asks the user to confirm (e.g. before deleting). Returns true only when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Delete',
  String cancelText = 'Cancel',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(cancelText)),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmText, style: const TextStyle(color: ColorConfig.errorColor)),
        ),
      ],
    ),
  );
  return result ?? false;
}
```

### A.5 Global features
```dart
// lib/core/global/global_features/model/response/basic_response_model.dart
/// issuccess : true
/// statusCode : 200
/// message : "The request has succeeded"
/// payload : true
class BasicResponseModel {
  BasicResponseModel({this.issuccess, this.statusCode, this.message, this.payload});

  BasicResponseModel.fromJson(Map<String, dynamic> json) {
    issuccess = json['issuccess'];
    statusCode = (json['statusCode'] as num?)?.toInt();
    message = json['message'];
    payload = json['payload'];
  }

  bool? issuccess;
  int? statusCode;
  String? message;
  dynamic payload;

  Map<String, dynamic> toJson() => {
        'issuccess': issuccess,
        'statusCode': statusCode,
        'message': message,
        'payload': payload,
      };
}
```

```dart
// lib/core/global/global_features/model/request/app_config_request_model.dart
/// version : "1.2.0"
/// platform : "android"
class AppConfigRequestModel {
  AppConfigRequestModel({this.version, this.platform});

  String? version;
  String? platform;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (version != null) data['version'] = version;
    if (platform != null) data['platform'] = platform;
    return data;
  }
}
```

```dart
// lib/core/global/global_features/model/response/app_config_response_model.dart
/// issuccess : true
/// statusCode : 200
/// message : "OK"
/// payload : {"latestVersion": "1.3.0", "forceUpdate": false, "maintenance": false}
class AppConfigResponseModel {
  AppConfigResponseModel({this.issuccess, this.statusCode, this.message, this.payload});

  AppConfigResponseModel.fromJson(Map<String, dynamic> json) {
    issuccess = json['issuccess'];
    statusCode = (json['statusCode'] as num?)?.toInt();
    message = json['message'];
    payload = json['payload'] != null ? AppConfigPayload.fromJson(json['payload']) : null;
  }

  bool? issuccess;
  int? statusCode;
  String? message;
  AppConfigPayload? payload;
}

class AppConfigPayload {
  AppConfigPayload({this.latestVersion, this.forceUpdate, this.maintenance});

  AppConfigPayload.fromJson(Map<String, dynamic> json) {
    latestVersion = json['latestVersion'];
    forceUpdate = json['forceUpdate'];
    maintenance = json['maintenance'];
  }

  String? latestVersion;
  bool? forceUpdate;
  bool? maintenance;
}
```

```dart
// lib/core/global/global_features/model/response/image_upload_response_model.dart
/// issuccess : true
/// statusCode : 200
/// message : "Uploaded"
/// payload : {"url": "https://cdn.example.com/images/abc.jpg"}
class ImageUploadResponseModel {
  ImageUploadResponseModel({this.issuccess, this.statusCode, this.message, this.url});

  ImageUploadResponseModel.fromJson(Map<String, dynamic> json) {
    issuccess = json['issuccess'];
    statusCode = (json['statusCode'] as num?)?.toInt();
    message = json['message'];
    final payload = json['payload'];
    url = payload is Map ? payload['url'] as String? : null;
  }

  bool? issuccess;
  int? statusCode;
  String? message;
  String? url;
}
```

```dart
// lib/core/global/global_features/repository/repository.dart
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:app/core/config/api_config.dart';
import 'package:app/core/config/network/api_request.dart';
import 'package:app/core/config/network/auth_interceptor.dart';
import '../model/request/app_config_request_model.dart';
import '../model/response/app_config_response_model.dart';
import '../model/response/image_upload_response_model.dart';

/// API calls shared by several features.
class GlobalRepository {
  /// [dio] is only passed in tests (a Dio with a fake adapter).
  GlobalRepository({this.dio});

  final Dio? dio;

  Future<AppConfigResponseModel> appConfig(AppConfigRequestModel body) => ApiRequest.send(
        dio: dio,
        call: (client) => client.post(
          UrlUtils.appConfigUrl,
          data: body.toJson(),
          options: Options(extra: {AuthInterceptor.skipAuth: true}),
        ),
        fromJson: (json) => AppConfigResponseModel.fromJson(json as Map<String, dynamic>),
        onError: (message, statusCode) =>
            AppConfigResponseModel(message: message, statusCode: statusCode),
      );

  /// Multipart upload. The FormData is built inside `call` so a missing file becomes an error model.
  Future<ImageUploadResponseModel> uploadImage(File file) => ApiRequest.send(
        dio: dio,
        call: (client) async {
          final fileName = file.path.split('/').last;
          final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpeg';
          final data = FormData.fromMap({
            'image': await MultipartFile.fromFile(
              file.path,
              filename: fileName,
              contentType: DioMediaType('image', extension == 'jpg' ? 'jpeg' : extension),
            ),
          });
          return client.post(UrlUtils.imageUploadUrl, data: data);
        },
        fromJson: (json) => ImageUploadResponseModel.fromJson(json as Map<String, dynamic>),
        onError: (message, statusCode) =>
            ImageUploadResponseModel(message: message, statusCode: statusCode),
      );
}
```

```dart
// lib/core/global/global_features/provider/provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_riverpod/legacy.dart'; // flutter_riverpod 3.x: uncomment

/// App-wide user state (filled by BaseController.getUserData).
final nameProvider = StateProvider<String>((ref) => '');
final emailProvider = StateProvider<String>((ref) => '');
final avatarProvider = StateProvider<String>((ref) => '');
final isPremiumUserProvider = StateProvider<bool>((ref) => false);
```

```dart
// lib/core/global/global_features/controller/base_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/global/util/app_device_info.dart';
import 'package:app/core/global/util/session_manager.dart';
import 'package:app/core/global/util/shared_preferences.dart';
import '../model/request/app_config_request_model.dart';
import '../model/response/app_config_response_model.dart';
import '../provider/provider.dart';
import '../repository/repository.dart';

/// Base class for every feature controller: shared logic only. No widgets, no BuildContext.
class BaseController extends ChangeNotifier {
  BaseController({GlobalRepository? globalRepository})
      : globalRepository = globalRepository ?? GlobalRepository();

  final GlobalRepository globalRepository;

  void onNotifyListeners() => notifyListeners();

  /// Override for pull-to-refresh.
  Future<void> onRefresh(WidgetRef ref) async {}

  /// Loads the stored user into the global providers.
  Future<void> getUserData(WidgetRef ref) async {
    final name = await SharedPreference.getFullName();
    final email = await SharedPreference.getEmail();
    if (!ref.context.mounted) return;
    ref.read(nameProvider.notifier).state = name;
    ref.read(emailProvider.notifier).state = email;
  }

  Future<AppConfigResponseModel> appConfig() => globalRepository.appConfig(
        AppConfigRequestModel(version: AppDeviceInfo.appVersion, platform: AppDeviceInfo.platform),
      );

  /// Clears the session; the router goes to sign-in and AppRoot resets all providers.
  Future<void> logout() => SessionManager.instance.logout();
}
```

### A.6 Router and entry point
```dart
// lib/core/config/router_config.dart
import 'package:go_router/go_router.dart';

import 'package:app/core/config/app_keys.dart';
import 'package:app/core/global/util/session_manager.dart';
import 'package:app/core/global/widgets/custom_transition_page.dart';
import 'package:app/features/items/model/response/item_list_response_model.dart';
import 'package:app/features/items/presentation/page/item_detail_screen.dart';
import 'package:app/features/items/presentation/page/item_form_screen.dart';
import 'package:app/features/items/presentation/page/items_screen.dart';
import 'package:app/features/sign_in/presentation/page/sign_in_screen.dart';

// Top-level routes start with '/'. Sub-routes do not (RouterPath builds the full path).
const String signInScreen = '/signInScreen';
const String itemsScreen = '/itemsScreen';
const String itemDetailScreen = 'itemDetailScreen';
const String itemFormScreen = 'itemFormScreen';

final GoRouter goRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: itemsScreen,
  refreshListenable: SessionManager.instance,
  redirect: (context, state) {
    final loggedIn = SessionManager.instance.isLoggedIn;
    final onSignIn = state.matchedLocation == signInScreen;
    if (!loggedIn) return onSignIn ? null : signInScreen;
    if (onSignIn) return itemsScreen;
    return null;
  },
  routes: [
    GoRoute(
      path: signInScreen,
      pageBuilder: (context, state) => buildPageWithTransition(
        context: context,
        state: state,
        transitionType: AppTransitionType.fade,
        child: const SignInScreen(),
      ),
    ),
    GoRoute(
      path: itemsScreen,
      pageBuilder: (context, state) => buildPageWithTransition(
        context: context,
        state: state,
        child: const ItemsScreen(),
      ),
      routes: [
        GoRoute(
          path: itemDetailScreen,
          pageBuilder: (context, state) => buildPageWithTransition(
            context: context,
            state: state,
            child: ItemDetailScreen(item: extraAs<Item>(state)),
          ),
        ),
        GoRoute(
          path: itemFormScreen,
          pageBuilder: (context, state) => buildPageWithTransition(
            context: context,
            state: state,
            transitionType: AppTransitionType.slideFromBottom,
            child: ItemFormScreen(item: extraAs<Item>(state)),
          ),
        ),
      ],
    ),
  ],
);

/// Safe access to GoRouterState.extra: null when it is missing (deep link, app restore) or another type.
T? extraAs<T>(GoRouterState state) {
  final extra = state.extra;
  return extra is T ? extra : null;
}

class RouterPath {
  RouterPath._();

  static const String signInScreenPath = signInScreen;
  static const String itemsScreenPath = itemsScreen;
  static const String itemDetailScreenPath = '$itemsScreen/$itemDetailScreen';
  static const String itemFormScreenPath = '$itemsScreen/$itemFormScreen';
}
```

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:app/core/config/app_constant_config.dart';
import 'package:app/core/config/app_keys.dart';
import 'package:app/core/config/router_config.dart';
import 'package:app/core/config/size_config.dart';
import 'package:app/core/config/theme_config.dart';
import 'package:app/core/global/util/app_device_info.dart';
import 'package:app/core/global/util/session_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Firebase, only if used (run `flutterfire configure` first):
  //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Hive, only if used:
  //   await Hive.initFlutter();
  await ScreenUtil.ensureScreenSize();
  await SessionManager.init();
  runApp(const AppRoot());
  // Slow work never delays the first frame.
  WidgetsBinding.instance.addPostFrameCallback((_) => AppDeviceInfo.init());
}

/// Holds the ProviderScope and gives it a new key on logout, which resets every provider.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  Key _providerKey = UniqueKey();
  bool _wasLoggedIn = SessionManager.instance.isLoggedIn;

  @override
  void initState() {
    super.initState();
    SessionManager.instance.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    SessionManager.instance.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    final loggedIn = SessionManager.instance.isLoggedIn;
    if (_wasLoggedIn && !loggedIn) restartProviders();
    _wasLoggedIn = loggedIn;
  }

  void restartProviders() => setState(() => _providerKey = UniqueKey());

  @override
  Widget build(BuildContext context) {
    return ProviderScope(key: _providerKey, child: const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        SizeConfig.screenWidth = MediaQuery.sizeOf(context).width;
        SizeConfig.screenHeight = MediaQuery.sizeOf(context).height;
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: appName,
          theme: theme(),
          routerConfig: goRouter,
          scaffoldMessengerKey: scaffoldMessengerKey,
        );
      },
    );
  }
}
```
