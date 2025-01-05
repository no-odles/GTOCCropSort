local sides = require("sides")
local component = require("component")
local tr = component.transposer

local db = require("database")
local config = require("config")
local sc = require("score")
local tslot = 0

local function getTSlot()
    tslot = (tslot + 1) % 64
    return tslot + 2 -- slots 2-65 are valid destinations
end

local function deleteFromSource(slot)
    local ntransferred = tr.transferItem(config.source_side, config.trash_side, 64, slot, getTSlot())
    return ntransferred ~= 0
end

local function deleteFromStorage(name, slot, no_update)
    local ntransferred = tr.transferItem(config.seed_store_side, config.trash_side, 64, slot, getTSlot())
    if not no_update then
        db.incN(name, -ntransferred) -- does not update worst(), need to call cleanAll for that
    end
    return ntransferred ~= 0
end


local function storeAt(slot, name, score)
    local out_slot = tr.getInventorySize(config.seed_store_side)
    local ntransferred = tr.transferItem(config.source_side, config.seed_store_side, 64, slot, out_slot)

    local n, worst, best = db.getEntry(name)
    print(name, n, worst, best)
    if n == nil then
        n = 0
        best = score
        worst = score
    elseif best == nil then
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

    local n, worst, best = db.getEntry(name)

    if n == nil or n < config.min_to_keep then
        best = -1
        store = true
    elseif best - score <= config.score_fuzziness then -- best - score being negative is ok
        store = true

    end
    
    if store then
        print(string.format("Storing %s  with score %d (best %d)", name, score, best))

        return storeAt(slot, name, score)
    else
        print(string.format("Deleting %s from storage with score %d (best %d)", name, score, best))
        return deleteFromSource(slot)
    end
end


local function dumpInv()
    print("Emptying inventory!")
    local success = true
    local transferred = false

    -- local slots = tr.getAllStacks(config.source_side).getAll()

    local nslots = tr.getInventorySize(config.source_side)
    local stack

    local i = 1
    while i <= nslots do
        stack = tr.getStackInSlot(config.source_side, i)
       
        if stack  == nil or stack.crop == nil then
            break
        end


        success = storeInInv(i, stack)

        if not success then
            print("unable to store item!")
            success = false
            break
        else
            transferred = true
        end
        i = i + 1
    end


    return success, transferred
end

local function cleanAll()
    print("Cleaning inventory!")
    local success = true
    local ns, bests = db.getNsBests()
    local worsts = {}
    local needs_cleaning = db.needsCleaning()

    --local slots = tr.getAllStacks(config.seed_store_side).getAll()

    local nslots = tr.getInventorySize(config.seed_store_side)
    local name, score, keep, worst, stack, low_number, n

    local i = 1
    while i <= nslots do
        stack = tr.getStackInSlot(config.seed_store_side, i)
       
        if stack  == nil or stack.crop == nil then
            break
        end


        if needs_cleaning[stack.crop.name] then
            name, score = sc.evalCrop(stack)

            n = ns[name]

            low_number = n == nil or n <= config.min_to_keep

            keep = low_number or bests[name] - score <= config.score_fuzziness

            if keep then
                -- logic to keep the worsts updated
                worst = worsts[name]
                if worst == nil or worst > score then
                    worsts[name] = score
                end

            else
                print(string.format("Deleting %s from storage with score %d (best %d)", name, score, bests[name]))
                success = deleteFromStorage(name, i)
                i = i - 1 -- the relative position of everything is shifted by one
            end

            if not success then
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

    -- local slots = tr.getAllStacks(config.seed_store_side).getAll()
    local nslots = tr.getInventorySize(config.seed_store_side)
    local name, score, keep, n, worst, best, stack, low_number

    local i = 1
    while i <= nslots do
        stack = tr.getStackInSlot(config.seed_store_side, i)
        
        if stack  == nil or stack.crop == nil then
            break
        end

        name, score = sc.evalCrop(stack)

        best = bests[name]
        n = ns[name]

        low_number = n == nil or n <= config.min_to_keep

        keep = low_number or bests[name] - score <= config.score_fuzziness

        if keep then
            -- update worsts and n
            worst = worsts[name]
            if worst == nil or worst > score then
                worsts[name] = score
            end

            if best == nil or score > best then
                bests[name] = score
            end

            
            if n == nil then
                ns[name] = stack.size
            else
                ns[name] = n + stack.size
            end

        else
            print(string.format("Deleting %s from storage with score %d (best %d)", name, score, bests[name]))
            success = deleteFromStorage(name, i, true)
            i = i - 1 -- the relative position of everything is shifted by one
        end

        if not success then
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
    initDB=initDB,
}