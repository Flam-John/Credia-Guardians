extends Node
## Only class that touches the disk. Slot saves are JSON with atomic writes
## (tmp + rename) and a version/migration chain. See docs/SAVE_STRUCTURE.md.

const SLOT_COUNT := 3
const CURRENT_VERSION := 1

## version (int) -> Callable(Dictionary) -> Dictionary. Filled as versions grow.
var _migrations: Dictionary = {}

var active_slot: int = -1

## Overridable so the test suite writes to a sandbox instead of the player's
## real files (a test once shipped fullscreen=true to a real settings.cfg).
var save_dir := "user://saves"
var settings_path := "user://settings.cfg"


func redirect_for_tests(dir: String, cfg_path: String) -> void:
	save_dir = dir
	settings_path = cfg_path
	DirAccess.make_dir_recursive_absolute(save_dir)


func restore_default_paths() -> void:
	save_dir = "user://saves"
	settings_path = "user://settings.cfg"

## "" (never cleared) followed by GameManager.Rank names, worst->best.
## Derived, not duplicated: GameManager.Rank is the single source of truth.
var _rank_order: Array = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)
	_rank_order = [""]
	_rank_order.append_array(GameManager.Rank.keys())


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [save_dir, slot]


## Lightweight summaries for the slot-select UI. Never loads full state.
func get_slot_summaries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(1, SLOT_COUNT + 1):
		var data := load_slot(i)
		if data.is_empty():
			if is_slot_incompatible(i):
				out.append({"slot": i, "empty": false, "incompatible": true})
			else:
				out.append({"slot": i, "empty": true})
		else:
			out.append({
				"slot": i,
				"empty": false,
				"last_character": data.get("last_character", "chris"),
				"play_time_sec": data.get("play_time_sec", 0),
				"stages_cleared": _count_cleared(data),
				"global_hi_score": data.get("global_hi_score", 0),
				"coop": bool(data.get("coop", false)),
			})
	return out


## Returns {} for missing or unreadable slots. A corrupt file is preserved as
## .bak and reported empty -- never silently deleted.
func load_slot(slot: int) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	# Instance parse: returns an Error instead of spamming the engine log
	# (a corrupt save is an expected condition, not an engine fault).
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary or not json.data.has("version"):
		_quarantine(path)
		return {}
	var data: Dictionary = json.data
	var version := int(data.version)
	if version > CURRENT_VERSION:
		push_warning("Save slot %d is from a newer build (v%d) -- refusing to load." % [slot, version])
		return {}
	while version < CURRENT_VERSION:
		if not _migrations.has(version):
			_quarantine(path)
			return {}
		data = _migrations[version].call(data)
		version = int(data.version)
	return data


## True when the slot file exists but comes from a newer build. Such slots
## must never be overwritten (docs/SAVE_STRUCTURE.md) -- only explicitly
## deleted by the player.
func is_slot_incompatible(slot: int) -> bool:
	return _raw_version(slot) > CURRENT_VERSION


func write_slot(slot: int, data: Dictionary) -> Error:
	if is_slot_incompatible(slot):
		push_warning("Refusing to overwrite newer-build save in slot %d." % slot)
		return ERR_UNAVAILABLE
	data["version"] = CURRENT_VERSION
	data["updated_utc"] = Time.get_datetime_string_from_system(true)
	var path := slot_path(slot)
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	# Atomic-enough on the same volume: old file is replaced in one step.
	var dir := DirAccess.open(save_dir)
	dir.remove(path.get_file()) # no-op if missing
	return dir.rename(tmp.get_file(), path.get_file())


func delete_slot(slot: int) -> Error:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.open(save_dir).remove(path.get_file())


func new_slot_data(character: StringName) -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"created_utc": Time.get_datetime_string_from_system(true),
		"updated_utc": Time.get_datetime_string_from_system(true),
		"play_time_sec": 0,
		"last_character": String(character),
		"stages": {
			"1": _new_stage_entry(true),
		},
		"hp_upgrades_found": [],
		"global_hi_score": 0,
		"coop": false,
		"character2": "",
	}


## Records a clear: max-merges bests, unlocks the next stage.
## stats: {stage_id, rank (String), score, time, coins, hidden_rooms (Array[bool]),
##         character, next_stage_id}
func record_stage_clear(data: Dictionary, stats: Dictionary) -> Dictionary:
	var key := str(stats.stage_id)
	var stages: Dictionary = data.get("stages", {})
	var entry: Dictionary = stages.get(key, _new_stage_entry(true))
	entry.cleared = true
	entry.best_rank = _best_rank(entry.get("best_rank", ""), stats.rank)
	entry.hi_score = maxi(int(entry.get("hi_score", 0)), int(stats.score))
	var prev_time := float(entry.get("best_time_sec", 0.0))
	entry.best_time_sec = stats.time if prev_time <= 0.0 else minf(prev_time, stats.time)
	entry.max_coins_collected = maxi(int(entry.get("max_coins_collected", 0)), int(stats.coins))
	var found: Array = entry.get("hidden_rooms_found", [])
	var new_found: Array = stats.get("hidden_rooms", [])
	for i in new_found.size():
		if i >= found.size():
			found.append(new_found[i])
		else:
			found[i] = found[i] or new_found[i]
	entry.hidden_rooms_found = found
	var cleared_with: Array = entry.get("cleared_with", [])
	if not cleared_with.has(String(stats.character)):
		cleared_with.append(String(stats.character))
	entry.cleared_with = cleared_with
	stages[key] = entry
	var next_id: int = stats.get("next_stage_id", 0)
	if next_id > 0:
		var next_key := str(next_id)
		if not stages.has(next_key):
			stages[next_key] = _new_stage_entry(true)
		else:
			stages[next_key]["unlocked"] = true
	data.stages = stages
	data.global_hi_score = maxi(int(data.get("global_hi_score", 0)), int(stats.score))
	return data


# -- Settings ---------------------------------------------------------------

func save_settings(settings: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for section: String in settings:
		for key: String in settings[section]:
			cfg.set_value(section, key, settings[section][key])
	cfg.save(settings_path)


func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return {}
	var out := {}
	for section in cfg.get_sections():
		out[section] = {}
		for key in cfg.get_section_keys(section):
			out[section][key] = cfg.get_value(section, key)
	return out


# -- Internals ---------------------------------------------------------------

func _count_cleared(data: Dictionary) -> int:
	var count := 0
	for entry: Dictionary in data.get("stages", {}).values():
		if entry.get("cleared", false):
			count += 1
	return count


func _new_stage_entry(unlocked: bool) -> Dictionary:
	return {
		"unlocked": unlocked,
		"cleared": false,
		"best_rank": "",
		"hi_score": 0,
		"best_time_sec": 0.0,
		"max_coins_collected": 0,
		"hidden_rooms_found": [],
		"cleared_with": [],
	}


func _best_rank(a: String, b: String) -> String:
	return a if _rank_order.find(a) >= _rank_order.find(b) else b


## Version field of the raw file, without loading/migrating. -1 if absent.
func _raw_version(slot: int) -> int:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return -1
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return -1
	return int(json.data.get("version", -1))


func _quarantine(path: String) -> void:
	push_warning("Corrupt save at %s -- moved to .bak" % path)
	var dir := DirAccess.open(save_dir)
	# Windows rename fails onto an existing target; keep the LATEST corrupt
	# file (an older .bak from a previous corruption gives way).
	dir.remove(path.get_file() + ".bak")
	dir.rename(path.get_file(), path.get_file() + ".bak")
