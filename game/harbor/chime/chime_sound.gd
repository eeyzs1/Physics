extends Node

# The mechanism oscillates below hearing. Transpose the five calculated modes
# together for the wood, and give the separate bell and foghorn their own voices.
const RATE := 16000
var players: Array[AudioStreamPlayer] = []
var next_voice := 0
var samples: Dictionary = {}


func _ready() -> void:
	for i in range(4):
		var player := AudioStreamPlayer.new()
		player.volume_db = -12
		add_child(player)
		players.append(player)


func silence() -> void:
	for player in players:
		player.stop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED:
		silence()


func sound(kind: String, lab, board: int = 0) -> void:
	if players.is_empty() or not can_process():
		return
	var key := kind
	if kind == "wood":
		key += "/%d/%d" % [lab.loaded, board]
	if kind == "tune":
		key += "/%d" % roundi(lab.frequency * 1000.0)
	if not samples.has(key):
		if samples.size() >= 72:
			samples.erase(samples.keys()[0])
		samples[key] = _sample(kind, lab, board)
	var player := players[next_voice]
	next_voice = (next_voice + 1) % players.size()
	player.stream = samples[key]
	player.play()


func _sample(kind: String, lab, board: int) -> AudioStreamWAV:
	var seconds := 0.44
	match kind:
		"bell": seconds = 0.86
		"horn": seconds = 0.56
		"tune": seconds = 0.27
	var partials := PackedFloat64Array()
	var weights := PackedFloat64Array()
	if kind == "wood":
		for n in range(5):
			partials.append(TAU * 220.0 * lab.frequencies[n])
			weights.append(lab.shapes[n][board] ** 2 * lab.masses[board])
	var length := ceili(seconds*RATE)
	var data := PackedByteArray()
	data.resize(length*2)
	for i in range(length):
		var t := float(i)/RATE
		var value := 0.0
		match kind:
			"bell":
				value = (0.52*sin(TAU*498.0*t)*exp(-4.2*t) + 0.25*sin(TAU*1293.0*t)*exp(-6.4*t) + 0.10*sin(TAU*1988.0*t)*exp(-9.0*t))
			"horn":
				var phase := TAU*(124.0*t + 3.6*t*t)
				value = (0.50*sin(phase) + 0.22*sin(phase*2.0) + 0.08*sin(phase*3.0))*minf(1.0,t/0.09)*exp(-2.6*t)
			"tune":
				var phase: float = TAU*220.0*lab.frequency*t
				value = (0.55*sin(phase) + 0.14*sin(2.0*phase))*exp(-10.0*t)
			"wood":
				for n in range(5):
					value += 0.86*weights[n]*sin(partials[n]*t)*exp(-(5.5+1.5*n)*t)
		value *= minf(1.0,t/0.005) * clampf((seconds-t)/0.045,0.0,1.0)
		data.encode_s16(i*2,clampi(roundi(value*32000),-32768,32767))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = RATE
	wave.data = data
	return wave
