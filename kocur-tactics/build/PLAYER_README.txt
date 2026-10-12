KOCUR TACTICS  v1.0.0  -  a Kocur Studios game
===============================================

A turn-based pixel-art tactics game. Lead a squad of black cats (Nox the
Shadowblade, Bramble the Guardian, Willow the Ranger and friends) against
the white-cat White Crown Legion across 12 missions in 3 acts, plus 3
tactical challenges.

HOW TO START
  1. Unzip the whole folder anywhere (for example to your Desktop).
  2. Double-click KocurTactics.exe.
  Windows SmartScreen may warn about an unknown publisher because the
  executable is not code-signed: click "More info" -> "Run anyway".

REQUIREMENTS
  Windows 10/11 64-bit, a graphics card with OpenGL 3.3 support.
  No internet connection or installation needed.

CONTROLS (mouse + keyboard)
  Left click ........ select a hero / move to a blue tile
  Left click enemy .. first click aims (shows exact damage), second click confirms
  Right click ....... cancel aim -> undo move -> deselect   (also Backspace)
  1-4 ............... choose an ability
  F ................. interact (Free a captive / Claim a relic / Escape)
  W ................. wait (end this hero's action)
  Z ................. undo the last move (before acting)
  Tab ............... next hero that can act
  Space ............. confirm the aimed action
  T ................. show every tile enemies can attack next turn
  Enter or E ........ end turn
  Esc ............... pause menu (settings, restart, controls, quit)

RULES IN ONE MINUTE
  Every hero moves once and then acts once per turn. Damage is always
  ATK - DEF (minimum 1) plus listed bonuses: no dice, the preview is exact.
  Melee attacks get +2 when an ally also stands next to the target.
  Walls and pillars block line of sight; forest gives +1 DEF.
  Orange hatched tiles with "!" mark a boss attack that lands next enemy
  turn - step out of them. A red X marks arriving enemy reinforcements.

SAVES AND SETTINGS
  %APPDATA%\KocurTactics\save.json      (campaign progress)
  %APPDATA%\KocurTactics\settings.cfg   (volume, display, speed)
  The game saves automatically after each battle and each upgrade.
  Reset progress from Main Menu -> Reset Progress.

LICENCES
  Game content (code, pixel art, sound effects, music) (c) Kocur Studios.
  Built with the Godot Engine, MIT licence - see LICENSE_GODOT.txt.
