PuddingCraft = LibStub("AceAddon-3.0"):NewAddon("PuddingCraft", "AceComm-3.0", "AceConsole-3.0", "AceEvent-3.0", "AceSerializer-3.0", "AceTimer-3.0");
PuddingCraft.Version = "1.0"
PuddingCraft.PuddingCraftFrame = '';

function PuddingCraft:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("PuddingCraftDB", defaults, true)
    self.GUI = LibStub("AceGUI-3.0")
    local playerName, realm = UnitName("player")
    self.playerName = playerName
    self.playerGUID = UnitGUID("player");
    self.recipes = {}
    if (self.db.factionrealm.recipes ~= nil) then
        self.allRecipes = self.db.factionrealm.recipes;
    else 
        self.allRecipes = {}
    end
    self:RegisterComm("PuddingCraft")
    self:RegisterChatCommand("pc", "handleChatCommand");
    self.debug = false;    
end

function PuddingCraft:OnEnable()
    self:RegisterEvent("TRADE_SKILL_UPDATE", "onTradeSkillOpen")
    
    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
        local itemName, itemLink = tooltip:GetItem();
        local itemID;
        if (itemLink ~= nil) then
            itemID = tonumber(itemLink:match("item:(%d+)"))        
        end
        local players = {}
        if (PuddingCraft.allRecipes ~= nil) then
            if (PuddingCraft.allRecipes[itemID] ~= nil) then 
                players = PuddingCraft.allRecipes[itemID];
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
    end)
    
    self:SetupFrames();
end

function PuddingCraft:OnDisable()
    
end

function PuddingCraft:onTradeSkillOpen()
    local tradeSkillName, tradeSkillLevel, _ = GetTradeSkillLine();
    local recipes = PuddingCraft:scanRecipes(tradeSkillName, tradeSkillLevel);
	--local i = 1; 
    for _, itemID in pairs(recipes) do
		--if (i <= 1) then
			PuddingCraft:updateRecipe(_, itemID, PuddingCraft.playerName, PuddingCraft.playerGUID);
			if (PuddingCraft.recipes ~= nil) then
				PuddingCraft.recipes[itemID] = itemID;
			end
			--i = i + 1;
		--end
    end
    PuddingCraft:updateDB();
end

function PuddingCraft:OnCommReceived(prefix, msg)
    local _, data = self:Deserialize(msg);    
    PuddingCraft:debugMsg('Recieved recipes from ' .. data.player);    
    for _, itemID in pairs(data.recipes) do
		PuddingCraft:debugMsg("Importing ItemID: " .. itemID .. ", From: " .. data.player);
        PuddingCraft:updateRecipe(_, itemID, data.player, data.guid);
    end

    self.updateDB();
end

function PuddingCraft:scanRecipes(tradeSkillName, tradeSkillLevel)    
    local recipes = {};
    if (tradeSkillLevel > 0) then
        local numRecipes = GetNumTradeSkills();
        PuddingCraft:debugMsg(tradeSkillName .. ' opened, ' .. numRecipes .. ' recipes found.');
        
        local name, type;        
        for i=1,numRecipes do
            name, type, _, _, _, _ = GetTradeSkillInfo(i);
            if (name and type ~= "header") then
                table.insert( recipes, tonumber(GetTradeSkillItemLink(i):match("item:(%d+)")) );           
            end
        end
    end
    return recipes;
end

function PuddingCraft:updateRecipe(type, id, playerName, playerGUID)
    if (PuddingCraft.allRecipes ~= nil) then -- recipe list exists
        PuddingCraft:debugMsg("Recipe list exists");
        if (PuddingCraft.allRecipes[id] ~= nil) then -- current recipe already has linked players
            PuddingCraft:debugMsg("recipe already has linked players");
            if (PuddingCraft.allRecipes[id][playerName] ~= nil) then -- player is already linked to recipe
                -- do nothing 
                PuddingCraft:debugMsg("player is already linked to recipe");
            else
                -- link player to recipe
                PuddingCraft:debugMsg("link player to recipe");
                PuddingCraft.allRecipes[id][playerName] = playerGUID;
            end
        else
            -- add recipe and link player to it
            PuddingCraft:debugMsg("add recipe and link player to it");
            PuddingCraft.allRecipes[id] = { [playerName] = playerGUID }
        end 
    else
        -- crate db, add recipe, and link player
        PuddingCraft:debugMsg("Recipe list does not exist");
        PuddingCraft.allRecipes = {
            [id] = { [playerName] = playerGUID },
        };
    end
end

function PuddingCraft:updateDB()
    PuddingCraft.db.factionrealm.recipes = PuddingCraft.allRecipes;
end

function PuddingCraft:broadcastRecipes()
    local data = {
        ["player"] = self.playerName,
        ["guid"] = self.playerGUID,
        ["recipes"] = self.recipes,
    }
    self:SendCommMessage("PuddingCraft", self:Serialize(data), "GUILD")
end

function PuddingCraft:reset()
    self.db:ResetDB()
    self.allRecipes = {}
end

function PuddingCraft:SetupFrames()

    PuddingCraft.PuddingCraftFrame = CreateFrame("Frame", "PuddingCraftFrame", UIParent, "BasicFrameTemplateWithInset");
    PuddingCraft.PuddingCraftFrame:SetPoint("CENTER");
    PuddingCraft.PuddingCraftFrame:SetSize(300,400);
    PuddingCraft.PuddingCraftFrame.title = PuddingCraft.PuddingCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    PuddingCraft.PuddingCraftFrame.title:SetPoint("CENTER", PuddingCraftFrame.TitleBg, "CENTER", 5, 0);
    PuddingCraft.PuddingCraftFrame.title:SetText("Pudding Craft");
    PuddingCraft.PuddingCraftFrame:SetMovable(true);

    local editFrame = CreateFrame("EditBox", "editFrame", PuddingCraft.PuddingCraftFrame, "InputBoxTemplate");
    editFrame:SetPoint("TOPLEFT", PuddingCraft.PuddingCraftFrame, "TOPLEFT", 15, 0);
    editFrame:SetPoint("TOPRIGHT", PuddingCraft.PuddingCraftFrame, "TOPRIGHT", -130, 0);
    editFrame:SetFrameStrata("DIALOG");
    editFrame:SetHeight(80);
    editFrame:SetScript("OnKeyDown", function(self, key)
        if (key == "ENTER") then
            PuddingCraft:search();
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
    scrollframe:SetPoint("TOPLEFT", PuddingCraft.PuddingCraftFrame, "TOPLEFT", 0, -57);
    scrollframe:SetPoint("TOPRIGHT", PuddingCraft.PuddingCraftFrame, "TOPRIGHT", -5, -57);
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
        for itemID, players in pairs(PuddingCraft.allRecipes) do

            itemName, itemLink = GetItemInfo(itemID);

            if (itemName ~= nil) then
                if (text == nil or string.find(strlower(itemName), strlower(text))) then 
                    items[i] = {["frame"] = CreateFrame("Frame", "ItemLinkFrame"..i, PuddingCraft.PuddingCraftFrame.scrollchild), ["link"] = nil};
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
        
        for _, item in pairs(items) do
            item["frame"]:HookScript("OnEnter", function()
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
        PuddingCraft.PuddingCraftFrame.scrollchild.items = items;
    end

end



function PuddingCraft:showRecipes()
    PuddingCraft.PuddingCraftFrame:Show();
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
    elseif (arg == "reset") then
        self:reset();
    else 
        self:showRecipes();
    end
    if (self.debug) then
        self:Print(arg);
    end
end

--[[function PuddingCraft:dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end]]--

function PuddingCraft:debugMsg (msg)
    if (PuddingCraft.debug) then 
        PuddingCraft:Print(msg)
    end
end