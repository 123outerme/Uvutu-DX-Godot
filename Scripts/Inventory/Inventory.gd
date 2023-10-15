extends Resource
class_name Inventory

@export var inventorySlots: Array[InventorySlot]
@export var isPlayerInventory: bool = false

var save_name: String = "inventory.tres"

func _init(i_slots: Array[InventorySlot] = [], i_playerInv = false):
	inventorySlots = i_slots
	isPlayerInventory = i_playerInv
	
func add_item(item: Item) -> bool:
	var found: bool = false
	for slot in inventorySlots:
		if slot.item == item:
			found = true
			if slot.count < slot.item.maxCount or slot.item.maxCount == 0:
				slot.count += 1
				add_shard_minion_entry(item)
				return true
	# if not found, add a new slot
	if not found:
		inventorySlots.append(InventorySlot.new(item))
		add_shard_minion_entry(item)
		return true
	return false

func add_shard_minion_entry(item: Item):
	if isPlayerInventory and item.itemType == Item.Type.SHARD:
		var shard: Shard = item as Shard
		var minion: Combatant = PlayerResources.minions.get_minion(shard.combatantSaveName) # if it does not exist, this will create it
		PlayerResources.minions.level_up_minions(PlayerResources.playerInfo.stats.level) # if necessary, this will level up the new minion

func use_item(item: Item, target: Combatant):
	item.use(target)
	for slot in inventorySlots:
		if slot.item == item and item.consumable:
			trash_item(slot) # remove one of the appropriate items
	
func equip_item(inventorySlot: InventorySlot, equip: bool = true):
	var item: Item = inventorySlot.item
	if not equip:
		item = null
	
	if inventorySlot.item is Weapon:
		PlayerResources.playerInfo.stats.equippedWeapon = item
	if inventorySlot.item is Armor:
		PlayerResources.playerInfo.stats.equippedArmor = item

func is_equipped(item: Item) -> bool:
	if item is Weapon:
		return PlayerResources.playerInfo.stats.equippedWeapon == item
	if item is Armor:
		return PlayerResources.playerInfo.stats.equippedArmor == item
	return false

func trash_item(inventorySlot: InventorySlot):
	inventorySlot.count -= 1
	if inventorySlot.count <= 0:
		inventorySlots.erase(inventorySlot)

func get_sorted_slots() -> Array[InventorySlot]:
	var slots: Array[InventorySlot] = []
	slots.append_array(inventorySlots)
	slots.sort_custom(sort_by_equipped)
	return slots

func sort_by_equipped(a: InventorySlot, b: InventorySlot) -> bool:
	var aEquipped: bool = PlayerResources.playerInfo.stats.equippedArmor == a.item \
			or PlayerResources.playerInfo.stats.equippedWeapon == a.item
	var bEquipped: bool = PlayerResources.playerInfo.stats.equippedArmor == b.item \
			or PlayerResources.playerInfo.stats.equippedWeapon == b.item
	if aEquipped and not bEquipped:
		return true
	if bEquipped and not aEquipped:
		return false
	return a.item.itemName.naturalnocasecmp_to(b.item.itemName) < 0 # compare names (including natural number comparisons)

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
		printerr("Inventory ResourceSaver error: ", err)
