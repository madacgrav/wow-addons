# Implementation Plan

## Overview
Publish a GitHub Pages site at `https://madacgrav.github.io/wow-addons/`. It explains the repo, shows how to install an addon into WoW Forever (`_forever_\Interface\AddOns\`), and gives a tab per addon: a header card built from the `.toc` with a download link to the newest release for that addon's prefix, then the README and the CHANGELOG. All content is fetched live from `main` and the Releases API, so addon updates need no site edits.

Context:
- Repo `madacgrav/wow-addons`, default branch `main`, public.
- Addons and prefixes: ProfessionPlanner `pp`, TackleBox `tb`, WarlockCombatKit `wck`, WarlockUtilityKit `wuk`, BusinessCard `bcard`.
- Release tag `<prefix>-v<ver>`, single asset `<Dir>-<ver>.zip`.
- Newest releases today: pp 0.2.1, tb 1.0.0, wck 0.2.0, wuk 0.5.0, bcard 0.8.5.
- Work on branch `2026-11-17-addon-docs-site`. The commit includes this `thoughts/qrspi/2026-11-17-addon-docs-site/` folder. Do **not** stage `thoughts/qrspi/2026-10-21-forever-fishing-addon-gaps/plan.md` or `WoW Forever Addon Ideas — PRD.md`, which are unrelated local changes.

## Phase 1: Page shell + one addon end to end

### Changes

#### 1. Pages marker
**File**: `docs/.nojekyll`
**Action**: create (empty file)

#### 2. Site page
**File**: `docs/index.html`
**Action**: create

Structure (write the full file. Content and copy below; styling follows the tokens given):

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>WoW Forever Addons</title>
<meta name="description" content="Addons for WoW Forever: install guide, commands and changelogs.">
<script src="https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.2/marked.min.js"></script>
<style>
  :root { --bg:#0f0b14; --panel:#1a1422; --line:#3a2d4a; --text:#e8e2ef; --muted:#a99bb8;
          --accent:#d4a73a; --accent-ink:#1a1422; --link:#c9a2ff; --code:#251c30; }
  @media (prefers-color-scheme: light) {
    :root { --bg:#f7f4fa; --panel:#fff; --line:#ddd2e8; --text:#1f1828; --muted:#5f5370;
            --accent:#8a5a00; --accent-ink:#fff; --link:#6b2fb3; --code:#f0eaf6; } }
  body { margin:0; background:var(--bg); color:var(--text); font:16px/1.6 system-ui, sans-serif; }
  main { max-width:960px; margin:0 auto; padding:24px 16px 64px; }
  /* tabs: nav[role=tablist] flex, overflow-x:auto; button[aria-selected=true] underline in --accent */
  /* .card: panel bg, border --line, radius 10px; .dl: --accent bg, --accent-ink text button */
  /* .md table { display:block; overflow-x:auto } ; code/pre bg --code ; .log h2 { font-size:1.15rem } */
  /* never let content widen the page: img,pre,table { max-width:100% } */
</style>
</head>
<body>
<main>
  <header>
    <h1>WoW Forever Addons</h1>
    <p>Small, focused addons for the <strong>WoW Forever</strong> client (Interface 16001). Each addon lives in its own
       folder of the <a href="https://github.com/madacgrav/wow-addons">wow-addons</a> repo, has its own README and
       changelog, and is released as a zip on GitHub every time its version changes.</p>
  </header>

  <section id="install">
    <h2>Installing an addon</h2>
    <ol>
      <li>Pick an addon below and click <strong>Download</strong> to get its <code>.zip</code>.</li>
      <li>Close the game, or plan to restart it.</li>
      <li>Open your World of Warcraft folder (default <code>C:\Program Files (x86)\World of Warcraft\</code>) and go to
          <code>_forever_\Interface\AddOns\</code>. Create the <code>AddOns</code> folder if it is missing.</li>
      <li>Extract the zip there. The addon folder (for example <code>TackleBox</code>) must sit directly inside
          <code>AddOns</code>, not inside another folder: <code>_forever_\Interface\AddOns\TackleBox\TackleBox.toc</code>.</li>
      <li>Start the game. On character select, click <strong>AddOns</strong> and make sure the addon is ticked.</li>
    </ol>
    <p><strong>Updating:</strong> delete the old addon folder, extract the new zip the same way, then restart or
       <code>/reload</code>. Your settings are kept (they live in <code>WTF\</code>, not the addon folder).
       Addons with key bindings (Warlock Combat Kit, BusinessCard) need a full restart the first time.</p>
    <p><strong>Removing:</strong> delete the addon folder from <code>AddOns</code>.</p>
  </section>

  <section id="addons">
    <h2>Addons</h2>
    <nav role="tablist" aria-label="Addons" id="tabs"></nav>
    <div id="panels"></div>
  </section>
</main>
<script>/* below */</script>
</body>
</html>
```

Script (Phase 1 version):

```js
const REPO = "madacgrav/wow-addons";
const RAW = `https://raw.githubusercontent.com/${REPO}/main/`;
const GH = `https://github.com/${REPO}`;
const ADDONS = [ // new addon? add one line: folder name + release tag prefix
  { dir: "ProfessionPlanner", prefix: "pp" },
];

function parseToc(text) {
  const out = {};
  for (const m of text.matchAll(/^## (\w+): *(.*?)\s*$/gm)) out[m[1]] = m[2];
  return out;
}

async function getText(path) {
  const r = await fetch(RAW + path);
  if (!r.ok) throw new Error(`${path}: ${r.status}`);
  return r.text();
}

let releasesPromise;
function fetchReleases() {
  return releasesPromise ??= (async () => {
    try { const c = sessionStorage.getItem("releases"); if (c) return JSON.parse(c); } catch {}
    try {
      const r = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=100`);
      if (!r.ok) return [];
      const list = await r.json();
      try { sessionStorage.setItem("releases", JSON.stringify(list)); } catch {}
      return list;
    } catch { return []; }
  })();
}

function latestFor(prefix, releases) {
  const mine = releases.filter(r => r.tag_name.startsWith(prefix + "-v") && !r.draft);
  if (!mine.length) return null;
  const r = mine.reduce((a, b) => (a.published_at > b.published_at ? a : b));
  const zip = r.assets.find(a => a.name.endsWith(".zip"));
  return { tag: r.tag_name, version: r.tag_name.slice(prefix.length + 2),
           zipUrl: zip ? zip.browser_download_url : r.html_url, pageUrl: r.html_url };
}

const stripH1 = md => md.replace(/^# .*\r?\n/, "");
const el = (tag, attrs = {}, html = "") => Object.assign(document.createElement(tag), attrs, { innerHTML: html });

async function renderAddon(addon, panel) {
  const [toc, readme, log, releases] = await Promise.all([
    getText(`${addon.dir}/${addon.dir}.toc`).then(parseToc),
    getText(`${addon.dir}/README.md`),
    getText(`${addon.dir}/CHANGELOG.md`),
    fetchReleases(),
  ]);
  const rel = latestFor(addon.prefix, releases);
  panel.append(el("div", { className: "card" }, `
    <h2>${toc.Title || addon.dir}</h2>
    <p>${toc.Notes || ""}</p>
    <p class="meta">Version ${toc.Version || "?"} · Interface ${toc.Interface || "?"}</p>
    <a class="dl" href="${rel.zipUrl}">Download v${rel.version}</a>
    <a href="${rel.pageUrl}">Release notes</a> · <a href="${GH}/tree/main/${addon.dir}">Source</a>`));
  panel.append(el("div", { className: "md" }, marked.parse(stripH1(readme))));
  panel.append(el("div", { className: "md log", id: `${addon.dir}-changelog` },
    "<h2>Changelog</h2>" + marked.parse(stripH1(log).replace(/^All notable changes.*\r?\n/m, ""))));
}

// Phase 1: one tab, rendered immediately
const tabs = document.getElementById("tabs"), panels = document.getElementById("panels");
for (const a of ADDONS) {
  tabs.append(el("button", { role: "tab", id: `tab-${a.dir}`, ariaSelected: "true" }, a.dir));
  const p = el("section", { role: "tabpanel", id: a.dir });
  panels.append(p);
  renderAddon(a, p);
}
```

Notes:
- `marked` 12 defaults to GFM (tables and fenced code). The READMEs and `.toc` are our own content, so `innerHTML` without a sanitizer is acceptable (design decision).
- Phase 1 assumes `rel` is non-null (PP has releases). Phase 2 adds the fallback.

### Verification
#### Automated
- [x] `test -f docs/.nojekyll && test -f docs/index.html`
- [x] `grep -c "cdnjs.cloudflare.com/ajax/libs/marked/12.0.2" docs/index.html` prints `1`
- [x] `curl -sI https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.2/marked.min.js | head -1` shows `200`

#### Manual
- [x] Serve with `python -m http.server -d docs 8000` (background) and open `http://localhost:8000/` in the browser pane
- [x] The intro and the install guide render, and the install steps show `_forever_\Interface\AddOns\`
- [x] The PP card shows "Profession Planner", "Version 0.2.1 · Interface 16001", and `Download v0.2.1`
- [x] The Download href is `https://github.com/madacgrav/wow-addons/releases/download/pp-v0.2.1/ProfessionPlanner-0.2.1.zip` (check with `find`/`read_page`)
- [x] README tables render as tables, and the changelog's first entry is `[0.2.1] — 2026-10-20`
- [x] `read_console_messages` with `onlyErrors` returns no errors

---

## Phase 2: All five tabs, deep links, link rewrite, fallbacks

### Changes

#### 1. Full addon list
**File**: `docs/index.html`
**Action**: modify `ADDONS`

```js
const ADDONS = [ // new addon? add one line: folder name + release tag prefix
  { dir: "ProfessionPlanner", prefix: "pp" },
  { dir: "TackleBox", prefix: "tb" },
  { dir: "WarlockCombatKit", prefix: "wck" },
  { dir: "WarlockUtilityKit", prefix: "wuk" },
  { dir: "BusinessCard", prefix: "bcard" },
];
```

Tab button label: `toc.Title` is unknown until fetched, so use a display name derived from `dir`: `dir.replace(/([a-z])([A-Z])/g, "$1 $2")` gives "Warlock Combat Kit", which also yields "Business Card". Acceptable.

#### 2. Download fallback + per-part error
**File**: `docs/index.html`
**Action**: modify `renderAddon`

```js
const dl = rel
  ? `<a class="dl" href="${rel.zipUrl}">Download v${rel.version}</a> <a href="${rel.pageUrl}">Release notes</a> ·`
  : `<a class="dl" href="${GH}/releases?q=${addon.prefix}-v">Releases</a>`;
```

Fetch each part with its own catch, so one failure does not blank the tab:

```js
const fail = path => `<p class="err">Couldn't load this part. <a href="${GH}/blob/main/${path}">View on GitHub</a>.</p>`;
const safe = (path, fn) => getText(path).then(fn, () => null);
// toc → {} on failure; readme/log → null, then render fail(path)
```

#### 3. Link rewrite
**File**: `docs/index.html`
**Action**: add, called on the README and changelog containers after render

```js
function fixLinks(root, dir) {
  const base = `${GH}/blob/main/${dir}/`;
  for (const a of root.querySelectorAll("a[href]")) {
    const h = a.getAttribute("href");
    if (/^(https?:|mailto:|#)/.test(h)) continue;
    if (/^CHANGELOG\.md$/i.test(h)) { a.href = `#${dir}-changelog`; continue; }
    const sib = h.match(/^\.\.\/(\w+)\/?$/);
    if (sib && ADDONS.some(x => x.dir === sib[1])) { a.href = `#${sib[1]}`; continue; }
    a.href = new URL(h, base).href; // resolves ../ against the blob path
  }
}
```

Changelog anchor clicks (`#Dir-changelog`) must not be treated as tab hashes. In `onHash`, if the hash ends with `-changelog`, select the tab named by the prefix, then `scrollIntoView` the anchor.

#### 4. Tabs: lazy render, hash deep links, keyboard
**File**: `docs/index.html`
**Action**: replace the Phase 1 loop

```js
const rendered = new Set();
function selectTab(dir, focus) {
  for (const a of ADDONS) {
    const on = a.dir === dir;
    const t = document.getElementById(`tab-${a.dir}`);
    t.setAttribute("aria-selected", on); t.tabIndex = on ? 0 : -1;
    document.getElementById(a.dir).hidden = !on;
    if (on && focus) t.focus();
  }
  if (!rendered.has(dir)) { rendered.add(dir); renderAddon(ADDONS.find(a => a.dir === dir), document.getElementById(dir)); }
}
for (const a of ADDONS) {
  const t = el("button", { role: "tab", id: `tab-${a.dir}` }, a.dir.replace(/([a-z])([A-Z])/g, "$1 $2"));
  t.setAttribute("aria-controls", a.dir);
  t.onclick = () => { history.replaceState(null, "", `#${a.dir}`); selectTab(a.dir); };
  tabs.append(t);
  const p = el("section", { role: "tabpanel", id: a.dir, hidden: true });
  p.setAttribute("aria-labelledby", `tab-${a.dir}`);
  panels.append(p);
}
tabs.addEventListener("keydown", e => {
  const i = ADDONS.findIndex(a => document.getElementById(`tab-${a.dir}`) === document.activeElement);
  if (i < 0 || !["ArrowLeft", "ArrowRight"].includes(e.key)) return;
  const n = ADDONS[(i + (e.key === "ArrowRight" ? 1 : ADDONS.length - 1)) % ADDONS.length];
  history.replaceState(null, "", `#${n.dir}`); selectTab(n.dir, true);
});
function onHash() {
  const h = decodeURIComponent(location.hash.slice(1));
  const dir = h.replace(/-changelog$/, "");
  const known = ADDONS.some(a => a.dir === dir);
  selectTab(known ? dir : ADDONS[0].dir);
  if (known && h !== dir) {
    const wait = () => { const t = document.getElementById(h); t ? t.scrollIntoView() : setTimeout(wait, 100); };
    wait();
  }
  if (known) document.getElementById("addons").scrollIntoView();
}
addEventListener("hashchange", onHash);
onHash();
```

When the page loads with no hash, it must not scroll to `#addons`. Only call `scrollIntoView` when `location.hash` is non-empty.

### Verification
#### Automated
- [x] `grep -c 'prefix: "' docs/index.html` prints `5`
- [x] `gh release list --limit 50 --json tagName,publishedAt` shows the newest per prefix as pp-v0.2.1, tb-v1.0.0, wck-v0.2.0, wuk-v0.5.0, bcard-v0.8.5

#### Manual (browser pane, local server)
- [ ] Each of the five tabs shows its card with the versions above, and Download hrefs use the `releases/download/<tag>/<Dir>-<ver>.zip` pattern
- [ ] Load `http://localhost:8000/#WarlockUtilityKit`: the WUK tab is selected
- [ ] In the WCK README, the "Warlock Utility Kit" link switches to the WUK tab; "CHANGELOG.md" links scroll to that tab's changelog
- [ ] Arrow keys move between tabs when one is focused
- [ ] Fallback: run `sessionStorage.clear(); window.fetch = (f => (u, ...a) => String(u).includes("api.github.com") ? Promise.reject() : f(u, ...a))(fetch); releasesPromise = undefined;` via `javascript_tool`, then open an unopened tab. It shows the `Releases` button and the README still renders.
- [ ] `resize_window` mobile (375×812): `document.documentElement.scrollWidth <= innerWidth` is `true` via `javascript_tool`. Then reset to `desktop`.
- [ ] No console errors

---

## Phase 3: Align repo docs

### Changes

#### 1. Install path in the four READMEs
**Files / lines**: `ProfessionPlanner/README.md:12`, `TackleBox/README.md:11`, `WarlockCombatKit/README.md:10`, `WarlockUtilityKit/README.md:12`
**Action**: modify. Replace `` `_classic_beta_\Interface\AddOns\` `` with `` `_forever_\Interface\AddOns\` `` (one occurrence each).

#### 2. Development line in the four READMEs
**Files / lines**: after the CI line in each Development section (PP:115, TB:77, WCK:129, WUK:166)
**Action**: modify. Add on its own line (PP uses a bullet list there, so prefix it with `- ` in PP only):

```markdown
The [addon site](https://madacgrav.github.io/wow-addons/) reads this README and CHANGELOG live from `main`. A brand-new addon also needs a line in `ADDONS` in `docs/index.html`.
```

#### 3. BusinessCard README
**File**: `BusinessCard/README.md`
**Action**: modify. Insert after the intro paragraph (before `## Features`):

```markdown
## Install

1. Download `BusinessCard-X.Y.Z.zip` from the repo's GitHub releases (tag `bcard-vX.Y.Z`).
2. Extract it so that the folder `BusinessCard` sits in `_forever_\Interface\AddOns\`.
3. Restart the game. A `/reload` is not enough on first install, because key bindings load at startup.
```

Append at end of file:

````markdown
## Development

Pure logic lives in `Logic.lua` and is tested with plain Lua 5.1:

```bash
lua5.1 BusinessCard/tests/run.lua
```

CI runs the tests and publishes a release zip on every push to `main` that touches the addon. Bump `## Version` in the `.toc` to cut a new release. See [CHANGELOG.md](CHANGELOG.md).

The [addon site](https://madacgrav.github.io/wow-addons/) reads this README and CHANGELOG live from `main`. A brand-new addon also needs a line in `ADDONS` in `docs/index.html`.
````

#### 4. BusinessCard CHANGELOG
**File**: `BusinessCard/CHANGELOG.md`
**Action**: modify
- Line 1 `# Changelog` → `# Changelog — BusinessCard`, then a blank line and:
  `All notable changes to this addon. Versions match `## Version` in `BusinessCard.toc`; each version is published as a `bcard-vX.Y.Z` GitHub release.`
- Every heading `## X.Y.Z` → `## [X.Y.Z] — 2026-11-16` (20 headings, 0.1.0–0.8.5; all were committed 2026-11-16). Use: `sed -i -E 's/^## ([0-9]+\.[0-9]+\.[0-9]+)\s*$/## [\1] — 2026-11-16/' BusinessCard/CHANGELOG.md`, then fix the title with Edit. Keep the file's existing line endings (check with `file BusinessCard/CHANGELOG.md` first; if CRLF, run the sed with `\r?` before `$`).
- Entry bullets stay unchanged.

#### 5. Root README
**File**: `README.md`
**Action**: modify. Full new content:

```markdown
# wow-addons

Addons for WoW Forever. Each folder is one addon with its own README, changelog and GitHub release tag.

**Site:** https://madacgrav.github.io/wow-addons/ has the install guide, commands, changelogs and a download link for every addon.

- [ProfessionPlanner](ProfessionPlanner/) — leveling planner docked next to the profession window (`pp-v` releases).
- [WarlockUtilityKit](WarlockUtilityKit/) — shards, stones, summons and healthstone trades for warlocks (`wuk-v` releases).
- [WarlockCombatKit](WarlockCombatKit/) — in-combat cast map, rotation helper, proc alerts and mouseover casting for warlocks (`wck-v` releases).
- [TackleBox](TackleBox/) — fishing companion: where to fish, quest fish, catch log, camp buffs and a click-to-use fishing bar (`tb-v` releases).
- [BusinessCard](BusinessCard/) — remembers who advertised professions, summons and portals, and swaps cards and status with other users (`bcard-v` releases).

## Install

Download an addon's zip from its latest release, then extract it so the addon folder sits in `World of Warcraft\_forever_\Interface\AddOns\`. Restart the game. Full steps are on the site.
```

### Verification
#### Automated
- [ ] `grep -rn "_classic_beta_" README.md */README.md` prints nothing
- [ ] `grep -c "^## \[[0-9.]*\] — 2026-11-16$" BusinessCard/CHANGELOG.md` prints `20` (strip `\r` first if CRLF: `tr -d '\r' < BusinessCard/CHANGELOG.md | grep -c ...`)
- [ ] `grep -c "^## " BusinessCard/CHANGELOG.md` still prints `20`
- [ ] `grep -n "^## Install\|^## Development" BusinessCard/README.md` shows both
- [ ] `grep -c "docs/index.html" */README.md | grep -c ":1"` prints `5`
- [ ] `grep -n "BusinessCard\|madacgrav.github.io" README.md` matches both
- [ ] `git diff --stat` touches only the 7 docs files plus `docs/`, no `.lua`/`.toc`/`.yml`

#### Manual
- [ ] Optional: temporarily point `RAW` at `http://localhost:8000/../` by serving the repo root (`python -m http.server -d . 8001`) and setting `RAW = "http://localhost:8001/"` in devtools only, to preview the BusinessCard tab with the new changelog and Install section. Do not commit the change.

---

## Phase 4: Publish and keep current

### Changes

#### 1. Commit and PR
- `git switch -c 2026-11-17-addon-docs-site`
- Stage explicitly: `docs/`, `README.md`, the 5 addon `README.md` files, `BusinessCard/CHANGELOG.md`, `thoughts/qrspi/2026-11-17-addon-docs-site/`
- Commit `Add GitHub Pages addon site; align install docs on _forever_` with the Co-Authored-By trailer
- `git push -u origin 2026-11-17-addon-docs-site`, then `gh pr create`. The body summarizes the site, the doc alignment, and the post-merge Pages enable, ending with the Claude Code line.
- Merge only after the user approves.
- After merge: `git switch main && git pull --ff-only`

#### 2. Enable Pages (needs user approval)
```bash
gh api -X POST repos/madacgrav/wow-addons/pages -f "source[branch]=main" -f "source[path]=/docs"
```
If it returns 409 (already exists), use `gh api -X PUT repos/madacgrav/wow-addons/pages -f "source[branch]=main" -f "source[path]=/docs"`. If it returns 403/404 (token scope), ask the user to set Settings → Pages → Deploy from branch → `main` / `/docs`.

#### 3. Homepage (needs user approval)
```bash
gh repo edit madacgrav/wow-addons --homepage https://madacgrav.github.io/wow-addons/
```

#### 4. Memory note
**File**: `C:\Users\madac\.claude\projects\D--Source-wow-addons\memory\docs-site-addon-list.md` plus a line in `MEMORY.md`

```markdown
---
name: docs-site-addon-list
description: New addon must be added to ADDONS in docs/index.html (Pages site) and root README
metadata:
  type: project
---
The Pages site (https://madacgrav.github.io/wow-addons/, docs/index.html) renders each addon's .toc, README, CHANGELOG and newest `<prefix>-v*` release live from main.
**Why:** user wants the site current on every addon create/update; live fetch makes updates automatic.
**How to apply:** updating an existing addon needs no site change. Keep README/CHANGELOG accurate. A NEW addon needs `{ dir, prefix }` added to ADDONS in docs/index.html, a root README bullet, and its package-<prefix>.yml.
```

### Verification
#### Automated
- [ ] `gh pr view --json state -q .state` prints `MERGED`
- [ ] `gh api repos/madacgrav/wow-addons/pages -q .status` prints `built` (retry for a minute or two after enabling; use Monitor rather than sleep)
- [ ] `curl -s -o /dev/null -w "%{http_code}" https://madacgrav.github.io/wow-addons/` prints `200`
- [ ] `gh repo view --json homepageUrl -q .homepageUrl` prints the site URL
- [ ] `gh release list --limit 5` shows no release newer than `wck-v0.2.0`, so the merge made no new tags

#### Manual
- [ ] Open the live URL in the browser pane: all five tabs work and the Download links match the Phase 2 list
- [ ] The BusinessCard tab shows the Install section and the `[0.8.5] — 2026-11-16` changelog heading
- [ ] The memory file exists and `MEMORY.md` has its pointer line
