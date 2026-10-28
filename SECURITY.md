# Политика безопасности / Security Policy

**Русский ниже первым. English version follows.**

## Русский

### Поддерживаемые версии
**Играбельных релизов пока нет.** Тем не менее сообщать о возможных проблемах безопасности документации, инструментов и будущих тестовых сборок можно уже сейчас.

### Как сообщить об уязвимости
**Не публикуйте в открытых Issues или Pull Requests пароли, токены, личные данные, инструкции по эксплуатации уязвимостей или подробности ещё не исправленных проблем.**

1. Если доступна функция **Security → Report a vulnerability**, используйте её для приватного сообщения.
2. Если она не включена, создайте публичный Issue **без технических подробностей уязвимости** с просьбой согласовать конфиденциальный канал связи.
3. Никогда не прикладывайте токены, cookies, адреса частной инфраструктуры, пароли или личные контакты.

### Наши правила
- Ранняя версия должна запускаться **локально и офлайн**: никакого обязательного сервера.
- Не добавляем ключи доступа в ZIP, Lua, JavaScript, логи и документацию.
- Не собираем телеметрию, IP-адреса, отпечатки устройств и не отправляем данные игрока без его ведома.
- Названия машин, данные объявлений и сторонние метаданные **не должны интерпретироваться как команды или исполняемый код**.
- Сохранения проверяем как потенциально недоверенные данные; ошибочные файлы не должны ломать игру.
- Не запускаем автоматически непроверенный код из чужих Pull Requests.
- Не выдаём повышенные права и секреты рабочим процессам GitHub Actions, запущенным непроверенными изменениями.
- Основная ветка защищена Pull Request; права автоматизаций должны быть минимальными.
- Не включаем в репозиторий чужие автомобили, карты и файлы игры без соответствующих разрешений.

### Использование ИИ
ИИ помогает разрабатывать мод, но **не заменяет проверку кода, зависимостей и тестирование**. Конфиденциальные данные не должны попадать в открытые промпты, Issue или коммиты.

### Ограничение гарантий
Абсолютную безопасность программного обеспечения гарантировать невозможно. Если нашли проблему, сообщите о ней ответственным способом.

---

## English

### Supported versions
There is **no published playable release** yet. Security concerns about the repository, documentation, future tooling, and test builds can still be reported.

### Reporting vulnerabilities
**Do not publicly post exploit instructions, credentials, private information or details of unpatched vulnerabilities in Issues or Pull Requests.**

1. If available, use **Security → Report a vulnerability** for private reporting.
2. Otherwise, open an Issue **without exploit details** asking the maintainer to arrange a confidential reporting channel.
3. Never submit passwords, authentication cookies, personal contacts, or private infrastructure addresses.

### Security design
- Initial versions are **local and offline**; no required project-operated backend.
- No embedded secrets or API keys in shipped code, archives, logs or docs.
- No telemetry, IP geolocation, device fingerprinting or silent uploads.
- Treat listing data, vehicle titles and mod metadata as data, **not executable instructions**.
- Validate local career saves conservatively and fail safely on malformed files.
- Never automatically execute unreviewed code from outside Pull Requests.
- Do not expose elevated GitHub Actions credentials to untrusted contributions.
- Maintain protected main and minimal workflow permissions.
- Do not bundle proprietary BeamNG.drive or third-party vehicle/map assets without permission.

### AI assistance
AI can assist development but is **not** a substitute for code review, dependency inspection and in-game testing. Do not publish confidential data in prompts or commits.

### No security warranty
No software can be guaranteed completely secure. Please report vulnerabilities responsibly.
