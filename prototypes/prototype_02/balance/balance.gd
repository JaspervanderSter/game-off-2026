extends Node
## On-demand balance suite: every ordered pair of forms fights 1v1 at the same
## star rank, without shapeshifting, from random (seeded) spawn cells.
##
## NOT part of tests/: run only when explicitly requested. See balance/README.md.
##
## The same scene runs in two modes:
## - coordinator (default): splits the duels into shards, launches one headless
##   Godot worker process per shard, waits, merges and analyses the results.
## - worker (--worker): runs every shards-th duel starting at --shard and writes
##   its rows to a CSV file.
##
## User arguments (after `--`): --workers=N --reps=N --stars=0,1,2,3
## --forms=all|id,id,... --seed=N --out=DIR --help

const DT := 1.0 / 60.0 # same step as the game's physics frame
const RESULTS_DIR := "res://balance/results"
const SCENE := "res://balance/balance.tscn"
const DEFAULTS := {"reps": "10", "stars": "0,1,2,3", "forms": "all", "seed": "1", "workers": "0", "out": ""}
const PROGRESS_EVERY := 100
const CSV_HEADER := "star,form_a,form_b,rep,seed,cell_a,cell_b,start_dist,winner,winner_form,time,timeout,hp_a,max_hp_a,hp_b,max_hp_b,damage_taken_a,damage_taken_b,healing_a,healing_b,parries_a,parries_b"
const BT_PRIOR_GAMES := 1.0 # one virtual draw per pair keeps ratings finite
const BT_ITERATIONS := 500

var opts := {}
var forms: Array[String] = []
var stars: Array[int] = []
var reps := 0
var base_seed := 0

var _workers: Array[Dictionary] = []
var _out_dir := ""
var _shard_dir := ""
var _start_ms := 0
var _total_jobs := 0
var _last_report_ms := 0


func _ready() -> void:
	call_deferred("_main")


func _main() -> void:
	opts = _parse_args()
	if opts.has("help"):
		print(_usage())
		get_tree().quit(0)
		return
	var error := _read_config()
	if error != "":
		push_error(error)
		printerr(error + "\n" + _usage())
		get_tree().quit(2)
		return
	if opts.has("worker"):
		_run_worker()
	else:
		_start_coordinator()


# --- Configuration ------------------------------------------------------------

func _parse_args() -> Dictionary:
	var result := DEFAULTS.duplicate()
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		if eq < 0:
			result[body] = "true"
		else:
			result[body.substr(0, eq)] = body.substr(eq + 1)
	return result


func _read_config() -> String:
	reps = int(opts.reps)
	base_seed = int(opts.seed)
	if reps < 1:
		return "--reps must be at least 1"
	for part in String(opts.stars).split(",", false):
		var s := int(part)
		if not part.strip_edges().is_valid_int() or s < 0 or s > Rules.MAX_STARS:
			return "invalid star rank '%s' (expected 0..%d)" % [part, Rules.MAX_STARS]
		if s not in stars:
			stars.append(s)
	if opts.forms == "all":
		forms = CreatureDB.all_ids()
	else:
		for part in String(opts.forms).split(",", false):
			var id: String = part.strip_edges()
			if not CreatureDB.FORMS.has(id):
				return "unknown form '%s'" % id
			if id not in forms:
				forms.append(id)
	if forms.size() < 2 or stars.is_empty():
		return "need at least two forms and one star rank"
	return ""


func _usage() -> String:
	return "\n".join([
		"Balance suite (on demand only). User arguments, after `--`:",
		"  --workers=N   parallel worker processes (default: CPU threads - 2)",
		"  --reps=N      duels per ordered pair and star rank (default 10)",
		"  --stars=LIST  star ranks to test, e.g. 0,1,2,3 (default)",
		"  --forms=LIST  'all' (default) or comma-separated form ids",
		"  --seed=N      base seed; same seed + options = same results (default 1)",
		"  --out=DIR     output folder (default res://balance/results/<timestamp>)",
		"  --no-sound    mute all audio (the launcher always passes it)",
	])


## Every duel as [star, form_a, form_b, rep]. Mirror pairs are included to
## measure side bias; they are excluded from the rankings.
func _build_jobs() -> Array:
	var jobs := []
	for star in stars:
		for a in forms:
			for b in forms:
				for rep in reps:
					jobs.append([star, a, b, rep])
	return jobs


## Seed derived from the duel itself, so a given duel is reproducible even
## when the form or star selection changes.
func _duel_seed(star: int, a: String, b: String, rep: int) -> int:
	return ("%d|%d|%s|%s|%d" % [base_seed, star, a, b, rep]).hash()


# --- Worker -----------------------------------------------------------------

func _run_worker() -> void:
	var shard := int(opts.get("shard", "0"))
	var shards := maxi(1, int(opts.get("shards", "1")))
	var dir: String = opts.out
	DirAccess.make_dir_recursive_absolute(dir)
	var jobs := _build_jobs()
	var lines := PackedStringArray()
	var progress_path := dir.path_join("shard_%d.progress" % shard)
	var i := shard
	while i < jobs.size():
		lines.append(_run_duel(jobs[i]))
		if lines.size() % PROGRESS_EVERY == 0:
			_write_text(progress_path, str(lines.size()))
		i += shards
	_write_text(dir.path_join("shard_%d.csv" % shard), "\n".join(lines))
	_write_text(dir.path_join("shard_%d.done" % shard), str(lines.size()))
	get_tree().quit(0)


func _run_duel(job: Array) -> String:
	var star: int = job[0]
	var a: String = job[1]
	var b: String = job[2]
	var rep: int = job[3]
	var seed_value := _duel_seed(star, a, b, rep)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rows_a := Rules.team_rows(0)
	var rows_b := Rules.team_rows(1)
	var cell_a := Vector2i(rng.randi_range(0, Rules.COLS - 1), rows_a[rng.randi_range(0, rows_a.size() - 1)])
	var cell_b := Vector2i(rng.randi_range(0, Rules.COLS - 1), rows_b[rng.randi_range(0, rows_b.size() - 1)])

	var battle := Battle.new()
	battle.rng.seed = seed_value
	battle.casting_enabled = false
	battle.ai_casting = [false, false]
	var ua := battle.spawn(0, a, Rules.cell_center(cell_a), 1, star)
	var ub := battle.spawn(1, b, Rules.cell_center(cell_b), 2, star)
	while not battle.finished:
		battle.step(DT)

	var winner: int = battle.result.winner
	var winner_form := "draw"
	if winner == 0:
		winner_form = a
	elif winner == 1:
		winner_form = b
	var timeout := winner < 0 and battle.time >= Rules.COMBAT_TIMEOUT
	var start_dist := Rules.cell_center(cell_a).distance_to(Rules.cell_center(cell_b)) / Rules.CELL
	var row := "%d,%s,%s,%d,%d,%d:%d,%d:%d,%.2f,%d,%s,%.3f,%d,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%d,%d" % [
		star, a, b, rep, seed_value, cell_a.x, cell_a.y, cell_b.x, cell_b.y, start_dist,
		winner, winner_form, battle.time, 1 if timeout else 0,
		maxf(ua.hp, 0.0), ua.max_hp, maxf(ub.hp, 0.0), ub.max_hp,
		battle.damage_taken[0], battle.damage_taken[1],
		battle.healing_received[0], battle.healing_received[1],
		battle.parries[0], battle.parries[1]]
	battle.free()
	return row


# --- Coordinator --------------------------------------------------------------

func _start_coordinator() -> void:
	_start_ms = Time.get_ticks_msec()
	_total_jobs = stars.size() * forms.size() * forms.size() * reps
	var workers := int(opts.workers)
	if workers <= 0:
		workers = maxi(1, OS.get_processor_count() - 2)
	workers = mini(workers, _total_jobs)

	var results_root := ProjectSettings.globalize_path(RESULTS_DIR)
	DirAccess.make_dir_recursive_absolute(results_root)
	# Keep generated CSV files out of the Godot import system.
	if not FileAccess.file_exists(results_root.path_join(".gdignore")):
		_write_text(results_root.path_join(".gdignore"), "")
	if opts.out != "":
		_out_dir = ProjectSettings.globalize_path(opts.out)
	else:
		var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
		_out_dir = results_root.path_join(stamp)
	_shard_dir = _out_dir.path_join("shards")
	DirAccess.make_dir_recursive_absolute(_shard_dir)

	print("Balance suite: %d duels (%d forms, stars %s, %d reps per ordered pair) on %d workers" % [
		_total_jobs, forms.size(), opts.stars, reps, workers])
	print("Output: %s" % _out_dir)

	var project := ProjectSettings.globalize_path("res://")
	for shard in workers:
		var args := PackedStringArray([
			"--headless", "--audio-driver", "Dummy", "--path", project, SCENE, "--",
			"--no-sound", "--worker", "--shard=%d" % shard, "--shards=%d" % workers,
			"--reps=%d" % reps, "--stars=%s" % ",".join(stars.map(func(s): return str(s))),
			"--forms=%s" % ",".join(forms), "--seed=%d" % base_seed, "--out=%s" % _shard_dir])
		var pid := OS.create_process(OS.get_executable_path(), args)
		if pid < 0:
			printerr("Could not start worker %d" % shard)
			get_tree().quit(1)
			return
		_workers.append({"pid": pid, "shard": shard})
	_last_report_ms = Time.get_ticks_msec()


func _process(_dt: float) -> void:
	if _workers.is_empty():
		return
	OS.delay_msec(200) # the coordinator only polls; leave the CPU to workers
	var running := 0
	for w in _workers:
		if OS.is_process_running(w.pid):
			running += 1
	if running > 0:
		if Time.get_ticks_msec() - _last_report_ms >= 3000:
			_last_report_ms = Time.get_ticks_msec()
			print("  %d / %d duels (%d workers running, %.0f s)" % [
				_progress(), _total_jobs, running, _elapsed()])
		return
	var workers := _workers.size()
	_workers.clear()
	_finish(workers)


func _progress() -> int:
	var total := 0
	for w in _workers:
		var done := _shard_dir.path_join("shard_%d.done" % w.shard)
		var progress := _shard_dir.path_join("shard_%d.progress" % w.shard)
		if FileAccess.file_exists(done):
			total += int(FileAccess.get_file_as_string(done))
		elif FileAccess.file_exists(progress):
			total += int(FileAccess.get_file_as_string(progress))
	return total


func _elapsed() -> float:
	return (Time.get_ticks_msec() - _start_ms) / 1000.0


func _finish(workers: int) -> void:
	var lines := PackedStringArray([CSV_HEADER])
	for shard in workers:
		var path := _shard_dir.path_join("shard_%d.csv" % shard)
		if not FileAccess.file_exists(_shard_dir.path_join("shard_%d.done" % shard)) or not FileAccess.file_exists(path):
			printerr("Worker %d did not finish; partial shards kept in %s" % [shard, _shard_dir])
			get_tree().quit(1)
			return
		for line in FileAccess.get_file_as_string(path).split("\n", false):
			lines.append(line)
	if lines.size() - 1 != _total_jobs:
		printerr("Expected %d duels, got %d; shards kept in %s" % [_total_jobs, lines.size() - 1, _shard_dir])
		get_tree().quit(1)
		return
	_write_text(_out_dir.path_join("duels.csv"), "\n".join(lines) + "\n")
	for file in DirAccess.get_files_at(_shard_dir):
		DirAccess.remove_absolute(_shard_dir.path_join(file))
	DirAccess.remove_absolute(_shard_dir)

	var simulated := _elapsed()
	var analysis := _analyse(lines)
	analysis.config = {
		"forms": forms, "stars": stars, "reps_per_ordered_pair": reps, "seed": base_seed,
		"workers": workers, "dt": DT, "duels": _total_jobs, "shapeshift": false,
		"spawn": "random cell in each team's own half, per-duel seed",
		"simulation_seconds": snappedf(simulated, 0.1),
		"engine": Engine.get_version_info().string,
		"generated": Time.get_datetime_string_from_system(),
	}
	_write_text(_out_dir.path_join("summary.json"), JSON.stringify(analysis, "  ", false) + "\n")
	print("Done: %d duels in %.1f s. Files: duels.csv, matchups.csv, ranking.csv, summary.json" % [_total_jobs, _elapsed()])
	print("Output: %s" % _out_dir)
	get_tree().quit(0)


# --- Analysis -----------------------------------------------------------------

func _new_stats() -> Dictionary:
	return {"games": 0, "wins": 0, "losses": 0, "draws": 0, "timeouts": 0, "hp_margin": 0.0,
		"time": 0.0, "win_time": 0.0, "dealt": 0.0, "taken": 0.0, "healing": 0.0}


func _add(stats: Dictionary, outcome: int, timeout: bool, margin: float, time: float, dealt: float, taken: float, healing: float) -> void:
	stats.games += 1
	if outcome > 0:
		stats.wins += 1
		stats.win_time += time
	elif outcome < 0:
		stats.losses += 1
	else:
		stats.draws += 1
	if timeout:
		stats.timeouts += 1
	stats.hp_margin += margin
	stats.time += time
	stats.dealt += dealt
	stats.taken += taken
	stats.healing += healing


func _score(stats: Dictionary) -> float:
	return (stats.wins + 0.5 * stats.draws) / maxf(1.0, stats.games)


func _analyse(lines: PackedStringArray) -> Dictionary:
	# pair[star][a][b]: a's results against b, both sides combined.
	var pair := {}
	var side := {} # star -> {"mirror": [t0 wins, t1 wins, draws], "all": [...]}
	for star in stars:
		pair[star] = {}
		side[star] = {"mirror": [0, 0, 0], "all": [0, 0, 0]}
		for a in forms:
			pair[star][a] = {}
			for b in forms:
				if a != b:
					pair[star][a][b] = _new_stats()
	for i in range(1, lines.size()):
		var c := lines[i].split(",")
		var star := int(c[0])
		var a := c[1]
		var b := c[2]
		var winner := int(c[8])
		var time := float(c[10])
		var timeout := c[11] == "1"
		var ratio_a := float(c[12]) / float(c[13])
		var ratio_b := float(c[14]) / float(c[15])
		var bucket: int = 2 if winner < 0 else winner
		side[star].all[bucket] += 1
		if a == b:
			side[star].mirror[bucket] += 1
			continue
		var out_a := 0 if winner < 0 else (1 if winner == 0 else -1)
		_add(pair[star][a][b], out_a, timeout, ratio_a - ratio_b, time, float(c[17]), float(c[16]), float(c[18]))
		_add(pair[star][b][a], -out_a, timeout, ratio_b - ratio_a, time, float(c[16]), float(c[17]), float(c[19]))

	var matchup_lines := PackedStringArray(["star,form,opponent,games,wins,losses,draws,score,avg_hp_margin,avg_time,avg_damage_dealt,avg_damage_taken,avg_healing"])
	var ranking_lines := PackedStringArray(["star,rank,form,family,role,price,games,wins,losses,draws,timeouts,score,bt_rating,opponents_beaten,opponents_lost_to,avg_hp_margin,avg_win_time,avg_damage_dealt,avg_damage_taken,avg_healing"])
	var per_star := {}
	for star in stars:
		var totals := {}
		for a in forms:
			var total := _new_stats()
			var beaten := 0
			var lost_to := 0
			for b in forms:
				if a == b:
					continue
				var s: Dictionary = pair[star][a][b]
				var n := maxf(1.0, s.games)
				matchup_lines.append("%d,%s,%s,%d,%d,%d,%d,%.4f,%.4f,%.2f,%.1f,%.1f,%.1f" % [
					star, a, b, s.games, s.wins, s.losses, s.draws, _score(s),
					s.hp_margin / n, s.time / n, s.dealt / n, s.taken / n, s.healing / n])
				var sc := _score(s)
				if sc > 0.5:
					beaten += 1
				elif sc < 0.5:
					lost_to += 1
				for key in total:
					total[key] += s[key]
			total.beaten = beaten
			total.lost_to = lost_to
			totals[a] = total
		var bt := _bradley_terry(pair[star])
		var order := forms.duplicate()
		order.sort_custom(func(x, y):
			var sx := _score(totals[x])
			var sy := _score(totals[y])
			return sx > sy if not is_equal_approx(sx, sy) else bt[x] > bt[y])
		var ranking := []
		for r in order.size():
			var id: String = order[r]
			var t: Dictionary = totals[id]
			var f: Dictionary = CreatureDB.FORMS[id]
			var n := maxf(1.0, t.games)
			ranking_lines.append("%d,%d,%s,%s,%s,%d,%d,%d,%d,%d,%d,%.4f,%.0f,%d,%d,%.4f,%.2f,%.1f,%.1f,%.1f" % [
				star, r + 1, id, f.family, f.role, f.price, t.games, t.wins, t.losses, t.draws, t.timeouts,
				_score(t), bt[id], t.beaten, t.lost_to, t.hp_margin / n,
				t.win_time / maxf(1.0, t.wins), t.dealt / n, t.taken / n, t.healing / n])
			ranking.append({"rank": r + 1, "form": id, "family": f.family, "price": f.price,
				"score": snappedf(_score(t), 0.0001), "bt_rating": roundi(bt[id]),
				"opponents_beaten": t.beaten, "avg_hp_margin": snappedf(t.hp_margin / n, 0.0001)})
		var all_games: Array = side[star].all
		var draws_total := 0
		var timeouts_total := 0
		for id in forms:
			draws_total += totals[id].draws
			timeouts_total += totals[id].timeouts
		per_star[str(star)] = {
			"ranking": ranking,
			"price_vs_score_spearman_fantasy": _price_correlation(totals, "fantasy"),
			"price_vs_score_spearman_all": _price_correlation(totals, ""),
			"side_bias": {
				"mirror_team0_wins": side[star].mirror[0], "mirror_team1_wins": side[star].mirror[1],
				"mirror_draws": side[star].mirror[2],
				"all_team0_wins": all_games[0], "all_team1_wins": all_games[1], "all_draws": all_games[2],
			},
			# Each non-mirror duel is counted once per side in the totals.
			"draw_rate": snappedf(draws_total / maxf(1.0, totals.size() * (forms.size() - 1) * 2.0 * reps), 0.0001),
			"timeout_duels": timeouts_total / 2,
		}
	_write_text(_out_dir.path_join("matchups.csv"), "\n".join(matchup_lines) + "\n")
	_write_text(_out_dir.path_join("ranking.csv"), "\n".join(ranking_lines) + "\n")
	return {"per_star": per_star}


## Bradley-Terry strengths by minorisation-maximisation, draws counted as half
## a win, with a small symmetric prior. Returned on an Elo-like scale (mean 1500).
func _bradley_terry(star_pairs: Dictionary) -> Dictionary:
	var p := {}
	for id in forms:
		p[id] = 1.0
	for iteration in BT_ITERATIONS:
		var next := {}
		for i in forms:
			var w := 0.0
			var denom := 0.0
			for j in forms:
				if i == j:
					continue
				var s: Dictionary = star_pairs[i][j]
				var n: float = s.games + BT_PRIOR_GAMES
				w += s.wins + 0.5 * s.draws + 0.5 * BT_PRIOR_GAMES
				denom += n / (p[i] + p[j])
			next[i] = w / denom
		var log_mean := 0.0
		for id in forms:
			log_mean += log(next[id])
		log_mean /= forms.size()
		for id in forms:
			p[id] = next[id] / exp(log_mean)
	var rating := {}
	for id in forms:
		rating[id] = 1500.0 + 400.0 * log(p[id]) / log(10.0)
	return rating


## Spearman rank correlation between price and score (family "" = every form).
func _price_correlation(totals: Dictionary, family: String) -> Variant:
	var prices := []
	var scores := []
	for id in forms:
		if family == "" or CreatureDB.FORMS[id].family == family:
			prices.append(float(CreatureDB.FORMS[id].price))
			scores.append(_score(totals[id]))
	if prices.size() < 3:
		return null
	return snappedf(_pearson(_ranks(prices), _ranks(scores)), 0.0001)


func _ranks(values: Array) -> Array:
	var idx := range(values.size())
	idx.sort_custom(func(x, y): return values[x] < values[y])
	var ranks := []
	ranks.resize(values.size())
	var i := 0
	while i < idx.size():
		var j := i
		while j + 1 < idx.size() and values[idx[j + 1]] == values[idx[i]]:
			j += 1
		for k in range(i, j + 1):
			ranks[idx[k]] = (i + j) / 2.0 + 1.0
		i = j + 1
	return ranks


func _pearson(x: Array, y: Array) -> float:
	var n := x.size()
	var mx := 0.0
	var my := 0.0
	for i in n:
		mx += x[i]
		my += y[i]
	mx /= n
	my /= n
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in n:
		sxy += (x[i] - mx) * (y[i] - my)
		sxx += (x[i] - mx) * (x[i] - mx)
		syy += (y[i] - my) * (y[i] - my)
	if sxx == 0.0 or syy == 0.0:
		return 0.0
	return sxy / sqrt(sxx * syy)


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("Cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	f.store_string(text)
	f.close()
