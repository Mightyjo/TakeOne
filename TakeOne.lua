TakeOne = {
    displayName = "Take One",
    shortName = "TO",
    name = "TakeOne",
    version = "0.1.0",

}

function TakeOne:CreateMenu()

    self.savedVariables.debugLog = {}

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
            name = "Show Debug Log",
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

function TakeOne:OnAddOnLoaded(event, addonName)

    if addonName ~= self.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED)
    setmetatable(TakeOne, {__index = LibMarify})

    self.savedVariables = ZO_SavedVars:NewAccountWide("TakeOneVariables", 1, nil, {})
    self.savedCharVariables  = ZO_SavedVars:NewCharacterIdSettings("TakeOneVariables", 1, nil, {})
	self:CreateMenu()

--    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CRAFTING_STATION_INTERACT,     function(...) self:StationInteract(...) end)
    LibCustomMenu:RegisterContextMenu(function(...) self:ShowContextMenu(...) end, LibCustomMenu.CATEGORY_LATE)
	
	self:Debug("<<1>> Loaded", self.displayName)

end

function TakeOne:DoTake(inventorySlot)
    self:Debug("    Entered DoTake")
	
	local slotType = ZO_InventorySlot_GetType(inventorySlot)
	local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
	if not slotIndex then
	    PlaySound("Justice_PickpocketFailed")
	    return
	end
	
	local targetSlot = FindFirstEmptySlotInBag(BAG_BACKPACK)
	if not targetSlot then
	    PlaySound("Justice_PickpocketFailed")
		return
	end
	
	local quantity = GetSlotStackSize(bagId, slotIndex)
	self:Debug("    Moving 1 of <<1>>", quantity)
	
	if slotType == SLOT_TYPE_BANK_ITEM then
  	    CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_BACKPACK, targetSlot, 1)
	elseif slotType == SLOT_TYPE_GUILD_BANK_ITEM then
	    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, self:DoSplit(bagId, slotIndex, quantity))
		EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
	    self:Debug("    Sending DoSplit for <<1>>, <<2>>", bagId, slotIndex)
		TransferFromGuildBank(slotIndex)	
	else
	    return
	end
	
	self:Debug("    Leaving DoTake")
end

function TakeOne:DoSplit(bagId, slotIndex, quantity)
  return function(eventCode, _bagId, _slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
      self:Debug("    Entered DoSplit for <<1>>, <<2>>", bagId, slotIndex)
      if not( _bagId == BAG_BACKPACK ) then
          self:Debug("    Not in backpack: <<1>>", _bagId)
          return
      end
      
      local _quantity = GetSlotStackSize(_bagId, _slotIndex)
      self:Debug("    Expected qty=<<1>>; Got qty=<<2>>", quantity, _quantity)
      if not( quantity == _quantity ) then
          return
      end
               
      EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
               
      local _targetSlot = FindFirstEmptySlotInBag(BAG_BACKPACK)
      
      
      EVENT_MANAGER:RegisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, self:DoReturn(_bagId, _slotIndex, _targetSlot))
      EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
      self:Debug("    Sending DoReturn for <<1>>, <<2>>", _bagId, _slotIndex)
      CallSecureProtected("RequestMoveItem", _bagId, _slotIndex, BAG_BACKPACK, _targetSlot, 1)
               
      self:Debug("    Leaving DoSplit")
  end
end

function TakeOne:DoReturn(bagId, slotIndex, targetSlot)
  return function(eventCode, _bagId, _slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
    self:Debug("    Entered DoReturn for <<1>>, <<2>>", bagId, slotIndex)
    if not( targetSlot == _slotIndex ) then
	   self:Debug("    <<1>> is not the slot we're looking for: <<2>>", targetSlot, _slotIndex)
       return
    end
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    TransferToGuildBank( bagId, slotIndex)
	
	self:Debug("    Leaving DoReturn")
    end
end

ZO_CreateStringId("TO_CONTEXT_MENU", "Take 1")
function TakeOne:ShowContextMenu(inventorySlot, slotActions)

--  Check this is in a guild bank
    local slotType = ZO_InventorySlot_GetType(inventorySlot)
	self:Debug(" SlotType: <<1>>", slotType)
    if not( slotType == SLOT_TYPE_BANK_ITEM or slotType == SLOT_TYPE_GUILD_BANK_ITEM ) then
        return
    end


    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    local itemLink = GetItemLink(bagId, slotIndex)
	
	self:Debug(" BagID: <<1>>;  slotIndex: <<2>>", bagId, slotIndex)

    if not CheckInventorySpaceSilently(2) then
	    return
    end
	
	if not (GetSlotStackSize(bagId, slotIndex) > 1) then
	    return
	end
	
	slotActions:AddCustomSlotAction(TO_CONTEXT_MENU, function() self:DoTake(inventorySlot) end, "")
	 
end

EVENT_MANAGER:RegisterForEvent(TakeOne.name, EVENT_ADD_ON_LOADED, function(...) TakeOne:OnAddOnLoaded(...) end)
