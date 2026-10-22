local ADDON, WCK = ...
WCK.DATA = {}
-- ponytail: enUS names; Forever spell names come from beta notes, unknown ones are skipped at login
-- stale = seconds after which the icon is fully faded (rough durations, not timers)
WCK.DATA.tracked = {
  ["Corruption"] = { kind = "dot", stale = 18 }, ["Immolate"] = { kind = "dot", stale = 15 },
  ["Siphon Life"] = { kind = "dot", stale = 30 }, ["Unstable Affliction"] = { kind = "dot", stale = 18 },
  ["Curse of Agony"] = { kind = "curse", stale = 24 }, ["Bane of Agony"] = { kind = "curse", stale = 24 },
  ["Curse of Doom"] = { kind = "curse", stale = 60 }, ["Bane of Doom"] = { kind = "curse", stale = 60 },
  ["Bane of Havoc"] = { kind = "curse", stale = 300 },
  ["Curse of the Elements"] = { kind = "curse", stale = 300 }, ["Curse of Recklessness"] = { kind = "curse", stale = 120 },
  ["Curse of Weakness"] = { kind = "curse", stale = 120 }, ["Curse of Tongues"] = { kind = "curse", stale = 30 },
  ["Curse of Exhaustion"] = { kind = "curse", stale = 12 },
  ["Fear"] = { kind = "cc", stale = 20 }, ["Banish"] = { kind = "cc", stale = 30 },
  ["Seduction"] = { kind = "cc", stale = 15 }, ["Death Coil"] = { kind = "cc", stale = 3 },
  ["Howl of Terror"] = { kind = "cc", stale = 8 },
}

-- spells offered in the rule editor (filtered to known spells when the menu opens)
WCK.DATA.rotation = { "Shadow Bolt", "Incinerate", "Searing Pain", "Soul Fire", "Shadowburn", "Conflagrate", "Drain Life",
  "Drain Soul", "Life Tap", "Haunt", "Chaos Bolt", "Corruption", "Immolate", "Siphon Life", "Unstable Affliction",
  "Curse of Agony", "Bane of Agony", "Curse of Doom", "Bane of Doom", "Curse of the Elements", "Curse of Recklessness",
  "Fear", "Death Coil", "Howl of Terror" }
WCK.DATA.defaultRules = {
  { spell = "Corruption", cond = "notRecent", n = 15 }, { spell = "Curse of Agony", cond = "notRecent", n = 22 },
  { spell = "Bane of Agony", cond = "notRecent", n = 22 }, { spell = "Immolate", cond = "notRecent", n = 13 },
  { spell = "Shadow Bolt", cond = "proc" }, { spell = "Shadow Bolt", cond = "ready" },
}
WCK.DATA.conds = { "ready", "notRecent", "proc", "marked", "usable" } -- "usable" only if WCK.USABLE_OK
WCK.DATA.condLabels = { ready = "off cooldown", notRecent = "not cast on target in N s", proc = "proc up",
  marked = "target has a mark", usable = "usable (mana/range)" }

-- spell = the spell a proc makes instant; the proc is up while its castTime reads 0 (probe runs 11-12)
WCK.DATA.procs = {
  { key = "nightfall", spell = "Shadow Bolt", icon = "Interface\\Icons\\Spell_Shadow_Twilight" },
}
