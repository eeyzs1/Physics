extends RefCounted

# Five moving boards, six identical springs and two fixed walls. SI units throughout.
const COUNT := 5
const K := TAU * TAU
const DRIVE_NEWTON := 1.0
const DAMP_RATE := 0.37
const LOAD := 1.8
const BELL_CM := 4.0
const WHISTLE_CM := 1.7
const LOW_HZ := 0.30
const HIGH_HZ := 2.12

var masses := PackedFloat64Array()
var eigenvalues := PackedFloat64Array()
var frequencies := PackedFloat64Array()
var shapes: Array[PackedFloat64Array] = []
var cosine := PackedFloat64Array()
var sine := PackedFloat64Array()
var free_q := PackedFloat64Array()
var free_v := PackedFloat64Array()
var peaks := PackedFloat64Array()
var peak_phase := PackedFloat64Array()
var frequency := 1.0
var phase := 0.0
var loaded := -1
var driving := true


func configure(load_at: int = -1) -> void:
	loaded = load_at if load_at >= 0 and load_at < COUNT else -1
	masses.resize(COUNT)
	masses.fill(1.0)
	if loaded >= 0:
		masses[loaded] += LOAD
	eigenvalues.resize(COUNT)
	frequencies.resize(COUNT)
	shapes.clear()
	for mode in range(COUNT):
		var lo := 0.0
		var hi := 4.01 * K
		for it in range(53):
			var mid := (lo + hi) * 0.5
			if _below(mid) <= mode:
				lo = mid
			else:
				hi = mid
		var lambda := (lo + hi) * 0.5
		eigenvalues[mode] = lambda
		frequencies[mode] = sqrt(lambda) / TAU
		var shape := PackedFloat64Array([1.0])
		var previous := 0.0
		for j in range(COUNT - 1):
			var next := (2.0 - lambda * masses[j] / K) * shape[j] - previous
			previous = shape[j]
			shape.append(next)
		var norm_squared := 0.0
		for j in range(COUNT):
			norm_squared += masses[j] * shape[j] * shape[j]
		for j in range(COUNT):
			shape[j] /= sqrt(norm_squared)
		shapes.append(shape)
	set_frequency(frequency)


func _below(value: float) -> int:
	# Sturm count using LDL pivots of M^(-1/2) K M^(-1/2) - value I.
	var negative := 0
	var pivot := 0.0
	for j in range(COUNT):
		var next := 2.0*K/masses[j] - value
		if j > 0:
			next -= K*K / (masses[j-1]*masses[j]*pivot)
		pivot = -1e-14 if absf(next) < 1e-14 else next
		if pivot < 0.0:
			negative += 1
	return negative


func set_frequency(hz: float) -> void:
	frequency = clampf(hz, LOW_HZ, HIGH_HZ)
	phase = 0.0
	driving = true
	cosine.resize(COUNT)
	sine.resize(COUNT)
	free_q.resize(COUNT)
	free_v.resize(COUNT)
	free_q.fill(0)
	free_v.fill(0)
	peaks.resize(COUNT)
	peak_phase.resize(COUNT)
	var omega := TAU * frequency
	for n in range(COUNT):
		var a := eigenvalues[n] - omega*omega
		var b := DAMP_RATE * omega
		var participation := shapes[n][0] * DRIVE_NEWTON / (a*a + b*b)
		cosine[n] = a * participation
		sine[n] = b * participation
	# Orthogonal quadratures measure the peak displacement of the settled periodic response.
	for i in range(COUNT):
		var c := 0.0
		var s := 0.0
		for n in range(COUNT):
			c += shapes[n][i] * cosine[n]
			s += shapes[n][i] * sine[n]
		peaks[i] = 100.0 * sqrt(c*c + s*s)
		peak_phase[i] = atan2(s,c)


func crosses_rising(board: int, threshold_cm: float, phase_from: float, seconds: float) -> bool:
	var amplitude := peaks[board]
	if amplitude < threshold_cm or amplitude <= 0.0:
		return false
	# For u=A cos(phase-peak_phase), the rising contact happens before the peak.
	var contact := peak_phase[board]-acos(clampf(threshold_cm/amplitude,-1,1))
	var ahead := fposmod(contact-phase_from,TAU)
	if ahead < 1e-12:
		ahead = TAU
	return ahead <= TAU*frequency*seconds+1e-12


func tap(board: int) -> void:
	# A brief vertical impulse projects onto every free mode that moves this board.
	for n in range(COUNT):
		free_v[n] += 0.43 * shapes[n][board]


func release_bellows() -> void:
	if not driving:
		return
	var c := cos(phase)
	var s := sin(phase)
	for n in range(COUNT):
		free_q[n] += cosine[n]*c + sine[n]*s
		free_v[n] += TAU*frequency*(-cosine[n]*s + sine[n]*c)
	driving = false


func advance(dt: float) -> void:
	phase = fmod(phase + TAU*frequency*dt, TAU)
	var beta := DAMP_RATE * 0.5
	var decay := exp(-beta * dt)
	for n in range(COUNT):
		var wd := sqrt(eigenvalues[n] - beta*beta)
		var c := cos(wd*dt)
		var s := sin(wd*dt)/wd
		var q := free_q[n]
		var v := free_v[n]
		free_q[n] = decay * (q*c + (v + beta*q)*s)
		free_v[n] = decay * (v*c - (eigenvalues[n]*q + beta*v)*s)


func displacements() -> PackedFloat64Array:
	var u := PackedFloat64Array([0,0,0,0,0])
	var c := cos(phase)
	var s := sin(phase)
	for n in range(COUNT):
		var coordinate := free_q[n]
		if driving:
			coordinate += cosine[n]*c + sine[n]*s
		for i in range(COUNT):
			u[i] += shapes[n][i] * coordinate
	return u


func modal_record(after_tap: bool = false) -> Dictionary:
	var best := 0
	var largest := -1.0
	var magnitude := 0.0
	var omega_squared := (TAU*frequency)**2
	for n in range(COUNT):
		var amplitude := sqrt(cosine[n]**2 + sine[n]**2)
		var energy := amplitude**2 * (eigenvalues[n] + omega_squared) / 4.0
		if not driving or after_tap:
			var q := free_q[n]
			var v := free_v[n]
			if driving:
				q += cosine[n]*cos(phase) + sine[n]*sin(phase)
				v += TAU*frequency*(-cosine[n]*sin(phase) + sine[n]*cos(phase))
			energy = (v*v + eigenvalues[n]*q*q)/2.0
			amplitude = sqrt(2.0*energy/eigenvalues[n])
		if energy > largest:
			best = n
			largest = energy
			magnitude = amplitude
	var u := shapes[best].duplicate()
	# Choose a common phase for the isolated mode, orienting its first plate upward.
	for i in range(COUNT):
		u[i] *= magnitude
	var ku := stiffness_times(u)
	var inertia := PackedFloat64Array()
	for i in range(COUNT):
		inertia.append(eigenvalues[best]*masses[i]*u[i])
	return {"mode": best+1, "hz": frequencies[best], "u": u, "ku": ku, "inertia": inertia}


func steady_imprint() -> Dictionary:
	# Sample every board at the same instant, the top of board one's cycle.
	# The amplitudes are separate whole-cycle measurements.
	var side_cm := PackedFloat64Array()
	var fourth_by_mode_cm := PackedFloat64Array()
	for i in range(COUNT):
		side_cm.append(peaks[i]*cos(peak_phase[0]-peak_phase[i]))
		fourth_by_mode_cm.append(100.0*absf(shapes[i][3])*sqrt(cosine[i]**2+sine[i]**2))
	var primary := modal_record()
	var shape: PackedFloat64Array = primary.u
	return {
		"hz":frequency, "peaks":peaks.duplicate(), "side_cm":side_cm,
		"primary":primary, "fourth_by_mode_cm":fourth_by_mode_cm,
		"left":K*(shape[1]-shape[2]), "right":K*(shape[3]-shape[2]),
		"node":absf(shapes[int(primary.mode)-1][2]) < 1e-8
	}


func stiffness_times(u: PackedFloat64Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i in range(COUNT):
		var left := u[i-1] if i > 0 else 0.0
		var right := u[i+1] if i < COUNT-1 else 0.0
		out.append(K * (2.0*u[i] - left - right))
	return out


func answers_call() -> bool:
	return peaks[3] >= BELL_CM and peaks[2] <= WHISTLE_CM
