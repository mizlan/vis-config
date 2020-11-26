vis:command_register("b", function(argv, force, win, selection, range)
	local cmd = string.format("g++-10 -std=c++11 %s 2>&1", win.file.name)
	local fhandle = assert(io.popen(cmd))
	local output = assert(fhandle:read("*all"))
	local rc = {fhandle:close()}
	vis:info(rc[3])

	if rc[3] ~= 0 then
		vis:command("vnew")
		vis:info(output:len())
		vis:insert(output)
	end
	
	return true;
end)

vis:command_register("B", function(argv, force, win, selection, range)
	local cmd = string.format("[ -f a.out ] && { [ -f input ] && ./a.out < input || ./a.out; }")
	local fhandle = assert(io.popen(cmd))
	local output = assert(fhandle:read("*all"))
	local rc = {fhandle:close()}
	vis:info(rc[3])

	if (output:len() > 0) or (rc ~= 0) then
		vis:command("vnew")
		vis:info(output:len())
		vis:insert(output)
	end

	return true;
end)
