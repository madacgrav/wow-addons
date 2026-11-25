# Research Questions

## Context
Focus on the TackleBox addon (`TackleBox/`): `Core.lua` event handling and slash commands, `CastBar.lua` screen-flash frame, `Actions.lua` lure application, `Logic.lua` pure helpers, `Data.lua` lure table, `tests/run.lua` harness. Also relevant: the WoW Forever (Interface 16xxx) API surface for weapon enchants, sounds and on-screen messages.

## Questions
1. Trace every call site of `TB.Flash()` in TackleBox: what triggers each one, what settings gate it (`TB.db.flash`, cooldowns, combat checks), and how the `TBFlash` frame and its animation group are built in `CastBar.lua` (texture, color, alpha, duration). Can color be set per call today?
2. How does TackleBox currently detect and apply fishing lures: the `GetWeaponEnchantInfo` usage in `Actions.lua`, `PickLure` in `Logic.lua`, and the `TB.DATA.lures` table in `Data.lua`? Which return values of `GetWeaponEnchantInfo` (has enchant, expiration ms, charges, enchant ID) are read or ignored?
3. What events and polling mechanisms does TackleBox register (event frame in `Core.lua`, OnUpdate/timer usage, `C_Timer`), and which ones fire while the player is fishing or idle? Is there any existing periodic tick?
4. On WoW Forever / Classic Era clients, which events or APIs signal a main-hand temporary weapon enchant appearing or expiring (e.g. `UNIT_INVENTORY_CHANGED`, `PLAYER_EQUIPMENT_CHANGED`, `GetWeaponEnchantInfo` polling), and how do existing addons (in this repo or common ones) detect expiry? Check the bundled Forever API index from the wow-forever-addon skill.
5. What APIs and existing patterns exist for on-screen notifications and sounds: `RaidNotice_AddMessage`/`RaidWarningFrame`, `UIErrorsFrame:AddMessage`, `PlaySound` with `SOUNDKIT` IDs, `PlaySoundFile`? Look at `WarlockCombatKit/Core.lua` `PlaySound` usage and any other addons in the repo that alert the user.
6. How are TackleBox settings defined, toggled and documented: `DEFAULTS`/`CHAR_DEFAULTS` and `MergeDefaults`, the `/tb` slash-command parser and help text, README/CHANGELOG conventions, and how `tests/run.lua` mocks the WoW API for `Logic.lua` functions?
