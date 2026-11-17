# Research Questions

## Context
Focus on the five top-level addon directories (ProfessionPlanner, TackleBox, WarlockCombatKit, WarlockUtilityKit, BusinessCard), their README/CHANGELOG/.toc files and `Core.lua` slash handlers, the root `README.md`, and the per-addon workflows in `.github/workflows/`. Also look at the `thoughts/qrspi/` folders only for how work on an addon is carried from plan to release.

## Questions
1. For each addon, what does its `README.md` document (sections, install steps, usage, screenshots/assets), and how consistent is that structure across the five addons?
2. Trace each addon's slash command handler in `Core.lua`: what subcommands and arguments are accepted, what each does, and where (if anywhere) the help/usage text is defined? Also list any key bindings declared in `Bindings.xml` files.
3. What metadata does each `.toc` file carry (Interface version, Title, Notes, Version, SavedVariables, dependencies)? What format does each `CHANGELOG.md` follow (headings, version/date lines, entry style), and how do the `.toc` version, the changelog versions, and the release tag prefix relate?
4. How do the `.github/workflows/package-*.yml` workflows work end to end — triggers, tag patterns, what files are packaged, release names and asset file names, release body/notes source, and permissions? Using `gh release list` / `gh release view`, what releases exist today per tag prefix, which one GitHub marks as "Latest", and what are the asset download URLs?
5. What do the root `README.md` and addon READMEs say about installing an addon into the WoW Forever client (folder paths, download source, client version/Interface number), and what is the client's AddOns directory layout as referenced anywhere in the repo?
6. When an addon is created or changed, which files are touched as part of a release (CHANGELOG, .toc version, README, root README, workflows)? Use recent git history and the `thoughts/qrspi/*/plan.md` files to describe the actual sequence of steps.
7. Are there any existing static assets (images, icons, screenshots, HTML/CSS/Markdown site files, Jekyll/Pages config) anywhere in the repo, and what does `.gitignore` exclude?
