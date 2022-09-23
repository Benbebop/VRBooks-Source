
include("includes/modules/pdflib.lua")

local insert = table.insert

function position( panel, wScale, wOffset, hScale, hOffset, wAnchor, hAnchor )
	
	local parent = panel:GetParent()
	
	local f = parent and function()
		if not panel:IsValid() then return true end
		
		local w, h = parent:GetSize()
		local w2, h2 = panel:GetSize()
		
		panel:SetPos( w * wScale + wOffset - w2 * wAnchor, h * hScale + hOffset - h2 * hAnchor )
		
	end or function()
		if not panel:IsValid() then return true end
		local w, h = panel:GetSize()
		
		panel:SetPos( ScrW() * wScale + wOffset - w * wAnchor, ScrH() * hScale + hOffset - h * hAnchor )
		
	end
	
	f()
	
	return f
	
end

function size( panel, wScale, wOffset, hScale, hOffset )
	
	local parent = panel:GetParent()
	
	local f = parent and function()
		if not panel:IsValid() then return true end
		local w, h = parent:GetSize()
		
		panel:SetSize( w * wScale + wOffset, h * hScale + hOffset )
		
	end or function()
		if not panel:IsValid() then return true end
		
		panel:SetSize( ScrW() * wScale + wOffset, ScrH() * hScale + hOffset )
		
	end
	
	f()
	
	return f
	
end

hook.Add("OnGamemodeLoaded", "vrbooks_gui_startup", function()
	
	local cb = {}
	
	local mainWindow = vgui.Create( "DFrame" )
	size( mainWindow, 0.5, 0, 0.5, 0 )
	position( mainWindow, 0.5, 0, 0.5, 0, 0.5, 0.5 )
	mainWindow:SetDeleteOnClose( false )
	mainWindow:SetSizable( true )
	mainWindow:SetDraggable( true )
	mainWindow:SetTitle("VRBooks Manager")
	mainWindow:MakePopup()
	
	local enabledBooks = util.KeyValuesToTable( file.Read("pdf/enabled.txt", "DATA") or "" )
	
	local books = vgui.Create( "DScrollPanel", mainWindow )
	insert( cb, size( books, 1, -50, 1, -100 ) )
	insert( cb, position( books, 0.5, 0, 0, 75, 0.5, 0 ) )
	books:SetVisible( true )
	books:SetPaintBackground( true )
	function loadBooks()
		books:Clear() 
		for i,name,enabled,valid in pdf.scanPDF() do
			i = i - 1
			local delete = vgui.Create( "DImageButton", books )
			position( delete, 0, 3, 0, i * 19 + 3, 0, 0 )
			delete:SetImage( "icon16/cross.png" )
			delete:SizeToContents()
			delete.DoClick = function()
				file.Delete("pdf/" .. f)
				loadBooks()
			end
			local enabled = vgui.Create( "DCheckBox", books )
			position( enabled, 0, 22, 0, i * 19 + 3, 0, 0 )
			enabled:SetChecked( valid and enabled )
			if valid then
				enabled.OnChange = function( val )
					pdf.setEnabled(name, tostring( val:GetChecked() ) )
				end
			end
			enabled:SetEnabled(valid)
			local title = vgui.Create( "DButton", books )
			local resize = function()
				if not title:IsValid() then return true end
				local w, h = books:GetSize()
				title:SetSize(w - 44, 16)
			end
			local reposition = function()
				if not title:IsValid() then return true end
				local w, h = books:GetSize()
				title:SetPos(41, i * 19 + 3)
			end
			resize() reposition() insert( cb, resize ) insert( cb, reposition )
			title:SetText( name .. ".pdf" )
			if not valid then
				title:SetTextColor( Color( 255, 0, 0) )
			end
		end
	end
	loadBooks()
	
	local dInput = vgui.Create( "DTextEntry", mainWindow )
	insert( cb, size( dInput, 1, -150, 0, 16 ) )
	insert( cb, position( dInput, 0, 25, 0, 50, 0, 0.5 ) )
	dInput:SetPlaceholderText( "http://www.example.com/book.pdf" )
	
	local download = vgui.Create( "DButton", mainWindow )
	insert( cb, size( download, 0, 75, 0, 16 ) )
	insert( cb, position( download, 1, -25, 0, 50, 1, 0.5 ) )
	download:SetText( "download" )
	download.DoClick = function()
		download:SetText( "downloading" )
		download:SetEnabled( false )
		pdf.download( dInput:GetValue(), function()
			loadBooks()
			download:SetEnabled( true )
			download:SetText( "download" )
		end)
	end
	
	mainWindow.OnSizeChanged = function()
		
		for i,v in ipairs(cb) do
			if v() then
				table.remove(cb, i)
			end
		end
		
	end
	
end)