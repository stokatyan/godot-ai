extends ZAgent

class_name ZSoldier

var _current_ammo: float = 0.20
var _ammo_per_reload: float = 0.20
var _ammo_cost_per_shot: float:
	get:
		return 0.01

var _reload_delay_remaining = 0.0
var _reload_time = 0.1
var _reload_time_per_frame: float:
	get:
		return 0.01

var _fire_delay_per_shot = 0.02
var _fire_delay_remaining = 0.0
var _fire_time_per_frame: float:
	get:
		return 0.01

var last_shot_line: Vector4

func _init():
	_attack_damage = 0.25
	_radius = 20
	_physics_body = PhysicsServer2D.body_create()
	_physics_shape = PhysicsServer2D.circle_shape_create()
	PhysicsServer2D.shape_set_data(_physics_shape, _radius)
	PhysicsServer2D.body_add_shape(_physics_body, _physics_shape)
	PhysicsServer2D.body_set_mode(_physics_body, PhysicsServer2D.BodyMode.BODY_MODE_KINEMATIC)

func get_vision_angles() -> Array[float]:
	var r: float = _rotation
	var _angles: Array[float] = [
		(0 + r),

		(PI * 0.1 + r),
		(PI * -0.1 + r),

		(PI * 0.21 + r),
		(PI * -0.21 + r),

		(PI * 0.33 + r),
		(PI * -0.33 + r),

		(PI * 0.48 + r),
		(PI * -0.48 + r),

		(PI * 0.60 + r),
		(PI * -0.60 + r),
		(PI * 0.75 + r),
		(PI * -0.75 + r),
	]
	return _angles

func did_get_hit(damage_taken: float):
	_health -= damage_taken
	_health = max(0, _health)

## Get all agent stats converted from 0->1 to -1->1
func get_stats() -> Array[float]:
	var stats: Array[float] = [
		_double_and_subtract_one(_health),
		_double_and_subtract_one(_attack_damage),
		_double_and_subtract_one(_current_ammo),
		_double_and_subtract_one(_ammo_per_reload),
		_double_and_subtract_one(_reload_delay_remaining),
		_double_and_subtract_one(_reload_time),
		_double_and_subtract_one(_fire_delay_per_shot),
		_double_and_subtract_one(_fire_delay_remaining),
	]

	return stats

func _double_and_subtract_one(val: ) -> float:
	return val * 2 - 1.0

func step_did_elapse(steps: float = 1.0):
	var was_reloading = _reload_delay_remaining > 0
	_reload_delay_remaining -= steps * _reload_time_per_frame
	_reload_delay_remaining = max(0, _reload_delay_remaining)
	if _reload_delay_remaining == 0 and was_reloading:
		_current_ammo = _ammo_per_reload

	_fire_delay_remaining -= steps * _fire_time_per_frame
	_fire_delay_remaining = max(0, _fire_delay_remaining)

## Update ammo state and returns true if a bullet was fired
func shoot() -> bool:
	if _current_ammo < _ammo_cost_per_shot:
		reload()
		return false
	if _fire_delay_remaining > 0:
		return false

	_current_ammo -= _ammo_cost_per_shot
	_fire_delay_remaining = _fire_delay_per_shot

	return true

func reload():
	if _current_ammo == _ammo_per_reload:
		return
	if _reload_delay_remaining > 0:
		return
	_current_ammo = 0
	_reload_delay_remaining = _reload_time
