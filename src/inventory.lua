local sides = require("sides")
local component = require("component")
local tr = component.transposer

local db = require("database")
local config = require("config")
local sc = require("score")

local function deleteFromSource(slot)
    local ntransferred = tr.transferItem(config.source_side, config.trash_side, 64, slot, 1)
    return ntransferred ~= 0
end

local function deleteFromStorage(name, slot, no_update)
    local ntransferred = tr.transferItem(config.seed_store_side, config.trash_side, 64, slot, 1)
    if not no_update then
        db.incN(name, -ntransferred) -- does not update worst(), need to call cleanAll for that
    end
    return ntransferred ~= 0
end


local function storeAt(slot, name, score)
    local out_slot = tr.getInventorySize(config.seed_store_side)
    local ntransferred = tr.transferItem(config.source_side, config.seed_store_side, 64, slot, out_slot)

    local n, worst, best = db.getEntry(name)

    if n == nil then
        n = 0
        best = score
        worst = score
    elseif score >= best then
        best = score
    elseif score < worst then
        worst = score
    end

    n = n + ntransferred


    db.setEntry(name, n, worst, best)

    return ntransferred ~= 0
end


local function storeInInv(slot, item_stack)
    -- designed to work with a filing cabinet + a trash can
    local store = false
    local name, score = sc.evalCrop(item_stack)

    local n, worst, best
    local db_entry = db.getEntry(name)

    if db_entry ~= nil then
        n, worst, best = table.unpack(db_entry)
        if best - score <= config.score_fuzziness then -- best - score being negative is ok
            store = true
        end
    end
    
    if store then
        return storeAt(slot, score)
    else
        return deleteFromSource(slot)
    end
end


local function dumpInv()
    print("Emptying inventory!")
    local success = true
    local transferred = false

    local slots = tr.getAllStacks(config.source_side).getAll()


    local i = 1
    for k, stack in pairs(slots) do
        if stack.crop == nil then
            break
        end

        success = storeInInv(i, stack)

        if ~success then
            print("unable to store item!")
            success = false
            break
        else
            transferred = true
        end

    end


    return success, transferred
end

local function cleanAll()
    print("Cleaning inventory!")
    local success = true
    local bests = db.getBests()
    local worsts = {}
    local needs_cleaning = db.needsCleaning()

    local slots = tr.getAllStacks(config.seed_store_side).getAll()

    local name, score, keep, worst

    local i = 1
    for k, stack in pairs(slots) do
        if stack.crop == nil then
            break
        end

        if needs_cleaning[stack.crop.name] then
            name, score = sc.evalCrop(stack)

            keep = bests[name] - score <= config.score_fuzziness

            if keep then
                -- logic to keep the worsts updated
                worst = worsts[name]
                if worst == nil or worst > score then
                    worsts[name] = score
                end

            else
                success = deleteFromStorage(name, i)
                i = i - 1 -- the relative position of everything is shifted by one
            end

            if ~success then
                print("unable to delete item!")
                return false
            end
        end

        
        i = i + 1
    end
    -- update worsts
    for k,v in pairs(worsts) do
        db.setWorst(k,v)
    end


    return success
end

local function initDB()
    print("Initialising inventory!")
    local success = true
    local bests = {}
    local worsts = {}
    local ns = {}

    local slots = tr.getAllStacks(config.seed_store_side).getAll()
    local name, score, keep, n, worst, best

    local i = 1
    for k, stack in pairs(slots) do
        
        if stack.crop == nil then
            break
        end

        name, score = sc.evalCrop(stack)

        best = bests[name]

        if best ==  nil or score > best then
            bests[name] = score
        end

        keep = bests[name] - score <= config.score_fuzziness

        if keep then
            -- update worsts and n
            worst = worsts[name]
            if worst == nil or worst > score then
                worsts[name] = score
            end

            n = ns[name]
            if n == nil then
                ns[name] = stack.size
            else
                ns[name] = n + stack.size
            end

        else
            success = deleteFromStorage(name, i, true)
            i = i - 1 -- the relative position of everything is shifted by one
        end

        if ~success then
            print("Unable to delete item during init!")
            return false
        end
        i = i + 1
    end
    -- update worsts
    db.initDB(ns, worsts, bests)


    return success

end


return {
    dumpInv=dumpInv,
    cleanAll=cleanAll,
    initDB=initDB
}