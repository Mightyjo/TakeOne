TakeOne = {
    displayName = "Take One",
    shortName = "TO",
    name = "TakeOne",
    version = "1.3.0",
    logger = nil,
    variablesVersion = 2,
    Default = {
        isDebug = false,
    },
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
        },
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
        d(string.format("%s: %s", self.name, text))
    end
end

function TakeOne:Debug(text, ...)
    if self.logger == nil or self.savedVariables.isDebug == false then
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

    local logger = self.logger
    local handlers = {
        [LibDebugLogger.LOG_LEVEL_DEBUG] = function(message) logger:Debug(message) end,
        [LibDebugLogger.LOG_LEVEL_INFO] = function(message) logger:Info(message) end,
        [LibDebugLogger.LOG_LEVEL_WARNING] = function(message) logger:Warn(message) end,
        [LibDebugLogger.LOG_LEVEL_ERROR] = function(message) logger:Error(message) end,
    }

    local handler = handlers[level]
    if handler then
        if ... ~= nil then
            text = zo_strformat(text, unpack({...}))
        end
        handler(text)
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

    self.savedVariables = ZO_SavedVars:NewAccountWide(
        "TakeOneVariables",
        self.variablesVersion,
        nil,
        self.Default
    )

    self:CreateMenu()

    LibCustomMenu:RegisterContextMenu(
        function(...)
            self:ShowContextMenu(...)
        end,
        LibCustomMenu.CATEGORY_LATE
    )

    self:Info(GetString(TAKE_ONE_LOADED))
end

-- Returns the item ID represented by an inventory slot.
function TakeOne:GetItemId(bagId, slotIndex)
    if bagId == BAG_FURNITURE_VAULT then
        return GetItemId(bagId, slotIndex)
    end

    local itemLink = GetItemLink(bagId, slotIndex)
    return GetItemLinkItemId(itemLink)
end

function TakeOne:HasBackpackSpace(slotType)
    if slotType == SLOT_TYPE_GUILD_BANK_ITEM then
        return CheckInventorySpaceSilently(2)
    end

    return CheckInventorySpaceSilently(1)
end

function TakeOne:DoTake(inventorySlot, itemId, greedy)
    local slotType = ZO_InventorySlot_GetType(inventorySlot)
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)

    if not slotIndex then
        self:Warn(GetString(TAKE_ONE_SLOT_FULL))
        PlaySound("Justice_PickpocketFailed")
        return
    end

    local currentItemId = self:GetItemId(bagId, slotIndex)
    if itemId ~= currentItemId then
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
    local amountToTake = greedy and (quantity - 1) or 1

    self:Debug(GetString(TAKE_ONE_DO_TAKE_ACTION), amountToTake)

    if slotType == SLOT_TYPE_BANK_ITEM
        or slotType == SLOT_TYPE_FURNITURE_VAULT then

        CallSecureProtected(
            "RequestMoveItem",
            bagId,
            slotIndex,
            BAG_BACKPACK,
            targetSlot,
            amountToTake
        )

    elseif slotType == SLOT_TYPE_GUILD_BANK_ITEM then
        EVENT_MANAGER:RegisterForEvent(
            self.name,
            EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            self:DoSplit(itemId, quantity, greedy)
        )
        EVENT_MANAGER:AddFilterForEvent(
            self.name,
            EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID,
            BAG_BACKPACK
        )

        self:Debug(
            GetString(TAKE_ONE_DO_TAKE_SENDING),
            itemId,
            quantity,
            greedy
        )

        TransferFromGuildBank(slotIndex)
    end
end

function TakeOne:DoSplit(itemId, quantity, greedy)
    return function(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
        if bagId ~= BAG_BACKPACK then
            self:Error(GetString(TAKE_ONE_DO_SPLIT_WRONG_BAG), bagId)
            return
        end

        local currentItemId = self:GetItemId(bagId, slotIndex)
        if currentItemId ~= itemId then
            self:Debug(
                GetString(TAKE_ONE_DO_SPLIT_WRONG_ITEM),
                currentItemId,
                itemId
            )
            return
        end

        local currentQuantity = GetSlotStackSize(bagId, slotIndex)
        if currentQuantity ~= quantity then
            self:Debug(
                GetString(TAKE_ONE_DO_SPLIT_WRONG_QUANTITY),
                currentQuantity,
                quantity
            )
            return
        end

        self:Debug(
            GetString(TAKE_ONE_DO_SPLIT_RIGHT_STACK),
            itemId,
            quantity
        )

        EVENT_MANAGER:UnregisterForEvent(
            self.name,
            EVENT_INVENTORY_SINGLE_SLOT_UPDATE
        )

        local targetSlot = FindFirstEmptySlotInBag(BAG_BACKPACK)
        if not targetSlot then
            self:Error(GetString(TAKE_ONE_NO_SLOTS))
            return
        end

        EVENT_MANAGER:RegisterForEvent(
            self.name,
            EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            self:DoReturn(bagId, slotIndex, targetSlot)
        )
        EVENT_MANAGER:AddFilterForEvent(
            self.name,
            EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID,
            BAG_BACKPACK
        )

        local amountToTake = greedy and (quantity - 1) or 1

        self:Debug(
            GetString(TAKE_ONE_DO_SPLIT_SENDING),
            bagId,
            slotIndex
        )

        CallSecureProtected(
            "RequestMoveItem",
            bagId,
            slotIndex,
            BAG_BACKPACK,
            targetSlot,
            amountToTake
        )
    end
end

function TakeOne:DoReturn(bagId, slotIndex, targetSlot)
    return function(eventCode, newBagId, newSlotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
        if targetSlot ~= newSlotIndex then
            self:Debug(
                GetString(TAKE_ONE_DO_RETURN_WRONG_SLOT),
                targetSlot,
                newSlotIndex
            )
            return
        end

        EVENT_MANAGER:UnregisterForEvent(
            self.name,
            EVENT_INVENTORY_SINGLE_SLOT_UPDATE
        )

        TransferToGuildBank(bagId, slotIndex)
    end
end

function TakeOne:isValid(inventorySlot)
    local slotType = ZO_InventorySlot_GetType(inventorySlot)
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)

    -- Take One supports personal bank, guild bank, storage coffers, and the ESO+ Furnishing Vault.
    if slotType ~= SLOT_TYPE_BANK_ITEM
        and slotType ~= SLOT_TYPE_GUILD_BANK_ITEM
        and slotType ~= SLOT_TYPE_FURNITURE_VAULT then

        return false
    end

    if not slotIndex then
        return false
    end

    if slotType == SLOT_TYPE_GUILD_BANK_ITEM then
        local guildId = GetSelectedGuildBankId()

        if not guildId then
            return false
        end

        if not DoesGuildHavePrivilege(guildId, GUILD_PRIVILEGE_BANK_DEPOSIT) then
            return false
        end

        if not (
            DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_DEPOSIT)
            and DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_WITHDRAW)
        ) then
            return false
        end
    end

    if not self:HasBackpackSpace(slotType) then
        return false
    end

    -- There must be something to leave behind.
    if GetSlotStackSize(bagId, slotIndex) <= 1 then
        return false
    end

    return true
end

function TakeOne:ShowContextMenu(inventorySlot, slotActions)
    if not self:isValid(inventorySlot) then
        return
    end

    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    local itemId = self:GetItemId(bagId, slotIndex)

    self:Debug(
        GetString(TAKE_ONE_CONTEXT_MENU_INFO),
        bagId,
        slotIndex,
        itemId
    )

    AddCustomMenuItem(
        GetString(TAKE_ONE_CONTEXT_MENU),
        function()
            self:DoTake(inventorySlot, itemId, false)
        end
    )

    AddCustomMenuItem(
        GetString(TAKE_ONE_CONTEXT_MENU_GREEDY),
        function()
            self:DoTake(inventorySlot, itemId, true)
        end
    )
end

EVENT_MANAGER:RegisterForEvent(
    TakeOne.name,
    EVENT_ADD_ON_LOADED,
    function(...)
        TakeOne:OnAddOnLoaded(...)
    end
)
