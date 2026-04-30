# Internationalization (i18n) — English Localization

## Overview

This document describes the strategy for adding English language support to cstatiWarehouse iOS app while maintaining Russian as the default language.

## Current State

- **Default Language**: Russian (ru_RU)
- **All UI Text**: Hardcoded Russian strings in SwiftUI views
- **Date Formatting**: Russian locale
- **Number Formatting**: Russian decimal separators

## Implementation Strategy

### 1. iOS Localization Setup

#### 1.1 Add Localizable.strings Files

Create two localization files:

**`ios/cstatiWarehouse/Resources/ru.lproj/Localizable.strings`** (Russian - default):
```swift
/* Authentication */
"auth.login.title" = "Вход";
"auth.login.email" = "Email";
"auth.login.password" = "Пароль";
"auth.login.button" = "Войти";
"auth.register.title" = "Регистрация";
"auth.register.name" = "Имя";
"auth.telegram.button" = "Войти через Telegram";
"auth.google.button" = "Войти через Google";

/* Warehouse */
"warehouse.title" = "Мой склад";
"warehouse.scope.active" = "Активные";
"warehouse.scope.history" = "История";
"warehouse.search.placeholder" = "Поиск по названию";
"warehouse.empty.active.title" = "Склад пуст";
"warehouse.empty.active.subtitle" = "Добавьте первую позицию";
"warehouse.empty.history.title" = "История пуста";
"warehouse.empty.history.subtitle" = "Архивированные позиции появятся здесь";
"warehouse.add.button" = "Добавить";
"warehouse.filter.button" = "Фильтры";
"warehouse.archive.button" = "История архивации";

/* Item Details */
"item.quantity" = "Количество";
"item.category" = "Категория";
"item.expiresAt" = "Срок годности";
"item.location" = "Местоположение";
"item.notes" = "Заметки";
"item.packaging" = "Фасовка";
"item.unit.pieces" = "шт";
"item.unit.kg" = "кг";
"item.unit.liters" = "л";
"item.unit.ml" = "мл";

/* Archive Reasons */
"archive.reason.sold" = "Продано";
"archive.reason.expired" = "Истёк срок годности";
"archive.reason.damaged" = "Повреждено";
"archive.reason.lost" = "Утеряно";
"archive.reason.returned" = "Возврат";
"archive.reason.other" = "Другое";

/* Organization */
"org.title" = "Организация";
"org.members" = "Участники";
"org.create.title" = "Создать организацию";
"org.join.title" = "Присоединиться";
"org.invite.code" = "Код приглашения";
"org.role.owner" = "Владелец";
"org.role.admin" = "Администратор";
"org.role.member" = "Участник";

/* Settings */
"settings.title" = "Настройки";
"settings.profile" = "Профиль";
"settings.language" = "Язык";
"settings.notifications" = "Уведомления";
"settings.logout" = "Выйти";

/* Common */
"common.save" = "Сохранить";
"common.cancel" = "Отмена";
"common.delete" = "Удалить";
"common.edit" = "Редактировать";
"common.done" = "Готово";
"common.error" = "Ошибка";
"common.loading" = "Загрузка...";
"common.retry" = "Повторить";

/* Errors */
"error.network" = "Ошибка сети";
"error.unauthorized" = "Требуется авторизация";
"error.notFound" = "Не найдено";
"error.serverError" = "Ошибка сервера";
"error.unknown" = "Неизвестная ошибка";
```

**`ios/cstatiWarehouse/Resources/en.lproj/Localizable.strings`** (English):
```swift
/* Authentication */
"auth.login.title" = "Login";
"auth.login.email" = "Email";
"auth.login.password" = "Password";
"auth.login.button" = "Sign In";
"auth.register.title" = "Sign Up";
"auth.register.name" = "Name";
"auth.telegram.button" = "Sign in with Telegram";
"auth.google.button" = "Sign in with Google";

/* Warehouse */
"warehouse.title" = "My Warehouse";
"warehouse.scope.active" = "Active";
"warehouse.scope.history" = "History";
"warehouse.search.placeholder" = "Search by name";
"warehouse.empty.active.title" = "Warehouse is empty";
"warehouse.empty.active.subtitle" = "Add your first item";
"warehouse.empty.history.title" = "History is empty";
"warehouse.empty.history.subtitle" = "Archived items will appear here";
"warehouse.add.button" = "Add";
"warehouse.filter.button" = "Filters";
"warehouse.archive.button" = "Archive History";

/* Item Details */
"item.quantity" = "Quantity";
"item.category" = "Category";
"item.expiresAt" = "Expiration Date";
"item.location" = "Location";
"item.notes" = "Notes";
"item.packaging" = "Packaging";
"item.unit.pieces" = "pcs";
"item.unit.kg" = "kg";
"item.unit.liters" = "L";
"item.unit.ml" = "ml";

/* Archive Reasons */
"archive.reason.sold" = "Sold";
"archive.reason.expired" = "Expired";
"archive.reason.damaged" = "Damaged";
"archive.reason.lost" = "Lost";
"archive.reason.returned" = "Returned";
"archive.reason.other" = "Other";

/* Organization */
"org.title" = "Organization";
"org.members" = "Members";
"org.create.title" = "Create Organization";
"org.join.title" = "Join";
"org.invite.code" = "Invite Code";
"org.role.owner" = "Owner";
"org.role.admin" = "Admin";
"org.role.member" = "Member";

/* Settings */
"settings.title" = "Settings";
"settings.profile" = "Profile";
"settings.language" = "Language";
"settings.notifications" = "Notifications";
"settings.logout" = "Sign Out";

/* Common */
"common.save" = "Save";
"common.cancel" = "Cancel";
"common.delete" = "Delete";
"common.edit" = "Edit";
"common.done" = "Done";
"common.error" = "Error";
"common.loading" = "Loading...";
"common.retry" = "Retry";

/* Errors */
"error.network" = "Network error";
"error.unauthorized" = "Authorization required";
"error.notFound" = "Not found";
"error.serverError" = "Server error";
"error.unknown" = "Unknown error";
```

#### 1.2 Xcode Project Configuration

1. Open `cstatiWarehouse.xcodeproj`
2. Select project → Info → Localizations
3. Add English (en) localization
4. Ensure Russian (ru) is set as Development Language

#### 1.3 String Localization Helper

Create `ios/cstatiWarehouse/Utilities/Localization.swift`:

```swift
//
//  Localization.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

/// Localization helper for accessing localized strings
enum L10n {
    // MARK: - Authentication
    enum Auth {
        enum Login {
            static let title = NSLocalizedString("auth.login.title", comment: "")
            static let email = NSLocalizedString("auth.login.email", comment: "")
            static let password = NSLocalizedString("auth.login.password", comment: "")
            static let button = NSLocalizedString("auth.login.button", comment: "")
        }
        
        enum Register {
            static let title = NSLocalizedString("auth.register.title", comment: "")
            static let name = NSLocalizedString("auth.register.name", comment: "")
        }
        
        static let telegramButton = NSLocalizedString("auth.telegram.button", comment: "")
        static let googleButton = NSLocalizedString("auth.google.button", comment: "")
    }
    
    // MARK: - Warehouse
    enum Warehouse {
        static let title = NSLocalizedString("warehouse.title", comment: "")
        
        enum Scope {
            static let active = NSLocalizedString("warehouse.scope.active", comment: "")
            static let history = NSLocalizedString("warehouse.scope.history", comment: "")
        }
        
        static let searchPlaceholder = NSLocalizedString("warehouse.search.placeholder", comment: "")
        static let addButton = NSLocalizedString("warehouse.add.button", comment: "")
        static let filterButton = NSLocalizedString("warehouse.filter.button", comment: "")
        static let archiveButton = NSLocalizedString("warehouse.archive.button", comment: "")
        
        enum Empty {
            enum Active {
                static let title = NSLocalizedString("warehouse.empty.active.title", comment: "")
                static let subtitle = NSLocalizedString("warehouse.empty.active.subtitle", comment: "")
            }
            
            enum History {
                static let title = NSLocalizedString("warehouse.empty.history.title", comment: "")
                static let subtitle = NSLocalizedString("warehouse.empty.history.subtitle", comment: "")
            }
        }
    }
    
    // MARK: - Item
    enum Item {
        static let quantity = NSLocalizedString("item.quantity", comment: "")
        static let category = NSLocalizedString("item.category", comment: "")
        static let expiresAt = NSLocalizedString("item.expiresAt", comment: "")
        static let location = NSLocalizedString("item.location", comment: "")
        static let notes = NSLocalizedString("item.notes", comment: "")
        static let packaging = NSLocalizedString("item.packaging", comment: "")
        
        enum Unit {
            static let pieces = NSLocalizedString("item.unit.pieces", comment: "")
            static let kg = NSLocalizedString("item.unit.kg", comment: "")
            static let liters = NSLocalizedString("item.unit.liters", comment: "")
            static let ml = NSLocalizedString("item.unit.ml", comment: "")
        }
    }
    
    // MARK: - Archive Reasons
    enum ArchiveReason {
        static let sold = NSLocalizedString("archive.reason.sold", comment: "")
        static let expired = NSLocalizedString("archive.reason.expired", comment: "")
        static let damaged = NSLocalizedString("archive.reason.damaged", comment: "")
        static let lost = NSLocalizedString("archive.reason.lost", comment: "")
        static let returned = NSLocalizedString("archive.reason.returned", comment: "")
        static let other = NSLocalizedString("archive.reason.other", comment: "")
    }
    
    // MARK: - Organization
    enum Organization {
        static let title = NSLocalizedString("org.title", comment: "")
        static let members = NSLocalizedString("org.members", comment: "")
        
        enum Create {
            static let title = NSLocalizedString("org.create.title", comment: "")
        }
        
        enum Join {
            static let title = NSLocalizedString("org.join.title", comment: "")
        }
        
        static let inviteCode = NSLocalizedString("org.invite.code", comment: "")
        
        enum Role {
            static let owner = NSLocalizedString("org.role.owner", comment: "")
            static let admin = NSLocalizedString("org.role.admin", comment: "")
            static let member = NSLocalizedString("org.role.member", comment: "")
        }
    }
    
    // MARK: - Settings
    enum Settings {
        static let title = NSLocalizedString("settings.title", comment: "")
        static let profile = NSLocalizedString("settings.profile", comment: "")
        static let language = NSLocalizedString("settings.language", comment: "")
        static let notifications = NSLocalizedString("settings.notifications", comment: "")
        static let logout = NSLocalizedString("settings.logout", comment: "")
    }
    
    // MARK: - Common
    enum Common {
        static let save = NSLocalizedString("common.save", comment: "")
        static let cancel = NSLocalizedString("common.cancel", comment: "")
        static let delete = NSLocalizedString("common.delete", comment: "")
        static let edit = NSLocalizedString("common.edit", comment: "")
        static let done = NSLocalizedString("common.done", comment: "")
        static let error = NSLocalizedString("common.error", comment: "")
        static let loading = NSLocalizedString("common.loading", comment: "")
        static let retry = NSLocalizedString("common.retry", comment: "")
    }
    
    // MARK: - Errors
    enum Error {
        static let network = NSLocalizedString("error.network", comment: "")
        static let unauthorized = NSLocalizedString("error.unauthorized", comment: "")
        static let notFound = NSLocalizedString("error.notFound", comment: "")
        static let serverError = NSLocalizedString("error.serverError", comment: "")
        static let unknown = NSLocalizedString("error.unknown", comment: "")
    }
}
```

### 2. Language Switching Implementation

#### 2.1 Language Preference Storage

Create `ios/cstatiWarehouse/Services/Localization/LanguagePreference.swift`:

```swift
//
//  LanguagePreference.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case english = "en"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .russian: return "Русский"
        case .english: return "English"
        }
    }
    
    var locale: Locale {
        switch self {
        case .russian: return Locale(identifier: "ru_RU")
        case .english: return Locale(identifier: "en_US")
        }
    }
}

final class LanguagePreferenceStorage {
    private let userDefaults: UserDefaults
    private let key = "app.language.preference"
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    var currentLanguage: AppLanguage {
        get {
            guard let rawValue = userDefaults.string(forKey: key),
                  let language = AppLanguage(rawValue: rawValue) else {
                return .russian // Default
            }
            return language
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: key)
            applyLanguage(newValue)
        }
    }
    
    private func applyLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
}
```

#### 2.2 Settings Integration

Add language picker to `SettingsView.swift`:

```swift
Section {
    Picker("Язык / Language", selection: $presenter.selectedLanguage) {
        ForEach(AppLanguage.allCases) { language in
            Text(language.displayName).tag(language)
        }
    }
    .onChange(of: presenter.selectedLanguage) { _, newLanguage in
        presenter.changeLanguage(newLanguage)
    }
} header: {
    Text("Локализация")
}
```

### 3. Date and Number Formatting

#### 3.1 Locale-Aware Formatters

Update `Date+Formatters.swift` to use current locale:

```swift
extension Date {
    static var currentLocale: Locale {
        // Get from LanguagePreferenceStorage
        let languageStorage = LanguagePreferenceStorage()
        return languageStorage.currentLanguage.locale
    }
    
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.dateStyle = .short
        return formatter
    }()
    
    static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.dateStyle = .medium
        return formatter
    }()
}
```

#### 3.2 Number Formatting

Create locale-aware number formatters:

```swift
extension NumberFormatter {
    static func decimal(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }
}
```

### 4. Backend i18n Support (Optional)

For server-side localization (error messages, notifications):

#### 4.1 Accept-Language Header

Backend already receives `Accept-Language` header from iOS:

```swift
// In APIClient.swift
var request = URLRequest(url: url)
request.setValue(Locale.current.languageCode, forHTTPHeaderField: "Accept-Language")
```

#### 4.2 Backend Response Localization

Create `backend/internal/infra/i18n/messages.go`:

```go
package i18n

import "golang.org/x/text/language"

type Messages struct {
    lang language.Tag
}

func New(acceptLanguage string) *Messages {
    tag, _ := language.MatchStrings(
        language.NewMatcher([]language.Tag{
            language.Russian,
            language.English,
        }),
        acceptLanguage,
    )
    return &Messages{lang: tag}
}

func (m *Messages) ErrorNotFound() string {
    if m.lang == language.English {
        return "Resource not found"
    }
    return "Ресурс не найден"
}

func (m *Messages) ErrorUnauthorized() string {
    if m.lang == language.English {
        return "Authorization required"
    }
    return "Требуется авторизация"
}

// Add more messages as needed
```

## Migration Plan

### Phase 1: Infrastructure (1-2 days)
1. ✅ Create Localizable.strings files (ru + en)
2. ✅ Add Xcode localization configuration
3. ✅ Create L10n helper enum
4. ✅ Create LanguagePreferenceStorage

### Phase 2: UI Migration (3-5 days)
1. Replace hardcoded strings in Views with L10n calls
2. Update all SwiftUI Text() to use localized strings
3. Update placeholders, buttons, labels
4. Test both languages

### Phase 3: Formatters (1 day)
1. Update Date formatters to use current locale
2. Update Number formatters
3. Test date/number display in both languages

### Phase 4: Settings Integration (1 day)
1. Add language picker to Settings
2. Implement language switching
3. Add app restart prompt (if needed)

### Phase 5: Backend (Optional, 2 days)
1. Add i18n package
2. Localize error messages
3. Localize push notification content

## Usage Examples

### Before (Hardcoded Russian):
```swift
Text("Мой склад")
    .font(.title)
```

### After (Localized):
```swift
Text(L10n.Warehouse.title)
    .font(.title)
```

### Dynamic Strings:
```swift
// For strings with parameters, use String(format:)
let message = String(
    format: NSLocalizedString("item.archived.count", comment: ""),
    count
)

// In Localizable.strings:
// "item.archived.count" = "Архивировано: %d позиций"; // Russian
// "item.archived.count" = "Archived: %d items"; // English
```

## Testing Strategy

### 1. Manual Testing
- Switch language in Settings
- Verify all screens display correct language
- Test date/number formatting
- Test error messages

### 2. Automated Testing
```swift
func testLocalization() {
    // Test Russian
    let ru = AppLanguage.russian
    XCTAssertEqual(ru.displayName, "Русский")
    
    // Test English
    let en = AppLanguage.english
    XCTAssertEqual(en.displayName, "English")
}
```

### 3. Screenshot Testing
- Generate screenshots for both languages
- Verify UI layout doesn't break with longer English text

## Best Practices

1. **Always use L10n enum** instead of NSLocalizedString directly
2. **Keep keys organized** by feature/screen
3. **Add comments** to Localizable.strings for context
4. **Test both languages** before committing
5. **Use String(format:)** for dynamic content
6. **Avoid concatenation** - use complete localized strings
7. **Consider text length** - English text is often 30% longer than Russian

## Performance Considerations

- Localized strings are cached by iOS
- No performance impact from using NSLocalizedString
- Language switching requires app restart for full effect

## Future Enhancements

1. **More Languages**: Add Spanish, German, Chinese
2. **Pluralization**: Use `.stringsdict` for plural forms
3. **RTL Support**: Add Arabic/Hebrew with right-to-left layout
4. **Crowdin Integration**: Use translation management platform
5. **Context-Aware Translation**: Different translations based on context

## References

- [Apple Localization Guide](https://developer.apple.com/localization/)
- [NSLocalizedString Documentation](https://developer.apple.com/documentation/foundation/nslocalizedstring)
- [Locale Documentation](https://developer.apple.com/documentation/foundation/locale)
