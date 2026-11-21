extends RefCounted

const MASS := 40.0
const LENGTH := 2.5
const GRAVITY := 9.81
const A := .36
const REACH := .91*A
const DOCK_TIME := 18.0
const HOOK_WINDOW := .65

var spring := 20.0
var q_plus := 0.0
var q_minus := 0.0
var u_plus := 0.0
var u_minus := 0.0

static func omega_common() -> float:
	return sqrt(GRAVITY/LENGTH)

static func omega_opposed(k: float) -> float:
	return sqrt(GRAVITY/LENGTH+2.0*k/MASS)

func reset(k: float, state: Vector4) -> void:
	spring = k
	q_plus = .5*(state.x+state.y)
	q_minus = .5*(state.x-state.y)
	u_plus = .5*(state.z+state.w)
	u_minus = .5*(state.z-state.w)

static func release_state(mode: String) -> Vector4:
	match mode:
		"together": return Vector4(A,A,0,0)
		"opposed": return Vector4(A,-A,0,0)
		"far": return Vector4(0,A,0,0)
	return Vector4(A,0,0,0)

func sample(t: float) -> Vector4:
	var w0 := omega_common()
	var w1 := omega_opposed(spring)
	var c0 := cos(w0*t)
	var s0 := sin(w0*t)
	var c1 := cos(w1*t)
	var s1 := sin(w1*t)
	var p := q_plus*c0 + u_plus*s0/w0
	var m := q_minus*c1 + u_minus*s1/w1
	var dp := -w0*q_plus*s0 + u_plus*c0
	var dm := -w1*q_minus*s1 + u_minus*c1
	return Vector4(p+m,p-m,dp+dm,dp-dm)

func energy(v: Vector4) -> Vector2:
	var split_spring := .25*spring*(v.x-v.y)*(v.x-v.y)
	var w2 := GRAVITY/LENGTH
	return Vector2(.5*MASS*(v.z*v.z+w2*v.x*v.x)+split_spring,
		.5*MASS*(v.w*v.w+w2*v.y*v.y)+split_spring)

func spring_force_on_far(v: Vector4) -> float:
	return spring*(v.x-v.y)
