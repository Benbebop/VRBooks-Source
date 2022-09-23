-- NATIVE LUA SIMILAR IO --

module("io", package.seeall)

local file_class = {}
file_class.__index = file_class

function file_class.read( self, length )
	
	assert(self.io)
	
	local result = ""
	
	if length > 0 then
		
		result = self.io:Read( length )
		
	elseif length < 0 then
		
		self.io:Skip( length )
		
		result = self.io:Read( math.abs( length ) )
		
		self.io:Skip( length )
		
	end
	
	return result
	
end

function file_class._read( self, ... ) return self.io:Read( ... ) end

function isOf( char, set )
	
	local isSet = false
	
	for _,v in ipairs(set) do
		if char == v then
			isSet = true
			break
		end
	end
	
	return isSet
	
end

function file_class.readUntil( self, set, reverse, inverse )
	
	assert(self.io)
	
	local str = ""
	
	local l = reverse and -1 or 1
	
	if type(set) == "function" then
		
		repeat
		
			local s = file_class.read( self, l )
		
			s = set(s, str)
			
			if not s then break end
		
			str = str .. s
		
		until self.io:EndOfFile()
		
	else
	
		repeat
		
			local s = file_class.read( self, l )
		
			local isSet = isOf( s, set )
		
			if inverse then isSet = not isSet end
		
			if isSet then break end
		
			str = str .. s
		
		until self.io:EndOfFile()
		
	end
	
	self.io:Skip(-l)
	
	if reverse then
		return string.reverse( str )
	else
		return str
	end
	
end

function file_class.seek( self, mode, offset )
	
	assert(self.io)
	
	if mode == "set" then
		
		self.io:Seek( offset or 0 )
		
	elseif mode == "cur" then
		
		self.io:Skip( offset or 0 )
		
	elseif mode == "end" then
		
		self.io:Seek( self.io:Size() )
		
	end
	
	return self.io:Tell()
	
end

function file_class._seek( self, ... ) return self.io:Seek( ... ) end
function file_class._skip( self, ... ) return self.io:Skip( ... ) end

function file_class.sample( self, length )
	
	local str = file_class.read( self, length )
	
	self.io:Skip( -length )
	
	return str
	
end

function file_class._tell( self ) return self.io:Tell() end

function file_class.done( self )
	
	return self.io:EndOfFile()
	
end

function file_class.close( self )
	
	self.io:Close()
	
end

file_class.__gc = file_class.close -- doesnt do anything unless its a userdata

function open( filePath, mode, path )
	
	path = path or "DATA"
	
	return setmetatable({io = file.Open( filePath, mode, path )}, file_class)
	
end