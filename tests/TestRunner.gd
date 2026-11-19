extends Node
## Headless test runner. Usage:
##   godot --headless --path . res://tests/TestRunner.tscn [-- --results=<file>]
## Exit code = number of failed tests.

const SUITES := [
	"res://tests/test_devices.gd",
	"res://tests/test_automation.gd",
	"res://tests/test_integration.gd",
	"res://tests/test_smart_devices.gd",
]


func _ready() -> void:
	DeviceManager.auto_simulate = false
	_run.call_deferred()


func _run() -> void:
	var lines: Array[String] = []
	var passed := 0
	var failed := 0
	var start := Time.get_ticks_msec()
	lines.append("IoT Smart Farm Simulator - automated tests")
	lines.append("Godot %s  |  %s" % [Engine.get_version_info().string, Time.get_datetime_string_from_system()])
	lines.append("")
	for path in SUITES:
		var script: GDScript = load(path)
		lines.append("== %s" % path.get_file())
		for m in script.get_script_method_list():
			var mname: String = m.name
			if not mname.begins_with("test_"):
				continue
			var suite: TestCase = script.new()
			suite.runner = self
			suite.before_each()
			suite.call(mname)
			suite.after_each()
			if suite.failures.is_empty():
				passed += 1
				lines.append("  PASS  %s" % mname)
			else:
				failed += 1
				lines.append("  FAIL  %s" % mname)
				for f in suite.failures:
					lines.append("          - %s" % f)
	lines.append("")
	lines.append("RESULT: %d passed, %d failed  (%d ms)" % [passed, failed, Time.get_ticks_msec() - start])
	var text := "\n".join(lines)
	print(text)
	var out_path := "user://test_results.txt"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--results="):
			out_path = a.substr(10)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(text + "\n")
		f.close()
	get_tree().quit(failed)
