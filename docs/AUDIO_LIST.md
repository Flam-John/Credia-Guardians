# Audio List

## Bus layout

```
Master
├── Music   (crossfaded by AudioManager, 2 stream players)
├── SFX     (8-player round-robin pool, pitch jitter ±5 %)
└── UI      (menu sounds — audible while game paused)
```

Options sliders: Master / Music / SFX(+UI). Stored in `user://settings.cfg`, applied via `AudioServer.set_bus_volume_db` (linear→dB conversion, mute below 0.01).

## Music — 12 tracks, .ogg, loop points tagged

| Track | File | Style cue |
|---|---|---|
| Main menu | `menu.ogg` | Confident mid-tempo synthwave-chiptune, bank-heist cool |
| Stage 1 Office | `stage_1.ogg` | Upbeat, playful — keyboard-clack percussion |
| Stage 2 Data Center | `stage_2.ogg` | Driving arps, rain-like hi-hats |
| Stage 3 HQ | `stage_3.ogg` | Swagger, brass-y square leads (corporate villainy) |
| Stage 4 Vault | `stage_4.ogg` | Tense heist ticking, sparse then building |
| Stage 5 Core | `stage_5.ogg` | Fast, glitchy, distorted bass |
| Mid-boss | `boss_mid.ogg` | Aggressive loop, short |
| CEO boss | `boss_final.ogg` | 3 intensities (vertical layers or 3 sections) |
| Stage clear | `stage_clear.ogg` | 6 s jingle → tally silence w/ ticks |
| Victory | `victory.ogg` | Triumphant full theme (credits) |
| Game over | `game_over.ogg` | 4 s descending jingle |
| Intro cutscene | reuse `menu.ogg` low-pass filtered |

Sourcing: CC0/CC-BY chiptune (OpenGameArt/FreePD) selected for style match in M6; attribution in credits. Placeholder until then: menu + stage_1 + boss_mid only.

## SFX — .wav one-shots (retro synth style, generated with jsfxr-style tool or CC0)

**Player:** `jump`, `double_jump` (higher pitch), `land` (soft), `dash` (whoosh), `attack_1`, `attack_2`, `attack_3` (rising pitches), `hit_connect` (crunch + hitstop), `hurt`, `death` (descending), `heal` (coffee slurp), `powerup` (ascending arp), `shield_on`, `shield_loop` (quiet hum), `shield_break`, `stomp` (boing).
**World:** `coin` (bright 2-note — THE signature sound), `checkpoint` ("commit" chirp), `node_hold_loop` (charging), `node_activate` (unlock fanfare 1 s), `gate_open` (heavy servo), `platform_crumble`, `hidden_room` (secret discovered — Zelda-like), `laser_hum`, `laser_fire`.
**Enemies:** `enemy_hurt`, `enemy_death` (pixel pop), `banker_panic` (comic yelp), `manager_charge` (angry grunt), `ledger_throw`, `shark_lunge` (splash-snap), `ai_teleport`, `projectile`, `boss_hurt`, `boss_slam` (+shake), `boss_death` (long dissolve).
**UI:** `menu_move`, `menu_select`, `menu_back`, `pause_in/out`, `tally_tick`, `rank_stamp`, `slot_select`, `type_blip` (cutscene text).

~40 one-shots. Mixing rules: coin/UI bright and short; damage sounds duck music −3 dB for 0.2 s; never more than 2 identical SFX within 0.05 s (pool guard).

## Implementation notes
- `AudioManager.play_sfx(name, pitch_jitter=true)` — name→preloaded stream dict.
- `AudioManager.play_music(track, crossfade=1.0)` — no restart if same track.
- Boss phases call `play_music("boss_final", section=n)`.
- Stage clear: music stops → jingle → tally ticks on UI bus.
