extends Resource
class_name QuestInventory

@export var quests: Array[QuestTracker] = []
@export var currentAct: int = 0

var save_name: String = "quests.tres"

func _init(i_quests: Array[QuestTracker] = [], i_act = 0):
	quests = i_quests
	currentAct = i_act

func get_quest_tracker_by_quest(q: Quest) -> QuestTracker:
	for questTracker in quests:
		if q == questTracker.quest:
			return questTracker
	return null

func get_quest_tracker_by_name(name: String) -> QuestTracker:
	for questTracker in quests:
		if questTracker.quest.questName == name:
			return questTracker
	return null
	
func get_quest_tracker_for_step(step: QuestStep) -> QuestTracker:
	for questTracker in quests:
		if questTracker.get_step_index(step) >= 0:
			return questTracker
	return null
	
func get_cur_trackers_for_target(targetName: String) -> Array[QuestTracker]:
	var trackers: Array[QuestTracker] = []
	for questTracker in quests:
		var curStep = questTracker.get_current_step()
		if curStep.objectiveName == targetName:
			trackers.append(questTracker)
	return trackers

func can_start_quest(q: Quest) -> bool:
	return has_completed_prereqs(q.prerequisiteQuestNames) and act_is_within_quest_range(q) and get_quest_tracker_by_quest(q) == null

func has_completed_prereqs(prereqNames: Array[String]) -> bool:
	var hasCompleted: bool = true
	for name in prereqNames:
		var completedPrereq: bool = false
		var tracker: QuestTracker = get_quest_tracker_by_name(name)
		if tracker != null and tracker.get_current_status() == QuestTracker.Status.COMPLETED:
			completedPrereq = true
		hasCompleted = hasCompleted and completedPrereq
	return hasCompleted

func act_is_within_quest_range(q: Quest) -> bool:
	return currentAct >= q.availableAtAct and currentAct <= q.unavailableAfterAct

func accept_quest(q: Quest):
	if get_quest_tracker_by_quest(q) != null:
		return
	var tracker: QuestTracker = QuestTracker.new(q)
	quests.append(tracker)

func update_collect_quests():
	for tracker in quests:
		if tracker.get_current_step().type == QuestStep.Type.COLLECT_ITEM:
			var count: int = 0
			for slot in PlayerResources.inventory.inventorySlots:
				if slot.item.itemName == tracker.get_current_step().objectiveName:
					count += slot.count
			tracker.set_current_step_progress(count)

func set_quest_progress(target: String, type: QuestStep.Type, progress: int = 0):
	for tracker in get_cur_trackers_for_target(target):
		if tracker.get_current_step().type == type:
			tracker.set_current_step_progress(progress)
	
func progress_quest(target: String, type: QuestStep.Type, progress: int = 1):
	for tracker in get_cur_trackers_for_target(target):
			if tracker.get_current_step().type == type:
				tracker.add_current_step_progress(progress)

func turn_in_cur_step(tracker: QuestTracker) -> int:
	var curStep: QuestStep = tracker.get_current_step()
	var newLvs: int = PlayerResources.accept_rewards([curStep.reward])
	if curStep.type == QuestStep.Type.COLLECT_ITEM:
		PlayerResources.inventory.trash_items_by_name(curStep.objectiveName, curStep.count)
	
	var _allDone: bool = tracker.turn_in_step()
	
	return newLvs

func get_sorted_trackers() -> Array[QuestTracker]:
	var trackers: Array[QuestTracker] = []
	trackers.append_array(quests)
	trackers.sort_custom(sort_by_pinned)
	return trackers

func sort_by_pinned(a: QuestTracker, b: QuestTracker) -> bool:
	if a.pinned and not b.pinned:
		return true # a goes before b
	if b.pinned and not a.pinned:
		return false # b goes before a
	return a.quest.questName.naturalnocasecmp_to(b.quest.questName) < 0 # compare names (including natural number comparisons)

func load_data(save_path):
	var data = null
	if ResourceLoader.exists(save_path + save_name):
		data = load(save_path + save_name)
		if data != null:
			return data #.duplicate(true)
	return data

func save_data(save_path, data):
	var err = ResourceSaver.save(data, save_path + save_name)
	if err != 0:
		printerr("QuestInventory ResourceSaver error: ", err)
