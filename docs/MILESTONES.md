# Milestone Plan

Rules: every milestone merges to `main` only when its **acceptance criteria** pass and the build is playable. One feature branch per milestone (`feature/mN-name`). Tag on merge. No milestone starts until the previous is tagged.

---

## M0 — Bootstrap `feature/m0-bootstrap` → tag `v0.1.0`
Install Godot 4.x (winget) · `git init` + `.gitignore` + first commit of docs · `project.godot` fully configured (viewport 480×270, stretch/integer/nearest/snap, physics 60 Hz, input map, physics layer names, audio buses) · folder skeleton · GUT addon installed · `tools/artgen/generate_placeholders.py` producing all placeholder sheets · `main.tscn` + `SceneManager` fade + an empty test room with tiles.

**Accept:** project opens clean (zero errors/warnings in Output), test room renders pixel-perfect at ×1/×3/×4 window scales, 60 FPS, artgen re-runnable & deterministic, GUT smoke test passes headless.

## M1 — Player core `feature/m1-player` → tag `v0.2.0`
`StateMachine`/`State` · player.tscn with all M1 states (Idle/Run/Jump/DoubleJump/Fall/Dash) · gravity pair, coyote, jump buffer, variable jump · `CharacterStats` + `chris.tres`/`flam.tres` (dash differences live) · pixel camera (limits, lookahead, snap) · full input map incl. gamepad · debug overlay (F3) · movement debug room with ledges/gaps/slopes-free geometry.

**Accept:** all FSM transitions per PLAYER_FSM.md verified in debug room with both characters; GUT: state transition table, buffer/coyote timing (simulated frames); no jitter at any window scale; gamepad hot-plug works.

## M2 — Combat & entities `feature/m2-combat` → tag `v0.3.0`
Attack/AirAttack/Hurt/Dead states + 3-hit combo · Health/Hurtbox/Hitbox/Knockback/Flash/Loot components · hitstop + screenshake helper · `EnemyBase` + Junior Banker + Angry Manager (full FSMs) · stomp · coins + coffee · checkpoints + death/respawn + lives · moving platforms (Path2D + one-way, velocity inheritance) · crumbling platforms · hazard tiles · combat debug room.

**Accept:** kill/get-killed loops correct incl. i-frames, shield-arc negation (Chris), stomp bounce; enemies sleep off-screen; platform riding has zero slip; GUT: damage pipeline, combo window, enemy state tables.

## M3 — Game shell `feature/m3-shell` → tag `v0.4.0`
All UI screens (splash, main menu, slot select, character select, stage select, options, pause, game over) · HUD wired to EventBus · `GameManager` run state + score · `SaveManager` (atomic writes, migrations, settings) · options: volumes, fullscreen, window scale, scanlines, rebinding · full keyboard/gamepad menu navigation.

**Accept:** complete loop Splash→…→debug level→death→Game Over→menu without a single direct scene reference violation; save slots survive process kill (verified); rebind persists; GUT: SaveManager round-trip + migration + corrupt-file handling.

## M4 — Stage 1 + clear screen `feature/m4-stage1` → tag `v0.5.0`
Developer Office: full TileSet (terrain autotiles, decor, hazards), parallax, 100 coins, 3 nodes, 2 hidden rooms, conveyor desks, coffee-steam updrafts, paper platforms, enemy placement, Angry Manager ×2 gauntlet, exit gate · stage-clear tally screen (EXP/CREDITS/LEVEL BONUS count-up, rank medal, confetti) · rank computation · stage select shows real data.

**Accept:** S1 clearable start→finish by both characters; S rank achievable (dev playtest proof); par time tuned; all 100 coins reachable; save records rank/hi-score; 60 FPS worst case.

## M5 — Roster & systems `feature/m5-roster` → tag `v0.6.0`
Auditor, Loan Shark, Corrupted AI Banker (+projectiles) · power-ups: Firewall Shield, Keyboard Upgrade, Energy Drink, USB Key + firewall gate · security camera spawner prop · `ObjectPool` for projectiles/FX · particle pass: hit sparks, coin glints, dash ghosts, dust, confetti, dizzy stars, score popups · monitors prop (propaganda→positive flip on node activation).

**Accept:** every enemy vs. both characters in combat room matches ENEMY_AI.md; zero per-frame allocations in profiler during combat; pools never leak (enter/exit stage ×10).

## M6 — Stages 2–4 + audio `feature/m6-stages` → tag `v0.7.0`
Data Center (heat vents, rail platforms, fans, AI Banker mid-boss) · Corporate HQ (elevators, glass floors, shredders, cameras, Regional Manager) · Digital Vault (lock sequences, laser grids, fading coin bridges, wave gauntlet) · boss_base + PhaseManager + arena lock + boss HP bar · full music/SFX sourcing + AudioManager crossfade/ducking.

**Accept:** stages 1–4 each clearable and S-rankable; mid-bosses match diagrams; every action has an SFX; music loops seamlessly; progression/unlock chain saves correctly.

## M7 — Finale `feature/m7-finale` → tag `v0.8.0`
Core Banking System stage (corruption zones, firewall gates ×3 USB keys, auto-scroll segment, elite recolors) · CEO 3-phase boss per ENEMY_AI.md · intro cutscene (4 panels) · victory screen (key-art recreation: heroes posed, KO'd bankers, monitors flipped, confetti) · credits · global hi-score.

**Accept:** full game completable both characters; boss has zero unreactable patterns (blind-playtest rule: every death explainable); victory/credits/save finalization correct.

## M8 — Ship `feature/m8-polish` → tag `v1.0.0`
Rank threshold tuning across all stages · game feel pass (shake/hitstop budgets, transition timing) · full GUT suite green in CI-style headless run · PERFORMANCE.md checklist executed + profiler evidence · export presets (Windows x86_64, embedded PCK) · itch-ready zip · README with controls.

**Accept:** 60 FPS everywhere on integrated GPU; zero known crash/softlock; fresh-machine run from exported build; all 17 docs updated to as-built.

---

### Post-1.0 backlog (not scheduled)
Local co-op, boss rush mode, speedrun timer + leaderboard, localization (EL/EN), gamepad rumble, Steam build.
