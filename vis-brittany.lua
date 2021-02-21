local function brittany(file)
  -- vis:message('file')
  -- vis:message(file.name)
  
  filerange = {
    start = 0,
    finish = file.size
  }

  local exitcode, formatted, stderr = vis:pipe(file, filerange, 'brittany')
  
  -- vis:message('exitcode')
  -- vis:message(exitcode)
  -- vis:message('stdout')
  -- vis:message(stdout)
  -- vis:message('stderr')
  -- vis:message(stderr)
  
  if exitcode == 0 then
    file:delete(filerange)
    file:insert(0, formatted)
  end
end

vis:command_register("HB", function(argv, force, win, selection, range)
  file = win.file
  brittany(file)
  return true
end)

-- vis:command_register("foo", function(argv, force, win, selection, range)
	 -- for i,arg in ipairs(argv) do
		 -- print(i..": "..arg)
	 -- end
	 -- print("was command forced with ! "..(force and "yes" or "no"))
	 -- print(win.file.name)
	 -- print(selection.pos)
	 -- print(range ~= nil and ('['..range.start..', '..range.finish..']') or "invalid range")
	 -- return true;
-- end)

