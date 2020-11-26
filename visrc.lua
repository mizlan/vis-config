require('vis')

require('vis-commentary')
require('vis-surround')
require('vis-ibrace')
require('vis-status')

require('vis-lint-manager')

-- this disables auto ci" jumping, so comment it out for now
-- local p = require('vis-pairs')
-- p.autopairs = false

vis.events.subscribe(vis.events.INIT, function()
	-- Your global configuration options
	vis:command('set theme moon')
	vis:command('set escdelay 20')
	vis:command('set tabwidth 2')
	vis:command('set autoindent')
	vis:command('set expandtab')
end)

vis.events.subscribe(vis.events.WIN_OPEN, function(win)
	-- Your per window configuration options e.g.
	-- vis:command('set number')
	vis:command('set number')
	vis:command('set rnu')
	vis:command('set show-tabs on')
	vis:command('set show-eof off')
end)

