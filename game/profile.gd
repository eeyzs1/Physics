extends RefCounted

const SLOTS := ["user://harbour-a.cfg", "user://harbour-b.cfg"]
const ROUTE_LIMIT := 9
var generation := 0
var seeds := 0
var voyages := 0
var last_seed := 0
var best_total := 0
var sound := true
var ghost := true
var fullscreen := false
var ribbon := 0
var records: Dictionary = {}
var last_cases := PackedStringArray(["", "", ""])
var case_records: Dictionary = {}
var companions: Dictionary = {}
var harbor_notes: Dictionary = {}
var harbor_resolved: Dictionary = {}
var loading_next_order := 0
const NOTE_FIELDS := ["title", "observation", "prediction", "result", "principle", "boundary"]

func load_profile() -> void:
	var best: ConfigFile
	for path: String in SLOTS:
		var file := ConfigFile.new()
		if file.load(path) != OK or file.get_value("port", "version", 0) != 1:
			continue
		var candidate := int(file.get_value("port", "generation", 0))
		if candidate > generation:
			best = file
			generation = candidate
	if best == null:
		return
	seeds = maxi(0, int(best.get_value("port", "seeds", 0)))
	voyages = maxi(0, int(best.get_value("port", "voyages", 0)))
	best_total = maxi(0, int(best.get_value("port", "best_total", 0)))
	last_seed = clampi(int(best.get_value("port", "last_seed", 0)), 0, 999999)
	sound = bool(best.get_value("settings", "sound", true))
	ghost = bool(best.get_value("settings", "ghost", true))
	fullscreen = bool(best.get_value("settings", "fullscreen", false))
	ribbon = clampi(int(best.get_value("settings", "ribbon", 0)), 0, 2)
	var stored = best.get_value("routes", "records", {})
	if stored is Dictionary:
		records = stored
	var itinerary = best.get_value("routes", "last_cases", last_cases)
	if itinerary is PackedStringArray and itinerary.size() == 3:
		last_cases = itinerary
	var archived = best.get_value("instruments", "records", {})
	if archived is Dictionary:
		case_records = archived
	var rays = best.get_value("port", "companions", {})
	if rays is Dictionary:
		companions = rays
	var notes = best.get_value("investigations", "notes", {})
	if notes is Dictionary:
		harbor_notes = notes
	var cleared = best.get_value("investigations", "resolved", {})
	if cleared is Dictionary:
		harbor_resolved = cleared
	loading_next_order = maxi(0, int(best.get_value("investigations", "loading_next_order", 0)))

func persist() -> bool:
	var file := ConfigFile.new()
	var next := generation + 1
	file.set_value("port", "version", 1)
	file.set_value("port", "generation", next)
	file.set_value("port", "seeds", seeds)
	file.set_value("port", "voyages", voyages)
	file.set_value("port", "last_seed", last_seed)
	file.set_value("port", "best_total", best_total)
	file.set_value("port", "companions", companions)
	file.set_value("settings", "sound", sound)
	file.set_value("settings", "ghost", ghost)
	file.set_value("settings", "fullscreen", fullscreen)
	file.set_value("settings", "ribbon", ribbon)
	file.set_value("routes", "records", records)
	file.set_value("routes", "last_cases", last_cases)
	file.set_value("instruments", "records", case_records)
	file.set_value("investigations", "notes", harbor_notes)
	file.set_value("investigations", "resolved", harbor_resolved)
	file.set_value("investigations", "loading_next_order", loading_next_order)
	# The previous generation stays intact if writing the other slot is interrupted.
	if file.save(SLOTS[next % SLOTS.size()]) != OK:
		return false
	generation = next
	return true

func record_investigation(location: String, evidence: Dictionary) -> bool:
	var note := {}
	for field: String in NOTE_FIELDS:
		var value := str(evidence.get(field, "")).strip_edges()
		if value.is_empty():
			return false
		note[field] = value
	note.resolved = bool(evidence.get("resolved", false))
	var previous: Array = harbor_notes.get(location, [])
	if not previous.is_empty() and previous.back() == note:
		return false
	previous.append(note)
	while previous.size() > 6:
		previous.pop_front()
	harbor_notes[location] = previous
	if note.resolved:
		harbor_resolved[location] = true
		if location == "loading":
			loading_next_order = maxi(loading_next_order, int(evidence.get("next_order", 0)))
	return true

func _route_id(seed_value: int, leg: int, case_key: String) -> String:
	return "%d/%d" % [seed_value, leg] + ("/" + case_key if not case_key.is_empty() else "")

func record_for(seed_value: int, leg: int, case_key: String = "") -> Dictionary:
	var entry = records.get(_route_id(seed_value, leg, case_key), {})
	return entry if entry is Dictionary else {}

func store_record(seed_value: int, leg: int, score: int, seconds: float, track: PackedFloat32Array, case_key: String = "") -> bool:
	var previous := record_for(seed_value, leg, case_key)
	if not previous.is_empty():
		if int(previous.get("score", 0)) > score:
			return false
		if int(previous.get("score", 0)) == score and float(previous.get("time", INF)) <= seconds:
			return false
	var key := _route_id(seed_value, leg, case_key)
	records.erase(key)
	records[key] = {"score": score, "time": seconds, "track": track}
	while records.size() > ROUTE_LIMIT:
		records.erase(records.keys()[0])
	return true

func log_instrument(report: Dictionary) -> void:
	var before: Dictionary = case_records.get(report.key, {})
	case_records[report.key] = {
		"attempts": int(before.get("attempts", 0)) + 1,
		"hits": int(before.get("hits", 0)) + int(report.hit),
		"best_error": minf(float(before.get("best_error", INF)), float(report.error_fraction))
	}

func export_samples(report: Dictionary) -> String:
	var folder := OS.get_user_data_dir().path_join("survey-logs")
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return ""
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var stem := "%06d-%d-%s-%s" % [report.seed, int(report.leg) + 1, report.key, stamp]
	var path := folder.path_join(stem + ".csv")
	var counter := 1
	while FileAccess.file_exists(path):
		path = folder.path_join(stem + "-%d.csv" % counter)
		counter += 1
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_csv_line(PackedStringArray(["course", "title", "route", "leg", "sample", "input", "condition", "output",
		"model_value", "pilot_estimate", "caught", "held_out", "lateral_offset_m", "height_offset_m"]))
	for n in report.samples.size():
		var row: Dictionary = report.samples[n]
		file.store_csv_line(PackedStringArray([report.key, report.title, str(report.seed), str(int(report.leg) + 1),
			str(n + 1), report.input, row.condition, report.output, JSON.stringify(row.model, "", true, true),
			JSON.stringify(row.estimate, "", true, true), str(row.caught), str(n == 3),
			JSON.stringify(row.lateral_m, "", true, true), JSON.stringify(row.altitude_m, "", true, true)]))
	file.flush()
	var saved := file.get_error() == OK
	file.close()
	return path if saved else ""
