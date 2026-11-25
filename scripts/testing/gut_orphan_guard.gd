extends GutHookScript

## Post-run gate: fail the GUT command if any node was left orphaned.
## GUT reports orphans in its summary, but a summary alone cannot fail CI;
## this hook turns that signal into a non-zero exit code.
##
## Loaded as a GUT hook via `-gpost_run_script=...` from `gut_cmdln.gd`.
## It is not a SceneTree script and must not be run with `godot -s`.

func run() -> void:
	var counter: Object = gut.get_orphan_counter()
	counter.call("record_orphans", "post_run")
	var count := int(counter.call("orphan_count"))
	if count > 0:
		gut.logger.error("Orphan guard: %d orphaned node(s) after test run." % count)
		set_exit_code(1)
	else:
		gut.logger.info("Orphan guard: 0 orphaned nodes.")
