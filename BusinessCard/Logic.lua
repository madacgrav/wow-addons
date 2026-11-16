local ADDON, BC = ...

function BC.MergeDefaults(sv, defaults)
  if type(sv) ~= "table" then sv = {} end
  for k, v in pairs(defaults) do
    if type(v) == "table" then sv[k] = BC.MergeDefaults(sv[k], v)
    elseif sv[k] == nil then sv[k] = v end
  end
  return sv
end
