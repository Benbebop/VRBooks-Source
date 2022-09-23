
include("includes/modules/bbb_file.lua")

module("pdf", package.seeall)

function objType( object )
	return (getmetatable( object ) or {}).__type or type( object )
end

local error_classes = {"pdf init", "pdf"}

function createErr( f, errorClass, err, from, to )
	
	if not f then return false, error_classes[errorClass] .. ": " .. err end
	
	from = from or f:_tell()
	to = to or from
	
	return false, error_classes[errorClass] .. ": " .. err .. " [ %04d - %04d ]":format( from, to )
	
end

-- READUNTIL SETS --

local sets = {}

do

local c = string.char

sets.eol = {c(10),c(13)}
sets.whitespace = {c(0),c(9),c(10),c(12),c(13),c(32)}
sets.number = {}
sets.regularNumber = {"-","+","."}
sets.delim = {"(",")","<",">","[","]","{","}","/","%"}
sets.syntax = {"(",")","<",">","[","]","{","}","/","%","f","t","-","+","."}
sets.syntaxEnds = {"(",")","<",">","[","]","{","}","/","%",c(0),c(9),c(10),c(12),c(13),c(32)}
for i=48,57 do table.insert(sets.number, c(i)) table.insert(sets.regularNumber, c(i)) table.insert(sets.syntax, c(i)) end

end

-- BASE CLASSES --

local root_class = {}

function root_class._parse( self, f )
	
	local s1 = f:sample(1)
	
	if s1 == "(" then
		
		io:seek("cur", 1)
		
		local level, isEscaped = 0, false
		
		return f:readUntil(function( s )
			if not isEscaped then
				if s == "(" then
					level = level + 1
				elseif s == ")" then
					if level > 0 then
						level = level - 1
					else
						return false
					end
				end
			end
			if isEscaped then
				isEscaped = false
			elseif s == "\\" then
				isEscaped = true
				return ""
			end
			return s
		end)
		
	elseif s1 == "<" then
		
		io:seek("cur", 1)
		
		local hex = ""
		
		local str = f:readUntil(function( s )
			if s == ">" then return false
			if io.isOf( s, sets.whitespace ) then return "" end
			hex = hex .. s
			if #hex >= 2 then
				return string.char(tonumber(hex, 16))
			end
			return ""
		end)
		
		if #hex > 0 then
			str = str .. string.char(tonumber(hex, 16))
		end
		
		return str
		
	elseif s1 == "/" then
		
		return root_class._constructName( self, f )
		
	elseif s1 == "[" then
		
		return root_class._constructArray( self, f )
		
	elseif f:sample(4) == "true" then
		
		f:_skip( 4 )
		
		return true
		
	elseif f:sample(5) == "false" then
		
		f:_skip( 5 )
		
		return false
		
	elseif f:sample(2) == "<<" then
		
		local dict, err = root_class._constructDict( self, f )
		
		local revenir = f:_tell()
		
		f:readUntil(sets.whitespace, false, true)
		
		if f:sample(6) ~= "stream" then f:seek("set", revenir) return dict, err end
		
		return root_class._constructStream( self, f, dict )
		
	elseif io.isOf(s1, sets.regularNumber) then
		
		if io.isOf(s1, sets.number) then
		
			local revenir = f:_tell()
		
			local index = tonumber(f:readUntil(sets.syntaxEnds))
		
			if index then
		
				f:seek("cur", 1)
		
				local gen = tonumber(f:readUntil(sets.syntaxEnds))
		
				if gen then
		
					f:seek("cur", 1)
			
					if f:read(1) == "R" then
						
						return root_class._constructRef( self, index )
						
					end
				end
			end
			
			f:seek("set", revenir)
		
		end
		
		local number = f:readUntil(sets.syntaxEnds)
		
		if number:sub(1,1) == "+" then
			return tonumber(number:sub(2,-1))
		end
		
		return tonumber(number)
	
	else
		
		return false, "invalid class"
		
	end
	
end

function root_class.LoadObject( self, objectIndex )
	
	local position = self.xref[objectIndex]
	
	if not position then return createErr( f, 2, "object (" .. objectIndex .. ") not in xref table" ) end
	
	local f = io.open( self.io, "rb", "DATA" )
	
	f:seek("set", self.xrefOffset + position)
	
	local index = tonumber(f:readUntil(sets.whitespace))
		
	f:seek("cur", 1)
		
	local gen = tonumber(f:readUntil(sets.whitespace))
		
	f:seek("cur", 1)
	
	if f:read(3) == "obj" and index and gen then
		
		local obj, err = root_class._parse( self, f )
		
		if not obj then return createErr( f, 2, err )
		
		self.objects[index] = obj
		
		return true
		
	end
	
end

function root_class._FindPage( self, pageIndex )
	
	local Obj = self.trailer.Root
	
	if Obj.Type ~= "Catalog" then return createErr( nil, 2, "Root object not type Catalog" ) end
	
	Obj = Obj.Pages
	
	if not Obj then return createErr( nil, 2, "Root object does not contains Pages object" ) end
	
	Obj = Obj.Kids
	
	if not Obj then return createErr( nil, 2, "Root object does not contains Pages object" ) end
	
	return Obj
	
end

function root_class.LoadPage( self, pageIndex )
	
	local Obj, err = root_class._FindPage( self, pageIndex )
	
	if not Obj then return false, err end
	
	for _,Page in Obj:Iter() then end
	
	return true
	
end

function root_class.GetObject( self, index )
	
	local obj = self.objects[index]
	
	if not obj then root_class.LoadObject( self, index ) obj = self.objects[index] end
	
	return obj
	
end

function root_class.UncacheObject( self, index )
	
	if self.objects[index] then
		self.objects[index] = nil
		return true
	end
	
	return false
	
end

local page_class = {}
page_class.__index = function( self, index )
	
	return page_class[index] or self.objects[index]
	
end
page_class.__type = "pdf_page"
page_class.__tostring = page_class.__type

function root_class.GetPage( self, pageIndex )
	
	local Obj, err = root_class._FindPage( self, pageIndex )
	
	
	
end

local page_iter_class = {}
page_iter_class.__call = function( self )
	
	local i,v = self()
	
	return i,v()
	
end

function root_class.ScanPage( self, pageIndex )
	
	local Obj, err = root_class._FindPage( self, pageIndex )
	
	
	
end

local name_class = {}
name_class.__index = function( self, index )
	
	return name_class[index] or self[index]
	
end
name_class.__type = "pdf_name"
name_class.__tostring = function( self ) return self.Name end

function name_class.GetName( self )
	
	return self.Name
	
end

function name_class.GetAtomicID( self )
	
	return self.Id
	
end

--TODO: escaping
function root_class._constructName( self, f )
	
	f:seek("cur", 1)
	
	local name = f:readUntil(sets.syntaxEnds)
	
	local index = false
	
	for i,v in ipairs(self.atomics) do
		if v:GetName() == name then
			index = i
			break
		end
	end
	
	if index then
		return self.atomics[index]
	else
		index = #self.atomics + 1
		self.atomics[index] = setmetatable({Name = name, Id = index}, name_class)
		return self.atomics[index]
	end
	
end

local table_iter_class = {}
table_iter_class.__call = function( self )
	
	local i,v = self()
	
	if objType(v) == "pdf_refrence" then
		return i,v()
	end
	
	return i,v
	
end

local dict_class = {}
dict_class.__index = function( self, index )
	local obj = dict_class[index]
	if obj then return obj end
	obj = self[index]
	if objType(obj) == "pdf_refrence" then
		return obj()
	end
	return obj
end
dict_class.__type = "pdf_dictionary"
dict_class.__tostring = dict_class.__type

function dict_class._Table( self )
	
	return self
	
end

function dict_class._GetRaw( self, index )
	
	return self[index]
	
end

function dict_class.Iter( self )
	
	return setmetatable( pairs( self ), table_iter_class )
	
end

function root_class._constructDict( self, f )
	
	if f:read( 2 ) ~= "<<" then return false, "invalid start delimiter" end
	
	local tbl = {}
	
	repeat
		
		f:readUntil(sets.syntax)
		
		if f:sample(2) == ">>" then break end
		
		local key = root_class._parse( self, f )
		
		print(key)
		
		if objType(key) ~= "pdf_name" then return false, "key is not a name object" end
		
		f:readUntil(sets.syntax)
		
		local value = root_class._parse( self, f )
		
		tbl[key:GetName()] = value
		
	until f:done()
	
	return setmetatable(tbl, dict_class)
	
end

local array_class = dict_class
array_class.__type = "pdf_array"
array_class.__tostring = array_class.__type

function array_class._Table( self )
	
	return self
	
end

function array_class._GetRaw( self, index )
	
	return self[index]
	
end

array_class.Iter = function( self )
	
	return return setmetatable( ipairs( self ), table_iter_class )
	
end

function root_class._constructArray( self, f )
	
	if f:read( 1 ) ~= "[" then return false, "invalid start delimiter" end
	
	local tbl = {}
	
	repeat
		
		f:readUntil(sets.syntax)
		
		if f:sample(1) == "]" then break end
		
		local value = root_class._parse( self, f )
		
		table.insert(tbl, value)
		
	until f:done()
	
	return setmetatable(tbl, array_class)
	
end

local stream_class = {}
stream_class.__index = stream_class

function stream_class.read( self )
	
	return self.data
	
end

function stream_class.decode( self )
	
	local data = self.data
	
end

function root_class._constructStream( self, f, dict )
	
	f:readUntil(sets.whitespace) f:_skip(1)
	
	return setmetatable({data = f:read(dict.Length), meta = dict}, stream_class)
	
end

root_class.__index = function( self, index )
	
	return root_class[index] or root_class.GetObject( self, index )
	
end

local ref_class = {}
ref_class.__index = ref_class
ref_class.__type = "pdf_refrence"
ref_class.__tostring = ref_class.__type

function root_class._constructRef( self, index )
	
	local ref_class = ref_class
	
	ref_class.__call = function()
		return root_class.GetObject( self, index )
	end
	
	return setmetatable( {id = index}, root_class )
	
end

function root_class.init( self )
	
	local f = io.open( self.io, "rb" )
	
	if f:read(5) ~= "%PDF-" then f:close() return createErr( f, 1, "PDF header comment missing or malformed" ) end
	
	f:readUntil(sets.eol)
	
	self.xrefOffset = f:_tell()
	
	f:readUntil(sets.whitespace, false, true)
	
	if f:read(1) == "%" then f:readUntil(sets.eol, false, true) self.xrefOffset = f:_tell() end
	
	f:seek( "end" )
	
	if f:read(-5) ~= "%%EOF" then f:close() return createErr( f, 1, "EOF comment missing or malformed" ) end
	
	f:readUntil(sets.number, true)
	f:seek("set", tonumber(f:readUntil( sets.number, true, true )))
	
	self.xref, self.atomics, self.objects = {}, {}, {}
	
	repeat
	
		f:readUntil({"x"})
		
		local pos = f:_tell()
		
		if f:readUntil(sets.whitespace) ~= "xref" then f:close() return createErr( f, 1, "xref header malformed", pos, f:_tell() ) end
		pos = f:_tell()
		f:readUntil(sets.number)
		local xrefstart = tonumber(f:readUntil(sets.whitespace))
		f:readUntil(sets.number)
		local xrefcount = tonumber(f:readUntil(sets.whitespace))
		if not (xrefstart and xrefcount) then f:close() return createErr( f, 1, "xref object malformed", pos, f:_tell() ) end
		
		if xrefcount > 0 then
	
			for i=xrefstart,xrefstart + xrefcount do
				f:readUntil(sets.number)
				local offset = tonumber(f:read(10)) f:seek("cur", 1)
				local gen = tonumber(f:read(5)) f:seek("cur", 1)
				local inUse = f:read(1) == "n"
				if not self.xref[i] then
					self.xref[i] = {offset = offset, generation = gen, inUse = inUse}
				end
			end
		
		end
	
		f:readUntil({"t"})
	
		pos = f:_tell()
	
		if f:readUntil(sets.whitespace) ~= "trailer" then f:close() return createErr( f, 1, "trailer header malformed", pos, f:_tell() ) end
	
		f:readUntil(sets.delim)
	
		pos = f:_tell()
		
		local trailer, err = root_class._constructDict( self, f )
	
		if not trailer then f:close() return createErr( f, 1, err, pos, f:_tell() ) end
		if not self.trailer then self.trailer = trailer end
		if trailer.Prev then f:seek("set", trailer.Prev) end
		
	until not trailer.Prev
	
	f:close()
	
	self.initialized = true
	
end

-- MODULE FUNCTIONS --

function open( pdf )
	
	local root = setmetatable( {io = "pdf/" .. pdf}, root_class )
	
	print(not not getmetatable(root).init)
	
	local success, err = root:init()
	
	if not success then return false, err end
	
	return true, root
	
end

function download( url )
	
	
	
end

function _loadEnabled()
	
	return util.KeyValuesToTable( file.Read("pdf/embeded.txt", "DATA") or "" )
	
end

function _saveEnabled( tbl )
	
	file.Write("pdf/embeded.txt", util.TableToKeyValues( tbl ) )
	
end

local scan_class = {}
scan_class.__call = function( self )
	
	local pdf = self.io[1]
	
	if not pdf then return nil end
	
	table.remove(self.io, 1)
	
	local title = pdf:sub(1,-5)
	
	local valid, err = open( pdf )
	
	if not valid then print(err) end
	
	self.i = self.i + 1
	
	return self.i, title, self.enabled[title], not not valid
	
end

function scanPDF()
	
	local pdf = file.Find("pdf/*.dat", "DATA")
	
	return setmetatable({io = pdf, enabled = _loadEnabled(), i = 0}, scan_class)
	
end

local metadata_class = {}
metadata_class.__index = metadata_class

function metadata_class.setEnabled( self, pdf, enabled )
	
	assert(type(enabled) == "boolean")
	
	if not self[pdf] then self[pdf] = {} end
	
	self[pdf][1] = enabled
	
end

function metadata_class.setValid( self, pdf, valid )
	
	assert(type(valid) == "boolean")
	
	if not self[pdf] then self[pdf] = {} end
	
	self[pdf][2] = valid
	
end

function metadata_class.save()
	
	_saveEnabled( self )
	
end

function getMetadata()
	
	return setmetatable(_loadEnabled, metadata_class)
	
end