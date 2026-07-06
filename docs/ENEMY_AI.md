# Enemy AI — State Diagrams

All enemies run the shared `StateMachine`. Off-screen enemies sleep (`VisibleOnScreenEnabler2D`). Every enemy has implicit transitions: `(hurt received) → Hurt` (0.2 s flash + knockback, then back to previous state) and `(hp == 0) → Death` (play death, spawn loot via LootComponent, emit `enemy_killed`, free). Diagrams show behavior states only.

## Junior Banker — nervous patroller

```mermaid
stateDiagram-v2
    [*] --> Patrol
    Patrol : walk at 40 px/s, flip at wall/ledge (EdgeDetector)
    Panic : flee away from player at 80 px/s, drop 1 coin/s (max 3), ignore ledges (can fall)
    Patrol --> Panic : hp == 1
    Panic --> [*] : hp == 0 or fell off-screen (no score if fell)
```

Stompable. Contact 1 dmg. The comedy enemy — panic yelp SFX, briefcase flails.

## Angry Manager — sight-triggered charger

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle : stand, look both ways every 2 s
    Alert : "!!" popup, 0.4 s telegraph (red flash)
    Charge : 180 px/s toward player's position at alert-time, no turning
    WallStun : 1.2 s dizzy (stars FX) — punish window, takes DOUBLE damage
    Cooldown : 0.8 s heavy breathing, faces player
    Idle --> Alert : player in LoS raycast (120 px, same height ±16)
    Alert --> Charge : telegraph done
    Charge --> WallStun : hit wall
    Charge --> Cooldown : traveled 200 px without wall
    WallStun --> Idle : timer
    Cooldown --> Alert : player still in LoS
    Cooldown --> Idle : lost sight
```

## Auditor — spacing ranged

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle : adjust glasses
    Reposition : hop AWAY if player < 100 px, hop toward if > 140 px (stay in band)
    Throw : 4-frame windup, lob ledger projectile (arc, aimed at player pos)
    Idle --> Reposition : player detected (160 px range) and out of band
    Idle --> Throw : player in band and cooldown (2 s) ready
    Reposition --> Idle : landed
    Throw --> Idle : animation done
```

NOT stompable (spiked ledger hat — stomping hurts player). Projectile despawns on wall/2.5 s.

## Loan Shark — ambusher

```mermaid
stateDiagram-v2
    [*] --> Hidden
    Hidden : inside prop, only fin visible (subtle tell, 2-frame anim)
    Emerge : 0.25 s burst out (brief telegraph splash FX)
    Lunge : leap toward player, 220 px/s arc, contact 2 dmg
    Recover : 1.0 s exposed on ground — main punish window
    Return : swim back into nearest prop slot
    Hidden --> Emerge : player within 60 px
    Emerge --> Lunge
    Lunge --> Recover : landed
    Recover --> Return : timer, player > 80 px
    Recover --> Lunge : timer, player ≤ 80 px (re-lunge, max 2 consecutive)
    Return --> Hidden : reached slot
```

Only vulnerable outside Hidden (hurtbox disabled while hidden).

## Corrupted AI Banker — teleport caster (also S2 mid-boss with 2× HP)

```mermaid
stateDiagram-v2
    [*] --> Float
    Float : hover at current anchor, bob
    TeleportOut : 3-frame glitch out
    TeleportIn : appear at random OTHER anchor (3 anchors per placement)
    Cast : 4-frame windup → 3-projectile fan aimed at player
    Summon : spawn 1 Junior Banker (max 2 alive), once per 50% hp lost
    Stagger : 1.5 s vulnerable hover after casting — punish window
    Float --> Cast : player in 180 px, cooldown ready
    Cast --> Stagger
    Stagger --> TeleportOut : timer
    Float --> TeleportOut : took a hit while floating
    TeleportOut --> TeleportIn
    TeleportIn --> Float
    Float --> Summon : crossed 50% hp threshold
    Summon --> TeleportOut
```

## Regional Manager (S3 mid-boss) — elite Angry Manager

Same FSM as Angry Manager plus: `DeskThrow` state between cooldowns (arcing desk projectile, breaks on ground into 2 paper hazards, 3 s), 12 HP, charge 220 px/s, WallStun shortened to 0.8 s after half HP.

## CEO Boss — "The Chairman" (3 phases via PhaseManager)

```mermaid
stateDiagram-v2
    [*] --> Intro : arena locks, health bar fills
    state "Phase 1 — Executive Suit (30 hp)" as P1 {
        [*] --> ChoosePattern1
        ChoosePattern1 --> Slam : weight 40%
        ChoosePattern1 --> CoinVolley : weight 35%
        ChoosePattern1 --> DeskCharge : weight 25%
        Slam : jump to player x, ground slam → shockwave both directions (jumpable)
        Slam --> Stagger1 : lands bent over 1.5 s (head weak point)
        CoinVolley : 5 gold coins in arc spread
        DeskCharge : full-arena charge, telegraphed 0.5 s
        Stagger1 --> ChoosePattern1
        CoinVolley --> ChoosePattern1
        DeskCharge --> ChoosePattern1
    }
    state "Phase 2 — Hostile Takeover (25 hp)" as P2 {
        [*] --> ChoosePattern2
        note right of ChoosePattern2 : P1 patterns 20% faster + two new
        ChoosePattern2 --> SummonBankers : 2 Junior Bankers (max 3 alive)
        ChoosePattern2 --> MarketCrash : red candlestick pillars fall (shadow telegraphs 0.6 s)
    }
    state "Phase 3 — Full Corruption (20 hp)" as P3 {
        [*] --> ChoosePattern3
        ChoosePattern3 --> LaserSweep : screen-edge horizontal sweep — dash i-frames / shield / platform
        ChoosePattern3 --> TeleportSlam : glitch above player, slam down
        ChoosePattern3 --> CoinSpiral : bullet-hell spiral, 12 projectiles/s for 3 s
        ChoosePattern3 --> CoreExposed : after any 2 patterns, core glows 2 s (ONLY damage window in P3)
        CoreExposed --> ChoosePattern3
    }
    Intro --> P1
    P1 --> PhaseChange1 : hp pool 1 empty — invulnerable, jacket-off anim, music layer 2
    PhaseChange1 --> P2
    P2 --> PhaseChange2 : hp pool 2 empty — demon transform, arena tint red, music layer 3
    PhaseChange2 --> P3
    P3 --> Death : hp pool 3 empty — long dissolve, coins rain, arena unlocks
    Death --> [*]
```

Boss HP bar: segmented bottom bar, refills per phase (classic arcade). All boss projectiles pooled. Every pattern has ≥ 0.4 s visual telegraph — **no unreactable hits**.

## Shared tuning table (in `data/enemies/*.tres`)

| Enemy | HP | Speed | Detect | Cooldown |
|---|---|---|---|---|
| Junior Banker | 2 | 40/80 | — | — |
| Angry Manager | 4 | 180 charge | 120 LoS | 0.8 |
| Auditor | 3 | 60 hop | 160 | 2.0 |
| Loan Shark | 5 | 220 lunge | 60 | 1.0 |
| AI Banker | 8 (16 midboss) | — | 180 | 2.5 |
| Regional Manager | 12 | 220 | 140 | 0.6 |
| CEO | 30/25/20 | varies | arena | pattern-driven |
