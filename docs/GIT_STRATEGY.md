# Git Branching Strategy

## Model: trunk-based with milestone feature branches

```
main ──●───────●────────●────────●──→   (always playable, tagged per milestone)
        \     / \      / \      /
         m0──●   m1───●   m2───●        feature/m0-bootstrap, feature/m1-player, ...
```

- **`main`**: protected by discipline — only merge commits from finished milestones land here. Every commit on `main` opens in Godot without errors and passes the GUT suite. Tagged `v0.1.0` … `v1.0.0` per MILESTONES.md.
- **`feature/mN-name`**: one per milestone, branched from latest `main`. Small commits within.
- **`fix/short-desc`**: hotfix branches off `main` for bugs found after a milestone merged; merge back to `main` AND into the active feature branch.
- No `develop` branch — solo/duo team, milestones are short, trunk-based is less ceremony.

## Commits — Conventional Commits

`type(scope): summary` — types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `art`, `audio`, `tune` (pure .tres value changes).
Scopes: `player`, `enemy`, `boss`, `level`, `ui`, `save`, `audio`, `fx`, `core` (autoloads/fsm/components), `tools`.

Examples: `feat(player): add coyote time and jump buffering` · `tune(enemy): slow auditor cadence 2.0→2.4s` · `art(tiles): vault tileset v2`.

## `.gitignore` (Godot 4)

```gitignore
.godot/            # editor cache — NEVER commit
*.tmp
export_presets.cfg # contains local paths/keys; commit export_presets.example.cfg instead
build/
.idea/
*.blend1
```

`.import` files no longer exist in Godot 4 (metadata lives in `.godot/`); **all `assets/**` binaries ARE committed** (small pixel art + ogg — fine without LFS; revisit if repo > 500 MB).

## Merge & tag ritual (end of each milestone)

```powershell
git checkout main
git merge --no-ff feature/m1-player -m "feat: M1 player core (v0.2.0)"
git tag -a v0.2.0 -m "M1: player core playable build"
git branch -d feature/m1-player
```

`--no-ff` keeps milestone boundaries visible in history.

## Scene/resource merge safety (the Godot-specific rules)

- `.tscn`/`.tres` are text but merge badly. Rule: **one person/branch touches a given scene at a time**; milestones are sequenced so this holds automatically.
- Keep scenes small (component scenes) — smaller diff surface.
- Never re-save unrelated scenes (Godot re-serializes ids); commit only intentionally-changed files (`git add -p` habit).
- Binary conflict fallback: take theirs, redo local change in-editor.
