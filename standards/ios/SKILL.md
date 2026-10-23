---
name: project-architecture
description: Native iOS house architecture standard: Swift, SwiftUI, MVVM with Observation, async/await, URLSession APIClient, Codable models, Keychain/UserDefaults/SwiftData storage, NavigationStack router, feature-first folders that mirror the Flutter house standard. MANDATORY: read it before planning or writing any code, and use it to place every new feature, screen and component.
---
<!-- aidlc-kit:standard=ios · house standard v1 (PROPOSED, review before first use) · project-owned copy: init-project.sh never overwrites it (use --update-architecture) -->

# Native iOS Architecture: House Standard

> **⚠️ CRITICAL**: Read and follow this standard before writing any code, creating any file or modifying
> any module. Workflow rules: `.agents/rules/00-aidlc-core.md` and `.agents/rules/10-quality-gates.md`.
> **Status: proposed v1.** It mirrors the Flutter house standard so every project looks alike. Adapt names
> to the actual project and record approved deviations in `aidlc-docs/project-profile.md`.

## 1. Stack

| Layer | Technology |
|---|---|
| Language | Swift (current stable; Swift 6 language mode when the project allows) |
| UI | SwiftUI |
| Presentation pattern | MVVM: `@Observable` view models (iOS 17+), `ObservableObject` for iOS 16 and lower |
| Concurrency | async/await, `@MainActor` view models |
| Networking | `APIClient` on `URLSession` (use Alamofire only if the project already does) |
| Models | `Codable` structs |
| Storage | Keychain (tokens), `UserDefaults` wrapper (settings), SwiftData (iOS 17+) or Core Data (structured data) |
| Navigation | `NavigationStack` + `Router` + `Route` enum |
| Dependencies | Swift Package Manager |
| Lint / format | SwiftLint / swift-format, only if the project configures them |
| Testing | Swift Testing (`@Test`) or XCTest, as the project uses; XCUITest for main flows |

Before any work, read `aidlc-docs/project-profile.md` (run `.agents/skills/project-analysis/SKILL.md` if missing).

## 2. Mapping from the Flutter house standard

| Flutter folder | iOS folder | Holds |
|---|---|---|
| `controller/` | `ViewModel/` | `<Feature>ViewModel` |
| `model/request/` | `Model/Request/` | `<Name>Request: Encodable` |
| `model/response/` | `Model/Response/` | `<Name>Response: Decodable` |
| `presentation/page/` | `View/Screen/` | `<Feature>Screen` |
| `presentation/component/` | `View/Component/` | one `View` struct per file |
| `provider/` | `App/AppEnvironment.swift` | shared services and view-model factories (initializer injection) |
| `repository/` | `Repository/` | `<Feature>Repository` protocol + `Live<Feature>Repository` |

## 3. Project structure

```
<AppName>/
├── App/
│   ├── <AppName>App.swift        # @main; creates AppEnvironment and RootView
│   ├── AppEnvironment.swift      # APIClient, storage, SessionManager; make<Feature>ViewModel() factories
│   └── RootView.swift            # NavigationStack(path:) + navigationDestination(for: Route.self)
├── Core/
│   ├── Config/        APIConfig.swift (base URL per build configuration, endpoint paths), AppConstants.swift
│   ├── Network/       APIClient.swift, Endpoint.swift, APIError.swift, AuthHeaderProvider.swift
│   ├── Storage/       KeychainStore.swift, UserDefaultsStore.swift, Persistence.swift (SwiftData, if used)
│   ├── DesignSystem/  AppColor.swift, AppFont.swift, Spacing.swift
│   ├── Components/    PrimaryButton.swift, InputTextField.swift, LoadingView.swift, ErrorView.swift
│   ├── Navigation/    Route.swift, Router.swift
│   ├── Session/       SessionManager.swift (logout on 401)
│   └── Utilities/
├── Features/
│   └── <FeatureName>/
│       ├── ViewModel/        <Feature>ViewModel.swift
│       ├── Model/Request/    <Name>Request.swift
│       ├── Model/Response/   <Name>Response.swift
│       ├── View/Screen/      <Feature>Screen.swift
│       ├── View/Component/   <Feature><Part>.swift
│       └── Repository/       <Feature>Repository.swift
└── Resources/         Assets.xcassets (colors, images), Localizable.xcstrings
<AppName>Tests/        mirrors Features/ and Core/
```
UI-only features may leave out `Model/` and `Repository/`. Never invent other folder names.

## 4. Data flow

```
Screen ──.task / actions──► ViewModel (@MainActor) ──async──► Repository ──► APIClient ──► server
   ▲                              │                               │
   └──── observed state ◄─────────┘◄──── value or thrown APIError ◄┘
```
1. The screen owns its view model and calls `load()` in `.task`; it renders `viewModel.state`.
2. The view model calls the repository, catches every error and maps it to a state. Nothing throws into the view.
3. The repository builds an `Endpoint` and calls the `APIClient`, which adds the standard headers and maps
   HTTP errors to `APIError`.

## 5. Naming

| Type | Pattern | Example |
|---|---|---|
| Feature folder | PascalCase | `Features/BudgetAlerts/` |
| View model | `<Feature>ViewModel` | `HomeViewModel` |
| Repository | `<Feature>Repository` (protocol), `Live<Feature>Repository` | `LiveHomeRepository` |
| Request / response | `<Name>Request` / `<Name>Response` | `LoginRequest` / `HomeConfigResponse` |
| Screen | `<Feature>Screen` | `HomeScreen` |
| Component | `<Feature><Part>` | `HomeHeader` |
| Route case | lowerCamelCase in `Route` | `.budgetDetail(id:)` |
| Files | named after the main type (Swift convention, PascalCase) | `HomeViewModel.swift` |

## 6. Patterns

### 6.1 Endpoint, APIClient and errors
```swift
struct Endpoint {
    var path: String
    var method: String = "GET"
    var body: (any Encodable)? = nil
}

enum APIError: Error, Equatable {
    case network
    case unauthorized          // 401 → SessionManager logs out
    case server(code: Int, message: String?)
    case decoding
    case unknown(String?)
}

protocol APIClient {
    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
}

final class LiveAPIClient: APIClient {
    private let session: URLSession
    private let baseURL: URL
    private let headers: AuthHeaderProvider

    init(session: URLSession = .shared, baseURL: URL, headers: AuthHeaderProvider) {
        self.session = session
        self.baseURL = baseURL
        self.headers = headers
    }

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: endpoint.path))
        request.httpMethod = endpoint.method
        headers.apply(to: &request)                       // Authorization, module, Content-Type
        if let body = endpoint.body { request.httpBody = try JSONEncoder().encode(body) }

        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) } catch { throw APIError.network }

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown(nil) }
        switch http.statusCode {
        case 200..<300:
            do { return try JSONDecoder().decode(T.self, from: data) } catch { throw APIError.decoding }
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.server(code: http.statusCode, message: String(data: data, encoding: .utf8))
        }
    }
}
```

### 6.2 Repository
```swift
protocol <Feature>Repository {
    func fetchData() async throws -> <Name>Response
}

struct Live<Feature>Repository: <Feature>Repository {
    let client: APIClient

    func fetchData() async throws -> <Name>Response {
        try await client.send(Endpoint(path: APIConfig.<endpointPath>), as: <Name>Response.self)
    }
}
```

### 6.3 View model
```swift
@MainActor
@Observable
final class <Feature>ViewModel {
    enum State: Equatable {
        case loading, empty, data([Item]), error(String)
    }

    private(set) var state: State = .loading
    private let repository: <Feature>Repository

    init(repository: <Feature>Repository) {
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            let response = try await repository.fetchData()
            let items = response.payload?.items ?? []
            state = items.isEmpty ? .empty : .data(items)
        } catch {
            state = .error(String(localized: "error.generic"))
        }
    }
}
```
iOS 16 and lower: `final class <Feature>ViewModel: ObservableObject` with `@Published private(set) var state`.

### 6.4 Models
```swift
struct <Name>Request: Encodable {
    let fieldOne: String
    let fieldTwo: String?          // nil values are left out of the JSON

    enum CodingKeys: String, CodingKey {
        case fieldOne = "field_one"
        case fieldTwo = "field_two"
    }
}

struct <Name>Response: Decodable {
    let isSuccess: Bool?
    let statusCode: Int?
    let message: String?
    let payload: <Payload>?

    enum CodingKeys: String, CodingKey {
        case isSuccess = "issuccess", statusCode, message, payload
    }
}
```

### 6.5 Screen and components (no view-builder helpers in screens)
> **STRICT RULE:** a screen only lays out the navigation bar, state switching, refresh and composition.
> Every sub-UI (cards, rows, filters, sheets) is its own `View` struct in `View/Component/`, one per file,
> with a `#Preview`. No `@ViewBuilder` helper functions or computed `some View` properties in screens.

```swift
struct <Feature>Screen: View {
    @State private var viewModel: <Feature>ViewModel   // iOS 16: @StateObject
    private let onOpenDetail: (Item.ID) -> Void

    init(viewModel: <Feature>ViewModel, onOpenDetail: @escaping (Item.ID) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onOpenDetail = onOpenDetail
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading: LoadingView()
            case .empty: <Feature>EmptyState()
            case .error(let message): ErrorView(message: message) { Task { await viewModel.load() } }
            case .data(let items): <Feature>List(items: items, onSelect: onOpenDetail)
            }
        }
        .navigationTitle(String(localized: "<feature>.title"))
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

struct <Feature>Card: View {
    let title: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(title).font(AppFont.body)
                Spacer()
                Image(systemName: "chevron.right").accessibilityHidden(true)
            }
            .padding(Spacing.m)
        }
        .buttonStyle(.plain)
    }
}

#Preview { <Feature>Card(title: "Title", onTap: {}) }
```

## 7. Navigation
```swift
enum Route: Hashable {
    case <feature>
    case <feature>Detail(id: String)
}

@MainActor
@Observable
final class Router {
    var path = NavigationPath()
    func push(_ route: Route) { path.append(route) }
    func popToRoot() { path = NavigationPath() }
}
```
1. Add a case to `Route`.
2. Map it in `RootView`'s `.navigationDestination(for: Route.self)` using `AppEnvironment` factories.
3. Screens never touch the router directly; they receive closures (`onOpenDetail`).
4. Pass IDs, not objects; the destination's view model loads the data.

## 8. API integration
1. Add the endpoint path to `APIConfig`.
2. Request/response models in the feature's `Model/` folders.
3. Method in the `<Feature>Repository` protocol + `Live…` implementation.
4. Factory in `AppEnvironment` (`make<Feature>ViewModel()`).
5. Standard headers come from `AuthHeaderProvider` only. Never hardcode URLs outside `APIConfig`.

## 9. State rules
- One `State` enum per screen covering loading, empty, data and error.
- View models are `@MainActor`, hold no SwiftUI views, and get dependencies through `init`.
- Long work runs in `Task`/async functions, never blocking the main actor.

## 10. Storage
- Tokens and secrets: `KeychainStore`. Never `UserDefaults`.
- Settings: `UserDefaultsStore` with `store<Key>()` / `get<Key>()` methods.
- Structured or offline data: SwiftData (iOS 17+) or Core Data.

## 11. Design system
- Colors from the asset catalog through `AppColor` (e.g. `static let primary = Color("Primary")`). Never
  `Color(red:green:blue:)` or hex values in features.
- Fonts through `AppFont`, supporting Dynamic Type. Spacing from `Spacing`.
- User-facing text in `Localizable.xcstrings`. Accessibility labels for icon-only buttons; tap targets ≥ 44pt.

## 12. Testing
| What | How |
|---|---|
| View model | fake repository (a struct conforming to the protocol); check each state |
| APIClient | `URLProtocol` stub; status codes → `APIError` |
| Models | decode sample JSON, encode requests |
| Main flows | XCUITest, few and focused |

```swift
import Testing
@testable import <AppName>

struct Fake<Feature>Repository: <Feature>Repository {
    var result: Result<<Name>Response, Error>
    func fetchData() async throws -> <Name>Response { try result.get() }
}

@MainActor
struct <Feature>ViewModelTests {
    @Test func showsErrorWhenTheRequestFails() async {
        let viewModel = <Feature>ViewModel(repository: Fake<Feature>Repository(result: .failure(APIError.network)))
        await viewModel.load()
        guard case .error = viewModel.state else {
            Issue.record("expected the error state")
            return
        }
    }
}
```

## 13. Placement rules
| Adding | Goes to |
|---|---|
| New feature | `Features/<FeatureName>/` (folders above) |
| Endpoint path | `Core/Config/APIConfig.swift` |
| Color / font / spacing | `Core/DesignSystem/` + asset catalog |
| Route | `Core/Navigation/Route.swift` + `RootView` |
| Cross-feature view | `Core/Components/` |
| Shared service | `Core/` + `AppEnvironment` |
| Feature sub-UI | `Features/<FeatureName>/View/Component/` |

## 14. New feature checklist
- [ ] 1. Folders under `Features/<FeatureName>/`
- [ ] 2. Response and request models
- [ ] 3. Endpoint path in `APIConfig`
- [ ] 4. Repository protocol + live implementation
- [ ] 5. View model with a `State` enum
- [ ] 6. Components in `View/Component/` (with previews)
- [ ] 7. Screen in `View/Screen/`
- [ ] 8. `Route` case, destination in `RootView`, factory in `AppEnvironment`, navigation from the caller
- [ ] 9. Strings in the string catalog; accessibility labels
- [ ] 10. Tests (view model states, models)
- [ ] 11. Feature registry in `aidlc-docs/project-profile.md`

## 15. Commands
```bash
xcodebuild -scheme <App> -destination 'platform=iOS Simulator,name=<iPhone model>' build
xcodebuild -scheme <App> -destination 'platform=iOS Simulator,name=<iPhone model>' test
swiftlint          # only if configured
swift test         # Swift packages
```

## 16. Dependencies and security
New packages only through an approved plan, added with SPM ("up to next major" rules). No secrets in code
or committed files (use git-ignored `.xcconfig` files or CI secrets). Keep App Transport Security on.
Tokens in the Keychain. Never log tokens or personal data.
