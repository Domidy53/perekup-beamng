# Security Policy / Политика безопасности

## Supported versions / Поддерживаемые версии
There is **no published playable release** yet. Security issues in the repository, documentation, future tooling, or test builds are still welcome.

Играбельных релизов пока нет. Сообщения об уязвимостях будущих сборок и инструментов приветствуются.

## Reporting a vulnerability / Как сообщить об уязвимости
**Do not post exploit instructions, secrets, private data, or unpatched vulnerabilities in public Issues or Pull Requests.**

1. If GitHub private vulnerability reporting is available, use the repository's **Security → Report a vulnerability** feature.
2. If unavailable, open a public issue **without technical exploit details** asking the maintainer to arrange a private reporting channel.
3. Never post passwords, tokens, authentication cookies, IP addresses of private infrastructure, or personal contact data.

**Не публикуйте** эксплойты, пароли, токены и личную информацию. При наличии используйте приватное сообщение через вкладку Security; если его нет — создайте Issue с просьбой связаться конфиденциально, без технических деталей.

## Security design / Правила разработки
- v0.0.1 is designed to run **locally and offline**; no project-operated public backend.
- No credentials or hidden keys in mod ZIPs, Lua, JavaScript, logs or documentation.
- No telemetry, device fingerprinting, IP geolocation or silent uploads.
- Dynamic vehicle discovery is data-driven: do not execute scripts from a listing, a vehicle name, or an untrusted API response.
- Local save files should be treated as untrusted input and parsed/validated conservatively.
- Do not automatically run executable contributions from unknown forks.
- Avoid dangerous GitHub Actions patterns such as running untrusted PR code with elevated credentials.
- Protect main via PR review workflow; keep Actions default permissions read-only whenever possible.
- Depend on third-party content only with appropriate permission; do not bundle ripped game assets.

## AI disclosure
AI tools may assist development. They are **not** a substitute for reviewing code, checking dependencies and testing. No confidential data should be pasted into public AI prompts or public commits.

## No security warranty
No software can be guaranteed completely secure. Please report defects responsibly.
