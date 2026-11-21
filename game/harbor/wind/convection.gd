extends RefCounted

# Lorenz time is dimensionless. This fictional port maps one model unit to three harbour minutes.
const DT := 0.01
const SECONDS_PER_TICK := 1.8
const MINUTES_PER_TICK := 0.03
const LOCK_MINUTES := 14.0
const BUOY_TICKS := 24
const WAIT_TICKS := 40
const TIDES := [
	Vector3(-7.23771392, -4.08288471, 29.42143497),
	Vector3(-11.00479189, -5.95516137, 35.19343145),
]
const LEGS := {
	"outer": {"name": "旧邮路", "ticks": 90, "width": 55.0, "exposure": .70},
	"shoal": {"name": "双礁浅滩", "ticks": 132, "width": 32.0, "exposure": .65},
	"narrow": {"name": "裂帆峡", "ticks": 145, "width": 15.0, "exposure": 1.0},
	"bay": {"name": "灯笼湾", "ticks": 216, "width": 60.0, "exposure": .32},
}

static func rate(v: Vector3) -> Vector3:
	return Vector3(10.0 * (v.y-v.x), v.x * (28.0-v.z)-v.y, v.x*v.y-(8.0/3.0)*v.z)

static func step(v: Vector3) -> Vector3:
	var a := rate(v)
	var b := rate(v + .5*DT*a)
	var c := rate(v + .5*DT*b)
	var d := rate(v + DT*c)
	return v + (DT/6.0)*(a+2.0*b+2.0*c+d)

static func wind(v: Vector3) -> float:
	return .36*v.x + .10*v.y

static func reading(truth: Vector3, tick: int, precision: float, tide: int) -> Vector3:
	# Same direction of sensor error for both probes in a matched replay.
	var direction := Vector3(.8*cos(.021*tick+.7+.65*tide), .7*sin(.017*tick+1.1+.45*tide), .55*cos(.015*tick-.2))
	return truth + direction.normalized() * (.81*precision)

static func candidates(centre: Vector3, radius: float) -> Array[Vector3]:
	var states: Array[Vector3] = []
	for axis: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		states.append(centre + radius*axis)
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				states.append(centre + radius*Vector3(x,y,z).normalized())
	return states

static func drift(offset: float, wind_error: float, exposure: float, helm: float = 0.0) -> float:
	# Along-track speed is fixed per route. The pilot holds the predicted crosswind correction
	# and slowly recentres on the channel lights. Manual helm adds up to 0.86 m/s.
	return offset + SECONDS_PER_TICK*(exposure*wind_error - .012*offset + .86*helm)

static func outlook(centre: Vector3, members: Array[Vector3], key: String) -> Dictionary:
	var spec: Dictionary = LEGS[key]
	var local: Array[Vector3] = members.duplicate()
	var offsets := PackedFloat32Array()
	var peaks := PackedFloat32Array()
	offsets.resize(local.size())
	peaks.resize(local.size())
	var curves: Array[PackedFloat32Array] = []
	for i in local.size():
		curves.append(PackedFloat32Array([0.0]))
	var predicted := centre
	for k in int(spec.ticks):
		var prev_pred := wind(predicted)
		predicted = step(predicted)
		var mean_pred := .5*(prev_pred+wind(predicted))
		for i in local.size():
			var prev_wind := wind(local[i])
			local[i] = step(local[i])
			var residual := .5*(prev_wind+wind(local[i]))-mean_pred
			offsets[i] = drift(offsets[i], residual, spec.exposure)
			peaks[i] = maxf(peaks[i], absf(offsets[i]))
			if (k+1) % 3 == 0 or k+1 == int(spec.ticks):
				curves[i].append(offsets[i])
	var outside := 0
	var maximum := 0.0
	for value in peaks:
		maximum = maxf(maximum, value)
		if value >= float(spec.width):
			outside += 1
	return {"key":key, "curves":curves, "outside":outside, "maximum":maximum, "total":curves.size()}

static func horizon(anchor: Vector3, tick: int, precision: float, tide: int) -> float:
	var truth := anchor
	var predicted := reading(anchor, tick, precision, tide)
	for i in 800:
		truth = step(truth)
		predicted = step(predicted)
		if truth.distance_to(predicted) >= 1.0:
			return (i+1)*MINUTES_PER_TICK
	return -1.0

# Both instruments observe the very same truth, with the same error direction.
# Every point compares their respective forecast with the reference at that tick.
static func probe_trace(start: Vector3, tick: int, tide: int) -> Dictionary:
	var actual := start
	var a := reading(start, tick, 0.30, tide)
	var b := reading(start, tick, 0.03, tide)
	var normal := PackedFloat32Array()
	var fine := PackedFloat32Array()
	var crossed := Vector2i(-1, -1)
	for i in 801:
		var ea := actual.distance_to(a)
		var eb := actual.distance_to(b)
		normal.append(ea)
		fine.append(eb)
		if crossed.x == -1 and ea >= 1.0: crossed.x = i
		if crossed.y == -1 and eb >= 1.0: crossed.y = i
		actual = step(actual)
		a = step(a)
		b = step(b)
	return {"normal":normal, "fine":fine, "crossed":crossed}
