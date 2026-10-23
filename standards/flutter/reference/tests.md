# Flutter House Standard v3 · Reference D: tests, complete files

> Part of the Flutter house standard v3. The rules are in `../SKILL.md` (sections 1–24): read them first.
> Open this file only when you need its complete code. Every code block whose first line is a path comment
> (`// lib/...` or `// test/...`) is a **whole file**: create it at that path and replace `app` in
> `package:app/...` with your package name (`name:` in `pubspec.yaml`). The four reference files
> (`core.md`, `feature-items.md`, `feature-sign-in.md`, `tests.md`) compile and pass their tests together
> on flutter_riverpod 2.6.1 and 3.3.2 (`tests/flutter-standard-check.sh` in the kit).

No network and no plugins: Dio uses `FakeAdapter`, storage uses the packages' test mocks.

### D.1 Test helpers
```dart
// test/helpers/test_helpers.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_riverpod/misc.dart'; // flutter_riverpod 3.x: uncomment (Override type)
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/global/util/session_manager.dart';

/// Wraps a widget for tests: Riverpod + ScreenUtil + MaterialApp (ScreenUtil needs ScreenUtilInit).
Widget wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(home: child),
    ),
  );
}

/// Answers every Dio request with [handler]: no real network.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A JSON response for [FakeAdapter].
ResponseBody jsonBody(Object? data, {int statusCode = 200}) => ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// A Dio that only talks to [adapter] (repository tests).
Dio fakeDio(FakeAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.test/'))..httpClientAdapter = adapter;

/// Empty storage and a logged-out session before each test.
Future<void> resetStorageAndSession() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  SessionManager.instance.refreshHandler = null;
  await SessionManager.instance.logout();
}
```

```dart
// test/helpers/fake_items_repository.dart
import 'package:app/core/global/global_features/model/response/basic_response_model.dart';
import 'package:app/features/items/model/request/item_request_model.dart';
import 'package:app/features/items/model/response/item_list_response_model.dart';
import 'package:app/features/items/model/response/item_response_model.dart';
import 'package:app/features/items/repository/items_repository.dart';

/// In-memory items: [total] items served in pages of the requested size.
class FakeItemsRepository extends ItemsRepository {
  FakeItemsRepository({this.total = 25, this.fail = false});

  final int total;
  bool fail;
  int deleteCalls = 0;

  @override
  Future<ItemListResponseModel> getItems({required int page, int limit = 20}) async {
    if (fail) return ItemListResponseModel(message: 'No internet connection');
    final start = (page - 1) * limit;
    final end = start + limit > total ? total : start + limit;
    final items = [for (var i = start; i < end; i++) Item(id: '${i + 1}', title: 'Item ${i + 1}')];
    return ItemListResponseModel(
      issuccess: true,
      payload: ItemListPayload(items: items, page: page, limit: limit, total: total),
    );
  }

  @override
  Future<ItemResponseModel> createItem(ItemRequestModel body) async => fail
      ? ItemResponseModel(message: 'Title already used')
      : ItemResponseModel(
          issuccess: true,
          message: 'Saved',
          payload: Item(id: 'new', title: body.title, description: body.description),
        );

  @override
  Future<ItemResponseModel> updateItem(String id, ItemRequestModel body) async => ItemResponseModel(
        issuccess: true,
        payload: Item(id: id, title: body.title, description: body.description),
      );

  @override
  Future<BasicResponseModel> deleteItem(String id) async {
    deleteCalls++;
    return BasicResponseModel(issuccess: !fail, message: fail ? 'Not allowed' : 'Deleted');
  }
}
```

### D.2 Network core
```dart
// test/core/network/api_request_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/items/repository/items_repository.dart';
import '../../helpers/test_helpers.dart';

void main() {
  test('success: returns the parsed model and sends query parameters', () async {
    final adapter = FakeAdapter((options) => jsonBody({
          'issuccess': true,
          'statusCode': 200,
          'message': 'OK',
          'payload': {
            'items': [
              {'id': 1, 'title': 'A'},
            ],
            'page': 1,
            'limit': 20,
            'total': 1,
          },
        }));
    final result = await ItemsRepository(dio: fakeDio(adapter)).getItems(page: 1);
    expect(result.issuccess, isTrue);
    expect(result.payload?.items?.single.id, '1');
    expect(adapter.requests.single.queryParameters, {'page': 1, 'limit': 20});
  });

  test('server error: keeps the server message and the status code', () async {
    final adapter = FakeAdapter((options) => jsonBody({'message': 'Title already used'}, statusCode: 422));
    final result = await ItemsRepository(dio: fakeDio(adapter)).getItem('7');
    expect(result.issuccess, isNull);
    expect(result.message, 'Title already used');
    expect(result.statusCode, 422);
  });

  test('no connection (no response at all): returns an error model, never throws', () async {
    final adapter = FakeAdapter(
      (options) => throw DioException.connectionError(requestOptions: options, reason: 'offline'),
    );
    final result = await ItemsRepository(dio: fakeDio(adapter)).deleteItem('7');
    expect(result.issuccess, isNull);
    expect(result.message, contains('No internet'));
  });

  test('unexpected JSON shape: returns an error model, never throws', () async {
    final adapter = FakeAdapter((options) => jsonBody(['not', 'an', 'object']));
    final result = await ItemsRepository(dio: fakeDio(adapter)).getItems(page: 1);
    expect(result.issuccess, isNull);
    expect(result.message, 'Unexpected response from the server.');
  });
}
```

```dart
// test/core/network/auth_interceptor_test.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/config/network/auth_interceptor.dart';
import 'package:app/core/config/network/dio_client.dart';
import 'package:app/core/global/util/session_manager.dart';
import '../../helpers/test_helpers.dart';

void main() {
  setUp(() async {
    debugPrint = (String? message, {int? wrapWidth}) {}; // keep test output quiet
    await resetStorageAndSession();
  });

  Dio clientWith(FakeAdapter adapter) =>
      DioClient.createDio(baseUrl: 'https://api.test/')..httpClientAdapter = adapter;

  test('adds the bearer token when logged in', () async {
    await SessionManager.instance.saveTokens(accessToken: 'token-1');
    final adapter = FakeAdapter((options) => jsonBody({'issuccess': true}));
    await clientWith(adapter).get('items');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer token-1');
  });

  test('skipAuth requests are sent without a token', () async {
    await SessionManager.instance.saveTokens(accessToken: 'token-1');
    final adapter = FakeAdapter((options) => jsonBody({'issuccess': true}));
    await clientWith(adapter).post(
      'auth/login',
      options: Options(extra: {AuthInterceptor.skipAuth: true}),
    );
    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('401 without a refresh handler logs out', () async {
    await SessionManager.instance.saveTokens(accessToken: 'expired');
    final adapter = FakeAdapter((options) => jsonBody({'message': 'Unauthorized'}, statusCode: 401));
    await expectLater(clientWith(adapter).get('items'), throwsA(isA<DioException>()));
    expect(SessionManager.instance.isLoggedIn, isFalse);
  });

  test('401 with a refresh handler refreshes once and retries with the new token', () async {
    await SessionManager.instance.saveTokens(accessToken: 'old', refreshToken: 'refresh-1');
    var refreshCalls = 0;
    SessionManager.instance.refreshHandler = (refreshToken) async {
      refreshCalls++;
      return 'new';
    };
    final adapter = FakeAdapter((options) => options.headers['Authorization'] == 'Bearer new'
        ? jsonBody({'issuccess': true})
        : jsonBody({'message': 'Unauthorized'}, statusCode: 401));
    final response = await clientWith(adapter).get('items');
    expect(response.statusCode, 200);
    expect(refreshCalls, 1);
    expect(adapter.requests.last.headers['Authorization'], 'Bearer new');
    expect(SessionManager.instance.accessToken, 'new');
  });
}
```

```dart
// test/core/network/logging_interceptor_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/config/network/logging_interceptor.dart';
import '../../helpers/test_helpers.dart';

void main() {
  test('masks secrets in the log and never changes the real request', () async {
    final logs = <String>[];
    final adapter = FakeAdapter((options) => jsonBody({'issuccess': true, 'accessToken': 'abc123'}));
    final dio = fakeDio(adapter)..interceptors.add(LoggingInterceptor(enabled: true, log: logs.add));
    await dio.post(
      'auth/login',
      data: {'email': 'jane@example.com', 'password': 'hunter2'},
      options: Options(headers: {'Authorization': 'Bearer secret-token'}),
    );
    final log = logs.join('\n');
    expect(log, isNot(contains('hunter2')));
    expect(log, isNot(contains('secret-token')));
    expect(log, isNot(contains('abc123')));
    expect(log, contains('jane@example.com'));
    final sent = adapter.requests.single;
    expect(sent.headers['Authorization'], 'Bearer secret-token');
    expect(sent.headers.containsKey('followRedirects'), isFalse);
    expect(sent.data, {'email': 'jane@example.com', 'password': 'hunter2'});
  });

  test('a disabled logger prints nothing', () async {
    final logs = <String>[];
    final dio = fakeDio(FakeAdapter((options) => jsonBody({'issuccess': true})))
      ..interceptors.add(LoggingInterceptor(enabled: false, log: logs.add));
    await dio.get('items');
    expect(logs, isEmpty);
  });
}
```

```dart
// test/core/network/dio_exceptions_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/config/network/dio_exceptions.dart';

void main() {
  final options = RequestOptions(path: '/items');

  test('unknown error without a response does not throw', () {
    final error = DioExceptions.fromDioError(DioException(requestOptions: options));
    expect(error.type, ApiErrorType.unknown);
    expect(error.statusCode, isNull);
  });

  test('bad certificate without a response does not throw', () {
    final error = DioExceptions.fromDioError(DioException.badCertificate(requestOptions: options));
    expect(error.type, ApiErrorType.badCertificate);
  });

  test('bad response uses the server message', () {
    final error = DioExceptions.fromDioError(DioException.badResponse(
      statusCode: 422,
      requestOptions: options,
      response: Response(requestOptions: options, statusCode: 422, data: {'message': 'Title already used'}),
    ));
    expect(error.type, ApiErrorType.badRequest);
    expect(error.message, 'Title already used');
  });

  test('401 without a server message explains the session', () {
    final error = DioExceptions.fromDioError(DioException.badResponse(
      statusCode: 401,
      requestOptions: options,
      response: Response(requestOptions: options, statusCode: 401),
    ));
    expect(error.type, ApiErrorType.unauthorized);
    expect(error.message, contains('session'));
  });
}
```

### D.3 Session, validation, router
```dart
// test/core/global/session_manager_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/global/util/session_manager.dart';
import 'package:app/core/global/util/shared_preferences.dart';
import '../../helpers/test_helpers.dart';

void main() {
  setUp(resetStorageAndSession);

  test('saveTokens keeps the tokens in memory and in secure storage, and notifies', () async {
    var notified = 0;
    void listener() => notified++;
    SessionManager.instance.addListener(listener);
    await SessionManager.instance.saveTokens(accessToken: 'a1', refreshToken: 'r1');
    SessionManager.instance.removeListener(listener);
    expect(SessionManager.instance.isLoggedIn, isTrue);
    expect(await SharedPreference.getAccessToken(), 'a1');
    expect(await SharedPreference.getRefreshToken(), 'r1');
    expect(notified, 1);
  });

  test('init loads the saved session', () async {
    await SharedPreference.storeAccessToken('saved');
    await SessionManager.init();
    expect(SessionManager.instance.accessToken, 'saved');
  });

  test('logout clears the session but keeps app settings', () async {
    await SharedPreference.storeIsOnboardingDone(true);
    await SharedPreference.storeEmail('jane@example.com');
    await SessionManager.instance.saveTokens(accessToken: 'a1');
    await SessionManager.instance.logout();
    expect(SessionManager.instance.isLoggedIn, isFalse);
    expect(await SharedPreference.getAccessToken(), '');
    expect(await SharedPreference.getEmail(), '');
    expect(await SharedPreference.getIsOnboardingDone(), isTrue);
  });
}
```

```dart
// test/core/global/global_validation_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/global/util/global_validation.dart';

void main() {
  test('email', () {
    expect(isValidEmail('jane@example.com'), isNull);
    expect(isValidEmail('jane@'), isNotNull);
  });

  test('password minimum length', () {
    expect(isValidPassword('secret1'), isNull);
    expect(isValidPassword('abc'), 'Password must be at least 6 characters');
  });

  test('phone number', () {
    expect(isValidPhoneNumber('+8801712345678'), isNull);
    expect(isValidPhoneNumber('12ab'), isNotNull);
  });

  test('OTP has its own message and exact length', () {
    expect(isValidOTP('123456'), isNull);
    expect(isValidOTP('12345'), 'Please enter the 6-digit code');
    expect(isValidOTP('1234567'), isNotNull);
  });

  test('required', () {
    expect(isRequired('x'), isNull);
    expect(isRequired('  ', field: 'Title'), 'Title is required');
  });
}
```

```dart
// test/core/router_config_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/config/app_keys.dart';
import 'package:app/core/config/router_config.dart';
import 'package:app/core/global/util/session_manager.dart';
import 'package:app/features/items/controller/items_controller.dart';
import 'package:app/features/items/provider/items_provider.dart';
import '../helpers/fake_items_repository.dart';
import '../helpers/test_helpers.dart';

Widget routerApp() {
  return ProviderScope(
    overrides: [
      itemsControllerProvider.overrideWith(
        (ref) => ItemsController(repository: FakeItemsRepository(total: 3)),
      ),
    ],
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp.router(
        routerConfig: goRouter,
        scaffoldMessengerKey: scaffoldMessengerKey,
      ),
    ),
  );
}

void main() {
  setUp(resetStorageAndSession);

  testWidgets('logged out: the redirect shows the sign-in screen', (tester) async {
    goRouter.go(RouterPath.itemsScreenPath);
    await tester.pumpWidget(routerApp());
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('logged in: the list shows; a detail opened without data shows the fallback',
      (tester) async {
    await SessionManager.instance.saveTokens(accessToken: 'token');
    goRouter.go(RouterPath.itemsScreenPath);
    await tester.pumpWidget(routerApp());
    await tester.pumpAndSettle();
    expect(find.text('Item 1'), findsOneWidget);

    goRouter.push(RouterPath.itemDetailScreenPath); // no extra, like a deep link
    await tester.pumpAndSettle();
    expect(find.text('This item could not be opened.'), findsOneWidget);
  });
}
```

### D.4 Reference features
```dart
// test/features/items/items_models_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/items/model/request/item_request_model.dart';
import 'package:app/features/items/model/response/item_list_response_model.dart';
import 'package:app/features/items/model/response/item_response_model.dart';

void main() {
  test('list response parses items and numbers', () {
    final model = ItemListResponseModel.fromJson({
      'issuccess': true,
      'statusCode': 200.0,
      'message': 'OK',
      'payload': {
        'items': [
          {'id': 7, 'title': 'A', 'description': null},
        ],
        'page': 1,
        'limit': 20,
        'total': 1,
      },
    });
    expect(model.statusCode, 200);
    expect(model.payload?.items?.single.id, '7');
    expect(model.payload?.total, 1);
  });

  test('a missing payload is null', () {
    expect(ItemResponseModel.fromJson({'issuccess': false, 'message': 'x'}).payload, isNull);
  });

  test('the request model leaves out null fields', () {
    expect(ItemRequestModel(title: 'A').toJson(), {'title': 'A'});
  });
}
```

```dart
// test/features/items/items_controller_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/items/controller/items_controller.dart';
import 'package:app/features/items/model/request/item_request_model.dart';
import '../../helpers/fake_items_repository.dart';

void main() {
  // Controllers use AppFeedback (navigator and messenger keys), which needs the test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saveItem returns the saved item on success', () async {
    final controller = ItemsController(repository: FakeItemsRepository());
    final saved = await controller.saveItem(body: ItemRequestModel(title: 'Milk'));
    expect(saved?.id, 'new');
    expect(saved?.title, 'Milk');
  });

  test('saveItem returns null when the server rejects it', () async {
    final controller = ItemsController(repository: FakeItemsRepository(fail: true));
    expect(await controller.saveItem(body: ItemRequestModel(title: 'Milk')), isNull);
  });

  test('deleteItem reports success', () async {
    final repository = FakeItemsRepository();
    expect(await ItemsController(repository: repository).deleteItem('3'), isTrue);
    expect(repository.deleteCalls, 1);
  });
}
```

```dart
// test/features/items/items_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/items/controller/items_controller.dart';
import 'package:app/features/items/model/response/item_list_response_model.dart';
import 'package:app/features/items/provider/items_provider.dart';
import '../../helpers/fake_items_repository.dart';

void main() {
  ItemsNotifier notifierWith(FakeItemsRepository repository) =>
      ItemsNotifier(ItemsController(repository: repository), pageSize: 10);

  test('loads pages until there are no more', () async {
    final notifier = notifierWith(FakeItemsRepository(total: 25));
    await notifier.loadFirstPage();
    expect(notifier.state.requireValue.length, 10);
    expect(notifier.hasMore, isTrue);
    await notifier.loadNextPage();
    await notifier.loadNextPage();
    expect(notifier.state.requireValue.length, 25);
    expect(notifier.hasMore, isFalse);
  });

  test('a first-page error becomes an error state with the message', () async {
    final notifier = notifierWith(FakeItemsRepository(fail: true));
    await notifier.loadFirstPage();
    expect(notifier.state.hasError, isTrue);
    expect(notifier.state.error, 'No internet connection');
  });

  test('upsert and remove update the list without reloading', () async {
    final notifier = notifierWith(FakeItemsRepository(total: 3));
    await notifier.loadFirstPage();
    notifier.upsert(Item(id: 'new', title: 'New'));
    notifier.upsert(Item(id: '1', title: 'Renamed'));
    notifier.remove('2');
    final titles = notifier.state.requireValue.map((item) => item.title).toList();
    expect(titles, ['New', 'Renamed', 'Item 3']);
  });
}
```

```dart
// test/features/items/items_widgets_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/global/widgets/app_state_views.dart';
import 'package:app/features/items/controller/items_controller.dart';
import 'package:app/features/items/model/response/item_list_response_model.dart';
import 'package:app/features/items/presentation/component/item_card_component.dart';
import 'package:app/features/items/presentation/component/item_form_component.dart';
import 'package:app/features/items/presentation/component/items_list_component.dart';
import 'package:app/features/items/provider/items_provider.dart';
import '../../helpers/fake_items_repository.dart';
import '../../helpers/test_helpers.dart';

void main() {
  setUp(resetStorageAndSession);

  Widget listWith(FakeItemsRepository repository) => wrap(
        const Scaffold(body: ItemsListComponent()),
        overrides: [
          itemsControllerProvider.overrideWith((ref) => ItemsController(repository: repository)),
        ],
      );

  testWidgets('list: loading first, then the data', (tester) async {
    await tester.pumpWidget(listWith(FakeItemsRepository(total: 3)));
    expect(find.byType(AppLoadingView), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(ItemsListComponent)));
    await container.read(getItemsProvider.notifier).loadFirstPage();
    await tester.pump();
    expect(find.byType(ItemCardComponent), findsNWidgets(3));
    expect(find.text('Item 1'), findsOneWidget);
  });

  testWidgets('list: empty and error states', (tester) async {
    final repository = FakeItemsRepository(total: 0);
    await tester.pumpWidget(listWith(repository));
    final container = ProviderScope.containerOf(tester.element(find.byType(ItemsListComponent)));
    await container.read(getItemsProvider.notifier).loadFirstPage();
    await tester.pump();
    expect(find.byType(AppEmptyView), findsOneWidget);

    repository.fail = true;
    await container.read(getItemsProvider.notifier).loadFirstPage();
    await tester.pump();
    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('card: tapping calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(Scaffold(
      body: ItemCardComponent(item: Item(id: '1', title: 'Milk'), onTap: () => taps++),
    )));
    await tester.tap(find.text('Milk'));
    expect(taps, 1);
  });

  testWidgets('form: the title is required', (tester) async {
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController();
    final description = TextEditingController();
    addTearDown(title.dispose);
    addTearDown(description.dispose);
    var submitted = 0;
    await tester.pumpWidget(wrap(Scaffold(
      body: ItemFormComponent(
        formKey: formKey,
        titleController: title,
        descriptionController: description,
        isSaving: false,
        submitText: 'Create item',
        onSubmit: () {
          if (formKey.currentState?.validate() ?? false) submitted++;
        },
      ),
    )));
    await tester.tap(find.text('Create item'));
    await tester.pump();
    expect(find.text('Title is required'), findsOneWidget);
    expect(submitted, 0);

    await tester.enterText(find.byType(TextFormField).first, 'Milk');
    await tester.tap(find.text('Create item'));
    await tester.pump();
    expect(submitted, 1);
  });
}
```

```dart
// test/features/sign_in/sign_in_controller_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/global/util/session_manager.dart';
import 'package:app/core/global/util/shared_preferences.dart';
import 'package:app/features/sign_in/controller/sign_in_controller.dart';
import 'package:app/features/sign_in/model/request/sign_in_request_model.dart';
import 'package:app/features/sign_in/model/response/sign_in_response_model.dart';
import 'package:app/features/sign_in/repository/sign_in_repository.dart';
import '../../helpers/test_helpers.dart';

class FakeSignInRepository extends SignInRepository {
  FakeSignInRepository(this.response);

  final SignInResponseModel response;

  @override
  Future<SignInResponseModel> signIn(SignInRequestModel body) async => response;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // the controller uses AppFeedback
  setUp(resetStorageAndSession);

  test('success: saves the profile and the session (awaited)', () async {
    final controller = SignInController(
      repository: FakeSignInRepository(SignInResponseModel(
        issuccess: true,
        payload: SignInPayload(accessToken: 'a1', refreshToken: 'r1', name: 'Jane', email: 'jane@example.com'),
      )),
    );
    expect(await controller.signIn(email: 'jane@example.com', password: 'secret1'), isTrue);
    expect(SessionManager.instance.isLoggedIn, isTrue);
    expect(await SharedPreference.getAccessToken(), 'a1');
    expect(await SharedPreference.getFullName(), 'Jane');
  });

  test('failure: nothing is saved', () async {
    final controller = SignInController(
      repository: FakeSignInRepository(SignInResponseModel(message: 'Wrong password')),
    );
    expect(await controller.signIn(email: 'jane@example.com', password: 'nope12'), isFalse);
    expect(SessionManager.instance.isLoggedIn, isFalse);
    expect(await SharedPreference.getAccessToken(), '');
  });
}
```
