# Data Flow Diagrams

## 1. Input → Movement (every physics frame)

```mermaid
flowchart LR
    IN[InputMap actions<br/>keyboard + gamepad] --> P[player.gd plumbing<br/>buffers: jump, combo]
    P --> SM[StateMachine<br/>active State.physics_update]
    ST[CharacterStats.tres] --> SM
    SM -->|sets velocity| MS[move_and_slide]
    MS -->|is_on_floor, collisions| SM
    SM -->|play anim| SPR[AnimatedSprite2D]
    SM -->|transition| SM
```

## 2. Coin pickup → HUD/score

```mermaid
flowchart LR
    C[coin.tscn Area2D<br/>body_entered = player] -->|queue_free + glint FX + SFX| EB[EventBus.coin_collected 100]
    EB --> GM[GameManager<br/>score += · coins += 1]
    GM --> EB2[EventBus.score_changed]
    EB2 --> HUD[HUD: counter + score labels]
    GM -.stage end.-> SC[StageClear tally<br/>CREDITS EARNED]
```

## 3. Damage pipeline (both directions)

```mermaid
flowchart TD
    HB[HitboxComponent<br/>area_entered on target hurtbox] --> HUR{HurtboxComponent}
    HUR -->|invulnerable / dash i-frames / shield arc| NOPE[negate<br/>shield: drain meter + spark FX]
    HUR -->|vulnerable| HP[HealthComponent.damage]
    HP --> FLASH[FlashComponent] & KB[KnockbackComponent] & HS[hitstop 0.05 s]
    HP -->|hp > 0, owner=player| HURT[FSM → Hurt + 1 s invuln]
    HP -->|hp > 0, owner=enemy| EFLASH[stay in state, flash]
    HP -->|died, player| PD[EventBus.player_died → lives-- → respawn or Game Over]
    HP -->|died, enemy| ED[LootComponent drops → EventBus.enemy_killed → score popup + FX]
```

## 4. Save / Load

```mermaid
flowchart LR
    subgraph triggers
        T1[checkpoint_reached] & T2[stage_cleared] & T3[options changed]
    end
    T1 & T2 --> GM[GameManager assembles run stats]
    GM --> SM[SaveManager.write_slot]
    SM -->|serialize + version stamp| J[user://saves/slot_N.json]
    T3 --> CFG[user://settings.cfg]
    subgraph load
        MENU[Continue → slot pick] --> RD[SaveManager.load_slot]
        J --> RD --> MIG{version match?}
        MIG -->|no| M[migrate chain] --> DATA
        MIG -->|yes| DATA[SaveSlotData] --> SS[Stage Select: unlocks, ranks, hi-scores]
    end
```

## 5. Stage lifecycle

```mermaid
flowchart TD
    SEL[Stage Select] -->|SceneManager fade| LOAD[threaded load stage_N.tscn]
    LOAD --> INIT[LevelBase: spawn Player with chosen CharacterStats<br/>camera limits from CameraLimits rect<br/>AudioManager.play_music]
    INIT --> PLAY[gameplay loop]
    PLAY -->|all required nodes active| GATE[ExitGate opens]
    GATE -->|player enters exit| TALLY[stage_cleared stats:<br/>time, coins, kills-score, deaths, nodes]
    TALLY --> RANK[GameManager.compute_rank]
    RANK --> SAVE[SaveManager: unlock next, best rank/hi-score]
    SAVE --> CLEAR[StageClear screen count-up]
    CLEAR --> SEL
    PLAY -->|lives == 0| GO[Game Over] -->|retry| LOAD
```

**Contract summary:** gameplay objects write to `EventBus`; `GameManager` is the only aggregator; `SaveManager` is the only disk-toucher; UI only reads. No object polls another object's state across systems.
