# CASCADIA - DELETION MANIFEST

CANONICAL artifact-cleanup ledger for Cascadia. Manual cleanup only. This is NOT an
automated deletion system, and it is NOT a second roadmap.

Development truth - what Cascadia is, which milestone is accepted, what is verified,
what is deferred - lives in `res://.summer/plans/CASCADIA_MILESTONE_ROADMAP.md`.
This file answers one question class only: **what artifacts exist, whether they are
cleanup candidates, why, what supersedes them, and whether a deletion actually happened.**

Last reviewed: 2026-09-14 (documentation consolidation pass; index added, nothing deleted).

---

## READ THIS FIRST

**NO FILE IN THIS PROJECT HAS EVER BEEN DELETED.** There is no `DELETED` entry anywhere in
this manifest, and every candidate listed below was confirmed present on disk. Recording a
candidate is the action. Deletion is a separate, deliberate, manual step the user performs
later. Do not read this file as evidence that cleanup already happened.

Rules:
- Never delete, rename or move a project file as part of routine development.
- When a file looks obsolete, add an entry here instead.
- Do not stop or block normal development because cleanup is pending.
- Do not repeatedly ask for deletion confirmation.
- If usefulness is uncertain, leave the file in place and mark "Safe To Delete: Uncertain".
- Never upgrade a candidate's status to `APPROVED` or `DELETED` without an explicit user
  decision. Do not infer approval from age, from a replacement existing, or from this file.

Status vocabulary (use exactly these):

    RETAIN                           - deliberately kept; still useful
    REVIEW                           - needs a human decision before any action
    CANDIDATE FOR DELETION           - unnecessary once its dependents stop needing it
    APPROVED - MANUAL DELETION REQUIRED - the user approved removal; the file is still here
    DELETED                          - removed. NOTHING IS IN THIS STATE TODAY.
    REPLACED                         - a canonical file supersedes it
    CONSOLIDATED                     - merged into another file
    UNRESOLVED                       - path or status could not be verified; do not guess

Entry format (unchanged; every entry body is authoritative for its own fields):

    ## Candidate: path/to/file

    Status: Candidate for manual deletion

    Reason:        Why the file appears obsolete, temporary, duplicated or superseded.
    Replacement:   The file/system that replaced it, if applicable.
    Used By:       Known remaining dependencies. READ THIS BEFORE DELETING ANYTHING.
    Safe To Delete: Yes / Uncertain
    Date Flagged:  YYYY-MM-DD
    Notes:         Additional relevant information.

---

## ENTRY INDEX

Status as recorded in each entry. Derived from the entry headings and their `Status:` lines
on 2026-09-14. The entry body is always the authority for Reason / Used By / Safe To Delete /
Date Flagged - this index is for navigation and retrieval only.

### A. Cleanup candidates - development diagnostics and temporary tooling

| Artifact | Status as recorded |
| -------- | ------------------ |
| `scripts/diagnostics/input_debug_overlay.gd` | CANDIDATE FOR DELETION (uncertain; retain while input ergonomics are unsettled) |
| `scripts/player/player_stub.gd` | CANDIDATE FOR DELETION (M0 placeholder actor, superseded by the real controller) |
| `scripts/diagnostics/step_probe_debug.gd` + `scenes/diagnostics/step_probe_debug.tscn` | CANDIDATE FOR DELETION (two entries; delete together) |
| `scripts/diagnostics/damage_probe_debug.gd` + `scenes/diagnostics/damage_probe_debug.tscn` | CANDIDATE FOR DELETION (two entries; delete together) |
| `scenes/actors/dummy_actor.tscn` | CANDIDATE FOR DELETION (M2 test target; still used by probes) |
| `scripts/diagnostics/actor_probe_debug.gd` + `scenes/diagnostics/actor_probe_debug.tscn` | CANDIDATE FOR DELETION (two entries; delete together) |
| `scripts/diagnostics/attack_probe_debug.gd` + `scenes/diagnostics/attack_probe_debug.tscn` | CANDIDATE FOR DELETION (two entries; delete together) |
| `scripts/diagnostics/hit_feedback_debug.gd` | CANDIDATE FOR DELETION (M4 observability) |
| `scripts/diagnostics/target_sweep_debug.gd` and `scenes/diagnostics/target_sweep_debug.tscn` | CANDIDATE FOR DELETION (two headings share ONE entry body; delete the pair together) |
| `scripts/diagnostics/input_path_probe_debug.gd` + `scenes/diagnostics/input_path_probe_debug.tscn` | CANDIDATE FOR DELETION (two entries; delete together) |
| `scripts/diagnostics/dodge_probe_debug.gd` + `scenes/diagnostics/dodge_probe_debug.tscn` | CANDIDATE FOR DELETION (two entries; holds M6's measured claims) |
| `scripts/diagnostics/parry_probe_debug.gd` + `scenes/diagnostics/parry_probe_debug.tscn` | CANDIDATE FOR DELETION (two entries; delete together) |
| `scripts/diagnostics/enemy_attack_probe_debug.gd` + `scenes/diagnostics/enemy_attack_probe_debug.tscn` | CANDIDATE FOR DELETION (two entries; delete together) |
| `scripts/diagnostics/dodge_input_probe_debug.gd` + `scenes/diagnostics/dodge_input_probe_debug.tscn` | CANDIDATE FOR DELETION (two entries; delete together) |
| `scripts/diagnostics/fkey_host_ownership_probe_debug.gd` + `scenes/diagnostics/fkey_host_ownership_probe_debug.tscn` | CANDIDATE FOR DELETION (two entries; records which F-keys the host owns) |
| `res://_fkey_probe_report.txt` | CANDIDATE FOR DELETION (probe transcript at project root) |
| `scripts/diagnostics/focus_input_routing_probe_debug.gd` + `scenes/diagnostics/focus_input_routing_probe_debug.tscn` | CANDIDATE FOR DELETION (two entries; delete together) |
| `scripts/diagnostics/mouse_look_routing_probe_debug.gd` (+ `.uid`) | RETAIN - temporary diagnostic, retained |
| `scripts/diagnostics/recovery_chain_probe_debug.gd` + `scenes/diagnostics/recovery_chain_probe_debug.tscn` | CANDIDATE FOR DELETION (two entries; delete together) |
| `scripts/diagnostics/dodge_authority_probe_debug.gd` + `scenes/diagnostics/dodge_authority_probe_debug.tscn` | CANDIDATE FOR DELETION (two entries; holds the 8N measured claims) |
| `scripts/diagnostics/facing_marker_feedback_debug.gd` | CANDIDATE FOR DELETION (uncertain; delete WITH the facing markers or the marker loses swing feedback) |
| `scripts/diagnostics/credit_economy_probe_debug.gd` + `scenes/diagnostics/credit_economy_probe_debug.tscn` | CANDIDATE FOR DELETION (recorded in the M9 pass section) |
| Save/load probes and `scripts/diagnostics/save_load_debug_controls.gd` | CANDIDATE FOR DELETION once save/load becomes a real menu routed through `CascadiaInput` (recorded inside the M10 pass sections) |
| `scripts/diagnostics/game_state_world_restore_probe_debug.gd` + its scene | CANDIDATE FOR DELETION (recorded inside the M10.2 pass section) |
| `scripts/diagnostics/game_state_mixed_state_probe_debug.gd` + its scene | CANDIDATE FOR DELETION (recorded inside the M10.3 pass section) |
| `res://project.godot.bak` | CANDIDATE FOR DELETION (root-level backup, same byte size as `project.godot`) |
| InputMap bindings `quick_load` (F9) and `quick_load_alt` (F8) | REVIEW - binding removal only, NOT a file. The keys are owned by the embedding host and can never reach the game |

### B. Entries whose heading says "Candidate" but which are NOT deletion candidates

Mislabelled by convention, not by intent. Do not delete these; they are real systems, in-use
directories, or retained evidence.

| Artifact | Status as recorded |
| -------- | ------------------ |
| `scripts/combat/enemy_attacker.gd` | NOT a cleanup candidate - real system |
| `scenes/actors/test_attacker.tscn` | NOT a cleanup candidate - real system |
| `.summer/plans/` (directory) | In use - NOT a deletion candidate |
| `res://_dodge_authority_report.txt` | RETAIN - evidence for the 8N measured claims, not a cleanup candidate |
| "Notes On Dodge And I-Frames (Milestone 6) - Acceptance" | Not a candidate at all - an ACCEPTANCE record |

### C. Recurring tooling and editor problems (not files)

| Problem | Status as recorded |
| ------- | ------------------ |
| Stale `open_script_buffers` linter false positive (recorded under more than one heading, and repeatedly as a recurrence) | RETAIN as recorded knowledge - known false positive, do not chase |
| The mouse-capture-must-be-released-in-an-input-event symptom | RETAIN as recorded knowledge - known false positive |

### D. Unresolved paths - recorded, NOT verified (do not guess a status)

| Path | Why unresolved |
| ---- | -------------- |
| `res://_probe_report.txt`, `res://_focus_probe_report.txt`, `res://_mouse_look_report.txt`, `res://_recovery_chain_report.txt`, `res://_retarget_probe_report.txt`, `res://_targeting_probe_report.txt` | All SIX were CONFIRMED present on disk on 2026-09-14, but no dedicated per-file entry exists for them. They are referenced inside the M10 pass sections' "Cleanup candidates (recorded, NOT deleted)" lists and inside the focus / mouse-look entries. Status at path level: UNRESOLVED. CORRECTED 2026-09-14: these transcripts ARE tracked in git (the older five are committed and clean; `_targeting_probe_report.txt` was added by the Milestone 12 commit). An earlier note in this file described them as never tracked - that was wrong. They are durable evidence under the convention the focus and Dodge-authority entries already describe, overwritten by each probe run. `.gitignore` does NOT ignore `_*_report.txt`. |
| `scripts/debug/` | Suggested by the user as a probe path; does NOT exist in this project. The probe went to `scripts/diagnostics/` instead. Recorded, not resolved. |

---

## MILESTONE 9 - SOULSLIKE CREDIT ECONOMY PASS - NEW FILES AND RECORDED CHANGES (2026-09-12)

Recorded at the moment of the work, per the file-hygiene rule. Recording is the action; deletion
stays manual.

### New gameplay file (NOT a deletion candidate)

- `scripts/economy/credit_ledger.gd` (`class_name CreditLedger`). Gameplay, not diagnostic: it owns
  the player's CARRIED Credits and the ONE place an enemy defeat becomes a reward. It subscribes to
  the EXISTING `EnemyDeathComponent.defeated` signal and to nothing else - it never reads `died`,
  never polls `is_dead`, and never looks at a health value - so the definition of "defeat" keeps one
  owner. Carried / stored / spent / persistent are deliberately kept apart and only CARRIED exists.
  Wired as the `CreditLedger` node in `main.tscn`.

### New diagnostic files (cleanup candidates, delete with their scene)

- `scripts/diagnostics/credit_economy_probe_debug.gd` - deterministic probe for the carried-credit
  loop. Kills enemies through the real damage chain and reads the balance; it never awards Credits
  itself, so it measures the production path rather than its own arithmetic.
- `scenes/diagnostics/credit_economy_probe_debug.tscn` - the probe's standalone entry scene.

### Recorded changes to existing files

- `scripts/diagnostics/combat_debug_overlay.gd`: added a `carried credits` line to the player block,
  resolved through `CreditLedger.find_ledger()`. Presentation only; it decides nothing.
- `main.tscn`: added the `CreditLedger` node and its ext_resource (`load_steps` unchanged in kind).

### Process defects found this pass (recorded, not worked around)

- The ledger's refusal attribution checked the defeated STATE before the MORTALITY policy, so every
  non-mortal refusal was filed as NOT_DEFEATED and `awards_refused_non_mortal` was unreachable. The
  refusal itself was correct; the recorded CAUSE was not. Fixed by checking policy before state.
- The console buffer stopped refreshing between rapid probe runs, so several regression probes could
  not be re-read in that pass. Recorded rather than papered over.

### New-directory registration issue, THIRD occurrence

`scripts/economy/` was created for the new gameplay file and the first load failed with `Could not
find type "CreditLedger"` because a brand-new folder is not yet in Godot's global class cache. A
follow-on stale cache entry then kept the edit-time duplicate-class guard pointed at the old path
even after the file had moved, blocking targeted edits. Same class as the two previously recorded
occurrences. Workaround used: keep the file at the path the registry already owns, then re-run.

---

## Candidate: scripts/diagnostics/input_debug_overlay.gd

Status: Candidate for manual deletion

Reason:
Diagnostic overlay. It exists to make the semantic input layer observable during
the input/locomotion milestones so bindings can be verified by eye. It is
development tooling, not shipping UI.

Replacement:
None planned. A real HUD arrives with the combat/UI milestones.

Used By:
res://main.tscn (InputDebugOverlay node).

Safe To Delete:
Uncertain

Date Flagged:
2026-09-11

Notes:
Retain until the input layer and controller ergonomics are confirmed stable.
It costs nothing at runtime when idle and is the only current way to see which
semantic action fired.

---

## Candidate: scripts/player/player_stub.gd

Status: Candidate for manual deletion

Reason:
Milestone 0 placeholder actor. It gives the test environment a physical body for
the camera to follow and for physical collision to be exercised, but deliberately
implements no locomotion (gravity and floor settling only).

Replacement:
The real grounded player controller (Milestone 1: horizontal movement,
acceleration, deceleration, rotation, camera-relative input).

Used By:
No remaining references. res://scenes/test_environment.tscn (Player node) was
switched to res://scripts/player/player_controller.gd in Milestone 1.

Safe To Delete:
Yes

Date Flagged:
2026-09-11

Notes:
Superseded during Milestone 1 (grounded player movement). The Player node's
script reference was repointed to player_controller.gd in the same change, so
nothing in the project loads this file any more. Retained in place per the
project rule that development files are never deleted automatically.

---

## Notes On Naming

Diagnostic and test material is kept under `scripts/diagnostics/` and named
`*_debug_*` or `*_test_*` where practical, so it is easy to find later.

---

## Notes On Asset Health

Recorded 2026-09-11, during Milestone 1, at the user's request.

Earlier in the session a missing-texture report was made against the Modular
SciFi MegaKit import. That claim was re-checked while the test course was being
reworked, and it does NOT hold up. The imports are intact:

- `assets/environments/Modular SciFi MegaKit[Standard]/Textures/` contains all
  22 source PNGs, including the T_Trim_01/02/03 base color, normal, ORM,
  detail mask and emissive maps.
- No orphaned `.png.import` files were found under that pack's glTF folders.
- `assets/environments/Sci-Fi Essentials Kit[Standard]/glTF/` contains its full
  set of source PNGs (enemies, guns, props, crates, trim) alongside the
  .bin / .gltf pairs.

Conclusion: this is not a known defect and nothing here needs fixing. If
missing-texture errors reappear for these packs, the likely cause is an
interrupted import rather than files absent from disk.

One harmless but easily misread filename worth knowing about:

    assets/environments/Sci-Fi Essentials Kit[Standard]/glTF/T_Enemies_BaseColor_png.png

The doubled "png" comes from the pack author, not from this project. It is a
valid image and imports normally.

---

## Notes On Asset Clutter And Import Risk

Recorded 2026-09-11, at the user's request. These are OBSERVATIONS of things
that could cause friction later, not confirmed defects. None of them is
currently producing an error.

1. Unity `.meta` files throughout `assets/characters/Nephilite Studios/`

   Every FBX in the Fist Animation Set has a sibling `.fbx.meta` file, and each
   folder has a `.meta` (for example `Animations/Core.meta`). These are Unity
   metadata and mean nothing to Godot. They are harmless clutter - Godot ignores
   or "keeps" unknown files - but they are noise in the file tree and will be
   scanned on every import pass. Roughly 100+ files.

2. `assets/folder_tree.txt` - about 2 MB

   A directory listing dump sitting inside the project. It is the largest single
   text file under `res://` and serves no runtime purpose. Safe to delete
   manually; recorded here rather than removed.

3. `LowPoly_SpiderBot_Rzenn.blend` in `assets/characters/Low_Poly_Spider_Bot/`

   This is a Blender SOURCE file. Godot imports `.blend` by launching Blender,
   so if Blender is not installed and configured on this machine the import will
   fail. The `.fbx` sitting beside it does not have that dependency and is the
   file to reference from scenes. Worth knowing before wiring the spider bot in.

4. `[Standard]` in two asset folder names

   `Modular SciFi MegaKit[Standard]` and `Sci-Fi Essentials Kit[Standard]`.
   Square brackets work in Godot paths, but they are unusual and can need
   escaping in some shell and tooling contexts. Noting it only so it is not a
   surprise later.

5. `project.godot.bak`

   A stale copy of project settings from before the input bindings were added.
   It does not reflect the current InputMap. Do not restore from it.

Re-confirmed at the same time: neither pack has missing textures. See the asset
health section above.

---

## Notes On The Test Course Layout

Recorded 2026-09-11, during the Milestone 1 test-environment correction.

`res://scenes/test_environment.tscn` has been re-laid-out twice.

FIRST ATTEMPT (superseded): the stations were clustered in the west half and the
player spawned at `(0, 0.1, 4)`. The user reported being blocked from the
obstacle section. That report was answered by moving the course elements, which
was the WRONG diagnosis - see the wall bug below.

ROOT CAUSE FOUND (2026-09-11): the perimeter walls were built with a single
60-unit-long BoxMesh and a 90 degree rotation on two of them, which produced a
giant plus-sign through the middle of the arena instead of a box perimeter:

- `WallNorth` / `WallSouth` had no rotation and a mesh 60 long on Z, so they ran
  north-south through the arena centre line at X = 0, from Z = -60 to Z = +60.
- `WallEast` / `WallWest` had a 90 degree Y rotation, which swung that same
  60-unit length onto X, so they ran east-west through the centre at Z = 0.

The player spawned at `(0, 0.1, 24)`, directly on the X = 0 wall line, and was
confined to the south-east quadrant. That quadrant contained exactly three
solids: the `Ramp`, the `RampLanding` pier and `PillarD`. The user reported
seeing exactly those three. The report was accurate and identified the bug.

FIX: walls are now built from correctly-sized meshes with NO rotation -
`(40, 4, 1)` for the north/south pair and `(1, 4, 40)` for the east/west pair.
The arena is 40 x 40 with walls at X = +/-20 and Z = +/-20.

The `RampLanding` pier was also removed. It was a 2.74 m block sitting beside the
ramp and read as an unclimbable cube blocking the ramp. The ramp now rises to
1.4 m with its low end flush with the ground and facing the spawn.

Course layout (player spawns at `X = 0`, `Z = 12`, facing north):

- Step lane, west at `X = -7`: three separate risers of 0.14 m, 0.28 m and
  0.42 m at `Z = 6`, `Z = -2` and `Z = -10`. Walk west into each from open floor.
- Ramp lane, east at `X = 7`: a 20 degree ramp spanning `Z = 5.17` (LOW end,
  flush with the floor) up to `Z = 9.86` (HIGH end, about 1.68 m tall).

  CORRECTION recorded 2026-09-11. An earlier version of this note said to
  approach the ramp "from the SOUTH (spawn side)". That was WRONG and it made the
  ramp look broken. The measured geometry is the other way round: the spawn is at
  `Z = 12`, which is PAST the high end, so walking straight from spawn into the
  ramp meets the 1.68 m end face and is correctly blocked. To climb the ramp,
  walk past it to `Z < 5` and then head back in the +Z direction.

  A ramp is only climbable from its low end; its side edge is a tall face and is
  correctly not steppable.
- 1 m ledge, east at `X = 7`, `Z = -8`. Deliberately too tall to step onto.
- Corner pillars at `(+/-16, +/-16)` and three target posts along `Z = -18`, as
  scenery and future combat fixtures.
- Label3D signs name each station, at pixel_size 0.016 so they are legible at
  walking distance. An earlier pass shrank them to 0.006, which made them too
  small to read.

All stations sit within about 12 m of spawn and are reachable over open floor.

---

## Candidate: scripts/diagnostics/step_probe_debug.gd

Status: Candidate for manual deletion

Reason:
Temporary Milestone 1 diagnostic harness. It drives the player into a test
station under scripted input and prints measured position and ground state, so
the step-up resolver can be verified without a human at the keyboard. Created to
diagnose why the three step risers could not be climbed.

Replacement:
None. It is a debugging tool, not a system.

Used By:
res://scenes/diagnostics/step_probe_debug.tscn only.

Safe To Delete:
Yes

Date Flagged:
2026-09-11

Notes:
Kept for now because it is the only way this project can verify traversal
behaviour without a playtester, and Milestone 2 (camera) may want the same
pattern. It is inert unless its scene is played directly.

---

## Candidate: scenes/diagnostics/step_probe_debug.tscn

Status: Candidate for manual deletion

Reason:
The scene half of the diagnostic harness above. It instances the whole of
main.tscn and adds one probe node. It is NOT referenced by the main scene and
cannot affect a normal play session.

Replacement:
None. Debugging tooling.

Used By:
Nothing in production.

Safe To Delete:
Yes

Date Flagged:
2026-09-11

Notes:
Pairs with scripts/diagnostics/step_probe_debug.gd. Delete the two together.

---

## Notes On The Step-Up Defect

Recorded 2026-09-11, Milestone 1.

Symptom: the three step risers (0.14 / 0.28 / 0.42 m) could not be climbed and
behaved identically to the 1 m ledge, while the 20 degree ramp worked normally.

Two incorrect diagnoses happened before the real cause was measured:

1. First hypothesis was contact geometry - that a capsule touches a step edge
   roughly one radius short of the edge, so a single frame of travel could not
   carry the body onto the tread. A forward translation was added to compensate.
   This did not fix it, because the code containing it was never reached.

2. The real cause, found by instrumenting the resolver and reading the output:
   `_resolve_step_up()` was gated on `is_on_wall()`. Measured, `move_and_slide()`
   reports ZERO slide collisions on every frame the body travels at full speed
   toward a step, and `is_on_wall()` only becomes true once that collision has
   already killed the body's velocity. So the gate opened only after the player
   had stopped - at which point the horizontal-speed guard returned instead. The
   step-up had never fired at all.

Instrumented evidence (position is the player Z, moving north into the 14 cm step):

    f=36  pos=(-0.011, 10.908)  slides=0  wall=false  wish=1.00
    f=50  pos=(-0.011, 10.037)  slides=0  wall=false  wish=1.00
    f=60  pos=(-0.011,  9.337)  slides=0  wall=false  wish=1.00
    [PROBE] f=200 pos=z 9.279  wall=true     <- pinned, velocity already zero

FIX ATTEMPT 1 (worked for steps, broke the ramp): gate on an explicit
`test_move()` probe ahead instead of the post-slide flags, probing along the WISH
direction while input is held rather than current velocity. This made the steps
climb, but it introduced a SECOND defect.

SECOND DEFECT (reported by the user, 2026-09-11): the ramp then launched the
player forward. Cause, measured rather than assumed: a horizontal `test_move()`
CANNOT tell a slope from a step face. On a 20 degree ramp the surface 0.48 m
ahead is `0.48 * tan(20) = 0.175 m` higher, so a horizontal probe sinks into the
rising slope and returns true. The gate therefore opened on EVERY frame of the
ramp, and each opening teleported the body 0.48 m forward plus 0.5 m up - about
28 m/s of effective motion. Measured before the fix, on the ramp: every frame
reported a 0.48 m correction. A slope is not an obstruction, and a shape cast
cannot see the difference.

FIX (final): gate on ACHIEVED TRAVEL, not on a probe. `_resolve_step_up()` now
receives the position and intended motion for the frame and returns unless the
body achieved less than `blocked_travel_ratio` of its intended horizontal travel.
On a walkable slope the body keeps nearly all of its travel - it simply also
rises - so nothing is corrected. On a step face it achieves almost none, so the
correction fires. This is the discriminator that actually separates the two.

Verified by measured runtime behaviour with the final gate (scripted probe
driving the real controller, recording position each frame and counting frames
whose displacement exceeded 0.15 m - a 0.48 m correction in one frame means a
step; many of them mean a launch):

- 14 cm step: CLIMBS. Final `y=0.129`, 1 over-threshold frame (the intended
  single correction).
- 28 cm step: CLIMBS. Final `y=0.269`, 1 over-threshold frame.
- 42 cm step: CLIMBS. Final `y=0.410`, 1 over-threshold frame.
- 1 m ledge: BLOCKED. Pinned at `z=-5.62`, `y=-0.011`, 0 over-threshold frames.
- Ramp, low end: SMOOTH. Rose `y -0.011 -> 1.648` with 0 over-threshold frames
  and a max per-frame step of 0.0701 m - which is exactly normal walking speed
  (4.2 m/s at 60 fps), so there is no launch and no unnatural slide.
- Ramp, high end: BLOCKED, as a 1.68 m end face should be.

`max_step_height` (0.5), `floor_max_angle` (46 deg), the ledge and the ramp
geometry were NOT changed. No collision rule was weakened and step-up was not
disabled - it still fires, exactly once per step.

Both wrong gates are documented above deliberately, so neither gets reintroduced:
the first never opened; the second opened far too often.

---

## Notes On The Damage Plumbing

Recorded 2026-09-11, Milestone 2.

The foundation is four small files under `scripts/combat/` plus the layer map in
`scripts/core/game_layers.gd`:

- `damage_event.gd` - `DamageEvent`, a plain data object (amount, source,
  hitbox, position, was_lethal). No behaviour. Later milestones add fields here
  (poise damage, damage type, knockback) without changing every call signature.
- `health_component.gd` - `HealthComponent`, a `Node` child of the body named
  exactly `Health`. Owns the health value and is the ONLY place damage is
  applied, so "exactly once per valid hit" has one place to be true or false.
  `apply_damage()` returns whether health actually changed.
- `hurtbox_component.gd` - `HurtboxComponent`, an `Area3D` on `HURTBOX` with
  mask 0. Never monitoring, never masks anything: it can receive but never
  detect, so it cannot push a body or block a hit.
- `hitbox_component.gd` - `HitboxComponent`, an `Area3D` on `HITBOX` masking
  `HURTBOX` only. Windows are explicit `activate()` / `deactivate()` calls, so
  attack timing stays in gameplay (Milestone 5) and never in the volume.

Layer separation, verified at runtime by the probe: the target's physical body
stays on `WORLD`/`ACTOR`, the hurtbox is a separate `Area3D` on `HURTBOX`, and
no body is ever placed on a combat layer. Physical collision and combat
collision are genuinely different concerns, as the project rules require.

DEFECT FOUND AND FIXED DURING VERIFICATION: the first implementation used
`monitoring` as the window gate. Measured, a window closed and reopened inside
the SAME frame applied nothing - `monitoring` toggling off/on does not reliably
re-detect an already-overlapping area, so the hit was silently dropped. Windows
separated by frames applied correctly, which is what isolated it. `monitoring`
is now always on and the `active` flag is the real gate, with an explicit sweep
when a window opens. This matters beyond testing: a fast attack chain in
Milestone 5 could close and reopen a window quickly and lose a hit.

## Notes On New Script Folders And The Class Cache

Recorded 2026-09-11. Worth knowing before adding another subsystem.

Godot's global class cache (`.godot/global_script_class_cache.cfg`) did NOT pick
up the four new classes when they were first written into `scripts/combat/`, a
brand-new folder. The editor filesystem scanner had not discovered the folder,
so every cross-file reference to `HealthComponent`, `HitboxComponent`,
`HurtboxComponent` and `DamageEvent` reported "not declared in the current
scope", and the probe scene failed to load WITH NO CONSOLE OUTPUT - which looks
exactly like a silent logic failure and is not one.

Two things resolve it, and the distinction matters when diagnosing:

- Writing a new file into an ALREADY-SCANNED folder registers fine (this is why
  `damage_probe_debug.gd` appeared in the cache while the combat classes did not).
- A brand-new folder needs the scanned file tree refreshed. `RevealInFileSystem`
  on a file inside it triggered the rescan here; all four classes then appeared
  in the cache and the errors cleared.

Also re-confirmed from earlier milestones: the recurring
`Identifier "GameActions" not declared` errors are scoped to
`open_script_buffers` - stale analysis of scripts open as editor tabs. They are
not runtime failures. The class is registered in the cache and resolves when the
game runs. Do not chase them, and do not trust them over a clean run.

---

## Candidate: scripts/diagnostics/damage_probe_debug.gd

Status: Candidate for manual deletion

Reason:
Temporary Milestone 2 diagnostic harness. Drives the damage plumbing through a
scripted sequence - open window, hold it, close and reopen, damage to death,
damage after death, then damage the player - and prints measured results. It
exists because no still frame can prove that damage applies exactly once or that
death happens at zero health.

Replacement:
None. Debugging tooling, not a system.

Used By:
res://scenes/diagnostics/damage_probe_debug.tscn only.

Safe To Delete:
Yes

Date Flagged:
2026-09-11

Notes:
Inert unless its scene is played directly. It carries its own neutral hitbox and
is not referenced by the main scene.

---

## Candidate: scenes/diagnostics/damage_probe_debug.tscn

Status: Candidate for manual deletion

Reason:
The scene half of the damage probe above. Instances all of main.tscn and adds
one probe body.

Replacement:
None. Debugging tooling.

Used By:
Nothing in production.

Safe To Delete:
Yes

Date Flagged:
2026-09-11

Notes:
Pairs with scripts/diagnostics/damage_probe_debug.gd. Delete the two together.

---

## Notes On Actor Physical Collision (Milestone 3)

Recorded 2026-09-11, Milestone 3.

Established that an actor's PHYSICAL body and its COMBAT volumes are separate
concerns, and proved it by measurement rather than assertion.

New reusable actor: `res://scenes/dummy_actor.tscn`. A CharacterBody3D on
GameLayers.ACTOR with a capsule collider, plus `Health` and `Hurtbox` children.
It carries no script of its own: a physical body needs no damage logic, and the
combat volumes resolve their own layers in their own `_ready`.

Instanced once into `res://scenes/test_environment.tscn` as `DummyActor` at
`(0, 0, 5)`, standing in open floor between the spawn and the course.

Verified by the actor probe, `RESULT: ALL CHECKS PASSED`:

- Physical blocking is real. A carrier body driven straight at the actor for 90
  frames at 5 m/s did not pass through it. Measured: start z=7.478, end z=5.781,
  actor z=4.978, final gap 0.803 m. That is exactly the two capsule radii
  (0.4 + 0.4), so bodies stop where they physically should.
- Combat damage still lands THROUGH the physical body. The probe parked its
  hitbox 0.000 m from the actor's centre - deeper inside the body than the
  carrier could ever reach, having been blocked 0.803 m out - and damage still
  applied exactly once (100 -> 75), with one damaged signal.
- A held window did not re-apply.
- Layer audit, printed at runtime: actor body on ACTOR and on no combat layer;
  hurtbox is an Area3D on HURTBOX with mask 0; hitbox is layer 4 (HITBOX) masking
  8 (HURTBOX) only, and cannot see WORLD or ACTOR at all.

No collision rule was weakened, no layer was merged, and existing behaviour did
not need to change for this to hold.

## Camera Mask Drift - Found And Fixed In Milestone 3

The SpringArm3D in `test_environment.tscn` had `collision_mask = 9`, written in
Milestone 1 when the layer map was `WORLD | CAMERA_BLOCKER` = `1 | 8`.

Milestone 2 renumbered the layers: bit 3 became HURTBOX and CAMERA_BLOCKER moved
to bit 4. The literal `9` was not updated with it, so the camera was treating
HURTBOX as obstruction and had stopped respecting CAMERA_BLOCKER.

Fixed to `17` = `WORLD | CAMERA_BLOCKER` (`1 | 16`).

This is exactly the drift the layer-map comment in `game_layers.gd` warns about:
the constants and the literal values written into scenes are two separate copies
of one fact. Any future change to the layer map must grep the scenes for literal
masks.

## New-Directory Registration - Second Occurrence

In Milestone 2 the brand-new `scripts/combat/` folder was not discovered by the
class cache, so cross-file `class_name` references reported "not declared" and a
scene failed to load with no console output.

Milestone 3 hit the same thing for a new SCENE folder, with a clearer error:

    [SE] Timed out registering owned file in EditorFileSystem:
         res://scenes/actors/dummy_actor.tscn
    failed to open scene res://scenes/actors/dummy_actor.tscn (err 7)

`err 7` is file-not-found at the FILESYSTEM level, not a parse error. Godot never
registered the new directory, so the file was invisible to the engine even though
it was present on disk. Scripts written into already-registered folders were
unaffected, which is what isolated it to the directory rather than the file.

Practical rule: prefer writing new scenes into a folder the editor already knows
(`res://scenes/`). If a new folder is genuinely needed, expect the first load to
fail and force a rescan before concluding anything is wrong with the file itself.

## Process Note: Reported Writes That Were Not On Disk

Early in Milestone 3, three file writes were reported as succeeded but were
proven absent from disk on inspection: `scenes/actors/dummy_actor.tscn`,
`scripts/diagnostics/actor_probe_debug.gd` and
`scenes/diagnostics/actor_probe_debug.tscn`. Their reported hashes did not match
any file in the project.

All three were written again and then verified present, by reading them back and
by a successful scene load. Recorded because a receipt is not the same as a file,
and this project's history should say which is which.

---

## Candidate: scenes/actors/dummy_actor.tscn

Status: Candidate for manual deletion

Reason:
Byproduct of the registration problem above, not a content mistake. Written first
inside a brand-new `scenes/actors/` folder the editor filesystem never registered,
so the engine could not load it. An identical copy was written to
`res://scenes/dummy_actor.tscn`, which is the one actually used.

Replacement:
`res://scenes/dummy_actor.tscn`

Used By:
Nothing. The live instance in `test_environment.tscn` points at
`res://scenes/dummy_actor.tscn`.

Safe To Delete:
Yes

Date Flagged:
2026-09-11

Notes:
Not deleted, per the project rule that development files are never removed
automatically. Delete if the `scenes/actors/` folder is not wanted.

---

## Candidate: scripts/diagnostics/actor_probe_debug.gd

Status: Candidate for manual deletion

Reason:
Temporary Milestone 3 diagnostic harness. Drives a carrier body into an actor and
parks a hitbox inside that actor's body volume, proving physical and combat
collision are separate concerns. Debugging tooling, not a system.

Replacement:
None.

Used By:
res://scenes/diagnostics/actor_probe_debug.tscn only.

Safe To Delete:
Yes

Date Flagged:
2026-09-11

Notes:
Kept for the same reason as the other probes: it is how collision behaviour gets
verified without a playtester. Inert unless its scene is played.

---

## Candidate: scenes/diagnostics/actor_probe_debug.tscn

Status: Candidate for manual deletion

Reason:
The scene half of the actor probe above. Instances all of main.tscn and adds one
probe node.

Replacement:
None.

Used By:
Nothing in production.

Safe To Delete:
Yes

Date Flagged:
2026-09-11

Notes:
Pairs with scripts/diagnostics/actor_probe_debug.gd. Delete the two together.

---

## Notes On Player Attacks (Milestone 4)

Recorded 2026-09-11, Milestone 4. Light and heavy attack, each with
STARTUP / ACTIVE / RECOVERY.

Architecture:

- `res://scripts/combat/attack_definition.gd` (`AttackDefinition`, a Resource)
  holds one attack's timing and damage. It is data only: no input, no state, no
  scene access. Later milestones add poise damage or a hit reaction here.
- `res://scripts/player/player_combat.gd` (`PlayerCombat`, a Node under the
  player) owns the state machine and nothing else. Locomotion is not here,
  stamina is not here, health is not here.
- The damage volume is `Player/AttackHitbox`, a `HitboxComponent` already on
  HITBOX masking HURTBOX. `source_actor_path = NodePath("..")` makes it refuse
  to hit its own owner, which matters because it sits inside the player's own
  hurtbox reach.
- The controller asks `is_busy()` and stands down while an attack is in
  progress. This is what makes an attack commit the body: movement stops
  feeding it, and the attack cannot be cancelled out of.

Timings, in seconds, chosen so the heavy attack is the committed option:

    LIGHT   startup 0.16  active 0.10  recovery 0.28  damage 15
    HEAVY   startup 0.44  active 0.14  recovery 0.62  damage 32

Commitment is structural rather than a rule checked afterwards: an attack may
only begin from IDLE, and a press during an attack is refused outright rather
than queued, so no accidental combo chain can form. There is deliberately no
cancellation path from STARTUP or RECOVERY.

Stamina cost is deliberately NOT implemented. The stamina system does not exist
yet (its own milestone). When it arrives the cost belongs to this state machine,
not to the hitbox.

Verified by measured runtime output, probe printed RESULT: ALL CHECKS PASSED:
light and heavy each accepted from IDLE, each returned to IDLE on its own, the
window opened for the active phase only, damage landed only inside ACTIVE, a
second attack during STARTUP was refused and not counted, and health moved by
exactly the attack's damage.

NOT verified: that LIGHT_ATTACK / HEAVY_ATTACK input reaches the state machine.
The probe drove the state machine through `try_start()` directly rather than by
injecting input events, so pressing the mouse buttons is still unproven. That is
exactly the user playtest.

---

## Candidate: scripts/diagnostics/attack_probe_debug.gd

Status: Candidate for manual deletion

Reason:
Temporary Milestone 4 diagnostic harness. Drives the attack state machine
through a scripted sequence and prints the observed phase, window state and
health, so attack timing and commitment can be verified from measured output.

Replacement:
None. Debugging tooling.

Used By:
res://scenes/diagnostics/attack_probe_debug.tscn only.

Safe To Delete:
Yes

Date Flagged:
2026-09-11

Notes:
Delete together with its scene.

---

## Candidate: scenes/diagnostics/attack_probe_debug.tscn

Status: Candidate for manual deletion

Reason:
The scene half of the attack probe above. Instances all of main.tscn and adds
one probe node.

Replacement:
None.

Used By:
Nothing in production.

Safe To Delete:
Yes

Date Flagged:
2026-09-11

Notes:
Pairs with scripts/diagnostics/attack_probe_debug.gd. Delete the two together.

---

## Candidate: scripts/diagnostics/hit_feedback_debug.gd

Status: Candidate for manual deletion

Reason:
Temporary in-world hit-confirmation feedback. Before this, a landed hit produced no
visible result anywhere in the world: the HUD listed actors by name and health, but
nothing on the struck target itself proved which object had just been damaged, and
two actors shared the name DummyActor. This prints a rising damage number above the
struck actor, flashes its material red, and shows a short-lived health bar over it.

Replacement:
None. Milestone 15 (animation adapter) plus a real HUD will replace it with proper
hit reaction, damage numbers and enemy health bars.

Used By:
res://main.tscn (HitFeedback node). Inert in that scene until a hitbox reports a
landed hit, which only a real attack does.

Safe To Delete:
Yes

Date Flagged:
2026-09-11

Notes:
Listens on the damageable group and on the player's AttackHitbox signal, so it needs
no exported paths. Milestone 4 could have been functioning perfectly while still
being unverifiable by the user, which is why it exists.

---

## Candidate: scripts/diagnostics/target_sweep_debug.gd
## Candidate: scenes/diagnostics/target_sweep_debug.tscn

Status: Candidate for manual deletion

Reason:
Temporary Milestone 4 verification harness. Walks every damageable actor in the
scene, drives the player's real light attack from real range, and measures health
before and after, so "every target is attackable" is checkable in one run instead of
by hand.

Replacement:
None. Debugging tooling.

Used By:
Nothing in production. The scene instances all of main.tscn and adds one probe node.

Safe To Delete:
Yes

Date Flagged:
2026-09-11

Notes:
Delete the two together. This is the probe that found the stray duplicate DummyActor
in main.tscn (see the Milestone 3 notes) and that now proves all four targets take
damage.

---

## Notes On The Combat Readout And Hit Confirmation

Recorded 2026-09-11, Milestone 4 observability pass.

WHY THIS PASS EXISTED
Milestone 4 was built and the attacks fired, but the result could not be confirmed
by eye: there was no health, damage, hit-confirmation or attack-phase display
anywhere, and the arena showed only one visibly distinct target. The user could not
tell whether an attack reached anything. Diagnostic UI is usually the thing that
gets skipped, and skipping it here is exactly what made a working system
unverifiable.

THREE DEFECTS FOUND AND FIXED IN THE READOUT
1. The panel was clipped off the RIGHT edge. `set_anchors_and_offsets_preset` was
   applied before the labels were added, so the panel had zero width at anchor time
   and then grew outward off-screen instead of expanding leftward.
2. The panel was then clipped off the BOTTOM edge. No grow direction was set, so
   runtime rows added at the END of its vertical axis pushed its bottom out of the
   viewport.
3. `_reclamp()` still measured a stale size. It was called once at build time, but the
   actor rows are created later, so anchors were derived from a size the panel no
   longer had. Anchors cannot track a container whose content height changes. It is
   now a plain top-left anchored panel whose position is clamped every frame from
   `get_combined_minimum_size()`, after the rows are updated.

Also: `combat_path` and `hitbox_path` had no default and resolved to null, so the
attack volume and state machine could never have been found by tooling. Both now
default to their sibling paths in the script rather than the scene. Worth knowing:
a SetProp for a NodePath that equals the property's default is silently dropped by
the ops layer and does NOT appear in the saved scene.

RAMP ORIENTATION
Measured during the Milestone 1 work: the ramp's low end is at ~Z=5.17 and its high
end at ~Z=9.86. The player spawns at Z=12, which is PAST the high end, so walking
straight north from spawn meets the tall end face. Earlier notes in this file
claimed the low end faced the spawn; that was wrong and has been corrected.

---

## Notes On Arena Target Placement

Recorded 2026-09-11, Milestone 4 observability pass.

Four damageable targets now stand in a visible row at Z=-2, centred on the spawn
axis so all of them are in front of the player at once:

- TargetA   at (-5.0, 1.18, -2)  [seated on Step28; top surface 0.28]
- TargetB   at (-2.5, 0.9, -2)
- DummyActor at ( 0.0, 0.0, -2)
- TargetC   at ( 2.5, 0.9, -2)

Each has a Label3D above it at y=2.6, pixel_size 0.009. The size matters: at 0.016
the names collided into one unreadable string ("TARGET B DUMMY ACTOR TARGET C"),
which defeated the entire purpose of naming them.

Viewport note: in the narrow docked viewport (347 px wide) the horizontal field of
view is only about 34 degrees, so a 24 m spread of targets cannot all be on screen.
The row is deliberately kept inside roughly 10 m for that reason. If the targets are
ever spread out again, expect only some of them to be visible while docked.

---

## Notes On Target Grounding

Recorded 2026-09-12, the grounding pass requested after Milestone 4.

REPORTED: TargetA was spawned on a step and appeared to float, sink or clip.

CAUSE, measured rather than assumed. Two facts combine:

1. The test targets are placed by DIRECT TRANSFORM. A StaticBody3D has no gravity,
   no floor detection and no floor snapping, so nothing grounds it - its Y is
   whatever number was typed into the scene. TargetA kept its flat-ground Y of 0.9
   after being moved into the step lane.

   The geography of the mistake: Step28 is a 6 x 0.28 x 6 box centred at
   (-7, 0.14, -2), so its top surface is at y = 0.28 and its footprint is
   x -10..-4, z -5..1. TargetA's 1.8 m cylinder at (-5, 0.9, -2) has a footprint of
   x -5.35..-4.65, entirely inside that step. Its base therefore sat at y = 0.0
   while the surface beneath it was at y = 0.28 - sunk 0.28 m into the block.

2. The PLAYER is unaffected because PlayerController applies gravity and calls
   move_and_slide(), which performs floor detection and floor snapping
   (floor_snap_length 0.4). That is the whole asymmetry: the player is grounded by
   code, the targets are grounded by nothing.

FIX (smallest correct change): TargetA is placed at (-5, 1.18, -2), putting its
1.8 m cylinder base exactly on the 0.28 step top; its Label3D moved with it to
y 2.88. The dummy actor's collision and mesh sat at local y 0.92 against a capsule
whose full height is 1.8, so its base floated 0.02 m; both corrected to 0.9.

NOT changed: no actor gained a script, gravity, grounding or AI. These are static
test fixtures, not enemies. No player input or combat behaviour was copied onto them.

VERIFICATION - measured, not eyeballed. New diagnostic
scripts/diagnostics/grounding_probe_debug.gd casts a downward ray per actor,
EXCLUDING the actor itself so it cannot hit its own collider, to find the real
surface beneath it, then compares that surface against the actor's actual collision
bottom and mesh bottom. Result: RESULT: ALL CHECKS PASSED.

  TargetA     surface=0.280  collision=0.280  mesh=0.280  mesh-vs-collision=0.000  float/sunk=0.000
  TargetB     surface=0.000  collision=0.000  mesh=0.000  mesh-vs-collision=0.000  float/sunk=0.000
  TargetC     surface=0.000  collision=0.000  mesh=0.000  mesh-vs-collision=0.000  float/sunk=0.000
  DummyActor  surface=0.000  collision=0.000  mesh=0.000  mesh-vs-collision=0.000  float/sunk=0.000
  Player      surface=0.000  collision=0.001  mesh=0.001  mesh-vs-collision=0.000  float/sunk=-0.001

The ray independently found TargetA's surface at exactly 0.280, matching Step28's
computed top, and TargetA's collision bottom and mesh bottom both coincide with it
to 0.000. Every actor's visual mesh also matches its collider.

RENDERED-VIEW LIMITATION, recorded so it is not later mistaken for a clean pass: the
seating was NOT confirmed by a crisp screenshot. A 0.28 m elevation difference is
only about 6 pixels in a whole-arena view, so a still frame at that scale cannot
distinguish "resting on the step" from "level with the floor". In the live gameplay
camera the spot is additionally occluded by the input debug panel. The measurement
above is the strong evidence; the rendered view was consistent but not conclusive.

Also observed and deliberately NOT changed, because it belongs to the debug layer
rather than the game: in the live view TargetA's Label3D sits behind the input debug
panel and near the "STEP 14 CM" sign. F1 hides both debug panels. No overlap between
the four target names themselves was seen in the gameplay camera; they only crowd
together in a steep staged isometric view, which is not a gameplay angle.

---

## Notes On The Roadmap Pass

Recorded 2026-09-12. Documentation pass only - no gameplay code, scene or asset
was changed, and no file was deleted.

Created:

- res://.summer/plans/CASCADIA_MILESTONE_ROADMAP.md (33052 bytes)

That file is now Cascadia's local source of truth for milestone order, status,
acceptance criteria, deferred systems and the next approved task. Read it together
with this manifest.

SIDE EFFECT WORTH RECORDING: the Output panel had been reporting

    Resource file not found: res://.summer/plans (expected type: unknown)

because the res://.summer/plans directory did not exist. Creating the roadmap
created the directory. If that message is still visible it is a stale console
entry; re-check the file system before treating it as a live error.

Also re-confirmed during this pass: the recurring script errors

    Identifier "GameActions" not declared in the current scope.
    (res://scripts/input/cascadia_input.gd)

are still scoped to open_script_buffers, i.e. stale analysis of scripts open as
editor tabs. cascadia_input.gd on disk is well-formed and GameActions is in the
global class list. Same known condition as noted above - not a runtime failure.
Do not chase it.

---

## Candidate: project.godot.bak

Status: Candidate for manual deletion

Reason:
A backup copy of project.godot sitting in the project root. It is byte-for-byte
the same size as project.godot (9669 bytes) and serves no runtime purpose. Godot
does not read it. It is a leftover from an earlier edit or export step.

Replacement:
None needed. project.godot itself is the live file.

Used By:
Nothing. No scene, script or project setting references it.

Safe To Delete:
Uncertain

Date Flagged:
2026-09-12

Notes:
Marked Uncertain rather than Yes because project.godot is the one file a broken
project cannot be rebuilt without, so keeping one known-good backup in the project
root is a defensible choice. If the project is under version control (it is NOT
yet - no git repo exists as of this pass) the backup is redundant. Flagged, not
deleted, per the project rule that development files are never removed
automatically.

---

## Candidate: .summer/plans/ (directory)

Status: In use - NOT a deletion candidate

Recorded only so its existence is not mistaken for clutter later. This directory
holds Cascadia's persistent plan files, beginning with
CASCADIA_MILESTONE_ROADMAP.md. It is part of the project's working documentation,
not a temporary artifact.

---

## Candidate: scripts/diagnostics/input_path_probe_debug.gd

Status: Candidate for manual deletion (development diagnostic)

Reason:
Temporary diagnostic written during audit pass 3 to close the one genuinely unproven
claim in Milestone 4: that the physical left/right mouse buttons actually reach the
attack state machine. Existing probes called `try_start()` directly, so the input path
was never exercised. This probe injects real `InputEventMouseButton` objects through
`Input.parse_input_event()` and watches the production chain end to end.

Replacement:
None - it is development tooling, not a game system.

Used By:
Nothing in the game. `res://scenes/diagnostics/input_path_probe_debug.tscn` instantiates it.
Its result is cited in the roadmap verification log (section 16, "Audit P3").

Dependencies:
Instances `res://main.tscn`. Relies on the live node layout, so it is only valid while
the player is at `TestEnvironment/Player` with `Combat`, `AttackHitbox` and `Health`
children, and the dummy at `TestEnvironment/DummyActor`.

Safe To Delete:
Uncertain - keep while Milestone 4's input path is cited as evidence. Deleting it does
not break the game; it does remove the only reproduction of that verification.

Date Flagged:
2026-09-12

Notes:
A first version of this probe FAILED through its own bug: step 3 released the right
mouse button without ever pressing it, so the heavy path was never exercised and a stale
light-attack result was then mis-graded against the heavy expectation. Fixed in-place
(remove the stray release, actually press button 2). Worth remembering: a failing probe
is not automatically a failing game - read the probe before blaming the system.

---

## Candidate: scenes/diagnostics/input_path_probe_debug.tscn

Status: Candidate for manual deletion (development diagnostic)

Reason:
Scene wrapper for `input_path_probe_debug.gd`. Sibling of `Main`, same pattern as the
other diagnostic scenes under `scenes/diagnostics/`.

Replacement:
None.

Used By:
Manual runs only.

Dependencies:
`res://scripts/diagnostics/input_path_probe_debug.gd`, `res://main.tscn`.

Safe To Delete:
Uncertain - same reason as its script above.

Date Flagged:
2026-09-12

Notes:
Delete together with its script, or the script becomes unreachable tooling.

---

## Notes On The Ramp Label Discrepancy (audit pass 3)

Recorded 2026-09-12. Project-vs-documentation discrepancy, NOT a code defect.

The arena ramp RISES toward the south. Measured this pass with `step_probe_debug`:

- Phase E, labelled "ramp from SOUTH driving north", is BLOCKED by the ramp's tall end
  face.
- Phase F, labelled "ramp from NORTH driving south", climbs it smoothly with a
  `0.0702 m` maximum per-frame step and zero over-threshold frames.

The `Label3D` standing on the ramp reads `"RAMP 20 DEG - WALK UP FROM SOUTH"`, which
names the wrong end, and phase E's label/comment in `step_probe_debug.gd` does too.
The geometry itself is unchanged and correct for Milestone 1.

Deliberately NOT changed: it is a debug-arena cosmetic label plus a probe phase comment.
It has no gameplay effect, and editing the arena would oblige a fresh traversal probe run
for no functional gain. Recorded here so it is not rediscovered as a "bug" later. If the
label is ever corrected, rerun `step_probe_debug` in the same pass.

---

## Notes On The Legacy Milestone Numbering In Code Comments (re-confirmed)

Recorded 2026-09-12, re-confirmed during audit pass 3.

Comments in `player_controller.gd`, `player_combat.gd` and `third_person_camera.gd` use a
LEGACY milestone numbering that disagrees with the roadmap:

    code comments            roadmap (authoritative)
    attacks   = Milestone 5  attacks   = Milestone 4
    stamina   = Milestone 6  stamina   = Milestone 5

`player_controller.gd` still says "attacks (Milestone 5), stamina (Milestone 6)".
The roadmap's numbering is the one to trust. The comments were left alone again:
cosmetic, several files, and churning them risks a needless parse-error cycle. Recorded
so a future reader does not treat the code comment as the source of truth.

---

## Notes On The Audit Pass 3 Probe Sweep (all fresh, nothing carried forward)

Recorded 2026-09-12.

Every diagnostic probe was re-run against the live project during audit pass 3, so no
result from an earlier session is being presented as current:

    damage_probe_debug      RESULT: ALL CHECKS PASSED
    actor_probe_debug       RESULT: ALL CHECKS PASSED
    step_probe_debug        all traversal phases as expected
    attack_probe_debug      RESULT: ALL CHECKS PASSED
    target_sweep_debug      RESULT: ALL CHECKS PASSED (4/4 targets)
    grounding_probe_debug   RESULT: ALL CHECKS PASSED
    stamina_probe_debug     RESULT: ALL CHECKS PASSED
    input_path_probe_debug  RESULT: ALL CHECKS PASSED (new this pass)

Each run reported `debugger.error_count 0`. The recurring 20 `GameActions not declared`
entries remained scoped to `open_script_buffers` with `incomplete: true` while a run that
successfully resolved `GameActions` was in progress - see the class-cache note above and
roadmap section 12.1. The live run is authoritative.

---

## Candidate: scripts/diagnostics/dodge_probe_debug.gd

Status: Candidate for manual deletion

Reason:
Milestone 6 (Dodge and i-frames) verification probe. Temporary diagnostic, not shipping code.

Replacement:
None. It is the only reproduction of the dodge acceptance measurements (travel, duration,
steering lock, per-cause refusals, i-frame refusal counts).

Used By:
Nothing at runtime. It is launched directly as a scene
(`res://scenes/diagnostics/dodge_probe_debug.tscn`). Deleting it removes the only automated
evidence for Milestone 6's measured claims.

Safe To Delete:
Uncertain - yes once Milestone 6's numbers are no longer being re-verified. Prefer keeping
it while dodge tuning is still open (i-frame values are untuned).

Date Flagged:
2026-09-12

Notes:
Contains one fix made this pass: the summary line read `travel=0.000m` because
`_reset_actor()` clears the `_travel` accumulator before the later i-frame phases run.
AC2's own assertion had already passed against the correct value; only the summary was
wrong. The measurement is now captured into `_measured_travel` at evaluation time.
Recorded here because a self-contradicting probe is a real (if cosmetic) defect.

---

## Candidate: scenes/diagnostics/dodge_probe_debug.tscn

Status: Candidate for manual deletion

Reason:
Scene that runs `dodge_probe_debug.gd` against `res://main.tscn`. Temporary diagnostic.

Replacement:
None.

Used By:
Nothing. Launched manually to verify Milestone 6.

Safe To Delete:
Uncertain - delete together with `dodge_probe_debug.gd`, never separately.

Date Flagged:
2026-09-12

Notes:
Same shape as every other probe scene in this project: root Node3D, an instance of
`res://main.tscn` named "Main", and a "Probe" node carrying the script.

---

## Notes On Milestone 6 (Dodge And I-Frames)

Recorded 2026-09-12.

Files CREATED this milestone (all cleanup candidates above or real systems):

- `res://scripts/player/dodge_component.gd` - a REAL SYSTEM, not a cleanup candidate.
  It lives in `scripts/player/` rather than a new `scripts/locomotion/` folder on purpose:
  this project needs an explicit filesystem rescan before a class in a NEW folder resolves
  (see "Notes On New Script Folders And The Class Cache"). Avoiding that known trap cost
  nothing, so no new folder was created.
- `res://scripts/diagnostics/dodge_probe_debug.gd` - diagnostic, cleanup candidate.
- `res://scenes/diagnostics/dodge_probe_debug.tscn` - diagnostic, cleanup candidate.

Files MODIFIED this milestone (not candidates - all live systems):

- `res://scripts/player/player_controller.gd` - dodge input, direction choice, burst
  movement, commitment.
- `res://scripts/player/player_combat.gd` - refuses an attack while a dodge is committed.
  The gate is in `try_start()`, not only on the input path, so no caller can route around
  it.
- `res://scripts/combat/hurtbox_component.gd` - i-frame refusal point, duck-typed through
  `is_invulnerable()` so the hurtbox does not depend on the dodge system.
- `res://scenes/test_environment.tscn` - `Player/Dodge` node added.

Editor / process note, SECOND occurrence of a write reported as done that did not land:

A `writeFile` for `dodge_probe_debug.gd` returned a receipt reading `result=returned`
(not `succeeded`) and the file did NOT exist afterwards - confirmed by glob returning
0 matches and `state:script-errors` returning "file not found". The same shape as the
already-recorded "Process Note: Reported Writes That Were Not On Disk". Re-issuing the
write produced a real sha256 and the file was then present and clean.

Lesson, recorded because it recurs: a write receipt that is not `succeeded` with a sha256
is NOT evidence the file exists. Verify with glob or a read before relying on it. This cost
one false "probe written" state that had to be corrected.

Also observed and deliberately NOT changed: `player_controller.gd`'s header comment still
uses the legacy milestone numbering (it calls attacks "Milestone 5", stamina "Milestone 6",
dodge "Milestone 8") while the roadmap uses attacks=4, stamina=5, dodge=6. Cosmetic only;
left alone rather than churned, and re-recorded here so it is not mistaken for a new
discrepancy later.

---

## Notes On Dodge And I-Frames (Milestone 6) - Acceptance

Recorded 2026-09-12, after the user playtested the dodge in game.

STATUS: Milestone 6 is ACCEPTED. This entry records the acceptance and the two open tuning
items, so a later pass does not mistake either one for a defect or a regression.

Implementation files (all real systems, NOT cleanup candidates):

- `scripts/player/dodge_component.gd` - the dodge system.
- `scripts/player/player_controller.gd` - modified: dodge input, direction choice, burst
  movement, and dodge folded into commitment.
- `scripts/player/player_combat.gd` - modified: an attack is refused while a dodge is
  committed, enforced inside `try_start()` itself rather than only on the input path.
- `scripts/combat/hurtbox_component.gd` - modified: the i-frame refusal point, duck-typed
  so the hurtbox does not depend on the dodge system.
- `scenes/test_environment.tscn` - modified: `Player/Dodge` node added.

Diagnostics created (cleanup candidates; their status is UNCHANGED - see their own entries
above):

- `scripts/diagnostics/dodge_probe_debug.gd`
- `scenes/diagnostics/dodge_probe_debug.tscn`

TWO OPEN TUNING ITEMS - neither is a defect, and neither was acted on:

1. DODGE TRAVEL IS TOO LONG. Reported by the user directly after playing. This is an
   authored-value question (`dodge_speed` 7.5 m/s x `dodge_duration` 0.45 s = 3.375 m), not
   a logic error: measured travel matches the authored value exactly, so the system does
   precisely what it was told. The user explicitly asked that it NOT be retuned yet.
   Recorded for a later gameplay-feel pass.
2. I-FRAME TIMING FEEL IS UNJUDGED. The window is 0.05-0.30 s inside a 0.45 s dodge. The
   user could not judge the timing because NOTHING CAN CURRENTLY ATTACK THE PLAYER - no
   enemy attacks exist. This item is therefore BLOCKED on an attacker existing and cannot
   be closed by tuning alone. The measured refusal behaviour is correct; only the feel is
   unknown.

Deliberately NOT changed: no gameplay value was altered after acceptance, so the measured
acceptance evidence (travel 3.375 m, duration 0.450 s, every refusal cause counted, i-frame
refusals counted, RESULT: ALL CHECKS PASSED) still applies to the code as it stands.

---

## Candidate: scripts/diagnostics/parry_probe_debug.gd

Status: Candidate for manual deletion

Reason:
Milestone 7 (Parry) verification probe. Temporary diagnostic, not shipping code.

Replacement:
None. It is the only reproduction of the parry acceptance measurements (phase order and
total duration, stationarity under held movement input, a single stamina charge, atomic
refusal when unaffordable, the window's refused/applied split, every mutual-exclusion
refusal cause, and the physical input path).

Used By:
Nothing at runtime. Launched directly as a scene
(`res://scenes/diagnostics/parry_probe_debug.tscn`).

Safe To Delete:
Uncertain - yes once Milestone 7's numbers are no longer being re-verified. Prefer keeping
it until the parry has been human-playtested and accepted.

Date Flagged:
2026-09-12

Notes:
Written this pass, modelled directly on `dodge_probe_debug.gd`. Its summary travel line is
captured into `_measured_travel` at evaluation time on purpose, so it cannot repeat the
dodge probe's stale-accumulator defect where the summary contradicted its own passing
assertion. For a stationary parry the correct measured travel is 0.000 m, and the probe
asserts it (<= 0.05 m), so the summary and the assertion agree.

---

## Candidate: scenes/diagnostics/parry_probe_debug.tscn

Status: Candidate for manual deletion

Reason:
Scene that runs `parry_probe_debug.gd` against `res://main.tscn`. Temporary diagnostic.

Replacement:
None.

Used By:
Nothing. Launched manually to verify Milestone 7.

Safe To Delete:
Uncertain - delete together with `parry_probe_debug.gd`, never separately.

Date Flagged:
2026-09-12

Notes:
Same shape as every other probe scene in this project: root Node3D, an instance of
`res://main.tscn` named "Main", and a "Probe" node carrying the script.

---

## Notes On Milestone 7 (Parry) - Found Already Implemented

Recorded 2026-09-12.

Milestone 7 was approved by the user. Architecture inspection BEFORE any write found the
parry already fully implemented and wired:

Files that ARE the parry system (all live systems, NOT cleanup candidates):

- `res://scripts/player/parry_component.gd` - ParryComponent. Three phases (STARTUP /
  WINDOW / RECOVERY), authored 0.08 / 0.18 / 0.34 s, stamina cost 20, per-cause refusal
  counters, and a `parry_finished(landed)` signal sourced from the hurtbox's refusal.
- `res://scripts/player/player_controller.gd` - `_read_parry()` consumes the press, and
  `_is_committed()` includes a committed parry so movement input is ignored for its whole
  duration.
- `res://scripts/player/player_combat.gd` - a committed parry refuses an attack inside
  `try_start()` itself, counted as `attacks_refused_while_parrying`.
- `res://scripts/player/dodge_component.gd` - a committed parry refuses a dodge inside
  `try_start()`, counted as `dodges_refused_while_parrying`.
- `res://scripts/combat/hurtbox_component.gd` - `is_parry_window_open()` duck-typed check
  ahead of the i-frame check, counted as `refusals_by_parry` and emitted as
  `damage_refused_by_parry`.
- `res://scenes/test_environment.tscn` - `Player/Parry` node carrying the component.

Consequence: NO gameplay code needed to change for M7. The only genuinely missing artifact
was the dedicated verification probe, which was created this pass.

Files CREATED this pass:

- `res://scripts/diagnostics/parry_probe_debug.gd` - diagnostic, cleanup candidate (entry above).
- `res://scenes/diagnostics/parry_probe_debug.tscn` - diagnostic, cleanup candidate (entry above).

Files MODIFIED this pass (documentation only - NO gameplay file was touched):

- `res://.summer/plans/CASCADIA_MILESTONE_ROADMAP.md`
- `res://CASCADIA_DELETION_MANIFEST.md`

Documentation discrepancy found and repaired:

The previous pass's roadmap HEADER promised "Section 8C records the M7 architecture and the
measured results" and added a Milestone 7 table row, but SECTION 8C DID NOT EXIST and
section 11A still read "NOT SELECTED (candidate recorded, NOT APPROVED)". Section 8C was
written this pass and 11A was resolved. A roadmap that references a section it does not have
is worse than one that omits it, because it is trusted.

Process note, THIRD occurrence - a write reported as done that was not on disk:

The first `writeFile` for `parry_probe_debug.gd` returned a receipt reading `result=returned`
(not `succeeded`) and the file did NOT exist afterwards: `glob **/*parry*` returned only
`parry_component.gd`, and `state:script-errors` on the probe path returned "file not found".
The scene file was missing the same way, and the manifest append written after it also failed
to land in that pass. Re-issuing each write produced a real sha256 and the file was then
present and clean.

This is the same shape as:
- "Process Note: Reported Writes That Were Not On Disk" (Milestone 3), and
- the SECOND occurrence recorded under "Notes On Milestone 6 (Dodge And I-Frames)".

Lesson, now confirmed three times: a write receipt that is not `succeeded` WITH a sha256 is
NOT evidence that the file exists or that the edit landed. Verify with glob or a read before
relying on it.

---

## Candidate: scripts/combat/enemy_attacker.gd

Status: NOT a cleanup candidate - real system.

Reason:
Milestone 8 (Single attacking test enemy). The smallest real attacker that makes Cascadia's
defensive mechanics human-testable: one committed windup -> active -> recovery swing that
delivers damage through the existing HitboxComponent -> HurtboxComponent -> HealthComponent
chain.

Replacement:
None. Deleting it removes the only attacker in the project and re-blocks M6's i-frame feel item
and M7's parry playtest.

Used By:
`scenes/actors/test_attacker.tscn` (its `Attacker` node), instanced in
`scenes/test_environment.tscn` as `TestAttacker`.

Safe To Delete:
No - live system, not a candidate.

Date Flagged:
2026-09-12 (recorded for completeness, NOT flagged for deletion)

Notes:
Deliberately NOT PlayerCombat. The player's state machine reads player input through
CascadiaInput, and an enemy must never read player input. This reuses the three-phase SHAPE and
the AttackDefinition payload rather than the owner. It adds no fourth committed action, so the
arbiter trigger recorded in roadmap 8C.8 is NOT reached.

---

## Candidate: scenes/actors/test_attacker.tscn

Status: NOT a cleanup candidate - real system.

Reason:
Milestone 8. The attacking test actor: CharacterBody3D on GameLayers.ACTOR, with Health,
Hurtbox, an AttackHitbox on GameLayers.HITBOX, a Telegraph MeshInstance3D, and the Attacker
component.

Replacement:
None.

Used By:
Instanced in `res://scenes/test_environment.tscn` as `TestAttacker` at (0, 0, 5).

Safe To Delete:
No - live system.

Date Flagged:
2026-09-12 (recorded for completeness, NOT flagged for deletion)

---

## Candidate: scripts/diagnostics/enemy_attack_probe_debug.gd

Status: Candidate for manual deletion

Reason:
Milestone 8 verification probe. Temporary diagnostic, not shipping code.

Replacement:
None. It is the only reproduction of the M8 acceptance measurements (phase order, phase
durations, window and telegraph discipline, undefended damage, parry refusal, i-frame refusal,
the range gate and auto_attack).

Used By:
Nothing at runtime. Launched directly as a scene
(`res://scenes/diagnostics/enemy_attack_probe_debug.tscn`). Deleting it removes the only
automated evidence for Milestone 8's measured claims.

Safe To Delete:
Uncertain - yes once Milestone 8's numbers are no longer being re-verified.

Date Flagged:
2026-09-12

Notes:
Contains a real defect fix made this pass: the probe originally started the attack in the same
frame it repositioned the player, so the attacker still faced its OLD position and the first
scenario recorded 0 damage. Recorded here because a probe that contradicts the gameplay it
measures is worse than no probe - the same class of defect as the dodge probe's stale summary
line recorded above.

---

## Candidate: scenes/diagnostics/enemy_attack_probe_debug.tscn

Status: Candidate for manual deletion

Reason:
Scene that runs `enemy_attack_probe_debug.gd` against `res://main.tscn`. Temporary diagnostic.

Replacement:
None.

Used By:
Nothing. Launched manually to verify Milestone 8.

Safe To Delete:
Uncertain - delete together with `enemy_attack_probe_debug.gd`, never separately.

Date Flagged:
2026-09-12

---

## Notes On Milestone 8 (Single Attacking Test Enemy)

Recorded 2026-09-12.

Files CREATED this milestone:

- `res://scripts/combat/enemy_attacker.gd` - a REAL SYSTEM, not a cleanup candidate.
- `res://scenes/actors/test_attacker.tscn` - a REAL SYSTEM, not a cleanup candidate.
- `res://scripts/diagnostics/enemy_attack_probe_debug.gd` - diagnostic, cleanup candidate (entry above).
- `res://scenes/diagnostics/enemy_attack_probe_debug.tscn` - diagnostic, cleanup candidate (entry above).

Files MODIFIED this milestone (all live systems):

- `res://scenes/test_environment.tscn` - the `TestAttacker` instance added at (0, 0, 5), and the
  Player given the `player_actor` group tag so the attacker resolves a target by group.
- `res://scripts/diagnostics/dodge_probe_debug.gd`, `attack_probe_debug.gd`,
  `damage_probe_debug.gd`, `actor_probe_debug.gd`, `stamina_probe_debug.gd`,
  `parry_probe_debug.gd` - each gained an ambient-attacker stand-down (5 lines each).

CROSS-SYSTEM DEFECT, caught by RE-RUNNING the regressions rather than carrying them forward:

Adding a live attacker to the shared arena broke the DODGE probe. Its i-frame test brings the
player inside the attacker's engage_range, so a real 20-damage hit landed mid-probe and the
health accounting failed while every i-frame check itself still passed. This is exactly the
class of defect a "no regression" claim made from memory would have missed: the arena is shared
state, so every existing probe HAD to be re-run after the arena changed.

THE FIX, and a trap encountered applying it: the stand-down is group-based plus a duck-typed
`auto_attack` membership test (`get_nodes_in_group(&"enemy_attacker")`), NOT a call to a static
helper on EnemyAttacker. Referencing a newly added member of that class from another script
produced `Parse Error: Static function "stand_down_all()" not found in base "EnemyAttacker"`
even though the class itself resolved - the same class-cache staleness documented above under
"Notes On New Script Folders And The Class Cache". The group-and-property approach depends on
no new symbol and works immediately.

WRITE TIMEOUTS, fourth and fifth occurrences of the recurring shape: two `writeFile` calls in
this milestone returned "the editor operation did not return a terminal receipt before its wait
deadline" rather than a sha256, and the files did NOT exist afterwards. Both were re-issued and
landed. Same rule as the three previous occurrences. A contributing factor to the retry loop
this caused was payload size - the probe was attempted at 541 and 451 lines in one call, while
the version that landed first time was 424 lines, so keeping a single write payload moderate is
worth doing for its own sake.

Also observed and deliberately NOT changed: the arena ramp label discrepancy and the legacy
milestone numbering in code comments (both recorded above) remain cosmetic and untouched.

---

## Candidate: scripts/diagnostics/dodge_input_probe_debug.gd

Status: Candidate for manual deletion

Reason:
Sprint / Dodge / Backstep input pass verification probe. Temporary diagnostic, not shipping code.

Replacement:
None. It is the only automated evidence for the shared tap/hold resolution, the
directional-versus-backstep selection, the camera-relative facing classification, the halved
dodge travel and the backstep travel.

Used By:
Nothing at runtime. It is launched directly as a scene
(`res://scenes/diagnostics/dodge_input_probe_debug.tscn`). Deleting it removes the only
automated evidence for this pass's measured claims.

Safe To Delete:
Uncertain - yes once this pass's numbers are no longer being re-verified. Prefer keeping it
while dodge travel is still an open feel question.

Date Flagged:
2026-09-12

Notes:
Four probe defects were found and fixed inside this file during the pass (see "Notes On The
Sprint / Dodge / Backstep Input Pass" below). The most instructive one: because the probe
never reset the stamina pool between phases, a REFUSED dodge reported the component's DEFAULT
kind/facing, and those defaults read as a plausible wrong answer rather than as a failure. The
probe now asserts that an evasion actually STARTED, so a refusal cannot masquerade as a result.

---

## Candidate: scenes/diagnostics/dodge_input_probe_debug.tscn

Status: Candidate for manual deletion

Reason:
Scene that runs `dodge_input_probe_debug.gd` against `res://main.tscn`. Temporary diagnostic.

Replacement:
None.

Used By:
Nothing. Launched manually to verify the Sprint / Dodge / Backstep pass.

Safe To Delete:
Uncertain - delete together with `dodge_input_probe_debug.gd`, never separately.

Date Flagged:
2026-09-12

Notes:
Same shape as every other probe scene in this project: root Node3D, an instance of
`res://main.tscn` named "Main", and a "Probe" node carrying the script.

---

## Notes On The Sprint / Dodge / Backstep Input Pass

Recorded 2026-09-12.

Files MODIFIED (all live systems, none candidates):

- `res://scripts/input/cascadia_input.gd` - the shared tap/hold command resolver. Two sources
  (`mobility_button`, `sprint`) now advance through ONE `_advance_source()`, so keyboard and
  controller use one implementation and cannot drift apart. Also gained
  `command_sprint_tap_max()` / `command_sprint_hold_min()` so tooling and a future rebinding UI
  read the threshold instead of hardcoding it.
- `res://scripts/player/player_controller.gd` - `_read_dodge()` now decides the KIND and the
  FACING and passes both to the component; added `_camera_relative_facing()` and
  `_dodge_kind()`.
- `res://scripts/player/dodge_component.gd` - `Kind` and `Facing` enums, backstep values, and a
  3-argument `try_start(direction, kind, facing)`. `dodge_speed` halved 7.5 -> 3.75.
- `res://.summerrules` - an explicit AMENDMENT to the recorded keyboard input rule, because this
  pass deliberately reverses a decision that was previously recorded as intentional.

Files CREATED (cleanup candidates, entries above):

- `res://scripts/diagnostics/dodge_input_probe_debug.gd`
- `res://scenes/diagnostics/dodge_input_probe_debug.tscn`

THREE SPEC PREMISES DID NOT MATCH THE PROJECT, and were raised with the user BEFORE any edit
rather than silently obeyed or silently skipped:

1. The recorded project rule in `.summerrules` deliberately kept keyboard Sprint and Dodge on
   separate keys. Sharing Left Shift amends a deliberate decision, so it needed the user's call.
2. There is NO lock-on system. `lock_on` is a reserved semantic action and
   `CascadiaInput.consume_lock_on()` exists with NO consumer; there is no target, no lock
   facing, and `PlayerController` explicitly lists lock-on facing as not its job. The requested
   "dodge direction stays relative to the locked-on target" therefore had nothing to be
   relative to.
3. There is NO animation system anywhere in the project. A project-wide search for
   AnimationPlayer, AnimationTree, AnimationNode, AnimatedSprite and SpriteFrames returned ZERO
   matches; actors are capsule primitives and animation is a deferred milestone. The requested
   directional ANIMATION selection could not be implemented, only exposed as gameplay state.

RESOLUTION, per the user's answers: keep Space as a dedicated dodge alongside the new shared
Left Shift; do NOT implement or assume lock-on in this pass; resolve and expose the dodge kind
and facing as gameplay state for a future animation adapter, and leave animation to its own
milestone.

WHY THE DODGE WAS SHORTENED BY SPEED AND NOT DURATION: `dodge_speed` 7.5 -> 3.75 with
`dodge_duration` left at 0.45 s. The i-frame window is authored in ABSOLUTE seconds inside the
dodge (0.05-0.30 s), so cutting the duration would have moved the window and quietly weakened
the defence the user asked to preserve. Halving the speed halves the distance and leaves every
timing untouched. Result: 1.688 m, exactly half of 3.375 m.

WHY FACING IS CAMERA-RELATIVE: the controller's `_apply_facing()` turns the body toward its own
velocity every frame, so classifying the dodge against the BODY would collapse a sustained
left-strafe into FORWARD as soon as the body caught up with the input. Classifying against the
camera keeps W/A/S/D stable, matches `_read_wish_direction()`'s existing basis, and is the exact
basis a future lock-on system would swap out. The values are named semantically
(FORWARD/BACKWARD/LEFT/RIGHT) rather than by axis precisely so that swap is possible.

THE RECURRING CLASS-CACHE ARTIFACT, now with DIRECT RUNTIME PROOF: the script-error panel
reported 9 errors in `open_script_buffers` claiming `DodgeComponent` has no `Kind`/`Facing` and
that `try_start` takes at most 1 argument. In the SAME run, the probe successfully read
DIRECTIONAL / BACKSTEP / FORWARD / RIGHT / BACKWARD from the live component and classified
3-argument `try_start()` calls correctly. Those members exist only in the new code, so the panel
was demonstrably analysing a stale cached class while the engine used the real one. This is the
strongest evidence yet for the standing rule in this manifest and roadmap 12.1: judge the class
cache by a RUN, never by the open-tab linter.

FOUR PROBE DEFECTS, none in gameplay - recorded because each one could have produced a false
result:

1. A probe assertion claimed a neutral tap should be DIRECTIONAL. That contradicts the spec;
   BACKSTEP is correct. A wrong assertion is a wrong spec, not a found bug.
2. The probe never reset the stamina pool between phases. After AC1's tap and AC2's three
   dodges the pool was empty, so AC3's dodge was LEGITIMATELY refused - and a refused dodge
   leaves the component reporting its DEFAULT kind/facing, which read as a plausible if wrong
   answer instead of as a failure. Fixed by resetting the pool per phase AND asserting the
   evasion actually started.
3. Input was injected across a 2-frame window while the input layer polls on idle frames, so no
   poll sometimes landed inside it. This made WHICH checks failed differ between runs - the
   signature of a race, not a logic fault.
4. Direction assertions were measured against the arena enemy's position, which tests
   architecture rather than the requested behaviour. Replaced with camera-basis comparisons,
   since there is no lock-on for direction to be relative to. Separately, the backstep phase set
   `rotation.y` but left `velocity` coasting, so `_apply_facing()` re-oriented the body before
   the tap and the check measured the probe's own leftover motion (dot 0.10).

A probe that can turn a refusal into a plausible-looking wrong answer is worse than no probe,
because it trains the reader to trust a number that was never measured.

---

## Notes On The End-of-Session Review (2026-09-12)

Documentation-only pass. NO gameplay file was modified.

WHAT THE REVIEW WAS ASKED TO CHECK, AND WHAT IT FOUND: the premise was that "current movement
code may still be allowing normal movement to overwrite or compete with Dodge movement". Read
from disk, that is only PARTLY true, and the distinction matters because two of the three
candidates are real and one is not:

1. VELOCITY - ALREADY CORRECT. `PlayerController._apply_horizontal()` tests
   `dodge.is_dodging()` FIRST, assigns `velocity.x/z` from `dodge.velocity()`, and returns
   before the acceleration branch. There is no blend and nothing to fix.
   `_read_wish_direction()` additionally forces `_wish_direction` to ZERO while committed, so
   sprint speed and sprint drain are both inert during an evasion.
2. ORIENTATION - REAL INTEGRATION DEFECT. `_apply_facing()` has no dodge guard. It derives
   `target_yaw` from CURRENT horizontal velocity every frame, and during an evasion that
   velocity IS the dodge burst - so a BACKSTEP drives the yaw target to the reverse of the
   actor's facing and the body turns around mid-backstep. The locked gameplay facing is
   currently NOT what orients the body.
3. POSITION - REAL INTEGRATION DEFECT, lower severity. `_resolve_step_up()` has no dodge
   guard and runs after `move_and_slide()` on obstructed frames. A dodge INTO a step can set
   `global_position` by `step_probe_reach` and re-run `move_and_slide()` plus
   `_settle_after_step()`, adding displacement the evasion never authorised.

Recorded as roadmap section 8F (a bounded, NOT-STARTED future pass) and as a Movement
Authority rule in `.summerrules`. Nothing was implemented, by instruction.

WHY RECORDED RATHER THAN FIXED: the user scoped this pass to review, planning and diagnostics
only, and explicitly deferred the fix. The finding is recorded so the next pass starts from
the real mechanism instead of re-reading the code, and so the already-correct velocity branch
is not "fixed" by mistake.

ALSO CORRECTED HERE: roadmap section 9's keyboard binding table had gone STALE - it still
described Left Shift and Space as purely separate keys, which the 8E input pass reversed. A
roadmap that contradicts the code is worse than one that omits it.

NO NEW FILES were created by this review, so no new cleanup candidates were added.

---

## Notes On The Full-Loop Human Playtest (2026-09-12)

Recorded after the user played the assembled prototype end to end. NO FILE WAS MODIFIED to make
this happen - it is a record of what the existing build does in the hand. Full detail is in
roadmap section 8G. This entry exists because the playtest changed the project's state of
knowledge, which is exactly what this manifest is meant to capture.

WHAT IT CONFIRMED: the loop runs - move, sprint, spend stamina, attack, damage an enemy, be
attacked, parry, dodge/backstep, exhaust stamina. Camera, movement, diagnostics (F1 hides the
overlay), combat phase readout, light/heavy attacks, damage both ways, stamina drain and
depletion, stamina-gated attacks and dodges, enemy attack damage, and step-up traversal to 42 cm
are all confirmed in play. This is the first time any of these has been judged by a person
rather than by a probe.

WHAT IT FOUND - two items that matter, one of which is a genuine BLOCKER for further testing:

1. **NO DEATH / RESET CIRCUIT (BLOCKER).** Health reaches zero and stays at zero. Nothing
   respawns, resets or restores it, so once the player dies, combat cannot be tested again
   without restarting the run. `HealthComponent` already emits `died`; nothing consumes it. This
   is not a defect in what was built - nothing ever scoped a death circuit - but it now blocks
   the next round of testing, which makes it the highest-priority next task.
2. **BACKSTEP ORIENTATION (CONFIRMED INTEGRATION DEFECT).** Recorded in the previous pass as a
   STATIC finding in roadmap 8F.2, with the honest caveat that it was inferred from reading
   `_apply_facing()` and had not been observed. The user then reported, WITHOUT having read that
   section, that the backstep "seems to lose or alter the intended facing orientation" and that
   repeating it makes the effect more obvious. Two independent derivations of the same defect -
   one from the code, one from the hand - is the strongest confirmation this project has
   produced. The user adds a practical point the code reading could not: the capsule has NO
   front-facing marker, so the change is invisible to the eye and the FIX MUST include a legible
   facing indicator, not just the guard.

A third item, NO ANIMATION PRESENTATION, is recorded as the current presentation boundary rather
than a defect: parry timing, attack direction, hit stop and facing are all genuinely harder to
judge through unmarked capsules, and the user says so explicitly.

ONE DISCREPANCY TO CONFIRM, deliberately NOT acted on: the user reports that an attack costs 20
stamina, while `PlayerCombat` authors `light_stamina_cost = 18` and `heavy_stamina_cost = 32`.
The reported dodge cost of 22 matches the code exactly, so this is likely either a rounded
recollection or something the overlay displays differently. Recorded so the next pass CHECKS the
displayed value before touching a balance number.

STILL OPEN AFTER PLAY, in the user's own words: parry timing, enemy windup readability, dodge
distance and backstep feel, attack commitment, hit stop, damage-window readability, and whether
the stamina costs create the intended pressure. The distinction the user draws is the useful one:
"the mechanics function" is now established, "the mechanics feel like Lies of P" is not.

NEW DEFERRED ITEMS recorded from this playtest: the death/reset circuit, backstep facing
preservation plus a facing indicator, SOCD-style input arbitration/cleanup, and a review of the
secondary / click action bindings.

DOCUMENTATION DEFECT FOUND AND FIXED IN THIS PASS, and it is the same class as a previously
recorded one: section 0's table correctly recorded the playtest and cited "section 8G", while
sections 8C, 8D and 8E still carried headers reading "AWAITING HUMAN PLAYTEST" and 8D still said
"NOT yet human-played, so NOT accepted". A file that cites its own new section while three older
headers contradict it is the stale-roadmap-language problem in miniature - the same shape as the
earlier pass where the header promised a "section 8C" that did not exist. All four stale headers
and one stale deferred-list line were corrected. Section 16's history log was deliberately LEFT
ALONE: it is append-only and the superseded statements in it were true when written.

SIXTH RECURRENCE of the write-failure shape, and the first one caught by VERIFYING RATHER THAN
TRUSTING: five `strReplace` calls to the roadmap returned success-shaped receipts, but a
follow-up grep showed every one of the target strings still present - none of the five edits had
applied. Re-issued individually, all five then landed with distinct real sha256 values, and a
second grep returned zero matches for all three stale strings. The rule recorded five times
before this ("a receipt that is not `succeeded` WITH a sha256 is not evidence the edit landed")
did not cover this case, because these receipts looked successful. The stronger rule is the one
this pass actually used: verify the EDIT by reading back the changed text, not the receipt, and
do not trust a successful-looking receipt for a documentation edit any more than for a file
write.

---

## DEATH / RESET CIRCUIT PASS - NEW FILES AND RECORDED CHANGES (2026-09-12)

Recorded at the moment of the work, per the file-hygiene rule. Recording is the action;
deletion stays manual.

### New gameplay file (NOT a deletion candidate)

- `scripts/player/death_component.gd` (`class_name DeathComponent`). Gameplay, not diagnostic:
  it owns the death state and the single-arena reset and is the consumer of the existing
  `HealthComponent.died` signal. Wired as the `Death` node under `TestEnvironment/Player` in
  `scenes/test_environment.tscn`, with `death_delay = 1.5` s as the one timing knob.

### New diagnostic files (cleanup candidates, delete with their scene)

- `scripts/diagnostics/death_presentation_debug.gd` - temporary death presentation
  (`YOU DIED` panel, reset countdown, restart-key hint read from the live InputMap binding, plus a
  remembered and exactly restored death pose on the player capsule). Instanced as the
  `DeathPresentation` node in `main.tscn`. Placeholder presentation, NOT animation; the project
  still has no animation system.
- `scripts/diagnostics/death_probe_debug.gd` - deterministic probe for the whole circuit.
- `scenes/diagnostics/death_probe_debug.tscn` - the probe's standalone entry scene.

### Recorded changes to existing files

- `scripts/core/game_actions.gd`: added `RESTART := &"restart"`, added to `BUFFERED_ACTIONS` and
  to `GROUPS` under `SYSTEM`.
- `project.godot`: new input action `restart` bound to physical `R`.
- `scripts/input/cascadia_input.gd`: added `consume_restart()`.
- `scripts/player/player_controller.gd`: added a `Death` export group, `_is_dead()`, and a single
  dead gate at the top of `_physics_process()` that suppresses all input while dead while still
  applying gravity.
- `scripts/player/player_combat.gd`: added `death_path`, `_is_death_blocked()`, the refusal in
  `try_start()`, and `cancel_current_action()` (used by the death circuit only).
- `scenes/test_environment.tscn`: added the `Death` node under `Player` and the `12_death`
  ext_resource.
- `main.tscn`: added the `DeathPresentation` CanvasLayer and its ext_resource.
- `scripts/diagnostics/dodge_input_probe_debug.gd` and `scripts/diagnostics/dodge_probe_debug.gd`
  and `scripts/diagnostics/parry_probe_debug.gd` and `scripts/diagnostics/stamina_probe_debug.gd`
  and `scripts/diagnostics/enemy_attack_probe_debug.gd`: NOT modified this pass.

### Recurring editor registration issue, re-confirmed this pass

The stale open-tab analysis reported `Cannot find member "RESTART" in base "GameActions"` in
`scripts/input/cascadia_input.gd` (`scope: open_script_buffers`) even though `RESTART` is declared
in `game_actions.gd` on disk AND was resolved successfully at runtime by the probe (the injected
restart action drove an input-driven reset). Same class as the long-recorded `GameActions not
declared` artifact: stale analysis of open script buffers, not a runtime failure.

---

## ENEMY DEATH AND PERSISTENCE PASS - NEW FILES AND RECORDED CHANGES (2026-09-12)

Recorded at the moment of the work, per the file-hygiene rule. Recording is the action; deletion
stays manual.

### New gameplay file (NOT a deletion candidate)

- `scripts/combat/enemy_death_component.gd` (`class_name EnemyDeathComponent`). Gameplay, not
  diagnostic: it owns one enemy's DEFEATED state, consumes the existing `HealthComponent.died`
  signal, asks the attacker to cancel any committed attack, and is the single authority the attack
  state machine asks before it acts. Wired as the `Death` node under `TestEnvironment/TestAttacker`
  in `scenes/actors/test_attacker.tscn`. Deliberately a DIFFERENT class from the player's
  `death_component.gd`: that one owns a full arena reset, which an enemy death must not perform.

### New diagnostic files (cleanup candidates, delete with their scene)

- `scripts/diagnostics/enemy_death_presentation_debug.gd` - temporary defeat presentation (a
  `DEFEATED` Label3D plus a remembered and exactly restored tipped/sunk/tinted pose on the enemy
  capsule). Instanced as the `DeathPresentation` node in `scenes/actors/test_attacker.tscn`.
  Placeholder presentation, NOT animation; the project still has no animation system.
- `scripts/diagnostics/enemy_death_probe_debug.gd` - deterministic probe for the enemy defeat and
  its persistence across the player's death and reset.
- `scenes/diagnostics/enemy_death_probe_debug.tscn` - the probe's standalone entry scene.

### Recorded changes to existing files

- `scripts/combat/enemy_attacker.gd`: added `death_path`, the `_death` reference, the
  `attacks_refused_while_defeated` counter, `_is_defeated()` / `_get_death()`, a defeat gate at the
  top of `_physics_process()` and inside `try_start()`, and `cancel_attack()` (used by the death
  circuit only). No attack timing, damage, engage range or cadence value was changed.
- `scenes/actors/test_attacker.tscn`: added the `Death` and `DeathPresentation` nodes and their two
  ext_resources (`load_steps` 12 -> 14). No transform, shape, material or collision layer changed.
- `CASCADIA_MILESTONE_ROADMAP.md`: new section 8I, a section 0 status row, an entry in section 13,
  two items in section 12.3, and the header block.
- `scripts/player/death_component.gd`, `scripts/diagnostics/death_probe_debug.gd` and
  `scenes/diagnostics/death_probe_debug.tscn`: NOT modified this pass (re-run only).

### Pre-existing defect recorded, NOT fixed by this pass

`grounding_probe_debug` fails one check on `TestAttacker` (float/sunk -0.020 against a 0.02
TOLERANCE) because the attacker's collision capsule is authored at y=0.92 while `DummyActor` uses
0.90, placing its lowest point exactly on the tolerance boundary where float rounding fails the
comparison. Those transforms are unchanged by this pass, and the fix would edit a combat actor's
authored collision, mesh and hurtbox heights, so it is recorded in roadmap 8I.8 and 12.3 for a
deliberate decision instead of being changed here.

### Recurring editor registration issue, re-confirmed this pass

The stale open-tab analysis reports `Cannot find member "RESTART" in base "GameActions"` in
`scripts/input/cascadia_input.gd` (`scope: open_script_buffers`) even though `RESTART` is declared in
`game_actions.gd` on disk and has been resolved at runtime by two separate probes. `enemy_attacker.gd`
showed the same shape for `_is_defeated()` and `cancel_attack()` before the probe forced a fresh
script load, after which both resolved cleanly. Same class as the long-recorded `GameActions not
declared` artifact: stale analysis of open script buffers, not a runtime failure.

---

## REUSABLE ACTOR DEATH CAPABILITY PASS - NEW FILES AND RECORDED CHANGES (2026-09-12)

Recorded at the moment of the work, per the file-hygiene rule. Recording is the action; deletion
stays manual.

### New diagnostic files (cleanup candidates, delete with their scene)

- `scripts/diagnostics/actor_death_probe_debug.gd` - deterministic probe for the REUSABLE death
  capability: the second mortal actor's defeat, the exactly-once guard, the post-death refusal, the
  damageable-but-immortal axis, the non-damageable axis, and the player's reset not reviving a
  defeated actor.
- `scenes/diagnostics/actor_death_probe_debug.tscn` - the probe's standalone entry scene. Instances
  `res://main.tscn`, the same convention every other probe uses.

### Recorded changes to existing files

- `scripts/combat/enemy_death_component.gd`: added the `mortal` policy export (+ `is_mortal()`), the
  `lethal_refusals` counter, and the mortality gate in `_on_died()`. No defeat timing changed.
- `scripts/combat/hurtbox_component.gd`: added the `damageable` policy export (+ `is_damageable()`),
  the `refusals_by_policy` counter, and the permanent-policy gate at the top of `receive_hit()`.
- `scripts/player/death_component.gd`: added the `resets_actors` policy export and the guard in
  `_reset_attackers()`.
- `scenes/dummy_actor.tscn`: added the `Death` node (`enemy_death_component.gd`) and a
  `DeathPresentation` node (the EXISTING `enemy_death_presentation_debug.gd`, reused unchanged), plus
  their two ext_resources; `load_steps` 7 -> 9. No transform, shape, material or collision layer was
  changed. The presentation was added because a second mortal actor whose defeat produced no visible
  change in the world would be a regression in readability, not a feature - and the adapter already
  existed and is state-read-only, so reusing it adds no new system.
- `.summer/plans/CASCADIA_MILESTONE_ROADMAP.md`: section 8J, a section 0 status row, 12.3 items, a
  section 13 entry, and changelog entries.

### Process note: a write receipt is not proof of file state

Two defects introduced during this pass were caught ONLY by re-reading the files from disk - not by
trusting write receipts, and not by the open-tab linter:

1. `enemy_death_component.gd` briefly held TWO `@export var mortal` declarations and two
   `lethal_refusals` counters.
2. `hurtbox_component.gd` briefly held THREE `damageable` exports and three `refusals_by_policy`
   counters.

Either would have been a hard parse failure had it survived. Both were removed after a disk read.
Recorded because this is a persistence-adjacent problem of the same family as the registration
entries above: several write receipts for these files came back explicitly marked as unverified
historical records rather than confirmed writes, and the open-tab linter then reported duplicate
definitions that did NOT exist on disk. The authoritative check for "did the bytes change" is a
disk read, not a success receipt and not the linter.

### Recurring editor registration issue, re-confirmed a THIRD time

The stale open-tab analysis reported parse failures in `enemy_death_component.gd` and
`hurtbox_component.gd` describing MULTIPLE definitions of `mortal`, `damageable`,
`lethal_refusals`, `refusals_by_policy` and `resets_actors`. Reading both files from disk showed
exactly ONE definition of each, `state:script-errors` returned 0 errors for every edited file, and
all ten probes ran clean. The duplicate-definition text described an intermediate edited state that
existed only inside the open script buffer, never on disk. Same class as the long-recorded
`GameActions not declared` and `Cannot find member "RESTART"` artifacts. The pattern is now
confirmed three times; judge the class cache by a RUN or a disk read, never by the open-tab linter.

---

## REUSABLE ACTOR DEATH - ACCEPTED (2026-09-12)

The user verified the DummyActor's death in the live game: it can be damaged, reaches 0/100, enters
the dead state, tips and darkens, displays DEFEATED, and does not interfere with the other actors.
The milestone is accepted and recorded as roadmap section 8J.12. No files changed by this
acceptance - it is a status recording only.

---

## REUSABLE ACTOR COMBAT READINESS PASS - NEW FILES AND RECORDED CHANGES (2026-09-12)

Recorded at the moment of the work, per the file-hygiene rule. Recording is the action; deletion
stays manual.

### New gameplay file (NOT a deletion candidate)

- `scripts/combat/combat_participant.gd` (`class_name CombatParticipant`). Gameplay, not diagnostic:
  it answers the combat-readiness questions about ONE actor (damageable, mortal, dead, defeated,
  attack-capable, targetable, can-act) and exposes a typed refusal REASON. Composable and per-actor.
  Wired as a direct child named "Participant" under `TestAttacker`, under `DummyActor`, and under
  `Player` in `scenes/test_environment.tscn`. It replaces no existing system and duplicates none:
  health and damage still belong to `HealthComponent`, mortality to `EnemyDeathComponent.mortal`,
  damageability to `HurtboxComponent.damageable`. This component only ANSWERS about them.

### New diagnostic files (cleanup candidates, delete with their scene)

- `scripts/diagnostics/actor_combat_readiness_probe_debug.gd` - deterministic probe for target
  validity, per-cause refusal counting, invalid/freed-target safety, and the reset boundary.
- `scenes/diagnostics/actor_combat_readiness_probe_debug.tscn` - the probe's standalone entry scene.

### Recorded changes to existing files

- `scripts/combat/enemy_attacker.gd`: added `has_valid_target()`, `target_refusal_reason()`, the
  by-cause target-refusal counters (`target_refusals_dead` / `_defeated` / `_missing` /
  `_non_participant` / `_not_targetable`), the `attacks_refused_no_target` counter, the
  `_auto_start_refusal()` recorder with its `_last_auto_refusal` cause tracker, a validity gate in
  `is_target_in_range()` and `try_start()`, and `_get_valid_target()` for facing. NO attack timing,
  damage, engage range or cadence value was changed - measured unchanged at 0.58/0.13/0.70.
- `scripts/diagnostics/combat_debug_overlay.gd`: each damageable-actor row now appends the actor's
  participant state (for example `[alive attack-capable targetable]`, `[no participant]`), so the
  readiness vocabulary is legible in the running game and not only in probe output.
- `scenes/actors/test_attacker.tscn`: added the `Participant` node and its ext_resource;
  `attack_path` set to `../Attacker`.
- `scenes/dummy_actor.tscn`: added the `Participant` node and its ext_resource.
- `scenes/test_environment.tscn`: added the `Participant` node under `Player` and its ext_resource.
- `scripts/combat/combat_participant.gd`, `scripts/combat/enemy_death_component.gd`,
  `scripts/combat/hurtbox_component.gd`, `scripts/player/death_component.gd`,
  `scripts/diagnostics/actor_death_probe_debug.gd`: NOT functionally modified by this pass beyond
  the earlier 8J work; re-run only.

### Process defect recorded, found and fixed this pass

The first version of the attacker's auto-attack refusal recorder used a bare boolean, which
silently swallowed a refusal whose CAUSE changed - a spell that started OUT_OF_RANGE and became
DEAD (exactly what happens when a target dies while the attacker watches it) was never recorded, so
the dead-target counter could not move and the check it existed for was not actually being measured.
Replaced with a last-CAUSE tracker. Two earlier intermediate versions also briefly declared the flag
twice and called a helper that did not exist; both were caught by `state:script-errors` and by
reading the file from disk before any measurement was trusted. Note the distinction: the
duplicate-DECLARATION report was the stale open-buffer artifact described above, but the
missing-HELPER error was REAL and would have crashed the loop had it not been fixed.

### Recurring editor registration issue, re-confirmed a fourth time

The open-tab analysis again reported duplicate declarations (`_auto_refusal_recorded` twice) that a
disk read proved did not exist in the final file, while separately reporting a genuinely missing
helper in the same session. The two must be told apart by a disk read or a RUN, never by the linter
alone - the linter is right about missing symbols often enough that dismissing it outright would
also be wrong.

---

## DEFEAT COVERAGE PASS - NEW FILES AND RECORDED CHANGES (2026-09-12)

Recorded at the moment of the work, per the file-hygiene rule. Recording is the action; deletion
stays manual.

### The defect this pass exists for

A damageable enemy that reached zero health did NOT update to a defeated state. The root cause was
not a broken death system - the system worked, and `EnemyDeathComponent` had already been proven
actor by actor in 8I and 8J. The root cause was that **NO PROBE ASSERTED THE PROPERTY ACROSS THE
ARENA.** Every existing probe inspected only the actors it was told about BY NAME, so an actor with
no defeat path could reach zero health and silently do nothing while every probe in the suite still
reported ALL CHECKS PASSED. `damage_probe_debug` reports `died=1` because `HealthComponent` EMITS
`died`; whether anything CONSUMES that signal was never asserted anywhere. That is the missing test,
and it is why the hole survived 8I, 8J and 8K.

### New diagnostic files (cleanup candidates, delete with their scene)

- `scripts/diagnostics/defeat_coverage_probe_debug.gd` - the missing test. ENUMERATES the
  `damageable` group rather than using a name list, kills every non-player enemy through the real
  `HurtboxComponent.receive_hit` -> `HealthComponent.apply_damage` chain, then asserts per enemy:
  zero health, `mortal`, `is_defeated()` true, `defeats == 1`, a defeat presentation present, and
  that presentation `is_showing()`. A newly added enemy is covered the moment it exists in the
  scene. The player is excluded BY ARCHETYPE (its Death owns `resets_actors`), not by name.
- `scenes/diagnostics/defeat_coverage_probe_debug.tscn` - the probe's standalone entry scene.

### Recorded changes to existing files

- `scenes/test_environment.tscn`: TargetA, TargetB and TargetC each gained a `Death` node using the
  EXISTING `EnemyDeathComponent` with `mortal = true` (their only non-default value), plus an
  existing `enemy_death_presentation_debug.gd` adapter as `DeathPresentation`. This is the minimal
  correction: no new death system, no new component class, and no change to any transform, shape,
  material or collision layer.
- `scripts/diagnostics/actor_combat_readiness_probe_debug.gd`: the unkillable-archetype check no
  longer uses a scene fixture as its subject (every arena actor is now a mortal enemy or the
  player). It builds its subject AT RUNTIME - damageable, `mortal = false`, never defeated - so the
  unkillable archetype is still proven to exist and behave as declared.
- `CASCADIA_MILESTONE_ROADMAP.md`: section 8K.11 marked SUPERSEDED with its wrong conclusion
  retracted; new section 8K.12 records the defect, the cause, the fix and the measured results;
  section 0 status row and the changelog updated.

### Not changed, deliberately

- No combat value, timing, stamina cost, dodge or parry timing, or hitbox/hurtbox dimension.
- No new actor framework, AI, navigation, faction, target-selection, checkpoint or save/load system.

### RETRACTED CONCLUSION, recorded so it is not repeated

The 8K.11 audit declared the three static targets "intentional non-participants" and deliberately
changed nothing, on the reading that `[no participant]` was a correct statement about scenery rather
than a missing wire. **That reading was wrong.** It treated the ABSENCE of a defeat component as a
design choice when nothing anywhere stated that intent, and it left an enemy-shaped hole in the
death path. The pass asked "is this actor explained?" instead of "does EVERY damageable actor reach
a defeated state?", and only the second question finds this class of bug. 8K.11 is superseded.

### Process note

Repeated `callEditorState state:diagnostics` calls returned results flagged as superseded by an
unrelated later call, and several write receipts were flagged as unverified historical records.
Every result published for this pass was therefore taken from a fresh run whose console output was
read directly after an explicit stop/start, and the scene conclusions came from reading
`scenes/test_environment.tscn` on disk rather than from any overlay text.

---

## POST-ACCEPTANCE PLUMBING AUDIT - THE STATIC TARGETS (2026-09-12)

No files created, no files changed. This entry records an AUDIT RESULT, because the honest answer
to "is this plumbing incomplete?" is that nothing needed correcting and that conclusion is worth
being able to find again without re-reading the scenes.

### Question raised by the user after accepting 8K

The combat readout shows `TargetA` / `TargetB` / `TargetC` as `[no participant]` while `DummyActor`
and `TestAttacker` show participant states. Intended design, or incomplete wiring?

### Answer: intentional non-participants. NO correction made.

Read from disk (`scenes/test_environment.tscn`, lines 327-395): `TargetA`, `TargetB` and `TargetC`
are `StaticBody3D` bodies carrying `Mesh`, `Collision`, `Health`, `Hurtbox` and `Shape`, and NOTHING
else - no script on the body, no `Attacker`, no defeat component, no `Participant`, and none of the
player components. They are placed by direct transform with no gravity or floor logic.

This matches the role already recorded before 8K existed (roadmap 8J.10d): damageable static test
fixtures, not actors in a fight. `target_sweep_debug` uses them to prove the Hitbox -> Hurtbox ->
Health chain reaches MULTIPLE actors; `grounding_probe_debug` uses them as static placement fixtures.
Neither role requires acting, being targeted, dying or being reset.

### Why this is not a gap

`CombatParticipant.target_refusal()` carries an explicit UNWIRED FALLBACK: for an actor with no
participant component it returns the pre-8K health-based answer (`NONE` while alive, `DEAD` once
health reaches zero). An unwired actor is therefore handled BY DESIGN, not by accident, and the
readiness probe measures that path directly - it asserts `find_for(actor) == null` TOGETHER WITH
`refusal == Refusal.NONE` on a component-less actor.

Adding a `CombatParticipant` to the fixtures was deliberately NOT done: it would change behaviour
with no requirement behind it (declaring them `can_be_targeted = false` would flip
`is_usable_target(TargetA)` from true to false today), and it would flatten three different actor
types into one implementation purely so the overlay labels matched.

### Re-verified after the audit (no source change)

`actor_combat_readiness_probe_debug` re-run: RESULT: ALL CHECKS PASSED. All probes re-run fresh.
`main.tscn` booted with 0 runtime errors. Rendered frame read directly: the readout reported
`DummyActor ... [alive targetable]`, `TestAttacker ... [alive attack-capable targetable]`,
`TargetA` / `TargetB` / `TargetC` `[no participant]`, all at 100/100 - which is the intended
architecture, correctly labelled.

### Recorded concern, NOT a defect

The same wording that prompted this audit will prompt it again: `[no participant]` reads like a
warning when it is in fact a correct statement about scenery. If this becomes a recurring source of
doubt, a future tooling pass could distinguish "no participant by design" from "no participant by
omission" - but that needs a statement of intent that does not exist yet, so nothing was invented.

---

## Milestone 9 - Soulslike Credit Economy (2026-09-12)

New gameplay file (NOT a cleanup candidate):
- `scripts/economy/credit_ledger.gd` (`class_name CreditLedger`). It owns the CARRIED balance and the
  single place an enemy defeat becomes a reward. Carried / stored / spent / persistent are kept apart
  and only CARRIED exists. Wired into `main.tscn` as one node under the game root.

New diagnostic files (candidates for manual deletion, as always):
- `scripts/diagnostics/credit_economy_probe_debug.gd` - enumerates the defeat authority's own group
  and measures the award, duplicate prevention, and every exclusion, each counted by cause.
- `scenes/diagnostics/credit_economy_probe_debug.tscn` - its standalone entry scene.

Modified:
- `scripts/diagnostics/combat_debug_overlay.gd` - one `carried credits N` line, resolved through
  `CreditLedger.find_ledger()`, so the loop is observable without building a HUD system.
- `main.tscn` - one `CreditLedger` node.

### NEW CLASS OF PROCESS DEFECT: a moved class_name script blocks BOTH edit tools

Moving a `class_name` script between folders can leave the editor's global-class registry pointing at
the OLD path. The file then exists at the new path, resolves at runtime, and is listed correctly by
`listTree`, but BOTH `strReplace` and `writeFile` refuse to edit it with:

    Refusing to edit ... because it would duplicate GDScript class_name <Name>.
    That global class already belongs to <old path>.

The old path did NOT exist on disk (`listTree` proved it), so the refusal named a file that was not
there. `readFile` and `glob` on the moved file ALSO lagged, returning "file not found" while
`listTree` listed it - `listTree` was the only reliable witness of the move.

RESOLUTION: move the file to the path the registry already owns, then repoint the scene. Do NOT
"fix" this by creating a second copy of the class, and do not delete the original by hand.

RELATED, re-confirmed: after the move the console reported 20 script errors ("Identifier
CreditLedger not declared") scoped to `open_script_buffers`, while `state:script-errors` returned 0
for every one of those files, the probe ran and printed its full output, and `main.tscn` booted
showing `carried credits 0`. The open-tab linter was describing a stale buffer. Judge this class by
a RUN or a per-file `state:script-errors`, never by the console panel alone - but it HAS caught real
missing helpers too, so it is not ignorable either.

### Registration note

`scripts/economy/` is now the ledger's home and is registered. It was created empty during this pass
and briefly failed to resolve, because a brand-new folder is not in the class cache yet. Same family
as the two previously recorded new-directory registration issues.

---

## MILESTONE 10 - GAME-STATE SAVING AND LOADING FOUNDATION (this pass)

### Files created

- `scripts/core/game_state_save.gd` (`class_name GameStateSave`). Gameplay/service, not diagnostic: the
  canonical save file for Cascadia. It writes and reads ONE real save at `user://cascadia_save.json`
  carrying `schema_version`, `carried_credits` and `saved_at_unix`, and it owns NO balance of its own -
  it reads the balance from `CreditLedger` on save and restores it through the ledger's own controlled
  restoration method on load. Placed in `scripts/core/` DELIBERATELY: that directory is already in the
  class cache, which avoids the new-directory registration defect recorded three times in this file.
- `scripts/diagnostics/game_state_save_load_probe_debug.gd` (`class_name GameStateSaveLoadProbeDebug`).
  Temporary diagnostic (not production). Drives the REAL ledger and the REAL save service, earns
  Credits by killing enemies through the damage chain, and tests every failure mode. Takes a backup of
  any existing save and restores it at the end, so running it does not destroy real progress.
- `scripts/diagnostics/save_load_debug_controls.gd` (`class_name SaveLoadDebugControls`). Temporary
  PROTOTYPE control surface (not production, not final UI): an F5 save / F9 load / F10 new-run panel
  that shows the live carried balance. It owns no balance and no saved state.
- `scenes/diagnostics/game_state_save_load_probe_debug.tscn`. The probe's standalone entry scene.

### Files modified

- `scripts/economy/credit_ledger.gd`: added `loads` (how many times the balance was RESTORED) and
  `restore_carried_credits()`, the controlled restoration path a load uses. It is deliberately NOT
  `award_credits()`: it does not increment `awards`, does not emit `credits_awarded` and does not mark
  any actor as paid, so a load can never be mistaken for an enemy defeat. It refuses a negative amount
  rather than clamping it.
- `main.tscn`: added the `GameStateSave` node and the `SaveLoadControls` CanvasLayer.
- `project.godot`: three NEW InputMap actions - `quick_save` (F5), `quick_load` (F9), `new_run` (F10).

### Failure modes handled that turned out to be WORTH HANDLING

- `JSON.parse_string()` pushes an engine ERROR into the debugger every time it meets a corrupt save, so
  a correctly handled malformed save still looked like a game fault (2 debugger errors on the first
  run). Switched to `JSON.new().parse()`, which reports the same answer, plus the line and message,
  through this service's own typed `Result`. The debugger error count went to 0 and the failure is
  still reported precisely.
- Two assertions in the probe were WRONG on its first run and were fixed rather than tolerated:
  (1) it asserted `credits_earned` was unchanged by a load, but the ledger deliberately re-bases it to
  the restored total so earned and carried cannot disagree; the check now asserts CONSISTENCY with the
  restored balance instead. (2) the defeated-enemy check was written as
  `defeated == defeated_before and not defeated_before`, which can never be true; it now asserts the
  enemy killed before the save is STILL defeated after it.
- `restore_carried_credits()` re-bases `credits_earned` to the restored total. That is a deliberate
  decision, not an oversight: the restored balance IS this run's accumulated earnings as of the save
  point. If a later milestone wants lifetime-earned history, it needs its own separate field.

### Cleanup status

The three new files above are TEMPORARY except `game_state_save.gd`. The probe and its scene, and the
prototype control panel, are candidates for manual deletion once save/load becomes a real menu routed
through `CascadiaInput`. They are recorded, not deleted, per the project rule.

---

## M10.1 CORRECTION PASS - the save now restores the RUN, not just the number (2026-09-12)

### Files created

- `scripts/diagnostics/game_state_overall_probe_debug.gd` - the overall run-state contract probe. The
  FIRST probe that proves a loaded run is still a GAME: it drives real movement and real combat after a
  load, asserts the schema v2 fields, the run identity, 12 bad-data cases, and that a new run cannot be
  mistaken for a load. Recorded as a cleanup candidate.
- `scenes/diagnostics/game_state_overall_probe_debug.tscn` - its entry scene. Cleanup candidate.
- `scripts/diagnostics/game_state_death_loop_probe_debug.gd` - the death-loop contract probe. Proves a
  load inside the death window is REFUSED by its own cause, that the player is restored by the CIRCUIT
  rather than by a load, that defeated enemies stay defeated, and that no service or signal duplicates.
  Recorded as a cleanup candidate.
- `scenes/diagnostics/game_state_death_loop_probe_debug.tscn` - its entry scene. Cleanup candidate.

### Files modified

- `scripts/core/game_state_save.gd` - rewritten to schema v2. It now saves a RUN (identity + carried
  balance + `player.alive`), REFUSES a save from a dead player, and REFUSES a load that is not
  applicable, with two new typed results (`PLAYER_DEAD`, `NO_RUN`). Loading validates in a deliberate
  order (file -> schema -> run identity -> fields -> applicability -> apply) and returns before touching
  anything on every refusal.

### The concrete failure this pass corrected

M10 persisted ONE gameplay value. `load_game()` validated the FILE thoroughly and then applied its
value unconditionally - it never asked whether the run could accept it, and the file recorded nothing
about which run it belonged to. So a load could be applied at ANY moment, including while the player's
death circuit was mid-reset, and it would overwrite a single number inside a world that had already
moved on. The standard was "the number came back"; the standard is "the game came back".

### Why the architecture required it

`DeathComponent` OWNS the player's restoration - health, stamina, position and the arena attacker are
all put back by it, in its own order. A save service that also wrote player state would be a second
owner fighting the first. So M10.1 does NOT persist player health/stamina/position; it persists only
what is needed to know a run is LOADABLE, refuses when it is not, and lets the death circuit keep sole
ownership. That exclusion is written into the schema doc block, because an exclusion that is recorded is
part of the contract and a silent one is a bug waiting.

### Deliberately excluded from the save, with reasons

Player health/stamina/position (owned by the death-reset circuit; restoring them would bypass its
order); defeated-actor state (owned by `EnemyDeathComponent`; a load touches no actor, so nothing is
revived); enemy health; world geometry; checkpoints; banking; spending; stats; items; gear.

---

## M9/M10 recurring defect - a MOVED `class_name` script silently blocks BOTH edit tools (2026-09-12)

`credit_ledger.gd` moved between `scripts/economy/` and `scripts/player/`, and after the move
`strReplace` AND `writeFile` both refused every further edit to it with "would duplicate GDScript
class_name CreditLedger ... already belongs to <the OLD path>". The named old path did not exist:
`listTree` and `glob` both showed the file only at its new location, and the file itself was intact and
loading correctly. The class registry was holding the STALE path.

Practical consequence for any future agent: after moving a script that declares `class_name`, BOTH edit
tools can be blocked by a registry entry pointing at a path that no longer exists. The workaround that
worked was to move the file BACK to the path the registry already owned (`scripts/economy/`, which by
then was registered) and edit it there. Do not conclude the file is corrupt, and do not reach for shell
- read the disk, find where the file ACTUALLY is, and work from there.

Same family as the three recorded new-directory registration issues, and the same lesson: judge by a
disk read or a RUN, never by the registry's memory or the open-tab linter.

---

## M10.2 - input-routing hypothesis TESTED AND FALSIFIED (2026-09-12)

### New files (temporary diagnostics - candidates for manual deletion)

- `scripts/diagnostics/save_load_input_runtime_probe_debug.gd` - the probe that tested, rather than
  assumed, the claim that the save/load debug panel was swallowing mouse attacks.
- `scenes/diagnostics/save_load_input_runtime_probe_debug.tscn` - its standalone entry scene.

### Files modified this pass

- `scripts/diagnostics/save_load_debug_controls.gd` - the panel subtree (`PanelContainer`,
  `MarginContainer`, `Label`) now sets `Control.MOUSE_FILTER_IGNORE`. Kept because it is correct
  practice and matches the other three overlays, which already did this.
- `scripts/diagnostics/save_load_input_runtime_probe_debug.gd` - the probe itself, twice: once to
  fix an `await`-returns-a-coroutine bug that would have made an attack assertion pass VACUOUSLY,
  and once to remove a measurement confound.
- Roadmap section 8M.15.

### FALSIFIED HYPOTHESIS - record this so it is not re-believed

The claim "the panel consumes mouse clicks, so the game looks dead" is FALSE, and it is now measured
false. The probe forces `MOUSE_FILTER_STOP` back onto the panel and fires a real `Mouse1` event at its
centre: **the attack still starts**. Cascadia reads attacks as semantic actions through
`CascadiaInput`, and Godot updates InputMap action state independently of viewport GUI consumption,
so a Control consuming a GUI click cannot cost an attack. The non-consuming filter was applied and
is harmless, but it was NOT the cause of any lost attack.

### Two probe-harness defects found and fixed (both were the PROBE's fault, not the game's)

1. **`await` in a probe helper returned a coroutine.** An awaited function returns a coroutine
   object, which is TRUTHY in an `if`, so `_expect(await _do_thing(), ...)` would have PASSED without
   proving anything. Rewritten await-free with an explicit stage machine. Any future probe that waits
   must use frame counters, not `await`, for exactly this reason.
2. **A committed action suppressed the movement measurement.** The probe measured post-load movement
   immediately after its own click had started an attack, and the 8L movement-authority rule makes a
   committed action authoritative over locomotion - so `0.0000 m` was the RULE working, not a frozen
   runtime. The probe now waits for the combat machine to return to idle first. The assertion was not
   weakened; the confound was removed. This also confirms the 8L arbitration rule is live in the
   current build.

### Honest limitation recorded

The GUI-delivery mechanism (counting Controls that RECEIVE a click via `get_viewport().push_input`)
could NOT be validated in this build: its `MOUSE_FILTER_STOP` positive control never received a
click, so that harness cannot detect consumption either way. It is recorded as SKIP - NOT
MEASURABLE, NOT as a pass. The end-to-end real-click mechanism and the controlled A/B are the
authoritative measurements.

---

## Pass: M10.2 - save/load restores the WORLD, not just a tally (2026-09-12)

### The defect, and why the earlier pass did not find it

The user reported `DEFEATED` stuck on screen while the overlay said `load: OK (carried 100)`.

ROOT CAUSE, read from the code: `enemy_death_presentation_debug.gd` was **ONE-WAY**. It had
`_apply_defeat_pose()` and no `_clear_defeat_pose()`, and its `_process` only ever asked
`if not _posed and _is_defeated()`. So once an actor was posed as defeated, that pose and label
stayed for the life of the instance and **could never come off**. The adapter even remembered the
original mesh transform and material "for a future resurrect/reset"; that path had never been
written. Combined with a `load_game()` that restored ONLY the carried balance, a load left every
actor and the player exactly as the run had left them.

This was NOT found by 8M.15, and 8M.15 does not claim otherwise: that pass falsified the
mouse_filter hypothesis and ruled out one explanation. It never tested the presentation adapter's
one-way state, because no probe looked at whether a label can come OFF.

### Files changed

- `scripts/combat/health_component.gd` - added `restore_to_full()`. The owner's own API for putting
  health back WITHOUT clearing `is_dead`, which stays under `EnemyDeathComponent`'s control.
  Deliberately NOT a change to `reset()`.
- `scripts/combat/enemy_death_component.gd` - added `restore_defeated(value)`. Sets the flag BOTH
  ways and deliberately does NOT emit `defeated`, because that signal PAYS a reward; emitting it on
  a restore would mint currency on every load.
- `scripts/core/game_state_save.gd` - schema 3. Added `_capture_world()` / `_restore_world()`,
  recording each actor in `GROUP_ENEMY_DEATH` by **scene path** (no node references serialized),
  sorted so the same world always produces the same file. Added the player restore through
  `DeathComponent.reset_playable_state()`. REMOVED a duplicated unreachable dead-player branch.
- `scripts/diagnostics/enemy_death_presentation_debug.gd` - `_process` now polls BOTH ways, and
  `_clear_defeat_pose()` was added.
- `scripts/diagnostics/game_state_world_restore_probe_debug.gd` + its scene - NEW.
- `scripts/diagnostics/game_state_overall_probe_debug.gd` - 7 fixtures de-hardcoded.
- `scripts/diagnostics/game_state_save_load_probe_debug.gd` - 3 fixtures de-hardcoded.
- `scripts/diagnostics/game_state_death_loop_probe_debug.gd` - two assertions updated to the
  revised contract (see below).

### Measured

`game_state_world_restore_probe_debug`: RESULT: ALL CHECKS PASSED, 0 debugger errors. It performs
the exact reported sequence - save with the world alive, kill enemies AND the player, then load.
All five actors restored to 100 health, `is_defeated=false`, none showing a label;
`after the load: alive=5 defeated=0 credits=250`; the player restored through its own death circuit
(`resets=1`) and MOVES 1.3133 m afterwards; one ledger and one save service.

`game_state_overall_probe_debug`: ALL CHECKS PASSED. `game_state_save_load_probe_debug`: ALL CHECKS
PASSED. `game_state_death_loop_probe_debug`: ALL CHECKS PASSED. `credit_economy_probe_debug`: ALL
CHECKS PASSED (5 eligible, 500, 5 awards). `defeat_coverage_probe_debug`: ALL CHECKS PASSED, 5/5.
`main.tscn`: 0 debugger errors.

### Contract change recorded, NOT silent

`game_state_death_loop_probe_debug` previously asserted a load inside the death window is REFUSED.
Under the snapshot contract a save always records a PLAYABLE run, so loading it mid-death RESTORES
that run through the death circuit. The probe was updated to the STRONGER form: the revival must
come from the circuit (`resets` must increment), it must pay nothing, and it must not revive an
enemy the snapshot recorded as defeated.

### Process defect recorded - a fixture that hardcodes a version stops testing its own claim

After the schema bump to 3, TEN fixtures across three probes were pinned to older versions and
began failing as `unsupported-version` - i.e. they FAILED AS THE WRONG ERROR, which reads like the
code under test is broken. Every one now derives from `GameStateSave.SCHEMA_VERSION`.
LESSON: derive fixtures from the constant. A hardcoded version turns a passing test into a
misleading failure the moment the constant moves.

### Cleanup candidates (recorded, NOT deleted)

- `scripts/diagnostics/game_state_world_restore_probe_debug.gd` + its scene - diagnostic.
- All save/load probes and `save_load_debug_controls.gd` remain cleanup candidates once save/load
  becomes a real menu routed through `CascadiaInput`.
- `scripts/debug/` was suggested by the user for a probe path but does not exist in this project;
  the probe went to `scripts/diagnostics/` to match the established convention. Recorded so the
  discrepancy is visible rather than silently ignored.

---

## M10.3 - Mixed-state snapshot proof (2026-09-12)

### Files created

- `scripts/diagnostics/game_state_mixed_state_probe_debug.gd` - diagnostic (cleanup candidate). Proves
  the snapshot contract across FIVE world densities, per actor, by scene PATH. It exists because the
  previous probes only ever saved an ALL-ALIVE world, which cannot detect a wrong-actor restore or a
  restore that rebuilds a default world.
- `scenes/diagnostics/game_state_mixed_state_probe_debug.tscn` - its entry scene.

### Process defect recorded - the probe charged the load for the mutation's own kills

The mixed-state probe's first run FAILED with `awards 0 -> 2`, `2 -> 3`, `3 -> 4`, `4 -> 5`. Each
delta exactly equalled the number of enemies the probe's own MUTATION step had killed, because
`_awards_at_save` was captured BEFORE the mutation. The loads were innocent; the measurement window
was wrong.

FIX: take `_awards_before_load` / `_credits_before_load` IMMEDIATELY before the load and assert
against those. The assertion is stronger than before - it isolates the load - rather than relaxed.

GENERAL LESSON FOR ANY FUTURE AGENT: when asserting "operation X caused no side effect", the baseline
must be captured IMMEDIATELY before X. A baseline taken earlier silently absorbs every legitimate
change in between and reports them as X's fault. This is the second time in this milestone that a
measurement-window error produced a false failure (the first was measuring movement while a committed
attack was still suppressing locomotion, 8M.15).

### Doc defect recorded - duplicate section numbers in the roadmap

`CASCADIA_MILESTONE_ROADMAP.md` contains TWO headings numbered `8M.15` and TWO numbered `8M.16`,
because the M10.1 block and the M10.2 block each restarted the count. This pass used `8M.18` to avoid
adding a third collision. Renumbering the older headings is left to MANUAL REVIEW rather than done
silently, per the file-hygiene rule.

### Cleanup candidates (recorded, NOT deleted)

- `scripts/diagnostics/game_state_mixed_state_probe_debug.gd` + its scene - diagnostic.

---

## M10.4 - Quicksave/quickload GAMEPLAY contract + reward-history restore defect (2026-09-13)

Independent investigation of the reported failure: kill one enemy -> F5 -> kill a second enemy -> F9
-> the game does not come back playable. Recorded at the moment of the work, per the file-hygiene
rule. Recording is the action; deletion stays manual.

### Root cause confirmed by reproduction, NOT by inspection alone

Every existing save/load probe restored STATE correctly and every one of them PASSED on this build.
`game_state_mixed_state_probe_debug` was re-run FRESH at the start of this pass and returned
`RESULT: ALL CHECKS PASSED` across all five snapshot densities with per-actor identity. So the defect
was not in capture, serialization, file handling, schema, actor identity, restoration ordering or
state ownership - it was in what NO existing probe measured: whether the restored world still
FUNCTIONS as a game.

`CreditLedger` refuses to pay an actor twice and recognises "already paid" by the defeat component's
INSTANCE ID, which belongs to the live process. A load puts the world back to a state the run
recorded EARLIER, which necessarily includes actors killed AFTER the save - those come back alive,
targetable and killable, but the ledger still remembered paying them. So a restored run contained
live enemies that were permanently worth NOTHING, while the saved balance looked correct. Nothing
detected it, because every previous probe only ever observed restored variables.

### Files created

- `scripts/diagnostics/quicksave_contract_probe_debug.gd` - diagnostic (cleanup candidate). Drives
  the REPORTED sequence through the REAL gameplay path: `CascadiaInput` actions -> `PlayerCombat` ->
  `HitboxComponent` -> `HurtboxComponent` -> `HealthComponent` -> `EnemyDeathComponent` ->
  `CreditLedger` -> `GameStateSave`. Kills are never assigned; the probe presses the real light
  attack and must actually defeat the enemy. It then KEEPS PLAYING after the load.
- `scenes/diagnostics/quicksave_contract_probe_debug.tscn` - its entry scene.

### Files modified

- `scripts/economy/credit_ledger.gd` - added `is_rewarded(component)` (the public read of the paid
  set, so the save service records reward history through the owner's API instead of reaching into
  private state) and `restore_reward_tracking(already_paid)` (the controlled restore path a load
  uses). `restore_reward_tracking` deliberately does NOT award, does NOT touch the balance, does NOT
  emit `credits_awarded`, and does NOT inflate `awards`. It leaves `_watched` ALONE - those are live
  signal connections, not history, and clearing them would let `_watch_enemies()` double-connect.
- `scripts/core/game_state_save.gd` - `_capture_world()` now records a `paid` field per actor read
  through `ledger.is_rewarded()`; load step 6d calls the new `_restore_reward_tracking()`, which
  restores the ledger's paid set from the snapshot. A save that predates the field falls back to
  `paid == defeated`, which is the behaviour the service had implicitly before, so no older file
  changes meaning.

### Evidence that the fix is LOAD-BEARING (negative control, run and reverted)

A temporary `return 0` was inserted at the top of `_restore_reward_tracking()` and the probe re-run.
Measured: the post-load kill still SUCCEEDED through the real combat path and the enemy died
normally, but it paid NOTHING - `FAIL the post-load kill paid EXACTLY ONCE (awards 2 -> 2)` and
`FAIL the post-load kill paid exactly one reward (want 200, got 100)`, `RESULT: 2 FAILED`. The
control was then reverted and the file hash confirmed back to the shipped state, and the probe
re-run. Measured on the shipped state: `RESULT: ALL CHECKS PASSED`.

This is the honest significance: the defect is INVISIBLE to a state-only check. The world was right
and the economy silently stopped paying.

### Process note - the probe's own attack budget

The probe's first design used a 22-frame gap between real attacks. A light attack costs 18 stamina
with 0.8 s of blocked regeneration, so seven hits (100 health / 15 damage) cannot be afforded at
that rate and the later presses were correctly REFUSED for stamina - which would have read as a
broken kill rather than a probe that outran its own economy. The gap is now 40 frames, deliberately
longer than the 0.54 s whole light-attack timeline AND long enough to fund the kill. The assertion
was not weakened; the harness was fixed.

### Cleanup candidates (recorded, NOT deleted)

- `scripts/diagnostics/quicksave_contract_probe_debug.gd` + its scene - diagnostic.
- The two pre-existing identical-named members `_expect` (variable + function) remain in
  `game_state_mixed_state_probe_debug.gd` style; the NEW probe uses `_check()` to avoid repeating
  that collision, which GDScript rejects outright as a parse error.

---

## M10.5 - DEEP quicksave contract: THIRD enemy and a SECOND return to the same quicksave (2026-09-13)

The user asked whether the probe was written correctly and working, and asked for it to be DEEPER:
kill additional enemies after the second and still return to the previous quicksave. The M10.4 probe
proved ONE post-save kill and ONE load. That is a single point on the curve, and it cannot detect a
reward history that only survives the first restore.

### What the probe now does (rewritten, not extended in place)

`scripts/diagnostics/quicksave_contract_probe_debug.gd` was rewritten as a QUEUE-DRIVEN sequence so
extra kills and extra loads are data, not new copy-pasted stages. Named victims:

    VICTIM_A = DummyActor      killed BEFORE the save
    VICTIM_B = TestAttacker    killed after the save, then again after each load
    VICTIM_C = TargetA         the THIRD enemy - the extension the user asked for

Sequence, every kill through the REAL attack path (PlayerCombat -> HitboxComponent ->
HurtboxComponent -> HealthComponent -> EnemyDeathComponent), never a direct assignment:

| stage | action | measured |
| ----- | ------ | -------- |
| A | arena baseline | 5 alive, all targetable, 1 ledger, 1 save service |
| B | kill DummyActor, SAVE | file records all 5 by scene path, incl. per-actor `paid` |
| C | kill TestAttacker AND TargetA | two more real kills; awards 1 -> 3 |
| D | LOAD 1 | DummyActor still dead; TestAttacker and TargetA alive again; balance back to 100 |
| E | kill TargetA then TestAttacker again | both die; awards 3 -> 5; balance 100 -> 300 |
| F | LOAD 2 - SAME quicksave | identical restore; awards 5 -> 5 ACROSS the load |
| G | kill TestAttacker a THIRD time | paid exactly once; awards 5 -> 6; balance 200 |

### Evidence the load is the SAME quicksave, not a re-save

Both loads assert the save FILE is UNCHANGED since the save (read from disk, hashed by content
comparison), so a passing load 2 cannot be explained by the probe quietly re-saving the live world.
Without that guard, a load that silently snapshotted the mutated world would pass identically.

### Evidence the reward history survives REPEATED restores

The new assertions are per-actor and read the ledger's own API:

- after each load: `is_rewarded(TestAttacker)` and `is_rewarded(TargetA)` are FALSE (they were alive
  in the snapshot, so they must be worth Credits again);
- after each load: `is_rewarded(DummyActor)` is TRUE (it was dead and already paid in the snapshot,
  so it must not pay twice);
- the ledger PAYS for the twice-revived enemy on the third kill cycle - `the twice-restored world
  still pays (want 200, got 200)`.

That last check is the one the user's request was really about: an enemy revived by a SECOND load is
still worth Credits, which a restore that only cleared the paid set on the FIRST load could not pass.

### Measured (shipped state, 0 debugger errors from the probe)

    [QUICKSAVE] held at save: defeated=[DummyActor] alive=[TargetA,TargetB,TargetC,TestAttacker] carried=100 awards=1
    [QUICKSAVE] after load 1: defeated=[DummyActor] alive=[TargetA,TargetB,TargetC,TestAttacker] carried=100 awards=3
    [QUICKSAVE] after continued play: defeated=[DummyActor,TargetA,TestAttacker] carried=300 awards=5
    [QUICKSAVE] after load 2: defeated=[DummyActor] alive=[TargetA,TargetB,TargetC,TestAttacker] carried=100 awards=5
    [QUICKSAVE] after final play: defeated=[DummyActor,TestAttacker] carried=200 awards=6
    [QUICKSAVE] RESULT: ALL CHECKS PASSED

Load 2 restored the SAME world as load 1 (only DummyActor defeated) from the SAME unchanged file,
after the run had moved two enemies further from it.

### Still NOT verified

The physical F5/F9 keys have still not been pressed by hand. Every result above comes from injected
`Input.action_press` through the real action path, which is the closest automated equivalent but is
NOT the same as an OS-level key event. Recorded as unverified rather than implied.

---

## M10.6 - THE F9 FAILURE IS A HOST KEY COLLISION, NOT A SAVE/LOAD DEFECT (2026-09-13)

Root cause of the reported "F9 breaks gameplay", MEASURED rather than inferred, and it is OUTSIDE the
game. Recorded at the moment of the work, per the file-hygiene rule. Recording is the action;
deletion stays manual.

### The decisive experiment

`scripts/diagnostics/fkey_host_ownership_probe_debug.gd` (+ its scene) injects function keys while
the ONLY in-game consumer of the save/load actions (`main.tscn/SaveLoadControls`) is set to
`PROCESS_MODE_DISABLED`, so `quick_save` / `quick_load` / `new_run` have NO consumer at all. With no
game code able to react, any reaction has to be the HOST's.

Measured, consumer disabled, nothing consuming the actions:

    F8  ENDS THE DEBUG SESSION. The process stops on F8 with no script error and no trace.
    F9  IS THE HOST'S PAUSE TOGGLE. F9 was delivered to the game AND simultaneously set
        `Engine.time_scale = 0`, released the mouse (mode 2 -> 0), and starved the game's own frame
        loop to 6 of ~40 frames - while `SceneTree.paused` stayed FALSE and the window stayed
        focused. A SECOND F9 press was NOT delivered (delivered_to_game=0) and restored the clock
        and the cursor (scale 1.000, mouse 2). A TOGGLE, not a one-way stop.

Safe and delivered, each with `scale=1.000 paused=false mouse=2` and no skipped input frames:
F1, F2, F3, F4, F5, F6, F7, F10, F11, F12, and ordinary letters (K tested as the letter control).

### Why this explains every reported symptom

With `Engine.time_scale == 0` the frame loop still runs and still renders, so the game LOOKS alive,
while every delta-driven system stands still: movement, mouse look (the cursor is released), attack
phases, dodges and stamina regeneration. `SceneTree.paused == false`, `is_processing()` returns true,
the camera is current - every in-engine check reads healthy. That is exactly "the game does not come
back playable after F9", and no code inside the game can win a race for a key the host consumes.

### Why the earlier automated verification was "inconsistent"

It was not inconsistent; it was driving a host key. `save_load_runtime_state_probe_debug` used
`KEY_LOAD := 4194339` = **F8**, while its own banner printed "F9". Every run therefore measured the
host ending the debug session, which is why its transcript stopped at the `--- PHASE 4 ---` banner
with no script error.

### The fix (applied)

- Two NEW InputMap actions exist, bound ONLY to measured-safe keys: `load_run` = F7, `load_run_alt`
  = F11.
- `scripts/diagnostics/save_load_debug_controls.gd` reads `load_run` / `load_run_alt` instead of
  `quick_load` / `quick_load_alt`.
- `quick_load` / `quick_load_alt` are LEFT IN THE INPUTMAP, still bound to F9 / F8, UNUSED. Removal
  of an InputMap binding is MANUAL review, and leaving them keeps the host collision directly
  re-testable.
- `scripts/diagnostics/save_load_runtime_state_probe_debug.gd` now drives F7 (was F8).

### Measured result after the rebind (durable transcript, `_probe_report.txt`)

`RESULT: ALL CHECKS PASSED`, 0 debugger errors from the probe. F5 saves (saves 0 -> 1), the world is
mutated, and the load restores the player to `0.195 m` of the saved position on BOTH loads, with
`result=OK` both times. Gameplay continues after each load: walk 1.7950 m, mouse look 48.8952 deg,
attack 8 -> 9 and 9 -> 10, dodge running, and stamina REGENERATES 60.0 -> 77.9 and 47.6 -> 65.4.
Across all 80 traced frames there is NOT ONE frame with `scale=0.000`, `mouse=0`, `paused=true` or a
dead player - the reported unplayability window is ABSENT.

### Still NOT verified

The physical F5/F7 keys have not been pressed by hand. Everything above is injected
`Input.parse_input_event` through the real action path. The physical test is the user's.

### Cleanup candidates (recorded, NOT deleted)

## Candidate: scripts/diagnostics/fkey_host_ownership_probe_debug.gd

Status: Candidate for manual deletion

Reason:
Temporary diagnostic. Answers one question - who owns F8/F9 in the embedding host - and that question
is now ANSWERED and recorded above. It is not part of the game.

Replacement:
None. Its finding is recorded in this section and in roadmap 8M.20.

Used By:
Nothing. `scenes/diagnostics/fkey_host_ownership_probe_debug.tscn` is its only entry point.

Safe To Delete:
Yes

Date Flagged:
2026-09-13

Notes:
Keep until the rebind has been confirmed by hand at least once - it is the only direct way to
re-demonstrate the host collision if `quick_load`/`quick_load_alt` are ever rebound.

## Candidate: scenes/diagnostics/fkey_host_ownership_probe_debug.tscn

Status: Candidate for manual deletion

Reason:
Entry scene for the diagnostic above; nothing else instances it.

Replacement:
None.

Used By:
Nothing.

Safe To Delete:
Yes

Date Flagged:
2026-09-13

Notes:
Delete together with its script.

## Candidate: _fkey_probe_report.txt

Status: Candidate for manual deletion

Reason:
Generated transcript of the F8/F9 ownership experiment. Evidence, not a game file.

Replacement:
None. Its finding is recorded in this section.

Used By:
Nothing.

Safe To Delete:
Uncertain

Date Flagged:
2026-09-13

Notes:
Evidence for the root cause above. Delete only when the finding no longer needs to be reproduced.

## Candidate: InputMap bindings `quick_load` (F9) and `quick_load_alt` (F8) in project.godot

Status: Candidate for manual review (binding removal only)

Reason:
Bound to F9 and F8, both OWNED BY THE HOST, so they can never reach the game reliably. Superseded by
`load_run` (F7) and `load_run_alt` (F11).

Replacement:
`load_run` / `load_run_alt`.

Used By:
Nothing. `save_load_debug_controls.gd` no longer reads them.

Safe To Delete:
Uncertain

Date Flagged:
2026-09-13

Notes:
NOT a file - they live in `project.godot`. Deliberately left in place so the host collision stays
re-testable, and because removing an InputMap binding is manual review.

---

## M10.7 - FOCUS RETURN / MOUSE CAPTURE PLUMBING (2026-09-13)

The user reported that after Alt-Tab and return, clicking the window left the game partially broken:
the camera responded, the cursor stayed FREE, and the character would not move. No save/load defect
is involved - quicksave is untouched by this pass.

### Two distinct defects, both measured

1. THE CAPTURE REQUEST WAS MADE FROM A FRAME CALLBACK. `_keep_mouse_captured()` asked the host for
   the pointer every frame. In an embedded/browser host pointer lock is a USER-GESTURE permission,
   so a request made outside a real input event can be dropped while looking successful from inside
   the game. That is the reported "camera responds, cursor stays free".

2. EVERY REFOCUS CLICK WAS STARTING A LIGHT ATTACK. The click that arrives to retarget the window
   reached `PlayerCombat`. A COMMITTED attack owns the body (project rule: committed action is
   authoritative over its own movement), so locomotion was suppressed - which is the reported "I
   still cannot move". The suppression already existed for the Escape-recapture path but was NOT
   applied when the host had dropped capture.

### Files modified

- `scripts/input/cascadia_input.gd` - new `_recover_capture_on_press()`, called from `_input`
  (before GUI handling) on every mouse-button press. It re-takes capture INSIDE the click's own call
  stack, so the request happens in the user-gesture context a host can grant; it sets the
  `_suppress_presses` flag so the same click cannot become an attack; and it is deliberately NOT
  gated on the focus belief, because a click that reached this game IS the player proving presence.
  Unconditional on `_focus_lost`, so it also covers a host that drops capture with no focus change.
- `scripts/diagnostics/focus_input_routing_probe_debug.gd` - new PHASE 3b.
- `scripts/diagnostics/input_debug_overlay.gd` - shows live engine capture state beside the gate.

### Measured (shipped state, `_focus_probe_report.txt`, 0 debugger errors from the probe)

`RESULT: ALL CHECKS PASSED`. PHASE 3b reproduces the reported state by clearing `Input.mouse_mode`
while the engine still reports focus, then measures SYNCHRONOUSLY (flush, no `await`) so the recovery
is credited to the click and not to the per-frame keeper:

    PASS  HOST-DROPPED: the CLICK ITSELF re-took the cursor (mode=2)
    PASS  HOST-DROPPED: that click is SUPPRESSED as a swing
    PASS  HOST-DROPPED: the refocus click did NOT start an attack (attacks 2 -> 2)
    PASS  HOST-DROPPED: the player can MOVE after the click (1.0950 m)

The third line is the negative control for the "cannot move" cause: without the suppression the click
becomes a committed attack and locomotion is suppressed by design.

### Cleanup candidates (recorded, NOT deleted)

- `scripts/diagnostics/focus_input_routing_probe_debug.gd` + its scene - diagnostic.
  `scenes/diagnostics/focus_input_routing_probe_debug.tscn`.
- `res://_focus_probe_report.txt` - durable transcript. Overwritten by each run; kept while the
  finding still needs reproducing.
- The recurring lint FALSE POSITIVE `mouse-capture-must-release` on every probe that sets
  `Input.mouse_mode`: the Escape release lives in `CascadiaInput`, which `main.tscn` provides for
  each probe scene. Not a real trap, do not "fix" it in the probes.

---

## M10.7 - Window focus / gameplay input routing (2026-09-13)

Independent investigation of the reported focus-and-retargeting failure. Recorded at the moment of the
work, per the file-hygiene rule. Recording is the action; deletion stays manual.

### The report

Alt-Tab away from the game, return, click the window to retarget it: keyboard presses may still
register, but the camera no longer turns with the mouse, the character does not move normally, and
clicking the game does not restore mouse capture.

### Root cause - two defects, both in the focus handling added by the previous pass

1. THE RECONCILIATION WEDGED THE GAME. `_refresh_focus()` forced the layer's belief to match the
   engine's `has_focus()` in BOTH directions, every frame. `has_focus()` is the authority; when the
   host never flips it back, or the notification is missed, the layer was re-suspended on every
   single frame. Everything downstream followed: `_keep_mouse_captured()` refused to re-assert (the
   keeper is gated on being active), so capture was never restored; `get_move_vector()` returned
   ZERO, so the character would not walk; and the debug overlay kept lighting up key rows because it
   reads raw `Input` rather than the gate. That is exactly the reported "keys arrive but the game
   does not recover".
2. THE RECOVERY PATH WAS GATED BEHIND THE STATE IT HAD TO CLEAR. `_unhandled_input()` early-returned
   while suspended, so the click that should end a suspension was discarded BY the suspension. The
   only exit was a focus-in notification - the one thing observed not to arrive.

### Fix

- `_refresh_focus()` is now RESUME-ONLY. A missed focus-in can no longer wedge the game; the only
  cost is that a suspension lasts one frame longer than the notification would have given.
- `_input()` presence recovery runs BEFORE GUI handling, so no Control can consume it: a deliberate
  key press or mouse-button press while suspended resumes input, restores the declared capture and
  drops the half-finished input. Mouse MOTION deliberately cannot resume anything, because motion can
  arrive from the host with no interaction at all - letting it resume would re-create the original
  defect of a camera that turns while the player is in another window.

### Files created (cleanup candidates, recorded below)

- `scripts/diagnostics/focus_input_routing_probe_debug.gd`
- `scenes/diagnostics/focus_input_routing_probe_debug.tscn`

### Files modified

- `scripts/input/cascadia_input.gd` - resume-only reconciliation, the `_input` presence recovery,
  and the `is_input_active()` gate consulted by every semantic query.
- `scripts/diagnostics/input_debug_overlay.gd` - the mouse header now shows the live engine capture
  state beside the focus gate, so a focus change is readable while it happens.

### Measured (durable transcript `_focus_probe_report.txt`, 0 debugger errors from the probe)

`RESULT: ALL CHECKS PASSED`. Focused: look 86.5229 deg, movement 1.0950 m, attack and dodge work.
Focus lost: input suspended, cursor released (mode 0), capture intent kept, a held W reads as ZERO
movement, a pending look delta is DISCARDED, sprint OFF, a queued dodge cannot be consumed, no action
reads as pressed, no pause and scale 1.000. PHASE 2b, the reported wedge - a suspension with NO
focus-in: motion alone does NOT resume; a real CLICK resumes and restores capture (mode 2); a KEY press
also resumes; state and capture hold afterwards; the layer kept processing throughout (440 -> 448).
Refocused: capture returned with NO click, the returning button is suppressed, look 86.5229 deg,
movement 1.1342 m, attack and dodge work, stamina regenerates 21.7 -> 39.6. `lock_on` still reaches the
layer, the targeting group still resolves to the player, no debug-panel Control consumes gameplay
mouse input, no UI Control holds focus, no pause and no time-scale change anywhere.

### Probe defect found and corrected during this pass

The first version of the new PHASE 2b asserted "the layer is still processing" with a frame counter
read across a stretch that deliberately contains NO `await` - no frame runs inside it, so
`process_ticks` cannot advance and the assertion could never pass. It reported `429 -> 429`. The
control was moved to where frames actually run (after the click recovery, `440 -> 448`), and PHASE 2
now asserts only that the counter did not go BACKWARDS. The game was not at fault; the measurement was.

### Quicksave

NOT touched by this pass. `game_state_save.gd`, the save actions and their bindings are unchanged.

### Still NOT verified by hand

The focus round trip was reproduced with `propagate_notification` plus injected input, NOT by a real
Alt-Tab with a real OS cursor. This environment cannot hold the window genuinely unfocused - the
engine keeps reporting focus - so the handler's effect lasts one tick here and that limit is printed
in the transcript rather than hidden. The user's physical Alt-Tab-and-return remains the only proof of
that half.

---

## Candidate: scripts/diagnostics/focus_input_routing_probe_debug.gd

Status: Candidate for manual deletion

Reason:
Temporary diagnostic for the M10.7 focus / input-routing pass.

Replacement:
Nothing. Its findings are recorded above and in roadmap section 8M.21.

Used By:
`scenes/diagnostics/focus_input_routing_probe_debug.tscn` is its only entry point.

Safe To Delete:
Uncertain

Date Flagged:
2026-09-13

Notes:
Keep while the focus behaviour needs to stay re-testable. It writes the durable transcript
`res://_focus_probe_report.txt`, which is evidence and is NOT proposed for deletion.

Updated 2026-09-13 (M10.9): PHASE 5 added - Escape release/recovery coverage (the one reported edge
case that had no measurement at all) and a DIRECT measurement of the look-consumption contract
(`peek_look_delta()` observes the pending delta and does not consume it; `get_look_delta()` returns
that same value and then ZERO, so the camera remains the single spender). Status unchanged - still a
candidate for manual deletion, still the re-test harness for focus behaviour.

## Candidate: scenes/diagnostics/focus_input_routing_probe_debug.tscn

Status: Candidate for manual deletion

Reason:
Entry scene for the temporary M10.7 focus diagnostic above.

Replacement:
Nothing.

Used By:
Nothing.

Safe To Delete:
Uncertain

Date Flagged:
2026-09-13

Notes:
Delete only together with its script, or the script loses its entry point.

---

## M10.7c - FOCUS RETURN: SINGLE-SHOT DELIVERY (2026-09-13, third pass)

User's second hands-on retest: camera works, attacks now work and are unchanged, **mouse capture and
movement still do not**. Recorded at the moment of the work, per the hygiene rule.

### Root cause

Both recovery requests were made exactly ONCE, from the focus event, at the instant the host hands focus
over, and a host can need a beat before it acts on a request made that early:

1. mouse capture - one `_force_capture()` from `_on_focus_gained()`;
2. keyboard delivery to the window - `_take_window_focus()` early-returned on `window.has_focus()`.

Dropped request + the focus event never coming again (the window IS focused, so there is no further
transition to hang it on) = permanent. That is what separates the working systems from the broken one:
attacks and the camera need only that MOUSE events reach the process, while movement is the only path
built on KEY events delivered to the focused window.

### Files modified

- `scripts/input/cascadia_input.gd` - unconditional `_take_window_focus()`; new
  `FOCUS_REASSERT_FRAMES` settle window opened only by `_on_focus_gained()` and consumed by
  `_reassert_after_focus()`, which re-renders the window request and a REAL capture transition
  (`_force_capture()`, not the plain assignment the per-frame keeper uses, because a host-dropped lock
  leaves `Input.mouse_mode` reading CAPTURED and the keeper then asks for nothing). Bounded to a
  handful of frames after a real focus change so it cannot fight the host for the foreground.

### Measured

`RESULT: ALL CHECKS PASSED` on the existing focus probe, 0 runtime errors. Refocused: capture returned
with NO click, movement 1.1293 m, attacks and dodges work, camera works, no pause, scale 1.000, player
in the normal process mode. Transcript `res://_focus_probe_report.txt`.

### Still NOT verified - do not read this pass as proven

- The physical Alt-Tab with a real OS cursor. This environment cannot hold the window genuinely
  unfocused (the engine keeps reporting focus), so the recovery PATH is proven and the real transition
  is NOT. The user's hands-on Alt-Tab has not been re-run since this change.
- Regression surface not re-measured this pass: quicksave, the debug panels, the InputMap host-key
  entries. No change was made to any of them, and no evidence of regression exists.

### Recurring problems (unchanged, still recorded)

- The lint FALSE POSITIVE `mouse-capture-must-release` on every probe that sets `Input.mouse_mode`: the
  Escape release lives in `CascadiaInput`, which each probe scene provides. Not a real trap.
- `F8` / `F9` remain HOST-OWNED in this engine host and stay unusable as load keys (M10.6). Unchanged.

---

## Candidate: scripts/diagnostics/mouse_look_routing_probe_debug.gd (+ .uid)

Status: Temporary diagnostic, retained

Reason:
Built to localise ONE defect: injected mouse motion did not turn the camera while movement, attacks,
dodge, stamina and focus handling all worked. It measures each link separately (arrival, delivery,
accumulation, a direct control call into the layer, and the end-to-end yaw change) instead of a single
yaw reading, so it can say WHERE motion dies and not only that it did. It is the probe that proved the
look delta was accumulated by `CascadiaInput` and then consumed by a display reader before the camera
could spend it.

Replacement:
None. It is a targeted diagnostic, not a placeholder for production code.

Used By:
`res://scenes/diagnostics/mouse_look_routing_probe_debug.tscn`, which instances `res://main.tscn` the
same way every other probe does. Registered here at the moment of creation, per the hygiene rule.

Safe To Delete:
Yes, once the mouse-look routing is stable and covered by the focus probe's own look checks.

Date Flagged:
2026-09-13

Notes:
Writes its transcript to `res://_mouse_look_report.txt` (also a cleanup candidate; it is a durable
transcript under the same convention as `_focus_probe_report.txt`). It restores
`Input.use_accumulated_input` and the camera rig's process mode before the run ends. Carries the
`mouse-capture-must-release` lint warning, which is the SAME documented false positive as every other
probe here: the Escape release lives in `CascadiaInput`, which the probe scene provides.

---

## Recurring: stale open-buffer linter false positive (UNCHANGED, fifth confirmation)

Status: Known false positive, do NOT "fix" by editing the named files

Reason:
The diagnostics panel still reports 20 phantom `Identifier "CreditLedger" not declared` errors in
`combat_debug_overlay.gd` and `credit_economy_probe_debug.gd` under scope `open_script_buffers`, while
per-file `state:script-errors` returns 0 for EVERY file involved and both scripts run and print in
full. Re-confirmed 2026-09-13 during M10.8.

Safe To Delete:
Nothing to delete. Judge the affected files by a RUN or a per-file query, never by the open-tab linter.

Date Flagged:
2026-09-12 (re-confirmed 2026-09-13)

---

## Recurring: `mouse-capture-must-release` lint false positive (UNCHANGED)

Status: Known false positive

Reason:
Reported on every script that sets `Input.mouse_mode`, and on `input_debug_overlay.gd` again during
M10.8 when its look read was changed. The Escape release is implemented ONCE, in `CascadiaInput`, which
every probe scene and the main scene provide. The affected scripts are display-only and set no mouse
mode of their own; the warning is emitted for the file because it references the mouse mode for
reporting.

Safe To Delete:
Nothing to delete. Not a real trap.

Date Flagged:
2026-09-13

---

## Candidate: scripts/diagnostics/recovery_chain_probe_debug.gd

Status: Candidate for manual deletion

Reason:
Temporary diagnostic for the M10.10 recovery-chain pass. It measures the eight reported recovery chains
END TO END - focus, cursor mode, capture intent, input-active, the pending look delta and the layer's
capture counters at every step - rather than one state at a time.

Replacement:
Nothing. Its findings are recorded in roadmap section 8M.24.

Used By:
`scenes/diagnostics/recovery_chain_probe_debug.tscn` is its only entry point.

Safe To Delete:
Uncertain

Date Flagged:
2026-09-13

Notes:
Keep while the recovery chains need to stay re-testable: it is currently the ONLY test that measures a
whole recovery SEQUENCE rather than a single transition. It writes the durable transcript
`res://_recovery_chain_report.txt`, which is evidence and is NOT proposed for deletion. Three defects
were found and fixed in ITS OWN measurement during this pass (frame counts used as time in an uncapped
scene, a backstep tap held past `MOBILITY_TAP_MAX` so it resolved as a sprint HOLD, and an assumed
stamina-regeneration wait). None of the three was a production defect.

---

## Candidate: scenes/diagnostics/recovery_chain_probe_debug.tscn

Status: Candidate for manual deletion

Reason:
Entry scene for the temporary M10.10 recovery-chain diagnostic above.

Replacement:
Nothing.

Used By:
Nothing.

Safe To Delete:
Uncertain

Date Flagged:
2026-09-13

Notes:
Delete only together with its script, or the script loses its entry point.

---

## Recurring: stale open-buffer linter false positive (UNCHANGED, sixth confirmation)

Status: Known false positive, do NOT "fix" by editing the named files

Reason:
The diagnostics panel still reports 20 phantom `Identifier "CreditLedger" not declared` errors in
`combat_debug_overlay.gd` and `credit_economy_probe_debug.gd` under scope `open_script_buffers`, while a
per-file `state:script-errors` query returns 0 for EVERY file involved and both scripts run and print in
full. Re-confirmed 2026-09-13 during M10.10, alongside a newly written probe whose per-file errors were
also 0 while the panel reported the same class of stale error elsewhere.

Safe To Delete:
Nothing to delete. Judge the affected files by a RUN or a per-file query, never by the open-tab linter.

Date Flagged:
2026-09-12 (re-confirmed 2026-09-13)

---

## Candidate: scripts/diagnostics/dodge_authority_probe_debug.gd

Status: Candidate for manual deletion

Reason:
Temporary diagnostic for the Dodge movement-authority pass (roadmap section 8F, implemented and
measured in 8N). It measures the arbitration contract the pass exists to establish: during a COMMITTED
evasion the evasion owns the body's orientation and its displacement, and nothing that did not author
the evasion may rewrite either. Nine checks - backstep facing, directional facing (with the body
deliberately pinned 180 deg away from the dodge direction), dodge travel, backstep travel, a dodge
driven into the 42 cm step, the attack mutex, the single stamina cost, the i-frame window, and the
handoff back to ordinary locomotion.

Replacement:
Nothing. Its findings are recorded in roadmap section 8N.

Used By:
`scenes/diagnostics/dodge_authority_probe_debug.tscn` is its only entry point.

Safe To Delete:
Uncertain

Date Flagged:
2026-09-13

Notes:
Keep while the evasion-authority contract needs to stay re-testable - it is currently the ONLY test
that asserts orientation and position arbitration DURING an evasion, including the adversarial
180-degree facing pin. It writes the durable transcript `res://_dodge_authority_report.txt`, which is
evidence and is NOT proposed for deletion. Two defects were found and fixed in ITS OWN measurement
during this pass (the body was spawned inside `TestAttacker` so the evasion was physically blocked, and
travel was anchored to the frame the phase began rather than to the evasion's own first frame). Neither
was a production defect.

---

## Candidate: scenes/diagnostics/dodge_authority_probe_debug.tscn

Status: Candidate for manual deletion

Reason:
Entry scene for the temporary Dodge movement-authority diagnostic above.

Replacement:
Nothing.

Used By:
Nothing.

Safe To Delete:
Uncertain

Date Flagged:
2026-09-13

Notes:
Delete only together with its script, or the script loses its entry point.

---

## Evidence (NOT a deletion candidate): res://_dodge_authority_report.txt

Status: Keep. Evidence, not a cleanup candidate.

Reason:
Durable transcript written by `dodge_authority_probe_debug.gd` on finish - the full 80-line run behind
roadmap section 8N. The Output panel keeps a bounded recent-message list and truncates a long run, so
the transcript is kept on disk rather than only in a console that has already scrolled.

Safe To Delete:
No. Regenerated by a probe run, but it is the pass's evidence.

Date Flagged:
2026-09-13

---

## Candidate: scripts/diagnostics/facing_marker_feedback_debug.gd

Status: Candidate for manual deletion

Reason:
Temporary presentation aid attached to the `FacingMarker` node under `Player` in
`res://scenes/test_environment.tscn` (roadmap sections 8O.13 / 8O.14). It reads `PlayerCombat.state` and
tints the amber marker so a committed attack is visible on the capsule. It exists ONLY because there is no
animation system yet (the presentation boundary recorded in 8G.2 item 3), so a swing is otherwise
invisible on the body.

Replacement:
A real animation system (Milestone 15). When attack animation arrives, the clip becomes the presentation
and this adapter is redundant along with the primitive facing markers it decorates.

Used By:
`scenes/test_environment.tscn` - the only scene that instances `FacingMarker` and assigns this script.

Safe To Delete:
Uncertain

Date Flagged:
2026-09-13

Notes:
STRICTLY READ-ONLY on gameplay. It reads the attack PHASE and writes exactly one thing: a material's
`albedo_color`. It never starts, cancels, delays, extends or redirects an attack, imposes no timing of its
own, and owns no gameplay state - the colour FOLLOWS the phase, never the reverse. It duplicates the
material on first use so it can never mutate a resource another node draws with. Delete together with the
facing markers, or the marker loses its swing feedback. Its colours are exported, so a re-tune needs no
code change.

---

## Recurring: case-mismatch import warnings (38 measured, 2026-09-14)

Status: RECURRING EDITOR/IMPORT ISSUE - NOT a deletion candidate. No file is proposed for removal.

Reason (recorded, not worked around):
`state:diagnostics` reports 38 warnings of one class while the editor is open:

    Case mismatch opening requested file
    'res://assets/environments/Sci-Fi Essentials Kit[Standard]/textures/...',
    stored as '.../Textures/...' in the filesystem.
    This file will not open when exported to other case-sensitive platforms.

Measured this pass across two third-party Unity kits:
`assets/environments/Sci-Fi Essentials Kit[Standard]/` and
`assets/environments/Modular SciFi MegaKit[Standard]/`. Something requests the textures directory
with a lowercase `textures/` while the on-disk folder is `Textures/`.

Replacement:
None. This is an already-imported third-party asset tree, not a superseded file.

Used By:
Nothing at runtime that this pass measured. The warnings do not block opening the project on
Windows; they would block an export to a case-sensitive platform.

Safe To Delete:
NOT APPLICABLE - this entry tracks a warning class, not a file.

Date Flagged:
2026-09-14

Notes:
Recorded rather than fixed. NOT verified: which code or resource requests the lowercase path, and
whether any scene actually depends on these textures. Do NOT "clean up" the asset folders to
silence this - renaming folders inside an imported Unity kit is exactly the change that breaks
imports. Fix the requesting path, not the asset.

---

## Process record: documentation consolidation pass (2026-09-14)

Status: RECORDED. Not a file entry.

What changed: this manifest gained a READ THIS FIRST block, a status vocabulary and an ENTRY
INDEX. The roadmap gained a `# CURRENT STATE - READ THIS FIRST` block, a DOCUMENT MAP and a
MILESTONE INDEX, and its stale "CURRENT TASK" / "CURRENT MILESTONE" / "NEXT MILESTONE" headings
were relabelled as HISTORICAL.

What did NOT change: no file was deleted, renamed or moved. No gameplay file was edited. No
milestone was started or authorised. No candidate's Safe To Delete value was upgraded. Every
candidate above was confirmed still present on disk.

Carried forward UNRESOLVED (recorded, not guessed): see section D of the ENTRY INDEX for the five
root-level `_*_report.txt` transcripts and `scripts/debug/`.

---

## MILESTONE 12 - TARGET LOCK-ON PASS - NEW FILES AND RECORDED CHANGES (2026-09-14)

Recorded at the moment of the work, per the file-hygiene rule. Recording is the action; deletion
stays manual. The scope record was written into the roadmap as section 8P BEFORE implementation.

### New gameplay file (NOT a deletion candidate)

- `scripts/player/targeting_component.gd` (`class_name TargetingComponent`). Gameplay, not
  diagnostic: it owns lock-on state - the candidate list, the current target and the acquire/cycle
  order - and nothing else. It reuses the project's EXISTING validity authority
  (`CombatParticipant.is_usable_target()` / `target_refusal()`) rather than adding a second one, reads
  defeat from the target's own defeat authority, and reads player death from `DeathComponent.is_dead()`.
  Wired as the `Targeting` node in `main.tscn`. It does not touch locomotion, stamina, combat damage,
  enemy AI or animation.

### New diagnostic files (cleanup candidates, delete with their scene)

- `scripts/diagnostics/targeting_probe_debug.gd` - deterministic probe covering acquire, cycle-left,
  cycle-right, wrap and round-trip, the declared look-yaw intent measured from both sides, camera
  framing / pitch / roll / hierarchy, and all four auto-release causes each counted separately.
- `scenes/diagnostics/targeting_probe_debug.tscn` - the probe's standalone entry scene.

### Recorded changes to existing files

- `scripts/input/cascadia_input.gd`: added `look_yaw_suppressed` (a gameplay-DECLARED intent, the
  established analogue of `mouse_look_enabled`), `set_look_yaw_suppressed()` /
  `is_look_yaw_suppressed()`, and `consume_target_cycle_left()` / `consume_target_cycle_right()`.
  `_update_look()` drops ONLY the horizontal stick component while the intent is set; mouse motion and
  the vertical stick are untouched. The layer never derives lock state and focus transitions never
  clear the intent.
- `scripts/core/game_actions.gd`: `TARGET_CYCLE_LEFT` / `TARGET_CYCLE_RIGHT` added to the TARGETING
  group and to `BUFFERED_ACTIONS`.
- `scripts/camera/third_person_camera.gd`: added `_frame_locked_target()` plus `lock_yaw_smoothing`.
  It yaws onto the locked target on the shortest arc, never writes pitch, keeps roll zero by
  construction, and only READS the lock. The rig hierarchy is unchanged.
- `project.godot`: `target_cycle_left` / `target_cycle_right` bound to joypad axis 2 at -1.0 / +1.0
  plus mouse wheel. Nothing new is bound to R, F8 or F9; `lock_on` is untouched.
- `main.tscn`: added the `Targeting` node.
- `project.godot.bak`: re-written by the engine when project settings were saved. Pre-existing tracked
  candidate (see its own entry); no action needed, recorded so the change is not a surprise.

### Measured result (this pass)

`targeting_probe_debug`: `RESULT: ALL CHECKS PASSED (78)`, 0 debugger errors. The probe leaves the
arena as it found it: no arena actor damaged or defeated, carried balance unchanged, `awards`
unchanged, no lock and no look intent left held.

### Probe defects found and fixed in THIS pass (all three in the probe, none in the module)

- `_spawn_target()` pre-registered its temporary actor with `CreditLedger.handle_defeat()` expecting
  that to BLOCK a later reward. It does not: that call refuses and returns BEFORE `_rewarded[id]` is
  set, and the ledger re-scans the damageable group every physics frame, so a defeated temporary actor
  WOULD have been paid and the cleanup assertions WOULD have failed. Replaced with
  `EnemyDeathComponent.restore_defeated(true)`, which sets the authoritative defeated state WITHOUT
  emitting `defeated` - the documented reason Milestone 10 uses it for loads, and what makes it safe
  for a probe to reach the defeated state without minting Credits.
- The look-intent stick measurement was taken WHILE a lock was held, so TWO yaw authorities were active
  at once (the stick, and the rig framing the target). It reported a FALSE FAILURE of 0.8644 deg that
  was entirely the framing transient - the rig's yaw had been restored off-target and framing pulled it
  back. The measurement is now taken with no lock held, with `is_framing_lock()` asserted false; the
  re-run measures exactly 0.0000 deg. The lock is re-acquired immediately for the mouse and framing
  checks.
- `_resolve()` resolved the camera rig BEFORE assigning `_camera`, and `_find_camera_rig()` returns null
  when `_camera` is null - so the rig could never be found and the probe aborted before running a
  single check (`1 of 0 FAILED`).

### Recurring issue re-confirmed (NOT a new defect)

`state:diagnostics` reported 2 script errors during this pass:
`Cannot find member "TARGET_CYCLE_LEFT" / "TARGET_CYCLE_RIGHT" in base "GameActions"` at
`scripts/input/cascadia_input.gd` lines 396 and 400, scope `open_script_buffers`. Both constants ARE
present on disk in `game_actions.gd` (lines 60-61) AND the probe exercised BOTH actions successfully
at runtime, so this is the stale open-buffer linter false positive recorded above, not a real error.

### Documentation corrections carried out in the same pass

- The two duplicate `8M.15` / `8M.16` headings are renumbered to `8M.17a` / `8M.17b` (the file's own
  suffix pattern, as used by `8M.21a` / `8M.21b`), with every cross-reference updated. The two notes
  that recorded the collision as "left to manual review" now record it as RESOLVED.
- The stale header comment in `scripts/player/player_combat.gd` that claimed "Stamina cost is
  deliberately NOT implemented" while the same file charges it was corrected.
- The inverted `float(+)/sunk(-)` label in `scripts/diagnostics/grounding_probe_debug.gd` was
  corrected: negative means the collider bottom is BELOW the surface (sunk), positive means above it.

---

## MILESTONE 13 - MINIMAL UI (HUD, LOCK-ON INDICATOR, PAUSE, SAVE/LOAD CONTROLS) (2026-09-14)

Recorded at the moment of the work, per the file-hygiene rule. Recording is the action; deletion
stays manual. Roadmap record: section 8Q.

### New SHIPPED UI files (NOT deletion candidates)

These are the shipped game's interface, not tooling. They are recorded here so the inventory is
complete and so a future reader does not mistake them for cleanup candidates.

- `scripts/ui/game_hud.gd` (`class_name GameHUD`) - the minimal HUD: carried Credits, player Health
  and player Stamina. Owns NO gameplay value; it declares no `credits`, `health` or `stamina` field
  and stores only the text it is already displaying. Reads `CreditLedger.get_credits()`,
  `HealthComponent.current_health` and `StaminaComponent.current_stamina`, and connects each owner's
  own change signal. Every Control is `MOUSE_FILTER_IGNORE` because attacks are bound to MOUSE BUTTONS.
- `scripts/ui/lock_on_indicator.gd` (`class_name LockOnIndicator`) - a presentation marker driven by
  `TargetingComponent`'s signals. It is hidden while unlocked and on ALL FOUR release causes, and it
  reads lock state without ever writing it. `TargetingComponent` remains the only lock authority.
- `scripts/ui/pause_menu.gd` (`class_name PauseMenu`) - pause plus the save/load controls. Pause is
  `get_tree().paused = true` and nothing else. Owns one boolean derived from the tree plus its own
  visibility; it calls the existing `GameStateSave` and displays the `Result` code that service
  RETURNS, so a refusal can never be shown as a success. The panel is `visible = false` while unpaused
  and only its Buttons take `MOUSE_FILTER_STOP`, and only while open.

### New diagnostic files (cleanup candidates, delete with their scene)

- `scripts/diagnostics/ui_hud_probe_debug.gd` - deterministic probe for the UI pass. It drives REAL
  Escape presses and REAL Button signals rather than calling shortcuts, asserts each owner value AT
  REST as well as after a change, exercises all four lock-on release paths through the indicator, and
  proves a load leaves the HUD showing the RESTORED value rather than a stale one. Re-run result:
  `RESULT: ALL CHECKS PASSED (114)`.
- `scenes/diagnostics/ui_hud_probe_debug.tscn` - the probe's standalone entry scene.
- `_ui_hud_probe_report.txt` - the probe's durable transcript, written on finish under the same
  convention as `_focus_probe_report.txt`. Overwritten by each run; it is regenerable evidence, so it
  is a low-value cleanup candidate rather than a record worth preserving.

### Recorded changes to existing files

- `main.tscn`: added the `GameHUD` (CanvasLayer), `LockOnIndicator` (Node3D) and `PauseMenu`
  (CanvasLayer) nodes with their ext_resources.
- `scripts/player/player_controller.gd`: the carried-over ORIENTATION tweak - while a lock is held and
  no committed action owns the body, the body turns toward the locked target. A committed action
  (dodge, backstep, attack, parry) keeps its own facing for its whole duration and is never overwritten
  by the lock, per the project's recorded MOVEMENT AUTHORITY rule. With no lock, orientation is exactly
  as it was.
- `scripts/diagnostics/save_load_debug_controls.gd`: moved DOWN out of the HUD's top-right corner, and
  the panel now toggles with the SAME key that toggles the other debug overlays, so one press clears
  the whole debug layer. Direct fix for the user's report that the panel sat over the Credits readout.
- `scripts/diagnostics/focus_input_routing_probe_debug.gd`: aligned with the new Escape contract, and
  two measurement-integrity fixes (below).

### Process defects found and fixed this pass (recorded, not worked around)

- THE PROBE PASSED WHILE THE SHIPPED GAME WAS WRONG, and this is the most important entry here.
  `game_hud.gd` only refreshed on owner signals, but Godot runs `_ready()` in TREE ORDER and
  `main.tscn` places the HUD BEFORE `TestEnvironment`. The HUD therefore read Health and Stamina
  before those components had run their own `_ready()`, which is where they reset themselves to full;
  the `health_changed` emission went into a signal with no listener, the HUD then connected and
  correctly stood its per-frame fallback down, and the display kept `0 / 100` indefinitely. Seen on
  screen as `HEALTH 0 / 100` beside a combat overlay reading `player 100/100`. Fixed by refreshing once
  at the moment the owner connections land. MEASURED LESSON: every HUD assertion measured a CHANGE, so
  a display that started stale and caught up on the first damage event satisfied all 111 of them. Three
  at-rest assertions were added to the probe (now 114), because a change-only assertion cannot see this.
- TWO YAW AUTHORITIES IN ONE MEASUREMENT, AGAIN. `focus_input_routing_probe_debug` measured "mouse
  motion does NOT turn the camera while the cursor is free" while Milestone 12's targeting module was
  left holding a lock from its own delivery check, so the rig was ALSO framing a target. The reading was
  a real 28.4337 deg that belonged to the framing, not the mouse. The delivery check now silences the
  gameplay consumer while it measures (the same pattern `fkey_host_ownership_probe_debug` uses), and the
  lock is explicitly released and asserted before the camera phase. Re-measured: exactly 0.0000 deg.
  This is the THIRD instance of this class in the project (see `targeting_probe_debug`'s 0.8644 deg).
- A probe expectation was internally inconsistent: `ui_hud_probe_debug` asserted stamina DID advance
  after a drain while the tree was expected to be paused. Stamina's `regen_delay` is 0.8 s, so the
  measurement also had to outlive that delay rather than assume a short wait. Reordered so the
  drain happens while playing and the regeneration is measured on resume.

### Documentation corrections carried out in the same pass

- The five pre-existing root `_*_report.txt` transcripts previously carried status UNRESOLVED at path
  level. They are RESOLVED as a class: each is a `REPORT_PATH` const opened `FileAccess.WRITE` by its
  own probe, so each is overwritten by the next run of that probe and is regenerable evidence rather
  than a preserved record. Nothing in the project reads any of them.
- The Escape contract in `.summerrules` now records that Escape PAUSES ON ITS FIRST PRESS, amending the
  earlier reading that its only job was to own `mouse_look_enabled`.

---

## NEW RUN RESET-STATE FIX (2026-09-14, reported by the user after the M13 playtest)

Recorded at the moment of the work, per the file-hygiene rule. Recording is the action; deletion stays
manual.

### The defect, as reported and as found

The user reported that New Run did not reset the world: it should move the player to the spawn point,
reset player state, respawn the arena's enemies, clear defeated/invalid target state, release any held
lock, and leave the HUD showing the reset values.

`GameStateSave.new_run()` reset the carried balance, minted a new run identity and deleted the save file
- and touched NO ACTOR. So a New Run left the player dead where it fell, every killed enemy still
defeated with its presentation still showing, and a lock still held on a target from the previous run.
The number restarted; the world did not.

### What was changed, and why each change is where it is

- `scripts/core/game_state_save.gd` - `new_run()` now calls a new `_reset_world()`, the MIRROR of the
  existing `_restore_world()`: a load puts the world back to a RECORDED snapshot, a new run puts it back
  to the AUTHORED starting state. It goes through each owner's own API - `DeathComponent.reset_playable_state()`
  for the player, `HealthComponent.reset()` and `EnemyDeathComponent.restore_defeated(false)` per enemy,
  each attacker's own `reset()`, and `TargetingComponent.release()` - so it owns nobody's state twice and
  cannot mint a reward. `restore_defeated()` deliberately does NOT emit `defeated`, which is exactly why
  reviving an enemy here pays nothing.
- `scripts/core/game_state_save.gd` - added `_spawn_transforms`, captured ONCE at boot by a DEFERRED
  call. The deferral is load-bearing: `HealthComponent._ready()` is what joins the damageable group and
  this node sits BEFORE `TestEnvironment` in `main.tscn`, so an immediate call would see an EMPTY group.
  A recorded yardstick is required rather than reading the scene, because `TestAttacker` pursues the
  player and its transform at reset time is wherever the fight left it.
- `scripts/player/targeting_component.gd` - `ReleaseReason.RUN_RESET` added, so a run reset is filed
  under its OWN cause and is not confused with the four invalidation paths or a manual release.
- `scripts/diagnostics/ui_hud_probe_debug.gd` - Phase 6 added: dirty the world, assert it is dirty, run
  New Run twice, assert every reset claim. Probe now 142 checks, up from 114.
- `scripts/diagnostics/game_state_overall_probe_debug.gd` - its `_make_payload()` fixture CORRECTED. It
  built `"player": {"alive": true}` and nothing else, which predates the snapshot contract; the loader
  refuses a player block with no `position`, so the fixture failed as `missing-field` and the post-load
  stages could never run. It now derives the block from the live player. THIS WAS A PRE-EXISTING STALE
  FIXTURE, not a consequence of the New Run work - the failure reproduced before the reset change and
  the log names the fixture, not the service.

### Process defects and probe flaws found this pass, recorded rather than worked around

- MY OWN PROBE ASSERTION WAS WRONG TWICE BEFORE IT WAS RIGHT, both times by asserting something the
  game is not supposed to do. (a) It tried to LOCK ON to an enemy AFTER killing it - a defeated actor is
  deliberately an invalid target, so the check failed on its own premise. (b) It then tried to hold a
  lock while the player was DEAD, but player death is one of the four release causes, so a held lock
  there is impossible by design. Restructured: dead player and defeated enemy first, then a lock on a
  LIVE enemy, then New Run.
- `ui_hud_probe_debug`'s cleanup asserted `awards == awards_start + 1`, which was true before New Run
  touched the world and is false by design afterwards - A FIXTURE THAT DEMANDS A RESET NOT RESET. It now
  asserts the fresh-boot baseline (counter zeroed, balance at the documented starting value).
- `game_state_overall_probe_debug`'s stale fixture (above) - the SAME CLASS as the schema-3 version-pin
  defect already recorded in M10: a fixture written against an older shape stops testing its own claim
  once the shape moves, and fails as the wrong error, which reads like the code under test is broken.
- A FLAKY CHECK, recorded and NOT claimed fixed: `targeting_probe_debug`'s "the camera FOLLOWS when the
  target moves" FAILED once at 10.62 deg off centre and PASSED on an immediate re-run with NO CODE CHANGE
  (0.01 deg; tolerance 3.0 deg over 45 frames). The only edit made to that file this pass was an inert
  enum append, which cannot affect camera framing. Recorded as intermittent rather than resolved.
- The debug save/load panel and the new HUD Credits panel were both anchored top-right, so the debug
  panel COVERED the Credits readout. The panel now sits below it, and toggles with the existing
  `toggle_debug_overlay` (F1) alongside the other debug overlays.

### Verification

`ui_hud_probe_debug` **ALL CHECKS PASSED (142)**; `focus_input_routing_probe_debug`,
`targeting_probe_debug` (78), `retarget_state_probe_debug`, `game_state_overall_probe_debug`,
`game_state_world_restore_probe_debug`, `game_state_save_load_probe_debug`,
`game_state_mixed_state_probe_debug` and `game_state_death_loop_probe_debug` all
**ALL CHECKS PASSED**; the shipped `main.tscn` boots at 0 runtime and 0 debugger errors. NOT
human-played - the user's read of the New Run flow is what accepts it.

**ACCEPTED BY THE USER 2026-09-14 on that read.** The acceptance covered the HUD, the lock-on
indicator, pause/resume, save/load, loaded-state feedback, target cycling, lock-on orientation and the
debug panel toggle. Milestone 13 is CLOSED and must not be reopened without a genuine regression.

---

## MILESTONE 14 - ENEMY HEALTH BARS (2026-09-14)

### New gameplay-presentation file (NOT a deletion candidate)

- `res://scripts/ui/enemy_health_bars.gd` (`class_name EnemyHealthBars`) - NEW. Draws a small bar over
  each TRACKED enemy: revealed by that enemy's OWN `damaged` signal, held for `hold_seconds` (4.0 s) or
  while that enemy is the locked target, and hidden when neither is true. It owns NO health value, no
  aggro state and no lock state - it reads `HealthComponent.health_fraction()` and
  `TargetingComponent.get_current_target()` fresh each frame, and stores only its reveal timestamps and
  the Controls it draws. The player is deliberately EXCLUDED from tracking, because the player already
  has the HUD's own health bar.

### Recorded as a deletion candidate (NOT deleted)

- `res://scripts/ui/enemy_health_bars.gd` - the module itself is intended to be PERMANENT presentation
  and is NOT a cleanup candidate. Recorded here only so the file is accounted for. Its
  `is_engaged()` seam is the documented hand-off point for future enemy AI.

### Process defects found this pass (recorded, not worked around)

- A PROBE CANNOT BE HANDED A FREED NODE. `ui_hud_probe_debug` asserted `bars.is_tracked(enemy)` AFTER
  `_destroy(enemy)`, and a typed `Node3D` parameter rejects a previously-freed Object - so the probe
  CRASHED at teardown (`Invalid type in function 'is_tracked' ... previously freed`) rather than
  measuring. Fixed by counting tracked entries before and after the free, which observes the same drop
  without naming the dead instance. The component was never at fault; this was the probe's own bug.
- Same class as the earlier stale fixtures: an assertion written against an object's lifetime rather
  than against the observable change.

### Verification

### Milestone 15 - shared combatant foundation (2026-09-14)

New artifacts this pass (all recorded as RETAIN unless noted):

| Artifact | Status | Note |
| -------- | ------ | ---- |
| `scripts/actors/actor_state.gd` | RETAIN | The shared actor contract. Owns no state; reads every answer from its owner. |
| `scripts/actors/actor_profile.gd` | RETAIN | Archetype IDENTITY data: health, mortality, targetability, reaction. |
| `scripts/combat/enemy_attack_profile.gd` | RETAIN | Archetype ATTACK data: timing, damage, range, cadence. |
| `scripts/combat/health_reaction_component.gd` | RETAIN | Shared hit-reaction state (flinch / stagger). Inert by default (threshold 0.0). |
| `scripts/npc/passive_npc.gd` + `scenes/actors/passive_npc.tscn` | RETAIN | First NPC archetype. |
| `resources/actors/civilian_npc.tres` | RETAIN | Civilian archetype data. NOW ASSIGNED and measured live (see defect 6). |
| `resources/enemies/test_attacker_attack.tres` | RETAIN | Arena attacker archetype. Assigned and verified. |
| `resources/enemies/heavy_brute_attack.tres` | RETAIN | Second variant archetype. NOW ASSIGNED to `HeavyBrute` and measured live. |
| `scenes/actors/heavy_brute.tscn` | RETAIN | Second enemy variant. The SAME `scripts/combat/enemy_attacker.gd` script as `TestAttacker`; differs only by its assigned archetype resource. |
| `scripts/diagnostics/actor_contract_probe_debug.gd` + its .tscn | CANDIDATE FOR DELETION | Temporary diagnostic. Writes `res://actor_contract_probe_report.txt`. Delete together. |
| `res://actor_contract_probe_report.txt` | CANDIDATE FOR DELETION | Probe output, regenerated each run. |

Defects found and fixed THIS pass, recorded because each was a real boot or truth failure:

1. **`scenes/actors/test_attacker.tscn` was corrupted by incremental `strReplace`** - six duplicate
   `Reaction`/`ActorState` node blocks and duplicated `ext_resource` ids. The scene failed to parse,
   and the editor then REFUSED to reload it from disk (error 43), keeping the broken in-memory copy.
   Repaired with a single whole-file write. LESSON: build a scene with one whole-file write, never
   node-by-node into an existing file.
2. **`ActorState` called a nonexistent method** (`_get_actor()`; the method is `_resolve_actor()`),
   which failed the whole script to parse.
3. **THE BOOT FAILURE (the reported defect).** `scenes/actors/passive_npc.tscn` put an
   `extends CharacterBody3D` script on a plain `Node` named `Npc`, and the actual `CharacterBody3D`
   root carried NO script. Godot cannot apply a body script to a Node, so the NPC scene failed to
   instantiate, which failed `test_environment.tscn`, which failed `main.tscn`. This is what "the
   game does not boot" was. Fixed by moving the script to the root body.
4. **`passive_npc.gd` referenced the brand-new `ActorProfile` type** while the editor had not yet
   registered it, so that script failed to parse DURING AUTHORING. That was a registration-timing
   symptom of writing these files inside one pass, NOT the cause of the boot failure - and the
   `preload` workaround adopted for it introduced a worse, silent defect. See defect 6.
5. **`ActorState` had no `can_act()`**, so the contract could not answer the question the probe (and
   Phase 3 of the brief) requires. Added, DELEGATING to `CombatParticipant.can_act()` so there is
   still exactly one authority.
6. **THE SILENT ONE - found by the probe, not by inspection.** Once defect 3 was fixed and the game
   booted, the NPC still ran with **no archetype at all**. `profile` was declared as
   `@export var profile: <preload() const type>`, and an exported property typed by a `preload()` CONST
   does NOT register as a bindable property - so the scene's `profile = ExtResource(...)` line was
   DROPPED at load with no error anywhere. The source scene's inspector showed the resource bound while
   the arena's instance showed `null`. Declaring the property with the global `class_name`
   (`@export var profile: ActorProfile`) fixed it - the SAME mechanism `EnemyAttacker` already uses for
   `EnemyAttackProfile`. LESSON: a `preload`-const export type can silently fail to bind, and only a
   BEHAVIOURAL check caught it; the class-registration workaround that caused it is not needed.

Also recorded: the editor console in this build does NOT reliably surface a running game's `print()`
output. Nine `_*_report.txt` files already exist at the project root for that reason. Do not diagnose
a probe by its console output alone - read its report file.

`ui_hud_probe_debug` **RESULT: ALL CHECKS PASSED (165)** - up from 142, the 23 new checks covering:
the player is NOT tracked, no bar at rest, damage reveals, the fill width equals the owner's real
health fraction (47.00 px measured against 47.00 px expected), the lock holds a bar past the damage
window, releasing the lock lets it hide, hiding is counted exactly once, and a freed enemy's bar is
dropped with it. The shipped `main.tscn` boots at 0 runtime and 0 debugger errors. NOT human-read:
bar size, position, colour and whether the 4 s hold feels right are the user's call.

---

## 2026-09-14 - Milestone 15 (shared combatant foundation): artifacts recorded

### A. New cleanup candidates - development diagnostics

| Artifact | Status as recorded |
| -------- | ------------------ |
| `scripts/diagnostics/actor_contract_probe_debug.gd` + `scenes/diagnostics/actor_contract_probe_debug.tscn` | CANDIDATE FOR DELETION (new this pass; the contract probe. Delete the pair together with its report file) |
| `actor_contract_probe_report.txt` (project root) | CANDIDATE FOR DELETION (probe output; same family as the existing `_*_report.txt` scratch files) |
| `scripts/diagnostics/new_run_reset_probe_debug.gd` + its `.tscn` + `new_run_reset_probe_report.txt` | CANDIDATE FOR DELETION (new this pass; proves New Run restores every actor. Delete the trio together) |
| `scripts/diagnostics/player_death_reset_probe_debug.gd` + its `.tscn` + `player_death_reset_probe_report.txt` | CANDIDATE FOR DELETION (new this pass; proves the player-death encounter reset. Delete the trio together) |

### C. 2026-09-14 - New Run / player-death reset regression pass

Two behaviour FIXES, both in existing production files, both measured:

1. **`DeathComponent._reset_attackers()` reset only ONE attacker** - it fell back to
   `get_first_node_in_group(GROUP_ATTACKER)`, so with two enemy variants only one was reset and which
   one depended on unspecified group order. Now enumerates the group; an authored `attacker_path`
   still means "reset exactly this one". ACTION state only, because the same method runs on a load.
2. **Dying now resets the ENCOUNTER** - new `DeathComponent._restore_arena_actors()` returns every
   other combat actor to alive at full health. This deliberately REVERSES the earlier recorded
   decision that `EnemyDeathComponent` must not be cleared from the player-death circuit. It goes
   through each owner's own API and does not emit `defeated`, so it cannot pay a Credit reward.
3. **`PassiveNpc` cancels a pending respawn** when the actor is already alive again, so the arena
   reset or a load cannot be followed by its own timer firing a second restoration.

NPC health bars were NOT touched: no change to `enemy_health_bars.gd`, no `can_be_targeted` gate added.
A damaged NPC still reveals a bar, as intended.

The probe follows the existing `*_debug_*` naming and lives under `scripts/diagnostics/`, so it obeys
the diagnostic-material rule in `.summerrules`.

### B. New PRODUCTION files (NOT cleanup candidates - recorded for completeness)

Added this pass, all retained:

- `scripts/actors/actor_profile.gd` (`ActorProfile`) - identity/lifecycle archetype data
- `scripts/actors/actor_state.gd` (`ActorState`) - the shared animation-facing contract
- `scripts/combat/enemy_attack_profile.gd` (`EnemyAttackProfile`) - attack archetype data
- `scripts/combat/health_reaction_component.gd` (`HealthReactionComponent`) - hit reaction
- `scripts/npc/passive_npc.gd` (`PassiveNpc`) + `scenes/actors/passive_npc.tscn` - first NPC archetype
- `resources/actors/civilian_npc.tres`, `resources/enemies/test_attacker_attack.tres`

### C. Recurring process/editor problems - NEW ENTRIES

**C1. Repeated `strReplace` on a `.tscn` corrupted `test_attacker.tscn` (RESOLVED).**
Nine successive `strReplace` calls writing new nodes into `scenes/actors/test_attacker.tscn` produced
a file with SIX duplicate `Reaction`/`ActorState` node blocks and duplicated `ext_resource` ids
(`8_reaction`, `9_actorstate` repeated six times). Godot refused to load it:

    Parse Error: Parse error. [Resource file res://scenes/actors/test_attacker.tscn:92]

and the editor then refused to reload it from disk at all, keeping the broken in-memory scene and
blocking the save. Repair: ONE complete `writeFile` of the whole scene. Lesson, recorded so it is not
rediscovered: **add several nodes to a scene with a single whole-file write, not with one
`strReplace` per node.**
Related, and separately useful: `InstantiateScene`/`SetProp` batches against a scene the editor is
not currently editing fail with `scene_target_inactive`; OpenScene the target first (the destination
is still declared by the top-level `scenePath`).

**C2. The game halts at a debugger breakpoint and cannot execute (OPEN, environment).**
Every launch this pass reported `is_breaked: true` with `session_active: true`. Consequence, measured
three times with a probe that writes an EARLY MARKER from `_ready()`: the marker file was never
created, no GDScript `print()` from any script reached the Output panel (not even the `[DAMAGE]`
lines `HealthComponent` emits with `debug_logging = true`), and `gameSnapshot` returned a blurred
magenta placeholder image rather than a viewport frame. Engine-level lines ("Welcome to Summer
Engine", the D3D12 device line) DID appear, so stdout capture works - it is script execution that is
suspended. **No runtime claim from this pass is verified.** Clearing the breakpoint is a UI action
outside this project's tooling.

### D. Stale-analysis noise reconfirmed (do not chase)

`state:diagnostics` reported three `open_script_buffers` entries that are NOT real defects, each
contradicted by a direct read: `GameActions.TARGET_CYCLE_LEFT` / `TARGET_CYCLE_RIGHT` ARE declared
(`game_actions.gd:60-61`), and `ActorProfile` IS a valid global class
(`scripts/actors/actor_profile.gd:1`). Per-file `state:script-errors` returned **0** for every file
this pass touched. Consistent with the existing `open_script_buffers` entry at the top of this file.

---

## 2026-09-14 - Milestone 16 (animation adapter): artifacts recorded

### A. New cleanup candidates - development diagnostics

| Artifact | Status as recorded |
| -------- | ------------------ |
| `scripts/diagnostics/animation_adapter_probe_debug.gd` + `scenes/diagnostics/animation_adapter_probe_debug.tscn` | CANDIDATE FOR DELETION (new this pass; the animation-adapter contract probe. Delete the pair together with its report file) |
| `animation_adapter_probe_report.txt` (project root) | CANDIDATE FOR DELETION (probe output; same family as the existing `_*_report.txt` scratch files) |

### B. New PRODUCTION files (NOT cleanup candidates - recorded for completeness)

| Artifact | Status | Note |
| -------- | ------ | ---- |
| `scripts/animation/animation_adapter.gd` | RETAIN | MILESTONE 16's deliverable. The FIRST consumer of `ActorState`. Reads the contract, owns no gameplay state, writes no mesh transform or material. Its placeholder driver is the single seam a real animation system replaces. |
| `Animation` node inside `scenes/test_environment.tscn` (`Player`), `scenes/actors/test_attacker.tscn`, `scenes/actors/heavy_brute.tscn`, `scenes/actors/passive_npc.tscn` | RETAIN | One adapter per actor, all running the SAME script. Enemy variants differ by PROFILE, not by animation code. |

### C. Defect found and fixed THIS pass

`animation_adapter_probe_debug` asserted the adapter covered **FOUR different actor KINDS**. Cascadia
has exactly THREE actor kinds (player / enemy / npc) while the arena has FOUR actors, because two of
them are enemy ARCHETYPES - so the check could only ever have failed, and did (`1 CHECK(S) FAILED
(52 passed)`). It now asserts that every KIND is covered AND that BOTH enemy archetypes are driven by
the one shared adapter. Re-run: `RESULT: ALL CHECKS PASSED (54)`.

### D. Scene-editing hazard reconfirmed (do not repeat)

`AddNode` collided with a STALE in-memory node from an earlier failed batch and created
`Animation_1` beside an existing `Animation` in `scenes/actors/test_attacker.tscn` and
`scenes/actors/heavy_brute.tscn`. Both stray nodes were removed with `RemoveNode` and the scenes
re-read from disk to confirm exactly one adapter node each. LESSON, and it is the SAME lesson as the
Milestone 15 `test_attacker.tscn` corruption: after any batch that PARTIALLY fails, re-read the scene
from disk before issuing the next mutation, and prefer `OpenScene` first so the editor's in-memory
copy matches what is on disk.

---

## 2026-09-14 - Milestone 18 (combat feedback, interruption, death credits): artifacts recorded

### A. New cleanup candidates - development diagnostics

| Artifact | Status as recorded |
| -------- | ------------------ |
| `scripts/diagnostics/combat_feedback_probe_debug.gd` + `scenes/diagnostics/combat_feedback_probe_debug.tscn` | CANDIDATE FOR DELETION (new this pass; the probe that MEASURES hitstop, attack interruption and the death credit reset at runtime. Delete the pair together. It writes NO report file - its output is console only, so there is no `_report.txt` to pair with it) |
| `scripts/diagnostics/live_combat_credit_probe_debug.gd` + `scenes/diagnostics/live_combat_credit_probe_debug.tscn` | CANDIDATE FOR DELETION (Milestone 18 follow-up, PREVIOUSLY UNRECORDED - recorded now. The probe that measures the same three behaviours through the REAL player attack path with nothing stood down, which `combat_feedback_probe_debug` could not, because that one stands every enemy down and opens the hitbox by hand. Delete the pair together. Console only, no `_report.txt`.) |
| `scripts/diagnostics/player_attack_reach_probe_debug.gd` + `scenes/diagnostics/player_attack_reach_probe_debug.tscn` | CANDIDATE FOR DELETION (new this pass, section 8U.6; the probe that measures the player's REAL attack at each archetype's OWN `Locomotion.stopping_distance()` rather than a hard-coded 1.8 m. Delete the pair together. Console only, no `_report.txt`.) |

## 2026-09-14 - UI cleanup and layout unification pass (section 8W): artifacts recorded

### A. New production file

| Artifact | Status | Note |
| -------- | ------ | ---- |
| `scripts/ui/screen_regions.gd` (`class_name ScreenRegions`) | RETAIN | THE ONE LAYOUT AUTHORITY for every persistent panel. Owns the reserved screen regions as anchor fractions, the CanvasLayer z-order constants, and the host-VBoxContainer-per-region model. Also owns `adaptive_columns()` / `bound_to_region()` (the shared reflow and no-clip helpers) and `region_pixel_size()`. This SUPERSEDES the ad-hoc placement that used to live in each panel script. |
| `scenes/test_environment.tscn` - `Markers/*` Label3D `outline_size = 6` | RETAIN | World-space debug labels given an outline so they stay legible against the arena. Light touch only: no label was moved, renamed or removed. |

### B. Refactored in place (NOT new files - the existing panels, re-pointed at the shared regions)

| Artifact | Status | Note |
| -------- | ------ | ---- |
| `scripts/ui/game_hud.gd` | RETAIN | Credits and vitals now join reserved regions instead of hand-set anchors and offsets. |
| `scripts/diagnostics/save_load_debug_controls.gd` | RETAIN | The hand-tuned `offset_top = 62` dodge is GONE; the panel is the second child of the shared top-right stack. |
| `scripts/diagnostics/combat_debug_overlay.gd` | RETAIN | Its per-frame viewport maths and `_reclamp` were removed; the region places it. |
| `scripts/diagnostics/death_presentation_debug.gd` | RETAIN | Centred by its region; no self-positioning. |
| `scripts/diagnostics/input_debug_overlay.gd` | RETAIN | Split into two reflowing columns inside a region bound (8W.5). |
| `scripts/ui/enemy_health_bars.gd` | RETAIN | Layer now read from `ScreenRegions.LAYER_ENEMY_HEALTH_BARS` instead of a hardcoded 2. |

### C. New cleanup candidates - development diagnostics

| Artifact | Status as recorded |
| -------- | ------------------ |
| `scripts/diagnostics/input_panel_layout_probe_debug.gd` + `scenes/diagnostics/input_panel_layout_probe_debug.tscn` + `input_panel_layout_probe_report.txt` | CANDIDATE FOR DELETION (new this pass; the probe that MEASURES the INPUT FOUNDATION panel's geometry, reflow decision and row count at runtime. Delete all three together.) |

---

## 2026-09-14 - Milestone 19 (death-drop loop): artifacts recorded

### A. New cleanup candidates - development diagnostics

| Artifact | Status as recorded |
| -------- | ------------------ |
| `scripts/diagnostics/death_drop_credit_probe_debug.gd` + `scenes/diagnostics/death_drop_credit_probe_debug.tscn` | CANDIDATE FOR DELETION (new this pass, section 8V; the probe that MEASURES the death-drop loop end to end - drop, revive, claim, one-stake rule, empty-pocket death, new run, load. Pair it with the report file below and delete all three together.) |
| `res://death_drop_credit_probe_report.txt` | CANDIDATE FOR DELETION (new this pass; the report written by the probe above. It is written because the console TAIL IS TRUNCATED - a measurement printed only mid-run can be missing from the transcript, so the probe routes its results to a file as well.) |

### B. New PRODUCTION files (NOT cleanup candidates - recorded for completeness)

| Artifact | Status | Note |
| -------- | ------ | ---- |
| `scripts/economy/credit_stake.gd` | RETAIN | MILESTONE 19's deliverable node (`class_name CreditStake`, group `credit_stake`). A world MARKER that displays a dropped stake and offers the claim. It owns no balance and never pays out: `CreditLedger.reclaim_stake()` is the only thing that moves Credits. Claims by DISTANCE only and never by `get_overlapping_bodies()` - see 8V for the measured reason. |
| `scenes/props/credit_stake.tscn` | RETAIN | The stake marker scene: an `Area3D` on layer 0 (detection only, it collides with nothing and nothing collides with it) with a `MeshInstance3D` readout and a `CollisionShape3D` sphere sized from `pickup_radius`. Placed ONCE in `scenes/test_environment.tscn` as `CreditStake`. |
| `CreditLedger` stake API in `scripts/economy/credit_ledger.gd` | RETAIN | The death-drop contract: `drop_on_death` (exported, default true), `has_stake()` / `stake_amount()` / `stake_position()`, `place_stake()` / `reclaim_stake()` / `clear_stake()`, the `stake_placed` / `stake_reclaimed` / `stake_lost` signals, and the `stakes_placed` / `stakes_reclaimed` / `stakes_lost` per-run counters. |

### B. New PRODUCTION files (NOT cleanup candidates - recorded for completeness)

| Artifact | Status | Note |
| -------- | ------ | ---- |
| `scripts/combat/hit_stop.gd` | RETAIN | MILESTONE 18's deliverable. Freezes the two PARTICIPANTS of a confirmed hit with `propagate_call` over `set_process` / `set_physics_process`. Never touches `process_mode`, `Engine.time_scale` or `get_tree().paused`. Owns no gameplay truth, no damage and no attack state. |
| `HitStop` node in `main.tscn` | RETAIN | ONE service, a DIRECT child of the game root and a sibling of `TestEnvironment`, so a participant's own freeze can never disable the clock that releases it. |
| `HitboxComponent.GROUP_HITBOX` in `scripts/combat/hitbox_component.gd` | RETAIN | New group constant, added so a confirmed-hit consumer enumerates hitboxes without a hard-coded scene path - the same resolution pattern the attacker, locomotion and health modules use. |

### C. Modified PRODUCTION files (recorded for completeness)

| Artifact | Change |
| -------- | ------ |
| `scripts/combat/enemy_attacker.gd` | Subscribes to its sibling `Reaction`'s `staggered` signal and cancels its OWN attack (`_connect_reaction` / `on_hit_received` / `interrupt_attack`). Also DEFERS uncommitted facing to a `Locomotion` sibling when one is present. |
| `scripts/economy/credit_ledger.gd` | Subscribes to the PLAYER's own `DeathComponent.GROUP_DEATH` circuit and resets the carried balance, `credits_earned` and the per-run reward history on death. Lifetime counters and live signal connections are deliberately left alone. |
| `scenes/actors/test_attacker.tscn` | `Reaction.stagger_threshold = 12.0` |
| `scenes/actors/heavy_brute.tscn` | `Reaction.stagger_threshold = 20.0` |
| `scripts/diagnostics/game_state_death_loop_probe_debug.gd` | Header and step-10 note updated: roadmap 8L.7's "carried Credits SURVIVE death" contract is SUPERSEDED by the user's decision. |

### D. Contract change recorded

Roadmap section 8L.7 explicitly recorded the OPPOSITE decision - that carried Credits SURVIVE the
player's death and reset - and `game_state_death_loop_probe_debug` pinned it in its header. The user
overruled it during this playtest: dying costs the run its carried Credits. `CreditLedger.on_player_death()`
now performs that reset, and the death-loop probe was updated to assert the new rule rather than left
pinning the old one. The full Soulslike drop-and-retrieve loop (a corpse to return to) is still NOT
implemented and remains deferred.

### E. Reported defect that was NOT a defect

The playtest report "hitstop does not work" was accurate in the most literal sense. A project-wide
search for `hitstop` / `hit_stop` / `hitStop` returned ZERO matches in any `.gd` or `.tscn`: there was
no hitstop, broken or otherwise. The only hit feedback in the project was a tweened damage number and a
`material_overlay` flash, neither of which has any time component. Recorded here so a later session does
not go hunting for a broken implementation that was never written.

### F. Benign tooling noise confirmed this pass (do not chase)

`state:diagnostics` reports three console errors that are ALL stale `open_script_buffers` analysis of
editor tabs. Each was re-checked OUTSIDE that scope, as the project rule requires:
`cascadia_input.gd:396` / `:400` (`TARGET_CYCLE_LEFT` / `TARGET_CYCLE_RIGHT`) - both constants exist at
`game_actions.gd:60-61`; and `hit_stop.gd:264` (`HitboxComponent.GROUP_HITBOX`) - the constant exists at
`hitbox_component.gd:24` AND the runtime proves it resolves, because hitstop demonstrably froze and
released during the probe. `state:script-errors` returns ZERO errors for every file this milestone touched.

---

## 2026-09-14 - Milestone 17 (minimal enemy engagement): artifacts recorded

STATUS: ACCEPTED BY THE USER 2026-09-14 after HUMAN PLAYTESTING. The user reported that human
testing shows the enemy engagement concept is implemented correctly, which satisfies this
milestone's manual-play criterion. That is the user's own first-hand result and it is the only
evidence in this project for how the behaviour READS in motion; everything else below is artifact
accounting and probe output from the pass that produced it, and neither kind substitutes for the
other.

### A. New cleanup candidates - development diagnostics

| Artifact | Status as recorded |
| -------- | ------------------ |
| `scripts/diagnostics/enemy_engagement_probe_debug.gd` + `scenes/diagnostics/enemy_engagement_probe_debug.tscn` | CANDIDATE FOR DELETION (new this pass; the enemy-engagement probe. Delete the pair together. It writes NO report file - its output is console only, so there is no `_report.txt` to pair with it) |

### B. New PRODUCTION files (NOT cleanup candidates - recorded for completeness)

| Artifact | Status | Note |
| -------- | ------ | ---- |
| `scripts/combat/enemy_locomotion.gd` | RETAIN | MILESTONE 17's deliverable. Owns ONLY an enemy body's horizontal velocity, its yaw while no attack is committed, and one engagement state (`IDLE` / `APPROACH` / `RETURNING`). Owns no combat truth, no attack phases, no damage and no defeat. |
| `resources/enemies/test_attacker_actor.tres`, `resources/enemies/heavy_brute_actor.tres` | RETAIN | The two archetypes' MOVEMENT records on the existing `ActorProfile` resource. Archetype difference stays DATA, so no per-archetype movement script exists. |
| `Locomotion` node inside `scenes/actors/test_attacker.tscn` and `scenes/actors/heavy_brute.tscn` | RETAIN | One `EnemyLocomotion` per enemy body, both running the SAME script, each seeded from its own `.tres`. |
| `detection_radius` on `resources/enemies/test_attacker_attack.tres` and `heavy_brute_attack.tres` | RETAIN | The one field `EnemyAttackProfile`'s own header had always earmarked for detection. 12.0 m for the arena attacker, 9.0 m for the brute. |

### C. Defects found and fixed THIS pass

1. **DUPLICATE `@export var locomotion_path` in `scripts/combat/enemy_attacker.gd`.** Two identical
   declarations landed, which is a GDScript PARSE ERROR - `Parse Error: Variable "locomotion_path"
   has the same name as a previously declared variable` - and it made the script fail to load
   entirely (`Failed to load script ... with error "Parse error"`), taking the whole attacker with
   it. Found by reading the file back and by the parse error in `state:diagnostics`; fixed by
   removing the duplicate declaration and its duplicated comment block.

2. **Three parse defects in the new probe**, all found by running it rather than by reading it:
   `_commit_max_speed` used but never declared; `Step.ARENA_RESET_CONFIRM` referenced before it was
   added to the `enum`; and `_attacker_health.is_dead()` called as a METHOD when `is_dead` is a
   `HealthComponent` PROPERTY. All three fixed; the probe then parsed clean and ran to completion.

3. **A measurement artifact in the probe's own AC10**, not a product defect. After the arena reset
   the attacker was reported 0.864 m off its mark. Cause: `TestAttacker` spawns 7 m from the player
   spawn, INSIDE its own 12 m detection radius, so on the frame after the reset it correctly
   RE-ENGAGES and walks off the mark. 2.6 m/s with acceleration over 25 physics frames is about
   0.86 m, which matches the measurement exactly. Fixed by measuring the restoration on the frame it
   happens and asserting re-engagement separately as the correct consequence. The brute stays on its
   mark in the same window because its spawn is outside its 9 m radius. Re-run: `ALL CHECKS PASSED`.

### D. Regression results recorded THIS pass (all re-run fresh, not carried over)

| Probe | Fresh result |
| ----- | ------------ |
| `enemy_engagement_probe_debug` (new) | `RESULT: ALL CHECKS PASSED` - run twice, identical |
| `actor_contract_probe_debug` | `ALL CHECKS PASSED (82)` |
| `new_run_reset_probe_debug` | `ALL CHECKS PASSED (32)` |
| `player_death_reset_probe_debug` | `ALL CHECKS PASSED (38)` |
| `grounding_probe_debug` | **CHANGED - see the roadmap's known-defects entry.** `TestAttacker` now PASSES at -0.001 (gravity from the new body physics settled it); `PassiveNpc` now FAILS at -0.139, reproduced identically on two consecutive runs. The NPC is authored at `X = -4, Z = 6` and `BoxShape_step14` is `Vector3(6, 0.14, 6)` centred at `X = -7`, so the step's east face is at exactly `X = -4` and the NPC stands on that EDGE - its collider bottom rests 0.139 m up while the probe's downward ray down its centre hits the open floor. The failing ACTOR therefore changed. MEASURED: Milestone 17 touched neither `passive_npc.gd`, `passive_npc.tscn` nor any step geometry, and both readings are negative, so this is not the same check failing on the same actor. NOT ESTABLISHED: whether the NPC also floated before this pass. The roadmap recorded only ONE failure (TestAttacker), but that note may have been a partial record rather than a complete one, and no earlier full grounding transcript has been found, so it is NOT claimed either way here. Left UNFIXED and recorded, per the project's rule against solving geometry problems during an unrelated pass. |
| `animation_adapter_probe_debug` | `ALL CHECKS PASSED (54)` - re-run fresh, matches its historical count |
| `targeting_probe_debug` | `ALL CHECKS PASSED (78)` - re-run fresh, matches its historical count. All six regression probes in the brief were therefore re-run, not carried over. |

### E. Persistence gap EXPOSED (not introduced) by this milestone

Enemy POSITION is not restored by a LOAD. `GameStateSave._capture_world()` records health, defeated
and paid, and no transform, so loading a game leaves enemies wherever the fight left them rather
than on their spawn marks. NEW RUN is unaffected (`_spawn_transforms`) and the player-death
encounter reset is unaffected (the locomotion component's own recorded mark). Recorded because
movement makes the gap observable for the first time; deliberately NOT addressed in this milestone,
which forbade enemy-position save/load.

---

## MILESTONE 21 SLICE B - ANIMATION CONTENT PIPELINE - NEW FILES AND RECORDED CHANGES (2026-09-15)

Recorded at the moment of the work, per the file-hygiene rule. Recording is the action; deletion
stays manual.

### New gameplay/presentation files (NOT deletion candidates)

- `scenes/actors/player_visual.tscn` (`PlayerVisual`) - the player's VISUAL child. Three nodes: the
  wrapper, the imported Nephilite model instance, and an `AnimationPlayer`. Carries no collision node
  at any depth. Instanced under `Player` in `scenes/test_environment.tscn`; the primitive `Mesh` is
  hidden but its NODE and the authored `CollisionShape3D` are retained.
- `scripts/animation/player_visual.gd` (`PlayerVisual`) - the driver behind `AnimationAdapter`'s
  `_apply_intent()` seam. Owns the `AnimationPlayer`, the extracted `Animation` resources and which
  clip is playing. Writes no gameplay state; holds no timing; poses bones only.
- `resources/animation/player_fist.animset.tres` (`AnimationSet`) - the FIRST real animation set: ten
  slots mapped to ten imported Nephilite clips. `parry` is deliberately ABSENT (the pack ships no
  parry clip) and is reported through the fallback policy as `neutral`. A machete set will be a second
  `.tres` and one assignment.

### New diagnostic files (cleanup candidates, delete with their scenes)

- `scripts/diagnostics/animation_content_probe_debug.gd` - deterministic content-pipeline probe, 70
  checks. It DRIVES real gameplay (a committed attack, a lethal blow, a reset) and reads the skeleton,
  and it carries two FALSIFICATION CONTROLS: the bone-pose check proves the clips bound to the real
  skeleton, and a stopped-driver control proves THIS driver is what poses it.
- `scenes/diagnostics/animation_content_probe_debug.tscn` - the probe's standalone entry scene.
- `scenes/diagnostics/model_recon_debug.tscn` - a THREE-NODE recon scene built to inspect what an
  imported FBX actually contains without opening the package's own scenes. Temporary; it exists so the
  recon was a measurement rather than an assumption. Safe To Delete: Yes, once `player_visual.tscn`
  itself carries the same information.
- `res://animation_content_probe_report.txt` - the durable probe transcript, same convention as the
  other `*_report.txt` evidence files.

### Recorded changes to existing files

- `scripts/animation/animation_adapter.gd`: added a `visual_path` export, a `_visual` reference, a
  `_resolve_visual()` and a handoff inside `_apply_intent()`. The adapter still resolves the SLOT and
  the CLIP; it now hands both to a real driver. The placeholder label's second line was changed from
  the full `res://` clip PATH to the bare clip NAME - the path at font size 40 painted text across the
  whole viewport, which was a real defect observed in a captured frame and fixed.
- `scenes/test_environment.tscn`: two `ext_resource` lines (`player_visual.tscn`, `player_fist.animset.tres`),
  `animation_set` on `Player/Animation`, the `Visual` instance under `Player`, and `visible = false`
  on `Player/Mesh`.

### Recurring tooling problem, recorded (FOURTH occurrence of a class already in this file)

**A ZERO-FILE glob result for `*.import` / `*.fbx.import` IS NOT EVIDENCE THAT NOTHING IS IMPORTED.**
The project's listing tools (`glob`, `listTree`) do NOT return `.import` files at all: a glob for
`**/*.import` over the whole project returns ZERO while the console simultaneously reports warnings
from `.png.import` FILES THAT PLAINLY EXIST. A direct `readFile` of the exact path reads them fine.
This produced a FALSE claim in the roadmap's Slice A record - "THE PACK IS NOT IMPORTED ... all 112
animations and the model are currently inert raw files" - which was WRONG: every FBX already carried a
valid `[remap] importer="scene"` sidecar. The lesson is the project's own oldest one: a convenient tool
result is not a measurement. When an asset's import state matters, read the `.import` file by path or
call `OpenScene`, and never conclude from an empty listing.

### Rendered-evidence limitation, recorded honestly

`gameSnapshot` on the shipped scene returned a frame that was captured successfully but that the
visual observer could NOT analyze (`observer_analysis_failed`), so the one frame taken is INCONCLUSIVE
rather than evidence of success or failure. What the frame DID show to a direct read: the humanoid
model standing where the capsule was, at roughly player scale, with the capsule hidden - and the
oversized clip-path label defect described above, which is why that label was fixed. Model facing,
scale, and pose quality are NOT measured and are the user's judgement.

---

## MILESTONE 21 - ANIMATION LOOKUP ARCHITECTURE, SLICE A (2026-09-15)

Recorded at the moment of the work, per the file-hygiene rule. Recording is the action; deletion
stays manual. NOTHING WAS DELETED. Slice B (FBX import, a rig, a real `AnimationPlayer`) was
EXPLICITLY DEFERRED by the user and is not started.

### New gameplay files (NOT deletion candidates - real systems)

- `scripts/animation/animation_set.gd` (`class_name AnimationSet`, extends `Resource`). The
  swappable per-weapon/per-creature clip mapping: slot key -> ordered clip list, plus declared
  fallbacks and a neutral slot. Holds no timing, no damage and no phase. A new moveset is a new
  `.tres`, not a code change.
- `scripts/animation/animation_intent.gd` (`class_name AnimationIntent`, extends `RefCounted`). The
  read model that carries ATTACK IDENTITY alongside the state the adapter already reported. Built
  exclusively from `ActorState`; owns no timer and decides nothing.

### New diagnostic files (cleanup candidates, delete with their scene)

- `scripts/diagnostics/animation_lookup_probe_debug.gd` - the Slice A acceptance probe. 30 checks,
  `RESULT: ALL CHECKS PASSED (30)`. Proves the five resolution outcomes against a SYNTHETIC set, the
  slot vocabulary, that four actors resolve non-empty slots, and - by DRIVING real attacks through
  `PlayerCombat.try_start` - that one attack holds ONE slot for its whole commitment while the coarse
  intent walks all three phases.
- `scenes/diagnostics/animation_lookup_probe_debug.tscn` - its standalone entry scene.

### New report transcript at project root (evidence, same convention as the other `_*_report.txt`)

- `res://animation_lookup_probe_report.txt` - written by the probe above, overwritten each run.

### Recorded changes to EXISTING files

- `scripts/combat/attack_definition.gd` - NEW `id` field (the stable lookup key), NEW optional `id`
  parameter on `make()` (last and optional, so every existing call site is unchanged), NEW `key()`
  and NEW `slug()`. Fallback behaviour when no id is authored: the key derives from the display name.
- `scripts/combat/enemy_attack_profile.gd` - NEW optional exported `attack_id`, seeded one-way like
  every other field here.
- `scripts/combat/enemy_attacker.gd` - NEW `_attack_id` seeded from the profile, passed into
  `AttackDefinition.make`, NEW `attack_id()` accessor. No timing value touched.
- `scripts/player/player_combat.gd` - the two definitions now author `"light"` / `"heavy"` ids, NEW
  `_last_attack_id` remembered at `try_start()`, NEW `attack_id()` accessor. No timing value touched.
- `scripts/actors/actor_state.gd` - NEW `attack_id()` on the read-only contract, duck-typed off the
  owning component so it works for both the player and an enemy.
- `scripts/animation/animation_adapter.gd` - NEW slot vocabulary, NEW optional `animation_set` export,
  NEW `report_missing_slots`, NEW `_slot` / `_resolved_clip` / `_resolved_status` / `_missing_slot`
  tracking, NEW `slot_name()` / `resolved_clip()` / `resolution_status()` / `resolution_note()`, and
  `_apply_intent()` now takes the previous slot as well. `intent_name()`, `history_values()` and
  `intent_vocabulary()` are UNCHANGED, which is why the existing adapter probe still passes at 54/54.
- `.summer/plans/CASCADIA_MILESTONE_ROADMAP.md` - new Milestone 21 section, current-state entry, and
  new known-defect 12.5.

### DEFECTS FOUND AND FIXED IN THIS PASS

1. `player_combat.gd` ended up with `_last_attack_id` declared TWICE (two edits both applied), which
   is a parse error. Fixed by keeping one declaration with the fuller comment. LESSON: two
   independent edits sent against overlapping regions of one file are not safe - the second
   duplicated the first.
2. `animation_intent.gd` referenced `AnimationSet` and its own `class_name` before the global class
   registry had scanned either new file, so both scripts failed to resolve. This is the
   REGISTRATION-TIMING class of failure this project has recorded before (see the deletion-manifest
   recurring-issues entries). Rewritten to depend only on `preload` and duck typing, the same
   convention `animation_adapter_probe_debug.gd` already documents for exactly this reason.
3. `animation_lookup_probe_debug.gd` crashed at runtime with
   `Invalid call 'String' constructor: missing` - `String()` applied to a `PackedStringArray`. Fixed
   to inspect the array directly.
4. `animation_lookup_probe_debug.gd` also discovered the player through an INVENTED group name
   (`"player"`) that does not exist in this project, which silently turned three player assertions
   into null comparisons that read like gameplay failures. Corrected to the project's ESTABLISHED
   group, `CreditLedger.GROUP_PLAYER_ACTOR` (`"player_actor"`), the same one every other probe, the
   HUD, the ledger and the stake use. LESSON: an invented group name in a diagnostic is not a
   harmless placeholder - it finds nothing and turns every downstream assertion into a false failure.

### NEW DEFECT FOUND, RECORDED, DELIBERATELY NOT FIXED

- `attack_probe_debug` now FAILS 2 checks (`LIGHT`/`HEAVY`: "measured ACTIVE matches definition").
  Diagnosed as a PROBE MEASUREMENT artifact caused by hitstop (Milestone 18): the probe counts
  FRAMES per phase, and a hitstop freeze stops the body advancing but not the frame count, so only
  ACTIVE inflates (0.22 vs 0.14 authored) while STARTUP and RECOVERY both PASS. Separate from
  Milestone 21, which changed no timing constant. Full record: roadmap section 12.5.

### Regression results recorded THIS pass (all re-run fresh, not carried over)

| Probe | Fresh result |
| ----- | ------------ |
| `animation_lookup_probe_debug` (new) | `RESULT: ALL CHECKS PASSED (30)` |
| `animation_adapter_probe_debug` | `ALL CHECKS PASSED (54)` - unchanged, and it still drives a real attack |
| `actor_contract_probe_debug` | `ALL CHECKS PASSED (82)` |
| `live_combat_credit_probe_debug` | `ALL CHECKS PASSED (54)` - hitstop, interruption and the death credit reset intact |
| `enemy_attack_probe_debug` | `ALL CHECKS PASSED` |
| `attack_probe_debug` | **2 FAILED - KNOWN RED, diagnosed above (12.5)** |
| `main.tscn` | boots at 0 errors, 0 debugger errors, 20 warnings |

---

## MILESTONE 21 - ANIMATION INTEGRATION CORRECTION PASS - NEW FILES AND RECORDED CHANGES (2026-09-15)

Recorded at the moment of the work, per the file-hygiene rule. Recording is the action; deletion
stays manual.

### New diagnostic files (cleanup candidates, delete with their scenes)

- `scripts/diagnostics/animation_model_recon_probe_debug.gd` + its `.tscn` - the FIRST recon probe.
  Measured the ROOT bone and the static transforms and correctly reported that the root never moves
  and all transforms are identity. It was kept rather than deleted even though its successor
  superseded it, because it is the evidence that RULED OUT two of the three candidate mechanisms.
- `scripts/diagnostics/animation_model_axes_probe_debug.gd` + its `.tscn` - the SECOND recon probe,
  and the one that found the real causes. It reads each clip's `Animation` RESOURCE directly rather
  than sampling a playing clip, so its numbers cannot be perturbed by the driver, by frame timing or
  by which slot happened to be active. Reports the model's authored forward axis from the REST pose
  foot-to-toe vector, and the Hips position-track span for every clip in the assigned set.
- `scripts/diagnostics/animation_visual_correction_probe_debug.gd` + its `.tscn` - the ACCEPTANCE
  probe for this pass. 20 checks, including the control that matters most: the skeleton must still be
  MOVING, so "in place" cannot be achieved by freezing the animation.
- `res://animation_model_recon_report.txt`, `res://animation_model_axes_report.txt`,
  `res://animation_visual_correction_report.txt` - durable transcripts, same convention as the other
  probe reports. NOT cleanup candidates: they are the measured evidence for this pass.

### Changed files (NOT new, and NOT deletion candidates)

- `scripts/animation/player_visual.gd` - added `_flatten_horizontal_travel()` and
  `_is_whole_body_bone()`, called during extraction beside the existing `_strip_node_tracks()`.
  Added `flattened_tracks` as a diagnostic counter. The class comment was corrected: it previously
  described only NODE-level stripping and did not mention that this pack's travel lives on a BONE.
- `scenes/actors/player_visual.tscn` - the `Model` instance now carries a 180-degree yaw
  (`Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 0)`), which is the facing correction. Written as
  ONE whole-file write, per the project's rule against incremental scene edits.
- `.summer/plans/CASCADIA_MILESTONE_ROADMAP.md` - section 8Z and the current-state entry.

### MEASURED ROOT CAUSES (not inferred - recorded because both were counter-intuitive)

1. **FACING.** The model's rest-pose foot-to-toe vector is `(0, 0, 1)` = **+Z**, and gameplay forward
   is **-Z**, so `dot = -1.000`: exactly opposed. Measured independently on all four toe bones across
   both feet, unanimous. Nothing had applied a rotation anywhere - visual, model and skeleton were all
   identity transforms - so the mismatch was purely the pack's AUTHORED axis.
2. **DRIFT.** The root bone NEVER moves (`0.0000 m` over a whole walk clip) and no clip contains a
   single node-level track (measured: `node=0` in every one of the 10 clips). The travel is baked onto
   the **HIPS BONE**, which `_strip_node_tracks()` correctly preserves because it IS a bone track. So
   the character walked forward inside its own body and snapped back at every loop point. Measured
   horizontal travel before the fix: walk 1.5869 m, sprint 3.7807 m, roll 4.6342 m, heavy attack
   2.9334 m, light attack 1.6138 m, death 1.1266 m, hit reaction 1.1402 m, stagger 1.1719 m, backstep
   2.9679 m, idle 0.0066 m. NOT ONE of them returned to its starting value.

### A RECORDED NEGATIVE RESULT

The first recon probe sampled the ROOT bone only and reported **zero drift**, which CONTRADICTED the
hand-reported defect. That was NOT a probe bug and NOT a false report: both were correct, about
different bones. Recorded because the natural next step - "the probe says there is no drift, so the
report must be wrong" - would have discarded a real defect. Widening the measurement from the root to
the hips is what found it.

### Regression results recorded THIS pass (all re-run fresh, not carried over)

| Probe | Fresh result |
| ----- | ------------ |
| `animation_visual_correction_probe_debug` (new) | `RESULT: ALL CHECKS PASSED (20)` |
| `animation_content_probe_debug` | `ALL CHECKS PASSED (70)` |
| `animation_lookup_probe_debug` | `ALL CHECKS PASSED (30)` |
| `animation_adapter_probe_debug` | `ALL CHECKS PASSED (54)` |
| `actor_contract_probe_debug` | `ALL CHECKS PASSED (82)` |
| `targeting_probe_debug` | `ALL CHECKS PASSED (78)` |
| `new_run_reset_probe_debug` | `ALL CHECKS PASSED (32)` |
| `live_combat_credit_probe_debug` | `ALL CHECKS PASSED (54)` |
| `combat_feedback_probe_debug` | `RESULT: ALL CHECKS PASSED` |
| `main.tscn` | boots at 0 errors, 0 debugger errors, 22 warnings |

The 22 warnings are the pre-existing third-party case-mismatch import warnings plus the adapter's
BY-DESIGN `slot 'parry' has no clip` report, which is the fallback policy being visible as intended.

### Defect found and fixed IN THE PROBE during this pass

`animation_model_recon_probe_debug.gd` line 248 returned `_skeleton.global_transform *
get_bone_global_pose(i)`, which is a `Transform3D`, from a function declared to return `Vector3`. A
parse error. Fixed by taking `.origin`. Recorded because it is the second time this pass that a
probe's own type error - not a game defect - was the thing standing between the work and its evidence.
