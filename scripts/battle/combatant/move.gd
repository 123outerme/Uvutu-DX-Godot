extends Resource
class_name Move

enum DmgCategory {
	PHYSICAL = 0,
	MAGIC = 1,
	AFFINITY = 2,
}

enum MoveEffectType {
	NONE = 0,
	CHARGE = 1,
	SURGE = 2,
	BOTH = 3,
}

@export var moveName: String = ''
@export var requiredLv: int = 1
@export var category: DmgCategory = DmgCategory.PHYSICAL
@export var chargeEffect: MoveEffect = null
@export var surgeEffect: MoveEffect = null
@export_multiline var description: String = ''
@export_multiline var moveLearnedText: String = ''
@export var moveAnimation: MoveAnimation = null

static func dmg_category_to_string(c: DmgCategory) -> String:
	match c:
		DmgCategory.PHYSICAL:
			return 'Physical'
		DmgCategory.MAGIC:
			return 'Magic'
		DmgCategory.AFFINITY:
			return 'Affinity'
	return 'UNKNOWN'

static func move_effect_type_to_string(t: MoveEffectType) -> String:
	match t:
		MoveEffectType.NONE:
			return 'None'
		MoveEffectType.CHARGE:
			return 'Charge'
		MoveEffectType.SURGE:
			return 'Surge'
		MoveEffectType.BOTH:
			return 'Both'
	return 'UNKNOWN'

func _init(
	i_moveName = '',
	i_requiredLv = 1,
	i_category = DmgCategory.PHYSICAL,
	i_chargeEffect = null,
	i_surgeEffect = null,
	i_description = '',
	i_moveLearnedText = '',
	
):
	moveName = i_moveName
	requiredLv = i_requiredLv
	category = i_category
	chargeEffect = i_chargeEffect
	surgeEffect = i_surgeEffect
	description = i_description
	moveLearnedText = i_moveLearnedText

func get_effect_of_type(t: MoveEffectType) -> MoveEffect:
	if t == MoveEffectType.CHARGE:
		return chargeEffect
	
	if t == MoveEffectType.SURGE:
		return surgeEffect
	
	return null

func effects_with_status() -> MoveEffectType:
	var chargeStatus: bool = chargeEffect.statusEffect != null
	var surgeStatus: bool = surgeEffect.statusEffect != null
	
	if chargeStatus and surgeStatus:
		return MoveEffectType.BOTH
	
	if chargeStatus:
		return MoveEffectType.CHARGE
	
	if surgeStatus:
		return MoveEffectType.SURGE
	
	return MoveEffectType.NONE

func effects_with_role(role: MoveEffect.Role) -> MoveEffectType:
	var chargeHeals: bool = chargeEffect.role == role
	var surgeHeals: bool = surgeEffect.role == role
	
	if chargeHeals and surgeHeals:
		return MoveEffectType.BOTH
	
	if chargeHeals:
		return MoveEffectType.CHARGE
	
	if surgeHeals:
		return MoveEffectType.SURGE
	
	return MoveEffectType.NONE
