# Credia Guardians — Game Design Document (GDD)

**Version:** 1.0 · **Date:** 2026-07-07 · **Engine:** Godot 4.x · **Target:** Windows PC, 60 FPS

---

## 1. High Concept

A retro 16-bit side-scrolling action platformer. Two full-stack developers — **Chris** and **Flam** — built the secure Credia banking system. Corrupted bankers have invaded its digital infrastructure. Run, jump, dash, and code-fu your way through 5 stages, collect every Credia Coin, activate security nodes, and defeat the CEO to declare **BANK SYSTEM SECURED!**

**Pillars:**
1. **Tight, readable arcade action** — Mega Man X movement precision, Metal Slug personality.
2. **Everything glows** — dark cyber-bank world lit by neon green (secure/good) and electric blue (tech), with red reserved for corruption.
3. **Mastery loops** — stages are clearable by anyone, S-rankable only by experts (all coins, all nodes, fast, deathless).

**Tone:** Heroic but funny. Bankers are comedic villains — KO'd with dizzy stars, propaganda monitors ("WE OWN YOUR FUTURE") flip to "FINANCIAL FREEDOM ACTIVE" when you clear a zone.

---

## 2. Story

> CrediaBank runs on a fortress of code built by two developers. One night, the **CEO** — corrupted by greed — uploads his consciousness and his loyal bankers into the system itself. Interest rates spike. Accounts freeze. Coins scatter through the infrastructure as raw data.
>
> Chris and Flam jack in. Five layers of the system stand between them and the Core. Secure every node. Recover every coin. Delete the corruption at its source.

**Intro:** 4-panel pixel cutscene (static images + text crawl) after character select.
**Ending:** Victory screen matching the key art — heroes posed before the secured vault, defeated bankers scattered, monitors flipped to positive messages.

---

## 3. Playable Characters

Both share the full core moveset (run, jump, double jump, dash, melee). They differ in stats and one **signature ability**.

| Stat | Chris — "Credia Warrior" | Flam — "Credia Guardian" |
|---|---|---|
| Max HP | **6** | 4 |
| Run speed | 95 px/s | **115 px/s** |
| Jump velocity | −290 px/s | −290 px/s |
| Double jump | −260 px/s | −260 px/s |
| Dash | 240 px/s, 0.12 s, ground+air (1 air charge), 0.6 s cooldown | **300 px/s, 0.16 s, i-frames during dash, 2 air charges, 0.4 s cooldown** |
| Melee | 1 dmg, slightly larger arc | 1 dmg, standard arc |
| Signature | **Firewall Shield** (hold): blocks frontal damage & projectiles; drains shield meter (3 s capacity, regens after 1.5 s idle); walk-only while active | **Overclock Dash**: dash specs above; dashing through enemies deals 1 contact dmg |

Design intent: Chris is the forgiving pick (more HP, panic button); Flam is the speedrun pick (faster, i-frame dash, but 2 fewer hits).

---

## 4. Core Mechanics & Tuning

All values live in `CharacterStats.tres` resources — tunable without code changes.

### Movement
| Parameter | Value | Notes |
|---|---|---|
| Gravity (rising) | 900 px/s² | |
| Gravity (falling) | 1150 px/s² | Snappier descents, retro feel |
| Max fall speed | 320 px/s | |
| Ground accel / friction | 900 / 1100 px/s² | ~0.1 s to full speed |
| Air control | 75 % of ground accel | |
| Coyote time | 0.10 s | Jump grace after leaving ledge |
| Jump buffer | 0.12 s | Early-press grace before landing |
| Variable jump | Jump button up at any point during ascent → cut velocity ×0.45 (once) | Short hops; also applies to buffered jumps whose press was released pre-landing |

### Combat
- **Melee attack**: 3-hit ground combo (chain window 0.35 s), single air slash. Hitbox active frames 2–5 of each swing. Hitstop 0.05 s on connect.
- **Damage**: melee = 1; most enemies die in 2–5 hits (see §6). Player contact damage taken = 1 (2 from bosses/hazard spikes).
- **Hurt**: 0.15 s knockback + stun, then **1.0 s invulnerability** (sprite flicker).
- **Stomp**: landing on a standard enemy's head deals 1 dmg + bounce (−240 px/s). Not valid on Auditors (spiked ledger) or bosses.

### World interactions
- **Moving platforms**: Path2D followers; player inherits platform velocity. One-way platforms drop-through with Down+Jump.
- **Checkpoints**: terminal props — flash green "COMMIT SAVED ✓" when touched; respawn there with full HP on death.
- **Security nodes**: per-stage objectives (3–5 per stage). Activating one (interact key, 0.5 s hold) clears local corruption (background tint shifts red→blue), opens the gate to the next section, +500 pts.
- **Hidden rooms**: fake walls / vents. Contain coin caches, a power-up, or a HP upgrade. 1–3 per stage. Subtle tells: cracked tiles, coin trails, off-pattern décor.
- **Lives & death**: 3 lives per stage attempt; death → checkpoint; 0 lives → Game Over screen → retry stage (progress in save is kept).

---

## 5. Stages

Each stage: ~5–8 min first clear · 3–5 security nodes · 1–3 hidden rooms · 100 Credia Coins · mid-stage checkpoint(s) · end gauntlet or mid-boss → stage-clear tally.

| # | Stage | Theme & palette accent | Gimmicks | New enemies | Climax |
|---|---|---|---|---|---|
| 1 | **Developer Office** | Cubicles, monitors, whiteboards; warm dark blues | Conveyor desks, coffee-steam updrafts (boost jumps), stacks-of-paper crumbling platforms | Junior Banker, Angry Manager | Angry Manager ×2 arena gauntlet |
| 2 | **Data Center** | Server racks, digital rain, cable trays; cyan | Heat vents (rising hazard columns on timers), platforms riding cable rails, cooling fans that push/pull | Auditor | **Mid-boss: Corrupted AI Banker (v1)** — teleport + 3-shot spread |
| 3 | **Corporate Headquarters** | Marble lobby, elevators, glass offices; gold accents | Elevators (call buttons), cracking glass floors, paper-shredder pits, security cameras that spawn Junior Bankers until smashed | Loan Shark | **Mid-boss: Regional Manager** — Angry Manager elite with desk-throw |
| 4 | **Digital Vault** | Rotating vault doors, laser grids, gold-on-black | Timed lock sequences (hit switches in order before reset), laser grids on rhythm, coin-block bridges that fade | Corrupted AI Banker (regular spawns) | Vault-heart gauntlet: survive 3 waves while nodes charge |
| 5 | **Core Banking System** | Abstract cyberspace, red corruption veins over blue circuitry | Corruption zones (inverted gravity wells pull down harder), firewall gates (need stage's USB Security Key), one auto-scroll escape segment | All (elite recolors) | **CEO Boss** — 3 phases (§7) |

**Difficulty curve:** S1 teaches (no death pits until midpoint, generous checkpoints); S2 adds timing; S3 adds resource pressure (camera spawners); S4 demands execution (lasers + sequences); S5 is the exam.

---

## 6. Enemies

Melee dmg = 1 per hit. "Contact" = damage touching the enemy deals to the player.

| Enemy | HP | Contact | Score | Behavior (full FSM in ENEMY_AI.md) |
|---|---|---|---|---|
| **Junior Banker** | 2 | 1 | 200 | Patrols ledges with briefcase; turns at edges/walls. Panics (runs away, drops 3 coins) when last hit. Stompable. |
| **Angry Manager** | 4 | 1 | 400 | Idles until player in line-of-sight → red "!!" telegraph 0.4 s → charge (180 px/s). Hits wall → stunned 1.2 s (punish window). |
| **Auditor** | 3 | 1 | 300 | Keeps 100–140 px distance, hops back if approached. Throws ledger projectiles (arc, 2 s cadence). Spiked ledger hat — no stomp. |
| **Loan Shark** | 5 | 2 | 500 | Lurks inside props (plants, cabinets, vault slots) — dorsal fin visible tell. Lunges when player within 60 px. Brief recovery after lunge. |
| **Corrupted AI Banker** | 8 | 2 | 1000 | Teleports between 3 anchor points, fires 3-projectile spread, summons 1 Junior Banker at half HP. Vulnerable 1.5 s after each volley. |
| **CEO Boss** | 30/25/20 | 2 | 10000 | Three-phase finale (§7). |

Elite recolors in S5: +2 HP, +20 % speed, red-tinted.

---

## 7. CEO Boss — "The Chairman"

Arena: the Core — circular chamber, vault door backdrop (key art), 3 floating platforms.

| Phase | HP | Pattern |
|---|---|---|
| **1 — Executive Suit** (giant suited sprite, 64×96) | 30 | Briefcase slam (shockwave along ground — jump), coin-toss volley (gold projectiles in arc), desk-charge across arena. Weak point: head, after slam leaves him bent over. |
| **2 — Hostile Takeover** (jacket off, red tie glowing) | 25 | Adds: summons 2 Junior Bankers per cycle, "MARKET CRASH" — red candlestick pillars fall from ceiling (shadows telegraph), faster charges. |
| **3 — Full Corruption** (digital demon form, red/black, 96×96) | 20 | Screen-edge laser sweeps (dash through with i-frames or shield), teleport slam, bullet-hell coin spiral. Between patterns, exposes glowing core 2 s. |

Defeat → corruption dissolve FX → coins rain → Victory screen.

---

## 8. Collectibles & Power-ups

| Item | Effect | Placement |
|---|---|---|
| **Credia Coin** | +100 pts. 100 per stage; collecting all 100 → "FULL AUDIT" bonus 5000 pts (required for S rank). Blue/green yin-yang coin (bank logo). | Trails teach routes; clusters reward risk. |
| **Coffee** | Restore 1 HP. | Common, after fights. |
| **Energy Drink** | Restore all HP + 10 s speed boost (+15 %). | Rare, 1–2 per stage. |
| **Firewall Shield** | One-hit shield bubble (any character). Lost on hit. | Hidden rooms, pre-boss. |
| **Keyboard Upgrade** | Melee +1 dmg for the rest of the stage (lost on death). Mechanical-keyboard pickup, "CLACK!" SFX. | 1 per stage, guarded. |
| **USB Security Key** | Stage key item — opens the firewall gate blocking a required or secret path. | 1 per stage; in S5, three are required. |

---

## 9. Scoring & Rank

**Score sources:** coins (100), enemies (table §6), nodes (500), hidden room found (1000), no-damage checkpoint-to-checkpoint streaks (500).

**Stage-clear tally** (matches key art): `EXP GAINED` (enemy score) + `CREDITS EARNED` (coin score) + `LEVEL BONUS` (par-time bonus: max 10000, −100/s over par) + FULL AUDIT bonus → total → rank.

| Rank | Requirement |
|---|---|
| **S — PERFECT!** | 100 % coins + all nodes + under par time + no deaths |
| A | ≥ 90 % coins + all nodes + ≤ 1 death |
| B | ≥ 70 % coins + all nodes |
| C | Stage cleared |
| D | Cleared with 0 lives remaining at any point |

Hi-score per stage persisted in save. Ranks shown on stage-select.

---

## 10. Game Flow

```
Splash (logos) → Main Menu → [New Game | Continue | Options | Quit]
  New Game → Slot select → Character Select (Chris/Flam) → Intro cutscene → Stage 1
  Continue → Slot select → Stage Select (unlocked stages, best ranks shown)
In-stage: Pause (Resume | Restart Stage | Options | Quit to Menu)
Stage clear → Tally → next stage unlock → Stage Select
Stage 5 clear → Victory screen → Credits → Main Menu
0 lives → Game Over → [Retry Stage | Quit to Menu]
```

Character can be re-chosen per stage from Stage Select (supports experimenting; save records who cleared what).

---

## 11. Presentation

- **Resolution:** 480×270 native, integer-scaled (×4 = 1080p). Optional scanline overlay (Options toggle).
- **Palette** (from key art): bg `#050A12`, panel `#0A1422`, neon green `#39FF5A`, dark green `#1FA83C`, cyan `#16E0E0`, blue `#26A8FF`, deep blue `#1148B8`, gold `#FFC825`, red `#FF3040`, white `#E8F4FF`, gray `#7A8CA0`.
- **HUD:** top-left portrait + segmented green HP bar + score + coin ×N; top-center HI-SCORE. Chunky pixel font.
- **Feel:** hitstop 0.05 s, screen shake (2–4 px) on heavy hits, dash afterimages, coin glint particles, confetti on clear.
- **Audio:** driving chiptune per stage; boss theme; jingle stingers (checkpoint, node, clear). Full list in AUDIO_LIST.md.

---

## 12. Out of Scope (v1.0)

Local co-op (architecture keeps it possible — input device abstraction, no player singletons), leaderboards, achievements, localization (strings centralized for later), mobile/console ports.
