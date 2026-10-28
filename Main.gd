extends Control

const COLORS: Array[Color] = [
	Color("#ff4757"), # красный
	Color("#2ed573"), # зелёный
	Color("#1e90ff"), # синий
	Color("#ffa502"), # оранжевый
	Color("#a55eea"), # фиолетовый
	Color("#00d2d3"), # бирюзовый
	Color("#ff6b81"), # розовый
	Color("#feca57"), # жёлтый
]

const AD_EVERY_N_LEVELS := 7   # показывать рекламу каждые N уровней

var bottles: Array[Bottle] = []
var selected: Bottle = null
var level := 1
var num_colors := 3
var num_empty := 2
var moves := 0
var _animating := false

var grid: GridContainer
var level_label: Label
var moves_label: Label
var win_panel: Control
var win_label: Label


func _ready() -> void:
	# Инициализация Yandex Games SDK
	_build_ui()
	_load_progress()
	_start_level()
	if YandexGames:
			YandexGames.game_ready()

# -------------------- UI --------------------
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#12121f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	# Верхняя панель
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 30)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(top)

	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 30)
	level_label.add_theme_color_override("font_color", Color("#ffffff"))
	top.add_child(level_label)

	moves_label = Label.new()
	moves_label.add_theme_font_size_override("font_size", 22)
	moves_label.add_theme_color_override("font_color", Color("#9aa0b4"))
	top.add_child(moves_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	top.add_child(spacer)

	var new_btn := Button.new()
	new_btn.text = "  Заново  "
	new_btn.add_theme_font_size_override("font_size", 18)
	new_btn.pressed.connect(_start_level)
	top.add_child(new_btn)

	# Центр — игровое поле
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	center.add_child(grid)

	# Подсказка снизу
	var hint := Label.new()
	hint.text = "Нажми на бутылку, затем на другую — чтобы перелить"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("#6b7290"))
	root.add_child(hint)

	_build_win_panel()


func _build_win_panel() -> void:
	win_panel = Control.new()
	win_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	win_panel.visible = false
	add_child(win_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_panel.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	for s in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 36)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 24)
	margin.add_child(vb)

	win_label = Label.new()
	win_label.add_theme_font_size_override("font_size", 32)
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(win_label)

	var btn := Button.new()
	btn.text = "Следующий уровень"
	btn.custom_minimum_size = Vector2(240, 54)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(_next_level)
	vb.add_child(btn)


# -------------------- Логика игры --------------------
func _start_level() -> void:
	if _animating:
		return

	for b in bottles:
		grid.remove_child(b)
		b.queue_free()
	bottles.clear()
	selected = null
	moves = 0
	win_panel.visible = false
	_update_labels()

	num_colors = clampi(2 + level, 3, COLORS.size())
	var total := num_colors + num_empty

	# Формируем пул цветов (по 4 каждого)
	var pool: Array[Color] = []
	for i in range(num_colors):
		for j in range(Bottle.CAPACITY):
			pool.append(COLORS[i])
	pool.shuffle()

	grid.columns = total if total <= 6 else 5

	for i in range(total):
		var b := Bottle.new()
		b.index = i
		if i < num_colors:
			for j in range(Bottle.CAPACITY):
				b.liquids.append(pool[i * Bottle.CAPACITY + j])
		b.clicked.connect(_on_bottle_clicked)
		grid.add_child(b)
		bottles.append(b)


func _on_bottle_clicked(bottle: Bottle) -> void:
	if win_panel.visible or _animating:
		return

	if selected == null:
		if bottle.liquids.is_empty():
			return
		_select(bottle)
	elif selected == bottle:
		_deselect()
	else:
		if _try_pour(selected, bottle):
			moves += 1
			_update_labels()
			_deselect()
		else:
			_deselect()
			if not bottle.liquids.is_empty():
				_select(bottle)


func _select(b: Bottle) -> void:
	selected = b
	b.selected = true


func _deselect() -> void:
	if selected:
		selected.selected = false
	selected = null


func _try_pour(from: Bottle, to: Bottle) -> bool:
	if from.liquids.is_empty():
		return false
	if to.liquids.size() >= Bottle.CAPACITY:
		return false

	var top_color: Color = from.liquids.back()
	if not to.liquids.is_empty() and to.liquids.back() != top_color:
		return false

	# Сколько подряд одинаковых сверху
	var count := 0
	for i in range(from.liquids.size() - 1, -1, -1):
		if from.liquids[i] == top_color:
			count += 1
		else:
			break

	var space := Bottle.CAPACITY - to.liquids.size()
	var amount := mini(count, space)

	_animating = true
	_do_pour_animation(from, to, amount, top_color)
	return true


func _do_pour_animation(from: Bottle, to: Bottle, amount: int, color: Color) -> void:
	var orig_pos := from.position
	var orig_rot := from.rotation
	var orig_pivot := from.pivot_offset

	# Куда наклоняемся — направление по X в локальных координатах грида
	var dx_sign := signf(to.position.x - orig_pos.x)
	if dx_sign == 0.0:
		dx_sign = 1.0

	# Точка вращения — низ бутылки по центру
	from.pivot_offset = Vector2(from.size.x * 0.5, from.size.y)
	from.z_index = 10
	to.z_index = 5

	# Точка, к которой поднимаемся и наклоняемся
	var target_pos := Vector2(
		orig_pos.x + (to.position.x - orig_pos.x) * 0.65,
		orig_pos.y - 30.0
	)
	var target_rot := dx_sign * 0.4   # ≈ 23°

	# 1) Подъём + наклон
	var t1 := create_tween()
	t1.set_parallel(true)
	t1.tween_property(from, "position", target_pos, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t1.tween_property(from, "rotation", target_rot, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t1.finished

	await get_tree().create_timer(0.1).timeout

	# 2) Мгновенно обновляем состояние жидкости
	for i in range(amount):
		from.liquids.pop_back()
		to.liquids.append(color)
	from.queue_redraw()
	to.queue_redraw()

	# «Пружинка» целевой бутылки
	to.pivot_offset = to.size * 0.5
	var pop := create_tween()
	pop.tween_property(to, "scale", Vector2(1.06, 0.95), 0.08)
	pop.tween_property(to, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.25).timeout

	# 3) Возврат на исходное место
	var t2 := create_tween()
	t2.set_parallel(true)
	t2.tween_property(from, "position", orig_pos, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t2.tween_property(from, "rotation", orig_rot, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t2.finished

	from.pivot_offset = orig_pivot
	from.z_index = 0
	to.z_index = 0

	_animating = false

	if _check_win():
		_show_win()


func _check_win() -> bool:
	for b in bottles:
		if b.liquids.is_empty():
			continue
		if b.liquids.size() != Bottle.CAPACITY:
			return false
		var c: Color = b.liquids[0]
		for col in b.liquids:
			if col != c:
				return false
	return true


func _update_labels() -> void:
	level_label.text = "Уровень %d" % level
	moves_label.text = "Ходы: %d" % moves


func _show_win() -> void:
	win_label.text = "Уровень %d пройден!\nХодов: %d" % [level, moves]
	win_panel.visible = true


func _next_level() -> void:
	level += 1
	_save_progress()

	# Каждые N уровней — межстраничная реклама
	if level % AD_EVERY_N_LEVELS == 0 and YandexGames:
		await YandexGames.show_interstitial()

	_start_level()


# -------------------- Yandex Games: сохранения --------------------
func _save_progress() -> void:
	if not YandexGames:
		return
	await YandexGames.player.set_data({ "level": level }, true)


func _load_progress() -> void:
	if not YandexGames:
		return
	var data: Dictionary = await YandexGames.player.get_data(["level"])
	if data.has("level"):
		level = maxi(1, int(data["level"]))
