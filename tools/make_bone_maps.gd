extends SceneTree
## Generates humanoid BoneMap resources for the Quaternius rigs (UAL1 "DEF-*" rig and UAL2 Unreal-style rig),
## so both animation sets retarget onto Godot's SkeletonProfileHumanoid.
## Run: <godot> --headless -s res://tools/make_bone_maps.gd

const FINGERS := {"Thumb": ["Metacarpal", "Proximal", "Distal"], "Index": ["Proximal", "Intermediate", "Distal"],
	"Middle": ["Proximal", "Intermediate", "Distal"], "Ring": ["Proximal", "Intermediate", "Distal"],
	"Little": ["Proximal", "Intermediate", "Distal"]}


func _init() -> void:
	_save("res://assets/models/characters/mannequin/ual1_bone_map.tres", _ual1())
	_save("res://assets/models/characters/animations/ual2_bone_map.tres", _ual2())
	quit()


func _ual1() -> Dictionary:
	var m := {"Root": "root", "Hips": "DEF-hips", "Spine": "DEF-spine.001", "Chest": "DEF-spine.002",
		"UpperChest": "DEF-spine.003", "Neck": "DEF-neck", "Head": "DEF-head"}
	var ual1_finger := {"Thumb": "thumb", "Index": "f_index", "Middle": "f_middle", "Ring": "f_ring", "Little": "f_pinky"}
	for side in [["Left", "L"], ["Right", "R"]]:
		var s: String = side[1]
		m[side[0] + "Shoulder"] = "DEF-shoulder." + s
		m[side[0] + "UpperArm"] = "DEF-upper_arm." + s
		m[side[0] + "LowerArm"] = "DEF-forearm." + s
		m[side[0] + "Hand"] = "DEF-hand." + s
		m[side[0] + "UpperLeg"] = "DEF-thigh." + s
		m[side[0] + "LowerLeg"] = "DEF-shin." + s
		m[side[0] + "Foot"] = "DEF-foot." + s
		m[side[0] + "Toes"] = "DEF-toe." + s
		for finger in FINGERS:
			for i in 3:
				m[side[0] + finger + FINGERS[finger][i]] = "DEF-%s.0%d.%s" % [ual1_finger[finger], i + 1, s]
	return m


func _ual2() -> Dictionary:
	var m := {"Root": "root", "Hips": "pelvis", "Spine": "spine_01", "Chest": "spine_02",
		"UpperChest": "spine_03", "Neck": "neck_01", "Head": "Head"}
	var ual2_finger := {"Thumb": "thumb", "Index": "index", "Middle": "middle", "Ring": "ring", "Little": "pinky"}
	for side in [["Left", "l"], ["Right", "r"]]:
		var s: String = side[1]
		m[side[0] + "Shoulder"] = "clavicle_" + s
		m[side[0] + "UpperArm"] = "upperarm_" + s
		m[side[0] + "LowerArm"] = "lowerarm_" + s
		m[side[0] + "Hand"] = "hand_" + s
		m[side[0] + "UpperLeg"] = "thigh_" + s
		m[side[0] + "LowerLeg"] = "calf_" + s
		m[side[0] + "Foot"] = "foot_" + s
		m[side[0] + "Toes"] = "ball_" + s
		for finger in FINGERS:
			for i in 3:
				m[side[0] + finger + FINGERS[finger][i]] = "%s_0%d_%s" % [ual2_finger[finger], i + 1, s]
	return m


func _save(path: String, mapping: Dictionary) -> void:
	var bone_map := BoneMap.new()
	bone_map.profile = SkeletonProfileHumanoid.new()
	for profile_bone in mapping:
		assert(bone_map.profile.find_bone(profile_bone) != -1, "unknown profile bone " + profile_bone)
		bone_map.set_skeleton_bone_name(profile_bone, mapping[profile_bone])
	var err := ResourceSaver.save(bone_map, path)
	print("saved %s (%d bones) err=%d" % [path, mapping.size(), err])
