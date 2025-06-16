local process = require("@lune/process")
local FS = require("@lune/fs")

local function getCurrentUserPath()
	local env = process.env
	local osName = process.os

	if osName == "windows" then
		if env.USERPROFILE then
			return env.USERPROFILE
		end
		if env.HOMEDRIVE and env.HOMEPATH then
			return env.HOMEDRIVE .. env.HOMEPATH
		end
		if env.USERNAME then
			return "C:\\Users\\" .. env.USERNAME
		end
	elseif osName == "linux" or osName == "macos" then
		if env.HOME then
			return env.HOME
		end
		if env.USER then
			if osName == "linux" then
				return "/home/" .. env.USER
			elseif osName == "macos" then
				return "/Users/" .. env.USER
			end
		end
	end

	error("Unable to determine current user path on " .. tostring(osName))
end

local function joinPath(...)
	local parts = { ... }
	local sep = process.os == "windows" and "\\" or "/"
	return table.concat(parts, sep)
end

local function getTempBase()
	local osName = process.os
	local env = process.env

	if osName == "windows" then
		if env.TEMP then
			return env.TEMP
		elseif env.USERPROFILE then
			return joinPath(env.USERPROFILE, "AppData", "Local", "Temp")
		elseif env.USERNAME then
			return joinPath("C:\\Users", env.USERNAME, "AppData", "Local", "Temp")
		end
	else
		if env.TMPDIR then
			return env.TMPDIR
		else
			return joinPath(getCurrentUserPath(), "tmp")
		end
	end

	error("Could not determine temp directory.")
end

local module = {}
local TempPaths = {}

function module:GetPath()
	return getCurrentUserPath()
end

function module:WriteFile(File_Path: string, Content: string)
    assert(type(File_Path) == "string", "File_Path must be a string")
    assert(type(Content) == "string", "Content must be a string")

    local sep = process.os == "windows" and "\\" or "/"

    local lastSepIndex = File_Path:match(".*()"..sep)
    local dirPath = nil
    if lastSepIndex then
        dirPath = File_Path:sub(1, lastSepIndex - 1)
    else
        dirPath = "."
    end

    local function createDirsRecursively(path)
        if path == "" or path == "." then
            return true
        end
        if FS.isDir(path) then
            return true
        end

        local parentPath = path:match("^(.*)"..sep)
        if parentPath then
            createDirsRecursively(parentPath)
        end

        FS.writeDir(path)

        return
    end

    createDirsRecursively(dirPath)

    FS.writeFile(File_Path, Content)
end

function module:PushTemp(TempID: string): string
	assert(type(TempID) == "string", "TempID must be a string")

	if TempPaths[TempID] then
		return TempPaths[TempID]
	end

	local tempBase = getTempBase()
	local fullPath = joinPath(tempBase, TempID)

	TempPaths[TempID] = fullPath
    
    FS.writeDir(fullPath)

	return fullPath
end

function module:PopTemp(TempID: string): boolean
	assert(type(TempID) == "string", "TempID must be a string")

    if FS.isDir(TempPaths[TempID]) then
        FS.removeDir(TempPaths[TempID])
    end
    
	if TempPaths[TempID] then
		TempPaths[TempID] = nil
		return true
	end

	return false
end

local DocumentsPaths = {}

local function getDocumentsBase()
	local osName = process.os
	local env = process.env

	if osName == "windows" then
		if env.USERPROFILE then
			return joinPath(env.USERPROFILE, "Documents")
		elseif env.USERNAME then
			return joinPath("C:\\Users", env.USERNAME, "Documents")
		end
	elseif osName == "linux" then
		if env.XDG_DOCUMENTS_DIR then
			return env.XDG_DOCUMENTS_DIR
		else
			return joinPath(getCurrentUserPath(), "Documents")
		end
	elseif osName == "macos" then
		return joinPath(getCurrentUserPath(), "Documents")
	end

	error("Could not determine Documents directory.")
end

function module:PushDocuments(DocID)
	assert(type(DocID) == "string", "DocID must be a string")

	if DocumentsPaths[DocID] then
		return DocumentsPaths[DocID]
	end

	local documentsBase = getDocumentsBase()
	local fullPath = joinPath(documentsBase, DocID)

	DocumentsPaths[DocID] = fullPath

	if not FS.isDir(fullPath) then
		FS.writeDir(fullPath)
	end

	return fullPath
end

function module:PopDocuments(DocID)
	assert(type(DocID) == "string", "DocID must be a string")

	local path = DocumentsPaths[DocID]
	if path and FS.isDir(path) then
		FS.removeDir(path)
	end

	if DocumentsPaths[DocID] then
		DocumentsPaths[DocID] = nil
		return true
	end

	return false
end

return module
