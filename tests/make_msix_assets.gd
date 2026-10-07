extends SceneTree
## Renders the MSIX visual assets (tiles, store logo, splash) from icon.svg.
##   godot --headless --path . -s res://tests/make_msix_assets.gd


const BG := Color(0.027, 0.027, 0.102, 1.0)


func _icon(size: int) -> Image:
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string("res://icon.svg"), size / 128.0)
	img.convert(Image.FORMAT_RGBA8)
	return img


func _canvas(w: int, h: int, bg: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	return img


func _save(img: Image, name: String) -> void:
	img.save_png("res://store/msix/Assets/" + name)
	print("asset ", name, " ", img.get_size())


func _initialize() -> void:
	# Logos are rendered at 200% scale for crisp display on HiDPI screens.
	_save(_icon(100), "StoreLogo.png")
	_save(_icon(88), "Square44x44Logo.png")
	_save(_icon(142), "Square71x71Logo.png")
	_save(_icon(300), "Square150x150Logo.png")
	_save(_icon(620), "Square310x310Logo.png")
	var wide := _canvas(620, 300, BG)
	var ic := _icon(240)
	wide.blend_rect(ic, Rect2i(Vector2i.ZERO, ic.get_size()), Vector2i(190, 30))
	_save(wide, "Wide310x150Logo.png")
	var splash := _canvas(1240, 600, Color(0, 0, 0, 0))
	var big := _icon(420)
	splash.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(410, 90))
	_save(splash, "SplashScreen.png")
	quit()
