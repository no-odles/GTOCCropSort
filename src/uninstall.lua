local shell = require('shell')

local scripts = {
    'config.lua',
    'database.lua',
    'inventory.lua',
    'score.lua',
    'sort.lua',
    'uninstall.lua'
}

for i=1, #scripts do
    shell.execute(string.format('rm %s', scripts[i]))
end