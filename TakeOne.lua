TakeOne = {
    displayName = "Take One",
    shortName = "TO",
    name = "TakeOne",
    version = "1.1.0",
    logger = nil,
	variablesVersion = 2,
	variablesDefault = {
	  isDebug = false,
	}
	
}

function TakeOne:CreateMenu()

    local panelData = {
        type = "panel",
        name = self.displayName,
        displayName = self.displayName,
        author = "Mightyjo",
        version = self.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }
    LibAddonMenu2:RegisterAddonPanel(self.displayName, panelData)


    local optionsTable = {
        {
            type = "checkbox",
            name = GetString(TAKE_ONE_OPTION_DEBUG),
            getFunc = function()
                return self.savedVariables.isDebug
            end,
            setFunc = function(value)
                self.savedVariables.isDebug = value
            end,
            width = "full",
            default = false,
        }
    }
    LibAddonMenu2:RegisterOptionControls(self.displayName, optionsTable)
end

function TakeOne:Info(text, ...)
    
	if self.logger then
	  self:Log(LibDebugLogger.LOG_LEVEL_INFO, text, ...)
	else
	  if ... ~= nil then
	    text = zo_strformat(text, unpack({...}))
	  end
	  d( string.format("%s: %s", self.name, text) )
	end
	
end

function TakeOne:Debug(text, ...)
    
	if self.logger == nil then
	  return
	end
	
	if self.savedVariables.isDebug == false then
	  return
	end
	  
	self:Log(LibDebugLogger.LOG_LEVEL_DEBUG, text, ...)
	
end

function TakeOne:Warn(text, ...)
    
	if self.logger == nil then
	  return
	end
	  
	self:Log(LibDebugLogger.LOG_LEVEL_WARNING, text, ...)
	
end

function TakeOne:Error(text, ...)
    
	if self.logger == nil then
	  return
	end
	  
	self:Log(LibDebugLogger.LOG_LEVEL_ERROR, text, ...)
	
end

function TakeOne:Log(level, text, ...)
    if self.logger == nil then
	  return
	end
	
	local _logger = self.logger
	
	local switch = {
	  [LibDebugLogger.LOG_LEVEL_DEBUG] = function (text) _logger:Debug(text) end,
	  [LibDebugLogger.LOG_LEVEL_INFO] = function (text) _logger:Info(text) end,
	  [LibDebugLogger.LOG_LEVEL_WARNING] = function (text) _logger:Warn(text) end,
	  [LibDebugLogger.LOG_LEVEL_ERROR] = function (text) _logger:Error(text) end,
	  default = nil,
	}
	
	local case = switch[level] or switch.default
	if case then
	  if ... ~= nil then
	    text = zo_strformat(text, unpack({...}))
	  end
	  case(text)
	end

end

function TakeOne:OnAddOnLoaded(event, addonName)

    if addonName ~= self.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED)
    
	if LibDebugLogger then
	  self.logger = LibDebugLogger(self.name)
	end

    self.savedVariables = ZO_SavedVars:NewAccountWide("TakeOneVariables", TakeOne.variablesVersion, nil, TakeOne.variablesDefault)
	--self.savedCharVariables  = ZO_SavedVars:NewCharacterIdSettings("TakeOneVariables", 1, nil, {})
	self:CreateMenu()

    LibCustomMenu:RegisterContextMenu(function(...) self:ShowContextMenu(...) end, LibCustomMenu.CATEGORY_LATE)
	
	self:Info(GetString(TAKE_ONE_LOADED))

end

function TakeOne:DoTake(inventorySlot, _itemId)
    	
	local slotType = ZO_InventorySlot_GetType(inventorySlot)
	local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
	if not slotIndex then
	    self:Warn(GetString(TAKE_ONE_SLOT_FULL))
	    PlaySound("Justice_PickpocketFailed")
	    return
	end
	
	local itemLink = GetItemLink(bagId, slotIndex)
	local itemId = GetItemLinkItemId(itemLink)
	if not( _itemId == itemId ) then
	    self:Warn(GetString(TAKE_ONE_SLOT_CHANGED))
	    PlaySound("Justice_PickpocketFailed")
	    return
	end
	
	local targetSlot = FindFirstEmptySlotInBag(BAG_BACKPACK)
	if not targetSlot then
	    self:Warn(GetString(TAKE_ONE_NO_SLOTS))
	    PlaySound("Justice_PickpocketFailed")
		return
	end
	
	local quantity = GetSlotStackSize(bagId, slotIndex)
	self:Debug(GetString(TAKE_ONE_DO_TAKE_ACTION), quantity)
	
	if slotType == SLOT_TYPE_BANK_ITEM then
  	    CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_BACKPACK, targetSlot, 1)
	elseif slotType == SLOT_TYPE_GUILD_BANK_ITEM then
	    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, self:DoSplit(itemId, quantity))
		EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
		
	    self:Debug(GetString(TAKE_ONE_DO_TAKE_SENDING), itemId, quantity)
		TransferFromGuildBank(slotIndex)	
	else
	    return
	end
	
end

function TakeOne:DoSplit(itemId, quantity)
  return function(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)

      if not( bagId == BAG_BACKPACK ) then
          self:Error(GetString(TAKE_ONE_DO_SPLIT_WRONG_BAG), bagId)
          return
      end
      
	  local itemLink = GetItemLink(bagId, slotIndex)
	  local _itemId = GetItemLinkItemId(itemLink)
	  if not( _itemId == itemId ) then
	      self:Debug(GetString(TAKE_ONE_DO_SPLIT_WRONG_ITEM), _itemId, itemId )
	      return
	  end
	  
      local _quantity = GetSlotStackSize(bagId, slotIndex)
      if not( quantity == _quantity ) then
	      self:Debug(GetString(TAKE_ONE_DO_SPLIT_WRONG_QUANTITY), _quantity, quantity )
          return
      end
      
	  self:Debug(GetString(TAKE_ONE_DO_SPLIT_RIGHT_STACK), itemId, quantity)
      EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
               
      local targetSlot = FindFirstEmptySlotInBag(BAG_BACKPACK)
      
      
      EVENT_MANAGER:RegisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, self:DoReturn(bagId, slotIndex, targetSlot))
      EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
	  
      self:Debug(GetString(TAKE_ONE_DO_SPLIT_SENDING), _bagId, _slotIndex)
      CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_BACKPACK, targetSlot, 1)

  end
end

function TakeOne:DoReturn(bagId, slotIndex, targetSlot)
  return function(eventCode, _bagId, _slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
    
    if not( targetSlot == _slotIndex ) then
	   self:Debug(GetString(TAKE_ONE_DO_RETURN_WRONG_SLOT), targetSlot, _slotIndex)
       return
    end
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    TransferToGuildBank( bagId, slotIndex)

    end
end

function TakeOne:isValid(inventorySlot)
    local slotType = ZO_InventorySlot_GetType(inventorySlot)
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
	
    -- Check that this is a BANK or GUILD_BANK slot
	if not( slotType == SLOT_TYPE_BANK_ITEM or slotType == SLOT_TYPE_GUILD_BANK_ITEM ) then
        return false
    end
	
	-- Check that guild has a 
	if slotType == SLOT_TYPE_GUILD_BANK_ITEM then
	  local guildId = GetSelectedGuildBankId()
	  
	  if not guildId then
	      return false
	  end
	  if not DoesGuildHavePrivilege(guildId, GUILD_PRIVILEGE_BANK_DEPOSIT) then
	      return false
      elseif not( DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_DEPOSIT) and DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_WITHDRAW) ) then
	      return false
	  end
	end
	
	-- Check that the BACKPACK has enough room to operate
	if slotType == SLOT_TYPE_BANK_ITEM and not CheckInventorySpaceSilently(1) then 
	    return false
	elseif slotType == SLOT_TYPE_GUILD_BANK_ITEM and not CheckInventorySpaceSilently(2) then
	    return false
	end
	
	-- Check that the source stack contains more than 1 item
	if not (GetSlotStackSize(bagId, slotIndex) > 1) then
	    return false
	end
	
	return true
end

function TakeOne:ShowContextMenu(inventorySlot, slotActions)

    -- Check inventorySlot validity
	if not self:isValid(inventorySlot) then
	    return
	end


    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    local itemLink = GetItemLink(bagId, slotIndex)
	local itemId = GetItemLinkItemId(itemLink)
	
	self:Debug(GetString(TAKE_ONE_CONTEXT_MENU_INFO), bagId, slotIndex, itemId)
	
	AddCustomMenuItem(GetString(TAKE_ONE_CONTEXT_MENU), function() self:DoTake(inventorySlot, itemId) end)

	 
end

EVENT_MANAGER:RegisterForEvent(TakeOne.name, EVENT_ADD_ON_LOADED, function(...) TakeOne:OnAddOnLoaded(...) end)
