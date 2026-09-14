# CASCADIA - LOCAL MILESTONE ROADMAP

Local source of truth for Cascadia's development order, milestone status,
acceptance criteria, known defects, deferred systems and the next approved task.

A fresh session must be able to read THIS FILE plus `CASCADIA_DELETION_MANIFEST.md`
and know exactly where the project stands without chat history.

Last updated: 2026-09-12 (MILESTONE 10 IMPLEMENTED AND MEASURED - Game-State Saving and Loading
Foundation; roadmap written BEFORE implementation)
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

## 0. READ ME FIRST - CURRENT STATE IN ONE SCREEN

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
| - | Sprint / Dodge / Backstep input pass | IMPLEMENTED, MEASURED, AND HUMAN-PLAYED (backstep orientation DEFECT human-confirmed) | dodge_input_probe_debug: shared input tap->dodge / hold->sprint, release-after-sprint does NOT dodge, forward/right/backward resolve camera-relative (dot 1.00), a neutral tap produces a BACKSTEP travelling backwards along facing (dot 1.00), directional travel 1.688 m vs 3.375 m before, backstep 1.280 m, i-frames intact, exactly one 22-stamina charge and an unaffordable refusal counted by cause, RESULT: ALL CHECKS PASSED; all eight probes re-run and passed |
| - | Reusable actor death capability | ACCEPTED 2026-09-12 (measured AND human-verified) | Roadmap section 8J written BEFORE implementation, per the user's instruction. Audit read from the live scenes: the reusable defeat path existed (`EnemyDeathComponent`) but only `TestAttacker` carried it, so the capability was NOT actually shared; `DummyActor` and `Targets/TargetA..C` had health and a hurtbox and no defeat path at all. `DummyActor` now carries the same component and is measured defeated exactly once; the immortal and non-damageable axes are measured as genuinely distinct; the player's reset did NOT revive it. `actor_death_probe_debug`: RESULT: ALL CHECKS PASSED, 0 runtime errors; all nine other probes re-run and passed. ACCEPTED after the user's manual playtest: the dummy takes damage, reaches 0/100, enters the dead state, tips and darkens, shows DEFEATED, and does not disturb the other actors. See 8J.10 and 8J.12 |
| 9 | Soulslike credit economy and meaningful progression foundation | IMPLEMENTED AND MEASURED (CARRIED Credits only; banking/spending/persistence NOT built; feel not yet played) | MILESTONE 9, selected by the user and written into section 8L BEFORE implementation. `credit_economy_probe_debug` ENUMERATES the authoritative enemy population and kills each eligible enemy through the real `receive_hit -> apply_damage` chain: every one awards Credits exactly once, the reward equals the documented provisional amount, the carried balance equals the sum of eligible rewards, and the non-mortal and player archetypes are excluded by explicit rule. Duplicate, freed-actor and not-actually-defeated cases award nothing. STILL NOT BUILT: banking, spending, stats/items/gear progression, death-loss retrieval and save/load. See 8L |
| 10 | Game-state saving and loading foundation | IMPLEMENTED AND MEASURED (probe-verified; NOT yet human-played; persists the carried balance ONLY). The reported physical-F9 failure was a HOST KEY COLLISION, NOT a save/load defect - see 8M.20. The load key is now F7 (F11 alternate); F9 and F8 are owned by the embedding host and cannot be used | MILESTONE 10, selected by the user and written into section 8M BEFORE implementation. `GameStateSave` writes a REAL save at `user://cascadia_save.json` carrying `schema_version`, `carried_credits` and `saved_at_unix`, reading the balance from `CreditLedger` and restoring it through the ledger's own controlled path (which is NOT `award_credits`, so a load can never be mistaken for a defeat). `game_state_save_load_probe_debug`: RESULT: ALL CHECKS PASSED, 0 debugger errors. Measured round trip: one real kill earned 100, a 250 top-up set the saved value to 350, the live balance was then changed, and the load restored 350 EXACTLY; a further post-load kill took it to 450. Every malformed case (missing, empty, not-an-object, unsupported version, missing field, text value, negative value) failed with its OWN result and left the balance untouched. `main.tscn` boots with 0 runtime errors and the F5/F9/F10 prototype panel plus the balance render in-game. STILL NOT BUILT: banking, spending, stats, items, gear, inventory, checkpoints, world-state persistence, defeated-enemy persistence, death currency loss, multiple slots, cloud saves. See 8M |
| - | Defeat coverage across every enemy (defect fix) | ACCEPTED 2026-09-12 (measured AND user-verified) | User-reported DEFECT: an enemy reaching 0 health showed no defeated state because `TargetA/B/C` carried no death path at all and NO probe looked at them - so they processed nothing while every probe still passed. Fixed by wiring the EXISTING `EnemyDeathComponent` + presentation to all three, and by adding the test that was missing: `defeat_coverage_probe_debug` ENUMERATES the `damageable` group instead of naming actors, so a new enemy is covered the moment it exists. Measured: 5/5 enemies `is_defeated=true defeats=1 presentation=showing`, ALL CHECKS PASSED. All 13 probes re-run and passed. See 8K.12 |
| - | Defeat coverage across the arena | ACCEPTED 2026-09-12 (measured AND user-verified) | The user reported that an enemy reaching 0 health did not show a defeated state, and that NO test asserted defeat coverage. Both were CORRECT: `TargetA/B/C` carried no death path at all, and every probe inspected actors BY NAME, so an unwired actor reaching zero health processed nothing while the whole suite still reported ALL CHECKS PASSED. Fix: `TargetA/B/C` wired to the EXISTING `EnemyDeathComponent` (mortal) + the EXISTING presentation adapter in `scenes/test_environment.tscn`; no new death system, no combat value or timing changed. The missing test now exists as `defeat_coverage_probe_debug`, driven by ENUMERATION of the `damageable` group so a newly added enemy is covered the moment it exists, and the player is excluded BY ARCHETYPE (`resets_actors`), not by name. `[DEFCOV] RESULT: ALL CHECKS PASSED`, 5/5 enemies each reading `is_defeated=true defeats=1 presentation=showing`; all 13 regression probes re-run and passed; `main.tscn` boots with 0 runtime errors. Rendered frame confirms red `DEFEATED` labels, tipped/darkened poses, and all five actors at `0/100 DEAD`. See 8K.12 |
| - | Reusable actor combat readiness | IMPLEMENTED AND MEASURED; DEFECT FOUND IN PLAY AND FIXED (8K.12) | `defeat_coverage_probe_debug`: 5/5 damageable enemies reach the DEFEATED state with a VISIBLY showing presentation (TestAttacker, DummyActor, TargetA, TargetB, TargetC all `is_defeated=true defeats=1 presentation=showing`). The 8K.11 audit had wrongly concluded the static targets were intentional non-participants; they were a HOLE - no death path at all - and are now wired into the existing defeat component. `actor_combat_readiness_probe_debug`: ALL CHECKS PASSED. All 13 regression probes re-run and passed. Section 8K written BEFORE any implementation. Audit read from the live project: damageability (`HealthComponent` + `HurtboxComponent.damageable`), mortality (`EnemyDeathComponent.mortal`), attack capability (`EnemyAttacker`), per-actor debug presentation (`CombatDebugOverlay`) and group-based target selection (`EnemyAttacker.target_group`) ALREADY existed and were reused unchanged. The genuine gap was TARGET VALIDITY: `EnemyAttacker._get_target()` returned the first node in the group with no alive check, so a dead actor was still a valid target the attacker faced and swung at. `actor_combat_readiness_probe_debug`: RESULT: ALL CHECKS PASSED, 0 runtime errors - the dead target was refused with the DEAD cause (`target_refusals_dead 0 -> 2`) and NOT as out-of-range (`0 -> 0`), the attacker did not turn to face the corpse (`max drift 0.0000 rad`), a revived actor was targetable again, and a freed node was refused without raising. All twelve regression probes re-run and passed. See 8K.10 |

- **Highest milestone reached: 8.** This input pass is a REFINEMENT of Milestone 6's
  locomotion and is deliberately NOT numbered - Milestone 9 remains enemy pursuit and was
  NOT started.
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
- **Current active task: NONE.** Milestone 10 is complete and measured; no further work is authorised.
  Milestone 11 is NOT selected and must be named and approved before anything begins.

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
## (SELECTED BY THE USER; roadmap written BEFORE implementation)

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

### 8M.15 M10.2 - THE MOUSE_FILTER HYPOTHESIS IS FALSIFIED (2026-09-12)

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

### 8M.16 M10.2 - THE SAVE/LOAD STATE MODEL IS CORRECTED: SNAPSHOT, NOT TALLY (2026-09-12)

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

#### Honest note on the earlier 8M.15 falsification

8M.15 proved the mouse_filter hypothesis wrong and it STAND. That work ruled out one explanation; it
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

**Doc defect recorded:** this file contains TWO sections numbered `8M.15` and TWO numbered `8M.16`
(the M10.1 block and the M10.2 block each restarted the count). This pass used `8M.18` to avoid adding
a third collision. Renumbering the older headings is left to manual review rather than done silently.

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

## 10. CURRENT TASK - TARGET / TEST-ACTOR GROUNDING

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

## 11. CURRENT MILESTONE - MILESTONE 6: DODGE AND I-FRAMES (DELIVERED)

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

## 11A. NEXT MILESTONE - MILESTONE 7 (PARRY) SELECTED, APPROVED AND DELIVERED

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

`state:diagnostics` currently reports `20` script errors and `5` warnings. All 20
errors are ONE root cause:

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
- `[OPEN 2026-09-12: found in human playtest - CONFIRMED DEFECT]` BACKSTEP ORIENTATION. The body
  turns during a backstep instead of retreating while facing forward, exactly as the static
  reading in section 8F.2 predicted. Found independently by the user in play (section 8G.2
  item 2). A facing indicator is needed to make the correction readable.
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
  lose them permanently). RECORDED AS FUTURE WORK, NOT IMPLEMENTED. For Milestone 9 the carried balance
  explicitly SURVIVES the player's existing death and reset, and that choice is measured by the probe
  rather than left implicit (section 8L.7).
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
- Enemy stagger / poise.
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
- Dodge movement-authority arbitration - orientation and position (section 8F). Bounded
  gameplay/presentation pass. RECORDED, NOT STARTED. Orientation is now human-confirmed.
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

The manifest is currently ~938 lines and already records, among others:

- Cleanup candidates: `scripts/diagnostics/input_debug_overlay.gd`,
  `scripts/player/player_stub.gd`, the step / damage / actor / attack / target-sweep
  probe scripts and their scenes, `scenes/actors/dummy_actor.tscn`,
  `scripts/diagnostics/hit_feedback_debug.gd`.
- Environment notes: asset health, Unity `.meta` clutter, `assets/folder_tree.txt`.
- Process notes: writes reported but absent from disk; new-directory registration
  failures; the class-cache `open_script_buffers` issue; the camera mask drift.

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
