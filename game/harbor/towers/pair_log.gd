extends RefCounted

# Index order is day-0, day-1, moon-0, moon-1. One tick is 22.5 physical degrees.
var visits := PackedInt32Array([0, 0, 0, 0])
var matched := PackedInt32Array([0, 0, 0, 0])
var bright := PackedInt32Array([0, 0])
var count := 0
var wins := 0

static func desired_same(cell: int) -> bool:
	return cell != 3

static func pass_classical(rules: PackedInt32Array, cell: int) -> bool:
	var same := rules[cell >> 1] == rules[2 + (cell & 1)]
	return same == desired_same(cell)

static func same_chance(angles: PackedInt32Array, noise: float, cell: int) -> float:
	var difference := (angles[cell >> 1] - angles[2 + (cell & 1)]) * PI / 8.0
	return 0.5 * (1.0 + (1.0 - noise) * cos(2.0 * difference))

static func long_run(angles: PackedInt32Array, noise: float) -> float:
	var total := 0.0
	for cell in 4:
		var same := same_chance(angles, noise, cell)
		total += same if desired_same(cell) else 1.0 - same
	return total / 4.0

static func angle_name(ticks: int) -> String:
	var signed_ticks := posmod(ticks, 8)
	if signed_ticks > 4:
		signed_ticks -= 8
	var degrees := signed_ticks * 22.5
	return ("%d°" % int(degrees)) if signed_ticks % 2 == 0 else ("%.1f°" % degrees)

func sample(rng: RandomNumberGenerator, angles: PackedInt32Array, noise: float) -> Vector3i:
	var x := rng.randi_range(0, 1)
	var y := rng.randi_range(0, 1)
	return sample_setting(rng, angles, noise, 2 * x + y)

func sample_setting(rng: RandomNumberGenerator, angles: PackedInt32Array, noise: float, cell: int) -> Vector3i:
	var a := rng.randi_range(0, 1)
	# Drawing the joint distribution here simulates a pair. No remote input is
	# available to either keeper. Each tower's marginal is an unbiased bit.
	var same := float(rng.randi()) / 4294967296.0 < same_chance(angles, noise, cell)
	var b := a if same else 1 - a
	visits[cell] += 1
	matched[cell] += int(same)
	bright[0] += a
	bright[1] += b
	wins += int(same == desired_same(cell))
	count += 1
	return Vector3i(cell, a, b)

func percent(n: int) -> float:
	return 100.0 * n / maxi(count, 1)

func chsh_score() -> float:
	if visits.has(0):
		return NAN
	var score := 0.0
	for cell in 4:
		var correlation := 2.0 * matched[cell] / visits[cell] - 1.0
		score += correlation if desired_same(cell) else -correlation
	return score

func chsh_readout() -> String:
	var score := chsh_score()
	if is_nan(score):
		return "还有来信组合没到齐。凑齐四班才能把实测关联换算成 CHSH 的 S。"
	return "每班的关联 E＝2 × 同号率 − 1。用四班实测得 S＝E₀₀＋E₀₁＋E₁₀−E₁₁＝%.3f，经典上限是 2。" % score

func interval() -> Vector2:
	if count == 0:
		return Vector2(0.0, 1.0)
	var z := 1.95996398454
	var p := float(wins) / count
	var denominator := 1.0 + z * z / count
	var center := (p + z * z / (2.0 * count)) / denominator
	var half_width := z * sqrt((p * (1.0 - p) + z * z / (4.0 * count)) / count) / denominator
	return Vector2(maxf(0.0, center - half_width), minf(1.0, center + half_width))
