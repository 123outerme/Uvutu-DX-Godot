extends Node

var saved_scripts: Array
var save_file_location: String = "user://"

var subdirs: Array = ["npcs/"]

var save_exists_file: String = "user://playerinfo.tres" # this file should always exist if a save game exists

# Called when the node enters the scene tree for the first time.
func _ready():
	get_tree().set_auto_accept_quit(false) # handle quit requests manually
	fetch_saved_scripts()
	
# handle quit requests: save game before quitting
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if get_node_or_null("/root/MainMenu") == null:
			save_data() # if not in the main menu, save the game!
		get_tree().quit() # then quit

func fetch_saved_scripts():
	saved_scripts = ["PlayerResources"]
	for item in len(saved_scripts):
		saved_scripts[item] = "/root/" + saved_scripts[item]
	
	var persist_nodes = get_tree().get_nodes_in_group("Persist")
	for node in persist_nodes:
		saved_scripts.append("/" + node.get_path().get_concatenated_names().c_escape())

func save_data():
	fetch_saved_scripts()
	for script_path in saved_scripts:
		var scr = get_node_or_null(NodePath(script_path))
		if scr != null and scr.has_method("save_data"):
			scr.call("save_data", save_file_location)

func load_data():
	fetch_saved_scripts()
	for script_path in saved_scripts:
		var scr = get_node_or_null(NodePath(script_path))
		if scr != null and scr.has_method("load_data"):
			scr.call("load_data", save_file_location)
			
func new_game():
	fetch_saved_scripts()
	for script_path in saved_scripts:
		var scr = get_node_or_null(NodePath(script_path))
		if scr != null and scr.has_method("new_game"):
			scr.call("new_game", save_file_location)
			
	for subdir in subdirs: # for each save subdirectory
		var files = DirAccess.get_files_at(save_file_location + subdir)
		for filepath in files: # remove all files inside the subdir
			DirAccess.remove_absolute(save_file_location + subdir + filepath)
		var err = DirAccess.remove_absolute(save_file_location + subdir) # then remove the subdir itself
		if err > 0:
			print("Remove save subdir error " + String.num(err))
			
func save_file_exists():
	return FileAccess.file_exists(save_exists_file)
