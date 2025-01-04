
local os = require("os")

local config = require("config")
local db = require("database")
local inv = require("inventory")

local ctr = 0

if ~inv.initDB() then
    return
end

while true do
    local success, transferred = inv.dumpInv()

    if ~success then
        break
    end

    if transferred == false then
        inv.cleanAll()
        ctr = 0

    elseif ctr > config.max_dirty_cycles then
        inv.cleanAll()
        ctr = 0
    else
        ctr = ctr + 1
    end


    os.sleep(5)
end
