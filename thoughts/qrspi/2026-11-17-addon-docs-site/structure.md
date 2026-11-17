# Structure Outline

## Approach
A single `docs/index.html` (inline CSS and JS, `marked` from cdnjs). In the browser it fetches each addon's `.toc`, `README.md` and `CHANGELOG.md` from `raw.githubusercontent.com/.../main/` and the releases list from the GitHub API, then renders a tab per addon. GitHub Pages serves it from `main` `/docs`. Repo docs get aligned: `_forever_` install path, BusinessCard brought in line, root README updated.

## Phase 1: Page shell + one addon end to end
The intro, the install guide, and a working tab for **ProfessionPlanner** only: header card from `.toc` + newest `pp-v*` release, then the rendered README, then the rendered CHANGELOG. This proves the fetch, parse and render path.

**Files**: `docs/index.html` (new), `docs/.nojekyll` (new, empty)
**Key changes** (inline `<script>`):
- `const REPO = "madacgrav/wow-addons"`, `const RAW = "https://raw.githubusercontent.com/" + REPO + "/main/"`
- `const ADDONS = [{ dir: "ProfessionPlanner", prefix: "pp" }]`
- `parseToc(text: string): { Title, Notes, Version, Interface }`: matches lines of the form `^## (\w+): (.*)$`
- `fetchReleases(): Promise<Release[]>`: `GET api.github.com/repos/{REPO}/releases?per_page=100`, cached in `sessionStorage`, wrapped in try/catch
- `latestFor(prefix, releases): { tag, version, zipUrl, pageUrl } | null`: filters `tag_name` starting with `prefix + "-v"`, takes max `published_at`, picks the `.zip` asset
- `renderAddon(addon, releases): Promise<HTMLElement>`: card, then `marked.parse(readme)` with the H1 dropped, then `marked.parse(changelog)`
- Markup: `<header>` intro, `<section id="install">`, `<nav role="tablist">`, one `<section role="tabpanel">` per addon
- CSS: tokens on `:root`, a dark default, a `prefers-color-scheme: light` override, and a 16px gutter at ≤600px

**Verify**: `python -m http.server -d docs 8000` and open it in the browser pane. The PP tab shows Title "Profession Planner", v0.2.1, and the Download link is `.../releases/download/pp-v0.2.1/ProfessionPlanner-0.2.1.zip`. The README tables and lists render, the changelog shows `[0.2.1] — 2026-10-20` first, and the console has no errors.

---

## Phase 2: All five tabs, deep links, link rewrite, fallbacks
The remaining four addons go in the list, plus hash deep links, README link fixups and graceful failure handling.

**Files**: `docs/index.html`
**Key changes**:
- `ADDONS` gains `{TackleBox,"tb"}`, `{WarlockCombatKit,"wck"}`, `{WarlockUtilityKit,"wuk"}`, `{BusinessCard,"bcard"}`
- `selectTab(dir: string)`: sets `aria-selected`, shows the panel, writes `location.hash`. On load and on `hashchange` it reads the hash, defaulting to the first tab. Arrow keys move between tabs.
- `fixLinks(root: HTMLElement, dir: string)`: relative `href` → `https://github.com/{REPO}/blob/main/{dir}/{path}`; `CHANGELOG.md` → `#{dir}-changelog`; `../X/` → `#X`
- Fallbacks:
  - no releases or API error: the Download button becomes "Releases" and links to `github.com/{REPO}/releases?q={prefix}-v`;
  - a failed raw fetch shows an inline "couldn't load, view on GitHub" link for that part only.
- Each panel renders lazily on first open, so a single page load does not fetch every README.

**Verify**: in the browser pane:
- all five tabs show the versions `gh release list` reports as newest (pp 0.2.1, tb 1.0.0, wck 0.2.0, wuk 0.5.0, bcard 0.8.5);
- `#WarlockUtilityKit` opens directly;
- WCK's "Warlock Utility Kit" link switches tabs;
- forcing the API URL to a bad host (devtools) gives the Releases fallback while READMEs still render;
- at mobile width (375px) there is no horizontal page scroll.

---

## Phase 3: Align repo docs
The READMEs and CHANGELOGs the site renders become consistent and correct.

**Files**:
- `ProfessionPlanner/README.md`, `TackleBox/README.md`, `WarlockCombatKit/README.md`, `WarlockUtilityKit/README.md`: Install path `_classic_beta_` → `_forever_`, plus a Development line: "New addon? Add it to `ADDONS` in `docs/index.html`."
- `BusinessCard/README.md`: new `## Install` section with the PP:9-13 skeleton, tag `bcard-vX.Y.Z`, and a `## Development` section with the CI/version line and the ADDONS line
- `BusinessCard/CHANGELOG.md`: title `# Changelog — BusinessCard`, the standard intro line, and 20 headings rewritten as `## [X.Y.Z] — 2026-11-16`. Entries stay unchanged.
- `README.md` (root): BusinessCard bullet (`bcard-v` releases), a link to `https://madacgrav.github.io/wow-addons/`, and a one-line install pointer to the site

**Verify**:
- `grep -rn "_classic_beta_" */README.md README.md` returns nothing;
- `grep -c "^## \[" BusinessCard/CHANGELOG.md` gives 20;
- `grep -n "BusinessCard" README.md` matches;
- the local site still renders, since it reads `main` and these files change only after merge, so check the markdown preview of the edited files.

---

## Phase 4: Publish and keep current
Ship the change, turn on Pages, and record the upkeep rule.

**Files / actions**:
- branch, commit and PR. After merge, `package-*.yml` re-runs for the touched addons and re-uploads the same zips (`--clobber`), with no new tags. Expected.
- `gh api -X POST repos/madacgrav/wow-addons/pages -f "source[branch]=main" -f "source[path]=/docs"` (**user approval**)
- `gh repo edit madacgrav/wow-addons --homepage https://madacgrav.github.io/wow-addons/` (**user approval**)
- memory note `docs-site-addon-list.md`: a new addon means adding it to `ADDONS` in `docs/index.html` and to the root README, plus the workflow. Existing addon updates need nothing.

**Verify**:
- `gh api repos/madacgrav/wow-addons/pages -q .status` gives `built`;
- the live URL shows all five tabs and the correct Download links;
- the BusinessCard tab shows the dated changelog and Install section;
- `gh release list` shows no new releases from the merge.

## Testing Checkpoints
- **After 1:** `docs/index.html` serves locally. The intro, the install guide and the PP tab fully render with the correct v0.2.1 download.
- **After 2:** five tabs with correct newest versions, hash deep links, rewritten links, the API-failure fallback, and a clean mobile layout.
- **After 3:** no `_classic_beta_` in READMEs; BusinessCard has Install, Development and a dated changelog; the root README lists all five plus the site link.
- **After 4:** the PR is merged, the Pages site is live at `madacgrav.github.io/wow-addons/`, the homepage is set, the memory note is saved, and there are no stray releases.
