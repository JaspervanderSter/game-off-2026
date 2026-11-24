extends Node
## Rendered cloud-cache regression: compare with the old curtain at fixed times,
## and verify that animation and tint changes never recreate its geometry.
var output := "user://cloud_cache"

func _ready() -> void:
	var script: Script = preload("res://scripts/ui/screen_transition.gd")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		if arg.begins_with("--reference="):
			script = load(arg.trim_prefix("--reference="))
	DirAccess.make_dir_recursive_absolute(output)
	var background := ColorRect.new()
	background.color = Color("354975")
	background.size = Vector2(2000, 2000)
	add_child(background)
	var curtain: Node2D = script.new()
	add_child(curtain)
	curtain.set_process(false)
	for portrait in 2:
		get_window().size = Vector2i(1280, 720) if portrait == 0 else Vector2i(680, 1180)
		for i in 3:
			await get_tree().process_frame
		for palette in 2:
			var tint := Color("d1dccf") if palette == 0 else Color("637087")
			curtain.play(Vector2.ZERO, Vector2.ZERO, func(): pass, tint)
			var mesh: Mesh
			if curtain is ScreenTransition:
				mesh = curtain._cloud_mesh
			var paints: Array[int] = []
			for step in 7:
				curtain.t = step * 0.22
				curtain._process(0.0)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(output.path_join("cloud_%d_%d_%d.png" % [portrait, palette, step]))
				if curtain is ScreenTransition:
					assert(curtain._cloud_mesh == mesh, "Cloud animation must reuse its mesh")
					for i in curtain._clouds.size():
						var node: Node2D = curtain._clouds[i].node
						if step == 0:
							paints.append(node.paints)
						else:
							assert(node.paints == paints[i], "Cloud motion must not re-record drawing commands")
			curtain._process(10.0)
			assert(not curtain.active())
	print("Cloud capture checks passed: landscape/portrait, day/night, cover/hold/reveal.")
	get_tree().quit()
