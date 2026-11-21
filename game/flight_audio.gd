extends Node

const SAMPLE_RATE := 22050
var ambient := AudioStreamPlayer.new()
var voices: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}
var next_voice := 0
var enabled := true
var live := false
var volume_target := -35.0

func _ready() -> void:
	add_child(ambient)
	ambient.stream = _wind()
	ambient.volume_db = -55
	for index in 5:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -12
		voices.append(voice)
		add_child(voice)
	clips = {
		"gate": _chime([69, 76], 0.09, 0.6),
		"chain": _chime([69, 73, 76, 81], 0.075, 0.65),
		"seed": _chime([81, 85], 0.075, 0.37),
		"thermal": _chime([57, 64, 69], 0.16, 0.95),
		"companion": _chime([76, 81, 79, 85], 0.16, 1.18),
		"survey": _chime([79], 0.0, 0.19),
		"echo": _chime([74, 81], 0.10, 0.47),
		"home": _chime([62, 66, 69, 76], 0.16, 1.3),
		"land": _chime([62, 57], 0.18, 0.8),
		"dock": _chime([50, 57, 62], 0.22, 1.55),
		"launch": _chime([52, 59], 0.12, 0.84),
		"finish": _chime([62, 69, 71, 74], 0.14, 1.35),
		"impact": _chime([48, 45], 0.13, 0.75),
	}

func _wav(data: PackedByteArray, looping: bool = false) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = data.size() / 2
	return stream

func _wind() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 61593
	var samples := SAMPLE_RATE * 2
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var low := 0.0
	var mid := 0.0
	for i in samples:
		var source := rng.randf_range(-1, 1)
		low = lerpf(low, source, 0.045)
		mid = lerpf(mid, source, 0.28)
		var taper := minf(1.0, minf(i, samples - i) / 220.0)
		bytes.encode_s16(i * 2, int((0.72 * low + 0.28 * mid) * taper * 29000))
	return _wav(bytes, true)

func _chime(notes: Array, spacing: float, duration: float) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var mix := 0.0
		for n in notes.size():
			var age := t - n * spacing
			if age < 0:
				continue
			var f := 440.0 * pow(2.0, (float(notes[n]) - 69.0) / 12.0)
			var env := minf(age / 0.009, 1.0) * exp(-age * 7.0)
			mix += env * (sin(TAU * f * age) + 0.23 * sin(TAU * f * 2.0 * age))
		var end_fade := minf((samples - i) / 230.0, 1.0)
		data.encode_s16(i * 2, int(clampf(mix * end_fade * 0.45, -1, 1) * 28000))
	return _wav(data)

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		for voice in voices:
			voice.stop()
	set_flight(live)

func set_flight(value: bool) -> void:
	live = value
	if enabled and live:
		if not ambient.playing:
			ambient.volume_db = -52
			ambient.play()
	else:
		ambient.stop()

func wind_speed(speed: float, folded: bool) -> void:
	volume_target = clampf(-37.0 + speed * 0.4, -33.0, -17.0)
	ambient.pitch_scale = clampf(0.75 + speed * 0.012 + (0.12 if folded else 0.0), 0.8, 1.55)

func cue(kind: String) -> void:
	if not enabled or not clips.has(kind) or voices.is_empty():
		return
	var player := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	player.stream = clips[kind]
	player.play()

func _process(delta: float) -> void:
	if ambient.playing:
		ambient.volume_db = move_toward(ambient.volume_db, volume_target, delta * 20)
