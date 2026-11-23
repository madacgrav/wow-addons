# Task

WarlockCombatKit's per-target DoT tracker breaks inside dungeons: instead of one row per enemy (named, with its DoTs), it collapses everything into a single row labelled "Target". Outside instances it works correctly. Goal: make the tracker keep distinct, labelled rows per enemy inside dungeons (or degrade as gracefully as the instance API allows).
