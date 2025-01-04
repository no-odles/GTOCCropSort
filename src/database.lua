local config = require("config")


local db = {} -- db["cropname"] = {n, worst, best}

local function getEntry(key)
    local entry = db[key]
    if entry ~= nil then 
        return table.unpack(db[key])
    else
        return nil
    end
end

local function setEntry(key, n, worst, best)
    db[key] = {n, worst, best}
end



local function getN(key)
    local entry = db[key]

    if entry ~= nil then
        return entry[1]
    end
end

local function setN(key, n)
    -- will error if db[key] is nil
    db[key][1] = n
end

local function incN(key, dn)
    -- will error if db[key] is nil
    db[key][1] = db[key][1] + dn
end


local function getWorst(key)
    local entry = db[key]

    if entry ~= nil then
        return entry[3]
    end
end

local function setWorst(key, worst)
    -- will error if db[key] is nil
    db[key][2] = worst
end

local function getBest(key)
    local entry = db[key]

    if entry ~= nil then
        return entry[3]
    end
end

local function setBest(key, best)
    -- will error if db[key] is nil
    db[key][3] = best
end


local function initDB(ns, worsts, bests)
    db = {}
    for k,n in pairs(ns) do
        db[k] = {n, worsts[k], bests[k]}
    end
end

local function keyNeedsCleaning(key)
    local _, best, worst = table.unpack(db[key])

    return best - worst > config.score_fuzziness
end

local function needsCleaning()
    local needs_cleaning
    for k,v in pairs(db) do
        local _, best, worst = table.unpack(v)
        needs_cleaning[k] = best - worst > config.score_fuzziness
    end
    return needs_cleaning
end


local function getBests()

    local bests = {}
    for k,v in pairs(db) do
        bests[k] = v[3]
    end
    return bests
end



return {
    -- getters/setters
    
    getEntry=getEntry, 
    setEntry=setEntry, 
    getN=getN,
    incN=incN,
    setN=setN,
    getWorst=getWorst,
    setWorst=setWorst,
    getBest=getBest,
    setBest=setBest,
    
    initDB=initDB,
    needsCleaning=needsCleaning,
    getBests=getBests

}