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

-- spell = the spell a proc makes instant; the proc is up while its castTime reads 0 (probe runs 11-12)
WCK.DATA.procs = {
  { key = "nightfall", spell = "Shadow Bolt", icon = "Interface\\Icons\\Spell_Shadow_Twilight" },
}
