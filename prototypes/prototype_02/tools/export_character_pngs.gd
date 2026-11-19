extends SceneTree
## Export the current procedural artwork using Godot's actual drawing code.
## Requires a rendering device (do not use --headless).
## godot --path prototypes/prototype_02 --minimized --script res://tools/export_character_pngs.gd

const Art = preload("res://scripts/ui/icons.gd")
const DB = preload("res://scripts/data/creature_db.gd")
const GameRules = preload("res://scripts/core/rules.gd")
const SIZES := [64, 512]
const VARIANTS := ["characters", "tokens_blue", "tokens_red"]
var output_dir := "res://../../docs/design/character_pngs"


func _initialize() -> void:
	_export.call_deferred()


func _export() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):
			output_dir = arg.trim_prefix("--output-dir=")
	output_dir = ProjectSettings.globalize_path(output_dir)
	var count := 0
	for size: int in SIZES:
		for variant: String in VARIANTS:
			var folder := output_dir.path_join(str(size)).path_join(variant)
			var err := DirAccess.make_dir_recursive_absolute(folder)
			if err != OK:
				push_error("Cannot create %s: %s" % [folder, error_string(err)])
				quit(1)
				return
			for id: String in DB.all_ids():
				var viewport := SubViewport.new()
				viewport.size = Vector2i(size, size)
				viewport.transparent_bg = true
				viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
				root.add_child(viewport)
				var canvas := Node2D.new()
				viewport.add_child(canvas)
				canvas.draw.connect(_draw_character.bind(canvas, id, size, variant))
				canvas.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var image := viewport.get_texture().get_image()
				err = image.save_png(folder.path_join(id + ".png"))
				viewport.queue_free()
				if err != OK:
					push_error("Cannot save %s: %s" % [id, error_string(err)])
					quit(1)
					return
				count += 1
	print("Exported %d character PNGs to %s" % [count, output_dir])
	quit()


func _draw_character(canvas: Node2D, id: String, size: int, variant: String) -> void:
	# Scale the entire canvas, including minimum line widths, from gameplay size.
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (float(size) / 64.0))
	var center := Vector2(32, 32)
	var radius: float = GameRules.BODY_RADIUS * GameRules.CELL
	if variant == "characters":
		Art.creature(canvas, id, center, radius * 0.92)
	else:
		Art.token(canvas, id, center, radius, 0 if variant == "tokens_blue" else 1)
