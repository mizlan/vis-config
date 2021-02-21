require("vis")
require("vis-commentary")
require("vis-surround")
require("vis-ibrace")
require("vis-status")
require("vis-brittany")

-- require('vis-pairs')
-- require('vis-lint-manager')

vis.events.subscribe(
    vis.events.INIT,
    function()
        vis:command("set theme moon")
        -- vis:command('set theme zenburn')
        vis:command("set escdelay 20")
        vis:command("set tabwidth 2")
        vis:command("set autoindent")
        vis:command("set expandtab")
    end
)

vis.events.subscribe(
    vis.events.WIN_OPEN,
    function(win)
        -- vis:command('set number')
        -- vis:command('set rnu')
        vis:command("set show-eof off")
        -- vis:command('set cursorline')
    end
)
