@tool
extends PanelContainer

class_name MovementTrackEditorPanel

const PANEL_WIDTH := 320.0

var movement: MovementModule
var scroll: ScrollContainer
var root_layout: VBoxContainer
var overlay: Control
var duration_axis_buttons: Array[Button] = []
var duration_spin: SpinBox
var collision_option: OptionButton
var x_graph: CurveGraph
var y_graph: CurveGraph
var header: HBoxContainer
var dragging := false
var user_positioned := false
var resize_mode := ""
var resize_mouse := Vector2.ZERO
var resize_size := Vector2.ZERO
var resize_position := Vector2.ZERO
var drag_origin := Vector2.ZERO
var panel_origin := Vector2.ZERO
var number_dialog: AcceptDialog
var number_spin: SpinBox
var number_callback: Callable


class CurveGraph extends Control:
	var curve: Curve
	var duration := 0.2
	var value_range := 100.0
	var view_zoom := 1.0
	var view_pan := Vector2.ZERO
	var panning := false
	var pan_mouse := Vector2.ZERO
	var pan_origin := Vector2.ZERO

	func _ready() -> void:
		custom_minimum_size = Vector2(270, 132)
		mouse_filter = Control.MOUSE_FILTER_STOP
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.05, 0.5), true)
		var left := 28.0
		var right := size.x - 10.0
		var top := 10.0
		var bottom := size.y - 22.0
		var graph_size := Vector2(right - left, bottom - top)
		if graph_size.x <= 0.0 or graph_size.y <= 0.0:
			return

		for i in range(5):
			var x := left + graph_size.x * float(i) / 4.0
			draw_line(Vector2(x, top), Vector2(x, bottom), Color(0.5, 0.58, 0.68, 0.16), 1.0)
		for i in range(5):
			var y := top + graph_size.y * float(i) / 4.0
			draw_line(Vector2(left, y), Vector2(right, y), Color(0.5, 0.58, 0.68, 0.16), 1.0)

		var zero_y := top + graph_size.y * 0.5
		draw_line(Vector2(left, zero_y), Vector2(right, zero_y), Color(0.8, 0.84, 0.9, 0.6), 1.2)
		draw_line(Vector2(left, top), Vector2(left, bottom), Color(0.8, 0.84, 0.9, 0.6), 1.2)

		draw_string(ThemeDB.fallback_font, Vector2(2, top + 4), "%+.0f" % value_range, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.78, 0.84, 0.92))
		draw_string(ThemeDB.fallback_font, Vector2(2, bottom), "%+.0f" % -value_range, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.78, 0.84, 0.92))
		draw_string(ThemeDB.fallback_font, Vector2(left, size.y - 5), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.78, 0.84, 0.92))
		draw_string(ThemeDB.fallback_font, Vector2(right - 38, size.y - 5), "%.2fs" % duration, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.78, 0.84, 0.92))

		if curve == null:
			return
		var points := PackedVector2Array()
		for i in range(65):
			var progress := float(i) / 64.0
			var value := curve.sample_baked(progress)
			var x := left + (progress * view_zoom + view_pan.x) * graph_size.x
			var y := zero_y - clampf(value / maxf(value_range, 0.01), -1.0, 1.0) * graph_size.y * 0.5 * view_zoom + view_pan.y
			points.append(Vector2(x, y))
		if points.size() > 1:
			draw_polyline(points, Color(0.3, 0.92, 0.74, 0.95), 2.0, true)

	func set_curve(value: Curve, track_duration: float, axis_range: float) -> void:
		curve = value
		duration = maxf(track_duration, 0.01)
		value_range = maxf(axis_range, 1.0)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var button := event as InputEventMouseButton
			if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
				view_zoom = minf(view_zoom * 1.12, 4.0)
				queue_redraw()
				accept_event()
			elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
				view_zoom = maxf(view_zoom / 1.12, 0.5)
				queue_redraw()
				accept_event()
			elif button.button_index == MOUSE_BUTTON_MIDDLE:
				if button.pressed:
					panning = true
					pan_mouse = button.position
					pan_origin = view_pan
				else:
					panning = false
				accept_event()

	func _input(event: InputEvent) -> void:
		if not panning:
			return
		if event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			view_pan = pan_origin + motion.position - pan_mouse
			queue_redraw()
		elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(PANEL_WIDTH, 320)
	size = Vector2(PANEL_WIDTH, 430)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.085, 0.78)
	style.border_color = Color(0.48, 0.56, 0.68, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	root_layout = VBoxContainer.new()
	root_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(root_layout)
	header = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_header_input)
	root_layout.add_child(header)
	var title := Label.new()
	title.text = "MovementTrack"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var hint := Label.new()
	hint.text = "拖动"
	hint.add_theme_font_size_override("font_size", 10)
	header.add_child(hint)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var duration_row := HBoxContainer.new()
	content.add_child(duration_row)
	duration_row.add_child(_make_label("持续时间"))
	duration_spin = SpinBox.new()
	duration_spin.min_value = 0.01
	duration_spin.max_value = 5.0
	duration_spin.step = 0.01
	duration_spin.value = 0.2
	duration_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration_spin.value_changed.connect(_on_duration_changed)
	duration_row.add_child(duration_spin)

	var collision_row := HBoxContainer.new()
	content.add_child(collision_row)
	collision_row.add_child(_make_label("碰撞策略"))
	collision_option = OptionButton.new()
	collision_option.add_item("BLOCK", MovementModule.MovementCollisionStrategy.BLOCK)
	collision_option.add_item("IGNORE_WORLD", MovementModule.MovementCollisionStrategy.IGNORE_WORLD)
	collision_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collision_option.item_selected.connect(_on_collision_changed)
	collision_row.add_child(collision_option)

	x_graph = CurveGraph.new()
	content.add_child(_make_graph_section("Track_X（面向方向为正）", x_graph, true))
	y_graph = CurveGraph.new()
	content.add_child(_make_graph_section("Track_Y（向上为正）", y_graph, false))

	number_dialog = AcceptDialog.new()
	number_dialog.title = "输入数值"
	get_parent().add_child(number_dialog)

	_create_resize_grips()

	number_spin = SpinBox.new()
	number_spin.min_value = 0.01
	number_spin.max_value = 100000.0
	number_spin.step = 1.0
	number_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	number_dialog.add_child(number_spin)
	number_dialog.confirmed.connect(_on_number_confirmed)


func _make_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.custom_minimum_size.x = 92
	return label


func _make_graph_section(title_text: String, graph: CurveGraph, _is_x: bool) -> VBoxContainer:
	var section := VBoxContainer.new()
	var heading := HBoxContainer.new()
	section.add_child(heading)
	var title := Label.new()
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var range_button := Button.new()
	range_button.flat = true
	range_button.text = "+100"
	heading.add_child(range_button)
	section.add_child(graph)
	var footer := HBoxContainer.new()
	section.add_child(footer)
	var lower_range_button := Button.new()
	lower_range_button.flat = true
	lower_range_button.text = "-100"
	range_button.pressed.connect(_on_range_button_pressed.bind(graph, range_button, lower_range_button))
	lower_range_button.pressed.connect(_on_range_button_pressed.bind(graph, range_button, lower_range_button))
	footer.add_child(lower_range_button)
	var start_label := Label.new()
	start_label.text = "时间 0"
	footer.add_child(start_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var end_button := Button.new()
	end_button.flat = true
	end_button.text = "0.20s"
	end_button.pressed.connect(_on_duration_axis_pressed)
	footer.add_child(end_button)
	duration_axis_buttons.append(end_button)
	return section


func set_movement(value: MovementModule) -> void:
	visible = value != null
	if movement == value:
		return
	if movement != null and movement.changed.is_connected(_refresh):
		movement.changed.disconnect(_refresh)
	movement = value
	if not is_node_ready() or movement == null:
		return
	if not movement.changed.is_connected(_refresh):
		movement.changed.connect(_refresh)
	if movement.movement_track_x != null and not movement.movement_track_x.changed.is_connected(_refresh):
		movement.movement_track_x.changed.connect(_refresh)
	if movement.movement_track_y != null and not movement.movement_track_y.changed.is_connected(_refresh):
		movement.movement_track_y.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if movement == null:
		return
	if movement.movement_track_x != null:
		movement.movement_track_x.bake_resolution = 8
		if not movement.movement_track_x.changed.is_connected(_refresh):
			movement.movement_track_x.changed.connect(_refresh)
	if movement.movement_track_y != null:
		movement.movement_track_y.bake_resolution = 8
		if not movement.movement_track_y.changed.is_connected(_refresh):
			movement.movement_track_y.changed.connect(_refresh)
	duration_spin.set_value_no_signal(movement.movement_track_duration)
	for axis_button in duration_axis_buttons:
		axis_button.text = "%.2fs" % movement.movement_track_duration
	collision_option.select(int(movement.movement_track_collision_strategy))
	x_graph.set_curve(movement.movement_track_x, movement.movement_track_duration, x_graph.value_range)
	y_graph.set_curve(movement.movement_track_y, movement.movement_track_duration, y_graph.value_range)
func _on_duration_changed(value: float) -> void:
	if movement == null:
		return
	movement.movement_track_duration = value
	movement.emit_changed()
	_refresh()


func _on_collision_changed(index: int) -> void:
	if movement == null:
		return
	movement.movement_track_collision_strategy = collision_option.get_item_id(index)
	movement.emit_changed()


func _on_range_button_pressed(graph: CurveGraph, button: Button, opposite_button: Button) -> void:
	_open_number_dialog("纵轴最大位移绝对值", graph.value_range, 1.0, 100000.0, func(value: float) -> void:
		graph.value_range = value
		button.text = "+%.0f" % value
		opposite_button.text = "-%.0f" % value
		graph.queue_redraw()
	)


func _on_duration_axis_pressed() -> void:
	if movement == null:
		return
	_open_number_dialog("时间范围（秒）", movement.movement_track_duration, 0.01, 5.0, func(value: float) -> void:
		duration_spin.value = value
		_on_duration_changed(value)
	)


func _open_number_dialog(title_text: String, current_value: float, min_value: float, max_value: float, callback: Callable) -> void:
	number_dialog.title = title_text
	number_spin.min_value = min_value
	number_spin.max_value = max_value
	number_spin.value = current_value
	number_callback = callback
	number_dialog.popup_centered(Vector2i(300, 100))


func _on_number_confirmed() -> void:
	if number_callback.is_valid():
		number_callback.call(number_spin.value)


func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_origin = get_global_mouse_position()
			panel_origin = position
			header.accept_event()
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		header.accept_event()


func _process(_delta: float) -> void:
	if dragging:
		position = panel_origin + get_global_mouse_position() - drag_origin
		user_positioned = true
	if not resize_mode.is_empty():
		var mouse_delta := get_global_mouse_position() - resize_mouse
		var next_width := resize_size.x
		var next_height := resize_size.y
		if resize_mode == "left":
			next_width = clampf(resize_size.x - mouse_delta.x, 280.0, 620.0)
			position.x = resize_position.x + resize_size.x - next_width
		elif resize_mode == "right" or resize_mode == "corner":
			next_width = clampf(resize_size.x + mouse_delta.x, 280.0, 620.0)
		if resize_mode == "bottom" or resize_mode == "corner":
			next_height = clampf(resize_size.y + mouse_delta.y, 300.0, 760.0)
		size = Vector2(next_width, next_height)
		custom_minimum_size = Vector2(next_width, 300.0)
	if not user_positioned and get_parent() != null and get_parent().size.x > size.x + 24.0:
		position.x = get_parent().size.x - size.x - 12.0


func _create_resize_grips() -> void:
	_create_resize_grip("bottom", Control.CURSOR_VSIZE, 0.0, 1.0, 1.0, 1.0, 8.0, -8.0, -6.0, 0.0)
	_create_resize_grip("left", Control.CURSOR_HSIZE, 0.0, 0.0, 0.0, 1.0, 0.0, 6.0, 8.0, -8.0)
	_create_resize_grip("right", Control.CURSOR_HSIZE, 1.0, 1.0, 0.0, 1.0, -6.0, 0.0, 8.0, -8.0)
	_create_resize_grip("corner", Control.CURSOR_FDIAGSIZE, 1.0, 1.0, 1.0, 1.0, -12.0, 0.0, -12.0, 0.0)


func _create_resize_grip(mode: String, cursor: int, left_anchor: float, right_anchor: float, top_anchor: float, bottom_anchor: float, left_offset: float, right_offset: float, top_offset: float, bottom_offset: float) -> void:
	var grip := Control.new()
	grip.name = "ResizeGrip_" + mode
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	grip.mouse_default_cursor_shape = cursor
	grip.anchor_left = left_anchor
	grip.anchor_right = right_anchor
	grip.anchor_top = top_anchor
	grip.anchor_bottom = bottom_anchor
	grip.offset_left = left_offset
	grip.offset_right = right_offset
	grip.offset_top = top_offset
	grip.offset_bottom = bottom_offset
	grip.gui_input.connect(_on_resize_input.bind(mode))
	overlay.add_child(grip)


func _on_resize_input(event: InputEvent, mode: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			resize_mode = mode
			user_positioned = true
			resize_mouse = get_global_mouse_position()
			resize_size = size
			resize_position = position
		else:
			resize_mode = ""
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not resize_mode.is_empty():
		get_viewport().set_input_as_handled()
