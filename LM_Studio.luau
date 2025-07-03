local module = {}

local Serde = require("@lune/serde")
local FS = require("@lune/fs")
local Net = require("@lune/net")

function module.BuildJsonSchema(name, properties, required)
    required = required or {}
    return {
        name = name,
        strict = true,
        schema = {
            type = "object",
            properties = properties,
            required = required,
        }
    }
end

local function QueryLM_Studio(self)
    local Endpoint = "http://" .. self.Host .. "/v1/chat/completions"
    local Payload = Serde.encode("json", {
        model = self.Model,
        messages = self.History,
        max_tokens = self.MaxTokens,
        temperature = self.Temperature,
        stream = false,
    })

    local rawResponse = Net.request({
        url = Endpoint,
        method = "POST",
        headers = { ["Content-Type"] = "application/json" },
        body = Payload,
    })

    local response = Serde.decode("json", rawResponse.body)
    local content = response.choices[1].message.content
    return content
end

local function QueryLM_StudioStructured(self, jsonSchema)
    local Endpoint = "http://" .. self.Host .. "/v1/chat/completions"
    local Payload = Serde.encode("json", {
        model = self.Model,
        messages = self.History,
        max_tokens = self.MaxTokens,
        temperature = self.Temperature,
        stream = false,
        response_format = {
            type = "json_schema",
            json_schema = jsonSchema,
        }
    })

    local rawResponse = Net.request({
        url = Endpoint,
        method = "POST",
        headers = { ["Content-Type"] = "application/json" },
        body = Payload,
    })

    local response = Serde.decode("json", rawResponse.body)
    local content = response.choices[1].message.content

    local success, parsed = pcall(function() return Serde.decode("json", content) end)
    if not success then
        error("Failed to parse structured output JSON: " .. tostring(parsed))
    end

    return parsed
end

function module.New(Model, Host, Temperature, MaxTokens)
    Host = Host or "127.0.0.1:1234"

    local self = setmetatable({}, {})
    self.Host = Host
    self.Model = Model
    self.Temperature = Temperature or 0.7
    self.MaxTokens = MaxTokens or 500
    self.History = {}

    function self:AddSystem(prompt)
        table.insert(self.History, { role = "system", content = prompt })
    end

    function self:Prompt(prompt)
        table.insert(self.History, { role = "user", content = prompt })
        local response = QueryLM_Studio(self)
        table.insert(self.History, { role = "assistant", content = response })
        return response
    end

    function self:PromptStructured(prompt, jsonSchema)
        table.insert(self.History, { role = "user", content = prompt })
        local responseTable = QueryLM_StudioStructured(self, jsonSchema)
        table.insert(self.History, { role = "assistant", content = Serde.encode("json", responseTable) })
        return responseTable
    end

    function self:SaveHistory(filename)
        local json = Serde.encode("json", self.History)
        local success, err = pcall(function()
            FS.writeFile(filename, json)
        end)
        if not success then
            error("Failed to save history to file: " .. tostring(err))
        end
    end

    function self:LoadHistory(filename)
        local success, contentOrErr = pcall(function()
            return FS.readFile(filename)
        end)
        if not success then
            error("Failed to read history file: " .. tostring(contentOrErr))
        end
        local successDecode, loadedHistory = pcall(function()
            return Serde.decode("json", contentOrErr)
        end)
        if not successDecode then
            error("Failed to parse history JSON: " .. tostring(loadedHistory))
        end
        self.History = loadedHistory
    end

    function self:ClearHistory()
        self.History = {}
    end

    self.__index = self
    return self
end

return module
