# Folder Structure (`res://`)

Rule of thumb: **`src/` = code, `scenes/` = .tscn, `assets/` = imports, `data/` = .tres tuning**. A script lives beside nothing — it lives in `src/` mirroring its domain; scenes reference scripts by path.

```
res://
├── project.godot
├── .gitignore                      # .godot/, *.import cache per strategy
├── addons/
│   └── gut/                        # Godot Unit Test plugin
├── assets/
│   ├── art/
│   │   ├── characters/            # chris_sheet.png, flam_sheet.png, portraits
│   │   ├── enemies/               # one sheet per enemy + bosses/
│   │   ├── tiles/                 # tileset_office.png, tileset_datacenter.png, ...
│   │   ├── props/                 # checkpoints, nodes, platforms, doors, monitors
│   │   ├── backgrounds/           # parallax layers per stage
│   │   ├── ui/                    # hud atlas, menu panels, rank medals, cursor
│   │   └── fx/                    # spark/glint/confetti/afterimage sheets
│   ├── audio/
│   │   ├── music/                 # .ogg per stage + menu/boss/victory/gameover
│   │   └── sfx/                   # .wav one-shots
│   └── fonts/                     # credia_pixel.fnt / .ttf (pixel font)
├── data/
│   ├── characters/                # chris.tres, flam.tres            (CharacterStats)
│   ├── enemies/                   # junior_banker.tres, ...          (EnemyStats)
│   └── levels/                    # stage_1.tres ... stage_5.tres    (LevelData)
├── scenes/
│   ├── main/                      # main.tscn
│   ├── levels/
│   │   ├── level_base.tscn
│   │   ├── stage_1_office/        # stage_1.tscn + stage-unique prop scenes
│   │   ├── stage_2_datacenter/
│   │   ├── stage_3_hq/
│   │   ├── stage_4_vault/
│   │   └── stage_5_core/
│   ├── entities/
│   │   ├── player/                # player.tscn
│   │   ├── enemies/               # enemy_base.tscn + one per enemy
│   │   ├── bosses/                # boss_base.tscn, ceo_boss.tscn, midbosses
│   │   ├── collectibles/          # coin.tscn, coffee.tscn, ... usb_key.tscn
│   │   └── props/                 # checkpoint, security_node, moving_platform,
│   │                              #   crumbling_platform, hidden_room, exit_gate,
│   │                              #   projectiles/
│   ├── ui/                        # all screens from SCENE_HIERARCHY.md + hud.tscn
│   └── fx/                        # hit_spark.tscn, coin_glint.tscn, dash_ghost.tscn,
│                                  #   confetti.tscn, score_popup.tscn
├── src/
│   ├── autoload/                  # event_bus.gd, game_manager.gd, save_manager.gd,
│   │                              #   audio_manager.gd, scene_manager.gd
│   ├── fsm/                       # state_machine.gd, state.gd
│   ├── components/                # health_component.gd, hurtbox_component.gd, ...
│   ├── entities/
│   │   ├── player/                # player.gd, player_camera.gd, states/*.gd
│   │   ├── enemies/               # enemy_base.gd, states/ per enemy
│   │   └── bosses/
│   ├── levels/                    # level_base.gd, checkpoint.gd, security_node.gd, ...
│   ├── ui/                        # one script per screen + hud.gd
│   ├── resources/                 # character_stats.gd, enemy_stats.gd, level_data.gd
│   └── util/                      # object_pool.gd, math_util.gd, debug_overlay.gd
├── tests/
│   ├── unit/                      # test_state_machine.gd, test_save_manager.gd, ...
│   └── debug_scenes/              # movement_room.tscn, combat_room.tscn, ...
├── tools/
│   └── artgen/                    # generate_placeholders.py + palette.py (Pillow)
└── docs/                          # these 17 documents
```

Naming: `snake_case` files/folders, `PascalCase` node names & class_name, one class per file in `src/` (test files may declare inner helper classes), script filename = class_name in snake_case.
