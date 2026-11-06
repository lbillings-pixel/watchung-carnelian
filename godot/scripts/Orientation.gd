extends Control
## North arrow + scale bar, drawn from the camera.

var main: Node
var scale_bar := true   # off in views with no meaningful scale (the chapter-4 microscope)


func _draw() -> void:
	if main == null:
		return
	var cam: Camera3D = main.camera.cam
	var font := ThemeDB.fallback_font
	# north arrow: world -Z is north; project its screen direction from the camera yaw
	var fwd := -cam.global_transform.basis.z
	var right := cam.global_transform.basis.x
	var north := Vector3(0, 0, -1)
	var sx := north.dot(right)
	var sy := north.dot(fwd)
	var ang := atan2(sx, sy)   # 0 = north straight ahead (up on screen)
	var c := Vector2(size.x - 40, 70)
	var dir := Vector2(sin(ang), -cos(ang))
	draw_circle(c, 22, Color(0.08, 0.09, 0.11, 0.8))
	draw_line(c - dir * 16, c + dir * 16, Color.WHITE, 2.0)
	draw_polygon(PackedVector2Array([c + dir * 18, c + dir * 6 + dir.orthogonal() * 5, c + dir * 6 - dir.orthogonal() * 5]), PackedColorArray([Color(1, 0.3, 0.2)]))
	draw_string(font, c + dir * 24 - Vector2(4, -4), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	# scale bar: metres per pixel at the ground point under the screen centre
	if not scale_bar:
		return
	var dist := _ground_distance(cam)
	var mpp := 2.0 * dist * tan(deg_to_rad(cam.fov) * 0.5) / get_viewport().get_visible_rect().size.y
	var nice := _nice(mpp * 120.0)
	var px := nice / maxf(mpp, 1.0e-9)
	var y := 108.0
	draw_rect(Rect2(size.x - 60 - px, y - 12, px + 8, 26), Color(0.08, 0.09, 0.11, 0.8))
	draw_line(Vector2(size.x - 56 - px, y), Vector2(size.x - 56, y), Color.WHITE, 3.0)
	draw_string(font, Vector2(size.x - 56 - px, y + 12), _fmt(nice), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _ground_distance(cam: Camera3D) -> float:
	var t: Node3D = main.terrain
	var o := cam.global_position
	var d := -cam.global_transform.basis.z
	var p := o
	if o.y <= t.height_at(o.x, o.z) * AppState.vexag or not t.visible:
		# underground (cut-face views) or no terrain (chapter W): the orbit target is the reference distance
		return maxf((o - main.camera.target).length(), 0.01)
	var step := maxf(1.0, absf(o.y - t.height_at(o.x, o.z) * AppState.vexag) * 0.02)
	for i in 3000:
		p += d * step
		if p.y <= t.height_at(p.x, p.z) * AppState.vexag:
			return (p - o).length()
	return maxf((o - main.camera.target).length(), 1.0)


static func _nice(v: float) -> float:
	var e := pow(10.0, floor(log(v) / log(10.0)))
	var m := v / e
	var n := 1.0
	if m >= 5.0:
		n = 5.0
	elif m >= 2.0:
		n = 2.0
	return n * e


static func _fmt(m: float) -> String:
	if m >= 1000.0:
		return _num(m / 1000.0) + " km"
	if m >= 1.0:
		return _num(m) + " m"
	if m >= 0.01:
		return _num(m * 100.0) + " cm"
	return _num(m * 1000.0) + " mm"


static func _num(v: float) -> String:
	return str(int(round(v))) if is_equal_approx(v, round(v)) else ("%.2f" % v)
