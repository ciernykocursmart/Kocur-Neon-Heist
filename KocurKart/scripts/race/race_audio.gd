class_name RaceAudio
extends Node
## Race sound hooks (engines, drift, boosts, countdown). Filled in milestone 5.

var race: Race


func setup(r: Race) -> void:
	race = r
