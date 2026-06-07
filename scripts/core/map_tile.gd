class_name MapTile

var height: int = 0
# 0 = ground, 1 = raised, 2 = cliff

var terrain: StringName = &"grass"
# &"grass" | &"stone" | &"snow" | &"desert" | &"water" | &"lava"

var decoration: StringName = &"none"
# &"none" | &"rock" | &"tree" | &"fence" | &"flower"
