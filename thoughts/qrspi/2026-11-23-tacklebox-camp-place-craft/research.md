# Research Findings

Refs are under `TackleBox/` unless prefixed. `idx` = `D:\Source\wowskill\skills\wow-forever-addon\references\forever-api-index.md`; `notes` = `forever-api-notes.md` (same folder); `probe` = `thoughts/qrspi/GH-22-forever-fishing-addon/probe-results.md`. Web facts are labelled **verified / reported / unverified** for Forever.

## Q1: How does `Actions.lua` build and drive the side-bar buttons?

### Findings
- **Keys and tips:** `ORDER = {"pole","lure","water","cast"}` (`Actions.lua:5`); default tooltips in `TIPS` (`:6`). `TB.actions` maps key → `{item=id} | {spell=name} | nil` (`:8`). The Water tab reads `TB.actions.water`.
- **`MakeButton(key)`** (`:10-37`):
  - `CreateFrame("Button","TBAction_"..key, bar, "SecureActionButtonTemplate")`, 40x40, registered for `AnyUp`/`AnyDown` (`:12-13`).
  - Parts: icon inset 3, rope quickslot rim, highlight/pushed textures, bottom-right `count` text, looping ripple animation (`:14-26`). Starts hidden (`:35`).
  - OnEnter (`:27-33`): `SetItemByID(self.itemID)` when set, else `self.tip or TIPS[key]` in sand; `self.need` as a red line (1,.3,.3).
- **Bar** (`:76-87`): `TBActionBar`, a BackdropTemplate frame on UIParent, 52x52, `TB.Skin(bar,12)`, TOPRIGHT to `TB.Dock()` TOPLEFT at (2,0), `TB.DockDrag(bar)`. Buttons are created in ORDER (`:81`).
- **`TBCastKey`** (`:82-84,119-120`): hidden 1x1 secure button; `type="spell"`, `spell=cast.spell` when `TB.actions.cast` exists. Bound via `SetOverrideBindingClick` in `TB.BindCast` (`:45-49`). `TB.ReelMode` swaps the binding to `INTERACTTARGET` with CVar backup (`:59-74`, `REEL_CVARS` at `:42`).
- **Refresher** (`:151-186`), which builds table `A`, then `TB.actions = A` (`:184`), then `Apply()` (`:185`):
  - `BagItems()` (`:125-137`): bags `0..NUM_BAG_SLOTS or 4` via `C_Container.GetContainerNumSlots`/`GetContainerItemID`, `C_Item.GetItemInfoInstant` for class/sub; returns `{id, classID, subID, bag, slot, link}`. Bags only, no bank.
  - Pole: when not equipped, snapshot weapons into `TB.char.weapons` and `A.pole = {item = TB.PickPole(items)}` (`:153-157`). When equipped, `A.pole` becomes a weapons swap-back with `macro = TB.WeaponsMacro(mh,oh)`, `usable`, `need` (`:158-164`).
  - Lure: counts via `C_Item.GetItemCount`; `TB.PickLure(lures, counts, GetWeaponEnchantInfo(), skill)` gives `{item, usable, need = "Requires Fishing N"}` (`:166-170`).
  - Water: counts = `GetItemCount + IsEquippedItem`; aura check over `ww.auras` via `TB.ReadAura`; `TB.WaterWalkPick(...)` gives `{item, usable, need="Requires level N"}`; sets `TB.waterActive` (`:173-178`).
  - Cast: `C_Spell.GetSpellInfo(7620)` gives `{spell, icon}` when `TB.skill` exists (`:180-183`).
- **`Apply()`** (`:90-123`):
  - Returns early if there is no bar or `InCombatLockdown()` (`:91`); after combat, `PLAYER_REGEN_ENABLED` → `TB.Refresh` re-applies (`Core.lua:61`).
  - Per key with an action:
    - `usable == false` → `type=nil` (visible but inert) (`:96-97`).
    - `pole` → `type="macro"`, `macrotext = a.macro or "/equip item:<id>"` (`:98-99`).
    - `lure` → `type="macro"`, `"/use item:<id>\n/use 16"` (`:100-102`).
    - `water` → `type="item"`, `item="item:<id>"` (`:103-104`).
    - `cast` / else → `type="spell"`, `spell=a.spell` (`:105-106`).
  - Then `b.itemID`, `b.need`, `b.tip` (`:108-109`). Icon is `GetItemIconByID` or `a.icon`, desaturated with alpha .5 when unusable (`:110-111`). Count text via `GetItemCount` except for pole (`:112`).
  - Layout: `SetPoint("TOP", bar, "TOP", 0, -y)`, `y` from 6, +44 per shown button (`:92,113-114`). Hidden when there is no action (`:116`).
  - Bar height is `max(52, y+2)`; shown when at least one button exists and the panel is shown (`:121-122`).
- **Pure helpers** (`Logic.lua`):
  - `WaterWalkPick(items, counts, auraActive, level, minLevel)` → `id, true` | `locked, false` | nil (`:167-177`).
  - `PickPole(items)` (`:181-183`).
  - `PickLure(lures, counts, lureActive, skill)` → best usable by bonus, else the lowest-req locked lure plus `req` (`:187-201`).
  - `FindWeapon` (`:204-212`), `WeaponsMacro` (`:215-220`).
- **Data shape:** `waterWalk = {items={8827,276274}, minLevel={...}, auras={11319,1299351,1310296,546,1221095}}` (`Data.lua:92-96`).
- **Refresh triggers:** debounced `TB.Refresh` (`Core.lua:45-53`) on PLAYER_LOGIN, SKILL_LINES_CHANGED, PLAYER_REGEN_ENABLED, BAG_UPDATE_DELAYED, BANKFRAME_OPENED, PLAYERBANKSLOTS_CHANGED, ZONE_CHANGED_NEW_AREA, UNIT_INVENTORY_CHANGED (player), UNIT_AURA (player), the 1 s camp ticker, a miss, and LOOT_READY (`Core.lua:55-86,236,259`).

## Q2: How is the Camp tab's data produced, and what does probe-results.md record about camp items?

### Findings
- **`campBuffs`** (`Data.lua:85-89`): `{spellID=1280341, name="Fishing Rack (Uncommon)", unlock=140}` and `{spellID=1280342, name="Fishing Hut (Rare)", unlock=300}`. The comment says the aura IDs are DB2 "Uncommon/Rare Fishing" dummies, "mapping unverified in game". No item IDs, no `subzone`.
- **`TB.ReadAura(spellID)`** (`Core.lua:72-79`):
  - In combat it returns the cached `TB.auraState[spellID]` or `{active=false}` (combat aura reads error on Forever, WUK probe).
  - Out of combat it uses `pcall(C_UnitAuras.GetPlayerAuraBySpellID)`.
  - A secret, nil or 0 `expirationTime` gives `{active=true}`; otherwise `{active=true, remaining}`.
  - `TB.auraState` is written only by the Camp build (`Panel.lua:333`). The 1 s ticker refreshes while any entry has `remaining` (`Core.lua:82-86`).
- **`CampRows(buffs, state, skill, subzone)`** (`Logic.lua:152-164`):
  - active = aura active OR `b.subzone == subzone`.
  - sub = "M:SS left" / "active" / "needs skill N" / "available".
  - Active rows are green.
- **Camp section** (`Panel.lua:331-337`): `CAMP_ITEMS = {279965, 279966}` used only for row icons, by index; empty text "No camp buffs known."
- **probe-results.md:**
  - Items (DB2 build 1.60.1.70450): 279965 Fishing Rack, 279966 Fishing Hut, 279967 Fish Bowl (quality 1, class 0/8); 273141 Blueprint: Fishing Rack and 273119 Blueprint: Fishing Hut (quality 2, class 9/9) (`probe:71-72`).
  - Unlock skills on Fishing (356): Blueprint Rack 140, Rack 140, Blueprint Hut 300, Hut 300, Fish Bowl 20 (`probe:89-98`).
  - Placeable spells: Rack 1307247 and Hut 1307246 each summon a game object (effect 50) and create an area trigger (effect 179, misc 43850 / 43851). Neither applies an aura directly (`probe:100-102`).
  - **Craft spells (effect 24, create item): 1262990 → Fishing Rack, 1262998 → Fishing Hut** (`probe:100-102`).
  - Candidate auras: 1280341 "Uncommon Fishing" and 1280342 "Rare Fishing" (dummy aura type 4), "likely" applied by the area triggers; "Needs an in-game check at a camp" (`probe:104-107`).
  - Fish Bowl: buff aura not identified; 1255254 triggers 1229745, which only creates an item (`probe:113`).
  - Site 4 (at a camp) is still listed under "Still needed" (`probe:82,122`). No in-game camp observation has been recorded in any run.
- **Other repo mentions:**
  - Enchanted Lute recipe `[1230643]` (prof 333, item 279976) is at `ProfessionPlanner/Data.lua:948`.
  - "Basic Campfire" as a Cooking recipe (profession 185) is at `thoughts/qrspi/2026-10-19-profession-leveling-planner/probe-results.md:24`.
  - fishing-gaps `research.md:75`: "Bait and Tackle" is the camp crafting menu; Fish Bowl gives a Kings-equivalent buff.
  - fishing-gaps `research.md:16,18`: FishFry has "Campsite Assist"; Forever Fishing has camp queues.
  - GH-22 `design.md:155`: risk "Rack/Hut may not be player auras; fallback GetSubZoneText".

## Q3: What fishing camp items exist in Forever, and how are they obtained and used?

### Findings
- **Camping system** (the Blizzard news article is **verified**/official, https://news.blizzard.com/en-us/article/24301516):
  - A Cooking "Basic Campfire" makes a shared campsite holding up to 3 features, each from a different nearby player.
  - Each profession has one camp item, usually learned at skill 20; items at skill 140+ come from dungeon or raid drops.
  - You sit or craft at the campsite for 1+ minute to gain benefits.
  - All camp features share a 1-hour cooldown and need a nearby campfire.
- **No separate Camping/Survival skill line was found.** Tier-1 recipes come from the profession trainer or the "Camping 101" quest. Tiers 2-3 come from Blueprint items that drop in dungeons (**reported**: warcrafttavern Forever camping guide, wow-professions Forever camping guide).
- **Campfire tiers (reported):**
  - Basic Campfire Kit 279981: Cooking 1, 1 Simple Wood with Flint and Tinder, holds 3, spell 818.
  - Journeyman 279961: BP 273087 from Lord Serpentis, Cooking 90, holds 5.
  - Expert 279974: BP 273101, Cooking 200-220, holds 10.
  - Higher tiers can be placed over lower ones, ignoring the cooldown.
- **Fishing camp items:**

  | Item | ID | Source | Skill | Reagents | Effect | Recipe spell |
  |---|---|---|---|---|---|---|
  | Fish Bowl | 279967 (verified, wiki.gg) | Fishing trainer or Camping 101 | Fishing 20 | 1 Raw Brilliant Smallfish, 1 Empty Vial | +8% stats to you and nearby sitting players, exclusive with Kings; needs campfire | 1229745 (reported; matches the `probe:113` create-item spell) |
  | Fishing Rack | 279965 (verified, wiki.gg) | Blueprint 273141 from Gelihast (BFD) | Fishing 140 | 2 Simple Wood, 1 Crystal Vial, 2 Raw Mithril Head Trout | Uncommon fish, lures, plus Fish Bowl benefits; 1 h; replaces a Bowl | 1262990 (reported; matches the probe DB2 craft spell) |
  | Fishing Hut | 279966 (verified, wiki.gg) | Blueprint 273119 from Jammal'an (ST) | Fishing 300 | 5 Simple Wood, 2 Bolt of Runecloth, 1 Seasonal Fish Steaks | Rare fish, lures, plus Fish Bowl benefits; 1 h | 1262998 (reported; matches probe) |

- Wiki.gg lists max stack 20 for the Fishing Hut. Buff spell IDs, radius and consumed-vs-reusable are **not stated** by any source reached.
- "Simple Fish Drying Rack", "Fisher's Bait Table" and "Grand Angler's Basin" (named by Gfinity) were **not found** anywhere else.
- **Other camp items (reported):**
  - Enchanted Lute 279976: Enchanting 20, 1 Simple Wood + 1 Strange Dust; armor/stats/resists, exclusive with Mark of the Wild; spell 1230643.
  - Each other profession has a tier-1 object at 20 plus blueprint tiers at 140 and 300 (Mana Well, Sharpening Wheel, Camp Tent, Reagent Bot, …), with spell IDs on the warcrafttavern / wow-professions pages.
- Waylaid Crates: turn-ins for Merchant's Favor; no item ID found.

## Q4: Which Forever APIs and constraints govern crafting from an addon?

### Findings
- **Present in idx:**
  - `C_TradeSkillUI` (`idx:973`): OpenTradeSkill, CloseTradeSkill, CraftRecipe, GetRecipeInfo, GetRecipeSchematic, GetCraftableCount, GetBaseProfessionInfo, GetChildProfessionInfo, GetProfessionInfoByRecipeID, IsRecipeProfessionLearned, GetAllProfessionTradeSkillLines, GetTradeSkillDisplayName.
  - `C_SpellBook` (`idx:910`): IsSpellKnown, IsSpellKnownOrInSpellBook, CastSpellBookItem. `C_Spell` (`idx:904`): GetSpellInfo, IsSpellUsable, GetSpellCooldown. Undocumented C global `CastSpellByName` (`idx:1065`).
  - Events: TRADE_SKILL_SHOW (`:2611`), TRADE_SKILL_CLOSE (`:2599`), TRADE_SKILL_LIST_UPDATE (`:2609`), TRADE_SKILL_DATA_SOURCE_CHANGED/CHANGING (`:2603-2604`), TRADE_SKILL_CRAFT_BEGIN (`:2601`), TRADE_SKILL_ITEM_CRAFTED_RESULT (`:2607`), UPDATE_TRADESKILL_CAST_STOPPED (`:2782`), NEW_RECIPE_LEARNED (`:2120`), UNIT_SPELLCAST_SUCCEEDED (`:2740`).
- **Absent from idx:**
  - `C_TradeSkillUI`: GetAllRecipeIDs, GetRecipeNumAvailable, IsTradeSkillReady, GetTradeSkillLine.
  - `IsPlayerSpell` and the global `IsSpellKnown`.
  - Classic crafting globals: GetNumTradeSkills, GetTradeSkillInfo, DoTradeSkill, DoCraft.
- **Never-emit** (`notes:50-61`): the global container functions and GetSpellInfo/GetSpellCooldown/GetSpellTexture; their `C_` replacements are present.
- **`C_TradeSkillUI.CraftRecipe(recipeSpellID [, numCasts [, craftingReagents [, itemTarget [, applyConcentration]]]])`** (**reported** for Retail, https://warcraft.wiki.gg/wiki/API:C_TradeSkillUI.CraftRecipe):
  - The only restriction listed is "AllowedWhenUntainted".
  - Whether it is protected, needs a hardware event, or needs the trade skill UI open: **not stated / unverified**.
- **/cast or `type=spell` on a recipe:**
  - Classic `/cast Profession` opens the window (forum, reported).
  - A Retail 12.0 beta CraftRecipe macro was reported not working (Wowhead beta forum).
  - **No authoritative source**; unverified for Forever.
- `taint-and-secure.md:23`: buttons that cast or use items inherit SecureActionButtonTemplate and are configured outside combat. Neither it nor `events.md` covers crafting.
- `events.md:29`: item/spell data may be uncached; wait for GET_ITEM_INFO_RECEIVED / SPELL_DATA_LOAD_RESULT.
- A CurseForge "forever-profession-master" addon exists (not opened).

## Q5: Item-use placement mechanics, cooldown APIs, and current bag scans

### Findings
- **SecureActionButtonTemplate `type="item"`:** uses an item by name, macro-conditional or bag/slot (**reported**, https://warcraft.wiki.gg/wiki/SecureActionButtonTemplate). Whether a placeable gives an instant use or a ground-target cursor is **not documented / unverified**. The probe found the Rack/Hut spells summon a game object (effect 50) (`probe:100-102`); targeting mode not recorded.
- **Cooldowns:**
  - `C_Container.GetItemCooldown(itemID)` → `startTime, duration, enable`, listed for "forever (1.60.1)" (**reported**, wiki).
  - `C_Container.GetContainerItemCooldown` and `C_Item.GetItemCooldown` are present (`idx:433,646`).
  - Events BAG_UPDATE_COOLDOWN (`idx:1208`), SPELL_UPDATE_COOLDOWN (`idx:2532`).
  - The camp shared cooldown is 1 h (Blizzard, verified).
- **Other item APIs:**
  - `C_Item.GetItemSpell(itemInfo)` → `spellName, spellID` (present `idx:646`; wiki reported).
  - `C_Item.IsUsableItem`, `C_Item.GetItemCount`, `C_Item.UseItemByName` are present.
  - `C_ToyBox` is absent (only `C_ToyBoxInfo`, `idx:967`).
- **Current bag scans:**
  - `BagItems()` (`Actions.lua:125-137`) scans bags only.
  - `C_Item.GetItemCount(id)` without bank for lures, water and count text (`Actions.lua:112,167,174`).
  - `TB.CountItems(ids)` uses `GetItemCount(id, true)`, including the bank (`Core.lua:89-93`).
  - The probe bag loop uses `C_Container.GetContainerItemInfo` (`Core.lua:333-348`).
  - **No cooldown API is called anywhere in the repo.**

## Q6: How does `TB.Probe()` work, and what do the tests cover?

### Findings
- **`TB.Probe()`** (`Core.lua:265-361`):
  - Resets `TB.db.lastProbe` (`:266`).
  - Helpers: `S(v)` gives "SECRET" or tostring; `P(k,v)` prints and appends; `Try(k,fn)` is a pcall printing "ERROR …" (`:267-269`).
  - Sections in order: build, combat, bindings, cast key; professions; SkillLine 356; spells 7620/131474; IsFishingLoot; zone; softinteract; tooltip; SoftTargetInteract; map; pools; map hooks; auras 1..40 plus by-ID; bags; lastChannel; lastLoot; trace (`:271-360`).
  - Bag filter: keep `classID == 7 or 0`, or a name containing a `PROBE_WORDS` entry (`:262,333-348`). Camp placeables are class 0/8, so they are kept; this is how the user's earlier probe listed Fish Bowl 279967 and Basic Campfire Kit 279981.
- **Tests** (`tests/run.lua`):
  - CampRows: timer "1:05 left", "needs skill 300", subzone "active", secret-timer "active", "available" (`:63-67`).
  - WaterWalkPick: none, first, preference, aura active, level skip, locked-only (`:70-77`).
  - PickPole (`:80-81`).
  - PickLure: best usable, skip above skill, locked lowest req, active, none (`:82-88`).
  - FindWeapon and WeaponsMacro (`:103-110`).
  - No tests for Actions.lua or Probe (they are not loaded by the harness).

## Cross-Cutting Observations
- The side bar is one pattern: a pure picker in `Logic.lua`, an entry in the `A` table, and attribute mapping in `Apply()` by key, with `usable=false` + `need` for greyed-out buttons. Everything secure changes only out of combat.
- Camp state is aura-driven (`ReadAura`), with an unused subzone fallback; aura IDs are unconfirmed in-game.
- Camp items are crafted items: Fish Bowl is a trainer recipe, while the Rack and Hut need Blueprints (dungeon drops). The recipe spell IDs (1229745, 1262990, 1262998) agree between the probe DB2 data and the web guides.
- Camp item use requires a nearby campfire and shares a 1 h cooldown across all of a player's camp items.
- The user's bags at probe time contained Fish Bowl 279967 and Basic Campfire Kit 279981 (screenshot of probe run 6A).

## Open Areas
- Whether `C_TradeSkillUI.CraftRecipe` (or a `/cast`/`type=spell` recipe) works from an addon click on Forever: protected or not, hardware event, profession window open.
- Whether using a camp item via a secure `type=item` button is instant or opens a placement cursor.
- Actual buff aura IDs at a camp (1280341/1280342 unconfirmed), Fish Bowl buff ID, buff durations, and whether camp items are consumed on use.
- Whether placing works without a campfire (sources say a campfire is required) and how the shared 1 h cooldown is exposed (item cooldown vs spell cooldown).
- Item ID and recipe for the "Simple Fish Drying Rack", "Fisher's Bait Table" and "Grand Angler's Basin" (possibly misnamed by one guide).
- Campfire Kit placement mechanics (same questions as the camp items).
