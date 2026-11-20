extends SceneTree
## Draws the shape atlas (Shapes.build_image) into ui/shapes_atlas.png, which
## the game loads with mipmaps instead of drawing it at startup. Run it after
## changing the shapes in scripts/ui/shapes.gd; the tests fail until it is run:
##
##   godot --headless --path . --script res://tools/make_shapes_atlas.gd


func _init() -> void:
	var image := Shapes.build_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Shapes.ATLAS_FILE.get_base_dir()))
	var error := image.save_png(Shapes.ATLAS_FILE)
	if error != OK:
		push_error("Cannot write %s: %s" % [Shapes.ATLAS_FILE, error_string(error)])
		quit(1)
		return
	print("Wrote ", Shapes.ATLAS_FILE)
	quit()
