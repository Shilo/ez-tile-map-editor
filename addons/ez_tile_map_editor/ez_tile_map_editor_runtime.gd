extends CanvasLayer
class_name EZTileMapEditorRuntime

enum ActivationEdge { TOP, BOTTOM, LEFT, RIGHT }

const DEFAULT_INPUT_BINDINGS := {
	"ez_tile_select": KEY_S,
	"ez_tile_draw": KEY_D,
	"ez_tile_line": KEY_L,
	"ez_tile_rect": KEY_R,
	"ez_tile_fill": KEY_B,
	"ez_tile_pick": KEY_P,
	"ez_tile_erase": KEY_E,
}

const PANEL_SCENE := preload("res://addons/ez_tile_map_editor/ez_tile_map_editor_panel.tscn")

@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_inside_tree():
			_root.visible = enabled

@export var activation_edge: ActivationEdge = ActivationEdge.BOTTOM:
	set(value):
		activation_edge = value
		if is_inside_tree():
			_layout_dock()

@export_range(1, 256, 1, "or_greater") var activation_thickness_px: int = 12
@export_range(64.0, 2048.0, 1.0, "or_greater") var dock_size_px: float = 160.0:
	set(value):
		dock_size_px = value
		if is_inside_tree():
			_layout_dock()

@export_range(0.0, 2.0, 0.01) var animation_duration: float = 0.15
@export var start_open: bool = false
@export var show_close_button: bool = true:
	set(value):
		show_close_button = value
		if _close_button:
			_close_button.visible = show_close_button

@export var excluded_controls: Array[NodePath] = []
@export var excluded_rects: Array[Rect2] = []
@export var discover_root_path: NodePath
@export var install_default_input_actions: bool = false
@export var grid_enabled: bool = true:
	set(value):
		grid_enabled = value
		if _panel:
			_panel.runtime_grid_enabled = value
			_queue_overlay_redraw()

@export var layer_highlight_enabled: bool = false:
	set(value):
		layer_highlight_enabled = value
		if _panel:
			_panel.runtime_layer_highlight_enabled = value
			_queue_overlay_redraw()

@export var grid_color: Color = Color(1.0, 0.5, 0.2, 0.5):
	set(value):
		grid_color = value
		if _panel:
			_panel.runtime_grid_color = value
			_queue_overlay_redraw()

var _root: Control
var _overlay: Control
var _dock: PanelContainer
var _chrome: HBoxContainer
var _close_button: Button
var _panel: Control
var _undo_redo := UndoRedo.new()
var _layers: Array[TileMapLayer] = []
var _is_open := false
var _hover_armed := true
var _tween: Tween


class RuntimeOverlay extends Control:
	var host: EZTileMapEditorRuntime

	func _draw() -> void:
		if host:
			host._draw_runtime_overlay(self)


func _ready() -> void:
	layer = 100
	if install_default_input_actions:
		_setup_default_input_actions()

	_build_nodes()
	get_viewport().size_changed.connect(_layout_dock)
	refresh_layers()
	_layout_dock()

	if start_open:
		open(false)
	else:
		close(false)


func _process(_delta: float) -> void:
	if not enabled or _is_open:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var in_zone := _is_in_activation_zone(mouse_pos)
	if not in_zone:
		_hover_armed = true
		return
	if _hover_armed and not _is_excluded_position(mouse_pos):
		open()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not _is_open or not _panel:
		return
	if _panel.canvas_input(event):
		get_viewport().set_input_as_handled()
		_queue_overlay_redraw()


func refresh_layers() -> void:
	_layers.clear()
	var root := _get_discover_root()
	if root:
		_collect_visible_tilemap_layers(root, _layers)
	if _panel:
		if _panel.tilemap == null or not _layers.has(_panel.tilemap):
			_panel.tilemap = _layers[0] if not _layers.is_empty() else null
		_panel.about_to_be_visible()


func set_tilemap(layer: TileMapLayer) -> void:
	if not _panel:
		return
	if layer and not _layers.has(layer):
		_layers.append(layer)
	_panel.tilemap = layer
	_panel.about_to_be_visible()
	_queue_overlay_redraw()


func set_editing_enabled(value: bool) -> void:
	enabled = value


func open(animated: bool = true) -> void:
	if not enabled:
		return
	_is_open = true
	_hover_armed = true
	_move_dock(_get_open_position(), animated)


func close(animated: bool = true) -> void:
	_is_open = false
	_hover_armed = not _is_in_activation_zone(get_viewport().get_mouse_position())
	if _panel:
		_panel.canvas_mouse_exited()
	_move_dock(_get_closed_position(), animated)


func undo() -> void:
	if _undo_redo.has_undo():
		_undo_redo.undo()
		_queue_overlay_redraw()


func redo() -> void:
	if _undo_redo.has_redo():
		_undo_redo.redo()
		_queue_overlay_redraw()


func _build_nodes() -> void:
	_root = Control.new()
	_root.name = "EZTileMapRuntimeRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = enabled
	add_child(_root)

	var overlay := RuntimeOverlay.new()
	overlay.name = "Overlay"
	overlay.host = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(overlay)
	_overlay = overlay

	_dock = PanelContainer.new()
	_dock.name = "Dock"
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dock)

	var layout := VBoxContainer.new()
	layout.name = "RuntimeDockLayout"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock.add_child(layout)

	_chrome = HBoxContainer.new()
	_chrome.name = "RuntimeDockChrome"
	_chrome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_chrome)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chrome.add_child(spacer)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "Close"
	_close_button.visible = show_close_button
	_close_button.pressed.connect(close)
	_chrome.add_child(_close_button)

	_panel = PANEL_SCENE.instantiate()
	_panel.runtime_mode = true
	_panel.undo_manager = _undo_redo
	_panel.runtime_grid_enabled = grid_enabled
	_panel.runtime_layer_highlight_enabled = layer_highlight_enabled
	_panel.runtime_grid_color = grid_color
	_panel.layer_provider = Callable(self, "_get_layers_for_panel")
	_panel.layer_selected_callback = Callable(self, "_on_panel_layer_selected")
	_panel.canvas_transform_provider = Callable(self, "_get_canvas_transform_for_panel")
	_panel.viewport_size_provider = Callable(self, "_get_viewport_size_for_panel")
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.update_overlay.connect(_queue_overlay_redraw)
	layout.add_child(_panel)


func _layout_dock() -> void:
	if not _root or not _dock:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var side_dock := activation_edge == ActivationEdge.LEFT or activation_edge == ActivationEdge.RIGHT
	if side_dock:
		_dock.size = Vector2(dock_size_px, viewport_size.y)
	else:
		_dock.size = Vector2(viewport_size.x, dock_size_px)
	if _panel:
		_panel.custom_minimum_size = Vector2(dock_size_px, 0.0) if side_dock else Vector2(0.0, dock_size_px)
	_dock.position = _get_open_position() if _is_open else _get_closed_position()
	_queue_overlay_redraw()


func _get_open_position() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	match activation_edge:
		ActivationEdge.TOP:
			return Vector2.ZERO
		ActivationEdge.BOTTOM:
			return Vector2(0.0, viewport_size.y - _dock.size.y)
		ActivationEdge.LEFT:
			return Vector2.ZERO
		ActivationEdge.RIGHT:
			return Vector2(viewport_size.x - _dock.size.x, 0.0)
	return Vector2.ZERO


func _get_closed_position() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	match activation_edge:
		ActivationEdge.TOP:
			return Vector2(0.0, -_dock.size.y)
		ActivationEdge.BOTTOM:
			return Vector2(0.0, viewport_size.y)
		ActivationEdge.LEFT:
			return Vector2(-_dock.size.x, 0.0)
		ActivationEdge.RIGHT:
			return Vector2(viewport_size.x, 0.0)
	return Vector2.ZERO


func _move_dock(position: Vector2, animated: bool) -> void:
	if not _dock:
		return
	if _tween:
		_tween.kill()
	if not animated or animation_duration <= 0.0:
		_dock.position = position
		return
	_tween = create_tween()
	_tween.tween_property(_dock, "position", position, animation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _is_in_activation_zone(pos: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	var thickness := max(1.0, float(activation_thickness_px))
	match activation_edge:
		ActivationEdge.TOP:
			return pos.y <= thickness
		ActivationEdge.BOTTOM:
			return pos.y >= viewport_size.y - thickness
		ActivationEdge.LEFT:
			return pos.x <= thickness
		ActivationEdge.RIGHT:
			return pos.x >= viewport_size.x - thickness
	return false


func _is_excluded_position(pos: Vector2) -> bool:
	for rect in excluded_rects:
		if rect.has_point(pos):
			return true
	for path in excluded_controls:
		if path.is_empty():
			continue
		var node := get_node_or_null(path)
		if node is Control and node.visible and node.get_global_rect().has_point(pos):
			return true
	return false


func _get_discover_root() -> Node:
	if not discover_root_path.is_empty():
		var configured := get_node_or_null(discover_root_path)
		if configured:
			return configured
	if get_tree() and get_tree().current_scene:
		return get_tree().current_scene
	var parent_root: Node = self
	while parent_root.get_parent():
		parent_root = parent_root.get_parent()
	return parent_root


func _collect_visible_tilemap_layers(node: Node, result: Array[TileMapLayer]) -> void:
	if node is TileMapLayer and node.visible:
		result.append(node)
	for child in node.get_children():
		_collect_visible_tilemap_layers(child, result)


func _get_layers_for_panel() -> Array[TileMapLayer]:
	refresh_layers()
	return _layers


func _on_panel_layer_selected(layer: TileMapLayer) -> void:
	set_tilemap(layer)


func _get_canvas_transform_for_panel(layer: TileMapLayer) -> Transform2D:
	if not layer:
		return Transform2D.IDENTITY
	return layer.get_viewport_transform() * layer.global_transform


func _get_viewport_size_for_panel() -> Vector2:
	return get_viewport().get_visible_rect().size


func _draw_runtime_overlay(target: Control) -> void:
	if not enabled or not _panel:
		return
	_panel.canvas_draw(target)
	if layer_highlight_enabled and _panel.tilemap:
		_draw_layer_highlight(target, _panel.tilemap)


func _draw_layer_highlight(target: Control, layer: TileMapLayer) -> void:
	var used_rect := layer.get_used_rect()
	if not used_rect.has_area() or not layer.tile_set:
		return
	var tform := _get_canvas_transform_for_panel(layer)
	var cell_size := Vector2(layer.tile_set.tile_size)
	var top_left := tform * layer.map_to_local(used_rect.position)
	var bottom_right_cell := used_rect.position + used_rect.size - Vector2i.ONE
	var bottom_right := tform * layer.map_to_local(bottom_right_cell)
	var rect := Rect2(top_left, bottom_right - top_left).abs()
	rect = rect.grow(max(cell_size.x, cell_size.y) * 0.5)
	target.draw_rect(rect, Color(0.3, 0.7, 1.0, 0.25), false, 2.0)


func _queue_overlay_redraw() -> void:
	if _overlay:
		_overlay.queue_redraw()


func _setup_default_input_actions() -> void:
	for action: String in DEFAULT_INPUT_BINDINGS:
		if InputMap.has_action(action):
			continue
		var ev := InputEventKey.new()
		ev.keycode = DEFAULT_INPUT_BINDINGS[action]
		ev.command_or_control_autoremap = false
		InputMap.add_action(action)
		InputMap.action_add_event(action, ev)
