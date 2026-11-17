# Design Discussion

## Current State
- Five addons, one top-level dir each: ProfessionPlanner, TackleBox, WarlockCombatKit, WarlockUtilityKit, BusinessCard. Each has `.toc`, `README.md`, `CHANGELOG.md`, `tests/run.lua` and a `package-<prefix>.yml` workflow (research Q3, Q4).
- The `.toc` `## Version` line is the source of truth. CI reads it, zips `<Dir>`, and creates release `<prefix>-v<ver>` with one asset `<Dir>-<ver>.zip` (`package-*.yml:23-44`). Prefixes: `pp-v`, `tb-v`, `wck-v`, `wuk-v`, `bcard-v`.
- GitHub "Latest" is repo-wide (currently `wck-v0.2.0`), so `releases/latest` cannot give a per-addon download (research Q4).
- Root `README.md:1-8` is a short index of 4 addons. BusinessCard is missing.
- No site exists: no HTML/CSS/JS/images/`docs/`/`_config.yml`; Pages is not enabled (API 404) (research Q4, Q7).
- READMEs tell players to extract into `_classic_beta_\Interface\AddOns\` (PP:12, TB:11, WCK:10, WUK:12). Current deploys use `_forever_\Interface\AddOns\` (recent `thoughts/*/plan.md`, user memory).
- BusinessCard differs: README has Features/Commands/Known limits only (`BusinessCard/README.md:5,17,28`), and the CHANGELOG uses `## 0.8.5` headings with no date (`BusinessCard/CHANGELOG.md:3`). Its 20 versions (0.1.0–0.8.5) were all committed on 2026-11-16 (`git log -- BusinessCard/BusinessCard.toc`).
- READMEs contain relative links: `[CHANGELOG.md](CHANGELOG.md)` (PP:115, TB:77, WCK:129, WUK:166) and `../WarlockUtilityKit/` (WCK:5).

## Desired End State
A GitHub Pages site at `https://madacgrav.github.io/wow-addons/` with:
1. **Intro:** what the repo is (WoW Forever addons, one folder per addon, released through GitHub) and its purpose.
2. **Install guide:** download the zip, extract so `<Addon>\` sits in `World of Warcraft\_forever_\Interface\AddOns\`, restart the game (`/reload` is enough for updates; WCK needs a full restart on first install for key bindings), and enable it on the character-select AddOns screen. Includes how to update and uninstall.
3. **Tabbed addon view:** one tab per addon. Each tab has:
   - a header card built from the `.toc`: Title, Notes, Version, Interface, plus a **Download vX.Y.Z** button linking the newest `<prefix>-v*` release zip, and a link to that release page;
   - the addon's `README.md` rendered (description, how it works, slash commands, bindings, notes);
   - the addon's `CHANGELOG.md` rendered under its own heading.
4. **Self-updating.** All content is fetched live from `main` and the Releases API, so a new release or README edit shows up with no site change. A new addon needs one line in the site's addon list.

Verify:
- Open the Pages URL. All five tabs render. Each Download button points at the same zip `gh release list` reports as newest for that prefix.
- The page also works when opened from a local static server (`python -m http.server` in `docs/`), since it fetches absolute GitHub URLs.
- Deep link `#WarlockUtilityKit` opens that tab.
- If the API is rate-limited or offline, the download button falls back to the filtered releases page and the rest still renders.

## Patterns to Follow
- **Version source = `.toc`** (`package-*.yml:23-28`, the README Development sections PP:115 etc.). The header card parses `## Version`, `## Title`, `## Notes` and `## Interface` from the raw `.toc` with the same `^## Key: value` shape the workflow `sed` uses. Do not hard-code versions in the site.
- **Release naming** `<prefix>-v<ver>`, asset `<Dir>-<ver>.zip` (`package-*.yml:36-44`). Pick the newest release per prefix by `published_at` from `GET /repos/madacgrav/wow-addons/releases?per_page=100`, and take the asset whose name ends in `.zip`.
- **Addon registry = dir + prefix.** Mirrors the workflow pair (`<Dir>`, `<prefix>`). The site keeps one array `[{dir:"ProfessionPlanner", prefix:"pp"}, …]`.
- **CHANGELOG format** `## [X.Y.Z] — YYYY-MM-DD` + `### Added/Changed/Fixed` (`ProfessionPlanner/CHANGELOG.md:1-5`). BusinessCard is converted to this format.
- **README Install skeleton** (PP:9-13): download zip from release tag, extract the folder, restart. BusinessCard gains the same section. All five switch the path to `_forever_`.
- **Do NOT follow:**
  - Relative README links: they break when rendered off-repo. The site rewrites relative `href`s to `https://github.com/madacgrav/wow-addons/blob/main/<Dir>/<path>`, and rewrites `CHANGELOG.md` links to the in-page changelog anchor.
  - The repo-wide `releases/latest` URL: it is wrong for 4 of 5 addons.
  - Lua's `||` escaping in usage strings (`TackleBox/Core.lua:246`): it is chat-only. READMEs already show single pipes, and the site renders READMEs, not Lua.

## Design Decisions
1. **Content source: live fetch in the browser.** Content comes from `raw.githubusercontent.com/madacgrav/wow-addons/main/<Dir>/{<Dir>.toc,README.md,CHANGELOG.md}` and the releases API. Why: zero upkeep per release, so "update every time an addon changes" happens automatically. Raw and API endpoints allow CORS. Cost: about 15 raw fetches plus 1 API call per page load. The API limit is 60/hour per visitor IP, which is fine for one call.
2. **Single file `docs/index.html`, inline CSS/JS.** Markdown is rendered by `marked` pinned from cdnjs. No build step, no framework. Why: the fewest moving parts. A tab bar is a few lines of JS plus `location.hash`.
3. **Pages source: deploy from branch `main`, folder `/docs`.** Plus `docs/.nojekyll`. Why: no workflow needed. `.nojekyll` stops Jekyll processing. The repo setting has to be switched on once (`gh api -X POST repos/madacgrav/wow-addons/pages` with `source.branch=main, path=/docs`), with user approval at implement time.
4. **Tab layout: header card (from `.toc` + release), then README, then CHANGELOG.** The README's own `# Title` H1 is dropped (the card shows the title). Why: the READMEs already hold features, commands and notes, so there is no duplicate copy to maintain.
5. **Install path `_forever_`.** It is used on the site and in all 4 existing README Install sections plus the new BusinessCard one. Why: it matches the current client (user decision).
6. **BusinessCard brought in line:**
   - add an `## Install` section to its README;
   - add it to the root README index;
   - rewrite its CHANGELOG to `# Changelog — BusinessCard`, add the standard intro line, and change each heading to `## [X.Y.Z] — 2026-11-16`. Every version shipped that day, so `### Added/Changed/Fixed` subheadings are skipped for its history.
   - No version bump. A README/CHANGELOG-only push still re-runs `package-bcard.yml`, which re-uploads the same zip with `--clobber` (`package-*.yml:38-40`). That is harmless.
7. **Root README links to the site.** It also gets the BusinessCard line, and the repo homepage URL is set to the Pages URL (`gh repo edit --homepage`).
8. **Keeping it current, for new addons:** the site needs a new array entry, plus a root README line and workflow as today. Record this as a memory note and as a line in each README's Development section ("new addon: add to `docs/index.html` ADDONS"). Existing addon updates need nothing.
9. **Look:** dark, WoW-ish palette (deep purple/near-black, gold accents), tokens on `:root`, a light-mode override via `prefers-color-scheme`, and a 16px gutter at phone width with tabs that wrap or scroll horizontally. The `.toc` IconTexture is an in-game path, so no icons. The style is text-only.

## What We're NOT Doing
- No static generation, build workflow, Jekyll theme or framework.
- No screenshots or images (none exist in repo; research Q7).
- No changes to `package-*.yml`, release notes (still `--generate-notes`) or Lua code.
- No version bumps or new releases of any addon.
- No search, i18n, analytics or custom domain.
- No CurseForge/WowUp packaging metadata.
- No rewrite of README contents beyond the Install path and BusinessCard's new Install section.

## Open Risks
- **Rate limit:** a visitor behind a busy NAT may hit 60 calls/hour. The fallback link to `releases?q=<prefix>-v` keeps download reachable; cache the API response in `sessionStorage`.
- **raw.githubusercontent caching:** it serves about 5 minutes stale after a push. Acceptable.
- **README markdown edge cases:** tables, nested lists and `<kbd>`-style HTML. `marked` handles GFM. HTML in READMEs is our own content, so there is no sanitizer. If third-party content is ever rendered, add DOMPurify.
- **Pages enable API** needs admin scope on the `gh` token. If it fails, the user flips Settings → Pages → `main` /docs by hand.
- **`_forever_` path:** this assumes the default install root `C:\Program Files (x86)\World of Warcraft\`. The site says "your World of Warcraft folder" and shows that default as an example.
- **More than 100 releases:** past 100, `per_page=100` could miss an old addon's newest release. That is far off. Add pagination if the release count approaches 100.
