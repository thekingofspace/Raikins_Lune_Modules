local FS = require("@lune/fs")

local function getLastFiveChars(str)
	return string.sub(str, -5)
end

local function serializeTable(tbl, pretty, indentLevel)
	indentLevel = indentLevel or 0
	local indent = pretty and string.rep("  ", indentLevel) or ""
	local newline = pretty and "\n" or ""
	local space = pretty and " " or ""

	local function serialize(value, level)
		if type(value) == "string" then
			return string.format("%q", value)
		elseif type(value) == "number" or type(value) == "boolean" then
			return tostring(value)
		elseif type(value) == "table" then
			return serializeTable(value, pretty, level)
		else
			return "nil"
		end
	end

	local parts = {}
	for k, v in pairs(tbl) do
		local keyStr
		if type(k) == "string" then
			keyStr = "[" .. string.format("%q", k) .. "]"
		elseif type(k) == "number" then
			keyStr = "[" .. k .. "]"
		else
			keyStr = "[nil]"
		end

		local valStr = serialize(v, indentLevel + 1)
		if pretty then
			table.insert(parts, string.rep("  ", indentLevel + 1) .. keyStr .. "=" .. space .. valStr)
		else
			table.insert(parts, keyStr .. "=" .. valStr)
		end
	end

	local joined = table.concat(parts, "," .. newline)
	return "{" .. newline .. joined .. newline .. indent .. "}"
end

local function deserializeTable(str)
	local function parseValue(v)
		if v == "true" then
			return true
		elseif v == "false" then
			return false
		elseif v == "nil" then
			return nil
		elseif tonumber(v) then
			return tonumber(v)
		elseif string.sub(v, 1, 1) == '"' or string.sub(v, 1, 1) == "'" then
			return v:sub(2, -2):gsub('\\"', '"'):gsub("\\'", "'")
		else
			return nil
		end
	end

	local function parseTable(tblStr)
		local out = {}
		local i = 1
		while i <= #tblStr do
			local keyStart, keyEnd = tblStr:find("%[.-%]", i)
			if not keyStart then break end

			local keyStr = tblStr:sub(keyStart + 1, keyEnd - 1)
			i = keyEnd + 1

			local eqStart, eqEnd = tblStr:find("=", i)
			if not eqStart then break end
			i = eqEnd + 1

			local valStr
			if tblStr:sub(i, i) == "{" then
				local depth, j = 1, i + 1
				while j <= #tblStr do
					if tblStr:sub(j, j) == "{" then depth = depth + 1 end
					if tblStr:sub(j, j) == "}" then depth = depth - 1 end
					if depth == 0 then break end
					j = j + 1
				end
				valStr = tblStr:sub(i, j)
				i = j + 1
			else
				local valStart, valEnd = tblStr:find("[^,%}]+", i)
				if not valStart then break end
				valStr = tblStr:sub(valStart, valEnd)
				i = valEnd + 1
			end

			local key = parseValue(keyStr)
			local value
			if valStr:sub(1, 1) == "{" then
				value = parseTable(valStr:sub(2, -2))
			else
				value = parseValue(valStr:match("^%s*(.-)%s*$"))
			end

			if key ~= nil then
				out[key] = value
			end

			if tblStr:sub(i, i) == "," then
				i = i + 1
			end
		end
		return out
	end

	str = str:match("^%s*(%b{})%s*$")
	if not str then return {} end
	return parseTable(str:sub(2, -2))
end


local module = {}

local function ensureDirectoriesExist(filePath)
    local dirPath = filePath:match("(.+)/[^/]+$") 
    if not dirPath then
        return 
    end

    local parts = {}
    for part in dirPath:gmatch("[^/]+") do
        table.insert(parts, part)
    end

    local currentPath = ""
    for i, part in ipairs(parts) do
        currentPath = currentPath .. part
        if not FS.isDir(currentPath) then
            FS.writeDir(currentPath)
        end
        currentPath = currentPath .. "/"
    end
end

function module.ReadFile(Path)
	local TestPath = string.lower(Path)
	if getLastFiveChars(TestPath) == ".luat" then
		if FS.isFile(Path) then
			local Data = FS.readFile(Path)
			local TableData = deserializeTable(Data)
			return TableData
		else
			error("File not found.")
		end
	end

	return nil
end

function module.WriteFile(Path, Value, pretty:boolean)
    local TestPath = string.lower(Path)
    if getLastFiveChars(TestPath) == ".luat" then
        ensureDirectoriesExist(Path)
        local StrData = serializeTable(Value, pretty)
        FS.writeFile(Path, StrData)
    end
end

function module.Encode(Value, pretty)
    local StrData = serializeTable(Value, pretty)
    return StrData
end

function module.Decode(StrData)
    local TableData = deserializeTable(StrData)
    return TableData
end

return module
