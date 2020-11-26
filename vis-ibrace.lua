--
-- vis-ibrace
-- 

local function checkbrace()
  local win = vis.win
  local lines = win.file.lines
  local lnum = win.selection.line
  local curline = lines[lnum]
  local col = win.selection.col
  local indent = curline:match("^%s*")
  if (col ~= curline:len() and col ~= curline:len() + 1) or curline:sub(curline:len(), curline:len()) ~= '{' then
    vis:feedkeys("<vis-insert-newline>")
  else
    vis:feedkeys("<vis-insert-newline>")
    vis:feedkeys("<vis-insert-newline>}")
    vis:feedkeys("<vis-motion-line-up>")
    vis:feedkeys(indent)
    vis:feedkeys("<vis-motion-line-end>")
    -- don't insert the tab, make the manual tab insert universal
    -- vis:feedkeys("<vis-insert-tab>")
  end
end

local function overrideo(n)
  local win = vis.win
  local lines = win.file.lines
  local lnum = win.selection.line
  local curline = lines[lnum]
  local col = win.selection.col
  local indent = curline:match("^%s*")
end

-- vis:map(vis.modes.NORMAL, "o", overrideo(0))
-- vis:map(vis.modes.NORMAL, "O", overrideo(1))
vis:map(vis.modes.INSERT, "<Enter>", checkbrace, "check if fill brace")
