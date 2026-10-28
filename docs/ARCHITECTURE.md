# Архитектура / Architecture

**Русский ниже первым. English version follows.**

> Это **предварительная схема**, а не описание уже готового мода. Точные точки интеграции с BeamNG.drive v0.40.x нужно проверить в игре.

## Русский

### Основные принципы
- Правила карьеры отделены от интерфейса и каталога автомобилей.
- Сохранения версионируются и находятся **вне ZIP мода**.
- Используются стандартные карты BeamNG; чужие машины или карты не копируются в архив.
- Сканируем установленные у игрока автомобили; проверяем данные и корректно обрабатываем несовместимые моды.
- Первые версии — **без сервера, телеметрии, скрытых сетевых запросов и API-ключей**.
- Валюта сделки определяется регионом карты; язык интерфейса и NPC — настройками игрока.

### Планируемые модули
| Модуль | Назначение |
| --- | --- |
| `core` | Запуск, состояние игры, подключение остальных систем |
| `vehicles` | Поиск и проверка легковых автомобилей и внедорожников |
| `pricing` | Базовые цены, оценка состояния, корректировки |
| `market` | Объявления с изображениями, покупка и продажа |
| `economy` | Деньги, расходы, время и будущий обмен валют |
| `inventory` | Запчасти, инструменты, склад и будущие грузы |
| `garage` | Собственность, места для хранения машин |
| `repairs` | Диагностика и ограниченные операции ремонта |
| `characters` | Наставник и будущие характеры продавцов |
| `stories` | Расширяемые задания и события |
| `world` | Регионы, точки услуг и будущие путешествия |
| `saves` | Сохранения, резервные копии и обновление формата |
| `ui` | Меню игрока, объявления и фотографии автомобилей |

### Первый запуск v0.0.1
1. Игрок выбирает **Free Roam → East Coast USA**.
2. Открывает интерфейс **ПЕРЕКУП**, выбирает «Новая карьера» или «Продолжить».
3. Выбирает **одну из трёх** доступных потрёпанных машин и получает **500 $**.
4. Наставник знакомит игрока с объявлениями; игрок может купить, осмотреть, починить и продать автомобиль.
5. Локальное сохранение запоминает деньги, собственность и прогресс.

Отдельная кнопка в главном меню — **возможное будущее улучшение**, не требование первой версии.

### Изображения и чужие материалы
Приоритет — **локальные игровые превью** автомобилей. Если картинка отсутствует, используем временную заглушку или снимок, созданный в самой игре, если это допустимо. Не включаем в репозиторий чужие модели или снимки без прав.

### Надёжность и совместимость
- Нельзя превращать название машины или поле объявления в исполняемую команду.
- Сохраняем идентификаторы автомобиля и проверенные данные конфигурации. Если мод удалён, запись остаётся **временно недоступной**.
- Проверяем финансовые операции на двойные покупки, отрицательные балансы и неполные сохранения.
- Версионируем сохранения и не удаляем неизвестные данные без предупреждения.
- Проверяем совместимость после обновлений BeamNG и при работе со сторонними автомобилями.

### Развитие
Позже можно независимо подключать путешествия через порты, банки, персонажей, ремонт, задания и необязательные AI-диалоги NPC. **Публичный сервер для первой версии не требуется.**

---

## English

> This is an **implementation proposal**, not implemented code. BeamNG.drive v0.40.x integration points still need in-game verification.

### Principles
- Career logic independent from UI and vehicle catalog.
- Local, versioned saves **outside** the mod ZIP.
- Default maps only initially; no third-party vehicle/map assets bundled.
- Validate installed stock/mod vehicle metadata and fail gracefully on incompatible entries.
- **No required backend, telemetry, hidden network requests, or API keys** for early releases.
- Map region determines market and transaction currency; player preferences determine UI/dialogue language.

### Planned modules
| Module | Responsibility |
| --- | --- |
| `core` | Lifecycle and feature registration |
| `vehicles` | Discover, normalize and validate compatible cars/SUVs |
| `pricing` | Reference prices, estimates, condition and overrides |
| `market` | Listings with images, purchase and resale |
| `economy` | Balances, expenses, time and future currency exchange |
| `inventory` | Parts, tools, storage and future cargo |
| `garage` | Ownership and garage slots |
| `repairs` | Inspection and basic repair actions |
| `characters` | Scripted mentor and future NPC personalities |
| `stories` | Extensible missions and events |
| `world` | Regions, points of interest and later inter-map travel |
| `saves` | Versioned saves, backups and migrations |
| `ui` | Player menus, advertisements and vehicle previews |

### First-run experience — v0.0.1
1. Open **Free Roam → East Coast USA**.
2. Open the **PEREKUP** UI and choose New Career / Continue.
3. Select **one of three** compatible rough starter vehicles; start with **$500**.
4. A mentor introduces the market; buy, inspect, repair and resell a car.
5. Local saves preserve funds, vehicle ownership and progress.

A custom main-menu entry is a **future option**, not a first-release prerequisite.

### Third-party assets
Prefer **locally available in-game preview images**; use placeholders or permitted local captures where needed. Do not bundle third-party models, maps or screenshots without the required rights.

### Compatibility and resilience
- Never execute vehicle names, listing fields or mod metadata as commands.
- Store stable vehicle identifiers and validated configurations. If a mod disappears, preserve the ownership record as **temporarily unavailable**.
- Prevent duplicate transactions, negative balances and partial-save corruption.
- Version save schemas and avoid silently deleting unknown data.
- Review compatibility after game updates and with varying vehicle mods.

### Future expansion
Ports, banks, seller personalities, interactive repairs, missions and optional AI NPC dialogue are separate future systems. **No public backend is necessary for v0.0.1.**
