# Roadmap / Дорожная карта

> This is a **plan**, not a list of implemented features. Dates are estimates, not promises. / Это **план**, а не список готовых функций.

## v0.0.1 — First playable loop / Первый играбельный цикл

**Goal:** enter Free Roam on East Coast USA, begin a PEREKUP career, purchase a used car, repair something, sell it, and load the saved progress.

- [ ] Create a reliable Lua extension bootstrap and minimal in-game UI for Free Roam.
- [ ] Create an offline profile; starting funds **$500**, a basic garage and **one of three available starter cars**.
- [ ] Scan in-game stock vehicle data and compatible installed car/SUV mods dynamically; never hardcode the entire fleet.
- [ ] Generate a small market with realistic-enough **provisional** USD values, listings, and locally available vehicle preview images.
- [ ] Support buying and ownership; basic inspection and repair of a limited number of known failure types.
- [ ] Resell and calculate expenses, profit and loss.
- [ ] Add in-game date/time, moderate difficulty, and a very simple scripted mentor.
- [ ] Save/load career state with versioned data and safe fallbacks for removed vehicle mods.
- [ ] Package a testable ZIP; collect in-game crash reports without private data.

**Deliberately deferred:** cross-map travel, bank/exchange, advanced AI NPCs, broad vehicle-specific animations, detailed laws/taxes, network servers.

## v0.0.x — Stabilize and expand
- [ ] More reliable prices per real-world model, year, trim, and condition; manual overrides for unknown mods.
- [ ] Better repair interactions, compatible parts, stores and transporting parts.
- [ ] Seller personalities, refusal of inspections, hidden defects and optional tests.
- [ ] Improved buyer negotiation, vehicle history reports, additional jobs and story arcs.
- [ ] More testing, game version compatibility, accessibility, language translations.

## Later — More regions and business progression
- [ ] Default-map travel via ports/terminals with persistent vehicle state.
- [ ] Separate currency balances, exchange at banks, transaction fees and local markets.
- [ ] Garage upgrades, employees, showrooms, towing and complex logistics.
- [ ] More missions, competitors and serious narrative consequences.
- [ ] Additional community maps **only with appropriate permissions**.
- [ ] Investigate opt-in AI NPC dialogue **only if justified** by cost, privacy, rate limits and security.

## Development principles / Принципы
1. **Safety first:** no credentials, private information, unreviewed code execution or unnecessary infrastructure.
2. **Playability first:** each milestone should improve a working gameplay loop.
3. **Offline first:** no required server, cloud account or telemetry for v0.0.1.
4. **Mod compatibility:** discovery, validation, graceful fallback, no bundling others' vehicles.
5. **Respect creators:** original code only unless explicit redistribution rights exist.
6. **Human review:** AI-assisted contributions still need manual code review and game testing.
