class_name AutomationRule
extends RefCounted
## Data for one predefined IF/THEN automation. Evaluation logic lives in
## AutomationManager; this object only carries state for the UI and tests.

var id: String
var name: String
var trigger_text: String
var action_text: String
var description: String
var enabled := true
var status := "Monitoring"
var engaged := false        ## true while the rule's action is active (and it started it)
var zone := ""              ## last evaluated condition zone - rules act on zone *entry*
var fire_count := 0
var last_event := "-"
var timer := 0.0            ## rule-specific countdown (e.g. floodlight hold time)


func _init(p_id: String, p_name: String, p_trigger: String, p_action: String, p_desc: String) -> void:
	id = p_id
	name = p_name
	trigger_text = p_trigger
	action_text = p_action
	description = p_desc
