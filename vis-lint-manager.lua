__VIS_LINT = require('vis-linting')
require('lua-vec')

__VISLINTM_all_instances = Vec:new()
__VISLINTM_cur_instance = 0

local function jump_to_next(win)
  if __VISLINTM_all_instances.size == 0 then return end

  __VISLINTM_cur_instance = __VISLINTM_cur_instance + 1
  
  if __VISLINTM_cur_instance > __VISLINTM_all_instances.size then
    __VISLINTM_cur_instance = 1
  end

  local CUR = __VISLINTM_all_instances:at(__VISLINTM_cur_instance)

  -- move cursor to the position, and visual select it
  -- require('pl.pretty').dump(__VISLINTM_all_instances)
  
  win.selection:to(CUR['range']['min']['line'], CUR['range']['min']['col'])
  vis:feedkeys('<Escape>v')
  win.selection:to(CUR['range']['max']['line'], CUR['range']['max']['col'])
  vis:info('#'..__VISLINTM_cur_instance..' '..(CUR['kind'] == 'error' and 'E' or 'W')..' '..CUR['msg'])
  
end

local function update(win)
  if __VIS_LINT[win.syntax] == nil then return end
  
  local res = __VIS_LINT[win.syntax](win)
  if res ~= nil then
    __VISLINTM_all_instances = res
    
    if __VISLINTM_all_instances.size > 0 then
      __VISLINTM_cur_instance = 0
    else
      __VISLINTM_cur_instance = -1
    end
  else
    vis:info('nothing')
  end
end

local function vl_upd(argv, force, win, selection, range)
  update(win)
end

local function vl_next(argv, force, win, selection, range)
  jump_to_next(win)
end

vis:command_register('upd', vl_upd)
vis:command_register('j', vl_next)

vis.events.subscribe(vis.events.FILE_SAVE_POST, function(file, path)
  -- update
  update(vis.win)
end)

vis:map(vis.modes.NORMAL, " j", function()
  jump_to_next(vis.win)
end)

vis:map(vis.modes.VISUAL, " j", function()
  jump_to_next(vis.win)
end)
