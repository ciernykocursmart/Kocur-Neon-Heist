class_name TrackLocation
extends RefCounted
## Where a kart is relative to the track. Updated by Track.locate() every
## physics tick and shared by the kart (surface handling), the race manager
## (progress, checkpoints, wrong-way) and the AI.

var path := 0            ## 0 = main circuit, 1.. = shortcut index + 1
var index := -1          ## nearest sample on `path`
var main_index := -1     ## nearest sample on the main circuit
var s := 0.0             ## progress along the main circuit, metres
var lateral := 0.0       ## signed offset from the path centre (+ = right)
var height := 0.0        ## height above the path centre
var half_width := 6.0
var surface: StringName = &"road"
var on_pad := false
var in_gap := false
var off_track := false   ## outside the walls / far from any road
