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
    local function trim(s)
        return s:match("^%s*(.-)%s*$")
    end

    local function parseString(s)
        s = s:sub(2, -2)
        s = s:gsub('\\"', '"'):gsub('\\\\', '\\')
        return s
    end

    local function parseValue(s)
        s = trim(s)
        if s == "true" then
            return true
        elseif s == "false" then
            return false
        elseif s == "nil" then
            return nil
        elseif tonumber(s) then
            return tonumber(s)
        elseif s:sub(1,1) == '"' and s:sub(-1) == '"' then
            return parseString(s)
        elseif s:sub(1,1) == "{" and s:sub(-1) == "}" then
            return parseTable(s)
        else
            error("Unknown value: " .. s)
        end
    end

    local function splitKeyValues(s)
        local parts = {}
        local braceLevel = 0
        local inString = false
        local current = ""
        local i = 1
        while i <= #s do
            local c = s:sub(i,i)
            if c == '"' and (i == 1 or s:sub(i-1,i-1) ~= '\\') then
                inString = not inString
                current = current .. c
            elseif not inString then
                if c == "{" then
                    braceLevel = braceLevel + 1
                    current = current .. c
                elseif c == "}" then
                    braceLevel = braceLevel - 1
                    current = current .. c
                elseif (c == "," or c == ";") and braceLevel == 0 then
                    table.insert(parts, current)
                    current = ""
                else
                    current = current .. c
                end
            else
                current = current .. c
            end
            i = i + 1
        end
        if current ~= "" then
            table.insert(parts, current)
        end
        return parts
    end

    function parseTable(s)
        assert(s:sub(1,1) == "{" and s:sub(-1) == "}", "Table must start with { and end with }")
        local inner = s:sub(2, -2)
        local result = {}

        local keyValues = splitKeyValues(inner)
        for _, part in ipairs(keyValues) do
            part = trim(part)
            if part ~= "" then
                local key, value = part:match("^%[([^%]]+)%]%s*=%s*(.+)$")
                if key then
                    key = trim(key)
                    if key:sub(1,1) == '"' and key:sub(-1) == '"' then
                        key = parseString(key)
                    elseif tonumber(key) then
                        key = tonumber(key)
                    else
                        key = key
                    end
                    result[key] = parseValue(value)
                else
                    local val = parseValue(part)
                    table.insert(result, val)
                end
            end
        end
        return result
    end

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
