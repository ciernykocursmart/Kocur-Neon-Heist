extends RefCounted
## Builds and caches SpriteFrames from the generated sprite sheets.
## Grid sheets use one row per animation; strips are a single row.

const DIR := "res://assets/sprites/"

## name -> [file, frame_w, frame_h, {anim: [row, frames, fps, loop]}]
const SHEETS := {
	"hero": ["hero.png", 32, 32, {"idle": [0, 4, 5, true], "run": [1, 6, 14, true], "jump": [2, 2, 8, true],
		"fall": [2, 2, 8, true, 2], "attack": [3, 3, 16, false], "pounce": [4, 2, 12, true], "hurt": [5, 1, 1, false],
		"death": [5, 3, 5, false, 1]}],
	"scout": ["scout.png", 32, 32, {}],
	"guard": ["guard.png", 32, 32, {}],
	"archer": ["archer.png", 32, 32, {}],
	"mage": ["mage.png", 32, 32, {}],
	"beast": ["beast.png", 64, 48, {}],
	"boss_mouser": ["boss_mouser.png", 64, 64, {}],
	"boss_ember": ["boss_ember.png", 64, 64, {}],
	"boss_frost": ["boss_frost.png", 64, 64, {}],
	"boss_stalker": ["boss_stalker.png", 64, 64, {}],
	"boss_king": ["boss_king.png", 64, 80, {}],
}
const ENEMY_ANIMS := {"idle": [0, 4, 4, true], "walk": [1, 4, 8, true], "windup": [2, 2, 6, true],
	"attack": [3, 2, 10, false], "hurt": [4, 1, 1, false], "death": [5, 3, 8, false]}
const BEAST_ANIMS := {"idle": [0, 4, 4, true], "walk": [1, 4, 7, true], "windup": [2, 2, 6, true],
	"attack": [3, 2, 10, true], "hurt": [4, 1, 1, false], "death": [5, 3, 6, false]}
const BOSS_ANIMS := {"idle": [0, 2, 3, true], "walk": [1, 4, 7, true], "windup": [2, 2, 5, true],
	"attack": [3, 2, 8, false], "cast": [4, 2, 6, true], "stunned": [5, 2, 3, true], "hurt": [6, 1, 1, false],
	"death": [7, 3, 4, false]}

## Strips: name -> [file, frame_w, frame_h, fps, loop]
const STRIPS := {
	"coin": ["coin.png", 16, 16, 8, true], "gem": ["gem.png", 16, 16, 6, true], "fish": ["fish.png", 16, 16, 3, true],
	"chest": ["chest.png", 16, 16, 0, false], "checkpoint": ["checkpoint.png", 16, 32, 0, false],
	"door": ["door.png", 32, 32, 0, false], "lever": ["lever.png", 16, 16, 0, false],
	"torch": ["torch.png", 16, 16, 8, true], "cage": ["cage.png", 32, 32, 0, false],
	"saw": ["saw.png", 16, 16, 16, true], "flame": ["flame.png", 16, 48, 12, true], "spring": ["spring.png", 16, 16, 0, false],
	"slash": ["slash.png", 32, 32, 20, false], "spark": ["spark.png", 16, 16, 18, false], "dust": ["dust.png", 16, 16, 14, false],
	"poof": ["poof.png", 32, 32, 14, false], "orb": ["orb.png", 12, 12, 8, true], "fireball": ["fireball.png", 12, 12, 10, true],
	"pale_orb": ["pale_orb.png", 12, 12, 8, true], "shadow_orb": ["shadow_orb.png", 12, 12, 8, true],
	"shockwave": ["shockwave.png", 32, 16, 10, true], "relic": ["relic.png", 16, 16, 0, false],
}

static var _cache := {}
static var _tex_cache := {}


static func texture(file: String) -> Texture2D:
	if not _tex_cache.has(file):
		_tex_cache[file] = load(DIR + file)
	return _tex_cache[file]


static func frames(sheet_name: String) -> SpriteFrames:
	if _cache.has(sheet_name):
		return _cache[sheet_name]
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	if SHEETS.has(sheet_name):
		var def: Array = SHEETS[sheet_name]
		var tex := texture(def[0])
		var anims: Dictionary = def[3]
		if anims.is_empty():
			if sheet_name == "beast":
				anims = BEAST_ANIMS
			elif sheet_name.begins_with("boss_"):
				anims = BOSS_ANIMS
			else:
				anims = ENEMY_ANIMS
		for anim: String in anims:
			var a: Array = anims[anim]
			sf.add_animation(anim)
			sf.set_animation_speed(anim, a[2])
			sf.set_animation_loop(anim, a[3])
			var start: int = a[4] if a.size() > 4 else 0
			for i in range(start, start + a[1]):
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(i * def[1], a[0] * def[2], def[1], def[2])
				sf.add_frame(anim, at)
	elif STRIPS.has(sheet_name):
		var s: Array = STRIPS[sheet_name]
		var tex := texture(s[0])
		var count := int(tex.get_width() / s[1])
		sf.add_animation("default")
		sf.set_animation_speed("default", maxf(s[3], 1.0))
		sf.set_animation_loop("default", s[4])
		for i in count:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * s[1], 0, s[1], s[2])
			sf.add_frame("default", at)
	_cache[sheet_name] = sf
	return sf


static func region(file: String, rect: Rect2) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = texture(file)
	at.region = rect
	return at


## One 16x16 icon from icons.png by index.
static func icon(index: int) -> AtlasTexture:
	return region("icons.png", Rect2(index * 16, 0, 16, 16))


static func captive_frames(color_index: int) -> SpriteFrames:
	var key := "captive_%d" % color_index
	if _cache.has(key):
		return _cache[key]
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 4)
	sf.set_animation_loop("default", true)
	for i in 4:
		sf.add_frame("default", region("captives.png", Rect2(i * 32, color_index * 32, 32, 32)))
	_cache[key] = sf
	return sf


static func make_sprite(sheet_name: String, anim := "default") -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(sheet_name)
	if s.sprite_frames.has_animation(anim):
		s.play(anim)
	return s
