extends Node

var saved_scripts: Array
var save_file_location: String = "user://save/"
var save_exists_file: String = save_file_location + "playerinfo.tres" # this file should always exist if a save game exists
var battle_file = save_file_location + "battle.tres" # this file should exist if the game was saved in battle

var subdirs: Array = ["npcs/", "enemies/", "minions/", ""] # last one is root save folder

# Called when the node enters the scene tree for the first time.
func _ready():
	get_tree().set_auto_accept_quit(false) # handle quit requests manually
	fetch_saved_scripts()
	
# handle quit requests: save game before quitting
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if get_node_or_null("/root/MainMenu") == null:
			if PlayerFinder.player == null or not PlayerFinder.player.inCutscene:
				save_data() # if not in the main menu or in a cutscene, save the game!
		SettingsHandler.save_data() # save settings
		get_tree().quit() # then quit

func fetch_saved_scripts():
	saved_scripts = ["PlayerResources"] # singletons to be saved
	for idx in range(len(saved_scripts)):
		saved_scripts[idx] = "/root/" + saved_scripts[idx]
	
	var persist_nodes = get_tree().get_nodes_in_group("Persist") # all objects in the group to be saved (persisted)
	for node in persist_nodes:
		saved_scripts.append("/" + node.get_path().get_concatenated_names().c_escape())

func save_data():
	create_save_subdirs()
	fetch_saved_scripts()
	for script_path in saved_scripts:
		var scr = get_node_or_null(NodePath(script_path))
		if scr != null and scr.has_method("save_data"):
			scr.call("save_data", save_file_location)
		else:
			print('SAVE ERROR ON ', script_path)

func load_data():
	create_save_subdirs()
	fetch_saved_scripts()
	for script_path in saved_scripts:
		var scr = get_node_or_null(NodePath(script_path))
		if scr != null and scr.has_method("load_data"):
			scr.call("load_data", save_file_location)
			
func new_game(characterName: String):
	fetch_saved_scripts()
	for subdir in subdirs: # for each save subdirectory
		if DirAccess.dir_exists_absolute(save_file_location + subdir):
			var files = DirAccess.get_files_at(save_file_location + subdir)
			for filepath in files: # remove all files inside the subdir
				DirAccess.remove_absolute(save_file_location + subdir + filepath)
			var err = DirAccess.remove_absolute(save_file_location + subdir) # then remove the subdir itself
			if err > 0:
				print("Remove save subdir ", subdir, " error ", err)
	
	create_save_subdirs()
	for script_path in saved_scripts:
		var scr = get_node_or_null(NodePath(script_path))
		if scr != null and scr.has_method("new_game"):
			scr.call("new_game", save_file_location)
		if scr != null and scr.has_method("name_player"):
			scr.call("name_player", save_file_location, characterName)
	
func save_file_exists():
	return FileAccess.file_exists(save_exists_file)

func is_save_in_battle():
	return FileAccess.file_exists(battle_file)

func create_save_subdirs():
	if not DirAccess.dir_exists_absolute(save_file_location):
		var err = DirAccess.make_dir_absolute(save_file_location)
		if err > 0:
			print("DirAccess create root save dir error ", err)
	
	for subdir in subdirs:
		if not DirAccess.dir_exists_absolute(save_file_location + subdir):
			var err = DirAccess.make_dir_absolute(save_file_location + subdir)
			if err > 0:
				print("DirAccess create dir ", subdir, " error ", err)
