-- custom status line configuration
-- feast

local modes = {
  [vis.modes.NORMAL] = 'N',
  [vis.modes.OPERATOR_PENDING] = 'O',
  [vis.modes.VISUAL] = 'V',
  [vis.modes.VISUAL_LINE] = 'V',
  [vis.modes.INSERT] = 'I',
  [vis.modes.REPLACE] = 'R',
}

local function main_stl(win)
  local left_parts = {}
  local right_parts = {}
  local file = win.file
  local selection = win.selection

  local mode = modes[vis.mode]
  if mode ~= '' and vis.win == win then
  table.insert(left_parts, mode)
  end

  table.insert(left_parts, (file.name or '-') ..
  (file.modified and ' *' or '') .. (vis.recording and ' @' or ''))

  local count = vis.count
  local keys = vis.input_queue
  if keys ~= '' then
  table.insert(right_parts, keys)
  elseif count then
  table.insert(right_parts, count)
  end

  if #win.selections > 1 then
  table.insert(right_parts, selection.number..'/'..#win.selections)
  end

  local size = file.size
  local pos = selection.pos
  if not pos then pos = 0 end

  if not win.large then
  local col = selection.col
  table.insert(right_parts, selection.line..':'..col)
  if size > 33554432 or col > 65536 then
  win.large = true
  end
  end

  if __VISLINTM_all_instances ~= nil and __VISLINTM_all_instances.size  > 0 then
  table.insert(right_parts, __VISLINTM_all_instances.size)
  end

  local left = ' ' .. table.concat(left_parts, "  ") .. ' '
  local right = ' ' .. table.concat(right_parts, "  ") .. ' '
  win:status(left, right);
end

local function min_stl(win)
  local stl = ' '
  if win.file.name ~= nil then
    stl = stl .. win.file.name
  end
  if win.file.modified then
    stl = stl .. ' (modified)'
  end
  if vis.recording then
    stl = stl .. ' (recording)'
  end
  win:status(stl)
end

vis.events.subscribe(vis.events.WIN_STATUS, min_stl)
