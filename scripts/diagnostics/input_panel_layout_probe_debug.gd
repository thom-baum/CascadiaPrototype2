class_name InputPanelLayoutProbeDebug
extends Node3D
## Temporary diagnostic (UI unification pass - the INPUT FOUNDATION panel). Not production.
##
## WHY A PROBE RATHER THAN A LOOK AT THE SCREEN. The input foundation table is the one panel whose
## HEIGHT is a function of the WINDOW rather than of its own content, so two of the properties that
## were actually asked for cannot be judged from a single screenshot at a single size:
##
##   - does the panel's bottom edge stay inside the viewport (no silent clipping), and
##   - did splitting the table in two keep EVERY input action, or did a row go missing in the split.
##
## So this measures the live geometry and the live row count instead. It reads the real
## `main.tscn` instance, through the same `ScreenRegions` group a consumer would use, and it asserts
## the relationship the layout is supposed to hold - not a rectangle that happens to look right.
##
## It reports the blocked/stacked decision as a READING rather than a pass or fail, because BOTH are
## correct: two columns are right when they fit the region and one column is right when they do not.
## What is asserted is the rule behind the choice - two columns are shown ONLY when both of them
## actually fit, so neither can ever be crushed.
##
## Prints console AND writes res://input_panel_layout_probe_report.txt, because the console tail is
## truncated and a measurement nobody can read is not evidence.

const REPORT_PATH := "res://input_panel_layout_probe_report.txt"
## Frames to let every _ready() and the first layout pass in the arena complete.
const SETTLE_FRAMES := 5
## A pixel of slack, so float rounding cannot fail a layout that is exactly flush.
const TOLERANCE := 0.5

var _main: Node3D
var _lines: Array[String] = []
var _failures: Array[String] = []
var _passed := 0
var _failed := 0


func _ready() -> void:
	# The game root is a SIBLING of this probe, not a child, so the probe is never itself inside the
	# tree it measures.
	_main = get_node_or_null("../Main") as Node3D
	for _i in SETTLE_FRAMES:
		await get_tree().physics_frame
	# AWAITED, because the narrow-fallback scenario below drives the layout and has to let it settle.
	await _run()
	_write_report()


func _run() -> void:
	var viewport := get_viewport().get_visible_rect().size
	_say("viewport (logical canvas): %.0f x %.0f" % [viewport.x, viewport.y])
	# THE CONSTANTS ARE PRINTED, not assumed. The reflow decision depends on how wide the region actually
	# is, and a reading that disagrees with what the constants say is the difference between a layout bug
	# and a stale scene - so both numbers are stated side by side.
	_say("ScreenRegions: LEFT_COLUMN_END=%.2f  RIGHT_COLUMN_START=%.2f  LEFT_COLUMN_SPLIT=%.2f  EDGE_MARGIN=%.0f"
		% [ScreenRegions.LEFT_COLUMN_END, ScreenRegions.RIGHT_COLUMN_START,
			ScreenRegions.LEFT_COLUMN_SPLIT, ScreenRegions.EDGE_MARGIN])
	_say("INPUT_DIAGNOSTICS bounds [left,top,right,bottom]: %s"
		% str(ScreenRegions.bounds(ScreenRegions.Region.INPUT_DIAGNOSTICS)))

	var overlay := _main.get_node_or_null("InputDebugOverlay") if _main != null else null
	_expect(overlay != null, "the InputDebugOverlay resolved in the live tree")
	if overlay == null:
		return

	var host := _find_host()
	_expect(host != null, "the INPUT_DIAGNOSTICS region host resolved through its group")
	if host == null:
		return
	_say("region host: pos %.0f,%.0f  size %.0f x %.0f"
		% [host.global_position.x, host.global_position.y, host.size.x, host.size.y])

	var scroll := _find_descendant(host, "RegionScroll") as ScrollContainer
	_expect(scroll != null, "the input panel is BOUNDED by a region scroll container")
	if scroll == null:
		return

	var panel := scroll.get_child(0) as Control
	_expect(panel != null, "the input panel resolved inside its bound")
	if panel == null:
		return

	var minimum := panel.get_combined_minimum_size()
	_say("scroll rect: pos %.0f,%.0f  size %.0f x %.0f"
		% [scroll.global_position.x, scroll.global_position.y, scroll.size.x, scroll.size.y])
	_say("panel rect:  pos %.0f,%.0f  size %.0f x %.0f  min %.0f x %.0f"
		% [panel.global_position.x, panel.global_position.y, panel.size.x, panel.size.y,
			minimum.x, minimum.y])

	# THE NO-CLIP PROPERTY, which is the one the resize was reported to threaten. Asserted against the
	# VIEWPORT for the symptom, and against the REGION for the cause: the region is what makes the
	# first one true at every size rather than at the size being measured.
	# WHAT IS ASSERTED HERE IS THE INTENT, not a shape. The no-clip promise is that the panel's BOUND
	# stays inside the viewport and that its content is either visible or reachable by scrolling.
	# Asserting "the panel's bottom edge is inside the viewport" would instead FORBID the controlled
	# internal scrolling this layout is explicitly allowed to use on a short window - so it would fail
	# on a correct layout, which is a trap this pass already fell into once and is not repeating.
	var scroll_bottom := scroll.global_position.y + scroll.size.y
	_expect(scroll_bottom <= viewport.y + TOLERANCE,
		"the panel's BOUND is inside the viewport (%.0f <= %.0f)" % [scroll_bottom, viewport.y])
	_expect(panel.size.x - scroll.size.x <= TOLERANCE,
		"the panel does not exceed its bound HORIZONTALLY (%.0f <= %.0f)"
			% [panel.size.x, scroll.size.x])
	var over_tall := maxf(0.0, panel.size.y - scroll.size.y)
	_expect(over_tall <= TOLERANCE or scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED,
		"the table either fits its bound or is reachable by scrolling (%.0f px over)" % over_tall)

	var flow := _find_descendant(panel, "AdaptiveColumns") as HFlowContainer
	_expect(flow != null, "the table's adaptive column container resolved")
	var expected := _expected_rows()
	var built := 0
	# Declared OUTSIDE the membership test because the narrow-fallback scenario below re-reads the same
	# two blocks after driving the width down and back up again.
	var first: Control = null
	var second: Control = null
	if flow != null:
		var blocks := flow.get_children()
		_expect(blocks.size() == 2, "the table is split into exactly TWO blocks (%d)" % blocks.size())
		built = _count_rows(flow)
		if blocks.size() == 2:
			first = blocks[0] as Control
			second = blocks[1] as Control
			var side_by_side := absf(first.global_position.y - second.global_position.y) < 1.0
			_say("block positions: (%.0f,%.0f) and (%.0f,%.0f) -> %s"
				% [first.global_position.x, first.global_position.y,
					second.global_position.x, second.global_position.y,
					"SIDE BY SIDE" if side_by_side else "STACKED - narrow reflow"])
			# THE REFLOW RULE, which is what makes either reading correct. Two columns are only
			# allowed when the two of them genuinely fit the region they were given; when they do not,
			# the layout must have wrapped rather than show two cramped columns.
			# The budget is the width the FLOW CONTAINER was actually given - not the region host's width,
			# which is wider than the flow by the panel's own style margins. Comparing against the host
			# was an off-by-the-margins error that could pass a stacked layout the region could not
			# explain, so the comparison is made against the container that implements the reflow.
			var combined := first.size.x + second.size.x + ScreenRegions.ADAPTIVE_SEPARATION
			if side_by_side:
				_expect(combined <= flow.size.x + TOLERANCE,
					"two columns are shown only because the pair FITS the width they were given (%.0f <= %.0f)"
						% [combined, flow.size.x])
			else:
				_expect(combined > flow.size.x - TOLERANCE,
					"the layout stacked because the pair genuinely does NOT fit (%.0f > %.0f)"
						% [combined, flow.size.x])

	# EVERY ROW MUST SURVIVE THE SPLIT. The two blocks partition the groups, so this is the check that
	# the partition is exhaustive and no action was silently dropped between the halves.
	_expect(built == expected,
		"every input action still has a row (built %d, expected %d)" % [built, expected])
	_say("rows built: %d | actions in GameActions.GROUPS: %d" % [built, expected])

	# --- THE NARROW FALLBACK, DRIVEN DIRECTLY ------------------------------------------------------
	# THIS HOST CANNOT RESIZE ITS OWN WINDOW, so a narrow window cannot be produced by resizing. The
	# property is driven at its CAUSE instead: the reflow container is granted a single-column width,
	# which is exactly what a narrow window produces, and is then granted the full width again. That
	# distinguishes "the fallback rule is written down" from "the table demonstrably wraps", which is
	# the difference the request actually asks to be shown.
	if first == null or second == null or flow == null:
		return
	var wide_width := flow.custom_minimum_size.x
	var single := maxf(first.size.x, second.size.x)
	flow.custom_minimum_size.x = single
	await _settle_layout()
	var wrapped := absf(first.global_position.y - second.global_position.y) > 1.0
	_expect(wrapped,
		"a width that fits ONE column makes the table STACK instead of crushing two columns (%.0f px)" % single)
	_say("narrow width %.0f -> stacked=%s" % [single, str(wrapped)])
	flow.custom_minimum_size.x = wide_width
	await _settle_layout()
	var restored := absf(first.global_position.y - second.global_position.y) < 1.0
	_expect(restored, "restoring the width brings the two columns back")
	_say("restored width %.0f -> side by side=%s" % [wide_width, str(restored)])


## Let a changed layout settle before it is measured. Two frames: one for the container to re-place the
## blocks, one for the result to be readable.
func _settle_layout() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


## The number of action rows the table is supposed to contain, read from the SAME source the panel
## builds from, so the expectation cannot drift from the table by being restated here.
func _expected_rows() -> int:
	var total := 0
	for group_name in GameActions.GROUPS:
		var actions = GameActions.GROUPS[group_name]
		total += actions.size()
	return total


## Every action row is one HBoxContainer of name/binding/state labels, so counting them counts rows.
func _count_rows(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		if child is HBoxContainer:
			total += 1
		total += _count_rows(child)
	return total


func _find_host() -> VBoxContainer:
	for node in get_tree().get_nodes_in_group(
			ScreenRegions.host_group(ScreenRegions.Region.INPUT_DIAGNOSTICS)):
		var column := node as VBoxContainer
		if column != null:
			return column
	return null


func _find_descendant(root: Node, wanted: String) -> Node:
	if root == null:
		return null
	for child in root.get_children():
		if child.name == wanted:
			return child
		var found := _find_descendant(child, wanted)
		if found != null:
			return found
	return null


func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		_say("PASS  %s" % label)
	else:
		_failed += 1
		_failures.append(label)
		_say("FAIL  %s" % label)


func _say(message: String) -> void:
	_lines.append(message)
	print("[INPUTLAYOUT] %s" % message)


func _write_report() -> void:
	_lines.append("")
	_lines.append("RESULT: %s (%d passed, %d failed)" % [
		"ALL CHECKS PASSED" if _failed == 0 else "%d CHECK(S) FAILED" % _failed,
		_passed, _failed])
	for label in _failures:
		_lines.append("  FAILED: %s" % label)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		print("[INPUTLAYOUT] could not write report to %s" % REPORT_PATH)
		return
	file.store_string("\n".join(PackedStringArray(_lines)))
	file.close()
	print("[INPUTLAYOUT] report written to %s" % REPORT_PATH)
