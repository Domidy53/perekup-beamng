# Участие в разработке / Contributing to PEREKUP

**ПЕРЕКУП** — бесплатный проект с открытым исходным кодом для BeamNG.drive. Мы рады идеям, переводам, сообщениям об ошибках и полезным изменениям кода.

**PEREKUP** is a free, open-source BeamNG.drive project. We welcome ideas, translations, bug reports, and carefully reviewed code contributions.

**Языки документа:** [Русский](#русский) · [English](#english)

> **Текущий статус:** подготовка проекта. Играбельная версия пока не выпущена. Пожалуйста, не заявляйте, что функции уже работают, если их ещё не проверили в игре.  
> **Current status:** project preparation. No playable release has been published. Please do not claim features work until tested in-game.

---

## Русский

### 💡 Хочу предложить идею

Не обязательно разбираться в программировании, чтобы помочь проекту.

- **[Предложить новое название проекта](https://github.com/Domidy53/perekup-beamng/issues/6)** — «ПЕРЕКУП» пока рабочее название.
- **[Предложить механику, сюжетное задание или улучшение](https://github.com/Domidy53/perekup-beamng/issues)** — создайте новую тему (Issue) и объясните, что вы хотите видеть.
- Расскажите, как новая идея сделает интереснее покупку, диагностику, ремонт, перевозку или продажу автомобилей.
- Перед созданием темы проверьте, не предложил ли кто-то подобное ранее.

**Не обещаем, что каждая идея попадёт в игру.** Решения принимаются с учётом технических возможностей, безопасности и общего направления проекта.

### 🧑‍💻 Хочу помочь с кодом

1. Прочитайте [README.md](README.md), [ROADMAP.md](ROADMAP.md) и [SECURITY.md](SECURITY.md).
2. Крупные изменения сначала обсудите в GitHub Issue.
3. Создайте отдельную ветку и Pull Request в `main`. **Не вносите изменения напрямую в `main`.**
4. Опишите, что изменилось, как это проверить, на какой версии BeamNG.drive проводилось тестирование и какие ограничения остались.
5. Делайте небольшие, понятные изменения, которые можно безопасно проверить.
6. Если использовали нейросеть, **проверьте её результат** и укажите, в чём она помогала. Нельзя считать сгенерированный код автоматически безопасным или работающим.

### 🔐 Безопасность и ограничения

- **Нельзя публиковать** пароли, токены, API-ключи, приватные логи, личные данные, вредоносный код или файлы чужих модов без разрешения.
- Мод **не должен включать** автомобили, карты, 3D-модели, текстуры и другую собственность BeamNG.drive или сторонних авторов без соответствующих прав.
- На первом этапе игра должна работать **локально, без собственного сервера, телеметрии и обязательной регистрации**.
- Нельзя незаметно добавлять аналитику, сетевые запросы, сторонние сервисы или выполнение кода из интернета.
- Новые языки, задания, игровые регионы и адаптеры автомобилей по возможности делайте отдельными модулями.
- Об уязвимостях сообщайте по инструкции в [SECURITY.md](SECURITY.md), **не раскрывая детали публично**.

### 🚗 Границы первой версии

Первая цель — **East Coast USA**, экономика в долларах, локальные сохранения, динамический каталог доступных автомобилей, объявления, простая диагностика, ремонт и перепродажа.

Полноценные путешествия между странами, банковский обмен валют, нейросетевые NPC и расширенный сюжет — **планы на будущее**, а не готовые функции.

Все игровые функции планируются **бесплатными**. Будущие пожертвования будут добровольными и не дадут игровых преимуществ.

### ✅ Проверка перед отправкой Pull Request

- [ ] Изменение небольшое и понятное, связано с Issue или объяснено в описании.
- [ ] Я проверил изменения на отсутствие секретов, личных данных и случайно добавленных файлов.
- [ ] У меня есть права на все добавленные материалы, код, изображения и переводы.
- [ ] Я описал проверки и тесты, включая тестирование в BeamNG.drive, если оно проводилось.
- [ ] Я указал, использовался ли ИИ при создании материалов или кода.
- [ ] Я не добавлял сетевые запросы, аналитику и новые разрешения без отдельного обсуждения.

### 🐞 Как сообщить об ошибке

Создайте [Issue](https://github.com/Domidy53/perekup-beamng/issues) и укажите:
- Версию BeamNG.drive и версию мода или хеш коммита.
- Что вы делали и какие действия приводят к ошибке.
- Какое поведение ожидали и что произошло на самом деле.
- При необходимости — **очищенный от личных данных** фрагмент лога.

### 📄 Лицензия

Оригинальные материалы, предлагаемые для включения в проект, должны быть совместимы с лицензией **GNU GPL v3** (см. [LICENSE](LICENSE)). Отправляя собственный код, вы соглашаетесь на его распространение в составе проекта на этих условиях. Чужие материалы без разрешения отправлять нельзя.

---

## English

### 💡 Suggest an idea

You do not need programming skills to help.

- **[Suggest a new project name](https://github.com/Domidy53/perekup-beamng/issues/6)** — “PEREKUP” is a working title.
- **[Suggest a feature, story mission, or improvement](https://github.com/Domidy53/perekup-beamng/issues)** — open an Issue explaining what you would like to see.
- Describe how your idea improves finding, inspecting, repairing, transporting, or selling cars.
- Search existing Issues before opening a duplicate.

Submitting an idea **does not guarantee** it will be included. Decisions depend on technical feasibility, safety, and project direction.

### 🧑‍💻 Contribute code

1. Read [README.md](README.md), [ROADMAP.md](ROADMAP.md), and [SECURITY.md](SECURITY.md).
2. Discuss significant changes in an Issue before implementation.
3. Work on a separate branch and open a Pull Request to `main`. **Do not push directly to `main`.**
4. Describe what changed, how to test it, the BeamNG.drive version used, and any limitations.
5. Keep contributions small, focused, and reviewable.
6. Review all AI-assisted work carefully and disclose relevant AI assistance. Never present untested AI-generated code as safe or working.

### 🔐 Security and boundaries

- Never upload passwords, tokens, API keys, private logs, personal information, malware, or third-party assets without redistribution rights.
- Do not bundle BeamNG.drive or third-party vehicle/map models, textures, or other proprietary content without permission.
- The first versions are designed to run **locally and offline**, without a project-operated server, telemetry, or required accounts.
- Do not silently add analytics, network requests, third-party services, or remote code execution.
- Prefer optional modules for new languages, missions, game regions, and vehicle adapters.
- Report vulnerabilities using [SECURITY.md](SECURITY.md); **do not disclose exploit details in public Issues**.

### 🚗 Initial scope

The first milestone targets **East Coast USA**, USD, local saves, dynamic vehicle discovery, listings, basic inspection, repair, and resale.

Cross-country travel, bank currency exchange, AI-driven NPCs, and a large story are **future plans**, not implemented features.

The project is intended to remain **free**. Donations will be optional and will not grant gameplay advantages.

### ✅ Pull Request checklist

- [ ] My change is small and focused, tied to an Issue or clearly explained.
- [ ] I checked the diff for secrets, personal information, and accidental files.
- [ ] I have the rights to all contributed code, assets, images, and translations.
- [ ] I described testing, including BeamNG.drive manual tests if applicable.
- [ ] I disclosed relevant AI assistance.
- [ ] I did not introduce network calls, analytics, or new permissions without review.

### 🐞 Bug reports

Open an [Issue](https://github.com/Domidy53/perekup-beamng/issues) with the game version, mod version or commit, reproduction steps, expected versus actual behavior, and a sanitized log excerpt if useful. Never publish passwords or personal identifiers.

### 📄 License

Original contributions must be compatible with the project's **GNU GPL v3** license (see [LICENSE](LICENSE)). By submitting your original code for inclusion, you agree it may be distributed under that license. Do not submit material you lack the rights to redistribute.
