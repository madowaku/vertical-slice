# vertical-slice

Playable vertical slice for the cooperative watermelon-smashing game.

## Current goal

Build the smallest 4-player PICNIC-mode slice that can prove the core loop:

`role assignment -> sensor update -> talk -> blind action -> repeat -> SWING -> result -> reveal -> rematch`

The first implementation milestone is **Phase A: headless core logic only**.

### Phase A scope

- Godot 4.7 / GDScript
- 6x6 logical grid
- 12 validated preset boards
- Blind position and facing
- Relative movement: FORWARD / LEFT / RIGHT / BACK
- Obstacles and boundary collisions
- 3 sensors:
  - Side Radar
  - Step Echo
  - Pattern Match
- 8-turn round state machine
- Turn records
- Headless tests
- Minimal success output; detailed logs only on failure

### Explicitly out of scope for Phase A

- UI
- 3D presentation
- networking
- Steam integration
- voice chat
- MAYBE / traitor mode
- procedural generation
- additional sensors
- cosmetics / progression

## Game rules that implementation must preserve

1. The Blind player must never receive the watermelon position.
2. Guides must not automatically receive one another's sensor values.
3. Sensors always report truthful information.
4. The Blind player alone chooses movement and SWING.
5. Movement should create new information.
6. The logical grid is authoritative; 3D is presentation only.
7. SWING success is a logical cell comparison, not a physics collision.
8. Reveal is a post-round second act, not just a score screen.
9. Do not add features to compensate for an unproven core loop.
10. The key product signal is: **PLAY AGAIN**.

## Repository workflow

Implement in small commits. Do not mix unrelated refactors or speculative product features into Phase A.
