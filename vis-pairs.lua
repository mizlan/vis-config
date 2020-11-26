-- Author: Georgi Kirilov
--
-- You can contact me via email to the posteo.net domain.
-- The local-part is the Z code for "Place a competent operator on this circuit."

require("vis")
local vis = vis

local l = require("lpeg")

-- XXX: in Lua 5.2 unpack() was moved into table
local unpack = table.unpack or unpack

local M

local builtin_textobjects = {
	["["] = { "[" , "]" },
	["{"] = { "{" , "}" },
	["<"] = { "<" , ">" },
	["("] = { "(" , ")" },
	['"'] = { '"' , '"', name = "A quoted string" },
	["'"] = { "'" , "'", name = "A single quoted string" },
	["`"] = { "`" , "`", name = "A backtick delimited string" },
}

local builtin_motions = {
	["["] = { ["("] = true, ["{"] = true },
	["]"] = { [")"] = true, ["}"] = true },
}

local aliases = {}
for key, pair in pairs(builtin_textobjects) do aliases[pair[2]] = key ~= pair[2] and pair or nil end
for alias, pair in pairs(aliases) do builtin_textobjects[alias] = pair end
for alias, key in pairs({
		B = "{",
		b = "(",
		}) do
	builtin_textobjects[alias] = builtin_textobjects[key]
end

local function get_pair(key, win)
	return M.map[win.syntax] and M.map[win.syntax][key]
		or M.map[1] and M.map[1][key]
		or builtin_textobjects[key]
		or not key:match("%w") and {key, key}
end

local function at_pos(t, pos)
	if pos.start + 1 >= t[1] and pos.finish < t[#t] then return t end
end

local function asymmetric(d, escaped, pos)
	local p
	local I = l.Cp()
	local skip = escaped and escaped + l.P(1) or l.P(1)
	if #d == 1 then
		p = (d - l.B"\\") * I * ("\\" * l.P(1) + (skip - d))^0 * I * d
	else
		p = d * I * (skip - d)^0 * I * d
	end
	return l.Ct(I * p * I) * l.Cc(pos) / at_pos
end

local function symmetric(d1, d2, escaped, pos)
	local I = l.Cp()
	local skip = escaped and escaped + l.P(1) or l.P(1)
	return l.P{l.Ct(I * d1 * I * ((skip - d1 - d2) + l.V(1))^0 * I * d2 * I) * l.Cc(pos) / at_pos}
end

local function nth_innermost(t, count)
	local start, finish, c = 0, 0, count
	if #t == 5 then
		start, finish, c = nth_innermost(t[3], count)
	end
	if c then
		return {t[1], t[2]}, {t[#t - 1], t[#t]}, c > 1 and c - 1 or nil
	end
	return start, finish
end

local precedence = {
	[vis.lexers.COMMENT] = {vis.lexers.STRING},
	[vis.lexers.STRING] = {},
}

local function selection_range(win, pos)
	for selection in win:selections_iterator() do
		if selection.pos == pos then
			return selection.range
		end
	end
end

local prev_match

local function any_captures(_, position, t)
	if type(t) == "table" then
		return position, t
	end
	if t then
		prev_match = position - t
	end
end

local function not_past(_, position, pos)
	local newpos =  prev_match > position and prev_match or position
	return newpos <= pos and newpos or false
end

local function match_at(str, pattern, pos)
	prev_match = 0
	local I = l.Cp()
	local p = l.P{l.Cmt(l.Ct(I * (pattern/0) * I) * l.Cc(pos) / at_pos * l.Cc(0), any_captures) + 1 * l.Cmt(l.Cc(pos.start + 1), not_past) * l.V(1)}
	local t = p:match(str)
	if t then return t[1] - 1, t[#t] - 1 end
end

local function escaping_context(win, range, data)
	if not win.syntax then return {} end
	local rules = vis.lexers.lexers[win.syntax]._RULES
	local p
	for _, name in ipairs({vis.lexers.COMMENT, vis.lexers.STRING}) do
		if rules[name] then
			p = p and p + rules[name] / 0 or rules[name] / 0
		end
	end
	if not p then return {} end
	if not range then return {escape = p} end    -- means we are retrying with a "fake" pos
	local e1, e2 = match_at(data, p, range)
	if not (e1 and e2) then return {escape = p} end
	p = nil
	local escaped_range = {e1 + 1, e2}
	local escaped_data = data:sub(e1 + 1, e2)
	for _, level in ipairs({vis.lexers.COMMENT, vis.lexers.STRING}) do
		if l.match(rules[level] / 0 * -1, escaped_data) then
			for _, name in ipairs(precedence[level]) do
				if rules[name] then
					p = p and p + rules[name] / 0 or rules[name] / 0
				end
			end
			return {escape = p, range = escaped_range}
		end
	end
end

local function get_range(key, win, pos, file_data, count)
	local d = get_pair(key, win)
	if not d then return end
	repeat
		local sel_range = selection_range(win, pos)
		local c = escaping_context(win, sel_range, file_data)
		local range = c.range or {1, #file_data}
		local correction = range[1] - 1
		pos = pos - correction
		if sel_range then
			sel_range.start = sel_range.start - correction
			sel_range.finish = sel_range.finish - correction
		else
			sel_range = {start = pos + 1, finish = pos + 2}
		end
		local p = d[1] ~= d[2] and symmetric(d[1], d[2], c.escape, sel_range) or asymmetric(d[1], c.escape, sel_range)
		local can_abut = d[1] == d[2] and #d[1] == 1 and not (builtin_textobjects[key] or M.map[1][key] or M.map[win.syntax] and M.map[win.syntax][key])
		local skip = c.escape and c.escape + 1 or 1
		local data = c.range and file_data:sub(unpack(c.range)) or file_data
		local pattern = l.P{l.Cmt(p * l.Cc(can_abut and 1 or 0), any_captures) + skip * l.Cmt(l.Cc(pos + 1), not_past) * l.V(1)}
		prev_match = 0
		local hierarchy = pattern:match(data)
		if hierarchy then
			local offsets = {nth_innermost(hierarchy, count or 1)}
			offsets[3] = nil  -- a leftover from calling nth_innermost() with count higher than the hierarchy depth.
			for _, o in ipairs(offsets) do
				for i, v in ipairs(o) do
					o[i] = v - 1 + correction
				end
			end
			return unpack(offsets)
		else
			pos = correction - 1
		end
	until hierarchy or pos < 0
end

local function keep_last(acc, cur)
	if #acc == 0 then
		acc[1] = cur
	else
		acc[2] = cur
	end
	return acc
end

local function barf_linewise(win, content, start, finish)
	if vis.mode == vis.modes.VISUAL_LINE then
		local skip
		if win.syntax then
			local rules = vis.lexers.lexers[win.syntax]._RULES
			for _, name in ipairs({vis.lexers.COMMENT, vis.lexers.STRING}) do
				if rules[name] then
					skip = skip and skip + rules[name] / 0 or rules[name] / 0
				end
			end
		end
		skip = skip and skip + 1 or 1
		start, finish = unpack(l.match(l.Cf(l.Cc({}) * (l.Cp() * l.P"\n" + skip * l.Cmt(l.Cc(finish), not_past))^0, keep_last), content, start + 1))
	end
	return start, finish
end

local function get_delimiters(key, win, pos, count)
	local d = get_pair(key, win)
	if not d or type(d[1]) == "string" and type(d[2]) == "string" then return d end
	local content = win.file:content(0, win.file.size)
	local start, finish = get_range(key, win, pos, content, count or vis.count)
	if start and finish then
		return {win.file:content(start[1], start[2] - start[1]), win.file:content(finish[1], finish[2] - finish[1]), d[3], d.prompt}
	elseif #d > 2 then
		return {nil, nil, d[3], d.prompt}
	end
end

local function outer(win, pos, content, count)
	local start, finish = get_range(M.key, win, pos, content, count)
	if start and finish then return start[1], finish[2] end
end

local function inner(win, pos, content, count)
	local start, finish = get_range(M.key, win, pos, content, count)
	if start and finish then return barf_linewise(win, content, start[2], finish[1]) end
end

local function opening(win, pos, content, count)
	local start, _ = get_range(M.key, win, pos, content, count)
	if not start then return pos end
	local exclusive = vis.mode == vis.modes.OPERATOR_PENDING and pos >= start[2] or vis.mode == vis.modes.VISUAL and pos < start[2] - 1
	return start[2] - 1 + (exclusive and 1 or 0), vis.mode == vis.modes.OPERATOR_PENDING and pos >= start[2]
end

local function closing(win, pos, content, count)
	local _, finish = get_range(M.key, win, pos, content, count)
	if not finish then return pos end
	local exclusive = vis.mode == vis.modes.VISUAL and pos > finish[1]
	return finish[1] - (exclusive and 1 or 0)
end

local done_once

local function bail_early()
	if vis.count and vis.count > 1 then
		if done_once then
			done_once = nil
			return true
		else
			done_once = true
		end
	end
	return false
end

local function win_map(textobject, prefix, binding, help)
	return function(win)
		if not textobject then
			win:map(vis.modes.NORMAL, prefix, binding, help)
		end
		win:map(vis.modes.VISUAL, prefix, binding, help)
		win:map(vis.modes.OPERATOR_PENDING, prefix, binding, help)
	end
end

local function bind_builtin(key, execute, id)
	return function()
		M.key = key
		execute(vis, id)
	end
end

local function prep(func)
	return function(win, pos)
		if bail_early() then return pos end
		local content = win.file:content(0, win.file.size)
		local start, finish = func(win, pos, content, vis.count)
		if not vis.count and vis.mode == vis.modes.VISUAL or start and not finish then
			local old = selection_range(win, pos)
			local same_or_smaller = finish and start >= old.start and finish <= old.finish
			local didnt_move = not finish and start == pos
			if same_or_smaller or didnt_move then
				start, finish = func(win, pos, content, 2)
			end
		end
		return start, finish
	end
end

local mappings = {}

local function new(execute, register, prefix, handler, help)
	local id = register(vis, prep(handler))
	if id < 0 then
		return false
	end
	if prefix then
		local binding = function(keys)
			if #keys < 1 then return -1 end
			if #keys == 1 then
				M.key = keys
				execute(vis, id)
			end
			return #keys
		end
		table.insert(mappings, win_map(execute == vis.textobject, prefix, binding, help))
		local builtin = execute == vis.motion and builtin_motions[prefix] or builtin_textobjects
		for key, _ in pairs(builtin) do
			local d = builtin_textobjects[key]
			local simple = type(d[1]) == "string" and type(d[2]) == "string" and d[1]..d[2]
			local hlp = (execute == vis.motion and help or "") .. (d.name or (simple or "pattern-delimited") .." block")
			if execute ~= vis.textobject then
				vis:map(vis.modes.NORMAL, prefix..key, bind_builtin(key, execute, id), hlp)
			end
			local variant = prefix == M.prefix.outer and " (outer variant)" or prefix == M.prefix.inner and " (inner variant)" or ""
			vis:map(vis.modes.VISUAL, prefix..key, bind_builtin(key, execute, id), hlp and hlp .. variant or help)
			vis:map(vis.modes.OPERATOR_PENDING, prefix..key, bind_builtin(key, execute, id), hlp and hlp .. variant or help)
		end
	end
	return id
end

vis.events.subscribe(vis.events.WIN_OPEN, function(win)
	for _, map_keys in ipairs(mappings) do
		map_keys(win)
	end
	local function delete_pair(direction, do_delete)
		return function()
			local locations = {}
			for selection in win:selections_iterator() do
				local pos = selection.pos
				if pos - direction < 0 then return end
				local key = win.file:content(pos - direction, 1)
				local p = M.map[win.syntax] and M.map[win.syntax][key]
					or M.map[1] and M.map[1][key]
					or builtin_textobjects[key]
				local left, len = pos - direction, #key
				if p and (key == p[1] or key == p[2]) then
					M.key = p[1]
					local start, finish = inner(win, pos, win.file:content(0, win.file.size))
					if start and start == finish and pos == start then
						left = start - #p[1]
						len = #p[1] + #p[2]
					end
				end
				locations[selection.number] = len - 1
				if do_delete then
					win.file:delete(left, len)
					selection.pos = left
				end
			end
			return locations
		end
	end
	M.unpair[win] = delete_pair(1)
	if M.autopairs and (not vis_parkour or vis_parkour(win)) then
		win:map(vis.modes.INSERT, "<Backspace>", delete_pair(1, true))
		win:map(vis.modes.INSERT, "<Delete>", delete_pair(0, true))
	end
end)

vis.events.subscribe(vis.events.WIN_CLOSE, function(win)
	M.unpair[win] = nil
end)

vis.events.subscribe(vis.events.INIT, function()
	local function cmp(_, _, c1, c2) return c1 == c2 end
	local function casecmp(_, _, c1, c2) return c1:lower() == c2:lower() end
	local function end_tag(s1, s2, cmpfunc) return l.Cmt(s1 * l.Cb("t") * l.C((1 - l.P(s2))^1) * s2, cmpfunc) end
	local tex_environment = {"\\begin{" * l.Cg(l.R("az", "AZ")^1, "t") * "}", end_tag("\\end{", "}", cmp), {"\\begin{\xef\xbf\xbd}", "\\end{\xef\xbf\xbd}"}, "environment name"}
	local tag_name = (l.S"_:" + l.R("az", "AZ")) * (l.R("az", "AZ", "09") + l.S"_:.-")^0
	local noslash = {--[[implicit:]] p=1, dt=1, dd=1, li=1, --[[void:]] area=1, base=1, br=1, col=1, embed=1, hr=1, img=1, input=1, link=1, meta=1, param=1, source=1, track=1, wbr=1}
	local function is_not(_, _, v) return v ~= 1 end
	local html_tag = {"<" * l.Cg(l.Cmt(tag_name / string.lower / noslash, is_not), "t") * (1 - l.S"><")^0 * (">" - l.B"/"), end_tag("</", ">", casecmp), {"<\xef\xbf\xbd>", "</\xef\xbf\xbd>"}, prompt = "tag name"}
	local xml_tag = {"<" * l.Cg(tag_name, "t") * (1 - l.S"><")^0 * (">" - l.B"/"), end_tag("</", ">", cmp), {"<\xef\xbf\xbd>", "</\xef\xbf\xbd>"}, prompt = "tag name", name = "<tag></tag> block"}
	local function any_pair(set, default) return {l.Cg(l.S(set), "s"), l.Cmt(l.Cb("s") * l.C(1), function(_, _, c1, c2) return builtin_textobjects[c1][2] == c2 end), builtin_textobjects[default]} end
	local any_bracket = any_pair("({[", "(")
	local presets = {
		{t = xml_tag},
		xml = {t = xml_tag},
		html = {t = html_tag},
		markdown = {t = html_tag, ["_"] = {"_", "_"}, ["*"] = {"*", "*"}},
		asp = {t = html_tag},
		jsp = {t = html_tag},
		php = {t = html_tag},
		rhtml = {t = html_tag},
		scheme = {b = any_bracket},
		clojure = {b = any_bracket},
		latex = {t = tex_environment},
	}
	for syntax, bindings in pairs(presets) do
		if not M.map[syntax] then
			M.map[syntax] = bindings
		else
			for key, pattern in pairs(bindings) do
				if not M.map[syntax][key] then M.map[syntax][key] = pattern end
			end
		end
	end
	for key, d in pairs(M.map[1]) do
		builtin_textobjects[key] = {d[1], d[2], name = d.name}
		builtin_motions[M.prefix.opening][key] = true
		builtin_motions[M.prefix.closing][key] = true
	end

	M.motion = {
		opening = new(vis.motion, vis.motion_register, M.prefix.opening, opening, "Move cursor to the beginning of a "),
		closing = new(vis.motion, vis.motion_register, M.prefix.closing, closing, "Move cursor to the end of a "),
	}
	M.textobject = {
		inner = new(vis.textobject, vis.textobject_register, M.prefix.inner, inner, "Delimited block (inner variant)"),
		outer = new(vis.textobject, vis.textobject_register, M.prefix.outer, outer, "Delimited block (outer variant)"),
	}

	if M.autopairs then
		vis.events.subscribe(vis.events.INPUT, function(key)
			local win = vis.win
			if vis_parkour and vis_parkour(win) then return end
			local p = M.map[win.syntax] and M.map[win.syntax][key]
				or M.map[1] and M.map[1][key]
				or builtin_textobjects[key]
			if not p then return end
			if M.no_autopairs[key] and M.no_autopairs[key][win.syntax or ""] then return end
			for selection in win:selections_iterator() do
				local pos = selection.pos
				M.key = key
				local _, finish = outer(win, pos, win.file:content(0, win.file.size))
				if key == p[1] and p[1] ~= p[2] or p[1] == p[2] and pos + 1 ~= finish then
					win.file:insert(pos, p[2])
					selection.pos = pos
				elseif key == p[2] and pos + 1 == finish then
					win.file:delete(pos, #p[2])
					selection.pos = pos
				end
			end
		end)
	end

end)

M = {
	map = {},
	get_pair = get_delimiters,
	get_range_inner = inner,
	get_range_outer = outer,
	prefix = {outer = "a", inner = "i", opening = "[", closing = "]"},
	autopairs = true,
	no_autopairs = {["'"] = {markdown = true, [""] = true}},
	unpair = {}
}

vis_pairs = M

return M
