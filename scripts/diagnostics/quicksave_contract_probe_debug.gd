class_name QuicksaveContractProbeDebug
extends Node3D
## Temporary diagnostic (not production): the QUICKSAVE / QUICKLOAD gameplay contract, end to end,
## across TWO returns to the SAME quicksave and THREE kills after it.
##
## WHY THIS EXISTS. Every save/load probe before this one restored state, assigned state, or killed
## actors by handing `HurtboxComponent.receive_hit()` a lethal `DamageEvent` directly with a null
## source. All of that is real in the damage chain, but none of it is the PLAYER'S ATTACK, and none
## of it continues into ordinary gameplay afterwards. The reported failure is a GAMEPLAY one:
##
##     kill one enemy -> F5 -> kill a second enemy -> F9 -> the game does not come back playable
##
## So this probe drives the reported sequence through the pieces a player actually uses: the real
## gameplay scene, the real player, the real `CascadiaInput` action path, the real `PlayerCombat`
## state machine, the real `HitboxComponent -> HurtboxComponent -> HealthComponent` chain, the real
## `EnemyDeathComponent`, the real `CreditLedger` and the real `GameStateSave` service - and then it
## keeps PLAYING afterwards, twice over.
##
## THE DEPTH THIS PASS ADDS. A single kill-then-load round trip cannot tell a correct restore from a
## restore that happens to work while only two actors have ever changed. So the world is mutated by
## TWO FURTHER KILLS after the save, the quicksave is returned to TWICE, and kills keep happening
## between and after those returns:
##
##   A. the arena starts coherent: named enemies alive, targetable, one ledger, one save service.
##   B. kill enemy A with a REAL attack; save through the real save path; read the FILE back and
##      confirm it records A dead, the other enemies alive, the balance, and the run.
##   C. kill a DIFFERENT enemy B, then a THIRD enemy C, with real attacks - so the world no longer
##      matches the snapshot by two actors, not one.
##   D. load #1 through the real load path; every actor must match the snapshot EXACTLY, by name.
##   E. keep playing: move, then kill B and C - the two the snapshot recorded as ALIVE. Each reward
##      must be paid exactly once. This is the case that exposes a reward ledger whose
##      "already paid" memory was never brought back with the world.
##   F. load #2, returning to the SAME quicksave after all of that: A is dead again, B and C are
##      alive again, the balance is back to the saved value, and the load itself paid nothing.
##   G. kill B once more, after that second return, so the restored world is proven to still be a
##      playing game rather than a state that can only be observed.
##
## The save file is never rewritten after step B, and the probe asserts that: "return to the
## previous quicksave" means the SAME snapshot, not a new one written on the way back.

## Frames given to the scene to settle before anything is measured.
const SETTLE_FRAMES := 30
## Frames given to presentation adapters after a load; they poll on their own _process.
const PRESENTATION_FRAMES := 10
## Frames to let a committed light attack reach and finish its ACTIVE window, plus the stamina pause
## the attack costs. Long enough that the pool has begun regenerating before the next press, so a
## kill is not blocked by an unaffordable swing rather than by anything under test.
const ATTACK_WAIT_FRAMES := 40
## How many real attacks may be spent trying to kill one enemy before it counts as a failure.
const ATTACK_ATTEMPTS := 24
const MOVE_FRAMES := 24
const MIN_TRAVEL := 0.25

## Horizontal distance the player stands from its victim. Outside the two capsule radii (0.8), and
## inside the attack hitbox's reach.
const APPROACH_OFFSET := 1.15
## Height the player is stood at, measured from the arena floor. Deliberately a FLOOR height rather
## than the victim's own origin: one of the actors stands on a raised pedestal, and placing the body
## at that height would drop it through the air mid-swing and make reach depend on where it happened
## to be falling. The attack hitbox reaches down to the floor, so every victim is attacked from the
## same, settled stance.
const APPROACH_FLOOR_Y := 0.1
## How close (HORIZONTALLY) the player must actually be for an approach to count as arrived.
const ARRIVE_TOLERANCE := 0.4

## The enemies this probe drives by NAME, so the report names actors rather than counting them.
## A is killed before the save; B and C are killed after it.
const VICTIM_A := "DummyActor"
const VICTIM_B := "TestAttacker"
const VICTIM_C := "TargetA"

var _frame := 0
var _stage := 0
var _wait := 0
var _wait_next := 0
var _done := false
var _failures: Array = []
var _recap: Array = []

var _ledger: CreditLedger
var _save: GameStateSave
var _player: Node3D
var _player_health: HealthComponent
var _player_death: Node
var _combat: Node
var _hitbox: HitboxComponent

## Every defeatable actor that is not the player, keyed by short name, with the scene path recorded
## as identity.
var _actors: Array = []
var _paths: Array = []
var _by_name: Dictionary = {}

## The snapshot: what every actor must look like after a load, keyed by scene path.
var _expect: Dictionary = {}
var _credits_at_save := 0
var _awards_at_save := 0
## Read IMMEDIATELY before each load. The claim under test is narrow: the LOAD itself must pay
## nothing. Everything before it legitimately EARNS Credits by killing actors, so a baseline taken
## earlier would charge the load for the mutation's own earnings.
var _awards_before_load := 0
## Read IMMEDIATELY before a run of kills, for the same reason in the other direction.
var _awards_before_kills := 0
var _attacks_before := 0
var _move_start := Vector3.ZERO
## The save file's exact text at the moment of the save, so "we returned to the SAME quicksave" is
## checkable rather than assumed.
var _saved_text := ""

## The kill queue: a list of victim names to defeat in order, and where to go once they all are.
## A queued kill is only ever driven through the real attack path - see _stage_kill().
var _kill_names: Array = []
var _kill_index := 0
var _kill_return := 0
var _kill_label := ""
var _victim: Node3D
var _attempts_left := 0
var _attack_phase := 0

## Input actions currently held by this probe, released together.
var _held: Array = []
var _release_frame := -1

## Save-file hygiene, so a real user's quicksave is not destroyed by running a diagnostics scene.
var _had_save := false
var _backup_text := ""


func _ready() -> void:
	print("[QUICKSAVE] === quicksave / quickload contract probe (deep) ===")


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1

	# Ambient attackers are held down for the whole probe. The contract under test is the save/load
	# round trip and the player's own attack path; an enemy that happens to swing during it would add
	# a damage source to every measurement that has nothing to do with the state being measured.
	EnemyAttacker.stand_down_all(get_tree())

	if _release_frame >= 0 and _frame >= _release_frame:
		_release_inputs()

	if _stage == STAGE_KILL:
		_stage_kill()
		return

	if _stage == STAGE_WAIT:
		_wait -= 1
		if _wait <= 0:
			_stage = _wait_next
		return

	match _stage:
		STAGE_SETTLE:
			if _frame >= SETTLE_FRAMES:
				_stage = STAGE_INITIAL
		STAGE_INITIAL:
			_phase_initial()
		STAGE_AFTER_SAVE:
			_phase_after_save()
		STAGE_AFTER_MUTATION:
			_phase_after_mutation()
		STAGE_LOAD1:
			_phase_load_one()
		STAGE_VERIFY1:
			_phase_verify_one()
		STAGE_AFTER_MOVE:
			_phase_after_move()
		STAGE_AFTER_PLAY:
			_phase_after_play()
		STAGE_LOAD2:
			_phase_load_two()
		STAGE_VERIFY2:
			_phase_verify_two()
		STAGE_AFTER_FINAL:
			_phase_after_final()
		STAGE_FINISH:
			_finish()


const STAGE_SETTLE := 0
const STAGE_INITIAL := 1
const STAGE_AFTER_SAVE := 2
const STAGE_AFTER_MUTATION := 3
const STAGE_LOAD1 := 4
const STAGE_VERIFY1 := 5
const STAGE_AFTER_MOVE := 6
const STAGE_AFTER_PLAY := 7
const STAGE_LOAD2 := 8
const STAGE_VERIFY2 := 9
const STAGE_AFTER_FINAL := 10
const STAGE_FINISH := 11
const STAGE_WAIT := 98
## Driven by the kill QUEUE rather than by one fixed victim, so a sequence of kills is ordinary
## control flow instead of a hand-written stage per actor.
const STAGE_KILL := 99


# --- Phase A: the arena as it starts ------------------------------------------

func _phase_initial() -> void:
	_resolve()
	if _ledger == null or _save == null or _player == null or _player_health == null or _combat == null:
		_fail("could not resolve the ledger, the save service, the player, its health or its combat")
		_finish()
		return
	if _by_name.size() < 3:
		_fail("expected at least three named defeatable enemies, found %d" % _by_name.size())
		_finish()
		return
	if not _require_victims():
		_finish()
		return

	_backup_existing()

	print("[QUICKSAVE] --- PHASE A: initial state ---")
	_check(not _player_health.is_dead, "the player is ALIVE and playable")
	_check(_count_ledgers() == 1, "exactly ONE CreditLedger exists (got %d)" % _count_ledgers())
	_check(_count_saves() == 1, "exactly ONE GameStateSave exists (got %d)" % _count_saves())

	# The reward-history API this probe asserts on later must actually exist, or those assertions
	# would be measuring nothing. Checked up front so the failure is attributed to the API, not to
	# the restore.
	_check(_ledger.has_method("is_rewarded"),
		"the ledger exposes is_rewarded(), so reward history is observable through its own API")

	# Every other enemy in the arena starts alive and targetable, so "A is dead and B is alive" later
	# is a statement about specific actors rather than about the arena's population.
	for name in _by_name.keys():
		var actor: Node3D = _by_name[name]
		var row := _state(actor)
		_check(not bool(row["defeated"]) and not bool(row["dead"]),
			"%s starts ALIVE" % name)
		_check(bool(row["targetable"]), "%s starts TARGETABLE" % name)

	_log_world("INITIAL")
	_attacks_before = int(_combat.get("attacks_started"))
	_begin_kills([VICTIM_A], STAGE_AFTER_SAVE, "kill %s then save" % VICTIM_A)


# --- Phase B: A is killed, then the run is saved ------------------------------

func _phase_after_save() -> void:
	print("[QUICKSAVE] --- PHASE B: %s killed, saving ---" % VICTIM_A)
	var a: Node3D = _by_name[VICTIM_A]
	_check(int(_combat.get("attacks_started")) > _attacks_before,
		"the kill was made by a REAL attack (PlayerCombat.attacks_started %d -> %d)"
			% [_attacks_before, int(_combat.get("attacks_started"))])
	_check(_is_defeated(a), "%s is DEFEATED after the attack" % VICTIM_A)
	_log_world("KILLED A")

	# The snapshot every later check is measured against.
	_expect = {}
	for i in range(_actors.size()):
		_expect[_paths[i]] = _state(_actors[i])

	_credits_at_save = _ledger.credits
	_awards_at_save = _ledger.awards
	var code := _save.save_game()
	_check(code == GameStateSave.Result.OK,
		"the save succeeded (%s - %s)" % [GameStateSave.result_name(code), _save.last_error])
	print("[QUICKSAVE] save: %s  carried=%d  awards=%d" % [
		GameStateSave.result_name(code), _credits_at_save, _awards_at_save])
	_log_world("SAVED")

	# The FILE is what a load reads, so the contract is checked against the bytes on disk rather than
	# against the dictionary that produced them.
	var on_disk := _read_save_file()
	_check(not on_disk.is_empty(), "the save file exists and parses")
	_check(int(on_disk.get("schema_version", 0)) == GameStateSave.SCHEMA_VERSION,
		"the file records schema_version %d (got %s)"
			% [GameStateSave.SCHEMA_VERSION, str(on_disk.get("schema_version"))])
	_check(int(on_disk.get("carried_credits", -1)) == _credits_at_save,
		"the file records the carried balance (%d, got %s)"
			% [_credits_at_save, str(on_disk.get("carried_credits"))])

	var records := _world_records(on_disk)
	_check(records.size() == _actors.size(),
		"the file records every defeatable actor (%d of %d)" % [records.size(), _actors.size()])
	for i in range(_actors.size()):
		var path := String(_paths[i])
		var short := _short(path)
		_check(records.has(path), "the file records %s by scene path" % short)
		if not records.has(path):
			continue
		var rec: Dictionary = records[path]
		var snapshot: Dictionary = _expect[path]
		_check(bool(rec.get("defeated", false)) == bool(snapshot["defeated"]),
			"the file records %s defeated=%s (snapshot %s)"
				% [short, str(rec.get("defeated", false)), str(snapshot["defeated"])])
		_check(bool(rec.get("dead", false)) == bool(snapshot["dead"]),
			"the file records %s dead=%s (snapshot %s)"
				% [short, str(rec.get("dead", false)), str(snapshot["dead"])])
		_check(is_equal_approx(float(rec.get("health", -1.0)), float(snapshot["health"])),
			"the file records %s health %.1f (snapshot %.1f)"
				% [short, float(rec.get("health", -1.0)), float(snapshot["health"])])
		# The recorded reward history must equal the LEDGER's live history - the file records what
		# the economy actually held, not a guess derived from something else.
		var live_paid := _is_paid(_actors[i])
		_check(bool(rec.get("paid", not live_paid)) == live_paid,
			"the file records %s paid=%s, the ledger's own answer at save time"
				% [short, str(live_paid)])
	_check(_is_paid(a), "the ledger has PAID for %s by the time of the save" % VICTIM_A)
	_check(not _is_paid(_by_name[VICTIM_B]) and not _is_paid(_by_name[VICTIM_C]),
		"the ledger has paid for NEITHER %s NOR %s yet" % [VICTIM_B, VICTIM_C])

	_saved_text = _read_save_text()
	_recap.append("held at save: defeated=[%s] alive=[%s] carried=%d awards=%d" % [
		_defeated_names(_expect), _alive_names(_expect), _credits_at_save, _awards_at_save])

	_begin_kills([VICTIM_B, VICTIM_C], STAGE_AFTER_MUTATION,
		"mutate: kill %s and %s" % [VICTIM_B, VICTIM_C])


# --- Phase C: the world moves on by TWO actors, not one -----------------------

func _phase_after_mutation() -> void:
	print("[QUICKSAVE] --- PHASE C: %s and %s killed after the save ---" % [VICTIM_B, VICTIM_C])
	var b: Node3D = _by_name[VICTIM_B]
	var c: Node3D = _by_name[VICTIM_C]
	_check(_is_defeated(b) and _is_defeated(c),
		"%s and %s are BOTH DEFEATED after the mutation" % [VICTIM_B, VICTIM_C])
	_log_world("MUTATED")

	var live := _live_world()
	var differs := false
	var differ_count := 0
	for path in _expect.keys():
		if not live.has(path):
			continue
		var want: Dictionary = _expect[path]
		var got: Dictionary = live[path]
		if bool(want["defeated"]) != bool(got["defeated"]):
			differs = true
			differ_count += 1
	_check(differs, "the world genuinely DIFFERS from the snapshot before the load")
	_check(differ_count == 2,
		"TWO actors differ from the snapshot, not one (differing: %d)" % differ_count)

	var reward := int(_ledger.reward_per_enemy)
	_check(_ledger.credits == _credits_at_save + 2 * reward,
		"the two mutation kills earned exactly two rewards (want %d, got %d)"
			% [_credits_at_save + 2 * reward, _ledger.credits])
	_check(_ledger.awards == _awards_at_save + 2,
		"exactly two awards were granted by the mutation (want %d, got %d)"
			% [_awards_at_save + 2, _ledger.awards])
	print("[QUICKSAVE] at this point: defeated=[%s]  carried=%d  awards=%d" % [
		_defeated_names(live), _ledger.credits, _ledger.awards])

	# Read immediately before the load: the mutation above legitimately EARNED Credits, so the only
	# honest question is whether the LOAD itself pays anything.
	_awards_before_load = _ledger.awards
	_stage = STAGE_LOAD1


# --- Phase D: load #1, and check every actor by identity ----------------------

func _phase_load_one() -> void:
	print("[QUICKSAVE] --- PHASE D: load #1 ---")
	var code := _save.load_game()
	print("[QUICKSAVE] load 1: %s  carried=%d  error=%s" % [
		GameStateSave.result_name(code), _ledger.credits, _save.last_error])
	_check(code == GameStateSave.Result.OK,
		"load 1 succeeded (%s - %s)" % [GameStateSave.result_name(code), _save.last_error])
	_stage = STAGE_WAIT
	_wait_next = STAGE_VERIFY1
	_wait = PRESENTATION_FRAMES


func _phase_verify_one() -> void:
	_verify_snapshot("load 1")
	_recap.append("after load 1: defeated=[%s] alive=[%s] carried=%d awards=%d" % [
		_defeated_names(_live_world()), _alive_names(_live_world()), _ledger.credits, _ledger.awards])

	_move_start = _player.global_position
	_press(GameActions.MOVE_FORWARD, MOVE_FRAMES + 4)
	_stage = STAGE_WAIT
	_wait_next = STAGE_AFTER_MOVE
	_wait = MOVE_FRAMES


# --- Phase E: keep playing after the first load -------------------------------

func _phase_after_move() -> void:
	_release_inputs()
	var travelled := _player.global_position.distance_to(_move_start)
	print("[QUICKSAVE] post-load movement: travelled %.4f m over %d frames" % [travelled, MOVE_FRAMES])
	_check(travelled > MIN_TRAVEL, "the player MOVES after load 1 (travelled %.4f m)" % travelled)
	_check(not _player_health.is_dead, "the player is still ALIVE after moving")

	# Kill the two enemies the snapshot recorded as ALIVE, through the real attack path. Under the
	# reported failure both are alive, targetable and killable and BOTH pay NOTHING, because the
	# reward ledger still remembered paying them after the save.
	_awards_before_kills = _ledger.awards
	_begin_kills([VICTIM_B, VICTIM_C], STAGE_AFTER_PLAY,
		"kill %s and %s after load 1" % [VICTIM_B, VICTIM_C])


func _phase_after_play() -> void:
	print("[QUICKSAVE] --- PHASE E result: continued play after load 1 ---")
	var reward := int(_ledger.reward_per_enemy)
	_check(int(_combat.get("attacks_started")) > _attacks_before,
		"the player kept ATTACKING after the load (attacks_started %d -> %d)"
			% [_attacks_before, int(_combat.get("attacks_started"))])
	_check(_is_defeated(_by_name[VICTIM_B]) and _is_defeated(_by_name[VICTIM_C]),
		"%s and %s were KILLED after the load through the real combat path" % [VICTIM_B, VICTIM_C])
	_check(_ledger.awards == _awards_before_kills + 2,
		"BOTH post-load kills paid, exactly once each (awards %d -> %d)"
			% [_awards_before_kills, _ledger.awards])
	_check(_ledger.credits == _credits_at_save + 2 * reward,
		"the restored world still PAYS for a revived enemy (want %d, got %d)"
			% [_credits_at_save + 2 * reward, _ledger.credits])
	_check(not _player_health.is_dead, "the player is still ALIVE and playable afterwards")
	_log_world("PLAYED ON")
	_recap.append("after continued play: defeated=[%s] carried=%d awards=%d" % [
		_defeated_names(_live_world()), _ledger.credits, _ledger.awards])

	# Return to the SAME quicksave a second time. The probe has not saved since step B, so the file
	# on disk is still the snapshot taken then - which the next stage asserts.
	_awards_before_load = _ledger.awards
	_stage = STAGE_LOAD2


# --- Phase F: load #2, back to the same quicksave after all of that -----------

func _phase_load_two() -> void:
	print("[QUICKSAVE] --- PHASE F: load #2, back to the SAME quicksave ---")
	var code := _save.load_game()
	print("[QUICKSAVE] load 2: %s  carried=%d  error=%s" % [
		GameStateSave.result_name(code), _ledger.credits, _save.last_error])
	_check(code == GameStateSave.Result.OK,
		"load 2 succeeded (%s - %s)" % [GameStateSave.result_name(code), _save.last_error])
	_stage = STAGE_WAIT
	_wait_next = STAGE_VERIFY2
	_wait = PRESENTATION_FRAMES


func _phase_verify_two() -> void:
	_verify_snapshot("load 2")
	_recap.append("after load 2: defeated=[%s] alive=[%s] carried=%d awards=%d" % [
		_defeated_names(_live_world()), _alive_names(_live_world()), _ledger.credits, _ledger.awards])

	# Kill once more after the SECOND return, so the world restored twice is proven to still be a
	# game that pays out rather than a state that can only be looked at.
	_awards_before_kills = _ledger.awards
	_begin_kills([VICTIM_B], STAGE_AFTER_FINAL, "kill %s after load 2" % VICTIM_B)


# --- Phase G: play on after the second return ---------------------------------

func _phase_after_final() -> void:
	print("[QUICKSAVE] --- PHASE G result: continued play after load 2 ---")
	var reward := int(_ledger.reward_per_enemy)
	_check(_is_defeated(_by_name[VICTIM_B]),
		"%s was KILLED again after the second return to the quicksave" % VICTIM_B)
	_check(_ledger.awards == _awards_before_kills + 1,
		"the third kill cycle paid exactly once (awards %d -> %d)"
			% [_awards_before_kills, _ledger.awards])
	_check(_ledger.credits == _credits_at_save + reward,
		"the twice-restored world still pays (want %d, got %d)"
			% [_credits_at_save + reward, _ledger.credits])
	_check(not _player_health.is_dead, "the player is still ALIVE and playable at the end")
	_log_world("AFTER FINAL")
	_recap.append("after final play: defeated=[%s] carried=%d awards=%d" % [
		_defeated_names(_live_world()), _ledger.credits, _ledger.awards])
	_stage = STAGE_FINISH


# --- The shared snapshot check, run after BOTH loads --------------------------

## Assert that the LIVE world and economy equal the snapshot taken at the save, for every actor, by
## scene path. Shared by both loads on purpose: the second return is the same contract, asserted
## again after more has happened in between, so a restore that only works once cannot pass.
func _verify_snapshot(tag: String) -> void:
	var live := _live_world()
	_log_world("AFTER LOAD " + tag)

	# PER-ACTOR, BY PATH: the same actors, each with the exact recorded state.
	var wrong: Array = []
	for path in _expect.keys():
		if not live.has(path):
			wrong.append("%s MISSING" % _short(path))
			continue
		var want: Dictionary = _expect[path]
		var got: Dictionary = live[path]
		if bool(want["defeated"]) != bool(got["defeated"]):
			wrong.append("%s defeated %s!=%s" % [_short(path), str(want["defeated"]), str(got["defeated"])])
		elif bool(want["dead"]) != bool(got["dead"]):
			wrong.append("%s dead %s!=%s" % [_short(path), str(want["dead"]), str(got["dead"])])
		elif not is_equal_approx(float(want["health"]), float(got["health"])):
			wrong.append("%s health %.1f!=%.1f" % [_short(path), float(want["health"]), float(got["health"])])
	_check(wrong.is_empty(),
		"%s: every actor was restored to the EXACT recorded state, by identity (%s)"
			% [tag, ", ".join(wrong)])
	print("[QUICKSAVE] %s identity check: before=[%s] after=[%s]" % [
		tag, _defeated_names(_expect), _defeated_names(live)])

	# THE reported case, stated in the report's own nouns.
	_check(_is_defeated(_by_name[VICTIM_A]),
		"%s: %s (killed BEFORE the save) is still DEFEATED" % [tag, VICTIM_A])
	_check(not _is_defeated(_by_name[VICTIM_B]) and not _is_defeated(_by_name[VICTIM_C]),
		"%s: %s and %s (killed AFTER the save) are ALIVE again" % [tag, VICTIM_B, VICTIM_C])

	# Targetability has to follow the restored state, both directions.
	for name in _by_name.keys():
		var actor: Node3D = _by_name[name]
		var want_dead := bool((_expect[String(actor.get_path())] as Dictionary)["defeated"])
		var usable := bool(CombatParticipant.is_usable_target(actor))
		_check(usable == (not want_dead),
			"%s: %s targetable=%s (snapshot defeated=%s)"
				% [tag, name, str(usable), str(want_dead)])

	# Coherence: the fields must agree with EACH OTHER, not only with the snapshot.
	var incoherent: Array = []
	for path in live.keys():
		var row: Dictionary = live[path]
		var defeated := bool(row["defeated"])
		var dead := bool(row["dead"])
		var targetable := bool(row["targetable"])
		if defeated and not dead:
			incoherent.append("%s defeated but not dead" % _short(path))
		if not defeated and dead:
			incoherent.append("%s dead but not defeated" % _short(path))
		if (defeated or dead) and targetable:
			incoherent.append("%s unusable but targetable" % _short(path))
		if not defeated and not dead and not targetable:
			incoherent.append("%s alive but not targetable" % _short(path))
		if defeated != bool(row["showing"]):
			incoherent.append("%s presentation showing=%s while defeated=%s"
				% [_short(path), str(row["showing"]), str(defeated)])
	_check(incoherent.is_empty(),
		"%s: health, death, defeat, targetability and presentation all AGREE (%s)"
			% [tag, ", ".join(incoherent)])

	# The world and the ECONOMY must agree. This is the defect the reward-history restore fixes: a
	# revived actor that the ledger still remembers paying is alive and worth nothing.
	_check(_ledger.credits == _credits_at_save,
		"%s: the carried balance is the recorded value (want %d, got %d)"
			% [tag, _credits_at_save, _ledger.credits])
	_check(_ledger.awards == _awards_before_load,
		"%s: the load paid NO reward (awards %d -> %d across the load)"
			% [tag, _awards_before_load, _ledger.awards])
	_check(_is_paid(_by_name[VICTIM_A]),
		"%s: the ledger still counts %s as PAID (it was dead in the snapshot)" % [tag, VICTIM_A])
	_check(not _is_paid(_by_name[VICTIM_B]) and not _is_paid(_by_name[VICTIM_C]),
		"%s: the ledger no longer counts %s/%s as paid, so a revived enemy is worth Credits again"
			% [tag, VICTIM_B, VICTIM_C])

	_check(not _player_health.is_dead, "%s: the player is ALIVE and playable" % tag)
	_check(_count_ledgers() == 1 and _count_saves() == 1,
		"%s: still exactly one ledger and one save service (ledgers=%d saves=%d)"
			% [tag, _count_ledgers(), _count_saves()])

	# The quicksave being returned to is the SAME one: nothing rewrote it on the way back.
	_check(_read_save_text() == _saved_text,
		"%s: the save file is UNCHANGED since the save, so this returned to the SAME quicksave" % tag)


# --- The real attack path -----------------------------------------------------

## Queue a sequence of real kills, then continue at `return_stage`. The kills are never assigned -
## each one has to happen through PlayerCombat, the hitbox, the health chain and the defeat
## component, exactly as it would for a player pressing the attack button.
func _begin_kills(names: Array, return_stage: int, label: String) -> void:
	if names.is_empty():
		_stage = return_stage
		return
	_kill_names = names.duplicate()
	_kill_index = 0
	_kill_return = return_stage
	_kill_label = label
	_victim = _by_name[_kill_names[0]]
	_attempts_left = ATTACK_ATTEMPTS
	_attack_phase = 0
	_stage = STAGE_KILL


func _stage_kill() -> void:
	if _victim == null or not is_instance_valid(_victim):
		_fail("%s: victim is gone" % _kill_label)
		_stage = _kill_return
		return

	if _attack_phase == 0:
		_approach(_victim)
		_press(GameActions.LIGHT_ATTACK, 3)
		_attack_phase = 1
		_wait = ATTACK_WAIT_FRAMES
		return

	_wait -= 1
	if _wait > 0:
		return

	if _is_defeated(_victim):
		_kill_index += 1
		if _kill_index >= _kill_names.size():
			_stage = _kill_return
			return
		_victim = _by_name[_kill_names[_kill_index]]
		_attempts_left = ATTACK_ATTEMPTS
		_attack_phase = 0
		return

	_attempts_left -= 1
	if _attempts_left <= 0:
		_fail("%s: could not defeat %s with %d real attacks"
			% [_kill_label, String(_victim.name), ATTACK_ATTEMPTS])
		_stage = _kill_return
		return
	_attack_phase = 0


## Stand the player beside `actor` and turn the body to face it.
##
## The player is PLACED rather than walked here on purpose, and it is test setup rather than a
## measured result: Cascadia has no navigation, so pathing the player across the arena and around
## scenery would be testing traversal, not the save/load contract. Everything that CHANGES state -
## the attack, the damage, the defeat, the reward - still happens through the real gameplay path,
## and Phase E separately proves real input movement works. Where the body came to rest before the
## swing is not part of what is being proved.
##
## The stance height is the FLOOR, not the victim's origin: one actor stands on a raised pedestal,
## and matching that height would leave the body airborne and falling through its own swing. The gap
## is measured HORIZONTALLY for the same reason - a pedestal's height difference is not distance.
func _approach(actor: Node3D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var base := actor.global_position
	var from := Vector3(base.x + APPROACH_OFFSET, APPROACH_FLOOR_Y, base.z)
	_player.global_position = from
	var to := Vector3(base.x - from.x, 0.0, base.z - from.z)
	_player.rotation.y = atan2(-to.x, -to.z)
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = Vector3.ZERO

	var flat := Vector3(
		base.x - _player.global_position.x, 0.0, base.z - _player.global_position.z)
	var gap := flat.length()
	if gap > (APPROACH_OFFSET + ARRIVE_TOLERANCE):
		_fail("could not stand beside %s (gap %.2f m)" % [String(actor.name), gap])


func _is_defeated(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	var death := actor.get_node_or_null("Death")
	if death != null and death.has_method("is_defeated"):
		return bool(death.call("is_defeated"))
	var health := _health_of(actor)
	return health != null and health.is_dead


## Whether this run has already been PAID for `actor`, asked through the ledger's own API. Guarded
## so a ledger without the query reports false rather than raising; the initial phase asserts the
## query exists, so that guard can never be the reason a check passes.
func _is_paid(actor: Node) -> bool:
	if _ledger == null or not _ledger.has_method("is_rewarded"):
		return false
	if actor == null or not is_instance_valid(actor):
		return false
	var death := actor.get_node_or_null("Death")
	if death == null:
		return false
	return bool(_ledger.call("is_rewarded", death))


# --- World reading -------------------------------------------------------------

## One actor's full observable state, each field read from its OWN owner.
func _state(actor: Node3D) -> Dictionary:
	var health := _health_of(actor)
	var death := actor.get_node_or_null("Death")
	var presentation := actor.get_node_or_null("DeathPresentation")
	return {
		"health": health.current_health if health != null else -1.0,
		"max_health": health.max_health if health != null else -1.0,
		"dead": health.is_dead if health != null else false,
		"defeated": bool(death.call("is_defeated")) if death != null and death.has_method("is_defeated") else false,
		"targetable": bool(CombatParticipant.is_usable_target(actor)),
		"showing": bool(presentation.call("is_showing")) if presentation != null and presentation.has_method("is_showing") else false,
	}


func _live_world() -> Dictionary:
	var out: Dictionary = {}
	for i in range(_actors.size()):
		out[_paths[i]] = _state(_actors[i])
	return out


func _log_world(tag: String) -> void:
	for i in range(_actors.size()):
		var row: Dictionary = _state(_actors[i])
		print("[QUICKSAVE]   %-12s %-12s hp=%6.1f/%-6.1f dead=%-5s defeated=%-5s targetable=%-5s showing=%s" % [
			tag, _short(String(_paths[i])), float(row["health"]), float(row["max_health"]),
			str(row["dead"]), str(row["defeated"]), str(row["targetable"]), str(row["showing"])])


func _defeated_names(world: Dictionary) -> String:
	var names: Array = []
	for path in world.keys():
		if bool((world[path] as Dictionary)["defeated"]):
			names.append(_short(String(path)))
	return ", ".join(names) if not names.is_empty() else "none"


func _alive_names(world: Dictionary) -> String:
	var names: Array = []
	for path in world.keys():
		if not bool((world[path] as Dictionary)["defeated"]):
			names.append(_short(String(path)))
	return ", ".join(names) if not names.is_empty() else "none"


func _short(path: String) -> String:
	var parts := path.split("/")
	return parts[parts.size() - 1] if parts.size() > 0 else path


# --- Save file ------------------------------------------------------------------

func _read_save_text() -> String:
	if not FileAccess.file_exists(GameStateSave.SAVE_PATH):
		return ""
	var file := FileAccess.open(GameStateSave.SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _read_save_file() -> Dictionary:
	var text := _read_save_text()
	if text.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	if parsed is Dictionary:
		return parsed
	return {}


## The `world.actors` block keyed by scene path, so the file's records can be compared to the
## snapshot by IDENTITY rather than by position in an array.
func _world_records(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var world_raw: Variant = data.get("world", {})
	if not (world_raw is Dictionary):
		return out
	var actors_raw: Variant = (world_raw as Dictionary).get("actors", [])
	if not (actors_raw is Array):
		return out
	for entry_raw in (actors_raw as Array):
		if entry_raw is Dictionary and (entry_raw as Dictionary).has("path"):
			out[String((entry_raw as Dictionary)["path"])] = entry_raw
	return out


func _backup_existing() -> void:
	_had_save = _save.has_save()
	if not _had_save:
		return
	_backup_text = _read_save_text()


func _restore_existing() -> void:
	if _had_save:
		var file := FileAccess.open(GameStateSave.SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(_backup_text)
			file.close()
		print("[QUICKSAVE] restored the save file that existed before this run")
	elif _save.delete_save():
		print("[QUICKSAVE] removed the probe's save (there was none before this run)")


# --- Resolution -----------------------------------------------------------------

func _resolve() -> void:
	_ledger = CreditLedger.find_ledger(get_tree())
	_save = GameStateSave.find_save(get_tree())

	# The player is the actor in the player group, and its death circuit is identified by ARCHETYPE
	# rather than by node name.
	_player = get_tree().get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR) as Node3D
	if _player == null:
		for node in get_tree().get_nodes_in_group(DeathComponent.GROUP_DEATH):
			if node != null and is_instance_valid(node):
				_player = node.get_parent() as Node3D
				break
	if _player == null:
		return

	_player_health = _health_of(_player)
	_player_death = _player.get_node_or_null("Death")
	_combat = _player.get_node_or_null("Combat")
	_hitbox = _player.get_node_or_null("AttackHitbox") as HitboxComponent

	# Identity is the SCENE PATH, sorted so an actor's index is stable between runs.
	var found: Array = []
	for node in get_tree().get_nodes_in_group(EnemyDeathComponent.GROUP_ENEMY_DEATH):
		if node == null or not is_instance_valid(node):
			continue
		var actor := node.get_parent() as Node3D
		if actor == null or not is_instance_valid(actor):
			continue
		if actor == _player:
			continue
		found.append(actor)
	found.sort_custom(func(a, b): return String(a.get_path()) < String(b.get_path()))
	for actor in found:
		_actors.append(actor)
		_paths.append(String(actor.get_path()))
		_by_name[String(actor.name)] = actor


func _require_victims() -> bool:
	for name in [VICTIM_A, VICTIM_B, VICTIM_C]:
		if not _by_name.has(name):
			_fail("the arena has no enemy named %s to drive the contract with" % name)
			return false
	return true


func _health_of(actor: Node) -> HealthComponent:
	if actor == null:
		return null
	return actor.get_node_or_null("Health") as HealthComponent


func _count_ledgers() -> int:
	return get_tree().get_nodes_in_group(CreditLedger.GROUP_LEDGER).size()


func _count_saves() -> int:
	return get_tree().get_nodes_in_group(GameStateSave.GROUP_SAVE).size()


# --- Input ----------------------------------------------------------------------

func _press(action: StringName, hold_frames: int = 2) -> void:
	if not InputMap.has_action(action):
		_fail("the project has no %s action, so this probe cannot drive it" % action)
		return
	Input.action_press(action)
	if not _held.has(action):
		_held.append(action)
	_release_frame = _frame + hold_frames


func _release_inputs() -> void:
	for action in _held:
		Input.action_release(action)
	_held.clear()
	_release_frame = -1


# --- Reporting -------------------------------------------------------------------

func _finish() -> void:
	if _done:
		return
	_release_inputs()
	_done = true
	print("[QUICKSAVE] --- summary ---")
	for line in _recap:
		print("[QUICKSAVE] %s" % line)
	if _failures.is_empty():
		print("[QUICKSAVE] RESULT: ALL CHECKS PASSED")
	else:
		print("[QUICKSAVE] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
	_restore_existing()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[QUICKSAVE]   PASS  %s" % message)
		return
	_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	print("[QUICKSAVE]   FAIL  %s" % message)
