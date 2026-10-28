# Architecture / Архитектура (design draft)

> This file is an **implementation proposal**. The exact BeamNG.drive v0.40.x integration points require testing in-game. / Это проектная схема, пока не проверенная в игре.

## Principles
- Core game rules independent of UI and vehicle data.
- Local, versioned career saves outside the ZIP.
- Standard maps; no bundled BeamNG assets or third-party vehicle assets.
- Vehicle discovery reads the player's installed stock/mod configurations, validates metadata and fails gracefully.
- No servers, remote calls, telemetry, or API keys in early releases.
- Game region determines transaction currency and local market; player preference determines interface/dialogue language.

## Planned logical modules
| Module | Responsibility |
| --- | --- |
| `core` | Lifecycle, feature registration, guards |
| `vehicles` | Discover, normalize, classify compatible car/SUV configurations |
| `pricing` | Local reference prices, estimators, overrides, condition |
| `market` | Generate listings with preview images, buy/sell operations |
| `economy` | Money, cost ledger, time and later currency exchange |
| `inventory` | Parts, tools, stock, future physical cargo |
| `garage` | Ownership and garage slots |
| `repairs` | Simple inspect/repair actions, validated parts changes |
| `characters` | Scripted mentor and later seller personalities |
| `stories` | Expandable mission and event definitions |
| `world` | Map region, service points and later inter-map travel |
| `saves` | Versioned profile persistence, backups, migrations |
| `ui` | Player-facing panels, advertisements and images |

## First-run UX (v0.0.1 proposal)
1. Player enters **Free Roam → East Coast USA**.
2. Open the **PEREKUP** UI app and choose new career or continue.
3. Pick **one of three** compatible rough starter vehicles; start with **$500**.
4. Mentor introduces the first listing. Player can buy, inspect, do a simple repair and sell.
5. Local, recoverable save records money, ownership and progress.

A dedicated main menu entry is a **future option**, not required by the first release.

## Asset boundaries
Vehicle thumbnails should first use available in-game previews, with fallback placeholders or locally generated captures where permitted. Images remain at the player's installation; do not include third-party vehicle images or entire models in this repository.

## Compatibility and resilience
- Never interpret a vehicle title or mod package as executable commands.
- Persist stable vehicle identifiers and validated configuration data; if a mod disappears, keep the ownership record **unavailable** instead of corrupting the profile.
- Guard against duplicate purchases, negative balances and partial save writes.
- Keep saves schema-versioned; do not silently delete unknown data.
- Review compatibility on BeamNG updates and when third-party mods differ.

## Future expansion
Ports, banks/currency exchange, seller personality, localized dialogue, mechanic interactions, jobs and opt-in AI NPCs can be added as new features **only after the offline gameplay loop works**. A public backend is not required today.
