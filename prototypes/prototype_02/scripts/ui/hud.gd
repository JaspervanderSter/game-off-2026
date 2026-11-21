class_name Hud
extends Node2D
## Side panels, buttons, overlays and the hover card.

# Each wizard is a medallion beside the board (playtest decision, 21 November
# 2026): its portrait, its hearts on arcs above it at a fixed spacing (up to
# HEART_ARC on one arc, otherwise two balanced concentric arcs), its charge
# crystals on an arc below, and its gold in a pill on its right. Hud.layout_screen
# places the medallions with the board.
const MEDALLION_RADIUS := 40.0
const HEART_SPACING := 22.0 # between two heart centres, along their arc
const HEART_ARC := 6 # most hearts on one arc
const HEART_INNER := 18.0 # from the medallion edge to the inner arc
const HEART_ROW_GAP := 19.0 # between the two arcs
const CRYSTAL_SPACING := 26.0
const CRYSTAL_RING := 24.0 # from the medallion edge to the crystal arc
const PILL_GAP := 10.0 # from the medallion edge to the gold pill
const PILL_DROP := 24.0 # the pill sits this far below the medallion centre
# Before the shop, the board and the medallions are centred together; with the
# shop, the board takes its final place between the medallions and the stall.
# In both, the bench and then the fight button share the row under the board.
const SHOPLESS_BOARD_X := 410.0
const SHOPLESS_MEDALLION_X := 333.0
const SHOP_BOARD_X := 352.0
const SHOP_MEDALLION_X := 130.0
const ENEMY_MEDALLION_Y := 170.0
const PLAYER_MEDALLION_Y := 442.0
const BENCH_Y := 556.0
const FIGHT_Y := 600.0
const FIGHT_BENCH_GAP := 18.0
## Medallion centres, player then opponent (team order), set by layout_screen.
static var medallion_centers: Array[Vector2] = [Vector2(SHOP_MEDALLION_X, PLAYER_MEDALLION_Y), Vector2(SHOP_MEDALLION_X, ENEMY_MEDALLION_Y)]
# Round frieze centred above the board, clear of the combat timer bar (y 50).
const FRIEZE_Y := 23.0
const FRIEZE_STEP := 36.0
const FRIEZE_PAST := 7 # finished rounds shown left of the current one
const FRIEZE_FUTURE := 3
const FRIEZE_RADIUS := 17.0
const FRIEZE_PIP := 9.0
const FRIEZE_SLIDE := 0.45
const FRIEZE_LINE := Color(0.42, 0.35, 0.28)
const FRIEZE_DRAW := Color(0.55, 0.5, 0.45)
const RESTART_POS := Vector2(640, 420)
# Abandoning a replayed duel: the island medallion in the top-left corner (or
# Esc) pauses the duel under a confirmation with a check and a cross.
const ABANDON_POS := Vector2(48, 42)
const ABANDON_RADIUS := 24.0
const ABANDON_HOVER_SCALE := 1.08
const CONFIRM_MEDALLION := Vector2(640, 300)
const CONFIRM_YES := Vector2(570, 420)
const CONFIRM_NO := Vector2(710, 420)
const CONFIRM_RADIUS := 32.0
const VICTORY_POS := Vector2(640, 255)
const UNLOCK_CLICK := 0.48
const UNLOCK_OPEN_TIME := 0.24
const UNLOCK_DURATION := 1.40
const VictoryFx := preload("res://scripts/ui/victory_fx.gd")
# Shop column: a merchant stall for the creature offers and reroll (Rules.SHOP_RECT),
# then a purple scroll of wand upgrades, then the fight button (Rules.FIGHT_CENTER).
const STALL_RECT := Rect2(956, 62, 312, 308)
const AWNING_TOP := 42.0
const AWNING_STRIPES := 8
const AWNING_SCALLOP := 9.0
const OFFER_SIZE := Vector2(288, 76)
const OFFER_STEP := 82.0
const REROLL_RECT := Rect2(968, 322, 288, 36)
const SCROLL_TOP := 386.0 # centre of the top rod
const SCROLL_LENGTH := 198.0 # rod-to-rod distance once unrolled
const SCROLL_X := Vector2(976, 1252) # parchment left and right edges, clear of the field pips
const UPGRADE_TOP := 400.0
const UPGRADE_SIZE := Vector2(260, 38)
const UPGRADE_STEP := 44.0
# Ready fight button: a light glint sweeps across it once per period.
const FIGHT_GLINT_PERIOD := 4.0
const FIGHT_GLINT_SWEEP := 0.72
const FIGHT_HOVER_SCALE := 1.07
# Reroll button: while a reroll makes sense (main.reroll_sensible), a glint
# sweeps across it every REROLL_GLINT_PERIOD, the first one REROLL_GLINT_DELAY
# after it starts making sense. A reroll turns each replaced offer over on a
# horizontal axis: the old offer, its plain wooden back, the new offer.
const REROLL_GLINT_DELAY := 0.5
const REROLL_GLINT_PERIOD := 3.0
const REROLL_GLINT_SWEEP := 0.75
const OFFER_FLIP_TIME := 0.5
const OFFER_FLIP_STAGGER := 0.08
const OFFER_BACK := Color(0.33, 0.22, 0.13)
# Wand upgrade tooltip: two scene panels, current level then next level.
const TOOLTIP_SIZE := Vector2(300, 132)
const TOOLTIP_PANEL := Vector2(120, 112)
const PACK_TOP := 222.0
const PACK_CARD_SIZE := Vector2i(176, 168)
const DIFFICULTY_CARD_SIZE := Vector2i(168, 260)
const CHOICE_HALO_MARGIN := 12
const CHOICE_HALO_FADE := 0.16
const SHOP_SLIDE := 360.0 # pushes the whole shop column past the right edge
const FIGHT_SLIDE := 180.0 # drops the fight button past the bottom edge
const HEART_STAGGER := 0.26
const HEART_BURST := 0.20
const COIN_FLIGHT := 0.62
const REWARD_TAIL := 0.45
# Combat-start harvest: each fielded harvester hops in turn, its coins burst out
# in a fan above it, hover a beat, then fly one by one into the wizard's purse.
const HARVEST_DELAY := 0.35
const HARVEST_STAGGER := 0.26
const HARVEST_HOP := 0.42
const HARVEST_POP := 0.34
const HARVEST_HOVER := 0.18
const HARVEST_COIN_STAGGER := 0.09
const HARVEST_FLIGHT := 0.58
## Harvest coin sound events, coins/harvest/1 to /8, each a step higher; later
## coins of the same harvester replay the last one.
const HARVEST_COIN_SOUNDS := 8
# Harvest lesson (the innkeeper's duel, first harvest): the spotlight follows one
# harvester's coins from its hop into the purse, the harvest plays slower, and
# the gold earned rises from the purse as "+N" once the coins have landed.
const HARVEST_LESSON_SPEED := 0.6
const HARVEST_LESSON_PURSE_HOLD := 0.9 # seconds the light rests on the purse
const HARVEST_LESSON_GAIN_TIME := 1.1 # seconds the "+N" rises
const HARVEST_LIGHT_FARMER := Vector2(54, 72) # harvester and its coin fan
const HARVEST_LIGHT_COIN := Vector2(46, 46)
const HARVEST_LIGHT_PURSE := Vector2(76, 46)

var game # main.gd
var font: Font
var loss_rewards: Array[Dictionary] = []
var reward_time := 0.0
var harvest_time := 0.0
## Offers turning over after a reroll: {"slot", "from" (the replaced offer, ""
## for an empty slot), "start"}, timed by offer_flip_time.
var offer_flips: Array[Dictionary] = []
var offer_flip_time := 0.0
var harvest_sources: Array[Dictionary] = []
var harvest_coins: Array[Dictionary] = []
var harvest_speed := 1.0
var harvest_lesson := {} # {team, uid, gold, landed (harvest time)} while shown
var victory := VictoryFx.new()
var unlock_level := -1
var unlock_time := 0.0
var difficulty_halo: Texture2D
var pack_halo: Texture2D
var choice_hover := PackedFloat32Array()
var choice_phase := -1
var frieze_round := 0
var frieze_time := FRIEZE_SLIDE
var _tooltip_row := -1 # wand upgrade row whose tooltip is showing
var _tooltip_start := 0.0 # when that hover began, in seconds
## Canvas item the drawing functions draw on: one of the layers below.
var _ci: CanvasItem = self
## Child canvas items in drawing order, each {"node", "key"}. Every redraw
## rebuilds a layer's draw commands, so the side panels and the shop column
## redraw only when what they show changes (their key); the others every frame.
var _layers := {}
var _merge_ghost: Node2D
## The merge demonstration flies each copy in for this long, in seconds, then
## shows the star it makes for MERGE_DEMO_STAR before looping.
const MERGE_DEMO_PERIOD := 1.8
const MERGE_DEMO_STAR := 1.1


func _ready() -> void:
	font = ThemeDB.fallback_font
	difficulty_halo = _make_choice_halo(DIFFICULTY_CARD_SIZE)
	pack_halo = _make_choice_halo(PACK_CARD_SIZE)
	for layer_name in ["panels", "base", "shop", "overlay"]:
		var layer := Node2D.new()
		layer.name = layer_name.capitalize()
		layer.draw.connect(_draw_layer.bind(layer_name, layer))
		add_child(layer)
		_layers[layer_name] = {"node": layer, "key": null}
	# The merge lesson's translucent copy needs its own alpha (modulate).
	_merge_ghost = Node2D.new()
	_merge_ghost.name = "MergeGhost"
	_merge_ghost.draw.connect(_draw_merge_ghost)
	add_child(_merge_ghost)
	set_process_internal(true)


func _process(dt: float) -> void:
	advance_loss_rewards(dt)
	advance_harvest(dt)
	advance_offer_flips(dt)
	advance_round_frieze(dt)
	if game.phase == game.Phase.OVER:
		victory.advance(dt)
	elif game.phase == game.Phase.DIFFICULTY:
		advance_difficulty_unlock(dt)
	if game.phase == game.Phase.DIFFICULTY or game.phase == game.Phase.PACK:
		_advance_choice_hover(dt)
	else:
		choice_phase = -1
	_refresh_layers()
	_merge_ghost.queue_redraw()


## Layers refresh at the end of _process, after this frame's animation steps.
## Tests that stop the HUD's processing to step animations by hand still need
## them refreshed: internal processing does it then.
func _notification(what: int) -> void:
	if what == NOTIFICATION_INTERNAL_PROCESS and not is_processing():
		_refresh_layers()


func _advance_choice_hover(dt: float) -> void:
	var picking_difficulty: bool = game.phase == game.Phase.DIFFICULTY
	var card_count: int = Difficulty.COUNT if picking_difficulty else game.offered_packs.size()
	if choice_phase != game.phase:
		choice_phase = game.phase
		choice_hover.resize(card_count)
		choice_hover.fill(0.0)
	var mouse := get_global_mouse_position()
	for i in card_count:
		var rect := difficulty_rect(i) if picking_difficulty else pack_rect(i)
		var selectable: bool = not picking_difficulty or (game.is_difficulty_unlocked(i) and not unlock_animation_active())
		var target := 1.0 if selectable and rect.has_point(mouse) else 0.0
		choice_hover[i] = move_toward(choice_hover[i], target, dt / CHOICE_HALO_FADE)


## The frieze slides one step left when the next round of the same duel begins;
## a new duel snaps back to round 1.
func advance_round_frieze(dt: float) -> void:
	var shown := maxi(1, game.round_num)
	if shown != frieze_round:
		frieze_time = 0.0 if frieze_round > 0 and shown == frieze_round + 1 else FRIEZE_SLIDE
		frieze_round = shown
	frieze_time = minf(frieze_time + dt, FRIEZE_SLIDE)


func begin_difficulty_unlock(level: int) -> void:
	unlock_level = level
	unlock_time = 0.0


func unlock_animation_active() -> bool:
	return unlock_level >= 0


func advance_difficulty_unlock(dt: float) -> void:
	if not unlock_animation_active():
		return
	var previous := unlock_time
	unlock_time += dt
	if previous < UNLOCK_CLICK and unlock_time >= UNLOCK_CLICK:
		Sfx.play("ui/difficulty_unlock")
	if unlock_time >= UNLOCK_DURATION:
		unlock_level = -1


func begin_victory() -> void:
	victory.start(VICTORY_POS)


func clear_victory() -> void:
	victory.clear()


func clear_harvest() -> void:
	harvest_sources.clear()
	harvest_coins.clear()
	harvest_time = 0.0
	harvest_speed = 1.0
	harvest_lesson = {}


## Shows the harvest rule on one queued harvester: slows the harvest and
## returns how long the spotlight stays at full strength, from now until it has
## rested on the purse after the last coin landed.
func begin_harvest_lesson(team: int, uid: int) -> float:
	var landed := harvest_time
	var gold := 0
	for coin in harvest_coins:
		if coin.team == team and coin.uid == uid:
			landed = maxf(landed, coin.fly + HARVEST_FLIGHT)
			gold += 1
	harvest_speed = HARVEST_LESSON_SPEED
	harvest_lesson = {"team": team, "uid": uid, "gold": gold, "landed": landed}
	return (landed - harvest_time) / harvest_speed + HARVEST_LESSON_PURSE_HOLD


## Where the harvest lesson's light stands now, [center, radii]: on the
## harvester and its coin fan, then on its flying coins, then on the purse.
## Empty when no lesson is shown.
func harvest_spotlight() -> Array:
	if harvest_lesson.is_empty():
		return []
	var coins := harvest_coins.filter(func(c): return c.team == harvest_lesson.team and c.uid == harvest_lesson.uid)
	var purse := gold_pos(harvest_lesson.team) + Vector2(34, -4)
	if coins.is_empty():
		return [purse, HARVEST_LIGHT_PURSE]
	var farmer: Vector2 = coins[0].from + Vector2(0, -26)
	var first_fly: float = coins[0].fly
	var middle := Vector2.ZERO
	for coin in coins:
		middle += _coin_position(coin)
	middle /= coins.size()
	var leave := smoothstep(0.0, 0.3, (harvest_time - first_fly) / HARVEST_FLIGHT)
	var arrive := smoothstep(0.0, 0.25, harvest_time - harvest_lesson.landed)
	var center := farmer.lerp(middle, leave).lerp(purse, arrive)
	var radii := HARVEST_LIGHT_FARMER.lerp(HARVEST_LIGHT_COIN, leave).lerp(HARVEST_LIGHT_PURSE, arrive)
	return [center, radii]


## Queues the harvest animation for one wizard. Rules already granted the gold;
## displayed_gold() hides each coin until it lands. sources: [{uid, pos, gold}]
## with screen positions.
func begin_harvest(team: int, sources: Array[Dictionary]) -> void:
	var base := harvest_time + HARVEST_DELAY
	for i in sources.size():
		var src: Dictionary = sources[i]
		var start := base + i * HARVEST_STAGGER
		var from: Vector2 = src.pos
		harvest_sources.append({"team": team, "uid": src.uid, "pos": from, "start": start, "popped": false})
		var n: int = src.gold
		var fan := minf(1.25, 0.3 * (n - 1))
		for j in n:
			var spread := 0.0 if n == 1 else (j - (n - 1) / 2.0) / ((n - 1) / 2.0)
			var radius := 42.0 + (12.0 if n > 4 and j % 2 == 1 else 0.0)
			harvest_coins.append({"team": team, "uid": src.uid, "from": from, "index": j, "start": start + j * 0.025,
				"offset": Vector2.from_angle(-PI / 2 + spread * fan) * radius,
				"fly": start + HARVEST_POP + HARVEST_HOVER + j * HARVEST_COIN_STAGGER, "arrived": false})


## Seconds until the last queued coin of a team has landed (0 when none).
func harvest_remaining(team: int) -> float:
	var remaining := 0.0
	for coin in harvest_coins:
		if coin.team == team:
			remaining = maxf(remaining, coin.fly + HARVEST_FLIGHT - harvest_time)
	return remaining


func advance_harvest(dt: float) -> void:
	if harvest_sources.is_empty() and harvest_coins.is_empty() and harvest_lesson.is_empty():
		return
	harvest_time += dt * harvest_speed
	if not harvest_lesson.is_empty() and harvest_time >= harvest_lesson.landed + HARVEST_LESSON_GAIN_TIME * harvest_speed:
		harvest_lesson = {}
		harvest_speed = 1.0
	for src in harvest_sources:
		if not src.popped and harvest_time >= src.start:
			src.popped = true
			_pop_harvester(src)
			Sfx.play("coins/pop")
	for coin in harvest_coins:
		if not coin.arrived and harvest_time >= coin.fly + HARVEST_FLIGHT:
			coin.arrived = true
			# Each landing coin rings a little higher: a rising cash-register run.
			Sfx.play("coins/harvest/%d" % mini(coin.index + 1, HARVEST_COIN_SOUNDS))
	harvest_sources = harvest_sources.filter(func(s): return harvest_time < s.start + HARVEST_HOP + 0.3)
	harvest_coins = harvest_coins.filter(func(c): return harvest_time < c.fly + HARVEST_FLIGHT + REWARD_TAIL)


## The harvester's combat unit hops where it now stands, and its coins burst
## out from there (it may have walked since the fight began).
func _pop_harvester(src: Dictionary) -> void:
	var b: Battle = game.battle if game != null else null
	if b == null:
		return
	for u in b.units:
		if u.alive and u.team == src.team and u.source_uid == src.uid:
			u.beat_t = HARVEST_HOP
			u.beat_len = HARVEST_HOP
			src.pos = Rules.BOARD_POS + u.position
			for coin in harvest_coins:
				if coin.team == src.team and coin.uid == src.uid:
					coin.from = src.pos
			return


func clear_loss_rewards() -> void:
	loss_rewards.clear()
	reward_time = 0.0


func begin_loss_rewards(team: int, hp_before: float, count: float, coin_count: int = 0, compensation_before: float = 0.0) -> void:
	clear_loss_rewards()
	var halves := roundi(count * 2.0)
	for i in halves:
		var half_index := roundi(hp_before * 2.0) - 1 - i
		var coin := coin_count > 0 and floori(compensation_before + (i + 1) * 0.5) > floori(compensation_before + i * 0.5)
		loss_rewards.append({"team": team, "heart": floori(half_index / 2.0), "half": half_index % 2,
			"start": 0.22 + i * HEART_STAGGER, "burst": false, "arrived": false, "coin": coin})


func loss_reward_duration() -> float:
	var duration := 0.0
	for reward in loss_rewards:
		var tail := HEART_BURST + COIN_FLIGHT + REWARD_TAIL if reward.coin else 0.48 + 0.3
		duration = maxf(duration, reward.start + tail)
	return duration


func advance_loss_rewards(dt: float) -> void:
	reward_time += dt
	for reward in loss_rewards:
		var age: float = reward_time - reward.start
		if age >= 0.0 and not reward.burst:
			reward.burst = true
			Sfx.play("duel/heart_break")
		if age >= HEART_BURST + COIN_FLIGHT and not reward.arrived:
			reward.arrived = true
			if reward.coin:
				Sfx.play("coins/compensation")


## Rules settle immediately; presentation reveals each loss and coin in order.
func displayed_hp(state: WizardState) -> float:
	var value := state.hp
	for reward in loss_rewards:
		if reward.team == state.team and not reward.burst:
			value += 0.5
	return value


func displayed_gold(state: WizardState) -> int:
	var value := state.gold
	for reward in loss_rewards:
		if reward.team == state.team and reward.coin and not reward.arrived:
			value -= 1
	for coin in harvest_coins:
		if coin.team == state.team and not coin.arrived:
			value -= 1
	return value


## Centre of heart `index` of a wizard showing `count` hearts: up to HEART_ARC
## on one arc above the medallion; more split evenly over two concentric arcs,
## the inner one first (hearts are lost from the end, the outer arc first).
## Hearts keep the same spacing along their arc whatever their number.
static func heart_pos(team: int, index: int, count: int) -> Vector2:
	var row := 0
	var in_row := count
	var first := 0
	if count > HEART_ARC:
		var inner := ceili(count / 2.0)
		row = 0 if index < inner else 1
		in_row = inner if row == 0 else count - inner
		first = 0 if row == 0 else inner
	var radius := MEDALLION_RADIUS + HEART_INNER + row * HEART_ROW_GAP
	var step := HEART_SPACING / radius
	var angle := -PI * 0.5 + (index - first - (in_row - 1) * 0.5) * step
	return medallion_centers[team] + Vector2.from_angle(angle) * radius


## Centre of charge crystal `index` (0 to 2, left to right) under a medallion.
static func crystal_pos(team: int, index: int) -> Vector2:
	var radius := MEDALLION_RADIUS + CRYSTAL_RING
	var angle := PI * 0.5 + (1 - index) * CRYSTAL_SPACING / radius
	return medallion_centers[team] + Vector2.from_angle(angle) * radius


## Centre of the coin in a wizard's gold pill, right of its medallion.
static func gold_pos(team: int) -> Vector2:
	return medallion_centers[team] + Vector2(MEDALLION_RADIUS + PILL_GAP + 16, PILL_DROP)


## Places the board, the bench, the fight button and the medallions for a
## duel's rules, then the shop column: the screen grows with the rules the
## journey has introduced instead of leaving their places empty.
static func layout_screen(rules: Ruleset) -> void:
	var shop := rules.has(Ruleset.SHOP)
	var board_x := SHOP_BOARD_X if shop else SHOPLESS_BOARD_X
	var medallion_x := SHOP_MEDALLION_X if shop else SHOPLESS_MEDALLION_X
	Rules.BOARD_POS = Vector2(board_x, Rules.BOARD_POS.y)
	medallion_centers = [Vector2(medallion_x, PLAYER_MEDALLION_Y), Vector2(medallion_x, ENEMY_MEDALLION_Y)]
	# The bench and the fight button share the row under the board in every
	# duel, so the button the first duels teach stays where it will always be.
	var bench_width := Rules.CELL * Rules.RESERVE_CAP
	var row := bench_width + FIGHT_BENCH_GAP + Rules.FIGHT_RADIUS * 2.0
	var bench_x := board_x + (Rules.BOARD_SIZE.x - row) * 0.5
	var fight_x := bench_x + bench_width + FIGHT_BENCH_GAP + Rules.FIGHT_RADIUS
	Rules.RESERVE_POS = Vector2(bench_x, BENCH_Y)
	Rules.FIGHT_CENTER = Vector2(fight_x, FIGHT_Y)
	layout_column(rules)


# --- Geometry used for hit tests -------------------------------------------------

static func offer_rect(i: int) -> Rect2:
	return Rect2(shop_rect().position + Vector2(0, i * OFFER_STEP), OFFER_SIZE)


## Vertical offset of the stall and the scroll (set per duel by layout_column):
## the constants above describe the column at offset 0.
static var column_dy := 0.0
## Least offset: keeps the awning clear of the round frieze.
const COLUMN_MIN_DY := 10.0
## Space kept between the bottom of the column and the screen edge (the fight
## button now sits under the board, left of the column).
const COLUMN_BOTTOM_GAP := 12.0


## Places the stall (and the scroll, once introduced) for a duel's rules:
## centred on the board's height when it fits, otherwise as low as the screen
## allows, and never against the frieze.
static func layout_column(rules: Ruleset) -> void:
	var top := AWNING_TOP
	var bottom := STALL_RECT.end.y
	if rules.any_upgrade():
		bottom = SCROLL_TOP + scroll_length(rules) + 8.0 # lower rod
	var centred := Rules.BOARD_POS.y + Rules.BOARD_SIZE.y * 0.5 - (top + bottom) * 0.5
	var lowest := 720.0 - COLUMN_BOTTOM_GAP - bottom
	column_dy = maxf(COLUMN_MIN_DY, minf(centred, lowest))


static func stall_rect() -> Rect2:
	return Rect2(STALL_RECT.position + Vector2(0, column_dy), STALL_RECT.size)


static func awning_top() -> float:
	return AWNING_TOP + column_dy


## Creature offers and reroll; also the sell drop zone.
static func shop_rect() -> Rect2:
	return Rect2(Rules.SHOP_RECT.position + Vector2(0, column_dy), Rules.SHOP_RECT.size)


static func reroll_rect() -> Rect2:
	return Rect2(REROLL_RECT.position + Vector2(0, column_dy), REROLL_RECT.size)


## Centre of the scroll's top rod.
static func scroll_top() -> float:
	return SCROLL_TOP + column_dy


## Centre of the creature token drawn on offer i.
static func offer_token_pos(i: int) -> Vector2:
	return offer_rect(i).position + Vector2(48, 38)


## Row of wand upgrade i (Rules.WAND_UPGRADES order) on the unrolled scroll.
## With `rules`, upgrades the journey has not introduced take no row: the
## introduced ones close up from the top.
static func upgrade_rect(i: int, rules: Ruleset = null) -> Rect2:
	var row := i
	if rules != null:
		row = 0
		for j in i:
			if rules.allows_upgrade(Rules.WAND_UPGRADES[j]):
				row += 1
	return Rect2(Vector2(SCROLL_X.x + 8, UPGRADE_TOP + column_dy + row * UPGRADE_STEP), UPGRADE_SIZE)


## Rod-to-rod length of the unrolled scroll: just enough for the introduced
## upgrades (SCROLL_LENGTH holds all four).
static func scroll_length(rules: Ruleset = null) -> float:
	var hidden := 0
	if rules != null:
		for id in Rules.WAND_UPGRADES:
			if not rules.allows_upgrade(id):
				hidden += 1
	return SCROLL_LENGTH - hidden * UPGRADE_STEP


## The three composition cards, centred on the board wherever it stands.
static func pack_rect(i: int) -> Rect2:
	return Rect2(Vector2(Rules.BOARD_POS.x + 12 + i * 188, PACK_TOP), Vector2(PACK_CARD_SIZE))


static func difficulty_rect(i: int) -> Rect2:
	return Rect2(Vector2(372 + i * 184, 170), Vector2(DIFFICULTY_CARD_SIZE))


## Opponent hat shown in the enemy panel: the hovered card previews its level.
func shown_difficulty() -> int:
	if game.phase == game.Phase.DIFFICULTY and not unlock_animation_active():
		for i in Difficulty.COUNT:
			if game.is_difficulty_unlocked(i) and difficulty_rect(i).has_point(get_global_mouse_position()):
				return i
	return game.enemy.ai_level


## Creature j of the n shown on card i, centred; four creatures sit closer.
static func pack_token_pos(i: int, j: int, n: int) -> Vector2:
	var spacing := 54.0 if n <= 3 else 40.0
	var r := pack_rect(i)
	return Vector2(r.get_center().x + (j - (n - 1) * 0.5) * spacing, r.position.y + 88)


static func pack_token_radius(n: int) -> float:
	return 24.0 if n <= 3 else 19.0


static func charge_pos(i: int) -> Vector2:
	return Vector2(640 + (i - 1) * 64, 584)


# --- Drawing ------------------------------------------------------------------------

func _refresh_layers() -> void:
	for layer_name in _layers:
		var layer: Dictionary = _layers[layer_name]
		var key: Variant = _layer_key(layer_name)
		if key == null or key != layer.key:
			layer.key = key
			layer.node.queue_redraw()


## What a layer shows, compared each frame to skip unchanged redraws; null for
## layers that animate every frame.
func _layer_key(layer_name: String) -> Variant:
	match layer_name:
		"panels":
			return [game.phase, game.round_num, _wizard_key(game.enemy), _wizard_key(game.player)]
		"shop":
			return _shop_key()
	return null


func _wizard_key(state: WizardState) -> Array:
	var key := [state.max_hp, displayed_hp(state), displayed_gold(state), _wizard_pulse(state.team), state.harvest_total(),
		state.start_charges()]
	if game.battle != null:
		var spell: ShiftSpell = game.battle.spells[state.team]
		key.append_array([spell.charges, spell.progress()])
	return key


func _shop_key() -> Array:
	var player: WizardState = game.player
	var key := [game.shop_out, game.phase, player.gold, player.offers.duplicate(), player.locked.duplicate(),
		game.drag != null, game.shop_drag_index, player.can_reroll(), player.field_count(), game.enemy_preparing,
		player.upgrades.duplicate(), game.scroll_open]
	if smoothstep(0.0, 1.0, float(game.shop_out)) >= 1.0:
		return key # off screen: nothing else shows
	var mouse := get_global_mouse_position()
	for i in Rules.SHOP_SIZE:
		key.append(offer_rect(i).has_point(mouse))
	for i in Rules.WAND_UPGRADES.size():
		key.append(upgrade_rect(i, game.ruleset).has_point(mouse))
	key.append(Rules.FIGHT_CENTER.distance_to(mouse) < Rules.FIGHT_RADIUS)
	key.append(shop_rect().has_point(mouse))
	if game.enemy_preparing:
		key.append(Time.get_ticks_msec()) # the spinner around the fight button turns
	elif _fight_ready() and fight_glint(Time.get_ticks_msec() / 1000.0) >= 0.0:
		key.append(Time.get_ticks_msec()) # the glint crosses the fight button
	else:
		key.append(-1)
	if not offer_flips.is_empty() or reroll_glint(game.reroll_sense_time) >= 0.0:
		key.append(Time.get_ticks_msec()) # offers turn over, or the glint crosses the reroll button
	return key


## Draws one layer, from the bottom: side panels, then the round frieze and
## phase screens, then the shop column, then hover card and travelling effects.
func _draw_layer(layer_name: String, layer: CanvasItem) -> void:
	_ci = layer
	match layer_name:
		"panels":
			_draw_wizard(game.enemy)
			_draw_wizard(game.player)
		"base":
			_draw_enemy_hat()
			_draw_round_frieze()
			match game.phase:
				game.Phase.DIFFICULTY, game.Phase.PACK:
					_ci.draw_rect(get_viewport_rect(), Color(0, 0, 0, 0.45))
					if game.phase == game.Phase.DIFFICULTY:
						_draw_difficulty_choice()
					else:
						_draw_pack_choice()
				game.Phase.COMBAT:
					_draw_combat_hud()
				game.Phase.RESOLVE:
					_draw_combat_hud()
					_draw_result()
				game.Phase.OVER:
					_draw_game_over()
		"shop":
			_draw_shop_column()
		"overlay":
			_draw_learning_cast_hint()
			_draw_merge_lesson()
			if not game.hover_info.is_empty() and game.drag == null and game.phase != game.Phase.RESOLVE:
				_draw_hover_card(game.hover_info)
			_draw_upgrade_tooltip()
			_draw_loss_rewards()
			_draw_harvest()
			_draw_enemy_preparation()
			if game.shop_drag_index >= 0 and game.drag_visual_active():
				# Shop previews travel above the cards and side panels, without being
				# purchased or placed on the bench until the mouse is released.
				var p: Vector2 = game.shop_drag_position
				Shapes.circle(_ci, p + Vector2(4, 10), 22, Color(0, 0, 0, 0.3))
				Icons.token(_ci, game.drag.form_id, p, Rules.BODY_RADIUS * Rules.CELL * 1.1, 0, true)
			game.spotlight.draw(_ci)
			_draw_harvest_gain()
			_draw_abandon()
	_ci = self


## Invite an allied cast, then an enemy cast, without blocking the duel.
func _draw_learning_cast_hint() -> void:
	var unit: Unit = game.learning_cast_target()
	if unit == null:
		return
	# Real time: the duel may be stopped while the cast waits.
	var t := Time.get_ticks_msec() / 1000.0
	var p: Vector2 = Rules.BOARD_POS + unit.position
	Icons.shift_reticle(_ci, p, 22, t, unit.team == 0, true)
	Icons.wand(_ci, p + Vector2(36, -40 + sin(t * 3.0) * 6), 18)


## True when the demonstrated copies complete the target's group: a star forms.
static func _merge_demo_stars(demo: Dictionary) -> bool:
	var target: OwnedCreature = demo.target
	return target.merge_copies + demo.sources.size() >= 3


## Seconds into the merge demonstration's loop, on real time: each copy's
## flight in turn, then the star when one forms.
func _merge_demo_time(demo: Dictionary) -> float:
	var period: float = MERGE_DEMO_PERIOD * demo.sources.size() + (MERGE_DEMO_STAR if _merge_demo_stars(demo) else 0.0)
	return fmod(Time.get_ticks_msec() / 1000.0, period)


## Phase of copy `index`'s flight, 0 to 1 (0 before its turn, 1 after it).
static func _merge_flight(time: float, index: int) -> float:
	return clampf(time / MERGE_DEMO_PERIOD - index, 0.0, 1.0)


## Point along the merge demonstration's arc, k from 0 (source) to 1 (target).
static func _merge_arc(from: Vector2, to: Vector2, k: float) -> Vector2:
	var lift := clampf(from.distance_to(to) * 0.3, 48.0, 90.0) # clears neighbouring tokens
	return from.lerp(to, k) + Vector2(0, -sin(k * PI) * lift)


## The thief's lesson: a dotted gold arc from each copy to the identical target;
## the copies fly in one after the other (translucent, drawn by
## _draw_merge_ghost), the target pulses and its merge pips fill as each lands,
## and when the group is complete a star pops above it (playtest, 21 November
## 2026: three shield guardians merge into a one-star guardian).
func _draw_merge_lesson() -> void:
	var demo: Dictionary = game.merge_demo()
	if demo.is_empty():
		return
	var to: Vector2 = demo.to
	var target: OwnedCreature = demo.target
	var time := _merge_demo_time(demo)
	var landed_copies := 0
	var pulse := 0.0
	for index in demo.sources.size():
		var from: Vector2 = demo.sources[index]
		var t := _merge_flight(time, index)
		if t > 0.7:
			landed_copies += 1
		pulse = maxf(pulse, smoothstep(0.68, 0.74, t) * (1.0 - smoothstep(0.92, 1.0, t)))
		if t >= 0.8:
			continue # a landed copy's arc is gone until the loop restarts
		for i in range(1, 10):
			Shapes.circle(_ci, _merge_arc(from, to, i / 10.0), 3.0, Color(Icons.GOLD, 0.55))
		var tip := _merge_arc(from, to, 0.93)
		var dir := (to - tip).normalized()
		_ci.draw_colored_polygon(PackedVector2Array([tip + dir * 10, tip - dir * 4 + dir.orthogonal() * 7,
			tip - dir * 4 - dir.orthogonal() * 7]), Color(Icons.GOLD, 0.8))
	Shapes.arc(_ci, to, 28 + pulse * 8, 0, TAU, 32, Color(Icons.GOLD, 0.5 + pulse * 0.5), 3.0, true)
	Icons.merge_progress(_ci, to + Vector2(0, 30), mini(target.merge_copies + landed_copies, 3), target.stars)
	if not _merge_demo_stars(demo):
		return
	# The last copy lands at 0.7 of its flight: the star pops out of the target.
	var star_age: float = time - MERGE_DEMO_PERIOD * (demo.sources.size() - 1 + 0.7)
	if star_age < 0.0:
		return
	var at := to + Vector2(0, -32)
	var burst := clampf(star_age / 0.5, 0.0, 1.0)
	Shapes.arc(_ci, at, 8.0 + burst * 30.0, 0, TAU, 32, Color(Icons.GOLD, 0.85 * (1.0 - burst)), 2.5, true)
	for i in 6:
		var direction := Vector2.from_angle(TAU * i / 6.0 + 0.3)
		Icons.star(_ci, at + direction * (10.0 + burst * 26.0), 4.0 * (1.0 - burst), Color(Icons.GOLD, 1.0 - burst))
	var pop := smoothstep(0.0, 0.12, star_age) * (1.0 + 0.6 * exp(-6.0 * star_age))
	var count := mini(target.stars + 1, Rules.MAX_STARS)
	for i in count:
		Icons.star(_ci, at + Vector2((i - (count - 1) * 0.5) * 11.0, 0), 6.0 * (pop if i == count - 1 else 1.0))


func _draw_merge_ghost() -> void:
	var demo: Dictionary = game.merge_demo() if game != null else {}
	if demo.is_empty():
		return
	var time := _merge_demo_time(demo)
	var index := mini(floori(time / MERGE_DEMO_PERIOD), demo.sources.size() - 1)
	var t := _merge_flight(time, index)
	var k := smoothstep(0.15, 0.7, t)
	_merge_ghost.modulate = Color(1, 1, 1, 0.75 * smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.7, 0.8, t)))
	var p := _merge_arc(demo.sources[index], demo.to, k)
	var target: OwnedCreature = demo.target
	Shapes.circle(_merge_ghost, p + Vector2(4, 12), 20, Color(0, 0, 0, 0.3))
	Icons.token(_merge_ghost, target.form_id, p, Rules.BODY_RADIUS * Rules.CELL, 0, true)


func _panel(r: Rect2, col := Color(0.12, 0.09, 0.08, 0.85)) -> void:
	_ci.draw_rect(r, col)
	_ci.draw_rect(r, Color(0.45, 0.32, 0.2), false, 2.0)


## Panel shake after a lost heart (x) and gold coin pulse (y) of a wizard.
func _wizard_pulse(team: int) -> Vector2:
	var impact := 0.0
	var coin_pulse := 0.0
	for reward in loss_rewards:
		if reward.team != team:
			continue
		var age: float = reward_time - reward.start
		if age >= 0.0 and age < 0.24:
			impact = maxf(impact, 1.0 - age / 0.24)
		var arrival_age := age - HEART_BURST - COIN_FLIGHT
		if reward.coin and arrival_age >= 0.0 and arrival_age < REWARD_TAIL:
			coin_pulse = maxf(coin_pulse, 1.0 - arrival_age / REWARD_TAIL)
	for coin in harvest_coins:
		var landed: float = harvest_time - coin.fly - HARVEST_FLIGHT
		if coin.team == team and landed >= 0.0 and landed < REWARD_TAIL:
			coin_pulse = maxf(coin_pulse, 1.0 - landed / REWARD_TAIL)
	if team == 1 and game.phase == game.Phase.PREP and not game.enemy_action.is_empty():
		var action: Dictionary = game.enemy_action
		if action.kind == "buy" and action.t < 0.45:
			coin_pulse = maxf(coin_pulse, (1.0 - action.t / 0.45) * 0.7)
	return Vector2(impact, coin_pulse)


func _hat_position(team: int) -> Vector2:
	var impact := _wizard_pulse(team).x
	var shake := Vector2(sin(reward_time * 95.0) * 5.0, cos(reward_time * 80.0) * 2.0) * impact
	return medallion_centers[team] + shake


## The opponent animates, so it is drawn every frame above its panel: a journey
## opponent's portrait, otherwise the hat of the difficulty (its level shows on
## hover during the choice).
func _draw_enemy_hat() -> void:
	var impact := _wizard_pulse(1).x
	if game.opponent >= 0:
		var id: String = OpponentDB.get_opponent(game.opponent).id
		Icons.opponent(_ci, id, _hat_position(1) + Vector2(0, 2), 26 * (1.0 + impact * 0.12), Time.get_ticks_msec() / 1000.0)
		return
	Icons.difficulty_hat(_ci, shown_difficulty(), _hat_position(1) + Vector2(0, 5), 26 * (1.0 + impact * 0.12), Time.get_ticks_msec() / 1000.0)


## A wizard's medallion: its portrait in a disc ringed in its team colour and
## gold (the opponent's portrait is drawn over it by _draw_enemy_hat), its
## hearts on arcs above, its charge crystals below and its gold on the right.
func _draw_wizard(state: WizardState) -> void:
	var team := state.team
	var pulse := _wizard_pulse(team)
	var impact := pulse.x
	var coin_pulse := pulse.y
	var hat_pos := _hat_position(team)
	var r := MEDALLION_RADIUS * (1.0 + impact * 0.08)
	Shapes.circle(_ci, hat_pos, r, Color(0.1, 0.075, 0.07).lerp(Color(0.6, 0.08, 0.12), impact * 0.6))
	Shapes.circle(_ci, hat_pos, r - 3, Color(Icons.team_color(team), 0.16))
	Shapes.arc(_ci, hat_pos, r, 0, TAU, 40, Icons.team_color(team), 3.0, true)
	Shapes.arc(_ci, hat_pos, r + 4, 0, TAU, 40, Icons.GOLD, 1.5, true)
	if team == 0:
		Icons.wizard_hat(_ci, hat_pos + Vector2(0, -2), 29 * (1.0 + impact * 0.12), team)
	var shown_hp := displayed_hp(state)
	for i in state.max_hp:
		Icons.wizard_heart(_ci, heart_pos(team, i, state.max_hp), 8, clampf(shown_hp - i, 0.0, 1.0))
	# Spell charges (live in combat; the starting charges otherwise), for a
	# wizard who casts in this duel.
	var spell: ShiftSpell = null
	if game.battle != null:
		spell = game.battle.spells[team]
	for i in (Rules.MAX_CHARGES if state.can_cast() else 0):
		var p := crystal_pos(team, i)
		var count: int = spell.charges if spell else state.start_charges()
		var filled: bool = count > i
		var prog := 0.0
		if spell and i == spell.charges:
			prog = spell.progress()
		Icons.charge_crystal(_ci, p, 14, filled, prog)
	if not state.rules.has(Ruleset.SHOP):
		return # no gold before the journey introduces the shop
	# The gold pill: the purse, its count and, for the player, the next income.
	var coin := gold_pos(team)
	var gold := str(displayed_gold(state))
	var width := 46.0 + gold.length() * 16.0
	var next_income := -1
	if team == 0 and game.phase != game.Phase.PACK:
		next_income = Rules.income(game.round_num + 1)
		if game.phase == game.Phase.PREP:
			# The current board's harvest is paid when this round's fight begins.
			next_income += state.harvest_total()
		width += 22.0 + str(next_income).length() * 10.0
	var pill := Rect2(coin - Vector2(22, 18), Vector2(width, 36))
	Shapes.circle(_ci, pill.position + Vector2(18, 18), 18, Color(0.14, 0.1, 0.08))
	Shapes.circle(_ci, pill.end - Vector2(18, 18), 18, Color(0.14, 0.1, 0.08))
	_ci.draw_rect(Rect2(pill.position + Vector2(18, 0), Vector2(width - 36, 36)), Color(0.14, 0.1, 0.08))
	Icons.coin(_ci, coin, 13 * (1.0 + coin_pulse * 0.45))
	_ci.draw_string(font, coin + Vector2(18, 10 - coin_pulse * 5), gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Icons.GOLD.lerp(Color.WHITE, coin_pulse))
	if next_income >= 0:
		var at := coin + Vector2(24 + gold.length() * 16.0, 0)
		Icons.coin(_ci, at + Vector2(8, 0), 7)
		_ci.draw_string(font, at + Vector2(17, 6), "+" + str(next_income), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.8, 0.5, 0.7))


func _draw_loss_rewards() -> void:
	for reward in loss_rewards:
		var age: float = reward_time - reward.start
		var origin := heart_pos(reward.team, reward.heart, game.states[reward.team].max_hp)
		var dest := gold_pos(reward.team)
		# Anticipation: the next heart swells and flashes before it breaks.
		if age >= -0.16 and age < 0.0:
			var anticipation := (age + 0.16) / 0.16
			Icons.heart_half(_ci, origin, 9.0 + anticipation * 7.0, reward.half, Color(1, 0.3, 0.4).lerp(Color.WHITE, anticipation))
		if age < 0.0:
			continue
		if age < 0.48:
			var k := age / 0.48
			Shapes.arc(_ci, origin, 7 + 33 * k, 0, TAU, 32, Color(1, 0.35, 0.4, 1.0 - k), 4.0 * (1.0 - k) + 1.0, true)
			for j in 9:
				var direction := Vector2.from_angle(TAU * j / 9.0 + reward.heart * 0.7)
				var p := origin + direction * (12 + 38 * k) + Vector2(0, 30 * k * k)
				Icons.heart_half(_ci, p, 4.5 * (1.0 - k), reward.half, Color(1, 0.18, 0.3, 1.0 - k))
		if age < HEART_BURST:
			var k := age / HEART_BURST
			Icons.heart_half(_ci, origin + Vector2(0, -8 * k), 16 * (1.0 - k), reward.half, Color(1, 0.65, 0.7, 1.0 - k))
		if not reward.coin:
			continue
		var flight := (age - HEART_BURST) / COIN_FLIGHT
		if flight >= 0.0 and flight < 1.0:
			var control := origin.lerp(dest, 0.5) + Vector2(100, -45)
			# Curved, accelerating flight, with a gold trail and spinning coin.
			var progress := flight * flight
			for j in 7:
				var t := maxf(0.0, progress - j * 0.035)
				var trail := origin.bezier_interpolate(control, control, dest, t)
				Shapes.circle(_ci, trail, 6.0 - j * 0.65, Color(1, 0.75, 0.12, (1.0 - j / 7.0) * 0.5))
			var p := origin.bezier_interpolate(control, control, dest, progress)
			Shapes.set_transform(_ci, p, sin(flight * TAU * 2) * 0.2, Vector2(0.35 + absf(cos(flight * TAU * 2)) * 0.65, 1))
			Icons.coin(_ci, Vector2.ZERO, 13 + sin(flight * PI) * 4)
			Shapes.set_transform(_ci, Vector2.ZERO, 0, Vector2.ONE)
		var arrived := age - HEART_BURST - COIN_FLIGHT
		if arrived >= 0.0 and arrived < REWARD_TAIL:
			var k := arrived / REWARD_TAIL
			Shapes.arc(_ci, dest, 16 + 30 * k, 0, TAU, 32, Color(1, 0.85, 0.3, 1.0 - k), 4 * (1.0 - k), true)
			for j in 7:
				Icons.star(_ci, dest + Vector2.from_angle(TAU * j / 7.0) * (18 + k * 28), 5 * (1.0 - k), Color(1, 0.9, 0.35, 1.0 - k))


func _draw_harvest() -> void:
	# Harvester burst: a golden flash and ring with sparkles under the hop.
	for src in harvest_sources:
		var age: float = harvest_time - src.start
		if age < 0.0 or age >= 0.5:
			continue
		var k := age / 0.5
		var p: Vector2 = src.pos
		Shapes.circle(_ci, p, 30.0 * (1.0 - k * 0.4), Color(1.0, 0.85, 0.3, 0.35 * (1.0 - k)))
		Shapes.arc(_ci, p, 18.0 + 36.0 * k, 0, TAU, 32, Color(1.0, 0.85, 0.3, 1.0 - k), 5.0 * (1.0 - k) + 1.0, true)
		for j in 8:
			var q := p + Vector2.from_angle(TAU * j / 8.0 + 0.4) * (22.0 + 30.0 * k)
			Icons.star(_ci, q, 5.0 * (1.0 - k), Color(1.0, 0.92, 0.45, 1.0 - k))
	for coin in harvest_coins:
		var age: float = harvest_time - coin.start
		if age < 0.0:
			continue
		var from: Vector2 = coin.from
		var hover: Vector2 = from + coin.offset
		var dest := gold_pos(coin.team)
		var flight: float = (harvest_time - coin.fly) / HARVEST_FLIGHT
		var spin: float = harvest_time * 9.0 + coin.index * 0.8
		if flight < 0.0:
			# Pop out with an overshoot, then hover, bobbing, spinning and twinkling.
			var k := clampf(age / HARVEST_POP, 0.0, 1.0)
			var e := 1.0 + 2.70158 * pow(k - 1.0, 3) + 1.70158 * pow(k - 1.0, 2)
			var p := _coin_position(coin)
			_spinning_coin(p, 13.0 * (0.35 + 0.65 * e), spin)
			if k >= 1.0 and fmod(harvest_time * 3.0 + coin.index * 0.37, 1.0) < 0.3:
				var tw := fmod(harvest_time * 3.0 + coin.index * 0.37, 1.0) / 0.3
				Icons.star(_ci, p + Vector2(9, -9), 5.0 * sin(tw * PI), Color(1, 1, 0.85))
		elif flight < 1.0:
			# Curved, accelerating flight with a fading gold trail.
			var control := hover.lerp(dest, 0.5) + Vector2(0, -90)
			var progress := flight * flight
			for j in 8:
				var t := maxf(0.0, progress - j * 0.03)
				var trail := hover.bezier_interpolate(control, control, dest, t)
				Shapes.circle(_ci, trail, 6.5 - j * 0.7, Color(1, 0.75, 0.12, (1.0 - j / 8.0) * 0.55))
			_spinning_coin(_coin_position(coin), 13.0 + sin(flight * PI) * 5.0, spin)
		else:
			# Landing: a ring and a little star burst on the purse.
			var k := clampf((flight - 1.0) * HARVEST_FLIGHT / REWARD_TAIL, 0.0, 1.0)
			Shapes.arc(_ci, dest, 16 + 26 * k, 0, TAU, 32, Color(1, 0.85, 0.3, 1.0 - k), 4 * (1.0 - k) + 0.5, true)
			for j in 5:
				var a: float = TAU * j / 5.0 + coin.index * 0.6
				Icons.star(_ci, dest + Vector2.from_angle(a) * (16 + k * 24), 4.5 * (1.0 - k), Color(1, 0.9, 0.35, 1.0 - k))


## The way back to the map in a replayed duel, then, once asked, the paused
## duel under a dimmed screen with the island medallion, a check (back to the
## map) and a cross (resume).
func _draw_abandon() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var mouse := get_global_mouse_position()
	if not game.abandon_asked:
		if game.can_abandon():
			var hot := ABANDON_POS.distance_to(mouse) < ABANDON_RADIUS
			Icons.island_medallion(_ci, ABANDON_POS, ABANDON_RADIUS * (ABANDON_HOVER_SCALE if hot else 1.0), t, hot)
		return
	_ci.draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), Color(0.04, 0.03, 0.06, 0.66))
	Icons.island_medallion(_ci, CONFIRM_MEDALLION, 52, t)
	for yes in [true, false]:
		var c: Vector2 = CONFIRM_YES if yes else CONFIRM_NO
		var hot := c.distance_to(mouse) < CONFIRM_RADIUS
		var r := CONFIRM_RADIUS * (ABANDON_HOVER_SCALE if hot else 1.0)
		var fill := Color("2f6b3a") if yes else Color("6b2f2f")
		var edge := Color("9fe1a0") if yes else Color("f09595")
		Shapes.circle(_ci, c, r, fill.lightened(0.12) if hot else fill)
		Shapes.arc(_ci, c, r, 0, TAU, 40, edge.lightened(0.3) if hot else edge, 3.0, true)
		var k := r / 20.0
		var ink := Color("eaffea") if yes else Color("ffecec")
		if yes:
			Shapes.polyline(_ci, PackedVector2Array([c + Vector2(-8, 0) * k, c + Vector2(-2, 6) * k, c + Vector2(9, -6) * k]), ink, 3.5 * k)
		else:
			Shapes.line(_ci, c + Vector2(-6, -6) * k, c + Vector2(6, 6) * k, ink, 3.5 * k)
			Shapes.line(_ci, c + Vector2(6, -6) * k, c + Vector2(-6, 6) * k, ink, 3.5 * k)


## The harvest lesson's gold rises beside the purse once its coins have landed,
## above the spotlight's dimming.
func _draw_harvest_gain() -> void:
	if harvest_lesson.is_empty():
		return
	var rise: float = (harvest_time - harvest_lesson.landed) / harvest_speed / HARVEST_LESSON_GAIN_TIME
	if rise < 0.0 or rise >= 1.0:
		return
	var at := gold_pos(harvest_lesson.team) + Vector2(54, 8 - 24 * rise)
	var size := roundi(28 + 8 * sin(minf(rise * 4.0, 1.0) * PI))
	var alpha := 1.0 - smoothstep(0.6, 1.0, rise)
	var text := "+%d" % harvest_lesson.gold
	_ci.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.2, 0.12, 0.05, alpha))
	_ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Icons.GOLD.lerp(Color.WHITE, 0.35), alpha))


## Where a harvest coin is now: popping out of its harvester and hovering
## above it, then flying along its curve into the purse.
func _coin_position(coin: Dictionary) -> Vector2:
	var from: Vector2 = coin.from
	var hover: Vector2 = from + coin.offset
	var dest := gold_pos(coin.team)
	var flight: float = (harvest_time - coin.fly) / HARVEST_FLIGHT
	if flight >= 1.0:
		return dest
	if flight >= 0.0:
		var control := hover.lerp(dest, 0.5) + Vector2(0, -90)
		return hover.bezier_interpolate(control, control, dest, flight * flight)
	var k := clampf((harvest_time - coin.start) / HARVEST_POP, 0.0, 1.0)
	var e := 1.0 + 2.70158 * pow(k - 1.0, 3) + 1.70158 * pow(k - 1.0, 2)
	return from.lerp(hover, e) + Vector2(0, -sin(k * PI) * 14.0 + sin(harvest_time * 10.0 + coin.index) * 2.0 * k)


## A coin seen turning on its vertical axis, with a bright rim on its edge.
func _spinning_coin(p: Vector2, r: float, spin: float) -> void:
	Shapes.circle(_ci, p + Vector2(2, 4), r * 0.9, Color(0, 0, 0, 0.25))
	Shapes.set_transform(_ci, p, 0.0, Vector2(0.25 + absf(cos(spin)) * 0.75, 1.0))
	Icons.coin(_ci, Vector2.ZERO, r)
	Shapes.set_transform(_ci, Vector2.ZERO, 0.0, Vector2.ONE)
	Shapes.circle(_ci, p + Vector2(-r * 0.3, -r * 0.35), r * 0.18, Color(1, 1, 0.9, 0.8))


## Finished rounds as pips in the winner's colour (grey for a draw), the current
## round as a gold medallion with its number, upcoming rounds as fading dashes.
## Once the round resolves, the medallion's ring takes the winner's colour.
func _draw_round_frieze() -> void:
	var current := maxi(1, game.round_num)
	var winners: Array[int] = game.round_winners
	var k := smoothstep(0.0, 1.0, frieze_time / FRIEZE_SLIDE)
	var center := Vector2(Rules.BOARD_POS.x + Rules.BOARD_SIZE.x * 0.5, FRIEZE_Y) + Vector2(FRIEZE_STEP * (1.0 - k), 0)
	# The oldest pip fades out while the frieze slides.
	var oldest := maxi(1, current - FRIEZE_PAST - (1 if k < 1.0 else 0))
	Shapes.line(_ci, center - Vector2((current - oldest) * FRIEZE_STEP, 0),
		center + Vector2(FRIEZE_FUTURE * FRIEZE_STEP, 0), FRIEZE_LINE, 3.0, true)
	for r in range(oldest, current):
		var p := center - Vector2((current - r) * FRIEZE_STEP, 0)
		var alpha := 1.0 - k if current - r > FRIEZE_PAST else 1.0
		var winner: int = winners[r - 1] if r - 1 < winners.size() else -1
		var col := Icons.team_color(winner) if winner >= 0 else FRIEZE_DRAW
		Shapes.circle(_ci, p, FRIEZE_PIP, Color(col, alpha))
		Shapes.arc(_ci, p, FRIEZE_PIP, 0, TAU, 20, Color(0, 0, 0, 0.35 * alpha), 1.5, true)
	for i in FRIEZE_FUTURE:
		var p := center + Vector2((i + 1) * FRIEZE_STEP, 0)
		_dashed_ring(p, FRIEZE_PIP - 1.0, Color(FRIEZE_LINE.lightened(0.2), 0.75 * (1.0 - float(i) / FRIEZE_FUTURE)))
	# Current round: pops up from pip size while sliding into the centre.
	var s := lerpf(FRIEZE_PIP / FRIEZE_RADIUS, 1.0, k)
	var radius := FRIEZE_RADIUS * s
	var resolved: bool = winners.size() >= current and game.phase in [game.Phase.RESOLVE, game.Phase.OVER]
	if resolved:
		var winner: int = winners[current - 1]
		var col := Icons.team_color(winner) if winner >= 0 else FRIEZE_DRAW
		Shapes.arc(_ci, center, radius + 4, 0, TAU, 32, col, 4.0, true)
	else:
		var pulse := fmod(Time.get_ticks_msec() / 1000.0, 1.6) / 1.6
		Shapes.arc(_ci, center, radius + 2 + 6 * pulse, 0, TAU, 32, Color(Icons.GOLD, 0.7 * (1.0 - pulse)), 3.0, true)
	Shapes.circle(_ci, center, radius, Color(0.15, 0.1, 0.12))
	Shapes.arc(_ci, center, radius, 0, TAU, 32, Icons.GOLD, 3.0, true)
	var font_size := int(round(22 * s))
	_ci.draw_string(font, center + Vector2(-20, 8 * s), str(current), HORIZONTAL_ALIGNMENT_CENTER, 40, font_size, Color(1.0, 0.92, 0.7))


func _dashed_ring(p: Vector2, radius: float, color: Color) -> void:
	const DASHES := 8
	for i in DASHES:
		var a := TAU * i / DASHES
		Shapes.arc(_ci, p, radius, a, a + TAU / DASHES * 0.55, 4, color, 2.0, true)


## The creature stall, the wand scroll and the fight button slide together off
## the right edge when the fight begins and back in when the next shop opens.
func _draw_shop_column() -> void:
	var k := smoothstep(0.0, 1.0, float(game.shop_out))
	if k >= 1.0:
		return
	Shapes.set_transform(_ci, Vector2(SHOP_SLIDE * k, 0), 0.0, Vector2.ONE)
	# The stall and the scroll appear as the journey introduces their rules.
	if game.ruleset.has(Ruleset.SHOP):
		_draw_stall()
		_draw_shop()
	if game.ruleset.any_upgrade():
		_draw_wand_scroll()
	# The fight button sits under the board: it drops out of sight instead.
	Shapes.set_transform(_ci, Vector2(0, FIGHT_SLIDE * k), 0.0, Vector2.ONE)
	_draw_fight_button()
	Shapes.set_transform(_ci, Vector2.ZERO, 0.0, Vector2.ONE)


## Merchant stall around the creature offers: wooden frame under a striped,
## scalloped awning.
func _draw_stall() -> void:
	_ci.draw_rect(stall_rect(), Color(0.17, 0.115, 0.08))
	_ci.draw_rect(stall_rect(), Color(0.54, 0.38, 0.22), false, 5.0)
	_ci.draw_rect(stall_rect().grow(-5), Color(0.29, 0.19, 0.125), false, 2.0)
	var left := stall_rect().position.x - 6
	var width := stall_rect().size.x + 12
	var bottom := stall_rect().position.y
	var stripe := width / AWNING_STRIPES
	for i in AWNING_STRIPES:
		var col := Color(0.79, 0.64, 0.29) if i % 2 else Color(0.48, 0.29, 0.16)
		var x := left + i * stripe
		_ci.draw_rect(Rect2(x, awning_top(), stripe, bottom - awning_top()), col)
		var scallop := PackedVector2Array()
		for j in 9:
			var a := PI * j / 8.0
			scallop.append(Vector2(x + stripe * 0.5 + cos(a) * stripe * 0.5, bottom + sin(a) * AWNING_SCALLOP))
		_ci.draw_colored_polygon(scallop, col)
	Shapes.line(_ci, Vector2(left - 4, awning_top()), Vector2(left + width + 4, awning_top()), Color(0.35, 0.23, 0.13), 6.0)


func _draw_shop() -> void:
	var trading: bool = game.ruleset.has(Ruleset.TRADE)
	var selling: bool = trading and game.drag != null and game.shop_drag_index < 0
	for i in Rules.SHOP_SIZE:
		var r := offer_rect(i)
		var id: String = game.player.offers[i] if i < game.player.offers.size() else ""
		var flip := _offer_flip(i)
		if not flip.is_empty():
			_draw_turning_offer(r, flip, id)
			continue
		if id == "":
			_draw_empty_offer(r)
			continue
		# Shown read-only during the fight: no purchase highlight.
		var hovered: bool = r.has_point(get_global_mouse_position()) and not selling and game.phase == game.Phase.PREP
		_draw_offer(r, id, hovered)
		if game.player.locked[i]:
			_ci.draw_rect(r.grow(-2), Icons.GOLD, false, 3.0)
			Icons.padlock(_ci, r.position + Vector2(266, 19))
	if not trading:
		return # no reroll and no selling before the journey introduces trading
	var reroll_ok: bool = game.player.can_reroll()
	_panel(reroll_rect(), Color(0.23, 0.18, 0.12) if reroll_ok else Color(0.1, 0.09, 0.08))
	Icons.restart(_ci, reroll_rect().position + Vector2(30, 18), 11, Icons.GOLD if reroll_ok else Color.DIM_GRAY)
	Icons.coin(_ci, reroll_rect().position + Vector2(116, 18), 10)
	_ci.draw_string(font, reroll_rect().position + Vector2(134, 25), str(Rules.REROLL_COST), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Icons.GOLD)
	if not reroll_ok:
		_ci.draw_rect(reroll_rect(), Color(0, 0, 0, 0.35))
	var glint := reroll_glint(game.reroll_sense_time)
	if glint >= 0.0:
		_draw_reroll_glint(reroll_rect(), glint)
	if selling:
		var r := shop_rect()
		var over := r.has_point(get_global_mouse_position())
		_ci.draw_rect(r, Color(0.9, 0.7, 0.1, 0.35 if over else 0.18))
		_ci.draw_rect(r, Icons.GOLD, false, 3.0)
		Icons.coin(_ci, r.get_center(), 34)
		Icons.arrow_right(_ci, r.get_center() + Vector2(0, -60), 22, Icons.GOLD)


func _draw_empty_offer(r: Rect2) -> void:
	_ci.draw_rect(r, Color(0.1, 0.08, 0.07, 0.6))
	_ci.draw_rect(r, Color(0.35, 0.25, 0.18), false, 2.0)


## An offer card: the creature and its price in coins, dimmed when too dear.
func _draw_offer(r: Rect2, id: String, hovered := false) -> void:
	var price: int = CreatureDB.get_form(id).price
	var affordable: bool = game.player.gold >= price
	_panel(r, Color(0.2, 0.14, 0.1) if hovered and affordable else Color(0.14, 0.1, 0.08))
	Icons.token(_ci, id, r.position + Vector2(48, 38), 30, 0, hovered and affordable)
	for j in price:
		Icons.coin(_ci, r.position + Vector2(112 + j * 32, 38), 13)
	if not affordable:
		_ci.draw_rect(r, Color(0, 0, 0, 0.55))


## Starts turning over the offers a reroll replaced, left to right; a locked
## offer stays. `before` holds the offers as they were.
func begin_reroll_flip(before: Array) -> void:
	offer_flips.clear()
	offer_flip_time = 0.0
	for i in mini(before.size(), game.player.offers.size()):
		if game.player.offers[i] != before[i]:
			offer_flips.append({"slot": i, "from": before[i], "start": offer_flips.size() * OFFER_FLIP_STAGGER})


func advance_offer_flips(dt: float) -> void:
	if offer_flips.is_empty():
		return
	offer_flip_time += dt
	if offer_flip_time >= float(offer_flips[-1].start) + OFFER_FLIP_TIME:
		offer_flips.clear()


func _offer_flip(slot: int) -> Dictionary:
	for flip in offer_flips:
		if flip.slot == slot:
			return flip
	return {}


## An offer turning over on a horizontal axis: the replaced offer (an empty
## slot shows nothing there), its plain wooden back, then the new offer,
## darker as the card turns edge-on.
func _draw_turning_offer(r: Rect2, flip: Dictionary, id: String) -> void:
	_draw_empty_offer(r)
	var u := clampf((offer_flip_time - float(flip.start)) / OFFER_FLIP_TIME, 0.0, 1.0)
	var old_side := u < 0.25
	var back := not old_side and u < 0.75
	if (old_side and flip.from == "") or (not old_side and not back and id == ""):
		return # nothing on that side: the empty slot shows
	var squash := absf(cos(u * TAU))
	if squash < 0.03:
		return
	# The shop column only slides sideways, so its transform is a translation.
	var column := Shapes.current_transform(_ci).origin
	Shapes.set_transform(_ci, column + r.get_center(), 0.0, Vector2(1.0, squash))
	var card := Rect2(-r.size * 0.5, r.size)
	if back:
		_ci.draw_rect(card, OFFER_BACK)
		_ci.draw_rect(card, Color(0.54, 0.38, 0.22), false, 3.0)
		_ci.draw_rect(card.grow(-7), Color(0.26, 0.17, 0.1), false, 2.0)
	else:
		_draw_offer(card, flip.from if old_side else id)
	_ci.draw_rect(card, Color(0, 0, 0, (1.0 - squash) * 0.45))
	Shapes.set_transform(_ci, column)


## Progress (0 to 1) of the glint across the reroll button after a reroll has
## made sense for `sense_time` seconds, or -1 between two sweeps.
static func reroll_glint(sense_time: float) -> float:
	if sense_time < REROLL_GLINT_DELAY:
		return -1.0
	var phase := fmod(sense_time - REROLL_GLINT_DELAY, REROLL_GLINT_PERIOD)
	return phase / REROLL_GLINT_SWEEP if phase < REROLL_GLINT_SWEEP else -1.0


## Two slanted bands of light cross the reroll button, clipped to it, and its
## frame catches the light as they pass: it draws the eye without the dimming
## of a rule spotlight, which made a reroll feel compulsory.
func _draw_reroll_glint(r: Rect2, sweep: float) -> void:
	var k := smoothstep(0.0, 1.0, sweep)
	var box := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var along := Vector2.from_angle(-PI * 0.5 + deg_to_rad(25.0)) * r.size.y * 1.6
	# Each band: offset behind the leading one, width, opacity.
	for band in [Vector3(0.0, 16.0, 0.4), Vector3(-34.0, 5.0, 0.3)]:
		var mid := Vector2(lerpf(r.position.x - 40.0, r.end.x + 40.0, k) + band.x, r.get_center().y)
		var across := Vector2(band.y * 0.5, 0.0)
		var shape := PackedVector2Array([mid - along - across, mid + along - across, mid + along + across, mid - along + across])
		for piece in Geometry2D.intersect_polygons(box, shape):
			_ci.draw_colored_polygon(piece, Color(1.0, 0.97, 0.85, band.z))
	_ci.draw_rect(r, Color(Icons.GOLD, 0.7 * sin(PI * k)), false, 2.0)


func _draw_fight_button() -> void:
	var ok := _fight_ready()
	var hovered := ok and Rules.FIGHT_CENTER.distance_to(get_global_mouse_position()) < Rules.FIGHT_RADIUS
	var c := Rules.FIGHT_CENTER
	var r := Rules.FIGHT_RADIUS * (FIGHT_HOVER_SCALE if hovered else 1.0)
	# Medallion split vertically: red combat half left, purple magic half right.
	var left := Color(0.6, 0.16, 0.12) if ok else Color(0.25, 0.2, 0.2)
	var right := Color(0.29, 0.16, 0.4) if ok else Color(0.22, 0.2, 0.25)
	var half := PackedVector2Array()
	for i in 17:
		half.append(c + Vector2.from_angle(PI * 0.5 + PI * i / 16.0) * r)
	_ci.draw_colored_polygon(half, left)
	for i in half.size():
		half[i] = c * 2.0 - half[i]
	_ci.draw_colored_polygon(half, right)
	var ring := Icons.GOLD if ok else Color(0.4, 0.35, 0.3)
	Shapes.line(_ci, c + Vector2(0, -r), c + Vector2(0, r), ring, 2.0)
	Icons.sword_and_wand(_ci, c, r, not ok)
	var sweep := fight_glint(Time.get_ticks_msec() / 1000.0) if ok else -1.0
	if sweep >= 0.0:
		_draw_fight_glint(c, r, sweep)
	Shapes.arc(_ci, c, r, 0, TAU, 40, ring.lightened(0.45) if hovered else ring, 4.0, true)
	if game.enemy_preparing:
		var t := Time.get_ticks_msec() / 1000.0
		Shapes.arc(_ci, Rules.FIGHT_CENTER, Rules.FIGHT_RADIUS + 8, t * 3, t * 3 + PI * 1.4, 32, Icons.GOLD, 3, true)


## True when a click on the fight button would start the combat.
func _fight_ready() -> bool:
	return game.player.field_count() > 0 and not game.enemy_preparing and game.drag == null


## Progress (0 to 1) of the light glint across the ready fight button at time t,
## or -1 between two sweeps: one FIGHT_GLINT_SWEEP-long pass every FIGHT_GLINT_PERIOD.
static func fight_glint(t: float) -> float:
	var phase := fmod(t, FIGHT_GLINT_PERIOD)
	return phase / FIGHT_GLINT_SWEEP if phase < FIGHT_GLINT_SWEEP else -1.0


## A slanted band of light crossing the medallion from left to right, clipped
## to its disc.
func _draw_fight_glint(c: Vector2, r: float, sweep: float) -> void:
	var disc := PackedVector2Array()
	for i in 32:
		disc.append(c + Vector2.from_angle(TAU * i / 32.0) * r)
	var along := Vector2.from_angle(-PI * 0.5 + deg_to_rad(25.0)) * r * 2.0
	var across := Vector2(r * 0.15, 0)
	var mid := c + Vector2(lerpf(-1.5, 1.5, smoothstep(0.0, 1.0, sweep)) * r, 0)
	var band := PackedVector2Array([mid - along - across, mid + along - across, mid + along + across, mid - along + across])
	for piece in Geometry2D.intersect_polygons(disc, band):
		_ci.draw_colored_polygon(piece, Color(1, 1, 1, 0.35))


## Purple scroll of wand upgrades between two rods. The bottom rod travels down
## as it unrolls; each row appears once the parchment has passed it.
func _draw_wand_scroll() -> void:
	var length := scroll_length(game.ruleset) * smoothstep(0.0, 1.0, float(game.scroll_open))
	var bottom := scroll_top() + length
	if length > 0.0:
		var body := Rect2(SCROLL_X.x, scroll_top(), SCROLL_X.y - SCROLL_X.x, length)
		_ci.draw_rect(body, Color(0.21, 0.12, 0.29))
		_ci.draw_rect(body.grow_individual(-6, 0, -6, 0), Color(0.33, 0.22, 0.45), false, 1.5)
	for i in Rules.WAND_UPGRADES.size():
		if not game.ruleset.allows_upgrade(Rules.WAND_UPGRADES[i]):
			continue # not yet introduced: no row at all
		var r := upgrade_rect(i, game.ruleset)
		if r.end.y + 6.0 <= bottom:
			_draw_upgrade_row(Rules.WAND_UPGRADES[i], r)
	_draw_scroll_rod(bottom)
	_draw_scroll_rod(scroll_top())


func _draw_scroll_rod(y: float) -> void:
	var wood := Color(0.36, 0.23, 0.13)
	_ci.draw_rect(Rect2(SCROLL_X.x - 8, y - 8, SCROLL_X.y - SCROLL_X.x + 16, 16), wood)
	_ci.draw_rect(Rect2(SCROLL_X.x - 4, y - 7, SCROLL_X.y - SCROLL_X.x + 8, 14), Color(0.45, 0.29, 0.62))
	Shapes.line(_ci, Vector2(SCROLL_X.x - 2, y - 3), Vector2(SCROLL_X.y + 2, y - 3), Color(0.62, 0.47, 0.8), 2.0)
	for x in [SCROLL_X.x - 10, SCROLL_X.y + 10]:
		Shapes.circle(_ci, Vector2(x, y), 8, Color(0.75, 0.55, 0.1))
		Shapes.circle(_ci, Vector2(x, y), 6, Icons.GOLD)


## Wand upgrade row under the mouse, or -1. Only on the settled, unrolled scroll.
func hovered_upgrade() -> int:
	if game.phase != game.Phase.PREP or game.drag != null or game.shop_out > 0.0 or game.scroll_open < 1.0:
		return -1
	var mouse := get_global_mouse_position()
	for i in Rules.WAND_UPGRADES.size():
		if game.ruleset.allows_upgrade(Rules.WAND_UPGRADES[i]) and upgrade_rect(i, game.ruleset).has_point(mouse):
			return i
	return -1


## Card left of the hovered wand upgrade row: the same short scene played side by
## side at the current level (dim frame) and at the next level (gold frame),
## restarting when the hovered row changes. A maxed upgrade compares its last
## two levels. No price: the row already shows it.
func _draw_upgrade_tooltip() -> void:
	var i := hovered_upgrade()
	var now := Time.get_ticks_msec() / 1000.0
	if i != _tooltip_row:
		_tooltip_row = i
		_tooltip_start = now
	if i < 0:
		return
	var id := Rules.WAND_UPGRADES[i]
	var row := upgrade_rect(i, game.ruleset)
	var card := Rect2(Vector2(SCROLL_X.x - 24 - TOOLTIP_SIZE.x, row.get_center().y - TOOLTIP_SIZE.y * 0.5), TOOLTIP_SIZE)
	var tip := PackedVector2Array([Vector2(card.end.x - 1, row.get_center().y - 9), Vector2(row.position.x - 2, row.get_center().y),
		Vector2(card.end.x - 1, row.get_center().y + 9)])
	_ci.draw_colored_polygon(tip, Color(0.08, 0.06, 0.05, 0.96))
	_ci.draw_rect(card, Color(0.08, 0.06, 0.05, 0.96))
	_ci.draw_rect(card, Color(0.42, 0.29, 0.18), false, 2.0)
	var level := mini(game.player.upgrade_level(id), Rules.WAND_UPGRADE_COSTS[id].size() - 1)
	var t := now - _tooltip_start
	var before := Rect2(card.position + Vector2(10, 10), TOOLTIP_PANEL)
	var after := Rect2(Vector2(card.end.x - 10 - TOOLTIP_PANEL.x, card.position.y + 10), TOOLTIP_PANEL)
	_ci.draw_rect(before, Color(0.12, 0.09, 0.07))
	_ci.draw_rect(after, Color(0.15, 0.1, 0.2))
	_draw_upgrade_scene(id, Rules.wand_value(id, level), before.get_center(), t)
	_draw_upgrade_scene(id, Rules.wand_value(id, level + 1), after.get_center(), t)
	_ci.draw_rect(before, Color(0, 0, 0, 0.3))
	_ci.draw_rect(before, Color(0.35, 0.29, 0.23), false, 2.0)
	_ci.draw_rect(after, Icons.GOLD, false, 2.5)
	Icons.arrow_right(_ci, card.get_center(), 9, Icons.GOLD)


## One looping tooltip scene for a wand upgrade value, centred on c, at t
## seconds since the hover began.
func _draw_upgrade_scene(id: String, value: float, c: Vector2, t: float) -> void:
	match id:
		"recharge":
			# An empty crystal fills with magic in `value` seconds, then shows full.
			var progress := clampf(fmod(t, 3.6) / value, 0.0, 1.0)
			Icons.charge_crystal(_ci, c, 30, progress >= 1.0, progress)
		"charges":
			# Combat start: the starting crystals pop in one after another.
			var phase := fmod(t, 2.6)
			for k in Rules.MAX_CHARGES:
				var p := c + Vector2((k - 1) * 36, 0)
				var appear := clampf((phase - 0.3 - k * 0.3) / 0.2, 0.0, 1.0)
				var shown := k < int(value) and appear > 0.0
				Icons.charge_crystal(_ci, p, 15 * (1.0 + 0.25 * sin(appear * PI)) if shown else 15.0, shown)
		"heal":
			# The wand blesses an ally: a green cross, then the health it gains.
			var phase := fmod(t, 3.0)
			var token := c + Vector2(0, -14)
			Icons.token(_ci, "peasant", token, 24, 0)
			_draw_wand_zap(token, phase)
			var gain := smoothstep(0.35, 0.9, phase)
			if phase > 0.35:
				var s := 7.0 * minf(1.0, (phase - 0.35) / 0.15)
				var cross := token + Vector2(28, -18)
				Shapes.line(_ci, cross + Vector2(-s, 0), cross + Vector2(s, 0), Color(0.5, 1, 0.65), 4.0)
				Shapes.line(_ci, cross + Vector2(0, -s), cross + Vector2(0, s), Color(0.5, 1, 0.65), 4.0)
			var bar := Rect2(c + Vector2(-44, 26), Vector2(88, 10))
			_ci.draw_rect(bar, Color(0.16, 0.1, 0.1))
			_ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * 0.4, bar.size.y)), Color(0.29, 0.54, 0.23))
			_ci.draw_rect(Rect2(bar.position + Vector2(bar.size.x * 0.4, 0), Vector2(bar.size.x * value * gain, bar.size.y)), Color(0.5, 1, 0.65))
		"hex":
			# The wand hexes an enemy: it spins dazed while the ring drains for
			# `value` seconds.
			var phase := fmod(t, 5.4)
			var token := c + Vector2(0, 6)
			Icons.token(_ci, "guardian", token, 24, 1)
			_draw_wand_zap(token, phase)
			var stunned := phase - 0.3
			if stunned > 0.0 and stunned < value:
				var left := 1.0 - stunned / value
				Shapes.arc(_ci, token, 33, -PI / 2, -PI / 2 + TAU * left, 32, Icons.MAGIC.lightened(0.45), 3.0, true)
				Icons.stun_spiral(_ci, token + Vector2(0, -36), 9, -t * 6.0)


## Brief star flash on a creature as the wand's spell lands, at the start of a
## scene loop.
func _draw_wand_zap(p: Vector2, phase: float) -> void:
	if phase < 0.35:
		var k := phase / 0.35
		Icons.star(_ci, p, 8.0 + 16.0 * k, Color(Icons.MAGIC.lightened(0.5), 1.0 - k))


## One wand upgrade: its icon (the charges icon also shows the current starting
## charges), then the next level's price in coins or a check once maxed.
func _draw_upgrade_row(id: String, r: Rect2) -> void:
	var player: WizardState = game.player
	var maxed := player.upgrade_maxed(id)
	var affordable: bool = game.phase == game.Phase.PREP and player.can_buy_upgrade(id)
	var hovered := r.has_point(get_global_mouse_position()) and game.drag == null
	var fill := Color(0.11, 0.23, 0.15) if maxed else Color(0.29, 0.16, 0.4)
	if hovered and affordable:
		fill = fill.lightened(0.12)
	_ci.draw_rect(r, fill)
	_ci.draw_rect(r, Icons.GOLD if affordable else Color(0.48, 0.31, 0.66), false, 2.5 if affordable else 1.5)
	var mid := r.position.y + r.size.y * 0.5
	Icons.wand_upgrade(_ci, id, Vector2(r.position.x + 10, mid), 13, player.start_charges())
	if maxed:
		var check := Vector2(r.end.x - 30, mid)
		Shapes.line(_ci, check + Vector2(-10, 0), check + Vector2(-2, 8), Color(0.5, 1, 0.65), 3, true)
		Shapes.line(_ci, check + Vector2(-2, 8), check + Vector2(13, -10), Color(0.5, 1, 0.65), 3, true)
		return
	var cost := player.upgrade_cost(id)
	for j in cost:
		Icons.coin(_ci, Vector2(r.end.x - 18 - (cost - 1 - j) * 19, mid), 8)
	if not affordable:
		_ci.draw_rect(r, Color(0, 0, 0, 0.45))


func _draw_enemy_preparation() -> void:
	if game.phase != game.Phase.PREP:
		return
	for c in game.enemy.fielded():
		if game.enemy_is_moving(c):
			var p: Vector2 = game.enemy_display_position(c) + Rules.BOARD_POS
			Icons.token(_ci, c.form_id, p, Rules.BODY_RADIUS * Rules.CELL, 1)
			Icons.merge_stars(_ci, p + Vector2(0, -32), c.stars)
	if game.enemy_action.is_empty():
		return
	var action: Dictionary = game.enemy_action
	if not action.has("cost"):
		return
	for i in int(action.cost):
		var k := (float(action.t) - i * 0.05) / 0.40
		if k < 0.0 or k >= 1.0:
			continue
		var start := gold_pos(1)
		var end := medallion_centers[1]
		var p := start.lerp(end, k) + Vector2(sin(k * PI) * 45, 0)
		Icons.coin(_ci, p, 9 * (1.0 - 0.35 * k))
		Shapes.arc(_ci, p, 13, 0, TAU, 16, Color(1, 0.8, 0.2, 1.0 - k), 2, true)


func _draw_combat_hud() -> void:
	var b: Battle = game.battle
	if b == null:
		return
	# Timer bar above the board.
	var bar := Rect2(Rules.BOARD_POS + Vector2(0, -34), Vector2(Rules.BOARD_SIZE.x, 10))
	_ci.draw_rect(bar, Color(0, 0, 0, 0.5))
	var left := clampf(1.0 - b.time / Rules.COMBAT_TIMEOUT, 0.0, 1.0)
	var timer_color := Color(0.9, 0.8, 0.5).lerp(Color(1, 0.3, 0.2), 1.0 - left)
	if b.frenzy_level > 0:
		timer_color = Color(1.0, 0.24, 0.16)
		if not b.finished:
			_draw_frenzy(b, bar, timer_color)
	_ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), timer_color)
	# Large player charges under the board.
	var spell: ShiftSpell = b.spells[0]
	for i in (Rules.MAX_CHARGES if game.player.can_cast() else 0):
		var prog: float = spell.progress() if i == spell.charges else 0.0
		Icons.charge_crystal(_ci, charge_pos(i), 24, spell.charges > i, prog)


func _draw_frenzy(b: Battle, bar: Rect2, color: Color) -> void:
	var step_start := Rules.FRENZY_START + (b.frenzy_level - 1) * Rules.FRENZY_STEP_SECONDS
	var flash := clampf(1.0 - (b.time - step_start) / 0.55, 0.0, 1.0)
	var outline := Rect2(Rules.BOARD_POS, Rules.BOARD_SIZE).grow(3.0)
	_ci.draw_rect(outline, Color(color, 0.45 + flash * 0.55), false, 2.0 + flash * 3.0)
	var bonus := roundi((b.frenzy_multiplier() - 1.0) * 100.0)
	_ci.draw_string(font, bar.position + Vector2(0, -7), "+%d%%" % bonus,
		HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 18, Color(1.0, 0.65, 0.35).lerp(Color.WHITE, flash))


func _draw_result() -> void:
	var c := Rules.BOARD_POS + Rules.BOARD_SIZE * 0.5
	Shapes.circle(_ci, c, 70, Color(0, 0, 0, 0.55))
	match int(game.last_result.get("winner", -1)):
		0:
			Icons.crown(_ci, c, 46)
		1:
			Icons.skull(_ci, c, 50)
		_:
			Icons.draw_mark(_ci, c, 40)


## Precompute the alpha falloff from the edge of a card, including its corners.
static func _make_choice_halo(card_size: Vector2i) -> Texture2D:
	var margin := CHOICE_HALO_MARGIN
	var size := card_size + Vector2i.ONE * (margin * 2)
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		var dy := maxf(margin - (y + 0.5), y + 0.5 - (size.y - margin))
		for x in size.x:
			var dx := maxf(margin - (x + 0.5), x + 0.5 - (size.x - margin))
			var distance := Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length()
			var alpha := 1.0 - smoothstep(0.0, float(margin), distance)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


func _draw_choice_halo(card: Rect2, texture: Texture2D, index: int) -> void:
	var hover := choice_hover[index] if choice_phase == game.phase else 0.0
	var opacity := lerpf(0.26, 0.78, smoothstep(0.0, 1.0, hover))
	_ci.draw_texture_rect(texture, card.grow(CHOICE_HALO_MARGIN), false, Color(Color.WHITE, opacity))


## Three opponent hats, from the modest apprentice to the glowing archmage.
func _draw_difficulty_choice() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var mouse := get_global_mouse_position()
	for i in Difficulty.COUNT:
		var r := difficulty_rect(i)
		var unlocked: bool = game.is_difficulty_unlocked(i)
		var revealing := i == unlock_level
		var hovered := unlocked and not unlock_animation_active() and r.has_point(mouse)
		var reveal_age := unlock_time - UNLOCK_CLICK
		var opening := smoothstep(0.0, UNLOCK_OPEN_TIME, reveal_age) if revealing else 0.0
		var pulse := sin(PI * smoothstep(0.0, 0.58, reveal_age)) if revealing else 0.0
		var lift := 6.0 if hovered else pulse * 9.0
		var card := Rect2(r.position - Vector2(0, lift), r.size)
		if unlocked and not revealing:
			_draw_choice_halo(card, difficulty_halo, i)
		_panel(card, Color(0.22, 0.16, 0.1) if hovered else Color(0.14, 0.1, 0.08))
		var hat_scale: float = [46.0, 48.0, 54.0][i] * (1.06 if hovered else 1.0)
		var bob := sin(t * 4.0) * 3.0 if hovered else 0.0
		var centre := card.get_center() + Vector2(0, -9)
		# Soft pool of light under each hat, brighter for stronger opponents.
		var glow: Color = [Color(0.85, 0.65, 0.4), Color(0.4, 0.6, 1.0), Icons.MAGIC][i]
		for k in 5:
			var w := 70.0 - k * 11.0
			Shapes.set_transform(_ci, centre + Vector2(0, hat_scale * 0.62), 0.0, Vector2(1.0, 0.28))
			Shapes.circle(_ci, Vector2.ZERO, w, Color(glow, (0.05 + i * 0.025) * (1.4 if hovered else 1.0)))
		Shapes.set_transform(_ci, Vector2.ZERO, 0.0, Vector2.ONE)
		Icons.difficulty_hat(_ci, i, centre + Vector2(0, bob), hat_scale, t)
		if not unlocked or revealing:
			_ci.draw_rect(card.grow(-2), Color(0.06, 0.04, 0.06, 0.65 * (1.0 - opening)))
			var lock_pos := Vector2(centre.x, card.end.y - 40)
			if revealing:
				_draw_difficulty_unlock(card, lock_pos, opening, reveal_age)
			else:
				Shapes.circle(_ci, lock_pos, 19, Color(0.13, 0.09, 0.08), true)
				Icons.padlock(_ci, lock_pos)


func _draw_difficulty_unlock(card: Rect2, lock_pos: Vector2, opening: float, age: float) -> void:
	var anticipation := smoothstep(0.0, UNLOCK_CLICK, unlock_time)
	var wobble := sin(unlock_time * 46.0) * anticipation * (1.0 - opening) * 3.0
	var fade := 1.0 - smoothstep(0.40, 0.78, age)
	var scale_factor := 1.0 + anticipation * 0.25 + opening * 0.18
	lock_pos += Vector2(wobble, -opening * 8.0)
	Shapes.circle(_ci, lock_pos, 19.0 * scale_factor, Color(0.13, 0.09, 0.08, fade), true)
	Icons.padlock(_ci, lock_pos, opening, scale_factor, fade)
	var flash := smoothstep(0.0, 0.10, age) * (1.0 - smoothstep(0.17, 0.92, age))
	_ci.draw_rect(card.grow(3), Color(Icons.GOLD, flash), false, 2.5)
	if age > 0.0 and age < 0.60:
		var burst := age / 0.60
		Shapes.arc(_ci, lock_pos, 21.0 + burst * 38.0, 0.0, TAU, 32, Color(Icons.GOLD, 0.75 * (1.0 - burst)), 2.0, true)
		for i in 10:
			var direction := Vector2.from_angle(TAU * i / 10.0)
			var distance := 24.0 + burst * (45.0 + (i % 3) * 12.0)
			Icons.star(_ci, lock_pos + direction * distance, 5.0 * (1.0 - burst), Color(Icons.GOLD, 1.0 - burst))


func _draw_pack_choice() -> void:
	var mouse := get_global_mouse_position()
	for i in game.offered_packs.size():
		var pack: Dictionary = game.pack_at(i)
		var r := pack_rect(i)
		var hovered := r.has_point(mouse)
		_draw_choice_halo(r, pack_halo, i)
		_panel(r, Color(0.22, 0.16, 0.1) if hovered else Color(0.14, 0.1, 0.08))
		var emblem_pos := Vector2(r.get_center().x, r.position.y + 31)
		Icons.pack_emblem(_ci, pack.emblem, emblem_pos, hovered)
		var n: int = pack.forms.size()
		for j in n:
			Icons.token(_ci, pack.forms[j], pack_token_pos(i, j, n), pack_token_radius(n), 0)
		var coin_row := Vector2(emblem_pos.x, r.end.y - 24)
		var divider := Color(0.45, 0.32, 0.2, 0.65)
		Shapes.line(_ci, coin_row + Vector2(-66, -17), coin_row + Vector2(66, -17), divider, 1.0)
		var starting_gold := Rules.income(1) + int(pack.bonus_gold)
		for j in (starting_gold if game.ruleset.has(Ruleset.SHOP) else 0):
			Icons.coin(_ci, coin_row + Vector2((j - (starting_gold - 1) * 0.5) * 21, 0), 8)


func _draw_game_over() -> void:
	_ci.draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0, 0, 0, 0.6))
	var won: bool = game.player.hp > 0
	if won:
		victory.draw(_ci)
		var pop := 1.0 + 0.35 * sin(victory.age * 16.0) * exp(-5.5 * victory.age)
		Icons.crown(_ci, VICTORY_POS, 90 * pop)
	else:
		Icons.skull(_ci, Vector2(640, 280), 95)
	# Back to the journey map: the same island medallion as when leaving a replay.
	var hovered := RESTART_POS.distance_to(get_global_mouse_position()) < 46
	Icons.island_medallion(_ci, RESTART_POS, 46 * (ABANDON_HOVER_SCALE if hovered else 1.0), Time.get_ticks_msec() / 1000.0, hovered)


## Hover card: current form, its three possible outcomes with chances, and
## stat bars for the current form.
func _draw_hover_card(info: Dictionary) -> void:
	var form: String = info.form
	var team: int = info.get("team", 0)
	var u: Unit = info.get("unit")
	var owned: OwnedCreature = info.get("owned")
	var stars: int = u.stars if u != null else owned.stars if owned != null else 0
	var size := Vector2(236, 162)
	var pos: Vector2 = info.pos + Vector2(24, 16)
	pos.x = clampf(pos.x, 8, 1280 - size.x - 8)
	pos.y = clampf(pos.y, 8, 720 - size.y - 8)
	_panel(Rect2(pos, size), Color(0.08, 0.06, 0.1, 0.93))
	var main := pos + Vector2(36, 40)
	Icons.token(_ci, form, main, 26, team)
	Icons.merge_stars(_ci, main + Vector2(0, 34), stars)
	# Merge pips and harvest coins only once their rule exists in this duel.
	if game.ruleset.has(Ruleset.MERGE):
		var copies: int = u.merge_copies if u != null else owned.merge_copies if owned != null else 1
		Icons.merge_progress(_ci, main + Vector2(0, 46), copies, stars)
	if u != null:
		if u.immune_t > 0.0:
			Icons.immunity_ring(_ci, main, 31, u.immune_t / Rules.TARGET_IMMUNITY, u.anim_t)
	# Shapeshift outcomes, once the player has a wand.
	var outs: Array = game.ruleset.outcomes(form) if game.player.can_cast() else []
	if not outs.is_empty():
		Icons.arrow_right(_ci, pos + Vector2(78, 40), 9, Icons.MAGIC)
	for i in outs.size():
		var op := pos + Vector2(116 + i * 46, 32)
		Icons.token(_ci, outs[i].id, op, 18, team)
		Icons.chance_pie(_ci, op + Vector2(0, 29), 7, outs[i].chance)
	# Harvesters: one coin per gold they bring at the start of each round.
	var harvest := Rules.harvest_gold(form, stars) if game.ruleset.has(Ruleset.HARVEST) else 0
	for i in harvest:
		Icons.coin(_ci, pos + Vector2(100 + i * 15, 84), 6)
	# Stat bars (normalised against the roster's high values).
	var d := CreatureDB.get_form(form)
	var mult: float = u.stat_mult() if u != null else Rules.star_mult(stars)
	var stats := [
		["hp", d.hp * mult / 250.0], ["dmg", d.dmg * mult / d.interval / 14.0],
		["speed", 1.0 / d.interval / 1.3], ["range", d.range / 5.0],
		["move", d.speed / 3.0], ["armour", d.armour / 50.0],
	]
	for i in stats.size():
		var col := i % 2
		var row := floori(i / 2.0)
		var sp := pos + Vector2(20 + col * 112, 104 + row * 20)
		Icons.stat_icon(_ci, stats[i][0], sp, 7)
		_ci.draw_rect(Rect2(sp + Vector2(12, -4), Vector2(80, 8)), Color(0.2, 0.18, 0.22))
		_ci.draw_rect(Rect2(sp + Vector2(12, -4), Vector2(80 * clampf(stats[i][1], 0.03, 1.0), 8)), Color(0.85, 0.8, 0.6))
