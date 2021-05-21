TakeOne = {
    displayName = "Take One",
    shortName = "TO",
    name = "TakeOne",
    version = "1.0.1",

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

    LibCustomMenu:RegisterContextMenu(function(...) self:ShowContextMenu(...) end, LibCustomMenu.CATEGORY_PRIMARY)
	
	self:Debug("<<1>> Loaded", self.displayName)

end

function TakeOne:DoTake(inventorySlot, _itemId)
    self:Debug("    Entered DoTake")
	
	local slotType = ZO_InventorySlot_GetType(inventorySlot)
	local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
	if not slotIndex then
	    self:Debug("    Slot no longer available")
	    PlaySound("Justice_PickpocketFailed")
	    return
	end
	
	local itemLink = GetItemLink(bagId, slotIndex)
	local itemId = GetItemLinkItemId(itemLink)
	if not( _itemId == itemId ) then
	    self:Debug("   Slot contents changed")
	    PlaySound("Justice_PickpocketFailed")
	    return
	end
	
	local targetSlot = FindFirstEmptySlotInBag(BAG_BACKPACK)
	if not targetSlot then
	    self:Debug("   No available slots in backpack")
	    PlaySound("Justice_PickpocketFailed")
		return
	end
	
	local quantity = GetSlotStackSize(bagId, slotIndex)
	self:Debug("    Moving 1 of <<1>>", quantity)
	
	if slotType == SLOT_TYPE_BANK_ITEM then
  	    CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_BACKPACK, targetSlot, 1)
	elseif slotType == SLOT_TYPE_GUILD_BANK_ITEM then
	    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, self:DoSplit(itemId, quantity))
		EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
	    self:Debug("    Sending DoSplit for <<1>>, <<2>>", itemId, quantity)
		TransferFromGuildBank(slotIndex)	
	else
	    return
	end
	
	self:Debug("    Leaving DoTake")
end

function TakeOne:DoSplit(itemId, quantity)
  return function(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
      self:Debug("    Entered DoSplit for <<1>>, <<2>>", itemId, quantity)
      if not( bagId == BAG_BACKPACK ) then
          self:Debug("    Not in backpack: <<1>>", bagId)
          return
      end
      
	  local itemLink = GetItemLink(bagId, slotIndex)
	  local _itemId = GetItemLinkItemId(itemLink)
	  if not( _itemId == itemId ) then
	      self:Debug("   Not the item we're looking for: <<1>> (<<2>>)", _itemId, itemId )
	      return
	  end
	  
      local _quantity = GetSlotStackSize(bagId, slotIndex)
      if not( quantity == _quantity ) then
	      self:Debug("   Not the quantity we're expecting: <<1>> (<<2>>)", _quantity, quantity )
          return
      end
               
      EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
               
      local targetSlot = FindFirstEmptySlotInBag(BAG_BACKPACK)
      
      
      EVENT_MANAGER:RegisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, self:DoReturn(bagId, slotIndex, targetSlot))
      EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
      self:Debug("    Sending DoReturn for <<1>>, <<2>>", _bagId, _slotIndex)
      CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_BACKPACK, targetSlot, 1)
               
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

function TakeOne:isValid(inventorySlot)
    local slotType = ZO_InventorySlot_GetType(inventorySlot)
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
	
	self:Debug(" SlotType: <<1>>", slotType)
	
    -- Check that this is a BANK or GUILD_BANK slot
	if not( slotType == SLOT_TYPE_BANK_ITEM or slotType == SLOT_TYPE_GUILD_BANK_ITEM ) then
        return false
    end
	
	-- Check that guild has a 
	if slotType == SLOT_TYPE_GUILD_BANK_ITEM then
	  local guildId = GetSelectedGuildBankId()
	  
	  self:Debug("    GuildId: <<1>>", guildId)
	  
	  if not guildId then
	      return false
	  end
	  if not DoesGuildHavePrivilege(guildId, GUILD_PRIVILEGE_BANK_DEPOSIT) then
	      return false
      elseif not( DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_DEPOSIT) and DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_WITHDRAW) ) then
	      return false
	  end
	end
	
	self:Debug("   Has bank privileges")
	
	-- Check that the BACKPACK has enough room to operate
	if slotType == SLOT_TYPE_BANK_ITEM and not CheckInventorySpaceSilently(1) then 
	    return false
	elseif slotType == SLOT_TYPE_GUILD_BANK_ITEM and not CheckInventorySpaceSilently(2) then
	    return false
	end
	
	self:Debug("   Has enough bag space")
	
	-- Check that the source stack contains more than 1 item
	if not (GetSlotStackSize(bagId, slotIndex) > 1) then
	    return false
	end
	
	self:Debug("   Source stack is large enough")
	
	return true
end

ZO_CreateStringId("TO_CONTEXT_MENU", "Take 1")
function TakeOne:ShowContextMenu(inventorySlot, slotActions)

    -- Check inventorySlot validity
	if not self:isValid(inventorySlot) then
	    return
	end


    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    local itemLink = GetItemLink(bagId, slotIndex)
	local itemId = GetItemLinkItemId(itemLink)
	
	self:Debug(" BagID: <<1>>;  slotIndex: <<2>>; itemId: <<3>>", bagId, slotIndex, itemId)
	
	slotActions:AddCustomSlotAction(TO_CONTEXT_MENU, function() self:DoTake(inventorySlot, itemId) end, "")
	 
end

EVENT_MANAGER:RegisterForEvent(TakeOne.name, EVENT_ADD_ON_LOADED, function(...) TakeOne:OnAddOnLoaded(...) end)
