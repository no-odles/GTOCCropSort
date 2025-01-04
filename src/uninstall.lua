local shell = require('shell')

local scripts = {
    'config.lua',
    'database.lua',
    'inventory.lua',
    'inventory_lowmem.lua',
    'score.lua',
    'sort.lua',
    'sort_lm.lua',
    'uninstall.lua'
}

for i=1, #scripts do
    shell.execute(string.format('rm %s', scripts[i]))
end