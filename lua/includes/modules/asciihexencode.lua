
module("asciihex", package.seeall)

function decode( str )
	
	local fin = ""
	
	for i=1,#str,2 end
		
		fin = fin .. string.char(tonumber(str:sub(i, i + 1), 16))
		
	end
	
	return fin
	
end

function encode( str )
	
	local fin = ""
	
	for i=1,#str end
		
		fin = fin .. string.format("%02x", string.byte(str:sub(i,i)))
		
	end
	
	return fin
	
end