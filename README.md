## mdmT2 Config

Позволяет просматривать логи и выполнять некоторые команды на [mdmTerminal2](https://github.com/Aculeasis/mdmTerminal2). Изменять настройки нельзя.

### Установка
[Скачать](https://github.com/Aculeasis/mdmt2-config-android/releases) и установить нужный apk (вероятно \*-arm64-v8a.apk). Google Play может ругаться на подпись неизвестного разработчика, это нормально.

### Сборка
- Установить [Flutter](https://flutter.dev/docs/get-started/install).
- Собрать
```
flutter pub get
flutter build apk --split-per-abi
```

### Требования
 - mdmTerminal2 не ниже 0.15.4 (зависит от версии приложения).
 - Android 4.4+ (API 19+).
 - Доступ к сети.
 
 Можно попробовать собрать под другие платформы поддерживаемые флаттером.

## Особенности

WIP
