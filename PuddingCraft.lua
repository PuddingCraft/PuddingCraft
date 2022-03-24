PuddingCraft = LibStub("AceAddon-3.0"):NewAddon("PuddingCraft", "AceComm-3.0", "AceConsole-3.0", "AceEvent-3.0", "AceSerializer-3.0", "AceTimer-3.0");
PuddingCraft.Version = "1.0.3"
PuddingCraft.PuddingCraftFrame = '';
PuddingCraft.itemTypeFilter = nil;
PuddingCraft.itemSubTypeFilter = nil;

function PuddingCraft:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("PuddingCraftDB", defaults, true)
    self.GUI = LibStub("AceGUI-3.0")
    local playerName, realm = UnitName("player")
    self.playerName = playerName
    self.guild = GetGuildInfo("player");
    self.playerGUID = UnitGUID("player");
    self.recipes = {["trade"] = {}, ["craft"] = {}};
    if (self.db.factionrealm.recipes ~= nil) then
        self.allRecipes = self.db.factionrealm.recipes;
    else 
        self.allRecipes = {["trade"] = {}, ["craft"] = {}};
    end
    self:RegisterComm("PuddingCraft")
    self:RegisterChatCommand("pc", "handleChatCommand");
    self.debug = false;    
end

function PuddingCraft:OnEnable()
    self:RegisterEvent("TRADE_SKILL_UPDATE", "onTradeSkillOpen")
    self:RegisterEvent("CRAFT_UPDATE", "onTradeSkillOpen")
    PuddingCraft.broadcastTimer = PuddingCraft:ScheduleRepeatingTimer("broadcastRecipes", 1800);

    
    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
        local itemName, itemLink = tooltip:GetItem();
        local itemID;
        if (itemLink ~= nil) then
            itemID = tonumber(itemLink:match("item:(%d+)"))        
        end
        local players = {}
        if (PuddingCraft.allRecipes ~= nil) then
            if (PuddingCraft.allRecipes["trade"] ~= nil) then
                if (PuddingCraft.allRecipes["trade"][itemID] ~= nil) then 
                    players = PuddingCraft.allRecipes["trade"][itemID];
                    tooltip:AddLine(" ");
                    tooltip:AddLine("Players that can craft this:");
                    local count = 0
                    local numPlayers = tablelength(players);
                    for PlayerName, PlayerGUID in pairs(players) do
                        if (count <= 15) then
                            local _, class = GetPlayerInfoByGUID(PlayerGUID);
                            local r, g, b = GetClassColor(class);
                            tooltip:AddLine(PlayerName, r, g, b);
                            count = count + 1;
                        end
                        
                    end
                    if (count > 15) then
                        tooltip:AddLine("+" .. (numPlayers-15) .. " more");
                    end
                    tooltip:AddLine(" ");
                end
            end
        end
    end)

    GameTooltip:HookScript("OnTooltipSetSpell", function(tooltip)
        local itemName, itemID = tooltip:GetSpell();
        local players = {}
        if (PuddingCraft.allRecipes ~= nil) then
            if (PuddingCraft.allRecipes["craft"] ~= nil) then 
                if (PuddingCraft.allRecipes["craft"][itemID] ~= nil) then 
                    players = PuddingCraft.allRecipes["craft"][itemID];
                    tooltip:AddLine(" ");
                    tooltip:AddLine("Players that can craft this:");
                    for PlayerName, PlayerGUID in pairs(players) do
                        local _, class = GetPlayerInfoByGUID(PlayerGUID);
                        local r, g, b = GetClassColor(class);
                        tooltip:AddLine(PlayerName, r, g, b);
                    end
                    tooltip:AddLine(" ");
                end
            end
        end
    end)
    
    self:SetupFrames();

    PuddingCraft:Print(PuddingCraft.Version .. " Loaded by Paluo @ Nethergarde Keep(EU). Type '/pc help' for usage information.");
end

function PuddingCraft:OnDisable()
    PuddingCraft:CancelTimer(PuddingCraft.broadcastTimer);
    PuddingCraft:broadcastRecipes();
end

function PuddingCraft:onTradeSkillOpen()
    local skillType, skillName, skillLevel = PuddingCraft:getSkillLevel();
    
    if (skillLevel > 0) then
        local recipes = PuddingCraft:scanRecipes(skillType, skillName, skillLevel);
        if (recipes ~= nil) then
            for _, itemID in pairs(recipes) do
                PuddingCraft:updateRecipe(skillType, itemID, PuddingCraft.playerName, PuddingCraft.playerGUID);
                if (PuddingCraft.recipes ~= nil) then
                    if (PuddingCraft.recipes[skillType] ~= nil) then 
                        PuddingCraft.recipes[skillType][itemID] = itemID;
                    else
                        PuddingCraft.recipes[skillType] = {[itemID] = itemID};
                    end
                end
            end
            PuddingCraft:updateDB();
        end
    end    
end

function PuddingCraft:OnCommReceived(prefix, msg)
    local _, data = PuddingCraft:Deserialize(msg);
    if (data.player ~= nill) then     
        PuddingCraft:debugMsg('Recieved recipes from ' .. data.player);
    end
    if (data.recipes ~= nil) then
        for skillType, items in pairs(data.recipes) do
            for itemID, players in pairs(items) do
                for playerName, playerGUID in pairs(players) do
                    PuddingCraft:updateRecipe(skillType, itemID, playerName, playerGUID);
                end
            end
            
            --[[for _, itemID in pairs(items) do
                PuddingCraft:debugMsg("Importing ItemID: " .. itemID .. ", From: " .. data.player);
                PuddingCraft:updateRecipe(skillType, itemID, data.player, data.guid);
            end]]--
        end
        PuddingCraft:updateDB();
    end
end

function PuddingCraft:getSkillLevel()
    local tradeSkillName, tradeSkillLevel, _ = GetTradeSkillLine();
    local craftSkillName, craftSkillLevel, _ = GetCraftDisplaySkillLine();
    local skillType, skillName, skillLevel;
    if (tradeSkillLevel > 0) then
        skillType = "trade";
        skillName = tradeSkillName;
        skillLevel = tradeSkillLevel;
    elseif (craftSkillLevel > 0) then
        skillType = "craft";
        skillName = craftSkillName;
        skillLevel = craftSkillLevel;
    end
    return skillType, skillName, skillLevel
end

function PuddingCraft:scanRecipes(skillType, skillName, skillLevel)
    local recipes = {};
    local numRecipes = 0;
    if (skillType == "trade") then
        numRecipes = GetNumTradeSkills();
        
        local name, type;        
        for i=1,numRecipes do
            name, type, _, _, _, _ = GetTradeSkillInfo(i);
            if (name and type ~= "header") then
                table.insert( recipes, tonumber(GetTradeSkillItemLink(i):match("item:(%d+)")) );           
            end
        end
    elseif (skillType == "craft") then
        numRecipes = GetNumCrafts();
        
        local name, type;        
        for i=1,numRecipes do
            name, type, _, _, _, _ = GetCraftInfo(i);
            if (name and type ~= "header") then
                table.insert( recipes, tonumber(GetCraftItemLink(i):match("enchant:(%d+)")) ); 
            end
        end
    end
    PuddingCraft:debugMsg(skillName .. ' opened, ' .. numRecipes .. ' recipes found.');
    return recipes;
end

function PuddingCraft:updateRecipe(skillType, id, playerName, playerGUID)
    if (PuddingCraft.allRecipes ~= nil) then -- recipe list exists
        PuddingCraft:debugMsg("recipe list exists");
        if (PuddingCraft.allRecipes[skillType] ~= nil) then -- list for skill type exists
            PuddingCraft:debugMsg("list for skill type exists");
            if (PuddingCraft.allRecipes[skillType][id] ~= nil) then -- current recipe already has linked players
                PuddingCraft:debugMsg("recipe already has linked players");
                if (PuddingCraft.allRecipes[skillType][id][playerName] ~= nil) then -- player is already linked to recipe
                    -- do nothing 
                    PuddingCraft:debugMsg("player ".. playerName .. " is already linked to recipe " .. id);
                else
                    -- link player to recipe
                    PuddingCraft:debugMsg("linking player ".. playerName .. " to recipe " .. id);
                    PuddingCraft.allRecipes[skillType][id][playerName] = playerGUID;
                end
            else
                -- add recipe and link player to it
                PuddingCraft:debugMsg("add recipe " .. id .." and link player " .. playerName .." ("..playerGUID..") to it");
                PuddingCraft.allRecipes[skillType][id] = { [playerName] = playerGUID }
            end 
        else
            -- add skill type, recipe, and link player to it
            PuddingCraft:debugMsg("add skill type, recipe " .. id .. ", and link player " .. playerName .. " ("..playerGUID..") to it");
            PuddingCraft.allRecipes[skillType] = {[id] = { [playerName] = playerGUID }}
        end
    else
        -- crate db, add recipe, and link player
        PuddingCraft:debugMsg("Recipe list does not exist");
        PuddingCraft.allRecipes = {[skillType] = {[id] = { [playerName] = playerGUID }}};
    end
end

function PuddingCraft:updateDB()
    PuddingCraft.db.factionrealm.recipes = PuddingCraft.allRecipes;
end

function PuddingCraft:broadcastRecipes()
    if (PuddingCraft.allRecipes ~= nil and PuddingCraft.guild ~= nil) then
        local data = {
            ["player"] = PuddingCraft.playerName,
            ["guid"] = PuddingCraft.playerGUID,
            ["recipes"] = PuddingCraft.allRecipes,
        }
        PuddingCraft:SendCommMessage("PuddingCraft", PuddingCraft:Serialize(data), "GUILD")
    end
end

function PuddingCraft:reset()
    self.db:ResetDB()
    self.allRecipes = {}
    ReloadUI();
end

function PuddingCraft:SetupFrames()
    PuddingCraft.PuddingCraftFrame = CreateFrame("Frame", "PuddingCraftFrame", UIParent, "BasicFrameTemplateWithInset");
    PuddingCraft.PuddingCraftFrame:SetPoint("CENTER");
    PuddingCraft.PuddingCraftFrame:SetSize(300,400);
    PuddingCraft.PuddingCraftFrame.title = PuddingCraft.PuddingCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    PuddingCraft.PuddingCraftFrame.title:SetPoint("CENTER", PuddingCraftFrame.TitleBg, "CENTER", 5, 0);
    PuddingCraft.PuddingCraftFrame.title:SetText("Pudding Craft");
    PuddingCraft.PuddingCraftFrame:SetMovable(true);
    PuddingCraft.PuddingCraftFrame:EnableMouse(true)
    PuddingCraft.PuddingCraftFrame:RegisterForDrag("LeftButton")
    PuddingCraft.PuddingCraftFrame:SetScript("OnDragStart", PuddingCraft.PuddingCraftFrame.StartMoving)
    PuddingCraft.PuddingCraftFrame:SetScript("OnDragStop", PuddingCraft.PuddingCraftFrame.StopMovingOrSizing)

    local editFrame = CreateFrame("EditBox", "editFrame", PuddingCraft.PuddingCraftFrame, "InputBoxTemplate");
    editFrame:SetPoint("TOPLEFT", PuddingCraft.PuddingCraftFrame, "TOPLEFT", 15, -32);
    editFrame:SetPoint("TOPRIGHT", PuddingCraft.PuddingCraftFrame, "TOPRIGHT", -130, -32);
    --editFrame:SetFrameStrata("DIALOG");
    editFrame:SetHeight(15);
    editFrame:SetScript("OnKeyDown", function(self, key)
        if (key == "ENTER") then
            PuddingCraft:search();
        elseif (key == "ESCAPE") then
            PuddingCraft.PuddingCraftFrame:Hide();
        end
    end)    
    PuddingCraft.PuddingCraftFrame.editFrame = editFrame;

    local button = CreateFrame("Button", "searchButton", PuddingCraft.PuddingCraftFrame);
    button:SetNormalTexture("Interface/Buttons/UI-Panel-Button-Up");
    button:SetHighlightTexture("Interface/Buttons/UI-Panel-Button-Highlight");
    button:SetPushedTexture("Interface/Buttons/UI-Panel-Button-Down");
    button:SetPoint("TOPLEFT", PuddingCraft.PuddingCraftFrame, "TOPLEFT", 170, -29);
    button:SetFrameStrata("DIALOG");
    button:SetWidth(200);
    button:SetHeight(30);

    local text = button:CreateFontString();
    text:SetFontObject("GameFontNormal");
    text:SetPoint("TOPLEFT", button, "TOPLEFT", 42, -5);
    text:SetText("Search");
    button:SetFontString(text);
    button:SetScript("OnClick", PuddingCraft.search);
    PuddingCraft.PuddingCraftFrame.searchButton = button;
    PuddingCraft.PuddingCraftFrame:Hide();

    local scrollframe = scrollframe or CreateFrame("ScrollFrame", "ScrollFrame", PuddingCraft.PuddingCraftFrame, "UIPanelScrollFrameTemplate");
    scrollframe:SetPoint("TOPLEFT", PuddingCraft.PuddingCraftFrame, "TOPLEFT", 0, -65);
    scrollframe:SetPoint("TOPRIGHT", PuddingCraft.PuddingCraftFrame, "TOPRIGHT", -5, -65);
    scrollframe:SetPoint("BOTTOMLEFT", PuddingCraft.PuddingCraftFrame, "BOTTOMLEFT", 0, 7);
    scrollframe:SetPoint("BOTTOMRIGHT", PuddingCraft.PuddingCraftFrame, "BOTTOMRIGHT", -5, 7);

    local scrollbarName = scrollframe:GetName()
    scrollbar = _G[scrollbarName.."ScrollBar"];
    scrollupbutton = _G[scrollbarName.."ScrollBarScrollUpButton"];
    scrolldownbutton = _G[scrollbarName.."ScrollBarScrollDownButton"];
     
    scrollupbutton:ClearAllPoints();
    scrollupbutton:SetPoint("TOPRIGHT", scrollframe, "TOPRIGHT", -2, -2);
     
    scrolldownbutton:ClearAllPoints();
    scrolldownbutton:SetPoint("BOTTOMRIGHT", scrollframe, "BOTTOMRIGHT", -2, 2);
     
    scrollbar:ClearAllPoints();
    scrollbar:SetPoint("TOP", scrollupbutton, "BOTTOM", 0, -2);
    scrollbar:SetPoint("BOTTOM", scrolldownbutton, "TOP", 0, 2);
    
    scrollchild = scrollchild or CreateFrame("Frame");
    scrollframe:SetScrollChild(scrollchild);
    scrollchild:SetSize(scrollframe:GetWidth(), ( scrollframe:GetHeight() * 2 ));

    PuddingCraft.PuddingCraftFrame.scrollframe = scrollframe
    PuddingCraft.PuddingCraftFrame.scrollchild = scrollchild
end

function PuddingCraft:search()
    local text = PuddingCraft.PuddingCraftFrame.editFrame:GetText();
    local items = {};
    if (PuddingCraft.PuddingCraftFrame.scrollchild.items ~= nil) then
        items = PuddingCraft.PuddingCraftFrame.scrollchild.items;
        for _, item in pairs(items) do
            item["frame"]:Hide()
        end
    end
    local i = 1;

    if (PuddingCraft.allRecipes ~= nil) then
        for skillType, itemIDs in pairs(PuddingCraft.allRecipes) do
            for itemID, players in pairs(itemIDs) do
                if (skillType == "trade") then 
                    itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc = GetItemInfo(itemID);
                elseif (skillType == "craft") then 
                    itemName = GetSpellInfo(itemID);
                    itemLink = GetSpellLink(itemID);
                end

                if (itemName ~= nil) then
                    if (text == nil or string.find(strlower(itemName), strlower(text))) then 
                        if ((
                            skillType == "trade" and (
                                (PuddingCraft.itemTypeFilter == nil or PuddingCraft.itemTypeFilter == itemType) and
                                (PuddingCraft.itemSubTypeFilter == nil or PuddingCraft.itemSubTypeFilter == itemSubType)
                            )
                        ) or (
                            skillType == "craft" and (
                                PuddingCraft.itemTypeFilter == nil or PuddingCraft.itemTypeFilter == "Enchant"
                            )
                        )) then
                            items[i] = {["frame"] = CreateFrame("Frame", "ItemLinkFrame"..i, PuddingCraft.PuddingCraftFrame.scrollchild), ["link"] = nil, ["skillType"] = skillType};
                            if (i == 1) then            
                                items[i]["frame"]:SetPoint("TOPLEFT", PuddingCraft.PuddingCraftFrame.scrollchild, "TOPLEFT", 10, -30);
                            else
                                items[i]["frame"]:SetPoint("TOPLEFT", items[i-1]["frame"], "BOTTOMLEFT");
                            end

                            items[i]["frame"]:SetSize(180,12);                        
                            items[i]["link"] = itemLink;

                            ItemLinkText = items[i]["frame"]:CreateFontString(nil, "OVERLAY", "GameFontNormal");
                            ItemLinkText:SetText(itemLink);
                            ItemLinkText:SetPoint("LEFT");
                            items[i]["frame"]:EnableMouse(true);
                            items[i]["players"] = players;

                            i = i + 1;
                        end
                    end
                end
            end
        end
        
        for _, item in pairs(items) do
            item["frame"]:HookScript("OnEnter", function()
                if (item["skillType"] == "trade") then
                    itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc = GetItemInfo(item["link"]);
                end
                if (item["link"]) then
                    GameTooltip:SetOwner(item["frame"], "ANCHOR_TOP");
                    GameTooltip:SetHyperlink(item["link"]);
                    GameTooltip:Show();
                end
            end);

            item["frame"]:HookScript("OnLeave", function()
                GameTooltip:Hide();
            end);
        end
        
    end
    PuddingCraft.PuddingCraftFrame.scrollchild.items = items;
end

function PuddingCraft:help()
    print("PuddingCraft - Help");
    print("This addon records the items you can craft and sends that list to guild members with the addon.");
    print("You can search for an item in the list, and mousing over any craftable item or link will show you who can make that item.");
    print("Type '/pc' to show the search frame.");
    print("Type '/pc help' to show this text.");
    print("Type '/pc send' to broadcast your database.");
    print("Type '/pc scan' to scan currently open tradeskill window (only required for enchanting at the moment).");
    print("Type '/pc reset' to wipe your database. Used when db format changes or data is corrupted.");
end

function PuddingCraft:showRecipes()
    PuddingCraft.PuddingCraftFrame:Show();
end

function PuddingCraft:debugMsg (msg)
    if (PuddingCraft.debug) then 
        PuddingCraft:Print(msg)
    end
end

function PuddingCraft:handleChatCommand(arg)
    
    if (arg == "debug") then
        if (self.debug) then 
            self.debug = false;
        else
            self.debug = true;
        end
    elseif (arg == "send") then
        self:broadcastRecipes();
    elseif (arg == "scan") then
        self:onTradeSkillOpen();
    elseif (arg == "reset") then
        self:reset();
    elseif (arg == "help") then
        self:help();
    else
        self:showRecipes();
    end
    if (self.debug) then
        self:Print(arg);
    end
end

function PuddingCraft:createDropdown(opts)
    local dropdown_name = '$parent_' .. opts['name'] .. '_dropdown'
    local menu_items = opts['items'] or {}
    local title_text = opts['title'] or ''
    local dropdown_width = 0
    local default_val = opts['defaultVal'] or ''
    local change_func = opts['changeFunc'] or function (dropdown_val) end

    local dropdown = CreateFrame("Frame", dropdown_name, opts['parent'], 'UIDropDownMenuTemplate')
    local dd_title = dropdown:CreateFontString(dropdown, 'OVERLAY', 'GameFontNormal')
    dd_title:SetPoint("TOPLEFT", 20, 10)

    for _, item in pairs(menu_items) do -- Sets the dropdown width to the largest item string width.
        dd_title:SetText(item)
        local text_width = dd_title:GetStringWidth() + 20
        if text_width > dropdown_width then
            dropdown_width = text_width
        end
    end

    UIDropDownMenu_SetWidth(dropdown, dropdown_width)
    UIDropDownMenu_SetText(dropdown, default_val)
    dd_title:SetText(title_text)

    UIDropDownMenu_Initialize(dropdown, function(self, level, _)
        local info = UIDropDownMenu_CreateInfo()
        for key, val in pairs(menu_items) do
            info.text = val;
            info.checked = false
            info.menuList= key
            info.hasArrow = false
            info.func = function(b)
                UIDropDownMenu_SetSelectedValue(dropdown, b.value, b.value)
                UIDropDownMenu_SetText(dropdown, b.value)
                b.checked = true
                change_func(dropdown, b.value)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    return dropdown
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end