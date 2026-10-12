extends "res://tests/test_case.gd"
## Export configuration for the Windows x64 build, and (when present) the
## exported executable itself. The pack's content is exercised separately by
## tools/pack_smoke.gd; nothing here can start the .exe on real Windows.


func test_windows_preset() -> void:
	var cfg := ConfigFile.new()
	eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg readable")
	eq(cfg.get_value("preset.0", "name", ""), "Windows Desktop", "preset name")
	eq(cfg.get_value("preset.0", "platform", ""), "Windows Desktop", "platform")
	eq(cfg.get_value("preset.0.options", "binary_format/architecture", ""), "x86_64", "64-bit build")
	eq(cfg.get_value("preset.0.options", "binary_format/embed_pck", false), true, "single self-contained exe")
	var excl: String = cfg.get_value("preset.0", "exclude_filter", "")
	check(excl.contains("tests/*") and excl.contains("tools/*"), "tests and tools are not shipped")
	eq(cfg.get_value("preset.0.options", "application/product_name", ""), "Kocur Dungeon", "product name")
	eq(cfg.get_value("preset.0.options", "application/company_name", ""), "Kocur Studios", "company name")
	check(FileAccess.file_exists("res://tools/build_windows.sh"), "build script present")
	check(FileAccess.file_exists("res://tools/pack_smoke.gd"), "exported-pack smoke test present")


func test_exported_exe_if_built() -> void:
	var path := ProjectSettings.globalize_path("res://build/windows/KocurDungeon.exe")
	if not FileAccess.file_exists(path):
		check(true, "no build present - run tools/build_windows.sh to test the exe")
		note("skipped: build/windows/KocurDungeon.exe not built in this checkout")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var size := f.get_length()
	gt(size, 40_000_000, "exe has the engine and the embedded game pack")
	eq(f.get_buffer(2).get_string_from_ascii(), "MZ", "Windows PE executable header")
	f.seek(0x3C)
	var pe_off := f.get_32()
	f.seek(pe_off)
	eq(f.get_buffer(4), PackedByteArray([0x50, 0x45, 0, 0]), "PE signature")
	eq(f.get_16(), 0x8664, "machine type is x86-64")
	f.seek(size - 4)
	eq(f.get_buffer(4).get_string_from_ascii(), "GDPC", "Godot pack embedded at the end of the exe")
