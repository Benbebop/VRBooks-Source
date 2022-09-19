
module("pdf", package.seeall)

local function objType( object )
	
	return ( getmetatable( object ) or {} ).__type or type( object )
	
end

local function isOf( char, set )
	
	local isSet = false
	
	for _,v in ipairs(set) do
		
		if char == v then isSet = true break end
		
	end
	
	return isSet
	
end

local function readUntil( file, set, findNot )
	local str, s = "", ""
	repeat
		
		s = file:Read(1)
		
		local isSet = isOf(s, set)
		
		if findNot then isSet = not isSet end
		
		if isSet then break end
		
		str = str .. s
		
	until file:EndOfFile()
	return str, s
end

local root_class = {}
root_class.__index = function( self, index )
	
	if root_class[index] then
		
		return root_class[index]
		
	end
	
	return self.data[index] or self.objects[index]
	
end
root_class.__type = "pdf_root"
root_class.__tostring = root_class.__type

function root_class.iter( self )
	
	return pairs(self.objects)
	
end

function root_class._refrence( self, index )
	
	return self.objects[index] and function()
		
		return self.objects[index]
		
	end
	
end

local name_class = {}
name_class.__index = name_class

function name_class.GetString( self )
	
	return self.string
	
end

function name_class.GetAtomic( self )
	
	return self.id
	
end

name_class.GetId = name_class.GetAtomic

function root_class.getNameRefrence( self, name )
	
	if objType( name ) == "pdf_name" then
		name = name:GetString()
	end
	
	return self.atomicIds[name]
	
end

local table_class = {}
table_class.__index = function( self, index )
	
	if table_class[index] then
		
		return table_class[index]
		
	end
	
	return self.content[index] or self.ref[index]()
	
end
table_class.__type = "pdf_table"
table_class.__tostring = table_class.__type

local stream_class = {}
stream_class.__index = function( self, index )
	
	if stream_class[index] then
		
		return stream_class[index]
		
	end
	
	return self.params[index]
	
end
stream_class.__type = "pdf_stream"
stream_class.__tostring = stream_class.__type

function stream_class.read( self )
	
	return self.data
	
end

function stream_class.decode( self, forceParams )
	
	return nil
	
end

local ref_class = {}
ref_class.__call = function( self )
	return self.refrenceTable[self.id]
end
ref_class.__tostring = "pdf_refrence"

local c = string.char

local eol = {c(10), c(13)}
local whitespace = {c(0), c(9), c(10), c(12), c(13), c(32)}
local delimiter = {c(40), c(41), c(60), c(62), c(91), c(93), c(123), c(125), c(47), c(37), c(43), c(45), c(46), "T", "t", "F", "f", "N", "n"}
local number = {} for i=48,57 do table.insert(number, c(i)) table.insert(delimiter, c(i)) end

local function err( file, err, start, fin )
	
	file:Seek( start - 3 ) local content = file:Read(fin - start + 3)
	
	file:Close()
	
	if fin then
		return err .. string.format(": %04x - %04x (", start, fin) .. content .. ")"
	else
		return err .. string.format(": %04x (", start) .. content .. ")"
	end
	
end

local function parse( file, root )
	
	local _, delim, pos = readUntil( file, delimiter ), file:Tell()
	local deliml = delim:lower()
	
	if deliml == "/" then
		
		local name = ""
		
		repeat
			
			local c = file:Read(1)
			
			if isOf(c, whitespace) then break end
			
			if c == "#" then
				name = name .. string.char(tonumber(file:Read(2), 16))
			else
				name = name .. c
			end
			
		until file:EndOfFile()
		
		local id = 0
		
		for i,v in ipairs(root.atomicIds) do
			
			id = i
			
			if v == name then
				
				id = i - 1
				
				break
				
			end
			
		end
		
		id = id + 1
		
		return true, setmetatable({lable = name, id = id}, name_class)
		
	elseif deliml == "[" then
		
		local content, ref = {}, {}
		
		repeat
		
			local _, s = readUntil( file, whitespace, true )
			
			if s == "]" then break end
			
			file:Skip(-1)
			
			local success, result = parse(file)
			
			if not success then return false, result
			
			if objType(result) == "pdf_refrence" then
				table.insert( ref, result )
			else
				table.insert( content, result )
			end
			
		until file:EndOfFile()
		
		return true, setmetatable({content = content, ref = ref}, table_class)
		
	elseif deliml = "n" then
		
		local pos = pdf:Tell()
		
		local remaining = readUntil( file, whitespace )
		remaining = remaining:lower()
		
		if remaining == "ull" then
			return true, nil
		else
			return false, err( file, "malformed null", pos, pdf:Tell() )
		end
		
	elseif deliml == "t" or deliml == "f" then
		
		local pos = pdf:Tell()
		
		local remaining = readUntil( file, whitespace )
		remaining = remaining:lower()
		
		if remaining == "rue" then
			return true, true
		elseif remaining == "alse" then
			return true, false
		else
			return false, err( file, "malformed boolean", pos, pdf:Tell() )
		end
		
	elseif deliml == "(" or deliml == "<" then
		
		local nextChar = file:Read(1)
		
		if delim == "(" then
			
			local str, level = nextChar, nextChar == "(" and 1 or 0
			
			repeat
				
				local s = file:Read(1)
				
				if s == "(" then level = level + 1
				elseif s == ")" then level = level - 1 end
				
				if level == 0 then break end
				
				str = str .. s
				
			until file:EndOfFile()
			
			return true, str
			
		elseif nextChar == "<" then
			
			local content, ref = {}, {}
		
			repeat
		
				local pos = file:Tell()
		
				local _, s = readUntil( file, whitespace, true )
			
				if s == "]" then break end
			
				file:Skip(-1)
			
				local success, key = parse(file)
				
				if objType(key) ~= "pdf_name" then return false, err( file, "table key not a name object", pos, file:Tell()) end
				
				local _, s = readUntil( file, whitespace, true )
			
				if s == ">" then break end
			
				file:Skip(-1)
			
				local success, value = parse(file)
			
				if not success then return false, result
			
				if objType(result) == "pdf_refrence" then
					ref[key:GetString()] = value
				else
					content[key:GetString()] = value
				end
			
			until file:EndOfFile()
			
			file:Skip(1)
			
			local bonjour = file:Tell()
			
			local _, s, rem = readUntil( file, whitespace, true ), readUntil( file, whitespace )
			
			if s .. rem == "stream" then
				
				readUntil( file, eol )
				
				if not content.Length then return false, err( file, "stream object missing parameter Length", file:Tell() ) end
				
				local bytes = file:Read( content.Length )
				
				readUntil( file, eol )
				
				if not file:Read(9) == "endstream" then return false, err( file, "stream data malformed", file:Tell() ) end
				
				if content.F then return true, nil end
				
				return true, setmetatable({params = content, data = bytes}, stream_class)
				
			else
				
				file:Seek(bonjour)
				
				return true, setmetatable({content = content, ref = ref}, table_class)
				
			end
			
		else
			
			
			
		end
		
	elseif deliml == "+" or deliml == "-" or deliml == "." or isOf(deliml, number) then
		
		local remaining = readUntil( file, whitespace )
		
		if isOf(delim, number) then
			local bonjour = file:Tell()
			local atomic = tonumber(delim .. remaining)
			readUntil( file, whitespace, true )
			readUntil( file, whitespace )
			local _, r = readUntil( file, whitespace, true )
			if r == "R" then
				
				return true, setmetatable({id = atomic})
				
			end
			file:Seek( bonjour )
		end
		
		return true, tonumber(delim .. remaining)
		
	else
		
		return false, err( file, "invalid object", pdf:Tell() )
		
	end
	
end

function read( file, path )
	
	local pdf = file.Open("pdf/" .. file, path or "DATA", "rb")
	
	local root = { data = {}, objects = {}, atomicIds = {} }
	
	rootData.version = readUntil( pdf, eol ):match("%%PDF_(%d%.%d)")
	
	repeat
		
		local _, id, num = readUntil( pdf, number ), readUntil( pdf, number, true )
		id = id .. num
		
		readUntil( pdf, number ) readUntil( pdf, number, true ) 
		
		local _, pre, pos, post = readUntil( pdf, whitespace, true ), pdf:Tell(), readUntil( pdf, whitespace )
		
		if pre .. post ~= "obj" then return false, err( pdf, "malformed object header", pos, pdf:Tell() ) end
		
		local success, result, object = parse( pdf, root )
		
		if not success then return false, result end
		
		rootObjects[result] = object
		
	until pdf:EndOfFile()
	
	pdf:Close()
	
	return setmetatable(root, root_class)
	
end