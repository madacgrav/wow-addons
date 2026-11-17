-- Addon-specific luacheck settings. Run via <skill>/scripts/lint.sh, which prepends stds.forever
-- and the base config, so extend `globals` rather than replacing it.
globals = globals or {}
for _, g in ipairs({ "BusinessCardDB", "BusinessCardCharDB", "BusinessCard_Toggle", "BusinessCardWin" }) do
  globals[#globals + 1] = g
end
