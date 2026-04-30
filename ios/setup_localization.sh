#!/bin/bash
# Проверка наличия файлов локализации и того, что они попадают в сборку cstatiWarehouse.
# Запускать из каталога ios/:  ./setup_localization.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "Проверка локализации cstatiWarehouse"
echo ""

if [[ ! -d "cstatiWarehouse" ]]; then
    echo "Ошибка: запускайте скрипт из каталога ios/ (рядом с cstatiWarehouse.xcodeproj)." >&2
    exit 1
fi

for f in \
    "cstatiWarehouse/Resources/Localization/L10n.swift" \
    "cstatiWarehouse/Resources/Localization/ru.lproj/Localizable.strings" \
    "cstatiWarehouse/Resources/Localization/en.lproj/Localizable.strings"
do
    if [[ ! -f "$f" ]]; then
        echo "Не найден файл: $f" >&2
        exit 1
    fi
    echo "  OK  $f"
done

echo ""
echo "Сборка (проверка компиляции и ресурсов)..."
xcodebuild -scheme cstatiWarehouse -destination 'platform=iOS Simulator,name=iPhone 17' build -quiet

APP=$(find "${HOME}/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Debug-iphonesimulator/cstatiWarehouse.app" -type d ! -path "*/Index.noindex/*" 2>/dev/null | head -1)

if [[ -z "$APP" || ! -d "$APP" ]]; then
    echo "Предупреждение: не удалось найти cstatiWarehouse.app в BUILD_DIR; проверьте сборку вручную." >&2
    exit 0
fi

echo ""
echo "Бандл: $APP"
for lang in en ru; do
    P="$APP/${lang}.lproj/Localizable.strings"
    if [[ -f "$P" ]]; then
        echo "  OK  ${lang}.lproj/Localizable.strings"
    else
        echo "  ОШИБКА: нет $P" >&2
        exit 1
    fi
done

echo ""
echo "Готово: строки на месте, отдельное «Add Files» в Xcode для этого проекта не требуется (синхронизируемая папка cstatiWarehouse/)."
