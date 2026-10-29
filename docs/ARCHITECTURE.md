# Архитектура / Architecture

**Русский ниже первым. English version follows.**

> Это схема проекта и описание v0.0.1. Статические тесты покрывают карьеру, физический checkpoint и обработку повторных команд. Совместимость внутренних игровых API всё ещё нужно подтвердить в актуальной BeamNG.drive.

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
| `world` | Связь карьерных записей с игровыми объектами и будущие регионы |
| `saves` | Сохранения, резервные копии и обновление формата |
| `ui` | Меню игрока, объявления и фотографии автомобилей |

### Первый запуск v0.0.1
1. Игрок выбирает **Free Roam → East Coast USA**.
2. Открывает интерфейс **ПЕРЕКУП**, выбирает «Новая карьера» или «Продолжить».
3. Выбирает одну из доступных машин, получает **500 $**, а стартовая машина появляется в мире.
4. Игрок может выставить стартовую машину, покупать объявления, вывести купленную машину в мир, вернуть её в гараж, отремонтировать полным физическим сбросом и продать.
5. Локальное сохранение запоминает деньги, конфигурации, физические checkpoint-файлы, предложения и историю. Игровой object ID временный; при восстановлении PEREKUP создаёт новый объект из сохранённых данных и связывает с карьерой только его.

Отдельная кнопка в главном меню — **возможное будущее улучшение**, не требование первой версии.

### Изображения и чужие материалы
Приоритет — **локальные игровые превью** автомобилей. Если картинка отсутствует, используем временную заглушку или снимок, созданный в самой игре, если это допустимо. Не включаем в репозиторий чужие модели или снимки без прав.

### Надёжность и совместимость
- Нельзя превращать название машины или поле объявления в исполняемую команду.
- Сохраняем идентификаторы автомобиля и проверенные данные конфигурации. Если мод удалён, запись остаётся **временно недоступной**.
- Проверяем финансовые операции на двойные покупки, отрицательные балансы и неполные сохранения.
- Реализация разрешает удаление мирового объекта только после проверки файлов конфигурации и Beamstate checkpoint. При выводе сначала создаётся сохранённая конфигурация, затем мод пытается загрузить совместимое физическое состояние; несовместимый файл блокирует вывод, запись владения остаётся.
- Используем внутренние BeamNG `beamstate.save/load` в формате `v2` только с проверкой модели, каталога автомобиля, конфигурации, узлов, балок и гидравлики. `.pc`-поля `parts`, `vars` и `paints` сохраняются отдельно, потому что Beamstate не сохраняет цвет.
- До сохранённого checkpoint ремонт не запускается. После reset списываем деньги только когда проверен post-reset файл и карьерная запись подтверждена. Повторные команды используют один токен, а потерянные подтверждения восстанавливаются по файлу.
- Незавершённый ремонт переживает перезапуск и повторно привязывается к новому игровому ID. Если checkpoint потерян до reset, операция отменяется без списания; если reset уже мог начаться, операция сохраняется и ждёт восстановления машины, чтобы не дать бесплатный ремонт.
- Постоянный ID машины принадлежит только карьерной записи. Числовой BeamNG object ID и nonce связи находятся только в runtime-памяти; при перезагрузке GE Lua в `M.state` сохраняется только счётчик поколения, без ID и связей. Схема сохранения 3 удаляет старые object ID. Машина связывается только с объектом из собственного spawn-вызова PEREKUP и пока текущий поиск возвращает тот же Lua-объект. Callback требует совпадения career token и session binding proof; старый ID не используется для удаления, сохранения или reset.
- UI App использует отдельные словари `ru`/`en` и хранит выбор языка в настройках приложения.
- Процент состояния — экономическая оценка, а не чтение фактического повреждения игрового объекта. Подтверждённого публичного Lua API для этой телеметрии мод не использует.
- Физический ремонт пока означает полный reset физики автомобиля, не починку отдельных деталей.
- Версионируем сохранения и не удаляем неизвестные данные без предупреждения.
- Проверяем совместимость после обновлений BeamNG и при работе со сторонними автомобилями.

### Развитие
Позже можно независимо подключать путешествия через порты, банки, персонажей, ремонт, задания и необязательные AI-диалоги NPC. **Публичный сервер для первой версии не требуется.**

---

## English

> This describes the v0.0.1 implementation. Static tests cover the object lifecycle and reset adapter; its internal game APIs still require verification in a current BeamNG.drive build.

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
| `world` | Career-to-world vehicle objects and future regions |
| `saves` | Versioned saves, backups and migrations |
| `ui` | Player menus, advertisements and vehicle previews |

### First-run experience — v0.0.1
1. Open **Free Roam → East Coast USA**.
2. Open the **PEREKUP** UI and choose New Career / Continue.
3. Select an available starter vehicle, begin with **$500**, and spawn it into the world.
4. List the starter, buy offers, retrieve a purchased car into the world, return it to the garage, physically reset it, and resell it.
5. Local saves preserve funds, career vehicle IDs, offers and history. Engine object IDs are session-local.

A custom main-menu entry is a **future option**, not a first-release prerequisite.

### Third-party assets
Prefer **locally available in-game preview images**; use placeholders or permitted local captures where needed. Do not bundle third-party models, maps or screenshots without the required rights.

### Compatibility and resilience
- Never execute vehicle names, listing fields or mod metadata as commands.
- Store stable vehicle identifiers and validated configurations. If a mod disappears, preserve the ownership record as **temporarily unavailable**.
- Prevent duplicate transactions, negative balances and partial-save corruption.
- Do not charge for repair until the vehicle Lua VM confirms a physics reset; persist and recover pending operations safely. Retry delayed acknowledgements for a live object without repeating a completed reset or cancelling a possibly completed operation.
- Keep UI copy in `ru`/`en` dictionaries and persist the selected locale in app settings.
- Condition percentages are career estimates, not live damage readings. No verified public in-game Lua contract is used to read physical damage.
- The implementation only deletes a returned world object after verifying the saved config and Beamstate checkpoint. Retrieval spawns that config and attempts to apply the compatible physical checkpoint; this is not an ordinary respawn presented as persistence.
- Career vehicle IDs are persistent; numeric BeamNG object IDs and binding proofs exist only in runtime memory. During a GE Lua reload, `M.state` carries only a generation counter, never IDs or bindings. Save schema 3 removes legacy object IDs, and callbacks must match the current session binding before they can complete a world operation. Unbound objects are not saved, reset or deleted.
- Beamstate and several vehicle-manager functions are internal APIs, not a stable official serialization contract. They are guarded, tested with mocks, and still need validation on a current BeamNG.drive PC. Third-party modules may keep state outside Beamstate's serialized packages.
- The current physical repair performs a full vehicle physics reset rather than repairing individual parts. Career condition remains an estimate.
- Day-one listings ensure that the starter sale can fund one listed vehicle and its estimated repair reserve, including a lower-condition starter-config offer when necessary.
- Version save schemas and avoid silently deleting unknown data.
- Review compatibility after game updates and with varying vehicle mods.

### Future expansion
Ports, banks, seller personalities, interactive repairs, missions and optional AI NPC dialogue are separate future systems. **No public backend is necessary for v0.0.1.**
