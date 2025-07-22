local module = {}

local Serde = require("@lune/serde")
local FS = require("@lune/fs")
local Net = require("@lune/net")

local function QueryLM_Studio(self)
    local Endpoint = "http://" .. self.Host .. "/v1/chat/completions"
    local Payload = Serde.encode("json", {
        model = self.Model,
        messages = self.History,
        max_tokens = self.MaxTokens,
        temperature = self.Temperature,
        response_format = self.Format,
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

function module.New(Model, Host, Temperature, MaxTokens)
    Host = Host or "127.0.0.1:1234"

    local self = setmetatable({}, {})
    self.Host = Host
    self.Model = Model
    self.Temperature = Temperature or 0.7
    self.MaxTokens = MaxTokens or 500
    self.History = {}

    self.Format = nil

    function self:AddSystem(prompt)
        table.insert(self.History, { role = "system", content = prompt })
    end

    function self:AddMessage(prompt)
        table.insert(self.History, { role = "user", content = prompt })
    end

    function self:Prompt(prompt)
        table.insert(self.History, { role = "user", content = prompt })
        local response = QueryLM_Studio(self)
        table.insert(self.History, { role = "assistant", content = response })

        if self.Format ~= nil then
            response = Serde.decode("json", response)
        end
        return response
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

    function self:Serialize()
        local state = {
            Host = self.Host,
            Model = self.Model,
            Temperature = self.Temperature,
            MaxTokens = self.MaxTokens,
            History = self.History,
            Format = self.Format,
        }
        return Serde.encode("json", state)
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

function module.Deserialize(jsonStr)
    local state = Serde.decode("json", jsonStr)
    local ai = module.New(state.Model, state.Host, state.Temperature, state.MaxTokens)
    ai.History = state.History or {}
    ai.Format = state.Format
    return ai
end
 
local Property = {}
Property.__index = Property

function Property.new(propType, enumValues, description)
	local self = setmetatable({}, Property)
	self.type = propType
	self.enum = enumValues
    self.description = description
	return self
end

function Property:Build()
	local result = {
		type = self.type,
        enum = self.enum,
        description = self.description
	}
	return result
end

-- Schema
local Schema = {}
Schema.__index = Schema

function Schema.new()
	local self = setmetatable({}, Schema)
	self.properties = {}
	self.required = {}
	return self
end

function Schema:AddProperty(name, property, isRequired)
	self.properties[name] = property
	if isRequired then
		table.insert(self.required, name)
	end
end

function Schema:Build()
	local builtProps = {}
	for name, prop in pairs(self.properties) do
		builtProps[name] = prop:Build()
	end

	return {
		type = "object",
		properties = builtProps,
		required = self.required
	}
end

local JsonSchemaBuilder = {}
JsonSchemaBuilder.__index = JsonSchemaBuilder

function JsonSchemaBuilder.new(name, strict)
	local self = setmetatable({}, JsonSchemaBuilder)
	self.name = name
	self.strict = strict or false
	self.schema = Schema.new()
	return self
end

function JsonSchemaBuilder:AddProperty(name:string, propType:"string" | "number" | "boolean" | "Integer", isRequired:boolean, description:string, enumValues:{any})
	local property = Property.new(propType, enumValues, description or "")
	self.schema:AddProperty(name, property, isRequired)
end

function JsonSchemaBuilder:Build()
	return {
		type = "json_schema",
		json_schema = {
			name = self.name,
			strict = tostring(self.strict),
			schema = self.schema:Build()
		}
	}
end

module.SchemaBuilder = {
	Property = Property,
	Schema = Schema,
	Builder = JsonSchemaBuilder
}

return module
