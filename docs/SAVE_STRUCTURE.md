# Save Game Structure

## Files

| File | Contents | Format |
|---|---|---|
| `user://saves/slot_1.json` … `slot_3.json` | Progress per save slot | JSON, UTF-8 |
| `user://settings.cfg` | Options (global, not per-slot) | Godot `ConfigFile` |

Writes are atomic: write to `slot_N.json.tmp`, then rename over the old file — a crash mid-write never corrupts the slot. On load, a corrupt/unparseable slot is renamed to `slot_N.bak` and reported as empty (never silently deleted).

## Slot JSON schema (version 1)

```json
{
  "version": 1,
  "created_utc": "2026-07-07T12:00:00Z",
  "updated_utc": "2026-07-07T12:34:56Z",
  "play_time_sec": 4520,
  "last_character": "flam",
  "stages": {
    "1": {
      "unlocked": true,
      "cleared": true,
      "best_rank": "A",
      "hi_score": 45200,
      "best_time_sec": 312.5,
      "max_coins_collected": 92,
      "hidden_rooms_found": [true, false],
      "cleared_with": ["chris", "flam"]
    },
    "2": { "unlocked": true, "cleared": false, "best_rank": "", "hi_score": 0,
           "best_time_sec": 0, "max_coins_collected": 0,
           "hidden_rooms_found": [false, false, false], "cleared_with": [] }
  },
  "hp_upgrades_found": ["s1_hidden_2"],
  "global_hi_score": 100000
}
```

Notes:
- **Checkpoint state is NOT saved to disk** — checkpoints are per-attempt (arcade rule). Quitting mid-stage returns you to Stage Select; the stage restarts fresh. This keeps ranks meaningful and the schema simple.
- `hidden_rooms_found` length comes from `LevelData.hidden_room_count` — arrays sized on first write for that stage.
- `hp_upgrades_found` — permanent +1 max HP pickups, keyed by unique string IDs so they never respawn.
- `best_*` fields only ever improve (max/min-merge on write).
- Stage keys are strings (JSON object keys), parsed to int on load.

## Settings (`settings.cfg`)

```ini
[audio]
master=0.8   ; linear 0..1
music=0.7
sfx=0.9

[video]
fullscreen=false
window_scale=3      ; 1..4 integer
scanlines=false

[input]
; only overridden actions stored, serialized InputEvent per action
jump="Key:Z"
```

## SaveManager API (contract for M3)

```gdscript
class_name SaveManagerAPI  # autoload "SaveManager"
func get_slot_summaries() -> Array[Dictionary]  # for slot-select UI (never loads full state)
func load_slot(i: int) -> SaveSlotData          # null-object EmptySlot if missing
func write_slot(i: int, data: SaveSlotData) -> Error
func delete_slot(i: int) -> Error
func record_stage_clear(stage_id: int, stats: StageClearStats) -> void  # max-merges bests, unlocks next
func save_settings() -> void / load_settings() -> void  # applies audio buses, window, input overrides
```

## Versioning & migration

`version` int at root. Loader: `while data.version < CURRENT: data = _migrations[data.version].call(data)`. Each migration is a pure Dictionary→Dictionary function, unit-tested with fixture files in `tests/unit/fixtures/`. Unknown future version (file from newer build) → refuse to load with UI message, never overwrite.

## What deliberately is NOT saved
Mid-stage position/HP/coins (arcade integrity), score of an unfinished run, enemy states. Session hi-score merges into `global_hi_score` only at stage clear / game over.
