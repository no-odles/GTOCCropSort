local db = require("database")
local config = require("config")


local function evalCrop(scan)
    local res_score
    local name = scan.crop.name

    res_score = -math.abs(scan.crop.resistance - config.resistance_target)

    if scan.crop.growth > config.max_growth then
        return db.WORST
    end
    
    local score =  math.max(0, scan.crop.growth + scan.crop.gain + res_score) -- -1 is empty, so literally any correct crop must be better than that

    return name, score

end

local function shouldReplace(scan, best)
    local name, score = evalCrop(scan)

    return math.abs(best - score) > config.score_fuzziness
end

return {evalCrop=evalCrop}