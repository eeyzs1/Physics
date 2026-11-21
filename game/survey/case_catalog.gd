extends RefCounted

const MANUAL: JSON = preload("res://library/course_library.json")
const TABLES := ["cases_00_08.tsv", "cases_09_16.tsv", "cases_17_25.tsv"]
var fields: Array = []
var by_key: Dictionary = {}
var by_field: Dictionary = {}

func _init() -> void:
	fields = MANUAL.data.fields.duplicate()
	var models := {}
	for table in TABLES:
		var file := FileAccess.open("res://survey/" + table, FileAccess.READ)
		if file == null:
			push_error("Missing flight instrument table: " + table)
			continue
		while not file.eof_reached():
			var line := file.get_line().strip_edges()
			if line.is_empty():
				continue
			var parts := line.split("\t")
			if parts.size() != 6:
				push_error("Malformed flight instrument row in " + table)
				continue
			var tags := parts[4].split(";")
			var raw_values := parts[5].split(";")
			if tags.size() != 4 or raw_values.size() != 4 or models.has(parts[0]):
				push_error("Malformed sampling points: " + parts[0])
				continue
			var outputs := PackedFloat64Array()
			for value in raw_values:
				var number := value.strip_edges()
				if number.is_valid_float() and is_finite(number.to_float()):
					outputs.append(number.to_float())
			if outputs.size() != 4:
				push_error("Invalid sampling values: " + parts[0])
				continue
			models[parts[0]] = {"input": parts[1], "output": parts[2], "rule": parts[3],
				"tags": tags, "values": outputs}
	for entry in MANUAL.data.entries:
		var key: String = entry.key
		if not models.has(key):
			push_error("No playable flight instrument for " + key)
			continue
		var model: Dictionary = models[key]
		model.merge({"key": key, "title": entry.title, "field": entry.field, "stage": entry.stage})
		by_key[key] = model
		if not by_field.has(entry.field):
			by_field[entry.field] = []
		by_field[entry.field].append(key)

func next_cases(first: String, count: int) -> PackedStringArray:
	var output := PackedStringArray()
	if not by_key.has(first):
		return output
	var order: Array = by_field[by_key[first].field]
	var at := order.find(first)
	for i in count:
		output.append(order[(at + i) % order.size()])
	return output
