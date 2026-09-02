# vertical-slice

Playable vertical slice for the cooperative watermelon-smashing game.

## Current milestone

Phase A is merged and green. Phase B adds a local, single-process four-role debug slice so one developer can inspect the full PICNIC round before networking is introduced.

Core loop:

`role assignment -> sensor update -> talk -> blind action -> repeat -> SWING -> result -> reveal -> rematch`

## Run the Phase B debug slice

Open the project in Godot 4.7 and run the project. The main scene is `scenes/debug/local_debug_slice.tscn`.

Controls:

- `F1`: Blind view
- `F2`: Side Radar Guide
- `F3`: Step Echo Guide
- `F4`: Pattern Match Guide
- `F10`: safe debug summary
- Blind actions are available as on-screen buttons

Choose one of the 12 preset boards and press **START ROUND**. During an active round, Guide views show the 6x6 board, Blind position/facing, obstacles, patterns, and only that Guide's private sensor. Blind view contains no board or Guide sensor information. After SWING, use **REVEAL WHAT EVERYONE SAW** to expose the watermelon and full path.

## Headless tests

CI uses official Godot 4.7.2. Locally, with a Godot executable on PATH:

```bash
godot --headless --path . --quit-after 10 tests/test_runner.tscn
```

The successful run ends with `Failures: 0`.

## Game rules that implementation must preserve

1. The Blind player must never receive the watermelon position in its active-view projection.
2. Guides must not automatically receive one another's sensor values.
3. Sensors always report truthful information.
4. The Blind player alone chooses movement and SWING.
5. Movement should create new information.
6. The logical grid is authoritative; presentation never owns gameplay state.
7. SWING success is a logical cell comparison, not a physics collision.
8. Reveal is a post-round second act, not just a score screen.
9. Do not add features to compensate for an unproven core loop.
10. The key product signal is **PLAY AGAIN**.

## Still out of scope

- networking / Steam
- voice chat
- MAYBE / traitor mode
- procedural generation
- additional sensors
- 3D presentation
- production art / audio
- cosmetics / progression
