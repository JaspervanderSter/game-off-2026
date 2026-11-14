class_name Oggenc
## Converts WAV files to OGG Vorbis with oggenc2 (rarewares.org, about 2 MB):
## the copy beside the exported executable (export_windows.ps1 puts it there),
## otherwise $OGGENC, %USERPROFILE%\Tools\oggenc\oggenc2.exe, or oggenc2 or
## oggenc on the PATH.

static var _program := ""
static var _searched := false


## The oggenc program to run, or "" when there is none.
static func program() -> String:
	if not _searched:
		_searched = true
		var candidates: Array[String] = []
		if OS.has_feature("template"):
			candidates.append(OS.get_executable_path().get_base_dir().path_join("oggenc2.exe"))
		if OS.get_environment("OGGENC") != "":
			candidates.append(OS.get_environment("OGGENC"))
		if OS.get_environment("USERPROFILE") != "":
			candidates.append(OS.get_environment("USERPROFILE").path_join("Tools/oggenc/oggenc2.exe"))
		candidates.append_array(["oggenc2", "oggenc"])
		for candidate in candidates:
			var on_path := not candidate.contains("/") and not candidate.contains("\\")
			if (on_path or FileAccess.file_exists(candidate)) \
					and OS.execute(candidate, ["--version"], [], false) == 0:
				_program = candidate
				break
	return _program


## Converts `source` to an OGG Vorbis file at `target`. Returns an error
## message, or "" on success.
static func to_ogg(source: String, target: String) -> String:
	if program() == "":
		return "Converting %s needs oggenc2.exe, beside Tuning Fork or on the PATH" % source.get_file()
	var output := []
	var code := OS.execute(program(), ["-Q", "-q", "5", "-o", target, source], output, true)
	if code != 0 or AudioStreamOggVorbis.load_from_file(target) == null:
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)
		return "oggenc could not convert %s: %s" % [source.get_file(), "".join(output).strip_edges().left(200)]
	return ""
