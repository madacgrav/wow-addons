-- Addon-specific luacheck settings, appended by <skill>/scripts/lint.sh after stds.forever and the base config.
-- Override-binding API: not in the Forever docs or index; used by Forever fishing addons (Fishing-OneKey, BetterFishing).
-- Guarded at runtime in Actions.lua (TB.HasBindAPI). Confirm in game with /tb probe.
-- GameTooltipTextLeft1 (FrameXML tooltip line), LibStub and HBD_PINS_WORLDMAP_SHOW_PARENT (embedded libs) are missing from the std.
read_globals = read_globals or {}
for _, g in ipairs({ "SetOverrideBinding", "SetOverrideBindingClick", "ClearOverrideBindings",
  "GameTooltipTextLeft1", "LibStub", "HBD_PINS_WORLDMAP_SHOW_PARENT" }) do
  read_globals[#read_globals + 1] = g
end
