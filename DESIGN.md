# Project Grid: Design Document

Handover document for the developer of the first prototype.
Engine: Godot 4.7 (project already set up in this directory). Reference mockup: `screenshot.png`.

## How to read this document

Every rule carries one of two labels:

- **[Decided]** The designers have settled this. Implement it as written.
- **[Default]** Not settled. This is a suggested starting value so the prototype can be
  built. The developer may choose differently.

Two overriding requirements:

1. **Nothing is locked in.** The purpose of the prototype is to iterate once we can play
   it. Every number, every pattern, every enemy parameter and every [Default] rule should
   be changeable without rewriting code, ideally from data files or Godot resources.
2. **Modularity is crucial.** We will change existing features and add new ones (abilities,
   enemy types, tile types, effects, rules) many times. A modular structure matters more
   than polish or completeness. See section 11.

**Art is bare-bones on purpose.** Plain coloured boxes on a grid, as in `screenshot.png`,
are entirely sufficient: a blue square for the player, red squares for enemies, black
walls, and so on. Spend no time on sprites, animation or sound.

## 1. Concept

A turn-based game on a 2D grid. The player moves one tile per step with the arrow keys.
There are no ability buttons: abilities fire automatically when the player's recent moves
complete a specific movement pattern. Enemies and projectiles advance once per player step
(lock-step time).

One room is one stage. The long-term frame is a rogue-like made of such rooms, with ability
pickups and upgrades between and inside them. **The proof of concept (PoC) is a single
room.**

## 2. Scope of the PoC

In scope:
- One hand-built room, roughly as in the mockup (16x16 tiles, walls, an exit area, about
  six enemies).
- Player movement, the pattern system, two starting abilities.
- Two enemy types (chaser, shooter). A third "boss" type if time allows.
- Projectiles, health, win and lose states, restart.
- Fog of war and enemy activation range.
- The two pickup tiles, in simplified form.
- Hazard and slow terrain, in simplified form.

Out of scope for now: multiple rooms, procedural generation, meta progression, any art
beyond coloured boxes, sound, menus beyond restart.

## 3. Win and lose

- **[Decided]** The player wins the room by **reaching the exit or by killing all enemies**.
- **[Decided]** The player loses when their health reaches zero.
- **[Decided]** In a simultaneous kill the player gets the advantage (see section 5).

## 4. Movement and time

- **[Decided]** Lock-step time. The world advances only when the player makes a valid move.
- **[Decided]** The player moves one tile in one of four directions per step. No diagonals.
- **[Decided]** There is **no wait action**.
  - Reasoning: movement is both positioning and attacking. Being unable to pass a turn makes
    every step a commitment, and an unwanted pattern completion is part of the game.
- **[Decided]** An invalid move (into a wall, off the grid) is rejected. No turn passes,
  nothing in the world steps, and the move is not added to the move history.
- **[Default]** Moving into a tile occupied by an enemy is an invalid move.
- **[Default]** If the player has no valid move at all (boxed in), a key press passes the
  turn without moving and without adding to the move history. Alternative to try: this
  counts as a loss.

## 5. Step resolution

- **[Decided]** Player and enemies resolve **simultaneously** within a step.
- **[Decided]** When kills happen in the same step, the player has the advantage.

**[Default]** Suggested order to implement this:

1. The player moves. The move is appended to the move history.
2. Abilities completed by this move trigger. Their damage and stun are applied.
3. Enemies killed in step 2 are removed and do not act. Enemies stunned in step 2 skip
   their action this step.
4. Win check: exit reached or no enemies left. If true, the player wins, even if step 5
   would have killed them.
5. Remaining enemies act and projectiles advance, all decided from the same board state.
   Damage to the player is applied.
6. Lose check.
7. Vision and fog are updated.

**[Default]** If the player and an enemy want to enter the same empty tile in the same
step, the player gets it and the enemy stays where it is.

## 6. Pattern abilities

This is the core of the game and should be the most carefully built system.

### 6.1 Matching rules

- **[Decided]** The game keeps a history of the player's **successful** moves. Only that
  sequence matters. Taking damage, being stunned, or rejected inputs do not break or alter
  it.
- **[Decided]** An ability triggers at the moment the **most recent moves** equal its
  pattern exactly (suffix match). What came before the pattern is irrelevant.
- **[Decided]** Patterns can be **rotated** in 90° steps. They are **never mirrored**.
  Rotation can be disallowed per ability, so it must be a per-ability setting.
- **[Decided]** **Different abilities can overlap.** One move can count toward several
  abilities, and all of them trigger. Example: the first two moves of the loop are an
  L-strike, so both fire in the course of one loop.
- **[Decided]** **The same ability cannot overlap with itself.** A move that was part of a
  triggered instance of an ability cannot be part of another instance of that same ability.
  - Reasoning: without this, walking a continuous clockwise circle would fire the L-strike
    and the loop on every single step, which makes spinning in place the dominant strategy.
  - Suggested implementation: store, per ability, the history index of its last trigger. A
    new match is valid only if its first move comes after that index.
  - Resulting behaviour on a continuous clockwise circle: the L-strike fires every second
    step and the loop every fourth step.
- **[Default]** If several abilities trigger on the same move, they resolve in the order
  they are listed in the player's ability list.

Consequences worth knowing while building and testing:
- With rotation and no mirroring, every clockwise turn is an L-strike, and a
  counter-clockwise turn is never one. Counter-clockwise movement is the "quiet" way to
  move.
- The loop traces a 2x2 square, so it needs three free neighbouring tiles.

### 6.2 Effect areas

- **[Decided]** The effect area is anchored at the tile where the pattern **ended**, and it
  rotates together with the pattern.
- **[Default]** The player is not harmed by their own abilities.
- **[Default]** Walls do not block ability effects.

### 6.3 Starting abilities

Numbers are placeholders taken from the mockup. Offsets are (x, y) relative to the end
tile, in the canonical orientation, with x to the right and y upward.

**[Decided] after the first playtest:** the mockup areas (an off-centre 2x2 for the L-strike,
the four diagonals for the loop) were too hard to aim. Areas are now defined relative to
the player: **stun hits the tiles around the player, damage hits a cone in front**. "In
front" is the direction of the last move of the pattern. To allow this, each effect of an
ability can have its own area; an effect without one uses the ability's area.

| Ability | Canonical pattern | Rotatable | Effect | Area (offsets from end tile) |
|---|---|---|---|---|
| L-strike | up, right (ends facing right) | yes | 1 turn stun | the 8 tiles around the player |
| | | | 1 damage | cone in front: (1,0), (2,1), (2,0), (2,-1) |
| Loop | up, left, down, right (counter-clockwise, ends facing right) | yes | 8 damage | cone in front: (1,0), (2,1), (2,0), (2,-1) |

**[Decided] after the first playtest:** the loop runs **counter-clockwise**. Consequences:
the two starting abilities no longer share moves, so walking a loop does not fire
L-strikes on the way (clockwise turns are L-strikes, a counter-clockwise square is the
loop). Counter-clockwise movement is therefore no longer fully "quiet": single
counter-clockwise turns still fire nothing, but four in a row complete a loop. The
statements in 6.1 about the loop containing an L-strike describe the original clockwise
loop; overlap between different abilities still works as specified.

- **[Default]** The cone is one tile directly in front, then three tiles behind it. Its
  size and the damage numbers are unchanged placeholders.
- The patterns themselves are unchanged. If they are still too hard to pull off, shorter or
  different patterns are a data change in `data/abilities`.

The original mockup areas, for reference: L-strike (0,0), (-1,0), (0,1), (-1,1); loop
(-1,-1), (1,-1), (-1,1), (1,1).

- **[Default]** "1 turn stun" means the enemy skips its next action.

## 7. Health

- **[Decided]** Rough shape: the player has **low** health, the melee enemy has **high**
  health, the ranged enemy has **lower** health.
- **[Default]** Starting numbers:

| Unit | Health |
|---|---|
| Player | 3 |
| Chaser | 8 |
| Shooter | 2 |
| Boss | 24 |

With these numbers a loop kills a chaser in one hit and an L-strike is mainly a stun tool
against it, while two L-strikes kill a shooter.

## 8. Enemies

- **[Decided]** The enemy shown in the mockup (double arrows, 2 damage on the surrounding
  3x3) is scrapped for now.
- **[Decided]** Enemies have no pattern mechanics of their own. They take one simple action
  per step.
- **[Decided]** Enemies stay idle until the player is within an activation range X.
- **[Default]** Activation range is 5 tiles and is never larger than the player's vision
  radius, so nothing activates unseen. Once active, an enemy stays active.

### 8.1 Chaser (melee)
- **[Decided]** Runs at the player and damages them.
- **[Default]** Moves one tile per step along the shortest path. If it is adjacent to the
  player (four directions) at the start of its action, it attacks for 1 damage instead of
  moving.

### 8.2 Shooter (ranged)
- **[Decided]** Shoots at the player. A shot creates a **projectile that travels in steps**
  like everything else; it is not an instant hit.
  - Reasoning: a travelling projectile is its own warning. The player sees it coming and
    can step out of its path, so no separate telegraph is needed.
- **[Default]** Fires along a straight line in one of four directions when the player is in
  that row or column with no wall between, within 8 tiles. Fires at most once every 3
  steps. Otherwise it moves one tile to line up with the player.
- **[Default]** Projectiles move 1 tile per step, deal 1 damage, and are destroyed by walls
  and on hitting the player. A projectile hits if it enters the player's tile or if the two
  swap tiles in the same step. Projectiles pass through other enemies and are not affected
  by player abilities.
  - Note: at 1 tile per step a projectile can never catch a player running straight away
    from it. Speed 2 is the obvious variant to try.

### 8.3 Boss
- **[Decided]** Does "a bit more complex stuff". Nothing more is defined.
- **[Default]** Lowest priority. A simple first version: a chaser with more health that,
  every few steps, marks the 3x3 around itself and deals 2 damage there on the next step.
  This reuses the scrapped mockup enemy and adds the game's only telegraphed attack.

## 9. Vision and fog of war

- **[Decided]** There is fog of war with a limited vision range, and it is linked to enemy
  activation.
- **[Default]** Vision radius 6 tiles. Walls block line of sight. Tiles seen once stay on
  the map in a dimmed state; enemies and projectiles are shown only inside current vision.
- **[Default]** The exit is visible from the start, so the player has a goal to route
  toward.

## 10. Tiles

| Tile in mockup | Meaning | Status |
|---|---|---|
| White | Floor | [Decided] |
| Black | Wall, blocks movement | [Decided] |
| Cyan | Exit area; entering any exit tile wins | [Decided] |
| Gray | Hazard and/or slow terrain | [Decided] in kind, semantics open |
| Green with arrow | Upgrade an existing ability, pick one of three | [Decided] |
| Yellow star | Gain a new ability, pick one of three | [Decided] |

### 10.1 Hazard and slow terrain
Both are wanted; neither is defined. The mockup uses one gray colour for both, so they need
two distinct looks.

- **[Default]** Hazard: 1 damage to any unit that ends a step on it.
- **[Default]** Slow, following the designers' idea: one key press commits the player to
  that direction for two steps, and the two steps together advance one tile. The world
  steps twice. The move history receives **one** entry, so slow terrain costs time but does
  not change which patterns can be completed across it.
- **[Default]** Both affect enemies as well as the player.

### 10.2 Pickups
- **[Decided]** In the full game both pickups offer a choice of three.
- **[Decided]** For the PoC the choice may be missing or trivial.
- **[Default]** Build the pick-one-of-N screen, but feed it placeholder options, for
  example "+1 damage on L-strike" for the upgrade tile and one extra ability for the star
  tile. An example third ability: three moves in the same direction deal 2 damage to the
  three tiles ahead.
- **[Default]** Picking up does not cost an extra step, and the world is paused while the
  choice is open.

## 11. Modularity and configurability

Required, not optional. This is the most important quality of the implementation.

### 11.1 Modularity

The test for the architecture: **adding a new ability, enemy type, tile type or effect
should mean adding one new data file or one small script, without editing the core loop
or existing features.** Concretely:

- **Rules separate from presentation.** Grid state, move history, pattern matcher and step
  resolution live in their own layer with no dependency on rendering or input. Drawing and
  UI only read that state. This also lets the rules be tested without the scene tree.
- **Abilities are data plus composable effects.** An ability is a pattern, an area and a
  list of effects (damage, stun, later push, heal, and so on). A new effect kind is one new
  small unit, usable by every ability. Upgrades are modifications of that data.
- **Enemy behaviour is pluggable.** Each enemy type combines shared stats with a behaviour
  unit (chase, shoot, boss logic) behind a common "decide your action for this step"
  interface. The step resolution does not know which types exist.
- **Tile types are pluggable.** Each tile type defines what happens on entering, on ending
  a step on it, and whether it blocks movement or sight. Hazard, slow, exit and pickups are
  all instances of this, not special cases in the movement code.
- **Rule variants are switches**, not code edits, so two versions of an open rule can be
  compared quickly.
- **Step resolution is an explicit ordered list of phases** (section 5), so phases can be
  reordered or new ones inserted.

### 11.2 Configurability

At minimum the following must be editable as data:

- **Abilities**: pattern (list of directions), rotatable yes/no, effect area offsets,
  damage, stun duration.
- **Enemy types**: health, damage, activation range, movement and attack parameters, fire
  interval, projectile speed and damage.
- **Player**: health, vision radius.
- **Rules as switches**: boxed-in behaviour, moving into enemies, self-damage, walls
  blocking effects, hazard and slow behaviour, whether terrain affects enemies.
- **Room layout**: tiles, start position, enemy placement, pickup placement. A plain text
  or tilemap format that a designer can edit is enough.

In Godot, custom `Resource` types for abilities, effects, enemy types and tile types fit
this well.

## 12. Interface needs

Because abilities fire from movement alone and there is no wait action, the player must be
able to see what a step will do. Suggested for the prototype:

- A panel listing the current abilities with their pattern and area, as in the mockup.
- The last few moves, shown as arrows or as a trail on the grid.
- For each of the four possible next moves, a preview of which abilities it would trigger
  and which tiles they would hit.
- Health of the player and of visible enemies.
- A clear flash on the affected tiles when an ability fires.
- Restart key.

## 13. Open questions for the designers

These were left open on purpose. The developer picks a starting behaviour (the [Default]
entries above) and we decide after playing.

1. What happens when the player is boxed in?
2. Can the player move into an enemy, and how do contested tiles resolve?
3. Exact semantics of hazard and slow terrain, and whether they affect enemies.
4. Concrete health and damage numbers.
5. Fog of war rules and activation range.
6. Shooter details: firing directions, rate, projectile speed, whether abilities can
   destroy projectiles.
7. What the boss does.
8. Which abilities may not be rotated.
9. Content of the upgrade and new-ability choices.
10. Confirmation of the L-strike area reading (section 6.3).

## 14. Implementation notes (first prototype)

Written by the developer. Everything here is a [Default] chosen while building, where the
document left a detail open. All of it is data or a switch unless stated otherwise.

**Where things are**

| To change | Edit |
|---|---|
| Rule switches, order of step phases | `data/rules.tres` |
| Player health, vision radius, starting abilities | `data/player.tres` |
| Abilities (pattern, rotatable, area, effects) | `data/abilities/*.tres` |
| Enemy types and their behaviour parameters | `data/enemies/*.tres` |
| Tile types, hazard damage, slow cost, pickup options | `data/tiles/*.tres` |
| Room layout | `data/rooms/room_01.txt` (legend in the file) |

A new tile or enemy type is a new file in its folder with its own `symbol`; it is picked up
automatically and can then be typed into the room file. New effect, behaviour, tile-effect
or phase kinds are one small script each under `src/core`. Rules live in `src/core` and do
not touch the scene tree; `src/view` only draws. Rules tests:
`godot --headless --path . --script res://tests/run_tests.gd`.

**Choices made where the document was silent**

- **Slow terrain** applies when *entering* a slow tile (tile `move_cost = 2`). On the first
  step the unit stays where it is, on the second it arrives. The tile the player is
  committed to is reserved, so no enemy can take it meanwhile.
- **Hazard** also damages a unit that stays on it (boxed in, or wading into slow terrain),
  since it "ends a step" there. Enemies path around hazards when another route exists.
- **Mockup gray tiles**: the cross left of the star room is hazard, the tiles leading into
  the star room are slow.
- **Activation** is checked at the end of a step, so a newly activated enemy first acts on
  the following step. It needs range *and* line of sight (switch), and an idle enemy that
  takes damage activates (switch).
- **"N tiles"** for vision and activation is a straight-line (Euclidean) radius. Manhattan
  and Chebyshev are available as a switch.
- **Stun** does not stack: a new stun replaces a shorter remaining one.
- **Chaser** attacks only if it is adjacent after the player's move. At equal speed it
  therefore never hits a player who keeps moving away; it hits when the player moves
  alongside or toward it, or is cornered.
- **Shooter**: the projectile appears on the shooter's tile and already advances one tile in
  the step it is fired. While lined up but reloading, the shooter stands still.
- **Projectile and sidestep**: a player who steps *into* a projectile's tile from the side
  is not hit (only entering the player's tile or swapping counts, as written).
- **Boss**: chases; every 4th action it marks the 3x3 around itself instead of moving, and
  on its next action deals 2 damage there. A stun delays the slam, it does not cancel it.
- **Win check runs twice**, after abilities and again after enemies and hazards, both before
  the lose check, so every simultaneous kill goes to the player.
- **Moving into an enemy**: besides "invalid" there is a "swap places" variant to try.
- **Boxed in**: besides "pass the turn" and "lose" there is a "nothing happens" variant.
- **Pickups**: the choice opens after the step in which the tile is entered has resolved.
  A newly gained ability can use moves made before it was picked up.
- **Placeholder content**: upgrade tile offers L-strike +1 damage, L-strike +1 stun, Loop +4
  damage. Star tile offers Lance (three in a line, 2 damage on the three tiles ahead),
  Zigzag (up, right, up: 2 damage and stun on the row ahead) and Recoil (up, down: 1 damage
  and 2 turn stun all around).
- **Room 01** has six enemies: three chasers, two shooters and the boss below the exit.

## 15. Decision log

| # | Decision | Reasoning |
|---|---|---|
| 1 | Win by exit or by killing all enemies | A room is one stage of a future rogue-like; both fleeing and fighting should be valid. |
| 2 | No wait action | Every step is a commitment; movement and attack are the same resource. |
| 3 | Invalid moves cost no turn | Otherwise a wall bump would be a hidden wait action. |
| 4 | Suffix matching on successful moves only | Simple to reason about; damage and stuns do not disturb the player's input sequence. |
| 5 | Rotation yes, mirroring no, rotation optional per ability | Keeps patterns directional and leaves room for abilities tied to a fixed direction. |
| 6 | Different abilities overlap and all trigger | Rewards routes that chain several patterns. |
| 7 | An ability cannot overlap with itself | Prevents continuous circling from firing everything on every step. |
| 8 | Effect area anchored at the end tile | The effect lands where the player is when the pattern completes. |
| 9 | Simultaneous resolution with player advantage | Fair lock-step, without the player losing a trade they also won. |
| 10 | Mockup enemy scrapped; chaser, shooter, boss instead | Simple enemies first, so the pattern system can be judged on its own. |
| 11 | Shooter uses stepping projectiles | Fits lock-step and gives the player something to dodge. |
| 12 | Enemies activate by range; fog of war planned | Lets the player approach groups deliberately instead of fighting the whole room at once. |
| 13 | Pickups simplified for the PoC | The choice system matters for the rogue-like, not for testing the core mechanic. |
| 14 | Open points are developer defaults and must be configurable | The design will be tuned by playing the first prototype. |
| 15 | Modularity is a top requirement | Features will be changed and added repeatedly; each addition should be a new unit, not an edit to the core. |
| 16 | Art is coloured boxes only | The prototype tests the mechanic; the mockup's look is enough. |
| 17 | Stun around the player, damage in a cone in front; areas per effect | First playtest: the mockup areas were too hard to aim and control. |
| 18 | Loop runs counter-clockwise | First playtest; also separates it from the clockwise L-strike. |
