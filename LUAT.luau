local FS = require("@lune/fs")

local function getLastFiveChars(str)
	return string.sub(str, -5)
end

local function serializeTable(tbl)
	local function serialize(value)
		if type(value) == "string" then
			return string.format("%q", value)
		elseif type(value) == "number" or type(value) == "boolean" then
			return tostring(value)
		elseif type(value) == "table" then
			return serializeTable(value)
		else
			return "nil"
		end
	end

	local result = "{"
	for k, v in pairs(tbl) do
		local keyStr
		if type(k) == "string" then
			keyStr = "[" .. string.format("%q", k) .. "]"
		elseif type(k) == "number" then
			keyStr = "[" .. k .. "]"
		else
			keyStr = "[nil]" 
		end

		local valStr = serialize(v)
		result = result .. keyStr .. "=" .. valStr .. ","
	end
	result = result .. "}"
	return result
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
		for key, val in tblStr:gmatch("%[(.-)%]%s*=%s*([^,%}]+)") do
			local parsedKey = parseValue(key)
			local parsedVal
			if string.sub(val, 1, 1) == "{" then
				local depth = 0
				local sub = ""
				local i = 1
				while i <= #val do
					local char = val:sub(i, i)
					if char == "{" then depth = depth + 1 end
					if char == "}" then depth = depth - 1 end
					sub = sub .. char
					if depth == 0 then break end
					i = i + 1
				end
				parsedVal = parseTable(sub)
			else
				parsedVal = parseValue(val)
			end

			if parsedKey ~= nil then
				out[parsedKey] = parsedVal
			end
		end
		return out
	end

	str = str:match("^%s*(%b{})%s*$")
	if not str then return {} end
	return parseTable(str)
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


function module.WriteFile(Path, Value)
    local TestPath = string.lower(Path)
    if getLastFiveChars(TestPath) == ".luat" then
        ensureDirectoriesExist(Path)
        local StrData = serializeTable(Value)
        FS.writeFile(Path, StrData)
    end
end

function module.Encode(Value)
    local StrData = serializeTable(Value)
    return StrData
end

function module.Decode(StrData)
    local TableData = deserializeTable(StrData)
    return TableData
end



return module
