extends Node3D
## Orbit / free-fly / walk camera with tweened flights to curated views.

enum Mode { ORBIT, FLY, WALK }

signal mode_changed(mode: int)
signal user_moved            # the user dragged, panned, zoomed or steered: scripted camera moves stand down

@onready var cam: Camera3D = $Camera3D
var mode: int = Mode.ORBIT
var terrain: Node3D

# orbit state
var target := Vector3(0, 80, 0)
var distance := 9000.0
var yaw := 0.6
var pitch := -0.55
# fly state
var fly_yaw := 0.0
var fly_pitch := 0.0
var fly_speed := 400.0
var walk_eye := 1.7
var _tween: Tween
var _fly_end_pos := Vector3.ZERO
var _fly_end_look := Vector3.ZERO
var _dragging := 0
var mouse_sensitivity := 0.004
var flying := false


func _ready() -> void:
	cam.near = 0.5
	cam.far = 60000.0
	cam.fov = 60.0
	_apply_orbit()


func set_mode(m: int) -> void:
	if m == mode:
		return
	var old_t := cam.global_transform
	mode = m
	if mode == Mode.ORBIT:
		# keep the view: put the orbit target on the ground ahead of the camera
		var fwd := -old_t.basis.z
		var d := 500.0
		if terrain:
			var g := _ground_hit(old_t.origin, fwd)
			if g.x > 0.0:
				d = g.x
		target = old_t.origin + fwd * d
		distance = d
		var rel := old_t.origin - target
		yaw = atan2(rel.x, rel.z)
		pitch = -asin(clampf(rel.y / maxf(rel.length(), 0.001), -1.0, 1.0))
		_apply_orbit()
	else:
		var e := old_t.basis.get_euler()
		fly_yaw = e.y
		fly_pitch = e.x
		if mode == Mode.WALK:
			_snap_walk()
	mode_changed.emit(mode)


func _ground_hit(from: Vector3, dir: Vector3) -> Vector2:
	# cheap ray-march against the heightmap: returns (distance, 0) or (-1, 0)
	var step := 20.0
	var p := from
	for i in 2000:
		p += dir * step
		if terrain.height_at(p.x, p.z) * AppState.vexag >= p.y:
			return Vector2(step * (i + 1), 0.0)
	return Vector2(-1.0, 0.0)


func _apply_orbit() -> void:
	var rot := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var offset := rot * Vector3(0, 0, distance)
	cam.global_position = target + offset
	cam.look_at(target, Vector3.UP)


func _snap_walk() -> void:
	if terrain:
		var g: float = terrain.height_at(cam.global_position.x, cam.global_position.z) * AppState.vexag
		cam.global_position.y = g + walk_eye


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.button_index if mb.pressed else 0
			if mode != Mode.ORBIT:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if (mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT) else Input.MOUSE_MODE_VISIBLE
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.85)
			user_moved.emit()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 / 0.85)
			user_moved.emit()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _tween and _tween.is_running():
			return
		if _dragging != 0:
			user_moved.emit()
		if mode == Mode.ORBIT:
			if _dragging == MOUSE_BUTTON_LEFT:
				yaw -= mm.relative.x * mouse_sensitivity
				pitch = clampf(pitch - mm.relative.y * mouse_sensitivity, -1.55, 1.55)
				_apply_orbit()
			elif _dragging == MOUSE_BUTTON_RIGHT or _dragging == MOUSE_BUTTON_MIDDLE:
				var b := cam.global_transform.basis
				var pan := (-b.x * mm.relative.x + b.y * mm.relative.y) * distance * 0.0015
				target += pan
				_apply_orbit()
		else:
			if _dragging == MOUSE_BUTTON_RIGHT:
				fly_yaw -= mm.relative.x * mouse_sensitivity
				fly_pitch = clampf(fly_pitch - mm.relative.y * mouse_sensitivity, -1.55, 1.55)
				cam.global_transform.basis = Basis.from_euler(Vector3(fly_pitch, fly_yaw, 0.0))


func _zoom(factor: float) -> void:
	if mode == Mode.ORBIT:
		distance = clampf(distance * factor, 0.02, 60000.0)
		_apply_orbit()
	else:
		fly_speed = clampf(fly_speed / factor, 0.01, 5000.0)


func _process(dt: float) -> void:
	if _tween and _tween.is_running():
		return
	if mode == Mode.ORBIT:
		return
	var dir := Vector3.ZERO
	var b := cam.global_transform.basis
	if Input.is_action_pressed("cam_forward"):
		dir -= b.z
	if Input.is_action_pressed("cam_back"):
		dir += b.z
	if Input.is_action_pressed("cam_left"):
		dir -= b.x
	if Input.is_action_pressed("cam_right"):
		dir += b.x
	if mode == Mode.FLY:
		if Input.is_action_pressed("cam_up"):
			dir += Vector3.UP
		if Input.is_action_pressed("cam_down"):
			dir -= Vector3.UP
	else:
		dir.y = 0.0
	if dir.length() > 0.0:
		user_moved.emit()
		var sp := fly_speed * (4.0 if Input.is_action_pressed("cam_fast") else 1.0)
		if mode == Mode.WALK:
			sp = minf(sp, 40.0) * (3.0 if Input.is_action_pressed("cam_fast") else 1.0)
		cam.global_position += dir.normalized() * sp * dt
	if mode == Mode.WALK:
		_snap_walk()


## Fly smoothly to a position looking at a point. Switches to orbit around `look_at` on arrival.
func fly_to(pos: Vector3, look_at: Vector3, duration := 1.6) -> void:
	if _tween:
		_tween.kill()
	flying = true
	_fly_end_pos = pos
	_fly_end_look = look_at
	var from_pos := cam.global_position
	var from_look := from_pos - cam.global_transform.basis.z * maxf((cam.global_position - look_at).length(), 1.0)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(func(t: float):
		var p := from_pos.lerp(pos, t)
		var l := from_look.lerp(look_at, t)
		cam.global_position = p
		if (l - p).length() > 0.0001:
			cam.look_at(l, Vector3.UP)
	, 0.0, 1.0, duration)
	_tween.tween_callback(func():
		flying = false
		target = look_at
		distance = maxf((pos - look_at).length(), 0.02)
		var rel := pos - look_at
		yaw = atan2(rel.x, rel.z)
		pitch = -asin(clampf(rel.y / maxf(rel.length(), 0.001), -1.0, 1.0))
		var e := cam.global_transform.basis.get_euler()
		fly_yaw = e.y
		fly_pitch = e.x
		if mode == Mode.ORBIT:
			_apply_orbit()
	)


## Place the camera immediately (no tween) and make it the orbit pose.
func jump_to(pos: Vector3, look_at: Vector3) -> void:
	if _tween:
		_tween.kill()
	flying = false
	cam.global_position = pos
	if (look_at - pos).length() > 0.0001:
		cam.look_at(look_at, Vector3.UP)
	target = look_at
	distance = maxf((pos - look_at).length(), 0.02)
	var rel := pos - look_at
	yaw = atan2(rel.x, rel.z)
	pitch = -asin(clampf(rel.y / maxf(rel.length(), 0.001), -1.0, 1.0))
	var e := cam.global_transform.basis.get_euler()
	fly_yaw = e.y
	fly_pitch = e.x


## Place the camera for this frame (a scripted move); the orbit state follows so the user can take over smoothly.
## Ignored while a flight is in progress.
func drive(pos: Vector3, look_at: Vector3) -> void:
	if _tween and _tween.is_running():
		return
	cam.global_position = pos
	if (look_at - pos).length() > 0.0001:
		cam.look_at(look_at, Vector3.UP)
	target = look_at
	distance = maxf((pos - look_at).length(), 0.02)
	var rel := pos - look_at
	yaw = atan2(rel.x, rel.z)
	pitch = -asin(clampf(rel.y / maxf(rel.length(), 0.001), -1.0, 1.0))


## If a flight is in progress, end it at its destination now.
func finish_flight() -> void:
	if _tween and _tween.is_running():
		jump_to(_fly_end_pos, _fly_end_look)


func set_near(n: float) -> void:
	cam.near = n
	cam.far = 60000.0 if n >= 0.1 else (n * 200000.0)


func camera_info() -> Dictionary:
	var p := cam.global_position
	var ground: float = terrain.height_at(p.x, p.z) if terrain else 0.0
	return {"x": p.x, "y": p.y / AppState.vexag, "z": p.z, "ground": ground, "depth": ground - p.y / AppState.vexag}
