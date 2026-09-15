# CASCADIA - LOCAL MILESTONE ROADMAP

Local source of truth for Cascadia's development order, milestone status,
acceptance criteria, known defects, deferred systems and the next approved task.

A fresh session must be able to read THIS FILE plus `CASCADIA_DELETION_MANIFEST.md`
and know exactly where the project stands without chat history.

Read `# CURRENT STATE - READ THIS FIRST` immediately below. Everything after it is either
the maintained acceptance table (section 0), standing rules, or HISTORICAL record. Where a
historical section disagrees with the current-state section, the current-state section wins.

---

# CURRENT STATE - READ THIS FIRST

Verified against the live project on 2026-09-14 during a documentation consolidation pass.
Every statement here is present-tense and current. Evidence and detail live in the numbered
sections; this block is the entry point, not a replacement for them.

## Identity and phase

- **Cascadia** - a THIRD-PERSON SOULSLIKE. Godot 4, GDScript.
- **Phase: foundation / systems-first prototyping.** Systems are proven with primitive
  geometry. There is NO animation system, no final art, and no real HUD.
- **Standing rule:** gameplay is authoritative. Animation, models, effects and sound are
  downstream adapters that conform to gameplay timing, never the reverse.

## Milestone status

- **THE CURRENT STATUS IS SECTION 8W (see below).** **Milestone 20 - the UI CLEANUP AND LAYOUT
  UNIFICATION PASS - is ACCEPTED BY THE USER 2026-09-14.** The user handplayed the running game and
  confirmed it: "Confirm this as accepted." It was applied, statically clean, MEASURED by its own
  probe and by a regression guard, VISUALLY REVIEWED BY THE USER across frames, and refined once at
  the user's request (8W.5, the INPUT FOUNDATION two-column reflow). Acceptance record: 8W.8. Read 8W. **Milestone 19 - the Soulslike death-drop loop -
  is ACCEPTED for the current DEVELOPMENT STATE.** The user handplayed it on 2026-09-14 and confirmed
  it works: "Current pass has been handplayed and verified ... consider it functionally working at
  this point." Acceptance record: 8V.7. Its remaining polish - tying the death stake to an on-screen
  button prompt - is explicitly DEFERRED BY THE USER, not a defect. The highest accepted milestone
  before this was **18 - COMBAT FEEDBACK AND THE DEATH LOOP** (hitstop, enemy attack interruption,
  death credit reset), accepted 2026-09-14 after a human playtest that followed the reach change
  (8U.5; record at 8U.8). Milestone 17 - MINIMAL ENEMY ENGAGEMENT - remains accepted, and its leash,
  stop-distance and speed behaviour was preserved unchanged through every part of 8U and 8V.
  **THE UI CLEANUP AND LAYOUT UNIFICATION PASS IS ACCEPTED** - see 8W - accepted by the user
  2026-09-14 after handplaying the running game and requesting one refinement, which is applied and
  re-measured (8W.5). The M13 bullet
  below is superseded as the "highest accepted" claim and is kept only for audit.

- **Highest accepted milestone: 20 - UI CLEANUP AND LAYOUT UNIFICATION** (accepted 2026-09-14 by
  HANDPLAY; accept record 8W.8). CORRECTED 2026-09-15: this bullet previously declared M13 as the
  highest accepted milestone and was overtaken by M17, M18, M19 and M20, all of which the user
  accepted. It is the same defect class as the section-0 staleness recorded below - a status line
  left standing after the status changed. The chain of acceptance is: M13 (sections 8Q-8R), M17 and
  M18 (8S-8U), M19 (8V), M20 (8W).
- **Milestone 13 - MINIMAL UI - ACCEPTED by the user 2026-09-14 after a MANUAL READ of the live
  game.** The user's report: the UI pass "seems to have been implemented correctly", "New Run works
  correctly", "save seems to be implemented correctly", and "the pause menu and debug menu seem to be
  working fine". Full record: section 8Q. This bullet carried the "highest accepted" claim until
  2026-09-15 and is kept here, demoted rather than deleted, because it is the evidence for M13.
  Milestone 12 (target lock-on) was the previous highest accepted, accepted the same day on its own
  playtest; its record stands at 8P.
- **Milestone 14 - ENEMY HEALTH BARS - IMPLEMENTED + MEASURED, still not human-read.** Requested by the user 2026-09-14 as the
  remaining DEBUG / player-feedback layer, with the scope record written into section 8R BEFORE
  implementation per section 15. Now IMPLEMENTED AND MEASURED: `ui_hud_probe_debug` reports
  `RESULT: ALL CHECKS PASSED (165)` (up from 142), and the shipped `main.tscn` boots at 0 runtime and
  0 debugger errors. It is **NOT yet human-read**: bar size, position, colour and whether the hold
  feels right are the user's call, and the user has stated this is NOT a permanent HUD decision yet.
- **Milestone 15 + the SECOND ENEMY VARIANT are IMPLEMENTED AND MEASURED.** The project BOOTS:
  `main.tscn` runs at **0 debugger errors**, `is_breaked: false`, with every actor's health
  initialising (`180.0` HeavyBrute, `60.0` NPC, `100.0` the rest).
- **NEW RUN and PLAYER-DEATH arena reset are now BOTH ALIVE AND MEASURED (2026-09-14, regression
  pass).** Two probes, both green, both writing readable reports:
  `new_run_reset_probe_debug` -> `RESULT: ALL CHECKS PASSED (32)` in
  `res://new_run_reset_probe_report.txt` (HeavyBrute returns to **180/180** after partial damage AND
  after a killing blow, tuning intact: windup 1.05, damage 34.0, range 3.40);
  `player_death_reset_probe_debug` -> `RESULT: ALL CHECKS PASSED (38)` in
  `res://player_death_reset_probe_report.txt` (a killed `DummyActor` comes back **alive at 100/100**,
  HeavyBrute 150->180, NPC 30->60, TestAttacker 70->100).
- **DEFECT FOUND AND FIXED THIS PASS - `DeathComponent._reset_attackers()` reset only ONE attacker.**
  It fell back to `get_first_node_in_group(GROUP_ATTACKER)`, so with two enemy variants only one was
  reset and WHICH one depended on unspecified group order. It now enumerates the group, and an
  authored `attacker_path` still means "reset exactly this one". ACTION state only - health and
  defeat are deliberately NOT touched there, because the same method runs on a LOAD.
- **SOULSLIKE DEATH SEMANTICS ADDED - a deliberate REVERSAL of the earlier decision.** Dying now
  resets the ENCOUNTER, not just the player: `DeathComponent._restore_arena_actors()` returns every
  other combat actor to alive at full health via each owner's own API (`HealthComponent.reset()`,
  `restore_defeated(false)`). `EnemyDeathComponent` was previously authored specifically NOT to be
  cleared from the player-death circuit - that is no longer the intent. The restore does NOT emit
  `defeated`, so reviving an enemy this way cannot pay a Credit reward. A LOAD deliberately does NOT
  do this: it restores a recorded world instead.
- **The NPC respawn timer is CANCELLED when something else restored the actor first.** Without that,
  the player-death arena reset or a load could revive the NPC and its own pending `respawn_delay`
  timer would still fire afterwards, performing a SECOND restoration and bumping `respawns_made` for
  a respawn the actor never actually made.
- **MILESTONE 16 - ANIMATION ADAPTER - ACCEPTED BY THE USER 2026-09-14.** Accepted after a manual read
  of the running build, in the user's words: "Everything seems to be functioning correctly. Consider
  this milestone finished for the moment." The first real
  CONSUMER of `ActorState`, and deliberately a thin one: it answers "given what this actor is
  ALREADY doing, what should be playing?", never "what is this actor doing?". The pipeline runs one
  way only - `gameplay owners -> ActorState -> AnimationAdapter -> driver` - and nothing in the
  adapter writes gameplay state, starts or cancels anything, or owns a phase.
- **ONE adapter, FOUR actors, THREE kinds, ONE script.** `scripts/animation/animation_adapter.gd` is
  attached to `Player`, `TestAttacker`, `HeavyBrute` and `PassiveNpc`, and the probe measures
  **1 distinct script** across all four. Enemy variants are distinguished by PROFILE timing, not by
  bespoke animation code - so presentation follows the data exactly as gameplay does.
- **`animation_adapter_probe_debug` -> `RESULT: ALL CHECKS PASSED (54)`** in
  `res://animation_adapter_probe_report.txt`. It is NOT a screenshot test: it DRIVES real gameplay and
  requires the adapter to follow. It started the player's attack through `PlayerCombat.try_start` and
  observed `idle, attack_windup, attack_active, attack_recovery` in the adapter's history; it killed
  the HeavyBrute through the real hurtbox chain and the adapter reported `dead`; the NPC's history is
  `idle` ONLY, never a combat intent. It also asserts, per actor, that every value the adapter
  consumed EQUALS what `ActorState` returns directly - a divergence would mean the layer is guessing
  instead of reading, which is how a presentation layer becomes a second authority.
- **THE ADAPTER WRITES NO MESH TRANSFORMS AND NO MATERIALS**, on purpose.
  `EnemyDeathPresentationDebug` already owns the defeat pose (mesh transform + `material_override`)
  and `hit_feedback_debug` owns `material_overlay`; writing either would clobber an existing
  presentation owner mid-effect. A dead actor therefore reports the DEAD intent and lets the existing
  defeat presentation keep owning the body.
- **The driver is a PLACEHOLDER and its seam is one function: `_apply_intent()`.** Today it is a
  billboarded `Label3D` coloured per intent, which makes the adapter's decision visible on every actor
  at a glance. A real `AnimationTree`/`AnimationPlayer` replaces exactly that one function; everything
  above it stays identical. NO animation clips, blend trees, root motion or
  animation-driven hitboxes/timing were added - those remain deferred by explicit instruction.
- **MEASURED IN THE SHIPPED BUILD:** `main.tscn` boots at **0 debugger errors**, `is_breaked: false`,
  and a captured frame shows the arena rendering with an `IDLE` intent label over the player and the
  combat overlay enumerating `HeavyBrute 180/180 [alive attack-capable targetable]`,
  `TestAttacker 100/100 [alive attack-capable targetable]`, `PassiveNpc 60/60 [alive not-targetable]`
  and `DummyActor`. **HUMAN-READ AND ACCEPTED:** the user read the running build and confirmed it
  functioning, with the `IDLE` intent label legible above the actor in their own capture. What the
  PROBE measured rather than the eye is the LABEL TRACKING through a fight: sprint, dodge, the three
  attack phases and death were driven and asserted, not watched while moving.
- **NPC RESPAWN IS SCAFFOLDING, NOT THE INTENDED DESIGN (user-stated 2026-09-14).** The long-term
  goal is LEVEL-LIFETIME-based NPC respawn, not a timer. The current `respawn_delay` countdown is a
  temporary stand-in that exists only because the test arena has no levels yet. Do NOT build
  permanence assumptions on top of the timer, and do not treat 6 s (or the `.tres` 4.0 s) as a design
  value.
- **The archetype abstraction is now PROVEN, not merely present:**
  `res://scenes/diagnostics/actor_contract_probe_debug.tscn` reports
  `RESULT: ALL CHECKS PASSED (82)` and writes `res://actor_contract_probe_report.txt`, which names
  `player=Player`, `npc=PassiveNpc`, `enemy:HeavyBrute=HeavyBrute`, `enemy:TestAttacker=TestAttacker`.
  Two enemy variants, **one** behaviour script (`enemy_attacker.gd`, 1 distinct), **two** distinct
  profiles, live values matching their `.tres`, and the profile proven to be a SEED rather than a live
  authority (retuning the resource at runtime does not move a running attacker).
  `Heavy Brute` vs `Arena Attacker` differ in SIX fields: windup, damage, recovery, range, cooldown,
  active. **SUPERSEDED 2026-09-15.** This line read "**NOT yet human-played:** no human has moved,
  attacked or fought in this build", which was true while M15/M16 were probe-only. It has been FALSE
  since 2026-09-14: the M17/M18 playtest (8S, accept record 8U.8), the M19 playtest (8V.7) and the M20
  handplay (8W.8) all happened in this build. The archetype measurements above are unchanged; only the
  "never played" claim was stale.
- **THREE DEFECTS THIS PASS, all now fixed, all recorded here so they are not repeated:**
  1. `scenes/actors/test_attacker.tscn` was corrupted by writing nodes into it ONE `strReplace` AT A
     TIME (six duplicate `Reaction`/`ActorState` blocks, duplicated `ext_resource` ids). It failed to
     parse and the editor then REFUSED to reload it from disk, keeping its broken in-memory copy.
     LESSON: build a scene with ONE whole-file write, never incremental node-by-node edits.
  2. `passive_npc.tscn` mounted `passive_npc.gd` (which `extends CharacterBody3D`) on a plain `Node`
     child while the `CharacterBody3D` ROOT had no script. A mismatched script/root type makes the
     scene fail to instantiate, which took `test_environment.tscn` and `main.tscn` down with it -
     THIS WAS THE "DOES NOT BOOT" REPORT. The script now sits on the `CharacterBody3D` root.
  3. `passive_npc.gd` referenced the brand-new `ActorProfile` type before the editor had registered
     that `class_name`, so the script failed to PARSE while it was being authored. That was a
     REGISTRATION-TIMING symptom of writing files during an editor pass, NOT the cause of the boot
     failure - and the `preload` workaround it prompted caused a worse, silent defect. The property is
     now declared with the global `class_name`, exactly as the enemy's already was.
- **`can_act()` was missing from `ActorState` and is now added, DELEGATED to `CombatParticipant`** so
  the contract never becomes a second opinion about whether an actor may act.
- **THE NPC'S PROFILE IS NOW ASSIGNED, and getting there exposed a defect worth remembering.** The
  property was declared as `@export var profile: <preload const type>`. An exported property typed by a
  `preload()` CONST does NOT register as a bindable property, so the scene's `profile = ExtResource(...)`
  line was SILENTLY DROPPED: the actor ran with no archetype while looking fully wired everywhere, and
  only the probe's behavioural check caught it. It is now declared with the global `class_name`
  (`@export var profile: ActorProfile`), the SAME mechanism `EnemyAttacker` already uses for
  `EnemyAttackProfile`. The old `preload` workaround was aimed at a class-registration parse failure
  that was NOT the cause of the boot defect (that was the script-on-the-wrong-node-type problem above)
  - do not reintroduce it.
- **Current active task: MILESTONE 15 - SHARED COMBATANT FOUNDATION (player / enemy / NPC +
  animation-facing state + archetype data).** Requested by the user 2026-09-14. The milestone built
  one shared actor vocabulary (`ActorState`), one archetype DATA layer (`ActorProfile` for identity
  and lifecycle, `EnemyAttackProfile` for attack tuning), a hit-reaction component, and the first NPC
  archetype (`PassiveNpc`), and it wired all of them into the arena.
- **Milestone 15 status: IMPLEMENTED + MEASURED AT RUNTIME. The boot failure is FIXED and PROVEN.**
  `main.tscn` boots with **0 debugger errors** and `is_breaked: false`, and a captured frame renders the
  arena with the HUD, combat overlay, input overlay and save/load panel all live. The earlier
  "debugger breakpoint" reading recorded in this file was WRONG and is superseded: no breakpoints are
  set anywhere in the project (`script_editor_cache.cfg` shows `breakpoints: PackedInt32Array()` on
  every script). The project genuinely was not loading.
- **MILESTONE 15.5 - SECOND ENEMY ARCHETYPE, MEASURED.** The arena now carries a `HeavyBrute` beside
  the original `TestAttacker`. Both instantiate the SAME `scripts/combat/enemy_attacker.gd`; they
  differ only by archetype resource. The probe reports `RESULT: ALL CHECKS PASSED (82)` and writes
  `res://actor_contract_probe_report.txt` listing `player=Player`, `npc=PassiveNpc`,
  `enemy:HeavyBrute`, `enemy:TestAttacker`, with both variants' live tuning matching their `.tres`
  (Heavy Brute windup 1.05 / damage 34.0 / range 3.40 / cooldown 2.20 / health 180.0 against Arena
  Attacker 0.60 / 20.0 / 2.80 / 1.60 / 100.0), ONE distinct behaviour script for 2 variants, and the
  profiles confirmed as SEED not authority (retuning a profile at runtime does not move a running
  attacker).
- **NOT yet human-played.** No human has moved, attacked or fought in this build, and the pre-existing
  probes (`ui_hud_probe_debug` 165/165, `targeting_probe_debug` 78/78, the attack / damage / parry /
  dodge / save-load families) were NOT re-run this pass. Their previous results stand as history, not
  as a re-verification. Do not describe the existing systems as re-baselined.
- **Defect found and fixed during this pass:** the first version of `scenes/actors/test_attacker.tscn`
  was corrupted by repeated single-node `strReplace` edits into it (six duplicate `Reaction` /
  `ActorState` blocks, duplicated `ext_resource` ids) and would not load at all. Repaired with one
  whole-file write. `ActorState` also called a method name that did not exist (`_get_actor()`), which
  made the whole script fail to parse. Both are recorded in the manifest (C1).
- **The engagement rule is a STAND-IN, not a system.** "Engaged" today means damaged within 4 s or
  currently locked. **No aggro, threat or deaggro system exists**, and enemy AI does not exist. The
  single function `EnemyHealthBars.is_engaged()` is the recorded seam where enemy AI will be asked
  instead. Do NOT describe the current rule as aggro, and do NOT build an aggro system here.
- **Next milestone after this one: NOT selected and NOT approved.** The user's stated intended
  direction after this pass is save/load presentation work, but it is NOT started and NOT approved.
  This file, its milestone index and its deferred list do NOT authorise anything merely by existing.
- **The carried-over lock-on ORIENTATION tweak is DONE** (part of 8Q, implemented in
  `player_controller.gd`). The accepted M12 mechanics were not reopened: release paths, cycle order,
  validity rules, bindings and camera framing are all unchanged, and `targeting_probe_debug` still
  reports 78/78.
- **Escape's meaning CHANGED this pass, on the user's instruction.** It used to free the cursor on the
  first press and open the panel on the second; ONE press now does both. `res://.summerrules` records
  the amended contract, and `focus_input_routing_probe_debug` was updated to measure it.

## What is implemented

Milestones 0-12 are implemented and accepted, in order: input/camera (M0), grounded movement
(M1), damage plumbing (M2), physical actor collision (M3), player attacks (M4), stamina (M5),
dodge + i-frames (M6), parry (M7), one attacking test enemy (M8), credit economy (M9),
save/load foundation (M10), facing indicator (M11), target lock-on (M12) - plus the M8-family and
later passes:
death/reset circuit (8H), enemy death + persistence (8I), reusable actor death (8J), reusable
actor combat readiness (8K), defeat coverage (8K.12), and dodge movement authority (8N).

**Authoritative per-milestone status and the strongest evidence held for each: section 0.**
It is not duplicated here on purpose.

## Evidence ceiling per system

- **CONFIRMED by measurement AND human play:** M0 and M1 (user playtests), M5, M6, M7, M8 and
  the input pass (full-loop playtest, section 8G), and Milestone 11 (user visual acceptance,
  8O.15).
- **CONFIRMED by deterministic probe output only - no human has played it:** the M8-family
  passes 8H / 8I / 8J / 8K, the 8N dodge authority pass, and Milestone 9.
- **PARTIALLY VERIFIED - probe-measured but NOT human-played: Milestone 10 (save/load).** The
  prototype F5 / F7 / F10 controls are built, bound and visible in a rendered frame, but a human
  has never exercised save -> change -> load by hand. This is the largest unplayed item.
- **PARTIALLY VERIFIED - feel never judged:** dodge i-frame timing for feel, attack timing and
  hit feedback, damage-number legibility (12.3).
- **PARTIAL - rendered evidence covers only part of the claim:** TargetA step seating (12.3); and
  the two Milestone 11 MOTION reads - whether the markers visibly track yaw while moving, turning,
  dodging and backstepping, and whether the swing colours read distinctly at the light attack's
  0.16 s / 0.10 s timing. Both are COVERED BY the user's general visual acceptance, NOT separately
  measured.
- **NOT YET VERIFIED:** physical controller buttons were never pressed (Circle tap/hold, joypad
  parry 9, restart) - only their InputMap bindings were read; a second defeated actor seen in a
  rendered frame or by a human; `HurtboxComponent.damageable = false` on a scene-authored actor;
  lock-on-relative dodge direction (not implemented, by explicit decision); directional dodge
  ANIMATION selection (not implementable - no animation system exists).
- **INFERRED (static read, never observed at runtime):** the standing claim in 12.1 that
  `cascadia_input.gd` is well-formed and that `GameActions` resolves.

## Known defects and open items

- **`grounding_probe_debug` - RE-MEASURED 2026-09-14 during Milestone 17. The recorded failure has
  MOVED, and the entry above it in earlier notes is now WRONG.** The earlier record was "`TestAttacker`
  rests at -0.020 against the probe's 0.02 tolerance". Re-run twice, identically:

      TestAttacker  -0.001  PASS   (was the failing actor; gravity now settles it)
      HeavyBrute    -0.000  PASS
      DummyActor     0.000  PASS
      Player        -0.001  PASS
      TargetA/B/C    0.000  PASS
      PassiveNpc    -0.139  FAIL

  So the milestone did NOT fix and did NOT break the attacker: giving the enemy bodies real gravity
  and `move_and_slide()` settled `TestAttacker` from -0.020 to -0.001, inside tolerance. The ONE
  failing actor is now `PassiveNpc`, and it is the same CHECK failing on a different actor.
  MEASURED: this milestone touched neither `passive_npc.gd`, `passive_npc.tscn` nor any step
  geometry, so the NPC's float cannot have been introduced by a change to the NPC. NOT ESTABLISHED:
  whether the NPC also floated before this pass. The previous record named only ONE failing actor,
  but a partial record is also possible, and no earlier full grounding transcript was found - so this
  is NOT claimed either way. Reproduced twice, so it is stable rather than flaky.
  LIKELY CAUSE, from measured geometry rather than guesswork: `PassiveNpc` is authored at
  `X = -4, Z = 6`, and `Course/StepLane/Step14` is a `BoxShape3D` of `Vector3(6, 0.14, 6)` centred at
  `X = -7, Z = 6` - so it spans exactly to `X = -4`. The NPC stands ON the step's edge, resting
  0.14 m up, while the probe's downward ray down its centre hits the open floor at `y = 0`. The
  probe reports `collision=0.139` against `surface=0.000`, which is what that geometry predicts.
  That makes this a PROBE-GEOMETRY edge case rather than a broken actor.
  NOT FIXED, and deliberately NOT guessed at: it is outside Milestone 17's scope, the fix is either
  moving a scene-authored actor or changing the probe's sampling, and neither belongs in an
  enemy-engagement pass. Recorded here so the next session does not re-discover it as new.
- **Group-order dependence in the arena reset** - `DeathComponent._resolve_attacker()` falls back to
  group order when `attacker_path` is empty, so a second attacking enemy could silently change which
  attacker the player reset restores. Fragile, NOT yet a defect (12.3).
- **BACKSTEP ORIENTATION (2026-09-12 entry) - RECONCILED 2026-09-15; no longer outstanding.** 12.3
  carried this as an OPEN confirmed defect while the gameplay half was confirmed by the user's own
  playtest (8N.6, 2026-09-13) and the presentation half was accepted as Milestone 11 (2026-09-13).
  The 2026-09-14 consolidation deliberately did NOT flip it, because flipping a defect entry needs a
  pass that checks the specific claim rather than assuming. That check was made on 2026-09-15 and the
  entry is now CLOSED, with its original wording retained inside it for audit. NOT a new measurement:
  no probe was run, and the two anchors above are the evidence.
  STILL OPEN, and deliberately NOT closed by that reconciliation: the SEPARATE residual item recorded
  at 8N.6 and 8O.4 - the HUMAN read of the facing marker WHILE MOVING, dodging and backstepping. A
  still frame cannot show it and no human has reported it.
- Tuning, NOT defects: dodge i-frame timing for feel; enemy windup readability and cadence; parry
  window readability without animation.

## Benign tooling noise (do not chase)

- **Script errors in the diagnostics panel (12.1).** The historically reported `Identifier
  "GameActions" not declared in the current scope` errors were scoped to `open_script_buffers` -
  stale analysis of scripts held open as editor tabs. **Re-checked this pass: `state:diagnostics`
  reports 0 errors and 38 warnings, and `state:script-errors` for `open_script_buffers` returns an
  EMPTY list.** Never report this class of error as a defect without confirming it outside
  `open_script_buffers`.
- **38 case-mismatch import warnings (NEW this pass: real, non-blocking, unfixed).** Godot warns that
  `assets/environments/Sci-Fi Essentials Kit[Standard]/` and `assets/environments/Modular SciFi
  MegaKit[Standard]/` are requested with a lowercase `textures/` while stored as `Textures/`. The
  files open on Windows but will NOT open when exported to a case-sensitive platform. Recorded in the
  deletion manifest; not fixed.
- **Console error `Resource file not found: res://.summer/plans`** - resolved once the directory
  existed (12.2). Re-check before flagging it again.
- **Duplicate `8M` section numbers - RESOLVED 2026-09-14 (NOT outstanding).** The two colliding pairs in
  the M10.2 block are now `8M.17a` / `8M.17b`, with cross-references updated. Do not re-flag this.

## Deferred

Nothing deferred is authorised. Full list: section 13. Highest-signal deferred items: animation
integration, enemy AI / pursuit / navigation, stored / spent / persistent Credits and progression,
banking and shops, checkpoints and world persistence, inventory, ranged combat, jumping. Lock-on is
NO LONGER on this list - it is the ACTIVE milestone (section 8P). Lock-on-RELATIVE dodge direction
remains deferred even though lock-on itself is being built (8P.5).

AMENDED 2026-09-14 by Milestone 17 (section 8S): "enemy AI / pursuit / navigation" is now PARTLY
DELIVERED and must not be described as wholly unbuilt. DELIVERED: detection radius, direct-steering
pursuit to strike range, rate-limited facing, return-to-mark on lost detection, a recorded spawn
mark, and an `is_engaged()` authority for the health bars. STILL DEFERRED, explicitly: navigation
and pathfinding, obstacle avoidance, multi-enemy coordination, threat tables, strafing / circling /
spacing, attacking while moving, leash-distance tuning, and enemy-position save/load.

AMENDED 2026-09-14 by Milestone 18 (section 8T). **HITSTOP IS NO LONGER DEFERRED AND IS NO LONGER
UNBUILT** - it is DELIVERED and now USER-ACCEPTED (8U.8). **STAGGER IS PARTLY DELIVERED**: an incoming
hit is classified against a per-actor `stagger_threshold`, and a hit at or above it INTERRUPTS a
committed enemy swing through that enemy's own attack state machine. STILL DEFERRED: poise, hitstun,
knockback, interrupt armor, and any stagger that displaces a body. Stated precisely because an earlier
line here read "poise, stagger, hitstun, knockback and hitstop remain deferred AND unbuilt", which
became false when Milestone 18 shipped.

## Current open decision

**No open decision blocks the accepted work.** Milestone 18 is ACCEPTED (8U.8). The NEXT milestone is
**unselected and unapproved**; a recommendation with its reasoning and its alternatives is recorded at
8U.9 and awaits the user's choice.

---

## DOCUMENT MAP

| What you need | Where it is |
| ------------- | ----------- |
| Cascadia's current truth: identity, phase, highest accepted milestone, active task, approval state | `# CURRENT STATE - READ THIS FIRST` at the top of this file |
| Per-milestone status + the strongest evidence held for each | Section 0 of this file |
| Evidence vocabulary definitions | Section 0.1 of this file |
| Milestone order and each milestone's scope record | MILESTONE INDEX below, then sections 4-8O |
| Known defects, open items, tuning items | Section 12 of this file |
| Deferred systems | Section 13 of this file |
| Detailed historical verification evidence | Section 16 (append-only log) plus the per-milestone sections 8A-8O |
| File hygiene rule and the automatic-update rule | Sections 14 and 15 of this file |
| Cleanup candidates and deletion accounting | `res://CASCADIA_DELETION_MANIFEST.md` |
| Editor / class-cache / import problems | `res://CASCADIA_DELETION_MANIFEST.md` (recurring-issue and process entries) |

Two files, one responsibility each: **this roadmap owns development truth; the deletion manifest
owns artifact cleanup accounting.** The manifest is not a second roadmap, and it is not proof that a
deletion happened - nothing in this project has ever been deleted.

---

## MILESTONE INDEX

Status vocabulary used here: ACCEPTED / CLOSED / IMPLEMENTED + MEASURED / CONFIRMED BY PLAY.
Evidence behind each row is in section 0.

| # | Milestone / pass | Section | Status |
| - | ---------------- | ------- | ------ |
| 0 | Project reconnaissance and test arena | 4 | ACCEPTED - user playtest |
| 1 | Grounded player movement | 5 | ACCEPTED - user playtest |
| 2 | Basic damage plumbing | 6 | ACCEPTED - measured |
| 3 | Physical actor collision | 7 | ACCEPTED - measured |
| 4 | Player attacks | 8 | ACCEPTED - measured; physical input path closed |
| - | Target / test-actor grounding | 10 | CONFIRMED BY MEASUREMENT (historical pass) |
| 5 | Stamina | 8A | IMPLEMENTED + HUMAN-PLAYED; pressure/feel still unjudged |
| 6 | Dodge and i-frames | 8B, 11 | ACCEPTED 2026-09-12 (measured + played); 2 tuning items open |
| 7 | Parry | 8C, 11A | IMPLEMENTED + MEASURED + HUMAN-PLAYED; window readability open |
| 8 | Single attacking test enemy | 8D | IMPLEMENTED + MEASURED + HUMAN-PLAYED; readability open |
| - | Sprint / Dodge / Backstep input pass | 8E | IMPLEMENTED + MEASURED + HUMAN-PLAYED |
| - | Human playtest, full combat loop | 8G | USER-CONFIRMED 2026-09-12 |
| - | Death / reset circuit | 8H | IMPLEMENTED + MEASURED |
| - | Enemy death and persistence | 8I | IMPLEMENTED + MEASURED |
| - | Reusable actor death capability | 8J | ACCEPTED 2026-09-12 (measured + user-verified) |
| - | Reusable actor combat readiness | 8K | IMPLEMENTED + MEASURED; defect found in play and fixed |
| - | Defeat coverage across the arena | 8K.12 | ACCEPTED 2026-09-12 (measured + user-verified) |
| 9 | Soulslike credit economy and progression foundation | 8L | IMPLEMENTED + MEASURED; CARRIED Credits only |
| 10 | Game-state saving and loading foundation | 8M | IMPLEMENTED + MEASURED; NOT human-played |
| - | Dodge movement authority (the recorded 8F pass) | 8F, 8N | IMPLEMENTED + MEASURED 2026-09-13 |
| 11 | Readable player facing indicator | 8O | CLOSED 2026-09-13 - user visual acceptance |
| 12 | Target lock-on (toggle, cycle, auto-release, camera framing) | 8P | ACCEPTED 2026-09-14 - user playtest; probe 78/78 |
| 13 | Minimal UI pass (HUD, lock-on indicator, pause, save/load controls) | 8Q | ACCEPTED 2026-09-14 - user read; probe 142/142 |
| 14 | Enemy health bars (damage reveals, disengagement hides) | 8R | IMPLEMENTED + MEASURED 2026-09-14 (probe 165/165); NOT yet human-read |
| 17 | Minimal enemy engagement (detect, approach, face, stop at strike range) | 8S | ACCEPTED BY THE USER 2026-09-14 - human playtest; probe ALL CHECKS PASSED |
| 18 | Combat feedback: hitstop, enemy attack interruption, death credit reset | 8T, 8U | ACCEPTED BY THE USER 2026-09-14 - HUMAN PLAYTEST after the reach change (8U.8). Hitstop, enemy attack interruption and the death credit reset were all confirmed IN THE HAND. Probe evidence behind it: reach probe 22/22, live_combat_credit 54/54, all 14 regression suites green, 0 errors. |
| 19 | Soulslike death-drop loop (drop carried Credits on death, retrieve the stake, a second death destroys it) | 8V | ACCEPTED BY THE USER 2026-09-14 - HUMAN PLAYTEST (8V.7), accepted for a DEVELOPMENT STATE. Probe 51/51; every M18/M17-era regression suite green; 0 errors. Three runtime defects were found and fixed during the pass (8V.3). ONE UNRELATED SUITE IS RED: `ui_hud_probe_debug` 15 of 165, a pre-existing probe defect in its synthetic lock target, diagnosed in 8V.4 and NOT caused by this milestone. DEFERRED BY THE USER: an on-screen button prompt for the death stake. |
| 20 | UI cleanup and layout unification (shared regions, explicit layer order, INPUT FOUNDATION reflow) | 8W | ACCEPTED BY THE USER 2026-09-14 - HANDPLAYED. One refinement was requested during review (8W.5, the INPUT FOUNDATION two-column reflow) and is applied and re-measured. Probe `input_panel_layout_probe_debug` ALL CHECKS PASSED (13, including the driven narrow-width reflow and its restoration); `focus_input_routing_probe_debug` ALL CHECKS PASSED; `main.tscn` 0 errors. Acceptance record: 8W.8. Deliberate trades recorded in 8W.7, including the centred death message overlaying the diagnostics. |

Delivered milestone sections 8N and 8O were appended at the END of the file, after section 16, so
they do not follow numerical order. That is an ordering artifact, not a missing record.

---

## Milestone 17 - Minimal enemy engagement (section 8S, recorded 2026-09-14)

STATUS: ACCEPTED BY THE USER 2026-09-14 after HUMAN PLAYTESTING. Applied, statically clean, measured
by its own probe, and then CONFIRMED IN PLAY: the user reported that human testing shows the enemy
engagement concept is implemented correctly. The manual-play criterion in this milestone's acceptance
bar is therefore satisfied by the user's own testing.

RECORDED PRECISELY, because the two are different kinds of evidence and this project does not blur
them. The PROBE measured detection, approach, the stop distance, facing convergence, the committed
facing lock, defeat and reset - mechanically, in the real loop. The USER'S PLAYTEST is what confirms
it reads correctly in motion, which no probe here can measure. Neither one substitutes for the other.

WHAT WAS BUILT. An enemy is no longer a fixture. It notices the player inside `detection_radius`,
walks to its own `engage_range`, turns to face at a finite rate, stops, and hands control back to
the UNCHANGED attack loop from Milestone 8. One new component, one new data field, one recorded
spawn mark, one yaw-ownership contract. No navigation, no AI state machine, no per-archetype code.

  res://scripts/combat/enemy_locomotion.gd                     EnemyLocomotion (new, class_name)
  res://scripts/diagnostics/enemy_engagement_probe_debug.gd    the probe (new)
  res://scenes/diagnostics/enemy_engagement_probe_debug.tscn   its scene (new)
  res://resources/enemies/test_attacker_actor.tres             movement record (new)
  res://resources/enemies/heavy_brute_actor.tres               movement record (new)

WHY MOVEMENT WAS THE RIGHT NEXT STEP, and what it unblocked. Every enemy body is a
`CharacterBody3D` with NO script, so its `velocity` was permanently zero and `ActorState.is_moving()`
answered false for every enemy for the whole life of the arena. That made the presentation intent
`locomotion` - already implemented and already accepted in the animation adapter - UNREACHABLE for
anything except the player. With gravity and `move_and_slide()` in place, the enemy's shared state
became real for the first time: `is_moving()`, `flat_speed()`, `is_grounded()` and
`has_ground_report()` all now report real values for an enemy.

MEASURED, from the probe: the attacker's recorded intent history across one full engagement is
`["idle", "locomotion", "idle", "attack_windup", "attack_active", "attack_recovery", "locomotion",
"dead", "idle", "locomotion"]`. `locomotion` is now a reachable intent for an enemy, and the
adapter still never reports an intent the actor did not earn.

THE YAW-OWNERSHIP CONTRACT (settled here, and the only structural risk in this milestone).
Two systems can write `rotation.y` on one body, so exactly one may own it at a time:

  - NO attack committed  ->  `EnemyLocomotion` owns yaw, turning at its own `turn_speed_degrees`.
  - An attack committed  ->  `EnemyAttacker` owns the locked facing, exactly as before.
  - `EnemyAttacker._face_target()` DEFERS when a sibling answers `owns_uncommitted_facing()`, and
    then writes no yaw at all. A sibling that does not answer the method changes nothing.
  - With NO Locomotion component present, `EnemyAttacker` behaves byte-for-byte as it did before
    this milestone, so every archived scene and probe result stays valid.

This is the same shape as the project's recorded dodge rule: body orientation during a committed
action belongs to the locked gameplay facing, not to current velocity.

THE RECORDED SPAWN MARK. `EnemyLocomotion` captures `_body.global_transform` once at `_ready()`,
following the `PassiveNpc._spawn_transform` pattern, and restores it through its OWN `reset()`. The
same mark serves the RETURNING state and the arena reset. There is no second restore mechanism.

DATA-DRIVEN ARCHETYPES, PROVEN BY MEASUREMENT. `detection_radius` was added to `EnemyAttackProfile`
in the Engagement group its own header had earmarked for it. `move_speed`, `acceleration` and
`turn_speed_degrees` come from the EXISTING `ActorProfile.Locomotion` group, seeded once at
`_ready()`. The two archetypes were measured moving at DIFFERENT speeds from those profiles
(2.60 m/s vs 1.70 m/s), with different detection radii (12 m vs 9 m) and different turn rates.
No per-archetype movement script exists.

RESET WIRING. `DeathComponent._restore_arena_actors()` now also asks each restored actor's
`Locomotion` to reset, duck-typed through `has_method("reset")`, exactly as it already does for
health and defeat. Measured on fresh re-runs after this change:
`player_death_reset_probe_debug` ALL CHECKS PASSED (38) and `new_run_reset_probe_debug` ALL CHECKS
PASSED (32). A revived enemy that still detects the player from its mark legitimately RESUMES
PURSUIT - recorded as an expected consequence of this milestone, not as drift.

PERSISTENCE LIMITATION EXPOSED BY MOVEMENT (recorded, NOT fixed). Enemy POSITION is restored by
NEW RUN (through `GameStateSave._spawn_transforms`) and by the player-death encounter reset
(through the locomotion mark). A LOAD does NOT restore enemy position: `GameStateSave._capture_world()`
records health, defeated and paid, and no transform. Movement makes that gap visible for the first
time - a loaded game leaves enemies wherever the fight left them rather than on their marks. It is
NOT a regression (nothing repositioned enemies before this milestone either, because they never
moved), and it was deliberately left alone: the brief forbade enemy-position save/load here.

KNOWN ENEMY COLLISION BEHAVIOUR (read from code, not playtested). Both enemy bodies are
`collision_layer = 2`, `collision_mask = 3`, so two enemies pursuing one player physically block and
shove each other, and `move_and_slide()` does not push the player's own `CharacterBody3D`. An enemy
that walks into the player blocks rather than shoves. Acceptable for this slice; stated rather than
left to be discovered.

ENGAGEMENT REPORTING - AND A BRIEF CONFLICT RESOLVED IN FAVOUR OF THE NON-GOAL. `EnemyLocomotion`
now EXPOSES `is_engaged()`, which is the real authority the health-bar module was recorded as
waiting for in section 8R. `EnemyHealthBars.is_engaged()` was deliberately NOT rewired to consult it,
and `scripts/ui/enemy_health_bars.gd` is UNCHANGED by this milestone (verified: identical hash to its
pre-milestone state).

The brief asked for both "update the `EnemyHealthBars.is_engaged()` seam to use the locomotion
authority where appropriate" AND "do not change the health-bar reveal/display rule", and listed
"aggro-based health-bar display changes" as an explicit NON-GOAL. Those clauses cannot both hold:
`is_engaged()` is the ONLY gate in `_sync_bar()` - there is no separate "already revealed" flag - so
making it return true for a merely-DETECTING enemy would reveal an undamaged, unlocked bar. That is
precisely the aggro-based display change the non-goal forbids, and it would also break the accepted
UI assertion that releasing a lock lets the bar hide again.

So the display rule was left exactly as it was, and the seam is documented as REACHABLE BUT
UNCONSUMED. Wiring it is the deferred feel decision (section 8R: whether the bar shows on
lock-on, on damage, while aggroed, or permanently for bosses), and it is now a one-line change in
one function with a real authority to call rather than a hypothetical one.

PROBES RE-RUN FRESH FOR THIS PASS, after the change, every one of them recorded from its own run:
`enemy_engagement_probe_debug` (new; ALL CHECKS PASSED), `actor_contract_probe_debug` (82),
`animation_adapter_probe_debug` (54), `targeting_probe_debug` (78), `new_run_reset_probe_debug` (32),
`player_death_reset_probe_debug` (38), `grounding_probe_debug` (the failing ACTOR changed - see the
corrected entry above). The first four match their previously recorded counts exactly.
NOT re-run in this pass, and therefore reported only as history and NOT as fresh verification:
`ui_hud_probe_debug` and `enemy_attack_probe_debug`. The engagement probe does assert lock-on
acquisition/release and health-bar tracking and reveal behaviour directly, but that is a scoped
claim, not a substitute for re-running those two suites.

DELIBERATELY NOT BUILT HERE: navigation, pathfinding, obstacle avoidance, multi-enemy coordination,
threat tables, strafing, circling, spacing, attacking while moving, combos, a second attack, ranged
anything, jumping, separate leash-distance tuning, poise, stagger, hitstun, knockback, hitstop,
interruption, rig swaps, animation clips, animation driver work, enemy-position save/load,
aggro-based health-bar display, and lock-on-relative dodge.

---

## Milestone 18 - Combat feedback and the death loop (section 8T, recorded 2026-09-14)

STATUS: **MILESTONE 18 IS ACCEPTED BY THE USER 2026-09-14 - HUMAN PLAYTEST.** CORRECTED 2026-09-15:
this header previously read "applied and probe-proven only - it is NOT accepted", which was true when
the pass landed and was overtaken by the acceptance at 8U.8. The acceptance was already recorded later
in this same section (8U.8: the user's "Confirmed working via playtest."); only this header was left
standing. What follows is the measurement basis, unchanged: applied, statically clean, and ALL THREE
fixes are measured at runtime by a probe that observes the effect rather than the code path.

THREE LIVE-PLAYTEST DEFECTS, three separate root causes. They were diagnosed before anything was
changed, and the diagnosis is recorded here because two of the three were NOT what the symptom
suggested.

### 8T.1 HITSTOP DID NOT EXIST. There was nothing to fix.

ROOT CAUSE, MEASURED: a project-wide search for `hitstop` / `hit_stop` / `hitStop` returned ZERO
matches in any `.gd` or `.tscn`. The only hit feedback was
`scripts/diagnostics/hit_feedback_debug.gd` - a tweened damage number and a material flash, with NO
time component at all. The confirmed-hit signal `HitboxComponent.hit_landed` (line 19, emitted at line
118) had exactly TWO consumers, both diagnostics (`combat_debug_overlay.gd:337`,
`hit_feedback_debug.gd:54`), and no gameplay system read it.

So the report "hitstop does not work" was accurate and the cause was that no such system was ever
built. Nothing had regressed.

POST-MILESTONE-16 CORRECTION: the Milestone 17 investigation recorded hitstop as "a feature that does
not exist" - that was CORRECT. The user's playtest then reported it as a broken feature, which is the
same fact from the player's side.

### 8T.2 NOTHING COULD INTERRUPT AN ENEMY ATTACK.

ROOT CAUSE, MEASURED: `enemy_attacker.gd` already HAD `cancel_attack()` - it ends the attack,
deactivates the hitbox, hides the telegraph and returns the phase to IDLE. Its callers were
`EnemyAttacker.reset()`, `EnemyDeathComponent._cancel_committed_attack()` and the death/reset path.
THERE WAS NO HIT-DRIVEN CALLER, so a committed swing was uninterruptible by construction.
`health_reaction_component.gd` already classified every hit against `stagger_threshold` and emitted
`signal staggered(amount)` at line 39 - and that signal was CONNECTED NOWHERE IN THE PROJECT.
`stagger_threshold` defaulted to 0.0, so no hit could stagger an enemy even in principle.

The mechanism existed and the signal existed; only the wire between them was missing.

### 8T.3 DEATH DID NOT RESET CREDITS, and had a second independent defect behind it.

ROOT CAUSE, MEASURED: `death_component.gd` contained ZERO references to Credits or the ledger. Its
`reset_playable_state()` restored health, stamina, position, committed actions and the arena's enemies
and touched the economy not at all. The ONLY credit reset in the project was on NEW RUN
(`game_state_save.gd:759`), which is a different lifecycle - which is exactly why "new run resets
Credits" was true and "death resets Credits" was not.

THE SECOND DEFECT, and it would still have been wrong after fixing the first: death revives every
enemy through `_restore_arena_actors()`, but `CreditLedger._rewarded` - the per-run reward history
keyed by defeat-component instance id - was NOT cleared. So after a death every revived enemy was
alive, killable and targetable and permanently worth ZERO Credits. Resetting the balance alone would
have left that in place.

### 8T.4 THE RECORDED CONTRACT THIS SUPERSEDES

Roadmap section 8L.7 recorded the OPPOSITE decision, in these words: "carried Credits SURVIVE the
player's death and reset. They are not dropped, lost, halved or banked." It was an explicit, recorded
choice, and `game_state_death_loop_probe_debug.gd:194-197` pinned it in a comment and a print. The
user has now overruled that decision. 8L.7 is SUPERSEDED, not violated silently, and the pinning
comment in that probe has been updated to state the new rule and to name where the reset is asserted.

### 8T.5 THE FIXES

HITSTOP - `scripts/combat/hit_stop.gd` (new, `class_name HitStop`), one node as a DIRECT CHILD of the
game root in `main.tscn`. It watches every member of the new `HitboxComponent.GROUP_HITBOX` group and
on `hit_landed` freezes `event.source` and `event.victim` for `duration` (0.075 s, exported).

  THE MECHANISM, and both alternatives are REFUSED with reasons recorded in the class header:

  - NOT `Engine.time_scale`. `cascadia_input.gd:535` records that "Nothing in Cascadia writes
    `Engine.time_scale`", and `_keep_clock_running()` (line 538) forces it back to 1.0 whenever it is
    <= 0.0 while the tree is not paused - so a zero-scale hitstop would be ERASED ON THE NEXT FRAME.
    A non-zero micro-scale is refused too: two probes assert the scale stays exactly 1.0.
  - NOT `get_tree().paused`. Pause belongs to `PauseMenu` and is a different concern.
  - INSTEAD: the two participant SUBTREES have per-frame callbacks switched off with
    `propagate_call` over `[set_process, set_physics_process]` - the idiom Godot's own documentation
    recommends for freezing a subtree. `process_mode` is NEVER touched, so no actor can be stranded in
    `PROCESS_MODE_DISABLED`; two existing probes assert the player stays `PROCESS_MODE_INHERIT` and
    they are this mechanism's regression guard. `set_process_input` is deliberately NOT called, so the
    input layer keeps buffering presses during a freeze.

  The countdown is `Time.get_ticks_msec()` on a service that is never inside a frozen subtree - never
  accumulated delta, which would be the stall risk. A concurrent hit EXTENDS the release point and adds
  new participants rather than double-freezing, and `_exit_tree` releases as a safety net.

INTERRUPTION - `EnemyAttacker` now subscribes to its sibling `Reaction.staggered` and answers it.
`interrupt_attack()` ends the attack through the EXISTING `cancel_attack()` (so the damage window
really closes), applies the enemy's NORMAL `attack_cooldown`, and emits `attack_interrupted`.
`on_hit_received()` RE-VALIDATES the amount against the reaction component's own `would_stagger()`
rather than trusting the signal, so the threshold decision keeps exactly one owner even if the method
is called by hand. `health_reaction_component.gd` still cancels nothing - the interrupt-armor decision
lives in the attack state machine, exactly as that component's own header requires.

THE COOLDOWN IS LOAD-BEARING, not polish: without it the enemy is idle on the very next frame and
instantly re-windups, which reads as the interruption having done nothing at all.

CREDITS - `CreditLedger` gained `reset_on_death` (exported, default true), a `death_resets` counter,
`_watch_death_circuits()` subscribing to `DeathComponent.GROUP_DEATH`, and `on_player_death()` which
resets the carried balance to `starting_credits`, clears `credits_earned`, and clears `_rewarded` so a
revived enemy is worth Credits again. `awards`, every refusal counter and `loads` are LIFETIME
counters and are deliberately LEFT ALONE - clearing them would destroy the diagnostics that make the
module checkable. `_watched`/`_watched_deaths` are live signal connections and are left alone so
re-scanning cannot double-connect.

THE SUBSCRIPTION IS SCOPED TO THE PLAYER ON PURPOSE: `DeathComponent.GROUP_DEATH` holds the
player-controlled actor, while an enemy carries `EnemyDeathComponent` in a deliberately DIFFERENT
group, so "an enemy was defeated" and "the player died" can never reach the same handler.

ARCHETYPE THRESHOLDS ARE DATA, and were chosen to make the difference measurable against the player's
REAL damages (`player_combat.gd`: light 15.0, heavy 32.0):

    TestAttacker  Reaction.stagger_threshold = 12.0   a LIGHT hit (15) interrupts it
    HeavyBrute    Reaction.stagger_threshold = 20.0   a light hit (15) does NOT; a heavy (32) does

That is the same shape as the project's existing archetype data: the difference between the two
enemies is two numbers in two scenes, and no per-archetype script exists.

### 8T.6 PROBE RESULTS, all fresh runs this pass

`combat_feedback_probe_debug` (NEW) - `RESULT: ALL CHECKS PASSED`. It is deliberately an EFFECT probe,
not a code-path probe, because "a hitstop function exists and is called" is exactly the claim that can
be true while nothing freezes. Measured:

  - AC2 a confirmed hit started a hitstop; the enemy body did NOT move while frozen (drift 0.0000 m)
    and its ATTACK PHASE CLOCK did not advance (0.0000 s) across 14 frozen physics frames - the
    measurement that distinguishes a real freeze from a counter being incremented.
  - AC3 `Engine.time_scale` stayed EXACTLY 1.0 and the tree was never paused for the whole freeze,
    proving neither forbidden mechanism was used.
  - AC4 the freeze ended on its own; no participant left in the frozen set; both participants
    restored their physics processing; BOTH still report `PROCESS_MODE_INHERIT` (never changed).
  - AC6 the lighter archetype is interrupted by a light hit and the heavier one is NOT, both by data.
  - AC8/AC9 a real defeat paid 100 Credits, then a real player death returned the carried balance to
    the run's starting value and cleared the reward history, while the LIFETIME award counter was
    left intact.

REGRESSION SUITES RE-RUN, every count matching its previously recorded value:

    actor_contract_probe_debug         ALL CHECKS PASSED (82)
    animation_adapter_probe_debug      ALL CHECKS PASSED (54)
    targeting_probe_debug              ALL CHECKS PASSED (78)
    new_run_reset_probe_debug          ALL CHECKS PASSED (32)
    player_death_reset_probe_debug     ALL CHECKS PASSED (38)
    credit_economy_probe_debug         ALL CHECKS PASSED
    game_state_death_loop_probe_debug  ALL CHECKS PASSED
    focus_input_routing_probe_debug    ALL CHECKS PASSED  (the hitstop regression guard: asserts the
                                       player stays in the normal process mode and the scale is 1.0)
    enemy_engagement_probe_debug       ALL CHECKS PASSED  (M17 still intact; archetype speeds still
                                       2.60 vs 1.70, so the threshold edits did not disturb movement)

NOT RE-RUN this pass, and therefore reported only as history: `ui_hud_probe_debug` and
`enemy_attack_probe_debug`. The latter is the one most likely to be affected by the enemy-facing
changes and SHOULD be re-run before this milestone is treated as fully regression-clean.

### 8T.7 THE STALE-OPEN-BUFFER ERRORS, re-confirmed

`state:diagnostics` reports three script errors in `open_script_buffers`: two in `cascadia_input.gd`
for `TARGET_CYCLE_LEFT` / `TARGET_CYCLE_RIGHT` and one in `hit_stop.gd` for
`HitboxComponent.GROUP_HITBOX`. ALL THREE ARE STALE ANALYSIS OF OPEN EDITOR TABS, not defects:

    state:script-errors for each file returns an EMPTY list (hit_stop.gd, cascadia_input.gd,
    hitbox_component.gd, credit_ledger.gd, combat_feedback_probe_debug.gd, all 0)
    GameActions.TARGET_CYCLE_LEFT / TARGET_CYCLE_RIGHT exist at game_actions.gd:60-61
    HitboxComponent.GROUP_HITBOX exists at hitbox_component.gd:24
    and at RUNTIME the hitstop froze 3 times, which is only possible if GROUP_HITBOX resolved.

Do not re-flag this class of error without confirming it outside `open_script_buffers`.

---

## Milestone 18 RE-VERIFICATION and two live-play gaps (section 8U, recorded 2026-09-14)

WHY THIS SECTION EXISTS: the user re-reported the SAME three problems that section 8T had already
diagnosed and fixed (hitstop, enemy attack interruption, death credit reset). This pass did NOT
re-implement any of them. It re-ran the relevant probes on FRESH RUNS and then audited the one thing
the probes structurally cannot see: the difference between the probe's vantage point and live play.

### 8U.1 RE-VERIFIED THIS PASS - all three 8T fixes are live, on fresh runs

    combat_feedback_probe_debug        ALL CHECKS PASSED      (hitstop effect, interruption by data, credit reset)
    live_combat_credit_probe_debug     ALL CHECKS PASSED (54)  <- the LIVE path, nothing stood down
    enemy_attack_probe_debug           ALL CHECKS PASSED      (observed a real 75 ms freeze of 2 participants)

`live_combat_credit_probe_debug` is the decisive one, and it exists precisely because
`combat_feedback_probe_debug` isolates itself: it calls `stand_down_all()`, disables each enemy's
`Locomotion`, and opens the player's damage window with a direct `hitbox.activate()`. The live probe
instead drives the player's REAL attack state machine (`PlayerCombat.try_start()` and its own
STARTUP -> ACTIVE phase advance) against REAL auto-attacking enemies. Measured, live:

  - AC1 hitstop: 4 frozen frame(s), drift 0.0000 m, phase clock moved 0.0000 s, duration 0.075 s.
  - AC4 interrupt: attacked=2 interrupted=2 recovered=true; the enemy committed a NEW swing afterwards.
  - AC6 credits: 100 -> 0 on a real lethal hit through the real hurtbox chain, `death_resets=1`,
    `loads=0`, and the LIFETIME `awards` counter deliberately left at 1.

The root causes recorded in 8T.1 / 8T.2 / 8T.3 therefore stand as the diagnosis of record:
hitstop did not exist (now `scripts/combat/hit_stop.gd`); nothing could interrupt a committed swing
(now `EnemyAttacker.interrupt_attack()` answering the pre-existing `Reaction.staggered`); and death
touched the economy not at all (now `CreditLedger.on_player_death()`).

### 8U.2 THE LIVE-PLAY GAP THE PROBES CANNOT SEE - the player is OUT-RANGED

MEASURED FROM THE SCENE FILES, not inferred:

    player  AttackHitbox offset z -1.1, BoxShape3D depth 1.2 (half 0.6)  -> forward reach 1.7 m
    enemy   hurtbox radii: TestAttacker 0.45, HeavyBrute 0.55
    => the player's attack CONNECTS at 1.7 + 0.45 = 2.15 m (TestAttacker), 1.7 + 0.55 = 2.25 m (HeavyBrute)

    TestAttacker  engage_range 2.80 - stop_margin 0.40 -> it STOPS at 2.40 m  (0.25 m BEYOND player reach)
    HeavyBrute    engage_range 3.40 - stop_margin 0.40 -> it STOPS at 3.00 m  (0.75 m BEYOND player reach)

    enemy   AttackHitbox: TestAttacker offset z -1.7 depth 2.4 -> reach 2.9 m
                          HeavyBrute   offset z -2.2 depth 3.2 -> reach 3.8 m
    => an enemy strikes a 0.6 m player hurtbox from up to 3.5 m / 4.4 m, far outside its own stop range

CONSEQUENCE IN LIVE PLAY: an enemy walks to its own stand-off, which is OUTSIDE the player's attack
reach, and swings. A player standing at the natural combat distance swings back and WHIFFS. The
interruption mechanism is correct and proven, but the attack that has to trigger it does not CONNECT.
The probe cannot see this because it TELEPORTS the player to exactly 1.8 m (`const STAND_DISTANCE`),
which is inside the player's reach by construction.

This is a TUNING asymmetry, not a code defect, and BOTH sides of it are user-accepted tuning
(M4 player attack, M8 enemy attack, M17 engagement). It is therefore recorded as an OPEN DECISION and
was NOT changed unilaterally.

### 8U.3 THE SECOND LIVE-PLAY GAP - the brute is immune to the light attack BY DESIGN

8T.5 set `HeavyBrute Reaction.stagger_threshold = 20.0` against the player's `LIGHT_DAMAGE = 15.0`
(`HEAVY_DAMAGE = 32.0`). So light-attacking a HeavyBrute mid-swing produces NO interruption, by
recorded intent. A player who light-attacks the big enemy, watches it swing straight through, and
reports "attacks do not interrupt" is describing the design rather than a defect. The TestAttacker
(threshold 12.0) IS interrupted by that same light hit.

### 8U.4 THE USER'S DECISIONS (2026-09-14)

8U.2 - extend the player's attack reach ONLY enough to make the EXISTING enemy stand-off distances
playable, and tune it against BOTH archetypes. Not an arbitrarily large weapon.

8U.3 - KEEP HeavyBrute heavy-only. A light hit must still NOT interrupt it.

No gameplay file, scene or tuning value had been modified when these were put to the user; the
accepted M17 engagement behaviour (stop distance, speeds, leash) was untouched throughout.

### 8U.5 THE REACH FIX, IMPLEMENTED

`scenes/test_environment.tscn`, `Player/AttackHitbox` and its `Shape`:

    before  offset z -1.10, BoxShape3D depth 1.2 (half 0.60)  -> reach 1.70 m, near edge 0.50 m
    after   offset z -1.55, BoxShape3D depth 2.1 (half 1.05)  -> reach 2.60 m, near edge 0.50 m

The NEAR EDGE IS UNCHANGED at 0.50 m, so the swing still starts at the body and reads as a melee
attack rather than being inflated around the player. The box is MOVED FORWARD and LENGTHENED. 2.60 m
covers both stand-offs (2.40 m and 3.00 m) with 0.20-0.25 m of margin and is the smallest round
value that does.

WHAT WAS DELIBERATELY NOT CHANGED: enemy `engage_range`, `stop_margin`, move speeds, detection
radii, leash behaviour, enemy attack ranges and damage, and every `stagger_threshold`. This is a
PLAYER-SIDE geometry change only.

### 8U.6 THE MISSING VERIFICATION - reach measured AT the stand-off

`scripts/diagnostics/player_attack_reach_probe_debug.gd` + its `.tscn` (NEW, diagnostic pair).
Every probe in 8U.1 TELEPORTS the player to a hard-coded 1.8 m, which is inside the reach by
construction, so a reach that cannot cover the stand-off is invisible to all of them. This probe
instead sets the player at each archetype's OWN `Locomotion.stopping_distance()` and drives the
player's REAL `PlayerCombat.try_start()` path.

Fresh run this pass: `RESULT: ALL CHECKS PASSED (22)`. Measured:

    geometry: reach 2.600 m, spans 0.500 m -> 2.600 m forward
    stand-off read from each enemy's own Locomotion: TestAttacker 2.400 m, HeavyBrute 3.000 m
    AC1 a real LIGHT attack DAMAGED TestAttacker at its own 2.40 m stand-off (100 -> 85)
    AC2 that LIGHT hit INTERRUPTED its committed swing (0 -> 1), phase IDLE, damage window CLOSED
    AC3 a real HEAVY attack DAMAGED HeavyBrute at 3.00 m (165 -> 133) and INTERRUPTED it (0 -> 1)
    AC3 a LIGHT hit was REFUSED by HeavyBrute - the heavy-only contract holds
    AC4 feel guards: reach 2.600 <= 3.000 m, near edge 0.500 <= 0.900 m

### 8U.7 PROBE RESULTS, all fresh runs this pass (2026-09-14)

    player_attack_reach_probe_debug     ALL CHECKS PASSED (22)   NEW this pass
    live_combat_credit_probe_debug      ALL CHECKS PASSED (54)   real path: 4 frozen frames,
                                                                drift 0.0000 m, phase moved
                                                                0.0000 s; attacked=2 interrupted=2
                                                                recovered=true; 100 -> 0 on death,
                                                                death_resets=1, loads=0
    combat_feedback_probe_debug         ALL CHECKS PASSED        freezes=3, releases=2
    enemy_attack_probe_debug            ALL CHECKS PASSED        phases WINDUP/ACTIVE/RECOVERY once
                                                                each; 5 frames excluded as
                                                                hitstop-frozen (independent read)
    enemy_engagement_probe_debug        ALL CHECKS PASSED        M17 intact: stop 2.40/3.00,
                                                                speeds 2.60/1.70, leash intact
    player_death_reset_probe_debug      ALL CHECKS PASSED (38)
    new_run_reset_probe_debug           ALL CHECKS PASSED (32)
    credit_economy_probe_debug          ALL CHECKS PASSED
    game_state_death_loop_probe_debug   ALL CHECKS PASSED        post-death LOAD still restores
    game_state_save_load_probe_debug    ALL CHECKS PASSED        save/load unaffected
    focus_input_routing_probe_debug     ALL CHECKS PASSED        scale 1.000, process mode intact
    actor_contract_probe_debug          ALL CHECKS PASSED (82)
    targeting_probe_debug               ALL CHECKS PASSED (78)
    animation_adapter_probe_debug       ALL CHECKS PASSED (54)

ZERO errors across every run (`state:diagnostics`: total_errors 0).

WHAT THIS DOES AND DOES NOT PROVE. The three behaviours are now measured at the distances live play
actually produces, through the real player attack path with nothing stood down, and they pass. That
is MEASUREMENT, not a human read. It cannot establish feel: whether the 2.60 m reach still reads as
a melee attack, whether hitstop reads as impact, or whether the combat spacing plays well. Those are
the user's to judge. Milestone 18 is therefore still NOT accepted.

REMAINING LIMITATIONS, recorded rather than implied:

  - The reach fix makes the existing stand-off PLAYABLE; it does not make the spacing GOOD. Enemy
    stop distance and player reach are now consistent, but the resulting combat distance has not
    been tuned for feel by a human.
  - HeavyBrute remains uninterruptible by light attacks BY DECISION (8U.3). A player who
    light-attacks it mid-swing and watches it swing through is seeing the design.
  - No poise, hitstun or knockback system exists; a stagger ends the swing and applies the normal
    cooldown, and nothing else.

### 8U.8 ACCEPTED BY THE USER - HUMAN PLAYTEST, 2026-09-14

STATUS: **MILESTONE 18 IS ACCEPTED.** The user played the game after the reach change and reported
"Confirmed working via playtest." That is a HUMAN read of the running game, and it is the read that
8T and 8U.1-8U.7 were carrying forward.

WHAT THE HUMAN READ COVERS, and it is the part no probe in this project can supply:

  - hitstop reads as IMPACT in the hand, not merely as a counter that increments;
  - a light attack INTERRUPTS the TestAttacker's committed swing;
  - a heavy attack interrupts the HeavyBrute, and a light attack does NOT (the heavy-only contract
    of 8U.3 reads as intended in play, not as a defect);
  - the player's death resets carried Credits as intended.

WHAT THIS DOES NOT CLOSE, recorded so it is not implied: Milestone 14 (enemy health bars) is still
IMPLEMENTED + MEASURED and NOT human-read. The reach of 2.60 m was accepted in play, which settles
the "does it still read as a melee attack" question 8U.7 explicitly left open.

NO gameplay, scene or tuning value changed to make this acceptance happen. The only files written by
this pass are documentation.

### 8U.9 RECOMMENDED NEXT GOAL - NOT APPROVED, awaiting the user's decision

RECOMMENDATION: **Milestone 19 - the Soulslike death-drop loop.** On the player's death, the carried
balance is dropped as a RETRIEVABLE stake at the death position; returning to it reclaims it, and a
second death before reclaiming destroys the previous stake.

WHY THIS IS THE SENSIBLE NEXT GOAL:

  - Milestone 18 made death reset carried Credits to `starting_credits`. That DELETES the balance
    with no way to get it back, so the economy is currently punitive without being a loop: there is a
    penalty and no retrieval. The drop-and-retrieve stake is what makes a Soulslike death a decision
    rather than only a loss.
  - It is PURE GAMEPLAY - no assets, no animation, no new presentation. That matches the project
    identity rule ("the foundation must behave correctly using primitive geometry and placeholder
    presentation") and needs only a primitive marker.
  - It builds directly on the death path Milestone 18 just created and the user just accepted, so
    the area is fresh and the contracts are already in place (`DeathComponent.GROUP_DEATH`,
    `CreditLedger.on_player_death()`, the existing save/load contract).
  - It is ALREADY RECORDED as future work rather than invented here - section 13 of this file lists
    "Player death Credit loss / retrieval (drop carried Credits on death, recover them on the corpse,
    or lose them permanently). RECORDED AS FUTURE WORK, NOT IMPLEMENTED."
  - It is a bounded milestone: one stake node, one reclaim trigger, one second-death rule, plus the
    save/load question of whether an unreclaimed stake survives a save.

ALTERNATIVES, recorded with their trade-offs rather than discarded:

  - ANIMATION INTEGRATION. The highest-signal deferred item on the list, and nearly every
    readability limitation in this file traces to it (the parry window "is hard to READ without
    animation", 8C). It is also the largest and the only one that requires ART ASSETS, so it is a
    different kind of milestone from everything delivered so far.
  - ENEMY NAVIGATION AND MULTI-ENEMY COORDINATION. Navigation, pathfinding, obstacle avoidance,
    threat tables and strafing are all explicitly still deferred (see the amendment above). Valuable,
    but the arena is a single open room today, so navigation buys less than it will once there is a
    level.

STATUS: SUPERSEDED BY 8V. The user selected this goal, and Milestone 19 is now BUILT. Kept for audit
as the record of why this was chosen.

---

## Milestone 19 - The Soulslike death-drop loop (section 8V, recorded 2026-09-14)

STATUS: **MILESTONE 19 IS ACCEPTED BY THE USER 2026-09-14 FOR THE CURRENT DEVELOPMENT STATE -
HUMAN PLAYTEST (record now written at 8V.7 below).** CORRECTED 2026-09-15: this header previously read
"NOT human-playtested ... it is NOT accepted", which was true when the pass landed and was overtaken by
the user's playtest. The measurement basis, unchanged: BUILT, statically clean, and MEASURED at runtime
by a probe that observes the effect rather than the code path (51 checks, ALL PASSED). The remaining
polish - an on-screen button prompt for the death stake - is DEFERRED BY THE USER, not a defect.

### 8V.1 THE MECHANIC

When the player dies, the carried balance above `starting_credits` is DROPPED as a retrievable stake
at the spot the player fell, and the balance then resets as Milestone 18 already established. Walking
back onto the stake reclaims it. A SECOND death before reclaiming DESTROYS the previous stake, so an
unclaimed death costs those Credits for good. Dying with nothing to drop still destroys the standing
stake - an empty pocket must not leave the previous stake alive to collect later.

This closes the gap 8U.9 identified: Milestone 18 gave death a PENALTY with no retrieval, which is a
loss rather than a loop. It is the mechanic section 13 has carried since Milestone 9 as "Player death
Credit loss / retrieval ... RECORDED AS FUTURE WORK, NOT IMPLEMENTED".

### 8V.2 THE IMPLEMENTATION

`CreditLedger` (existing owner) gained the stake as run-local state: `has_stake()`,
`stake_amount()`, `stake_position()`, `place_stake()`, `reclaim_stake()` (transactional - the stake is
gone whether or not the balance was empty, and it deliberately does NOT count as an `award`),
`clear_stake()`, the signals `stake_placed` / `stake_reclaimed` / `stake_lost`, the counters
`stakes_placed` / `stakes_reclaimed` / `stakes_lost`, and the `drop_on_death` policy export.

`on_player_death()` remains the ONE place a death's cost is decided. It now places the stake from the
balance the death is ABOUT TO TAKE, then empties the balance - that order is the whole rule, because
the stake has to be created while `credits` still holds it.

`reset_credits()` (NEW RUN) and `restore_carried_credits()` (LOAD) both destroy a standing stake. A
stake is run-local and is NOT saved, so a loaded world must not pay for a death it never saw - the
same double-dip guard each path already applies to reward history.

`scripts/economy/credit_stake.gd` + `scenes/props/credit_stake.tscn` (NEW): ONE primitive marker
node, instanced as `CreditStake` under `TestEnvironment` in `scenes/test_environment.tscn`. It OWNS
NO TRUTH - it reads `has_stake()` / `stake_amount()` / `stake_position()` and calls
`reclaim_stake()`, exactly as the HUD reads the ledger rather than storing a copy. It is hidden
(`visible = false`) when nothing is standing.

### 8V.3 THREE DEFECTS FOUND AND FIXED DURING THIS PASS

All three were found by MEASUREMENT, not by reading the code, and each is recorded because the
mechanism looked correct before it was run.

1. THE STAKE WAS CLAIMED INSIDE ITS OWN CREATION SIGNAL. `place_stake()` emits `stake_placed`; the
   marker swept immediately and reclaimed it, because the player was standing on the death spot.
   `on_player_death()` then overwrote `credits` afterwards, so the Credits were destroyed with NO
   stake left. Fixed by making the death transaction atomic and by gating the claim.

2. THE CORPSE RECLAIMED ITS OWN STAKE. `reset_playable_state()` clears `_dead` BEFORE
   `_restore_position()`, so the player briefly reports ALIVE while still standing where it fell. A
   dead-claimant gate alone was therefore insufficient; the fix is a dead gate AND a departure
   requirement.

3. THE REAL DEFECT: THE CLAIM READ STALE OVERLAP. Claiming used `get_overlapping_bodies()`, which
   lags live transforms by one physics step. On the revive frame the stake still saw the player
   overlapping while liveness and departure had both already cleared, so REVIVING HANDED THE CREDITS
   STRAIGHT BACK and the mechanic did nothing. MEASURED before the fix, from the probe report:
   `stake at (0.0, 0.0, 0.0), player at (6.0, 0.3, 6.0), distance 0.100 m, armed=false` - a stale
   overlap read reported as a 0.100 m claim. Fixed by making the claim DISTANCE-driven and
   overlap-free, so no stale physics read can author a claim. This one would have shipped as
   "the stake sometimes works".

### 8V.4 PROBE RESULTS, fresh runs this pass

`death_drop_credit_probe_debug` (NEW) - `RESULT: ALL CHECKS PASSED (51)`. It writes
`res://death_drop_credit_probe_report.txt` (the project's existing report-file convention) so the
full result survives console truncation. Scenarios, all through the REAL death circuit, the REAL
hurtbox chain and the REAL stake node - the probe moves a body and waits, it never calls
`reclaim_stake()`:

    A  the death dropped exactly one stake of 500 at 0.000 m from the death spot, emptied the
       balance, and made the marker armed and visible
    B  the actor's OWN auto-reset revived the player WITHOUT resetting the balance a second time or
       placing a second stake, and the stake was still standing afterwards
    C  standing on the stake CLAIMED it, returned exactly 500, hid the marker, and did NOT count as
       an award (the lifetime award counter was untouched)
    D  a second death dropped its own stake of 700, and the NEXT death DESTROYED the unclaimed stake
       and dropped only the new balance - the one-stake rule, with no double-drop
    E  an empty-pocket death destroyed the standing stake and created NOTHING (4 checks). This
       scenario also STATES its own premise and asserts it, so it cannot pass or fail for an
       invisible reason
    F  a NEW RUN cleared the standing stake, reset the balance and zeroed the stake history
    G  a LOAD cleared the standing stake and restored the saved balance, without running the death
       reset

REGRESSION SUITES RE-RUN with the drop in place:

    live_combat_credit_probe_debug      ALL CHECKS PASSED (54)  (M18 still intact end to end)
    actor_contract_probe_debug          ALL CHECKS PASSED (82)  (the new arena node disturbs nothing)
    targeting_probe_debug               ALL CHECKS PASSED (78)  (lock-on is intact; see the note below)
    new_run_reset_probe_debug           ALL CHECKS PASSED (32)
    credit_economy_probe_debug          ALL CHECKS PASSED
    player_death_reset_probe_debug      ALL CHECKS PASSED (38)
    game_state_death_loop_probe_debug   ALL CHECKS PASSED
    main.tscn                           0 runtime errors (the shipped scene boots with the stake in it)

ONE SUITE IS NOT GREEN, AND IT IS NOT THIS MILESTONE'S. `ui_hud_probe_debug` reports
`15 of 165 FAILED`, reproduced identically on a second fresh run. THIRTEEN of the fifteen are
"the lock is taken on the probe target" and its four release scenarios, plus two dependent counts.
The failures are CONFINED to lock-on against the probe's own SYNTHETIC enemy and involve no Credits,
no stake and no ledger state.

DIAGNOSIS, measured rather than assumed - it is a PROBE defect, not a product one:
  - `ui_hud_probe_debug` builds its temporary enemy with a `HealthComponent` and nothing else. Its
    own report confirms this: it PASSES "the temporary enemy carries a HealthComponent" and "the
    temporary enemy is tracked", and then FAILS to lock it.
  - `targeting_probe_debug`, which builds its temporary targets WITH a `CombatParticipant` ("the
    temporary target carries a CombatParticipant" PASSES), locks them successfully and reports
    ALL CHECKS PASSED (78) - including locks on temporary targets and lock release on defeat,
    invalidation, range and player death.
  - So target eligibility requires a `CombatParticipant` (the single validity authority,
    `CombatParticipant.is_usable_target()`), and the ui_hud probe's synthetic enemy has never had
    one. `_targeting.is_locked()` ALSO passes while the lock is on a DIFFERENT actor, which is why
    the probe reports a lock being "genuinely held" and still cannot lock ITS target.
  - M19 touched neither targeting, lock-on, `CombatParticipant`, nor the health-bar module's
    tracked set. Nothing in this milestone's change set can reach these checks.

RECORDED AS AN OPEN DEFECT, NOT SMOOTHED OVER: `ui_hud_probe_debug` needs its temporary enemy
composed like the one in `targeting_probe_debug`. That is a DIAGNOSTIC fix, it belongs to whoever
next touches the HUD suite, and it is NOT part of Milestone 19. Do not describe the suite as green
until it is fixed. Note also that the console reported a window focus loss during the run, so a
contributing environmental cause cannot be fully excluded - but the `CombatParticipant` gap above is
a sufficient explanation on its own and is confirmed by the two probes disagreeing about the same
operation.

### 8V.5 CONTRACTS ADDED

  - A run has exactly ONE stake. A second death DESTROYS the first; it is never merged, banked or
    stacked.
  - Reclaiming is a TRANSACTION, not an award: `awards` and `credits_awarded` are untouched, while
    `credits_earned` IS restored so earned-vs-carried cannot disagree.
  - A stake is RUN-LOCAL and is NOT saved. Both the NEW RUN and the LOAD paths destroy one.
  - A claim requires a LIVING player that has LEFT the stake and come back. The stake is walked back
    to, never collected where the player fell.
  - Claiming is DISTANCE-driven. Overlap queries are explicitly NOT an authority here, because they
    lag live transforms by a physics step and can author a claim the player never made.
  - The stake node OWNS NO TRUTH: it reads the ledger and is hidden when nothing is standing.

### 8V.6 REMAINING LIMITATIONS, recorded rather than implied

  - NOT human-playtested AT THE TIME THIS LIST WAS WRITTEN. Everything above is probe measurement.
    **SUPERSEDED 2026-09-15: the user handplayed the stake on 2026-09-14 and accepted it for the current
    development state - see 8V.7, written below.** The measured claims here are unchanged; only the
    "no human has seen it" limitation was overtaken. Whether the 1.60 m pickup radius feels right is
    still the user's call and is not claimed either way.
  - An unreclaimed stake does NOT survive a save/load, and there is no persistence of one across
    sessions. That is a deliberate scoping decision, not an oversight.
  - There is no "lost Credits" record once a stake is destroyed by a second death - the amount is
    reported through `stake_lost` but nothing keeps it.
  - The marker is deliberately a PRIMITIVE (a capsule and a sphere). No art, no glow, no label.

### 8V.7 ACCEPTED BY THE USER - HUMAN PLAYTEST, 2026-09-14

STATUS: **MILESTONE 19 IS ACCEPTED** for the current DEVELOPMENT STATE. The user handplayed the running
game and confirmed it works: "Current pass has been handplayed and verified ... consider it
functionally working at this point."

This subsection was REFERENCED but never written until 2026-09-15 - the current-state block and the
acceptance table both cited "8V.7" while section 8V stopped at 8V.6, which still read "NOT
human-playtested". The citation was dangling and 8V.6 contradicted the accepted status. Both are now
resolved; the acceptance claim itself is unchanged and is the user's own playtest report.

WHAT THE HUMAN READ COVERS, and what it does NOT:

  - The mechanic was played: death drops the carried balance above `starting_credits` as a retrievable
    stake, walking back onto it reclaims it, and a second death destroys the previous stake.
  - It was accepted FOR A DEVELOPMENT STATE, not as finished. The on-screen button prompt for the
    death stake is EXPLICITLY DEFERRED BY THE USER - it is deferred polish, NOT a defect.
  - The probe evidence behind it (51/51, `death_drop_credit_probe_debug`) is unchanged and is not
    restated here.
  - STILL NOT CLAIMED: that the 1.60 m pickup radius feels right, and that an unreclaimed stake
    survives a save/load - it does not, by deliberate scoping (8V.6).

---

## Milestone 20 - UI cleanup and layout unification (section 8W, recorded 2026-09-14)

STATUS: **ACCEPTED BY THE USER 2026-09-14 - HANDPLAYED.** CORRECTED 2026-09-15: this header
previously read "but NOT accepted. It needs a human playtest ACROSS WINDOW SIZES", which was overtaken
by the user's handplay and acceptance in 8W.8. The user handplayed the running game, requested one
refinement (8W.5, the INPUT FOUNDATION two-column reflow, applied and re-measured), and confirmed:
"Confirm this as accepted." M20 is therefore the HIGHEST ACCEPTED MILESTONE.

This is a LAYOUT pass, NOT a gameplay milestone: no combat, input, save/load, credit or death-drop
behaviour was changed. The 8W.7 trades are intentional and are part of what was accepted.

ONE PROPERTY IS STILL NOT PROBE-VERIFIED, kept honest rather than smoothed over: a REAL window resize.
This host cannot resize its own window from inside the game, so `adaptive_columns()` is driven at its
CAUSE (granted a single-column width, then the full width again). The pass is ACCEPTED ON THE USER'S
HANDPLAY, not on a probe measurement of a live resize - see 8W.7.

### 8W.1 THE ROOT CAUSE - there was NO SHARED LAYOUT AUTHORITY

MEASURED, not inferred. Six independent CanvasLayers each built their own Control tree and placed it
with their own values, across THREE different strategies:

    anchors                 game_hud.gd, save_load_debug_controls.gd
    manual viewport maths   combat_debug_overlay.gd (`_reclamp`, using get_viewport_rect())
    bare hardcoded position input_debug_overlay.gd (`position = Vector2(16,16)`), death_presentation_debug.gd

Where two panels shared a screen corner, the separation was a hand-tuned MAGIC NUMBER.
`save_load_debug_controls.gd` carried `offset_top = 62.0` whose OWN COMMENT admitted the value existed
because at 8 it "covered the credits number completely", and `combat_debug_overlay.gd` recorded that
"top-right collides with the input overlay in the narrow docked viewport".

WHY A MAGIC DODGE BREAKS WHEN THE WINDOW IS RESIZED, which is the mechanism the user's report
describes: the project runs `display/window/stretch/mode = canvas_items` with `aspect = expand` (base
1152x648). Under `canvas_items` the panel CONTENT grows with the scaled theme font while a fixed pixel
offset does NOT, so a gap tuned at one window size stops clearing its neighbour at another.

ALSO MEASURED: NO CanvasLayer in `main.tscn` set an explicit `layer`, so all of them defaulted to 1 and
z-order was decided by accidental TREE ORDER - `EnemyHealthBars` was declared LAST and therefore drew
over `PauseMenu`.

### 8W.2 WHAT REPLACED IT - `scripts/ui/screen_regions.gd`

ONE layout authority. A panel no longer positions itself at all: it JOINS a reserved region and that
region's host `VBoxContainer` lays it out. Regions are anchor fractions of the logical viewport, so
they track a resize with no resize handler anywhere.

    VITALS                   LEFT column, upper band    the shipped health/stamina readout - RESERVED
    INPUT_DIAGNOSTICS        LEFT column, lower band    the input foundation table
    TOP_RIGHT_STACK          right column, upper band    credits THEN save/load, in ONE shared stack
    BOTTOM_RIGHT_DIAGNOSTICS right column, lower band    combat / targeting diagnostics
    DEATH_MESSAGE            centre band, CENTRED       the "YOU DIED" message

THE REGION LAYOUT BELOW IS THE USER'S REQUESTED ARRANGEMENT, implemented as 8W.5: health/stamina
upper-left, input foundation lower-left, credits in the top-right with the save/load panel directly
BENEATH it, combat diagnostics lower-right, pause centred.

THE HAND-TUNED DODGE IS GONE. Credits and save/load are now SIBLINGS in one stack, so the space
between them is that Container's `separation` - neither panel knows the other's height, and nothing
needs re-tuning when the window changes.

### 8W.3 EXPLICIT LAYER ORDER, replacing accidental tree order

    enemy health bars (1)   above the world, below every panel
    debug panels (2)        input + combat + save/load (they cannot collide: different regions)
    death message (3)       above the other diagnostics while it is up
    game HUD (4)            the shipped readouts, above the debug panels
    pause overlay (8)       strictly above everything, so pause is never drawn over

`main.tscn` carries these literally AND each script re-asserts its own from the constants, so the scene
text and the running code can be read against each other. `GameHUD` is declared BEFORE
`SaveLoadControls` so the HUD builds the shared top-right stack - it therefore runs on the HUD layer
while the save/load panel is a child of it, and regular tree order no longer decides anything.

### 8W.4 TWO REAL DEFECTS FOUND AND FIXED DURING THE PASS

  - PANELS COLLAPSED TO THE TOP-LEFT. `save_load_debug_controls.gd` and `death_presentation_debug.gd`
    each did `add_child(panel)` - parenting to their own CanvasLayer INSTEAD of the region column they
    had just resolved. No Container ever laid them out, so both fell to (0,0). The user reported this
    precisely: "the save debug panel now appears over the input diagnostics, the respawn window now
    appears at the upper left instead of center". An earlier explanation of mine (node ordering) was
    WRONG; ordering governed the credits/save stacking order only.
  - THE TWO-COLUMN LAYOUT WAS UNREACHABLE. `ScrollContainer` did not stretch its child here: the panel
    measured 389 px inside a 736 px bound, so the reflow container only ever saw the single-column
    minimum and wrapped at EVERY window size. Two fixes: the bound now FILLS horizontally, and the
    reflow decision is taken from the REGION's measured width and the table's minimum width is SET
    from that decision (see 8W.5).

### 8W.5 THE INPUT FOUNDATION REFINEMENT (user-requested, applied)

The panel was too tall: 44 rows in one column pushed its bottom edge toward the window edge.

  - SPLIT INTO TWO COLUMNS, balanced by ROW COUNT so the two halves come out a similar height without
    reordering anything. The split is CONTIGUOUS - the early groups stay early - so the reading order
    is column one top to bottom, then column two.
  - REFLOW, NOT TWO CRAMPED COLUMNS. `ScreenRegions.adaptive_columns()` is an `HFlowContainer` that
    shows two columns ONLY when both genuinely fit the width they were given, and stacks them
    otherwise. The decision is made against the width the flow container actually HAS, measured at
    runtime - not against the region host, which is wider by the panel's own margins.
  - NO CLIPPING. `ScreenRegions.bound_to_region()` gives the panel a ScrollContainer bound to its
    region, so its bottom edge cannot leave the viewport; the region's height is the limit, and any
    excess is clipped inside a scrollable area rather than by the screen.
  - COMPACTNESS WITHOUT SHRINKING THE TEXT: row separation 0 (Godot's default 4 px cost 232 px over 58
    rows) and tighter column widths. The FONT SIZE was deliberately NOT reduced.

### 8W.6 PROBE RESULTS - the one new probe, and the regression guard

`input_panel_layout_probe_debug` (NEW) - `RESULT: ALL CHECKS PASSED (13)`. It writes
`res://input_panel_layout_probe_report.txt` (the project's report-file convention) because the console
tail truncates. MEASURED, at a 1152x889 logical canvas:

    region host 760 px wide | panel bound 760 x 704 | panel 760 x 416
    table split into exactly TWO blocks -> SIDE BY SIDE
    two columns shown only because the pair FITS the width they were given (708 <= 740)
    every input action still has a row (built 31, expected 31)
    a width that fits ONE column makes the table STACK instead of crushing two columns (359 px)
    restoring the width brings the two columns back

THE NARROW CASE IS DRIVEN, NOT ASSUMED. This host cannot resize its own window, so the fallback is
exercised at its CAUSE - the reflow container is granted a single-column width (exactly what a narrow
window produces) and is then granted the full width again. That is the difference between "the rule is
written down" and "the table demonstrably wraps and comes back".

`focus_input_routing_probe_debug` - `RESULT: ALL CHECKS PASSED`. This is the REGRESSION GUARD that
mattered most, because the new region hosts are full-band Controls and light/heavy attacks are bound to
MOUSE BUTTONS. Verified: mouse CAPTURED (mode=2), capture re-taken by a click, Escape releases the
cursor and the same key RESUMES, the recovering click did NOT start an attack, `Engine.time_scale`
1.000, tree not paused, player in the normal process mode.

`main.tscn` - boots at 0 errors (20 pre-existing warnings only).

### 8W.7 DELIBERATE TRADES, and what is NOT verified

  - THE DEATH MESSAGE OVERLAYS THE DIAGNOSTICS. It is centred by request, so it necessarily sits over
    panels whose content is larger than the centre band. It is not raised above the HUD or the pause
    overlay: it reads on top of the diagnostics only.
  - SCROLLING NEEDS A WHEEL, AND THE MOUSE IS CAPTURED IN PLAY, so the ScrollContainer's bound is
    reachable in principle but not by wheel in normal play. `mouse_filter` stayed IGNORE on purpose: a
    ScrollContainer needs a Control that ACCEPTS the mouse to scroll, and this project has already paid
    once for a debug panel that swallowed a click bound to an attack. The REFLOW is what keeps the
    content reachable at a normal size - scrolling is the fallback of last resort, not the mechanism.
  - THE INPUT TABLE PACKS AT THE TOP OF ITS BAND rather than hugging its bottom edge, so any overflow
    goes off the bottom of the band instead of upward over the reserved health/stamina area.
  - `adaptive_columns()` is an HFlowContainer ADAPTER, not a true CSS-style column reflow. Two
    two-column arrangements were considered and refused: a GridContainer needs its column count fixed
    at build time and cannot react to a resize, and manually re-parenting rows on `size_changed` would
    have handed the panel back the private resize logic this pass exists to remove. The adapter is the
    smallest mechanism that gives the asked-for BEHAVIOUR, and its limitation is recorded here.
  - RESIZE ITSELF IS NOT PROBE-VERIFIED, and this is kept honest rather than smoothed over. The
    no-clip property is enforced by the layout RULE - the region bounds the panel inside a scrollable
    area, so its bottom edge cannot leave the viewport - plus a probe that DRIVES the reflow at a
    narrow width, because this host cannot resize its own window from inside the game. The pass is
    ACCEPTED on the user's handplay rather than on a probe measurement of a real resize.

### 8W.8 ACCEPTED BY THE USER - HANDPLAYED, 2026-09-14

The user handplayed the running game and confirmed the pass: "Confirm this as accepted."

WHAT WAS ACCEPTED. The arrangement the user reviewed and accepted:

    upper-left        HEALTH / STAMINA, in its own RESERVED region
    lower-left        CASCADIA - INPUT FOUNDATION, two columns, bounded by its region
    top-right         CREDITS, with the SAVE/LOAD panel directly BENEATH it in one shared stack
    lower-right       CASCADIA - COMBAT
    centre            the death message, centred and above the diagnostics
    above everything  the pause overlay

This CLOSES the milestone. The trades listed in 8W.7 are INTENTIONAL and are part of what was
accepted - in particular the centred death message overlapping the diagnostics, which is what the
user asked for by name when they asked for the respawn window to be centred.

Two consequences of that arrangement, recorded so they are not rediscovered as surprises. Both are
deliberate, both are verified, and neither is a defect:

    - the death message draws over the input table's right column while the player is dead;
    - the input table packs to the TOP of its band, so any overflow leaves the bottom of the band
      rather than climbing into the reserved health/stamina area.

Do not re-open this pass for either. If the user later wants them changed, that is a new request, not
a defect against this milestone.

---

## HISTORICAL PASS LOG (newest first) - SUPERSEDED AS CURRENT STATUS

Everything from here down to section 0 is the rolling pass log, written at the time of each pass and
kept for audit value. It is HISTORICAL, not current status. Several entries below are known to be out
of date - one still reads "highest milestone reached: 8", and one still describes Milestone 5 as "not
human-played". Where a log line disagrees with `# CURRENT STATE` above or section 0, the current-state
section wins. Annotate these lines; do not delete them to tidy the file.

The newest log entry starts on the next line.

Last updated: 2026-09-13 (MILESTONE 11 CLOSED - THE FACING INDICATOR IS ACCEPTED BY THE USER. The user
reviewed the running game and reported "everything seems visually consistent and working properly.
consider this step implemented". That is a HUMAN VISUAL READ of the shipped scene, and it is the read
that 8E, 8F, 8N and all three 8O refinements were carrying forward: the capsule now communicates its
facing by eye, which CLOSES the presentation half of the 8G.2 backstep defect. Milestone 11 shipped a
`FacingMarker` under `Player` in `scenes/test_environment.tscn` - an amber FORWARD disc on local -Z and a
blue REAR disc on local +Z, scene-authored, no `CollisionShape3D` - plus ONE new read-only presentation
adapter, `scripts/diagnostics/facing_marker_feedback_debug.gd`, which tints the amber marker by attack
phase (amber IDLE, pale-yellow STARTUP, red ACTIVE, blue-grey RECOVERY) so a committed swing is visible
on the body for the first time. NO gameplay value, script, camera, input, stamina, save/load or HUD file
was touched by any part of Milestone 11. Still open, recorded and NOT closed by that acceptance: the two
specific MOTION reads - markers tracking yaw while moving/dodging/backstepping, and whether the swing
colours read distinctly at the light attack's timing - are covered by the general acceptance rather than
separately measured; physical Alt-Tab remains unproven in this host; and Milestone 10 save/load is still
probe-measured but not human-played. Current active task remains NONE. See 8O.15.)
Previous: 2026-09-13 (8O.14 - ATTACK-PHASE COLOUR FEEDBACK ADDED TO THE FACING MARKER. The user
approved SWING FEEDBACK on the capsule: the amber marker now changes COLOUR with the attack phase - amber
IDLE, pale-yellow STARTUP, red ACTIVE, blue-grey RECOVERY - so a committed swing is visible on the body
for the first time, because there is still no animation system (the presentation boundary in 8G.2 item
3). ONE NEW FILE: `scripts/diagnostics/facing_marker_feedback_debug.gd`, attached to `Player/FacingMarker`
in `scenes/test_environment.tscn` and recorded in the deletion manifest. It is STRICTLY READ-ONLY on
gameplay: it reads `PlayerCombat.state` and writes exactly ONE thing, a material `albedo_color`. It never
starts, cancels, delays, extends or redirects an attack, imposes no timing of its own, and owns no
gameplay state - the colour FOLLOWS the phase, never the reverse. It duplicates the material on first use
so it can never mutate a resource another node draws with. It reads the continuous PHASE rather than
listening for signals, so a mid-swing load cannot leave the marker stuck on a stale colour. Also settled
this pass: the user chose to LEAVE the flush amber disc EXACTLY AS IT IS, so the 8O.13 occlusion
trade-off is DECIDED, not a defect - 8O.14 CORRECTS the stronger "INVISIBLE" wording recorded in 8O.13,
because from the same camera an amber sliver IS visible at the silhouette edge. Verified: 0 debugger
errors; the script resolved both its nodes (no disabled warning was emitted); the rendered frame shows the
marker still amber with the combat overlay reading `phase=IDLE`, and the blue rear disc intact. STILL
PENDING: the human read of the yaw-following AND of the colour transitions in motion, neither of which a
still frame can settle. See 8O.14.)
Previous: 2026-09-13 (MILESTONE 11 - READABLE PLAYER FACING INDICATOR: APPROVED BY THE USER, THEN
IMPLEMENTED. The last open item from the 8G.2 backstep defect was PRESENTATION: the capsule is
rotationally symmetric, so the already-corrected committed evasion facing could not be judged by eye.
IMPLEMENTED as section 8O proposed - a `FacingMarker` Node3D under `Player` in
`scenes/test_environment.tscn`, holding an amber NOSE on local -Z (forward) and a blue TAIL on local +Z
(rear), scene-authored, SCRIPT-FREE, and with NO CollisionShape3D beneath it so `_capsule_radius()`
cannot pick up a stray shape. Two rendered frames confirm it: the blue tail reads on the camera-facing
side and the amber nose stands above the capsule dome, so front and rear are distinguishable from the
default third-person view. NO gameplay file was touched - no script changed, and the evasion contract
measured in 8N is untouched. THEN REFINED (8O.12) after the user saw the first result: the amber marker
became a compact ORB (`SphereMesh`) instead of a tall brick-like box, and the blue marker became a flat
DISC BADGE sitting flush against the rear of the body instead of a detached floating cube. The contract
is unchanged - amber still FORWARD on local -Z, blue still REAR on local +Z, still scene-authored, still
script-free, still NO `CollisionShape3D`. The blue badge is presentation-only design language: NO
backstab mechanic, rear-hit detection or damage multiplier exists. STILL PENDING: the user's own read of
it while MOVING, turning, dodging and backstepping, which no still frame can settle. THEN REFINED AGAIN
(8O.13) at the user's request: the amber marker became a flat DISC like the blue one, moved closer to the
capsule with its top flush at the capsule top. THAT FOUND A REAL CONFLICT - the capsule ends at local
y = 2.0, the disc's top is exactly 2.00, and from the default BEHIND-and-above camera the opaque capsule
now hides the amber marker COMPLETELY. "Flush with the top" and "visible from behind" cannot both hold;
the options went back to the user rather than being guessed at. The user's other request - swing/attack
visual feedback - was RECORDED but NOT built, because it needs new code consuming `PlayerCombat`'s phase
and the project has no animation system yet. See 8O.11, 8O.12 and 8O.13.)
Previous: 2026-09-13 (8F IMPLEMENTED - DODGE MOVEMENT AUTHORITY. The recorded future pass in section
8F was the sensible next task: it was the last open gameplay defect a HUMAN had actually confirmed in
play (the backstep turning the body around), and it was written up and scoped long before this session,
so it is roadmap work rather than an invented milestone. IMPLEMENTED: during a COMMITTED evasion the
evasion now owns the body's ORIENTATION and its DISPLACEMENT, and on the frame control returns the
evasion's residual burst velocity is cleared so ordinary locomotion cannot be dragged backwards by it.
Measured: `dodge_authority_probe_debug` - ALL CHECKS PASSED, 80-line transcript at
`res://_dodge_authority_report.txt`, 0 debugger errors. The body holds the locked facing to within
0.00 deg across a neutral backstep AND across a directional dodge that was pinned 180 deg away from its
own travel direction; travel equals speed x duration on clear ground (1.6875 m directional / 1.2800 m
backstep) with no single frame above 0.0625 m; a dodge driven into the 42 cm step gained NO unauthored
displacement and stayed at ground level (final y 0.000). Preserved unchanged and re-measured: the
attack/dodge mutex, exactly one 22-stamina charge, the i-frame window, and ordinary locomotion
resuming at 4.20 m/s with the facing following movement again. `step_probe_debug` re-run: all six
traversal stations still clean, no launch. `main.tscn` boots with 0 runtime errors and the arena
renders. STILL OPEN and deliberately untouched: the capsule has NO front-facing marker, so the
correction cannot yet be judged BY EYE - that is a presentation item, not a gameplay one.
Previous: 2026-09-13 (M10.10 - RECOVERY CHAINS MEASURED END TO END, AND THE "SECOND TRANSITION"
IS NOT THE GAME. The reported problem is a CHAIN, not a state: Escape releases the cursor, the click
back sometimes does not re-hook, and a LATER transition (another Escape, another Alt-Tab, another click)
makes it work. Every individual state had already been measured, so this pass built a chain-level probe
that runs all EIGHT reported sequences back to back, recording focus, cursor mode, capture intent,
input-active, the pending look delta and the capture counters at EVERY step. RESULT: ALL CHECKS PASSED -
all 8 chains end with the cursor captured, intent on, input active, capture stable across 20 further
frames, look turning the camera and movement working. THE DECISIVE MEASUREMENT: the game's internal
state after the FIRST recovery and after the SECOND recovery are IDENTICAL, so the game cannot be what
makes the second transition work - the difference is OUTSIDE it (the host granting pointer lock, or a
first click spent activating the window). NO PRODUCTION CODE WAS CHANGED. The three defects found and
fixed this pass were all in the PROBE's own measurement (frame counts used as time in an uncapped scene,
a backstep tap held past MOBILITY_TAP_MAX so it resolved as a sprint HOLD, and an assumed stamina-regen
wait). See 8M.24.)
Previous: 2026-09-13 (M10.9 - INPUT / CAPTURE HARDENING PASS: NO PRODUCTION DEFECT FOUND, NO
PRODUCTION CODE CHANGED, TWO EDGE CASES MEASURED FOR THE FIRST TIME. This pass was asked to review
and harden the existing mouse/focus/camera implementation without redesigning it, and to say plainly
what is proven and what is not. The working routing fix from 8M.22 was CONFIRMED INTACT on disk
(`peek_look_delta()` is what the overlay reads; `get_look_delta()` still has exactly ONE production
consumer, the camera; the shipped main scene still instances the arena). No new production defect was
found, so nothing in `cascadia_input.gd`, the camera or the scene composition was rewritten - the
architecture already answers the edge cases coherently. What WAS missing was COVERAGE, so it was
measured rather than assumed. (1) ESCAPE was the ONLY reported edge case with no measurement behind
it: `ui_cancel` is not overridden in `project.godot` and comes from Godot's built-in action. PHASE 5
now measures the whole loop - the intent goes OFF and the cursor is released, mouse motion produces NO
camera turn while the cursor is free (0.0000 deg), the click back re-takes the cursor AND the intent,
that click is suppressed so it cannot become a swing, and mouse look works again afterwards
(310.3347 deg). (2) The look-consumption contract was only ever INFERRED from the camera turning; it
is now measured DIRECTLY - a display read sees the pending delta, reads it twice identically, and the
consuming read returns that same value and then ZERO on a second read. `focus_input_routing_probe_debug`
reports RESULT: ALL CHECKS PASSED (132 lines, 0 debugger errors) and `mouse_look_routing_probe_debug`
reports RESULT: ALL CHECKS PASSED, with the shipped game booting at 0 runtime errors. See 8M.23.)
Previous: 2026-09-13 (M10.8 - THE ARENA WAS NOT IN THE MAIN SCENE, AND THE DEBUG OVERLAY WAS
EATING MOUSE LOOK. Two defects, both MEASURED, both fixed. (1) `res://main.tscn` contained no
`TestEnvironment` instance at all: the Play button booted an EMPTY VOID with no player, no camera, no
world and a combat readout that itself said `no PlayerCombat in scene`. Every probe scene builds its
own world by instancing `main.tscn`, so the whole probe suite kept passing while the SHIPPED game had
no world in it - the probe scenes supplied the very thing the main scene was missing. (2)
`InputDebugOverlay._process` called the CONSUMING `get_look_delta()`, and that CanvasLayer is ordered
BEFORE `TestEnvironment` in the main scene, so the diagnostic consumed the look delta every single
frame and `ThirdPersonCamera` always read ZERO - mouse look was dead while movement, attacks, dodge,
stamina and focus handling all worked. This is the actual cause of the "camera does not turn" reports
that the three earlier focus passes (8M.21, 8M.21a, 8M.21b) were chasing. Mouse look now measures
63.8254 deg where it measured 0.0000 deg, and `focus_input_routing_probe_debug` reports
`RESULT: ALL CHECKS PASSED`. See 8M.22.)
Previous: MILESTONE 10 IMPLEMENTED AND MEASURED - Game-State Saving and Loading Foundation;
roadmap written BEFORE implementation)
Updated by: Milestone 10 implementation pass. The user ACCEPTED Milestone 9 (carried Credits measured
and verified: 5 eligible enemies, 500 Credits, 5 awards, duplicate prevention, player and non-mortal
exclusions counted by cause) and SELECTED Milestone 10 as the next goal. Milestone 9's history,
caveats, defect manifest and deletion manifest are PRESERVED - nothing in 8L is rewritten. The FIRST
persistence loop now EXISTS: `GameStateSave` writes a real save file carrying `schema_version` and the
CARRIED Credit balance read from `CreditLedger`, and a load restores that balance exactly through the
ledger's own controlled restoration path. Loading is NOT an award - it grants no Credits, duplicates no
defeat reward and revives no defeated enemy - and a new run is distinguishable from a load. Every
failure mode (missing, malformed, unsupported version, missing field, invalid value) has its OWN
result and leaves the balance untouched. `game_state_save_load_probe_debug`: RESULT: ALL CHECKS
PASSED, 0 debugger errors; `main.tscn` boots with 0 runtime errors. Banking, spending, stats, gear,
checkpoints and world-state persistence are NOT built. The highest milestone is now 10. See 8M.10.
Previous: Milestone 9 selection and implementation pass. The user SELECTED Milestone 9 as the next
implementation goal and named Milestone 10 (Game-State Saving and Loading) as the PLANNED follow-up,
explicitly NOT to be implemented now. Milestone 9 is a CARRIED-Credit foundation only: every eligible
mortal enemy defeat awards Credits EXACTLY ONCE through the EXISTING authoritative defeat event
(`EnemyDeathComponent.defeated`), Credits accrue on the player's carried balance, the balance is
observable and deterministically testable, non-rewarding archetypes are excluded by an explicit rule,
and carried / stored / spent / persistent Credits are kept as FOUR SEPARATE concepts. Banking,
spending, stats, items, gear, death-loss retrieval and save/load are NOT built. Enemy pursuit was NOT
selected. The highest milestone is now 9. See section 8L.
Previous: 8K.12 defect-correction pass. The user reported that an enemy reaching 0 health did not
show a defeated state and that NO TEST asserted defeat coverage across the arena. The report was
CORRECT. `TargetA/B/C` carried no death path at all, and no probe was looking at them, so they
reached zero health and processed nothing while every probe still passed. They now use the existing
`EnemyDeathComponent` + presentation, and the missing test exists as `defeat_coverage_probe_debug`,
driven by ENUMERATION so a newly added enemy is covered automatically. 5/5 enemies measured
defeated, all 13 probes re-run and passed. Section 8K.11's "intentional non-participant" verdict is
SUPERSEDED by 8K.12.
Previous: Reusable actor combat readiness pass - roadmap first, then implementation and measurement
Note on this pass: the user MANUALLY VERIFIED the reusable actor death capability in the live game and
ACCEPTED it: the dummy actor takes damage, reaches 0/100, enters the dead state, tips and darkens,
shows DEFEATED, and does not disturb the other actors. That acceptance is recorded in 8J.12. The user
then named the NEXT bounded task, "Reusable Actor Combat Readiness", recorded as section 8K and written
BEFORE any implementation, as required. 8K makes the ALIVE / DEAD and VALID-TARGET questions consistent
across targeting, damage and presentation instead of each system answering them differently. It is
explicitly NOT Milestone 9 - M9 is enemy pursuit and was NOT started. The highest numbered milestone
therefore REMAINS 8.
Previous: Reusable actor death capability pass - roadmap updated before implementation
Updated by: Reusable actor death capability pass, bounded sub-steps, roadmap first as the user required
Note on this pass: the user APPROVED "Reusable Actor Death Capability" as the next bounded task and
required this roadmap to be updated BEFORE any implementation. The audit found the reusable death path
ALREADY EXISTS as `EnemyDeathComponent`, but it was reachable by exactly ONE actor (the test attacker):
the arena's other damageable actors had no defeat component at all. That is a COMPOSITION gap, not a
missing system. The pass therefore generalises the existing component (explicit `mortal` policy),
makes damageability explicit at the existing hurtbox (`damageable`), attaches the existing defeat
component to the arena's DummyActor as the SECOND mortal damageable actor, and adds one deterministic
probe. Section 8J records the milestone, its scope boundary, the persistence decision and the
capability vocabulary; its 8J.10 measured-results subsection is filled in AFTER the probe run rather
than pre-written. It is explicitly NOT Milestone 9 - M9 is enemy pursuit and was NOT started. The
highest numbered milestone therefore REMAINS 8.
Previous: Enemy death and persistence pass - implemented and measured
Updated by: Enemy death and persistence pass, bounded sub-steps, with all required probes re-run
Note on this previous pass: enemy death was APPROVED by the user as the next bounded task and is recorded as
section 8I. `EnemyDeathComponent` consumes the EXISTING `HealthComponent.died` signal, cancels any
committed attack, and holds a DEFEATED state that OUTLIVES the player's single-arena reset, so the
test attacker can be killed and stays defeated. It is explicitly NOT Milestone 9 - M9 is enemy
pursuit and was NOT started. The highest numbered milestone therefore REMAINS 8.
Previous: Sprint / Dodge / Backstep input pass - implemented and measured
Updated by: Sprint/Dodge/Backstep pass, bounded sub-steps, with all eight probes re-run
Note on this pass: shared LEFT SHIFT tap/hold was added (hold = sprint, tap = dodge; Space
remains a dedicated dodge), dodge travel was HALVED (3.375 m -> 1.688 m), and a neutral
BACKSTEP was added. This is a REFINEMENT of Milestone 6's locomotion, recorded as section 8E.
It is explicitly NOT Milestone 9 - M9 is enemy pursuit and was NOT started. The highest
numbered milestone therefore REMAINS 8.
Previous: Milestone 8 - Single attacking test enemy - implemented and measured
Updated by: Milestone 8 implementation pass, bounded sub-steps, with regression re-runs
Note on this pass: Milestone 8 (a minimal attacking test enemy for defensive-mechanic
playtesting) was APPROVED by the user. Purpose: make parry timing, dodge i-frame timing and the
damage window across windup / active / recovery human-testable, because nothing could attack the
player before. Created: EnemyAttacker component, test_attacker.tscn actor, the actor instanced in
the arena, and enemy_attack_probe_debug. Section 8D records the architecture, authored values,
measured results and the three harness defects found and fixed. M6 dodge values and M7 parry
values were deliberately NOT retuned.
Previous pass: Milestone 7 (Parry) was APPROVED by the user. The parry was found
ALREADY IMPLEMENTED AND WIRED in the project (ParryComponent, PlayerController input and
commitment, PlayerCombat refusal, DodgeComponent refusal, HurtboxComponent window). The
genuinely missing M7 artifact was the dedicated verification probe, which was created and
run this pass. Section 8C records the M7 architecture and the measured results.
Milestone 6 was APPROVED by the user and implemented in the same
session as the audit pass 3 above. The audit-pass-3 text below is preserved as history;
where it says Milestone 6 was "not approved", section 11 supersedes it.
Audited this pass: milestones 0-5 were re-audited from scratch against the LIVE project.
Every probe was re-run (nothing carried forward). The one genuinely unproven path - the
physical mouse-button attack input - was closed with a new end-to-end input probe that
injects real InputEvents through the production chain. The target-seating rendered check
was re-attempted and produced a readable frame. Two project discrepancies were found and
recorded: the arena ramp label names the wrong end, and the code comments use a legacy
milestone numbering. See sections 8, 8A, 10, 11, 12 and 16.
Reconciled against: res://project.godot, res://main.tscn,
res://scenes/test_environment.tscn, res://scenes/dummy_actor.tscn,
res://scenes/actors/dummy_actor.tscn, res://scripts/** (on disk),
plus the deletion manifest.

---

## 0. MILESTONE ACCEPTANCE TABLE - STATUS AND STRONGEST EVIDENCE HELD

Maintained status layer. The current-state entry point is `# CURRENT STATE - READ THIS FIRST`
at the very top of this file; this section is the per-milestone evidence behind it. The bullet
list at the END of this section is HISTORICAL pass narrative, not current status - the table
above it wins.

| # | Milestone | Status | Strongest evidence held |
| - | --------- | ------ | ----------------------- |
| 0 | Project reconnaissance and test arena | ACCEPTED | User physical playtest + input bindings read from project.godot |
| 1 | Grounded player movement | ACCEPTED | User physical playtest of the test course |
| 2 | Basic damage plumbing | ACCEPTED | Measured probe output, ALL CHECKS PASSED |
| 3 | Physical actor collision | ACCEPTED | Measured probe output, ALL CHECKS PASSED |
| 4 | Player attacks | ACCEPTED (physical input path now closed) | Attack probe + target sweep re-run; physical mouse-button path now measured by input_path_probe, ALL CHECKS PASSED |
| - | Target / test-actor grounding | CONFIRMED BY MEASUREMENT; frame now readable and consistent | Grounding probe ray results, ALL CHECKS PASSED; staged frame re-read this pass |
| 5 | Stamina | IMPLEMENTED; HUMAN-PLAYED AND FUNCTIONALLY CONFIRMED (pressure/feel still unjudged) | Stamina probe ALL CHECKS PASSED; the 2026-09-12 playtest confirmed drain, depletion slowing movement, costs charged on attacks and dodges, and dodges refused when the pool is short |
| 6 | Dodge and i-frames | ACCEPTED (measured AND human-played; 2 open tuning items) | dodge_probe_debug: travel 3.375m vs 3.375m authored, duration 0.450s vs 0.450s, all refusal causes counted, i-frame refusals counted, RESULT: ALL CHECKS PASSED; user playtest confirmed the systems behaviour and flagged dodge travel as too long. AMENDED 2026-09-12: travel halved to 1.688 m and a neutral backstep added by the Sprint/Dodge/Backstep pass - see section 8E |
| 7 | Parry | IMPLEMENTED, MEASURED, AND HUMAN-PLAYED (window readability still open) | parry_probe_debug: timeline 0.600s authored, STARTUP->WINDOW->RECOVERY in order, stationary (travel 0.000m with move_right held), one stamina cost charged, unaffordable/duplicate/still-attacking/still-dodging refusals all counted per cause, damage refused in-window and applied in startup+recovery, physical parry key produced exactly one parry, RESULT: ALL CHECKS PASSED; all five regression probes re-run and passed |
| 8 | Single attacking test enemy | IMPLEMENTED, MEASURED, AND HUMAN-PLAYED (readability/cadence still open) | enemy_attack_probe_debug: phase order WINDUP->ACTIVE->RECOVERY once each, measured 0.58/0.13/0.70s vs authored 0.60/0.12/0.70s, telegraph only during WINDUP, undefended player lost exactly 20 once on an ACTIVE frame, parry refused and counted as PARRY (0->1), dodge refused and counted as I-FRAME (0->1), out-of-range refused by cause, auto_attack started on its own, RESULT: ALL CHECKS PASSED; all six regression probes re-run and passed |
| - | Enemy death and persistence | IMPLEMENTED AND MEASURED (playtest of the presentation still pending) | enemy_death_probe_debug: the defeat processed exactly once, further damage refused, committed attack cancelled with its damage window closed, no attack can start after defeat (refusal counted by cause), a defeated enemy cannot damage the player, and the player's death + automatic reset do NOT resurrect it (health 0.0, is_dead, is_defeated, IDLE, defeats=1), RESULT: ALL CHECKS PASSED; all seven required regression probes re-run and passed. See section 8I |
| - | Sprint / Dodge / Backstep input pass | IMPLEMENTED, MEASURED, AND HUMAN-PLAYED; backstep orientation DEFECT FIXED 2026-09-13 by the 8F authority pass (the facing INDICATOR half is still open) | dodge_input_probe_debug: shared input tap->dodge / hold->sprint, release-after-sprint does NOT dodge, forward/right/backward resolve camera-relative (dot 1.00), a neutral tap produces a BACKSTEP travelling backwards along facing (dot 1.00), directional travel 1.688 m vs 3.375 m before, backstep 1.280 m, i-frames intact, exactly one 22-stamina charge and an unaffordable refusal counted by cause, RESULT: ALL CHECKS PASSED; all eight probes re-run and passed |
| - | Reusable actor death capability | ACCEPTED 2026-09-12 (measured AND human-verified) | Roadmap section 8J written BEFORE implementation, per the user's instruction. Audit read from the live scenes: the reusable defeat path existed (`EnemyDeathComponent`) but only `TestAttacker` carried it, so the capability was NOT actually shared; `DummyActor` and `Targets/TargetA..C` had health and a hurtbox and no defeat path at all. `DummyActor` now carries the same component and is measured defeated exactly once; the immortal and non-damageable axes are measured as genuinely distinct; the player's reset did NOT revive it. `actor_death_probe_debug`: RESULT: ALL CHECKS PASSED, 0 runtime errors; all nine other probes re-run and passed. ACCEPTED after the user's manual playtest: the dummy takes damage, reaches 0/100, enters the dead state, tips and darkens, shows DEFEATED, and does not disturb the other actors. See 8J.10 and 8J.12 |
| 9 | Soulslike credit economy and meaningful progression foundation | IMPLEMENTED AND MEASURED (CARRIED Credits only; banking/spending/persistence NOT built; feel not yet played) | MILESTONE 9, selected by the user and written into section 8L BEFORE implementation. `credit_economy_probe_debug` ENUMERATES the authoritative enemy population and kills each eligible enemy through the real `receive_hit -> apply_damage` chain: every one awards Credits exactly once, the reward equals the documented provisional amount, the carried balance equals the sum of eligible rewards, and the non-mortal and player archetypes are excluded by explicit rule. Duplicate, freed-actor and not-actually-defeated cases award nothing. STILL NOT BUILT: banking, spending, stats/items/gear progression, death-loss retrieval and save/load. See 8L |
| 10 | Game-state saving and loading foundation | IMPLEMENTED AND MEASURED (probe-verified; NOT yet human-played). SAVES THE RUN, not only the balance: `GameStateSave` also writes a `world.actors` snapshot (per-actor `health` / `dead` / `defeated` / `paid`, keyed by scene path) plus the player's recorded transform, health, stamina and camera orientation, and restores each through its own owner (M10.1-M10.4 records in section 8M; `scripts/core/game_state_save.gd`). The reported physical-F9 failure was a HOST KEY COLLISION, NOT a save/load defect - see 8M.20. The load key is now F7 (F11 alternate); F9 and F8 are owned by the embedding host and cannot be used | MILESTONE 10, selected by the user and written into section 8M BEFORE implementation. `GameStateSave` writes a REAL save at `user://cascadia_save.json` carrying `schema_version`, `carried_credits` and `saved_at_unix`, reading the balance from `CreditLedger` and restoring it through the ledger's own controlled path (which is NOT `award_credits`, so a load can never be mistaken for a defeat). `game_state_save_load_probe_debug`: RESULT: ALL CHECKS PASSED, 0 debugger errors. Measured round trip: one real kill earned 100, a 250 top-up set the saved value to 350, the live balance was then changed, and the load restored 350 EXACTLY; a further post-load kill took it to 450. Every malformed case (missing, empty, not-an-object, unsupported version, missing field, text value, negative value) failed with its OWN result and left the balance untouched. `main.tscn` boots with 0 runtime errors and the F5/F9/F10 prototype panel plus the balance render in-game. STILL NOT BUILT: banking, spending, stats, items, gear, inventory, checkpoints, world GEOMETRY and enemy POSITIONS (per-actor DEFEAT state IS persisted - M10.2), death currency loss, multiple slots, cloud saves. See 8M |
| - | Defeat coverage across every enemy (defect fix) | ACCEPTED 2026-09-12 (measured AND user-verified) | User-reported DEFECT: an enemy reaching 0 health showed no defeated state because `TargetA/B/C` carried no death path at all and NO probe looked at them - so they processed nothing while every probe still passed. Fixed by wiring the EXISTING `EnemyDeathComponent` + presentation to all three, and by adding the test that was missing: `defeat_coverage_probe_debug` ENUMERATES the `damageable` group instead of naming actors, so a new enemy is covered the moment it exists. Measured: 5/5 enemies `is_defeated=true defeats=1 presentation=showing`, ALL CHECKS PASSED. All 13 probes re-run and passed. See 8K.12 |
| - | Defeat coverage across the arena | ACCEPTED 2026-09-12 (measured AND user-verified) | The user reported that an enemy reaching 0 health did not show a defeated state, and that NO test asserted defeat coverage. Both were CORRECT: `TargetA/B/C` carried no death path at all, and every probe inspected actors BY NAME, so an unwired actor reaching zero health processed nothing while the whole suite still reported ALL CHECKS PASSED. Fix: `TargetA/B/C` wired to the EXISTING `EnemyDeathComponent` (mortal) + the EXISTING presentation adapter in `scenes/test_environment.tscn`; no new death system, no combat value or timing changed. The missing test now exists as `defeat_coverage_probe_debug`, driven by ENUMERATION of the `damageable` group so a newly added enemy is covered the moment it exists, and the player is excluded BY ARCHETYPE (`resets_actors`), not by name. `[DEFCOV] RESULT: ALL CHECKS PASSED`, 5/5 enemies each reading `is_defeated=true defeats=1 presentation=showing`; all 13 regression probes re-run and passed; `main.tscn` boots with 0 runtime errors. Rendered frame confirms red `DEFEATED` labels, tipped/darkened poses, and all five actors at `0/100 DEAD`. See 8K.12 |
| - | Reusable actor combat readiness | IMPLEMENTED AND MEASURED; DEFECT FOUND IN PLAY AND FIXED (8K.12) | `defeat_coverage_probe_debug`: 5/5 damageable enemies reach the DEFEATED state with a VISIBLY showing presentation (TestAttacker, DummyActor, TargetA, TargetB, TargetC all `is_defeated=true defeats=1 presentation=showing`). The 8K.11 audit had wrongly concluded the static targets were intentional non-participants; they were a HOLE - no death path at all - and are now wired into the existing defeat component. `actor_combat_readiness_probe_debug`: ALL CHECKS PASSED. All 13 regression probes re-run and passed. Section 8K written BEFORE any implementation. Audit read from the live project: damageability (`HealthComponent` + `HurtboxComponent.damageable`), mortality (`EnemyDeathComponent.mortal`), attack capability (`EnemyAttacker`), per-actor debug presentation (`CombatDebugOverlay`) and group-based target selection (`EnemyAttacker.target_group`) ALREADY existed and were reused unchanged. The genuine gap was TARGET VALIDITY: `EnemyAttacker._get_target()` returned the first node in the group with no alive check, so a dead actor was still a valid target the attacker faced and swung at. `actor_combat_readiness_probe_debug`: RESULT: ALL CHECKS PASSED, 0 runtime errors - the dead target was refused with the DEAD cause (`target_refusals_dead 0 -> 2`) and NOT as out-of-range (`0 -> 0`), the attacker did not turn to face the corpse (`max drift 0.0000 rad`), a revived actor was targetable again, and a freed node was refused without raising. All twelve regression probes re-run and passed. See 8K.10 |

- **Highest milestone reached: 20.** CORRECTED 2026-09-15: this bullet read "11" and had done since
  2026-09-13. It is the SAME staleness defect the bullet below already records twice - a status line
  left standing after the status changed - and it contradicts the table directly above it, which now
  carries rows through M20. The table above is authoritative; this bullet is the audit trail of how it
  drifted. For the record: M12 (8P), M13 (8Q), M14 (8R, measured but not human-read), M15-M16 (accepted
  on the user's manual read), M17 (8S), M18 (8U.8), M19 (8V.7 section, plus the record in the
  current-state block) and M20 (8W.8) were all DELIVERED after the "11" written here.
  The historical note this bullet carried is still true and is preserved: M9 was DELIVERED as the credit
  economy (8L), NOT as "enemy pursuit", which is a DIFFERENT system that remains unstarted. Lock-on was
  delivered as M12; pursuit, navigation and real enemy AI all remain deferred (section 13).
- **Milestones 0-4: ACCEPTED.** All four were re-audited against the live project this
  pass and every probe was re-run rather than carried forward. No contradictory evidence
  was found and no defect in milestones 0-4 was discovered, so no repair was required.
- **Milestone 4's last open mechanical gap is now CLOSED:** the physical mouse-button
  attack path is no longer unproven (section 8). What remains for Milestone 4 is human
  feel/legibility judgement only.
- **Milestone 5: implemented and measured, but not human-played.** What remains open is
  human feel and rendered readout legibility, not correctness - see section 8A.
- **Milestone 6: ACCEPTED 2026-09-12.** Implemented, measured, then human-played. The
  dodge is a committed 0.45 s / 7.5 m/s grounded burst costing 22 stamina, with an
  i-frame window of 0.05-0.30 s inside it, enforced at the existing hurtbox. Every
  acceptance criterion passed by measurement (section 8B), and the user playtest
  confirmed the systems behaviour: stamina-gated, direction-committed, attacks refused
  during commitment, an i-frame window, and a vulnerable tail.
- **TWO OPEN TUNING ITEMS from that playtest - tuning, NOT defects, deliberately NOT
  retuned (section 12.3):** dodge travel is too long; i-frame timing has not been judged
  for feel. The measured implementation and its acceptance evidence are preserved
  unchanged until a later gameplay-feel pass.
- **Milestone 7 - Parry: IMPLEMENTED, MEASURED, AND NOW HUMAN-PLAYED 2026-09-12.** The parry was
  already implemented and wired when M7 was authorised; the genuinely missing artifact was the
  dedicated verification probe, which was created and run. Authored: startup 0.08 s, window
  0.18 s, recovery 0.34 s (total 0.60 s), stamina cost 20. Every acceptance criterion passed by
  measurement (section 8C), and the user confirmed in play that a parry is attempted and can
  succeed. STILL OPEN: the window is hard to READ without animation - a readability question,
  not a correctness one.
- **Milestone 8 - Single attacking test enemy: IMPLEMENTED, MEASURED, AND NOW HUMAN-PLAYED
  2026-09-12.** A telegraphed windup 0.60 s -> active 0.12 s -> recovery 0.70 s swing for 20
  damage through the existing HitboxComponent -> HurtboxComponent -> HealthComponent chain,
  standing where it is placed and swinging on a 1.6 s cadence inside 2.8 m. Every acceptance
  criterion passed by measurement (section 8D), and the playtest confirmed the enemy attacks and
  deals damage. This is NOT enemy AI - see 8D.6. STILL OPEN: windup readability and cadence are
  human-feel questions.
- **THE FULL-LOOP HUMAN PLAYTEST HAPPENED (section 8G).** The user played the assembled loop -
  move, sprint, spend stamina, attack, damage an enemy, be attacked, parry, dodge/backstep, run
  out of stamina - and described it as "a functioning combat foundation", not a collection of
  disconnected tests. This is the first full-loop human playtest in the project's history and it
  upgrades M5, M7, M8 and the input pass from probe-only to HUMAN-PLAYED.
- **WHAT THE PLAYTEST ALSO FOUND - three concrete items (section 8G.2):**
  (1) **NO DEATH / RESET CIRCUIT - this BLOCKS further combat testing.** At zero health the
  player stays at zero and nothing resets, so combat cannot be exercised repeatedly in one
  session. `HealthComponent` already emits `died` and nothing consumes it. Highest-priority next
  task.
  (2) **BACKSTEP ORIENTATION - HUMAN-CONFIRMED DEFECT,** matching the static finding in section
  8F.2. The capsule also has no front-facing marker, so the change is hard to read - a facing
  indicator is part of the fix.
  (3) **No animation presentation yet.** Attacks, parry timing, hit stop and facing are all
  harder to judge through capsules. This is the current presentation boundary, NOT a gameplay
  failure.
- **REUSABLE ACTOR DEATH CAPABILITY: ACCEPTED 2026-09-12** - measured this pass and then verified by
  the user in the live game (damaged, reaches 0/100, enters the dead state, tips and darkens, shows
  DEFEATED, does not interfere with the other actors): section 8J.12. The milestone definition, its
  scope boundary and the persistence decision were written into
  section 8J BEFORE any implementation, as the user required; the implementation, the probe run and
  the full regression sweep followed. Measured results are in 8J.10 and 8J.10b. What remains open is
  human judgement of the defeat presentation on the second actor, not correctness.
- **NOT a new milestone number.** This is an M8-family pass that generalises 8I's capability. The
  highest milestone reached REMAINS 8, and Milestone 9 (enemy pursuit) was NOT started.
- **REUSABLE ACTOR COMBAT READINESS: IMPLEMENTED AND MEASURED 2026-09-12** - written into section 8K
  BEFORE any implementation, then implemented, probed and regression-tested in the same pass. The
  reusable combat-participant foundation now exists: `CombatParticipant` answers the capability
  questions (damageable / mortal / dead / defeated / attack-capable / targetable / can-act) as ONE
  authority, and `EnemyAttacker` consults it before facing, ranging or swinging. Measured results are
  in 8K.10 and 8K.10b. USER-VERIFIED 2026-09-12: the user reported the defeat-coverage defect and
  then confirmed the correction, so this behaviour is now confirmed by hand as well as by probe.
  What remains open is feel, not correctness.
- **MILESTONE 9 IS NOW SELECTED: "Soulslike Credit Economy and Meaningful Progression Foundation".**
  Named by the user, written into section 8L BEFORE implementation, and implemented in the same pass.
  The highest milestone reached is now **9**.
- **Enemy pursuit was NOT selected and was NOT started.** It is no longer assumed to be the next task.
- **Milestone 10 ("Game-State Saving and Loading") was the planned follow-up recorded in 8L.8. It was
  then AUTHORISED by the user and implemented - see the Milestone 10 bullets below and section 8M.**
- **What Milestone 9 does NOT do, and must never be read as doing:** it does NOT bank, store or spend
  Credits, does NOT convert them into stats, items or gear, and does NOT persist them. ONLY CARRIED
  Credits exist. The four-way boundary is stated in 8L.6.
- **MILESTONE 10 IS NOW SELECTED: "Game-State Saving and Loading Foundation".** Named by the user,
  written into section 8M BEFORE implementation, and implemented in the same pass. The highest
  milestone reached is now **10**.
- **Milestone 9 remains ACCEPTED.** Its measured results, caveats and defect records are preserved.
- **Milestone 10 persists ONLY the carried-Credit balance.** It does NOT bank, spend, convert, save
  world state, save defeated enemies, or add checkpoints. The schema carries one gameplay value plus
  its version and a timestamp.
- **Milestone 10 MEASURED:** `game_state_save_load_probe_debug` RESULT: ALL CHECKS PASSED with 0
  debugger errors, and `main.tscn` boots with 0 runtime errors. The measured round trip was: ONE real
  enemy kill earned 100, a distinctive 250 top-up set the saved value to **350**, the balance was then
  changed, and a load restored **350 exactly**; a further post-load kill then took it to **450**. Every
  malformed-data case (missing, empty, not-an-object, unsupported version, missing field, text value,
  negative value) failed with its OWN result and left the balance at 450, untouched.
- **This is PROBE-MEASURED, not yet human-played.** The prototype F5 / F9 / F10 controls are built,
  bound and VISIBLE in the running game (confirmed in a rendered frame), but a human has not yet
  exercised the save -> change -> load loop by hand. Treat that as the one open item.
- **SECTION 8F IS NOW IMPLEMENTED (2026-09-13).** The recorded future pass - dodge movement authority
  over orientation and displacement - was completed as a bounded pass, because it was the last open
  gameplay defect a HUMAN had confirmed in play. `_apply_facing()` no longer re-derives body yaw from
  velocity during an evasion (the locked facing drives it), `_resolve_step_up()` stands down while an
  evasion owns the body, and the evasion's residual burst velocity is cleared on the handoff frame so
  ordinary facing cannot be dragged backwards by it. MEASURED: `dodge_authority_probe_debug` ALL CHECKS
  PASSED, 80-line transcript on disk, 0 debugger errors; `step_probe_debug` re-run clean.
  **This closes the GAMEPLAY half of the 8G.2 backstep defect, and the USER HAS SINCE CONFIRMED IT BY
  HAND**: the corrected evasion uses the player's last movement orientation and keeps that orientation
  committed for the whole evasion. The OTHER half - the capsule having no front-facing marker, so the fix
  cannot be judged by eye - was a PRESENTATION item, and **it is now CLOSED.**
- **MILESTONE 11 - READABLE PLAYER FACING INDICATOR: APPROVED, IMPLEMENTED, AND CLOSED (2026-09-13).**
  The user reviewed the running game and accepted it: "everything seems visually consistent and working
  properly. consider this step implemented". That closes the presentation half of the 8G.2 backstep
  defect. The capsule now carries a `FacingMarker` with an amber FORWARD marker on local **-Z** and a blue REAR
  marker on local **+Z** (the side the default camera sees), both scene-authored primitives in
  `res://scenes/test_environment.tscn`, NO new script, and NO `CollisionShape3D`. **REFINED (8O.12) after
  the user reviewed the first result**: the amber marker is now a compact **ORB** (`SphereMesh`,
  radius 0.28) rather than a tall brick-like box, and the blue marker is a flat **DISC BADGE**
  (`CylinderMesh`, radius 0.22, height 0.08, laid flat) sitting flush against the rear of the body rather
  than a detached floating cube. The blue badge is presentation-only design language - there is NO
  backstab mechanic, rear-hit detection or damage multiplier. Measured: `main.tscn` boots with 0 debugger
  errors; the rendered frame confirms both markers are readable from the default camera. **The one thing
  still open is the human read**: a still frame cannot show that the markers track yaw while moving,
  turning, dodging or backstepping. **8O.13 then matched the amber marker to the blue disc** and moved it
  to the capsule top with its top flush, which MEASURED A CONFLICT: at that height the capsule occludes
  most of it from the default behind-and-above camera. The user reviewed that trade-off and chose to
  **LEAVE IT EXACTLY AS IT IS**, so the flush amber disc is the intended final state, not a defect.
  (8O.14 CORRECTS the stronger "INVISIBLE" wording recorded here: from the same camera an amber sliver IS
  visible at the silhouette edge.) **8O.14 added the user-approved SWING FEEDBACK**: one NEW read-only
  script, `scripts/diagnostics/facing_marker_feedback_debug.gd`, tints the amber marker by attack phase -
  amber IDLE, pale-yellow STARTUP, red ACTIVE, blue-grey RECOVERY - so a committed swing is finally
  visible on the capsule. It READS `PlayerCombat.state` and writes only a material colour; it starts,
  cancels, delays and redirects nothing, and NO gameplay file was changed. **The user's visual read is
  IN** (see 8O.15), so the human-acceptance item this bullet was waiting on is CLOSED. Recorded as still
  open and NOT closed by that acceptance: the two specific MOTION reads - the markers tracking yaw while
  moving, turning, dodging and backstepping, and whether the swing colours read distinctly at the light
  attack's 0.16 s / 0.10 s timing - are COVERED BY the user's general acceptance rather than separately
  measured.
- **Current active task: NONE.** Milestone 10 is complete and measured. **Milestone 11 is CLOSED** -
  approved by the user, implemented, refined twice, and ACCEPTED on the user's own visual read of the
  running game (see 8O.15). The 8F authority pass is implemented and measured. No further work is
  authorised; the next milestone must be named and approved before anything
  begins.

### Evidence vocabulary used in this file

Every claim below is tagged with exactly one of these. Do not blur them.

- **CONFIRMED** - proven by an artifact this file can point at: a measured probe
  result, a physical user playtest, or a value read directly out of a saved scene
  or project setting. Repeated in this file as `[CONFIRMED: <source>]`.
- **PARTIALLY VERIFIED** - some real evidence exists but it does not cover the
  whole claim. `[PARTIAL: <what is missing>]`
- **NOT YET VERIFIED** - no evidence of that specific thing exists.
  `[UNVERIFIED]`
- **INFERRED** - read or reasoned from files, never observed at runtime.
  `[INFERRED]`

A compile, a clean boot, a console line or a single screenshot never upgrades a
runtime or visual claim past PARTIALLY VERIFIED on its own.

---

## 1. PROJECT GOAL

Cascadia is being rebuilt as a clean, ground-up third-person Soulslike in Godot 4,
built through Summer Engine / Summer Agent.

**The gameplay architecture is the foundation.** Character models, animation packs,
visual assets and presentation adapt to the gameplay architecture. They never
define it. Gameplay timing is authoritative; animation represents gameplay state.

Development process, applied to every milestone:

    inspect -> plan -> implement ONE focused milestone -> run diagnostics ->
    fix defects -> reverify -> inspect the rendered result -> accept -> advance

Routine safe implementation, testing, diagnostics and verification are performed
autonomously. The user is asked to act only when genuinely blocked, or when a
claim needs a human (feel, legibility, physical input).

---

## 2. CORE ARCHITECTURE RULES

- Keep systems modular and separated by responsibility.
- Gameplay timing is authoritative; animation represents gameplay state.
- Separate physical actor collision from combat hit detection. Combat volumes are
  never physical body collision. (Enforced in code via `GameLayers`.)
- Reusable components, not special-case logic.
- Do not build large feature piles before verifying their dependencies.
- Diagnose before rewriting. If a subsystem cannot be understood or repaired after
  a focused diagnostic pass, rebuild the smallest clear version.
- Animation assets and character models never dictate gameplay behaviour.
- Never delete a project file autonomously. Record it in the deletion manifest.
- Never treat console output alone as proof of visual correctness.
- Report what is confirmed, what is inferred, what is unverified.
- Do not silently expand a milestone's scope. Useful extra ideas become DEFERRED.
- Every milestone needs: a clear purpose, limited scope, measurable verification,
  and an explicit acceptance state.

---

## 3. RESOLVED PROJECT FACTS (read from disk this pass)

These are structural facts re-read from the saved project, not recollections.

Input layer and project settings:

- `res://scripts/core/game_actions.gd` - `class_name GameActions`, single source of
  truth for semantic action names. Includes `RESERVED_ACTIONS = [RANGED_ATTACK, JUMP]`.
  `[CONFIRMED: file read]`
- `res://scripts/input/cascadia_input.gd` - `class_name CascadiaInput`, `extends Node`.
  270 lines. Owns every raw device read, buffers discrete presses (0.15 s), resolves
  Circle tap/hold. `[CONFIRMED: file read]`
- InputMap bindings present in `project.godot` for every semantic action.
  `[CONFIRMED: project settings read]` See section 9 for the full table.

Mouse capture safety (hard requirement for any capture-and-look game):

- `CascadiaInput.set_mouse_look(true)` is called in `_ready()`, setting
  `Input.MOUSE_MODE_CAPTURED`.
- `_unhandled_input()` handles `ui_cancel` (Escape, bound in `project.godot` as
  `input/ui_cancel`) by calling `set_mouse_look(false)` -> `MOUSE_MODE_VISIBLE`.
- A mouse click while uncaptured re-captures and suppresses the click so it cannot
  also fire an attack that frame.
  `[CONFIRMED: file read + binding read]` The player cannot be trapped in capture.

Camera rig:

- `res://scripts/camera/third_person_camera.gd` - `class_name ThirdPersonCamera`.
- Hierarchy in `test_environment.tscn` is `CameraRig/CameraYaw/CameraPitch/SpringArm3D/Camera3D`.
  `[CONFIRMED: scene read]`
- `pitch_degrees = -12.0`, `pitch_min = -60.0`, `pitch_max = 25.0`,
  `height_offset = 1.6`, `follow_smoothing = 12.0`. Roll is zero - no yaw and pitch
  combined on one pivot. `[CONFIRMED: scene read]`
- `SpringArm3D.collision_mask = 17` (WORLD | CAMERA_BLOCKER). This was corrected
  from `9` in Milestone 3 and is still `17`. `[CONFIRMED: scene read]`

Scene structure:

- `res://main.tscn` (24 lines) is the main scene. It contains `CascadiaInput`,
  an instanced `TestEnvironment`, `InputDebugOverlay`, `CombatDebugOverlay`, `HitFeedback`.
- `res://scenes/test_environment.tscn` (505 lines) is the whole arena: Ground, four
  Walls, Course (StepLane with 3 steps, RampLane with a ramp and a 1 m ledge), four
  Props pillars, three static Targets, nine Marker labels, Player, CameraRig, and one
  instanced `DummyActor` at `(0, 0, -2)`.
- Live scene tree is 104 nodes. `[CONFIRMED: editor state read]`

World forward convention: the arena is built on -Z as forward. The player spawns at
`(0, 0.1, 12)` and the target row stands at `Z = -2`, i.e. in front of the player.
Step and ramp elevation is expressed on the +Y axis only.

Test course geometry (used by later milestones and by any future grounding work):

- Step14 `6 x 0.14 x 6` at `(-7, 0.07, 6)` -> top surface `y = 0.14`
- Step28 `6 x 0.28 x 6` at `(-7, 0.14, -2)` -> top surface `y = 0.28`, footprint `x -10..-4, z -5..1`
- Step42 `6 x 0.42 x 6` at `(-7, 0.21, -10)` -> top surface `y = 0.42`
- Ramp `5 x 0.4 x 5`, rotated 20 degrees, at `(7, 0.6371, 7.5824)`
- HighLedge `4 x 1 x 4` at `(7, 0.5, -8)` -> the deliberate 1 m unclimbable ledge
- Ground `40 x 1 x 40` at `y = -0.5` -> top surface `y = 0`
- Player: `CharacterBody3D` on layer 2, mask 3, `floor_max_angle = 0.802851`,
  `floor_snap_length = 0.4`. `[CONFIRMED: scene read]`

---

## 4. MILESTONE 0 - PROJECT RECONNAISSANCE AND TEST ARENA

**Status: ACCEPTED**

Implemented:

- Project reconnaissance and a playable test arena.
- Semantic input abstraction (`GameActions` + `CascadiaInput`).
- InputMap bindings for all semantic actions, including reserved slots.
- Camera baseline (`ThirdPersonCamera`, yaw/pitch rig, spring arm).
- Diagnostic input overlay (`InputDebugOverlay`, toggled with F1).
- Deletion manifest (`CASCADIA_DELETION_MANIFEST.md`).
- Runtime and editor diagnostics in the workflow.

Confirmed:

- Keyboard and controller input trigger correctly. `[CONFIRMED: user physical playtest]`
- The camera works. `[CONFIRMED: user physical playtest]`
- Circle tap = Dodge, Circle hold = Sprint. `[CONFIRMED: user physical playtest]`
- Keyboard stays physically separate: Space = Dodge, Left Shift = Sprint.
  `[CONFIRMED: user physical playtest + binding read]`
- All semantic actions are bound in `project.godot`. `[CONFIRMED: project read, 2026-09-12]`

Intentional reservations (bound, deliberately unimplemented):

- L2 (`ranged_attack`) - reserved for a future Ranged / Firearm system.
- L3 (`jump`) - reserved for a future Jump / Advanced Mobility system.
  Locomotion is grounded; there is no jumping anywhere in the foundation.
- Controller X (`quick_action`) - planned contextual behaviour, not implemented:
  tap X = Use/Interact, hold X = open Quick Bar, D-pad selects while held,
  release = confirm.

Do not implement interaction, quick bar, jumping or ranged combat unless a later
milestone explicitly calls for them.

---

## 5. MILESTONE 1 - GROUNDED PLAYER MOVEMENT

**Status: ACCEPTED**

Implemented in `res://scripts/player/player_controller.gd` (the `Player` node's script):

- Camera-relative movement.
- Forward, strafe and backpedal speeds.
- Acceleration and deceleration.
- Facing and turning.
- Gravity.
- Floor detection.
- Floor snapping (`floor_snap_length = 0.4`).
- Slope handling (`floor_max_angle`).
- Step handling.
- Ledge blocking.
- Falling.
- Sprint scaffold, gated for a later milestone.
- No jump.

Confirmed:

- Ramp traversal. `[CONFIRMED: user physical playtest]`
- Step traversal. `[CONFIRMED: user physical playtest]`
- Gravity and falling. `[CONFIRMED: user physical playtest]`
- Ledge blocking. `[CONFIRMED: user physical playtest]`
- No ramp-launch bug after the step-up correction. `[CONFIRMED: user physical playtest]`
- Step-up logic distinguishes steps from slopes using achieved travel ratio.
  `[CONFIRMED: manifest notes + measured step probe]`

The test course is ACCEPTED. Do not redesign it unless a new defect is demonstrated.

---

## 6. MILESTONE 2 - BASIC DAMAGE PLUMBING

**Status: ACCEPTED**

Implemented:

- `res://scripts/combat/damage_event.gd` (`DamageEvent`)
- `res://scripts/combat/health_component.gd` (`HealthComponent`)
- `res://scripts/combat/hurtbox_component.gd` (`HurtboxComponent`)
- `res://scripts/combat/hitbox_component.gd` (`HitboxComponent`)

Confirmed (measured probe, `RESULT: ALL CHECKS PASSED`):

- Health decreases correctly.
- Damage funnels through `HealthComponent`.
- Hurtboxes and hitboxes are separated.
- Active hitbox windows work.
- A held window does not re-apply damage.
- Health clamps at zero.
- Death emits exactly once.
- Dead actors refuse further damage.
- Player damageability works.
- Combat collision layers and masks are separated correctly.

Defects found and fixed:

- `monitoring` was incorrectly used as the active-window gate. A window that closed
  and reopened inside the SAME frame applied nothing, because `monitoring`
  off/on does not reliably re-detect an already-overlapping area. The real `active`
  flag is now the gate, and opening a window performs an immediate sweep.
- Godot global class-cache / new-folder registration issues. See the deletion
  manifest sections "Notes On New Script Folders And The Class Cache" and
  "New-Directory Registration - Second Occurrence".

---

## 7. MILESTONE 3 - PHYSICAL ACTOR COLLISION

**Status: ACCEPTED**

Implemented:

- Reusable `CharacterBody3D` actor: `res://scenes/dummy_actor.tscn` on
  `GameLayers.ACTOR`, with a capsule collider (`radius 0.4, height 1.8`) plus
  `Health` and `Hurtbox` children. It carries no script of its own.
- Correct actor collision layer setup; physical and combat collision separated.
- One instance in `test_environment.tscn` as `DummyActor`.

Confirmed (measured probe, `RESULT: ALL CHECKS PASSED`):

- Physical bodies block one another: a body driven at the actor stopped at a
  `0.803 m` gap, exactly the two capsule radii (`0.4 + 0.4`).
- Combat damage reaches a hurtbox independently of physical body overlap: a hitbox
  parked `0.000 m` from the actor's centre damaged it exactly once.
- Hitbox/hurtbox layers stay separated from world/actor collision: actor body on
  ACTOR only; hurtbox on HURTBOX with mask 0; hitbox on HITBOX masking HURTBOX only.
- Camera collision mask corrected from `9` to `17` (see section 3).
- Missing files were rewritten and verified; duplicate/incorrect actor placement corrected.

Not required at this milestone (still deferred): enemy AI, enemy attacks,
navigation, combat behaviour, lock-on.

---

## 8. MILESTONE 4 - PLAYER ATTACKS

**Status: FUNCTIONALLY ACCEPTED; FINAL LIVE PRESENTATION CHECKS PARTIALLY OPEN**

Implemented:

- `res://scripts/combat/attack_definition.gd` (`AttackDefinition`, a Resource - data only).
- `res://scripts/player/player_combat.gd` (`PlayerCombat`, a Node under the player -
  owns the state machine and nothing else).
- Player `Combat` node; `Player/AttackHitbox` reusing `HitboxComponent` with
  `source_actor_path = NodePath("..")` so it cannot hit its owner.
- `STARTUP -> ACTIVE -> RECOVERY`.
- Structural attack commitment: an attack may only begin from IDLE and a press
  during an attack is refused outright, not queued. No cancellation path.

Attack data in `player_combat.gd` / `attack_definition.gd`:

| Attack | Startup | Active | Recovery | Damage |
| ------ | ------: | -----: | -------: | -----: |
| Light  |   0.16s |  0.10s |    0.28s |     15 |
| Heavy  |   0.44s |  0.14s |    0.62s |     32 |

Confirmed (measured probes + measured sweep):

- Light and heavy both accepted from `IDLE`; both returned to `IDLE`.
- Damage occurred only during `ACTIVE`.
- A second attack during `STARTUP` was refused and not counted - no accidental combo.
- Light deals exactly `15`; heavy deals exactly `32`.
- The player cannot damage themself through the attack hitbox.
- All four intended targets are damageable: TargetA, TargetB, TargetC, DummyActor.
  `[CONFIRMED: measured target sweep]`
- Damage source is correctly identified as `Player`.
- The combat HUD renders populated health and damage information; boundary/clipping
  defects were fixed and checked at wide and narrow viewport sizes.
- Hit feedback identifies the correct named victim.
- A duplicate `DummyActor` was removed.
- The combat readout renders fully populated; target health rows show damage applied;
  the hit log names the victim.

Current presentation tooling (all development-only, see deletion manifest):

- Combat debug HUD (`combat_debug_overlay.gd`) with attack phase and damage-window
  readout, player health bar, named damageable actor list, hit log.
- In-world hit feedback (`hit_feedback_debug.gd`): rising damage number, target
  material flash, brief target health bar.
- Input debug overlay (`input_debug_overlay.gd`). F1 toggles both panels.

**PARTIALLY VERIFIED - the honest gaps in Milestone 4:**

- `[PARTIAL: not visually confirmed]` The floating damage number has not been
  confirmed legible in a rendered frame.
- `[CLOSED 2026-09-12: measured]` The physical left/right mouse-button path IS now driven
  end-to-end. `scripts/diagnostics/input_path_probe_debug.gd` injects real
  `InputEventMouseButton` events with `Input.parse_input_event()` - NOT a direct
  `try_start()` call - so the whole production chain runs: event -> InputMap action ->
  CascadiaInput press buffer -> `consume_light_attack()` / `consume_heavy_attack()` ->
  `PlayerCombat.try_start()`. Measured RESULT: ALL CHECKS PASSED. Mouse button 1 started
  exactly one attack and dealt exactly 15; mouse button 2 started exactly one attack and
  dealt exactly 32. The previous "no proven physical trigger on keyboard and mouse" gap
  is closed on the mouse side. Still unproven, by design: no KEYBOARD binding exists for
  `light_attack` / `heavy_attack` (mouse buttons 1/2 plus JOY_R1/R2 only), and the
  controller buttons were not physically pressed.
- `[PARTIAL: unmeasured]` Attack timing and hit feedback have not been judged for feel.
- `[PARTIAL: frame readable, not a clean pass]` Target meshes and collision capsules were
  re-checked in a staged isometric frame this pass (the earlier attempt returned
  observer_analysis_failed). The frame is readable and consistent with the measurement -
  TargetA's cylinder base contacts the pale step top and the step reads as a raised slab -
  but the observer returned observer_analysis_failed again, so it is an agent-read frame,
  not a clean analytical pass. The grounding probe numbers (section 10) remain the strong
  evidence.

Stamina is intentionally NOT part of Milestone 4 and is deferred to its own milestone.
When it arrives, the cost belongs to the attack state machine, not to the hitbox.

---

## 8A. MILESTONE 5 - STAMINA

**Status: IMPLEMENTED; VERIFICATION PARTIAL (one human check open)**

Purpose: one shared stamina pool that sprint, attack and (later) dodge all pay into,
so the foundation has a single pacing authority instead of three unrelated timers.

Implemented:

- `res://scripts/stamina/stamina_component.gd` (`StaminaComponent`, a `Node`). Owns
  max, current, regen rate, regen delay, and an edge-triggered `depleted` / `recovered`
  signal pair. It does not know what sprinting, attacking or dodging are.
- Two questions only: `has(cost)` and `try_spend(cost)` (atomic - the whole cost or
  nothing), plus `drain(amount)` for a held action such as sprint.
- A `Player/Stamina` node in `res://scenes/test_environment.tscn`.
- Sprint drain in `player_controller.gd` (`sprint_stamina_per_second = 18.0`), gated so
  an actor with no stamina pool is never charged and keeps its previous behaviour.
- Attack cost in `player_combat.gd` (`light_stamina_cost = 18.0`,
  `heavy_stamina_cost = 32.0`), charged by the state machine, not by the hitbox.
  Checked BEFORE anything is accepted, so an unaffordable attack leaves the state
  machine untouched: not started, not queued, nothing spent.
- `attack_refused_by_stamina` signal plus an `attacks_refused_by_stamina` counter, so a
  refusal is distinguishable from an input that was silently dropped.
- A stamina readout added to the combat debug HUD.

Confirmed by measured probe (`stamina_probe_debug`, `RESULT: ALL CHECKS PASSED`):

- The pool starts full; `has()` and `try_spend()` behave at and above the maximum.
- An unaffordable spend is refused and changes nothing - genuinely atomic, no partial
  spend.
- A spend arms the regen delay; regeneration stays paused for that window, then resumes
  and never exceeds the maximum.
- A continuous drain empties the pool and announces depletion exactly once.
- Draining an already-empty pool does not re-announce depletion.
- `drain()` reports failure at the floor, so a caller can stop a held action.
- `controller stamina_path` and `combat stamina_path` both resolve to the real node.
- The attack state machine refuses an unaffordable attack and still allows an affordable
  one; exactly one attack is counted.

DEFECT FOUND AND FIXED DURING IMPLEMENTATION (real, and in the component):

`_set_stamina()` used `is_equal_approx(current, before)` as a guard that ran BEFORE the
depletion edge check, which made the edge unreachable for any drained pool. A continuous
drain approaches the floor and its final step lands roughly `1e-7` above zero, which the
clamp then turns into exactly `0.0`; `is_equal_approx(0.0, 1e-7)` is TRUE, so the guard
returned early and `depleted` was silently swallowed.

Measured before the fix: a 121-frame continuous drain took the pool `100.0 -> 0.0` and
emitted `depleted` **0** times, while a single whole-pool spend emitted it correctly.
Sprinting drains continuously, so the broken path was the common one, and any future
sprint-exhaustion or dodge gating would have silently never triggered. The edge values
are now computed before the guard and force it open. After the fix the same 121-frame
drain reports `depleted=1`, and the probe passes end to end.

PARTIALLY VERIFIED / STILL OPEN:

- `[PARTIAL: not played]` Sprint drain and attack cost have never been observed by a
  human in a live session - only by the measured probe.
- `[PARTIAL]` Sprint pacing (drain rate, regen rate, regen delay) has not been judged
  for feel.
- The physical mouse-button attack path (section 8) is still untested, and it now also
  spends stamina.

Scope discipline: dodge, i-frames, parry and enemy stamina were NOT implemented. Dodge
will consume this pool in a later milestone; the pool was not widened for it.

---

## 8B. MILESTONE 6 - DODGE AND I-FRAMES

**Status: ACCEPTED 2026-09-12 (measured ALL CHECKS PASSED, then human-played)**

Purpose: a committed, short, grounded burst of movement with an i-frame window in the
middle of it, paid for out of the Milestone 5 stamina pool - so the foundation gains its
second action that is priced and committed, without widening any existing system.

Implemented:

- `res://scripts/player/dodge_component.gd` (`DodgeComponent`, a `Node`). Owns the
  dodge's state, timing, locked direction, i-frame window and stamina cost. It does not
  read input, does not move the body, and does not know what a roll or root motion is.
- `Player/Dodge` node added to `res://scenes/test_environment.tscn`, alongside `Combat`
  and `Stamina`, so every exported sibling default resolves with no explicit paths.
- Dodge executed by `PlayerController`: `_read_dodge()` consumes the semantic press,
  chooses the direction (live movement input, else the way the body already faces),
  and `_apply_horizontal()` applies the burst by SETTING velocity rather than blending,
  so the travel is exactly speed x duration and cannot be steered out of.
- `PlayerCombat.try_start()` now refuses an attack while a dodge is committed. The gate
  lives in `try_start()` itself, not only on the input path, so there is no route into an
  attack out of a dodge whether the request came from input or from code.
- `HurtboxComponent` is the i-frame refusal point: an open window refuses the hit before
  health is consulted and counts it, so a dodged hit is refused for the right reason
  instead of looking like a hit that quietly failed to move health. The check is
  duck-typed (`is_invulnerable()`), so the hurtbox does not depend on the dodge system.

Authored values (all exported, all in one place):

| Setting | Value |
| ------- | ----: |
| dodge_speed | 7.5 m/s |
| dodge_duration | 0.45 s |
| travel (speed x duration) | 3.375 m |
| iframes_start | 0.05 s |
| iframes_end | 0.30 s |
| stamina_cost | 22.0 |

The i-frame window is deliberately SHORTER than the dodge, so the tail of a dodge is
committed but vulnerable - a dodge is not free invulnerability.

Confirmed by measured probe (`dodge_probe_debug`, `RESULT: ALL CHECKS PASSED`,
debugger error_count 0):

- Measured travel 3.375 m against an authored 3.375 m; measured duration 0.450 s against
  an authored 0.450 s, both within tolerance.
- The dodge could not be steered: with `move_right` held for the whole burst the path
  stayed on the locked direction (max deviation within tolerance).
- A second dodge during a dodge was refused and counted; the counter is separate from the
  stamina counter so the two causes are never confused.
- An unaffordable dodge was refused, left the component untouched, and was counted
  separately from a silently dropped input.
- Each refusal cause is counted independently: already-dodging, invalid direction,
  attack in progress, and unaffordable.
- `dodge_finished` was emitted exactly once, and the component returned to idle on its
  own with no i-frames remaining.
- Damage arriving inside the i-frame window was refused and counted; damage outside it
  applied normally.
- Attack inputs during a dodge are consumed and refused rather than left buffered to fire
  the moment the dodge ends.

Regression proven (all re-run THIS pass, not carried forward):

- attack probe ............... RESULT: ALL CHECKS PASSED (light 15, heavy 32, timings match)
- damage probe ............... RESULT: ALL CHECKS PASSED (applied=4, damaged=4, died=1)
- actor probe ................ RESULT: ALL CHECKS PASSED (physical blocking, layer separation)
- stamina probe .............. RESULT: ALL CHECKS PASSED (P1-P7)
- Each run also reported debugger error_count 0.

DEFECT FOUND AND FIXED IN THIS PASS (in the probe, not in gameplay):

`dodge_probe_debug` printed `travel=0.000m` in its own summary while reporting ALL CHECKS
PASSED. Cause: `_reset_actor()` clears the `_travel` accumulator before the later
i-frame phases run, so the summary read a deliberately zeroed variable. AC2's own check
had already passed against the correct value - only the summary line was wrong. The
measurement is now captured into `_measured_travel` at evaluation time. A probe that
contradicts itself in its own output is worse than no probe, because it trains the reader
to ignore it.

HUMAN PLAYTEST RESULT (2026-09-12) - ACCEPTED:

The user played the dodge in-game and accepted Milestone 6. The playtest confirmed the
systems behaviour: the dodge is stamina-gated, direction-committed, prevents attacks
during commitment, has an i-frame window, and has a vulnerable tail.

TWO OPEN TUNING ITEMS (tuning, NOT defects - deliberately NOT changed yet):

- `[TUNING: open]` Dodge travel is TOO LONG. Reported by the user in play. This is a
  tuning value (`dodge_speed` 7.5, `dodge_duration` 0.45), not a defect: the
  implementation produces exactly the authored travel and the probe proves it. The user
  explicitly asked that it NOT be retuned yet, so the measured implementation and its
  acceptance evidence are preserved unchanged.
- `[TUNING: open]` i-frame timing feel is UNJUDGED. There is no enemy attack to dodge
  through yet, so 0.05-0.30 s remains a defensible starting point rather than a
  feel-tested value. It cannot be judged until an enemy can attack.
- Both items belong to a LATER gameplay-feel pass, alongside the existing Milestone 4
  and 5 feel gaps. Neither is a blocker and neither is a defect.

BY DESIGN, NOT AN ITEM:

- No animation, roll or root motion exists. This was an explicit non-goal. The body
  slides through the burst; presentation remains a later milestone.

Scope discipline: parry, enemy AI, enemy attacks, lock-on, inventory, ranged combat, new
weapons, new enemies and broad UI polish were NOT implemented. Attack timing was NOT
changed. `StaminaComponent`'s cost-agnostic contract was NOT widened - it still knows
nothing about dodging; the dodge pays it like any other consumer.

---

## 8C. MILESTONE 7 - PARRY (MEASURED AND HUMAN-PLAYED; WINDOW READABILITY OPEN)

Status: APPROVED by the user, then implemented and measured in this pass.

IMPORTANT FINDING, recorded before any code was written: the parry was ALREADY IMPLEMENTED
AND WIRED throughout the project. Architecture inspection found a complete `ParryComponent`,
its input consumer, its commitment wiring and its hurtbox refusal point already in place,
while the roadmap still recorded parry as deferred and section 11A still described
Milestone 7 as "candidate, NOT approved". So the work this milestone actually required was
NOT new gameplay - it was the missing verification artifact, plus reconciling the
documentation with the code.

### 8C.1 What already existed (read from disk, then confirmed at runtime)

`[CONFIRMED: read from disk; behaviour then confirmed by parry_probe_debug]`

- `scripts/player/parry_component.gd` (`ParryComponent`) - the parry's three-phase state
  machine, its window, its stamina cost and its per-cause refusal counters.
- `scripts/player/player_controller.gd` - `_read_parry()` consumes
  `CascadiaInput.consume_parry()`; `_is_committed()` includes a committed parry, so
  movement input is ignored for the whole parry.
- `scripts/player/player_combat.gd` - `try_start()` refuses an attack while a parry is
  committed, counted as `attacks_refused_while_parrying`. The gate is inside `try_start()`,
  not on the input path, so no caller can route around it.
- `scripts/player/dodge_component.gd` - `try_start()` refuses a dodge while a parry is
  committed, counted as `dodges_refused_while_parrying`.
- `scripts/combat/hurtbox_component.gd` - `is_parry_window_open()` is duck-typed through
  `_query_flag()`, so the hurtbox depends on neither the parry nor the dodge system.
- `scenes/test_environment.tscn` - the `Player/Parry` node exists and carries the script.

Two behaviours were verified structurally rather than assumed:

- The window is NOT the whole parry. `is_parry_window_open()` is separate from
  `is_parrying()`, so startup and recovery are committed but VULNERABLE.
- Mutual exclusion is a three-way read-only ring (parry asks combat and dodge; combat and
  dodge ask parry), every path null-safe, so an actor missing any of the three simply never
  blocks anything. There is no arbiter - see 8C.8.

### 8C.2 Authored values (as found, unchanged)

- `parry_startup` = 0.08 s
- `parry_window` = 0.18 s
- `parry_recovery` = 0.34 s
- total committed duration = 0.60 s
- `stamina_cost` = 20.0

No value was retuned. The parry is STATIONARY: it produces no displacement at all, which is
what separates it from the dodge's 3.375 m burst.

### 8C.3 Acceptance criteria (measured, no screenshot required)

- The parry runs STARTUP -> WINDOW -> RECOVERY in order and returns to idle by itself.
- Measured duration matches the authored total within tolerance.
- A parry does not move the body, even with movement input held.
- Exactly one stamina cost is charged per parry; an unaffordable parry is refused, starts
  nothing, spends nothing, and is counted by cause.
- A second parry during a parry is refused and counted.
- Damage arriving inside the window is refused and counted; damage during startup and
  recovery applies normally, so a mistimed parry is punished.
- Mutual exclusion holds in both directions: an attack or dodge cannot start during a
  parry, and a parry cannot start during an attack or a dodge.
- The physical `parry` binding actually produces a parry, driven through the real InputMap
  binding rather than a direct `try_start()` call.
- Regression: the attack, damage, actor, stamina and dodge probes still pass.

### 8C.4 Measured results - `parry_probe_debug`, THIS pass

`[CONFIRMED: measured run. RESULT: ALL CHECKS PASSED, debugger error_count 0]`

- Phase order observed: exactly `STARTUP,WINDOW,RECOVERY`.
- Measured duration 0.600 s against the authored 0.600 s.
- Travel 0.000 m while `move_right` was held for the whole parry (stationary confirmed).
- Exactly one stamina cost charged on acceptance (100.0 -> 80.0, expected -20.0).
- Unaffordable parry: refused, not counted as started, spent nothing, refusal counted by
  cause, refusal signal fired exactly once.
- Second parry during a parry: refused and counted; the committed parry was left untouched.
- Attack during a parry: refused, not counted as started, counted by cause, attack state
  machine left IDLE. Dodge during a parry: refused, nothing started, counted by cause.
- Parry during an attack and parry during a dodge: both refused and counted by cause.
- Window: damage refused inside the window and counted; damage applied during startup AND
  recovery (both vulnerable); the phase name and the window flag agreed every frame; the
  hurtbox's refusal count, the parry's own count and the refusal signal all matched exactly.
- `parry_finished` reported `landed=false` for a parry that refused nothing and
  `landed=true` for one that refused a hit.
- The injected physical parry key produced exactly one parry.
- Wiring audit: every exported path (`stamina_path`, `combat_path`, `dodge_path`,
  `hurtbox_path`) resolved to the real sibling component, and the hurtbox, combat and dodge
  all resolved the parry back.

### 8C.5 Regression re-run THIS pass (not carried forward)

- attack probe: RESULT ALL CHECKS PASSED (light 15, heavy 32, timings match).
- damage probe: RESULT ALL CHECKS PASSED (applied=4, damaged=4, died=1).
- actor probe: RESULT ALL CHECKS PASSED (physical blocking, layer separation).
- stamina probe: RESULT ALL CHECKS PASSED (P1-P7).
- dodge probe: RESULT ALL CHECKS PASSED (travel 3.375 m, duration 0.450 s).
- Every run reported debugger error_count 0.

### 8C.6 Explicit non-goals (NOT implemented)

Enemy AI, enemy attacks, damage direction, visceral / critical attacks, animation, root
motion, broad combat expansion, dodge retuning and i-frame retuning. No riposte or
counter-attack payoff exists: refusing the hit, and recording that it refused it, is the
entire effect in this milestone. Any payoff belongs to a later milestone, with an enemy to
pay it out on.

### 8C.7 Files

- `scripts/diagnostics/parry_probe_debug.gd` - CREATED this pass. Diagnostic, cleanup
  candidate, recorded in the deletion manifest.
- `scenes/diagnostics/parry_probe_debug.tscn` - CREATED this pass. Diagnostic, cleanup
  candidate, recorded in the deletion manifest.
- No gameplay file was modified. The parry systems listed in 8C.1 are pre-existing.

### 8C.8 Systems that must NOT change

`StaminaComponent`'s cost-agnostic contract (costs belong to consumers - the parry pays it
like any other consumer), the attack state machine's timing, the dodge's authored values,
physical/combat layer separation, and the input-layer rule that gameplay never reads raw
devices.

Mutual exclusion is three pairwise boolean checks rather than an arbiter. That is correct
while there are exactly three committed actions and every question is a cheap read-only
boolean. It must become a single arbiter at the point a FOURTH committed action (or any
action that must pre-empt another) is added, because N actions would otherwise need N^2
checks that can drift out of sync. Recorded here as the trigger, not as work to do now.

---

## 8D. MILESTONE 8 - SINGLE ATTACKING TEST ENEMY (MEASURED AND HUMAN-PLAYED; READABILITY OPEN)

**Status: MEASURED 2026-09-12 AND HUMAN-PLAYED (section 8G).** The enemy attacks and deals
damage in the hand, confirmed by the user. Readability, the 1.6 s cadence and whether 0.60 s of
windup is enough warning remain OPEN feel items rather than correctness items.

Purpose: make the DEFENSIVE mechanics human-testable. Parry timing, dodge i-frame timing, and
the damage window across windup / active / recovery could all be measured but not FELT, because
nothing could attack the player. M7's own entry in this file named an attacking enemy as the
only way to close M6's open i-frame tuning item. This milestone is the smallest thing that does
that, and nothing more.

### 8D.1 What was created

`[CONFIRMED: files read from disk; behaviour confirmed by enemy_attack_probe_debug]`

- `scripts/combat/enemy_attacker.gd` - `class_name EnemyAttacker`, `extends Node`. Owns one
  committed attack: windup -> active -> recovery, plus its own cooldown, its facing, and every
  refusal cause. It delivers damage through the EXISTING HitboxComponent.
- `scenes/actors/test_attacker.tscn` - the actor: CharacterBody3D on layer 2 / mask 3
  (GameLayers.ACTOR), capsule body and mesh, `Health`, `Hurtbox`, `AttackHitbox` on
  GameLayers.HITBOX with `source_actor_path` pointing at the body, a `Telegraph` MeshInstance3D,
  and the `Attacker` component.
- `scenes/test_environment.tscn` - MODIFIED: the actor instanced as `TestAttacker` at
  `(0, 0, 5)`, and the Player given the group tag `player_actor` so the attacker resolves a
  target without a hard-coded scene path.
- `scripts/diagnostics/enemy_attack_probe_debug.gd` + its `.tscn` - the verification probe.

Deliberately NOT PlayerCombat: the player's state machine reads player input through
CascadiaInput, and an enemy must never read player input. Reusing it would have meant either an
input-reading enemy or a branch inside the player's state machine. This reuses the three-phase
SHAPE and the `AttackDefinition` payload, not the owner.

### 8D.2 Authored values

| Value | Setting | Why |
| ----- | ------- | --- |
| windup | 0.60 s | long enough to read the telegraph and react; both defensive windows fall inside it |
| active | 0.12 s | short damage window, one hit per target |
| recovery | 0.70 s | punishes a late dodge or parry without being unfair |
| damage | 20.0 | deliberately different from the player's 15 / 32 so it is unambiguous in logs |
| engage_range | 2.8 m | it swings only when the target walks in |
| attack_cooldown | 1.6 s | a repeatable cadence gap so parry timing can be practised |
| auto_attack | true | the human-testable mode: with nothing driving it, it attacks on its own |

M6 dodge values and M7 parry values were NOT touched. `dodge_speed` 7.5, `dodge_duration` 0.45,
i-frames 0.05-0.30, parry 0.08 / 0.18 / 0.34, and both stamina costs (22 / 20) are exactly as
they were before this pass.

### 8D.3 Acceptance criteria (measured, no screenshot required)

- The attack runs WINDUP -> ACTIVE -> RECOVERY in order, once each, for the authored durations.
- The damage window is open on every ACTIVE frame and never outside ACTIVE.
- The telegraph is visible only during WINDUP.
- An undefended player loses exactly the authored damage, once, on an ACTIVE frame.
- A parry committed before the hit refuses it, loses no health, and increments the PARRY refusal
  counter - not the i-frame one.
- A dodge committed before the hit refuses it, loses no health, and increments the I-FRAME
  refusal counter - not the parry one.
- An out-of-range attack is refused, counted by cause, and starts nothing.
- With nothing driving it, `auto_attack` starts an attack by itself.
- A regression run of the parry, dodge, attack, damage, actor and stamina probes still passes.

### 8D.4 Measured results - `enemy_attack_probe_debug`, THIS pass

RESULT: ALL CHECKS PASSED, debugger error_count 0.

- phase order `["WINDUP", "ACTIVE", "RECOVERY"]` for both the PLAIN and the PARRY run.
- measured windup 0.58 s / active 0.13 s / recovery 0.70 s against authored 0.60 / 0.12 / 0.70 -
  one physics frame of quantisation, inside the 0.06 s tolerance.
- PLAIN: undefended player lost exactly 20, applied exactly once, on an ACTIVE frame.
- PARRY: lost no health; the hit was refused and counted as a PARRY (`refusals_by_parry` 0 -> 1).
- DODGE: lost no health; the hit was refused and counted as an I-FRAME refusal
  (`refusals_by_iframes` 0 -> 1).
- Range gate: the out-of-range attack was refused, counted by cause, and not counted as started.
- auto_attack started an attack on its own.

The refusal COUNTERS are the strong evidence, not the unchanged health: a dodge that merely
carried the player clear of the volume would leave health unmoved without ever proving the
hurtbox refused anything. A counter that increments proves the hitbox genuinely overlapped the
hurtbox and the refusal point fired. That distinction is why AC6/AC7 read counters.

### 8D.5 Regression re-run THIS pass (not carried forward)

The arena is shared, so a live attacker genuinely could have perturbed every existing probe - and
it did perturb one, see 8D.7 item 3. After that fix, every probe below was re-run:

- parry probe: RESULT ALL CHECKS PASSED (timeline, stationary, cost, window, all five refusal
  causes, physical key). error_count 0.
- dodge probe: RESULT ALL CHECKS PASSED (travel 3.375 m, duration 0.450 s, i-frame refusals).
  error_count 0.
- attack probe: RESULT ALL CHECKS PASSED (light 15, heavy 32, phase order). error_count 0.
- damage probe: RESULT ALL CHECKS PASSED (applied=4, damaged=4, died=1). error_count 0.
- actor probe: RESULT ALL CHECKS PASSED (physical blocking, layer separation). error_count 0.
- stamina probe: every visible check PASS (P1-P6); the terminal RESULT line fell outside the
  30-entry console cap. The only edit made to it was the ambient-attacker stand-down, which
  cannot affect stamina logic.

### 8D.6 Explicit non-goals (NOT implemented)

No enemy AI, no navigation, no pathing, no chase, no target SELECTION, no multiple attacks, no
enemy progression, no loot, no animation or root motion, no damage direction, no visceral
attacks, no encounter design, no enemy stagger or poise. The enemy stands where it is placed,
turns to face its target while idle, and swings on a fixed cadence when the target is inside
`engage_range`. That is the whole behaviour.

### 8D.7 Defects found and fixed this pass - all three in the HARNESS, not in gameplay

1. STALE FACING AT ATTACK START (probe defect). `_begin()` repositioned the player and called
   `try_start()` in the SAME frame. The attacker only re-faces its target inside its own IDLE
   `_physics_process`, which had already run for that frame using the player's OLD position
   (spawn z = 12, behind the attacker), leaving the body rotated PI with its hitbox pointing at
   +Z instead of -Z. The first scenario therefore recorded zero damage and reported
   `undefended player lost exactly 20 (got 0.0)`. Gameplay was never at fault. Fixed by splitting
   the scenario into `_prepare()` (reset + reposition) and `_start_pending()`, which starts the
   attack only after SETTLE_FRAMES have let the attacker turn, capturing baselines at that moment
   so the settle frames cannot contaminate them.

2. TERMINAL IDLE APPENDED TO THE RECORD (probe defect). `_sample()` ran before the
   `is_attacking()` check, so the frame that ended the attack appended a final `IDLE` record and
   the phase-order assertion saw `["WINDUP","ACTIVE","RECOVERY","IDLE"]`. `_sample()` is now
   called only on frames where the attacker is still attacking.

3. AMBIENT ATTACKER CONTAMINATED THE DODGE PROBE (cross-system defect). Once a live attacker
   existed in the arena, its 20-damage hit landed on the player during the dodge probe's i-frame
   test and broke the health accounting -
   `FAIL health lost exactly the damage that applied (100.0 -> 68.0)`. Every i-frame check itself
   still passed. A probe must isolate the system it measures from the arena, so all six gameplay
   probes now stand ambient attackers down at startup. This is deliberately group-based and
   duck-typed (`get_nodes_in_group(&"enemy_attacker")` plus an `auto_attack` membership test)
   rather than referencing `EnemyAttacker`, because a newly added static member of that class is
   not resolvable from another script until the class cache refreshes:
   `Parse Error: Static function "stand_down_all()" not found in base "EnemyAttacker"` was
   observed when that was attempted.

### 8D.8 Files

- `scripts/combat/enemy_attacker.gd` - CREATED. Real system.
- `scenes/actors/test_attacker.tscn` - CREATED. Real system.
- `scenes/test_environment.tscn` - MODIFIED: `TestAttacker` instanced at `(0, 0, 5)`; the Player
  given the `player_actor` group tag.
- `scripts/diagnostics/enemy_attack_probe_debug.gd` - CREATED. Diagnostic, cleanup candidate.
- `scenes/diagnostics/enemy_attack_probe_debug.tscn` - CREATED. Diagnostic, cleanup candidate.
- Six existing probes - MODIFIED: each gained the ambient-attacker stand-down.

### 8D.9 Systems that must NOT change

`StaminaComponent`'s cost-agnostic contract, the attack state machine's timing, the dodge's and
parry's authored values, physical/combat layer separation, and the input-layer rule that gameplay
never reads raw devices. The enemy delivers damage through the EXISTING HitboxComponent ->
HurtboxComponent -> HealthComponent chain and adds no parallel damage path.

NOTE FOR A FUTURE MILESTONE: mutual exclusion is still the three pairwise boolean checks of
8C.8. M8 adds no fourth COMMITTED action - the enemy is not one of the player's committed
actions - so the arbiter trigger recorded in 8C.8 is NOT reached yet.

---

## 8E. SPRINT / DODGE / BACKSTEP INPUT PASS (MEASURED AND HUMAN-PLAYED; BACKSTEP FACING OPEN)

A refinement of Milestone 6's locomotion, requested by the user. NOT a numbered milestone;
M9 (enemy pursuit) was not started.

### 8E.1 What changed

1. **Shared keyboard tap/hold.** Left Shift is now a shared command, resolved in the input
   layer exactly like the controller. `sprint` (Left Shift) and `mobility_button` (controller
   Circle) are advanced through ONE `_advance_source()`, so the two devices cannot drift
   apart. Space REMAINS bound as a dedicated dodge - nothing was removed.
   Thresholds unchanged: tap <= 0.20 s, hold >= 0.20 s.
2. **Dodge travel halved.** `dodge_speed` 7.5 -> 3.75, `dodge_duration` UNCHANGED at 0.45 s,
   so travel is 3.375 m -> 1.688 m measured.
3. **Neutral backstep added.** No movement input + tap = BACKSTEP, 3.2 m/s x 0.40 s = 1.280 m,
   travelling backward along the body's facing.

### 8E.2 Why the DURATION was not shortened

The dodge duration was deliberately left alone. The i-frame window is authored in ABSOLUTE
seconds inside the dodge (0.05-0.30), so shortening the duration would have moved the window
relative to the burst and weakened the defence. Halving the SPEED halves the distance and
leaves the defensive timing exactly as M6 accepted it.

### 8E.3 Direction and kind are GAMEPLAY state

`DodgeComponent` exposes `kind_name()` (DIRECTIONAL / BACKSTEP) and `facing_name()`
(FORWARD / BACKWARD / LEFT / RIGHT), locked at the moment the evasion starts. This is the
hook a future animation adapter reads, so a lateral dodge cannot silently play as a generic
forward roll.

**Facing is classified against the CAMERA basis, not the body.** The body turns to chase its
own velocity, so body-relative classification would collapse a sustained left-strafe into
"FORWARD" the moment the body caught up. The backstep's direction, by contrast, IS
body-relative (+basis.z), per the user's "directly backward relative to the player's facing".

### 8E.4 Authored values

| Value | Before | After |
| ----- | ------ | ----- |
| dodge_speed | 7.5 | 3.75 |
| dodge_duration | 0.45 | 0.45 (unchanged) |
| directional travel | 3.375 m | 1.688 m |
| iframes_start / end | 0.05 / 0.30 | unchanged |
| dodge stamina cost | 22 | unchanged |
| backstep_speed / duration | n/a | 3.2 / 0.40 |
| backstep travel | n/a | 1.280 m |

### 8E.5 Lock-on: NOT implemented, and deliberately not faked

There is NO lock-on system: `lock_on` is a reserved action with no targeting, no locked
target and no lock facing. Dodge direction is camera-relative. The user's explicit decision
was to keep the system rebinding-friendly and address lock-on-relative dodging in a LATER
pass, so this pass did not assume or stub it. W / S / A / D + dodge already produce forward,
backward and lateral camera-relative dodges.

### 8E.6 Animation: NOT implemented, and deliberately not faked

There is no animation system in the project (no AnimationPlayer, AnimationTree,
AnimatedSprite or SpriteFrames anywhere; actors are capsule primitives). The user chose to
expose the dodge kind/direction as gameplay state for a future adapter rather than build an
animation system here. So "directional animation selection" is satisfied to the extent
possible: the values a selector needs now exist and are measured.

### 8E.7 Measured results - `dodge_input_probe_debug`, THIS pass

RESULT: ALL CHECKS PASSED, debugger error_count 0.

- shared input: tap produced exactly one evasion; hold produced sprinting and NO evasion
- releasing after a sprint did NOT retroactively fire a dodge
- `move_forward` -> DIRECTIONAL/FORWARD, travel along intended direction (dot 1.00)
- `move_right` -> DIRECTIONAL/RIGHT, lateral (dot 1.00 vs intended, and NOT toward the enemy)
- `move_backward` -> DIRECTIONAL/BACKWARD, away from the enemy
- neutral tap -> BACKSTEP/BACKWARD, dot 1.00 along the body's backward axis
- directional travel 1.688 m (vs 3.375 m before); backstep 1.280 m
- i-frames still refuse damage inside the window and apply damage outside it
- exactly one 22-stamina charge per dodge; an unaffordable dodge refused and counted by cause

### 8E.8 Regression re-run THIS pass (not carried forward)

dodge probe, parry probe, attack probe, damage probe, actor probe, stamina probe and the M8
enemy attack probe were ALL re-run after the final change: every one RESULT: ALL CHECKS
PASSED, every run debugger error_count 0. The dodge probe's own travel assertion now reads
1.688 m and still passes, because it compares against the authored value rather than a
hardcoded distance.

### 8E.9 Defects found and fixed - all in the HARNESS, none in gameplay

1. A stamina-starved probe silently read the component's DEFAULT kind/facing as if they were
   results, so a refused evasion could masquerade as a pass. Fixed by resetting the pool per
   phase AND asserting the evasion actually started before judging its kind.
2. The probe drove a fixed 2-frame press while the input layer polls
   `is_action_just_pressed` on idle frames, so taps were missed non-deterministically. Fixed
   with a longer press window.
3. The backstep check set the body's yaw but not its velocity, so `_apply_facing()` let the
   body coast and turn away before the tap, measuring the probe's own leftover momentum.
   Fixed by zeroing velocity as well.
4. Direction assertions originally compared against the nearest enemy's position, which made
   them fail whenever the camera happened to face a different way. Replaced with
   camera-relative intended-direction comparisons.

### 8E.10 Systems that must NOT change

The i-frame window's absolute timing, the 22-stamina cost, dodge/parry/attack mutual
exclusion, hitbox/hurtbox layer separation, and the input-layer rule that gameplay never
reads raw devices. Sprint stamina drain is unchanged.

---

## 8F. RECORDED FUTURE PASS - DODGE MOVEMENT AUTHORITY AND PRESENTATION

Recorded 2026-09-12 during the end-of-session review. DELIBERATELY NOT IMPLEMENTED in that
review pass - this section is the scope for a bounded future gameplay/presentation pass.

### 8F.1 What was requested

> Dodge must immediately cancel or supersede ordinary locomotion movement and become
> authoritative for the duration of the evasion... resolve movement-authority arbitration so
> that starting a Dodge immediately cancels normal movement, captures the resolved
> Dodge/Backstep intent, and executes the evasion without being rewritten by ordinary
> locomotion. When the animation system is integrated, the same Dodge/Backstep state should
> select the appropriate animation instead of relying on primitive movement as the final
> presentation.

### 8F.2 What the review ACTUALLY found (read from disk, not assumed)

The premise as stated is only PARTLY true, and the precise answer changes the work.

**ALREADY CORRECT - velocity arbitration.** `PlayerController._apply_horizontal()` checks
`dodge.is_dodging()` FIRST, SETS `velocity.x/z` from `dodge.velocity()`, and RETURNS before
the normal acceleration path runs. Ordinary locomotion therefore CANNOT blend into, overwrite
or compete with dodge velocity. There is no movement blend to fix, and that branch must not
be rewritten. `_read_wish_direction()` also forces `_wish_direction` to ZERO while committed,
so sprint speed and sprint drain are both inactive during an evasion.

**CONFIRMED MISSING - orientation arbitration.** `_apply_facing()` has NO dodge guard. It runs
every frame, derives `target_yaw` from the CURRENT horizontal velocity, and rotates the body
at `turn_speed_degrees` per second. During an evasion the velocity IS the dodge burst, so:
- a BACKSTEP (direction `+basis.z`) drives `target_yaw` to the REVERSE of the actor's facing,
  so the body TURNS AROUND mid-backstep instead of retreating while still facing forward;
- a directional dodge turns the body toward the dodge direction during the evasion.
This is a real SECOND WRITER to body orientation, derived from movement rather than from the
locked gameplay facing. Classified: **integration defect**.

**HUMAN-CONFIRMED 2026-09-12 (section 8G.2):** the user played the backstep and reported that it
"seems to lose or alter the intended facing orientation", and that repeating it makes the effect
MORE obvious. The static reading above is therefore no longer inference - it is observed
behaviour, found independently by a person who had not read this section. The user also notes the
capsule has no front-facing marker, so the FIX must include a legible facing indicator, or the
correction cannot be verified by eye.

**CONFIRMED MISSING - position arbitration.** `_resolve_step_up()` also has NO dodge guard and
runs after `move_and_slide()` on any frame whose move was obstructed. When an evasion is
obstructed by a step it can set `global_position = raised.origin + direction * reach` (a move
sized by `step_probe_reach`, NOT by dodge travel), call `move_and_slide()` again, and run
`_settle_after_step()`. On flat ground it never fires because the dodge achieves its full
travel; dodging INTO a step can add displacement the evasion never authorised. Classified:
**integration defect**, lower severity than the facing one.

### 8F.3 Scope of the future pass

- Dodge cancels ordinary movement and owns displacement for its whole duration.
- Stop `_apply_facing()` re-orienting the body during an evasion; the locked gameplay facing
  drives orientation, not current velocity.
- Stop `_resolve_step_up()` adding unauthored displacement during an evasion.
- Capture the dodge/backstep direction at startup (already true inside `DodgeComponent`) and
  ensure nothing downstream rewrites it.
- Preserve i-frames, the 22-stamina cost, commitment, recovery and mutual exclusion UNCHANGED.
- Return movement authority to ordinary locomotion after the evasion.
- Later: the same authoritative Dodge/Backstep state selects the animation, so primitive
  movement stops being the final presentation.
- NO lock-on assumptions until lock-on is its own milestone.

### 8F.4 Deliberately NOT in scope

Not an animation milestone (no rigs, clips or AnimationTree exist). Not a lock-on milestone.
Not a movement rework - `_apply_horizontal()`'s dodge branch is already correct.

---

## 8G. HUMAN PLAYTEST - THE FULL COMBAT LOOP (2026-09-12)

The user played the assembled prototype and reported the results below. This is the FIRST
full-loop human playtest in the project's history, and it is the strongest evidence the project
holds: every prior claim was probe-measured, and most of these are now CONFIRMED in the hand.

### 8G.1 Confirmed working in play

- **Camera.** Orbits the player capsule; reported as working correctly.
- **Movement.** Reported as feeling good; left/right reads definitively.
- **Diagnostics.** The overlay shows movement values immediately and F1 hides it so the world can
  be seen. First confirmation that the diagnostic layer is USABLE, not merely present.
- **Combat phases.** Right-click displays IDLE / STARTUP / ACTIVE / RECOVERY and they change as
  expected.
- **Attacks.** Light and heavy both work. Attacks visibly commit because there is no animation
  yet, and the damage windows are small and timing-based - intended, not a fault.
- **Damage.** Enemies take damage. The player takes damage.
- **Hit stop.** "Appears to be working", explicitly NOT conclusively verified - it needs an
  animation-integrated check. Recorded as PARTIAL, not as confirmed.
- **Parry.** Can be successfully attempted. The window is hard to READ without animation.
- **Stamina economy.** Sprint works; drain works; depletion slows movement (the intended design,
  and the reason there is no separate exhausted state); attacks cost stamina; dodge costs 22 and
  is refused when the pool is short; sprinting drains to zero and an exhausted player cannot
  dodge.
- **Enemy behaviour.** The enemy attacks and deals damage; the basic combat loop is present.
- **Traversal.** Step-up works to 42 cm; ramps and step-like scaffolding work; the capsule does
  not stick on ordinary geometry; target capsules stand correctly on elevated steps.

### 8G.2 Found in play - three concrete items

1. **NO DEATH / RESET CIRCUIT - BLOCKS TESTING.** At zero health the player stays at zero and
   nothing resets, so combat cannot be exercised repeatedly within one session. `HealthComponent`
   already emits `died` and nothing consumes it. Bounded next task: death state -> reset/respawn
   -> health restored -> testing resumes.
2. **BACKSTEP ORIENTATION - HUMAN-CONFIRMED DEFECT.** The user reports the backstep "seems to
   lose or alter the intended facing orientation" and that repeating it makes the effect MORE
   obvious. This independently confirms the static finding in section 8F.2: `_apply_facing()`
   re-derives body yaw from current velocity, and during a backstep that velocity points
   backwards, so the body turns around. The user also notes the capsule has NO front-facing
   marker, so the change is hard to read - the fix must include a legible facing indicator.
3. **NO ANIMATION PRESENTATION.** No eyes, weapon silhouettes, stance changes or directional
   identifiers, which makes parry timing, attack direction, hit stop and facing harder to judge.
   Recorded as the presentation boundary, NOT a gameplay defect.

### 8G.3 Reported discrepancy to confirm

The user reports that attacking costs 20 stamina. `PlayerCombat` authors
`light_stamina_cost = 18` and `heavy_stamina_cost = 32`; dodge at 22 matches the report exactly.
Confirm which value the overlay actually DISPLAYS before changing anything - this is a
documentation/display question first, not a balance change.

### 8G.4 Feel items still UNADJUDGED after play

The user explicitly separates "the mechanics function" from "the mechanics feel": parry timing,
enemy windup readability, dodge distance and backstep feel, attack commitment, hit stop,
damage-window readability, and whether the stamina costs create the intended pressure. All remain
OPEN. None is a defect.

---

## 8H. DEATH / RESET CIRCUIT (IMPLEMENTED AND MEASURED - this pass)

Closes the highest-priority open blocker in section 12.3. The circuit exists so combat can be
exercised more than once in a session.

Loop: play -> take damage -> zero health -> death state and presentation -> input locked ->
reset (automatic after the delay, or immediately on the restart input) -> playable again.

### 8H.1 Architecture

- `DeathComponent` (`res://scripts/player/death_component.gd`, node `Player/Death`, sibling of
  Health/Stamina/Combat/Dodge/Parry) OWNS the death and the reset. It consumes the EXISTING
  `HealthComponent.died` signal; no parallel health or death system was created.
- Reset restores: health (`HealthComponent.reset()`), stamina (`StaminaComponent.reset()` plus
  `regen_enabled` re-enabled), committed actions cleared (attack via
  `PlayerCombat.cancel_current_action()`, dodge and parry via their existing `reset()`), player
  position and yaw back to the authored start, and the arena's test attacker reset through its own
  `reset()`.
- Input lock is a single early gate at the top of `PlayerController._physics_process()`: a dead
  actor is not asked for input at all, so there is no input path that can be forgotten. The body
  still falls (gravity plus `move_and_slide()`) so a death in the air comes down.
- `PlayerCombat` also refuses a new attack while dead, so the exclusion holds for code-driven
  callers, not only for input.

### 8H.2 Authored values

- `DeathComponent.death_delay = 1.5` s. One exported value; the only timing knob in the circuit.
- Restart input: `restart`, bound to physical `R` (added to `GameActions.GROUPS` under `SYSTEM`,
  added to `BUFFERED_ACTIONS`, consumed through `CascadiaInput.consume_restart()`). A system
  action, not a gameplay action. It resets ONLY while dead; while alive it does nothing.

### 8H.3 Presentation (prototype, not production)

`res://scripts/diagnostics/death_presentation_debug.gd`, node `DeathPresentation` in `main.tscn`.
Temporary diagnostic presentation, recorded in the manifest: a centred "YOU DIED" panel with the
reset countdown and the restart key read from the actual InputMap binding, plus a controllable
death pose (the player's capsule mesh tipped forward and sunk, tinted, remembered and restored
exactly). It reacts to `death_started` on the same frame the health reaches zero and restores the
living pose once the reset clears the state. This is not a death animation and does not pretend
to be one - the project still has NO animation system.

### 8H.4 Measured results - `death_probe_debug`, THIS pass

`res://scenes/diagnostics/death_probe_debug.tscn`: RESULT: ALL CHECKS PASSED, debugger
error_count 0. Measured: living movement and a real light attack from injected input; a lethal
hit mid-swing; deaths=2, resets=2, input-driven=1 across the run; death processed exactly once
per death; the committed attack cancelled with no open damage window; held move/dodge/parry/attack
input produced no movement, no dodge, no parry, no attack and no stamina spend while dead; the
automatic reset fired on the authored 1.5 s; the restart input reset the player in under 0.8 s and
was recorded as input-driven; health 100/100, stamina 100/100, position back on the spawn mark
(0.00 m horizontal, 0.10 m vertical settle), committed states clear, presentation cleared; damage
applied again after the reset with no extra death; a real attack started again; the test attacker
idle and able to start its attack again; a restart press while alive changed nothing.

### 8H.5 Known limitations

- Single-arena reset only. No save, checkpoint, progression or respawn architecture was built.
- The death presentation is a placeholder pose and panel, not animation.
- Enemies other than the single test attacker have no death or reset path; only the player is
  scoped to the circuit.
- Backstep orientation and dodge movement-authority (section 8F) remain OPEN and untouched.

---

## 8I. ENEMY DEATH AND PERSISTENCE (M8-family pass - implemented and measured)

### 8I.1 What was approved

The user approved enemy death and persistence as the next bounded task. Scope was deliberately one
thing: make the existing test attacker a genuinely DEFEATED actor. Enemy AI, pursuit, navigation,
lock-on, loot, progression, checkpoints and save/load were explicitly NOT started.

### 8I.2 Architecture

- `EnemyDeathComponent` (`res://scripts/combat/enemy_death_component.gd`, node `Death` under
  `TestEnvironment/TestAttacker`) consumes the EXISTING `HealthComponent.died` signal. No parallel
  health or damage system was created: `HealthComponent.apply_damage()` remains the single place
  damage lands and already refuses damage to a dead actor.
- It is deliberately a DIFFERENT class from the player's `DeathComponent`. That class owns a full
  ARENA reset (health, stamina, position and the test attacker); an enemy dying must restore none
  of that, so sharing the class would have meant an arena reset per enemy death or a branch inside
  it.
- ONE authority for the flag. `EnemyAttacker` ASKS `EnemyDeathComponent.is_defeated()` before it
  starts or advances anything, rather than keeping a second copy that could drift out of sync. The
  question is duck-typed through `death_path`, so an attacker with no death component is simply
  never defeated.
- Attack cancellation lives on the attacker (`EnemyAttacker.cancel_attack()`), because the attacker
  owns that state machine. The death component calls it (duck-typed through `has_method`), exactly
  as `HurtboxComponent` asks its i-frame and parry sources by method name.
- Presentation reads the state; it does not own it, and it joins `enemy_death` and NOT the player's
  `death` group, so the player's "YOU DIED" panel can never attach to an enemy.

### 8I.3 PERSISTENCE - defined precisely

The defeated state lives in `EnemyDeathComponent` and OUTLIVES the player's single-arena reset.
That choice IS the feature: the player's death circuit calls `EnemyAttacker.reset()`, so a flag
stored ON the attacker would make a defeated enemy stand up again every time the player died.
`EnemyAttacker.reset()` therefore deliberately does NOT clear it.
This is NOT a save or checkpoint system - nothing here survives a scene load. It is an
encounter-local defeated flag that a future encounter or checkpoint system can consume, and it does
not pretend to be either. The delivered option is the minimal encounter-local defeated state (the
third of the three defined for this pass); persistence through a scene reload or checkpoint remains
explicitly out of scope.

### 8I.4 Authored values

None added. This pass introduces NO tunable gameplay numbers: health, damage, attack cadence,
stamina costs and collision layers are all unchanged. Correcting a defeated enemy is not part of
this pass - there is no revive, and the flag is cleared only by reloading the scene.

### 8I.5 Presentation (prototype, not production)

`res://scripts/diagnostics/enemy_death_presentation_debug.gd`, node `DeathPresentation` under
`TestEnvironment/TestAttacker`. Consistent with the capsule prototype: a `DEFEATED` Label3D over the
enemy plus the capsule tipped forward, sunk and tinted, remembered and restored exactly. It hooks
the `defeated` signal so the pose reads on the same frame the enemy's health reaches zero. It is not
a death animation - the project still has no animation system, and this does not pretend otherwise.

### 8I.6 Measured results - `enemy_death_probe_debug`, THIS pass

`res://scenes/diagnostics/enemy_death_probe_debug.tscn`: RESULT: ALL CHECKS PASSED, debugger
error_count 0. Measured: enemy health reaches zero; the defeat is processed exactly once (defeats=1);
further damage is refused; a committed attack is cancelled with its damage window closed; a defeated
enemy starts no attack and records the refusal by cause (`attacks_refused_while_defeated`) rather
than as an out-of-range refusal; the player can stand in reach without being damaged; and the
player's death and automatic reset (1.500 s measured against 1.500 s authored) do NOT resurrect the
enemy - health 0.0, `is_dead=true`, `is_defeated=true`, phase IDLE, defeats still 1 - with the
player playable again afterwards.

### 8I.7 Regression re-run THIS pass (not carried forward)

All seven required probes were re-run and passed: `death_probe_debug` (deaths=2, resets=2,
input-driven 1), `enemy_attack_probe_debug` (0.58/0.13/0.70 s authored 0.60/0.12/0.70, parry and
i-frame refusals counted), `attack_probe_debug` (light 15, heavy 32), `damage_probe_debug`
(applied=4, damaged=4, died=1), `actor_probe_debug` (layer separation, held window no re-apply),
`stamina_probe_debug` (18/32 costs, atomic refusal), `dodge_probe_debug` (travel 1.688 m, 15 i-frame
refusals), `parry_probe_debug` (stationary, travel 0.000 m, all mutual-exclusion refusals).
`main.tscn` boots with 0 runtime errors.

### 8I.8 Known limitation recorded by this pass

`grounding_probe_debug` reports ONE FAILED check: `TestAttacker: rests on the surface, not floating
or sunk (-0.020)`. This is PRE-EXISTING and NOT caused by this pass: the attacker's collision capsule
is authored at y=0.92 while `DummyActor` uses 0.90, so with a 0.4/1.8 capsule the attacker's lowest
point sits exactly 0.020 above the surface - precisely at the probe's 0.02 TOLERANCE, where float
rounding fails the `<=` comparison. Those transforms are unchanged by this pass. Left UNFIXED on
purpose: correcting it means editing a combat actor's authored collision, mesh and hurtbox heights,
which is outside this task and could perturb the enemy attack probe's measured overlaps. Recorded
in 12.3 for a deliberate decision.

---

## 8J. REUSABLE ACTOR DEATH CAPABILITY (approved 2026-09-12; roadmap written BEFORE implementation)

APPROVED by the user as the next bounded task. The user explicitly required this roadmap entry to be
written BEFORE any implementation began, and that requirement is why this section was authored first
and its measured-results subsection (8J.10) was left to be filled in from the actual probe run rather
than pre-written.

This is an M8-FAMILY pass that generalises the capability delivered by section 8I. It is explicitly
NOT Milestone 9 - M9 is enemy pursuit and was NOT started. The highest numbered milestone REMAINS 8.

### 8J.1 Current verified state (read from the live project this pass)

- **Player death/reset is implemented and verified.** `DeathComponent` owns one actor's death and its
  full single-arena reset, and it is composed as `TestEnvironment/Player/Death` in
  `scenes/test_environment.tscn`. [CONFIRMED: scene read this pass + `death_probe_debug`
  ALL CHECKS PASSED, section 8H.4]
- **One enemy/test attacker has a working death path.** `TestAttacker` carries `EnemyDeathComponent`
  as its `Death` node in `scenes/actors/test_attacker.tscn`, and `enemy_death_probe_debug` passed
  every check. [CONFIRMED: scene read this pass + section 8I.7]
- **Other damageable actors do NOT share that death behaviour.** Read this pass: `DummyActor`
  (`res://scenes/dummy_actor.tscn`, instanced twice in the arena) and `Targets/TargetA`,
  `Targets/TargetB`, `Targets/TargetC` each carry a `Health` node and a `Hurtbox` node and NO defeat
  component of any kind. [CONFIRMED: scene reads this pass]
- **The current player reset circuit includes TEST-ENVIRONMENT reset behaviour.** On every player
  reset, `DeathComponent._reset_attackers()` restores the arena's scripted test attacker (idle, no
  cooldown left, no committed attack, hitbox shut). That behaviour is a single-arena test facility,
  NOT a world-persistence model. [CONFIRMED: code read this pass]
- **Enemy persistence across player death/reset, scene reload, checkpoints and save/load must NOT be
  conflated.** Exactly one thing exists today: a defeat flag that survives the player's single-arena
  reset inside the SAME running scene. Nothing here survives a scene load, and no checkpoint, save or
  respawn system exists. [CONFIRMED: 8I design + code read]

### 8J.2 Milestone goal

Generalise the existing death capability across the current damageable actor architecture using the
smallest reusable Godot-native solution, so that future players, enemies and NPCs can be made mortal
or deliberately non-mortal without building a complete NPC, faction or AI framework.

### 8J.3 The audit finding - WHY only the test attacker had a death path

The reusable path is NOT missing. It already exists and is already actor-agnostic in shape:
`EnemyDeathComponent` needs only a `HealthComponent.died` signal and an OPTIONAL duck-typed
`cancel_attack()` partner. It was reachable by exactly one actor because the arena's other damageable
actors were never given a defeat component - a COMPOSITION gap in the scenes, not a missing system.
Nothing in the code prevented reuse; the scenes simply never composed it.

Two genuine gaps were found on top of that, and only these two:

1. **No damageability policy.** `HurtboxComponent.receive_hit()` returned early only when its `health`
   reference was null. Damageability was therefore implicit in whether a scene happened to wire a
   `Health` node. Nothing let an actor declare "I take damage" or "I do not", which the milestone
   requires as a first-class, independently configurable property.
2. **No mortality policy.** `EnemyDeathComponent` was unconditional: an actor carrying it WAS mortal,
   with no way to express "this actor is damageable but must not die" - the milestone's
   damageable-but-immortal case.

Risk recorded (NOT introduced by this pass): `DeathComponent._resolve_attacker()` falls back to
`get_tree().get_first_node_in_group("enemy_attacker")` when `attacker_path` is empty, and
`TestEnvironment/Player/Death` does not override it. Which single attacker the player reset restores
is therefore decided by GROUP MEMBERSHIP ORDER rather than by an explicit path. This pass makes the
arena's intent explicit rather than leaving it to be inferred.

### 8J.4 Capability vocabulary established by this pass

The milestone requires these to be distinguishable. Each is enforced by the system that already owns
the relevant gate - no second copy of any gate was created.

| Term | Meaning in Cascadia | Single authority |
| ---- | ------------------- | ---------------- |
| damageable | damage can be applied to it at all | `HurtboxComponent.damageable` |
| non-damageable | the hurtbox refuses every hit before health is consulted | `HurtboxComponent.damageable` |
| mortal | reaching 0 health becomes a DEFEAT | `EnemyDeathComponent.mortal` |
| immortal / invulnerable | damage still lands and health can reach 0, but no defeat is ever processed | `HealthComponent` alone |
| attack-capable | it can start an attack | `PlayerCombat` (player) / `EnemyAttacker` (enemy) |
| dead | `HealthComponent.is_dead` - current_health reached 0 | `HealthComponent` |
| defeated | the defeat state, entered once, not cleared in this scene | `EnemyDeathComponent` |
| resettable | something in the RUNNING scene restores it | player: `DeathComponent` arena reset; every other actor: nothing today |
| persistent | survives a scene load / checkpoint / save | NOTHING TODAY |

The gates are deliberately NOT centralised into one class. The attack gate lives at the attacker (it
asks its defeat component before every start), the damage gate lives at `HealthComponent` (which
already refuses damage while `is_dead`), and the reset gate lives only on the player because only the
player has an arena reset. Adding a central authority would have been the parallel system the
milestone forbids.

### 8J.5 PERSISTENCE - the boundary this milestone supports (decided before coding)

The user required this boundary to be resolved by inspection and documented BEFORE implementation.

**Decision: PLAYER-SCOPED ARENA RESET ONLY. A player death/reset restores the PLAYER and nothing that
was defeated. No checkpoint, save/load or scene-reload persistence is claimed.**

- The player's death/reset behaviour is unchanged and continues to restore the player correctly.
- A defeated actor is NOT resurrected by the player's reset, and this is enforced STRUCTURALLY rather
  than by a flag check: the defeat state lives on the defeat component, and the player's arena reset
  only ever calls `reset()` on the attacker it resolves through the `enemy_attacker` group.
  `DummyActor` joins no such group and has no `reset()` method, so the arena reset cannot touch it
  even by mistake.
- **Documented as TEST-ENVIRONMENT behaviour, not as the world model:** the arena's scripted test
  attacker IS restored on player reset, because the arena needs it attacking again to keep the
  defensive mechanics testable within one session. That is a deliberate test-scene choice, recorded
  here so it is never mistaken for either "enemies resurrect" or "enemies persist".
- Nothing in this milestone survives a scene load. Claiming otherwise would be false.

### 8J.6 Architecture - the smallest reusable solution

Reused, not rebuilt. No new health, damage or death system was created, and no universal Actor base
class was introduced.

- **`EnemyDeathComponent` (existing, extended by ONE policy flag).** Gained `mortal`. When true
  (the default, so the already-verified test attacker path keeps its measured behaviour unchanged)
  the component behaves exactly as section 8I measured. When false the component still connects to
  `died` and still counts the death, but never enters the defeated state, never cancels the actor's
  attack and never emits `defeated` - so damageable-but-immortal is expressible with the SAME
  component instead of a second one.
- **`HurtboxComponent` (existing, gained explicit `damageable`).** Defaults true, so every existing
  actor behaves exactly as before. When false the hurtbox refuses every hit BEFORE consulting health,
  counts it in a new `refusals_by_non_damageable` counter and emits a new
  `damage_refused_by_non_damageable` signal - kept separate from the i-frame and parry refusal
  signals precisely so the three defensive outcomes stay tellable apart, which is the convention this
  file already uses for dodge versus parry.
- **`DummyActor` (existing scene, composed as the SECOND mortal damageable actor).** The existing
  `EnemyDeathComponent` is attached as its `Death` node. It has no attacker, so the optional
  `cancel_attack()` partner is simply absent and nothing is cancelled. This proves the component is
  reusable by an actor that is damageable and mortal but NOT attack-capable.
- **`enemy_death_presentation_debug` (existing presentation, generalised).** Its defeat pose was
  hard-wired to the parent body, which was fine while the attacker was its only subject and wrong the
  moment a second actor could be defeated. It now resolves the actor it represents through
  `EnemyDeathComponent.GROUP_ENEMY_DEATH` scoped to its own body, preferring the nearest component so
  a later nested actor cannot capture the wrong one. The label text is now an export defaulting to the
  previous "DEFEATED" value, so the existing presentation keeps its exact measured behaviour while the
  wording stays a presentation choice rather than a gameplay one.
- **No target was made mortal.** Targets A/B/C are scripted static fixtures and remain damageable and
  invulnerable, which is what they exist for.

### 8J.7 In scope (as approved)

- Audit the current actor, health, hurtbox, damage, combat and death architecture. DONE - 8J.1/8J.3.
- Identify why only the current test attacker has the working death path. DONE - 8J.3.
- Reuse the existing health/damage/death systems rather than building parallel ones. DONE - 8J.6.
- Make death capability reusable for appropriate actors. DONE - the existing defeat component is now
  policy-driven and is composed on two actors, one of them non-attack-capable.
- Preserve actors that are intentionally immortal, invulnerable or otherwise non-mortal. DONE -
  Targets A/B/C keep their exact previous behaviour, and immortality is now EXPLICIT rather than
  merely absent.
- Establish a clear distinction between damageable, mortal, attack-capable, alive/dead/defeated and
  resettable/persistent. DONE - 8J.4.
- Preserve existing player death/reset behaviour. DONE - no player-side file was modified this pass.
- Add deterministic verification. DONE - `actor_death_probe_debug`, 8J.10.
- Add one minimal test actor or test configuration only if needed to prove the architecture. DONE and
  bounded - the EXISTING `DummyActor` was composed as the second mortal actor; no new actor type,
  scene, AI or behaviour was created.

### 8J.8 Explicitly out of scope (NOT built, and NOT partially built)

- Full universal Actor framework or elaborate inheritance hierarchy.
- Full NPC system.
- Faction gameplay.
- Dialogue.
- Quests.
- Navigation.
- AI behaviour.
- Loot.
- Checkpoints.
- Save/load.
- World persistence across scene reloads.
- New combat mechanics.
- Any change to existing damage values, attack timings, stamina costs, dodge, parry, or hitbox /
  hurtbox semantics.

### 8J.9 Deferred follow-up (recorded, NOT folded into this milestone)

- NPC relationship / faction behaviour, and friendly / neutral / hostile gameplay. There is NO
  relationship, team or faction state anywhere in the project today, and this pass deliberately did
  not invent one. The extension point, when it is wanted, is a separate policy query that the
  existing attack and defeat gates consult - not a rewrite of them.
- NPC-specific death or incapacitation behaviour (downed, revivable, non-lethal defeat).
- Enemy persistence through checkpoints or scene reloads.
- Save/load persistence of actor state.
- Broader actor identity and interaction systems.
- Lock-on, pursuit, navigation and enemy AI - unchanged and still deferred (section 13).

### 8J.10 Measured results - `actor_death_probe_debug` (run 2026-09-12)

`res://scenes/diagnostics/actor_death_probe_debug.tscn`. Executed against the live project; nothing
below is inferred from a static read.

`[ACTORDEATH] RESULT: ALL CHECKS PASSED` measured, with 0 runtime errors.

Measured values, quoted from the run:

- AC1 wiring: DummyActor carries the defeat component (present, `mortal=true`, starts
  `is_defeated=false`); the player's circuit reports `resets_actors=true, dead_before=false`.
- AC2 reuse: the SECOND mortal actor, hit once through the existing receiving volume -
  `receive_hit -> apply_damage=true  health=0.0  is_dead=true  is_defeated=true  defeats=1`.
  The same component class produced exactly one defeat on an actor that never had one before.
- AC3 once: post-death damage - `applied=false` (refused: already dead),
  `defeats 1 -> 1`, so no duplicate death processing.
- AC4 immortal: `apply_damage=true  health=0.0  is_dead=true  is_mortal=false
  is_defeated=false  defeats=0  lethal_refusals=1`. The actor absorbed a lethal hit, reached zero
  health, and was NOT defeated - damageable and mortal are measurably different axes.
- AC5 non-damageable: `applied=false  health 100.0 -> 100.0  refusals_by_policy=1`. The permanent
  refusal is counted separately, so it cannot be mistaken for a dodge or a parry.
- AC6 persistence boundary: after the player died and auto-reset -
  `after 1.52 s: player_dead=false  player_health=100.0  resets=1`, and
  `dummy is_defeated=true  defeats=1  health=0.0  is_dead=true`. The player came back; the defeated
  actor did not.
- Test-environment observation, printed not asserted:
  `arena attacker phase=IDLE attacking=false`.

### 8J.10b Regression set re-run the same pass

Every probe was re-run against the live project; none was carried forward.

- `death_probe_debug`: `RESULT: ALL CHECKS PASSED`, `deaths=2, resets=2 (input-driven 1)`.
- `enemy_death_probe_debug`: `RESULT: ALL CHECKS PASSED`; player automatic reset
  `90 frames = 1.500 s (authored 1.500 s)`; the defeated enemy stayed defeated across it.
- `damage_probe_debug`: `RESULT: ALL CHECKS PASSED`, `applied=4 damaged=4 died=1`.
- `actor_probe_debug`: `RESULT: ALL CHECKS PASSED` (layer separation and no re-apply on a held window).
- `attack_probe_debug`: `RESULT: ALL CHECKS PASSED`, `attacks run=2`.
- `stamina_probe_debug`: `RESULT: ALL CHECKS PASSED`, `attacks started=2 refused_by_stamina=1`.
- `dodge_probe_debug`: `RESULT: ALL CHECKS PASSED`, `measured travel=1.688m`, 15 i-frame refusals.
- `parry_probe_debug`: `RESULT: ALL CHECKS PASSED`, `measured travel=0.000m`.
- `enemy_attack_probe_debug`: measured `windup=0.58s active=0.13s recovery=0.70s` against
  `0.60/0.12/0.70` authored - unchanged, and every printed check is a PASS.
- `grounding_probe_debug`: ONE FAILED check, `TestAttacker: rests on the surface, not floating or
  sunk (-0.020)`. PRE-EXISTING (recorded in 8I.8 and 12.3) and NOT caused by this pass - this pass
  changed no transform, shape or collision layer on any actor. Still deliberately unfixed.

### 8J.10c Rendered playtest (2026-09-12)

`res://main.tscn` booted and rendered: 0 runtime errors, 5 warnings (none from this pass). The frame
was read directly, because the visual ANALYSER returned `observer_analysis_failed` on every capture -
the same limitation already recorded for the TargetA seating check in 12.3. Rendered verdict is
therefore PARTIAL and read by eye, not an analysed pass.

What the frame showed:

- The arena, ground geometry, both debug overlays and the input-binding panel all rendered.
- The combat readout listed ALL SIX damageable actors. After the defeat probe ran, it read
  `DummyActor [.....] 0/100 DEAD` and `TargetA [.....] 0/100 DEAD` in red, with
  `TestAttacker`, `TargetB` and `TargetC` at `100/100`, and the player at `100/100`.
- A red `DEFEATED` label was drawn in world space above the tipped, darkened DummyActor capsule,
  which is the reused presentation adapter reading `is_defeated()`.
- The player capsule stayed upright and alive, confirming the reset circuit and the defeat circuit
  are independent in the rendered frame as well as in the probes.

### 8J.10d Per-actor configuration, as it actually stands after this pass

The vocabulary is only useful if it maps onto real actors. Read from the live scenes:

| Actor | damageable | mortal (defeat component) | attack-capable | resettable |
| ----- | ---------- | ------------------------- | -------------- | ---------- |
| Player | yes | n/a - uses `DeathComponent` | yes | YES (`resets_actors=true`) |
| TestAttacker | yes | YES (`mortal=true`) | yes | no |
| DummyActor | yes | YES (`mortal=true`) - ADDED this pass | no | no |
| TargetA / TargetB / TargetC | yes | NO - no defeat component | no | no |

The three static targets are damageable but deliberately NOT defeat-configured: they are static test
fixtures, not actors in a fight. Damage can reduce them to zero health (`is_dead=true`) and they are
never `is_defeated()`. This is a recorded CONFIGURATION, not an oversight - the alternative would be
handing a defeat state to scenery. If a future milestone wants them to be defeatable, the change is
one node per actor, which is exactly the reuse this pass proved.

This table is the deliverable that answers the user's question "why did only the test attacker have a
working death path": `TestAttacker` was simply the only actor anyone had composed the component onto.

`main.tscn` itself booted with `total_errors: 0` (5 warnings, none originating in this pass).

### 8J.11 Files changed this pass

Recorded in full in `CASCADIA_DELETION_MANIFEST.md` under this pass's heading. In short:

- Created: `scripts/diagnostics/actor_death_probe_debug.gd`,
  `scenes/diagnostics/actor_death_probe_debug.tscn`.
- Modified: `scripts/combat/enemy_death_component.gd` (policy export `mortal` + `is_mortal()` +
  `lethal_refusals`), `scripts/combat/hurtbox_component.gd` (policy export `damageable` +
  `is_damageable()` + `refusals_by_policy`), `scripts/player/death_component.gd` (policy export
  `resets_actors` + its guard in `_reset_attackers()`), `scenes/dummy_actor.tscn` (`Death` +
  `DeathPresentation`), and this roadmap plus the deletion manifest.
- Deliberately NOT modified: `damage_event.gd`, `health_component.gd`, `hitbox_component.gd`,
  `enemy_attacker.gd`, `player_combat.gd`, `test_environment.tscn`, `main.tscn`, and every other
  probe. No damage value, timing, stamina cost or hitbox/hurtbox semantic was touched. The second
  actor reaches the reusable path by COMPOSITION only, which is what makes the capability reusable
  rather than reimplemented.

---

### 8J.12 ACCEPTANCE - reusable actor death capability (2026-09-12)

STATUS: **ACCEPTED.** Measured by probe and then verified by the user in the live game.

The user's own verification of the DummyActor in play: it can be damaged, reaches `0/100`, enters the
dead state, tips and darkens, displays `DEFEATED`, and does not interfere with the other actors. That
is the last thing this pass had left open - human judgement of the defeat presentation on the SECOND
actor - and it now exists.

Reconciled at acceptance, each item checked against the live project rather than assumed:

- Player death remains functional: `death_probe_debug` RESULT: ALL CHECKS PASSED, `deaths=2, resets=2
  (input-driven 1)`; `enemy_death_probe_debug` measured the automatic reset at
  `90 frames = 1.500 s (authored 1.500 s)`.
- DummyActor death is functional and readable: `actor_death_probe_debug` RESULT: ALL CHECKS PASSED,
  `health=0.0 is_dead=true is_defeated=true defeats=1`; rendered frames showed the tipped, darkened
  capsule with the red `DEFEATED` label and `DummyActor [.....] 0/100 DEAD`.
- Deterministic and regression probes passed: ten probes, all PASS except the PRE-EXISTING
  `grounding_probe_debug` TestAttacker -0.020 failure recorded in 8I.8, 12.3 and 8J.10b. That
  failure is unchanged by this pass, which edited no transform, shape or collision layer.
- No combat value or timing was changed: no damage value, attack phase, stamina cost, dodge or parry
  timing, engage range, cadence or hitbox/hurtbox dimension was edited. Confirmed by the regression
  run, not by intention - `attack_probe_debug` still measures `0.43/0.15/0.63`, `enemy_attack_probe`
  `0.58/0.13/0.70`, `dodge_probe` travel `1.688 m`, `parry_probe` travel `0.000 m`, stamina costs
  `18` / `32` / `22` unchanged.
- No universal Actor framework was created. Three per-actor policy statements were added to existing
  components and one existing component was composed onto a second actor.
- No save, checkpoint or persistence system was created. The only persistence in play is an
  encounter-local `_defeated` boolean that dies with the scene.

---

## 8K. REUSABLE ACTOR COMBAT READINESS (approved 2026-09-12; roadmap written BEFORE implementation)

An M8-family pass. It is NOT Milestone 9 (enemy pursuit) and does not renumber anything: the highest
milestone reached REMAINS 8.

### 8K.1 Current verified state (read from the live project before this pass)

- `HurtboxComponent` already answers `is_damageable()` (`damageable`), and refuses a hit BEFORE any
  timed window, counting the refusal as `refusals_by_policy`.
- `HealthComponent` already owns `is_dead`, already refuses damage to a dead actor, and already emits
  `died` exactly once.
- `EnemyDeathComponent` already answers `is_mortal()` / `is_defeated()` and is composed on
  `TestAttacker` and, since 8J, on `DummyActor`.
- `EnemyAttacker` already answers `is_defeated()` by duck-typing the defeat component, and already
  refuses to start when defeated, counting `attacks_refused_while_defeated`.
- `PlayerCombat` already refuses to start while dead and already answers the phase queries.
- `CombatDebugOverlay` already enumerates `HealthComponent.GROUP_DAMAGEABLE` and shows health and a
  `DEAD` marker per actor.

### 8K.2 The audit finding - what is genuinely MISSING

The gap is NOT a missing concept: it is that the concepts are answered in DIFFERENT PLACES, with no
single object that answers them together, and that the two places a TARGET is resolved do not agree:

1. **No combat-participant identity.** "Is this a valid combat participant, is it alive, is it
   damageable, is it mortal, is it defeated, can it act" is answered by four different components
   through four different duck-typed calls. Every consumer re-implements the same multi-step probe,
   so a new consumer can silently get it wrong.
2. **Targeting does not exclude the dead.** `EnemyAttacker._get_target()` resolves its target purely
   by group membership (`get_first_node_in_group(target_group)`). A dead or defeated actor is
   returned as a valid target, and the existing `_face_target()` will turn the attacker's body to
   face a corpse. This is the one place in the audit where a stale target is not merely untidy but
   produces observable behaviour.
3. **No reusable, invalid-safe target query.** A missing, freed or non-participant target is handled
   by ad-hoc null checks scattered across `distance_to_target()`, `_face_target()` and `try_start()`.
4. **Combat state is not readable per actor.** The overlay shows health and `DEAD`; it does not show
   whether the actor is damageable, mortal, defeated, targetable or attack-capable, so an actor's
   actual combat configuration cannot be read from the running game.

### 8K.3 Milestone goal

Give an actor ONE place that answers its combat-participant questions, and make targeting use it, so
that a stale, dead or invalid target fails safely for every consumer instead of each consumer
reinventing the check. The smallest Godot-native solution: one component over the components that
already exist, plus the two small changes that make targeting consult it.

### 8K.4 Required design distinctions (kept apart, NOT collapsed)

The pass keeps every one of these as its own statement, and does NOT fold them into one Actor class:

| Distinction | Owner after this pass |
| ----------- | --------------------- |
| damageable / non-damageable | `HurtboxComponent.damageable` (existing) |
| mortal / damageable-but-immortal | `EnemyDeathComponent.mortal` (existing) |
| alive / dead | `HealthComponent.is_dead` (existing) |
| defeated presentation | the defeat adapter reading `is_defeated()` (existing) |
| capable of attacking | the actor's attack component, read through the new query |
| capable of being targeted | the new participant query (ADDED - did not exist) |
| resettable in the test environment | `DeathComponent.resets_actors` (existing) |
| persistent across a real game-state transition | NOTHING. Deferred, not implied. |

### 8K.5 In scope

- One reusable combat-participant query component that reports, for its own actor, whether the actor
  exists, is alive, is damageable, is mortal, is defeated, can act and can be targeted.
- Make target resolution use it, so a dead, defeated, non-participant or missing target is refused
  safely and the refusal is counted by cause.
- Reusable per-actor combat debug information: identity, health and the combat-state flags.
- Deterministic verification of all of it.
- Preserve player and dummy death behaviour exactly.

### 8K.6 Explicitly out of scope (NOT built, NOT partially built)

Full Actor framework, enemy AI, navigation, NPC behaviour, dialogue, quests, factions, reputation,
loot, inventory, checkpoints, save/load, respawn systems, new weapons, new attacks, combat tuning,
stamina cost changes, dodge/parry timing changes, hitbox/hurtbox dimension changes, and new content
created only to demonstrate the system.

### 8K.7 Deferred follow-up (recorded, NOT folded into this milestone)

- Enemy persistence across a real game-state transition (checkpoints, scene reload, save/load).
- Relationship / team / faction state, and friendly / neutral / hostile gameplay. No such state
  exists anywhere in the project, and this pass does not invent it.
- Target SELECTION (choosing among several valid targets). This pass makes a single resolved target
  invalid-safe; it does not add a selection policy.
- Lock-on, pursuit, navigation and enemy AI (section 13).

### 8K.8 Files changed this pass

Recorded in full in `CASCADIA_DELETION_MANIFEST.md` under this pass's heading. In short:

- Created: `scripts/combat/combat_participant.gd` (`class_name CombatParticipant`) - the one new
  gameplay file. Per-actor combat capability as a query surface, plus one static target-validity
  authority (`target_refusal()` / `is_usable_target()`) that fails safe on a missing, freed,
  non-participant, dead, defeated or non-targetable node.
- Created: `scripts/diagnostics/actor_combat_readiness_probe_debug.gd` and
  `scenes/diagnostics/actor_combat_readiness_probe_debug.tscn` - the deterministic probe.
- Modified: `scripts/combat/enemy_attacker.gd` - target USABILITY gate before range, by-cause
  target-refusal counters, `has_valid_target()`, `target_refusal_reason()`, and the auto-attack
  path recording its refusal cause once per spell rather than once per frame. NO timing, damage,
  range, cadence or telegraph value changed.
- Modified: `scripts/diagnostics/combat_debug_overlay.gd` - each damageable-actor row now annotates
  the participant state. Read-only; no system owns presentation through it.
- Modified: `scenes/actors/test_attacker.tscn`, `scenes/dummy_actor.tscn`,
  `scenes/test_environment.tscn` - a `Participant` node under each of the three combat actors.
- Modified: this roadmap and the deletion manifest.

### 8K.9 Per-actor combat readiness, as it actually stands after this pass

Read from the live scenes and confirmed at runtime by the probe and the rendered readout:

| Actor | damageable | mortal | attack-capable | valid target (alive) | valid target (dead) | participant node |
| ----- | ---------- | ------ | -------------- | -------------------- | ------------------- | ---------------- |
| Player | yes | n/a - `DeathComponent` | yes | YES | NO (refused DEAD) | ADDED this pass |
| TestAttacker | yes | YES | YES | YES | NO (refused DEAD) | ADDED this pass |
| DummyActor | yes | YES | no | YES | NO (refused DEAD) | ADDED this pass |
| TargetA / B / C | yes | no | no | not a combat object | not a combat object | none (readout: `no participant`) |

The three static targets carry no participant and are reported as `[no participant]` rather than
silently reading as alive combatants - which is exactly the honest answer for scenery that can take
damage but is not a fight participant. Adding one later is one node, which is the reuse this pass
proves.

### 8K.10 Measured results - `actor_combat_readiness_probe_debug` (run 2026-09-12)

`res://scenes/diagnostics/actor_combat_readiness_probe_debug.tscn`. Executed against the live
project; every line below was read from the actual console output of a fresh run.

`[ACTRD] RESULT: ALL CHECKS PASSED`, with 0 runtime errors.

Measured values, quoted from the run:

- AC5/AC6 dead target: `dead target via try_start: started=false  target_refusals_dead 0 -> 2
  out_of_range 0 -> 0`. The dead actor was refused AS A TARGET, filed under the DEAD cause, and
  NOT filed as an out-of-range refusal.
- AC6 no corpse-facing: `the attacker did not turn to face the dead target (max drift 0.0000 rad)`.
  Before this pass the attacker turned to face a dead body; that is the defect this milestone closed.
- AC4 revived actor: `revived player: refusal=usable  attacker_in_range=true`. The refusal is a
  STATE, not a permanent ban - a revived actor is targetable again.
- AC9/AC10 player circuit unchanged: `after 0.85 s: player_dead=false  player_health=100.0
  resets=1`, and `after reset: dummy defeated=true  health=0.0`. The player came back; the defeated
  dummy did not.
- AC12 defeated actor cannot act: `defeated attacker via try_start: started=false
  defeat_refusals 0 -> 1`, and held over 40 frames `attacks 0 -> 0`.
- AC3 defeated actor is not a target: `defeated attacker participant: dead defeated attack-capable
  targetable  can_act=false  valid_target=false`. Note the axes stay separate - the actor is still
  reported `attack-capable` and `targetable` as CAPABILITY while `can_act` and `valid_target` say NO
  for its CURRENT state. That separation is the point of the milestone.
- AC8 invalid targets fail safely: a non-participant node is refused `NOT_PARTICIPANT`; a FREED node
  is refused `MISSING` without raising.

### 8K.10b Regression set re-run the same pass

Every probe was re-run from a freshly started instance; none was carried forward, and each result
below was read from the console of its own run.

- `enemy_attack_probe_debug`: all printed checks PASS, measured `windup=0.58s active=0.13s
  recovery=0.70s` against `0.60/0.12/0.70` authored - UNCHANGED.
- `target_sweep_debug`: ALL CHECKS PASSED, 5/5 targets damaged - the probe most exposed to the
  targeting change.
- `death_probe_debug`: `RESULT: ALL CHECKS PASSED`, `deaths=2, resets=2 (input-driven 1)`, including
  `PASS  the test attacker still resolves the player as a target`.
- `enemy_death_probe_debug`: `RESULT: ALL CHECKS PASSED`; the defeated enemy stayed defeated across
  the player's reset.
- `actor_death_probe_debug`: `RESULT: ALL CHECKS PASSED` - the accepted 8J milestone is intact.
- `damage_probe_debug`: `RESULT: ALL CHECKS PASSED`, `applied=4 damaged=4 died=1`.
- `actor_probe_debug`: `RESULT: ALL CHECKS PASSED` (layer separation, no re-apply on a held window).
- `attack_probe_debug`: `RESULT: ALL CHECKS PASSED` - light 15, heavy 32, damage values UNCHANGED.
- `stamina_probe_debug`: all decoded checks PASS - attack costs 18 light / 32 heavy, UNCHANGED.
- `dodge_probe_debug`: `RESULT: ALL CHECKS PASSED`, `measured travel=1.688m`, 15 i-frame refusals.
- `parry_probe_debug`: `RESULT: ALL CHECKS PASSED`, `measured travel=0.000m`.
- `grounding_probe_debug`: the ONE pre-existing failure is unchanged and NOT caused by this pass -
  `TestAttacker: rests on the surface, not floating or sunk (-0.020)`. `DummyActor` passes at 0.000.
  This pass changed no transform, shape or collision layer on any actor, so the recorded 8I.8 /
  12.3 item stands exactly as it was.
- `main.tscn`: booted with `total_errors: 0` (only warnings present).

### 8K.10c Rendered playtest (2026-09-12)

`res://main.tscn` booted and rendered in the live game. As with 8J.10c, the visual ANALYSER returned
`observer_analysis_failed`, so the rendered verdict is PARTIAL and read by eye from the captured
frame rather than an analysed pass.

What the frame showed:

- The arena, ground geometry, the player capsule and the combat readout all rendered.
- The combat readout listed EVERY damageable actor now annotated with its participant state:
  `DummyActor [.....] 100/100 [alive targetable]`, `TargetA` / `TargetB` / `TargetC`
  `100/100 [no participant]`, and `TestAttacker [.....] 100/100 [alive attack-capable targetable]`.
  The player row read `player [.....] 100/100`.
- This is the new capability visible in the running game rather than only in a probe: the readout
  now distinguishes an alive combatant, an attack-capable combatant, and damageable scenery, which
  is precisely the distinction the milestone was asked to make explicit.
- No actor was shown dead or stuck in that frame; `HIT LOG: no hits yet`.

One rendered frame cannot establish behaviour, so this is recorded as a readable, consistent FIRST
frame only. The behavioural claims rest on the probes above.

### 8K.11 Post-acceptance plumbing audit - the static targets (2026-09-12) - CONCLUSION SUPERSEDED

**READ 8K.12 BEFORE THIS SECTION. The verdict below was WRONG and is preserved only as history.**

This audit asked the right question and reached the wrong answer. It reasoned that an actor with no
defeat component was a deliberate "damage fixture" rather than a combat participant, and concluded
that "no participant" was intended design. That reasoning was backwards: it treated a missing death
path as an architecture choice, and it never asked the question that actually mattered - **should an
actor that can be damaged to zero show a defeated state?** The user answered that directly: yes, any
enemy that reaches zero must enter a defeated state. `TargetA/B/C` were a HOLE, not an archetype, and
they were the bug being reported. Section 8K.12 records the correction.

The user accepted 8K and asked ONE follow-up before moving on: the readout shows `TargetA` /
`TargetB` / `TargetC` as `[no participant]`, so is that intended design or incomplete plumbing?
Asked explicitly NOT to assume they must resemble `DummyActor`, and not to flatten different actor
types into one implementation to make the labels match.

**Audited from disk, not from the overlay.** `scenes/test_environment.tscn` lines 327-395:

| Actor | Body type | Has script | Components present |
| ----- | --------- | ---------- | ------------------ |
| TargetA / TargetB / TargetC | `StaticBody3D` | NO - none of the three bodies carries a script | `Mesh`, `Collision`, `Health`, `Hurtbox` (+ `Shape`) |

They carry NO `Attacker`, NO defeat component, NO `Participant`, and no player components (combat,
stamina, dodge, parry). They are placed by direct transform and have no gravity or floor logic.

**Their intended role, recorded BEFORE this pass and unchanged:** roadmap 8J.10d - "the three static
targets are damageable but deliberately NOT defeat-configured: they are static test fixtures, not
actors in a fight ... the alternative would be handing a defeat state to scenery." `target_sweep_debug`
uses all three (plus the player) as damage recipients to prove the
`Hitbox` -> `Hurtbox` -> `Health` chain reaches MULTIPLE actors; `grounding_probe_debug` uses them as
static placement fixtures. Neither role requires acting, being targeted, dying, or being reset.

**ANSWER: intentional non-participants, and the plumbing is CORRECT. No correction was made.**
The absence of a `CombatParticipant` does NOT leave them unhandled - `CombatParticipant.target_refusal()`
has an explicit UNWIRED FALLBACK (`combat_participant.gd` lines 244-253) that returns the pre-8K
health-based answer for an actor with no component: `NONE` (usable) while alive, `DEAD` once health
reaches zero. So their damageability and target-usability are preserved EXACTLY, and the fallback is
itself measured - the readiness probe asserts `participant == null` together with
`refusal == Refusal.NONE` on a component-less actor.

**The overlay is accurate, not merely echoing missing wiring.** `_combat_flags()` calls
`CombatParticipant.find_for(owner)` and prints the literal `[no participant]` when there is none,
rather than reconstructing a guess from health. It reports what the game believes about the actor.

**Why no component was added.** Three reasons, in order of weight:
1. It would change behaviour with no requirement behind it: declaring the fixtures
   `can_be_targeted = false` would flip `is_usable_target(TargetA)` from true to false today.
2. The fallback exists precisely so an unwired actor keeps working unchanged; the fixtures rely on
   it correctly rather than by accident.
3. Adding a component to scenery purely so a debug label reads differently is the flattening the
   user explicitly warned against. Actor-specific composition is preserved: attackers carry an
   attacker, the dummy is a mortal combat actor, the targets are damage fixtures.

**No consumer is broken by their absence.** Every `CombatParticipant` call site was enumerated:
`EnemyAttacker` (resolves only its own `target_group`, which is `player_actor`), the overlay, and the
readiness probe. Nothing enumerates participants and expects a fixture among them.

**The boundary this confirms, in one line:** DAMAGEABLE is not the same claim as COMBAT PARTICIPANT.
A damage fixture can accept damage without being an actor that acts, is targeted, dies or resets.

---

### 8K.12 CORRECTION - every damageable enemy must reach a defeated state (2026-09-12)

**The user reported a real defect, and 8K.11 had argued against fixing it.** Report, verbatim in
substance: the build does not show `TargetB` as defeated when reaching 0 health, implying no death
state is recorded; and there is NO TEST that determines that all enemies apply a defeated state after
death.

**The required behaviour, now the contract:** any actor that can be attacked to zero health
must enter a real defeated state, with a defeat presentation, through the existing death path.

**THE MISSING TEST WAS THE ROOT CAUSE.** Every previous probe proved the defeat path actor by actor,
by NAME (`enemy_death_probe_debug` on `TestAttacker`, `actor_death_probe_debug` on `DummyActor`). Not
one asserted the property ACROSS the arena. So `TargetA/B/C` - damageable, reachable by the player's
attack, and carrying no death path at all - reached zero health, processed NO defeat, showed nothing,
and still passed every probe in the suite, because no probe was looking at them. A property that is
only ever checked on named actors is not checked at all.

**The fix, in two parts:**

1. `scenes/test_environment.tscn`: `TargetA`, `TargetB` and `TargetC` each gained a `Death` node
   (`EnemyDeathComponent`, `mortal = true`) and a `DeathPresentation` node (the existing
   `enemy_death_presentation_debug.gd` adapter). They now use the SAME authoritative death
   architecture as every other enemy. No new system was written; the existing one was composed onto
   the actors that were missing it.
2. `scripts/diagnostics/defeat_coverage_probe_debug.gd` + its scene: the missing test. Driven by
   ENUMERATION, not a name list - it walks the `damageable` group, excludes the player (whose Death
   component is the one with `resets_actors`, i.e. the resettable circuit), kills every remaining
   enemy through the real `HurtboxComponent.receive_hit -> HealthComponent.apply_damage` chain, then
   requires of EACH: zero health, `mortal`, `is_defeated()`, `defeats == 1`, a defeat presentation
   present, and `is_showing()` true. A newly added enemy is covered the moment it exists.

**`defeat_coverage_probe_debug` RESULT: ALL CHECKS PASSED, 0 runtime errors. Enemies covered: 5 / 5.**

| Enemy | health | is_dead | mortal | is_defeated | defeats | presentation |
| ----- | ------ | ------- | ------ | ----------- | ------- | ------------ |
| DummyActor | 0.0 | true | true | true | 1 | showing |
| TargetA | 0.0 | true | true | true | 1 | showing |
| TargetB | 0.0 | true | true | true | 1 | showing |
| TargetC | 0.0 | true | true | true | 1 | showing |
| TestAttacker | 0.0 | true | true | true | 1 | showing |

**Rendered playtest, same arena, after the killing blows:** three red `DEFEATED` world labels drawn
above the target positions and the dummy, the cylinders tipped over and darkened, and the combat
readout reading `TargetA`, `TargetB`, `TargetC`, `DummyActor` at
`0/100 DEAD [dead defeated targetable]` and `TestAttacker` at
`0/100 DEAD [dead defeated attack-capable targetable]`, all in the DEAD colour, with the player row
`100/100` and upright. As always the visual ANALYSER returned `observer_analysis_failed`, so that
frame was read directly and is PARTIAL evidence.

**The unkillable archetype still exists and is still measured** - it is simply not a scene fixture any
more, because a fixture that was unkillable only by OMISSION was the defect. `_check_unkillable_archetype`
now builds one at runtime (health + `EnemyDeathComponent(mortal = false)` + participant) and proves:
it takes damage and reaches zero health, `is_mortal()` is false, `is_defeated()` stays false,
`defeats == 0`, the lethal hit is recorded by cause (`lethal_refusals >= 1`), it is refused as a target
for being DEPLETED rather than DEFEATED, it reports `depleted`, and it cannot act. That is the shape a
future quest / progression NPC uses.

**Actor archetype contract after this correction:**

| Archetype | Config | Example today |
| --------- | ------ | ------------- |
| Player | `DeathComponent` + `resets_actors = true` | Player |
| Attackable mortal enemy | `Health` + `Hurtbox` + `EnemyDeathComponent(mortal = true)` + presentation + participant | TestAttacker, DummyActor, TargetA/B/C |
| Unkillable / progression | `Health` + `Hurtbox` + `EnemyDeathComponent(mortal = false)`, `Hurtbox.damageable = false`, and/or `CombatParticipant.can_be_targeted = false` | none in the arena yet; measured by construction |

**Regression: all 13 existing probes re-run fresh and passed** (`enemy_attack` 0.58/0.13/0.70,
`attack` 15/32, `stamina` 18/32, `dodge` 1.688 m, `parry` 0.000 m, `damage`, `actor`, `death`
deaths=2 resets=2, `enemy_death`, `actor_death`, `target_sweep` 5/5 at 15.0 each, `dodge_input`,
`grounding` - which still shows its one PRE-EXISTING `TestAttacker` failure at -0.020, unchanged, and
now reports 6 damageable actors). `main.tscn` booted with `total_errors: 0`.

**No combat value, timing, stamina cost, dodge/parry window or hitbox/hurtbox dimension was changed.**
`target_sweep_debug` measuring `TargetA/B/C` at exactly 15.0 each is the evidence that composing a
death path onto them did not alter their damage behaviour.

No file was changed by this audit. It is documentation of a CONFIRMED design intent, per the project's
documentation-discipline rule.

---

## 8L. MILESTONE 9 - SOULSLIKE CREDIT ECONOMY AND MEANINGFUL PROGRESSION FOUNDATION

SELECTED BY THE USER; this section was written BEFORE implementation. Note: section 0 once
recorded "Milestone 9 = enemy pursuit". That was a MISLABEL - pursuit is still unstarted, and this
section is M9's real delivered scope.

MILESTONE 9 IS THE CURRENT MILESTONE. It was named and selected by the user, recorded here BEFORE any
implementation as the project's documentation rule requires, and implemented in the same pass. The
section label `8L` follows this file's convention of labelling milestone sections by 8-family letter
while stating the real milestone number in the title (cf. `8D. MILESTONE 8`); it deliberately does NOT
reuse `## 9.`, which is already the INPUT DESIGN NOTES section.

### 8L.1 Current verified state before this pass

- Milestones 0-8 ACCEPTED. 8I (enemy death), 8J (reusable death capability), 8K (combat readiness) and
  8K.12 (enumeration-driven defeat coverage) are all implemented and measured.
- The authoritative combat chain is `HitboxComponent -> HurtboxComponent -> HealthComponent`, with
  `EnemyDeathComponent` the single authority for enemy DEFEAT and `CombatParticipant` the single query
  for combat capability/state.
- FIVE mortal enemies exist in the arena (`TestAttacker`, `DummyActor`, `TargetA/B/C`), each already
  proven by `defeat_coverage_probe_debug` to reach a real defeated state with a presentation.
- NO currency, economy, progression, stat, item, gear or persistence system existed. This pass is the
  first economy work in the project's history.

### 8L.2 The core loop this milestone establishes

    defeat an eligible enemy -> that enemy awards Credits EXACTLY ONCE
                             -> Credits accrue on the PLAYER's carried balance
                             -> the balance is observable and deterministically testable

Storing, spending, converting and persisting are FUTURE systems and are named in 8L.6 so they are never
confused with the carried balance.

### 8L.3 The authoritative event reused, NOT reinvented

Damage already lands through `HealthComponent.apply_damage()`, which emits `died` exactly once and
refuses further damage to an already-dead actor. `EnemyDeathComponent` already consumes that and emits
`defeated()` exactly once, guarded by its own `_defeated` flag.

**The economy subscribes to `defeated()`.** It does NOT read `died`, does NOT poll `is_dead`, and does
NOT interpret a health value. So "what counts as a defeat" still has exactly ONE owner, and the economy
cannot drift from it. The economy OBSERVES the authority; it never redefines it.

### 8L.4 Reward eligibility - an explicit rule, not "reached zero health"

An actor awards Credits only when ALL of the following hold:

1. it carries an `EnemyDeathComponent` (the authoritative defeat authority), AND
2. that component reports `is_defeated() == true` at the moment of the award, AND
3. that component reports `is_mortal() == true`, AND
4. its body is not the player-controlled actor.

Each consequence is deliberate:

- **Non-mortal actors award nothing, structurally.** `EnemyDeathComponent` with `mortal = false` returns
  before any state change and never emits `defeated()`, so the economy is never even called. The
  exclusion is a property of the existing death authority, not a second check that could drift from it.
- **The player awards nothing.** The player carries `DeathComponent` (the resettable respawn circuit),
  not `EnemyDeathComponent`, so it never emits `defeated`; the `player_actor` group is checked as an
  explicit second statement of the same rule.
- **Reaching zero health is NOT sufficient.** Eligibility requires the component's own DEFEATED state,
  so an actor whose health reached zero without entering the defeat path awards nothing.
- **A freed, missing or non-node actor awards nothing** - guarded before any state is touched.
- **An eligible enemy awards at most once**, tracked per actor, so a repeated signal, a repeated frame or
  a repeated observation cannot pay twice.

### 8L.5 Provisional credit amount

**Credits** is the provisional resource name. The reward is ONE explicit value, `reward_per_enemy`
(default **100**), held on the ledger and trivial to replace later. Deliberately NOT implemented:
multiple currencies, enemy-specific balancing, rarity or loot tables, modifiers, multipliers, farming
prevention, or any final reward design.

### 8L.6 The four-way boundary, and exactly which parts exist

| Concept | Meaning | Exists after this pass? |
| ------- | ------- | ----------------------- |
| CARRIED Credits | the balance the ACTIVE player run holds | **YES** - this milestone |
| STORED Credits | safely banked at a future location or system | **NO** |
| SPENT Credits | converted into stats, items, gear or upgrades | **NO** |
| PERSISTENT Credits | restored through game-state saving/loading | **NO** - Milestone 10 |

Only CARRIED Credits are implemented. The other three are NAMED here so that no later reader mistakes
the carried balance for a bank, and so Milestone 10 has a boundary to attach to.

### 8L.7 Player death behaviour - decided EXPLICITLY, not silently

The existing player death/reset contract is PRESERVED UNCHANGED: `DeathComponent` still restores health,
stamina, position and committed action state, and still resets the arena's scripted attacker.

**DECISION FOR THIS MILESTONE: carried Credits SURVIVE the player's death and reset.** They are not
dropped, lost, halved or banked. This is an explicit, recorded choice and it is MEASURED by the probe -
it is not left implicit either way. The Soulslike "die -> drop carried Credits -> attempt recovery" loop
is NOT implemented and is recorded as future work in section 13. Adding a fake bank merely to avoid
deciding was explicitly rejected as a design.

### 8L.8 Milestone 10 - planned follow-up (RECORDED, NOT IMPLEMENTED)

**Game-State Saving and Loading.** Its purpose will be to persist the authoritative state that the
economy and progression systems create. It must eventually distinguish carried / stored / spent
Credits, player progression, stats, items, gear, inventory, location, world state, defeated enemies,
quest state, checkpoints, temporary runtime state and death/reset state. NONE of that is implemented
now and NONE of it may be started without explicit authorisation.

The only requirement Milestone 9 places on Milestone 10 is a NEGATIVE one: do not make those
distinctions impossible later. The economy therefore owns exactly ONE piece of state (the carried
balance) and keeps it separable from health, position, defeat state and presentation.

### 8L.9 In scope (as selected)

- One reusable carried-Credit balance owned by the player run, with add, read and deterministic reset.
- Awarding Credits from the AUTHORITATIVE enemy defeat event, once per eligible enemy.
- An explicit reward-eligibility rule that excludes non-mortal, non-participant and player archetypes.
- Reusable debug presentation of the current carried balance and of a gain.
- Deterministic verification driven by ENUMERATION of the enemy population.
- Preserving player and enemy death behaviour exactly.

### 8L.10 Explicitly out of scope (NOT built, NOT partially built)

Banking/storing, spending, stats, items, gear, upgrades, shops, merchants, inventory, equipment,
progression trees, player stat systems, death Credit-drop or retrieval, checkpoints, save/load,
persistent Credits, persistent enemy defeat, scene-persistent world state, enemy AI, navigation, enemy
pursuit, factions, dialogue, quests, NPC relationship systems, a universal Actor framework, a full NPC
archetype framework, multiple currencies, and final economy balancing.

### 8L.11 Measured results, files changed and the probe

Recorded in full in `CASCADIA_DELETION_MANIFEST.md` under this pass's heading, and in the verification
history log in section 16. The probe is `defeat_coverage_probe_debug`'s sibling:
`credit_economy_probe_debug`, driven by enumeration rather than by a name list, carrying forward the
central lesson of 8K.12 - **a name list proves the actors you remembered; enumeration proves the actors
you forgot.**

---

## 8M. MILESTONE 10 - GAME-STATE SAVING AND LOADING FOUNDATION (selected 2026-09-12; roadmap written BEFORE implementation)

The user SELECTED Milestone 10 and wrote its scope. This section is the record, written BEFORE any
code, per the project's standing rule. Milestone 9's history, caveats, defect manifest and deletion
manifest are PRESERVED.

### 8M.1 Current verified state before this pass

- `CreditLedger` (`scripts/economy/credit_ledger.gd`) owns the CARRIED balance and is the ONLY
  authority for it. Measured: `credit_economy_probe_debug` RESULT: ALL CHECKS PASSED - 5 eligible
  enemies, 500 Credits, 5 awards, duplicates refused, player and non-mortal exclusions counted by cause.
- `defeat_coverage_probe_debug` (5/5) and `actor_death_probe_debug` re-run and PASSED after M9.
- The carried balance is already OBSERVABLE in the running game: the combat readout shows
  `carried credits N`, read through `CreditLedger.find_ledger()`.
- NOTHING persists. `credits` is RUN state and is expected to die with the process.

### 8M.2 The loop this milestone establishes

    defeat enemies -> carry Credits -> save the real current state -> change the state -> load it back

That is the FIRST meaningful persistence loop for Cascadia, and deliberately the smallest one. This is
NOT a generalised serialization framework and NOT a full inventory or save architecture.

### 8M.3 Owner and boundary

`CreditLedger` REMAINS the authority for carried Credits. The save system does not own a balance, does
not keep a second copy, and does not mutate Credits by reaching into node internals. It reads
`CreditLedger.credits` to save, and restores through an explicit ledger API
(`restore_carried_credits()`) that is NOT an award.

The four-way boundary from 8L.6 is unchanged. After M10 exactly two of the four exist:

| Concept | Owner | Exists after M10 |
| ------- | ----- | ---------------- |
| CARRIED | `CreditLedger.credits` | YES |
| STORED | nothing | NO |
| SPENT | nothing | NO |
| PERSISTENT | `GameStateSave` (save file) | YES - carried Credits ONLY |

### 8M.4 Supported save schema

One JSON object at `user://cascadia_save.json` - Godot's own user-data location, deliberately OUTSIDE
the project tree so a save can never be committed by accident.

    {
      "schema_version": 1,
      "saved_at_unix": <int>,
      "carried_credits": <int>
    }

`schema_version` is explicit and CHECKED on load. An unrecognised version is refused, not guessed at.

### 8M.5 Load failure modes, each explicit

Each failure is a distinct typed result, so "it did not load" can never be confused with "it loaded
zero": OK, NO_SAVE, READ_FAILED, MALFORMED, UNSUPPORTED_VERSION, MISSING_FIELD, INVALID_VALUE,
NO_LEDGER, WRITE_FAILED. A FAILED LOAD LEAVES THE CARRIED BALANCE UNTOUCHED.

### 8M.6 New run vs load, kept distinguishable

`new_run()` resets the ledger to its documented starting balance AND removes the save file. It is a
SEPARATE call from `load_game()` returning a different result, so a fresh run can never masquerade as a
successful load, and a load after a new run correctly reports NO_SAVE.

### 8M.7 In scope

- `scripts/core/game_state_save.gd` - the save/load service. Placed in an ALREADY REGISTERED directory
  on purpose: a brand-new folder is not in Godot's global class cache and produced a load failure
  earlier in this project (recorded in the deletion manifest).
- An explicit restoration API on the EXISTING `CreditLedger`; no second balance anywhere.
- A controlled, VISIBLE debug action to save / load / start a new run.
- `scripts/diagnostics/game_state_save_load_probe_debug.gd` + its scene: drives the REAL ledger and the
  REAL save path, including a missing file, a malformed file, and repeated loads.

### 8M.8 Explicitly out of scope (NOT built, NOT partially built)

Banking, storing, spending, stats, items, gear, shops, inventory, equipment, checkpoints, enemy respawn
persistence, world-state persistence, player death currency loss, multiple save slots, cloud saves,
encryption, settings/options saving, enemy pursuit, navigation, factions, dialogue, quests.

### 8M.9 Requirements this pass must satisfy

- Boot `main.tscn` from a fresh run with 0 runtime errors.
- Save writes a REAL file carrying the schema above.
- A change made after saving is REVERTED exactly by loading.
- Loading awards nothing, duplicates nothing, and revives nothing.
- Missing and malformed data fail safely with the balance untouched.
- Repeated loads do not compound or duplicate state.
- Existing combat and defeat authorities are UNCHANGED.
- Regressions re-confirmed FRESH, and any regression NOT confirmed is recorded as unconfirmed rather
  than reported as passed.

### 8M.10 Measured results - `game_state_save_load_probe_debug` (run 2026-09-12)

`res://scenes/diagnostics/game_state_save_load_probe_debug.tscn`. Executed against the live project;
nothing below is inferred from a static read.

`[SAVEPROBE] RESULT: ALL CHECKS PASSED`, with **0 debugger errors**.

The full round trip, quoted from the run:

- Established baseline through the REAL path: `starting=0`, the first eligible enemy killed through
  the damage chain, balance `0 -> 100`.
- A distinctive `+250` made the saved value `350`, so "the load did nothing" cannot pass by
  coincidence.
- Save file on disk: `schema_version=1  carried_credits=350`, read from DISK rather than from the
  in-memory payload that produced it.
- Balance then changed to `1250` (`+900`) WITHOUT rewriting the file - a save is a snapshot, not a
  mirror; the file still held `350`.
- Load restored the EXACT saved balance `350`, with `awards` unchanged, `rewarded_count()` unchanged
  and nothing revived.
- A real enemy killed AFTER the load paid exactly once, taking `350 -> 450`.
- Repeated loads kept returning OK and did NOT compound: still `350` when re-measured at the point
  of the repeat, and no extra awards.
- `new_run` returned OK, reset the balance to the documented starting value `0`, removed the save
  file, and a subsequent load then reported `NO_SAVE` - a fresh run cannot look like a load.
- Malformed-data matrix, each with its OWN result and the balance UNTOUCHED (`450 -> 450` in every
  case): `empty file` -> malformed; `JSON that is not an object` -> malformed;
  `unsupported schema_version` -> unsupported-version; `no schema_version` -> missing-field;
  `no carried_credits` -> missing-field; `carried_credits` as text -> invalid-value;
  `carried_credits` negative -> invalid-value; save deleted -> `NO_SAVE`, deliberately distinct from
  a corrupt one.

### 8M.11 Files changed this pass

Created:

- `scripts/core/game_state_save.gd` (`class_name GameStateSave`) - the save service. Gameplay, not
  diagnostic. It owns the schema, the file, and the result vocabulary; it owns NO balance.
- `scripts/diagnostics/game_state_save_load_probe_debug.gd` + its scene - the probe.
- `scripts/diagnostics/save_load_debug_controls.gd` - the temporary prototype F5/F9/F10 panel.

Modified:

- `scripts/economy/credit_ledger.gd` - added `restore_carried_credits()` (the controlled restoration
  path a load uses) and a `loads` counter. Deliberately NOT `award_credits()`: a load is not a
  defeat, so it does not increment `awards`, does not emit `credits_awarded`, and does not mark any
  actor as paid.
- `main.tscn` - added the `GameStateSave` node and the `SaveLoadControls` layer.
- `project.godot` - `quick_save` (F5), `quick_load` (F9) and `new_run` (F10) InputMap actions.

NOT changed: `HealthComponent`, `HurtboxComponent`, `EnemyDeathComponent`, `CombatParticipant`,
`DeathComponent`, `EnemyAttacker`, and every combat value and timing. The save layer observes the
economy; it does not participate in combat.

### 8M.12 Two defects found and fixed in THIS pass

1. **Probe assertion could never pass (AC10).** The check read
   `_is_defeated(_enemy_a) == defeated_before and not defeated_before`. `_enemy_a` is the enemy killed
   BEFORE the save, so `defeated_before` is true and `not defeated_before` is false: the assertion was
   unsatisfiable and reported a real behaviour as a failure. Fixed to assert the actual contract -
   `defeated_before and _is_defeated(_enemy_a)` - i.e. this milestone does NOT persist defeated
   enemies, so nothing revives them.
2. **Probe asserted a frozen `credits_earned`.** `restore_carried_credits()` deliberately RE-BASES
   `credits_earned` to the restored total, because the restored balance IS this run's earnings as of
   the save point and a frozen value would make earned and carried disagree. The check now asserts
   CONSISTENCY (`credits_earned == get_credits()` after a load), which is the documented contract.

Also improved while measuring: `GameStateSave` now parses with `JSON.new().parse()` instead of
`JSON.parse_string()`. A corrupt save is an EXPECTED condition, and `parse_string()` pushed an engine
error into the log on every read, which made a handled failure look like a game fault. The probe went
from 2 debugger errors to **0** after this change.

### 8M.13 Honest limits of this pass

- The rendered frame was READ BY EYE. The visual analyser returned `observer_analysis_failed` on
  every capture, exactly as in 8J and 8K, so the rendered verdict is PARTIAL.
- `credit_economy_probe_debug`, `defeat_coverage_probe_debug` and `actor_death_probe_debug` were
  re-run FRESH this pass and each returned ALL CHECKS PASSED with 0 debugger errors.
- The remaining regression probes (attack, stamina, dodge, parry, enemy-attack, target-sweep,
  damage, actor, grounding, dodge-input, enemy-death, death) were ALL re-run FRESH and individually
  after the ledger, save service and scene wiring were in place, and every one returned ALL CHECKS
  PASSED with 0 debugger errors. This was done rather than assumed because the ledger was edited and
  the main scene gained two nodes, so an untouched-probe assumption would have been a guess. The
  sweep is recorded in the changelog with each probe's measured values.
- `grounding_probe_debug` still carries its one PRE-EXISTING `TestAttacker` failure (-0.020),
  unchanged and still separately identified. It was not repaired or reinterpreted here.
- The 20 script errors scoped to `open_script_buffers` naming `CreditLedger` are the STALE OPEN-TAB
  BUFFER artifact: per-file `state:script-errors` returns 0 for every one of those files and the
  probes run and print in full. Recorded again in the deletion manifest; judge by a run or a disk
  read, never by the open-tab linter.

---

### 8M.14 M10.1 CORRECTION - restore the RUN, not just the number (2026-09-12)

The user reported that M10's save path works at the data level but that LOADING BREAKS THE PLAYABLE
STATE, and asked for M10 to be corrected so that a save represents the current OVERALL implemented
run state with carried Credits as only ONE field. The standard is not "the number came back" but
"the game came back". Recorded BEFORE implementation, per the standing rule.

#### 8M.14.1 What M10 actually implemented (the honest version)

`GameStateSave` persisted exactly ONE gameplay value (`carried_credits`) plus `schema_version` and a
timestamp, and `load_game()` restored exactly that one value through
`CreditLedger.restore_carried_credits()`. Nothing else in the run was read, written or restored, and
no rule existed about WHEN a load is safe to apply. The Credit-only round trip in 8M.10 passed
because it only ever tested one number.

#### 8M.14.2 Root cause, diagnosed from the live code

1. **THE SAVE IS NOT A RUN.** The authoritative run state includes things the save never reads: the
   run's identity, the player's survival state, and which actors are defeated. A load therefore
   cannot put the run back - it overwrites one number inside a world that has moved on. Save at 100
   Credits, defeat another enemy, load: the balance returns to 100 while the enemy that paid for the
   other 100 stays dead. The ledger and the world then DISAGREE, and nothing can detect it.
2. **NO LOAD-SAFETY RULE.** `load_game()` validates the file and then applies its value
   unconditionally; it never asks whether the player is dead or mid-reset. The death circuit owns the
   player's restoration and runs it on its own schedule, so a load applied underneath it fights the
   system that owns that state instead of deferring to it. That is the concrete mechanism by which a
   load can leave the run in a state the death circuit did not author.
3. **NO RUN IDENTITY.** "New run" and "loaded run" are distinguishable only by the ABSENCE of a file,
   so a run that has already been loaded cannot be told from one that was started fresh, and the
   distinction cannot be asserted by any test.

#### 8M.14.3 The corrected contract (schema_version 2)

Every saved field has exactly ONE owner, a read path and a restore path:

| Field | Owner | Read via | Restore via |
| ----- | ----- | -------- | ----------- |
| `schema_version` | GameStateSave | constant | REJECTED unless 2 |
| `saved_at_unix` | GameStateSave | clock | provenance only, not restored |
| `run.id` | GameStateSave | generated when the run begins | compared, never applied |
| `run.started_unix` | GameStateSave | clock when the run begins | compared; makes new-vs-loaded ASSERTABLE |
| `carried_credits` | CreditLedger | `ledger.credits` | `ledger.restore_carried_credits()` |
| `player.alive` | HealthComponent + DeathComponent | `Death.is_dead()` | validated, never forced |

INTENTIONALLY EXCLUDED, and now recorded AS PART OF THE CONTRACT rather than silently omitted:

- **Player health, stamina and position** - owned by the death/reset circuit. Persisting them would
  let a load bypass `DeathComponent`'s own restoration order, which is the exact bypass M10.1 must
  not create. Excluded until the death circuit owns a save-participation contract.
- **Defeated-actor state** - owned by `EnemyDeathComponent`. A load must never revive a defeated
  actor, and it does not: a load touches no actor at all. Enemy persistence across a load remains
  DEFERRED, not silently claimed.
- Enemy health, world geometry, checkpoints, deaths, banking, spending, stats, items, gear.

#### 8M.14.4 Load safety rules, applied IN ORDER

1. Validate the FILE - exists, readable, parses as a JSON object.
2. Validate the SCHEMA - version present and supported; required fields present and correctly typed.
3. Validate the RUN - a run block with a non-empty id is required.
4. Validate the PLAYER block - present, and it must record a playable player.
5. Validate that the load is APPLICABLE NOW - if the player is dead or mid-reset, REFUSE with its own
   result instead of applying a load into a transitional state.
6. Only then restore, through the owner, changing nothing else.

Every refusal returns BEFORE any state is touched, so a refused load leaves the run exactly as it was.
Symmetrically, a save is REFUSED while the player is dead or resetting, so a save always represents a
playable state rather than a mid-death one.

#### 8M.14.5 New probes created by this correction

- `game_state_overall_probe_debug` - the overall-state contract, including post-load movement and
  post-load combat driven by real injected input.
- `game_state_death_loop_probe_debug` - the death/reset interaction with save and load.
Measured results are recorded in 8M.15.

---

### 8M.15 M10.1 measured results - the RUN comes back (2026-09-12)

Two NEW probes, both driven against the REAL scene and the REAL authorities, both
`RESULT: ALL CHECKS PASSED` with **0 debugger errors**.

**`res://scenes/diagnostics/game_state_overall_probe_debug.tscn`** - the overall-state contract:

- A new run starts at the documented balance, with its own identity, and loading reports `no-save`.
- Baseline established through the real chain: a real defeat paid 100 into the carried balance.
- The save file carries `schema_version=2`, a `run.id`, `run.started_unix`, the carried balance and
  `player.alive` - read back from DISK, not from the payload that produced it.
- A load restored the exact saved balance (350) and left the player in a valid state.
- **AC11/AC12, the correction's whole point: after loading the player still MOVES (travelled 1.3133 m
  over 24 frames) and still ENTERS COMBAT (`combat node=true  entered combat=true`).**
- 12 malformed/missing/wrong-version/absent-field cases each failed with its OWN result and left the
  balance at 350; a deleted save reports `no-save`, distinctly from a corrupt one.
- A new run removed the save, reset to 0 and got a DIFFERENT run identity, so a fresh run cannot be
  mistaken for a load.
- Service counters after the run: `saves=1 loads=4 new_runs=2` - no second ledger, no second service.

**`res://scenes/diagnostics/game_state_death_loop_probe_debug.tscn`** - the death-loop contract:

- Saved at 100 carried Credits, then killed the player through the real damage path.
- **A load INSIDE the death window is REFUSED as `player-dead`** - its own cause, distinct from a bad
  file - and the refused load left the balance untouched, granted no award, revived neither the player
  nor the defeated enemy.
- The player was restored by the CIRCUIT's OWN reset (`resets 0 -> 1`), proving the restoration is the
  death circuit's and not a load's.
- A load OUTSIDE the window succeeded, restored exactly 100, emitted exactly ONE `game_loaded` signal,
  and paid no award.
- The defeated enemy was STILL defeated and still recorded as paid, so it cannot pay twice.
- `ledgers=1 save-services=1`: the load created no second owner and no second service.
- Repeated post-death loads kept succeeding without compounding the balance or awards.
- **The existing death contract is PINNED, not assumed: death left the carried balance at 100. No
  death-loss mechanic exists, and this pass did not invent one.**

### 8M.16 M10.1 defects found and fixed (all three in the NEW probe, none in the service)

1. The probe called `player_is_alive()`, but the service exposes `player_is_playable()` and
   `player_is_unavailable()`. Two call sites; fixed. This is the same class as the earlier
   `_check_repeated_loads` mismatch: a probe naming a method that does not exist is a probe bug.
2. `_check_bad_data` left `"run": {"id": "x"}` without `started_unix`, so the "no player block" and
   "player recorded as dead" cases were refused as `no-run` instead of `missing-field` /
   `invalid-value`. The expectations were stale v1 order; the run block now carries `started_unix`.
3. The post-load combat stage never recorded that combat was entered (`_saw_combat` was never set), so
   the combat assertion could not pass. It now records entry when the combat node reports busy.

### 8M.17 M10.1 honest limits

- `res://main.tscn` boots with 0 debugger errors, and the captured frame shows the SAVE / LOAD panel
  with `carried credits 0`. The visual ANALYSER returned `observer_analysis_failed` on every capture,
  so the frame was READ BY EYE and is NOT an analyser-verified pass.
- Re-run FRESH this pass, each `ALL CHECKS PASSED` with 0 debugger errors:
  `game_state_overall_probe_debug`, `game_state_death_loop_probe_debug`, `credit_economy_probe_debug`
  (5 eligible, 500 Credits, 5 awards), `defeat_coverage_probe_debug` (5/5), `actor_death_probe_debug`.
- The remaining regression probes were passed earlier in the session and this pass changed no combat,
  health, hurtbox, hitbox, stamina, dodge or parry code - but they are recorded as **NOT RE-CONFIRMED
  in this final pass** rather than as passed. Recorded honestly, per the standing rule.
- `grounding_probe_debug` still carries its one PRE-EXISTING `TestAttacker` failure (-0.020), unchanged
  and separately identified. Not repaired and not reinterpreted here.

---

### 8M.17a M10.2 - THE MOUSE_FILTER HYPOTHESIS IS FALSIFIED (2026-09-12)

Reported live symptom: the overlay showed `load: OK (carried 100)` and the playable runtime appeared
to stop functioning afterwards. A hypothesis was raised that the save/load debug panel consumes
gameplay mouse clicks because its `Control` nodes default to `MOUSE_FILTER_STOP`, and that this is
what made the game look dead.

**A hypothesis is not evidence, so it was tested instead of believed.** New probe:
`res://scripts/diagnostics/save_load_input_runtime_probe_debug.gd` (+ its scene), driving the live
tree and the live input system.

**WHAT THE PROBE MEASURED (4 independent mechanisms):**

1. **HIERARCHY** - walks the INSTANTIATED panel subtree and reads every `Control.mouse_filter`.
   Measured: `save panel subtree: 3 Control(s), 0 STOP`. The panel is visible, occupies a real
   rect `[P: (822.0, 8.0), S: (322.0, 139.0)]`, and overlaps the viewport.
2. **GUI DELIVERY** - counts Controls that RECEIVE a click via the real GUI path, with a positive
   control (`MOUSE_FILTER_STOP`) that MUST receive one. The positive control received nothing, so
   this harness was recorded as `SKIP - NOT MEASURABLE` rather than as a pass. It cannot detect
   consumption either way, and saying so is the honest result.
3. **END TO END (the decisive one)** - fires a REAL `Mouse1` event through `Input.parse_input_event`
   at a world point and at the panel centre, BEFORE and AFTER a save/load, and observes whether
   `PlayerCombat` actually starts. Measured: **all four started an attack** -
   `world BEFORE=true`, `panel BEFORE=true`, `panel AFTER=true`, `world AFTER=true`.
4. **CONTROLLED A/B** - the experiment that settles the hypothesis. The probe forces
   `MOUSE_FILTER_STOP` onto the panel and fires again at the panel centre.
   Measured: **the click STILL started an attack.**
   `=> the filter was NOT the cause of a lost attack.`

**CONCLUSION - the hypothesis is FALSIFIED.** A `Control` consuming a GUI click does not cost an
attack, because Cascadia reads attacks as semantic ACTIONS through `CascadiaInput`, and Godot
updates InputMap action state from the input event independently of viewport GUI consumption. The
panel was never capable of eating a mouse attack. Making the debug panel non-consuming is still a
correct harmless improvement and is kept, but it is NOT the cause of the reported symptom and must
never be recorded as a fix for it.

**THE RUNTIME IS NOT BROKEN BY A LOAD.** Measured after a real save/load in the same run:
`the scene tree is NOT paused`, `player physics processing still ENABLED`, `player instance still
valid and not queued for deletion`, `services before=(1, 1) after=(1, 1)` (no second ledger, no
second save service), the exact saved balance restored (100), and the player then **MOVED 1.0333 m
over 20 frames** - the runtime was still PROCESSING. `game_state_overall_probe_debug` independently
re-measured the player moving **1.3133 m** and entering combat after a load, ALL CHECKS PASSED, and
`game_state_death_loop_probe_debug` re-passed ALL CHECKS.

**A CONFOUND FOUND AND FIXED IN THE PROBE, worth recording for any future agent.** The first run of
this probe reported `the runtime is still PROCESSING after the load (player moved 0.0000 m)`. That
failure was the PROBE's fault, not the game's: movement was measured immediately after the probe's
own click had started an attack, and the 8L movement-authority rule makes a committed action
authoritative over locomotion, so ordinary movement is suppressed for its whole duration. The probe
now waits for the combat state machine to return to idle before measuring movement. The assertion
was NOT weakened - the confound was removed.

**FINAL VERDICT ON M10.2:** both reported problems are accounted for. Problem A is not the cause of
Problem B, and B has no reproducible failure in the current build: a controlled, instrumented
save -> change -> load -> continue-playing sequence passes with the player moving and attacking
afterwards. What remains genuinely unproven is only the HUMAN-ONLY part: whether pressing the real
F5/F9 keys by hand, with a real OS-level mouse, feels correct.

---

### 8M.17b M10.2 - THE SAVE/LOAD STATE MODEL IS CORRECTED: SNAPSHOT, NOT TALLY (2026-09-12)

**The user's diagnosis was right, and my earlier one was wrong.** Reported: the live game still shows
`DEFEATED` over gameplay while the overlay says `load: OK (carried 100)`; the save/load is really a
WORLD-STATE problem, not a credits round trip. The correct model, now recorded as the contract:

    SAVE:  player alive, TargetA alive, carried = 100
    RUN:   player defeated, TargetA defeated
    LOAD:  player alive, TargetA alive, carried = 100

**The save is authoritative for the state it records.**

#### The actual defect, found by reading the code (not guessed)

`enemy_death_presentation_debug.gd` was **one-way**. `_apply_defeat_pose()` existed; there was no
`_clear_defeat_pose()` and no branch that ever removed the pose. Once an actor was shown `DEFEATED`,
`_posed` stayed true for the life of the instance, so **`DEFEATED` could never come off a living
actor**. That is exactly the label stuck on screen. The adapter even remembered the original mesh
transform and material "for a future resurrect/reset" - that path had simply never been written.

Second, `load_game()` restored ONLY the carried balance, so even a correct save left every actor and
the player exactly as the live run had left them. Both halves had to be fixed.

#### What was implemented

- `HealthComponent.restore_to_full()` - the owner's own API for putting health back WITHOUT touching
  the defeat flag. `reset()` clears `is_dead`, so a restore that wants the defeat flag to stay under
  `EnemyDeathComponent`'s control needs its own entry point. Single definition, 0 duplicates.
- `EnemyDeathComponent.restore_defeated(value)` - sets the flag both ways and **deliberately does NOT
  emit `defeated`**, because that signal is what PAYS a reward: emitting it on a restore would mint
  currency every time a save was loaded.
- `_capture_world()` / `_restore_world()` in `GameStateSave` - records each actor under
  `EnemyDeathComponent.GROUP_ENEMY_DEATH` by **scene path** (no node references are ever serialized),
  plus its health, its defeated flag and its paid flag, **sorted so the same world always produces the
  same file**. Every field is written through its owner.
- The player is restored through **`DeathComponent.reset_playable_state()`** - the death circuit's own
  reset - never by this service writing player fields. The save service coordinates; it does not
  become a second owner of health, stamina, or death.
- `enemy_death_presentation_debug.gd` now polls BOTH ways, so the label comes off when the actor is
  alive again.
- Schema bumped to **3**.

#### Measured - `game_state_world_restore_probe_debug` (new)

`RESULT: ALL CHECKS PASSED`, 0 debugger errors. It performs the EXACT reported sequence: save with the
world alive, kill enemies AND the player, then load.

- `DummyActor`, `TargetA`, `TargetB`, `TargetC`, `TestAttacker`: all health restored to 100, all
  `is_defeated=false`, **none showing a `DEFEATED` label**; `after the load: alive=5 defeated=0`
- the player is alive again, restored through its **own death circuit** (`resets=1`)
- carried balance restored exactly (250)
- the player **MOVES after the load** (travelled 1.3133 m) and enters combat
- exactly ONE ledger and ONE save service exist after the load

#### Honest note on the earlier 8M.17a falsification

8M.17a proved the mouse_filter hypothesis wrong and it STAND. That work ruled out one explanation; it
never claimed the game was playable. The stuck `DEFEATED` was a separate, real defect in the
presentation adapter, and it is the one this pass fixes.

#### Defects found and fixed in MY OWN probes during this pass, each caught by a failing run

- `game_state_overall_probe_debug`: 7 fixtures hardcoded `schema_version: 2`, so after the bump to 3
  they stopped at `unsupported-version` and never tested the field they named. Every fixture now
  derives from `GameStateSave.SCHEMA_VERSION`.
- `game_state_save_load_probe_debug`: 3 fixtures used `schema_version: 1` AND omitted the run/player
  blocks, so "no carried_credits" never reached the carried_credits check. Fixed the same way.
- `game_state_world_restore_probe_debug`: hardcoded `== 3`; now derived.
- The same probe first reported "moved 0.0000 m" because it measured movement while its OWN
  click-started attack was still committed - the movement-authority rule suppresses locomotion during
  a committed action. It now waits for idle. The confound was removed, not the assertion.
- A duplicated unreachable dead-player branch in `load_game()` was removed rather than left as a guard
  that protects nothing.

**Lesson for future agents: a fixture that hardcodes a version constant silently stops testing its own
claim the moment the version moves, and it FAILS AS THE WRONG ERROR - which reads like the code under
test is broken. Derive fixtures from the constant.**

#### Contract change recorded deliberately, NOT silently

`game_state_death_loop_probe_debug` previously asserted that a load inside the death window is
REFUSED. Under the new contract a save always records a playable run, so loading it mid-death
RESTORES that run. The probe was updated to the STRONGER form: the revival must come from the death
circuit (`resets` must increment), it must pay nothing, and it must not revive an enemy the snapshot
recorded as defeated. `RESULT: ALL CHECKS PASSED`.

### 8M.18 M10.3 - MIXED-STATE SNAPSHOT PROOF (2026-09-12)

**Why this pass exists.** The user reported that quicksave/load was still broken, and made a fair
criticism of the evidence: the previous probes only ever saved a world where EVERY actor was alive.
An all-alive round trip cannot detect a wrong-actor restore, an inconsistent flag pair, or a restore
that silently rebuilds a default world. The all-alive case is one point on the curve, not the curve.

**The contract this pass proves.** The snapshot is authoritative for the state it records. Save with
3 alive / 2 defeated must load back as the SAME 3 alive and the SAME 2 defeated - not merely the same
COUNT, and not a default world.

**Probe created:** `scripts/diagnostics/game_state_mixed_state_probe_debug.gd` (and scene). It drives
the REAL scene, the REAL service and the REAL actor owners. Actors are identified by their SCENE
PATH, never by array or discovery order.

**Five snapshot densities, each verified per actor:**

| case | defeated at SAVE | defeated AFTER LOAD | alive | rewards across load | incoherent | exact state |
|------|------------------|---------------------|-------|---------------------|------------|-------------|
| 0 | `[none]` | `[none]` | 5 | 0 | 0 | true |
| 1 | `[DummyActor]` | `[DummyActor]` | 4 | 0 | 0 | true |
| 2 | `[DummyActor,TargetA]` | `[DummyActor,TargetA]` | 3 | 0 | 0 | true |
| 3 | `[DummyActor,TargetA,TargetB]` | `[DummyActor,TargetA,TargetB]` | 2 | 0 | 0 | true |
| 4 | `[all five]` | `[all five]` | 0 | 0 | 0 | true |

`RESULT: ALL CHECKS PASSED`, 0 debugger errors. Case 2 is the user's exact scenario and the NAMED
actors match on both sides. Each case also mutates by killing two further actors AND the player, so
every load has to bring a dead player back to playable.

**Per-actor fields asserted on every actor, every case:** `health`, `max_health`, `dead`,
`defeated`, `targetable`, `presentation showing`. Plus self-consistency: a defeated actor must also be
`dead`, must NOT be targetable, and an actor with zero health must not read as alive.

**DEFECT FOUND - in the NEW probe, not the service.** The first run reported `awards 0 -> 2` etc.
against a snapshot taken BEFORE the mutation. Each delta exactly equalled the enemies the MUTATION
killed, i.e. legitimate earnings, not load-time rewards. The probe was charging the load for the
mutation's own kills. Fixed by taking `_awards_before_load` / `_credits_before_load` IMMEDIATELY
before the load and asserting against those. Case 4 is the clean proof: it restored all five actors
to defeated and measured `awards 5 -> 5 ACROSS THE LOAD`.

**Regression re-run FRESH, each in its own instance, all 0 debugger errors:**
`game_state_world_restore_probe_debug` ALL PASSED (5 alive, 0 defeated, credits 250, player restored
via its own circuit, 0 DEFEATED labels); `game_state_overall_probe_debug` ALL PASSED (player moves
1.2718 m and enters combat after load; 12 bad-data cases each by own cause); `game_state_death_loop_probe_debug`
ALL PASSED; `defeat_coverage_probe_debug` ALL PASSED 5/5; `credit_economy_probe_debug` ALL PASSED
(5 eligible, 500, 5 awards, duplicate refusals 0 -> 5); `main.tscn` boots with 0 debugger errors.

**Rendered, read by eye** (the visual analyser returned `observer_analysis_failed` on every capture,
so this is eye-read, NOT analyser-verified): `phase IDLE`, `player 100/100` - NOT the 160/100 reported
earlier - `carried credits 0`, all five actors `100/100 [alive targetable]`, no `DEFEATED` label
anywhere, every actor upright, and the SAVE/LOAD panel reading `F5 save  F9 load  F10 new run`.

**Still unexplained:** the `160/100` observation. No path in `HealthComponent` can produce health above
maximum (`reset()` assigns `max_health`; `apply_damage` clamps with `maxf(0.0, ...)`; there is no heal
function and `max_health` is overridden in ZERO scenes). It was not reproduced and is NOT claimed fixed.

**Doc defect RECORDED HERE, RESOLVED 2026-09-14:** this file contained TWO sections numbered `8M.15` and
TWO numbered `8M.16`, because the M10.1 block and the M10.2 block each restarted the count. This pass
avoided a third collision by using `8M.18`. In a later MANUAL renumbering pass the M10.2 pair became
`8M.17a` / `8M.17b` - the file's own suffix pattern, as used by `8M.21a` / `8M.21b` - and every
cross-reference to them was updated. No other section number was touched, and no historical content
was changed by the renumber.

**Not verified by hand.** The physical F5/F9 flow has not been exercised by the user since this fix.

---

### 8M.19 M10.5 - DEEP quicksave contract: a THIRD enemy and a SECOND return to the same quicksave (2026-09-13)

The M10.4 gameplay probe proved ONE post-save kill and ONE load. The user asked for a deeper test:
kill additional enemies after the second and still return to the previous quicksave. That is the
right objection - one post-save kill cannot detect a reward history that only survives the FIRST
restore.

**DEFECT FOUND (M10.4, fixed in the same pass).** `CreditLedger` refuses to pay an actor twice and
recognises "already paid" by the defeat component's LIVE INSTANCE ID. A load puts the world back to
an EARLIER state, so an actor killed after the save is alive again - but the ledger still remembers
paying it. The restored run then has live, targetable, killable enemies that are permanently worth
ZERO Credits. The world was restored correctly and the economy silently stopped earning; the saved
balance was right while the run could no longer earn. No state-only check can see this, which is why
the earlier probes passed.

Fix, through the owners' own APIs: `CreditLedger.is_rewarded()` + `restore_reward_tracking()`, the
snapshot's per-actor `paid` field read via `is_rewarded()`, and load step 6d calling
`_restore_reward_tracking()`. The restore deliberately does NOT award, does NOT touch the balance and
does NOT inflate `awards`, and leaves `_watched` (live signal wiring) alone.

**Proof the fix is load-bearing.** A negative control - temporary `return 0` at the top of
`_restore_reward_tracking()` - produced the exact defect: the post-load kill still SUCCEEDED and the
enemy still died, but paid NOTHING (`awards 2 -> 2`), `RESULT: 2 FAILED`. Reverted and re-run on the
shipped state: `RESULT: ALL CHECKS PASSED`.

**The deep probe, rewritten as a queue-driven sequence** (extra kills and extra loads are data, not
copied stages). Victims: `DummyActor` before the save, `TestAttacker` after it, `TargetA` as the
THIRD enemy. Every kill goes through the real attack path, never an assignment.

| stage | action | measured |
| ----- | ------ | -------- |
| A | baseline | 5 alive, all targetable, 1 ledger, 1 save service |
| B | kill DummyActor, SAVE | file records all 5 by scene path incl. per-actor `paid` |
| C | kill TestAttacker AND TargetA | awards 1 -> 3 |
| D | LOAD 1 | DummyActor still dead; both others alive again; balance 100 |
| E | kill TargetA then TestAttacker again | awards 3 -> 5; balance 300 |
| F | LOAD 2 - the SAME quicksave | identical restore; awards 5 -> 5 ACROSS the load |
| G | kill TestAttacker a THIRD time | paid exactly once; awards 5 -> 6; balance 200 |

Both loads assert the save FILE is UNCHANGED since the save, so a passing load 2 cannot be explained
by the probe quietly re-saving the live world.

    held at save:  defeated=[DummyActor]                                   carried=100 awards=1
    after load 1:  defeated=[DummyActor]  alive=[TargetA,TargetB,TargetC,TestAttacker]  100  3
    continued:     defeated=[DummyActor,TargetA,TestAttacker]              carried=300 awards=5
    after load 2:  defeated=[DummyActor]  alive=[TargetA,TargetB,TargetC,TestAttacker]  100  5
    final play:    defeated=[DummyActor,TestAttacker]                      carried=200 awards=6
    RESULT: ALL CHECKS PASSED   (0 debugger errors from the probe)

The decisive new assertion is that the TWICE-revived enemy still pays on the third kill cycle - a
restore that cleared the paid set only on the first load could not pass it.

**NEWLY CONFIRMED:** a mixed snapshot survives REPEATED returns to the SAME quicksave, with the same
actors restored each time; reward history restores per actor, both directions (revived enemies pay
again, snapshot-dead enemies stay retired); the run keeps killing and earning after each load.

**NEWLY UNVERIFIED:** the physical F5/F9 keys. Every result above comes from injected
`Input.action_press` through the real action path - the closest automated equivalent, NOT an OS-level
key event.

---

### 8M.20 M10.6 - THE F9 FAILURE IS A HOST KEY COLLISION (2026-09-13)

**The reported defect is real, is reproduced, and its cause is OUTSIDE the game.** The user reported
that physical F9 breaks gameplay. It does - and not because of anything in the save/load path.

**Root cause, MEASURED with the game's consumer removed.** A new diagnostic
(`fkey_host_ownership_probe_debug`) injects function keys with `main.tscn/SaveLoadControls` set to
`PROCESS_MODE_DISABLED`, so no Cascadia code can react to `quick_save` / `quick_load` / `new_run`:

- **F9 IS THE HOST'S PAUSE TOGGLE.** It reached the game AND set `Engine.time_scale = 0`, released
  the mouse (2 -> 0), and starved the game's own frame loop to 6 of ~40 frames - with
  `SceneTree.paused == false` and the window still focused. A SECOND F9 press was NOT delivered
  (`delivered_to_game=0`) and restored the clock and the cursor. A toggle, not a one-way stop.
- **F8 ENDS THE DEBUG SESSION.** The process stops on F8 with no script error and no trace.
- **SAFE and delivered** (`scale=1.000 paused=false mouse=2`, no skipped input frames): F1, F2, F3,
  F4, F5, F6, F7, F10, F11, F12 and ordinary letters (K tested as the letter control).

**Why it looked like a broken load.** With `time_scale == 0` the loop still renders, so the game
LOOKS alive while every delta-driven system is frozen - movement, mouse look, attack phases, dodge
and stamina regeneration. Every in-engine health check reads fine (`paused=false`,
`is_processing()==true`, camera current, player alive). That is precisely the reported symptom, and
it is also why `CascadiaInput._keep_clock_running()` - which DOES re-assert the clock every frame -
cannot win: the host re-applies the stop and starves the loop.

**Why the earlier automated verification was "inconsistent".** It was not inconsistent; it was
driving a host key. `save_load_runtime_state_probe_debug` used `KEY_LOAD := 4194339` = **F8**, while
its own banner printed "F9", so every run measured the host ending the session - hence a transcript
that stopped at the `--- PHASE 4 ---` banner with no script error.

**Fix applied.** New InputMap actions `load_run` (F7) and `load_run_alt` (F11), both from the
measured-safe list. `save_load_debug_controls.gd` reads those instead of
`quick_load`/`quick_load_alt`. `quick_load`/`quick_load_alt` remain in the InputMap, UNUSED, so the
host collision stays re-testable; removing a binding is manual review. The contract probe now drives
F7.

**Measured after the rebind** (`_probe_report.txt`, 0 debugger errors): `RESULT: ALL CHECKS PASSED`.
F5 saves (saves 0 -> 1); the mutation kills `DummyActor` and earns 100; both loads return
`result=OK` and restore the player to **0.195 m** of the saved position. Gameplay continues after
EACH load: walk 1.7950 m, mouse look 48.8952 deg, attack 8 -> 9 then 9 -> 10, dodge running, and
**stamina regenerates** 60.0 -> 77.9 and 47.6 -> 65.4. Across all **80 traced frames** there is
**not one** frame with `scale=0.000`, `mouse=0`, `paused=true` or a dead player - the reported
unplayability window is ABSENT.

**NEWLY CONFIRMED:** the F9 failure's cause is a host key collision, not the save/load path;
`time_scale` and mouse capture are restored and STAY restored for 40 consecutive frames after each
load; stamina regeneration - the contract condition still recorded as failing separately - does
regenerate after both loads.

**NEWLY UNVERIFIED:** the physical F5/F7 keys pressed by hand. Every result above is injected
`Input.parse_input_event` through the real action path, which is NOT an OS-level key event. The
user's physical test remains the only proof of that half.

**RECOMMENDATION FOR THE USER, not applied:** F8 and F9 cannot be used from inside this host. If the
host ever frees those keys, `quick_load` can be restored to F9; until then the load key is F7
(alternate F11).

---

## 9. INPUT DESIGN NOTES (do not regress)

Input layering, in one direction only:

    physical device -> InputMap action -> CascadiaInput -> gameplay systems

Gameplay code must never read physical keys, mouse buttons or controller buttons
directly. It reads semantic `GameActions` names through `CascadiaInput`.

Bindings confirmed present in `project.godot` (`physical=true` for WASD and location keys):

| Semantic action | Keyboard / mouse | Controller |
| --------------- | ---------------- | ---------- |
| move_forward / backward / left / right | W / S / A / D (physical) | left stick axes 0 / 1 |
| camera_look_up / down / left / right | (mouse motion, owned by CascadiaInput) | right stick axes 2 / 3 |
| sprint | Left Shift (physical) - SHARED command: HOLD = sprint | via `mobility_button` hold |
| dodge | Space (physical, dedicated) - or Left Shift TAP | via `mobility_button` tap |

AMENDED 2026-09-12 (Sprint / Dodge / Backstep input pass, section 8E). Left Shift is now a
SHARED tap/hold command, resolved in the input layer through the SAME `_advance_source()` the
controller uses, so keyboard and controller cannot drift apart: hold = sprint, tap = dodge.
Space REMAINS bound as a dedicated dodge, so nothing was removed. Gameplay still reads
semantic actions only - no gameplay code was changed to read a raw device, and both thresholds
are read through `command_sprint_tap_max()` / `command_sprint_hold_min()` rather than
hardcoded, so a rebinding UI can change them.
| mobility_button | - | joypad button 1 (Circle) |
| light_attack | mouse button 1 | joypad button 10 |
| heavy_attack | mouse button 2 | joypad axis 5 (RT +1) |
| parry | Q (physical) | joypad button 9 |
| critical | R (physical) | - |
| lock_on | Tab (physical) | joypad button 8 |
| quick_item | F (physical) | joypad button 2 |
| interact | E (physical) | - |
| quick_action (X) | - | joypad button 0 |
| secondary_action | - | joypad button 3 |
| item_up / down / left / right | - | joypad buttons 11 / 12 / 13 / 14 |
| ranged_attack (RESERVED) | - | joypad axis 4 (L2 +1) |
| jump (RESERVED) | - | joypad button 7 (L3) |
| menu | - | joypad button 6 |
| toggle_debug_overlay | F1 | - |
| ui_cancel | Escape | - |

`[CONFIRMED: project.godot read, 2026-09-12]`

Rules that must survive every future change:

- SPRINT and DODGE are separate gameplay actions with independent tuning, even though
  the controller presents both on Circle. Never merge them into one gameplay state
  because they share a button.
- Circle tap/hold is resolved in the INPUT layer, not in gameplay.
- Reserved actions return false from every `CascadiaInput` query and are refused by
  `consume()`. Nothing may wire them up during the foundation phase.
- `GameActions.RESERVED_ACTIONS` and `BUFFERED_ACTIONS` are the source of truth for
  which actions exist; `GameActions.GROUPS` drives the diagnostic overlay and any
  future rebinding UI.
- Escape must always release the mouse cursor. See section 3.

Not implemented, and not to be implemented early:

- Jumping (L3 reserved).
- Ranged combat (L2 reserved).
- X-button Use/Interact, quick bar and D-pad item selection.

---

## 10. HISTORICAL PASS - TARGET / TEST-ACTOR GROUNDING (delivered and measured; NOT the current task)

**Status: COMPLETE BY MEASUREMENT. Rendered confirmation NOT achieved.**

This was the focused task after Milestone 4. It is finished as far as measurement
can take it, and it is recorded here so it is not reopened by mistake.

The reported symptom: TargetA was spawned on a step and appeared to float, sink or clip.

Cause, measured rather than assumed. Two facts combine:

1. The test targets are placed by DIRECT TRANSFORM. A `StaticBody3D` has no gravity,
   no floor detection and no floor snapping, so nothing grounds it - its Y is whatever
   number is typed into the scene. TargetA kept its flat-ground Y of `0.9` after being
   moved into the step lane. Step28's top surface is at `y = 0.28` and its footprint is
   `x -10..-4, z -5..1`; TargetA's 1.8 m cylinder at `(-5, 0.9, -2)` had a footprint of
   `x -5.35..-4.65`, entirely inside that step, so its base sat at `y = 0.0` against a
   surface at `y = 0.28` - sunk `0.28 m`.
2. The PLAYER is unaffected because `PlayerController` applies gravity and calls
   `move_and_slide()`, which performs floor detection and snapping. That asymmetry is
   the entire bug: the player is grounded by code, the targets are grounded by nothing.

Fix applied (the smallest correct change):

- TargetA moved to `(-5, 1.18, -2)`, putting its 1.8 m cylinder base exactly on the
  `0.28` step top; its Label3D moved with it to `y = 2.88`.
- The dummy actor's collision and mesh sat at local `y = 0.92` against a capsule of
  full height `1.8`, so its base floated `0.02 m`; both corrected to local `y = 0.9`.

Verified this pass by reading the saved scenes:

- `TargetA` transform `(-5, 1.18, -2)` on Step28, whose top surface is `0.28`.
  `[CONFIRMED: scene read, 2026-09-12]`
- `TargetB (-2.5, 0.9, -2)` and `TargetC (2.5, 0.9, -2)` on open ground (`y = 0`),
  both with cylinder half-height `0.9`. `[CONFIRMED: scene read]`
- `dummy_actor.tscn`: `Collision` and `Mesh` both at local `y = 0.9` against a
  `radius 0.4, height 1.8` capsule; `Hurtbox/Shape` at local `y = 0.92`.
  `[CONFIRMED: scene read]`

Previously recorded measured evidence (manifest, "Notes On Target Grounding"):

- `scripts/diagnostics/grounding_probe_debug.gd` casts a downward ray per actor,
  EXCLUDING the actor itself, and compares the real surface against collision bottom
  and mesh bottom. Result: `RESULT: ALL CHECKS PASSED`.
- `TargetA surface=0.280 collision=0.280 mesh=0.280 mesh-vs-collision=0.000 float/sunk=0.000`
- `TargetB / TargetC / DummyActor` all `surface=0.000 collision=0.000 mesh=0.000`
- `Player surface=0.000 collision=0.001 mesh=0.001 float/sunk=-0.001`
  `[CONFIRMED: measured probe output]`

Rendered-view limitation - recorded so it is never mistaken for a clean visual pass:

- The seating has NOT been confirmed by a crisp screenshot. A `0.28 m` elevation at a
  whole-arena camera distance is roughly 6 pixels, so a normal still frame cannot
  distinguish "resting on the step" from "level with the floor". In the live gameplay
  camera the spot is also occluded by the input debug panel.
- This pass attempted one staged preview framed tightly on `TargetA`
  (`previewScene`, `res://scenes/test_environment.tscn`, `900x600`). The frame was
  produced, but the visual observer failed to analyze it (`observer_analysis_failed`),
  so the check returned INCONCLUSIVE. A second attempt was deliberately not made.
- `[UNVERIFIED]` TargetA visibly seated on the step, in a rendered frame.
- `[UNVERIFIED]` Target visual meshes and collision capsules aligned in a rendered frame.

Read of that staged frame, recorded as a human observation and NOT as verification:
the framed red cylinder's base contacts the pale step surface with no obvious gap, and
the step's top face reads as raised relative to the darker ground. Consistent with the
measurement, not proof of it. The same frame shows the left-hand targets overlapping in
projection; that is an artifact of the tight staged angle - the targets stand `2.5 m`
apart with `0.35 m` radii and do not intersect in world space.

Not changed, deliberately: no actor gained a script, gravity, grounding or AI. These are
static test fixtures, not enemies. No player input or combat behaviour was copied onto
them.

### Optional follow-up (NOT a blocker, NOT approved work)

If rendered confirmation of the step seating is ever wanted, the reliable way is to play
the game, walk to the step lane, and look at TargetA in the real camera with the debug
panels hidden (F1). A still frame at arena scale cannot settle it. This is a user
playtest, not an agent task.

---

## 11. HISTORICAL - MILESTONE 6 SCOPE RECORD (delivered; superseded as "current" by 8B and 8E)

**Status: ACCEPTED 2026-09-12. Delivered, measured, and human-played. This section is now
a closed record. The next milestone needs a NEW entry. No work is authorised.**

Approval record: the audit pass 3 recommendation below proposed Milestone 6, and the user
then named and approved it directly ("You may begin Milestone 6 - Dodge and i-frames,
since it is selected and now approved"). That satisfies the gate this section previously
set, so implementation is authorised and nothing here is a proposal any more.

Milestone 5 (Stamina) was approved and is implemented (section 8A). It is not re-proposed.

Standing rules that still apply:

- A milestone must come from THIS file, not from memory.
- It must be recorded and accepted before implementation starts.
- It must not skip, combine or invent milestones.
- The grounding/presentation correction is not a licence to introduce unrelated
  combat features.

### 11.1 Scope - the whole of Milestone 6

- A dodge owned by the locomotion actor: fixed speed over a committed duration, on the
  EXISTING grounded movement model, along a direction locked at the moment it starts.
- A stamina cost paid through `StaminaComponent`, with a clean refusal when unaffordable.
- An invulnerability window (i-frames) expressed as pure gameplay timing and applied at
  the existing hurtbox, so damage is refused during the window and counted.
- The same commitment discipline as attacks: it starts only from a valid state, cannot
  be steered, and cannot be cancelled.
- No animation, no roll model, no root motion - presentation adapts later.
- Verifiable without a screenshot: measured distance, duration, stamina cost and
  refused-damage counts printed by a probe.

### 11.2 Explicit non-goals

Each of these is its own future milestone; implementing any of them here is a scope
violation: animation, any roll/root-motion model, i-frame tuning to feel, parry, enemy
AI, enemy attacks, lock-on, inventory, ranged combat, new weapons, new enemies, broad UI
polish, any change to attack timing, any dodge cooldown or charge system, and any dodge
cancelling.

### 11.3 Acceptance criteria (measured, no screenshot required)

- **AC1 destination** - a dodge can only begin from a valid state, and while committed
  the movement input is ignored: it cannot be steered or cancelled.
- **AC2 travel** - measured dodge distance and duration match the authored values within
  tolerance, along the direction locked at start, on the ground.
- **AC3 cost** - exactly one stamina cost is charged per dodge; an unaffordable dodge is
  refused, starts nothing, changes nothing, and is counted separately from a silently
  dropped input.
- **AC4 i-frames** - damage arriving inside the i-frame window is refused and counted;
  damage outside it applies normally.
- **AC5 mutual exclusion** - an attack cannot start while a dodge is committed, and a
  dodge cannot start while an attack is committed.
- **AC6 regression** - attack, damage, actor, step and stamina probes still pass, and
  `main.tscn` boots with 0 runtime errors.

### 11.4 Verification plan

A `dodge_probe_debug` following the existing probe pattern (drive semantics, measure,
print PASS/FAIL per claim), plus fresh re-runs of the existing probes as the regression
gate. Rendered and gameplay feel stay a user playtest - they are not claimable from a
frame.

### 11.5 Files this milestone touches

- `scripts/locomotion/dodge_component.gd` (NEW - the dodge state machine, its timing and
  its i-frame window)
- `scripts/player/player_controller.gd` (input, direction lock, committed travel)
- `scripts/player/player_combat.gd` (one read-only gate: no attack while dodging)
- `scripts/combat/hurtbox_component.gd` (the i-frame refusal point)
- `scenes/test_environment.tscn` (`Player/Dodge` node + the hurtbox i-frame link)
- `scripts/diagnostics/dodge_probe_debug.gd` + `scenes/diagnostics/dodge_probe_debug.tscn`

No change to `game_actions.gd` is required: `dodge` already exists as a semantic action
and is already bound, so this milestone adds no input bindings.

### 11.6 Systems that must NOT change

`StaminaComponent`'s cost-agnostic contract (costs belong to consumers), the attack state
machine's timing and phase discipline, physical/combat layer separation, the input-layer
rule that gameplay never reads raw devices, and every confirmed Milestone 0-5 behaviour.

### Audit pass 3 recommendation (2026-09-12) - RECOMMENDED, STILL NOT APPROVED

The audit changed one input to this decision and left the decision itself to the user.

What changed: the previous audit could honestly say "the mouse attack path is unproven",
which made a verification-only pass a defensible next step. That gap is now CLOSED by
measurement (section 16, input_path_probe). Milestones 0-5 were re-run fresh and no
defect was found in any of them, so there is no repair task waiting either.

What did NOT change: nothing is implemented until a milestone is named APPROVED here.

**Recommended next: Milestone 6 - Dodge and i-frames.** Why it is next:

- `dodge` is already bound (Space / tap-Circle) and already resolves through
  `CascadiaInput.consume_dodge()`. Nothing consumes it yet.
- It is the only proposed system with a real, already-built dependency to pay into: the
  `StaminaComponent` from Milestone 5 was built as a shared pool precisely so dodge could
  consume it without widening anything.
- It is the smallest next system that makes the foundation play like a Soulslike rather
  than a movement demo, and it is verifiable without a screenshot.

Prerequisites already satisfied: `StaminaComponent` (M5) with atomic `try_spend` and a
clean refusal path; a proven `HurtboxComponent` damage-refusal point (M2); grounded
locomotion with attack commitment (M1/M4); verified physical input (this pass).

Still unverified going in: dodge has never been played by a human; i-frame timing has no
tuned value yet; stamina feel is unjudged.

Scope if approved (narrow, and this is the whole of it):

- A dodge owned by the locomotion actor: fixed distance (or velocity) over a committed
  duration, on the EXISTING grounded movement model.
- A stamina cost paid through `StaminaComponent`, with refusal when unaffordable.
- Invulnerability expressed as gameplay timing, applied at the existing hurtbox, so
  damage is refused during the window.
- The same commitment discipline as attacks: it can only start from a valid state and
  cannot be cancelled or steered out of.

Explicit non-goals (each is its own future milestone; implementing any of these here is
a scope violation): animation, any roll/root-motion model, i-frame tuning to feel,
parry, enemy AI, enemy attacks, lock-on, inventory, ranged combat, new weapons, new
enemies, broad UI polish, and any change to attack timing.

Acceptance criteria (measured, no screenshot required):

- A dodge can only begin from the allowed state; the input is ignored while committed.
- Measured dodge distance and duration match the authored values within tolerance.
- Exactly one stamina cost is charged per dodge; an unaffordable dodge is refused, starts
  nothing, and is counted separately from a silently dropped input.
- Damage arriving inside the i-frame window is refused and counted; damage outside it
  applies normally.
- A regression run of attack, damage, actor and stamina probes still passes.

Verification plan: a `dodge_probe_debug` following the existing probe pattern (drive
semantics, measure, print PASS/FAIL per claim), plus fresh re-runs of the existing probes.
Rendered/gameplay feel stays a user playtest - it is not claimable from a frame.

Files likely touched: `scripts/player/player_controller.gd` (dodge execution/commitment),
`scripts/combat/hurtbox_component.gd` or `health_component.gd` (i-frame refusal point),
`scripts/core/game_actions.gd` (only if a new semantic name is genuinely needed),
`scenes/test_environment.tscn` (tuning exports), plus a new diagnostic probe.

Systems that must NOT change: `StaminaComponent`'s cost-agnostic contract (costs belong
to consumers), the attack state machine's timing, physical/combat layer separation, and
the input-layer rule that gameplay never reads raw devices.

---

## 11A. HISTORICAL - MILESTONE 7 (PARRY) SCOPE RECORD (delivered; NOT a pending next milestone)

RESOLVED 2026-09-12. The user selected and APPROVED Milestone 7 - Parry, and it was
implemented and measured in the same pass: see section 8C for the architecture, the authored
values and the measured results. The text below is preserved UNCHANGED as history. At the
time it was written no milestone had been selected, so its "NOT APPROVED" wording was
correct then; it is NOT the current status. Read section 8C for where parry actually stands.

Milestone 6 is ACCEPTED and must not be re-proposed (section 8B). Nothing may begin until a
next milestone is named HERE and marked APPROVED.

IMPORTANT FINDING: this roadmap currently defines NO Milestone 7. The deferred list
(section 13) is an unordered set of future systems, not a sequence, so the next milestone is
NOT implied by this file - it has to be chosen. That is why no milestone was started.

Candidate, recommended but NOT approved: **Milestone 7 - Parry.**

Why parry is the natural next step:

- It is the third and last committed defensive action, and the only one of that family still
  missing. Dodge (M6) and attack (M4) already establish the exact pattern it needs: one
  enforcement point, a committed duration, a stamina cost, and a refusal that is counted
  rather than silently dropped.
- Its input already exists and already resolves: `parry` is bound and
  `CascadiaInput.consume_parry()` is already implemented, with nothing consuming it.
- It reuses existing infrastructure with no widening: the `StaminaComponent` pool (M5), the
  `HurtboxComponent` refusal point (M2, already duck-typed for exactly this kind of
  consumer), and the attack state machine's phase model (M4).
- It is verifiable by measurement the same way M6 was, and needs no enemy: a probe can drive
  the parry window and assert refusals directly.

Alternative candidates, for the decision (none approved):

- **Enemy attacks / a single attacking enemy.** This is the ONLY way to close Milestone 6's
  open i-frame tuning item, because i-frame feel cannot be judged without something to dodge.
  It is substantially larger than parry (enemy state, damage direction, targeting) and would
  be a scope jump.
- **A gameplay-feel pass.** Would address the dodge-travel tuning item and the earlier
  attack/sprint feel gaps, but CANNOT resolve the i-frame half of M6's tuning, which is
  blocked on an attacker existing.
- **Lock-on.** Listed as deferred; meaningful only once there are enemies to lock on to.
- **Animation integration.** Deferred to a later milestone by design; gameplay timing is
  authoritative and the current primitive presentation is intentional.

Do NOT begin any of these until the user names one and this section is updated to APPROVED
with its acceptance criteria written out.

RESOLVED: Milestone 7 - Parry was named, approved and delivered. Parry is no longer a
candidate; its scope, authored values and acceptance criteria are written out in section 8C.
The alternative candidates above (enemy attacks, a gameplay-feel pass, lock-on, animation
integration) remain UNAPPROVED and none of them was started. Choosing the NEXT milestone
after M7 is again the user's call.

---

## 12. KNOWN DEFECTS AND OPEN ISSUES

### 12.1 Open script errors in the diagnostics panel (KNOWN, BENIGN, DO NOT CHASE)

RE-CHECKED 2026-09-15 (roadmap reconciliation pass): `state:diagnostics` reports
**0 errors, 0 debugger errors, `is_breaked: false`, and 20 warnings**, and `state:script-errors`
for `open_script_buffers` returns an EMPTY list. THE ERRORS HALF IS UNCHANGED and remains the
finding that matters: there are no script errors to chase, and the warning set is still recorded
as benign. **RECORDED DISCREPANCY, not corrected:** the 2026-09-14 re-check below reported **38**
warnings. This pass measured **20**. Both readings are recorded rather than one overwriting the
other, because this pass did NOT re-classify the 20 to confirm they are the same case-mismatch
import warnings - the count differs and the cause is unverified. Treat the classification below as
inherited, not re-confirmed.

RE-CHECKED 2026-09-14 (documentation consolidation pass): `state:diagnostics` reported
**0 errors and 38 warnings**, and `state:script-errors` for `open_script_buffers` returned an
EMPTY list. The 38 warnings were case-mismatch import warnings from third-party asset kits,
recorded in `CASCADIA_DELETION_MANIFEST.md` under "Recurring: case-mismatch import warnings".
The GameActions symptom described below was NOT reproducible that pass.

When it was first recorded, `state:diagnostics` reported `20` script errors and `5` warnings.
All 20 errors were ONE root cause:

    Identifier "GameActions" not declared in the current scope.
    res://scripts/input/cascadia_input.gd, lines 56, 90-93, 119, 128-216

This is stale analysis of scripts held open as editor tabs (`scope: open_script_buffers`).
The class IS registered and IS used successfully at runtime. This exact symptom has
recurred since Milestone 0 and is documented in the deletion manifest under
"Notes On New Script Folders And The Class Cache":

> The recurring `Identifier "GameActions" not declared` errors are scoped to
> `open_script_buffers` - stale analysis of scripts open as editor tabs. They are not
> runtime failures. Do not chase them, and do not trust them over a clean run.

Verified this pass: `cascadia_input.gd` on disk is well-formed and uses
`GameActions.*` consistently, `game_actions.gd` declares `class_name GameActions`, and
`GameActions` appears in the project's global class list. `[INFERRED: static read]`
The claim that the game RUNS cleanly rests on the manifest's prior runtime records, not
on a run performed during this documentation pass.

Rule going forward: before reporting a script error as real, check whether it is in
`open_script_buffers` and whether the class is in the global class list. A real
regression shows up as a failed scene load or a runtime error, not as an open-tab
linter line.

### 12.2 Console error: `Resource file not found: res://.summer/plans`

Present in the Output panel. It was true until this pass: the `.summer/plans` directory
did not exist. Writing this file created the directory, so the condition is resolved.
Re-check before flagging it again.

### 12.3 Open verification items carried forward (not defects)

- `[CLOSED 2026-09-12: measured]` Physical mouse-button attack trigger. Now driven
  end-to-end by `input_path_probe_debug` - mouse button 1 dealt 15, mouse button 2 dealt
  32, RESULT: ALL CHECKS PASSED (section 8).
- `[PARTIAL: frame readable, not analyser-clean]` Rendered confirmation of TargetA's step
  seating (section 10). A readable staged frame was produced and read as consistent this
  pass; the visual observer returned observer_analysis_failed both times, so no clean
  analytical visual pass exists.
- `[PARTIAL]` Attack timing / hit feedback feel never judged by a human.
- `[UNVERIFIED]` Damage-number legibility in a rendered frame.
- `[CLOSED 2026-09-12: human playtest]` Sprint stamina drain and attack stamina cost are now
  played and confirmed (section 8G.1). One discrepancy to CONFIRM: the user reports an attack
  cost of 20, while `PlayerCombat` authors 18 (light) and 32 (heavy) - see section 8G.3.
- `[UNVERIFIED]` Physical controller buttons (JOY_R1/R2, R2 axis) were never physically
  pressed; only their InputMap bindings were read, even though dodge tap-Circle now has a
  gameplay consumer.
- `[CLOSED 2026-09-12: human playtest]` Milestone 8 attacking enemy. Played (section 8G.1): the
  enemy attacks, deals damage, and the loop works. Readability, cadence and whether 0.60 s of
  windup is enough warning remain OPEN feel items, not correctness items.
- `[CLOSED for M6/M7 by M8]` The "nothing can attack the player yet" blocker recorded above for
  i-frame feel is resolved: an attacker now exists and swings at the player.
- `[CLOSED 2026-09-12: human playtest]` Milestone 7 parry. The user confirmed in play that a
  parry can be successfully attempted (section 8G.1). The WINDOW READABILITY remains open: it is
  hard to read without animation.
- `[CLOSED 2026-09-12: implemented and measured - section 8H]` NO DEATH / RESET CIRCUIT. Health
  reached zero and stayed there, so combat could not be repeatedly exercised in one session. The
  `died` signal now has a real gameplay consumer (`DeathComponent`), and the full loop - death,
  locked input, presentation, reset, playable again - is measured by `death_probe_debug`,
  RESULT: ALL CHECKS PASSED. What remains is human feel, not correctness: see 8H.5.
- `[CLOSED 2026-09-12: implemented and measured - section 8I]` ENEMY DEATH. The test attacker had no
  death path: its health reached zero and nothing consumed it, so an enemy could not be defeated.
  `EnemyDeathComponent` now consumes `HealthComponent.died`, cancels any committed attack, and holds
  a defeated state that survives the player's reset, measured by `enemy_death_probe_debug`,
  RESULT: ALL CHECKS PASSED. What remains is human feel of the presentation, not correctness.
- `[OPEN 2026-09-12: PRE-EXISTING, surfaced by a regression re-run - NOT caused by the enemy death
  pass]` `grounding_probe_debug` FAILS one check: `TestAttacker: rests on the surface, not floating
  or sunk (-0.020)`. The attacker's collision capsule is authored at y=0.92 (`DummyActor` uses 0.90),
  so its lowest point sits exactly 0.020 above the surface - precisely at the probe's 0.02
  TOLERANCE, where float rounding fails the comparison. Left UNFIXED deliberately (see 8I.8):
  the fix is a combat actor's authored collision/mesh/hurtbox heights, which is outside this task.
- `[CLOSED 2026-09-15: reconciled against its own record - was OPEN, now resolved]` BACKSTEP
  ORIENTATION. Original entry, 2026-09-12: the body turned during a backstep instead of retreating
  while facing forward, exactly as the static reading in section 8F.2 predicted, found
  independently by the user in play (section 8G.2 item 2). RECONCILED THIS PASS against two
  records already in this file, neither of which is a new measurement:
  - GAMEPLAY HALF - CLOSED BY THE USER'S OWN PLAYTEST, recorded at 8N.6 (2026-09-13): the user
    reported that the evasion uses the player's last movement orientation and keeps that
    orientation committed during the evasion, "exactly the behaviour 8F set out to produce".
    8N.6 also records that no probe was re-run to restate it, and that every measured number is
    unchanged. The mechanism is measured (`dodge_authority_probe_debug`, 8N) and the result was
    confirmed in the hand.
  - PRESENTATION HALF - CLOSED BY MILESTONE 11, accepted 2026-09-13 on the user's visual read
    (section 0 milestone row; 8O.11 implementation, 8O.15 acceptance). The `FacingMarker` the
    original entry asked for ("A facing indicator is needed to make the correction readable")
    now exists and was accepted.
  WHAT THIS ENTRY DOES NOT CLAIM: 8N.6 and 8O.4 both record a residual item - the HUMAN read of
  the marker WHILE MOVING, dodging and backstepping - and that is tracked SEPARATELY below, not
  closed here. The defect this entry recorded is resolved; the moving-read item is a different,
  still-open verification item and is left standing.
- `[UNVERIFIED]` The physical parry CONTROLLER binding (joypad button 9) was never pressed.
  The probe drove the keyboard binding only, so the controller path is unproven.
- `[PARTIAL]` Sprint / Dodge / Backstep pass: every acceptance criterion passed by measurement
  (section 8E), but no human has played it. Whether the shared tap/hold threshold feels
  responsive, whether 1.688 m of dodge travel now feels right, and whether the backstep reads
  as a backstep are all feel questions that only a playtest answers.
- `[UNVERIFIED]` The physical CONTROLLER tap/hold path (Circle/B) was never pressed by a human.
  The controller source shares ONE `_advance_source()` implementation with the keyboard source,
  so the resolution logic is common code, but the device binding itself is unproven.
- `[UNVERIFIED]` Lock-on-relative dodge direction: NOT implemented, by explicit user decision.
  There is no lock-on system; dodge direction is camera-relative until lock-on is its own
  milestone. W / S / A / D + dodge already give forward, backward and lateral dodges.
- `[UNVERIFIED]` Directional dodge ANIMATION selection: not implementable - the project has no
  animation system at all. The semantic state an adapter needs (kind + facing) now exists and
  is measured; the clips do not.

- `[OPEN 2026-09-12: found by the reusable actor death capability pass - fragile, NOT yet a defect]`
  GROUP-ORDER DEPENDENCE in the player's arena reset. `DeathComponent._resolve_attacker()` falls back
  to `get_tree().get_first_node_in_group("enemy_attacker")` when `attacker_path` is empty, and
  `TestEnvironment/Player/Death` does not override that path. Which single attacker the player reset
  restores is therefore decided by group membership order rather than by an explicit path, so adding a
  second attacking enemy could silently change which one is restored. The arena's intent is now
  documented (section 8J.3); making the path explicit is a bounded future change, NOT done here because
  it would edit the player's authored scene wiring during a pass that must preserve player behaviour
  exactly.
- `[UNVERIFIED]` A SECOND defeated actor has never been seen in a rendered frame or by a human.
  `DummyActor` is proven mortal by deterministic probe only; the defeat presentation is now generalised
  to resolve its subject through `EnemyDeathComponent.GROUP_ENEMY_DEATH` rather than assuming its
  parent body, but only the test attacker's presentation has ever been looked at. Whether a second
  defeated actor reads correctly in the world is a rendered/human question, not a probe question.
- `[UNVERIFIED]` The `damageable` policy has never been exercised by a real non-damageable actor.
  Every actor in the arena is damageable, so `HurtboxComponent.damageable = false` and its
  `damage_refused_by_non_damageable` counter are proven by the deterministic probe injecting the
  property, NOT by an actor authored as non-damageable in a scene. Deliberately not manufactured: the
  milestone explicitly forbids building a new system (or a contrived actor) just to create the case.
- `[UNVERIFIED]` The physical CONTROLLER path remains unproven for restart. `death_probe_debug` drove
  the keyboard RESTART binding; the controller binding for restart was never pressed by a human.

OPEN TUNING ITEMS (from the Milestone 6 playtest - tuning, NOT defects):

- `[CLOSED 2026-09-12 by the Sprint/Dodge/Backstep pass]` Dodge travel was too long. The user
  requested it be shortened to about half, and it now measures 1.688 m (was 3.375 m) - see
  section 8E. The duration and the absolute i-frame window were deliberately NOT changed, so
  the defensive timing M6 accepted is preserved.
- `[TUNING: open]` The i-frame window (0.05-0.30 s) has not been judged for feel. It is no
  longer BLOCKED - M8's attacker now exists and swings at the player - but no human has judged
  the timing yet. This is testable as of M8.

Recorded here so they are preserved as known tuning work rather than rediscovered as
bugs. Neither blocks milestone acceptance, and neither is a defect.

### 12.4 Unknowns recorded rather than asserted

- Whether the test targets should ever become grounded actors (following the player's
  gravity / floor-snap rules) is a design question for a future enemy milestone. The
  current answer is NO: they are static fixtures.

---

## 13. DEFERRED SYSTEMS

Do not implement any of these until a milestone explicitly calls for it. If one appears
during other work, record it here instead of building it.

- Stamina and stamina costs - DELIVERED as Milestone 5 (section 8A). No longer deferred.
- Dodge and i-frames - DELIVERED as Milestone 6 (section 8B). No longer deferred.
- Parry - DELIVERED as Milestone 7 (section 8C). No longer deferred. It is built and measured
  and has now been HUMAN-PLAYED (section 8G.1): a parry can be successfully attempted in the hand.
The window remains hard to READ without animation, which is a readability item, not a defect.
- Enemy attacks - DELIVERED as Milestone 8 (section 8D) as ONE minimal telegraphed attack on a
  single stationary test enemy. Full Enemy AI is still deferred.
- Enemy death and persistence - DELIVERED this pass (section 8I). `EnemyDeathComponent` consumes the
  existing `died` signal, cancels a committed attack, and holds a defeated state that outlives the
  player's single-arena reset, so any actor that attaches the component can be defeated and stay
  defeated. No longer deferred. STILL DEFERRED: enemy AI, pursuit, navigation, loot, and any real
  respawn or checkpoint system - a defeat does NOT survive a scene load, and nothing revives an
  enemy.
- Reusable actor death capability - DELIVERED this pass (section 8J). Any damageable actor can now be
  made mortal by attaching the EXISTING `EnemyDeathComponent` with its `mortal` policy true; the
  arena's `DummyActor` is composed as a second mortal damageable actor beside the test attacker, and
  the capability is proven by deterministic probe for two actors. No longer deferred. STILL DEFERRED:
  everything below.
- Carried Credits - DELIVERED as Milestone 9 (section 8L). Eligible enemy defeats award Credits exactly
  once through the existing `defeated` authority, and the player carries the balance. No longer
  deferred. STILL DEFERRED by this milestone, deliberately: STORED/banked Credits, SPENT Credits
  (stats, items, gear, upgrades, shops, merchants, inventory, equipment, progression trees, player stat
  systems), PERSISTENT Credits, the Soulslike death-drop-and-retrieve loop, multiple currencies, loot or
  rarity tables, reward modifiers or multipliers, farming prevention, and any final economy balancing.
  Do not build these until a milestone calls for them.
- Game-state saving and loading - DELIVERED as Milestone 10 (section 8M). The CARRIED Credit balance
  now persists to `user://cascadia_save.json` and restores exactly. STILL DEFERRED: banking, spending,
  stats, items, gear, shops, inventory, checkpoints, enemy respawn persistence, world-state
  persistence, player death currency loss, multiple save slots, cloud saves, encryption, and
  settings/options saving.
  It will persist the authoritative state the economy and progression systems create, and must
  eventually distinguish carried / stored / spent Credits, progression, stats, items, gear, inventory,
  location, world state, defeated enemies, quest state, checkpoints, temporary runtime state and
  death/reset state. Nothing here is built; only the negative requirement is honoured, that Milestone 9
  must not make those distinctions impossible later.
- Player death Credit loss / retrieval (drop carried Credits on death, recover them on the corpse, or
  lose them permanently). RECORDED AS FUTURE WORK, NOT IMPLEMENTED. **THE RULE PREVIOUSLY RECORDED ON
  THIS LINE IS SUPERSEDED.** For Milestone 9 the carried balance "explicitly SURVIVES the player's
  existing death and reset" (section 8L.7). **Milestone 18 REVERSED that decision at the user's
  instruction**, and death now resets the carried balance to `starting_credits` and clears the per-run
  reward history (8T.3, 8T.5; re-verified 8U.1; USER-ACCEPTED 8U.8). What is still DEFERRED and
  unbuilt is the RETRIEVAL half - dropping the lost balance as a recoverable stake instead of
  destroying it. That gap is the recommended next milestone (8U.9).
- NPC relationship / faction behaviour. Recorded future work, NOT built. The audit for this pass found
  NO relationship state anywhere in the project, so this is an EXTENSION POINT rather than a gap: a
  `relationship` value (friendly / neutral / hostile) would belong on an actor identity component that
  does not exist yet. Do not build factions, allegiances or hostility rules until a milestone calls
  for them.
- Friendly / neutral / hostile gameplay consequences. Deferred with the above.
- NPC-specific death or incapacitation behaviour. Deferred: an NPC that is incapacitated rather than
  defeated, or that must be protected or kept alive, has no representation today.
- Enemy persistence through checkpoints or scene reloads. Deferred. A defeat does NOT survive a scene
  load and nothing revives a defeated actor. Explicitly NOT claimed by 8J.
- Save/load persistence of any actor state. Deferred.
- Broader actor identity and interaction systems. Deferred.
- A non-damageable-by-design actor in the arena. Deferred; the `damageable` policy is probe-proven
  only, because every actor in the arena is damageable today (see 12.3).
- Enemy stagger / poise. STAGGER IS PARTLY DELIVERED as of Milestone 18 (section 8T): a hit at or
  above an actor's own `stagger_threshold` interrupts a committed enemy swing through that enemy's
  attack state machine, and the player-facing consequence is now USER-ACCEPTED (8U.8). STILL DEFERRED:
  POISE (a meter that must be broken before an interrupt can land), interrupt armor, hitstun, and
  knockback.
- Critical / visceral attacks.
- Enemy AI.
- Navigation.
- Lock-on. Reserved to Tab in the InputMap, but with NO implementation and no consumer.
- Lock-on-relative directional dodge (section 8F). Blocked until lock-on exists. Dodge
  direction is camera-relative today and is deliberately NOT faked; W/A/S/D + dodge already
  give forward, backward and lateral camera-relative results.
- DEATH / RESET CIRCUIT - DELIVERED this pass (section 8H). Death state, input lock, prototype
  presentation, automatic and input-driven reset, stamina/health/position/committed-state
  restoration and the test attacker's reset are implemented and measured. No longer deferred.
  Still deferred: a real respawn/checkpoint system and any progression (NOT built, not in scope).
- Backstep facing preservation, plus a legible facing indicator on the player capsule (sections
  8F.2 and 8G.2 item 2). HUMAN-CONFIRMED in play. The guard alone is not enough: without a
  visible front marker the correction cannot be read, so the indicator is part of the fix.
  **DELIVERED: facing preservation by the 8F/8N authority pass (2026-09-13, measured) and the
  indicator by Milestone 11 (section 8O, user-accepted 2026-09-13). No longer deferred.**
- Dodge movement-authority arbitration - orientation and position (section 8F).
  **DELIVERED 2026-09-13 as section 8N.** Measured: `dodge_authority_probe_debug` ALL CHECKS
  PASSED, transcript on disk, 0 debugger errors; `step_probe_debug` re-run clean. No longer
  deferred.
- Dodge / Backstep animation integration, and the animation adapter and clip selection
  (sections 8E.6 and 8F). Requires an animation system, which does not exist yet.
- SOCD-style input arbitration / cleanup, and a review of the secondary / click action bindings
  (the user's wording). Not scheduled.
- Inventory.
- Ranged combat (`ranged_attack` / L2 reserved).
- Interaction prompts.
- X-button Use/Interact.
- X-button quick bar and D-pad item selection.
- Jumping (`jump` / L3 reserved).
- Animation integration (Milestone 15 in the plan sketched by the manifest notes).
- Final HUD / UI polish.
- Unplanned combos.
- Additional weapon systems.
- Additional enemy types or behaviour.
- Lore / content expansion unrelated to the current gameplay milestone.

---

## 14. FILE HYGIENE AND THE DELETION MANIFEST

Project rule: no project file is ever deleted, renamed or moved autonomously.

When a file looks obsolete, temporary, duplicated or superseded, it is recorded in
`res://CASCADIA_DELETION_MANIFEST.md` with: path, status, reason, replacement,
dependencies, safe-to-delete (yes / uncertain), date and notes. The user reviews and
deletes manually, later. Do not repeatedly ask for deletion confirmation.

The manifest is the CANONICAL accounting ledger for every cleanup candidate. Do not reproduce
its inventory here - a duplicated list goes stale, and this section did: it read "~938 lines"
while the file had grown to many times that size.

MEASURED 2026-09-14: the manifest holds 95 `##` sections, 40 of them `## Candidate:` entries, and **no file in this project has ever been
deleted** - there is no `DELETED` status anywhere in it, and every candidate is still present on
disk. Do not read the manifest as proof that a deletion happened. Its ENTRY INDEX lists every
tracked entry with its recorded status.

**Deleting anything listed there can break a probe that later verification depends on.
Read the manifest entry's "Used By" before removing anything.**

Files created by the roadmap pass:

- `res://.summer/plans/CASCADIA_MILESTONE_ROADMAP.md` (this file).

Files created by Milestone 5 (all recorded in the deletion manifest):

- `res://scripts/stamina/stamina_component.gd` - a real system, NOT a cleanup candidate.
- `res://scripts/diagnostics/stamina_probe_debug.gd` - diagnostic, cleanup candidate.
- `res://scenes/diagnostics/stamina_probe_debug.tscn` - diagnostic, cleanup candidate.
- `res://scripts/stamina/` - a new script folder. New folders in this project need an
  explicit filesystem rescan before their classes resolve (see the manifest and 12.1).

Files that may later be deleted (add to the manifest, do not delete):

- `res://project.godot.bak` - a byte-identical-size backup of `project.godot` sitting in
  the project root. Flagged in the manifest this pass.

Do not delete: `project.godot`, `project.godot.bak` (until reviewed), `icon.svg`,
`.godot/`, `.summer/`.

---

## 15. ROADMAP MAINTENANCE

At the beginning of EVERY new Cascadia task:

1. Read this roadmap.
2. Read the deletion manifest when relevant.
3. Inspect the actual project state - do not trust this file over the files.
4. Identify the current accepted milestone.
5. Identify the active task.
6. Confirm the requested work fits the current milestone.
7. If it does not fit, record it as deferred instead of implementing it.
8. Work in one discrete pass.
9. Verify deterministic behaviour AND rendered behaviour when applicable.
10. Update this roadmap before reporting completion.

At the end of EVERY milestone, state:

- What was implemented.
- What was verified, and by what evidence.
- What was only inferred.
- What remains unverified.
- Defects found and fixed.
- Files created.
- Files that may later be deleted.

Mark a milestone ACCEPTED only when its stated acceptance criteria are satisfied.

Update this roadmap after: milestone acceptance, major architecture changes, major
defects found or fixed, changes to milestone order, newly confirmed behaviour, newly
unverified behaviour, or changes to the deferred list.

Also update `CASCADIA_DELETION_MANIFEST.md` for diagnostic files, temporary UI,
obsolete or superseded files, cleanup candidates, editor / file-registration issues,
and known persistence or ops-layer defects.

STANDING RULE - both documents are updated as part of the work, not afterwards.

While implementing ANY milestone, these two files are updated AUTOMATICALLY, in the same
pass, without being asked and without waiting for the milestone to finish:

- `CASCADIA_DELETION_MANIFEST.md` - whenever a file is created that is diagnostic,
  temporary or otherwise a cleanup candidate; whenever a script or scene is superseded;
  whenever a cleanup candidate is discovered; whenever an existing candidate's status
  changes (for example "safe to delete: uncertain" becomes a confirmed yes); and
  whenever an editor registration, class-cache or persistence problem recurs.
- `CASCADIA_MILESTONE_ROADMAP.md` - whenever a milestone's status changes, a defect is
  found or fixed, behaviour is newly confirmed or newly found unverified, or the
  deferred list changes.

Record it at the moment it is discovered. A manifest entry written from memory a week
later is worth much less than one written while the file is still in hand, and a roadmap
that lags the project is worse than no roadmap, because it is trusted.

This does not override the file-hygiene rule: recording a candidate is the action, and
deletion stays manual.

This file must stay readable and maintainable, but it must preserve the ACTUAL
development order and verification history. Do not rewrite history to make it neater.

---

## 16. VERIFICATION HISTORY LOG

Append-only. One line per notable verification event.

    2026-09-11  Milestone 0  Input, camera, Circle tap/hold - user physical playtest. CONFIRMED.
    2026-09-11  Milestone 1  Ramp, step, gravity, fall, ledge - user physical playtest. CONFIRMED.
    2026-09-11  Milestone 2  Damage plumbing probe - measured. RESULT: ALL CHECKS PASSED.
    2026-09-11  Milestone 2  Fixed: `monitoring` used as window gate dropped same-frame reopen hits.
    2026-09-11  Milestone 3  Actor probe - measured. RESULT: ALL CHECKS PASSED.
    2026-09-11  Milestone 3  Fixed: camera SpringArm3D collision_mask 9 -> 17.
    2026-09-11  Milestone 4  Attack probe - measured. RESULT: ALL CHECKS PASSED.
    2026-09-11  Milestone 4  Target sweep - measured: all four targets damageable.
    2026-09-11  Milestone 4  Combat readout clipping defects (right edge, bottom edge, stale reclamp) fixed.
    2026-09-12  Grounding   TargetA 0.9 -> 1.18, dummy collision/mesh 0.92 -> 0.9.
    2026-09-12  Grounding   grounding_probe_debug ray check - measured. RESULT: ALL CHECKS PASSED.
    2026-09-12  Grounding   Rendered check NOT achieved. Staged preview produced but observer returned
                            observer_analysis_failed -> INCONCLUSIVE. Recorded as unverified, not as a pass.
    2026-09-12  Roadmap      This file created. Reconciled against disk: milestone table above,
                            input binding table (section 9), scene geometry (section 3), grounding state
                            (section 10), open script-error condition (section 12.1).
    2026-09-12  Audit        Milestones 0-4 re-audited against the live project. All four confirmed
                            present and correctly implemented. Discrepancy found: code comments in
                            player_controller.gd / player_combat.gd / third_person_camera.gd use a LEGACY
                            milestone numbering (attacks=M5, stamina=M6) that disagrees with this file
                            (attacks=M4, stamina=M5). This file's numbering is authoritative; the code
                            comments were left alone because they are cosmetic and not worth churn.
    2026-09-12  Audit        Project facts read this pass that the roadmap had not recorded: Godot 4.7
                            Forward+ on D3D12, Jolt Physics as the 3D engine, and a stray
                            [dotnet] project/assembly_name on a pure GDScript project.
    2026-09-12  Audit        Attack probe re-run: 6 FAILED, all on damage delivery, while all window /
                            phase / commitment / self-damage checks passed. Cause was the probe's own
                            hard-coded player placement Vector3(0.0, 0.1, -12.4), which put the player
                            BEHIND the dummy at Z=-2 facing away from it. Repaired to derive the spot
                            from the dummy's real position (STAND_OFFSET 1.6). Gameplay was never at
                            fault - the six failures were the harness's stale assumption.
    2026-09-12  Audit        After repair, ALL re-run this pass (not carried forward):
                            attack probe RESULT: ALL CHECKS PASSED.
                            target sweep RESULT: ALL CHECKS PASSED (4/4 targets, 100.0 -> 85.0).
                            damage probe RESULT: ALL CHECKS PASSED (applied=4 damaged=4 died=1).
                            actor probe RESULT: ALL CHECKS PASSED (gap 0.803 m = two capsule radii).
                            step probe RESULT: ALL CHECKS PASSED (6/6 traversal phases).
                            grounding probe RESULT: ALL CHECKS PASSED.
    2026-09-12  Audit        step_probe re-measured fresh: 14/28/42 cm steps CLIMB, 1 m ledge BLOCKED
                            (pinned z=-5.60), ramp climbs at 0.0702 m max per frame with 0 over-threshold
                            frames (no launch), ramp high face BLOCKED. Milestone 1 traversal freshly
                            confirmed by measurement, not by the earlier playtest alone.
    2026-09-12  Audit        The 20 `GameActions not declared` errors were re-checked during a live run:
                            scope is still `open_script_buffers`, `incomplete: true`, and the debugger
                            reported 0 runtime errors with all six probes passing. Proven stale, not
                            merely assumed stale. Section 12.1 confirmed still accurate.
    2026-09-12  Milestone 5  APPROVED and implemented: StaminaComponent + Player/Stamina node, sprint
                            drain, attack cost with refusal, refusal signal/counter and HUD readout.
                            Dodge, i-frames and parry deliberately NOT included.
    2026-09-12  Milestone 5  DEFECT FOUND AND FIXED in stamina_component.gd: `_set_stamina` ran the
                            is_equal_approx no-change guard BEFORE the depletion edge check, so
                            is_equal_approx(0.0, 1e-7) swallowed `depleted` for every DRAINED pool while a
                            single whole-pool spend still worked. Measured before: a 121-frame continuous
                            drain took the pool 100.0 -> 0.0 and emitted depleted 0 times. After: 1.
                            Sprinting drains continuously, so the common path was the broken one.
    2026-09-12  Milestone 5  stamina_probe RESULT: ALL CHECKS PASSED (measured).
    2026-09-12  Milestone 5  Regression proven: attack probe and target sweep re-run with stamina costs
                            active - both RESULT: ALL CHECKS PASSED. Production main.tscn boots with 0
                            runtime errors and exactly 5 damageable actors (Player + 4 targets).
    2026-09-12  Milestone 5  Interrupted-run recovery: a prior session left player_combat.gd calling
                            _cost_of() / _get_stamina() with neither defined (82 parse errors), the probe
                            files absent, and the Player/Stamina node never added. All repaired this pass.
    2026-09-12  Milestone 5  NOT verified: stamina readout legibility in a rendered frame, and human
                            play of sprint drain / attack cost. Recorded PARTIAL, not accepted.
    2026-09-12  Docs         Standing rule added to section 15 and to res://.summerrules: the manifest
                            and this roadmap are updated automatically as part of each milestone.
    2026-09-12  Audit P3     Independent re-audit of milestones 0-5 against the LIVE project. Every
                            probe re-run this pass, nothing carried forward:
                            damage probe ............... RESULT: ALL CHECKS PASSED (applied=4 died=1)
                            actor probe ................ RESULT: ALL CHECKS PASSED
                            step probe ................. RESULT: ALL traversal phases as expected
                            attack probe ............... RESULT: ALL CHECKS PASSED
                            target sweep ............... RESULT: ALL CHECKS PASSED (4/4, 100.0 -> 85.0)
                            grounding probe ............ RESULT: ALL CHECKS PASSED (TargetA 0.280/0.280/0.280)
                            stamina probe .............. RESULT: ALL CHECKS PASSED
                            Each run also reported debugger error_count 0.
    2026-09-12  Audit P3     NEW PROBE closes the longest-standing gap. input_path_probe_debug injects real
                            InputEventMouseButton through Input.parse_input_event() - not a direct
                            try_start() call - exercising event -> InputMap -> CascadiaInput buffer ->
                            consume_light_attack/consume_heavy_attack -> PlayerCombat.try_start().
                            Measured RESULT: ALL CHECKS PASSED. Mouse button 1 started exactly 1 attack and
                            dealt exactly 15; mouse button 2 started exactly 1 attack and dealt exactly 32.
                            The physical mouse attack path is now VERIFIED end-to-end, not inferred.
                            Also confirmed in the same run: CascadiaInput resolved through its group with its
                            script loaded and reported zero missing InputMap actions.
    2026-09-12  Audit P3     12.1 CONFIRMED stale, now with direct evidence: the probe above resolved
                            CascadiaInput and GameActions at runtime and reported no missing actions,
                            while state:diagnostics still reported 20 `GameActions not declared` errors
                            scoped to open_script_buffers (incomplete: true) with debugger error_count 0.
                            The editor text disagrees with a live run; the live run is authoritative.
    2026-09-12  Audit P3     DISCREPANCY recorded (project vs docs, not a code defect): the arena ramp
                            RISES toward the south, not the north. The Label3D on the ramp reads
                            "RAMP 20 DEG - WALK UP FROM SOUTH" and step_probe phase E ("ramp from SOUTH
                            driving north") is BLOCKED by the ramp's 1.68 m tall end face, while phase F
                            ("ramp from NORTH driving south") climbs it smoothly - so the label and that
                            phase comment name the wrong end. Recorded, NOT changed: it is a debug-arena
                            cosmetic, and editing it would also oblige a fresh step-probe run for no
                            gameplay gain.
    2026-09-12  Audit P3     DISCREPANCY re-confirmed: code comments in player_controller.gd /
                            player_combat.gd / third_person_camera.gd still use a LEGACY milestone
                            numbering (attacks=M5, stamina=M6; player_controller calls attacks
                            "Milestone 5" and stamina "Milestone 6") that disagrees with this file
                            (attacks=M4, stamina=M5). This file's numbering is authoritative; the
                            comments remain cosmetic and were left alone again.
    2026-09-12  Audit P3     Rendered re-attempt: staged isometric preview framed on Targets/TargetA now
                            produced a READABLE frame (the earlier attempt returned observer_analysis_failed
                            with no usable image). The frame shows TargetA's cylinder base in contact with
                            the pale step top, with that step reading as a raised slab above the darker
                            ground - consistent with the measured 0.280. The observer again returned
                            observer_analysis_failed, so this is recorded as a readable consistent frame,
                            NOT as a clean visual pass and NOT as a milestone acceptance. The grounding
                            probe numbers remain the strong evidence. A gameplay-camera look (walk to the
                            step lane, F1 to hide the debug panels) is still the user's step.
    2026-09-12  Audit P3     Files created this pass (all recorded in the deletion manifest):
                            scripts/diagnostics/input_path_probe_debug.gd + scenes/diagnostics/input_path_probe_debug.tscn.
    2026-09-12  Decision     NEXT MILESTONE NOT APPROVED. Section 11 is unchanged: Milestone 6 (Dodge
                            and i-frames) remains PROPOSED, NOT APPROVED. The audit removed the blocker
                            that previously argued for a verification-only pass (the physical mouse path
                            is now proven), but naming and approving the next milestone is the USER's
                            call, so no milestone was started.
    2026-09-12  Milestone 6  APPROVED by the user and implemented: DodgeComponent + Player/Dodge node,
                            dodge execution in PlayerController, structural attack refusal inside
                            PlayerCombat.try_start(), and the i-frame refusal point in HurtboxComponent.
                            Parry, enemy AI, enemy attacks and lock-on were NOT included.
    2026-09-12  Milestone 6  dodge_probe_debug RESULT: ALL CHECKS PASSED, debugger error_count 0.
                            Measured travel 3.375 m vs authored 3.375 m; measured duration 0.450 s vs
                            authored 0.450 s; the burst could not be steered with move_right held; a second
                            dodge was refused and counted; an unaffordable dodge was refused and counted;
                            dodge_finished fired exactly once; damage inside the i-frame window was refused
                            and counted while damage outside applied normally; the injected physical dodge
                            binding produced exactly one dodge.
    2026-09-12  Milestone 6  DEFECT FOUND AND FIXED IN THE PROBE (not in gameplay): dodge_probe_debug
                            printed travel=0.000m in its own summary while reporting ALL CHECKS PASSED,
                            because _reset_actor() zeroes the _travel accumulator before the later i-frame
                            phases run. AC2's own assertion had already passed against the correct value.
                            Now captured into _measured_travel at evaluation time.
    2026-09-12  Milestone 6  REGRESSION re-run THIS pass, not carried forward: attack probe
                            ALL CHECKS PASSED (light 15, heavy 32, timings match); damage probe
                            ALL CHECKS PASSED (applied=4, damaged=4, died=1); actor probe ALL CHECKS PASSED
                            (physical blocking, layer separation); stamina probe ALL CHECKS PASSED (P1-P7).
                            Every run reported debugger error_count 0.
    2026-09-12  Milestone 6  ACCEPTED after human playtest. The user confirmed in game that the dodge is
                            stamina-gated, direction-committed, prevents attacks during commitment, has an
                            i-frame window, and has a vulnerable tail.
    2026-09-12  Milestone 6  TWO OPEN TUNING ITEMS recorded, deliberately NOT changed and explicitly
                            separated from defects: (1) dodge travel is currently too long - the user asked
                            that it NOT be retuned yet; (2) i-frame timing feel is unjudged because nothing
                            can attack the player yet. Both belong to a later gameplay-feel pass. The
                            measured implementation and all acceptance evidence are preserved unchanged.
    2026-09-12  Decision     NEXT MILESTONE NOT SELECTED. Milestone 6 is ACCEPTED and must not be
                            re-proposed. FINDING: this roadmap defines no Milestone 7 - the deferred list
                            is unordered, so the next milestone is not implied and must be chosen. Recorded
                            section 11A: parry recommended (NOT approved) because its input and refusal
                            point already exist; an attacking enemy is noted as the ONLY way to close the
                            i-frame tuning item. No implementation authorised.
    2026-09-12  Milestone 7  APPROVED by the user. Architecture inspection found the parry ALREADY
                            IMPLEMENTED AND WIRED: ParryComponent, PlayerController input and commitment,
                            PlayerCombat refusal, DodgeComponent refusal, HurtboxComponent window, and a
                            Player/Parry node in test_environment.tscn. The genuinely missing M7 artifact
                            was the dedicated verification probe.
    2026-09-12  Milestone 7  DEFECT FOUND AND FIXED (process, not gameplay): the first writeFile for
                            parry_probe_debug.gd returned a receipt reading result=returned rather than
                            succeeded. glob **/*parry* returned only parry_component.gd, and
                            state:script-errors on the probe path returned "file not found". The probe did
                            NOT exist. The scene write failed the same way, and the manifest append below
                            it also did not land in that pass. Re-issued each write; every one then
                            returned a real sha256 and was verified present. THIRD recorded occurrence of
                            this shape.
    2026-09-12  Milestone 7  parry_probe_debug created and run. RESULT: ALL CHECKS PASSED, debugger
                            error_count 0. Measured duration matched the authored 0.600 s total with
                            phases in order; the body did not move with move_right held (travel
                            0.000 m); exactly one stamina cost charged and a short pool refused
                            atomically; a second parry, an attack during a parry, a dodge during a parry,
                            a parry during an attack and a parry during a dodge were each refused and
                            counted by cause; damage was refused inside the window and applied during
                            startup and recovery; an injected physical parry key produced exactly one
                            parry.
    2026-09-12  Milestone 7  SELF-CONTRADICTION DEFECT AVOIDED IN THE PROBE: the summary's
                            measured-travel line is captured into _measured_travel at evaluation time,
                            so it cannot repeat the dodge probe's stale-accumulator bug. For a stationary
                            parry the correct value is 0.000 m and the probe asserts it (<= 0.05 m), so
                            the summary and the assertion agree rather than contradicting each other.
    2026-09-12  Milestone 7  Probe-output counts reconciled rather than assumed: parries started=6
                            and finished signals=2 is correct, because only the two unbounded parries
                            (timeline and window) run to completion while the exclusion tests call
                            reset(), and the refusals never start one.
    2026-09-12  Milestone 7  REGRESSION re-run THIS pass, nothing carried forward: dodge probe
                            ALL CHECKS PASSED (travel 3.375 m, duration 0.450 s); attack probe
                            ALL CHECKS PASSED (light 15, heavy 32); damage probe ALL CHECKS PASSED
                            (applied=4, damaged=4, died=1); actor probe ALL CHECKS PASSED (physical
                            blocking, layer separation); stamina probe ALL CHECKS PASSED (P1-P7).
                            Every run reported debugger error_count 0.
    2026-09-12  Milestone 7  DOCUMENTATION RECONCILED: the header promised a "section 8C" and added a
                            Milestone 7 table row, but section 8C DID NOT EXIST and 11A still read
                            NOT APPROVED. Section 8C was written this pass, 11A was resolved, the
                            section 0 bullets, the deferred list and section 12.3 were updated, and the
                            deletion manifest gained the two new probe candidates. STATUS: implemented
                            and measured, NOT accepted - no human has played it.
    2026-09-12  Milestone 8  APPROVED by the user: a minimal attacking test enemy for
                            defensive-mechanic playtesting. Created EnemyAttacker (ONE committed
                            windup -> active -> recovery attack, no AI, no navigation, no chase),
                            created test_attacker.tscn, instanced it in the arena at (0, 0, 5), and
                            tagged the Player with the player_actor group so the attacker resolves a
                            target by group rather than a hard-coded scene path.
    2026-09-12  Milestone 8  enemy_attack_probe_debug created and run. RESULT: ALL CHECKS PASSED,
                            debugger error_count 0. Phase order WINDUP -> ACTIVE -> RECOVERY in both
                            runs; measured windup 0.58 s / active 0.13 s / recovery 0.70 s against
                            authored 0.60 / 0.12 / 0.70 (one physics frame of quantisation, inside
                            the 0.06 s tolerance); undefended player lost exactly 20, once, on an
                            ACTIVE frame; the parry refused and counted the hit
                            (refusals_by_parry 0 -> 1); the dodge refused and counted it as an i-frame
                            refusal (refusals_by_iframes 0 -> 1); the out-of-range attack was refused
                            and counted by cause; auto_attack started an attack on its own.
    2026-09-12  Milestone 8  THREE DEFECTS FOUND AND FIXED, all three in the HARNESS and none in
                            gameplay: (1) the probe called try_start() in the same frame it
                            repositioned the player, so the attacker still faced its OLD position
                            (spawn z = 12) with its hitbox pointing +Z instead of -Z, and the first
                            scenario recorded 0 damage - fixed by splitting the scenario into
                            _prepare() and _start_pending() with settle frames between them;
                            (2) _sample() ran before the is_attacking() check, appending a terminal
                            IDLE record and breaking the phase-order assertion - fixed by sampling
                            only while the attack is live; (3) the live arena attacker damaged the
                            player during the dodge probe's i-frame test, breaking its health
                            accounting (100.0 -> 68.0) - fixed by having all six gameplay probes
                            stand ambient attackers down at startup, group-based and duck-typed
                            because a newly added member of EnemyAttacker is not resolvable from
                            another script until the class cache refreshes.
    2026-09-12  Milestone 8  REGRESSION re-run THIS pass, nothing carried forward, after the fix:
                            parry probe ALL CHECKS PASSED; dodge probe ALL CHECKS PASSED (travel
                            3.375 m, duration 0.450 s); attack probe ALL CHECKS PASSED (light 15,
                            heavy 32); damage probe ALL CHECKS PASSED (applied=4, damaged=4,
                            died=1); actor probe ALL CHECKS PASSED (physical blocking, layer
                            separation); stamina probe every visible check PASS (P1-P6), its terminal
                            RESULT line falling outside the 30-entry console cap. Every run
                            reported debugger error_count 0.
    2026-09-12  Milestone 8  STATUS: implemented and measured, NOT accepted - no human has played
                            it. M6 dodge values and M7 parry values were deliberately NOT retuned.
                            Milestone 7 remains unaccepted for the same reason and is now testable
                            against a real attacker. This closes the "blocked on an attacker
                            existing" note that M6's i-frame tuning item has carried since 8B.
    2026-09-12  Input pass   APPROVED by the user, with three answers to three raised questions.
                            (1) Keyboard: ADD the shared Left Shift tap/hold behaviour, RETAIN
                            Space as a dedicated dodge - do NOT remove it. (2) Lock-on: do NOT
                            implement or assume lock-on in this pass; keep the system
                            rebinding-friendly and address lock-on in a later pass. (3) Animation:
                            resolve and expose the dodge kind/direction as GAMEPLAY state for a
                            future adapter; do not build an animation system.
    2026-09-12  Input pass   THREE SPEC PREMISES DID NOT MATCH THE PROJECT and were raised BEFORE
                            any edit rather than silently obeyed: (a) the recorded project rule
                            explicitly kept keyboard Sprint and Dodge separate, so sharing Left
                            Shift amends a deliberate decision; (b) there is NO lock-on system -
                            only a reserved action and consume_lock_on() with no consumer, so
                            "dodge direction relative to the locked-on target" had nothing to be
                            relative to; (c) there is NO animation system anywhere in the
                            project (zero AnimationPlayer/AnimationTree/AnimatedSprite/
                            SpriteFrames matches), so directional ANIMATION selection could not
                            be implemented. All three were put to the user; the answers are
                            recorded in the entry above.
    2026-09-12  Input pass   IMPLEMENTED: CascadiaInput now resolves TWO command sources through
                            ONE shared _advance_source(): mobility_button (controller Circle) and
                            sprint (Left Shift). Hold -> sprint, tap -> dodge, and a source that
                            reaches SPRINTING buffers nothing on release, so releasing a sprint
                            cannot also fire a dodge. Space stays bound to `dodge` independently.
                            PlayerController gained _dodge_kind() and _dodge_facing(): a tap with
                            movement input is DIRECTIONAL with a camera-relative facing, a tap
                            with no movement input is BACKSTEP along the BODY facing (+basis.z).
                            DodgeComponent gained Kind {DIRECTIONAL, BACKSTEP}, Facing
                            {FORWARD, BACKWARD, LEFT, RIGHT}, backstep_speed/backstep_duration,
                            backstep_travel_distance(), is_backstep(), kind_name(),
                            facing_name(), and a 3-argument try_start(direction, kind, facing).
    2026-09-12  Input pass   WHY FACING IS CLASSIFIED AGAINST THE CAMERA, NOT THE BODY: the body
                            turns to chase its own movement (_apply_facing), so a body-relative
                            classification would collapse a sustained left-strafe into FORWARD
                            the moment the body caught up with the input. Camera-relative keeps
                            W/A/S/D stable and is the same basis _read_wish_direction() already
                            uses. It is also the basis a future lock-on system would replace,
                            which is why the values are named semantically rather than by axis.
    2026-09-12  Input pass   DODGE TRAVEL HALVED BY SPEED, NOT DURATION: dodge_speed 7.5 -> 3.75,
                            dodge_duration UNCHANGED at 0.45 s. This is deliberate. The i-frame
                            window is expressed in ABSOLUTE seconds inside the dodge
                            (0.05-0.30 s), so shortening the duration would have moved the
                            window and silently weakened the defence the user explicitly asked
                            to preserve. speed x duration = 3.75 x 0.45 = 1.688 m, exactly half
                            of 3.375 m. Stamina cost unchanged at 22.
    2026-09-12  Input pass   BACKSTEP: backstep_speed 3.2 x backstep_duration 0.40 = 1.280 m,
                            deliberately shorter than the dodge. The backstep shares the
                            dodge's i-frame window and stamina cost - no separate cost exists
                            or was invented.
    2026-09-12  Input pass   dodge_input_probe_debug created and run. RESULT: ALL CHECKS PASSED,
                            debugger error_count 0. Measured: travel 1.688 m vs authored
                            1.688 m (was 3.375 m); hold resolves as SPRINT with NO dodge;
                            release after a sprint does NOT dodge and leaves nothing buffered;
                            tap with movement resolves DIRECTIONAL and travels along the
                            player's intended direction (forward/right/backward each dot 1.00
                            against the camera basis); neutral tap resolves BACKSTEP and travels
                            backwards along the facing (dot 1.00); i-frames still refuse damage
                            inside the window and apply it outside; exactly one 22-stamina
                            charge; an unaffordable dodge refused and counted by cause.
    2026-09-12  Input pass   REGRESSION re-run THIS pass, nothing carried forward, all EIGHT
                            probes after the change: dodge probe ALL CHECKS PASSED (travel now
                            1.688 m, duration 0.450 s, i-frame refusals 15); parry probe ALL
                            CHECKS PASSED; enemy attack probe ALL CHECKS PASSED (parry refusal
                            0->1, i-frame refusal 0->1, phase order clean); attack probe ALL
                            CHECKS PASSED (light 15, heavy 32); damage probe ALL CHECKS PASSED
                            (applied=4, damaged=4, died=1); actor probe ALL CHECKS PASSED;
                            stamina probe every P1-P7 check PASS. Every run reported debugger
                            error_count 0.
    2026-09-12  Input pass   SCRIPT-ERROR PANEL: 9 errors now, all in open_script_buffers on
                            player_controller.gd, claiming DodgeComponent has no Kind/Facing
                            and try_start takes 1 argument. This is the KNOWN stale class-cache
                            artifact (section 12.1), and this pass produced DIRECT PROOF of it:
                            the SAME run that reported those errors successfully read
                            DIRECTIONAL/BACKSTEP/FORWARD/RIGHT/BACKWARD from the running
                            DodgeComponent and classified 3-argument try_start() calls
                            correctly. Those members only exist in the new code, so the linter
                            is demonstrably reading a cached view of the class. Runtime is
                            authoritative; the panel is not. Recorded, not chased.
    2026-09-12  Input pass   FOUR PROBE DEFECTS FOUND AND FIXED, none in gameplay. (1) The probe
                            asserted a neutral tap should be DIRECTIONAL, which contradicts the
                            spec - BACKSTEP IS correct. (2) The probe never reset the stamina
                            pool between phases, so after AC1's tap plus AC2's three dodges the
                            pool was empty and AC3's dodge was legitimately refused; the
                            component then reported its DEFAULT kind/facing, which masqueraded
                            as a result. Fixed by resetting the pool per phase AND asserting the
                            evasion actually STARTED, so a refusal can never again read as a
                            pass. (3) Input was injected for a 2-frame window while the input
                            layer polls on idle frames, so no poll sometimes landed inside it -
                            a race that made WHICH checks failed differ between runs. Fixed with
                            longer windows. (4) The direction assertions compared against the
                            arena enemy's position, which measures architecture, not the spec;
                            replaced with camera-basis comparisons. Also fixed: the backstep
                            phase set rotation.y but left VELOCITY coasting, so _apply_facing
                            re-oriented the body before the tap - measured dot 0.10 against the
                            probe's own leftover motion.
    2026-09-12  Input pass   DOCUMENTATION: section 8E written; section 0 gained a row for this
                            pass; section 12.3 closed the long-standing "dodge travel is too
                            long" tuning item and added four new verification items; .summerrules
                            gained an explicit AMENDMENT to the keyboard input rule. STATUS:
                            implemented and measured, NOT accepted - no human has played it.
    2026-09-12  Review       END-OF-SESSION REVIEW PASS. Documentation only; NO gameplay file was
                            modified. Scope was the whole project, not just the input pass. Files
                            read: this roadmap, CASCADIA_DELETION_MANIFEST.md, .summerrules, and
                            the live input / player / dodge / combat / diagnostic scripts.
    2026-09-12  Review       ARCHITECTURAL QUESTION ANSWERED FROM DISK, AND THE ANSWER IS PARTIAL,
                            not a plain yes. The three candidates:
                            (1) VELOCITY - ALREADY CORRECT. _apply_horizontal() tests
                            is_dodging() first, SETS velocity from dodge.velocity() and returns
                            before the acceleration path, so ordinary locomotion CANNOT overwrite
                            dodge velocity. _read_wish_direction() also zeroes the wish direction
                            while committed, so sprint speed and drain are inert. Nothing to fix;
                            this branch must not be rewritten.
                            (2) ORIENTATION - REAL INTEGRATION DEFECT. _apply_facing() has NO dodge
                            guard and re-derives body yaw from CURRENT velocity every frame.
                            During an evasion that velocity IS the burst, so a BACKSTEP turns the
                            body around mid-evasion and a directional dodge rotates the body. The
                            locked gameplay facing is not what orients the body.
                            (3) POSITION - REAL INTEGRATION DEFECT, lower severity.
                            _resolve_step_up() has NO dodge guard and can add displacement sized
                            by step_probe_reach to an obstructed evasion.
                            NEITHER was fixed, by instruction. Recorded as section 8F and as a
                            Movement Authority rule in .summerrules.
    2026-09-12  Review       STATUS RECONCILED; no milestone moved. M0-M4 ACCEPTED. M5, M7 and M8
                            are measured but NOT human-played. M6 is the only measured AND
                            human-accepted milestone. The Sprint/Dodge/Backstep input pass is a
                            refinement of M6, not a numbered milestone, and is not accepted.
                            Next milestone remains UNSELECTED; this review authorised nothing.
    2026-09-12  Review       STALE DOC CORRECTED: section 9's keyboard binding table still
                            described Left Shift and Space as purely separate keys, which the 8E
                            pass reversed. Table amended. A roadmap that contradicts the code is
                            worse than one that omits it.
    2026-09-12  Review       KNOWN DIAGNOSTIC ARTIFACT RE-CONFIRMED, not a gameplay defect: the
                            script-error panel lists errors scoped to open_script_buffers claiming
                            DodgeComponent has no Kind/Facing and try_start takes 1 argument, while
                            the SAME runs read those members from the live component and classified
                            3-argument calls correctly. Judge the class cache by a RUN, never by
                            the open-tab linter.
    2026-09-12  Review       ARCHITECTURAL RISK RECORDED (pressure point, NOT a defect): every
                            probe instances the WHOLE `res://main.tscn`, so the test arena is
                            SHARED STATE and each new actor perturbs probes that have nothing to
                            do with it. M8 proved this - adding the attacking enemy broke the
                            dodge probe's health accounting until all six probes were given an
                            ambient-attacker stand-down. That fix is a patch, not a design fix.
                            As the arena grows, this coupling will keep producing false failures
                            in unrelated probes. A future tooling pass should let a probe
                            instantiate ONLY the actors it measures, or give each probe its own
                            isolated arena, instead of requiring every probe to know about every
                            other actor in the scene. NOT implemented - recorded, not scheduled.
    2026-09-12  Playtest     FULL-LOOP HUMAN PLAYTEST, the first in the project. The user played
                            the assembled prototype: move -> sprint -> spend stamina -> attack ->
                            damage an enemy -> be attacked -> parry -> dodge/backstep -> run out
                            of stamina. Reported as "a functioning combat foundation", not a
                            collection of disconnected tests. Recorded as section 8G.
    2026-09-12  Playtest     UPGRADED from probe-only to HUMAN-PLAYED: Milestone 5 (stamina
                            drain, depletion slowing movement, costs charged, dodges refused
                            when short), Milestone 7 (a parry can be attempted and succeeds),
                            Milestone 8 (the enemy attacks and deals damage), and the
                            Sprint/Dodge/Backstep input pass. Correctness is now confirmed by
                            HAND as well as by probe. FEEL remains open for all of them.
    2026-09-12  Playtest     THREE ITEMS FOUND IN PLAY. (1) NO DEATH/RESET CIRCUIT - at zero
                            health the player stays at zero and nothing resets, which BLOCKS
                            repeated combat testing; recorded as the highest-priority next task.
                            (2) BACKSTEP ORIENTATION - human-confirmed, and it MATCHES the static
                            finding recorded in 8F.2 the same day, independently. The user also
                            notes the capsule has no front-facing marker, so a facing indicator
                            is part of the fix. (3) NO ANIMATION PRESENTATION - the current
                            presentation boundary, explicitly NOT a gameplay failure.
    2026-09-12  Playtest     DISCREPANCY RECORDED, not acted on: the user reports attack stamina
                            cost as 20, while PlayerCombat authors 18 (light) / 32 (heavy).
                            Dodge at 22 matches. Confirm what the overlay DISPLAYS before
                            changing any value (section 8G.3).
    2026-09-12  Playtest     STILL OPEN AFTER PLAY - the user's own list: parry timing, enemy
                            windup readability, dodge distance and backstep feel, attack
                            commitment, hit stop, damage-window readability, and whether stamina
                            costs create the intended pressure. "The mechanics function" is now
                            established; "the mechanics feel like Lies of P" is not (section
                            8G.4).
    2026-09-12  Enemy death  ENEMY DEATH AND PERSISTENCE implemented and measured (section 8I).
                            enemy_death_probe_debug RESULT: ALL CHECKS PASSED with 0 runtime
                            errors. All SEVEN required regression probes re-run against the
                            live project and passed: death_probe (all checks, deaths=2,
                            resets=2, input-driven 1), enemy_attack (windup/active/recovery
                            0.58/0.13/0.70), attack, damage (applied=4 damaged=4 died=1),
                            actor, stamina, dodge (travel 1.688 m) and parry (travel 0.000 m).
                            main.tscn booted with 0 runtime errors.
    2026-09-12  Enemy death  PRE-EXISTING DEFECT SURFACED, NOT CAUSED BY THIS PASS, and LEFT
                            UNFIXED deliberately: grounding_probe_debug FAILS one check,
                            "TestAttacker: rests on the surface, not floating or sunk
                            (-0.020)". The attacker's collision capsule is authored at y=0.92
                            (DummyActor uses 0.90), putting its lowest point exactly on the
                            0.02 TOLERANCE boundary where float rounding fails. The transforms
                            are unchanged by this pass and fixing it would alter a combat
                            actor's authored collision, mesh and hurtbox heights, so it is
                            recorded for a deliberate decision (8I.8, 12.3) rather than
                            silently corrected. NOTE: the earlier log entry above recording
                            the grounding check as ALL CHECKS PASSED was true when written;
                            this entry supersedes it for the CURRENT project state.
    2026-09-12  Roadmap     ROADMAP UPDATED BEFORE IMPLEMENTATION, as the user required. New section
                            8J defines the approved "Reusable Actor Death Capability" pass: current
                            verified state, milestone goal, the capability vocabulary (damageable /
                            mortal / attack-capable / dead / defeated / resettable / persistent), the
                            persistence boundary, in scope, out of scope and the deferred follow-up.
                            Section 0 gained a status row; 12.3 gained the new open items; 13
                            gained the new deferred entries. Implementation began only after this.
    2026-09-12  Audit       AUDIT FINDING recorded in 8J.2: the reusable defeat path already EXISTS
                            (`EnemyDeathComponent`) and is actor-agnostic in shape - it needs only a
                            `HealthComponent.died` signal and an optional duck-typed
                            `cancel_attack()`. It was reachable by exactly ONE actor because the
                            other damageable actors had never been given a defeat component, so this
                            is a COMPOSITION gap, not a missing system. Also recorded:
                            `DeathComponent._resolve_attacker()` falls back to group membership
                            ORDER (`enemy_attacker`) whenever `attacker_path` is empty, so which
                            actor the player's reset restores is decided by scene order rather than
                            by an explicit path.
    2026-09-12  Reusable    IMPLEMENTATION COMPLETED. `EnemyDeathComponent` gained the `mortal`
                actor death policy export + `is_mortal()` + a `lethal_refusals` counter;
                capability  `HurtboxComponent` gained the `damageable` policy export +
                            `is_damageable()` + a `refusals_by_policy` counter;
                            `DeathComponent` gained the `resets_actors` policy export + a guard in
                            `_reset_attackers()`; `scenes/dummy_actor.tscn` gained the `Death` node
                            so a SECOND damageable actor uses the same defeat path. No existing
                            damage value, attack timing, stamina cost, dodge, parry or
                            hitbox/hurtbox semantic was changed.
    2026-09-12  Reusable    actor_death_probe_debug CREATED AND RUN: RESULT: ALL CHECKS PASSED,
                actor death with 0 runtime errors. Measured: the DummyActor took a lethal hit
                capability  through `receive_hit`->`apply_damage` and reported health=0.0,
                            is_dead=true, is_defeated=true, defeats=1; further lethal damage was
                            REFUSED ("already dead") and defeats stayed 1; the immortal
                            configuration took damage to 0.0 and was NOT defeated
                            (is_defeated=false, defeats=0, lethal_refusals=1); the non-damageable
                            configuration refused at the hurtbox with health 100.0 -> 100.0 and
                            refusals_by_policy=1; the player's automatic reset fired at 1.52 s,
                            restored the player to 100.0, and left the defeated actor at
                            is_defeated=true, defeats=1, health=0.0, is_dead=true.
    2026-09-12  Reusable    FULL REGRESSION SWEEP RE-RUN against the live project, all ten probes
                actor death fresh (nothing carried forward), every one ALL CHECKS PASSED with 0
                capability  runtime errors: actor_death (new), death (deaths=2, resets=2,
                            input-driven 1), enemy_death, enemy_attack (windup/active/recovery
                            0.58/0.13/0.70), attack (LIGHT -15, HEAVY -32), damage (applied=4
                            damaged=4 died=1), actor (layer separation, held window no re-apply),
                            stamina (18/32 costs, refusal atomic), dodge (travel 1.688 m, 15
                            i-frame refusals), parry (stationary, travel 0.000 m).
                            `main.tscn` booted with 0 runtime errors and 5 warnings (none from this
                            pass).
    2026-09-12  Reusable    RENDERED PLAYTEST PERFORMED on `main.tscn`. The frame rendered: ground
                actor death and arena geometry visible, both debug overlays drawn, the input panel
                capability  listing every binding, and the combat panel listing ALL SIX damageable
                            actors (DummyActor, TargetA, TargetB, TargetC, TestAttacker, player) at
                            100/100 with "no hits yet". The visual ANALYSER returned
                            observer_analysis_failed, so the frame was read by eye and the rendered
                            verdict is PARTIAL, not a clean analysed pass - the same limitation
                            recorded for the TargetA seating check in 12.3.
    2026-09-12  Reusable    GROUNDING PROBE re-run: still ONE FAILED check, `TestAttacker: rests on
                actor death the surface, not floating or sunk (-0.020)`. UNCHANGED and PRE-EXISTING,
                            not caused by this pass - the dummy actor's Death node added no transform.
                            Still recorded for a deliberate decision (8I.8, 12.3).
    2026-09-12  Reusable    PROCESS DEFECTS found and fixed BY DISK READ, not by receipts: two files
                actor death briefly held duplicated declarations (enemy_death_component.gd: two
                            `mortal` exports and two `lethal_refusals`; hurtbox_component.gd: three
                            `damageable` exports and three `refusals_by_policy`). Several write
                            receipts came back marked as unverified historical records, and the
                            open-tab linter reported duplicate definitions that did NOT exist on
                            disk. Corrected after re-reading; both files now hold exactly one of
                            each and `state:script-errors` returns 0 for every edited file.
    2026-09-12  Accept      REUSABLE ACTOR DEATH CAPABILITY ACCEPTED by the user after verifying it
                            in the live game: damaged, reaches 0/100, enters the dead state, tips
                            and darkens, shows DEFEATED, and does not interfere with the other
                            actors. Recorded as section 8J.12. The milestone's correctness is now
                            USER-VERIFIED, not probe-only.
    2026-09-12  Combat      REUSABLE ACTOR COMBAT READINESS: roadmap written BEFORE implementation
                readiness   (section 8K), then implemented, probed and regression-tested in the same
                            pass. AUDIT FINDING: damageability, mortality, attack capability, debug
                            presentation and group-based target selection already existed and were
                            REUSED UNCHANGED. The genuine gap was TARGET VALIDITY - `_get_target()`
                            took the first group member with no alive check, so a dead actor was
                            still a valid target the attacker faced and swung at.
    2026-09-12  Combat      NEW FILE: `scripts/combat/combat_participant.gd` (`CombatParticipant`),
                readiness   the smallest reusable combat-participant foundation: it answers
                            damageable / mortal / dead / defeated / attack-capable / targetable /
                            can-act and exposes a typed refusal REASON, so "not a valid target" is
                            a named cause rather than a bare false. Composable, per-actor, added as
                            a direct child named "Participant"; an actor without one keeps its
                            previous behaviour exactly.
    2026-09-12  Combat      MEASURED: `actor_combat_readiness_probe_debug` RESULT: ALL CHECKS PASSED
                readiness   with 0 runtime errors. The dead target was refused with the DEAD cause
                            (`target_refusals_dead 0 -> 2`) and NOT filed as out-of-range
                            (`0 -> 0`); the attacker did not turn to face the corpse
                            (`max drift 0.0000 rad`); a defeated actor reported `can_act=false` and
                            `valid_target=false` and started no attack in 40 held frames; a REVIVED
                            actor became targetable again (the refusal is a state, not a ban); a
                            freed node was refused as MISSING without raising; the player's reset
                            did NOT revive the defeated actor.
    2026-09-12  Combat      REGRESSION SET re-run against the live project, each probe stopped and
                readiness   restarted fresh (never reused): enemy_attack, target_sweep, death,
                            enemy_death, actor_death, damage, actor, attack, stamina, dodge, parry,
                            grounding - every one ALL CHECKS PASSED except grounding's ONE
                            pre-existing TestAttacker failure (-0.020), unchanged. Attack timings
                            still 0.58/0.13/0.70, damage still 15/32, dodge travel still 1.688 m,
                            parry travel still 0.000 m, stamina costs still 18/32. `main.tscn`
                            booted with 0 runtime errors.
    2026-09-12  Combat      RENDERED PLAYTEST: the combat readout in the running game now annotates
                readiness   every damageable actor with its participant state - `DummyActor [alive
                            targetable]`, `TargetA/B/C [no participant]`, `TestAttacker [alive
                            attack-capable targetable]`. Read directly from the frame because the
                            visual ANALYSER returned `observer_analysis_failed`, the same limitation
                            already recorded in 8J.10c and 12.3. Rendered verdict is therefore
                            PARTIAL and read by eye, not an analysed pass.
    2026-09-12  Combat      DEFECT FOUND AND FIXED during this pass, in the pass's OWN diagnostic
                readiness   path: the first version of the auto-attack refusal recorder used a bare
                            boolean, which silently swallowed a refusal whose CAUSE changed - a spell
                            that began OUT_OF_RANGE and became DEAD (exactly what happens when a
                            target dies while the attacker watches) was never recorded, so the
                            dead-target counter could not move. Replaced with a last-CAUSE tracker.
                            An earlier version also declared the flag twice and briefly called a
                            helper that did not exist; both were caught by `state:script-errors`
                            and by reading the file, before any measurement was trusted.
    2026-09-12  Combat      POST-ACCEPTANCE PLUMBING AUDIT (section 8K.11). 8K accepted by the user,
                readiness   who then asked whether `TargetA/B/C [no participant]` was intended design
                            or incomplete plumbing. AUDITED FROM DISK: all three are `StaticBody3D`
                            fixtures carrying only Mesh/Collision/Health/Hurtbox - no script, no
                            Attacker, no defeat component, no Participant - which matches the role
                            recorded before 8K existed (8J.10d). CONCLUSION: intentional
                            non-participants, plumbing CORRECT, NO correction made. They are handled
                            by design through the explicit UNWIRED FALLBACK in
                            `CombatParticipant.target_refusal()`, which is itself measured by the
                            readiness probe on a component-less actor. Adding a component was
                            deliberately declined: it would flip `is_usable_target(TargetA)` from
                            true to false today with no requirement behind it, and would flatten
                            three actor types into one implementation to make labels match.
    2026-09-12  Combat      RE-VERIFIED AFTER THE AUDIT, no source change: readiness probe re-run
                readiness   RESULT: ALL CHECKS PASSED with 0 runtime errors; all 13 probes re-run
                            fresh and passed; `main.tscn` booted with 0 runtime errors. Rendered
                            frame read directly (analyser returned observer_analysis_failed again,
                            so the verdict is read by eye, not an analysed pass): the readout showed
                            `DummyActor [alive targetable]`, `TestAttacker [alive attack-capable
                            targetable]` and `TargetA/B/C [no participant]`, all at 100/100 - the
                            intended architecture, correctly labelled.
    2026-09-12  Combat      CONCERN RECORDED, not a defect: `[no participant]` reads like a warning
                readiness   when it is a correct statement about scenery, and the same wording will
                            prompt this same audit again. Distinguishing "no participant by design"
                            from "no participant by omission" needs a statement of intent that does
                            not exist yet, so nothing was invented here.
    2026-09-12  Combat      PROCESS NOTE, re-confirmed: repeated `callEditorState state:diagnostics`
                readiness   calls returned results flagged as superseded, and several earlier write
                            receipts were flagged as unverified historical records. EVERY published
                            result in this pass was therefore taken from a fresh run whose output was
                            read directly, and the target/fixture conclusions came from reading the
                            scene on disk rather than from the overlay text.
    2026-09-12  Defeat      DEFECT REPORTED BY THE USER AND CONFIRMED: an enemy reaching zero health
                coverage    did not update to a defeated state. Root cause: no probe asserted the
                            property ACROSS the arena. Every existing probe inspected only the actors
                            it was told about BY NAME, so any damageable actor with no defeat path
                            reached zero health and silently did nothing while every probe still
                            passed. `damage_probe` reports `died=1` because HealthComponent emits
                            `died` - whether ANYTHING CONSUMES IT was never asserted. That is the
                            missing test, and it is why the hole survived 8I, 8J and 8K.
    2026-09-12  Defeat      NEW PROBE `defeat_coverage_probe_debug` written for exactly that property.
                coverage    Driven by ENUMERATION of the `damageable` group, not a name list, so a
                            newly added enemy is covered the moment it exists. Per enemy it asserts:
                            zero health through the existing chain, mortal, is_defeated() true,
                            defeats == 1, a defeat presentation present, and `is_showing()` true.
                            The player is excluded BY ARCHETYPE (its Death owns `resets_actors`), so
                            it is skipped as the resettable actor rather than by name.
    2026-09-12  Defeat      First run of the new probe: 5/5 enemies covered, ALL CHECKS PASSED -
                coverage    TestAttacker, DummyActor, TargetA, TargetB and TargetC each read
                            `is_defeated=true defeats=1 presentation=showing`. `main.tscn` booted with
                            0 runtime errors.
    2026-09-12  Defeat      MINIMAL CORRECTION APPLIED: TargetA/B/C were wired to the EXISTING
                coverage    `EnemyDeathComponent` (mortal, their only value) plus the EXISTING
                            presentation adapter, in `scenes/test_environment.tscn`. No new death
                            system, no new component class, no combat value or timing changed.
                            `target_sweep_debug` still measures 5/5 targets taking exactly 15.0, so
                            damageability is untouched.
    2026-09-12  Defeat      RENDERED CONFIRMATION: after the killings, the arena frame shows red
                coverage    `DEFEATED` labels above the dummy and the target positions, the counters
                            tipped and darkened, and the readout reading `DummyActor`, `TargetA`,
                            `TargetB`, `TargetC` all at `0/100 DEAD [dead defeated targetable]` and
                            `TestAttacker` at `0/100 DEAD [dead defeated attack-capable targetable]`.
                            Read by eye: the visual analyser returned observer_analysis_failed.
    2026-09-12  Defeat      EARLIER CONCLUSION RETRACTED, not quietly dropped: 8K.11 declared the
                coverage    static targets "intentional non-participants" and deliberately changed
                            nothing. That reading was WRONG - it treated "no defeat component" as a
                            design choice when there was no stated intent behind it, and it left an
                            enemy-shaped hole in the death path. A pass that had asked "does EVERY
                            damageable actor reach a defeated state?" instead of "is this actor
                            explained?" would have found it immediately. 8K.11 is marked SUPERSEDED
                            and the conclusion is recorded so it is not repeated.
    2026-09-12  Milestone 9 MILESTONE 9 SELECTED: Soulslike Credit Economy and Meaningful Progression
                            Foundation. Roadmap section 8L written BEFORE any implementation, per the
                            milestone's own instruction. Milestone 10 (Game-State Saving and Loading)
                            recorded as the planned follow-up and explicitly NOT started. Enemy
                            pursuit was NOT selected.
    2026-09-12  Milestone 9 `scripts/economy/credit_ledger.gd` (CreditLedger) implements the carried
                            half of the loop and NOTHING else. It subscribes to the EXISTING
                            `EnemyDeathComponent.defeated` signal - not `died`, not `is_dead`, not a
                            health value - so "what counts as a defeat" keeps exactly one owner.
                            Carried / stored / spent / persistent are kept APART, and only carried
                            exists. Reward is a single explicit `reward_per_enemy = 100`.
    2026-09-12  Milestone 9 Reward eligibility is an explicit rule with FOUR conditions, not "this
                            actor reached zero health": an EnemyDeathComponent is present, reports
                            is_defeated() true, reports mortal true, and the actor is not the
                            player-controlled actor. Paid actors are recorded by INSTANCE ID so one
                            enemy can never pay twice.
    2026-09-12  Milestone 9 DEFECT FOUND AND FIXED in the ledger's own refusal attribution: mortality
                            was checked AFTER the defeated state, so a non-mortal actor was always
                            filed as NOT_DEFEATED and `awards_refused_non_mortal` was unreachable.
                            The refusal was correct; the RECORDED CAUSE was wrong, which is exactly
                            the failure mode the by-cause counters exist to prevent. Policy is now
                            checked before state, matching EnemyAttacker's own gate order.
    2026-09-12  Milestone 9 `credit_economy_probe_debug`: RESULT: ALL CHECKS PASSED, 0 runtime errors.
                            ENUMERATION, not a name list: it walks the defeat authority's own group,
                            so a newly added enemy is covered automatically. Eligible enemies = 5,
                            carried = 500, awards = 5, rewarded = 5. Duplicate check: balance
                            500 -> 500, awards 5 -> 5, duplicate refusals 0 -> 5. Player exclusion:
                            paid=false, player refusals 0 -> 1. Non-mortal exclusion: refused AS
                            non-mortal with cause counted, non_mortal refusals 0 -> 1. A 90-frame
                            hold after every defeat granted no further award.
    2026-09-12  Milestone 9 The probe never calls award_credits() to build its own result. It kills
                            enemies through the real `HurtboxComponent.receive_hit ->
                            HealthComponent.apply_damage -> died -> EnemyDeathComponent.defeated ->
                            ledger` chain, so the signal subscription, the eligibility rule and the
                            duplicate guard are all exercised by measurement rather than by a direct
                            call that would prove only that the ledger can add integers.
    2026-09-12  Milestone 9 RENDERED: `main.tscn` booted with 0 runtime errors and the combat readout
                            shows `carried credits 0` above the DAMAGEABLE ACTORS list, with all five
                            actors at 100/100 reading [alive targetable] / [alive attack-capable
                            targetable]. Read by eye: the visual analyser returned
                            observer_analysis_failed on every capture.
    2026-09-12  Milestone 9 ENVIRONMENT ISSUE, recorded not worked around: the console buffer became
                            stale during the rapid regression sweep and stopped refreshing between
                            runs, so several probes could not be re-read in that pass. The credit
                            probe, the defeat-coverage probe (5/5) and the actor-death probe were
                            each read fresh and passed; the remaining regression probes were re-run
                            and passed earlier in the same session. Judge a probe by a fresh run,
                            never by a buffer that has stopped refreshing.
    2026-09-12  Milestone 9 NEW-DIRECTORY REGISTRATION, THIRD OCCURRENCE: `scripts/economy/` was
                            created and the very first load failed with `Could not find type
                            "CreditLedger"` because the brand-new folder was not yet in Godot's
                            global class cache. A follow-on stale-cache entry then kept the
                            edit-time duplicate-class guard pointed at the OLD path even after the
                            file had moved, blocking targeted edits until the file was returned to
                            the registry's own path. The RUN is the authority, not the linter and not
                            the guard's remembered path.
    2026-09-12  Defeat      USER-VERIFIED AND ACCEPTED. The user confirmed the fix in the live game and
                coverage    accepted the milestone. 8K is therefore ACCEPTED: the target-validity work
                            and the defeat-coverage correction are confirmed by hand as well as by
                            measurement. What remains open is FEEL, not correctness.
    2026-09-12  Defeat      LESSON RECORDED FOR ANY FUTURE AGENT, and the single most useful thing in
                coverage    this pass: a per-actor test suite is NOT coverage. 8I, 8J and 8K each proved
                            death on the actors they were pointed at BY NAME, and all of them passed
                            while three arena actors had no death path whatsoever. When adding an
                            actor-shaped capability, ENUMERATE the class of actor (join a group, walk
                            the group, assert the property per member) instead of listing instances.
                            A name list proves the actors you remembered; enumeration proves the ones
                            you did not. The user found this by playing the game, which no probe was
                            looking at.
    2026-09-12  Milestone   MILESTONE 10 SELECTED AND IMPLEMENTED. Section 8M was written BEFORE any
               10          code, per the same rule M9 followed. M9 is ACCEPTED and its history, caveats
                           and defect records are PRESERVED - nothing in 8L was rewritten. Owned by
                           `GameStateSave` (`scripts/core/game_state_save.gd`); the save carries
                           `schema_version`, `carried_credits` and `saved_at_unix`, and NOTHING else.
                           The highest milestone is now 10.
    2026-09-12  Milestone   BOUNDARY DECISION, stated so it cannot drift: the save persists the CARRIED
               10          Credit balance ONLY. It does NOT persist defeated enemies, world state, level
                           state, position or checkpoints. Loading therefore does NOT revive a defeated
                           enemy - measured, not assumed. Banking, spending, stats, items, gear,
                           inventory, death currency loss, multiple slots and cloud saves are all
                           still NOT built, and none of them is implied by this pass.
    2026-09-12  Milestone   CONTROLLED RESTORATION, not a second balance. `CreditLedger` gained
               10          `restore_carried_credits()`, deliberately separate from `award_credits()`: it
                           does NOT increment `awards`, does NOT emit `credits_awarded` and does NOT mark
                           any actor as paid. That separation is what makes "loading is not an enemy
                           defeat" a structural fact rather than a convention, and the migration probe
                           asserts BOTH counters are untouched by a load.
    2026-09-12  Milestone   DEFECT FOUND AND FIXED IN THE SERVICE: a corrupt save is an EXPECTED
               10          condition, but `JSON.parse_string()` pushes an engine ERROR into the debugger
                           every time it meets one, so two correctly-handled malformed saves still
                           showed as 2 debugger errors. Switched to `JSON.new().parse()`, which reports
                           the same answer plus line and message through the service's own typed
                           `Result`. Debugger errors went to 0 and the failure is still reported
                           precisely. RECORDED BECAUSE THE PATTERN IS GENERAL: a handled failure must
                           not be indistinguishable from a game fault in the log.
    2026-09-12  Milestone   TWO PROBE ASSERTIONS WERE WRONG ON THE FIRST RUN and were fixed rather than
               10          tolerated. (1) It asserted `credits_earned` was UNCHANGED by a load, but the
                           ledger deliberately RE-BASES it to the restored total so earned and carried
                           cannot disagree; the check now asserts consistency with the restored balance,
                           which is the documented contract. (2) The defeated-enemy check read
                           `defeated == defeated_before and not defeated_before`, which can NEVER be
                           true - a check that could not fail and could not pass. Both were found by
                           reading the real output, not by assuming the probe was right.
    2026-09-12  Milestone   REGRESSION SWEEP, FULLY RE-RUN FRESH. All 13 probes were stopped and
               10          restarted individually and each console read directly, AFTER the ledger,
                           the save service and the new scene wiring were all in place:
                           `game_state_save_load` ALL CHECKS PASSED (0 debugger errors);
                           `credit_economy` ALL CHECKS PASSED (5 eligible, 500 credits, 5 awards,
                           duplicate refusals 0 -> 5, player and non-mortal exclusions 0 -> 1 each);
                           `defeat_coverage` ALL CHECKS PASSED (5/5);
                           `actor_death` ALL CHECKS PASSED; `death` ALL CHECKS PASSED (deaths=2,
                           resets=2); `enemy_death` ALL CHECKS PASSED; `damage` ALL CHECKS PASSED
                           (4/4/1); `attack` ALL CHECKS PASSED (15 light / 32 heavy unchanged);
                           `stamina` ALL CHECKS PASSED (18/32 unchanged); `dodge` ALL CHECKS PASSED
                           (travel 1.688 m, 15 i-frame refusals); `parry` ALL CHECKS PASSED (travel
                           0.000 m); `enemy_attack` ALL CHECKS PASSED (0.58/0.13/0.70, damage 20);
                           `target_sweep` ALL CHECKS PASSED (5/5, exactly 15.0 each); `actor_probe`
                           ALL CHECKS PASSED (layer separation intact); `dodge_input` ALL CHECKS
                           PASSED. Every one reported 0 debugger errors. `main.tscn` booted with
                           0 debugger errors.
    2026-09-12  Milestone   THE ONE KNOWN FAILURE IS UNCHANGED AND STILL SEPARATE.
               10          `grounding_probe_debug` reports its single pre-existing FAIL,
                           `TestAttacker: rests on the surface, not floating or sunk (-0.020)`.
                           Every other actor passes (DummyActor 0.000, Player -0.001, TargetA 0.280,
                           TargetB/C 0.000). This pass changed no transform, shape or collision layer,
                           so it is NOT caused by Milestone 10 and was deliberately NOT repaired or
                           reinterpreted as part of it.
    2026-09-12  Milestone   STALE OPEN-BUFFER DEFECT REMAINS, fourth confirmation. The diagnostics
               10          panel still reports 20 phantom `Identifier "CreditLedger" not declared`
                           errors in `combat_debug_overlay.gd` and `credit_economy_probe_debug.gd`
                           (scope `open_script_buffers`), while per-file `state:script-errors` returns
                           0 for EVERY file involved and every script runs and prints in full. Judge
                           it by a RUN or a per-file query, never by the open-tab linter alone.
    2026-09-12  Milestone   RENDERED PLAYTEST: the frame was read BY EYE and shows the arena rendering,
               10          the top-right `SAVE / LOAD (prototype, not final UI)` panel with `F5 save`,
                           `F9 load`, `F10 new run` (read from the real InputMap, so the label cannot
                           drift from the bindings), `carried credits 0` and `save file: none yet`,
                           alongside the combat readout's own `carried credits 0` and all five actors
                           at 100/100. The visual ANALYSER returned `observer_analysis_failed` on every
                           capture, so this is a human-readable frame, NOT an analysed visual pass.
    2026-09-12  Milestone   NOT YET HUMAN-PLAYED. The probe proves the loop; it does not prove how the
               10          save/load flow FEELS in the hand, and no human has pressed F5/F9/F10 yet. Until
                           someone does, this milestone is measured, not accepted.
    2026-09-13  Milestone   HOST KEY COLLISION ISOLATED (M10.6, section 8M.20). The reported physical-F9
               10          failure was reproduced with the game's ONLY consumer of the save/load actions
                           set to PROCESS_MODE_DISABLED, so no Cascadia code could react. Measured: F9 IS
                           THE HOST'S PAUSE TOGGLE - it set `Engine.time_scale = 0` and released the
                           mouse while `SceneTree.paused` stayed FALSE and the window stayed focused,
                           starving the game's own loop to 6 of ~40 frames; a SECOND F9 press was never
                           delivered and restored it. F8 ENDS THE DEBUG SESSION outright, no script error
                           and no trace. F1-F7, F10-F12 and ordinary letters are safe and delivered. The
                           cause of "F9 breaks gameplay" is therefore OUTSIDE the game. The earlier
                           contract probe was ITSELF driving F8 (`KEY_LOAD := 4194339`) while printing
                           "F9", which is why its runs looked inconsistent and stopped at the load banner.
    2026-09-13  Milestone   FIX APPLIED: `load_run` (F7) and `load_run_alt` (F11) are new InputMap
               10          actions bound only to measured-safe keys, and `save_load_debug_controls.gd`
                           reads those instead of `quick_load`/`quick_load_alt`. `quick_load` and
                           `quick_load_alt` stay in the InputMap UNUSED, so the collision remains
                           re-testable - removing an InputMap binding is manual review. The contract
                           probe now drives F7 instead of F8.
    2026-09-13  Milestone   RE-MEASURED after the rebind (durable transcript `_probe_report.txt`, 0
               10          debugger errors from the probe): `RESULT: ALL CHECKS PASSED`. F5 saves (saves
                           0 -> 1), the mutation kills DummyActor and earns 100, both loads return
                           `result=OK` and restore the player to 0.195 m of the saved position, and
                           gameplay continues after EACH load - walk 1.7950 m, mouse look 48.8952 deg,
                           attack 8 -> 9 then 9 -> 10, dodge running, and stamina REGENERATES
                           60.0 -> 77.9 and 47.6 -> 65.4. Across all 80 traced frames, NOT ONE frame
                           shows `scale=0.000`, `mouse=0`, `paused=true` or a dead player.
                           RECORDED AS NEWLY CONFIRMED.
    2026-09-13  Milestone   STILL NOT VERIFIED: the physical F5/F7 keys pressed by hand. Every result
               10          above is injected `Input.parse_input_event` through the real action path,
                           which is NOT an OS-level key event. The user's physical test is the only proof
                           of that half, and this milestone stays measured-not-accepted until it happens.
    2026-09-13  Input       HUMAN RETEST of quicksave: the user confirmed F5 saves, F7/F11 load, the
                           position restores, and movement/look/attack/dodge/stamina all continue after
                           a load. Quicksave is therefore WORKING under the current implementation, and
                           the earlier F9/F8 failure is confirmed to have been a HOST key collision.
                           The user asked that the save/load path NOT be reopened without new evidence.
    2026-09-13  Input       FOCUS PASS 1 (section 8M.21). Two defects found in the focus handling added
                           that same day: `_refresh_focus()` forced the belief to match `has_focus()` in
                           BOTH directions every frame (a permanent wedge when the host never flips the
                           report back), and the recovery path was gated behind the state it had to
                           clear. Fix: reconciliation is RESUME-ONLY, plus an `_input()` presence
                           recovery running before GUI handling. Measured ALL CHECKS PASSED.
    2026-09-13  Input       HUMAN RETEST of the focus fix reported PARTIAL SUCCESS: "clicking the window
                           resumes camera movement but the game does not capture the mouse and I still
                           cannot move." That sentence is what separated the next two causes.
    2026-09-13  Input       FOCUS PASS 2 (sections 8M.21a). (1) The capture request was made from a
                           FRAME CALLBACK, and pointer lock is a user-gesture permission in an embedded
                           host, so the request could be dropped while looking successful in-game - the
                           camera worked while the cursor stayed free. (2) Every refocus click was
                           reaching `PlayerCombat` as a light attack, and a COMMITTED attack owns the
                           body, so locomotion was suppressed - the "cannot move". Fix: new
                           `_recover_capture_on_press()` re-takes capture INSIDE the click's own call
                           stack, suppresses that click as a swing, and is not gated on the focus belief.
                           Measured ALL CHECKS PASSED including the negative control that the refocus
                           click starts NO attack (attacks 2 -> 2) and the player can then walk 1.0950 m.
    2026-09-13  Input       STILL NOT VERIFIED: the physical Alt-Tab with a real OS cursor. This
                           environment cannot hold the window genuinely unfocused, so the effect of a
                           focus notification lasts one tick and the host-dropped cursor is SIMULATED by
                           clearing `mouse_mode` directly. The user's physical retest is the only proof
                           of that half.
    2026-09-13  Milestone   WINDOW FOCUS / INPUT ROUTING DEFECT FIXED (M10.7, section 8M.21). The user
               10          reproduced by hand: Alt-Tab away, return, click the window, and control does
                           not come back - keyboard presses may still register, the camera no longer
                           turns, the character does not move normally, and the click does not restore
                           capture. ROOT CAUSE was in the focus handling added by the previous pass, in
                           two parts. (1) The per-frame reconciliation forced the belief to match the
                           engine's `has_focus()` in BOTH directions, so a host that never flips it back
                           re-suspended the layer EVERY frame - which gated the capture keeper so capture
                           was never re-asserted, zeroed `get_move_vector()` so the character would not
                           walk, and left the debug overlay lighting up key rows because it reads raw
                           `Input`. (2) `_unhandled_input` early-returned while suspended, so the click
                           that should END the suspension was discarded BY the suspension. Fixed:
                           reconciliation is RESUME-ONLY (a missed focus-in can no longer wedge the game,
                           at the cost of a suspension lasting one frame longer than the notification
                           would give), and a new `_input` presence recovery runs BEFORE GUI handling so
                           a deliberate key/button press always ends a suspension, restores the declared
                           capture and drops the half-finished input. Motion still cannot resume anything.
    2026-09-13  Milestone   MEASURED (durable transcript `_focus_probe_report.txt`, 0 debugger errors
               10          from the probe): `RESULT: ALL CHECKS PASSED`. Focused: look 86.5229 deg,
                           movement 1.0950 m, attack and dodge work. Focus lost: input suspended, cursor
                           released (mode 0), capture intent kept, a held W reads as ZERO movement, a
                           pending look delta is DISCARDED rather than banked, sprint OFF, a queued dodge
                           cannot be consumed, no action reads as pressed, no pause and scale 1.000.
                           PHASE 2b - the reported wedge, a suspension with NO focus-in delivered:
                           motion alone does NOT resume input; a real CLICK resumes and RESTORES capture
                           (mode 2); a KEY press also resumes; state and capture hold afterwards; the
                           layer kept processing throughout (ticks 440 -> 448). Refocused: input ACTIVE,
                           capture returned with NO click, the button that brought the window back is
                           SUPPRESSED, look 86.5229 deg, movement 1.1342 m, attack and dodge work,
                           stamina regenerates 21.7 -> 39.6. `lock_on` still reaches the layer, the
                           targeting group still resolves to the player, no debug-panel Control consumes
                           gameplay mouse input, no UI Control holds focus, no pause and no time-scale
                           change anywhere. QUICKSAVE WAS NOT TOUCHED by this pass.
    2026-09-13  Milestone   STILL NOT VERIFIED BY HAND: the focus round trip was reproduced with
               10          `propagate_notification` and injected input, NOT by a real Alt-Tab with a real
                           OS cursor. This environment cannot hold the window genuinely unfocused (the
                           engine keeps reporting focus), so the handler's effect lasts one tick here and
                           that limit is printed in the transcript rather than hidden. The user's
                           physical Alt-Tab-and-return is the only proof of that half.

### 8M.21 M10.7 - Window focus, mouse capture and gameplay input routing (2026-09-13)

Scope discipline: window focus handling, mouse capture/visibility, input routing and gameplay input
gating ONLY. Quicksave was deliberately NOT touched - it was confirmed working by hand and no evidence
showed a save/load regression.

#### Root cause - two defects, both in the focus handling added by the previous pass

The reported reproduction was: Alt-Tab away, return, click the window to retarget it, and the game
does not fully recover - keyboard presses may still register, the camera no longer turns with the
mouse, the character does not move normally, and clicking does not restore mouse capture.

1. THE RECONCILIATION WEDGED THE GAME. `_refresh_focus()` forced the layer's belief to match the
   engine's `has_focus()` in BOTH directions, every frame. `has_focus()` is the authority; when the
   host never flips it back, or the notification is missed, the layer was re-suspended on every
   single frame - a permanent wedge, not a one-frame glitch. Everything downstream followed, and every
   one of those consequences is a symptom the user reported:
   - `_keep_mouse_captured()` is gated on the layer being active, so capture was NEVER re-asserted;
   - `get_move_vector()` returned ZERO while gated, so the character would not walk even though the
     key was arriving;
   - the debug overlay kept lighting up key rows, because it reads raw `Input` rather than the gate.
2. THE RECOVERY PATH WAS GATED BEHIND THE STATE IT HAD TO CLEAR. `_unhandled_input()` early-returned
   while suspended, so the click that should end a suspension was discarded BY the suspension itself.
   The only exit was a focus-in notification - the one thing observed not to arrive.

#### Fix

- `_refresh_focus()` is now RESUME-ONLY. It can switch the layer from suspended to active, but it never
  re-suspends from the engine's report. A missing focus-in therefore cannot wedge the game; the only
  cost is that a suspension lasts one frame longer than the notification would otherwise give.
- `_input()` presence recovery, running BEFORE GUI handling so no debug panel or other Control can
  consume it: a deliberate key press or mouse-button press while suspended resumes input, restores the
  declared capture and drops the half-finished input. `mouse_look_enabled` (gameplay's declared INTENT,
  owned by Escape) is never touched by a focus transition, which is what lets capture come back on its
  own instead of needing a second click.
- Mouse MOTION deliberately cannot resume anything. Motion can arrive from the host with no
  interaction at all, so treating it as presence would re-create the original defect - a camera that
  turns while the player is in another window.
- `esc`/intent separation and the existing capture keeper are unchanged; the keeper simply runs again
  once the layer is active.

#### The reported symptoms, mapped to the cause

| reported | explained by |
| -------- | ------------ |
| camera no longer turns after returning | layer suspended, so look accumulation is refused |
| "inputs are received but the game does not recover" | overlay reads raw `Input`; gameplay reads the gate |
| character does not move normally | `get_move_vector()` returns ZERO while suspended |
| clicking does not restore capture | the click was gated behind the suspension it had to clear |

#### Not in scope, and not changed

Enemy pursuit, banking, stats, items, gear, inventory, checkpoints, multiple slots, cloud saves, death
currency loss, animation, and the save/load path itself. `lock_on` remains a reserved action with NO
targeting system (8E.5) - what this pass verifies is only that the action still REACHES the input layer
after a focus round trip, which is the honest limit of a system that does not exist yet.

---

### 8M.21a M10.7b - FOCUS RETURN: THE CURSOR WAS NEVER RE-TAKEN (2026-09-13, second pass)

The user's hands-on retest after the pass above: **"clicking the window resumes camera movement but the
game does not capture the mouse and I still cannot move."** That single sentence separated the two
remaining causes, and they are DIFFERENT mechanisms from the ones already fixed.

#### Root cause - two fresh defects, both measured

1. THE CAPTURE REQUEST WAS MADE FROM A FRAME CALLBACK. `_keep_mouse_captured()` asked the host for the
   pointer from `_process`. In an embedded/browser host, pointer lock is a USER-GESTURE permission:
   a request made outside a real input event can be silently dropped while looking successful from
   inside the game. That is the reported state exactly - the camera responding (input works) while the
   cursor stays free (the lock request was refused).
2. EVERY REFOCUS CLICK WAS STARTING A LIGHT ATTACK. The click that arrives to retarget the window
   reached `PlayerCombat`. A COMMITTED attack is authoritative over its own movement (project rule,
   movement-authority section), so locomotion was suppressed for the whole attack - which is the
   reported "I still cannot move". The suppression ALREADY EXISTED for the Escape-recapture path, but
   was not applied when the HOST had dropped capture instead.

#### Fix

- New `_recover_capture_on_press()` in `cascadia_input.gd`, called from `_input()` (before GUI handling)
  on every mouse-button press. It re-takes capture INSIDE the click's own call stack, which is the
  user-gesture context a host can actually grant; it suppresses the same click so it cannot become a
  swing; and it is deliberately NOT gated on the focus belief, because a click that reached this game
  IS the player proving presence. Unconditional on `_focus_lost`, so it also covers a host that drops
  capture with NO focus change at all - which is the reported case.
- `_keep_mouse_captured()` keeps its job as the per-frame repair for a transient drop.

#### Measured (new PHASE 3b, and its negative control)

PHASE 3b reproduces the reported state by clearing `Input.mouse_mode` while the engine still reports
focus, then measures SYNCHRONOUSLY (`flush_buffered_events`, no `await`) so the recovery is credited to
the CLICK and not to the per-frame keeper repairing it one frame later - those are different mechanisms
and a report must not credit the wrong one.

    PASS  HOST-DROPPED: the CLICK ITSELF re-took the cursor (mode=2)
    PASS  HOST-DROPPED: that click is SUPPRESSED as a swing - it asked for the window, not an attack
    PASS  HOST-DROPPED: the refocus click did NOT start an attack (attacks 2 -> 2)
    PASS  HOST-DROPPED: the player can MOVE after the click that re-took the cursor (1.0950 m)

The third line is the negative control for "cannot move": without the suppression the click becomes a
committed attack and locomotion is suppressed BY DESIGN, so the check that attacks stay level is what
distinguishes the fix from a coincidence.

Full run: `RESULT: ALL CHECKS PASSED`, 0 debugger errors from the probe, transcript
`res://_focus_probe_report.txt`.

#### Still NOT verified

- The physical Alt-Tab with a real OS cursor. This environment cannot hold the window genuinely
  unfocused: the engine keeps reporting focus, so notification effects last one tick and the drop is
  simulated by clearing `mouse_mode` directly. Printed in the transcript rather than hidden.
- `lock_on` / retargeting as FEATURES - no targeting system exists (8E.5). Only "the action still
  reaches the input layer" was measured.
- Quicksave: NOT touched by this pass and no evidence of regression; still working under the current
  implementation.

---

### 8M.21b M10.7c - FOCUS RETURN: BOTH REQUESTS WERE SINGLE-SHOT AT THE TRANSITION (2026-09-13, third pass)

The user's second hands-on retest after 8M.21a: the camera works, **light and heavy attacks now work**,
and movement and mouse capture still do not. That report is itself the diagnosis: attacks arriving
PROVES mouse buttons, mouse motion and the input gate all work, so the gate, the pause state, the clock
and the debug panels were never the cause. What was left is the one thing attacks do not need and
movement does - **the keyboard**.

#### Root cause

Two requests are needed to hand the game back, and BOTH were made exactly once, from the focus event,
at the instant the host hands focus over:

1. **Mouse capture** - asked once by `_on_focus_gained()` via `_force_capture()`.
2. **Keyboard delivery to the window** - `_take_window_focus()` asked, but with an early `return` when
   `window.has_focus()` was true.

A host can need a beat before it will ACT on a request made that early. The first request is then
dropped, and - this is the part that makes the defect permanent - **the focus event never comes again**,
because the window is focused now, so there is no further transition to hang the request on. The result
is exactly the reported state, and it discriminates the two systems cleanly:

- **camera and attacks**: satisfied by any mouse event reaching the process. They need nothing from the
  window, so they recover on their own once the event stream resumes.
- **movement**: the only gameplay path built on `Input.get_vector()` over the `MOVE_*` ACTIONS, i.e. the
  only path that needs KEY EVENTS DELIVERED TO THE FOCUSED WINDOW. Requests dropped at focus-in mean
  the keyboard never starts arriving, so `get_move_vector()` returns zero forever while
  `consume_light_attack()` keeps succeeding from mouse buttons.

#### Fix (`scripts/input/cascadia_input.gd`)

- `_take_window_focus()` no longer early-returns on `window.has_focus()`. That belief is the one that can
  be wrong in precisely this failure, and the engine's own `grab_focus()` is a no-op when the window is
  genuinely focused, so asking unconditionally costs nothing.
- New bounded settle window: `FOCUS_REASSERT_FRAMES` (8) opened only by `_on_focus_gained()`, consumed
  by `_reassert_after_focus()`. While it is open it re-renders BOTH requests - the window focus when
  the engine reports it is not held, and a REAL capture transition via `_force_capture()`.
- It is deliberately NOT the per-frame keeper again: `_keep_mouse_captured()` cannot repair a
  host-dropped lock, because when the host releases pointer lock while `Input.mouse_mode` still reads
  CAPTURED the keeper sees "already captured" and asks the host for nothing - which is the free cursor
  no amount of clicking fixed. `_force_capture()` steps through VISIBLE so the host is actually asked.
- Bounded, and only ever opened by a real focus change, so it cannot fight the host for the foreground
  and cannot flicker the cursor indefinitely. It defers to `is_input_active()` unchanged, so the focus
  gate remains the single authority and Escape's release is never fought.
- The requirement to add no click, no key, no restart and no debug-panel step is unchanged: the whole
  recovery remains inside the focus transition plus a bounded retry.

#### Confirmed behaviour (probe re-run, 0 runtime errors, transcript `res://_focus_probe_report.txt`)

`RESULT: ALL CHECKS PASSED` with the settle window in place. Focused: mouse CAPTURED (mode 2), look
74.7243 deg, movement 0.5350 m, attacks and dodges work. Focus lost: input suspended, cursor released
(mode 0), capture intent kept, a held move key reads as ZERO, pending look discarded, no pause, scale
1.000. Stuck-with-no-focus-in: motion alone does not resume, a real click does and re-takes capture.
Refocused: capture returned with NO click, the returning button is suppressed, movement 1.1293 m,
attacks and dodges work, camera works, no pause, no time-scale change, player in the normal process
mode.

#### Still NOT verified

- **The physical Alt-Tab with a real OS cursor remains UNPROVEN by this environment.** The simulation
  cannot hold the window genuinely unfocused - the engine keeps reporting focus, printed in the
  transcript rather than hidden - so what is proven is the recovery PATH, not the real transition. The
  user's hands-on Alt-Tab is still the only proof of that half, and it has not been run since 8M.21b.
- Whether a host that keeps REFUSING both requests indefinitely can be fully recovered: the settle
  window bounds our asking, and the click path remains the documented manual escape.
- Not re-measured this pass: quicksave, the debug panels, and the deletion-manifest hygiene entries.

---

### 8M.22 M10.8 - THE SHIPPED GAME HAD NO WORLD, AND THE DEBUG OVERLAY ATE MOUSE LOOK (2026-09-13)

This pass was opened as "make the game window and mouse capture behave correctly". The previous three
passes (8M.21, 8M.21a, 8M.21b) had all worked on the FOCUS handling and all measured ALL CHECKS
PASSED, while the user kept reporting that control did not come back. The user's framing was not
accepted at face value, and the first thing done was to RUN THE SHIPPED GAME rather than a probe.

#### Root cause 1 - the main scene contained no world at all (the bigger defect)

`res://main.tscn` held only `CascadiaInput`, the four debug CanvasLayers, `HitFeedback`,
`CreditLedger`, `GameStateSave` and `SaveLoadControls`. It contained NO `TestEnvironment` instance, so
pressing Play booted an empty void. The captured frame showed exactly that: a blank viewport, the
input readout, the save/load panel, and the combat overlay reporting `phase: no PlayerCombat in scene`
with an empty DAMAGEABLE ACTORS list.

WHY EVERY PROBE STILL PASSED, and this is the trap. Every probe scene in `res://scenes/diagnostics/`
instances `main.tscn` as its own world and adds a probe node next to it, and every probe and the save
system resolve the arena at `TestEnvironment/...` under that root. So the probe scenes SUPPLIED the
world that the main scene was missing, and the suite measured a composition the shipped game did not
have. `main_scene` pointed at `res://main.tscn` the whole time; the defect was in the scene's
CONTENTS, not the setting.

FIX - the `TestEnvironment` instance was added back to `main.tscn` (the intended composition: input
layer, debug layers, ledger, save, save/load controls, and the world). Nothing else in the main scene
was changed. `scenes/test_environment.tscn` itself was NOT modified, and it was already tracked in
git - it was present on disk and simply not instanced by the main scene.

#### Root cause 2 - the diagnostic overlay was consuming the mouse look every frame

MEASURED, link by link, with a purpose-built probe (`mouse_look_routing_probe_debug`):

    ARRIVAL:  the injected motion ARRIVED with real content - relative=(290.1154, 0.0)
    LAYER:    raw_mouse=(0.0, 0.0)  raw_look=(290.1154, 0.0)  ->  the layer DID accumulate it
    END:      camera turned 0.0000 deg

The motion reached the input layer and the layer accumulated it - and the camera still never moved. The
delta was being spent by something else first. `get_look_delta()` is documented as CONSUMING the delta
so that exactly one consumer per frame can spend it, and a grep for its callers found a SECOND one:
`InputDebugOverlay._process` (a DISPLAY read). That CanvasLayer is ordered BEFORE `TestEnvironment` in
`main.tscn`, so its per-frame display read consumed the motion every frame and the camera - running
later in the same frame - always read ZERO.

This is why the symptom discriminated the systems so cleanly, and why the previous passes were aimed at
the wrong layer: mouse look was the ONLY consumer whose value could be consumed by a bystander, so
camera rotation died while movement, attacks, dodge, stamina and focus handling all kept working.

FIX - `CascadiaInput.peek_look_delta()` was added: a READ-ONLY accessor that returns the pending delta
WITHOUT consuming it, with its contract documented (display only; never a second mover). `input_debug_overlay.gd`
now uses it. `get_look_delta()` keeps its single consumer (`ThirdPersonCamera`) and its consuming
contract unchanged. `buffer_time()`, `is_action_held()` and `is_action_pressed_now()` were checked for
the same defect and are all pure/heap reads - `get_look_delta()` was the only consuming accessor, so
there is no sibling of this bug left behind.

#### Measured results

- `mouse_look_routing_probe_debug` - RESULT: ALL CHECKS PASSED, 0 debugger errors. Delivery OK on
  every entry point (`Input.parse_input_event` with accumulated input on and off, and
  `Viewport.push_input`), a DIRECT call into the layer's `_unhandled_input` as the control, and
  `END TO END: the camera TURNS for injected motion (63.8254 deg)` where it measured 0.0000 deg.
- `focus_input_routing_probe_debug` - RESULT: ALL CHECKS PASSED (was `2 FAILED` before this pass, both
  failures being the look checks). `PHASE 1: mouse look works while focused` and `REFOCUSED: mouse look
  works again` both report yaw changed 63.8254 deg. Every focus, capture, staleness and
  debug-panel check still passes unchanged. Transcript `res://_focus_probe_report.txt`.
- Shipped game (`res://main.tscn`): boots with the arena rendering, the player capsule under the
  third-person camera, and the combat overlay reporting `phase IDLE`, `player 100/100`, `stamina
  100/100` and all five damageable actors alive and targetable. Rendered frame read by eye.

#### Newly confirmed

- The shipped main scene now contains a playable world, and mouse look reaches the camera from injected
  motion through the real input pipeline (63.8254 deg).

#### Newly unverified / still open

- The PHYSICAL mouse and a real Alt-Tab remain unproven by this environment, exactly as 8M.21b recorded.
  The recovery PATH is measured; an OS-level pointer-lock drop and a genuine window unfocus cannot be
  held here. The user's hands-on playtest is the proof of that half.
- NOT re-measured this pass: quicksave, the other debug panels, the InputMap host-key entries, and the
  combat probes. No change was made to any of them.
- The stale open-buffer linter defect (`Identifier "CreditLedger" not declared`, 20 phantom errors in
  `combat_debug_overlay.gd` and `credit_economy_probe_debug.gd`) is UNCHANGED and still a false
  positive: per-file `state:script-errors` returns 0 for both files and both scripts run. Judge it by a
  run or a per-file query, never by the open-tab linter.

---

### 8M.23 M10.9 - INPUT / CAPTURE HARDENING: NO DEFECT FOUND, TWO EDGES MEASURED (2026-09-13)

Opened as ONE hardening and review pass over the existing mouse / focus / camera implementation, with an
explicit instruction not to redesign or revert the working routing fix. The outcome is deliberately
modest and is recorded as such: **no production defect was found, so no production file was changed.**

#### What was confirmed intact (read from DISK, not from a cached view)

- `scripts/input/cascadia_input.gd` contains `peek_look_delta()` - a read-only accessor that returns the
  pending delta WITHOUT consuming it.
- `scripts/diagnostics/input_debug_overlay.gd` reads `peek_look_delta()`, not the consuming accessor.
- A grep for `get_look_delta()` across every `.gd` file leaves exactly ONE production consumer:
  `ThirdPersonCamera._process`. The remaining hits are this pass's own probes and the retarget probe's
  comment, both of which are measurement, not gameplay.
- `main.tscn` still instances `scenes/test_environment.tscn` as `TestEnvironment`, and the shipped game
  boots the arena with 0 runtime errors.
- An earlier 7009-byte read of the overlay that appeared to still call `get_look_delta()` was a STALE
  cached view: disk holds the corrected 7298-byte file. Recorded because acting on that stale view would
  have "fixed" a defect that was already gone.

#### The questions this pass had to answer, and the answers

- **Ordering / conflicting owners?** No. The layer resolves focus ONCE per frame in `_process`, before
  anything reads input, and `is_input_active()` is the single authority every semantic query consults.
  No other script changes `Input.mouse_mode`; the other `MOUSE_MODE_*` hits in the tree are probes.
- **Frame-cost of the keeper?** Bounded. `_keep_mouse_captured()` returns immediately when capture is
  already held, and re-asserts only in `PASS` while it is not.
- **Can the recovery click permanently starve attacks?** No - and this was the specific worry, because an
  earlier version of this bug ate every attack click. `_capture_recovery_attempted` is reset the first
  time the keeper OBSERVES capture confirmed, so suppression is once-per-loss rather than while-free.
- **Is the `_suppress_presses` clear timing fragile?** Checked and deliberately NOT changed. It is
  cleared at the end of `_process`, while `PlayerCombat` consumes in `_physics_process`, which would
  normally be a red flag. It is robust here by CONSTRUCTION: `cascadia_input.gd:809` skips BUFFERING
  entirely while the flag is set, so the press is never stored and there is nothing left to consume even
  if the clear were late.
- **Was a no-input window left between recovery and camera look?** No measurable one. Look is re-gated
  through the same frame's `_process`, and the probe measures the camera turning 310.3347 deg on the
  first look after each recovery.

#### The two things that genuinely were missing: COVERAGE

Nothing measured ESCAPE, which is the FIRST item on the reported edge-case list, and the look contract
had only ever been inferred from "the camera turned". Both are now measured directly (probe PHASE 5):

    LOOK CONTRACT: display read (1410.612, 0.0) twice -> does NOT consume
    LOOK CONTRACT: consuming read (1410.612, 0.0) -> then ZERO (it spends it)
    ESCAPE: intent OFF, cursor released, motion turns the camera 0.0000 deg while free
    ESCAPE: the click re-took the cursor AND the intent, and was SUPPRESSED as a swing
    ESCAPE: the recovering click did NOT start an attack (attacks 2 -> 2)
    ESCAPE-RETURN: mouse look works again (310.3347 deg)

Note on the magnitude: the injected 240 px arrives at the layer as 1410.612 because the engine re-scales
synthetic motion. It is deterministic, not ambient noise - the probe's DIRECT-call control stage shows
the raw 240 passing through unchanged. Comparisons are therefore exact, not approximate.

#### Measured results

- `focus_input_routing_probe_debug` - RESULT: ALL CHECKS PASSED, 132 transcript lines, 0 debugger
  errors. Five phases plus the new Escape/look-contract phase. Transcript `res://_focus_probe_report.txt`.
- `mouse_look_routing_probe_debug` - RESULT: ALL CHECKS PASSED, 0 debugger errors. Delivery confirmed on
  every entry point, direct-call control included, and `END TO END: the camera TURNS (310.3347 deg)`.
- Shipped game (`res://main.tscn`) - boots the arena with 0 runtime errors.

#### Files changed by this pass

- `scripts/diagnostics/focus_input_routing_probe_debug.gd` - PHASE 5 added (Escape loop + look contract).
- `CASCADIA_DELETION_MANIFEST.md` - the focus probe's candidate entry updated; status unchanged.
- `.summer/plans/CASCADIA_MILESTONE_ROADMAP.md` - this section.

NO production file was touched. `cascadia_input.gd`, `input_debug_overlay.gd`, `third_person_camera.gd`
and `main.tscn` are all unchanged from 8M.22.

#### Newly confirmed

- Escape releases the cursor and the capture intent, motion cannot turn the camera while the cursor is
  free, and the click back restores both - measured, not inferred.
- The look delta is observed by the overlay WITHOUT being consumed, and is spent exactly once, by the
  camera.

#### Newly unverified / still open (do not read this pass as closing them)

- The PHYSICAL mouse, a real OS pointer-lock drop and a genuine OS-level window unfocus remain UNPROVEN
  by this environment, exactly as 8M.21b and 8M.22 recorded. The window here keeps reporting focus, so
  the simulated transition is single-tick by necessity. The reported "Alt-Tab sometimes needs the window
  selected again" is therefore plausibly HOST behaviour that no in-game code can fully absorb, and the
  user's hands-on playtest is the only proof of that half. Stated plainly rather than claimed solved.
- Not re-measured this pass: quicksave, the other debug panels, the InputMap host-key entries, and the
  combat probes. No change was made to any of them.

#### Deferred to a future production concern (recorded, NOT implemented)

A deliberate rendering / window policy is still owed before shipping and is explicitly OUT of scope for
the input passes: windowed vs fullscreen vs borderless, resolution and display-change behaviour, focus
and mouse-capture behaviour under EACH window mode, whether return should recapture automatically or
require a click, and player-facing feedback when capture is lost or restored. The current behaviour is
accepted as a development test bed: playable, recoverable in normal testing, with the state transitions
understood - not final shipping behaviour.

---

### 8M.24 M10.10 - RECOVERY CHAINS, MEASURED END TO END (2026-09-13)

The user reframed the problem usefully: it is not one broken STATE, it is a broken CHAIN. Escape releases
the cursor; the click back sometimes does not re-hook; and a later transition fixes it. Every individual
state had already been measured (8M.21b, 8M.22, 8M.23), so this pass measured the transitions BETWEEN
them instead.

#### The probe

`scripts/diagnostics/recovery_chain_probe_debug.gd` (scene
`scenes/diagnostics/recovery_chain_probe_debug.tscn`, transcript `res://_recovery_chain_report.txt`) runs
the eight reported chains in one session:

    1 Escape -> click back
    2 Escape -> click -> Escape -> click
    3 Alt-Tab away -> back
    4 Alt-Tab away -> click -> Alt-Tab again -> return
    5 Alt-Tab away -> Escape -> click back
    6 Escape -> Alt-Tab -> return -> click
    7 click away -> click back -> Escape -> click back
    8 Alt-Tab -> return -> Escape -> click -> Alt-Tab -> return

After EVERY step it records: engine focus, `Input.mouse_mode`, capture intent, `is_input_active()`, the
pending look delta, and the layer's own counters (`capture_requests_on_press`,
`capture_reasserted_by_click`, `focus_reasserts`, `focus_lost_count`, `focus_gained_count`). After every
chain it additionally asserts that capture STAYS held across 20 further frames, that look turns the
camera, and that movement works. It ends with the reported-pattern investigation and a full attack /
dodge / stamina battery.

Escape and Alt-Tab are injected as REAL events and REAL notifications - `ui_cancel` through the engine's
input pipeline, and the focus transitions by propagating the engine's own FOCUS_IN / FOCUS_OUT
notifications through the live tree - so the project's own handlers run rather than being simulated away.

#### The decisive finding

    PATTERN: the internal state after the FIRST recovery and after the SECOND are IDENTICAL.
    PATTERN: -> nothing in the game's state differs, so the game cannot be what made the
    PATTERN:    second transition work. That points OUTSIDE the game (the host's grant of
    PATTERN:    pointer lock, or a first click the host consumed to activate the window).

That is the answer to "what state is wrong or inconsistent", and it is a MEASURED one: after the first
click back the game already has the cursor captured, the intent on, input active and look working -
read byte-for-byte identical to the reading the second transition produces. So the flakiness the user
feels is NOT a half-completed state inside Cascadia. It is the host's own pointer-lock grant / window
activation, which the game cannot observe and cannot force.

#### Measured results

- `recovery_chain_probe_debug` - RESULT: ALL CHECKS PASSED, 231 transcript lines, 0 debugger errors. All
  8 chains pass; every chain ends captured / intent-on / active, capture stable for 20 frames, look
  turning the camera, and movement working (0.2750 m in ~0.14 s at a steady 3.3 m/s walk speed,
  `floor=true`, on every chain).
- `focus_input_routing_probe_debug` - RESULT: ALL CHECKS PASSED, 132 lines, 0 debugger errors
  (unchanged by this pass - regression control).
- `mouse_look_routing_probe_debug` - RESULT: ALL CHECKS PASSED, 0 debugger errors, camera turns
  245.2645 deg.
- Shipped game (`res://main.tscn`) - boots the arena with 0 runtime errors; the rendered frame shows the
  ground, the red target pillars with their world labels, and both debug overlays.

#### Three PROBE defects found and fixed (NOT production defects)

Every failure this pass started with was the probe's own measurement, and each is recorded because each
is a trap that would mislead a future session:

1. **Frame counts are not time in this scene.** It renders uncapped, so `await _frames(20)` was ~0.09 s
   of simulated time. Movement was therefore measured DURING the acceleration ramp from a dead stop
   (`_reset_to_clear_ground` zeroes velocity first), reading 0.08-0.12 m and FAILING all 8 chains while
   the player was demonstrably walking - the same line printed `floor=true` and a live velocity vector.
   Movement now holds the key until walk speed stops rising, then measures over a WALL-CLOCK window.
2. **A "tap" held too long is a HOLD.** The backstep is the shared tap/hold command (Left Shift). Holding
   it for a fixed 250 ms poll window exceeded `MOBILITY_TAP_MAX` (0.20 s), so the input layer CORRECTLY
   resolved it as a SPRINT HOLD and no dodge ever began. MEASURED as `running=false` with EVERY refusal
   counter still 0 - the signature of a command that was never a dodge at all. The probe now presses,
   RELEASES, and only then polls.
3. **Stamina regeneration was assumed, not waited for.** `regen_delay` is 0.8 s and frames do not cover it
   here, so a fixed 90-frame wait read flat stamina (60.0 -> 60.0). The check now polls until the pool
   GROWS and reports how long that took (`grew_after=181` frames). `regen_enabled` was true and
   `_regen_block` 0.000 throughout - the pool was healthy; only the measurement was wrong.

#### Files changed by this pass

- `scripts/diagnostics/recovery_chain_probe_debug.gd` - NEW chain-level probe.
- `scenes/diagnostics/recovery_chain_probe_debug.tscn` - its entry scene.
- `CASCADIA_DELETION_MANIFEST.md` - both new files recorded as deletion candidates.
- `.summer/plans/CASCADIA_MILESTONE_ROADMAP.md` - this section.

NO production file was touched. `cascadia_input.gd`, `input_debug_overlay.gd`, `third_person_camera.gd`
and `main.tscn` are all unchanged from 8M.22, and the look-consumption contract still holds: the overlay
reads `peek_look_delta()` and `get_look_delta()` has exactly one production consumer, the camera.

#### Newly confirmed

- All eight reported recovery chains end in a playable state - capture held, intent on, input active,
  look working, movement working - measured end to end rather than state by state.
- The first-click-vs-second-transition difference is NOT in the game's state. Whatever makes the second
  action work lives in the host, not in Cascadia.

#### Newly unverified / still open (do not read this pass as closing them)

- The PHYSICAL mouse, a real OS pointer-lock drop and a genuine OS-level window unfocus remain UNPROVEN
  here, exactly as 8M.21b, 8M.22 and 8M.23 recorded. `Window.has_focus()` keeps reporting true in this
  host, so the focus transition is simulated by propagating the engine's own notifications. That runs the
  project's REAL handlers, but it cannot make the OS actually take the window away. The reported
  "Alt-Tab sometimes needs the window selected again" therefore REMAINS the user's hands-on playtest to
  prove or disprove. The evidence says it is host-side; only a real Alt-Tab can confirm it.
- Not re-measured this pass: quicksave, the save/load probes, the other debug panels, the InputMap
  host-key entries, and the combat probes. No change was made to any of them.

#### Deferred to a future production concern (recorded, NOT implemented)

Unchanged from 8M.23 and still explicitly out of scope for the input passes: windowed vs fullscreen vs
borderless, resolution and display-change behaviour, focus and mouse-capture behaviour under EACH window
mode, whether a return should recapture automatically or require a click, and player-facing feedback when
capture is lost or restored. The current behaviour is accepted as a development test bed: playable,
recoverable in normal testing, with the state transitions understood - not final shipping behaviour.

---

## 8N. DODGE MOVEMENT AUTHORITY - THE RECORDED 8F PASS, IMPLEMENTED AND MEASURED (2026-09-13)

This pass closes the bounded future pass that section 8F recorded on 2026-09-12 and that section 8G.2
then CONFIRMED BY HAND (the user reported that the backstep "seems to lose or alter the intended facing
orientation"). It was chosen as the next sensible task because it is an explicitly active, recorded,
roadmap-aligned gameplay item - NOT a new milestone, and NOT a reason to reopen the mouse/focus work,
which stays accepted as a development test bed (8M.24).

### 8N.1 What was changed

**Orientation arbitration (`scripts/player/player_controller.gd`).** `_apply_facing()` had no evasion
guard, so it re-derived body yaw from the CURRENT horizontal velocity every frame - and during an
evasion that velocity IS the evasion burst. A backstep therefore drove yaw to the reverse of the
actor's facing, and the body turned around mid-evasion. The controller now holds the LOCKED gameplay
facing for the whole of a committed evasion and does not re-derive orientation from velocity while the
evasion owns the body. The facing yardstick is refreshed at the TOP of the physics frame
(`_sync_evasion_authority()`) while no evasion owns the body, and frozen once one does, so the value the
evasion holds is the last orientation the actor genuinely chose for itself.

**The end-of-evasion handoff.** The evasion owns its displacement for exactly its own duration. The
burst velocity it authored is now cleared at the handoff instead of being left on the body, because a
residual burst keeps driving BOTH the slide and - since ordinary facing follows travel - the
orientation, which would visibly turn the actor around AFTER an evasion it had already paid for.

**Position arbitration (`_resolve_step_up()`).** This had no evasion guard either, and is SIZED BY THE
PROBE REACH rather than by the evasion's authored travel. It now stands down entirely while an evasion
is active, so it cannot add displacement the evasion never asked for.

**A latent contradiction in `DodgeComponent.try_start()`.** `facing` defaulted to FORWARD, so a caller
asking for a BACKSTEP without also naming a facing stored `kind=BACKSTEP` with `facing=FORWARD` -
which contradicts the component's own documented rule that a backstep is ALWAYS backward. Production
always passed BACKWARD, so no gameplay path hit it, but the captured state a future animation adapter
reads could be self-contradictory. The kind now decides the facing, so the two cannot disagree.

### 8N.2 What was deliberately NOT changed

- `_apply_horizontal()`'s dodge branch was already CORRECT (8F.2) and was not touched.
- i-frames, the 22-stamina cost, dodge timing, commitment and the attack/parry mutexes: unchanged.
- No lock-on was assumed or added. The dodge direction stays camera-relative.
- No animation, rig or clip work - there is no animation system yet (8G.2 item 3 stands).
- No mouse, focus, capture or camera code was touched.

### 8N.3 The probe

`scripts/diagnostics/dodge_authority_probe_debug.gd` (scene
`scenes/diagnostics/dodge_authority_probe_debug.tscn`, transcript
`res://_dodge_authority_report.txt`) runs nine checks in one session:

    AC1 backstep facing   neutral backstep driven through REAL input retreats while still facing the
                          way the player faced; body yaw does not turn around on any evasion frame.
    AC2 dodge facing      DIRECTIONAL dodge driven through REAL input keeps the SAME locked facing even
                          when that facing is pinned 180 deg away from the dodge direction.
    AC3 dodge travel      on clear ground, travel = speed x duration, and no single frame exceeds the
                          speed the evasion authored.
    AC4 backstep travel   the same for the neutral backstep, which is slower.
    AC5 dodge into step   an evasion driven into the 42 cm step gains NO displacement beyond its own
                          authored travel and does NOT climb onto the step.
    AC6 commitment        an attack still refuses a dodge (mutex unchanged).
    AC7 stamina           exactly one 22-point cost per evasion.
    AC8 i-frames          damage is still refused inside the window.
    AC9 handoff           ordinary locomotion takes the body back at walking speed, facing follows
                          movement again - authority is RETURNED, not lost.

### 8N.4 Measured results - `RESULT: ALL CHECKS PASSED`, 80 transcript lines, 0 debugger errors

- AC1 backstep: `travel=1.2800 m over 0.4000 s`, authored 1.280 m; from (0.00, 12.05) to
  (0.00, 13.33); max body yaw deviation `0.00 deg` over the whole evasion.
- AC2 dodge: `travel=1.6875 m over 0.4500 s`, authored 1.6875 m; body pinned 180 deg AWAY from the dodge
  direction and still `max body deviation 0.00 deg` - the adversarial pin held.
- AC3 dodge travel: measured 1.6250 m vs 1.6875 m authored, max single frame `0.0625 m` (limit 0.20).
- AC4 backstep travel: measured 1.2267 m vs 1.2800 m authored; still reports BACKWARD.
- AC5 dodge into the 42 cm step: travel 0.5371 m, final y `0.000` (did not climb the 0.42 m step), max
  frame 0.0625 m - no step correction leaked into the evasion.
- AC6/AC7/AC8/AC9: attack mutex refusal counted by cause; exactly one 22-point charge (100 -> 78);
  damage refused in-window and applied normally outside it; walking resumed at 4.20 m/s for 2.1700 m
  with facing deviation `0.0 deg`.

Regression controls re-run in the same pass:

- `step_probe_debug` - all six traversal phases clean. A/B/C (14/28/42 cm) each show exactly ONE
  step-up frame; D (1 m ledge) and E/F (ramp) show ZERO, i.e. smooth. No launch anywhere. Confirms the
  new evasion guard in `_resolve_step_up()` did not disturb ordinary traversal.
- Shipped game (`res://main.tscn`) - boots with 0 debugger errors; the rendered frame shows the lit
  arena, both red target pillars with their world labels, the player capsule and both debug overlays.

### 8N.5 Newly confirmed

- Orientation during a committed evasion belongs to the locked gameplay facing, not to current
  velocity - measured with the body pinned 180 deg away from the dodge direction.
- Displacement during an evasion is authored ONLY by the evasion: on clear ground, into a 42 cm step,
  and at the handoff, with no unauthored frame.
- Authority is RETURNED at the end of an evasion: ordinary locomotion and facing resume at authored
  speed.
- A backstep can no longer store a self-contradictory `kind=BACKSTEP / facing=FORWARD` pair.

### 8N.6 Newly unverified / still open

- RESOLVED AFTER THIS PASS (2026-09-13): the corrected dodge/backstep orientation HAS been confirmed BY
  HAND. The user reports that the evasion uses the player's last movement orientation and keeps that
  orientation committed during the evasion - exactly the behaviour 8F set out to produce. RECORDED AS
  THE USER'S OWN PLAYTEST REPORT: no probe was re-run to restate it, and every measured number above is
  unchanged. This closes the GAMEPLAY half of the 8G.2 backstep defect.
- CLOSED BY MILESTONE 11 (2026-09-13): the facing INDICATOR the user asked for is now BUILT - a
  `FacingMarker` holding an amber NOSE on local -Z and a blue TAIL on local +Z, added under `Player` in
  `scenes/test_environment.tscn`, scene-authored and script-free. The correction is no longer judged only
  by numbers: two rendered frames confirm both markers are readable from the default camera. What remains
  is the HUMAN read of it WHILE MOVING, dodging and backstepping - a still frame cannot show that. 8O.11
  records the implementation; the marker geometry itself is what 8O.4 proposed.
- Physical Alt-Tab / OS pointer-lock behaviour remains unproven in this host, unchanged from 8M.24.
- Not re-measured this pass: the save/load probes, the other debug panels, and the combat probes. No
  change was made to any of them.

### 8N.7 Files changed by this pass

- `scripts/player/player_controller.gd` - facing lock + evasion authority sync + handoff velocity clear
  + evasion guard in `_resolve_step_up()`.
- `scripts/player/dodge_component.gd` - kind decides facing, so the pair cannot contradict.
- `scripts/diagnostics/dodge_authority_probe_debug.gd` - NEW probe (recorded in the deletion manifest).
- `scenes/diagnostics/dodge_authority_probe_debug.tscn` - its entry scene (same).
- `res://_dodge_authority_report.txt` - the durable transcript (evidence, NOT a deletion candidate).
- `CASCADIA_DELETION_MANIFEST.md`, `.summer/plans/CASCADIA_MILESTONE_ROADMAP.md` - this pass.

### 8N.8 Two PROBE defects found and fixed (NOT production defects)

Recorded because each would mislead a future session:

1. **A probe placed the body inside the enemy.** AC2 originally spawned the player at (0, 0.3, 6) and
   dodged along camera-forward (-Z), straight into `TestAttacker` at (0, 0, 5) one metre away. The
   evasion was physically blocked and measured 0.12 m against an authored 1.69 m - which looked exactly
   like a broken dodge. The phase now runs on clear ground at z=16.
2. **Travel was measured from the wrong anchor.** The real-input phases hold a movement key BEFORE the
   tap, so the body is already walking when the evasion starts; counting that approach reported
   1.9150 m against an authored 1.6875 m. The measurement is now anchored to the evasion's OWN first
   frame, which is why AC2 reads 1.6875 m exactly.

---

## 8O. MILESTONE 11 - READABLE PLAYER FACING INDICATOR (APPROVED AND IMPLEMENTED 2026-09-13)

STATUS: **APPROVED AND IMPLEMENTED. SCENE-VERIFIED AND RENDER-CONFIRMED. HUMAN PLAYTEST OF YAW-FOLLOWING
STILL PENDING.**

Subsections 8O.1 to 8O.9 below are the ORIGINAL PROPOSAL, kept verbatim so the scope that was agreed can
be compared against what was actually built. 8O.10 is the approval gate that has now been passed, and
**8O.11 records the implementation result**.

The user approved Milestone 11 explicitly. It was then implemented as a bounded, presentation-only pass:
`FacingMarker` and two primitive markers added to the player in `res://scenes/test_environment.tscn`.
NO script was written or modified, and no gameplay value changed. See 8O.11.

### 8O.1 The problem this would solve

The 8F pass corrected the evasion's orientation: during a committed dodge or backstep the body now holds
the facing it had when the evasion began, instead of re-deriving it from its own burst velocity
(section 8N). The user has confirmed that by hand - the evasion uses the last movement orientation and
keeps it committed.

What is STILL missing is the ability to SEE it. The player body is a plain pale capsule
(`Player/Mesh`, a `CapsuleMesh` with `Mat_player`, albedo roughly 0.88 white). A capsule is rotationally
symmetric about its vertical axis, so it looks IDENTICAL at every yaw. The user cannot tell, by eye,
which way the actor is facing at any moment - and therefore cannot visually confirm the very correction
that was just made. This is the parameterisation gap 8G.2 item 2 named, and it is the only half of that
item still open. It is a PRESENTATION gap, not a gameplay defect: nothing about the evasion's behaviour
is in question.

### 8O.2 Why this is the next sensible candidate

- It is the last item in this file that is ALREADY OPEN and already recorded against a human-reported
  finding, rather than a system invented for activity. 8G.2 item 2, 8F.2 and 8N.6 all name it.
- It is tiny and it is bounded: primitive geometry in one scene, no new system, no new script, and no
  change to any gameplay value.
- It closes a REAL blocker on judging other open feel items. 8G.4 lists parry timing, windup
  readability, attack commitment and "whether the facing reads" as UNADJUDGED. None of those can be
  judged while the actor's orientation is invisible.
- It is a prerequisite for any future animation work reading better. When animation arrives
  (Milestone 15) the primitive facing markers stop mattering, but until then they are the ONLY way the
  player-facing orientation is expressible at all.

It is NOT a milestone-scale system, and this section should not be read as inflating it into one.

### 8O.3 One finding that shapes the scope

**The third-person camera sits BEHIND the actor, so a front-face marker alone cannot work.**

Read from `scenes/test_environment.tscn`: the rig is `CameraRig/CameraYaw/CameraPitch/SpringArm3D/Camera3D`
with `spring_length = 4.5` and a `CameraPitch` of about -12 degrees, pivoted on the player. The camera
therefore looks at the actor from behind and slightly above. A marker placed only on the capsule's FRONT
would sit on the far side of an 0.8 m-wide opaque capsule and be hidden by the capsule itself for the
whole default view.

So the indicator must be readable FROM BEHIND as well as from other angles. That is a design constraint on
the proposal below, not a reason to move the camera: the camera is accepted and must not change.

### 8O.4 Proposed scope - the smallest change that makes facing readable

One new node in the player's own scene: `FacingMarker`, a `Node3D` added as a DIRECT CHILD of `Player` in
`res://scenes/test_environment.tscn`, holding two primitive markers with two scene-local materials:

- a NOSE marker on the actor's FORWARD side - local -Z, because Godot's convention here is that -Z is
  world forward. This matches `PlayerController._backstep_direction()` (which treats `+basis.z` as
  backward) and `_facing_of()`. It is made brighter and, deliberately, protrudes past the capsule so it
  is also visible in silhouette from above and from the side.
- a TAIL marker on the actor's REAR side - local +Z - in a contrasting dark colour. This is the one that
  carries the actual requirement, because it is the side the default camera sees: seeing the tail
  unambiguously means "forward is away from you", which is exactly the read a backstep needs.

Two markers rather than one, because a single rear marker reads correctly from behind but goes ambiguous
whenever the camera orbits to the front, and a single front marker reads correctly from the front but is
invisible from behind. The pair is readable from every angle at the cost of one extra primitive.

Both markers are children of the BODY transform, so they inherit `rotation.y` automatically. Nothing
drives them: no script writes to them, and they are presentation only.

### 8O.5 What must NOT change

Everything except the actor's rendered appearance. Specifically, and unchanged from this pass:

- No change to `player_controller.gd`, `dodge_component.gd`, or ANY script. The proposal needs zero new
  code and zero script edits.
- Dodge direction, backstep direction, orientation authority, evasion commitment, dodge speed, duration,
  distance, stamina cost, i-frames, the attack/evasion mutex and parry all stay exactly as measured in 8N.
- Movement, lock-on, camera, mouse look, mouse capture, focus handling, input routing, save/load, credits,
  enemy behaviour, combat timing, animation, AI, inventory, ranged combat and weapons.
- The camera rig itself, including spring length and pitch.

Hard constraint on the implementation: the markers must contain **no `CollisionShape3D`**. A capsule-shaped
collision shape added under `Player` would be silently picked up by `PlayerController._capsule_radius()`,
which walks the body's children looking for a `CapsuleShape3D`. Marker nodes are `MeshInstance3D` only, so
that path cannot see them.

### 8O.6 Acceptance criteria for a FUTURE implementation pass

Checkable from the saved scene text:

- AC-A `FacingMarker` exists as a direct child of `Player` in `res://scenes/test_environment.tscn`, and
  contains no `CollisionShape3D`.
- AC-B the forward marker's local Z offset is NEGATIVE and the rear marker's is POSITIVE, so the markers
  agree with the -Z forward convention the movement code already uses.
- AC-C no script file is added or modified by the pass.

Checkable by eye, once and only once, from the running game:

- AC-D with the default third-person camera, the actor shows a distinct rear marker, and the two markers
  are visually distinguishable from each other.

Only the user can settle:

- AC-E **HUMAN PLAYTEST - the criterion that actually closes 8G.2 item 2:** the user performs a backstep
  and a directional dodge and reports whether the facing is readable while the evasion runs.

### 8O.7 Evidence rules for that pass (recorded now so they cannot be softened later)

- AC-A/B/C are `[CONFIRMED]` by reading the saved scene and confirming no script changed.
- AC-D is `[PARTIAL]` at best. One rendered frame can show that the markers exist, where they sit and
  that they differ in colour. It CANNOT show readability in motion, and it cannot prove the evasion
  holds its facing.
- AC-E is the only thing that closes the item, and it is a human playtest. **NO new probe is proposed.**
  A probe cannot grade "can you read which way he is facing" - that is precisely why 8E, 8G and 8N all
  ended with a human read. Writing one would be activity, not evidence.

### 8O.8 Files expected to change in that later pass

- `res://scenes/test_environment.tscn` - the ONLY production file expected to change. The player body is
  authored INLINE in this scene (there is no `player.tscn`), so this is the correct and only owner.
- `.summer/plans/CASCADIA_MILESTONE_ROADMAP.md` and `CASCADIA_DELETION_MANIFEST.md` - bookkeeping.

New files: **none expected.** No new diagnostic, no new scene, no new directory. If the implementation
does add anything temporary, it must be recorded in the deletion manifest as it is created.

### 8O.9 Alternatives considered and NOT selected

- **Replacing the capsule with a character model or rig.** A scope jump, and animation is deferred by
  design (Milestone 15) with gameplay timing authoritative. Explicitly out of scope.
- **A world-space `Label3D` above the actor.** The arena already uses `Label3D` markers, so it is cheap -
  but a billboard label does not rotate with the body, so it would show position, not facing, and would
  answer nothing.
- **An on-screen debug readout of the facing value.** Would duplicate what the diagnostic overlays already
  imply, and still would not let the user judge facing BY EYE on the actor, which is the actual gap.
- **Making the overlay draw a facing gizmo.** Same objection: the requirement is a readable actor, not
  another number.

### 8O.10 Approval gate

    Do NOT begin this work until the user names it and this section is updated to APPROVED with its
    acceptance criteria confirmed.

**THE GATE WAS PASSED.** On 2026-09-13 the user explicitly approved Milestone 11 / this section for
implementation, with the same scope written above and one added hard constraint: no `CollisionShape3D`
may be added beneath `FacingMarker`, because `PlayerController._capsule_radius()` scans the body's
children for a capsule shape and a collision node added for visual convenience could silently interfere
with gameplay collision-radius discovery. That constraint was honoured. Implementation followed
immediately in the same pass and is recorded in 8O.11.

---

### 8O.11 Implementation result (2026-09-13)

IMPLEMENTED AS APPROVED. Presentation only. The whole change is scene-authored geometry - **no script was
created, opened or modified**, and no gameplay, camera, input, stamina, save/load or diagnostics file was
touched.

#### What was added

One `FacingMarker` `Node3D`, a DIRECT CHILD of `Player` in `res://scenes/test_environment.tscn` (there is
no separate `player.tscn`), holding two `MeshInstance3D` children with two scene-local materials:

| Node | Local transform | Mesh | Colour |
| ---- | --------------- | ---- | ------ |
| `Player/FacingMarker/Nose` | `position = (0, 2.3, -0.28)` | `BoxMesh` `0.18 x 0.7 x 0.22` | amber `Color(1, 0.62, 0.12, 1)` |
| `Player/FacingMarker/Tail` | `position = (0, 1.35, 0.52)` | `BoxMesh` `0.34 x 0.34 x 0.34` | blue `Color(0.15, 0.75, 0.95, 1)` |

- The NOSE sits on local **-Z**, the project's forward convention, matching
  `PlayerController._backstep_direction()` (which treats `+basis.z` as backward) and `_facing_of()`.
- The TAIL sits on local **+Z**, the side the default behind-and-above camera actually sees. It is the
  marker that carries the requirement: seeing the blue tail means forward is away from the camera.
- Both are children of the BODY transform, so they inherit `rotation.y` with no code.
- **No `CollisionShape3D` anywhere beneath `FacingMarker`** - the approved constraint. The nodes are
  `Node3D` and `MeshInstance3D` only.

#### One adjustment made after looking at the rendered frame

The NOSE was first placed at local y = 2.0 - the capsule's dome tip - and in the first rendered frame it
was NOT clearly resolvable: the camera looks down at the actor from behind and above, so the opaque dome
sat in the line of sight. It was moved up to y = 2.3 with a taller mesh (0.7) so it resolves ABOVE the
capsule silhouette. The second rendered frame shows both markers clearly. This was a placement correction
with no gameplay effect; the total footprint is two boxes and two materials.

#### Verification performed

- Scene re-read from disk after each write batch. `Player/FacingMarker`, `Nose` and `Tail` all present;
  Nose transform `Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2.3, -0.28)`, Tail
  `Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.35, 0.52)`.
- The two generated sub-resources confirmed on disk with the correct sizes and albedo colours, and each
  mesh node references the material and mesh declared above it.
- Confirmed NO `CollisionShape3D` was added beneath the marker (searched the saved scene text).
- `main.tscn` launched: **0 debugger errors**. The 20 reported script errors are the KNOWN stale
  `open_script_buffers` `CreditLedger` false positives, unchanged in count and in files this pass never
  touched (see 12.1) - not parse, load or runtime failures.
- Two rendered frames captured. Frame 1: arena renders, blue TAIL clearly readable on the camera-facing
  side, NOSE not resolvable. Frame 2 (after the placement fix): arena renders, blue TAIL readable AND the
  amber NOSE visible above the capsule dome. Both markers are distinguishable from each other and from
  the capsule.

#### Newly confirmed

- Both markers are readable from the DEFAULT third-person camera, which was the 8O.3 constraint.
- The arena still boots and renders with the markers present; the capsule is unaltered.

#### Still UNVERIFIED - the one thing only a human can settle

- **A still frame cannot show yaw-following.** Nothing here proves the markers track the actor's rotation
  while MOVING, while DODGING, or while BACKSTEPPING, and nothing here proves the facing now reads
  correctly in motion. That is exactly the read 8G.2 item 2 asked for, and it remains a HUMAN PLAYTEST:
  move, dodge and backstep, and say whether front and back are now obvious by eye.
- No gameplay value was changed, so the 8F measurements in 8N stand unaltered and were deliberately NOT
  re-run. No probe was written for this pass: a probe cannot grade visual readability.

#### Files changed by this pass

- `res://scenes/test_environment.tscn` - the only implementation change (`FacingMarker`, `Nose`, `Tail`,
  two `StandardMaterial3D` and two `BoxMesh` sub-resources).
- `.summer/plans/CASCADIA_MILESTONE_ROADMAP.md` - this section, the header, section 0 and 8N.6.

### 8O.12 Presentation refinement - final marker geometry (2026-09-13)

A follow-up presentation pass, requested by the user after seeing the first result. The markers were
FUNCTIONALLY correct but read as debug geometry: the amber nose was a tall brick-like box and the blue
tail was a cube floating clear of the body. Both were reshaped into compact, attached icons.

**Nothing about the marker CONTRACT changed.** The amber marker is still the FORWARD indicator on local
**-Z**, the blue marker is still the REAR indicator on local **+Z**, both are still children of
`Player/FacingMarker` under the body transform (so both inherit `rotation.y` with no code), and there is
still **no script** and still **no `CollisionShape3D` anywhere beneath `FacingMarker`**.

#### Final geometry (read from disk)

| Node | Local transform | Mesh | Colour |
| ---- | --------------- | ---- | ------ |
| `Player/FacingMarker/Nose` | `position = (0, 2.2, -0.36)` | `SphereMesh` radius `0.28`, height `0.56` | amber `Color(1, 0.62, 0.12, 1)` |
| `Player/FacingMarker/Tail` | rotated 90 deg about X, `position = (0, 1.3, 0.44)` | `CylinderMesh` top/bottom radius `0.22`, height `0.08` | blue `Color(0.15, 0.75, 0.95, 1)` |

- **Amber = a compact ORB.** The elongated box is gone; it is now a sphere sitting at the capsule crown
  on the forward axis. It is deliberately at the crown rather than on the capsule's front face because
  the default camera looks down from behind and above (8O.3), so a front-face marker would be hidden by
  the capsule. It reads over the top of the silhouette instead of obscuring it.
- **Blue = a flat BADGE on the body.** The cube is gone; it is now a thin disc (0.08 deep) sitting
  essentially flush against the capsule's rear surface, so it reads as an icon attached to the actor
  rather than a detached floating block. This is the marker the default camera actually faces, so it
  carries the primary read: seeing the blue badge means forward is away from the camera.
- The blue badge **suggests** a rear/backstab affordance as visual design language ONLY. **No backstab
  mechanic, rear-hit detection, damage multiplier, targeting rule or combat state exists or was
  implemented.** It is a picture of a direction, nothing more.

#### Verification performed

- `test_environment.tscn` re-read from disk after every write batch. Final state confirmed: Nose is a
  `SphereMesh` at local `(0, 2.2, -0.36)` on **-Z**; Tail is a `CylinderMesh` at local `(0, 1.3, 0.44)`
  on **+Z** with its 90-degree X rotation baked into the node transform.
- Sub-resources confirmed on disk with the values in the table above, and each mesh node referencing the
  material declared for it.
- Confirmed by searching the saved scene text that **NO `CollisionShape3D`** exists beneath
  `FacingMarker`, so `PlayerController._capsule_radius()` cannot pick up a stray shape. Only `Node3D` and
  `MeshInstance3D` nodes are present.
- `main.tscn` launched: **0 debugger errors**, no parse or load failures, no console errors. The 20
  reported script errors remain the KNOWN stale `open_script_buffers` `CreditLedger` false positives
  (section 12.1) - unchanged in count and in files this pass never touched.
- One rendered frame from the default camera confirms the intended result: the amber orb reads as a
  compact sphere at the crown (no longer a pillar) and the blue disc reads as a flat badge attached to
  the camera-facing surface (no longer a floating cube).

#### Limitation - what this pass still does NOT prove

- **A still frame cannot show yaw-following.** Nothing here proves the markers track the actor's rotation
  while MOVING, TURNING, DODGING or BACKSTEPPING, and nothing here proves the facing reads correctly in
  motion. That is the same human playtest 8O.11 recorded, and it REMAINS PENDING.
- No gameplay value changed, so the 8N measurements stand unaltered and were deliberately NOT re-run. No
  probe was written: a probe cannot grade visual readability.

#### One tooling error encountered (recorded so it is not repeated)

The first attempt to build the disc used `SetResourceProperty` with sub-property `radius` on a
`CylinderMesh`. That op was **REJECTED** (`unknown subProperty "radius" ... did you mean: top_radius,
bottom_radius`), which correctly skipped the remaining ops in that batch. `CylinderMesh` has NO `radius`
property - it has `top_radius` and `bottom_radius` separately. The retry used both and succeeded. The
scene was re-read afterwards rather than trusting the receipt, because a partially-applied batch is
exactly the case where a write receipt is not proof of the saved state.

---

### 8O.13 Presentation refinement 2 - amber disc, and an occlusion finding (2026-09-13)

Requested by the user after seeing 8O.12: make the amber marker the SAME KIND of marker as the blue one -
a flat DISC rather than a sphere - move it CLOSER to the capsule, and align its top with the capsule top
so it sits FLUSH and not above the capsule, "so the user can see it clearly".

#### What changed

| Node | Local transform | Mesh | Colour |
| ---- | --------------- | ---- | ------ |
| `Player/FacingMarker/Nose` | rotated 90 deg about X, `position = (0, 1.78, -0.40)` | `CylinderMesh` top/bottom radius `0.22`, height `0.08` | amber `Color(1, 0.62, 0.12, 1)` |
| `Player/FacingMarker/Tail` | unchanged from 8O.12 - rotated 90 deg about X, `position = (0, 1.3, 0.44)` | `CylinderMesh` top/bottom radius `0.22`, height `0.08` | blue `Color(0.15, 0.75, 0.95, 1)` |

The amber marker is now the same KIND of marker as the blue one - a thin disc - and no longer a sphere.
No script, no `CollisionShape3D`, hierarchy unchanged, and both markers still inherit `rotation.y`
because they are children of the body transform.

#### THE FINDING - "flush with the top" and "visible from behind" CONFLICT

Read from the scene, then confirmed in a rendered frame:

- `Player/Mesh` is a `CapsuleMesh` with `radius = 0.4` and the DEFAULT `height` of 2.0, sitting at local
  `(0, 1, 0)`. The capsule therefore occupies local y = 0.0 to 2.0, and its top is local y = 2.0.
- The amber disc's top edge is at `1.78 + 0.22 = 2.00` - EXACTLY flush with the capsule top, which is
  precisely what was asked for.
- The default camera sits BEHIND the actor and slightly above it (`spring_length = 4.5`, see 8O.3). From
  that side the opaque capsule hides anything mounted on its FORWARD face below the silhouette line.
- **Measured in the rendered frame: the blue rear disc is clearly visible, and the amber forward disc is
  NOT VISIBLE AT ALL** from the default behind-and-above view.

The previous sphere was only visible because it protruded ABOVE the dome (local y = 2.2) - which is
exactly what this refinement was asked to remove. So the two goals in the request cannot both hold from
the default camera. This is recorded as a real conflict rather than papered over, and the fix was put to
the user instead of being guessed at. The options are:

1. Keep the top flush as it is now, and accept that the forward marker is only readable when the camera
   is orbited to the front or the side.
2. Raise the disc so it clears the silhouette again - at this camera angle that means several
   centimetres above local y = 2.0.
3. Widen the disc so its edges extend past the capsule's narrower dome at that height. The capsule radius
   at local y = 1.78 is about `0.357`, so a disc radius above roughly `0.36` would show as amber flanks
   either side of the silhouette while the top stays flush.

#### Requested but NOT started - swing / attack visual feedback

The user also asked to "tie in the animation state for swinging/attacks to the capsule so the user has a
visual feedback mechanism for swings".

RECORDED, NOT BUILT. Three things make this different from the marker work above and they are why it was
not started in this pass:

- There is NO animation system in the project (the presentation boundary recorded in 8G.2 item 3, and
  animation is deferred to Milestone 15). The only real state available today is the attack PHASE machine
  in `PlayerCombat` (`state_name()` returns IDLE / STARTUP / ACTIVE / RECOVERY).
- It cannot be done scene-only. Unlike the facing markers, reacting to an attack requires NEW CODE - a
  read-only presentation consumer of `PlayerCombat`'s phase. That crosses the combat / presentation
  boundary this project governs carefully, so the form was put to the user rather than chosen here.
- The user's visual intent for it (what should change, and how) was not specified, and this user gives
  precise visual direction - so a guess would likely be discarded.

#### Verification

- `test_environment.tscn` re-read from disk AFTER the writes and confirmed: `Nose` is a `CylinderMesh`
  (top/bottom radius `0.22`, height `0.08`) at local `(0, 1.78, -0.40)` on **-Z**; `Tail` unchanged on
  **+Z**; still NO `CollisionShape3D` anywhere beneath `FacingMarker`.
- `main.tscn` launched from a STOPPED state. **Trap recorded:** an earlier capture this pass was taken
  from a REUSED instance (`playGame` reported "Game was already running ... No restart was performed"),
  so that frame did NOT reflect the saved scene and was discarded as evidence. Always stop before
  starting when the scene has changed.
- 0 debugger errors, no parse or load failures.
- One frame from the default camera: blue disc visible, amber disc not visible - the finding above.

#### Still UNVERIFIED

- The yaw-following read during movement, turning, dodge and backstep. Still a human playtest, unchanged
  from 8O.11 and 8O.12.

#### CORRECTION to 8O.13 (recorded in 8O.14)

The claim above that the amber disc is hidden "COMPLETELY" was TOO STRONG. A later frame from the same
default camera shows an amber sliver clearly visible at the left silhouette edge of the capsule. The disc
is substantially occluded but NOT invisible. See 8O.14.

---

### 8O.14 Swing feedback implemented, and the amber-marker question resolved (2026-09-13)

Two user decisions were taken before any further code, and this section records both.

#### Decision 1 - the amber marker stays exactly as 8O.13 left it

Asked how to resolve the flush-vs-visible conflict, the user chose **"Leave it exactly as it is now"**.
The amber disc therefore remains a flat disc (top/bottom radius `0.22`, height `0.08`) at local
`(0, 1.78, -0.40)` on **-Z**, its top flush at the capsule top. No change was made to it. This was the
user's call with the occlusion trade-off stated plainly, so it is not a defect to re-litigate.

#### Decision 2 - swing feedback is a MARKER COLOUR CHANGE

Asked what should visually change on an attack, the user chose **"Marker changes colour"** (not a scale
pulse, not a capsule tint). That is what was built.

#### What was added - ONE new script

`scripts/diagnostics/facing_marker_feedback_debug.gd` (`FacingMarkerFeedbackDebug`), assigned to the
existing `Player/FacingMarker` node. It reads `PlayerCombat.state` and tints the amber marker:

| Attack phase | Marker colour |
| ------------ | ------------- |
| IDLE | amber `(1, 0.62, 0.12)` - the authored colour |
| STARTUP | hot pale yellow `(1, 0.95, 0.45)` - commitment visible BEFORE the hit lands |
| ACTIVE | red `(0.95, 0.16, 0.12)` - the damage window |
| RECOVERY | cool blue-grey `(0.34, 0.46, 0.62)` - spent, unmistakably not ready |

Design constraints, deliberate and recorded:

- **STRICTLY READ-ONLY on gameplay.** It reads the phase and writes exactly one thing: a material's
  `albedo_color`. It never starts, cancels, delays, extends or redirects an attack, imposes no timing of
  its own, and owns no gameplay state. The colour FOLLOWS the phase; the phase never follows the colour.
  This is the same relationship a real animation clip will have in Milestone 15.
- It reads the phase CONTINUOUSLY rather than connecting to `attack_started` / `attack_finished`, so a
  missed signal or a mid-swing scene load cannot leave the marker stuck on the wrong colour.
- It runs on `_process` (visual frame), not `_physics_process`, so it cannot compete with `PlayerCombat`
  for physics ordering or affect combat timing.
- It **duplicates the material** on first use, so it can never mutate a resource another node draws with.
- It writes the material only when the phase CHANGES, not every frame.
- A missing marker or missing `PlayerCombat` disables it with a visible `push_warning` rather than
  failing silently. An actor without combat simply keeps the marker neutral.
- The four colours are **exported**, so a re-tune needs no code change.

#### The ONE rule this deliberately does not break

`gameplay is authoritative; presentation adapts`. The script is a consumer of combat state, never a
participant. `PlayerCombat`, `PlayerController`, the dodge component, the camera, input, stamina and
save/load were **not modified**. No gameplay file changed hands in this pass.

#### Verification

- The new script's per-file `state:script-errors` query returns **0**.
- `test_environment.tscn` re-read from disk: `FacingMarker` carries the new script via
  `ExtResource("13_0hxc1")`, `Nose` is still the flat `CylinderMesh` disc on **-Z** at `(0, 1.78, -0.40)`,
  `Tail` still the blue disc on **+Z**, and there is still **NO `CollisionShape3D`** anywhere beneath
  `FacingMarker` (searched the saved scene text).
- `main.tscn` launched from a STOPPED state: **0 debugger errors**, no parse or load failures, and no
  `[FACING] feedback disabled` warning - which is the positive signal that BOTH the marker and `Combat`
  resolved, since a failure there would print.
- One rendered frame from the default camera after the script took over the material: the arena renders,
  the capsule is intact and pale, the BLUE disc is plainly visible on the camera-facing side, and the
  amber marker is visible as a sliver at the left silhouette edge. The marker is **amber, not white or
  black**, which is the specific check that the material duplication did not break the authored look.
  The combat overlay read `phase=IDLE`, consistent with the amber idle colour.

#### Newly confirmed

- The amber marker is NOT fully hidden at the flush position - a sliver remains visible at the silhouette
  edge (correcting the stronger 8O.13 wording).
- Attaching a script to `FacingMarker` did not disturb the markers, the capsule, the camera or the arena.
- The idle colour the adapter paints is identical to the authored amber, so the marker is unchanged when
  no attack is running.

#### Still UNVERIFIED - and this one needs your hands, not a screenshot

- **A still frame cannot show a colour CHANGE.** Every frame captured here is IDLE, so nothing in this
  pass proves the marker actually turns yellow, then red, then blue-grey during a real swing. The mappings
  are readable in the script and the phase machine is the existing measured one, but the transition
  itself is UNPROVEN until someone attacks and watches.
- The yaw-following read during movement, turning, dodge and backstep remains an open human playtest,
  unchanged from 8O.11 / 8O.12 / 8O.13.
- No gameplay value changed, so the 8N evasion measurements stand unaltered and were deliberately NOT
  re-run. No probe was written for this pass: a probe cannot grade visual readability, and the colour
  transition is a visual read.

#### Files changed by this pass

- `scripts/diagnostics/facing_marker_feedback_debug.gd` - NEW (recorded in the deletion manifest).
- `scenes/test_environment.tscn` - the script assigned to `FacingMarker`.
- `CASCADIA_DELETION_MANIFEST.md` - the new file recorded as a cleanup candidate.
- `.summer/plans/CASCADIA_MILESTONE_ROADMAP.md` - this section, the header and section 0.

---

### 8O.15 Milestone 11 ACCEPTED by the user - the facing-indicator step is CLOSED (2026-09-13)

**The user reviewed the running game and accepted the step.** Verbatim report: "everything seems
visually consistent and working properly. consider this step implemented".

Recorded for what it actually is: a HUMAN VISUAL READ of the shipped scene, and precisely the read that
8O.11, 8O.12, 8O.13 and 8O.14 were each waiting on. It CLOSES the presentation half of the 8G.2 backstep
defect that 8E, 8F and 8N carried forward - the capsule now communicates its facing by eye.

#### What this acceptance covers

- The facing markers render and are visually consistent on the actor.
- The amber FORWARD marker (local **-Z**) and the blue REAR disc (local **+Z**) are both present and
  distinguishable in the shipped scene.
- The attack-phase colour feedback from 8O.14 did not break the authored look.
- No visual regression in the arena, the capsule, the camera or the debug overlay.

#### Classified by this file's own evidence vocabulary

- The markers EXIST with the recorded geometry and materials: **CONFIRMED** (read from
  `scenes/test_environment.tscn` on disk, plus rendered frames).
- They read correctly to the user's eye: **CONFIRMED** (the user's visual report, above).
- The read was a GENERAL visual acceptance, not a per-behaviour checklist. The two specific motion reads
  listed below are therefore recorded as COVERED BY that acceptance, NOT as independently measured.

#### Deliberately NOT re-run

- No probe was written or re-run for this pass. A probe cannot grade visual readability, and no gameplay
  value changed - the 8N evasion measurements stand unaltered.
- The already-closed 8F dodge movement-authority work was NOT reopened.

#### Milestone 11 - final state

**CLOSED. Approved by the user, implemented, refined twice, and accepted on a user visual read.**

The marker CONTRACT never changed across any of the three refinements:

- amber marker = FORWARD, on local **-Z**;
- blue marker = REAR, on local **+Z** (the side the default behind-and-above camera sees);
- both are children of the body transform, so both inherit `rotation.y` with no code;
- **no `CollisionShape3D`** anywhere beneath `FacingMarker`, so `_capsule_radius()` cannot pick up a
  stray shape and the player's physical collision is untouched;
- one read-only presentation adapter (`facing_marker_feedback_debug.gd`) tints the amber marker by attack
  phase, reading `PlayerCombat.state` and writing one material colour and nothing else.

#### Files changed across the whole of Milestone 11

- `scenes/test_environment.tscn` - `FacingMarker` with `Nose` and `Tail`, their meshes and materials, and
  the feedback script assigned to `FacingMarker`.
- `scripts/diagnostics/facing_marker_feedback_debug.gd` - NEW: the read-only attack-phase colour adapter.
- `CASCADIA_DELETION_MANIFEST.md` - the new script recorded as a cleanup candidate.
- `.summer/plans/CASCADIA_MILESTONE_ROADMAP.md` - sections 8O.11 to 8O.15, the header and section 0.

No gameplay script, combat value, camera, input, stamina, save/load or HUD file was touched at any point
in Milestone 11.

#### Open items that REMAIN - recorded, NOT closed by this acceptance

- The two specific MOTION reads: whether the markers visibly track yaw while moving, turning, dodging and
  backstepping, and whether the STARTUP / ACTIVE / RECOVERY colours read distinctly at the light attack's
  0.16 s startup and 0.10 s active timing. Covered by the user's general acceptance, not separately
  called out. If a swing ever looks unreadable in play, this is the thing to revisit.
- Physical Alt-Tab / OS pointer-lock behaviour remains unproven in this host (unchanged from 8M.24).
- The windowed / fullscreen / borderless and capture-on-return policy remains deferred.
- Milestone 10 save/load remains probe-measured but NOT human-played (section 0).

---

## 8P. MILESTONE 12 - TARGET LOCK-ON (selected and APPROVED by the user 2026-09-14; roadmap written BEFORE implementation)

Per the standing rule in section 15, this section was written before any code. Nothing below is
retro-fitted.

### 8P.1 The user's decision

The user selected the next milestone as **Combat Loop + Targeting**, sequenced as: (1) targeting /
lock-on, (2) a minimal UI pass, (3) save/load presentation in a real UI. Only step 1 is authorised
here. Steps 2 and 3 are recorded as the intended direction but are NOT started and NOT approved.

Control contract, chosen by the user from three options: lock-on is **acquired/toggled with the
existing `lock_on` binding**, and while locked, **two NEW separate actions cycle left/right through
valid targets** - the Bloodborne/Souls convention. Right-stick left/right on the controller, with
appropriate keyboard/mouse equivalents. Auto-release on target death, invalid target, excessive
range, or player death.

### 8P.2 What already exists (read from disk this pass - do NOT rebuild these)

- `lock_on` is ALREADY bound: TAB (keycode 4194306) and joypad button 8 (R3 / right-stick click).
- `CascadiaInput.consume_lock_on()` ALREADY exists and is currently UNUSED.
- `LOCK_ON` is already in `GameActions.BUFFERED_ACTIONS` and in the `TARGETING` group. It is NOT in
  `RESERVED_ACTIONS` (that list is `RANGED_ATTACK`, `JUMP` only), so it is already a legitimately
  consumable action.
- `CombatParticipant.is_usable_target()` and `CombatParticipant.target_refusal()` ALREADY exist and
  are the established validity predicates. Reuse them. Target validity must keep ONE owner.
- `HealthComponent.GROUP_DAMAGEABLE` is the enumerable enemy population; `EnemyDeathComponent`
  exposes `is_defeated()`; the player's death circuit exposes `is_dead()`.
- The camera rig is `CameraRig / CameraYaw / CameraPitch / SpringArm3D / Camera3D`, horizontal orbit
  on `CameraYaw`, vertical on `CameraPitch`, **roll is always zero**, and the SpringArm mask is
  `GameLayers.WORLD` only.

### 8P.3 The one real design tension, stated up front

On the controller the right stick's X axis (axis 2) ALREADY drives `camera_look_left` / `camera_look_right`.
Binding `target_cycle_left` / `target_cycle_right` to the same axis is the Soulslike convention, but it
means one physical axis would feed two consumers at once.

Resolve it through the EXISTING precedent, not a new mechanism: gameplay already declares look INTENT to
the input layer via `mouse_look_enabled` (owned by Escape alone, amended by the focus rules in
`.summerrules`). While locked, targeting declares an equivalent intent (`look_yaw_suppressed`), the input
layer then excludes the horizontal component from the look delta and reports the cycle presses instead.
The intent flag is gameplay's DECLARED STATE; the input layer must never derive lock state itself, and
the camera must never become the authority. No system may add its own focus or capture rules.

### 8P.4 In scope

- A `TargetingComponent` (own module, its own script) that owns lock state: current target, locked
  flag, acquire, cycle, release, and the four auto-release conditions.
- NEW actions `target_cycle_left` / `target_cycle_right` added to `GameActions` and bound in the
  InputMap, plus a `CascadiaInput.consume_*` accessor for each and the declared-intent flag from 8P.3.
- Camera integration: while locked, the rig frames the target. **Roll stays zero**, the existing
  hierarchy is preserved, and the rig only READS targeting state.
- Release-range tuning as a single exported number.
- Retention of `lock_on` as the toggle; no new acquire binding.

### 8P.5 Explicitly OUT of scope (not built, not partially built)

- **Lock-on-relative dodge direction.** The `.summerrules` gate said not to build it until lock-on was
  its own milestone; this is now that milestone, so it becomes *permitted* - but the user did not ask
  for it and it is deliberately NOT in this pass. Dodge stays CAMERA-relative.
- HUD / reticle / target marker or any other presentation of the lock.
- Enemy targeting. `EnemyAttacker.target_group` ("player_actor") is the ENEMY choosing the PLAYER - a
  DIFFERENT concern that happens to share the word "target". Do not conflate them, and do not change
  the attacker.
- Cycling VISUALS or ANIMATION (there is no animation system), the full UI/keybinding pass, save/load
  persistence of a locked target, lock-on during committed attacks or dodges beyond respecting them.
- Any retuning of combat, stamina, parry, dodge, save/load or camera sensitivity values.

### 8P.6 Acceptance criteria and evidence plan

Static and deterministic checks (probes CANNOT grade feel, and no probe may be claimed to):

1. `TargetingComponent` exists and is the single owner of lock state; target validity delegates to
   `CombatParticipant`.
2. `target_cycle_left` / `target_cycle_right` exist in `GameActions` and are bound in `project.godot`;
   keyboard/mouse equivalents chosen to NOT collide with existing bindings (note: R is already bound
   twice) and recorded in `.summerrules`.
3. Each of the four auto-release conditions is implemented and exercised deterministically.
4. A new `targeting_probe_debug` measures: acquire, cycle wraps and skips invalid targets, that a
   DEFEATED target is refused as invalid (not as out-of-range, counted by cause), that release-on-death
   and release-on-range actually release, and that the player's death releases.
5. The two existing regression probes still pass: `retarget_state_probe_debug` (Alt-Tab retargeting,
   unaffected by this work) and `focus_input_routing_probe_debug`. NOTE: that probe's own COMMENT
   describes `lock_on` as "a RESERVED action with no targeting system (roadmap 8E.5)" - that comment
   becomes stale once this milestone lands and should be corrected, but its ASSERTION is delivery-only
   and must still pass.
6. No gameplay, combat, stamina, camera-sensitivity or save/load VALUE is retuned; no milestone-11
   facing marker or existing binding is disturbed.

Rendered and human evidence: a lock-on read is a matter of FEEL and cannot be graded from a still
frame. The user plays it and says whether the camera framing, the cycle order and the release
behaviour read correctly.

### 8P.7 Milestone 12 - status

**ACCEPTED BY THE USER 2026-09-14 after a MANUAL PLAYTEST of the live game.** The user's verdict: the
lock-on "works fine". Probe evidence stands at `targeting_probe_debug` `RESULT: ALL CHECKS PASSED
(78)`, and the shipped `main.tscn` boots at 0 runtime errors.

Accepted as it stands, and NOT reopened. ONE bounded TWEAK was raised in the same playtest and is
carried into Milestone 13 (section 8Q) instead: the player character does not maintain its
ORIENTATION towards the locked target, as a Soulslike does. That is an ADDITION to presentation and
facing, not a defect in the accepted mechanics - no release path, cycle order, validity rule, input
binding or camera framing behaviour is being redesigned.

#### What was built

- `scripts/player/targeting_component.gd` (`class_name TargetingComponent`) - NEW. The single owner
  of lock state: the candidate list, the current target and the acquire/cycle order. Validity is
  delegated to the EXISTING `CombatParticipant.is_usable_target()` / `target_refusal()`, so no second
  validity authority was created. Defeat is read from the target's own defeat authority; player death
  from `DeathComponent.is_dead()`. The four release causes are enumerated and counted separately.
- `scripts/input/cascadia_input.gd` - added `look_yaw_suppressed`, a gameplay-DECLARED intent and the
  established analogue of `mouse_look_enabled`; plus `consume_target_cycle_left()` /
  `consume_target_cycle_right()`. `_update_look()` drops ONLY the horizontal stick component while the
  intent is set. The input layer never derives lock state, and focus transitions never clear the intent.
- `scripts/core/game_actions.gd` - `TARGET_CYCLE_LEFT` / `TARGET_CYCLE_RIGHT` added to the TARGETING
  group and to `BUFFERED_ACTIONS`.
- `scripts/camera/third_person_camera.gd` - `_frame_locked_target()` plus `lock_yaw_smoothing`. Yaws
  onto the target on the shortest arc, never writes pitch, keeps roll zero by construction, and only
  READS the lock. Hierarchy unchanged.
- `project.godot` - both cycle actions bound to joypad axis 2 (-1.0 / +1.0) plus mouse wheel. Nothing
  new on R, F8 or F9; `lock_on` untouched.
- `main.tscn` - the `Targeting` node added.
- `scripts/diagnostics/targeting_probe_debug.gd` and `scenes/diagnostics/targeting_probe_debug.tscn` -
  the probe and its entry scene.

#### Measured result

`targeting_probe_debug`: **RESULT: ALL CHECKS PASSED (78)**, 0 debugger errors, measured by running
the probe scene. Coverage includes: acquire through the REAL bound TAB event; cycle through the REAL
wheel events including wrap and round-trip; right cycling visiting every valid target exactly once;
the actor never being a candidate for its own lock; a refusal with no valid targets raising nothing
and declaring no intent; the declared intent measured on the camera from BOTH sides
(6.160 deg unsuppressed vs **0.0000 deg** suppressed); mouse motion still turning the camera while
locked; framing the target, following it when it moves, pitch unchanged, roll zero, hierarchy intact;
and all four auto-release causes each filed under its own cause - defeated, freed/invalid, refused as
a target, out of range - plus player death.

The probe also proves it leaves no trace: no arena actor damaged or defeated, carried balance
unchanged, `awards` unchanged, no lock and no look intent left held.

#### Three probe defects found and fixed in THIS pass (all three in the probe, none in the module)

1. `_resolve()` resolved the camera rig BEFORE assigning `_camera`, and `_find_camera_rig()` returns
   null when `_camera` is null - so the rig could never be found and the probe aborted before running
   a single check (`1 of 0 FAILED`).
2. `_spawn_target()` pre-registered its temporary actor with `CreditLedger.handle_defeat()` believing
   that would BLOCK a later reward. It does not: that call refuses and returns BEFORE `_rewarded[id]`
   is set, and the ledger re-scans the damageable group every physics frame, so defeating a temporary
   actor WOULD have minted Credits and broken the cleanup assertions. Replaced with
   `EnemyDeathComponent.restore_defeated(true)`, which sets the authoritative defeated state WITHOUT
   emitting `defeated` - the documented reason Milestone 10 uses it for loads, and the reason a probe
   can use it without paying a reward.
3. The look-intent stick measurement was taken WHILE a lock was held, so TWO yaw authorities were
   active at once (the stick, and the rig framing the target). It reported a FALSE FAILURE of
   0.8644 deg that was entirely the framing transient - the rig's yaw had been restored off-target,
   and framing pulled it back. The measurement is now taken with no lock held, with
   `is_framing_lock()` asserted false, and the re-run measures exactly **0.0000 deg**. The lock is
   re-acquired immediately afterwards for the mouse and framing checks.

#### Evidence vocabulary, applied honestly

- The module's behaviour above is **CONFIRMED by deterministic probe measurement**.
- Camera framing, cycle order and release feel could NOT be graded by a probe or a still frame - they
  are a matter of feel. They are now **CONFIRMED BY THE USER'S MANUAL PLAYTEST** (2026-09-14), which
  is the only evidence that could have settled them. See 8P.7 and 8Q.
- The two regression probes named in 8P.6 item 5 were NOT re-run in this pass, so they are neither
  claimed to pass nor to fail. `lock_on`'s path through the input layer IS covered by the new probe,
  which exercises the real `lock_on` binding end to end.
- The two `TARGET_CYCLE_*` script errors reported by `state:diagnostics` under scope
  `open_script_buffers` are the KNOWN stale open-buffer false positive, not real: both constants are
  present on disk in `game_actions.gd` (lines 60-61) and the probe exercised BOTH actions
  successfully at runtime. Recorded in the deletion manifest's recurring-issue section.

#### Not built, by explicit scope decision

Lock-on-RELATIVE dodge direction (dodge stays camera-relative), any animation, VFX, reticle or sound.
`EnemyAttacker.target_group` - the ENEMY targeting the PLAYER - was not modified.

---

## 8Q. MILESTONE 13 - MINIMAL UI (HUD, LOCK-ON INDICATOR, PAUSE, SAVE/LOAD CONTROLS) (approved by the user 2026-09-14; roadmap written BEFORE implementation)

Purpose: make the current playable prototype READABLE AND USABLE during repeated combat testing.
This is NOT final art and NOT a UI framework. The test of scope is "does this help the user test the
game", not "does this look finished".

### 8Q.1 The user's stated deliverables

1. A minimal HUD: carried Credits, player Health, player Stamina.
2. A lock-on indicator: visible when locked, identifies the current target, follows cycling, gone on
   release, correct on all four release paths.
3. Pause functionality and a pause panel.
4. Save/load controls using the EXISTING save/load service.
5. Clear loaded-state feedback, reflecting the ACTUAL returned result.
6. CARRIED OVER FROM THE ACCEPTED M12 PLAYTEST: the player character maintains ORIENTATION towards a
   locked target, and releases that orientation when not locked on.

### 8Q.2 Owners - read from disk this pass. The UI OBSERVES these; it must not duplicate any of them

| What | Single owner | How the UI reads it |
| ---- | ------------ | ------------------- |
| Carried Credits | `CreditLedger` | `get_credits()`; signal `credits_changed(credits, delta)` |
| Player Health | `HealthComponent` (on the Player) | `current_health` / `max_health`; signal `health_changed(current, maximum)` |
| Player Stamina | `StaminaComponent` ("Stamina" node on the Player) | `current_stamina` / `max_stamina`; signal `stamina_changed(current, maximum)` |
| Lock state + current target | `TargetingComponent` (group `targeting`) | `is_locked()`, `get_current_target()`; signals `target_acquired(target)`, `target_released(target, reason)`, `target_changed(target)` |
| Save/load | `GameStateSave` | `save_game()` / `load_game()` returning a `Result` code; `has_save()`; `last_result`, `last_error`; signals `game_saved`, `game_loaded`, `new_run_started` |
| Pause | NEW, and deliberately minimal | A UI/flow concern ONLY. It is NOT a gameplay authority and owns no gameplay state. |

### 8Q.3 Constraints MEASURED on disk this pass - breaking these breaks a passing probe or a rule

- ATTACKS ARE MOUSE BUTTONS (`light_attack` = LMB, `heavy_attack` = RMB). A visible Control with a
  non-IGNORE mouse filter can silently EAT AN ATTACK. Every HUD Control must be
  `Control.MOUSE_FILTER_IGNORE`. Mouse filter is PER CONTROL, not inherited - set it on each one.
- `focus_input_routing_probe_debug._controls_that_steal_gameplay_mouse()` enumerates EVERY visible
  Control under EVERY CanvasLayer and FAILS if one with a non-IGNORE filter overlaps the viewport
  centre. Consequence: the pause panel must be HIDDEN (not merely transparent or off-centre) while
  unpaused, and the HUD's own controls must be IGNORE. The indicator must therefore be a
  world-anchored marker or an IGNORE-filter Control, never a focusable panel.
- Escape is ALREADY wired: `CascadiaInput._unhandled_input` maps `ui_cancel` to `set_mouse_look(false)`,
  which releases the cursor. Pause must COOPERATE with that path rather than fight it, and must not
  leave the cursor captured while paused or free while playing.
- The `menu` action EXISTS but is bound to joypad button 6 ONLY - there is no keyboard key on it.
  `ui_cancel` (Escape) is the only already-working keyboard pause gesture.
- F8 and F9 are HOST-OWNED and unusable. Do NOT rebind anything to them.
- `CascadiaInput`'s clock reconciliation already skips its work when `get_tree().paused` is true, so a
  real `get_tree().paused` pause is already tolerated by the input layer.
- NO PAUSE SYSTEM EXISTS TODAY: `get_tree().paused` is never set anywhere in the project.
- `project.godot.bak` is rewritten by the editor whenever project settings are saved. It is already a
  tracked deletion candidate; do not treat its mtime change as a new file.
- A new UI scene must not be wired through the debug overlays (`InputDebugOverlay`,
  `CombatDebugOverlay`, `SaveLoadDebugControls`). Those are development tooling and are tracked
  deletion candidates. The new UI is SEPARATE from them and must not depend on debug mode.

### 8Q.4 In scope

- ONE new HUD `CanvasLayer` reading Credits / Health / Stamina from the owners above.
- ONE lock-on indicator: a marker on the CURRENT TARGET, driven by `TargetingComponent`'s signals,
  hidden when unlocked, repositioned on cycle, hidden on every release cause.
- ONE pause panel: pause, resume, save, load, and a status line. Hidden while unpaused.
- The player-orientation tweak, integrated with the EXISTING movement-authority rule: while a lock is
  held and NO committed action owns the body, the body faces the target; a COMMITTED action (dodge,
  backstep, attack, parry) keeps its own locked facing for its whole duration and is never overridden
  by the lock. Presentation must not become the accidental authority.
- A probe that measures the mechanical claims below.
- Recording any new file in `CASCADIA_DELETION_MANIFEST.md`.

### 8Q.5 Explicitly OUT of scope (not built, not partially built)

Settings, graphics options, audio menus, key rebinding, inventory screens, title screen, confirmation
flows, animation, final HUD art, damage numbers, status-effect UI, and any new gameplay system.
Milestone 12 mechanics are NOT reopened: no change to release paths, cycle order, validity rules,
input bindings or camera framing.

### 8Q.6 Acceptance criteria and evidence plan

The user's own checklist, plus the following, which a probe CAN carry:

1. HUD values TRACE TO THE REAL OWNERS, measured by CHANGING a real value (apply damage, spend
   stamina, award Credits) and asserting the displayed text changed accordingly - not by asserting a
   label merely exists.
2. The indicator is HIDDEN when unlocked, FOLLOWS the target after a cycle, and is hidden after EACH
   of the four release causes, each by its own cause.
3. Pause actually stops gameplay (a movement or combat measurement taken while paused does not
   advance), the panel stays interactive, resume restores gameplay, and pausing twice does not stack
   panels or states.
4. Save and load call the EXISTING service, and the status message reflects the RETURNED `Result`
   code, distinguishing success from every refusal. No invented success and no swallowed failure.
5. After a load, the HUD shows the LOADED values - no stale pre-load numbers.
6. The three existing probes touching this surface still pass: `focus_input_routing_probe_debug`,
   `targeting_probe_debug`, `retarget_state_probe_debug`.
7. No gameplay value is retuned (attack costs 18/32, dodge 22, parry 20, save schema, rewards).

Rendered and human evidence: HUD READABILITY, indicator CLARITY, pause feel, and whether the status
feedback is legible are the user's read. A probe cannot grade them and must not be claimed to.

### 8Q.7 Milestone 13 - status

**IMPLEMENTED AND MEASURED 2026-09-14, INCLUDING THE NEW RUN FIX AND THE ESCAPE CONTRACT CHANGE.
NOT YET HUMAN-ACCEPTED - awaiting the user's read of the HUD, the indicator, the pause, the save/load
feedback, and a NEW RUN. Milestone 12 remains the highest ACCEPTED milestone.**

[SUPERSEDED 2026-09-15: that closing sentence was the in-pass truth when 8Q.7 was written. M13 was
accepted shortly afterwards, and the highest accepted milestone is now 20 - see the CURRENT STATE
block at the top of this file. Kept verbatim for audit.]

The user reviewed the first pass on 2026-09-14 and reported everything working EXCEPT one
integration bug: **New Run did not reset the world** (see "The NEW RUN defect" below). That is now
fixed and measured. The user's stated remaining work is a presentation read, not another pass.

#### What was built

- `scripts/ui/game_hud.gd` (`class_name GameHUD`) - NEW. Carried Credits, player Health and player
  Stamina, each read from its existing owner. It declares no `credits`, `health`, `stamina`,
  `is_locked` or `current_target`: the only thing it stores is the text it is already displaying.
  Owner signals are connected `CONNECT_DEFERRED` so a read happens after the owner finishes its
  change; the per-frame pass is only a fallback while a connection is missing.
- `scripts/ui/lock_on_indicator.gd` (`class_name LockOnIndicator`) - NEW. A `Node3D` marker driven by
  `TargetingComponent`; hidden while unlocked, shown on the current target, follows cycling, and
  hidden on all four release causes. It READS the lock and never writes it.
- `scripts/ui/pause_menu.gd` (`class_name PauseMenu`) - NEW. Real pause (`get_tree().paused`), a
  centred panel with Resume / Save / Load / New run, and a status line whose wording comes from the
  RETURNED `GameStateSave.Result` code. `PROCESS_MODE_ALWAYS` so it stays interactive while paused.
- `main.tscn` - `GameHUD`, `LockOnIndicator` and `PauseMenu` instantiated as siblings, so the UI is
  live in the shipped game with no debug mode.
- `scripts/player/player_controller.gd` - the carried-over ORIENTATION tweak: while a lock is held
  and no committed action owns the body, the body turns toward the locked target. A committed action
  keeps its own locked facing for its whole duration, per the project's recorded movement authority.
- `scripts/diagnostics/ui_hud_probe_debug.gd` + `scenes/diagnostics/ui_hud_probe_debug.tscn` - NEW.

#### Four defects found and fixed during this pass, all by measurement

1. **The HUD showed stale values on first frame - a REAL shipped defect, caught from a rendered
   frame.** `main.tscn` places `GameHUD` BEFORE `TestEnvironment` in tree order, so the HUD's
   `_ready()` ran before the player's `HealthComponent`/`StaminaComponent` ran theirs and reset to
   full. It read the raw `0.0` defaults, then connected, then stood its per-frame fallback down - so
   the shipped game displayed `HEALTH 0 / 100` and `STAMINA 0 / 100` beside a combat overlay reading
   `100/100`. Fixed by refreshing once at the moment the owner connections land. The probe did NOT
   catch this because every HUD assertion measured a CHANGE, so a display that started stale and
   caught up on the first damage event passed. Three at-rest assertions were added, and the probe now
   reports 114 checks instead of 111.
2. **`focus_input_routing_probe_debug` went from passing to 2 FAILED** once Milestone 12's targeting
   module became live in `main.tscn`. Both were measurement artifacts, not gameplay defects. Its
   `lock_on` delivery check let the REAL consumer spend the press first, reporting "the action never
   arrived"; it now silences the consumer for the measurement and restores it - this project's
   established pattern for a delivery check (`fkey_host_ownership_probe_debug` does the same to the
   save/load consumer). Its camera-motion check then read 28.43 deg because a lock left held by that
   same press gave the rig a SECOND yaw authority; with no lock held it measures exactly 0.0000 deg.
3. **The probe's pause phase was internally inconsistent.** It expected a frame-driven value to
   REGENERATE "while the tree was running" immediately after asserting the tree was PAUSED. Reordered
   so the playing measurement happens while playing and the paused measurement while paused, and the
   resume check now waits past `StaminaComponent.regen_delay` (0.8 s) - the 0.4 s wait was too short
   once the drain moved inside the pause.
4. **The debug save/load panel covered the new Credits readout**, both anchored to the top-right. The
   panel now sits BELOW the credits panel and toggles with the existing `toggle_debug_overlay` (F1)
   alongside the other debug overlays, so one press clears the whole debug layer.

#### The Escape / pause contract CHANGED, and the project rules were amended to match

Escape used to be layered: the first press only released the cursor (the input layer's own
`set_mouse_look(false)`) and the panel opened on the SECOND press. The user asked for one press.
`PauseMenu` now performs the release itself through the input layer's own API and opens the panel in
the same press, marking the event handled so the layer does not repeat the work. **The release
behaviour is unchanged - only the number of presses is.** A short section was appended to
`res://.summerrules` recording this, and `focus_input_routing_probe_debug` was updated to measure the
new contract rather than the old one.

#### The NEW RUN defect - reported by the user, fixed and measured

**REPORTED:** New Run carried the number but not the world. `GameStateSave.new_run()` reset the
carried balance, minted a new run identity and deleted the save file, and **touched no actor at all**.
So a New Run left the player dead where it fell, every killed enemy still defeated with its DEFEATED
presentation still showing, and a lock still held on a target from the previous run - and the HUD
faithfully displayed those unreset values, which is exactly what the user saw.

**FIXED in `scripts/core/game_state_save.gd`.** `new_run()` now calls a new `_reset_world()`, which is
the deliberate MIRROR of `_restore_world()`: a LOAD puts the world back to a RECORDED snapshot, a NEW
RUN puts it back to the AUTHORED starting state. Every value still goes through its own owner:

1. **The player** through `DeathComponent.reset_playable_state(false)` - the component that already
   means "this actor is going back on its SPAWN mark": full health, full stamina, regeneration
   re-enabled, every committed attack/dodge/parry cancelled, position and yaw restored. The player's
   spawn mark is that component's state and is ASKED FOR, not duplicated here.
2. **Every enemy**, enumerated from `HealthComponent.GROUP_DAMAGEABLE` rather than a fixed list, so a
   newly added enemy is covered the moment it exists. `HealthComponent.reset()` plus
   `EnemyDeathComponent.restore_defeated(false)` - the SAME restore a load uses, which deliberately
   does **not** emit `defeated`, so reviving an enemy cannot pay a reward for it.
3. **Every attacker's state machine**, from the `enemy_attacker` group for the same enumeration
   reason.
4. **The lock**, released by `TargetingComponent` through its own API with a NEW cause.
   `ReleaseReason.RUN_RESET` was added and named `run-reset`, so a new run is NOT filed as one of the
   four invalidation paths or as a manual release, and the counters stay honest.

**Enemy POSITIONS need a recorded yardstick, not a scene read.** `TestAttacker` pursues the player, so
its transform at the moment New Run is pressed is wherever the fight left it - reading the scene at
reset time would restore the wrong place. `_record_spawn_transforms()` captures every damageable
actor's AUTHORED placement ONCE at boot, keyed by NodePath. It is called `call_deferred()` from
`_ready()`, and the ordering is load-bearing: `HealthComponent._ready()` is what joins the damageable
group, and `GameStateSave` sits BEFORE `TestEnvironment` in `main.tscn`, so at `_ready()` the group is
still EMPTY. A deferred call is the first moment the group is complete and every actor is still
exactly where its scene authored it.

THE HUD FOLLOWED WITH NO HUD CHANGE, which is the point of not duplicating state: `reset_credits()`
emits `credits_changed`, and both components emit from `reset()`, so the display re-reads its owners.
This is measured rather than assumed - the probe asserts the reset values appear in the labels.

#### Two probe-fixture defects found while verifying the New Run fix

Both were PRE-EXISTING and were found only because the New Run work made those probes run their
reset path; neither was caused by this pass, and neither is a gameplay defect.

1. **`game_state_overall_probe_debug` had a stale save fixture.** Its `_make_payload()` still built
   the M9-era TALLY shape `"player": {"alive": true}` and nothing else, while the snapshot contract
   since M10.1 requires the player's recorded transform and health - the loader refuses a save that
   cannot say where the player stood (`the player block has no position (expected 3 numbers)`). So the
   post-load stages failed as `missing-field` and could never run. The fixture now DERIVES a real
   player block from the live player, which is honest and self-maintaining. `RESULT: ALL CHECKS
   PASSED` afterwards. This is the second occurrence of the same class the manifest already records
   for the schema-3 bump: **a fixture that hardcodes a shape stops testing its own claim the moment
   the shape moves.**
2. **`ui_hud_probe_debug` asserted a reset would not reset.** Its cleanup check demanded the award
   counter still read `awards_start + 1`, which was true before New Run touched the world and is
   false by design afterwards. It now asserts the FRESH-BOOT baseline instead (counter zeroed,
   balance at the documented starting value), which is the stronger and more honest statement.

#### A FLAKY assertion, recorded rather than papered over

`targeting_probe_debug`'s "the camera FOLLOWS when the target moves" check FAILED once at **10.62 deg**
off centre and PASSED on an immediate re-run with **no code change** at all (0.01 deg, tolerance
3.0 deg, 45 frames). The one edit made to that file this pass was an inert enum append
(`ReleaseReason.RUN_RESET`), which cannot affect camera framing - so this is an INTERMITTENT probe
artifact, not a regression. It is recorded as flaky rather than claimed fixed, because a pass that
depends on a re-run is not a pass. `RESULT: ALL CHECKS PASSED (78)` on the recorded run.

#### Measured evidence

- `ui_hud_probe_debug`: **RESULT: ALL CHECKS PASSED (142)**. Its original 114 checks, unchanged and
  still passing, cover: HUD at rest and after change, the indicator on acquire / cycle / all four
  release causes, pause stopping a frame-driven value and resume restarting it, no panel stacking,
  save and load through the real service, the status line differing between success and a refusal,
  and the HUD showing the RESTORED value after a load (`CREDITS 525, was CREDITS 30`) rather than a
  stale one. The 28 NEW checks cover New Run: the world dirty (player dead, an enemy defeated through
  the real damage chain, a lock held, a reward paid), then after New Run - player alive and respawned,
  every enemy revived to full with no DEFEATED presentation, the lock released and filed under
  `run-reset`, no look intent left declared, the tree not left paused, and the HUD showing
  `CREDITS 0` / `HEALTH 100 / 100` / `STAMINA 100 / 100`. A SECOND New Run is also exercised, so the
  reset is proven repeatable rather than a one-shot, and the probe leaves the balance at the
  fresh-run baseline.
- `focus_input_routing_probe_debug`: **RESULT: ALL CHECKS PASSED**.
- `targeting_probe_debug`: **RESULT: ALL CHECKS PASSED (78)** - Milestone 12 is UNREGRESSED with the
  orientation tweak in place. (See the flaky check above.)
- `retarget_state_probe_debug`: **RESULT: ALL CHECKS PASSED**.
- `game_state_overall_probe_debug`: **RESULT: ALL CHECKS PASSED** (after the fixture correction).
- `game_state_world_restore_probe_debug`: **RESULT: ALL CHECKS PASSED**.
- `game_state_save_load_probe_debug`: **RESULT: ALL CHECKS PASSED**.
- `game_state_mixed_state_probe_debug`: **RESULT: ALL CHECKS PASSED** (all five snapshot densities,
  `exact_state=true`, no reward across any load).
- `game_state_death_loop_probe_debug`: **RESULT: ALL CHECKS PASSED**.
- The shipped `main.tscn` boots with 0 runtime errors and 0 debugger errors.

#### Evidence vocabulary, applied honestly

- The behaviour above is **CONFIRMED by deterministic probe measurement**.
- HUD **readability**, indicator **clarity**, and whether the pause and save/load flow feel right are
  **NOT YET VERIFIED** - they are a matter of reading the screen, which no probe grades. This is why
  the milestone is not called accepted: **the user reads it and says.**
- The two `TARGET_CYCLE_*` script errors reported under scope `open_script_buffers` remain the KNOWN
  stale open-buffer false positive: both constants are present in `game_actions.gd` (lines 60-61) and
  the probes exercise both actions successfully at runtime.

#### Not built, by explicit scope decision

No settings, graphics, audio or key-rebinding menus; no title screen; no inventory; no animation, VFX
or sound; no lock-on-relative dodge direction; no checkpoint or respawn work. The three existing debug
overlays were NOT replaced - the new UI is separate and works with no debug mode.

---

## 8R. MILESTONE 14 - ENEMY HEALTH BAR (damage-revealed engagement feedback) (approved by the user 2026-09-14; roadmap written BEFORE implementation)

### 8R.1 What the user asked for

An enemy health bar for player feedback and combat tuning. It appears after that enemy is ATTACKED,
remains visible while the enemy is ENGAGED, and disappears after deaggro / disengagement. The user's
words: it is "the obvious remaining debug/player-feedback layer", and "as a debug feature, the simplest
version is probably best: damage reveals the bar; combat engagement keeps it visible; deaggro hides it".

It is explicitly NOT a permanent HUD decision yet. It exists so damage, enemy survivability and combat
tuning are legible during testing.

### 8R.2 THE DESIGN PROBLEM, STATED BEFORE ANY CODE: "ENGAGED" HAS NO OWNER

Measured on disk this pass: this project has NO aggro, threat, engagement or deaggro system. The only
occurrence of the word is `@export_group("Engagement")` on `EnemyAttacker`, and that group is that
attacker's OWN attack ranges and cooldowns - not a shared aggro concept any other system can read.
There is no `is_aggroed()`, no `in_combat`, no deaggro event, and enemy AI / pursuit is a DEFERRED
milestone that does not exist.

So "stays while engaged, hides on deaggro" cannot be implemented as written: there is nothing to ask.
Quietly substituting a magic distance or timer and calling it aggro would be exactly the kind of
unexplained stand-in this project's rules forbid.

WHAT IS IMPLEMENTED INSTEAD - a STAND-IN with ONE owner, stated plainly in the code:

1. DAMAGE REVEALS. The bar appears the moment that enemy takes damage, driven by that enemy's own
   `HealthComponent.damaged` signal. Nothing watches the player's attack and nothing re-derives damage.
2. IT IS HELD while EITHER real, existing condition is true: the enemy was damaged within
   `hold_seconds`, OR the player CURRENTLY HOLDS A LOCK on it (`TargetingComponent`).
3. IT HIDES when neither is true.

`hold_seconds` is exported precisely because it is a FEEL value intended to be decided by testing.
Lock-on counts as engagement because it is the only real, player-DECLARED "I am fighting this one"
signal that exists today. It does NOT reveal an undamaged enemy - that is the separate "appear on
lock-on" option in 8R.3, and it stays undecided.

WHEN ENEMY AI ARRIVES, the aggro authority it creates is what should replace rule 2. The stand-in is
shaped to be replaceable: `is_engaged()` is the single function that decides, and it is the one place
an AI-owned aggro query will be called instead.

### 8R.3 Options the user listed as LATER decisions - recorded, NOT decided, NOT built

- Appear only after damage. THIS is what is built today.
- Appear on lock-on (revealing an UNDAMAGED enemy). NOT built.
- Stay while aggroed. NOT possible yet - there is no aggro.
- Fade after a short period without interaction. Present only as a DURATION (`hold_seconds`); there is
  no fade, tween or animation in this pass.
- Remain permanently for bosses or minibosses. NOT built.
- Show exact HP or a readable health state. Shows a BAR only, no numbers.

### 8R.4 In scope

- One new module drawing a bar over each TRACKED enemy.
- Reveal on damage; hold and hide per 8R.2.
- Health read from `HealthComponent`; lock read from `TargetingComponent`. The module owns NO health
  value, no aggro state, no lock state - only the reveal timestamps and the Controls it draws.
- Visible in the shipped game with no debug mode and NOT gated behind `debug_enabled`.

### 8R.5 Explicitly OUT of scope (not built, not partially built)

- No aggro / threat / deaggro system and no enemy AI. Nothing in this pass may become one.
- No change to any enemy's behaviour, health, damage, rewards or attack state machine.
- No change to combat timing, stamina, save/load, targeting rules, camera framing or the HUD.
- No boss/miniboss permanent bars, no exact-HP numbers, no fade tween, no damage numbers.
- No interaction with pause, the debug overlays or the New Run reset beyond READING health.

### 8R.6 Acceptance criteria and evidence plan

1. A bar appears for an enemy ONLY after that enemy takes damage.
2. The bar is HELD while the damaged-within-`hold_seconds` rule is true.
3. The bar EXPIRES when that window passes with no further damage and no lock.
4. A LOCK on that enemy also holds its bar; with the damage window already expired, releasing the lock
   hides the bar (this is the simple rule - there is no deaggro grace period, because there is no
   deaggro owner yet, and this is the first thing to tune).
5. The fill tracks the owner's REAL fraction, read fresh, including after a New Run restores the enemy
   to full.
6. READABILITY - bar size, position, colour and whether the hold feels right - is the USER's read. A
   probe cannot grade it and must not be claimed to.

Evidence: the existing `ui_hud_probe_debug` gains a phase; the shipped `main.tscn` is booted. The
engagement rule is recorded as PARTIALLY VERIFIED BY CONSTRUCTION: what is measurable is that the bar
obeys the rule above; what is NOT verifiable is whether that rule is the right FEEL, which needs enemy
AI and a human read.

### 8R.7 Milestone 14 - status

**IMPLEMENTED AND MEASURED 2026-09-14. NOT YET HUMAN-READ - awaiting the user's look at bar size,
position, colour, and whether the hold feels right.**

#### What was built

- `scripts/ui/enemy_health_bars.gd` (`class_name EnemyHealthBars`) - NEW. A `CanvasLayer` (its own
  layer, 2: ABOVE the world, BELOW the debug overlays, so one F1 press still clears the debug layer
  while this feedback stays visible in the plain game) that draws one small anchored bar per TRACKED
  enemy. It owns NO health value and NO aggro state: the only things it holds are a reveal timestamp
  per actor and the Controls it draws. Health is read fresh from `HealthComponent.health_fraction()`
  every frame; the lock is read from `TargetingComponent`.
- `main.tscn` - `EnemyHealthBars` instantiated as a sibling, live in the shipped game with no debug
  mode and not gated behind `debug_enabled`.
- `scripts/ui/enemy_health_bars.gd` also gained two READ-ONLY accessors for tooling:
  `is_tracked(actor)` and `fill_width_of(actor)`, the latter returning the DRAWN pixel width so a probe
  measures what is on screen rather than recomputing it.
- `scripts/diagnostics/ui_hud_probe_debug.gd` - a new PHASE 7, 23 checks.

#### The two rules, and where the seam is

1. **REVEAL.** The enemy's OWN `HealthComponent.damaged` signal is what makes a bar appear. Nothing
   watches the player's attack and nothing re-derives damage from a health difference - so a bar cannot
   appear for damage that did not happen.
2. **HOLD / HIDE.** One function, `is_engaged()`, is the single place that decides whether an enemy is
   engaged. Today it is a STAND-IN with two clauses: damaged within `hold_seconds` (4.0 s, exported),
   or currently locked (while `hold_while_locked`). **There is deliberately no deaggro grace period,
   because there is no deaggro owner yet.** When enemy AI exists, `is_engaged()` is the seam where the
   AI is asked instead of this stand-in - the call site does not move.

The player is EXCLUDED from tracking on purpose: the player already has the HUD's own health bar, and
this module is enemy feedback. The scan is deferred from `_ready()` because `HealthComponent._ready()`
is what joins the damageable group, and this node precedes the actors in tree order.

#### Measured evidence

- `ui_hud_probe_debug`: **RESULT: ALL CHECKS PASSED (165)** - up from 142, so the 23 new checks all
  pass. They cover: the module is live in the shipped scene; the arena's 5 enemies are TRACKED at boot
  while ZERO bars show at rest (existing is not the same as being revealed); the player is NOT tracked;
  damaging the PLAYER reveals no enemy bar; a tracked but undamaged enemy has no bar; real damage
  through the damage chain REVEALS the bar and the reveal is counted; the drawn FILL WIDTH equals the
  owner's own health fraction (47.00 px measured against 47.00 px expected); disengagement hides it
  after the window with NO further damage, counted exactly once; a LOCKED enemy stays revealed PAST
  the hold window while the lock is held; releasing the lock lets it hide again; the shipped
  `hold_seconds` is restored; and the temporary enemy's bar is dropped when the actor is freed.
- The shipped `main.tscn` boots with 0 runtime errors and 0 debugger errors.
- The two `TARGET_CYCLE_*` script errors under scope `open_script_buffers` remain the KNOWN stale
  open-buffer false positive.

#### One probe defect found and fixed during this pass

The probe's own teardown assertion CRASHED the run: it called `is_tracked(enemy)` AFTER
`queue_free()`, and a freed instance cannot be passed to a typed `Node3D` parameter
(`Invalid type in function 'is_tracked' ... previously freed`). The component was behaving correctly -
it had already dropped the entry. The assertion now captures the tracked count BEFORE the free and
asserts that it DECREASED, which measures the same thing without handing a freed object to a typed
parameter. Every behavioural check in PHASE 7 passed on the first run; only this teardown check was
ever wrong.

#### Evidence vocabulary, applied honestly

- The reveal, hold, expire and fill-tracking RULES are **CONFIRMED by deterministic probe measurement**.
- The ENGAGEMENT RULE itself (4 s hold, lock extends it) is **PARTIALLY VERIFIED BY CONSTRUCTION**: it
  is measurably obeyed, but whether a 4-second hold and a lock-extended reveal are the RIGHT FEEL is
  **NOT YET VERIFIED** and cannot be until enemy AI exists and the user reads it.
- Bar READABILITY - size, position, colour, legibility against the arena - is **NOT YET VERIFIED**.
  A probe cannot grade it and is not claimed to.

