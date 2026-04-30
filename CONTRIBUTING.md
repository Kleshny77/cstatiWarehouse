# Contributing to cstatiWarehouse

Спасибо за интерес к проекту cstatiWarehouse! Мы рады любому вкладу — от исправления опечаток до новых функций.

## Содержание

- [Code of Conduct](#code-of-conduct)
- [Как начать](#как-начать)
- [Процесс разработки](#процесс-разработки)
- [Стандарты кода](#стандарты-кода)
- [Тестирование](#тестирование)
- [Документация](#документация)
- [Pull Request Process](#pull-request-process)
- [Reporting Bugs](#reporting-bugs)
- [Feature Requests](#feature-requests)

## Code of Conduct

Участвуя в проекте, вы соглашаетесь соблюдать наш [Code of Conduct](CODE_OF_CONDUCT.md). Пожалуйста, будьте уважительны и конструктивны в общении.

## Как начать

### Prerequisites

**Backend (Go)**:
- Go 1.21+
- PostgreSQL 15+
- Docker & Docker Compose
- Make

**iOS (Swift)**:
- macOS 13+
- Xcode 15+
- Swift 5.9+
- CocoaPods (опционально)

### Настройка окружения

1. **Fork репозитория**

   Нажмите кнопку "Fork" на GitHub.

2. **Clone your fork**

   ```bash
   git clone https://github.com/YOUR_USERNAME/cstatiWarehouse.git
   cd cstatiWarehouse
   ```

3. **Add upstream remote**

   ```bash
   git remote add upstream https://github.com/cstati/cstatiWarehouse.git
   ```

4. **Backend setup**

   ```bash
   cd backend
   
   # Copy environment file
   cp .env.example .env
   
   # Start PostgreSQL
   docker-compose up -d postgres
   
   # Run migrations
   make migrate-up
   
   # Run tests
   make test
   
   # Start server
   make run
   ```

5. **iOS setup**

   ```bash
   cd ios
   
   # Open in Xcode
   open cstatiWarehouse.xcodeproj
   
   # Build and run (⌘R)
   ```

## Процесс разработки

### 1. Создайте ветку

```bash
# Sync with upstream
git fetch upstream
git checkout main
git merge upstream/main

# Create feature branch
git checkout -b feature/your-feature-name

# Or bugfix branch
git checkout -b fix/bug-description
```

**Naming conventions**:
- `feature/` - новые функции
- `fix/` - исправления багов
- `docs/` - изменения в документации
- `refactor/` - рефакторинг без изменения функциональности
- `test/` - добавление тестов
- `chore/` - обновление зависимостей, конфигурации

### 2. Внесите изменения

Следуйте [стандартам кода](#стандарты-кода) и [архитектурным принципам](Docs/ADR/).

### 3. Commit changes

Используйте [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Format: <type>(<scope>): <subject>

git commit -m "feat(warehouse): добавить фильтрацию по категориям"
git commit -m "fix(auth): исправить утечку JWT токенов"
git commit -m "docs(api): обновить OpenAPI спецификацию"
git commit -m "refactor(repo): упростить запросы к БД"
git commit -m "test(usecase): добавить тесты для WarehouseUseCase"
```

**Types**:
- `feat` - новая функция
- `fix` - исправление бага
- `docs` - изменения в документации
- `style` - форматирование, отсутствующие точки с запятой и т.д.
- `refactor` - рефакторинг кода
- `test` - добавление тестов
- `chore` - обновление задач сборки, конфигурации и т.д.

**Scopes** (примеры):
- `warehouse` - склад
- `auth` - аутентификация
- `org` - организации
- `api` - HTTP API
- `db` - база данных
- `ios` - iOS приложение

### 4. Push changes

```bash
git push origin feature/your-feature-name
```

### 5. Создайте Pull Request

Откройте PR на GitHub с описанием изменений.

## Стандарты кода

### Backend (Go)

#### Code Style

Следуйте [Effective Go](https://golang.org/doc/effective_go) и [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments).

**Форматирование**:

```bash
# Format code
make fmt

# Run linter
make lint

# Fix linter issues
make lint-fix
```

**Naming conventions**:

```go
// ✅ Good
type UserRepository interface { ... }
func (uc *AuthUseCase) Login(ctx context.Context, in LoginInput) { ... }
var ErrUserNotFound = errors.New("user not found")

// ❌ Bad
type userRepo interface { ... }  // Interface должен быть exported
func (uc *AuthUseCase) login(...) { ... }  // Public метод должен начинаться с заглавной
var errUserNotFound = errors.New(...)  // Error должен быть exported
```

**Error handling**:

```go
// ✅ Good - wrap errors with context
if err != nil {
    return fmt.Errorf("failed to create user: %w", err)
}

// ❌ Bad - lose error context
if err != nil {
    return err
}
```

**Comments**:

```go
// ✅ Good - exported functions have comments
// CreateUser creates a new user in the system.
// Returns ErrEmailAlreadyExists if email is taken.
func (uc *AuthUseCase) CreateUser(ctx context.Context, in CreateUserInput) (*domain.User, error) {
    // ...
}

// ❌ Bad - no comment for exported function
func (uc *AuthUseCase) CreateUser(...) { ... }
```

#### Architecture

Следуйте [Clean Architecture](Docs/ADR/ADR-0001-clean-architecture.md):

```
backend/
├── domain/      # Бизнес-сущности (независимы от всего)
├── usecase/     # Use cases + интерфейсы (ports)
├── adapter/     # Реализации интерфейсов (HTTP, DB, etc.)
└── infra/       # Инфраструктурный код
```

**Правила**:
- ✅ `domain/` не зависит ни от чего
- ✅ `usecase/` зависит только от `domain/`
- ✅ `adapter/` реализует интерфейсы из `usecase/`
- ❌ `usecase/` НЕ должен импортировать `adapter/`

#### Database

**Migrations**:

```bash
# Create new migration
make migrate-create name=add_user_avatar

# Run migrations
make migrate-up

# Rollback
make migrate-down
```

**SQL queries**:

```go
// ✅ Good - parameterized queries
const query = `SELECT * FROM users WHERE email = $1`
row := db.QueryRow(ctx, query, email)

// ❌ Bad - SQL injection vulnerability
query := fmt.Sprintf("SELECT * FROM users WHERE email = '%s'", email)
```

### iOS (Swift)

#### Code Style

Следуйте [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).

**Форматирование**:

```swift
// ✅ Good
func fetchItems(
    organizationID: UUID,
    scope: WarehouseScope,
    completion: @escaping (Result<[Item], Error>) -> Void
) {
    // ...
}

// ❌ Bad - слишком длинная строка
func fetchItems(organizationID: UUID, scope: WarehouseScope, completion: @escaping (Result<[Item], Error>) -> Void) { ... }
```

**Naming**:

```swift
// ✅ Good
protocol WarehouseServiceProtocol { ... }
final class ApiWarehouseService: WarehouseServiceProtocol { ... }
enum WarehouseError: Error { ... }

// ❌ Bad
protocol WarehouseService { ... }  // Protocol должен иметь суффикс Protocol
class WarehouseService { ... }  // Не final
enum WarehouseErr { ... }  // Используйте полное слово Error
```

**File headers**:

```swift
//
//  FileName.swift
//  cstatiWarehouse
//
//  Created by Артём on DD.MM.YYYY.
//

import Foundation
```

#### Architecture

Следуйте VIPER-like архитектуре:

```
Scenes/
└── MyWarehouse/
    ├── MyWarehouseAssembly.swift      # Dependency injection
    ├── MyWarehouseView.swift          # SwiftUI View
    ├── MyWarehousePresenter.swift     # Presentation logic
    ├── MyWarehouseInteractor.swift    # Business logic
    └── MyWarehouseRouter.swift        # Navigation
```

**Правила**:
- ✅ View зависит только от Presenter
- ✅ Presenter зависит от Interactor и Router
- ✅ Interactor зависит от Services
- ❌ View НЕ должен напрямую вызывать Services

#### SwiftUI

```swift
// ✅ Good - @Observable для iOS 17+
@Observable
final class MyPresenter {
    var items: [Item] = []
}

struct MyView: View {
    @Bindable var presenter: MyPresenter
    
    var body: some View {
        List(presenter.items) { item in
            Text(item.name)
        }
    }
}

// ❌ Bad - @Published для iOS 17+ (используйте @Observable)
class MyPresenter: ObservableObject {
    @Published var items: [Item] = []
}
```

## Тестирование

### Backend Tests

**Unit tests** (use cases):

```go
func TestWarehouseUseCase_Create(t *testing.T) {
    // Arrange
    repo := &FakeItemRepo{}
    uc := usecase.NewWarehouseUseCase(repo)
    input := usecase.CreateItemInput{
        Name:     "Test Item",
        Quantity: 10,
    }
    
    // Act
    item, err := uc.Create(context.Background(), input)
    
    // Assert
    assert.NoError(t, err)
    assert.NotNil(t, item)
    assert.Equal(t, "Test Item", item.Name)
}
```

**Integration tests** (repositories):

```go
func TestItemRepo_Create(t *testing.T) {
    // Setup test database
    db := setupTestDB(t)
    defer db.Close()
    
    repo := repo.NewItemRepo(db)
    
    // Test
    item := &domain.Item{
        ID:   uuid.New(),
        Name: "Test Item",
    }
    
    err := repo.Create(context.Background(), item)
    assert.NoError(t, err)
}
```

**Run tests**:

```bash
# All tests
make test

# With coverage
make test-coverage

# Specific package
go test ./internal/usecase/...

# Verbose
go test -v ./...
```

### iOS Tests

**Unit tests** (Presenters):

```swift
func testLoadItems_Success() {
    // Arrange
    let interactor = FakeMyWarehouseInteractor()
    let presenter = MyWarehousePresenter(interactor: interactor)
    
    // Act
    presenter.viewDidLoad()
    
    // Assert
    XCTAssertEqual(presenter.items.count, 2)
    XCTAssertFalse(presenter.isLoading)
}
```

**Run tests**:

```bash
# In Xcode: ⌘U

# Or via command line
xcodebuild test \
    -scheme cstatiWarehouse \
    -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Test Coverage

Стремитесь к покрытию:
- **Use cases / Interactors**: > 80%
- **Repositories / Services**: > 70%
- **Handlers / Views**: > 50%

## Документация

### Code Documentation

**Go**:

```go
// CreateUser creates a new user account.
//
// Parameters:
//   - ctx: Request context
//   - in: User creation input
//
// Returns:
//   - *domain.User: Created user
//   - error: ErrEmailAlreadyExists if email is taken
func (uc *AuthUseCase) CreateUser(ctx context.Context, in CreateUserInput) (*domain.User, error) {
    // ...
}
```

**Swift**:

```swift
/// Loads warehouse items for the specified organization.
///
/// - Parameters:
///   - organizationID: The organization identifier
///   - scope: Active or history scope
///   - completion: Completion handler with result
func loadItems(
    organizationID: UUID,
    scope: WarehouseScope,
    completion: @escaping (Result<[Item], Error>) -> Void
) {
    // ...
}
```

### Architecture Decision Records

Для значимых архитектурных решений создайте [ADR](Docs/ADR/):

```bash
# Create new ADR
cp Docs/ADR/template.md Docs/ADR/ADR-0042-your-decision.md

# Edit and commit
git add Docs/ADR/ADR-0042-your-decision.md
git commit -m "docs(adr): add ADR-0042 for your decision"
```

### API Documentation

Обновите [OpenAPI спецификацию](Docs/OpenAPI-Swagger-Documentation.md):

```go
// CreateItem godoc
// @Summary Создание позиции
// @Description Создает новую позицию на складе
// @Tags warehouse
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body createItemRequest true "Данные позиции"
// @Success 201 {object} itemDTO "Созданная позиция"
// @Router /items [post]
func (h *WarehouseHandler) CreateItem(w http.ResponseWriter, r *http.Request) {
    // ...
}
```

Затем регенерируйте документацию:

```bash
cd backend
make swagger
```

## Pull Request Process

### 1. Checklist перед созданием PR

- [ ] Код следует стандартам проекта
- [ ] Все тесты проходят (`make test` / `⌘U`)
- [ ] Добавлены новые тесты для новой функциональности
- [ ] Документация обновлена (если нужно)
- [ ] Нет конфликтов с `main` веткой
- [ ] Commit messages следуют Conventional Commits
- [ ] PR description заполнено

### 2. PR Template

```markdown
## Описание
[Краткое описание изменений]

## Тип изменений
- [ ] Bug fix (исправление бага)
- [ ] New feature (новая функция)
- [ ] Breaking change (изменение, ломающее обратную совместимость)
- [ ] Documentation update (обновление документации)

## Как протестировать
1. [Шаг 1]
2. [Шаг 2]
3. [Ожидаемый результат]

## Checklist
- [ ] Код следует стандартам проекта
- [ ] Все тесты проходят
- [ ] Добавлены новые тесты
- [ ] Документация обновлена
- [ ] Нет breaking changes (или они задокументированы)

## Скриншоты (если применимо)
[Добавьте скриншоты для UI изменений]

## Связанные issues
Closes #123
Related to #456
```

### 3. Code Review

Ваш PR будет проверен maintainer'ами. Ожидайте:

- **Feedback** - конструктивные комментарии
- **Requests for changes** - запросы на изменения
- **Approval** - одобрение от минимум 1 maintainer

**Как отвечать на review**:

```bash
# Make requested changes
git add .
git commit -m "fix: address review comments"
git push origin feature/your-feature-name
```

### 4. Merge

После approval ваш PR будет смержен maintainer'ом.

## Reporting Bugs

### Перед созданием issue

1. **Проверьте existing issues** - возможно, баг уже reported
2. **Убедитесь, что это баг** - не expected behavior
3. **Соберите информацию** - версия, OS, шаги воспроизведения

### Bug Report Template

```markdown
**Описание бага**
[Четкое описание проблемы]

**Шаги воспроизведения**
1. Перейти на '...'
2. Нажать на '...'
3. Прокрутить до '...'
4. Увидеть ошибку

**Ожидаемое поведение**
[Что должно было произойти]

**Фактическое поведение**
[Что произошло на самом деле]

**Скриншоты**
[Если применимо]

**Окружение**
- OS: [e.g. iOS 17.0, macOS 14.0]
- Backend version: [e.g. 1.2.3]
- iOS app version: [e.g. 1.0.5]
- Device: [e.g. iPhone 15 Pro]

**Дополнительный контекст**
[Любая другая информация]

**Логи**
```
[Вставьте логи, если есть]
```
```

## Feature Requests

### Feature Request Template

```markdown
**Описание функции**
[Четкое описание желаемой функции]

**Проблема, которую решает**
[Какую проблему решает эта функция]

**Предлагаемое решение**
[Как вы видите реализацию]

**Альтернативы**
[Рассмотренные альтернативы]

**Дополнительный контекст**
[Скриншоты, mockups, примеры из других приложений]

**Приоритет**
- [ ] High (критично для работы)
- [ ] Medium (важно, но не критично)
- [ ] Low (nice to have)
```

## Development Workflow

### Daily Workflow

```bash
# 1. Sync with upstream
git fetch upstream
git checkout main
git merge upstream/main

# 2. Create feature branch
git checkout -b feature/my-feature

# 3. Make changes
# ... code ...

# 4. Run tests
make test  # Backend
# ⌘U in Xcode  # iOS

# 5. Commit
git add .
git commit -m "feat(scope): description"

# 6. Push
git push origin feature/my-feature

# 7. Create PR on GitHub
```

### Keeping PR Updated

```bash
# Rebase on main
git fetch upstream
git rebase upstream/main

# Resolve conflicts if any
git add .
git rebase --continue

# Force push (PR will update automatically)
git push origin feature/my-feature --force-with-lease
```

## Getting Help

- **Documentation**: [Docs/](Docs/)
- **Discussions**: [GitHub Discussions](https://github.com/cstati/cstatiWarehouse/discussions)
- **Issues**: [GitHub Issues](https://github.com/cstati/cstatiWarehouse/issues)
- **Email**: dev@cstati-warehouse.app

## Recognition

Contributors will be recognized in:
- [CONTRIBUTORS.md](CONTRIBUTORS.md)
- Release notes
- GitHub contributors page

Спасибо за ваш вклад! 🎉
