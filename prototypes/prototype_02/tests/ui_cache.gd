extends Node
## Fixed-time comparison of tutorial masks and reusable interface silhouettes.
## --reference uses saved pre-change scripts outside the project, for visual QA.
var output := "user://ui_cache"
var reference := false
var reference_dir := ""
var spotlight
var icons
var age := 0.0
var mask: Node2D
var art: Node2D
var glow: Node2D
var mask_paints := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		if arg.begins_with("--reference-dir="):
			reference = true
			reference_dir = arg.trim_prefix("--reference-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	spotlight = load(reference_dir.path_join("spotlight_reference.gd")).new() if reference else RuleSpotlight.new()
	icons = load(reference_dir.path_join("icons_reference.gd")) if reference else preload("res://scripts/ui/icons.gd")
	art = Node2D.new()
	art.draw.connect(_draw_art)
	add_child(art)
	mask = Node2D.new()
	mask.draw.connect(func():
		mask_paints += 1
		if reference:
			spotlight.draw(mask)
		else:
			spotlight.draw_mask(mask)
	)
	add_child(mask)
	if not reference:
		spotlight.prepare_mask(mask)
	glow = Node2D.new()
	glow.draw.connect(func():
		if not reference:
			spotlight.draw_glow(glow)
	)
	add_child(glow)
	for target in 3:
		spotlight.begin([Vector2(360, 360), Vector2(15, 80), Vector2(1120, 620)][target],
			[Vector2(80, 50), Vector2(46, 120), Vector2(170, 60)][target])
		for step in 5:
			age = [0.0, 0.1, 0.34, 0.8, 2.4][step]
			spotlight.time = age
			if reference:
				mask.queue_redraw()
			else:
				spotlight.update_mask(mask)
			glow.queue_redraw()
			art.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output.path_join("ui_%d_%d.png" % [target, step]))
		var paints := mask_paints
		var meshes: int = Shapes._polygon_meshes.size()
		for step in 5:
			spotlight.center += Vector2(1, -1)
			spotlight.radii += Vector2(1, 2)
			if not reference:
				spotlight.update_mask(mask)
			art.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		if not reference:
			assert(mask_paints == paints, "Tracking/focusing must retain the tutorial mask draw commands")
			assert(Shapes._polygon_meshes.size() == meshes, "Interface redraws must reuse polygon meshes")
	print("UI cache checks passed: tutorial fade, wide/tall/edge targets, moving/resizing targets, interface silhouettes.")
	get_tree().quit()

func _draw_art() -> void:
	art.draw_rect(Rect2(0, 0, 1280, 720), Color("657d9a"))
	for i in 16:
		art.draw_rect(Rect2(i * 80, 0, 40, 720), Color("839169"))
	var forms := ["rabbit", "peasant", "pyromancer", "archer", "guardian", "frost_mage"]
	for i in forms.size():
		icons.creature(art, forms[i], Vector2(160 + i * 180, 170), 42)
	for i in 3:
		icons.difficulty_hat(art, i, Vector2(250 + i * 330, 360), 65, age)
		icons.sword_and_wand(art, Vector2(250 + i * 330, 570), 50, i == 1)
		icons.gem(art, Vector2(250 + i * 330, 650), 20, Color.CORNFLOWER_BLUE)
		icons.charge_crystal(art, Vector2(300 + i * 330, 650), 18, i == 2, age / 2.75)
