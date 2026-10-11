class_name KartFactory
extends RefCounted
## Builds a ready-to-race kart from catalog ids.


static func create(app: Dictionary, is_player := false) -> Kart:
	var kart := Kart.new()
	var racer_id: String = app.get("racer", "kocur")
	var kart_id: String = app.get("kart", "alley")
	kart.name = "Kart_" + racer_id
	kart.racer_id = racer_id
	kart.display_name = String(Catalog.RACERS.get(racer_id, {}).get("name", racer_id))
	kart.is_player = is_player
	kart.setup_stats(Catalog.KARTS.get(kart_id, Catalog.KARTS["alley"])["stats"])
	var model := KartModel.create(app)
	kart.add_child(model)
	kart.model = model
	return kart
