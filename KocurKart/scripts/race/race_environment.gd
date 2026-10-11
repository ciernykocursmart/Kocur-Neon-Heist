class_name RaceEnvironment
extends RefCounted
## Sky, sun, ambient light, fog and glow for a track theme.


static func apply(parent: Node, th: Dictionary) -> WorldEnvironment:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = th["sky_top"]
	sm.sky_horizon_color = th["sky_horizon"]
	sm.ground_horizon_color = th["ground_horizon"]
	sm.ground_bottom_color = Color(th["ground_horizon"]).darkened(0.4)
	sm.sun_angle_max = 20.0
	sm.sky_curve = 0.12
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = th["ambient"]
	env.ambient_light_energy = th["ambient_energy"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = th["fog"]
	env.fog_density = th["fog_density"]
	env.fog_sky_affect = 0.25
	if th.get("glow", false):
		env.glow_enabled = true
		env.glow_intensity = 0.8
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	var rot: Vector3 = th["sun_rot"]
	sun.rotation_degrees = rot
	sun.light_color = th["sun_color"]
	sun.light_energy = th["sun_energy"]
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_bias = 0.06
	parent.add_child(sun)
	return we
