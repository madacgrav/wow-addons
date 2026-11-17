# Research Findings

> **Snapshot note.** Research ran on `main` at b8fc283; `main` has since been fast-forwarded to a1b8141 (2026-11-17). Items marked **[origin]** describe a1b8141 and are now current. WCK/WUK line numbers below come from b8fc283 (WCK `Core.lua` shifted ~+24, WUK `Core.lua` +4).

## Q1: What does each addon's README.md document, and how consistent is the structure?

### Findings
- Root `README.md:1-8`: title, one-line purpose ("Addons for WoW Forever. Each folder is one addon with its own README, changelog and GitHub release tag." `:3`), bullet list linking PP, WUK, WCK, TB with tag prefixes. **BusinessCard not listed** (also not on origin). No install section.
- `ProfessionPlanner/README.md`: metadata bullets `:5-7` (Client, Professions, Optional deps), `## Install` `:9`, `## Opening the panel` `:15`, `## Reading the panel` `:21` (sub: Header `:23`, Plan steps `:35`, Learn steps `:50`, Shopping list `:59`), `## Click to craft` `:76`, `## Getting better plans` `:83`, `## Slash commands` `:93`, `## Notes` `:100`, `## Development` `:106`. Links CurseForge Auctionator `:7`.
- `TackleBox/README.md`: metadata `:5-6` (Client, Language), `## Install` `:8`, `## The panel` `:14`, `## Fishing bar` `:28`, `## Cast bar and "got away" flash` `:41`, `## Slash commands` `:47`, `## Probe` `:58`, `## Notes` `:62`, `## Development` `:69`.
- `WarlockCombatKit/README.md`: link to sibling WUK `:5`, no metadata bullets, `## Install` `:7`, `## The panel` `:15`, `## CC highlight` `:32`, `## Proc alerts` `:40`, `## Rotation helper` `:49`, `## Mouseover cast slots` `:70`, `## Minimap button` `:79`, `## Settings window` `:85`, `## Slash commands` `:92`, `## Notes` `:102`, `## Development` `:110`.
  - **[origin]** adds `## Rotation buttons` section; core described as clickable Life Tap; settings toggles gain "Show rotation buttons".
- `WarlockUtilityKit/README.md`: metadata `:5-7` (Client, Class, Language), `## Install` `:9`, `## The ring` `:15` (Motion `:45`, Moving and hiding `:53`), `## Preferred pet` `:59`, `## Summon queue` `:68`, `## Healthstone trades` `:82`, `## Assignment board (groups)` `:91`, `## Cooldown Manager dock` `:112`, `## Minimap button` `:118`, `## Settings window` `:124`, `## Slash commands` `:138`, `## Notes` `:156`, `## Development` `:161`.
  - **[origin]** summon queue text revised (group-only, class colours), settings grouped Strip & ring / Pet / Frames, slash table adds `/wuk summon`.
- `BusinessCard/README.md` (34 lines): `## Features` `:5`, `## Commands` `:17`, `## Known limits` `:28`. Client noted inline `:3` ("WoW Forever addon (Interface 16001)"). **No Install/Notes/Development.**
- No README references images (`![`, png, jpg grep empty).
- Consistency: PP/TB/WCK/WUK share skeleton title → intro → (metadata) → Install → feature sections → Slash commands → Notes → Development. BusinessCard uses Features/Commands/Known limits. Command section named "Slash commands" in 4, "Commands" in BusinessCard.

## Q2: Slash command handlers, subcommands, help text, key bindings

### ProfessionPlanner `/pp` — `ProfessionPlanner/Core.lua:273-298`
- Parse `msg:lower():match("^(%S*)")` `:275` (first word; leading space ⇒ empty cmd).
- `probe` `:276` → `PP.Probe()` `:197-271`: prints/saves API facts for open profession window, Auctionator API, LibQuestieDB, bag enums (`PP.db.lastProbe`).
- `debug` `:277-297`: prints profession/ready state, recipe counts by colour, sample recipes.
- else → usage `"/pp probe"` `:298` (does not mention `debug`). No panel toggle command (panel docks to profession window).

### TackleBox `/tb` — `TackleBox/Core.lua:237-246`
- Parse `msg:lower():match("^%s*(%S*)")` `:239`.
- (empty) toggle `TB.db.shown` `:241`; `show`/`hide` `:240`; `lock` `:242`; `reset` (wipe frames, "/reload to apply") `:243`; `probe` → `TB.Probe()` `:161-235` `:244`; `flash` toggle `TB.db.flash` `:245`.
- Usage `"/tb show||hide||lock||reset||probe||flash"` `:246` (`||` escapes chat-link pipe, comment same line).

### BusinessCard `/bcard` — `BusinessCard/Core.lua:239-251`
- Parse `msg:match("^(%S*)%s*(.-)$")`, cmd lowered, arg case kept `:241-242`.
- (empty) → `BC.TogglePanel()` (refused in combat) `:243`, `Panel.lua:199-203`; `probe` `:244`; `ping <name>` → addon WHISPER ping `:245`, `:234-237`; `seen` → `PrintSeen()` up to 20 players `:246`, `:121-133`; `busy` / `avail` → `BC.ChangeStatus("g","b"|"a")` `:247-248`, `:174-178`; `lock` `:249`; `reset` `:250`.
- Usage `"/bcard (window) | seen | busy | avail | probe | ping <name> | lock | reset"` `:251`.
- Binding: `BusinessCard/Bindings.xml:2` `BUSINESSCARD_TOGGLE` (header `BUSINESSCARD`, category ADDONS) → `BusinessCard_Toggle()`; globals `Panel.lua:207-209` (`"BusinessCard"`, `"Toggle window"`).

### WarlockCombatKit `/wck` — `WarlockCombatKit/Core.lua:337-347` (shifted ~+24 lines on origin)
- Non-warlock ⇒ "warlocks only" `:339`. Parse first word `:340`.
- `probe` → `WCK.Probe()` `:246-335`; `lock` `:342`; `reset` `:343`; `config` → `WCK.ToggleSettings()` (`Settings.lua:157`) `:344`; `show`/`hide` `:345`.
- Usage `"/wck config||show||hide||lock||reset||probe"` `:346`. Slash handler unchanged on origin.
- Bindings: `WarlockCombatKit/Bindings.xml:2-7` `CLICK WCKCast1..6:LeftButton` (header WCK on first). Names `Actions.lua:3-4` ("Warlock Combat Kit", "Mouseover cast slot N", `WCK.SLOTS`=6 `Logic.lua:136`). Buttons are SecureActionButtonTemplate macro buttons `Actions.lua:10-20`; macro from `WCK.CastMacro` `Logic.lua:137-140` → `/cast [@mouseover,harm,nodead][] <spell>`.
- **[origin]** new `Rotation.lua` (rotation button bar), `showBar` default, spellbook scan `WCK.ScanSpellbook` on `SPELLS_CHANGED`.

### WarlockUtilityKit `/wuk` — `WarlockUtilityKit/Core.lua:244-267` (shifted +4 on origin)
- Non-warlock ⇒ "warlocks only" `:246`. Parse cmd + arg `:247`.
- `show`/`hide` (refused in combat) `:248-249`; `lock` `:250`; `reset` `:251`; `pet <imp|voidwalker|succubus|incubus|felhunter>` `:252-253` (validated `WUK.IsPet`, `Logic.lua:87-91`); `config` `:254`; `probe` `:255` (`:174-242`); `board` → `WUK.ToggleBoard()` (`Board.lua:164`) `:256`; `lead` → `WUK.ClaimLead()` (`Board.lua:23-28`) `:257`; `dock` (combat-blocked) toggles `dockViewers` `:258-262`; `spin`/`collapse` (combat-blocked) `:263-265`.
- **[origin]** adds `summon` → `WUK.ToggleSummon()`.
- Usage built at `:266` with `table.concat(WUK.PETS,"|")`; **[origin]** includes `summon`.
- Settings window calls handler via `Run(cmd)` `Settings.lua:5` (used `:27-57`).
- No `Bindings.xml`, no `BINDING_` globals.

## Q3: .toc metadata; CHANGELOG format; version ↔ changelog ↔ tag

### .toc
- All five: line 1 `## Interface: 16001`; order Interface, Title, Notes, Version, IconTexture, SavedVariables, SavedVariablesPerCharacter (L1-7). No Author/Dependencies.
- PP: Title "Profession Planner", Notes "Docked leveling planner and shopping list for the profession window.", 0.2.1, `Interface\Icons\Trade_Tailoring`, `## OptionalDeps: Auctionator, QuestieDB` `ProfessionPlanner.toc:8`.
- TB: "TackleBox", "Forever fishing companion: skill, where to fish, quest fish, catches, camp buffs, water-walking.", 1.0.0, `Trade_Fishing`.
- WCK: "Warlock Combat Kit", "In-combat cast map, rotation helper, proc alerts and mouseover casting for WoW Forever warlocks.", 0.1.0 (**[origin] 0.2.0**, adds `Rotation.lua` to load list), `Spell_Shadow_DeathCoil`.
- WUK: "Warlock Utility Kit", "Shards, stones, prep, summons and healthstone trades for WoW Forever.", 0.3.3 (**[origin] 0.5.0**), `INV_Misc_Gem_Amethyst_02`.
- BusinessCard: "BusinessCard", "Remembers who advertised professions, summons and portals; swaps cards and status with other BusinessCard users.", 0.8.5, `INV_Letter_15`.
- Icons are in-game texture paths, not repo files.

### CHANGELOG.md
- PP/TB/WCK/WUK: `# Changelog — <Name>` (L1); intro L3 "Versions match `## Version` in `<X>.toc`; each version is published as a `<prefix>-vX.Y.Z` GitHub release."; headings `## [X.Y.Z] — YYYY-MM-DD` (e.g. `ProfessionPlanner/CHANGELOG.md:5` `## [0.2.1] — 2026-10-20`); `### Added|Changed|Fixed`; bullets `- **Lead.** text`; newest first. Some versions have a summary paragraph (PP `:12`, TB `:7`); WCK nests bullets; TB `[0.1.0]` is prose only (`:22-24`).
- BusinessCard: `# Changelog` (L1), no intro, `## 0.8.5` (no brackets, no date, L3), plain bullets, no `###`; newest first.
- Top changelog version equals `.toc` Version in all five (local and origin: WCK 0.2.0 / 2026-11-16, WUK 0.5.0 / 2026-11-16 on origin).
- Tag = `<prefix>-v` + `.toc` Version (set by workflow, Q4).

## Q4: Packaging workflows; releases today

### Workflows (`.github/workflows/package-{pp,tb,wck,wuk,bcard}.yml`, 45 lines each, same shape)
- Triggers L3-7: `push` to `main` with `paths: ["<Dir>/**", ".github/workflows/<self>"]`, plus `workflow_dispatch`. No tag trigger.
- `permissions: contents: write` L9-10; job `package` on `ubuntu-latest`; only action `actions/checkout@v4` L16.
- Steps: install `lua5.1` + run `<Dir>/tests/run.lua` (L18-21); read version via `sed` from `.toc` (L23-28, fails if empty); `zip -r "<Dir>-<ver>.zip" <Dir> -x '<Dir>/tests/*'` (L30-31; PP also excludes `tools/*`); publish (L33-44): if release `<prefix>-v<ver>` exists ⇒ `gh release upload --clobber`, else `gh release create --target $GITHUB_SHA --title "<Display Name> $TAG" --generate-notes`.
- Release body = GitHub auto notes (PR list + compare link). CHANGELOG.md is **not** used.
- Display names: "Profession Planner", "TackleBox", "Warlock Combat Kit", "Warlock Utility Kit", "BusinessCard".

### Releases (`gh release list`, 2026-11-17)
- 16 releases. GitHub "Latest" flag: **wck-v0.2.0 only** (repo-wide, one at a time).
- Newest per prefix, asset URL pattern `https://github.com/madacgrav/wow-addons/releases/download/<tag>/<Dir>-<ver>.zip`:
  - `pp-v0.2.1` → `ProfessionPlanner-0.2.1.zip` (2026-10-20)
  - `tb-v1.0.0` → `TackleBox-1.0.0.zip` (2026-10-22)
  - `wck-v0.2.0` → `WarlockCombatKit-0.2.0.zip` (2026-11-16)
  - `wuk-v0.5.0` → `WarlockUtilityKit-0.5.0.zip` (2026-11-16)
  - `bcard-v0.8.5` → `BusinessCard-0.8.5.zip` (2026-11-16)
- One asset (the zip) per release. Release page URL `https://github.com/madacgrav/wow-addons/releases/tag/<tag>`.
- Repo: public, default branch `main`, no homepage URL set; `GET /repos/.../pages` ⇒ 404 (no Pages site configured).

## Q5: Install instructions and client AddOns layout

### Findings
- Install sections (PP `:9-13`, TB `:8-12`, WCK `:7-11`, WUK `:9-13`) share wording:
  1. "Download `<Addon>-X.Y.Z.zip` from the repo's GitHub releases (tag `<prefix>-vX.Y.Z`)." (PP:11, TB:10, WCK:9, WUK:11)
  2. "Extract it so that the folder `<Addon>` sits in `_classic_beta_\Interface\AddOns\`." (PP:12, TB:11, WCK:10, WUK:12)
  3. Varies: "Restart the game or `/reload`." (PP:13, WUK:13); "Restart the client." (TB:12); WCK:11 "Restart the game. A `/reload` is not enough on first install, because key bindings load at startup."; WCK:13 "The addon only loads for warlocks."
- BusinessCard and root README: no install text.
- Client: `## Interface: 16001` in every `.toc`; "Client: WoW Forever (Interface 16001)" PP:5, TB:5, WUK:5; BusinessCard:3 inline; WCK README no Interface number. Build `1.60.1.70450` only at TB:64.
- Client folder naming differs by source:
  - READMEs: `_classic_beta_\Interface\AddOns\` (all four install sections).
  - Recent `thoughts/` deploy steps (2026-11-16+): `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\<Addon>` — e.g. `2026-11-16-business-card-ui-redesign/plan.md:17`, `2026-11-16-wuk-soul-shard-bag/plan.md:8`, `GH-28-wck-spell-dropdown/plan.md:13`.
  - Older `thoughts/` (Oct): `_classic_beta_` — e.g. `2026-10-19-profession-leveling-planner/plan.md:20`, `GH-22-forever-fishing-addon/plan.md:21`; `2026-10-24-disc-priest-kit/task.md:3` "Interface 16001, `_classic_beta_` client".
- Zip layout: zip contains top-level `<Dir>/` folder (`zip -r ... <Dir>`), so extracting places `<Dir>` directly.
- In-game UI path for bindings: "Esc > Options > Keybindings > AddOns > Warlock Combat Kit" (WCK README:75).

## Q6: Files touched when an addon is created or changed

### Findings
- Development sections state the release rule: "CI runs the tests and publishes a release zip on every push to `main` that touches the addon. Bump `## Version` in the `.toc` to cut a new release." (PP:115, TB:77, WCK:118, WUK:169).
- Release commits touch: addon Lua, `<Addon>/CHANGELOG.md`, `<Addon>/README.md`, `<Addon>.toc` (Version line), `<Addon>/tests/run.lua`.
  - `9f647b5` "Merge main; release ring views as 0.5.0": WUK Board/CHANGELOG/Core/Logic/README/Settings/Summon/UI/toc/tests.
  - `144d3d8` "release Incubus pets as 0.3.3": WUK CHANGELOG/Core/toc (+ BusinessCard files from merge).
  - `251b35c` "Mark GH-28 plan verified; date 0.2.0": WCK CHANGELOG date only.
- Root `README.md` history: only `271df1e` Initial, `53e367a` (TB 1.0.0 docs), `fef47d3` (WCK 0.1.0 docs). Not touched for BusinessCard or later WUK/WCK releases.
- Plan files spell release steps as explicit file edits, e.g. `2026-11-16-wuk-preferred-pet-demons/plan.md:151` (insert CHANGELOG entry above previous version), `:160` (bump `.toc` Version). New-addon plans add a `package-<x>.yml` workflow and `tests/run.lua`.
- Each merge to `main` touching `<Dir>/**` runs that addon's workflow; tag/release created only when `.toc` Version is new, otherwise zip re-uploaded to existing release (Q4).
- Work flows through PRs from per-topic branches (`gh release view` bodies list PRs #17, #32, #36, #37).

## Q7: Existing static assets; .gitignore

### Findings
- No png/jpg/gif/svg/tga/blp/ico/html/css/js/ttf files; no `_config.yml`, `Gemfile`, `CNAME`, `docs/`, `Media/`, `Textures/`. Only `.yml` files are the five workflows.
- `.gitignore` (41 lines) = GitHub Lua template: `luac.out`, `*.src.rock`, `*.zip` (L6), `*.tar.gz`, object/lib/binary patterns (`*.o`, `*.dll`, `*.so`, `*.exe`, `*.out`, `*.app`, `*.hex`, …). Nothing site-related ignored.
- Each addon has `tests/run.lua` (plain Lua 5.1, run in CI); excluded from zips.

## Cross-Cutting Observations
- One addon = one top-level dir with `.toc`, `Core.lua` (single `SLASH_<NAME>1` + usage string), `README.md`, `CHANGELOG.md`, `tests/run.lua`, and one `package-<prefix>.yml`.
- Version source of truth: `.toc` `## Version`; CHANGELOG top entry and release tag mirror it.
- Five tag prefixes in one repo: `pp-v`, `tb-v`, `wck-v`, `wuk-v`, `bcard-v`. GitHub `releases/latest` resolves to whichever release was flagged Latest last (currently wck-v0.2.0), not per addon.
- Usage strings in Lua use `||` to print a single pipe in chat.
- BusinessCard is the outlier: no README Install section, different CHANGELOG format, missing from root README.
- Client folder documented as `_classic_beta_` in READMEs but `_forever_` in recent internal plans.

## Open Areas
- Which client folder name (`_classic_beta_` vs `_forever_`) current WoW Forever installs use is not settled by the repo; both appear.
- WCK/WUK origin line numbers not re-mapped; local checkout needs `git pull` (untracked `thoughts/` dirs that also exist upstream may block a fast-forward).
- `WoW Forever Addon Ideas — PRD.md` (untracked) not inspected.
- No info in repo on GitHub Pages settings beyond the API 404.
