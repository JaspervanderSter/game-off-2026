class_name RedrawCheck
extends RefCounted
## Checks that canvas items which redraw only when their content changes
## (table, board, bench, side panels, shop column: see BoardView and Hud) did
## not miss a change. Freezes time, hides every layer that redraws each frame,
## grabs the screen, forces every canvas item to redraw and grabs it again: any
## difference comes from a cached layer that was out of date.
## Needs a rendering window. Used by perf_benchmark.gd and capture.gd with
## --check-redraw.


## Returns {"difference": largest colour difference (0 to 1), "where": screen
## position, "before": Image, "after": Image}.
static func run(game: Node) -> Dictionary:
	var tree := game.get_tree()
	var viewport := game.get_viewport()
	var previous_scale := Engine.time_scale
	Engine.time_scale = 0.0
	game._shake_t = 0.0 # the board keeps its current offset
	var hidden: Array[CanvasItem] = [game.fx, game.switch_flash, game.hud._layers.base.node,
		game.hud._layers.overlay.node, game.hud._layers.spotlight_glow.node, game.hud._layers.foreground.node]
	if game.battle != null:
		hidden.append(game.battle)
	var was_visible: Array[bool] = []
	for node in hidden:
		was_visible.append(node.visible)
		node.visible = false
	for i in 3:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var before := viewport.get_texture().get_image()
	game.propagate_call("queue_redraw")
	for i in 3:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var after := viewport.get_texture().get_image()
	for i in hidden.size():
		if is_instance_valid(hidden[i]):
			hidden[i].visible = was_visible[i]
	Engine.time_scale = previous_scale
	var worst := 0.0
	var where := Vector2i.ZERO
	var to_screen := Vector2(1280, 720) / Vector2(before.get_size())
	var fight_center := Rules.FIGHT_CENTER + Vector2(0, Hud.FIGHT_SLIDE * smoothstep(0.0, 1.0, float(game.shop_out)))
	for y in range(0, before.get_height(), 2):
		for x in range(0, before.get_width(), 2):
			var p := Vector2(x, y) * to_screen
			# The spinner and the glint on the fight button move with the clock.
			if p.distance_to(fight_center) < Rules.FIGHT_RADIUS + 14.0:
				continue
			var ca := before.get_pixel(x, y)
			var cb := after.get_pixel(x, y)
			var d := maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), absf(ca.b - cb.b))
			if d > worst:
				worst = d
				where = Vector2i(p)
	return {"difference": worst, "where": where, "before": before, "after": after}


## Whether a run() result shows an out-of-date layer.
static func is_stale(result: Dictionary) -> bool:
	return result.difference > 0.02
