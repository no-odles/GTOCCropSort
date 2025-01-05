local sides = require("sides")
local config = {

    resistance_target = 2,
    max_growth = 23,
    source_side = sides.south,
    seed_store_side = sides.north,
    trash_side = sides.west,
    score_fuzziness = 3,
    max_dirty_cycles = 10,
    min_to_keep = 2
}

return config