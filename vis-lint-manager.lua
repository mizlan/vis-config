__VIS_LINT = require('vis-linting')

__VISLINTM_all_instances = {}
__VISLINTM_ai_SIZE = 0
__VISLINTM_cur_instance = 0

local function jump_to_next(win)
  if __VISLINTM_ai_SIZE == 0 then return end

  __VISLINTM_cur_instance = __VISLINTM_cur_instance + 1
  
  if __VISLINTM_cur_instance > __VISLINTM_ai_SIZE then
    __VISLINTM_cur_instance = 1
  end

  local CUR = __VISLINTM_all_instances[__VISLINTM_cur_instance]

  -- move cursor to the position, and visual select it
  -- require('pl.pretty').dump(__VISLINTM_all_instances)
  
  win.selection:to(CUR['range']['min']['line'], CUR['range']['min']['col'])
  vis:feedkeys('<Escape>v')
  win.selection:to(CUR['range']['max']['line'], CUR['range']['max']['col'])
  vis:info((CUR['kind'] == 'error' and 'E' or 'W')..' '..CUR['msg'])
  
end

local function update(win)
  vis:info(win.syntax)
  if __VIS_LINT[win.syntax] == nil then return end
  
  local res = __VIS_LINT[win.syntax](win)
  if res ~= nil then
    __VISLINTM_all_instances = res
    
    -- get the fucking length of the table, which has no builtin way of doing so
    local __SZ = 0
    for _ in pairs(res) do __SZ = __SZ + 1 end
    __VISLINTM_ai_SIZE = __SZ
    
    if __VISLINTM_ai_SIZE > 0 then
      __VISLINTM_cur_instance = 1
    else
      __VISLINTM_cur_instance = -1
    end
  else
    vis:info('nothing')
  end
end

local function vl_upd(argv, force, win, selection, range)
  update(win)
  jump_to_next(win)
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
