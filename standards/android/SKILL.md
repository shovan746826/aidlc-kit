---
name: project-architecture
description: Native Android house architecture standard: Kotlin, Jetpack Compose, MVVM with StateFlow, Hilt, Retrofit + OkHttp + kotlinx.serialization, Room/DataStore, type-safe Navigation Compose, feature-first packages that mirror the Flutter house standard. MANDATORY: read it before planning or writing any code, and use it to place every new feature, screen and component.
---
<!-- aidlc-kit:standard=android · house standard v1 (PROPOSED, review before first use) · project-owned copy: init-project.sh never overwrites it (use --update-architecture) -->

# Native Android Architecture: House Standard

> **⚠️ CRITICAL**: Read and follow this standard before writing any code, creating any file or modifying
> any module. Workflow rules: `.agents/rules/00-aidlc-core.md` and `.agents/rules/10-quality-gates.md`.
> **Status: proposed v1.** It mirrors the Flutter house standard so every project looks alike. Adapt names
> to the actual project and record approved deviations in `aidlc-docs/project-profile.md`.

## 1. Stack

| Layer | Technology |
|---|---|
| Language | Kotlin (current stable; coroutines + Flow) |
| UI | Jetpack Compose + Material 3 |
| Presentation pattern | MVVM: `ViewModel` + `StateFlow<UiState>` |
| Dependency injection | Hilt |
| Networking | Retrofit + OkHttp (interceptors) + kotlinx.serialization |
| Local storage | DataStore (preferences), Room (structured data), encrypted storage for tokens |
| Navigation | Navigation Compose with type-safe `@Serializable` routes |
| Images | Coil |
| Build | Gradle Kotlin DSL + version catalog (`gradle/libs.versions.toml`) |
| Testing | JUnit, MockK or fakes, Turbine, kotlinx-coroutines-test, Compose UI tests, MockWebServer |

Use the versions in the project's version catalog. New projects: current stable versions.
Before any work, read `aidlc-docs/project-profile.md` (run `.agents/skills/project-analysis/SKILL.md` if missing).

## 2. Mapping from the Flutter house standard

| Flutter folder | Android package | Holds |
|---|---|---|
| `controller/` | `viewmodel/` | `<Feature>ViewModel`, `<Feature>UiState` |
| `model/request/` | `model/request/` | `<Name>Request` (`@Serializable`) |
| `model/response/` | `model/response/` | `<Name>Response` (`@Serializable`) |
| `presentation/page/` | `presentation/screen/` | `<Feature>Route` + `<Feature>Screen` |
| `presentation/component/` | `presentation/component/` | one public composable per file |
| `provider/` | `di/` | Hilt module for the feature |
| `repository/` | `repository/` | `<Feature>Api` (Retrofit) + `<Feature>Repository` |

## 3. Project structure

```
app/src/main/java/<package>/
├── App.kt                         # @HiltAndroidApp Application
├── MainActivity.kt                # setContent { AppTheme { AppNavHost() } }
├── core/
│   ├── config/
│   │   ├── ApiConfig.kt           # base URLs per build type/flavor, endpoint paths
│   │   └── AppConstants.kt
│   ├── network/
│   │   ├── NetworkModule.kt       # Hilt: OkHttpClient, Retrofit, Json
│   │   ├── AuthInterceptor.kt     # standard headers (Authorization, module, Content-Type)
│   │   ├── ApiResult.kt           # sealed result type
│   │   └── ApiErrorMapper.kt      # exceptions/HTTP codes → ApiError
│   ├── storage/
│   │   ├── AppPreferences.kt      # DataStore wrapper (store<Key>/get<Key>)
│   │   ├── TokenStorage.kt        # encrypted token storage
│   │   └── AppDatabase.kt         # Room (if needed)
│   ├── designsystem/
│   │   ├── Color.kt  Type.kt  Shape.kt  Dimens.kt  Theme.kt
│   ├── ui/component/              # shared composables (AppTopBar, PrimaryButton, InputTextField, LoadingView, ErrorView)
│   ├── navigation/
│   │   ├── Routes.kt              # @Serializable route objects/classes
│   │   └── AppNavHost.kt
│   ├── session/SessionManager.kt  # logout on 401
│   └── util/
└── feature/<feature_name>/
    ├── viewmodel/   <Feature>ViewModel.kt, <Feature>UiState.kt
    ├── model/request/   <Name>Request.kt
    ├── model/response/  <Name>Response.kt
    ├── presentation/screen/     <Feature>Screen.kt
    ├── presentation/component/  <Feature><Part>.kt
    ├── di/          <Feature>Module.kt
    └── repository/  <Feature>Api.kt, <Feature>Repository.kt
```

- Single `app` module with feature packages by default. Multi-module (`:feature:<name>`, `:core:*`) only
  when an approved architecture decision says so (many features or several teams).
- UI-only features may leave out `model/` and `repository/`. Never invent other package names.

## 4. Data flow

```
Screen (Route) ──collectAsStateWithLifecycle──► ViewModel ──suspend call──► Repository ──► Api (Retrofit) ──► server
      ▲                                              │                          │
      └────────────── UiState (StateFlow) ◄──────────┘◄──── ApiResult<T> ◄──────┘
```
1. `<Feature>Route` gets the ViewModel (`hiltViewModel()`), collects `uiState`, passes state and callbacks
   to the stateless `<Feature>Screen`.
2. The ViewModel calls the repository in `viewModelScope`, maps `ApiResult` to `UiState`.
3. The repository calls the Retrofit API, catches errors and returns `ApiResult<T>`. It never throws to the UI.

## 5. Naming

| Type | Pattern | Example |
|---|---|---|
| Feature package | lowercase, no underscores | `feature.budgetalerts` |
| ViewModel | `<Feature>ViewModel` | `HomeViewModel` |
| UI state | `<Feature>UiState` | `HomeUiState` |
| Repository / API | `<Feature>Repository` / `<Feature>Api` | `HomeRepository` / `HomeApi` |
| Request / response | `<Name>Request` / `<Name>Response` | `LoginRequest` / `HomeConfigResponse` |
| Screen | `<Feature>Route` + `<Feature>Screen` in `<Feature>Screen.kt` | `HomeRoute`, `HomeScreen` |
| Component | `<Feature><Part>` in `<Feature><Part>.kt` | `HomeHeader` |
| Hilt module | `<Feature>Module` | `HomeModule` |
| Navigation destination | `<Feature>Destination` (`@Serializable` object or data class) in `Routes.kt` | `HomeDestination` |
| Files | PascalCase, named after the main declaration (Kotlin convention) | `HomeViewModel.kt` |

## 6. Patterns

### 6.1 API and repository
```kotlin
interface <Feature>Api {
    @GET(ApiConfig.<ENDPOINT>)
    suspend fun getData(): <Name>Response
}

class <Feature>Repository @Inject constructor(
    private val api: <Feature>Api,
    private val errorMapper: ApiErrorMapper,
) {
    suspend fun getData(): ApiResult<<Name>Response> =
        try {
            ApiResult.Success(api.getData())
        } catch (e: Exception) {
            if (e is CancellationException) throw e
            ApiResult.Error(errorMapper.map(e))
        }
}
```

### 6.2 Result and errors
```kotlin
sealed interface ApiResult<out T> {
    data class Success<T>(val data: T) : ApiResult<T>
    data class Error(val error: ApiError) : ApiResult<Nothing>
}

sealed interface ApiError {
    data object Network : ApiError
    data object Unauthorized : ApiError          // 401 → SessionManager logs out
    data class Server(val code: Int, val message: String?) : ApiError
    data class Unknown(val message: String?) : ApiError
}
```

### 6.3 ViewModel and UI state
```kotlin
sealed interface <Feature>UiState {
    data object Loading : <Feature>UiState
    data object Empty : <Feature>UiState
    data class Data(val items: List<Item>) : <Feature>UiState
    data class Error(val message: String) : <Feature>UiState
}

@HiltViewModel
class <Feature>ViewModel @Inject constructor(
    private val repository: <Feature>Repository,
) : ViewModel() {
    private val _uiState = MutableStateFlow<<Feature>UiState>(<Feature>UiState.Loading)
    val uiState: StateFlow<<Feature>UiState> = _uiState.asStateFlow()

    init { load() }

    fun load() = viewModelScope.launch {
        _uiState.value = <Feature>UiState.Loading
        _uiState.value = when (val result = repository.getData()) {
            is ApiResult.Success -> if (result.data.items.isEmpty()) <Feature>UiState.Empty
                                    else <Feature>UiState.Data(result.data.items)
            is ApiResult.Error -> <Feature>UiState.Error(result.error.toMessage())
        }
    }
}
```

### 6.4 Models
```kotlin
@Serializable
data class <Name>Request(
    @SerialName("field_one") val fieldOne: String,
    @SerialName("field_two") val fieldTwo: String? = null,
)

@Serializable
data class <Name>Response(
    @SerialName("issuccess") val isSuccess: Boolean = false,
    @SerialName("statusCode") val statusCode: Int? = null,
    @SerialName("message") val message: String? = null,
    @SerialName("payload") val payload: <Payload>? = null,
)
```
Configure `Json { ignoreUnknownKeys = true; explicitNulls = false }` once in `NetworkModule`.

### 6.5 Screen and components (no inline sub-UI in screens)
> **STRICT RULE:** a screen file contains only `<Feature>Route` (state collection and navigation callbacks)
> and `<Feature>Screen` (Scaffold, top bar, layout that assembles components). Every sub-UI (cards, list
> items, filters, dialogs) is its own `@Composable` in `presentation/component/`, one public composable
> per file, with a `@Preview`. No private composable helpers inside screen files.

```kotlin
@Composable
fun <Feature>Route(onOpenDetail: (String) -> Unit, viewModel: <Feature>ViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    <Feature>Screen(uiState = uiState, onRetry = viewModel::load, onOpenDetail = onOpenDetail)
}

@Composable
fun <Feature>Screen(uiState: <Feature>UiState, onRetry: () -> Unit, onOpenDetail: (String) -> Unit) {
    Scaffold(topBar = { AppTopBar(title = stringResource(R.string.<feature>_title)) }) { padding ->
        when (uiState) {
            <Feature>UiState.Loading -> LoadingView(Modifier.padding(padding))
            <Feature>UiState.Empty -> <Feature>EmptyState(Modifier.padding(padding))
            is <Feature>UiState.Error -> ErrorView(uiState.message, onRetry, Modifier.padding(padding))
            is <Feature>UiState.Data -> <Feature>List(uiState.items, onOpenDetail, Modifier.padding(padding))
        }
    }
}
```
Components are stateless: data in, events out (state hoisting).

## 7. Navigation
1. Add a `@Serializable` destination in `core/navigation/Routes.kt` (object, or data class with arguments).
2. Register `composable<Destination> { <Feature>Route(...) }` in `AppNavHost.kt`.
3. Screens never receive `NavController`. They get callbacks such as `onOpenDetail: (String) -> Unit`.
4. Pass IDs, not objects, as arguments. Load the object in the next ViewModel.

## 8. API integration
1. Add the endpoint path to `ApiConfig`.
2. Request/response models in the feature's `model/` packages.
3. Function in `<Feature>Api`; call in `<Feature>Repository` returning `ApiResult`.
4. Bind the API in `<Feature>Module` (`retrofit.create(<Feature>Api::class.java)`).
5. Standard headers come from `AuthInterceptor`, never per call. URLs never hardcoded outside `ApiConfig`.

## 9. State rules
- One `UiState` per screen, exposed as `StateFlow`; one-off events (snackbar, navigation) via a `Channel`
  or a state field consumed by the UI.
- No Android framework types (Context, Views) in ViewModels.
- Collect with `collectAsStateWithLifecycle()`.

## 10. Storage
- Settings: `AppPreferences` (DataStore) with `store<Key>()` / `get<Key>()` functions.
- Tokens and secrets: encrypted storage (Android Keystore-backed), never plain preferences.
- Structured or offline data: Room (entities, DAOs) in `core/storage` or the feature's `repository/`.

## 11. Design system
- Colors only from `MaterialTheme.colorScheme` / `core/designsystem/Color.kt`; never hardcoded `Color(0xFF…)`
  in features.
- Typography from `Type.kt`; spacing from `Dimens.kt`; `dp` for sizes, `sp` for text.
- Strings in `res/values/strings.xml` (no hardcoded user-facing text). Content descriptions for icons.
- Tap targets ≥ 48dp.

## 12. Testing
| What | How |
|---|---|
| ViewModel | fake repository + `MainDispatcherRule` + Turbine on `uiState` |
| Repository | MockWebServer or a fake `Api` |
| Models | serialization round trip with `Json` |
| Components / screens | Compose UI tests (`createComposeRule`) for each UI state |
Test sources mirror the main package: `app/src/test/java/<package>/feature/<feature>/…`.

## 13. Placement rules
| Adding | Goes to |
|---|---|
| New feature | `feature/<feature_name>/` (packages above) |
| Endpoint path | `core/config/ApiConfig.kt` |
| Color / typography / spacing | `core/designsystem/` |
| Route | `core/navigation/Routes.kt` + `AppNavHost.kt` |
| Cross-feature composable | `core/ui/component/` |
| Shared API call | `core/network/` or a shared repository in `core/` |
| Feature sub-UI | `feature/<feature>/presentation/component/` |

## 14. New feature checklist
- [ ] 1. Packages under `feature/<feature_name>/`
- [ ] 2. Response and request models
- [ ] 3. Endpoint in `ApiConfig`; function in `<Feature>Api`
- [ ] 4. `<Feature>Repository` returning `ApiResult`
- [ ] 5. `<Feature>Module` (Hilt bindings)
- [ ] 6. `<Feature>UiState` + `<Feature>ViewModel`
- [ ] 7. Components in `presentation/component/` (with previews)
- [ ] 8. `<Feature>Route` + `<Feature>Screen`
- [ ] 9. Destination in `Routes.kt`, registration in `AppNavHost.kt`, navigation from the calling screen
- [ ] 10. Strings, content descriptions
- [ ] 11. Tests (ViewModel, repository, UI states)
- [ ] 12. Feature registry in `aidlc-docs/project-profile.md`

## 15. Commands
```bash
./gradlew assembleDebug            # build
./gradlew lint                     # Android lint
./gradlew testDebugUnitTest        # unit tests
./gradlew connectedDebugAndroidTest   # instrumented/UI tests (device or emulator)
./gradlew ktlintCheck detekt       # only if the project configures them
./gradlew bundleRelease            # release bundle
```

## 16. Dependencies and security
New libraries only through an approved plan, declared in the version catalog. No secrets in code or
committed files (use `local.properties` / CI secrets / build config fields from the environment). R8
enabled for release builds, with keep rules for serialization. Never log tokens or personal data.
