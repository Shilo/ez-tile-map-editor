@tool
extends EditorPlugin


var _panel: Control
var _button: Button


func _enter_tree() -> void:
	_panel = preload("res://addons/ez_tile_map_editor/ez_tile_map_editor_panel.tscn").instantiate()
	_button = add_control_to_bottom_panel(_panel, "EZ TileMap")
	_button.visible = false


func _exit_tree() -> void:
	if _panel:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null
	_button = null


func _handles(object: Object) -> bool:
	return object is TileMapLayer


func _edit(object: Object) -> void:
	if object is TileMapLayer:
		_panel.current_tilemap = object


func _make_visible(visible: bool) -> void:
	if visible and _button:
		_button.visible = true
		_button.button_pressed = true
		make_bottom_panel_item_visible(_panel)
		_ensure_visible_deferred.call_deferred()
	elif _button:
		_button.visible = false
		_button.button_pressed = false


func _ensure_visible_deferred() -> void:
	if _button and _button.button_pressed:
		make_bottom_panel_item_visible(_panel)


func _clear() -> void:
	_panel.current_tilemap = null
