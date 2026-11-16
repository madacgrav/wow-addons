# Implementation Plan

## Overview
New standalone addon `BusinessCard/` (Interface 16001) with three parts:
1. A persistent ad log of players advertising professions, summons or portals in public chat.
2. A "card" (professions, skill, services, per-entry available/busy/off status) exchanged silently with other addon users, by guild broadcast and by whisper on demand.
3. On-demand recipe lists sent in chunks.

Phase 1 is a probe gate; phases 2–6 each add one feature end to end.

**Conventions (all phases)**
- Copy helpers into the addon; never depend on another addon.
- Pure functions go in `Logic.lua` and are tested by `tests/run.lua`.
- Local test command: `lua BusinessCard/tests/run.lua` (CI uses `lua5.1`).
- Deploy after every phase, then ask for the in-game test:
  `robocopy "D:\Source\wow-addons\BusinessCard" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\BusinessCard" /MIR /XD tests /NJH /NJS /NP /NDL`
- Bump `## Version` in the `.toc` (0.1.0 … 0.6.0) and add a `CHANGELOG.md` entry each phase.
- Chat colour tag: `|cffe0b050BC|r`.

**Deviations from structure.md**
- **Link classification (P2):** no `|H(%a+):(%d+)` ID extraction. Link payloads are stripped and the visible link text (`[Enchant Bracer - …]`, `[Tailoring]`) goes through the same keyword tokenizer. Same result, no item or profession lookups.
- **Category filter (P3):** a dropdown (`WowStyle1DropdownTemplate`, as in `WarlockUtilityKit/Board.lua:90-94`) instead of TackleBox icon tabs. 12+ categories don't fit as tabs. Seen and My card are two top buttons.
- **Cards from guildmates who never advertised (P5):** stored in `db.cards` and merged into Seen rows, with categories derived from their card. Without this, guild exchange would be invisible.

---

## Phase 1: Skeleton + `/bcard probe` + release pipeline

### Changes

#### 1. TOC
**File**: `BusinessCard/BusinessCard.toc` — create
```
## Interface: 16001
## Title: BusinessCard
## Notes: Remembers who advertised professions, summons and portals; swaps cards and status with other BusinessCard users.
## Version: 0.1.0
## IconTexture: Interface\Icons\INV_Letter_15
## SavedVariables: BusinessCardDB
## SavedVariablesPerCharacter: BusinessCardCharDB

Data.lua
Logic.lua
Core.lua
```
Later phases append `Comm.lua`, `Panel.lua` and `Bindings.xml` (the `Bindings.xml` is auto-loaded and is not listed).

#### 2. Data
**File**: `BusinessCard/Data.lua` — create
```lua
local ADDON, BC = ...
-- Classic IDs; confirmed or replaced from probe-results.md after Phase 1
BC.SERVICES = {
  { key = "S", id = 698, name = "Ritual of Summoning", label = "Summon" },
  { key = "T-ORG", id = 3567, name = "Teleport: Orgrimmar" },   { key = "P-ORG", id = 11417, name = "Portal: Orgrimmar" },
  { key = "T-UC", id = 3563, name = "Teleport: Undercity" },    { key = "P-UC", id = 11418, name = "Portal: Undercity" },
  { key = "T-TB", id = 3566, name = "Teleport: Thunder Bluff" },{ key = "P-TB", id = 11420, name = "Portal: Thunder Bluff" },
  { key = "T-SW", id = 3561, name = "Teleport: Stormwind" },    { key = "P-SW", id = 10059, name = "Portal: Stormwind" },
  { key = "T-IF", id = 3562, name = "Teleport: Ironforge" },    { key = "P-IF", id = 11416, name = "Portal: Ironforge" },
  { key = "T-DARN", id = 3565, name = "Teleport: Darnassus" },  { key = "P-DARN", id = 11419, name = "Portal: Darnassus" },
}
BC.PROF_NAMES = { [171]="Alchemy", [164]="Blacksmithing", [333]="Enchanting", [202]="Engineering", [165]="Leatherworking",
  [197]="Tailoring", [185]="Cooking", [129]="First Aid", [186]="Mining", [182]="Herbalism", [393]="Skinning",
  [356]="Fishing", [755]="Jewelcrafting" }
```
Phase 2 adds the keyword sets to this file.

#### 3. Logic
**File**: `BusinessCard/Logic.lua` — create
Contains `BC.MergeDefaults`, copied verbatim from `TackleBox/Logic.lua:3-10`.

#### 4. Core
**File**: `BusinessCard/Core.lua` — create
- Header copied from `TackleBox/Core.lua:1-15`, renamed: `BC.inits`, `BC.refreshers`, `BC.Secret`, `BC.Print`, `BC.On`.
- `ADDON_LOADED`: `MergeDefaults` into `BusinessCardDB` / `BusinessCardCharDB`, with the nil-safe comment (ForeverSVFix).
- `PLAYER_LOGIN`: sets `BC.active = true` and runs `inits`.
```lua
BC.PREFIX = "BCARD"
local DEFAULTS = { locked = false, frames = {}, lastProbe = {} }
local CHAR_DEFAULTS = {}

-- probe: chat capture armed by /bcard probe, prints the next 5 channel messages' secrecy
local capture = 0
BC.On("CHAT_MSG_CHANNEL", function(text, sender, _, _, _, _, _, idx, base, _, _, guid)
  if capture <= 0 then return end
  capture = capture - 1
  BC.ProbeLine("chan msg", tostring(base) .. "#" .. tostring(idx) .. " text " .. (BC.Secret(text) and "SECRET" or "ok")
    .. " sender " .. (BC.Secret(sender) and "SECRET" or "ok") .. " guid " .. (BC.Secret(guid) and "SECRET" or "ok")
    .. " combat " .. tostring(InCombatLockdown()) .. " inst " .. tostring((select(2, IsInInstance()))))
end)

function BC.ProbeLine(k, v) local line = k .. ": " .. tostring(v); BC.Print(line); table.insert(BC.db.lastProbe, line) end

function BC.Probe()
  BC.db.lastProbe = {}
  local P = BC.ProbeLine
  local function Try(k, fn) local ok, err = pcall(fn); if not ok then P(k, "ERROR " .. tostring(err)) end end
  local ver, build = GetBuildInfo()
  P("build", tostring(ver) .. " " .. tostring(build))
  P("ctx", "combat " .. tostring(InCombatLockdown()) .. " inst " .. tostring((select(2, IsInInstance())))
    .. " trial " .. tostring(IsTrialAccount and IsTrialAccount()) .. " vet " .. tostring(IsVeteranTrialAccount and IsVeteranTrialAccount()))
  Try("chan", function()
    local l = { GetChannelList() } -- id, name, disabled triples
    for i = 1, #l, 3 do P("channel", tostring(l[i]) .. " " .. tostring(l[i + 1]) .. " disabled " .. tostring(l[i + 2])) end
  end)
  for _, s in ipairs(BC.SERVICES) do
    Try("spell", function()
      local byId, byName = C_Spell.GetSpellInfo(s.id), C_Spell.GetSpellInfo(s.name)
      P("spell " .. s.key, tostring(byId and byId.name) .. " id " .. s.id .. " player " .. tostring(IsPlayerSpell(s.id))
        .. " byName " .. tostring(byName and byName.spellID))
    end)
  end
  Try("prof", function()
    local p = { GetProfessions() }
    for i = 1, 6 do if p[i] then
      local name, _, rank, max, _, _, line = GetProfessionInfo(p[i])
      P("prof " .. i, tostring(name) .. " line " .. tostring(line) .. " " .. tostring(rank) .. "/" .. tostring(max))
    end end
  end)
  Try("recipe", function() -- a recipe this character likely does not know (Classic Enchant Bracer - Minor Health 7418)
    local r = C_TradeSkillUI.GetRecipeInfo(7418)
    P("recipe 7418", tostring(r and r.name) .. " spellName " .. tostring(C_Spell.GetSpellName and C_Spell.GetSpellName(7418)))
  end)
  capture = 5
  P("chat", "capturing next 5 channel messages")
end

table.insert(BC.inits, function()
  C_ChatInfo.RegisterAddonMessagePrefix(BC.PREFIX)
  BC.On("CHAT_MSG_ADDON", function(prefix, text, ch, sender)
    if prefix ~= BC.PREFIX or BC.Secret(text) or BC.Secret(sender) then return end
    if text == "ping" then
      BC.ProbeLine("ping from", tostring(sender) .. " via " .. tostring(ch))
      C_ChatInfo.SendAddonMessage(BC.PREFIX, "pong", "WHISPER", sender)
    elseif text == "pong" then BC.ProbeLine("pong from", sender) end
  end)
end)

function BC.Ping(name)
  local r = C_ChatInfo.SendAddonMessage(BC.PREFIX, "ping", "WHISPER", name)
  BC.ProbeLine("ping " .. name, "result " .. tostring(r) .. " guild " .. tostring(IsInGuild()))
end

SLASH_BUSINESSCARD1 = "/bcard"
SlashCmdList.BUSINESSCARD = function(msg)
  local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "probe" then BC.Probe()
  elseif cmd == "ping" and arg ~= "" then BC.Ping(arg)
  elseif cmd == "lock" then BC.db.locked = not BC.db.locked; BC.Print(BC.db.locked and "locked" or "unlocked")
  elseif cmd == "reset" then wipe(BC.db.frames); BC.Print("positions reset - /reload to apply")
  else BC.Print("/bcard probe | ping <name> | lock | reset") end
end
```
`/bcard` with no argument is rebound to toggle the window in Phase 3.

#### 5. Tests
**File**: `BusinessCard/tests/run.lua` — create
- Loader copied from `TackleBox/tests/run.lua:1-8`; loads `Data.lua`, then `Logic.lua`, with `("BusinessCard", BC)`.
- MergeDefaults cases (nil → defaults, nested table, existing value kept).
- Ends with `print("all tests passed")`.

#### 6. Docs + CI
- `BusinessCard/README.md`: what it does, slash commands, the known limits (trial and Veteran accounts can't send; ads with secret text are skipped).
- `BusinessCard/CHANGELOG.md`: `0.1.0 — skeleton and probe`.
- `.github/workflows/package-bcard.yml`: copy of `.github/workflows/package-tb.yml`, with `TackleBox` → `BusinessCard` and tag prefix `tb-v` → `bcard-v`.
- `thoughts/qrspi/2026-11-16-profession-business-card/probe-results.md`: created after the in-game run from `BusinessCardDB.lastProbe` (read the SavedVariables file `WTF\Account\*\SavedVariables\BusinessCard.lua`).

### Verification
#### Automated
- [x] `lua BusinessCard/tests/run.lua` prints `all tests passed`

#### Manual
- [x] Deploy with robocopy. The addon loads with no Lua errors, and `/bcard` prints usage.
- [x] Probe in Orgrimmar with busy Trade, out of combat: `/bcard probe`, wait for 5 `chan msg` lines.
- [ ] Probe again in combat (attack a training dummy or a nearby mob) in the open world.
- [x] Probe once in a dungeon, so instance chat behaviour is recorded.
- [ ] `/bcard ping <alt>` between two accounts in **different guilds and not grouped**; look for `pong from` and the result code. Repeat between guildmates.
- [ ] On a mage and a warlock (if available), `spell` lines show which IDs are known.
- [x] Write `probe-results.md` with the answers:
  - channel text and sender secret?
  - channel base names
  - stranger whisper works?
  - spell IDs
  - does the unknown recipe name resolve?
- [ ] **Gate:**
  - Text or sender SECRET in open-world Trade: stop and go back to `/qrspi-plan-toolkit:3-design`.
  - Stranger ping fails: in Phase 5, skip the `Q`-to-strangers trigger (guild only) and note it in the README.
  - Fix `BC.SERVICES` IDs and the Phase 2 default channel names to match the probe.
  - If the recipe name doesn't resolve, Phase 6 uses the `C_Spell.GetSpellName` fallback.

---

## Phase 2: Ad log (chat intake, classifier, persistence)

### Changes

#### 1. Keyword sets
**File**: `BusinessCard/Data.lua` — modify (append)
```lua
local function set(t) local s = {} for _, w in ipairs(t) do s[w] = true end return s end
-- category order = display order
BC.CATS = { "enchanting", "tailoring", "leatherworking", "alchemy", "blacksmithing", "engineering", "jewelcrafting",
  "cooking", "firstaid", "summon", "portal", "other" }
BC.CAT_LABEL = { enchanting="Enchanting", tailoring="Tailoring", leatherworking="Leatherworking", alchemy="Alchemy",
  blacksmithing="Blacksmithing", engineering="Engineering", jewelcrafting="Jewelcrafting", cooking="Cooking",
  firstaid="First Aid", summon="Summons", portal="Portals", other="Other" }
BC.WORDS = {
  enchanting = set{ "ench", "enchant", "enchants", "enchanter", "enchanting", "chanter" },
  tailoring = set{ "tailor", "tailors", "tailoring" },
  leatherworking = set{ "lw", "leatherworker", "leatherworking" },
  alchemy = set{ "alch", "alchemy", "alchemist", "flask", "flasks", "elixir", "elixirs", "transmute", "transmutes", "potion", "potions" },
  blacksmithing = set{ "bs", "blacksmith", "blacksmithing", "smith" },
  engineering = set{ "engi", "engineer", "engineering" },
  jewelcrafting = set{ "jc", "jewelcrafter", "jewelcrafting" },
  cooking = set{ "cook", "cooking" },
  firstaid = set{ "bandage", "bandages" },
  summon = set{ "sum", "summ", "summon", "summons", "summoning" },
  portal = set{ "port", "ports", "portal", "portals", "teleport", "tele" },
  other = set{ "lockpick", "lockpicking", "lockbox", "lockboxes" },
}
BC.REQUEST_WORDS = set{ "lf", "wtb", "need", "needs", "needing", "buying", "anyone", "someone", "somebody" }
BC.OFFER_WORDS = set{ "wts", "lfw", "selling", "offering", "avail", "available", "tips", "tip", "free" }
-- "if" deliberately omitted (common English word)
BC.PORTAL_DEST = { org="ORG", orgrimmar="ORG", ogri="ORG", uc="UC", undercity="UC", tb="TB", thunder="TB",
  thunderbluff="TB", sw="SW", stormwind="SW", ironforge="IF", darn="DARN", darnassus="DARN" }
BC.DEFAULT_CHANNELS = { Trade = true, General = true, LookingForGroup = true, ["Trade (Services)"] = true, ["Trade (Local)"] = true,
  SAY = true, YELL = true, WHISPER = true } -- keys = channelBaseName before " - " (probe-results.md)
```

#### 2. Classifier + seen store
**File**: `BusinessCard/Logic.lua` — modify
```lua
-- probe: channelBaseName is "Trade - English 53", "Trade (Services) - English 53", "General - Orgrimmar"; key = text before " - "
function BC.ChannelKey(base) if type(base) ~= "string" then return nil end return base:match("^(.-) %- ") or base end
-- strip colour codes and hyperlink payloads, keeping the visible [link text]
function BC.StripLinks(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")) end

-- returns { cats = {cat=true}, request = bool, dest = "ORG"? } or nil when nothing matched
function BC.Classify(text)
  if type(text) ~= "string" then return nil end
  local cats, any, req, offer, dest = {}, false, false, false, nil
  for w in BC.StripLinks(text):lower():gmatch("%w+") do
    for cat, words in pairs(BC.WORDS) do if words[w] then cats[cat] = true; any = true end end
    req = req or BC.REQUEST_WORDS[w] or false
    offer = offer or BC.OFFER_WORDS[w] or false
    dest = dest or BC.PORTAL_DEST[w]
  end
  if not any then return nil end
  return { cats = cats, request = req and not offer, dest = cats.portal and dest or nil }
end

function BC.SeenAdd(seen, name, r, text, now)
  local e = seen[name] or { cats = {} }
  for cat in pairs(r.cats) do e.cats[cat] = now end
  e.text, e.at, e.req, e.dest = text:sub(1, 120), now, r.request, r.dest or e.dest
  seen[name] = e
  return e
end

-- drop entries older than maxAge seconds, then the oldest beyond cap
function BC.SeenPrune(seen, now, maxAge, cap)
  local keep = {}
  for name, e in pairs(seen) do
    if now - (e.at or 0) > maxAge then seen[name] = nil else keep[#keep + 1] = name end
  end
  if #keep > cap then
    table.sort(keep, function(a, b) return seen[a].at > seen[b].at end)
    for i = cap + 1, #keep do seen[keep[i]] = nil end
  end
end
```

#### 3. Chat intake
**File**: `BusinessCard/Core.lua` — modify
- `DEFAULTS` gains `seen = {}`, `channels = BC.DEFAULT_CHANNELS`, `maxAgeDays = 7`.
- Add a realm-scoped accessor and the handlers, registered in an `init`:
```lua
function BC.Seen() local r = GetRealmName(); BC.db.seen[r] = BC.db.seen[r] or {}; return BC.db.seen[r] end

local function OnAd(source, text, sender)
  if not BC.db.channels[source] or BC.Secret(text) or BC.Secret(sender) then return end
  local name = Ambiguate(sender, "none")
  if name == UnitName("player") then return end
  local r = BC.Classify(text)
  if not r then return end
  BC.SeenAdd(BC.Seen(), name, r, text, time())
  for _, fn in ipairs(BC.onSeen) do fn(name, r) end -- P3 refresh, P5 card request
end
BC.onSeen = {}

table.insert(BC.inits, function()
  BC.On("CHAT_MSG_CHANNEL", function(text, sender, _, _, _, _, _, _, base) OnAd(BC.ChannelKey(base), text, sender) end)
  BC.On("CHAT_MSG_SAY", function(text, sender) OnAd("SAY", text, sender) end)
  BC.On("CHAT_MSG_YELL", function(text, sender) OnAd("YELL", text, sender) end)
  BC.On("CHAT_MSG_WHISPER", function(text, sender) OnAd("WHISPER", text, sender) end)
  if not InCombatLockdown() then BC.SeenPrune(BC.Seen(), time(), BC.db.maxAgeDays * 86400, 500) end
end)
```
- The probe capture handler from Phase 1 stays as is; it is a separate `BC.On` registration.
- `/bcard seen`: prints up to 20 newest entries as `name [cats] age: text`, sorted by `at` descending.

#### 4. Tests
**File**: `BusinessCard/tests/run.lua` — modify. Add cases:
- `"WTS enchants, your mats, tips appreciated"` → enchanting, `request=false`
- `"LF enchanter for crusader"` → enchanting, `request=true`
- `"LFW tailor, can do mooncloth"` → tailoring, offer (LFW wins)
- `"WTS ports to UC and Org"` → portal, dest `UC` (first matched)
- `"summons to BRD 5g"` → summon
- `"LF summon to Strath"` → summon, request
- `"portal"` alone → portal; `"supporting"`/`"important"` → nil (whole token only)
- `"LF tank for SM"` → nil
- `"|cffffffff|Henchant:13931|h[Enchant Bracer - Deflection]|h|r 2g"` → enchanting
- `"|cffffd000|Htrade:Player-1:333:333|h[Enchanting]|h|r"` → enchanting
- `"WTS [Major Healing Potion]"` with an item link → alchemy
- Non-string `nil` → nil
- `ChannelKey("Trade - English 53")` → `Trade`; `("Trade (Services) - English 53")` → `Trade (Services)`; `("LookingForGroup")` → `LookingForGroup`; `(nil)` → nil
- `SeenAdd` twice with different categories → both in `cats`; text truncated to 120
- `SeenPrune`: an 8-day-old entry dropped; cap 2 keeps the newest 2

### Verification
#### Automated
- [x] `lua BusinessCard/tests/run.lua` prints `all tests passed`

#### Manual
- [ ] Deploy. Idle in Orgrimmar for 10 minutes, then `/bcard seen` lists advertisers with sensible categories.
- [ ] `/reload`: `/bcard seen` still lists them.
- [ ] Whisper yourself from an alt `"WTS ports"`: the alt appears with `[portal]`.

---

## Phase 3: Seen window

### Changes

#### 1. Row model
**File**: `BusinessCard/Logic.lua` — modify
```lua
function BC.FormatAge(s)
  if s < 60 then return "now" elseif s < 3600 then return math.floor(s / 60) .. "m"
  elseif s < 86400 then return math.floor(s / 3600) .. "h" end
  return math.floor(s / 86400) .. "d"
end

-- filter = cat key or "all"; returns rows sorted newest first
function BC.SeenRows(seen, cards, filter, showRequests, now)
  local rows = {}
  for name, e in pairs(seen) do
    if (showRequests or not e.req) and (filter == "all" or e.cats[filter]) then
      rows[#rows + 1] = { name = name, cats = e.cats, at = e.at, age = BC.FormatAge(now - e.at), text = e.text,
        dest = e.dest, card = cards and cards[name] }
    end
  end
  table.sort(rows, function(a, b) return a.at > b.at end)
  return rows
end

function BC.CatList(cats) -- "Enchanting, Portals" in BC.CATS order
  local out = {}
  for _, c in ipairs(BC.CATS) do if cats[c] then out[#out + 1] = BC.CAT_LABEL[c] end end
  return table.concat(out, ", ")
end
```
`cards` is nil until Phase 5. Phase 5 extends `SeenRows` to merge card-only names.

#### 2. Panel
**File**: `BusinessCard/Panel.lua` — create; add `Panel.lua` to the `.toc` after `Core.lua`
- `MAX_ROWS = 20`, `local win`.
- `Build()`:
  - Window frame and drag, copied from `WarlockUtilityKit/Board.lua:97-101`: `BasicFrameTemplateWithInset`, named `"BusinessCardWin"`, `tinsert(UISpecialFrames, "BusinessCardWin")`.
  - Drag only when `not BC.db.locked`. Save the position in `BC.db.frames.win` on drag stop, restore it in `Build`.
  - Size 420 × (110 + 20 × 24).
  - Two top buttons `Seen` / `My card` (`UIPanelButtonTemplate`), which set `BC.db.view`; then `BC.RefreshPanel()`.
  - Category dropdown (`WowStyle1DropdownTemplate`), with entries `All` + `BC.CATS` labels; sets `BC.db.filter`.
  - A `Requests` checkbox (`UICheckButtonTemplate`) for `BC.db.showRequests`.
  - Row pool: `Button` frames 392×22 at a 24 px pitch, each with:
    - a status texture (8×8, hidden until Phase 5)
    - `row.name` FontString (left, 110 px)
    - `row.cats` (middle, 200 px, `GameFontDisableSmall`, no wrap)
    - `row.age` (right)
    - `RegisterForClicks("LeftButtonUp", "RightButtonUp")`
  - Row `OnClick(self, btn)`:
    - `btn == "RightButton"`: `BC.Seen()[self.key] = nil; BC.RefreshPanel()`.
    - `IsShiftKeyDown()`: `BC.ShowDetail(self.key)` (Phase 3 stub prints "card detail comes later").
    - Otherwise: `ChatFrame_OpenChat("/w " .. self.key .. " ")`.
  - Row `OnEnter`: GameTooltip with name, `CatList`, the last ad `text` and `age`.
  - A footer FontString: `"N shown / M seen"`.
- `BC.RenderSeen(rows)`: fills the pool with `SetShown(v ~= nil)`, as in `TackleBox/Panel.lua:179-200`.
- `BC.RefreshPanel()`: debounced 0.1 s (pattern from `TackleBox/Core.lua:42-50`); no-op if `win` is nil or hidden.
  - Seen view: `BC.RenderSeen(BC.SeenRows(BC.Seen(), BC.Cards and BC.Cards(), BC.db.filter, BC.db.showRequests, time()))`.
  - My card view: `BC.RenderMyCard()` (stub until Phase 4).
- `BC.TogglePanel()`: Build on first use; `win:SetShown(not win:IsShown())`; refresh. Refuses in combat with `BC.Print("not in combat")`.
- `table.insert(BC.onSeen, BC.RefreshPanel)`.
- `DEFAULTS` gains `view = "seen"`, `filter = "all"`, `showRequests = false`.

#### 3. Keybind + slash
- **File**: `BusinessCard/Bindings.xml` — create
```xml
<Bindings>
  <Binding name="BUSINESSCARD_TOGGLE" header="BUSINESSCARD" category="ADDONS">BusinessCard_Toggle()</Binding>
</Bindings>
```
- In `Panel.lua`:
  - `BINDING_HEADER_BUSINESSCARD = "BusinessCard"`
  - `BINDING_NAME_BUSINESSCARD_TOGGLE = "Toggle window"`
  - `function BusinessCard_Toggle() BC.TogglePanel() end`
- In `Core.lua`, the slash handler's empty `cmd` (`""`) calls `BC.TogglePanel()`.

#### 4. Tests
- `FormatAge(30)`, `(125)`, `(7200)` and `(200000)` give `now`, `2m`, `2h` and `2d`.
- `SeenRows`:
  - Filters by category.
  - Hides `req` entries unless `showRequests`.
  - Sorts newest first.
- `CatList` keeps `BC.CATS` order.

### Verification
#### Automated
- [ ] `lua BusinessCard/tests/run.lua` prints `all tests passed`

#### Manual
- [ ] `/bcard` and the keybind toggle the window. Esc closes it. Dragging moves it, and the position survives `/reload`. `/bcard lock` blocks dragging.
- [ ] The category dropdown filters rows. The Requests checkbox shows LF/WTB posts.
- [ ] Left-click opens `/w name`. Right-click removes the row. The tooltip shows the last ad text.

---

## Phase 4: My card + status (local)

### Changes

#### 1. Card model
**File**: `BusinessCard/Logic.lua` — modify
```lua
-- profs = {{id, name, skill}}, svcs = {key...}, status = {g="a"|"b", [statusKey]="a"|"b"|"o"}
-- Card = {rev, g, profs={{id, skill, st}}, svcs={{key, st}}}
function BC.BuildCard(profs, svcs, status, rev)
  local c = { rev = rev, g = status.g or "a", profs = {}, svcs = {} }
  for _, p in ipairs(profs) do c.profs[#c.profs + 1] = { id = p.id, skill = p.skill, st = status["p" .. p.id] or "a" } end
  for _, k in ipairs(svcs) do c.svcs[#c.svcs + 1] = { key = k, st = status[k] or "a" } end
  return c
end

function BC.SetStatus(char, key, st) -- key "g", "p<id>" or a service key
  if char.status[key] == st then return false end
  char.status[key] = st; char.rev = char.rev + 1
  return true
end

local NEXT = { a = "b", b = "o", o = "a" }
function BC.NextStatus(st) return NEXT[st or "a"] end
```

#### 2. Game reads + recipe cache
**File**: `BusinessCard/Core.lua` — modify
```lua
function BC.ReadProfessions()
  local out, p = {}, { GetProfessions() }
  for i = 1, 6 do if p[i] then
    local name, _, rank, _, _, _, line = GetProfessionInfo(p[i])
    if line then out[#out + 1] = { id = line, name = name, skill = rank } end
  end end
  return out
end

function BC.ReadServices()
  local out = {}
  for _, s in ipairs(BC.SERVICES) do
    if IsPlayerSpell(s.id) or C_Spell.GetSpellInfo(s.name) then out[#out + 1] = s.key end
  end
  return out
end

function BC.MyCard() return BC.BuildCard(BC.ReadProfessions(), BC.ReadServices(), BC.char.status, BC.char.rev) end

-- learned recipe IDs per profession; window must be open (ProfessionPlanner/Core.lua:28-40)
local tries = 0
function BC.ScanRecipes()
  if not C_TradeSkillUI.IsTradeSkillReady() then return end
  local info = C_TradeSkillUI.GetBaseProfessionInfo()
  local prof = info and info.professionID
  if not prof then return end
  local ids = {}
  for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
    local ri, pi = C_TradeSkillUI.GetRecipeInfo(id), C_TradeSkillUI.GetProfessionInfoByRecipeID(id)
    if ri and ri.learned and pi and (pi.professionID == prof or pi.parentProfessionID == prof) then ids[#ids + 1] = id end
  end
  if #ids == 0 and tries < 5 then tries = tries + 1; return C_Timer.After(0.5, BC.ScanRecipes) end
  tries = 0
  if #ids > 0 then BC.char.recipes[prof] = ids end
end
```
- `CHAR_DEFAULTS = { status = { g = "a" }, recipes = {}, rev = 0 }`.
- In an init: `BC.On("TRADE_SKILL_SHOW", BC.ScanRecipes)`, `BC.On("TRADE_SKILL_LIST_UPDATE", BC.ScanRecipes)`, `BC.On("SKILL_LINES_CHANGED", BC.RefreshPanel)`.
- `BC.onStatus = {}`, a hook list run after any status change (Phase 5 broadcasts on it).
- `function BC.ChangeStatus(key, st)`: if `BC.SetStatus(BC.char, key, st)`, run `BC.onStatus` and `BC.RefreshPanel()`.
- Slash: `busy` → `BC.ChangeStatus("g","b")`; `avail` → `BC.ChangeStatus("g","a")`. Both print the new state.

#### 3. My card view
**File**: `BusinessCard/Panel.lua` — modify
- `BC.RenderMyCard()` reuses the row pool. Hide the category dropdown and the Requests checkbox in this view.
- Row 1 is global: `"Overall: Available/Busy"`. Clicking toggles `g` between a and b.
- One row per profession: `PROF_NAMES[id] or name`, then `skill`, then the status label.
- One row per service: `label or name`, then the status label.
- Click cycles `BC.NextStatus`, using status key `"p"..id` or the service key.
- Status label colours: a = green `Available`, b = red `Busy`, o = grey `Off`.
- Footer:
  - `"Recipes cached: Enchanting 26, Tailoring 40"` from `BC.char.recipes`
  - `"Open a profession window to cache recipes"` if empty
- Row `OnClick` dispatches on `BC.db.view`: seen actions vs. status cycling.

#### 4. Tests
- `BuildCard` with stub profs and services:
  - Default status is `a`.
  - Status overrides apply.
  - `g` is copied.
- `SetStatus`:
  - Bumps `rev` on change.
  - Returns false and leaves `rev` alone when unchanged.
- `NextStatus` cycles a → b → o → a, and nil → b.

### Verification
#### Automated
- [ ] `lua BusinessCard/tests/run.lua` prints `all tests passed`

#### Manual
- [ ] My card lists real professions with skill. A warlock shows Summon; a mage shows the learned teleports and portals.
- [ ] Clicking cycles the status. `/bcard busy` and `/bcard avail` flip Overall. The state survives `/reload`.
- [ ] Open Enchanting: the footer shows the recipe count, and it survives `/reload`.

---

## Phase 5: Card exchange (guild + whisper on demand)

### Changes

#### 1. Wire format
**File**: `BusinessCard/Logic.lua` — modify
```lua
BC.PROTO = "1"
local function enc(v) if v == nil or v == "" then return "-" end return tostring(v) end
function BC.Split(msg) local f = {} for p in (msg .. "|"):gmatch("(.-)|") do f[#f + 1] = p end return f end

-- 1|C|rev|g|profs|svcs   profs = id:skill:st,...   svcs = key:st,...
function BC.EncodeCard(c)
  local p, s = {}, {}
  for _, x in ipairs(c.profs) do p[#p + 1] = x.id .. ":" .. x.skill .. ":" .. x.st end
  for _, x in ipairs(c.svcs) do s[#s + 1] = x.key .. ":" .. x.st end
  return table.concat({ BC.PROTO, "C", c.rev, c.g, enc(table.concat(p, ",")), enc(table.concat(s, ",")) }, "|")
end

local ST = { a = true, b = true, o = true }
function BC.Decode(msg)
  if type(msg) ~= "string" then return nil end
  local f = BC.Split(msg)
  if f[1] ~= BC.PROTO then return nil end
  if f[2] == "Q" and #f == 2 then return { kind = "Q" } end
  if f[2] == "C" and #f == 6 and tonumber(f[3]) and ST[f[4]] then
    local c = { kind = "C", rev = tonumber(f[3]), g = f[4], profs = {}, svcs = {} }
    if f[5] ~= "-" then for id, sk, st in f[5]:gmatch("(%d+):(%d+):(%a)") do
      c.profs[#c.profs + 1] = { id = tonumber(id), skill = tonumber(sk), st = st } end end
    if f[6] ~= "-" then for k, st in f[6]:gmatch("([%w%-]+):(%a)") do c.svcs[#c.svcs + 1] = { key = k, st = st } end end
    return c
  end
  -- RQ / RL added in Phase 6
end

-- categories a card advertises (status not "o"), for card-only Seen rows
BC.PROF_CAT = { [333]="enchanting", [197]="tailoring", [165]="leatherworking", [171]="alchemy", [164]="blacksmithing",
  [202]="engineering", [755]="jewelcrafting", [185]="cooking", [129]="firstaid" }
function BC.CardCats(c)
  local cats = {}
  for _, p in ipairs(c.profs) do if p.st ~= "o" and BC.PROF_CAT[p.id] then cats[BC.PROF_CAT[p.id]] = true end end
  for _, s in ipairs(c.svcs) do if s.st ~= "o" then cats[s.key == "S" and "summon" or "portal"] = true end end
  return cats
end

-- "a" when globally available and at least one entry for cat is available; else "b"; nil when unknown
function BC.CardStatus(c, cat)
  if not c then return nil end
  if c.g == "b" then return "b" end
  for _, p in ipairs(c.profs) do if (cat == "all" or BC.PROF_CAT[p.id] == cat) and p.st == "a" then return "a" end end
  for _, s in ipairs(c.svcs) do
    local sc = s.key == "S" and "summon" or "portal"
    if (cat == "all" or sc == cat) and s.st == "a" then return "a" end
  end
  return "b"
end
```
- `SeenRows` extension: after the `seen` loop, add every `cards[name]` not already in `seen`. Each gets `cats = BC.CardCats(card)`, `at = card.at`, `text = nil`, and is never a request. Then apply the same filter and sort.

#### 2. Comm
**File**: `BusinessCard/Comm.lua` — create; add it to the `.toc` after `Core.lua`
```lua
local ADDON, BC = ...
local queue, nextSend, failures = {}, 0, 0
BC.commOff = false

-- ponytail: one shared queue with per-message pacing; per-target buckets if stranger requests pile up
local function Flush()
  local m = queue[1]
  if not m or GetTime() < nextSend then return end
  local r = C_ChatInfo.SendAddonMessage(BC.PREFIX, m.msg, m.ch, m.to)
  if r == 0 or r == true then
    table.remove(queue, 1); failures = 0; nextSend = GetTime() + (m.ch == "WHISPER" and 1 or 0.5)
  elseif r == 12 then table.remove(queue, 1) -- TargetOffline
  elseif r == 3 or r == 8 then failures = failures + 1; nextSend = GetTime() + math.min(30, 2 ^ failures) -- throttles
  else -- trial/veteran, lockdown, not in guild, ...
    BC.commOff = true; wipe(queue)
    BC.Print("card sharing unavailable (code " .. tostring(r) .. "); the ad log still works")
  end
end

function BC.Send(msg, ch, to)
  if BC.commOff or #queue >= 64 then return end
  queue[#queue + 1] = { msg = msg, ch = ch, to = to }
end

function BC.Cards() local r = GetRealmName(); BC.db.cards[r] = BC.db.cards[r] or {}; return BC.db.cards[r] end

local asked = {}
local function Ask(name)
  if asked[name] or IsInInstance() then return end
  asked[name] = true
  BC.Send(BC.PROTO .. "|Q", "WHISPER", name)
end
BC.Ask = Ask

local pending = false
local function BroadcastGuild()
  if pending or not IsInGuild() then return end
  pending = true
  C_Timer.After(10, function() pending = false; BC.Send(BC.EncodeCard(BC.MyCard()), "GUILD") end)
end

table.insert(BC.inits, function()
  C_Timer.NewTicker(0.25, Flush)
  BC.On("CHAT_MSG_ADDON", function(prefix, text, ch, sender)
    if prefix ~= BC.PREFIX or BC.Secret(text) or BC.Secret(sender) then return end
    local name = Ambiguate(sender, "none")
    if name == UnitName("player") then return end
    local m = BC.Decode(text)
    if not m then return end
    if m.kind == "Q" then BC.Send(BC.EncodeCard(BC.MyCard()), "WHISPER", sender)
    elseif m.kind == "C" then
      local cards = BC.Cards()
      if not cards[name] or cards[name].rev ~= m.rev then m.at = time(); cards[name] = m; BC.RefreshPanel() end
      if ch == "GUILD" and not asked[name] then asked[name] = true end
    end
    if BC.OnComm then BC.OnComm(name, m, sender) end -- Phase 6 hook
  end)
  table.insert(BC.onSeen, function(name, r) if not r.request then Ask(name) end end)
  table.insert(BC.onStatus, BroadcastGuild)
  BroadcastGuild() -- login broadcast (10 s after login)
end)
```
- Compare `rev` with `~=` rather than `>`, so a peer whose SavedVariables reset (rev back to 0) still updates.
- `DEFAULTS` gains `cards = {}`. Cards are pruned with `BC.SeenPrune(BC.Cards(), …)` at login, using the same 7 days and a 500 cap; `SeenPrune` uses `e.at`, which cards also carry.
- **Phase 1 gate (stranger ping failed):** replace the `onSeen` insert with nothing and leave a `-- probe: stranger whisper blocked` comment. Shift-click `Ask` then only works for guildmates.
- The Phase 1 ping/pong handler stays, since `Decode` ignores non-protocol messages.

#### 3. Panel badges
**File**: `BusinessCard/Panel.lua` — modify
- Status texture per row:
  - `BC.CardStatus(row.card, filter)` → `a` green `{0.2,0.9,0.2}`, `b` red `{0.9,0.2,0.2}`; nil → hidden.
- A small addon icon (`Interface\Icons\INV_Letter_15`, 12×12) is shown when `row.card` exists.
- The tooltip adds a card summary: professions as `Name skill (status)`, then services.
- Shift-click on a row calls `BC.Ask(name)` before `BC.ShowDetail(name)`, which forces a fresh card.

#### 4. Tests
- `EncodeCard` → `Decode` round trip: profs, svcs, `g`, `rev`.
- An empty card encodes as `1|C|0|a|-|-` and decodes with empty lists.
- A max card (6 profs at skill 300, all 13 services) encodes to ≤255 bytes: `assert(#s <= 255)`.
- `Decode` rejects:
  - wrong PROTO
  - a C with 5 fields
  - a non-numeric rev
  - status `x`
  - `nil`
- `CardCats` skips status `o`.
- `CardStatus`:
  - global busy → `b`
  - an available enchanting entry → `a` for `"enchanting"`, `b` for `"tailoring"`
  - nil card → nil
- `SeenRows` with a card-only name includes it with `CardCats` categories.

### Verification
#### Automated
- [ ] `lua BusinessCard/tests/run.lua` prints `all tests passed`

#### Manual
- [ ] Two guildmates with the addon see each other in Seen within about 10 s of login, with badge and icon.
- [ ] Toggle `/bcard busy` on A: B's badge turns red within about 10 s.
- [ ] A (not in B's guild) says `"WTS ports"` in Trade or whispers it to B: B's row gets A's card after the `Q`/`C` round trip.
- [ ] A trial or Veteran account prints one `card sharing unavailable` line, and Seen keeps filling.
- [ ] Inside a dungeon, no `Q` is sent (check with `/bcard ping` timing or `/etrace` that no BCARD whispers go out).

---

## Phase 6: Recipe list on request

### Changes

#### 1. Chunking + base 36
**File**: `BusinessCard/Logic.lua` — modify
```lua
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
function BC.B36(n)
  local s = ""
  repeat local d = n % 36; s = DIGITS:sub(d + 1, d + 1) .. s; n = math.floor(n / 36) until n == 0
  return s
end

-- comma-joined base-36 ids, each chunk <= maxBytes
function BC.ChunkIDs(ids, maxBytes)
  local chunks, cur = {}, {}
  local len = 0
  for _, id in ipairs(ids) do
    local t = BC.B36(id)
    if len > 0 and len + 1 + #t > maxBytes then chunks[#chunks + 1] = table.concat(cur, ","); cur, len = {}, 0 end
    cur[#cur + 1] = t; len = len + (len > 0 and 1 or 0) + #t
  end
  if #cur > 0 then chunks[#chunks + 1] = table.concat(cur, ",") end
  return chunks
end

-- buf[key] = {total, parts={}, n, at}; returns full id list when complete, {} for total 0
function BC.Reassemble(buf, key, seq, total, part, now)
  for k, b in pairs(buf) do if now - b.at > 30 then buf[k] = nil end end
  if total == 0 then return {} end
  local b = buf[key]
  if not b or b.total ~= total then b = { total = total, parts = {}, n = 0, at = now }; buf[key] = b end
  if not b.parts[seq] then b.parts[seq] = part; b.n = b.n + 1 end
  if b.n < total then return nil end
  buf[key] = nil
  local ids = {}
  for i = 1, total do for t in (b.parts[i] or ""):gmatch("[^,]+") do ids[#ids + 1] = tonumber(t, 36) end end
  return ids
end
```
- `Decode` additions:
  - `RQ`: `#f == 3` and `tonumber(f[3])` → `{kind="RQ", prof}`.
  - `RL`: `#f == 6`, with numeric `prof`, `seq`, `total` and `seq <= total` → `{kind="RL", prof, seq, total, part = f[6] ~= "-" and f[6] or ""}`.

#### 2. Comm handlers
**File**: `BusinessCard/Comm.lua` — modify
```lua
local buf, lists = {}, {} -- lists[name..":"..prof] = ids (session cache)
function BC.RequestRecipes(name, prof) BC.Send(BC.PROTO .. "|RQ|" .. prof, "WHISPER", name) end
function BC.RecipeList(name, prof) return lists[name .. ":" .. prof] end

function BC.OnComm(name, m, sender)
  if m.kind == "RQ" then
    local ids = BC.char.recipes[m.prof] or {}
    local chunks = BC.ChunkIDs(ids, 200)
    if #chunks == 0 then return BC.Send(table.concat({ BC.PROTO, "RL", m.prof, 0, 0, "-" }, "|"), "WHISPER", sender) end
    for i, c in ipairs(chunks) do BC.Send(table.concat({ BC.PROTO, "RL", m.prof, i, #chunks, c }, "|"), "WHISPER", sender) end
  elseif m.kind == "RL" then
    local ids = BC.Reassemble(buf, name .. ":" .. m.prof, m.seq, m.total, m.part, time())
    if ids then lists[name .. ":" .. m.prof] = ids; BC.RefreshDetail() end
  end
end
```
- Queue room: a 300-recipe profession is about 6 chunks, well under the 64-message queue cap.

#### 3. Detail pane
**File**: `BusinessCard/Panel.lua` — modify; replace the `BC.ShowDetail` stub
- `detail`: a `BasicFrameTemplateWithInset` frame (300 × 520) anchored `TOPLEFT` to `win`'s `TOPRIGHT`, added to `UISpecialFrames`.
- Header: name and the global status. Service list as a single FontString (`"Summon (Available), Portal: Undercity (Busy)"`).
- Profession buttons, one per card profession, labelled `PROF_NAMES[id] skill`. Clicking sets `detail.prof`. If no list is cached, it shows "Requesting…" and calls `BC.RequestRecipes(name, id)`.
- Search: an `EditBox` with `SearchBoxTemplate`; `OnTextChanged` refreshes.
- A pool of 20 recipe-name rows, plus a `"x of N"` footer. No scroll; the search narrows the list.
  - Names resolve through `C_TradeSkillUI.GetRecipeInfo(id)`, then `.name`, then `C_Spell.GetSpellName(id)`, then `"Recipe #" .. id`.
  - Names are resolved once per list and cached alongside it.
  - Filter by lowercase substring (`string.find(name:lower(), q, 1, true)`) and sort alphabetically.
- An empty list (`total 0`) shows `"They haven't opened that profession yet."`
- With no card: `"No card yet — they may not run BusinessCard."`
- `BC.RefreshDetail()` re-renders if `detail` is shown.

#### 4. Tests
- `B36(0)`, `(35)`, `(36)` and `(1263080)` round-trip through `tonumber(s, 36)`.
- `ChunkIDs(500 ids, 200)`: every chunk is ≤200 bytes, and the concatenated decode equals the input.
- `Reassemble`:
  - chunks in order 2, 1 → full list on the second call
  - one missing chunk → nil
  - after `now + 31` the buffer is purged
  - `total 0` → `{}`
- `Decode`:
  - an `RL` with `seq > total` is rejected
  - a valid `RQ` and `RL` parse
- A full `RL` message line is ≤255 bytes for a 200-byte chunk with a 6-digit `prof` and 3-digit `seq`/`total`.

### Verification
#### Automated
- [ ] `lua BusinessCard/tests/run.lua` prints `all tests passed`

#### Manual
- [ ] Shift-click a guildmate with the addon. Their professions are listed; click Enchanting, and the recipe names appear within about 10 s. The search narrows the list.
- [ ] A profession they never opened shows the "haven't opened" message.
- [ ] A stranger seen in Trade (if the stranger-whisper gate passed) works the same way.
- [ ] Shift-click someone without the addon: "No card yet".
- [ ] Bump to `0.6.0` and add the CHANGELOG entry. Push to `main` and check that the `package-bcard.yml` run publishes `bcard-v0.6.0`.
