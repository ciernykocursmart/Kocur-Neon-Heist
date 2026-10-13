# Changelog

## 1.0.0 - 2026-10-13

First complete release candidate, waiting for human KX testing on Windows.

### Game
* Six streets: Alley Trouble, Market Mayhem, Neon Boulevard, Industrial Paws,
  White Crown Headquarters, The Fat Cat Showdown (6 themes with parallax
  backgrounds, signs, props and stage music).
* Player: walking and running on the street plane, jump, 3-hit combo with a timing
  window, flying kick, pounce, PAWQUAKE special with a 2-bar energy meter, grab /
  knee / throw, hit invulnerability, knockback, anti stun-lock knock-down.
* Enemies: Punk, Brawler (poise), Runner (flanks and lunges), Thrower (bottles,
  keeps distance), Enforcer (armor, slam zone, wall-stun charge); attack tokens
  limit how many attack at once.
* Bosses: Slick Whiskers, Big Bruno Boltpaw, General Snowmane and the 3-phase final
  boss Lord Lardpaw (Belly Bounce, Rolling Charge, Paw Slam, Food Frenzy).
* Encounters with arena lock, staggered waves (max 5 alive), watchdog that pulls
  enemies back into the arena, checkpoints after every fight.
* Hazards: electric puddles, hydraulic presses; solid barriers and crate walls.
* Food (fish, chicken, can), Golden Fish, yarn balls, breakable props, score,
  extra lives, results screen with rank and per-street challenge, ending.
* Menus: New Game (difficulty), Continue, Level Select, Settings (master / music /
  effects volume, fullscreen, window size, screen shake, difficulty), Controls,
  Credits, Reset Progress, Quit; pause menu; game over with continues.
* Versioned, crash-safe save (`streets_save.json`) and settings file.
* Keyboard and gamepad input through Godot input actions.
* 39 generated sound effects and 9 generated music loops.

### QA
* 66 automated tests (928 assertions), a two-process save/restart check, bot
  playthroughs on all difficulties, Windows export + exported-pack smoke test.
* Fixed from testing: combo chaining restarted at the jab; attack lunge carried
  the hero through the target; thrown cats hit from the wrong position; boss
  encounters were not marked cleared; out-of-range checkpoint spawn.
* Balance: Hard enemy damage 140% -> 130% and 2 continues per street (was 1).
* Earlier fixes: deferred grab_focus after scene changes, cat painter transform
  reset, camera zoom 1.35 for readable characters, levels extended for a fuller
  campaign, extra life every 40,000 points.
