extends RefCounted
## Movement tuning shared by the player controller and the level validator
## (tests/level_reach.gd), so level reachability always matches real physics.

const RUN_SPEED := 125.0
const ACCEL := 1100.0
const DECEL := 1500.0
const AIR_ACCEL := 850.0
const AIR_DECEL := 600.0
const ICE_ACCEL := 260.0
const ICE_DECEL := 90.0
const JUMP_VELOCITY := 335.0
const GRAVITY_UP := 900.0
const GRAVITY_DOWN := 1300.0
const GRAVITY_CUT := 2600.0
const APEX_THRESHOLD := 40.0
const APEX_GRAVITY_MULT := 0.6
const MAX_FALL := 400.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.13
const SPRING_VELOCITY := 520.0
const POUNCE_TIME := 0.2
const POUNCE_SPEED := 330.0
