extends Node
## Sound effects, each one an OGG file `res://sfx/<name>.ogg` played by name.
## Autoloaded as Sfx; result audio has its own voice so effects cannot steal it.
## Exported desktop builds also read `sfx/<name>.ogg` beside the executable:
## a file there replaces the packed one, so a sound designer can swap effects
## without re-exporting. Changed files reload when the game window regains focus.

const DIR := "res://sfx/"
## Every effect the game plays. Replacing a sound only means replacing its file.
const SOUNDS := [
	"click", "fail", "buy", "combine", "merge",
	"coin_gain", "coin_pop", "heart_break", "difficulty_unlock",
	"hit", "shoot", "death", "shift_bless", "shift_hex",
	"hop", "fear", "blizzard", "note",
	"victory", "defeat",
]
## Duel results play once at their original pitch on a dedicated voice.
const RESULT_SOUNDS := ["victory", "defeat"]
const VOICES := 10
const VOICE_DB := -8.0
const NOTE_DB := -13.0 # the song plays every second: keep it under the effects
## Bard melody in semitones above the `note` sound (pentatonic: do re mi sol la sol mi re).
const SONG_MELODY := [0, 2, 4, 7, 9, 7, 4, 2]
## Command-line user argument (after `--`) that silences all game audio.
const NO_SOUND_ARG := "--no-sound"

## False when launched with --no-sound: nothing is loaded or played and
## the master bus is muted (music included).
var enabled := true
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
var _result_player: AudioStreamPlayer
## Folder of replacement files beside the executable; empty when not exported.
var _override_dir := ""
## Modification time of each replacement file already loaded, by sound name.
var _override_times := {}


func _ready() -> void:
	_result_player = AudioStreamPlayer.new()
	_result_player.volume_db = VOICE_DB
	add_child(_result_player)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = VOICE_DB
		add_child(p)
		_players.append(p)
	if NO_SOUND_ARG in OS.get_cmdline_user_args():
		enabled = false
		AudioServer.set_bus_mute(0, true)
		return
	for sound_name in SOUNDS:
		_streams[sound_name] = load(DIR + sound_name + ".ogg")
	if OS.has_feature("template") and not OS.has_feature("web"):
		_override_dir = OS.get_executable_path().get_base_dir().path_join("sfx")
	load_overrides()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and enabled:
		load_overrides()


## Loads each replacement file that is new or changed since its last load.
## A file that cannot be decoded keeps the previous sound and is retried later.
func load_overrides() -> void:
	if _override_dir == "":
		return
	for sound_name in SOUNDS:
		var path := _override_dir.path_join(sound_name + ".ogg")
		if not FileAccess.file_exists(path):
			continue
		var time := FileAccess.get_modified_time(path)
		if _override_times.get(sound_name, -1) == time:
			continue
		var stream := AudioStreamOggVorbis.load_from_file(path)
		if stream == null:
			push_warning("Could not load replacement sound %s" % path)
			continue
		_override_times[sound_name] = time
		_streams[sound_name] = stream


func play(sound_name: String, pitch_jitter := 0.08, pitch := 1.0) -> void:
	if not enabled or not _streams.has(sound_name):
		return
	# Avoid machine-gun stacking of identical sounds in the same instant.
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound_name, -1000)) < 40:
		return
	_last_played[sound_name] = now
	if sound_name in RESULT_SOUNDS:
		_result_player.stream = _streams[sound_name]
		_result_player.pitch_scale = 1.0
		_result_player.play()
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sound_name]
	p.volume_db = VOICE_DB
	p.pitch_scale = pitch + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## One note of the bard's song: the `note` sound transposed along a pentatonic
## melody, one step per beat, so a singing bard is heard as a little tune.
func play_note(step: int) -> void:
	if not enabled or not _streams.has("note"):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams.note
	p.volume_db = NOTE_DB
	p.pitch_scale = pow(2.0, SONG_MELODY[posmod(step, SONG_MELODY.size())] / 12.0)
	p.play()
