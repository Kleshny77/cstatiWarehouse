# iOS-клиент (cstatiWarehouse)

Открывайте в Xcode файл **`cstatiWarehouse.xcodeproj`** в этой папке.

| Каталог | Назначение |
|---------|------------|
| `cstatiWarehouse/` | Исходный код приложения |
| `cstatiWarehouseTests/` | Модульные тесты |
| `cstatiWarehouseUITests/` | UI-тесты |

Серверная часть проекта — в соседней папке репозитория **`../backend/`**.

## Сборка из командной строки (из корня репозитория)

Чтобы артефакты сборки лежали рядом с клиентом, задайте DerivedData внутри `ios/`:

```bash
xcodebuild -project ios/cstatiWarehouse.xcodeproj \
  -scheme cstatiWarehouse \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/DerivedData \
  build
```

Папка `ios/DerivedData/` в git не коммитится (см. `.gitignore`).
