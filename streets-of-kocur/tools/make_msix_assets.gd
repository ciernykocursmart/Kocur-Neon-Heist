extends SceneTree
## Renders the square MSIX logos (Start tiles, taskbar, Store logo) from icon.svg
## at 200% scale for HiDPI screens:
##   godot --headless --path . -s res://tools/make_msix_assets.gd
## The wide tile and splash screen come from tools/store_art.gd (see tools/store_shots.sh).


func _icon(size: int) -> Image:
	var img := Image.new()
	# icon.svg is drawn on a 256x256 canvas
	img.load_svg_from_string(FileAccess.get_file_as_string("res://icon.svg"), size / 256.0)
	img.convert(Image.FORMAT_RGBA8)
	return img


func _initialize() -> void:
	for pair: Array in [["StoreLogo.png", 100], ["Square44x44Logo.png", 88], ["Square71x71Logo.png", 142],
			["Square150x150Logo.png", 300], ["Square310x310Logo.png", 620]]:
		var img := _icon(pair[1])
		img.save_png(ProjectSettings.globalize_path("res://store/msix/Assets/" + pair[0]))
		print("asset ", pair[0], " ", img.get_size())
	quit()
