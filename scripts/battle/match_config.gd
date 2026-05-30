# scripts/battle/match_config.gd
class_name MatchConfig
extends Resource

## Carries match setup data from skirmish_setup into match_view.
## Stored transiently in Engine meta; never saved to disk.

var player_squad: Array[MonsterData] = []
var enemy_squad:  Array[MonsterData] = []
var difficulty:   int = 2  # 1=Easy  2=Normal  3=Hard
var is_ranked:    bool = false
