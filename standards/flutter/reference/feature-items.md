# Flutter House Standard v3 · Reference B: feature `items` (create, read, update, delete, pagination), complete files

> Part of the Flutter house standard v3. The rules are in `../SKILL.md` (sections 1–24): read them first.
> Open this file only when you need its complete code. Every code block whose first line is a path comment
> (`// lib/...` or `// test/...`) is a **whole file**: create it at that path and replace `app` in
> `package:app/...` with your package name (`name:` in `pubspec.yaml`). The four reference files
> (`core.md`, `feature-items.md`, `feature-sign-in.md`, `tests.md`) compile and pass their tests together
> on flutter_riverpod 2.6.1 and 3.3.2 (`tests/flutter-standard-check.sh` in the kit).

Copy these patterns for every new feature: rename `items` / `Item`, keep the structure.

### B.1 Models
```dart
// lib/features/items/model/request/item_request_model.dart
/// title : "Groceries"
/// description : "Milk and bread"
class ItemRequestModel {
  ItemRequestModel({this.title, this.description});

  String? title;
  String? description;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    return data;
  }
}
```

```dart
// lib/features/items/model/response/item_list_response_model.dart
/// issuccess : true
/// statusCode : 200
/// message : "OK"
/// payload : {"items": [{"id": "1", "title": "Groceries", "description": "Milk and bread"}], "page": 1, "limit": 20, "total": 1}
class ItemListResponseModel {
  ItemListResponseModel({this.issuccess, this.statusCode, this.message, this.payload});

  ItemListResponseModel.fromJson(Map<String, dynamic> json) {
    issuccess = json['issuccess'];
    statusCode = (json['statusCode'] as num?)?.toInt();
    message = json['message'];
    payload = json['payload'] != null ? ItemListPayload.fromJson(json['payload']) : null;
  }

  bool? issuccess;
  int? statusCode;
  String? message;
  ItemListPayload? payload;
}

class ItemListPayload {
  ItemListPayload({this.items, this.page, this.limit, this.total});

  ItemListPayload.fromJson(Map<String, dynamic> json) {
    items = (json['items'] as List?)
        ?.map((item) => Item.fromJson(item as Map<String, dynamic>))
        .toList();
    page = (json['page'] as num?)?.toInt();
    limit = (json['limit'] as num?)?.toInt();
    total = (json['total'] as num?)?.toInt();
  }

  List<Item>? items;
  int? page;
  int? limit;
  int? total;
}

class Item {
  Item({this.id, this.title, this.description});

  Item.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    title = json['title'];
    description = json['description'];
  }

  String? id;
  String? title;
  String? description;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'description': description};
}
```

```dart
// lib/features/items/model/response/item_response_model.dart
import 'item_list_response_model.dart';

/// issuccess : true
/// statusCode : 200
/// message : "Saved"
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

### B.2 Repository, controller, provider
```dart
// lib/features/items/repository/items_repository.dart
import 'package:dio/dio.dart';

import 'package:app/core/config/api_config.dart';
import 'package:app/core/config/network/api_request.dart';
import 'package:app/core/global/global_features/model/response/basic_response_model.dart';
import '../model/request/item_request_model.dart';
import '../model/response/item_list_response_model.dart';
import '../model/response/item_response_model.dart';

/// One short method per endpoint. No headers, no try/catch: AuthInterceptor and ApiRequest do that.
class ItemsRepository {
  /// [dio] is only passed in tests (a Dio with a fake adapter).
  ItemsRepository({this.dio});

  final Dio? dio;

  Future<ItemListResponseModel> getItems({required int page, int limit = 20}) => ApiRequest.send(
        dio: dio,
        call: (client) => client.get(UrlUtils.itemsUrl, queryParameters: {'page': page, 'limit': limit}),
        fromJson: (json) => ItemListResponseModel.fromJson(json as Map<String, dynamic>),
        onError: (message, statusCode) => ItemListResponseModel(message: message, statusCode: statusCode),
      );

  Future<ItemResponseModel> getItem(String id) => ApiRequest.send(
        dio: dio,
        call: (client) => client.get(UrlUtils.itemUrl(id)),
        fromJson: (json) => ItemResponseModel.fromJson(json as Map<String, dynamic>),
        onError: (message, statusCode) => ItemResponseModel(message: message, statusCode: statusCode),
      );

  Future<ItemResponseModel> createItem(ItemRequestModel body) => ApiRequest.send(
        dio: dio,
        call: (client) => client.post(UrlUtils.itemsUrl, data: body.toJson()),
        fromJson: (json) => ItemResponseModel.fromJson(json as Map<String, dynamic>),
        onError: (message, statusCode) => ItemResponseModel(message: message, statusCode: statusCode),
      );

  Future<ItemResponseModel> updateItem(String id, ItemRequestModel body) => ApiRequest.send(
        dio: dio,
        call: (client) => client.put(UrlUtils.itemUrl(id), data: body.toJson()),
        fromJson: (json) => ItemResponseModel.fromJson(json as Map<String, dynamic>),
        onError: (message, statusCode) => ItemResponseModel(message: message, statusCode: statusCode),
      );

  Future<BasicResponseModel> deleteItem(String id) => ApiRequest.send(
        dio: dio,
        call: (client) => client.delete(UrlUtils.itemUrl(id)),
        fromJson: (json) => BasicResponseModel.fromJson(json as Map<String, dynamic>),
        onError: (message, statusCode) => BasicResponseModel(message: message, statusCode: statusCode),
      );
}
```

```dart
// lib/features/items/controller/items_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/global/global_features/controller/base_controller.dart';
import 'package:app/core/global/util/app_feedback.dart';
import '../model/request/item_request_model.dart';
import '../model/response/item_list_response_model.dart';
import '../provider/items_provider.dart';
import '../repository/items_repository.dart';

/// Business logic for items. No BuildContext and no navigation: methods return a result and the
/// page decides what to do next. Feedback goes through AppFeedback.
class ItemsController extends BaseController {
  ItemsController({ItemsRepository? repository}) : repository = repository ?? ItemsRepository();

  final ItemsRepository repository;

  @override
  Future<void> onRefresh(WidgetRef ref) => ref.read(getItemsProvider.notifier).loadFirstPage();

  Future<ItemListResponseModel> fetchItems({required int page, int limit = 20}) =>
      repository.getItems(page: page, limit: limit);

  /// Creates ([id] == null) or updates an item. Returns the saved item, or null on failure.
  Future<Item?> saveItem({String? id, required ItemRequestModel body}) async {
    final response = await AppFeedback.withLoading(
      () => id == null ? repository.createItem(body) : repository.updateItem(id, body),
    );
    final saved = response.payload;
    if (response.issuccess == true && saved != null) {
      AppFeedback.showSuccess(response.message ?? 'Saved');
      return saved;
    }
    AppFeedback.showError(response.message ?? 'Something went wrong');
    return null;
  }

  /// Returns true when the item was deleted.
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

```dart
// lib/features/items/provider/items_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_riverpod/legacy.dart'; // flutter_riverpod 3.x: uncomment

import 'package:app/core/global/util/app_feedback.dart';
import '../controller/items_controller.dart';
import '../model/response/item_list_response_model.dart';

// ChangeNotifierProvider for the controller
var itemsControllerProvider = ChangeNotifierProvider((ref) {
  ItemsController controller = ItemsController();
  return controller;
});

/// The paginated list. `.notifier` = the controller without listening to it (section 7.3).
final getItemsProvider = StateNotifierProvider<ItemsNotifier, AsyncValue<List<Item>>>((ref) {
  return ItemsNotifier(ref.watch(itemsControllerProvider.notifier));
});

class ItemsNotifier extends StateNotifier<AsyncValue<List<Item>>> {
  ItemsNotifier(this.controller, {this.pageSize = 20}) : super(const AsyncValue.loading());

  final ItemsController controller;
  final int pageSize;
  int _page = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;

  Future<void> loadFirstPage() async {
    _page = 0;
    _hasMore = true;
    state = const AsyncValue.loading();
    await _loadPage(reset: true);
  }

  Future<void> loadNextPage() async {
    if (!_hasMore || _isLoadingMore || !state.hasValue) return;
    _isLoadingMore = true;
    await _loadPage(reset: false);
    _isLoadingMore = false;
  }

  Future<void> _loadPage({required bool reset}) async {
    final response = await controller.fetchItems(page: _page + 1, limit: pageSize);
    if (!mounted) return;
    if (response.issuccess != true) {
      final message = response.message ?? 'Something went wrong';
      if (reset) {
        state = AsyncValue.error(message, StackTrace.current);
      } else {
        AppFeedback.showError(message);
      }
      return;
    }
    final items = response.payload?.items ?? const <Item>[];
    _page++;
    _hasMore = items.length >= pageSize;
    // hasValue + requireValue work on Riverpod 2 and 3 (`.value` throws on errors in 2.x).
    final previous = reset || !state.hasValue ? const <Item>[] : state.requireValue;
    state = AsyncValue.data([...previous, ...items]);
  }

  /// Keeps the list in sync after create or update, without reloading.
  void upsert(Item item) {
    if (!state.hasValue) return;
    final list = [...state.requireValue];
    final index = list.indexWhere((existing) => existing.id == item.id);
    if (index >= 0) {
      list[index] = item;
    } else {
      list.insert(0, item);
    }
    state = AsyncValue.data(list);
  }

  /// Keeps the list in sync after delete, without reloading.
  void remove(String id) {
    if (!state.hasValue) return;
    state = AsyncValue.data(state.requireValue.where((item) => item.id != id).toList());
  }
}
```

### B.3 Pages
```dart
// lib/features/items/presentation/page/items_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:app/core/config/router_config.dart';
import 'package:app/core/global/widgets/custom_appbar.dart';
import '../../provider/items_provider.dart';
import '../component/items_list_component.dart';

class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(getItemsProvider.notifier).loadFirstPage());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalAppBar(
        title: 'Items',
        showBack: false,
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(itemsControllerProvider).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(itemsControllerProvider).onRefresh(ref),
        child: const ItemsListComponent(),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add item',
        onPressed: () => context.push(RouterPath.itemFormScreenPath),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

```dart
// lib/features/items/presentation/page/item_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:app/core/config/router_config.dart';
import 'package:app/core/global/widgets/app_state_views.dart';
import 'package:app/core/global/widgets/confirm_dialog.dart';
import 'package:app/core/global/widgets/custom_appbar.dart';
import '../../model/response/item_list_response_model.dart';
import '../../provider/items_provider.dart';
import '../component/item_detail_component.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.item});

  /// Null when the screen was opened without data (deep link, app restore): show a fallback.
  final Item? item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = item;
    if (current == null) {
      return Scaffold(
        appBar: const GlobalAppBar(title: 'Item'),
        body: AppErrorView(
          message: 'This item could not be opened.',
          retryText: 'Back to the list',
          onRetry: () => context.go(RouterPath.itemsScreenPath),
        ),
      );
    }
    return Scaffold(
      appBar: GlobalAppBar(
        title: current.title ?? 'Item',
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(RouterPath.itemFormScreenPath, extra: current),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref, current),
          ),
        ],
      ),
      body: ItemDetailComponent(item: current),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Item item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete item',
      message: 'Delete "${item.title ?? ''}"? This cannot be undone.',
    );
    if (!confirmed || !context.mounted) return;
    final id = item.id ?? '';
    final deleted = await ref.read(itemsControllerProvider).deleteItem(id);
    if (!deleted || !context.mounted) return;
    ref.read(getItemsProvider.notifier).remove(id);
    context.pop();
  }
}
```

```dart
// lib/features/items/presentation/page/item_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:app/core/global/widgets/custom_appbar.dart';
import '../../model/request/item_request_model.dart';
import '../../model/response/item_list_response_model.dart';
import '../../provider/items_provider.dart';
import '../component/item_form_component.dart';

/// Create ([item] == null) or edit an item. Text controllers live here and are disposed here.
class ItemFormScreen extends ConsumerStatefulWidget {
  const ItemFormScreen({super.key, this.item});

  final Item? item;

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController = TextEditingController(text: widget.item?.title);
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.item?.description);
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final saved = await ref.read(itemsControllerProvider).saveItem(
          id: widget.item?.id,
          body: ItemRequestModel(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
          ),
        );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (saved == null) return;
    ref.read(getItemsProvider.notifier).upsert(saved);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;
    return Scaffold(
      appBar: GlobalAppBar(title: isEditing ? 'Edit item' : 'New item'),
      body: ItemFormComponent(
        formKey: _formKey,
        titleController: _titleController,
        descriptionController: _descriptionController,
        isSaving: _isSaving,
        submitText: isEditing ? 'Save changes' : 'Create item',
        onSubmit: _save,
      ),
    );
  }
}
```

### B.4 Components
```dart
// lib/features/items/presentation/component/item_card_component.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../model/response/item_list_response_model.dart';

class ItemCardComponent extends StatelessWidget {
  const ItemCardComponent({super.key, required this.item, required this.onTap});

  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = item.description;
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: ListTile(
        title: Text(item.title ?? '', style: theme.textTheme.titleMedium),
        subtitle: description != null && description.isNotEmpty
            ? Text(description, maxLines: 2, overflow: TextOverflow.ellipsis)
            : null,
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}
```

```dart
// lib/features/items/presentation/component/items_list_component.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:app/core/config/router_config.dart';
import 'package:app/core/global/widgets/app_state_views.dart';
import '../../provider/items_provider.dart';
import 'item_card_component.dart';

/// The list with all its states. Loads the next page near the end of the list (no ScrollController).
class ItemsListComponent extends ConsumerWidget {
  const ItemsListComponent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsState = ref.watch(getItemsProvider);
    final notifier = ref.read(getItemsProvider.notifier);
    return itemsState.when(
      loading: () => const AppLoadingView(),
      error: (error, stackTrace) => AppErrorView(message: '$error', onRetry: notifier.loadFirstPage),
      data: (items) {
        if (items.isEmpty) {
          return const AppEmptyView(message: 'No items yet. Tap + to add one.');
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.extentAfter < 300) notifier.loadNextPage();
            return false;
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length + (notifier.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final item = items[index];
              return ItemCardComponent(
                item: item,
                onTap: () => context.push(RouterPath.itemDetailScreenPath, extra: item),
              );
            },
          ),
        );
      },
    );
  }
}
```

```dart
// lib/features/items/presentation/component/item_detail_component.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:app/core/config/color_config.dart';
import '../../model/response/item_list_response_model.dart';

class ItemDetailComponent extends StatelessWidget {
  const ItemDetailComponent({super.key, required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        SelectableText(
          item.title ?? '',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: ColorConfig.textColorPrimary),
        ),
        SizedBox(height: 12.h),
        SelectableText(
          item.description ?? '',
          style: TextStyle(fontSize: 15.sp, color: ColorConfig.textColorSecondary),
        ),
      ],
    );
  }
}
```

```dart
// lib/features/items/presentation/component/item_form_component.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:app/core/global/util/global_validation.dart';
import 'package:app/core/global/widgets/input_text_field.dart';
import 'package:app/core/global/widgets/primary_button.dart';

/// The item form. The page owns the controllers and the form key and handles submit.
class ItemFormComponent extends StatelessWidget {
  const ItemFormComponent({
    super.key,
    required this.formKey,
    required this.titleController,
    required this.descriptionController,
    required this.isSaving,
    required this.submitText,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final bool isSaving;
  final String submitText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: EdgeInsets.all(16.r),
        children: [
          InputTextField(
            controller: titleController,
            label: 'Title',
            validator: (value) => isRequired(value, field: 'Title'),
            textInputAction: TextInputAction.next,
          ),
          InputTextField(controller: descriptionController, label: 'Description', maxLines: 4),
          SizedBox(height: 8.h),
          PrimaryButton(text: submitText, isLoading: isSaving, onPressed: onSubmit),
        ],
      ),
    );
  }
}
```
