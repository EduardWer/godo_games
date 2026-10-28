extends Control
class_name Bottle

signal clicked(bottle: Bottle)

const CAPACITY := 4
const BODY_WIDTH := 64.0
const BODY_HEIGHT := 200.0
const NECK_WIDTH := 34.0
const NECK_HEIGHT := 24.0
const SHOULDER_HEIGHT := 26.0
const BOTTOM_RADIUS := 16.0
const PADDING_BOTTOM := 14.0

var liquids: Array[Color] = []   # снизу вверх
var index := 0
var _hovered := false
var _pulse := 0.0

var selected := false:
	set(value):
		selected = value
		set_process(value)
		if not value:
			_pulse = 0.0
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(
		BODY_WIDTH + 24,
		BODY_HEIGHT + NECK_HEIGHT + SHOULDER_HEIGHT + PADDING_BOTTOM + 24
	)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	mouse_entered.connect(func() -> void: _hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hovered = false; queue_redraw())
	set_process(false)


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 5.0, TAU)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)


# -------------------- Рисование --------------------
func _draw() -> void:
	var lift := -14.0 if selected else 0.0
	var cx := size.x * 0.5
	var bottom_y := size.y - PADDING_BOTTOM + lift
	var body_top := bottom_y - BODY_HEIGHT
	var shoulder_top := body_top - SHOULDER_HEIGHT
	var neck_top := shoulder_top - NECK_HEIGHT
	var left := cx - BODY_WIDTH * 0.5
	var right := cx + BODY_WIDTH * 0.5
	var nw := NECK_WIDTH * 0.5
	var r := BOTTOM_RADIUS
	var slot_h := BODY_HEIGHT / float(CAPACITY)

	# Мягкая тень на «полу»
	if not selected:
		_draw_shadow(cx, size.y - PADDING_BOTTOM + 2)

	var outline := _build_outline(cx, bottom_y, body_top, shoulder_top, neck_top,
		left, right, nw, r)

	# Стекло (чуть голубоватое, полупрозрачное)
	draw_colored_polygon(outline, Color(0.78, 0.85, 1.0, 0.07))

	# Жидкость
	for i in range(liquids.size()):
		var c: Color = liquids[i]
		var y_top := bottom_y - (i + 1) * slot_h
		var y_bot := bottom_y - i * slot_h
		_draw_liquid_slot(left, right, y_top, y_bot, c, i == 0, r)

	# Мениск сверху жидкости
	if liquids.size() > 0:
		var top_y := bottom_y - liquids.size() * slot_h
		var top_col: Color = liquids[liquids.size() - 1]
		draw_line(Vector2(left + 2, top_y), Vector2(right - 2, top_y),
			top_col.lightened(0.35), 2.0)
		draw_line(Vector2(left + 2, top_y + 2), Vector2(right - 2, top_y + 2),
			top_col.darkened(0.15), 1.5)

	# Вертикальные блики на стекле
	draw_line(Vector2(left + 11, body_top + 14),
		Vector2(left + 11, bottom_y - r - 6),
		Color(1, 1, 1, 0.22), 6.0, true)
	draw_line(Vector2(left + 16, body_top + 18),
		Vector2(left + 16, bottom_y - r - 10),
		Color(1, 1, 1, 0.10), 3.0, true)
	draw_line(Vector2(right - 9, body_top + 14),
		Vector2(right - 9, bottom_y - r - 6),
		Color(0, 0, 0, 0.18), 5.0, true)

	# Блик на горлышке
	draw_line(Vector2(cx - nw + 5, neck_top + 4),
		Vector2(cx - nw + 5, shoulder_top),
		Color(1, 1, 1, 0.28), 2.5, true)

	# Контур
	var closed := outline.duplicate()
	closed.append(closed[0])
	var outline_col := Color(1, 0.85, 0.35, 0.95) if selected \
		else Color(1, 1, 1, 0.75 if _hovered else 0.5)
	draw_polyline(closed, outline_col, 2.5, true)

	# Ободок горлышка
	draw_line(Vector2(cx - nw - 3, neck_top), Vector2(cx + nw + 3, neck_top),
		Color(1, 1, 1, 0.75), 3.0)

	# Пульсация при выборе + стрелка сверху
	if selected:
		var p := 0.5 + 0.5 * sin(_pulse)
		draw_polyline(closed, Color(1, 0.85, 0.35, 0.15 + 0.35 * p), 8.0, true)
		var arrow_y := neck_top - 12.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 8, arrow_y - 8),
			Vector2(cx + 8, arrow_y - 8),
			Vector2(cx, arrow_y + 2)
		]), Color(1, 0.85, 0.35, 0.55 + 0.45 * p))


func _draw_shadow(cx: float, y: float) -> void:
	var rx := BODY_WIDTH * 0.55
	var ry := 5.0
	var seg := 22
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		pts.append(Vector2(cx + cos(a) * rx, y + sin(a) * ry))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.35))


func _draw_liquid_slot(left: float, right: float, y_top: float, y_bot: float,
		c: Color, is_bottom: bool, r: float) -> void:
	if not is_bottom:
		draw_rect(Rect2(left, y_top, right - left, y_bot - y_top), c)
		# лёгкий объём
		draw_rect(Rect2(right - 10, y_top, 10, y_bot - y_top), c.darkened(0.15))
		draw_rect(Rect2(left + 8, y_top, 6, y_bot - y_top), c.lightened(0.15))
	else:
		var pts := PackedVector2Array()
		pts.append(Vector2(left, y_top))
		pts.append(Vector2(right, y_top))
		pts.append(Vector2(right, y_bot - r))
		var brc := Vector2(right - r, y_bot - r)
		for i in range(1, 9):
			var a: float = lerp(0.0, PI * 0.5, float(i) / 8.0)
			pts.append(brc + Vector2(cos(a), sin(a)) * r)
		var blc := Vector2(left + r, y_bot - r)
		for i in range(1, 9):
			var a: float = lerp(PI * 0.5, PI, float(i) / 8.0)
			pts.append(blc + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, c)


func _build_outline(cx: float, bottom_y: float, body_top: float,
		shoulder_top: float, neck_top: float,
		left: float, right: float, nw: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(cx - nw, neck_top))
	pts.append(Vector2(cx + nw, neck_top))
	pts.append(Vector2(cx + nw, shoulder_top))

	# Правое «плечо» — сглаженный переход от горлышка к корпусу
	for i in range(1, 9):
		var t := float(i) / 8.0
		pts.append(_quad_bezier(
			Vector2(cx + nw, shoulder_top),
			Vector2(right, shoulder_top),
			Vector2(right, body_top), t))

	pts.append(Vector2(right, bottom_y - r))

	# Скругление правого нижнего угла
	var brc := Vector2(right - r, bottom_y - r)
	for i in range(1, 9):
		var a: float = lerp(0.0, PI * 0.5, float(i) / 8.0)
		pts.append(brc + Vector2(cos(a), sin(a)) * r)

	# Скругление левого нижнего угла
	var blc := Vector2(left + r, bottom_y - r)
	for i in range(1, 9):
		var a: float = lerp(PI * 0.5, PI, float(i) / 8.0)
		pts.append(blc + Vector2(cos(a), sin(a)) * r)

	pts.append(Vector2(left, body_top))

	# Левое «плечо»
	for i in range(1, 9):
		var t := float(i) / 8.0
		pts.append(_quad_bezier(
			Vector2(left, body_top),
			Vector2(left, shoulder_top),
			Vector2(cx - nw, shoulder_top), t))

	return pts


func _quad_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2
