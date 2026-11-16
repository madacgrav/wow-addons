# Research Findings

Paths are relative to `WarlockUtilityKit/` unless stated otherwise.

## Q1: How is the `WUKStrip` ring built and laid out?

### Findings
- **Constants**: `KINDS = { shard, healthstone, soulstone, spellstone, firestone }` (`UI.lua:3`). `FALLBACK` textures per kind (`UI.lua:5-9`). The sizes are `R=58` (ring radius), `CORE=44`, `BTN=36` and `LABELS=30` (`UI.lua:10`).
- **Orbit order**: `ORBIT = { healthstone, soulstone, spellstone, firestone, armor, pet }`, placed clockwise from 12 o'clock (`UI.lua:11`). Six orbit slots. `shard` is the centre "core".
- **Strip frame**: the init creates `CreateFrame("Frame", "WUKStrip", UIParent)` (`UI.lua:111`). Its size is `2*(R+BTN/2)+8` square plus `LABELS` (`UI.lua:113-114`). Its state fields are `f.angle`, `f.radius` and `f.targetRadius` (`UI.lua:115`).
- **Background**: a "summoning circle" made of three masked discs, `rim`, `disc` and `swirl`, built by the local `Disc()` helper (`UI.lua:53-59`, `117-119`). The swirl texture (`Spell_Shadow_Twilight`) rotates with a looping Rotation animation lasting 90s (`UI.lua:120-123`).
- **Stone buttons**: one per `KINDS` entry, `CreateFrame("Button", "WUKStone_"..kind, f, "SecureActionButtonTemplate")` (`UI.lua:126-128`).
  - Size is CORE for shard and BTN otherwise. The core gets frame level +3 so collapsed orbit buttons hide under it (`UI.lua:129-131`).
  - Children: `b.icon`, an ARTWORK texture with SetAllPoints (`UI.lua:134`); `b.shine`, a Scale pop animation group (`UI.lua:135-138`); `b.count`, a `NumberFontNormal` FontString at the bottom right (`UI.lua:139-140`); and a highlight texture `ButtonHilight-Square` ADD (`UI.lua:141`).
  - All buttons are stored in `f.icons[kind]` (`UI.lua:142`).
- **Armor and pet buttons**: created in `Prep.lua` as `WUKArmorButton` and `WUKPetButton`, both `SecureActionButtonTemplate` 36x36 parented to `WUK.strip`. They are registered into `WUK.strip.icons.armor` and `.pet` so the ring lays them out (`Prep.lua:5-6`, `24-25`). The two buttons have the same structure: icon, highlight and glow, with no count or shine (`Prep.lua:9-10`, `28-29`).
- **Labels**: `f.stone` holds the soulstone timer at the bottom +20 (`UI.lua:144-145`). `f.assign` holds the assignment text at the bottom +6 (`UI.lua:146-147`).
- **Startup**: the init stores the frame as `WUK.strip` (`UI.lua:148`). It then calls `MakeMovable(f, "strip", 0, -220)`, which allows Shift+drag and saves to `db.frames.strip` (`UI.lua:13-26`, `149`), calls `ApplyShown()` (`UI.lua:28-30`), and registers `CombatFreeze` on `PLAYER_REGEN_DISABLED` (`UI.lua:151`).
- **Layout**: `WUK.LayoutRing()` (`UI.lua:33-50`).
  - It returns early in combat (`UI.lua:35`).
  - It centres the shard core (`UI.lua:37`), then places each ORBIT button with `WUK.RingPoint(i, #ORBIT, s.radius, s.angle)` (`UI.lua:38-40`).
  - Alpha is `radius/R`, and mouse input is enabled only while `radius > 0` (`UI.lua:41`).
  - When the ring is collapsed below R/2, the core pulses if any orbit button is alerting (`UI.lua:44-46`).
  - The discs are resized with the radius (`UI.lua:48-49`).
- **RingPoint**: a pure function in `Logic.lua:174-177`. It returns `sin`/`cos` offsets, clockwise from 12 o'clock, rotated by `offsetDeg`.
- **Animation**:
  - `Step()` runs as the OnUpdate script (`UI.lua:68-80`). Spin is `SPIN=6` deg/s. Bloom/collapse takes `BLOOM=0.2` s (`UI.lua:61`).
  - `Target()` returns 0 (collapsed) when `db.collapse` is set, the player is not in combat and the mouse is not over the strip; otherwise it returns R (`UI.lua:64-66`).
  - The animator removes itself when idle (`UI.lua:79`). `WUK.Animate()` restarts it (`UI.lua:83-85`).
  - `CombatFreeze()` forces the full radius and stops the animator (`UI.lua:88-93`).
- **Refresh**: the stone refresher at `UI.lua:154-172` handles each KIND:
  - Icon: `C_Item.GetItemIconByID(id)`, cached in `db.icons[kind]`, falling back to `FALLBACK` (`UI.lua:157-159`).
  - Desaturated when the count is 0 (`UI.lua:160`).
  - Glow alert for healthstone or soulstone when the count is 0 and the create spell is known (`UI.lua:161`).
  - Count text (`UI.lua:162`). Shine plays when the count goes from 0 to more than 0 (`UI.lua:163-164`).
  - Macro attribute, set out of combat only (`UI.lua:165-168`).
  - Then `LayoutRing()` and `Animate()` (`UI.lua:171`).
- **Armor and pet refreshers**:
  - Armor (`Prep.lua:12-19`): texture from `C_Spell.GetSpellTexture(spellName)`, or 134400 (the "?" icon). Desaturated when the buff is up (armor) or the chosen pet is not out (pet). Alert when the spell is known and the buff or pet is missing.
  - Pet (`Prep.lua:31-39`): same pattern.

## Q2: How are click actions wired on the ring buttons?

### Findings
- **Stone buttons**: `RegisterForClicks("AnyUp","AnyDown")` and `SetAttribute("type","macro")` (`UI.lua:132-133`). There is a single unmodified `macrotext`, with no `type1`/`type2` and no modifier variants, so every mouse button runs the same macro.
- **`WUK.StoneMacro(kind, count, itemID, createSpell, ssTarget)`** (`Logic.lua:26-36`):
  - shard returns nil, so the macrotext is `""` (`Logic.lua:27`; `UI.lua:168` uses `or ""`).
  - With a stone held: soulstone produces `/use [@target] item:ID` when an assigned target exists. Otherwise it produces `/use [help] item:ID; [@player] item:ID` (`Logic.lua:29-32`). Other stones produce `/use item:ID` (`Logic.lua:33`).
  - With no stone held: `/cast <highest known create spell>`, or nil (`Logic.lua:35`).
  - The assigned soulstone target comes from `WUK.MySoulstoneTarget()` (Board, `Board.lua:11`) (`UI.lua:167`).
- **Armor and pet**: `type="macro"` with macrotext `/cast <known spell name>`, set only when `not InCombatLockdown()` (`Prep.lua:18`, `38`).
- **Summon rows**: these use per-button attributes: `type1`/`ctrl-type1` = macro, `macrotext1` = `/target X\n/cast Ritual`, and `ctrl-macrotext1` = `/target X` (`Summon.lua:77`, `46-47`). Right-click has no secure attribute and is handled by an insecure `HookScript` (Q6).
- **Combat behaviour**:
  - Attribute writes are guarded by `InCombatLockdown()` at `UI.lua:165`, `Prep.lua:18`, `38` and `Summon.lua:39`.
  - Movement and layout are blocked in combat (`UI.lua:35`, `69`, `84`).
  - `PLAYER_REGEN_DISABLED` leads to `CombatFreeze`, which expands the ring before lockdown starts (`UI.lua:87-93`, `151`).
  - `PLAYER_REGEN_ENABLED` leads to `WUK.Refresh`, which re-applies all deferred attributes (`Core.lua:156`).
  - Texture, desaturation, glow and count updates do still run in combat, because they are inside refreshers with no guard (`UI.lua:157-164`, `Prep.lua:14-17`).
  - `/wuk show|hide|dock|spin|collapse` are refused in combat (`Core.lua:248`, `259`, `264`).
- **Refresh triggers** (`Core.lua:147-159`): `PLAYER_LOGIN` (init and then refresh), `BAG_UPDATE_DELAYED`, `PLAYER_REGEN_ENABLED`, `SPELLS_CHANGED` (rescans spells), `UNIT_AURA` for the player, and `UNIT_PET` for the player.

## Q3: How are spells resolved and tracked as "known"?

### Findings
- **`SPELLS`** is a local table in `Core.lua:48-62`. Each entry maps a key to a list of names, ordered highest rank first.
  - `armor` = Demon Armor, Demon Skin.
  - `detect` = Detect Greater, Detect, Detect Lesser Invisibility.
  - Pets: `imp`, `voidwalker`, `succubus`, `incubus`, `felhunter`, one "Summon X" each.
  - `soullink`, `ritual`.
  - Stone creation: `healthstone`, `soulstone`, `spellstone` and `firestone`, each with ranked "Create X (Rank)" names.
  - `curseshadow`.
- **Comment** at `Core.lua:46-47`: ranked stone spells have distinct names in the Classic era, so the first known name wins. Same-name ranked spells such as Demon Armor cast their highest rank through `/cast Name`.
- **`SpellbookNames()`** (`Core.lua:64-85`): uses the mainline `C_SpellBook` skill-line API when it exists (`Core.lua:66-74`). Otherwise it falls back to `GetNumSpellTabs`/`GetSpellBookItemName` (`Core.lua:75-82`). It returns a set of names.
- **`WUK.ScanSpells()`** (`Core.lua:87-93`): for each SPELLS key it stores the first name found in the spellbook, so `WUK.known[key] = "<spell name>"`. The values are names, not spell IDs. It runs at `PLAYER_LOGIN` and on `SPELLS_CHANGED` (`Core.lua:151`, `157`).
- **`WUK.SpellName(spellID)`** (`Core.lua:164-168`): converts an ID to a name through `C_Spell.GetSpellInfo(id).name`. It is used only to recognise casts in `UNIT_SPELLCAST_SUCCEEDED` (`Prep.lua:43`, `Summon.lua:90`).
- **Who reads `WUK.known`**:
  - `armor`: `Prep.lua:13`.
  - The pet keys: `Prep.lua:32-33`.
  - `ritual`: `Summon.lua:44`, `46`, `90`.
  - The stone kinds: `UI.lua:161`, `168`.
  - `curseshadow`: `Board.lua:117`.
  - `detect` and `soullink` are scanned but **no code reads them**. A grep for `known.` and `known[` finds no other reads.
- **Pet keys**: `WUK.PETS = { imp, voidwalker, succubus, incubus, felhunter }` in `Logic.lua:87`. These keys double as SPELLS keys and as the lower-cased `UnitCreatureFamily`. `PetIsOut` accepts "succubus" for the incubus choice (`Logic.lua:92-95`).
- **Not in SPELLS**: none of the following appear anywhere in WarlockUtilityKit.
  - Buffs and utilities: Shadow Ward, Unending Breath, Eye of Kilrogg, Sense Demons, Fel Domination, Demonic Sacrifice, Health Funnel, Enslave Demon.
  - Summons: Summon Felguard, Inferno (Infernal), Ritual of Doom (Doomguard), and the Summon Felsteed/Dreadsteed mounts.
  - Curses other than Shadow live in `WUK.CURSES` (`Logic.lua:97-104`) and are not part of SPELLS.

## Q4: What tooltip code exists, and what tooltip API is available?

### Findings
- **Existing tooltip**: there is one, on the minimap button (`Settings.lua:102-108`).
  - `OnEnter`: `GameTooltip:SetOwner(self, "ANCHOR_LEFT")`, then `AddLine("Warlock Utility Kit")`, then `AddLine("Click: settings   Right-click: board   Drag: move", 1,1,1)`, then `Show()`.
  - `OnLeave`: `GameTooltip_Hide`.
- **Ring buttons**: none of them (stones, armor, pet) set OnEnter or OnLeave. Grepping `OnEnter`, `SetSpellByID` and `SetSpell` across `*.lua` matches only `Settings.lua:102`.
- **Available API data**:
  - The addon already calls `C_Spell.GetSpellInfo` (`Core.lua:166`), `C_Spell.GetSpellTexture(name)` (`Prep.lua:14`, `34`) and `C_Item.GetItemIconByID` (`UI.lua:157`).
  - Item IDs and bag slots for each stone kind are held in `WUK.counts.ids[kind]` and `WUK.counts.slots[kind]` (`Core.lua:38-39`).
  - Spells are held by name only (`WUK.known`).
- **Client API, from general WoW API knowledge (not verified in this repo or on the Forever client)**:
  - `GameTooltip:SetSpellByID(id)` exists on both mainline and Classic-era clients.
  - `GameTooltip:SetItemByID(id)` and `GameTooltip:SetBagItem(bag, slot)` exist on both.
  - On mainline, `C_Spell.GetSpellInfo(nameOrID)` returns a table that includes `spellID`.
  - The addon calls several mainline-only APIs: `C_SpellBook`, `WowStyle1DropdownTemplate` (with its comment "Mainline 11.0+ menu API", `Settings.lua:40-41`), `issecretvalue` and `C_CooldownViewer`. So the Forever client (`## Interface: 16001`, `WarlockUtilityKit.toc:1`) exposes mainline-style APIs.

## Q5: How does per-button visual state work, and what is persisted?

### Findings
- **Glow** (`WUK.AddGlow`, `UI.lua:96-103`): an OVERLAY texture `UI-ActionButton-Border` with ADD blend. It has `SetVertexColor(0.7, 0.3, 1)` (purple) and is 1.8x the button size, hidden by default. An Alpha animation loops in BOUNCE mode from 0.15 to 1 over 0.6s. Comment: "textures only, so safe in combat" (`UI.lua:95`).
- **`WUK.SetAlert(b, on)`** (`UI.lua:105-110`): toggles the glow and pulse, deduplicated through `b.alerting`.
- **Desaturation**: `icon:SetDesaturated(...)` at `UI.lua:160`, `Prep.lua:16` and `Prep.lua:36`. This is the only per-icon "state colour" in use. Glow is the only `SetVertexColor` in the addon, and no button icon is tinted.
- **Other visuals**: highlight on hover via `SetHighlightTexture` at `UI.lua:141`, `Prep.lua:10` and `29`. Shine pop at `UI.lua:135-138` and `163`. Alpha follows the ring radius at `UI.lua:41`. Disc colours are set once at `UI.lua:117-118`.
- **Account saved variables** (`WarlockUtilityKitDB`, `DEFAULTS` at `Core.lua:19`):
  - `locked`, `shown`, `frames` (positions), `icons` (cached stone textures), `minimapAngle`, `dockViewers`, `spin`, `collapse`.
- **Character saved variables** (`WarlockUtilityKitCharDB`, `CHAR_DEFAULTS` at `Core.lua:20`): `pet`, plus runtime keys `soulstone` (`Prep.lua:44`) and `board` (`Board.lua:171`).
- **Merging**: both tables are merged with `WUK.MergeDefaults` at `ADDON_LOADED` (`Core.lua:22-28`; `Logic.lua:16-23`).
- **Not persisted**: no ring-level "mode" or page state exists. Runtime fields reset on reload: `strip.angle`/`radius` (`UI.lua:115`), `b.alerting`, and `b.lastCount` (nil at login, so no shine at login, `UI.lua:163`).

## Q6: What constraints apply to changing secure buttons from a click handler?

### Findings
- **In-repo patterns**:
  - Secure buttons: `SecureActionButtonTemplate` only (`UI.lua:128`, `Prep.lua:5`, `24`, `Summon.lua:74`).
  - Mixed secure and insecure: summon rows keep the secure macro on button 1 and add `HookScript("OnClick", fn)` for RightButton up, which mutates the Lua queue and calls `UpdateSummonRows()` (`Summon.lua:80-82`). `UpdateSummonRows` then does `SetAttribute`, `Show` and `Hide` on the rows, and returns early in combat (`Summon.lua:39`).
  - Insecure buttons use plain `SetScript("OnClick")`: minimap (`Settings.lua:99`), settings and board buttons (`Settings.lua:53`, `57`; `Board.lua:139`), and checkboxes (`Settings.lua:12`).
  - Not used anywhere in the repo: `SecureHandlerClickTemplate`, `SecureHandlerWrapScript`, `SetFrameRef` and `RegisterStateDriver` (repo-wide grep).
- **Lockdown practice in the code**:
  - Every `SetPoint`, `ClearAllPoints`, `EnableMouse`, `SetAttribute` and `Show`/`Hide` on secure buttons or their parent is guarded by `InCombatLockdown()`: `UI.lua:35`, `165`; `Prep.lua:18`, `38`; `Summon.lua:39`; `Core.lua:248` (strip show/hide).
  - Texture-level calls (`SetTexture`, `SetDesaturated`, glow `Show`) run unguarded in combat.
- **Client rules, from general WoW API knowledge (not verified on Forever)**:
  - During combat lockdown, insecure code cannot `Show`, `Hide`, `SetPoint`, `SetAttribute` or `EnableMouse` on protected frames. Secure buttons and their parents count as protected.
  - Regions such as textures and font strings on those frames can still be changed.
  - Secure snippets (`SecureHandlerClickTemplate` `_onclick`, `SecureHandlerWrapScript`, or `SecureHandlerAttributeTemplate`) run in a restricted environment. They can change attributes and show or hide frame references in combat, but they cannot call arbitrary addon Lua.
  - `HookScript("OnClick")` on a secure button runs insecure code after the secure action.

## Q7: How are pure helpers tested, and how is the addon packaged?

### Findings
- **`Logic.lua`**: the file is pure, with no WoW API at load time. It is the first file in the TOC (`WarlockUtilityKit.toc:9`) and defines helpers on the shared `WUK` table (`Logic.lua:1`).
  - Some helpers carry `ponytail:` comments marking deliberate simplifications (`Logic.lua:3`).
  - Data tables live here: `WUK.PETS`, `WUK.CURSES` (`Logic.lua:87`, `97`).
- **Tests**: `tests/run.lua` (112 lines).
  - It loads `Logic.lua` with `loadfile(dir.."/Logic.lua")("WarlockUtilityKit", WUK)` into a fresh table (`tests/run.lua:1-3`).
  - A tiny `eq(got, want, label)` helper raises an error on mismatch (`tests/run.lua:5-7`).
  - Tests are grouped by "Phase N" comments (`tests/run.lua:9`, `23`, `28`).
  - There is no WoW API stub, so only `Logic.lua` is testable.
- **TOC load order** (`WarlockUtilityKit.toc:9-18`): Logic, Core, UI, Prep, Summon, Trade, Comm, Board, Dock, Settings.
  - Each file appends to `WUK.inits` and `WUK.refreshers` (`Core.lua:3`), which run in TOC order at login and refresh (`Core.lua:141-153`).
  - So Prep's armor and pet buttons are created after the UI strip init, and they register into `strip.icons` before the first `LayoutRing`.
- **CI** (`.github/workflows/package-wuk.yml`, repo root):
  - Triggers on pushes to `main` that touch `WarlockUtilityKit/**`.
  - Runs `lua5.1 WarlockUtilityKit/tests/run.lua`.
  - Reads `## Version` from the TOC.
  - Zips the folder without `tests/`.
  - Creates the GitHub release `wuk-v<version>`, or replaces the zip on an existing tag.
- **Versioning**: `## Version: 0.3.3` (`WarlockUtilityKit.toc:4`). `CHANGELOG.md` has one dated `## [x.y.z]` section per release with `### Added` and `### Fixed` subsections (`CHANGELOG.md:1-20`).

## Cross-Cutting Observations
- **Init and refresh pattern**: each feature file pushes one function onto `WUK.inits` (build frames) and one onto `WUK.refreshers` (update visuals). `WUK.Refresh()` reruns every refresher on bag, aura, pet, spell and regen events (`Core.lua:141-159`).
- **Ring membership** depends on two lists: a button key must be in `ORBIT` (`UI.lua:11`), and the button must be in `strip.icons` (`UI.lua:142`, `Prep.lua:6`, `25`). `LayoutRing` and the collapse alert both iterate `ORBIT`.
- **Spells are names everywhere**: `WUK.known` holds names, and macros are `/cast <name>`. Spell IDs appear only on incoming cast events.
- **Combat split**: protected changes (position, attributes, visibility) are made out of combat and re-applied on `PLAYER_REGEN_ENABLED`. Cosmetic texture changes are applied any time.
- **Settings route through slash commands**: every option runs through `SlashCmdList.WARLOCKUTILITYKIT` (`Settings.lua:5`, `Core.lua:244-266`), which is the single code path for toggles.

## Open Areas
- The tooltip and secure-handler behaviour on the Forever client has not been verified. That includes `GameTooltip:SetSpellByID`, the `C_Spell.GetSpellInfo(name).spellID` return, and the restricted environment. `/wuk probe` (`Core.lua:174-242`) does not currently report on these.
- Which of the absent spells (Shadow Ward, Unending Breath, Felguard, Inferno, Ritual of Doom and others) exist on Forever, and under what exact names, cannot be determined from the repo.
- Nothing in the code shows whether the ring keeps interactive regions or hit rects for collapsed buttons. Mouse is disabled only at `radius == 0` (`UI.lua:41`).
