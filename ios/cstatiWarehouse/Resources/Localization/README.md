# Локализация (i18n)

## Файлы

1. **L10n.swift** — типизированный доступ к строкам (`NSLocalizedString`).
2. **ru.lproj/Localizable.strings** — русский.
3. **en.lproj/Localizable.strings** — английский.

## Настройка в этом репозитории

Цель **cstatiWarehouse** использует **File System Synchronized Groups** в Xcode: всё дерево `ios/cstatiWarehouse/` уже входит в таргет. Отдельно добавлять папку `Localization` через *Add Files…* **не нужно**, если файлы лежат по указанным путям на диске.

В **project.pbxproj** для проекта заданы `knownRegions`: **en**, **Base**, **ru** — русский и английский учтены.

### Проверка из терминала (без Xcode)

Из каталога `ios/`:

```bash
xcodebuild -scheme cstatiWarehouse -destination 'platform=iOS Simulator,name=iPhone 17' build -quiet
```

Убедиться, что в собранном `.app` есть оба набора строк:

```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Build/Products/Debug-iphonesimulator/cstatiWarehouse.app" -type d | head -1)
ls "$APP/en.lproj/Localizable.strings" "$APP/ru.lproj/Localizable.strings"
```

Если оба файла на месте — локализации попадают в бандл.

### Когда могут понадобиться действия в Xcode

Только если проект переведён на классическую структуру без синхронизации папок: тогда имеет смысл инструкция «Add Files…» и **Localize…** для `Localizable.strings`. В текущем формате проекта это обычно не требуется.

### Смена языка для проверки

- Симулятор: **Settings → General → Language & Region → iPhone Language**.
- Xcode: **Scheme → Run → Options → Application Language** (Russian / English).

## Использование в коде

```swift
Text(L10n.warehouseTitle)
Button(L10n.add) { }
Text(L10n.warehouseItemsCount(count))
```

## Добавление новых строк

1. Ключ и свойство в **L10n.swift** (`NSLocalizedString("key", comment: "")`).
2. Та же пара `"key" = "…";` в **ru** и **en** `Localizable.strings`.

## Миграция с экранов

Заменять литералы постепенно: вкладки → склад → организация → настройки и т.д.

## Troubleshooting

- Показывается ключ вместо текста — проверить наличие ключа в обоих `.strings`.
- После правок `.strings`: **Clean Build Folder** (⇧⌘K) и пересборка.

Статус: инфраструктура в репозитории подключена; миграция UI со строк по экранам — отдельная задача.
