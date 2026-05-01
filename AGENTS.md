# EZ Tile Map Editor

A Godot 4.6 plugin that replaces the built-in TileMap bottom panel with a simpler terrain editing UI.

**Goal:** Make terrain painting on TileMapLayer nodes faster by providing a focused, always-visible bottom panel.

## Source map

- `addons/ez_tile_map_editor/plugin.cfg` — plugin registration
- `addons/ez_tile_map_editor/ez_tile_map_editor_plugin.gd` — hooks into editor selection, registers bottom panel, overrides built-in TileMap focus via deferred `make_bottom_panel_item_visible()`
- `addons/ez_tile_map_editor/ez_tile_map_editor_panel.tscn` + `.gd` — the bottom panel UI (empty placeholder, `current_tilemap` property wired)
- `addons/ez_tile_map_editor/ez_tile_map_editor_runtime.gd` — stub for eventual runtime terrain editing
