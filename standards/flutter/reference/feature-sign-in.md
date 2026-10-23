# Flutter House Standard v3 · Reference C: feature `sign_in` (login, tokens, session), complete files

> Part of the Flutter house standard v3. The rules are in `../SKILL.md` (sections 1–24): read them first.
> Open this file only when you need its complete code. Every code block whose first line is a path comment
> (`// lib/...` or `// test/...`) is a **whole file**: create it at that path and replace `app` in
> `package:app/...` with your package name (`name:` in `pubspec.yaml`). The four reference files
> (`core.md`, `feature-items.md`, `feature-sign-in.md`, `tests.md`) compile and pass their tests together
> on flutter_riverpod 2.6.1 and 3.3.2 (`tests/flutter-standard-check.sh` in the kit).

After a successful login the controller saves the session (awaited). The router redirect then leaves the
sign-in screen by itself, so there is no navigation code here.

```dart
// lib/features/sign_in/model/request/sign_in_request_model.dart
/// email : "jane@example.com"
/// password : "••••••"
class SignInRequestModel {
  SignInRequestModel({this.email, this.password});

  String? email;
  String? password;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (email != null) data['email'] = email;
    if (password != null) data['password'] = password;
    return data;
  }
}
```

```dart
// lib/features/sign_in/model/response/sign_in_response_model.dart
/// issuccess : true
/// statusCode : 200
/// message : "Welcome"
/// payload : {"accessToken": "…", "refreshToken": "…", "name": "Jane", "email": "jane@example.com"}
class SignInResponseModel {
  SignInResponseModel({this.issuccess, this.statusCode, this.message, this.payload});

  SignInResponseModel.fromJson(Map<String, dynamic> json) {
    issuccess = json['issuccess'];
    statusCode = (json['statusCode'] as num?)?.toInt();
    message = json['message'];
    payload = json['payload'] != null ? SignInPayload.fromJson(json['payload']) : null;
  }

  bool? issuccess;
  int? statusCode;
  String? message;
  SignInPayload? payload;
}

class SignInPayload {
  SignInPayload({this.accessToken, this.refreshToken, this.name, this.email});

  SignInPayload.fromJson(Map<String, dynamic> json) {
    accessToken = json['accessToken'];
    refreshToken = json['refreshToken'];
    name = json['name'];
    email = json['email'];
  }

  String? accessToken;
  String? refreshToken;
  String? name;
  String? email;
}
```

```dart
// lib/features/sign_in/repository/sign_in_repository.dart
import 'package:dio/dio.dart';

import 'package:app/core/config/api_config.dart';
import 'package:app/core/config/network/api_request.dart';
import 'package:app/core/config/network/auth_interceptor.dart';
import '../model/request/sign_in_request_model.dart';
import '../model/response/sign_in_response_model.dart';

class SignInRepository {
  /// [dio] is only passed in tests (a Dio with a fake adapter).
  SignInRepository({this.dio});

  final Dio? dio;

  Future<SignInResponseModel> signIn(SignInRequestModel body) => ApiRequest.send(
        dio: dio,
        call: (client) => client.post(
          UrlUtils.loginUrl,
          data: body.toJson(),
          options: Options(extra: {AuthInterceptor.skipAuth: true}),
        ),
        fromJson: (json) => SignInResponseModel.fromJson(json as Map<String, dynamic>),
        onError: (message, statusCode) => SignInResponseModel(message: message, statusCode: statusCode),
      );
}
```

```dart
// lib/features/sign_in/controller/sign_in_controller.dart
import 'package:app/core/global/global_features/controller/base_controller.dart';
import 'package:app/core/global/util/app_feedback.dart';
import 'package:app/core/global/util/session_manager.dart';
import 'package:app/core/global/util/shared_preferences.dart';
import '../model/request/sign_in_request_model.dart';
import '../repository/sign_in_repository.dart';

class SignInController extends BaseController {
  SignInController({SignInRepository? repository}) : repository = repository ?? SignInRepository();

  final SignInRepository repository;

  /// Signs in and saves the session. Returns true on success.
  /// Every write is awaited BEFORE the session changes, because the router reacts immediately.
  Future<bool> signIn({required String email, required String password}) async {
    final response = await AppFeedback.withLoading(
      () => repository.signIn(SignInRequestModel(email: email, password: password)),
    );
    final payload = response.payload;
    final token = payload?.accessToken ?? '';
    if (response.issuccess != true || payload == null || token.isEmpty) {
      AppFeedback.showError(response.message ?? 'Sign-in failed. Please try again.');
      return false;
    }
    await SharedPreference.storeFullName(payload.name ?? '');
    await SharedPreference.storeEmail(payload.email ?? '');
    await SessionManager.instance.saveTokens(
      accessToken: token,
      refreshToken: payload.refreshToken ?? '',
    );
    return true;
  }
}
```

```dart
// lib/features/sign_in/provider/sign_in_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_riverpod/legacy.dart'; // flutter_riverpod 3.x: uncomment

import '../controller/sign_in_controller.dart';

// ChangeNotifierProvider for the controller
var signInControllerProvider = ChangeNotifierProvider((ref) {
  SignInController controller = SignInController();
  return controller;
});
```

```dart
// lib/features/sign_in/presentation/page/sign_in_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../provider/sign_in_provider.dart';
import '../component/sign_in_form_component.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    await ref.read(signInControllerProvider).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    // On success the router has already left this screen.
    if (!mounted) return;
    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SignInFormComponent(
          formKey: _formKey,
          emailController: _emailController,
          passwordController: _passwordController,
          isSubmitting: _isSubmitting,
          onSubmit: _submit,
        ),
      ),
    );
  }
}
```

```dart
// lib/features/sign_in/presentation/component/sign_in_form_component.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:app/core/config/color_config.dart';
import 'package:app/core/global/util/global_validation.dart';
import 'package:app/core/global/widgets/input_text_field.dart';
import 'package:app/core/global/widgets/primary_button.dart';

class SignInFormComponent extends StatelessWidget {
  const SignInFormComponent({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: EdgeInsets.all(24.r),
        children: [
          SizedBox(height: 40.h),
          Text(
            'Sign in',
            style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w700, color: ColorConfig.textColorPrimary),
          ),
          SizedBox(height: 24.h),
          InputTextField(
            controller: emailController,
            label: 'Email',
            validator: isValidEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          InputTextField(
            controller: passwordController,
            label: 'Password',
            validator: isValidPassword,
            obscureText: true,
            textInputAction: TextInputAction.done,
          ),
          SizedBox(height: 8.h),
          PrimaryButton(text: 'Sign in', isLoading: isSubmitting, onPressed: onSubmit),
        ],
      ),
    );
  }
}
```
