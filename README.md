# ПЕРЕКУП / PEREKUP 🚗

### Your next car is somebody else's problem.
**Бесплатный симулятор перекупщика автомобилей для BeamNG.drive — открытый проект с историей, свободой выбора и настоящими последствиями решений.**

> **Статус проекта: концепция и подготовка.** Играбельная сборка пока не выпущена. Всё описанное ниже — **план и направление разработки**, а не список уже существующих возможностей.

📣 **Помогите выбрать окончательное название!** «ПЕРЕКУП» — пока рабочее имя. [Предлагайте названия и оставляйте комментарии в открытом обсуждении →](https://github.com/Domidy53/perekup-beamng/issues/6) / **Help us name the project!** [Suggest a name or leave feedback →](https://github.com/Domidy53/perekup-beamng/issues/6)

**[Русский](#-о-проекте) · [English](#-english) · [План разработки](ROADMAP.md) · [Архитектура](docs/ARCHITECTURE.md) · [Участие](CONTRIBUTING.md)**

---

## 🇷🇺 О проекте

**ПЕРЕКУП** — это задуманный нами отдельный карьерный режим внутри BeamNG.drive. Не просто покупай машину в меню и нажимай «Продать», а действительно **живи жизнью автомобильного перекупщика**.

Ты начинаешь с небольшим количеством денег, тесным гаражом и потрёпанной личной машиной. Находишь объявления, общаешься с владельцами, едешь за автомобилем, проверяешь его состояние, решаешь, стоит ли рисковать, доставляешь домой, ремонтируешь и пытаешься продать с прибылью.

**Игрок сам выбирает направление развития.** Выполнять сюжетные задания, искать редкие машины, заниматься дешёвыми автомобилями, развивать мастерскую или построить собственный автосалон — всё это части долгосрочного замысла.

### 🎮 Какой геймплей мы хотим

| Система | Что задумано |
| --- | --- |
| 🔎 Поиск автомобилей | Объявления с фотографиями, автосалоны, аукционы, частные продавцы, знакомые и случайные предложения |
| 🚗 Покупка | Личная поездка к продавцу, разговор, осмотр, тест-драйв, диагностика, риск скрытых дефектов и торг |
| 🛠️ Ремонт | Запчасти, неисправности, гараж, короткие анимации и простые интерактивные действия — без излишне сложного симулятора инструментов |
| 🚚 Доставка | Исправную машину можно пригнать самому; неисправную — попытаться починить на месте или перевезти эвакуатором |
| 💸 Продажа | Оценка состояния, затраты, прибыль или убыток; позднее — покупатели с характером, осмотры и переговоры |
| 📖 История | Наставник, конкуренты, сомнительные сделки, долги, сложные решения и необязательные сюжетные задания |
| 🏠 Бизнес | Развитие от маленького гаража до мастерской и автосалона с сотрудниками |
| 🌍 Путешествия | В будущем — поездки между картами через порты и терминалы, местные рынки и банковский обмен валют |

### 🧩 Машины — из твоей установки BeamNG

**В моде не будет жёстко прописанного перечня автомобилей.** Мы планируем обнаруживать доступные легковые машины и внедорожники из базовой игры и **совместимых автомобильных модификаций, установленных конкретным игроком**.

Поэтому у разных игроков могут быть разные автомобильные рынки. ПЕРЕКУП **не распространяет чужие автомобили** и не требует определённый платный автомобильный мод.

Цены должны быть правдоподобными: редкий дорогой автомобиль не должен стоить копейки только потому, что автор мода не указал стоимость. В первой версии расчёт будет очень примерным; позже появятся справочники реальных моделей, поколения, состояние, история автомобиля и более точная оценка.

В объявлениях планируются **изображения автомобилей**. Сначала будем использовать доступные локальные игровые превью; если их нет — безопасные запасные изображения или создание превью в игре, где это возможно.

### 🌐 Карты, языки и валюта

- **Язык интерфейса и разговоров NPC** задаётся настройками игрока, а не национальностью персонажа.
- **Страна игровой карты** определяет рынок и валюту сделок: в США — доллары, в Италии — евро.
- В будущем при поездках между странами игроку потребуется **обменять деньги в игровом банке**; курсы и комиссии станут частью экономики.
- На первых этапах используем **стандартные карты BeamNG.drive**. Новые пользовательские карты можно рассматривать позже **только с разрешения их авторов**.

### 🏁 Первая играбельная версия — v0.0.1

Главная цель первой версии — **законченный игровой цикл**, а не сотня недоделанных механик.

- Старт на стандартной карте **East Coast USA** через **Free Roam → ПЕРЕКУП → Новая карьера / Продолжить**.
- **$500 на старте**, маленький гараж, **выбор из трёх доступных потрёпанных стартовых машин**.
- Небольшое знакомство с наставником-перекупщиком.
- Базовый каталог из штатных и совместимых модовых автомобилей, простые цены и объявления с превью.
- Приехать за машиной, купить, осмотреть, провести ограниченный набор ремонтов, продать и увидеть прибыль или убыток.
- Игровое время: часы, сутки и календарь. Умеренная сложность: ошибки имеют последствия, но их можно исправлять.
- Локальное сохранение денег, машин, состояния и прогресса. При удалении стороннего автомобильного мода запись о купленной машине должна оставаться, даже если её временно нельзя загрузить.

**В v0.0.1 не обещаем:** полноценный международный банк, путешествия между картами, разумных нейросетевых NPC, поддержку буквально каждого мода, сложные анимации всех ремонтов или законченный большой сюжет. Это следующие этапы.

Подробные задачи и приоритеты: **[ROADMAP.md](ROADMAP.md)**.

### 🧠 Персонажи, задания и будущее

Мы хотим, чтобы продавцы **имели характер**, могли торопить, скрывать проблемы, отказывать в проверках или оказаться надёжными знакомыми. У каждой машины может быть собственная история. **Платный внутриигровой отчёт** иногда помогает, но не гарантирует полной правды.

Система заданий проектируется расширяемой, чтобы добавлять цепочки миссий, побочные истории и события. При достаточном развитии проекта можно изучить **опциональные AI-диалоги NPC**, но **не ценой обязательного сервера, утечки данных или неконтролируемых расходов**. Первая версия будет локальной и офлайновой.

---

## ❤️ Поддержать разработку / Donate

**ПЕРЕКУП будет бесплатным.** Доступ к игровым механикам, обновлениям и исходному коду **не зависит от пожертвований**. Поддержка исключительно добровольная.

Если проект понравится, можно будет помочь с будущими расходами на тестирование, лицензированные материалы, оформление и развитие.

> **Ссылка на добровольный сбор в ЮMoney появится здесь после настройки и проверки платёжной страницы.** Сейчас приём пожертвований через этот README **не подключён**. Мы не публикуем номера личных карт, паспортные данные или платёжные токены.

Пожертвования не являются предзаказом, не дают эксклюзивного контента и не гарантируют сроки релизов. Условия платёжного сервиса и доступные способы оплаты могут отличаться по стране.

---

## 🤝 Сообщество и открытый код

**Мы ждём идеи по поводу нового названия проекта!** Предлагайте свои варианты и обсуждайте предложения других пользователей в [открытом Issue №6](https://github.com/Domidy53/perekup-beamng/issues/6). Также можно оставлять отзывы и идеи по будущим механикам в [GitHub Issues](https://github.com/Domidy53/perekup-beamng/issues). Для комментариев нужен GitHub-аккаунт.


Мы хотим развивать проект **открыто**, выслушивать идеи и принимать качественные исправления от сообщества.

- **[Предложить идею или сообщить об ошибке](https://github.com/Domidy53/perekup-beamng/issues)**
- **[План работ](ROADMAP.md)** — что делаем сначала и что отложили.
- **[Как помочь проекту](CONTRIBUTING.md)** — правила Pull Request и использования чужого контента.
- **[Безопасность](SECURITY.md)** — как конфиденциально сообщать об уязвимостях.

**Исходный код оригинальных материалов проекта** планируется публиковать под **GNU GPL v3** ([LICENSE](LICENSE), после принятия документационного PR). Это разрешает форки и изменения при соблюдении условий лицензии. **Никакие исходные материалы BeamNG.drive или чужих модов не переходят под нашу лицензию.**

ПЕРЕКУП — **неофициальный фанатский проект**, не связанный с BeamNG GmbH или автопроизводителями.

### 👨‍💻 Кто создаёт ПЕРЕКУП

**Идея, игровые решения и руководство проектом:** [Domidy53](https://github.com/Domidy53).

В архитектуре, программировании и документации используются **инструменты искусственного интеллекта**. Это открыто указывается, но всё, что попадёт в играбельный релиз, должно пройти человеческую проверку и тестирование. Мы не выдаём планируемые функции за готовые и не обещаем безошибочность AI-сгенерированного кода.

---

## 🇬🇧 English

### What is PEREKUP?

**PEREKUP** is a planned **free and open-source vehicle flipping and restoration career experience for BeamNG.drive**. It aims to turn the game into a believable used-car trader's life — with a garage, buyers and sellers, vehicle condition, repairs, business progression, optional narrative missions and meaningful financial decisions.

**Status: planning stage. There is no playable release yet.** Descriptions on this page refer to intended features, not completed ones.

### The experience we want to build

You start small. Find a used car listing, travel to meet the owner, inspect and diagnose the vehicle, decide whether the deal is worth it, get the car home by driving or towing, fix what's wrong, then resell it. Make a profit — or learn an expensive lesson.

Over time the vision includes:
- Photo listings, private sellers, dealerships, auctions, negotiation and hidden defects.
- A useful garage, repair parts, small repair interactions and vehicle breakdowns.
- Scripted characters with personalities, competitors, honest and dishonest deals, and **optional story missions**.
- Business upgrades, more regions, shipping vehicles between maps and **physical foreign-exchange services at banks**.
- Model-aware vehicle pricing based on real-world values rather than arbitrary metadata.

### Your cars, your vehicle market

The mod will aim to discover **stock vehicles and compatible third-party car/SUV mods installed by each player**. Vehicle assets from other creators **will not be bundled**. Different players can therefore encounter different listings. Compatibility with every third-party mod is not guaranteed.

### The v0.0.1 milestone

- **East Coast USA**, Free Roam entry point, **$500 starting cash**, a basic garage and a choice of **three rough starter vehicles**.
- A simple scripted mentor, listings with local thumbnails and rough USD price estimation.
- An initial loop: buy → inspect → make a few basic repairs → sell → track profit or loss.
- Clock/calendar, moderate difficulty, and offline versioned career saves.

The first milestone does **not** promise cross-map travel, complex repair animations, live AI NPCs, or a full international banking system. More details: [ROADMAP.md](ROADMAP.md).

### Language and regions

NPC dialogue and interface language follow the **player's preferences**. The game's geographic region determines its car market and transaction currency. Later, travelling between regions may require exchanging money in an in-game bank. The first milestone is USD-only on East Coast USA.

### 💡 Help us pick a name

**PEREKUP is a temporary project title.** We welcome new name ideas and friendly feedback in [our open naming thread](https://github.com/Domidy53/perekup-beamng/issues/6). You can also propose gameplay features or report problems through [GitHub Issues](https://github.com/Domidy53/perekup-beamng/issues). Posting comments requires a GitHub account.

### ❤️ Support PEREKUP

PEREKUP will remain **free**; donations will be **strictly optional**, with no exclusive gameplay advantages.

**A verified donation link for supporters in Russia is being prepared. It is not active yet.** Never send payment credentials or personal financial information through public GitHub discussions.

### Open development and credits

Ideas and project direction: **[Domidy53](https://github.com/Domidy53)**. AI tools assist with architecture, code and documentation; contributions and releases still require human review and gameplay testing. See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and [ROADMAP.md](ROADMAP.md).

The planned license for **original project source code** is **GNU GPL v3**. Third-party maps, car mods, and BeamNG.drive itself remain under their owners' terms. This is an unofficial project, not affiliated with BeamNG GmbH or any vehicle manufacturer.
