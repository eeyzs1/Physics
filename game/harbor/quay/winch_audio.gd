extends Node

var motor := AudioStreamPlayer.new()
var contact := AudioStreamPlayer.new()

func _ready() -> void:
	add_child(motor)
	add_child(contact)
	motor.stream = _clip(true)
	contact.stream = _clip(false)

func _clip(loop: bool) -> AudioStreamWAV:
	var rate := 16000
	var count := rate if loop else rate / 4
	var bytes := PackedByteArray()
	bytes.resize(2 * count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 137
	var noise := 0.0
	for i in count:
		var t := float(i) / rate
		var amp := .42 * sin(TAU * 56 * t) + .22 * sin(TAU * 112 * t)
		amp += .15 * sin(TAU * 224 * t) * (.6 + .4 * cos(TAU * 8 * t))
		if not loop:
			noise = lerpf(noise, rng.randf_range(-1,1), .27)
			amp = (noise * .7 + .46 * sin(TAU * 79 * t)) * exp(-22*t)
		bytes.encode_s16(i*2, int(clampf(amp,-1,1) * 30000))
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = rate
	clip.data = bytes
	if loop:
		clip.loop_mode = AudioStreamWAV.LOOP_FORWARD
		clip.loop_end = count
	return clip

func drive(travel: float, hoist: float, enabled: bool, delta: float) -> void:
	var effort := clampf(maxf(absf(travel) / 2.9, absf(hoist) / 1.4), 0, 1)
	if not enabled or effort < .02:
		if motor.playing:
			motor.stop()
		return
	motor.pitch_scale = lerpf(.82,1.24,effort)
	if not motor.playing:
		motor.volume_db = -37
		motor.play()
	motor.volume_db = move_toward(motor.volume_db,lerpf(-31,-22,effort),delta*38)

func knock(speed: float, enabled: bool) -> void:
	if enabled:
		contact.volume_db = lerpf(-21,-9,clampf(speed / 2,0,1))
		contact.play()

func quiet() -> void:
	motor.stop()
	contact.stop()
