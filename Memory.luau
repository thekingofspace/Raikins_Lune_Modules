local module = {}

export type ClaimedMemory= {
	MetaData:{
		ClaimedTime:number;
		Updated:number
	};

	Value:any;
}

_G.SessionID = _G.SessionID or math.random(1, 2^31 - 1)

_G.MemoryController = _G.MemoryController or {FreedMemory = {}, ClaimedMemory = {}, JoinedMemory = {}}

local function throwerror(Error:string)
	error(`[UNHANDLED ERROR] - {Error:upper()}`)
end

local function GenerateMemoryAddress(key: string): string
    local baseString = string.format("%d|%s", _G.SessionID, key)
    local numericHash = 0
    for i = 1, #baseString do
        numericHash = (numericHash * 31 + string.byte(baseString, i)) % 0xFFFFFFFF
    end
    return string.format("0x%08X", numericHash)
end

local function IsJoined(Address:string):boolean
	return _G.MemoryController.JoinedMemory[Address] ~= nil
end

-- Returns a string used for memory address.
function module.GetAddress(Key:string):string
	return GenerateMemoryAddress(Key)
end


-- Claims memory to be used by providing a address.
-- If memory is claimed will throw a unhanlded error.
function module.Claim(Address:string):string
	if module.IsClaimed(Address) == true then
		throwerror("Memory already claimed")
	end
	
	if IsJoined(Address) == true then
		throwerror("Can not claim joined memory")
	end

	local OldAddress = table.find(_G.MemoryController.FreedMemory, Address)

	if OldAddress then
		table.remove(_G.MemoryController.FreedMemory,  OldAddress)
	end

	_G.MemoryController.ClaimedMemory[Address] = {
		MetaData = {
			ClaimedTime = os.date();
			Updated = os.time()
		};

		Value = {}
	}

	OldAddress = nil

	return Address
end

-- Frees memory from being used.
-- If memory is not claimed will throw a unhanlded error.
function module.Free(Address:string)
	if module.IsClaimed(Address) == false then
		throwerror("Memory is not claimed yet")
	end
	
	if IsJoined(Address) == true then
		for I, item in ipairs(_G.MemoryController.JoinedMemory[Address]) do
			pcall(function()
				module.Free(item)
			end)
		end
		
		_G.MemoryController.JoinedMemory[Address] = nil
	end
	
	table.insert(_G.MemoryController.FreedMemory, Address)

	table.clear(_G.MemoryController.ClaimedMemory[Address])


	_G.MemoryController.ClaimedMemory[Address] = nil
end

-- Reads that memory
-- If memory is not claimed will throw a unhanlded error.
function module.Read(Address:string):...any
	if module.IsClaimed(Address) == false and module.IsFreed(Address) == false then
		throwerror("Memory is not claimed yet")

	elseif module.IsClaimed(Address) == false and module.IsFreed(Address) == true  then
		throwerror("Memory was already freed.")
	end
	
	if IsJoined(Address) == true then
		local Data = {}
		
		for I, item in ipairs(_G.MemoryController.JoinedMemory[Address]) do
			local Input = nil
			local Suc = pcall(function()
				Input = module.Read(item)
			end)
			
			if Suc then
				table.insert(Data, Input)
			end
			
			Input = nil
		end
		
		
		return unpack(Data)
	else
		return _G.MemoryController.ClaimedMemory[Address].Value
	end
end

-- Writes that memory This writes only Value not metadata so only pass what you want value to be.
-- If memory is not claimed will throw a unhanlded error.
function module.Write(Address:string, NewValue:any)
	if IsJoined(Address) == true then
		throwerror("Can not write joined memory")
	end
	
	if module.IsClaimed(Address) == false and module.IsFreed(Address) == false then
		throwerror("Memory is not claimed yet")

	elseif module.IsClaimed(Address) == false and module.IsFreed(Address) == true  then
		throwerror("Memory was already freed.")
	end

	_G.MemoryController.ClaimedMemory[Address].MetaData.Updated = os.time()

	_G.MemoryController.ClaimedMemory[Address].Value = NewValue
end

function module.Transform(Address:string, Callback:(any) -> any)
	if module.IsClaimed(Address) == false and module.IsFreed(Address) == false then
		throwerror("Memory is not claimed yet")

	elseif module.IsClaimed(Address) == false and module.IsFreed(Address) == true  then
		throwerror("Memory was already freed.")
	end
	
	if IsJoined(Address) == true then
		throwerror("Can not transform joined memory")
	end
	
	_G.MemoryController.ClaimedMemory[Address].Value = Callback(_G.MemoryController.ClaimedMemory[Address].Value)
	
	_G.MemoryController.ClaimedMemory[Address].MetaData.Updated = os.time()
end


-- Reads that memory returning the full data including meta.
-- If memory is not claimed will throw a unhanlded error.
function module.RawRead(Address:string):ClaimedMemory
	if IsJoined(Address) == true then
		throwerror("Can not read joined memory")
	end
	
	local OldAddress = table.find(_G.MemoryController.FreedMemory, Address)

	if _G.MemoryController.ClaimedMemory[Address] == nil and OldAddress == nil then
		throwerror("Memory is not claimed yet")

	elseif _G.MemoryController.ClaimedMemory[Address] == nil and OldAddress ~= nil then
		throwerror("Memory was already freed.")
	end

	OldAddress = nil

	return _G.MemoryController.ClaimedMemory[Address]
end

--Check if a address is claimed or not.
function module.IsClaimed(Address:string)
	return _G.MemoryController.ClaimedMemory[Address] ~= nil
end

--Check if a addresss is freed or no.
function module.IsFreed(Address:string)
	return table.find(_G.MemoryController.FreedMemory, Address) ~= nil
end

-- any address connected to this become semi fused this address can not be written to it will act as a collection of addresses.
-- Deleting this deletes all join addresses.
function module.Join(Address:string, Adresses:{string})
	if module.IsClaimed(Address) ~= false then
		throwerror("This address is claimed.")
	end
	
	module.Claim(Address)
	
	_G.MemoryController.JoinedMemory[Address] = Adresses
end

-- any address connected to this become semi fused this address can not be written to it will act as a collection of addresses.
-- Deleting this deletes all join addresses.
function module.UnJoin(Address:string)
	if module.IsClaimed(Address) == false then
		throwerror("This address is not claimed.")
	end
	
	if IsJoined(Address) ~= true then
		throwerror("This address is not a joined value.")
	end
	
	_G.MemoryController.ClaimedMemory[Address] = nil
	
	_G.MemoryController.JoinedMemory[Address] = nil
end

--Adds a new address to a join.
function module.Union(Joint_Address:string, New_Join:string)
	if module.IsClaimed(Joint_Address) == false or module.IsClaimed(New_Join) == false then
		throwerror("One of the two addresses provided are invalid.")
	end
	
	if IsJoined(Joint_Address) == false then
		throwerror("This is not a joining address.")
	end
	
	table.insert(_G.MemoryController.JoinedMemory, New_Join)
end

--Removes a address from a join.
function module.UnUnion(Joint_Address:string, Old_Join:string)
	if module.IsClaimed(Joint_Address) == false or module.IsClaimed(Old_Join) == false then
		throwerror("One of the two addresses provided are invalid.")
	end

	if IsJoined(Joint_Address) == false then
		throwerror("This is not a joining address.")
	end
	
	local Target = table.find(_G.MemoryController.JoinedMemory, Old_Join)

	if Target ~= nil then
		table.remove(_G.MemoryController.JoinedMemory, Target)
	end
end

-- Lists all joined addresses with a joint.
function module.ListJoint(Address:string):{string}
	if module.IsClaimed(Address) == false then
		throwerror("Address is invalid")
	end

	if IsJoined(Address) == false then
		throwerror("This is not a joining address.")
	end
	
	return _G.MemoryController.JoinedMemory[Address]
end


return module
