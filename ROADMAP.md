# Дорожная карта / Roadmap

**Русский ниже первым. English version follows.**

> Это **планы разработки**, а не готовые функции. Указанные этапы не являются обещанием определённых сроков.

## Русский

### v0.0.1 — Первый играбельный цикл

**Цель:** игрок заходит в свободную езду на карте East Coast USA, начинает карьеру ПЕРЕКУПА, покупает подержанную машину, ремонтирует её, продаёт и сохраняет прогресс.

- [ ] Проверить реальный API BeamNG.drive и сделать безопасный запуск мода с интерфейсом в Free Roam.
- [ ] Локальная карьера: стартовые **500 $**, небольшой гараж, выбор **одной из трёх** доступных потрёпанных машин.
- [ ] Находить штатные и совместимые модовые легковые машины/внедорожники автоматически; не прописывать весь модельный ряд вручную.
- [ ] Создавать объявления с локальными изображениями автомобилей и **пока примерными** ценами в долларах.
- [ ] Покупка, владение, простой осмотр и ограниченное количество действий ремонта.
- [ ] Продажа машины с учётом расходов, прибыли или убытка.
- [ ] Игровые часы, календарь, умеренная сложность и простой наставник-перекупщик.
- [ ] Сохранение и загрузка профиля с защитой от потери машины при удалении автомобильного мода.
- [ ] Подготовить тестируемый ZIP; проверять ошибки без публикации личных данных.

**Пока не делаем:** путешествия между картами, банки, обмен валют, нейросетевых NPC, анимации для всех деталей, сложную налоговую систему, серверы.

### v0.0.x — Улучшение и расширение
- [ ] Точнее оценивать автомобили с учётом марки, модели, года, комплектации и состояния; предусмотреть ручные исправления.
- [ ] Расширять ремонт, совместимость запчастей, магазины и перевозку купленных деталей.
- [ ] Добавить характеры продавцов, отказ в проверках, скрытые неисправности и дополнительную диагностику.
- [ ] Развивать торг, покупателей, отчёты об истории машины, задания и сюжет.
- [ ] Тестирование, совместимость с версиями BeamNG, доступность интерфейса и новые языки.

### Далее — Регионы и собственный бизнес
- [ ] Переезды между стандартными картами через порты или терминалы с сохранением автомобилей.
- [ ] Раздельные валютные балансы, обмен в банках, комиссии и цены местного рынка.
- [ ] Улучшения гаража, сотрудники, автосалоны, эвакуаторы и логистика.
- [ ] Новые сюжетные линии, конкуренты и последствия решений.
- [ ] Дополнительные пользовательские карты **только с разрешения авторов**.
- [ ] Необязательные AI-диалоги NPC — только после оценки затрат, безопасности, приватности и ограничений запросов.

### Принципы разработки
1. **Безопасность:** никаких паролей, личных данных, непроверенного исполнения кода и ненужных серверов.
2. **Играбельность:** каждый этап должен улучшать рабочий игровой процесс.
3. **Офлайн:** в v0.0.1 нет обязательного сервера, аккаунта или телеметрии.
4. **Совместимость:** проверять модовые машины и корректно обрабатывать ошибки, не включать чужие ассеты.
5. **Права авторов:** добавлять только собственные материалы или контент с разрешением.
6. **Проверка:** код и материалы, созданные с помощью ИИ, нуждаются в проверке и тестировании в игре.

---

## English

> This is a **plan**, not an inventory of implemented features or a delivery-date commitment.

### v0.0.1 — First playable loop

**Goal:** launch PEREKUP through Free Roam on East Coast USA; buy a used car, do a simple repair, resell it, and save progress.

- [ ] Verify the actual BeamNG.drive API and build a safe Free Roam UI entry point.
- [ ] Create a local career: **$500** starting funds, a basic garage and **one of three** rough starter vehicles.
- [ ] Dynamically discover stock cars/SUVs and compatible installed vehicle mods instead of hardcoding a fleet.
- [ ] Generate listings with locally available preview images and **provisional** USD prices.
- [ ] Support purchasing, ownership, simple inspection and a limited number of repair actions.
- [ ] Resell vehicles and calculate expenses, profit and loss.
- [ ] Add in-game time/calendar, moderate difficulty and a scripted mentor.
- [ ] Add local versioned saves, including safe handling of missing vehicle mods.
- [ ] Package a testable ZIP and review sanitized errors.

**Deferred:** inter-map travel, banks and exchange, AI-powered NPCs, model-specific repair animations, advanced taxes and public servers.

### v0.0.x — Stabilize and expand
- [ ] More credible valuations by real-world model, year, trim and condition, with manual overrides.
- [ ] Repair mechanics, compatible parts, parts shops and physical transport.
- [ ] Seller personalities, refused inspections, hidden defects and optional diagnostics.
- [ ] Negotiation, buyers, vehicle history reports, optional missions and story arcs.
- [ ] Testing, compatibility, accessibility and more translations.

### Later — Regions and business
- [ ] Ports/terminals connecting default maps with persistent vehicles.
- [ ] Separate currency balances, banks, exchange fees and local markets.
- [ ] Garage upgrades, staff, dealerships, towing and logistics.
- [ ] Additional missions, competitors and meaningful consequences.
- [ ] Community maps **only with the creators' permission**.
- [ ] Optional AI NPC conversations **only after** examining cost limits, privacy, security and rate controls.

### Development principles
1. **Security first:** no secrets, private data, unsafe code execution or unnecessary infrastructure.
2. **Playability first:** improve a working gameplay loop each milestone.
3. **Offline first:** no required servers, accounts or telemetry for v0.0.1.
4. **Compatibility:** validate mods, fail gracefully, never bundle others' vehicle assets.
5. **Respect creators:** original or properly licensed materials only.
6. **Human review:** AI-assisted contributions must still be reviewed and tested.
