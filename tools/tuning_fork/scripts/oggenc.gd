class_name Oggenc
## Converts WAV files to OGG Vorbis with the bundled Windows oggenc or a
## compatible encoder. An exported copy lives beside Tuning Fork.

static var _program := ""
static var _searched := false


## The oggenc program to run, or "" when there is none.
static func program() -> String:
	if not _searched:
		_searched = true
		var candidates: Array[String] = []
		if OS.has_feature("template"):
			candidates.append(OS.get_executable_path().get_base_dir().path_join("oggenc.exe"))
			candidates.append(OS.get_executable_path().get_base_dir().path_join("oggenc2.exe"))
		if OS.get_environment("OGGENC") != "":
			candidates.append(OS.get_environment("OGGENC"))
		if OS.has_feature("editor") and OS.has_feature("windows"):
			candidates.append(ProjectSettings.globalize_path("res://vendor/oggenc/oggenc.exe"))
		if OS.get_environment("USERPROFILE") != "":
			candidates.append(OS.get_environment("USERPROFILE").path_join("Tools/oggenc/oggenc2.exe"))
		candidates.append_array(["oggenc2", "oggenc", "ffmpeg"])
		for candidate in candidates:
			var on_path := not candidate.contains("/") and not candidate.contains("\\")
			var version_arg := "-version" if "ffmpeg" in candidate.to_lower() else "--version"
			if (on_path or FileAccess.file_exists(candidate)) \
					and OS.execute(candidate, [version_arg], [], false) == 0:
				_program = candidate
				break
	return _program


## Converts `source` to an OGG Vorbis file at `target`. Returns an error
## message, or "" on success.
static func to_ogg(source: String, target: String) -> String:
	if program() == "":
		return "Converting %s needs oggenc beside Tuning Fork or on the PATH" % source.get_file()
	var output := []
	var args := PackedStringArray(["-Q", "-q", "5", "-o", target, source])
	if "ffmpeg" in program().to_lower():
		args = PackedStringArray(["-v", "error", "-y", "-i", source, "-c:a", "libvorbis", "-q:a", "5", target])
	var code := OS.execute(program(), args, output, true)
	if code != 0 or AudioStreamOggVorbis.load_from_file(target) == null:
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)
		return "oggenc could not convert %s: %s" % [source.get_file(), "".join(output).strip_edges().left(200)]
	return ""
