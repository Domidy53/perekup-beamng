# ПЕРЕКУП / PEREKUP 🚗

**Open-source vehicle trading and restoration career project for BeamNG.drive.**  
**Бесплатный проект симулятора перекупщика, ремонта и автомобильного бизнеса для BeamNG.drive.**

> **Status / Статус:** Early planning and development preparation. **No playable release yet.** / Проект в подготовке. **Играбельной сборки пока нет.**

[Русский](#русский) · [English](#english) · [Roadmap](ROADMAP.md) · [Security](SECURITY.md) · [Contributing](CONTRIBUTING.md)

## Русский

### Идея
ПЕРЕКУП — отдельный игровой режим в BeamNG.drive: находи объявления, езди осматривать машины, покупай, диагностируй, ремонтируй и перепродавай их. Развивай свой гараж и бизнес, знакомься с персонажами и проходи сюжетные задания **в свободном порядке**, без принудительной линейной кампании.

**Важное:** это концепция и план разработки, а не заявление о готовых функциях.

### План первой играбельной версии — v0.0.1
- Старт в **East Coast USA** с **$500**, простым гаражом и выбором одной из **трёх подержанных машин**.
- Наставник-перекупщик знакомит игрока с основами.
- Обнаружение штатных автомобилей и совместимых установленных автомобильных модов; **чужие машины не включаются в наш архив**.
- Объявления с изображениями машин, описаниями и предварительной локальной оценкой стоимости.
- Покупка → осмотр → базовый ремонт → продажа с расчётом прибыли или убытка.
- Время, календарь, умеренные последствия ошибок и сохранение прогресса.
- Язык интерфейса и диалогов задаёт игрок; цены и валюта зависят от игрового региона. Первая карта — США, поэтому экономика первой версии в **USD**.

**Совместимость с любым сторонним автомобильным модом не гарантируется.** Если у модели отсутствуют корректные метаданные, изображения или детали, будут предусмотрены проверка и запасные варианты.

### Долгосрочная концепция
Персонажи с характерами, скрытые дефекты и платные (внутриигровые) отчёты о прошлом автомобиля, магазины и перевозка запчастей, интерактивный ремонт, эвакуаторы, порты и переходы между картами, валютные обменники/банки, предприятия, конкуренты, задания и сюжет. Позже возможно добавление других карт с разрешения их авторов. AI-диалоги NPC — **только возможное будущее расширение**, не часть первой версии.

### Открытость и безопасность
- **Бесплатно и с открытым исходным кодом.** Добровольные пожертвования могут появиться позже; они не дают игровых преимуществ.
- Первая версия проектируется **для локальной игры без собственного сервера, телеметрии и регистрации аккаунта**.
- Не размещайте в Issues, PR или коммитах пароли, токены, личные данные и чужие платные игровые ресурсы.
- Исходный код проекта лицензируется по **GNU GPL v3** (см. [LICENSE](LICENSE)); права на BeamNG.drive и сторонние моды остаются у соответствующих правообладателей.
- Проект неофициальный, не связан с BeamNG GmbH и автопроизводителями.

### Кто делает проект
Идея, решения по игровому дизайну и руководство проектом — **Domidy53**. Для программирования, анализа архитектуры и подготовки материалов используются инструменты искусственного интеллекта. Изменения предполагают проверку человеком и тестирование в игре; AI-генерация сама по себе не гарантирует правильность и безопасность.

### Участие
Пока не выпущен прототип, приветствуются аккуратно описанные предложения и сообщения об ошибках. Прежде чем присылать код, прочитайте [CONTRIBUTING.md](CONTRIBUTING.md). Уязвимости сообщайте по [SECURITY.md](SECURITY.md), **не публикуя детали атак**.

---

## English

### The idea
PEREKUP is a planned independent BeamNG.drive career experience about buying used vehicles, inspecting them in person, diagnosing issues, repairing them, and reselling them. Build a garage and a business, meet characters, and discover story missions while retaining the freedom to choose your own deals.

This repository currently contains **planning and project documentation only**, not a playable mod.

### Planned first playable milestone — v0.0.1
- Start in **East Coast USA**, with **$500**, a basic garage, and a choice of **three rough used starter vehicles**.
- A scripted mentor introduces the vehicle market.
- Discover stock vehicles and compatible vehicles from mods installed by the player; **no third-party vehicle assets bundled**.
- Listings with vehicle thumbnails, descriptions, and rough offline valuations.
- Buy → inspect → perform basic repairs → resell; track profit/loss.
- In-game clock/calendar, moderate difficulty, and persistent career progress.
- UI/dialogue language follows the player's preference; market currency follows the map's region. The first release targets **USD**.

Support for every third-party vehicle mod cannot be guaranteed. Some mods lack usable metadata, thumbnails, or configurations.

### Beyond v0.0.1
NPC personalities, uncertain vehicle history reports, interactive repairs, parts stores, towing, travel between default maps, banks and foreign exchange, a growing business, optional missions, and a grounded story. Community maps would require the authors' permissions. AI-driven NPC dialogue is a **possible future feature**, not an existing one.

### Open source and safety
- Free and open-source. Optional donations may be accepted in the future, without pay-to-win benefits.
- Early releases are designed to work offline without our own server, telemetry, or mandatory accounts.
- Never submit passwords, API keys, private information, or third-party proprietary assets.
- Original project source code: **GNU GPL v3** (see [LICENSE](LICENSE)); BeamNG.drive and third-party content retain their respective owners' rights.
- Unofficial fan project; not affiliated with BeamNG GmbH or car manufacturers.

### Authorship and AI assistance
Project concept, design direction, and maintenance: **Domidy53**. AI tools assist with development, design analysis, and documentation. Changes are intended to be reviewed and tested by people before release; AI-generated output is not assumed correct or secure.

Read [ROADMAP.md](ROADMAP.md), [CONTRIBUTING.md](CONTRIBUTING.md), and [SECURITY.md](SECURITY.md) before participating.
