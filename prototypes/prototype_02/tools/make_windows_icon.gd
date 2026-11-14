extends SceneTree
## Renders icon.svg into icon.ico (16 to 256 px, PNG entries), the icon that the
## Windows export embeds in the executable. export_windows.ps1 runs it before each
## export; run it by hand after changing icon.svg if exporting from the editor:
##
##   godot --headless --path . --script res://tools/make_windows_icon.gd

const SOURCE := "res://icon.svg"
const TARGET := "res://icon.ico"
const SIZES := [16, 24, 32, 48, 64, 128, 256]


func _init() -> void:
	var svg := FileAccess.get_file_as_bytes(SOURCE)
	if svg.is_empty():
		push_error("Cannot read %s" % SOURCE)
		quit(1)
		return
	var probe := Image.new()
	if probe.load_svg_from_buffer(svg) != OK:
		push_error("Cannot parse %s" % SOURCE)
		quit(1)
		return
	var base_size := maxi(probe.get_width(), probe.get_height())

	var pngs: Array[PackedByteArray] = []
	for size: int in SIZES:
		var image := Image.new()
		image.load_svg_from_buffer(svg, float(size) / base_size)
		if image.get_width() != size or image.get_height() != size:
			image.resize(size, size, Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGBA8)
		pngs.append(image.save_png_to_buffer())

	var ico := StreamPeerBuffer.new()
	ico.big_endian = false
	ico.put_u16(0)  # reserved
	ico.put_u16(1)  # type: icon
	ico.put_u16(SIZES.size())
	var offset := 6 + 16 * SIZES.size()
	for i in SIZES.size():
		var size: int = SIZES[i]
		ico.put_u8(0 if size >= 256 else size)  # width
		ico.put_u8(0 if size >= 256 else size)  # height
		ico.put_u8(0)  # palette colors
		ico.put_u8(0)  # reserved
		ico.put_u16(1)  # color planes
		ico.put_u16(32)  # bits per pixel
		ico.put_u32(pngs[i].size())
		ico.put_u32(offset)
		offset += pngs[i].size()
	for png in pngs:
		ico.put_data(png)

	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s" % TARGET)
		quit(1)
		return
	file.store_buffer(ico.data_array)
	file.close()
	print("Wrote %s (%s)" % [TARGET, ", ".join(SIZES.map(func(s): return str(s)))])
	quit(0)
