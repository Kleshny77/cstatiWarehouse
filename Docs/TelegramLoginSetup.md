# Telegram Login — чек-лист настройки

Интеграция основана на официальном SDK [`TelegramMessenger/telegram-login-ios`](https://github.com/TelegramMessenger/telegram-login-ios) (OIDC Authorization Code Flow + PKCE) и описании на [core.telegram.org/bots/telegram-login](https://core.telegram.org/bots/telegram-login).

Пока `clientId` и `redirectUri` в `TelegramAuthConfig.swift` пустые — SDK не инициализируется, кнопка «Войти через Telegram» возвращает ошибку `notConfigured`. Сборка и остальные flow работают как обычно.

## 1. Создать бота

1. Открыть [@BotFather](https://t.me/botfather) в Telegram.
2. `/newbot` → имя + username.
3. Рекомендуется: сразу поставить логотип и описание, совпадающие с приложением.

## 2. Включить Login Widget для бота

1. В @BotFather: `Bot Settings → Login Widget` (mini app «Web Login» в мобильном @BotFather).
2. Внести **Bundle ID** и **Apple Team ID**:
   - Bundle ID: `com.kleshny.cstatiwarehouse`
   - Team ID: `NWMHAK8G97`
3. BotFather сгенерирует **Associated Domain** вида `app{appid}-login.tg.dev`. Его тоже нужно зарегистрировать как Allowed URL.
4. Сохранить из BotFather:
   - **Client ID** — положить в `TelegramAuthConfig.clientId`.
   - **Associated Domain** (в виде `https://app123456-login.tg.dev`) — положить в `TelegramAuthConfig.redirectUri`.
   - Client Secret **не кладём в iOS-клиент**: он нужен только бэкенду для обмена кода на токен (если будем реализовывать ручной OIDC флоу). Текущий SDK работает через публичный PKCE-эндпоинт и Secret не требует.

## 3. Xcode → Associated Domains

1. Target `cstatiWarehouse` → `Signing & Capabilities`.
2. `+ Capability → Associated Domains`.
3. Добавить запись: `applinks:app123456-login.tg.dev` (домен из BotFather, без `https://`).
4. На время разработки можно добавить `?mode=developer` для байпаса CDN-кеша AASA, и включить `Developer Mode → Associated Domains Development` на устройстве. В проде — убрать параметр.

## 4. (Опционально) Custom URL scheme как фолбэк

Нужен только для iOS < 17.4 или если не хочется связываться с Universal Links.

1. `Info.plist` → `URL types` → добавить элемент:
   - `URL identifier` = `com.kleshny.cstatiwarehouse`
   - `URL Schemes` = например `cstatiwarehouse`
2. В `TelegramAuthConfig.fallbackScheme` положить ту же схему (`"cstatiwarehouse"`).
3. Зарегистрировать в BotFather Allowed URL вида `cstatiwarehouse://tglogin`.

## 5. Бэкенд (позже)

`id_token` — это подписанный JWT. **В проде клиент не должен доверять содержимому без проверки подписи**. Сейчас:

- `MockAuthService.loginWithTelegram(idToken:)` декодирует payload без проверки подписи — только для локальной разработки.
- `ApiAuthService.loginWithTelegram(idToken:)` — стаб с TODO. Когда появится Go-бэкенд, там нужно:
  1. Скачивать JWKS с `https://oauth.telegram.org/.well-known/jwks.json`.
  2. Проверять подпись, `iss = https://oauth.telegram.org`, `aud = clientId`, `exp`.
  3. На основе `sub`/`phone_number` искать/создавать юзера и возвращать свою сессию.

## 6. Что проверить после настройки

1. Запустить приложение на симуляторе/устройстве, где установлен Telegram.
2. На экране логина тапнуть «Войти через Telegram».
3. Должно открыться окно Telegram-app (или ASWebAuthenticationSession как fallback) с подтверждением доступа для бота.
4. После подтверждения приложение должно автоматически закрыть веб-сессию и авторизоваться.
