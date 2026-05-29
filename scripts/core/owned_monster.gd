# scripts/core/owned_monster.gd
class_name OwnedMonster
extends RefCounted

var data:            MonsterData
var duplicate_count: int = 0
