extends Node
## Frame-time benchmark: plays the real game in a rendering window (menus,
## preparation, automated duels and a crowded 6-versus-6 fight), records every
## frame and reports averages, percentiles, spikes and resource growth.
## Needs a rendering window (not --headless). From prototypes/prototype_02:
##   godot --path . res://tests/perf_benchmark.tscn -- [options]
## Options (after --):
##   --out=<file.json>  where to write the per-frame report (default user://perf/)
##   --vsync            keep vertical sync on (measures dropped frames at the
##                      display refresh); by default vsync is off and the frame
##                      rate uncapped, which measures the true cost of a frame
##   --rounds=<n>       duel rounds to play (default 6)
##   --vector-art       vector art instead of pixel art
##   --check-redraw     every 1.5 s, freeze time, force every cached layer to
##                      redraw and check the screen did not change (a cached
##                      layer that missed a change shows up as a difference)
##   --no-sound         no sound (the game's own option)
##   --map-pan          title-to-map pans, removing components one at a time
##   --map-pan-cache-only  pans with island draw commands retained instead of rebuilt
##   --cloud-transition three map/level round trips, without playing any duels
##   --ui-effects       shop, fixed and moving tutorial spotlights; no duels

const SPIKE_MS := 1000.0 / 60.0 # a frame missing the 60 Hz deadline
const BIG_SPIKE_MS := 1000.0 / 30.0

var game: Node
var out_path := ""
var vsync := false
var rounds := 6
var scenario := "boot"
## Per-frame columns in packed arrays: recording costs about a hundred bytes per
## frame, so it barely distorts the memory figures it reports.
const COLUMNS := ["t", "frame_ms", "process_ms", "physics_ms", "render_cpu_ms", "render_gpu_ms",
	"draw_calls", "primitives", "nodes", "objects", "orphans", "memory_mb", "units", "fx", "audio_gaps"]
## Web only: audio quanta (128 samples) the browser played as silence because the
## main thread had not mixed them in time, counted by an instrumented audio
## worklet in window.__audioUnderruns (see README, "Tests"). Zero elsewhere.
var _audio_gaps_seen := 0
var columns := {}
var scenario_of := PackedInt32Array()
var scenario_names: Array[String] = []
var frame_marks := {} # frame index -> events that happened just before it
var marks: Array[String] = [] # events attached to the next recorded frame
var _last_usec := 0
var _textures_seen := 0
var _vp_rid: RID
var _hover_unit: Variant = null
var _hover_until := 0.0
var _rng := RandomNumberGenerator.new()
var check_redraw := false
var redraw_checks := 0
var redraw_failures: Array[String] = []
var _running := true
var _checking := false


func _ready() -> void:
	process_priority = 1000 # after the game: frame records see its work done
	_rng.seed = 1234
	var dir := "user://perf"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg == "--vsync":
			vsync = true
		elif arg == "--check-redraw":
			check_redraw = true
		elif arg.begins_with("--rounds="):
			rounds = int(arg.trim_prefix("--rounds="))
	if out_path == "":
		DirAccess.make_dir_recursive_absolute(dir)
		out_path = dir.path_join("perf_%s.json" % ("vsync" if vsync else "uncapped"))
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	# Scratch save files: never the player's decks, art style or progress.
	var scratch := OS.get_temp_dir().path_join("perf_benchmark_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(scratch)
	PackDeck.save_path = scratch.path_join("pack_decks.cfg")
	ArtStyle.save_path = scratch.path_join("art_style.cfg")
	ArtStyle.set_style(ArtStyle.Style.VECTOR if "--vector-art" in OS.get_cmdline_user_args() else ArtStyle.Style.PIXEL)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	game = load("res://main.tscn").instantiate()
	game.difficulty_progress_path = scratch.path_join("difficulty_progress.cfg")
	add_child(game)
	if check_redraw:
		_redraw_checker()
	await _run()
	_running = false
	_report()
	get_tree().quit()


func _process(_dt: float) -> void:
	_drive_hover()
	var now := Time.get_ticks_usec()
	if _last_usec == 0:
		_last_usec = now
		return
	var frame_ms := (now - _last_usec) / 1000.0
	_last_usec = now
	var textures: int = ArtStyle._textures.size()
	if textures != _textures_seen:
		marks.append("sprite_load+%d" % (textures - _textures_seen))
		_textures_seen = textures
	var record := {
		"t": now / 1e6,
		"frame_ms": frame_ms,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid),
		"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"units": game.battle.units.size() if game.battle != null else 0,
		"fx": game.fx.items.size(),
		"audio_gaps": _audio_gaps(),
	}
	if record.audio_gaps > 0:
		marks.append("audio_gap+%d" % record.audio_gaps)
	if columns.is_empty():
		for key in COLUMNS:
			columns[key] = PackedFloat64Array()
	for key in COLUMNS:
		columns[key].append(float(record[key]))
	var s := scenario_names.find(scenario)
	if s < 0:
		s = scenario_names.size()
		scenario_names.append(scenario)
	if not marks.is_empty():
		frame_marks[scenario_of.size()] = marks.duplicate()
		marks.clear()
	scenario_of.append(s)


## Audio gaps since the previous frame (Web with the instrumented worklet only).
func _audio_gaps() -> int:
	if not OS.has_feature("web"):
		return 0
	var total := int(JavaScriptBridge.eval("window.__audioUnderruns || 0", true))
	var delta := total - _audio_gaps_seen
	_audio_gaps_seen = total
	return delta


## Hovers a creature now and then during combat, as a player would; the game
## clears hover every frame, so this runs after it.
func _drive_hover() -> void:
	if game == null or game.battle == null or game.phase != game.Phase.COMBAT:
		_hover_unit = null
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now > _hover_until and not _checking:
		var living: Array = game.battle.units.filter(func(u: Unit) -> bool: return u.alive)
		_hover_unit = living[_rng.randi() % living.size()] if not living.is_empty() else null
		_hover_until = now + 1.5
	if _hover_unit != null and is_instance_valid(_hover_unit) and _hover_unit.alive:
		_hover_unit.hovered = true
		game.hover_info = {"form": _hover_unit.form_id, "team": _hover_unit.team, "unit": _hover_unit, "pos": Rules.BOARD_POS + _hover_unit.position}


# --- Scenarios ------------------------------------------------------------------

func _run() -> void:
	if "--ui-effects" in OS.get_cmdline_user_args():
		await _run_ui_effects()
		return
	if "--cloud-transition" in OS.get_cmdline_user_args():
		await _run_cloud_transition()
		return
	if "--map-pan" in OS.get_cmdline_user_args():
		await _run_map_pan()
		return
	await _seconds(1.0)
	scenario = "difficulty_menu"
	await _seconds(3.0)
	scenario = "pack_menu"
	_mark("choose_difficulty")
	game.choose_difficulty(Difficulty.APPRENTICE)
	await _seconds(3.0)
	scenario = "duel"
	_mark("choose_pack")
	game.choose_pack(0)
	game.enemy.ai_level = Difficulty.ARCHMAGE
	await _play_duel()
	scenario = "game_over"
	await _seconds(3.0)
	scenario = "stress_6v6"
	await _stress_fight()
	scenario = "end"


## Same title-to-map move with one component removed at a time. These are
## rendering measurements, not balance simulations; no duels are played.
func _run_map_pan() -> void:
	var map: Node2D = game.map_screen
	map.set_process_input(false)
	game.web_title_pending = false
	map.title.finish()
	await _seconds(2.0)
	var variants := ["baseline", "no_audio", "no_bridges", "no_islands", "no_sky", "baseline_repeat"]
	if "--map-pan-cache-only" in OS.get_cmdline_user_args():
		variants = ["baseline", "cached_islands", "baseline_repeat"]
	for variant in variants:
		Sfx.enabled = variant != "no_audio"
		map.ambience.set_process(variant != "no_audio")
		map.ambience.replaced = variant == "no_audio"
		if variant == "no_audio":
			map.ambience.cycle.stop()
		for bridge in map.bridges:
			bridge.visible = variant != "no_bridges"
		map.home_bridge.visible = variant != "no_bridges"
		for island in map.islands:
			island.visible = variant != "no_islands"
			island.set_process(variant != "cached_islands")
		map.sky.visible = variant != "no_sky"
		for attempt in 2:
			scenario = "settle"
			map.show_title(true, true)
			map.title.finish()
			await _seconds(0.6)
			scenario = variant + "_title"
			await _seconds(0.6)
			scenario = variant + "_pan"
			game.show_map()
			await _seconds(map.PAN_TIME + 0.05)
			scenario = variant + "_map"
			await _seconds(0.6)


func _run_ui_effects() -> void:
	game.web_title_pending = false
	game.journey.completed.assign(range(12))
	game.choose_stage(12)
	game.choose_pack(0)
	assert(game.phase == game.Phase.PREP and game.hud.visible, "UI benchmark must render the shop")
	game.player.gold += 20
	EnemyAI.shop(game.player, game.rng, EnemyAI.profile_for(Difficulty.ARCHMAGE))
	await _seconds(1.0)
	scenario = "ui_shop"
	await _seconds(3.0)
	scenario = "ui_spotlight"
	game.spotlight.reset("")
	game.spotlight.begin(Rules.FIGHT_CENTER, Vector2(76, 76), null, 2.4)
	await _seconds(3.3)
	scenario = "ui_tracking"
	game.spotlight.begin(Vector2(600, 300), Vector2(140, 60), null, 2.4, func():
		var age: float = game.spotlight.time
		return [Vector2(600 + sin(age * 2.0) * 180.0, 300), Vector2(140 + sin(age) * 30, 60)]
	)
	await _seconds(3.3)
	scenario = "ui_shop_repeat"
	await _seconds(3.0)


func _run_cloud_transition() -> void:
	game.web_title_pending = false
	game.map_screen.show_islands(true)
	await _seconds(1.0)
	for attempt in 3:
		scenario = "cloud_to_level"
		game.enter_stage(0)
		await _seconds(ScreenTransition.COVER + ScreenTransition.HOLD + ScreenTransition.REVEAL + 0.1)
		scenario = "level_settle"
		await _seconds(0.4)
		scenario = "cloud_to_map"
		game.leave_duel()
		await _seconds(ScreenTransition.COVER + ScreenTransition.HOLD + ScreenTransition.REVEAL + 0.1)
		scenario = "map_settle"
		await _seconds(0.4)


func _play_duel() -> void:
	var played := 0
	while played < rounds and game.phase != game.Phase.OVER:
		# Preparation: the player shops like the strongest AI, with extra gold
		# so the boards fill up quickly.
		scenario = "prep"
		game.player.gold += 12
		game.enemy.gold += 12
		await _seconds(1.0)
		_mark("player_shop")
		EnemyAI.shop(game.player, game.rng, EnemyAI.profile_for(Difficulty.ARCHMAGE))
		while game.enemy_preparing:
			await _frames(1)
		await _seconds(1.0)
		scenario = "combat"
		_mark("start_combat r%d" % game.round_num)
		game.start_combat()
		if game.battle == null:
			push_warning("Combat did not start")
			return
		_watch_battle(game.battle)
		game.battle.ai_casting[0] = true # the player's wizard casts too
		while game.phase == game.Phase.COMBAT:
			await _frames(1)
		scenario = "resolve"
		_mark("battle_end")
		while game.phase == game.Phase.RESOLVE:
			await _frames(1)
		_mark("round_end")
		played += 1
	# Finish the duel quickly if it is still going: drain the player's hearts.
	if game.phase != game.Phase.OVER:
		scenario = "prep"
		while game.enemy_preparing:
			await _frames(1)
		game.player.hp = 0.5
		scenario = "final_combat"
		_mark("start_combat final")
		game.start_combat()
		if game.battle != null:
			_watch_battle(game.battle)
			game.battle.ai_casting[0] = true
		while game.phase == game.Phase.COMBAT or game.phase == game.Phase.RESOLVE:
			await _frames(1)


## Six three-star creatures per side, many with area abilities, both wizards
## casting with full charges: the busiest fight the rules allow.
func _stress_fight() -> void:
	game.new_duel()
	game.choose_difficulty(Difficulty.APPRENTICE)
	game.choose_pack(0)
	while game.enemy_preparing:
		await _frames(1)
	var lineups := [
		["pyromancer", "frost_mage", "bard", "cleric", "crossbowman", "guardian"],
		["pyromancer", "frost_mage", "bard", "archer", "berserker", "spearman"],
	]
	for s: WizardState in game.states:
		s.creatures.clear()
		var cells: Array = []
		for row in Rules.team_rows(s.team):
			for col in Rules.COLS:
				cells.append(Vector2i(col, row))
		for i in lineups[s.team].size():
			var c: OwnedCreature = s.add_creature(lineups[s.team][i])
			c.stars = Rules.MAX_STARS
			c.cell = cells[(i * 4 + s.team) % cells.size()]
		s.hp = 10
	game.enemy_preparing = false
	_mark("start_combat stress")
	game.start_combat()
	if game.battle == null:
		push_warning("Stress combat did not start")
		return
	_watch_battle(game.battle)
	game.battle.ai_casting[0] = true
	for spell in game.battle.spells:
		spell.charges = Rules.MAX_CHARGES
	while game.phase == game.Phase.COMBAT:
		await _frames(1)
	scenario = "stress_resolve"
	await _seconds(2.5)


func _watch_battle(battle: Battle) -> void:
	battle.unit_transformed.connect(func(u: Unit, _c: int, from: String) -> void: _mark("shift %s>%s" % [from, u.form_id]))
	battle.unit_died.connect(func(u: Unit) -> void: _mark("death %s" % u.form_id))
	battle.frenzy_changed.connect(func(level: int) -> void: _mark("frenzy %d" % level))


func _mark(label: String) -> void:
	marks.append(label)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


# --- Report ---------------------------------------------------------------------

func _frame(i: int) -> Dictionary:
	var f := {"scenario": scenario_names[scenario_of[i]], "marks": frame_marks.get(i, [])}
	for key in COLUMNS:
		f[key] = columns[key][i]
	return f


func _report() -> void:
	var frames: Array[Dictionary] = []
	for i in scenario_of.size():
		frames.append(_frame(i))
	var by_scenario := {}
	for f in frames:
		by_scenario.get_or_add(f.scenario, []).append(f)
	var summary := {}
	var lines: Array[String] = []
	lines.append("Performance benchmark (%s, %s art, Godot %s, %s)" % [
		"vsync on" if vsync else "vsync off, uncapped",
		"vector" if ArtStyle.current() == ArtStyle.Style.VECTOR else "pixel",
		Engine.get_version_info().string, RenderingServer.get_video_adapter_name()])
	lines.append("%-16s %6s %7s %7s %7s %7s %7s %5s %5s %6s %6s %6s" % ["scenario", "frames", "avg_ms", "p50", "p95", "p99", "max", ">16.7", ">33", "fps", "calls", "gaps"])
	for name in by_scenario:
		var list: Array = by_scenario[name]
		var s := _stats(list)
		summary[name] = s
		lines.append("%-16s %6d %7.2f %7.2f %7.2f %7.2f %7.2f %5d %5d %6.0f %6.0f %6d" % [name, s.frames, s.avg_ms, s.p50_ms, s.p95_ms, s.p99_ms, s.max_ms, s.over_16, s.over_33, s.avg_fps, s.max_draw_calls, s.audio_gaps])
		if "--map-pan" in OS.get_cmdline_user_args() and name.ends_with("_pan"):
			lines.append("  CPU process %.2f ms; render %.2f ms" % [s.avg_process_ms, s.avg_render_cpu_ms])
	var all := _stats(frames)
	summary["all"] = all
	lines.append("%-16s %6d %7.2f %7.2f %7.2f %7.2f %7.2f %5d %5d %6.0f %6.0f %6d" % ["ALL", all.frames, all.avg_ms, all.p50_ms, all.p95_ms, all.p99_ms, all.max_ms, all.over_16, all.over_33, all.avg_fps, all.max_draw_calls, all.audio_gaps])
	# Spikes: the slowest frames with what happened around them.
	var order := range(frames.size())
	order.sort_custom(func(a: int, b: int) -> bool: return frames[a].frame_ms > frames[b].frame_ms)
	var spikes := []
	lines.append("\nSlowest frames (frame / process / physics / render cpu ms, events within +-1 frame):")
	for k in mini(15, order.size()):
		var i: int = order[k]
		var f: Dictionary = frames[i]
		var events: Array = []
		for j in range(maxi(0, i - 1), mini(frames.size(), i + 2)):
			events.append_array(frames[j].marks)
		spikes.append({"index": i, "frame": f, "events": events})
		lines.append("  #%-6d %-14s %7.2f / %6.2f / %6.2f / %6.2f  units %2d fx %3d  %s" % [i, f.scenario, f.frame_ms, f.process_ms, f.physics_ms, f.render_cpu_ms, f.units, f.fx, ", ".join(events)])
	# Growth: nodes, objects and memory at the start of each preparation.
	lines.append("\nResources at each scenario change (nodes / objects / orphans / static MB):")
	var previous := ""
	var growth := []
	for f in frames:
		if f.scenario != previous:
			previous = f.scenario
			growth.append({"scenario": f.scenario, "nodes": f.nodes, "objects": f.objects, "orphans": f.orphans, "memory_mb": f.memory_mb})
			lines.append("  %-16s %6d %7d %4d %7.1f" % [f.scenario, f.nodes, f.objects, f.orphans, f.memory_mb])
	if check_redraw:
		lines.append("\nCached layer check: %d checks, %d stale" % [redraw_checks, redraw_failures.size()])
		for failure in redraw_failures:
			lines.append("  STALE " + failure)
	var text := "\n".join(lines)
	print(text)
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"summary": summary, "spikes": spikes, "growth": growth,
			"scenarios": scenario_names, "scenario_of": scenario_of, "columns": columns, "marks": frame_marks}))
		file.close()
	var txt := FileAccess.open(out_path.get_basename() + ".txt", FileAccess.WRITE)
	if txt != null:
		txt.store_string(text + "\n")
		txt.close()
	print("\nReport written to ", ProjectSettings.globalize_path(out_path))


func _stats(list: Array) -> Dictionary:
	var times: Array[float] = []
	var calls := 0.0
	var render := 0.0
	var process := 0.0
	var physics := 0.0
	var gaps := 0
	for f in list:
		times.append(f.frame_ms)
		calls = maxf(calls, f.draw_calls)
		render += f.render_cpu_ms
		process += f.process_ms
		physics += f.physics_ms
		gaps += int(f.audio_gaps)
	times.sort()
	var n := times.size()
	var total := 0.0
	var over_16 := 0
	var over_33 := 0
	for t in times:
		total += t
		if t > SPIKE_MS:
			over_16 += 1
		if t > BIG_SPIKE_MS:
			over_33 += 1
	var avg := total / maxi(n, 1)
	return {
		"frames": n,
		"avg_ms": avg,
		"avg_fps": 1000.0 / avg if avg > 0.0 else 0.0,
		"p50_ms": times[int(n * 0.50)] if n > 0 else 0.0,
		"p95_ms": times[mini(n - 1, int(n * 0.95))] if n > 0 else 0.0,
		"p99_ms": times[mini(n - 1, int(n * 0.99))] if n > 0 else 0.0,
		"max_ms": times[n - 1] if n > 0 else 0.0,
		"over_16": over_16,
		"over_33": over_33,
		"max_draw_calls": calls,
		"audio_gaps": gaps,
		"avg_process_ms": process / maxi(n, 1),
		"avg_physics_ms": physics / maxi(n, 1),
		"avg_render_cpu_ms": render / maxi(n, 1),
	}


# --- Cached layer check ----------------------------------------------------------
# --- Cached layer check ----------------------------------------------------------

func _redraw_checker() -> void:
	while _running:
		await get_tree().create_timer(1.5, true, false, true).timeout
		if not _running:
			return
		await _check_cached_layers()


## See RedrawCheck.
func _check_cached_layers() -> void:
	_checking = true
	var result := await RedrawCheck.run(game)
	_checking = false
	redraw_checks += 1
	if RedrawCheck.is_stale(result):
		var label := "%s at %.1f s, near %s (difference %.2f)" % [scenario, Time.get_ticks_msec() / 1000.0, result.where, result.difference]
		redraw_failures.append(label)
		var dir := out_path.get_base_dir()
		result.before.save_png(dir.path_join("stale_%d_cached.png" % redraw_failures.size()))
		result.after.save_png(dir.path_join("stale_%d_redrawn.png" % redraw_failures.size()))
