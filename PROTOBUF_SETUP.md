# Protobuf Setup для Steam API

## Установка библиотеки

Библиотека `protobuf` уже установлена в проекте через `pubspec.yaml`.

## Проблема с декодированием Steam API

Steam API возвращает данные в формате **protobuf**, а не JSON. Для декодирования protobuf нужна **схема (.proto файл)**, которую Steam не предоставляет публично.

### Текущий статус

- ✅ Библиотека `protobuf` установлена
- ❌ Схема для `GetLiveLeagueGames` отсутствует
- ⚠️ Полное декодирование невозможно без схемы

### Возможные решения

1. **Найти существующую схему** в открытых проектах:
   - Поиск в GitHub репозиториях
   - Проверка документации Steam Web API
   - Использование схем из других проектов, работающих со Steam API

2. **Обратный инжиниринг схемы**:
   - Анализ структуры protobuf ответов
   - Создание собственной схемы на основе анализа

3. **Использование альтернативных методов**:
   - OpenDota API (текущее решение)
   - Парсинг сайтов турниров
   - Другие публичные API

### Пример использования (когда схема будет найдена)

```dart
import 'package:protobuf/protobuf.dart';
import 'generated/steam_api.pb.dart'; // Сгенерированный файл из .proto

// Декодирование protobuf ответа
final response = CMsgDOTALiveLeagueGames.fromBuffer(response.bodyBytes);
```

### Где искать схемы

- GitHub: `steam dota2 protobuf schema`
- Steam Web API документация
- Открытые проекты, работающие со Steam API
- Valve Developer Community

## Текущая реализация

Сейчас Steam API используется только для методов, возвращающих JSON. Методы с protobuf (например, `GetLiveLeagueGames`) используют альтернативные источники данных.

