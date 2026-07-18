--[[
    Selene UI Library - Standalone Bundled Module
    Automated Build System
--]]

local __modules = {}
local __cache = {}

local function createSourceProxy(prefix)
    prefix = prefix or ""
    return setmetatable({ __path = prefix }, {
        __index = function(self, key)
            local path = (prefix ~= "" and (prefix .. "/") or "") .. key
            return setmetatable({ __path = path }, {
                __index = function(_, childKey)
                    return createSourceProxy(path)[childKey]
                end
            })
        end
    })
end

local Source = createSourceProxy("")
local script = Source

local function __require(c)
    if typeof(c) == "table" and c.__path then
        c = c.__path
    elseif typeof(c) == "Instance" then
        c = c.Name
    end
    if type(c) ~= "string" then
        return nil
    end

    if c == "Packages/React" or c == "ReplicatedStorage/Packages/React" then
        c = "React"
    elseif c == "Packages/ReactRoblox" or c == "ReplicatedStorage/Packages/ReactRoblox" then
        c = "ReactRoblox"
    end

    if __cache[c] ~= nil then
        return __cache[c]
    end
    local modFunc = __modules[c]
    if not modFunc then
        error("[Selene Library] Module not found: " .. tostring(c))
    end
    local res = modFunc()
    __cache[c] = res
    return res
end

__modules["React"] = function()
    local require = __require
    local Source = Source
    local script = Source

--[[
    Native Light React Renderer for Luau / Roblox
    Eliminates all external React/Packages dependencies.
--]]

local React = {}

React.Component = {}
React.Component.__index = React.Component

function React.Component:extend(name)
    local class = {}
    class.__index = class
    setmetatable(class, { __index = self })
    class.__className = name or "Component"
    return class
end

function React.Component.new(props)
    local self = setmetatable({
        props = props or {},
        state = {},
    }, self)
    return self
end

function React.Component:setState(partialState, callback)
    local prevState = {}
    for k, v in pairs(self.state or {}) do prevState[k] = v end
    
    if type(partialState) == "function" then
        partialState = partialState(self.state, self.props)
    end
    for k, v in pairs(partialState or {}) do
        self.state[k] = v
    end
    
    if self._rerender then
        self:_rerender(prevState)
    end
    if callback then callback() end
end

function React.createRef()
    return { current = nil }
end

React.Event = setmetatable({}, {
    __index = function(t, k)
        return "Event:" .. k
    end
})

React.Change = setmetatable({}, {
    __index = function(t, k)
        return "Change:" .. k
    end
})

function React.useState(initialValue)
    local val = initialValue
    local function setVal(newVal)
        val = newVal
    end
    return val, setVal
end

function React.useEffect(callback, deps)
    task.defer(callback)
end

function React.createElement(elementType, props, children)
    props = props or {}
    
    if type(elementType) == "string" then
        local instance = Instance.new(elementType)
        
        -- Apply props
        for k, v in pairs(props) do
            if type(k) == "string" then
                if k:sub(1, 6) == "Event:" then
                    local eventName = k:sub(7)
                    if instance[eventName] then
                        instance[eventName]:Connect(v)
                    end
                elseif k:sub(1, 7) == "Change:" then
                    local propName = k:sub(8)
                    if instance:IsA("Instance") then
                        instance:GetPropertyChangedSignal(propName):Connect(function()
                            v(instance)
                        end)
                    end
                elseif k == "ref" then
                    if type(v) == "table" then
                        v.current = instance
                    elseif type(v) == "function" then
                        v(instance)
                    end
                elseif k == "Children" or k == "Key" or k == "key" then
                    -- Skip metadata keys
                else
                    pcall(function()
                        instance[k] = v
                    end)
                end
            end
        end
        
        -- Handle children
        local function addChildren(childList)
            if not childList then return end
            if typeof(childList) == "Instance" then
                childList.Parent = instance
            elseif type(childList) == "table" then
                if childList.__isInstanceWrapper then
                    childList.__instance.Parent = instance
                elseif childList.Parent ~= nil and typeof(childList) == "Instance" then
                    childList.Parent = instance
                else
                    for key, child in pairs(childList) do
                        if typeof(child) == "Instance" then
                            if type(key) == "string" then
                                child.Name = key
                            end
                            child.Parent = instance
                        elseif type(child) == "table" and child.__nodeInstance then
                            if type(key) == "string" then
                                child.__nodeInstance.Name = key
                            end
                            child.__nodeInstance.Parent = instance
                        elseif type(child) == "table" then
                            addChildren(child)
                        end
                    end
                end
            end
        end
        
        addChildren(children)
        addChildren(props.Children)
        
        return instance
    elseif type(elementType) == "table" and elementType.__index then
        -- Class component
        local componentInstance = setmetatable({
            props = props,
            state = {},
        }, elementType)
        
        if children then
            componentInstance.props.children = children
        end
        
        local renderedInstance
        local prevProps = {}
        local prevState = {}
        
        function componentInstance:_rerender(oldState)
            local newRendered = componentInstance:render()
            if renderedInstance and renderedInstance ~= newRendered then
                if typeof(newRendered) == "Instance" and typeof(renderedInstance) == "Instance" then
                    newRendered.Parent = renderedInstance.Parent
                    renderedInstance:Destroy()
                    renderedInstance = newRendered
                end
            end
            if componentInstance.didUpdate then
                task.spawn(function()
                    componentInstance:didUpdate(prevProps, oldState or prevState)
                end)
            end
        end
        
        renderedInstance = componentInstance:render()
        componentInstance.__nodeInstance = renderedInstance
        
        if props.ref then
            if type(props.ref) == "table" then
                props.ref.current = componentInstance
            elseif type(props.ref) == "function" then
                props.ref(componentInstance)
            end
        end
        
        if componentInstance.didMount then
            task.defer(function()
                componentInstance:didMount()
            end)
        end
        
        return renderedInstance
    elseif type(elementType) == "function" then
        -- Functional component
        return elementType(props)
    end
    
    return nil
end

return React

end

__modules["ReactRoblox"] = function()
    local require = __require
    local Source = Source
    local script = Source

--[[
    Native Light ReactRoblox Root for Luau / Roblox
    Eliminates all external ReactRoblox dependencies.
--]]

local ReactRoblox = {}

function ReactRoblox.createRoot(container)
    return {
        render = function(self, element)
            container:ClearAllChildren()
            if typeof(element) == "Instance" then
                element.Parent = container
            elseif type(element) == "table" and element.__nodeInstance then
                element.__nodeInstance.Parent = container
            end
        end,
        unmount = function(self)
            container:ClearAllChildren()
        end
    }
end

return ReactRoblox

end

__modules["Theme"] = function()
    local require = __require
    local Source = Source
    local script = Source

local Theme = {
    Themes = {
        Dark = {
            Background = Color3.fromRGB(13, 15, 19),      -- Main window background
            Sidebar = Color3.fromRGB(9, 10, 13),          -- Sidebar background
            Card = Color3.fromRGB(20, 23, 29),             -- Card/Section background
            Element = Color3.fromRGB(28, 32, 40),          -- Button, Slider, Input background
            ElementHover = Color3.fromRGB(36, 41, 51),     -- Element hover state
            Text = Color3.fromRGB(255, 255, 255),          -- White text
            TextSecondary = Color3.fromRGB(156, 163, 175), -- Muted grey text
            Border = Color3.fromRGB(38, 43, 54),           -- Subtle dark border
            BorderHover = Color3.fromRGB(50, 56, 70),      -- Brighter border
        },
        Light = {
            Background = Color3.fromRGB(243, 244, 246),
            Sidebar = Color3.fromRGB(229, 231, 235),
            Card = Color3.fromRGB(255, 255, 255),
            Element = Color3.fromRGB(243, 244, 246),
            ElementHover = Color3.fromRGB(209, 213, 219),
            Text = Color3.fromRGB(17, 24, 39),
            TextSecondary = Color3.fromRGB(107, 114, 128),
            Border = Color3.fromRGB(209, 213, 219),
            BorderHover = Color3.fromRGB(156, 163, 175),
        }
    },
    
    Accents = {
        Blue = Color3.fromRGB(59, 130, 246),
        Yellow = Color3.fromRGB(234, 179, 8),
        Green = Color3.fromRGB(34, 197, 94),
        Graphite = Color3.fromRGB(107, 114, 128),
    },

    Colors = {
        -- Defaults (will be updated dynamically based on active Theme/Accent)
        Background = Color3.fromRGB(13, 15, 19),
        Sidebar = Color3.fromRGB(9, 10, 13),
        Card = Color3.fromRGB(20, 23, 29),
        Element = Color3.fromRGB(28, 32, 40),
        ElementHover = Color3.fromRGB(36, 41, 51),
        Text = Color3.fromRGB(255, 255, 255),
        TextSecondary = Color3.fromRGB(156, 163, 175),
        Accent = Color3.fromRGB(59, 130, 246),
        Success = Color3.fromRGB(46, 204, 113),
        Border = Color3.fromRGB(38, 43, 54),
        BorderHover = Color3.fromRGB(50, 56, 70),
    },
    
    Fonts = {
        Bold = Enum.Font.GothamBold,
        Medium = Enum.Font.GothamMedium,
        Regular = Enum.Font.Gotham,
    },
    
    CornerRadius = {
        Window = UDim.new(0, 10),
        Card = UDim.new(0, 8),
        Element = UDim.new(0, 6),
        Circle = UDim.new(1, 0),
    },
}

return Theme

end

__modules["Store"] = function()
    local require = __require
    local Source = Source
    local script = Source

local Store = {
    _state = {
        title = "Selene UI",
        subtitle = "v1.0.0",
        tabs = {},
        activeTab = nil,
        visible = true,
        profile = nil,
        
        theme = "Dark",
        accent = "Blue",
        notifications = {},
        searchQuery = "",
        
        titleTag = nil,
        titleTagColor = nil,
        subtitleTag = nil,
        subtitleTagColor = nil,
        searching = true,
        canExit = true,
        canMinimize = true,
        canZoom = true,
        minimized = false,
        maximized = false,
        colorPickerActive = nil,
    },
    _listeners = {},
}

local table_find = table.find or function(tbl, val)
    for i, v in ipairs(tbl) do
        if v == val then
            return i
        end
    end
    return nil
end

function Store:Subscribe(listener)
    table.insert(self._listeners, listener)
    return function()
        local index = table_find(self._listeners, listener)
        if index then
            table.remove(self._listeners, index)
        end
    end
end

function Store:Update(updater)
    updater(self._state)
    for _, listener in ipairs(self._listeners) do
        listener(self._state)
    end
end

function Store:UpdateElement(targetId, updater)
    self:Update(function(state)
        local function searchElements(elements, targetId, updater)
            for _, el in ipairs(elements) do
                if el.id == targetId then
                    updater(el)
                    return true
                end
                if el.elements and searchElements(el.elements, targetId, updater) then
                    return true
                end
                if el.leftElements and searchElements(el.leftElements, targetId, updater) then
                    return true
                end
                if el.rightElements and searchElements(el.rightElements, targetId, updater) then
                    return true
                end
            end
            return false
        end
        
        for _, s in ipairs(state.sections or {}) do
            for _, t in ipairs(s.tabs or {}) do
                if t.pageSections and searchElements(t.pageSections, targetId, updater) then
                    return
                end
            end
        end
    end)
end

function Store:SetColorPicker(pickerData)
    self:Update(function(state)
        state.colorPickerActive = pickerData
    end)
end

return Store

end

__modules["Icons"] = function()
    local require = __require
    local Source = Source
    local script = Source

-- This file contains merged icons from dawid-scripts/Fluent (Lucide) and Cascade UI.
return {
	assets = {
		["00Circle"] = "rbxassetid://83028270380365",
		["00CircleFill"] = "rbxassetid://86809068648199",
		["00Square"] = "rbxassetid://122749670129495",
		["00SquareFill"] = "rbxassetid://113994495859936",
		["01Circle"] = "rbxassetid://97226917439387",
		["01CircleFill"] = "rbxassetid://84587253978749",
		["01Square"] = "rbxassetid://107219376369036",
		["01SquareFill"] = "rbxassetid://107829808355635",
		["02Circle"] = "rbxassetid://84345480243560",
		["02CircleFill"] = "rbxassetid://138068434560383",
		["02Square"] = "rbxassetid://108430049934958",
		["02SquareFill"] = "rbxassetid://85661875663721",
		["03Circle"] = "rbxassetid://98956711188823",
		["03CircleFill"] = "rbxassetid://101131309093130",
		["03Square"] = "rbxassetid://110182185893835",
		["03SquareFill"] = "rbxassetid://82242680200461",
		["04Circle"] = "rbxassetid://132715041479836",
		["04CircleFill"] = "rbxassetid://113282380257070",
		["04Square"] = "rbxassetid://70514965693841",
		["04SquareFill"] = "rbxassetid://89262337216532",
		["05Circle"] = "rbxassetid://125294166213948",
		["05CircleFill"] = "rbxassetid://130265371531723",
		["05Square"] = "rbxassetid://107516239217699",
		["05SquareFill"] = "rbxassetid://117323864732404",
		["06Circle"] = "rbxassetid://137306965556122",
		["06CircleFill"] = "rbxassetid://94892211121096",
		["06Square"] = "rbxassetid://104889857379096",
		["06SquareFill"] = "rbxassetid://105314805711265",
		["07Circle"] = "rbxassetid://99787513377232",
		["07CircleFill"] = "rbxassetid://132058802818154",
		["07Square"] = "rbxassetid://82223513821897",
		["07SquareFill"] = "rbxassetid://137613755884312",
		["08Circle"] = "rbxassetid://88618425851192",
		["08CircleFill"] = "rbxassetid://105339976565490",
		["08Square"] = "rbxassetid://129990117272036",
		["08SquareFill"] = "rbxassetid://125650076611446",
		["09Circle"] = "rbxassetid://103471787905743",
		["09CircleFill"] = "rbxassetid://105841318829878",
		["09Square"] = "rbxassetid://110493201929378",
		["09SquareFill"] = "rbxassetid://107198536694769",
		["0Circle"] = "rbxassetid://137352523558390",
		["0CircleFill"] = "rbxassetid://92718288126091",
		["0Square"] = "rbxassetid://136892616930971",
		["0SquareFill"] = "rbxassetid://71376891799551",
		["10ArrowTriangleheadClockwise"] = "rbxassetid://128762303542944",
		["10ArrowTriangleheadCounterclockwise"] = "rbxassetid://76674527536932",
		["10Calendar"] = "rbxassetid://99971987072382",
		["10Circle"] = "rbxassetid://92515002741648",
		["10CircleFill"] = "rbxassetid://114340053449257",
		["10Lane"] = "rbxassetid://118673566178183",
		["10Square"] = "rbxassetid://70604007286548",
		["10SquareFill"] = "rbxassetid://110206837615888",
		["11Calendar"] = "rbxassetid://84425977875050",
		["11Circle"] = "rbxassetid://98647733126057",
		["11CircleFill"] = "rbxassetid://114595490819205",
		["11Lane"] = "rbxassetid://134292941036759",
		["11Square"] = "rbxassetid://95453375539358",
		["11SquareFill"] = "rbxassetid://132202039821354",
		["12Calendar"] = "rbxassetid://114493786022821",
		["12Circle"] = "rbxassetid://121672832794983",
		["12CircleFill"] = "rbxassetid://122946923969916",
		["12Lane"] = "rbxassetid://132443115464407",
		["12Square"] = "rbxassetid://135913931652877",
		["12SquareFill"] = "rbxassetid://70425571060983",
		["13Calendar"] = "rbxassetid://125476355270691",
		["13Circle"] = "rbxassetid://124979455738373",
		["13CircleFill"] = "rbxassetid://76676158822711",
		["13Square"] = "rbxassetid://92207708556496",
		["13SquareFill"] = "rbxassetid://123971106532801",
		["14Calendar"] = "rbxassetid://79389761405548",
		["14Circle"] = "rbxassetid://116170541336582",
		["14CircleFill"] = "rbxassetid://135867491119117",
		["14Square"] = "rbxassetid://136705500158279",
		["14SquareFill"] = "rbxassetid://114499637922730",
		["15ArrowTriangleheadClockwise"] = "rbxassetid://110732229815610",
		["15ArrowTriangleheadCounterclockwise"] = "rbxassetid://127299415437175",
		["15Calendar"] = "rbxassetid://81636478363595",
		["15Circle"] = "rbxassetid://78927448681525",
		["15CircleFill"] = "rbxassetid://118327895426422",
		["15Square"] = "rbxassetid://90508797482214",
		["15SquareFill"] = "rbxassetid://120440643138154",
		["16Calendar"] = "rbxassetid://126220874727895",
		["16Circle"] = "rbxassetid://126567549131052",
		["16CircleFill"] = "rbxassetid://126688524438218",
		["16Square"] = "rbxassetid://84244666904565",
		["16SquareFill"] = "rbxassetid://105088240557538",
		["17Calendar"] = "rbxassetid://77297968626397",
		["17Circle"] = "rbxassetid://96369047073930",
		["17CircleFill"] = "rbxassetid://80691999562724",
		["17Square"] = "rbxassetid://78926693972141",
		["17SquareFill"] = "rbxassetid://85270565257338",
		["18Calendar"] = "rbxassetid://125707457639914",
		["18Circle"] = "rbxassetid://103499330032468",
		["18CircleFill"] = "rbxassetid://139400390011207",
		["18Square"] = "rbxassetid://96425450360158",
		["18SquareFill"] = "rbxassetid://95747860980425",
		["19Calendar"] = "rbxassetid://132759347346313",
		["19Circle"] = "rbxassetid://136880006821425",
		["19CircleFill"] = "rbxassetid://132010253426021",
		["19Square"] = "rbxassetid://86547351573625",
		["19SquareFill"] = "rbxassetid://113507822362885",
		["1Brakesignal"] = "rbxassetid://102491003904804",
		["1Calendar"] = "rbxassetid://98185546831379",
		["1Circle"] = "rbxassetid://130621158480059",
		["1CircleFill"] = "rbxassetid://119914746762070",
		["1Lane"] = "rbxassetid://108289649639933",
		["1Magnifyingglass"] = "rbxassetid://79094731969211",
		["1Square"] = "rbxassetid://89938443056690",
		["1SquareFill"] = "rbxassetid://91936609218444",
		["20Calendar"] = "rbxassetid://128748725884252",
		["20Circle"] = "rbxassetid://74724597303762",
		["20CircleFill"] = "rbxassetid://74025988368489",
		["20Square"] = "rbxassetid://100301580149753",
		["20SquareFill"] = "rbxassetid://81847976697662",
		["21Calendar"] = "rbxassetid://92479265735150",
		["21Circle"] = "rbxassetid://107042620932339",
		["21CircleFill"] = "rbxassetid://86466285996936",
		["21Square"] = "rbxassetid://118914310058881",
		["21SquareFill"] = "rbxassetid://137245696391587",
		["22Calendar"] = "rbxassetid://76926833805322",
		["22Circle"] = "rbxassetid://112949971675201",
		["22CircleFill"] = "rbxassetid://136675480787222",
		["22Square"] = "rbxassetid://70382544382768",
		["22SquareFill"] = "rbxassetid://136349772275086",
		["23Calendar"] = "rbxassetid://72540972332711",
		["23Circle"] = "rbxassetid://122644356502405",
		["23CircleFill"] = "rbxassetid://132927065976368",
		["23Square"] = "rbxassetid://133241790954057",
		["23SquareFill"] = "rbxassetid://131940949142587",
		["24Calendar"] = "rbxassetid://108261967636040",
		["24Circle"] = "rbxassetid://82428286993981",
		["24CircleFill"] = "rbxassetid://91411670826506",
		["24Square"] = "rbxassetid://139919867683269",
		["24SquareFill"] = "rbxassetid://71799607296423",
		["25Calendar"] = "rbxassetid://100633222933029",
		["25Circle"] = "rbxassetid://100704542539329",
		["25CircleFill"] = "rbxassetid://86282617997408",
		["25Square"] = "rbxassetid://85711261321247",
		["25SquareFill"] = "rbxassetid://92036217304787",
		["26Calendar"] = "rbxassetid://88912330770844",
		["26Circle"] = "rbxassetid://115236591138732",
		["26CircleFill"] = "rbxassetid://83556043270110",
		["26Square"] = "rbxassetid://138273926712016",
		["26SquareFill"] = "rbxassetid://104321077565351",
		["27Calendar"] = "rbxassetid://73201335235154",
		["27Circle"] = "rbxassetid://121764559253612",
		["27CircleFill"] = "rbxassetid://100219016046799",
		["27Square"] = "rbxassetid://83717779381903",
		["27SquareFill"] = "rbxassetid://99650567921303",
		["28Calendar"] = "rbxassetid://105788634273895",
		["28Circle"] = "rbxassetid://109395541199407",
		["28CircleFill"] = "rbxassetid://129403579574600",
		["28Square"] = "rbxassetid://101847553369506",
		["28SquareFill"] = "rbxassetid://125178103545775",
		["29Calendar"] = "rbxassetid://128726400170465",
		["29Circle"] = "rbxassetid://87253975016702",
		["29CircleFill"] = "rbxassetid://121458185459649",
		["29Square"] = "rbxassetid://115063859229340",
		["29SquareFill"] = "rbxassetid://86136990319710",
		["2Brakesignal"] = "rbxassetid://88382719031732",
		["2Calendar"] = "rbxassetid://98050312641153",
		["2Circle"] = "rbxassetid://88686989179529",
		["2CircleFill"] = "rbxassetid://117347647638182",
		["2Lane"] = "rbxassetid://73043736430431",
		["2Square"] = "rbxassetid://81405613158962",
		["2SquareFill"] = "rbxassetid://135108412068288",
		["2h"] = "rbxassetid://120554166840614",
		["2hCircle"] = "rbxassetid://80587972141848",
		["2hCircleFill"] = "rbxassetid://121984358372075",
		["30ArrowTriangleheadClockwise"] = "rbxassetid://74624510136124",
		["30ArrowTriangleheadCounterclockwise"] = "rbxassetid://135632602776767",
		["30Calendar"] = "rbxassetid://77714024284758",
		["30Circle"] = "rbxassetid://125851565099112",
		["30CircleFill"] = "rbxassetid://134873563219388",
		["30Square"] = "rbxassetid://98178040903351",
		["30SquareFill"] = "rbxassetid://124000446507321",
		["31Calendar"] = "rbxassetid://103712950051496",
		["31Circle"] = "rbxassetid://82832572967769",
		["31CircleFill"] = "rbxassetid://84776901062406",
		["31Square"] = "rbxassetid://100093966297675",
		["31SquareFill"] = "rbxassetid://109439143484113",
		["32Circle"] = "rbxassetid://128828563808013",
		["32CircleFill"] = "rbxassetid://106794836279809",
		["32Square"] = "rbxassetid://100529952897522",
		["32SquareFill"] = "rbxassetid://135053972405086",
		["33Circle"] = "rbxassetid://76834446462070",
		["33CircleFill"] = "rbxassetid://133471374143015",
		["33Square"] = "rbxassetid://132109947433846",
		["33SquareFill"] = "rbxassetid://92211719099524",
		["34Circle"] = "rbxassetid://78797665476071",
		["34CircleFill"] = "rbxassetid://87668137780853",
		["34Square"] = "rbxassetid://81598346353759",
		["34SquareFill"] = "rbxassetid://111975400463928",
		["35Circle"] = "rbxassetid://72637078655736",
		["35CircleFill"] = "rbxassetid://76736961743352",
		["35Square"] = "rbxassetid://119727141136934",
		["35SquareFill"] = "rbxassetid://117373278288844",
		["36Circle"] = "rbxassetid://98319312866253",
		["36CircleFill"] = "rbxassetid://77316378982918",
		["36Square"] = "rbxassetid://101616504680112",
		["36SquareFill"] = "rbxassetid://96022911959763",
		["37Circle"] = "rbxassetid://93687894376513",
		["37CircleFill"] = "rbxassetid://86485501852806",
		["37Square"] = "rbxassetid://139267911387901",
		["37SquareFill"] = "rbxassetid://91193382294091",
		["38Circle"] = "rbxassetid://121521469341757",
		["38CircleFill"] = "rbxassetid://105792148160711",
		["38Square"] = "rbxassetid://106051044850392",
		["38SquareFill"] = "rbxassetid://138218593875239",
		["39Circle"] = "rbxassetid://125288441586843",
		["39CircleFill"] = "rbxassetid://115892557058939",
		["39Square"] = "rbxassetid://112598329033121",
		["39SquareFill"] = "rbxassetid://98638503271042",
		["3Calendar"] = "rbxassetid://90795649820662",
		["3Circle"] = "rbxassetid://85824504644997",
		["3CircleFill"] = "rbxassetid://74910224380095",
		["3Lane"] = "rbxassetid://75686915457526",
		["3Square"] = "rbxassetid://120223972887350",
		["3SquareFill"] = "rbxassetid://84686638879122",
		["40Circle"] = "rbxassetid://83180478546770",
		["40CircleFill"] = "rbxassetid://132728837830874",
		["40Square"] = "rbxassetid://112224567454433",
		["40SquareFill"] = "rbxassetid://101941487357695",
		["41Circle"] = "rbxassetid://75225134548534",
		["41CircleFill"] = "rbxassetid://136094650593344",
		["41Square"] = "rbxassetid://125817109698445",
		["41SquareFill"] = "rbxassetid://138876358254873",
		["42Circle"] = "rbxassetid://127374826103215",
		["42CircleFill"] = "rbxassetid://122701075418215",
		["42Square"] = "rbxassetid://138197946562353",
		["42SquareFill"] = "rbxassetid://107430077421870",
		["43Circle"] = "rbxassetid://104838885962058",
		["43CircleFill"] = "rbxassetid://133602186789762",
		["43Square"] = "rbxassetid://108869662941519",
		["43SquareFill"] = "rbxassetid://101067151905278",
		["44Circle"] = "rbxassetid://128426936704844",
		["44CircleFill"] = "rbxassetid://137168247083835",
		["44Square"] = "rbxassetid://75545715410292",
		["44SquareFill"] = "rbxassetid://111628503136844",
		["45ArrowTriangleheadClockwise"] = "rbxassetid://120134525176078",
		["45ArrowTriangleheadCounterclockwise"] = "rbxassetid://123087333385500",
		["45Circle"] = "rbxassetid://102436156063197",
		["45CircleFill"] = "rbxassetid://132306924075130",
		["45Square"] = "rbxassetid://125303441223733",
		["45SquareFill"] = "rbxassetid://80893347771788",
		["46Circle"] = "rbxassetid://118709156698649",
		["46CircleFill"] = "rbxassetid://88412402128165",
		["46Square"] = "rbxassetid://101875634976749",
		["46SquareFill"] = "rbxassetid://123057980319615",
		["47Circle"] = "rbxassetid://134558301013886",
		["47CircleFill"] = "rbxassetid://137987636103436",
		["47Square"] = "rbxassetid://99547664530529",
		["47SquareFill"] = "rbxassetid://82416495107377",
		["48Circle"] = "rbxassetid://116659923987327",
		["48CircleFill"] = "rbxassetid://127585613163244",
		["48Square"] = "rbxassetid://88269026511583",
		["48SquareFill"] = "rbxassetid://128550656233484",
		["49Circle"] = "rbxassetid://116042725943528",
		["49CircleFill"] = "rbxassetid://70466830951089",
		["49Square"] = "rbxassetid://108294144287133",
		["49SquareFill"] = "rbxassetid://136824579664757",
		["4AltCircle"] = "rbxassetid://96065443995675",
		["4AltCircleFill"] = "rbxassetid://114108784117364",
		["4AltSquare"] = "rbxassetid://92007544707653",
		["4AltSquareFill"] = "rbxassetid://76782617943156",
		["4Calendar"] = "rbxassetid://117683067057146",
		["4Circle"] = "rbxassetid://85410335884890",
		["4CircleFill"] = "rbxassetid://117232689412009",
		["4Lane"] = "rbxassetid://90837743623016",
		["4Square"] = "rbxassetid://93614529304671",
		["4SquareFill"] = "rbxassetid://100548465120334",
		["4a"] = "rbxassetid://88536395160758",
		["4aCircle"] = "rbxassetid://121454839355516",
		["4aCircleFill"] = "rbxassetid://107149222480560",
		["4h"] = "rbxassetid://90250390247173",
		["4hCircle"] = "rbxassetid://128648031725106",
		["4hCircleFill"] = "rbxassetid://107728946853252",
		["4kTv"] = "rbxassetid://123674016506451",
		["4kTvFill"] = "rbxassetid://75999084684547",
		["4l"] = "rbxassetid://106811124514270",
		["4lCircle"] = "rbxassetid://135697353497465",
		["4lCircleFill"] = "rbxassetid://80779362494066",
		["50Circle"] = "rbxassetid://135049337228431",
		["50CircleFill"] = "rbxassetid://125135742443046",
		["50Square"] = "rbxassetid://92307459965921",
		["50SquareFill"] = "rbxassetid://129462028494317",
		["5ArrowTriangleheadClockwise"] = "rbxassetid://107383111794341",
		["5ArrowTriangleheadCounterclockwise"] = "rbxassetid://135478288864818",
		["5Calendar"] = "rbxassetid://139653164527127",
		["5Circle"] = "rbxassetid://138643256382369",
		["5CircleFill"] = "rbxassetid://81772533269342",
		["5Lane"] = "rbxassetid://110377621267035",
		["5Square"] = "rbxassetid://91863717310443",
		["5SquareFill"] = "rbxassetid://101252363013967",
		["60ArrowTriangleheadClockwise"] = "rbxassetid://99108772093793",
		["60ArrowTriangleheadCounterclockwise"] = "rbxassetid://139258134359335",
		["6AltCircle"] = "rbxassetid://120350071573739",
		["6AltCircleFill"] = "rbxassetid://86316701823078",
		["6AltSquare"] = "rbxassetid://137257337817731",
		["6AltSquareFill"] = "rbxassetid://80160043116436",
		["6Calendar"] = "rbxassetid://90102440243055",
		["6Circle"] = "rbxassetid://72149384954065",
		["6CircleFill"] = "rbxassetid://78297067061715",
		["6Lane"] = "rbxassetid://100354087243931",
		["6Square"] = "rbxassetid://120439558590340",
		["6SquareFill"] = "rbxassetid://72841586020208",
		["75ArrowTriangleheadClockwise"] = "rbxassetid://89560078813691",
		["75ArrowTriangleheadCounterclockwise"] = "rbxassetid://72011197335579",
		["7Calendar"] = "rbxassetid://86716901913977",
		["7Circle"] = "rbxassetid://134362216731609",
		["7CircleFill"] = "rbxassetid://128766124434672",
		["7Lane"] = "rbxassetid://87939210980451",
		["7Square"] = "rbxassetid://83019303763050",
		["7SquareFill"] = "rbxassetid://73394265174480",
		["8Calendar"] = "rbxassetid://123022135128239",
		["8Circle"] = "rbxassetid://121463881556470",
		["8CircleFill"] = "rbxassetid://98677569612860",
		["8Lane"] = "rbxassetid://73530448957022",
		["8Square"] = "rbxassetid://94534023907446",
		["8SquareFill"] = "rbxassetid://85132457001862",
		["90ArrowTriangleheadClockwise"] = "rbxassetid://75428859613511",
		["90ArrowTriangleheadCounterclockwise"] = "rbxassetid://100354802037825",
		["9AltCircle"] = "rbxassetid://116943330734703",
		["9AltCircleFill"] = "rbxassetid://74872216618128",
		["9AltSquare"] = "rbxassetid://93297089978709",
		["9AltSquareFill"] = "rbxassetid://118501519632418",
		["9Calendar"] = "rbxassetid://134402469311043",
		["9Circle"] = "rbxassetid://125766582985411",
		["9CircleFill"] = "rbxassetid://140040901574476",
		["9Lane"] = "rbxassetid://114357239781363",
		["9Square"] = "rbxassetid://99344731424187",
		["9SquareFill"] = "rbxassetid://82741160180392",
		["aCircle"] = "rbxassetid://91422740186540",
		["aCircleFill"] = "rbxassetid://80176355279906",
		["aSquare"] = "rbxassetid://110661926393175",
		["aSquareFill"] = "rbxassetid://118925074578922",
		["abc"] = "rbxassetid://100440409146443",
		["abs"] = "rbxassetid://104303148312310",
		["absBrakesignal"] = "rbxassetid://108288270804521",
		["absBrakesignalSlash"] = "rbxassetid://139900347181805",
		["absCircle"] = "rbxassetid://127912426662073",
		["absCircleFill"] = "rbxassetid://90389741944345",
		["ac"] = "rbxassetid://70584542126579",
		["acSlash"] = "rbxassetid://131379895015246",
		["accessibility"] = "rbxassetid://117778752008722",
		["accessibilityBadgeArrowUpRight"] = "rbxassetid://88644725338334",
		["accessibilityFill"] = "rbxassetid://99814938584597",
		["airCarSide"] = "rbxassetid://98549379001911",
		["airCarSideFill"] = "rbxassetid://74763317863435",
		["airConditionerHorizontal"] = "rbxassetid://110142871235385",
		["airConditionerHorizontalFill"] = "rbxassetid://103206558750136",
		["airConditionerVertical"] = "rbxassetid://140704008468110",
		["airConditionerVerticalFill"] = "rbxassetid://127386997506238",
		["airConvertibleSide"] = "rbxassetid://94382667709805",
		["airConvertibleSideFill"] = "rbxassetid://82469124247932",
		["airPickupSide"] = "rbxassetid://118486435215683",
		["airPickupSideFill"] = "rbxassetid://117535325295275",
		["airPurifier"] = "rbxassetid://121219934750735",
		["airPurifierFill"] = "rbxassetid://121283023382392",
		["airSuvSide"] = "rbxassetid://85264461833523",
		["airSuvSideFill"] = "rbxassetid://97290218602252",
		["airplane"] = "rbxassetid://133302594398057",
		["airplaneArrival"] = "rbxassetid://83294282884497",
		["airplaneCircle"] = "rbxassetid://80486171410882",
		["airplaneCircleFill"] = "rbxassetid://128766972660071",
		["airplaneCloud"] = "rbxassetid://106395273712591",
		["airplaneDeparture"] = "rbxassetid://110438799431401",
		["airplaneLanded"] = "rbxassetid://73211840820224",
		["airplanePathDotted"] = "rbxassetid://77257428977392",
		["airplaneTicket"] = "rbxassetid://131221608879931",
		["airplaneTicketFill"] = "rbxassetid://86885394248735",
		["airplaneUpForward"] = "rbxassetid://107258551084271",
		["airplaneUpForwardApp"] = "rbxassetid://79498952458569",
		["airplaneUpForwardAppFill"] = "rbxassetid://107908472496037",
		["airplaneUpRight"] = "rbxassetid://106459716120779",
		["airplaneUpRightApp"] = "rbxassetid://110247582997305",
		["airplaneUpRightAppFill"] = "rbxassetid://101889444884144",
		["airplaneseat"] = "rbxassetid://127474636630226",
		["airplayAudio"] = "rbxassetid://97872416468292",
		["airplayAudioBadgeExclamationmark"] = "rbxassetid://82691022378697",
		["airplayAudioCircle"] = "rbxassetid://79355534338385",
		["airplayAudioCircleFill"] = "rbxassetid://99882830125971",
		["airplayVideo"] = "rbxassetid://116428826763896",
		["airplayVideoBadgeExclamationmark"] = "rbxassetid://109306301769770",
		["airplayVideoCircle"] = "rbxassetid://124272728652470",
		["airplayVideoCircleFill"] = "rbxassetid://85432097318270",
		["airplayaudio"] = "rbxassetid://132916942955864",
		["airplayaudioBadgeExclamationmark"] = "rbxassetid://136447514823399",
		["airplayaudioCircle"] = "rbxassetid://88830131647623",
		["airplayvideo"] = "rbxassetid://84461284428154",
		["airplayvideoBadgeExclamationmark"] = "rbxassetid://118815409444339",
		["airplayvideoCircle"] = "rbxassetid://76641158810884",
		["airpodGen3Left"] = "rbxassetid://82259989716387",
		["airpodGen3Right"] = "rbxassetid://137315291748188",
		["airpodLeft"] = "rbxassetid://111640685320561",
		["airpodRight"] = "rbxassetid://92417752017903",
		["airpodproLeft"] = "rbxassetid://95793086337265",
		["airpodproRight"] = "rbxassetid://74684142613428",
		["airpods"] = "rbxassetid://102934461761467",
		["airpodsChargingcase"] = "rbxassetid://137188300011249",
		["airpodsChargingcaseFill"] = "rbxassetid://121114519994300",
		["airpodsChargingcaseWireless"] = "rbxassetid://82987264570808",
		["airpodsChargingcaseWirelessFill"] = "rbxassetid://115642815762700",
		["airpodsGen3"] = "rbxassetid://77127013352192",
		["airpodsGen3ChargingcaseWireless"] = "rbxassetid://103252568691488",
		["airpodsGen3ChargingcaseWirelessFill"] = "rbxassetid://138720486088620",
		["airpodsGen4"] = "rbxassetid://98813390596396",
		["airpodsGen4ChargingcaseWireless"] = "rbxassetid://81680510405013",
		["airpodsGen4ChargingcaseWirelessFill"] = "rbxassetid://103031303446000",
		["airpodsGen4Left"] = "rbxassetid://80342628187549",
		["airpodsGen4Right"] = "rbxassetid://116899672566620",
		["airpodsMax"] = "rbxassetid://129315211901723",
		["airpodsPro"] = "rbxassetid://115908103846782",
		["airpodsProChargingcaseWireless"] = "rbxassetid://100805444479847",
		["airpodsProChargingcaseWirelessFill"] = "rbxassetid://136683531844341",
		["airpodsProChargingcaseWirelessRadiowavesLeftAndRight"] = "rbxassetid://114165652099787",
		["airpodsProChargingcaseWirelessRadiowavesLeftAndRightFill"] = "rbxassetid://101029375177334",
		["airpodsProLeft"] = "rbxassetid://76398589107645",
		["airpodsProRight"] = "rbxassetid://110293485717436",
		["airpodsmax"] = "rbxassetid://102938893282204",
		["airpodspro"] = "rbxassetid://116114855183538",
		["airpodsproChargingcaseWireless"] = "rbxassetid://111093760650540",
		["airpodsproChargingcaseWirelessRadiowavesLeftAndRight"] = "rbxassetid://137171665646568",
		["airportExpress"] = "rbxassetid://84914509690369",
		["airportExtreme"] = "rbxassetid://91752831773330",
		["airportExtremeTower"] = "rbxassetid://84855334762457",
		["airtag"] = "rbxassetid://133510297942223",
		["airtagFill"] = "rbxassetid://93526399862084",
		["airtagRadiowavesForward"] = "rbxassetid://70835353797393",
		["airtagRadiowavesForwardFill"] = "rbxassetid://86335759121702",
		["alarm"] = "rbxassetid://94592263823729",
		["alarmFill"] = "rbxassetid://110854125435299",
		["alarmWavesLeftAndRight"] = "rbxassetid://102548399209045",
		["alarmWavesLeftAndRightFill"] = "rbxassetid://134148018537010",
		["alignHorizontalCenter"] = "rbxassetid://105387534506369",
		["alignHorizontalCenterFill"] = "rbxassetid://80228868536795",
		["alignHorizontalLeft"] = "rbxassetid://121417857557559",
		["alignHorizontalLeftFill"] = "rbxassetid://100445284088857",
		["alignHorizontalRight"] = "rbxassetid://78727045612818",
		["alignHorizontalRightFill"] = "rbxassetid://117183604846016",
		["alignVerticalBottom"] = "rbxassetid://126811262141729",
		["alignVerticalBottomFill"] = "rbxassetid://82585565029168",
		["alignVerticalCenter"] = "rbxassetid://87497476785272",
		["alignVerticalCenterFill"] = "rbxassetid://117303443763648",
		["alignVerticalTop"] = "rbxassetid://131829541174867",
		["alignVerticalTopFill"] = "rbxassetid://101695426589183",
		["allergens"] = "rbxassetid://121178963871633",
		["allergensFill"] = "rbxassetid://120835453624168",
		["alt"] = "rbxassetid://109200502181897",
		["alternatingcurrent"] = "rbxassetid://139782924101096",
		["americanFootball"] = "rbxassetid://131900707633129",
		["americanFootballCircle"] = "rbxassetid://126285687669632",
		["americanFootballCircleFill"] = "rbxassetid://120792391598468",
		["americanFootballFill"] = "rbxassetid://79772090879526",
		["americanFootballProfessional"] = "rbxassetid://79730291560074",
		["americanFootballProfessionalCircle"] = "rbxassetid://81165175257890",
		["americanFootballProfessionalCircleFill"] = "rbxassetid://85819536267258",
		["americanFootballProfessionalFill"] = "rbxassetid://132612978101644",
		["amplifier"] = "rbxassetid://99850964394213",
		["angle"] = "rbxassetid://97688144611384",
		["ant"] = "rbxassetid://108437719613458",
		["antCircle"] = "rbxassetid://73241676267354",
		["antCircleFill"] = "rbxassetid://90861066249394",
		["antFill"] = "rbxassetid://96049362790915",
		["antennaRadiowavesLeftAndRight"] = "rbxassetid://105783651610996",
		["antennaRadiowavesLeftAndRightCircle"] = "rbxassetid://106918794715121",
		["antennaRadiowavesLeftAndRightCircleFill"] = "rbxassetid://95673268616759",
		["antennaRadiowavesLeftAndRightSlash"] = "rbxassetid://83746876033500",
		["antennaRadiowavesLeftAndRightSlashCircle"] = "rbxassetid://72562971579727",
		["antennaRadiowavesLeftAndRightSlashCircleFill"] = "rbxassetid://80891332949617",
		["app"] = "rbxassetid://94635193120828",
		["appBackgroundDotted"] = "rbxassetid://109494182446738",
		["appBadge"] = "rbxassetid://139613945369115",
		["appBadgeCheckmark"] = "rbxassetid://81426112675395",
		["appBadgeCheckmarkFill"] = "rbxassetid://93503980447430",
		["appBadgeClock"] = "rbxassetid://134458400266753",
		["appBadgeClockFill"] = "rbxassetid://91313378758113",
		["appBadgeFill"] = "rbxassetid://88296846458468",
		["appConnectedToAppBelowFill"] = "rbxassetid://100342957440925",
		["appDashed"] = "rbxassetid://122696783855791",
		["appFill"] = "rbxassetid://134138664054034",
		["appGift"] = "rbxassetid://88383425466655",
		["appGiftFill"] = "rbxassetid://88482932848630",
		["appGrid"] = "rbxassetid://112293112122644",
		["appShadow"] = "rbxassetid://74201552367475",
		["appSpecular"] = "rbxassetid://88620890438453",
		["appTranslucent"] = "rbxassetid://93640553211023",
		["appclip"] = "rbxassetid://76150191896193",
		["appendPage"] = "rbxassetid://132003569675874",
		["appendPageFill"] = "rbxassetid://114109887686405",
		["appleBooksPages"] = "rbxassetid://83129377869855",
		["appleBooksPagesFill"] = "rbxassetid://79375977225236",
		["appleClassicalPages"] = "rbxassetid://109032335324915",
		["appleClassicalPagesFill"] = "rbxassetid://73169137754796",
		["appleHapticsAndExclamationmarkTriangle"] = "rbxassetid://84679413093806",
		["appleHapticsAndMusicNote"] = "rbxassetid://94992791728394",
		["appleHapticsAndMusicNoteSlash"] = "rbxassetid://120030098404409",
		["appleHomekit"] = "rbxassetid://138475901062724",
		["appleImagePlayground"] = "rbxassetid://109144440237311",
		["appleImagePlaygroundFill"] = "rbxassetid://95169627623891",
		["appleIntelligence"] = "rbxassetid://92927940894079",
		["appleIntelligenceBadgeXmark"] = "rbxassetid://136847756879125",
		["appleLogo"] = "rbxassetid://74231414416316",
		["appleMeditate"] = "rbxassetid://110884202603539",
		["appleMeditateCircle"] = "rbxassetid://96265715307080",
		["appleMeditateCircleFill"] = "rbxassetid://112011124705717",
		["appleMeditateSquareStack"] = "rbxassetid://94877406532991",
		["appleMeditateSquareStackFill"] = "rbxassetid://89004763882356",
		["applePodcastsPages"] = "rbxassetid://81110736056917",
		["applePodcastsPagesFill"] = "rbxassetid://133340247658961",
		["appleTerminal"] = "rbxassetid://88837948823350",
		["appleTerminalCircle"] = "rbxassetid://99041514023806",
		["appleTerminalCircleFill"] = "rbxassetid://100608272114701",
		["appleTerminalFill"] = "rbxassetid://83023410889826",
		["appleTerminalOnRectangle"] = "rbxassetid://82511073936391",
		["appleTerminalOnRectangleFill"] = "rbxassetid://137027325971487",
		["appleWritingTools"] = "rbxassetid://74586880049933",
		["applepencil"] = "rbxassetid://90464036055920",
		["applepencilAdapterUsbC"] = "rbxassetid://116737446576584",
		["applepencilAdapterUsbCFill"] = "rbxassetid://139496379804400",
		["applepencilAndScribble"] = "rbxassetid://106121855601154",
		["applepencilDoubletap"] = "rbxassetid://135219023747373",
		["applepencilGen1"] = "rbxassetid://110959209071798",
		["applepencilGen2"] = "rbxassetid://136157715411470",
		["applepencilHover"] = "rbxassetid://132499964823193",
		["applepencilSqueeze"] = "rbxassetid://130017747173569",
		["applepencilTip"] = "rbxassetid://91593400796177",
		["applescript"] = "rbxassetid://123810491451954",
		["applescriptFill"] = "rbxassetid://127519934422013",
		["appletv"] = "rbxassetid://102962906677124",
		["appletvBadgeCheckmark"] = "rbxassetid://101652457992538",
		["appletvBadgeCheckmarkFill"] = "rbxassetid://78422425043458",
		["appletvBadgeExclamationmark"] = "rbxassetid://81489066245182",
		["appletvBadgeExclamationmarkFill"] = "rbxassetid://114636492149768",
		["appletvFill"] = "rbxassetid://135903140150465",
		["appletvremoteGen1"] = "rbxassetid://135270967631693",
		["appletvremoteGen1Fill"] = "rbxassetid://81889369734284",
		["appletvremoteGen2"] = "rbxassetid://113895435393863",
		["appletvremoteGen2Fill"] = "rbxassetid://70483371792990",
		["appletvremoteGen3"] = "rbxassetid://105163273755884",
		["appletvremoteGen3Fill"] = "rbxassetid://115418422308741",
		["appletvremoteGen4"] = "rbxassetid://100567117806558",
		["appletvremoteGen4Fill"] = "rbxassetid://113022815763894",
		["applewatch"] = "rbxassetid://93138144347379",
		["applewatchAndArrowForward"] = "rbxassetid://110039352060422",
		["applewatchBadgeCheckmark"] = "rbxassetid://92778985550706",
		["applewatchBadgeExclamationmark"] = "rbxassetid://129599825985183",
		["applewatchCaseSizes"] = "rbxassetid://109653548205740",
		["applewatchRadiowavesLeftAndRight"] = "rbxassetid://102293766705017",
		["applewatchSideRight"] = "rbxassetid://73482822688773",
		["applewatchSlash"] = "rbxassetid://79088068041897",
		["applewatchWatchface"] = "rbxassetid://83969866132522",
		["appsIpad"] = "rbxassetid://133433158213093",
		["appsIpadBadgeCheckmark"] = "rbxassetid://117680941737775",
		["appsIpadBadgePlus"] = "rbxassetid://88752826248322",
		["appsIpadLandscape"] = "rbxassetid://86493684817099",
		["appsIpadOnRectanglePortraitDashed"] = "rbxassetid://114536357023471",
		["appsIphone"] = "rbxassetid://129167692551812",
		["appsIphoneBadgeCheckmark"] = "rbxassetid://103980567296855",
		["appsIphoneBadgePlus"] = "rbxassetid://71713357676686",
		["appsIphoneLandscape"] = "rbxassetid://97618850718449",
		["appwindowSwipeRectangle"] = "rbxassetid://86269047484283",
		["aqiHigh"] = "rbxassetid://124283236192520",
		["aqiLow"] = "rbxassetid://125965149266356",
		["aqiMedium"] = "rbxassetid://121844299793985",
		["aqiMediumGaugeOpen"] = "rbxassetid://137218283152183",
		["arcadeStick"] = "rbxassetid://136881673658280",
		["arcadeStickAndArrowDown"] = "rbxassetid://106511231849553",
		["arcadeStickAndArrowLeft"] = "rbxassetid://126374741762139",
		["arcadeStickAndArrowLeftAndArrowRight"] = "rbxassetid://113538637882184",
		["arcadeStickAndArrowLeftAndArrowRightOutward"] = "rbxassetid://138813689219871",
		["arcadeStickAndArrowRight"] = "rbxassetid://118159594368933",
		["arcadeStickAndArrowUp"] = "rbxassetid://86240487616233",
		["arcadeStickAndArrowUpAndArrowDown"] = "rbxassetid://112293103027077",
		["arcadeStickConsole"] = "rbxassetid://100669752883004",
		["arcadeStickConsoleFill"] = "rbxassetid://122547243212983",
		["archivebox"] = "rbxassetid://121345229961059",
		["archiveboxCircle"] = "rbxassetid://98842142630967",
		["archiveboxCircleFill"] = "rbxassetid://118356120505684",
		["archiveboxFill"] = "rbxassetid://93301170884322",
		["arkit"] = "rbxassetid://137506195249781",
		["arkitBadgeXmark"] = "rbxassetid://112860435555999",
		["arrow2Squarepath"] = "rbxassetid://115537208650468",
		["arrow3Trianglepath"] = "rbxassetid://81605064455205",
		["arrowBackward"] = "rbxassetid://88649419574770",
		["arrowBackwardCircle"] = "rbxassetid://136956454087601",
		["arrowBackwardCircleDotted"] = "rbxassetid://102449299281450",
		["arrowBackwardCircleFill"] = "rbxassetid://113290948178109",
		["arrowBackwardSquare"] = "rbxassetid://98664430133231",
		["arrowBackwardSquareFill"] = "rbxassetid://118804167090498",
		["arrowBackwardToLine"] = "rbxassetid://110504526302150",
		["arrowBackwardToLineCircle"] = "rbxassetid://78052803011890",
		["arrowBackwardToLineCircleFill"] = "rbxassetid://107890859844246",
		["arrowBackwardToLineCompact"] = "rbxassetid://138459990868775",
		["arrowBackwardToLineSquare"] = "rbxassetid://78531808011930",
		["arrowBackwardToLineSquareFill"] = "rbxassetid://75065759600319",
		["arrowCirclepath"] = "rbxassetid://82375876675933",
		["arrowClockwise"] = "rbxassetid://135150629431078",
		["arrowClockwiseCircle"] = "rbxassetid://74157022752988",
		["arrowClockwiseCircleFill"] = "rbxassetid://116449962863671",
		["arrowClockwiseHeart"] = "rbxassetid://89932974116238",
		["arrowClockwiseIcloud"] = "rbxassetid://119564317606359",
		["arrowClockwiseSquare"] = "rbxassetid://119196146574286",
		["arrowClockwiseSquareFill"] = "rbxassetid://134619956093951",
		["arrowCounterclockwise"] = "rbxassetid://93269551188316",
		["arrowCounterclockwiseCircle"] = "rbxassetid://100324999603105",
		["arrowCounterclockwiseCircleFill"] = "rbxassetid://89831785654730",
		["arrowCounterclockwiseIcloud"] = "rbxassetid://76284977441664",
		["arrowCounterclockwiseSquare"] = "rbxassetid://120748383469686",
		["arrowCounterclockwiseSquareFill"] = "rbxassetid://100952327039099",
		["arrowDown"] = "rbxassetid://104294868419018",
		["arrowDownAndLineHorizontalAndArrowUp"] = "rbxassetid://87886576322262",
		["arrowDownApp"] = "rbxassetid://126624351763492",
		["arrowDownAppDashed"] = "rbxassetid://120863880942317",
		["arrowDownAppDashedTrianglebadgeExclamationmark"] = "rbxassetid://102776085772699",
		["arrowDownAppFill"] = "rbxassetid://117366485860412",
		["arrowDownApplewatch"] = "rbxassetid://90433452282294",
		["arrowDownBackward"] = "rbxassetid://118854524118128",
		["arrowDownBackwardAndArrowUpForward"] = "rbxassetid://129996365679960",
		["arrowDownBackwardAndArrowUpForwardCircle"] = "rbxassetid://106065835022812",
		["arrowDownBackwardAndArrowUpForwardCircleFill"] = "rbxassetid://119097194369411",
		["arrowDownBackwardAndArrowUpForwardRectangle"] = "rbxassetid://86325793969716",
		["arrowDownBackwardAndArrowUpForwardRectangleFill"] = "rbxassetid://106014356084217",
		["arrowDownBackwardAndArrowUpForwardSquare"] = "rbxassetid://95759279304249",
		["arrowDownBackwardAndArrowUpForwardSquareFill"] = "rbxassetid://101483128565522",
		["arrowDownBackwardCircle"] = "rbxassetid://101148976029987",
		["arrowDownBackwardCircleDotted"] = "rbxassetid://101994800462988",
		["arrowDownBackwardCircleFill"] = "rbxassetid://104416395931960",
		["arrowDownBackwardSquare"] = "rbxassetid://120139080263601",
		["arrowDownBackwardSquareFill"] = "rbxassetid://96397200712935",
		["arrowDownBackwardToptrailingRectangle"] = "rbxassetid://128098505832607",
		["arrowDownBackwardToptrailingRectangleFill"] = "rbxassetid://136959509151256",
		["arrowDownCircle"] = "rbxassetid://135587411885714",
		["arrowDownCircleBadgePause"] = "rbxassetid://124364310110740",
		["arrowDownCircleBadgePauseFill"] = "rbxassetid://126034849419398",
		["arrowDownCircleBadgeXmark"] = "rbxassetid://132627732829179",
		["arrowDownCircleBadgeXmarkFill"] = "rbxassetid://118370194181839",
		["arrowDownCircleDotted"] = "rbxassetid://127920779547879",
		["arrowDownCircleFill"] = "rbxassetid://126613187533372",
		["arrowDownDoc"] = "rbxassetid://126263364298576",
		["arrowDownDocument"] = "rbxassetid://90055782991587",
		["arrowDownDocumentFill"] = "rbxassetid://79473920816292",
		["arrowDownForward"] = "rbxassetid://139974283617157",
		["arrowDownForwardAndArrowUpBackward"] = "rbxassetid://127715462923536",
		["arrowDownForwardAndArrowUpBackwardCircle"] = "rbxassetid://99167961428062",
		["arrowDownForwardAndArrowUpBackwardCircleFill"] = "rbxassetid://90718624284226",
		["arrowDownForwardAndArrowUpBackwardRectangle"] = "rbxassetid://109896428717818",
		["arrowDownForwardAndArrowUpBackwardRectangleFill"] = "rbxassetid://101296521578239",
		["arrowDownForwardAndArrowUpBackwardSquare"] = "rbxassetid://79718568224638",
		["arrowDownForwardAndArrowUpBackwardSquareFill"] = "rbxassetid://118653902474315",
		["arrowDownForwardCircle"] = "rbxassetid://91129944003312",
		["arrowDownForwardCircleDotted"] = "rbxassetid://79058882401591",
		["arrowDownForwardCircleFill"] = "rbxassetid://90616558170424",
		["arrowDownForwardSquare"] = "rbxassetid://135965851538670",
		["arrowDownForwardSquareFill"] = "rbxassetid://86743623269835",
		["arrowDownForwardTopleadingRectangle"] = "rbxassetid://100959335820912",
		["arrowDownForwardTopleadingRectangleFill"] = "rbxassetid://116322978531995",
		["arrowDownHeart"] = "rbxassetid://136960602456421",
		["arrowDownHeartFill"] = "rbxassetid://111091347386558",
		["arrowDownLeft"] = "rbxassetid://122224910211071",
		["arrowDownLeftAndArrowUpRight"] = "rbxassetid://104164888472588",
		["arrowDownLeftAndArrowUpRightCircle"] = "rbxassetid://139958788849042",
		["arrowDownLeftAndArrowUpRightCircleFill"] = "rbxassetid://77940274374626",
		["arrowDownLeftAndArrowUpRightRectangle"] = "rbxassetid://130268567739782",
		["arrowDownLeftAndArrowUpRightRectangleFill"] = "rbxassetid://136447163738546",
		["arrowDownLeftAndArrowUpRightSquare"] = "rbxassetid://74329478808503",
		["arrowDownLeftAndArrowUpRightSquareFill"] = "rbxassetid://112488682508039",
		["arrowDownLeftArrowUpRight"] = "rbxassetid://110501884912653",
		["arrowDownLeftArrowUpRightCircle"] = "rbxassetid://81099073033121",
		["arrowDownLeftArrowUpRightCircleFill"] = "rbxassetid://101109754050167",
		["arrowDownLeftArrowUpRightSquare"] = "rbxassetid://88334237843710",
		["arrowDownLeftArrowUpRightSquareFill"] = "rbxassetid://118701870591849",
		["arrowDownLeftCircle"] = "rbxassetid://92547732629924",
		["arrowDownLeftCircleDotted"] = "rbxassetid://95151928004771",
		["arrowDownLeftCircleFill"] = "rbxassetid://86643102687783",
		["arrowDownLeftSquare"] = "rbxassetid://83024806847192",
		["arrowDownLeftSquareFill"] = "rbxassetid://112644786722286",
		["arrowDownLeftToprightRectangle"] = "rbxassetid://113141341051779",
		["arrowDownLeftToprightRectangleFill"] = "rbxassetid://130388914126671",
		["arrowDownLeftVideo"] = "rbxassetid://76350513151515",
		["arrowDownLeftVideoFill"] = "rbxassetid://140633155175462",
		["arrowDownMessage"] = "rbxassetid://100621717832807",
		["arrowDownMessageFill"] = "rbxassetid://74100213634491",
		["arrowDownRight"] = "rbxassetid://79448572967402",
		["arrowDownRightAndArrowUpLeft"] = "rbxassetid://89225125347394",
		["arrowDownRightAndArrowUpLeftCircle"] = "rbxassetid://80802938078543",
		["arrowDownRightAndArrowUpLeftCircleFill"] = "rbxassetid://140259126181191",
		["arrowDownRightAndArrowUpLeftRectangle"] = "rbxassetid://107575531690549",
		["arrowDownRightAndArrowUpLeftRectangleFill"] = "rbxassetid://113365716944083",
		["arrowDownRightAndArrowUpLeftSquare"] = "rbxassetid://120050363028423",
		["arrowDownRightAndArrowUpLeftSquareFill"] = "rbxassetid://131765067257388",
		["arrowDownRightCircle"] = "rbxassetid://134197654580585",
		["arrowDownRightCircleDotted"] = "rbxassetid://90832353961844",
		["arrowDownRightCircleFill"] = "rbxassetid://74812371090023",
		["arrowDownRightSquare"] = "rbxassetid://140176759330522",
		["arrowDownRightSquareFill"] = "rbxassetid://123563260022187",
		["arrowDownRightTopleftRectangle"] = "rbxassetid://71596950769323",
		["arrowDownRightTopleftRectangleFill"] = "rbxassetid://93249639234250",
		["arrowDownSquare"] = "rbxassetid://96495851984147",
		["arrowDownSquareFill"] = "rbxassetid://78941122620807",
		["arrowDownToLine"] = "rbxassetid://81945854315577",
		["arrowDownToLineCircle"] = "rbxassetid://104062291929801",
		["arrowDownToLineCircleFill"] = "rbxassetid://90141383354318",
		["arrowDownToLineCompact"] = "rbxassetid://75925803459799",
		["arrowDownToLineSquare"] = "rbxassetid://105349654584160",
		["arrowDownToLineSquareFill"] = "rbxassetid://79175779364203",
		["arrowForward"] = "rbxassetid://121760727871708",
		["arrowForwardCircle"] = "rbxassetid://122188146321824",
		["arrowForwardCircleDotted"] = "rbxassetid://84632482795162",
		["arrowForwardCircleFill"] = "rbxassetid://136358992052631",
		["arrowForwardFolder"] = "rbxassetid://110107371036130",
		["arrowForwardFolderFill"] = "rbxassetid://132247910751681",
		["arrowForwardSquare"] = "rbxassetid://72679546839781",
		["arrowForwardSquareFill"] = "rbxassetid://90595336174638",
		["arrowForwardToLine"] = "rbxassetid://132984755317478",
		["arrowForwardToLineCircle"] = "rbxassetid://130410583070504",
		["arrowForwardToLineCircleFill"] = "rbxassetid://88891501791499",
		["arrowForwardToLineCompact"] = "rbxassetid://96760155810467",
		["arrowForwardToLineSquare"] = "rbxassetid://97107689023381",
		["arrowForwardToLineSquareFill"] = "rbxassetid://140368370217658",
		["arrowLeft"] = "rbxassetid://139677317950411",
		["arrowLeftAndLineVerticalAndArrowRight"] = "rbxassetid://76582002086211",
		["arrowLeftAndRight"] = "rbxassetid://131255998904716",
		["arrowLeftAndRightCircle"] = "rbxassetid://92018708920904",
		["arrowLeftAndRightCircleFill"] = "rbxassetid://101260287153536",
		["arrowLeftAndRightRighttriangleLeftRighttriangleRight"] = "rbxassetid://103119872066027",
		["arrowLeftAndRightSquare"] = "rbxassetid://106696311729076",
		["arrowLeftAndRightSquareFill"] = "rbxassetid://104053611756322",
		["arrowLeftAndRightTextVertical"] = "rbxassetid://105731168987658",
		["arrowLeftArrowRight"] = "rbxassetid://126907484829097",
		["arrowLeftArrowRightCircle"] = "rbxassetid://108565375252584",
		["arrowLeftArrowRightCircleFill"] = "rbxassetid://132777863386711",
		["arrowLeftArrowRightSquare"] = "rbxassetid://76772045577087",
		["arrowLeftArrowRightSquareFill"] = "rbxassetid://137418280059179",
		["arrowLeftCircle"] = "rbxassetid://128580341438564",
		["arrowLeftCircleDotted"] = "rbxassetid://80098770076714",
		["arrowLeftCircleFill"] = "rbxassetid://129347210326426",
		["arrowLeftSquare"] = "rbxassetid://70731607187432",
		["arrowLeftSquareFill"] = "rbxassetid://77669000354279",
		["arrowLeftToLine"] = "rbxassetid://84809777888169",
		["arrowLeftToLineCircle"] = "rbxassetid://95667050287745",
		["arrowLeftToLineCircleFill"] = "rbxassetid://133685867708333",
		["arrowLeftToLineCompact"] = "rbxassetid://108095528571274",
		["arrowLeftToLineSquare"] = "rbxassetid://101008265615734",
		["arrowLeftToLineSquareFill"] = "rbxassetid://115024811356910",
		["arrowRectanglepath"] = "rbxassetid://122042553990804",
		["arrowRight"] = "rbxassetid://105335022791801",
		["arrowRightAndLineVerticalAndArrowLeft"] = "rbxassetid://131068250358492",
		["arrowRightCircle"] = "rbxassetid://132800764212309",
		["arrowRightCircleDotted"] = "rbxassetid://103089050211240",
		["arrowRightCircleFill"] = "rbxassetid://91030657053477",
		["arrowRightDocOnClipboard"] = "rbxassetid://84583825314018",
		["arrowRightFilledFilterArrowRight"] = "rbxassetid://137853508742382",
		["arrowRightPageOnClipboard"] = "rbxassetid://73034395614819",
		["arrowRightSquare"] = "rbxassetid://87365895856110",
		["arrowRightSquareFill"] = "rbxassetid://118077314182831",
		["arrowRightToLine"] = "rbxassetid://106599596369923",
		["arrowRightToLineCircle"] = "rbxassetid://132392375458718",
		["arrowRightToLineCircleFill"] = "rbxassetid://127030236541102",
		["arrowRightToLineCompact"] = "rbxassetid://85675258932891",
		["arrowRightToLineSquare"] = "rbxassetid://105804634316858",
		["arrowRightToLineSquareFill"] = "rbxassetid://130284453934854",
		["arrowTriangle2Circlepath"] = "rbxassetid://97876840821545",
		["arrowTriangle2CirclepathCamera"] = "rbxassetid://110761440206205",
		["arrowTriangle2CirclepathCircle"] = "rbxassetid://137167033413367",
		["arrowTriangle2CirclepathDocOnClipboard"] = "rbxassetid://102874106989561",
		["arrowTriangle2CirclepathIcloud"] = "rbxassetid://89703160887614",
		["arrowTriangleBranch"] = "rbxassetid://106848864851086",
		["arrowTriangleCapsulepath"] = "rbxassetid://79935404561753",
		["arrowTriangleMerge"] = "rbxassetid://135675192910274",
		["arrowTrianglePull"] = "rbxassetid://92844954623247",
		["arrowTriangleSwap"] = "rbxassetid://127274138579155",
		["arrowTriangleTurnUpRightCircle"] = "rbxassetid://81052567291587",
		["arrowTriangleTurnUpRightDiamond"] = "rbxassetid://88682763036554",
		["arrowTrianglehead2Clockwise"] = "rbxassetid://120004886078638",
		["arrowTrianglehead2ClockwiseRotate90"] = "rbxassetid://95004536158964",
		["arrowTrianglehead2ClockwiseRotate90Camera"] = "rbxassetid://83773355445722",
		["arrowTrianglehead2ClockwiseRotate90CameraFill"] = "rbxassetid://117069297266941",
		["arrowTrianglehead2ClockwiseRotate90Circle"] = "rbxassetid://76837546635855",
		["arrowTrianglehead2ClockwiseRotate90CircleFill"] = "rbxassetid://125646699018805",
		["arrowTrianglehead2ClockwiseRotate90Icloud"] = "rbxassetid://110842292651436",
		["arrowTrianglehead2ClockwiseRotate90IcloudFill"] = "rbxassetid://83156429648892",
		["arrowTrianglehead2ClockwiseRotate90PageOnClipboard"] = "rbxassetid://92313237753356",
		["arrowTrianglehead2Counterclockwise"] = "rbxassetid://116637658638058",
		["arrowTrianglehead2CounterclockwiseRotate90"] = "rbxassetid://93633635072507",
		["arrowTriangleheadBottomleftCapsulepathClockwise"] = "rbxassetid://83435855503662",
		["arrowTriangleheadBranch"] = "rbxassetid://119639706252113",
		["arrowTriangleheadClockwise"] = "rbxassetid://113903120156035",
		["arrowTriangleheadClockwiseHeart"] = "rbxassetid://76711158700076",
		["arrowTriangleheadClockwiseHeartFill"] = "rbxassetid://111885492337179",
		["arrowTriangleheadClockwiseIcloud"] = "rbxassetid://119325834106076",
		["arrowTriangleheadClockwiseIcloudFill"] = "rbxassetid://130817770436829",
		["arrowTriangleheadClockwiseRotate90"] = "rbxassetid://125916637513059",
		["arrowTriangleheadCounterclockwise"] = "rbxassetid://81134858856836",
		["arrowTriangleheadCounterclockwiseIcloud"] = "rbxassetid://97631605490623",
		["arrowTriangleheadCounterclockwiseIcloudFill"] = "rbxassetid://124239436659602",
		["arrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://103879478813346",
		["arrowTriangleheadLeftAndRightRighttriangleLeftRighttriangleRight"] = "rbxassetid://95185575126651",
		["arrowTriangleheadLeftAndRightRighttriangleLeftRighttriangleRightFill"] = "rbxassetid://113746416760123",
		["arrowTriangleheadMerge"] = "rbxassetid://93660888122611",
		["arrowTriangleheadPull"] = "rbxassetid://70848847762237",
		["arrowTriangleheadRectanglepath"] = "rbxassetid://122075661819073",
		["arrowTriangleheadSwap"] = "rbxassetid://122615966163021",
		["arrowTriangleheadToprightCapsulepathClockwise"] = "rbxassetid://87561863258163",
		["arrowTriangleheadTurnUpRight"] = "rbxassetid://112409191526627",
		["arrowTriangleheadTurnUpRightCircle"] = "rbxassetid://125092376767446",
		["arrowTriangleheadTurnUpRightCircleFill"] = "rbxassetid://126793442327731",
		["arrowTriangleheadTurnUpRightDiamond"] = "rbxassetid://85736667530199",
		["arrowTriangleheadTurnUpRightDiamondFill"] = "rbxassetid://106982346982974",
		["arrowTriangleheadUpAndDownRighttriangleUpRighttriangleDown"] = "rbxassetid://85377495785588",
		["arrowTriangleheadUpAndDownRighttriangleUpRighttriangleDownFill"] = "rbxassetid://123977430406222",
		["arrowTurnDownLeft"] = "rbxassetid://132895074468769",
		["arrowTurnDownRight"] = "rbxassetid://106816227955900",
		["arrowTurnLeftDown"] = "rbxassetid://81993128525415",
		["arrowTurnLeftUp"] = "rbxassetid://72953914184632",
		["arrowTurnRightDown"] = "rbxassetid://93298093089829",
		["arrowTurnRightUp"] = "rbxassetid://82753096109690",
		["arrowTurnUpForwardIphone"] = "rbxassetid://126615799314276",
		["arrowTurnUpForwardIphoneFill"] = "rbxassetid://94877893999375",
		["arrowTurnUpLeft"] = "rbxassetid://92961717180242",
		["arrowTurnUpRight"] = "rbxassetid://99344786740317",
		["arrowUp"] = "rbxassetid://78648712658851",
		["arrowUpAndDown"] = "rbxassetid://86116303630216",
		["arrowUpAndDownAndArrowLeftAndRight"] = "rbxassetid://138985551455035",
		["arrowUpAndDownAndSparkles"] = "rbxassetid://81684341236209",
		["arrowUpAndDownCircle"] = "rbxassetid://75916292096750",
		["arrowUpAndDownCircleFill"] = "rbxassetid://75127469037390",
		["arrowUpAndDownRighttriangleUpRighttriangleDown"] = "rbxassetid://89990169721189",
		["arrowUpAndDownSquare"] = "rbxassetid://114110154035595",
		["arrowUpAndDownSquareFill"] = "rbxassetid://75202394337547",
		["arrowUpAndDownTextHorizontal"] = "rbxassetid://121347816102410",
		["arrowUpAndLineHorizontalAndArrowDown"] = "rbxassetid://105622726329752",
		["arrowUpAndPersonRectanglePortrait"] = "rbxassetid://130823180804285",
		["arrowUpAndPersonRectangleTurnLeft"] = "rbxassetid://85243691603750",
		["arrowUpAndPersonRectangleTurnRight"] = "rbxassetid://105085966547216",
		["arrowUpArrowDown"] = "rbxassetid://113515949560452",
		["arrowUpArrowDownCircle"] = "rbxassetid://121460592181765",
		["arrowUpArrowDownCircleFill"] = "rbxassetid://79203277607685",
		["arrowUpArrowDownSquare"] = "rbxassetid://137035914755347",
		["arrowUpArrowDownSquareFill"] = "rbxassetid://78686762407726",
		["arrowUpBackward"] = "rbxassetid://87724093939497",
		["arrowUpBackwardAndArrowDownForward"] = "rbxassetid://86635108527984",
		["arrowUpBackwardAndArrowDownForwardCircle"] = "rbxassetid://115317188393520",
		["arrowUpBackwardAndArrowDownForwardCircleFill"] = "rbxassetid://77043906356644",
		["arrowUpBackwardAndArrowDownForwardRectangle"] = "rbxassetid://89847106989116",
		["arrowUpBackwardAndArrowDownForwardRectangleFill"] = "rbxassetid://114674554996662",
		["arrowUpBackwardAndArrowDownForwardSquare"] = "rbxassetid://96097826426907",
		["arrowUpBackwardAndArrowDownForwardSquareFill"] = "rbxassetid://100908924982344",
		["arrowUpBackwardBottomtrailingRectangle"] = "rbxassetid://132306797856286",
		["arrowUpBackwardBottomtrailingRectangleFill"] = "rbxassetid://121132174005134",
		["arrowUpBackwardCircle"] = "rbxassetid://87697874759260",
		["arrowUpBackwardCircleDotted"] = "rbxassetid://72881423591822",
		["arrowUpBackwardCircleFill"] = "rbxassetid://120193357020420",
		["arrowUpBackwardSquare"] = "rbxassetid://71077852083839",
		["arrowUpBackwardSquareFill"] = "rbxassetid://93398569903581",
		["arrowUpBin"] = "rbxassetid://106712407901427",
		["arrowUpBinFill"] = "rbxassetid://124011006230787",
		["arrowUpCircle"] = "rbxassetid://94911675961250",
		["arrowUpCircleBadgeClock"] = "rbxassetid://125476968673977",
		["arrowUpCircleDotted"] = "rbxassetid://111193851076319",
		["arrowUpCircleFill"] = "rbxassetid://111941746337748",
		["arrowUpDoc"] = "rbxassetid://130298316589925",
		["arrowUpDocOnClipboard"] = "rbxassetid://99871373237994",
		["arrowUpDocument"] = "rbxassetid://117304311448174",
		["arrowUpDocumentFill"] = "rbxassetid://96587047161399",
		["arrowUpFolder"] = "rbxassetid://119174018910178",
		["arrowUpFolderFill"] = "rbxassetid://127574661082745",
		["arrowUpForward"] = "rbxassetid://108134164414127",
		["arrowUpForwardAndArrowDownBackward"] = "rbxassetid://130767770587903",
		["arrowUpForwardAndArrowDownBackwardCircle"] = "rbxassetid://107376465009384",
		["arrowUpForwardAndArrowDownBackwardCircleFill"] = "rbxassetid://103317843905876",
		["arrowUpForwardAndArrowDownBackwardRectangle"] = "rbxassetid://115453529068587",
		["arrowUpForwardAndArrowDownBackwardRectangleFill"] = "rbxassetid://79439647053232",
		["arrowUpForwardAndArrowDownBackwardSquare"] = "rbxassetid://92612164951517",
		["arrowUpForwardAndArrowDownBackwardSquareFill"] = "rbxassetid://70813042781223",
		["arrowUpForwardApp"] = "rbxassetid://112829959970173",
		["arrowUpForwardAppFill"] = "rbxassetid://91761460498076",
		["arrowUpForwardBottomleadingRectangle"] = "rbxassetid://134640132914184",
		["arrowUpForwardBottomleadingRectangleFill"] = "rbxassetid://122314628337723",
		["arrowUpForwardCircle"] = "rbxassetid://109463155016717",
		["arrowUpForwardCircleDotted"] = "rbxassetid://108263917514812",
		["arrowUpForwardCircleFill"] = "rbxassetid://77346795770693",
		["arrowUpForwardSquare"] = "rbxassetid://74557125136657",
		["arrowUpForwardSquareFill"] = "rbxassetid://119788530957673",
		["arrowUpHeart"] = "rbxassetid://81211473277206",
		["arrowUpHeartFill"] = "rbxassetid://112776567008638",
		["arrowUpLeft"] = "rbxassetid://110082174383245",
		["arrowUpLeftAndArrowDownRight"] = "rbxassetid://134847585698412",
		["arrowUpLeftAndArrowDownRightCircle"] = "rbxassetid://130371359392714",
		["arrowUpLeftAndArrowDownRightCircleFill"] = "rbxassetid://132427830878732",
		["arrowUpLeftAndArrowDownRightRectangle"] = "rbxassetid://112294474196779",
		["arrowUpLeftAndArrowDownRightRectangleFill"] = "rbxassetid://125360402793191",
		["arrowUpLeftAndArrowDownRightSquare"] = "rbxassetid://83415006038142",
		["arrowUpLeftAndArrowDownRightSquareFill"] = "rbxassetid://115887822292112",
		["arrowUpLeftAndDownRightAndArrowUpRightAndDownLeft"] = "rbxassetid://129739556524804",
		["arrowUpLeftAndDownRightMagnifyingglass"] = "rbxassetid://137681018745874",
		["arrowUpLeftArrowDownRight"] = "rbxassetid://75439123019508",
		["arrowUpLeftArrowDownRightCircle"] = "rbxassetid://105643094155741",
		["arrowUpLeftArrowDownRightCircleFill"] = "rbxassetid://131547709448660",
		["arrowUpLeftArrowDownRightSquare"] = "rbxassetid://85909271280986",
		["arrowUpLeftArrowDownRightSquareFill"] = "rbxassetid://99819888059672",
		["arrowUpLeftBottomrightRectangle"] = "rbxassetid://91558034145888",
		["arrowUpLeftBottomrightRectangleFill"] = "rbxassetid://100287102307407",
		["arrowUpLeftCircle"] = "rbxassetid://121309248454944",
		["arrowUpLeftCircleDotted"] = "rbxassetid://123064294982538",
		["arrowUpLeftCircleFill"] = "rbxassetid://78043906697669",
		["arrowUpLeftSquare"] = "rbxassetid://73015943041948",
		["arrowUpLeftSquareFill"] = "rbxassetid://102556879413712",
		["arrowUpMessage"] = "rbxassetid://94225019561009",
		["arrowUpMessageFill"] = "rbxassetid://82404908556915",
		["arrowUpPageOnClipboard"] = "rbxassetid://78980645203354",
		["arrowUpRight"] = "rbxassetid://138844888875215",
		["arrowUpRightAndArrowDownLeft"] = "rbxassetid://114866781443213",
		["arrowUpRightAndArrowDownLeftCircle"] = "rbxassetid://132105309061719",
		["arrowUpRightAndArrowDownLeftCircleFill"] = "rbxassetid://71412626619086",
		["arrowUpRightAndArrowDownLeftRectangle"] = "rbxassetid://73363578686738",
		["arrowUpRightAndArrowDownLeftRectangleFill"] = "rbxassetid://91445141227731",
		["arrowUpRightAndArrowDownLeftSquare"] = "rbxassetid://86339485660754",
		["arrowUpRightAndArrowDownLeftSquareFill"] = "rbxassetid://71919422941284",
		["arrowUpRightBottomleftRectangle"] = "rbxassetid://130762630351301",
		["arrowUpRightBottomleftRectangleFill"] = "rbxassetid://95630843701625",
		["arrowUpRightCircle"] = "rbxassetid://81069070166818",
		["arrowUpRightCircleDotted"] = "rbxassetid://97345855116158",
		["arrowUpRightCircleFill"] = "rbxassetid://128938699095412",
		["arrowUpRightSquare"] = "rbxassetid://85191059189074",
		["arrowUpRightSquareFill"] = "rbxassetid://137785035586451",
		["arrowUpRightVideo"] = "rbxassetid://90919665747630",
		["arrowUpRightVideoFill"] = "rbxassetid://88874555643489",
		["arrowUpSquare"] = "rbxassetid://138634860884120",
		["arrowUpSquareFill"] = "rbxassetid://120264192976826",
		["arrowUpToLine"] = "rbxassetid://88548334886822",
		["arrowUpToLineCircle"] = "rbxassetid://83360733774110",
		["arrowUpToLineCircleFill"] = "rbxassetid://108275997754139",
		["arrowUpToLineCompact"] = "rbxassetid://74427170938065",
		["arrowUpToLineSquare"] = "rbxassetid://137278763514757",
		["arrowUpToLineSquareFill"] = "rbxassetid://74700745163970",
		["arrowUpTrash"] = "rbxassetid://108944881391784",
		["arrowUpTrashFill"] = "rbxassetid://82802068079538",
		["arrowUturnBackward"] = "rbxassetid://84932065764436",
		["arrowUturnBackwardCircle"] = "rbxassetid://109075671313648",
		["arrowUturnBackwardCircleBadgeEllipsis"] = "rbxassetid://102431303478130",
		["arrowUturnBackwardCircleFill"] = "rbxassetid://82112623202198",
		["arrowUturnBackwardSquare"] = "rbxassetid://91917148305042",
		["arrowUturnBackwardSquareFill"] = "rbxassetid://99547665686894",
		["arrowUturnDown"] = "rbxassetid://91557237297615",
		["arrowUturnDownCircle"] = "rbxassetid://88762138487585",
		["arrowUturnDownCircleFill"] = "rbxassetid://125070612634633",
		["arrowUturnDownSquare"] = "rbxassetid://82491208720289",
		["arrowUturnDownSquareFill"] = "rbxassetid://140476075043878",
		["arrowUturnForward"] = "rbxassetid://125471619268828",
		["arrowUturnForwardCircle"] = "rbxassetid://123731708760049",
		["arrowUturnForwardCircleFill"] = "rbxassetid://86954998472846",
		["arrowUturnForwardSquare"] = "rbxassetid://119862778570014",
		["arrowUturnForwardSquareFill"] = "rbxassetid://73557234553032",
		["arrowUturnLeft"] = "rbxassetid://75706868554870",
		["arrowUturnLeftCircle"] = "rbxassetid://80299087209180",
		["arrowUturnLeftCircleBadgeEllipsis"] = "rbxassetid://76418451999894",
		["arrowUturnLeftCircleFill"] = "rbxassetid://111850081065384",
		["arrowUturnLeftSquare"] = "rbxassetid://101145741063035",
		["arrowUturnLeftSquareFill"] = "rbxassetid://138477537092319",
		["arrowUturnRight"] = "rbxassetid://85195579204455",
		["arrowUturnRightCircle"] = "rbxassetid://137184521519714",
		["arrowUturnRightCircleFill"] = "rbxassetid://96886515578405",
		["arrowUturnRightSquare"] = "rbxassetid://84513404712444",
		["arrowUturnRightSquareFill"] = "rbxassetid://87526577867039",
		["arrowUturnUp"] = "rbxassetid://130075543513615",
		["arrowUturnUpCircle"] = "rbxassetid://75243570930387",
		["arrowUturnUpCircleFill"] = "rbxassetid://133907130193679",
		["arrowUturnUpSquare"] = "rbxassetid://124293795803561",
		["arrowUturnUpSquareFill"] = "rbxassetid://114646903692155",
		["arrowkeys"] = "rbxassetid://107093674674175",
		["arrowkeysDownFilled"] = "rbxassetid://139314313798595",
		["arrowkeysFill"] = "rbxassetid://83701399567141",
		["arrowkeysLeftFilled"] = "rbxassetid://80905415438039",
		["arrowkeysRightFilled"] = "rbxassetid://78361096026269",
		["arrowkeysUpFilled"] = "rbxassetid://76100553966528",
		["arrowshapeBackward"] = "rbxassetid://103946413747803",
		["arrowshapeBackwardCircle"] = "rbxassetid://96473706444669",
		["arrowshapeBackwardCircleFill"] = "rbxassetid://78185643268471",
		["arrowshapeBackwardFill"] = "rbxassetid://137234108178990",
		["arrowshapeBounceForward"] = "rbxassetid://104361688592034",
		["arrowshapeBounceForwardFill"] = "rbxassetid://133551113789028",
		["arrowshapeBounceRight"] = "rbxassetid://77629075456961",
		["arrowshapeBounceRightFill"] = "rbxassetid://89650738004209",
		["arrowshapeDown"] = "rbxassetid://97389010768394",
		["arrowshapeDownCircle"] = "rbxassetid://77919837179930",
		["arrowshapeDownCircleFill"] = "rbxassetid://111547932661301",
		["arrowshapeDownFill"] = "rbxassetid://99240071360620",
		["arrowshapeForward"] = "rbxassetid://88362661062616",
		["arrowshapeForwardCircle"] = "rbxassetid://84389407203275",
		["arrowshapeForwardCircleFill"] = "rbxassetid://78338063364751",
		["arrowshapeForwardFill"] = "rbxassetid://95436585159679",
		["arrowshapeLeft"] = "rbxassetid://98701118720679",
		["arrowshapeLeftArrowshapeRight"] = "rbxassetid://121937636687253",
		["arrowshapeLeftArrowshapeRightFill"] = "rbxassetid://133886606502645",
		["arrowshapeLeftCircle"] = "rbxassetid://71393237208194",
		["arrowshapeLeftCircleFill"] = "rbxassetid://136385477516373",
		["arrowshapeLeftFill"] = "rbxassetid://118305835198238",
		["arrowshapeRight"] = "rbxassetid://120488785795747",
		["arrowshapeRightCircle"] = "rbxassetid://121626085651476",
		["arrowshapeRightCircleFill"] = "rbxassetid://76461671929970",
		["arrowshapeRightFill"] = "rbxassetid://70999924264432",
		["arrowshapeTurnUpBackward"] = "rbxassetid://78881537733143",
		["arrowshapeTurnUpBackward2"] = "rbxassetid://107092825956456",
		["arrowshapeTurnUpBackward2Circle"] = "rbxassetid://137756561495871",
		["arrowshapeTurnUpBackward2CircleFill"] = "rbxassetid://135826797352330",
		["arrowshapeTurnUpBackward2Fill"] = "rbxassetid://131562286201667",
		["arrowshapeTurnUpBackwardBadgeClock"] = "rbxassetid://135028155928594",
		["arrowshapeTurnUpBackwardBadgeClockFill"] = "rbxassetid://73450872932149",
		["arrowshapeTurnUpBackwardCircle"] = "rbxassetid://71825408205036",
		["arrowshapeTurnUpBackwardCircleFill"] = "rbxassetid://111623422888025",
		["arrowshapeTurnUpBackwardFill"] = "rbxassetid://109125772896311",
		["arrowshapeTurnUpForward"] = "rbxassetid://76816503115863",
		["arrowshapeTurnUpForwardCircle"] = "rbxassetid://98602961202921",
		["arrowshapeTurnUpForwardCircleFill"] = "rbxassetid://70470114130488",
		["arrowshapeTurnUpForwardFill"] = "rbxassetid://92381825435352",
		["arrowshapeTurnUpLeft"] = "rbxassetid://108614332890595",
		["arrowshapeTurnUpLeft2"] = "rbxassetid://78716969962631",
		["arrowshapeTurnUpLeft2Circle"] = "rbxassetid://123519063994380",
		["arrowshapeTurnUpLeft2CircleFill"] = "rbxassetid://113915966573413",
		["arrowshapeTurnUpLeft2Fill"] = "rbxassetid://86951174248840",
		["arrowshapeTurnUpLeftCircle"] = "rbxassetid://73601074472826",
		["arrowshapeTurnUpLeftCircleFill"] = "rbxassetid://136740410564323",
		["arrowshapeTurnUpLeftFill"] = "rbxassetid://94219456241500",
		["arrowshapeTurnUpRight"] = "rbxassetid://106325504068133",
		["arrowshapeTurnUpRightCircle"] = "rbxassetid://75919927711551",
		["arrowshapeTurnUpRightCircleFill"] = "rbxassetid://106669100525653",
		["arrowshapeTurnUpRightFill"] = "rbxassetid://134006299248390",
		["arrowshapeUp"] = "rbxassetid://101998758692791",
		["arrowshapeUpCircle"] = "rbxassetid://99257685761594",
		["arrowshapeUpCircleFill"] = "rbxassetid://96806111160193",
		["arrowshapeUpFill"] = "rbxassetid://88008006362903",
		["arrowshapeZigzagForward"] = "rbxassetid://129549353799543",
		["arrowshapeZigzagForwardFill"] = "rbxassetid://106898814741078",
		["arrowshapeZigzagRight"] = "rbxassetid://103673619735369",
		["arrowshapeZigzagRightFill"] = "rbxassetid://130759407110780",
		["arrowtriangleBackward"] = "rbxassetid://133521659387505",
		["arrowtriangleBackwardCircle"] = "rbxassetid://123787083134802",
		["arrowtriangleBackwardCircleFill"] = "rbxassetid://126681849588441",
		["arrowtriangleBackwardFill"] = "rbxassetid://111916009128209",
		["arrowtriangleBackwardSquare"] = "rbxassetid://140338552398565",
		["arrowtriangleBackwardSquareFill"] = "rbxassetid://74805844172505",
		["arrowtriangleDown"] = "rbxassetid://78561539908893",
		["arrowtriangleDownCircle"] = "rbxassetid://77571811725142",
		["arrowtriangleDownCircleFill"] = "rbxassetid://105503627251065",
		["arrowtriangleDownFill"] = "rbxassetid://83161926977947",
		["arrowtriangleDownSquare"] = "rbxassetid://138420790717673",
		["arrowtriangleDownSquareFill"] = "rbxassetid://91021138374724",
		["arrowtriangleForward"] = "rbxassetid://80300262330695",
		["arrowtriangleForwardCircle"] = "rbxassetid://88365381729452",
		["arrowtriangleForwardCircleFill"] = "rbxassetid://136664536116197",
		["arrowtriangleForwardFill"] = "rbxassetid://131170560324771",
		["arrowtriangleForwardSquare"] = "rbxassetid://94267906643716",
		["arrowtriangleForwardSquareFill"] = "rbxassetid://115669972392572",
		["arrowtriangleLeft"] = "rbxassetid://82742410867767",
		["arrowtriangleLeftAndLineVerticalAndArrowtriangleRight"] = "rbxassetid://82250512181706",
		["arrowtriangleLeftAndLineVerticalAndArrowtriangleRightFill"] = "rbxassetid://75120863415970",
		["arrowtriangleLeftCircle"] = "rbxassetid://130940545964020",
		["arrowtriangleLeftCircleFill"] = "rbxassetid://91597184747625",
		["arrowtriangleLeftFill"] = "rbxassetid://100246673935435",
		["arrowtriangleLeftSquare"] = "rbxassetid://138937088832435",
		["arrowtriangleLeftSquareFill"] = "rbxassetid://78816347161577",
		["arrowtriangleRight"] = "rbxassetid://120603282360061",
		["arrowtriangleRightAndLineVerticalAndArrowtriangleLeft"] = "rbxassetid://125551472926573",
		["arrowtriangleRightAndLineVerticalAndArrowtriangleLeftFill"] = "rbxassetid://137442224732768",
		["arrowtriangleRightCircle"] = "rbxassetid://137176667486761",
		["arrowtriangleRightCircleFill"] = "rbxassetid://108534551246412",
		["arrowtriangleRightFill"] = "rbxassetid://135662872907406",
		["arrowtriangleRightSquare"] = "rbxassetid://136702219548567",
		["arrowtriangleRightSquareFill"] = "rbxassetid://86559277753252",
		["arrowtriangleUp"] = "rbxassetid://111075032702135",
		["arrowtriangleUpArrowtriangleDownWindowLeft"] = "rbxassetid://111106358415702",
		["arrowtriangleUpArrowtriangleDownWindowRight"] = "rbxassetid://119754928116595",
		["arrowtriangleUpCircle"] = "rbxassetid://135791635467358",
		["arrowtriangleUpCircleFill"] = "rbxassetid://77906388596939",
		["arrowtriangleUpFill"] = "rbxassetid://95395937128837",
		["arrowtriangleUpSquare"] = "rbxassetid://121847518853496",
		["arrowtriangleUpSquareFill"] = "rbxassetid://90626000681247",
		["aspectratio"] = "rbxassetid://98517185380471",
		["aspectratioFill"] = "rbxassetid://102579851046592",
		["asterisk"] = "rbxassetid://88871616629375",
		["asteriskCircle"] = "rbxassetid://133395747175893",
		["asteriskCircleFill"] = "rbxassetid://139028990558441",
		["at"] = "rbxassetid://137471691924175",
		["atBadgeMinus"] = "rbxassetid://134623783886552",
		["atBadgePlus"] = "rbxassetid://135293868255291",
		["atCircle"] = "rbxassetid://75936351641093",
		["atCircleFill"] = "rbxassetid://134377411625052",
		["atom"] = "rbxassetid://108843899986154",
		["audioJackMono"] = "rbxassetid://122663599339745",
		["audioJackStereo"] = "rbxassetid://106388714289332",
		["australianFootball"] = "rbxassetid://83717210268275",
		["australianFootballCircle"] = "rbxassetid://91216938435305",
		["australianFootballCircleFill"] = "rbxassetid://119703555005899",
		["australianFootballFill"] = "rbxassetid://91615056179585",
		["australiandollarsign"] = "rbxassetid://108383329795594",
		["australiandollarsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://103619465363524",
		["australiandollarsignBankBuilding"] = "rbxassetid://112691589231459",
		["australiandollarsignBankBuildingFill"] = "rbxassetid://110933280500384",
		["australiandollarsignCircle"] = "rbxassetid://138087916288699",
		["australiandollarsignCircleFill"] = "rbxassetid://139132160908400",
		["australiandollarsignGaugeChartLefthalfRighthalf"] = "rbxassetid://105231666559232",
		["australiandollarsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://82562990214305",
		["australiandollarsignRing"] = "rbxassetid://107065817248382",
		["australiandollarsignRingDashed"] = "rbxassetid://98956564238236",
		["australiandollarsignSquare"] = "rbxassetid://105212688231309",
		["australiandollarsignSquareFill"] = "rbxassetid://75954055268212",
		["australsign"] = "rbxassetid://137973006716083",
		["australsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://130848259106826",
		["australsignBankBuilding"] = "rbxassetid://94265426732688",
		["australsignBankBuildingFill"] = "rbxassetid://123552301428619",
		["australsignCircle"] = "rbxassetid://108380187386176",
		["australsignCircleFill"] = "rbxassetid://127875262466300",
		["australsignGaugeChartLefthalfRighthalf"] = "rbxassetid://70536095598981",
		["australsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://100233677044940",
		["australsignRing"] = "rbxassetid://88317124938109",
		["australsignRingDashed"] = "rbxassetid://97213251184448",
		["australsignSquare"] = "rbxassetid://122311949572306",
		["australsignSquareFill"] = "rbxassetid://94187640679425",
		["automaticBrakesignal"] = "rbxassetid://112399930314317",
		["automaticHeadlightHighBeam"] = "rbxassetid://135968366756093",
		["automaticHeadlightHighBeamFill"] = "rbxassetid://139626180694517",
		["automaticHeadlightLowBeam"] = "rbxassetid://82654718912628",
		["automaticHeadlightLowBeamFill"] = "rbxassetid://107178223306087",
		["autostartstop"] = "rbxassetid://77457912590274",
		["autostartstopSlash"] = "rbxassetid://114435810438487",
		["autostartstopTrianglebadgeExclamationmark"] = "rbxassetid://72480057980841",
		["avRemote"] = "rbxassetid://96333083759338",
		["avRemoteFill"] = "rbxassetid://103929453784307",
		["axle2"] = "rbxassetid://75705790851902",
		["axle2DriveshaftDisengaged"] = "rbxassetid://85396555863957",
		["axle2FrontAndRearEngaged"] = "rbxassetid://120452693782445",
		["axle2FrontDisengaged"] = "rbxassetid://129154377234623",
		["axle2FrontEngaged"] = "rbxassetid://80501466407638",
		["axle2RearDisengaged"] = "rbxassetid://80324857349654",
		["axle2RearEngaged"] = "rbxassetid://132431074188989",
		["axle2RearLock"] = "rbxassetid://75264943176879",
		["bCircle"] = "rbxassetid://109038084515649",
		["bCircleFill"] = "rbxassetid://75555363720266",
		["bSquare"] = "rbxassetid://111811804858729",
		["bSquareFill"] = "rbxassetid://128837014096906",
		["backpack"] = "rbxassetid://105195953579349",
		["backpackCircle"] = "rbxassetid://106407965386940",
		["backpackCircleFill"] = "rbxassetid://85475403012001",
		["backpackFill"] = "rbxassetid://131750104401055",
		["backpackSensorTagRadiowavesLeftAndRight"] = "rbxassetid://128407574860682",
		["backpackSensorTagRadiowavesLeftAndRightFill"] = "rbxassetid://100870002764956",
		["backward"] = "rbxassetid://122427584897716",
		["backwardCircle"] = "rbxassetid://130281893184037",
		["backwardCircleFill"] = "rbxassetid://95748082741134",
		["backwardEnd"] = "rbxassetid://73396673985237",
		["backwardEndAlt"] = "rbxassetid://118305621946322",
		["backwardEndAltFill"] = "rbxassetid://127445169423377",
		["backwardEndCircle"] = "rbxassetid://92798094076866",
		["backwardEndCircleFill"] = "rbxassetid://140411571509914",
		["backwardEndFill"] = "rbxassetid://138630184521335",
		["backwardFill"] = "rbxassetid://81244210367969",
		["backwardFrame"] = "rbxassetid://131044827344482",
		["backwardFrameFill"] = "rbxassetid://113681075822442",
		["badgePlusRadiowavesForward"] = "rbxassetid://80276313107018",
		["badgePlusRadiowavesRight"] = "rbxassetid://104524636862542",
		["bag"] = "rbxassetid://83806619279503",
		["bagBadgeMinus"] = "rbxassetid://88414309827799",
		["bagBadgePlus"] = "rbxassetid://95221444956038",
		["bagBadgeQuestionmark"] = "rbxassetid://98313201554730",
		["bagCircle"] = "rbxassetid://90936649788632",
		["bagCircleFill"] = "rbxassetid://132136901130565",
		["bagFill"] = "rbxassetid://133362226558488",
		["bagFillBadgeMinus"] = "rbxassetid://96219013654249",
		["bagFillBadgePlus"] = "rbxassetid://101245370544483",
		["bagFillBadgeQuestionmark"] = "rbxassetid://108878208237447",
		["bahtsign"] = "rbxassetid://74124698800888",
		["bahtsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://73848213936133",
		["bahtsignBankBuilding"] = "rbxassetid://104523668446152",
		["bahtsignBankBuildingFill"] = "rbxassetid://128502368268696",
		["bahtsignCircle"] = "rbxassetid://121720395197210",
		["bahtsignCircleFill"] = "rbxassetid://128305148458106",
		["bahtsignGaugeChartLefthalfRighthalf"] = "rbxassetid://132156928740514",
		["bahtsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://127536612463560",
		["bahtsignRing"] = "rbxassetid://86639737855130",
		["bahtsignRingDashed"] = "rbxassetid://96197994846363",
		["bahtsignSquare"] = "rbxassetid://134719432492683",
		["bahtsignSquareFill"] = "rbxassetid://97050155065694",
		["balloon"] = "rbxassetid://104440599584995",
		["balloon2"] = "rbxassetid://132502412439183",
		["balloon2Fill"] = "rbxassetid://119048138308879",
		["balloonFill"] = "rbxassetid://124491712982295",
		["bandage"] = "rbxassetid://138446349462290",
		["bandageFill"] = "rbxassetid://80002522608083",
		["banknote"] = "rbxassetid://136343080453229",
		["banknoteFill"] = "rbxassetid://116710375951738",
		["barcode"] = "rbxassetid://117287404870584",
		["barcodeViewfinder"] = "rbxassetid://122128534490235",
		["barometer"] = "rbxassetid://72325164390494",
		["baseUnit"] = "rbxassetid://100753773581760",
		["baseball"] = "rbxassetid://97571414419713",
		["baseballCircle"] = "rbxassetid://131671829844062",
		["baseballCircleFill"] = "rbxassetid://117106713881204",
		["baseballDiamondBases"] = "rbxassetid://111867050801343",
		["baseballDiamondBasesOutsIndicator"] = "rbxassetid://93708945096775",
		["baseballFill"] = "rbxassetid://85157186852562",
		["basket"] = "rbxassetid://106180348978806",
		["basketFill"] = "rbxassetid://136755744597949",
		["basketball"] = "rbxassetid://109068809121703",
		["basketballCircle"] = "rbxassetid://91774708796019",
		["basketballCircleFill"] = "rbxassetid://72598040742035",
		["basketballFill"] = "rbxassetid://72986631471097",
		["bathtub"] = "rbxassetid://136389567560332",
		["bathtubFill"] = "rbxassetid://97822181240087",
		["battery0percent"] = "rbxassetid://109801745750538",
		["battery100percent"] = "rbxassetid://92406047854421",
		["battery100percentBolt"] = "rbxassetid://139235463865177",
		["battery100percentCircle"] = "rbxassetid://100741582191314",
		["battery100percentCircleFill"] = "rbxassetid://106944163430713",
		["battery25percent"] = "rbxassetid://72894607867936",
		["battery50percent"] = "rbxassetid://76241070440884",
		["battery75percent"] = "rbxassetid://117533833119206",
		["batteryblock"] = "rbxassetid://121629553249088",
		["batteryblockFill"] = "rbxassetid://101347307883171",
		["batteryblockSlash"] = "rbxassetid://121610081368628",
		["batteryblockSlashFill"] = "rbxassetid://74028036721108",
		["batteryblockStack"] = "rbxassetid://115116517381557",
		["batteryblockStackBadgeSnowflake"] = "rbxassetid://78199827655256",
		["batteryblockStackBadgeSnowflakeFill"] = "rbxassetid://92623354556534",
		["batteryblockStackFill"] = "rbxassetid://125795512213710",
		["batteryblockStackTrianglebadgeExclamationmark"] = "rbxassetid://123811371527725",
		["batteryblockStackTrianglebadgeExclamationmarkFill"] = "rbxassetid://94880673974554",
		["beachUmbrella"] = "rbxassetid://72865469806459",
		["beachUmbrellaFill"] = "rbxassetid://96407034761761",
		["beatsEarphones"] = "rbxassetid://73621409785573",
		["beatsFitPro"] = "rbxassetid://122083986744951",
		["beatsFitProChargingcase"] = "rbxassetid://120936645934230",
		["beatsFitProLeft"] = "rbxassetid://116602459616537",
		["beatsFitProRight"] = "rbxassetid://119699746025879",
		["beatsFitpro"] = "rbxassetid://117645606044444",
		["beatsFitproChargingcase"] = "rbxassetid://117440666717597",
		["beatsFitproChargingcaseFill"] = "rbxassetid://71759632509502",
		["beatsFitproLeft"] = "rbxassetid://88418709068625",
		["beatsFitproRight"] = "rbxassetid://115830286382559",
		["beatsHeadphones"] = "rbxassetid://73380840337035",
		["beatsPill"] = "rbxassetid://93439483257162",
		["beatsPillFill"] = "rbxassetid://95478226585165",
		["beatsPowerbeats"] = "rbxassetid://81774880364018",
		["beatsPowerbeats3"] = "rbxassetid://74951439393133",
		["beatsPowerbeats3Left"] = "rbxassetid://101932876942063",
		["beatsPowerbeats3Right"] = "rbxassetid://135752504888114",
		["beatsPowerbeatsLeft"] = "rbxassetid://97445451933143",
		["beatsPowerbeatsPro"] = "rbxassetid://127293771112234",
		["beatsPowerbeatsPro2"] = "rbxassetid://136525865662552",
		["beatsPowerbeatsPro2Chargingcase"] = "rbxassetid://112524730561658",
		["beatsPowerbeatsPro2ChargingcaseFill"] = "rbxassetid://82844342134163",
		["beatsPowerbeatsPro2Left"] = "rbxassetid://93989999644733",
		["beatsPowerbeatsPro2Right"] = "rbxassetid://91812278494548",
		["beatsPowerbeatsProChargingcase"] = "rbxassetid://133263655529236",
		["beatsPowerbeatsProChargingcaseFill"] = "rbxassetid://99941850096551",
		["beatsPowerbeatsProLeft"] = "rbxassetid://70990272965839",
		["beatsPowerbeatsProRight"] = "rbxassetid://110928518837662",
		["beatsPowerbeatsRight"] = "rbxassetid://106040814246712",
		["beatsPowerbeatspro"] = "rbxassetid://91388282815385",
		["beatsPowerbeatsproChargingcase"] = "rbxassetid://129174227736582",
		["beatsPowerbeatsproLeft"] = "rbxassetid://132454103156247",
		["beatsPowerbeatsproRight"] = "rbxassetid://121014913156174",
		["beatsSolobuds"] = "rbxassetid://81232374366099",
		["beatsSolobudsChargingcase"] = "rbxassetid://71797823184677",
		["beatsSolobudsChargingcaseFill"] = "rbxassetid://101814016626767",
		["beatsSolobudsLeft"] = "rbxassetid://71958672695604",
		["beatsSolobudsRight"] = "rbxassetid://96581298863151",
		["beatsStudiobudLeft"] = "rbxassetid://123610938062441",
		["beatsStudiobudRight"] = "rbxassetid://92812822483138",
		["beatsStudiobuds"] = "rbxassetid://111451076752414",
		["beatsStudiobudsChargingcase"] = "rbxassetid://73000765400424",
		["beatsStudiobudsChargingcaseFill"] = "rbxassetid://109848496275498",
		["beatsStudiobudsLeft"] = "rbxassetid://137326830510510",
		["beatsStudiobudsPlus"] = "rbxassetid://115554839561360",
		["beatsStudiobudsPlusChargingcase"] = "rbxassetid://126239738972103",
		["beatsStudiobudsPlusChargingcaseFill"] = "rbxassetid://80657113028988",
		["beatsStudiobudsPlusLeft"] = "rbxassetid://75699522736651",
		["beatsStudiobudsPlusRight"] = "rbxassetid://114336760507028",
		["beatsStudiobudsRight"] = "rbxassetid://95674926492092",
		["beatsStudiobudsplus"] = "rbxassetid://71975225998517",
		["beatsStudiobudsplusChargingcase"] = "rbxassetid://125879752007426",
		["beatsStudiobudsplusLeft"] = "rbxassetid://111603577383991",
		["beatsStudiobudsplusRight"] = "rbxassetid://118741913661751",
		["bedDouble"] = "rbxassetid://101701657145902",
		["bedDoubleBadgeCheckmark"] = "rbxassetid://109375568035932",
		["bedDoubleBadgeCheckmarkFill"] = "rbxassetid://120398540124030",
		["bedDoubleCircle"] = "rbxassetid://71145319148752",
		["bedDoubleCircleFill"] = "rbxassetid://92627250811342",
		["bedDoubleFill"] = "rbxassetid://129538544854607",
		["bell"] = "rbxassetid://133308773796467",
		["bellAndWavesLeftAndRight"] = "rbxassetid://121214018166023",
		["bellAndWavesLeftAndRightFill"] = "rbxassetid://88807057176486",
		["bellBadge"] = "rbxassetid://102918378539260",
		["bellBadgeCircle"] = "rbxassetid://96523824553022",
		["bellBadgeCircleFill"] = "rbxassetid://103345485539554",
		["bellBadgeFill"] = "rbxassetid://82918576077557",
		["bellBadgeSlash"] = "rbxassetid://102012144577464",
		["bellBadgeSlashFill"] = "rbxassetid://86863600694155",
		["bellBadgeWaveform"] = "rbxassetid://137731188990608",
		["bellBadgeWaveformFill"] = "rbxassetid://91685274004740",
		["bellBadgeWaveformSlash"] = "rbxassetid://139347903627441",
		["bellBadgeWaveformSlashFill"] = "rbxassetid://121644601155346",
		["bellCircle"] = "rbxassetid://119385063880385",
		["bellCircleFill"] = "rbxassetid://98518266376193",
		["bellFill"] = "rbxassetid://120560073129118",
		["bellSlash"] = "rbxassetid://131140638570899",
		["bellSlashCircle"] = "rbxassetid://101842323179229",
		["bellSlashCircleFill"] = "rbxassetid://115293256505054",
		["bellSlashFill"] = "rbxassetid://104881180476235",
		["bellSquare"] = "rbxassetid://96391651511460",
		["bellSquareFill"] = "rbxassetid://114947742366600",
		["beziercurve"] = "rbxassetid://100185315689380",
		["bicycle"] = "rbxassetid://81287373353221",
		["bicycleCircle"] = "rbxassetid://101135313427799",
		["bicycleCircleFill"] = "rbxassetid://123710817001547",
		["bicycleSensorTagRadiowavesLeftAndRight"] = "rbxassetid://85373873458550",
		["bicycleSensorTagRadiowavesLeftAndRightFill"] = "rbxassetid://92824033944913",
		["binoculars"] = "rbxassetid://82003982039983",
		["binocularsCircle"] = "rbxassetid://74444046694959",
		["binocularsCircleFill"] = "rbxassetid://105266215858774",
		["binocularsFill"] = "rbxassetid://80941766165614",
		["bird"] = "rbxassetid://130275772797284",
		["birdCircle"] = "rbxassetid://103178316855292",
		["birdCircleFill"] = "rbxassetid://117217024861213",
		["birdFill"] = "rbxassetid://106346146659683",
		["birthdayCake"] = "rbxassetid://109061723759610",
		["birthdayCakeFill"] = "rbxassetid://126609361495378",
		["bitcoinsign"] = "rbxassetid://85045716322963",
		["bitcoinsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://139903362520300",
		["bitcoinsignBankBuilding"] = "rbxassetid://100134569219475",
		["bitcoinsignBankBuildingFill"] = "rbxassetid://130799347858075",
		["bitcoinsignCircle"] = "rbxassetid://129872062077257",
		["bitcoinsignCircleFill"] = "rbxassetid://125803775641316",
		["bitcoinsignGaugeChartLefthalfRighthalf"] = "rbxassetid://86873732275506",
		["bitcoinsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://85495972134697",
		["bitcoinsignRing"] = "rbxassetid://128221652848711",
		["bitcoinsignRingDashed"] = "rbxassetid://71179864949845",
		["bitcoinsignSquare"] = "rbxassetid://135576039906233",
		["bitcoinsignSquareFill"] = "rbxassetid://120728418357680",
		["blindsHorizontalClosed"] = "rbxassetid://101420800756552",
		["blindsHorizontalOpen"] = "rbxassetid://129804746319995",
		["blindsVerticalClosed"] = "rbxassetid://107585669625798",
		["blindsVerticalOpen"] = "rbxassetid://133263406766885",
		["bloodPressureCuff"] = "rbxassetid://121817772408929",
		["bloodPressureCuffBadgeGaugeWithNeedle"] = "rbxassetid://84032836703049",
		["bloodPressureCuffBadgeGaugeWithNeedleFill"] = "rbxassetid://124578156567435",
		["bloodPressureCuffFill"] = "rbxassetid://107378979484859",
		["bold"] = "rbxassetid://103508086257150",
		["boldItalicUnderline"] = "rbxassetid://125199208998114",
		["boldUnderline"] = "rbxassetid://77310772877118",
		["bolt"] = "rbxassetid://112193227421813",
		["boltBadgeAutomatic"] = "rbxassetid://122112691291736",
		["boltBadgeAutomaticFill"] = "rbxassetid://140324573909470",
		["boltBadgeCheckmark"] = "rbxassetid://99899769150346",
		["boltBadgeCheckmarkFill"] = "rbxassetid://127797181436416",
		["boltBadgeClock"] = "rbxassetid://99768130135511",
		["boltBadgeClockFill"] = "rbxassetid://91456545149386",
		["boltBadgeXmark"] = "rbxassetid://94502185545264",
		["boltBadgeXmarkFill"] = "rbxassetid://91288260823755",
		["boltBatteryblock"] = "rbxassetid://91868076624899",
		["boltBatteryblockFill"] = "rbxassetid://133692683566130",
		["boltBrakesignal"] = "rbxassetid://73920694387621",
		["boltCar"] = "rbxassetid://125466798838914",
		["boltCarCircle"] = "rbxassetid://116306626599658",
		["boltCarCircleFill"] = "rbxassetid://101258013169069",
		["boltCarFill"] = "rbxassetid://114448131958206",
		["boltCircle"] = "rbxassetid://87781552660597",
		["boltCircleFill"] = "rbxassetid://131576589857912",
		["boltFill"] = "rbxassetid://71909592017771",
		["boltHeart"] = "rbxassetid://110674472844382",
		["boltHeartFill"] = "rbxassetid://87457386765556",
		["boltHorizontal"] = "rbxassetid://78421984366839",
		["boltHorizontalCircle"] = "rbxassetid://86052284804870",
		["boltHorizontalCircleFill"] = "rbxassetid://82912063382135",
		["boltHorizontalFill"] = "rbxassetid://89554007915579",
		["boltHorizontalIcloud"] = "rbxassetid://76349290026078",
		["boltHorizontalIcloudFill"] = "rbxassetid://119816421830601",
		["boltHouse"] = "rbxassetid://125087333698100",
		["boltHouseFill"] = "rbxassetid://97212832287617",
		["boltRingClosed"] = "rbxassetid://102748200499647",
		["boltShield"] = "rbxassetid://106576035322524",
		["boltShieldFill"] = "rbxassetid://82704335162541",
		["boltSlash"] = "rbxassetid://115719946769678",
		["boltSlashCircle"] = "rbxassetid://92077287655944",
		["boltSlashCircleFill"] = "rbxassetid://83130112629665",
		["boltSlashFill"] = "rbxassetid://107794328445914",
		["boltSquare"] = "rbxassetid://74864226733346",
		["boltSquareFill"] = "rbxassetid://111594600812914",
		["boltTrianglebadgeExclamationmark"] = "rbxassetid://135701608670001",
		["boltTrianglebadgeExclamationmarkFill"] = "rbxassetid://80426096092615",
		["bonjour"] = "rbxassetid://96862684647565",
		["book"] = "rbxassetid://99242168701957",
		["bookAndWrench"] = "rbxassetid://105806071385897",
		["bookAndWrenchFill"] = "rbxassetid://127213912485879",
		["bookBadgePlus"] = "rbxassetid://139444923393735",
		["bookBadgePlusFill"] = "rbxassetid://110708660617586",
		["bookCircle"] = "rbxassetid://72975429086279",
		["bookCircleFill"] = "rbxassetid://122835733327171",
		["bookClosed"] = "rbxassetid://102863733968191",
		["bookClosedCircle"] = "rbxassetid://114853803855969",
		["bookClosedCircleFill"] = "rbxassetid://85473630292871",
		["bookClosedFill"] = "rbxassetid://94972983718665",
		["bookFill"] = "rbxassetid://80798326864179",
		["bookPages"] = "rbxassetid://118964813491987",
		["bookPagesFill"] = "rbxassetid://106380748151373",
		["bookmark"] = "rbxassetid://74160648747460",
		["bookmarkCircle"] = "rbxassetid://88464339450728",
		["bookmarkCircleFill"] = "rbxassetid://116856497843645",
		["bookmarkFill"] = "rbxassetid://98979837416554",
		["bookmarkSlash"] = "rbxassetid://130159878454862",
		["bookmarkSlashFill"] = "rbxassetid://108272977689020",
		["bookmarkSquare"] = "rbxassetid://111204770836057",
		["bookmarkSquareFill"] = "rbxassetid://94388247283473",
		["booksVertical"] = "rbxassetid://131690780604844",
		["booksVerticalCircle"] = "rbxassetid://120107789999419",
		["booksVerticalCircleFill"] = "rbxassetid://102387103871516",
		["booksVerticalFill"] = "rbxassetid://118674063613880",
		["brain"] = "rbxassetid://113890207183352",
		["brainFill"] = "rbxassetid://73855894967261",
		["brainFilledHeadProfile"] = "rbxassetid://116245786010931",
		["brainHeadProfile"] = "rbxassetid://101188959120090",
		["brainHeadProfileFill"] = "rbxassetid://82786960924872",
		["brakesignal"] = "rbxassetid://119179613669128",
		["brakesignalDashed"] = "rbxassetid://129497081013961",
		["brazilianrealsign"] = "rbxassetid://126167651986830",
		["brazilianrealsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://101075452345166",
		["brazilianrealsignBankBuilding"] = "rbxassetid://98973047591934",
		["brazilianrealsignBankBuildingFill"] = "rbxassetid://75511426648552",
		["brazilianrealsignCircle"] = "rbxassetid://97704351842459",
		["brazilianrealsignCircleFill"] = "rbxassetid://78800068933179",
		["brazilianrealsignGaugeChartLefthalfRighthalf"] = "rbxassetid://81631327262795",
		["brazilianrealsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://127207787907253",
		["brazilianrealsignRing"] = "rbxassetid://74080520557295",
		["brazilianrealsignRingDashed"] = "rbxassetid://95538915598421",
		["brazilianrealsignSquare"] = "rbxassetid://125151718943130",
		["brazilianrealsignSquareFill"] = "rbxassetid://103532987773414",
		["briefcase"] = "rbxassetid://76302379241787",
		["briefcaseCircle"] = "rbxassetid://110072070889487",
		["briefcaseCircleFill"] = "rbxassetid://131985436861601",
		["briefcaseFill"] = "rbxassetid://103653061652865",
		["briefcaseSensorTagRadiowavesLeftAndRight"] = "rbxassetid://78511981305968",
		["briefcaseSensorTagRadiowavesLeftAndRightFill"] = "rbxassetid://79579810164856",
		["bubble"] = "rbxassetid://77226486416802",
		["bubbleAndPencil"] = "rbxassetid://80256643483910",
		["bubbleCircle"] = "rbxassetid://125219383982550",
		["bubbleCircleFill"] = "rbxassetid://109761907896649",
		["bubbleFill"] = "rbxassetid://80953989271043",
		["bubbleLeft"] = "rbxassetid://98539019826711",
		["bubbleLeftAndBubbleRight"] = "rbxassetid://81405663217056",
		["bubbleLeftAndBubbleRightFill"] = "rbxassetid://102654503925514",
		["bubbleLeftAndExclamationmarkBubbleRight"] = "rbxassetid://89966432584239",
		["bubbleLeftAndExclamationmarkBubbleRightFill"] = "rbxassetid://134483997334229",
		["bubbleLeftAndTextBubbleRight"] = "rbxassetid://132793650670374",
		["bubbleLeftAndTextBubbleRightFill"] = "rbxassetid://74625622843211",
		["bubbleLeftCircle"] = "rbxassetid://123298231169447",
		["bubbleLeftCircleFill"] = "rbxassetid://80558763328280",
		["bubbleLeftFill"] = "rbxassetid://118600153442100",
		["bubbleMiddleBottom"] = "rbxassetid://95146405413872",
		["bubbleMiddleBottomFill"] = "rbxassetid://88431074400146",
		["bubbleMiddleTop"] = "rbxassetid://103163735052752",
		["bubbleMiddleTopFill"] = "rbxassetid://74247184833387",
		["bubbleRight"] = "rbxassetid://109759263505956",
		["bubbleRightCircle"] = "rbxassetid://100274251581597",
		["bubbleRightCircleFill"] = "rbxassetid://84058503436916",
		["bubbleRightFill"] = "rbxassetid://118519568619648",
		["bubblesAndSparkles"] = "rbxassetid://106193796714647",
		["bubblesAndSparklesFill"] = "rbxassetid://85576812393251",
		["building"] = "rbxassetid://80702293989084",
		["building2"] = "rbxassetid://135138223013381",
		["building2CropCircle"] = "rbxassetid://115503248658638",
		["building2CropCircleFill"] = "rbxassetid://112598319040010",
		["building2Fill"] = "rbxassetid://113360848137363",
		["buildingColumns"] = "rbxassetid://86341549293525",
		["buildingColumnsCircle"] = "rbxassetid://89771684145053",
		["buildingColumnsCircleFill"] = "rbxassetid://140466597342735",
		["buildingColumnsFill"] = "rbxassetid://135456938295031",
		["buildingFill"] = "rbxassetid://118070055554916",
		["burn"] = "rbxassetid://100741266216840",
		["burst"] = "rbxassetid://138219935094738",
		["burstFill"] = "rbxassetid://90039414124678",
		["bus"] = "rbxassetid://132462958646640",
		["busDoubledecker"] = "rbxassetid://112589463325662",
		["busDoubledeckerFill"] = "rbxassetid://71921128889600",
		["busFill"] = "rbxassetid://116866000758003",
		["buttonAngledbottomHorizontalLeft"] = "rbxassetid://87772134018393",
		["buttonAngledbottomHorizontalLeftFill"] = "rbxassetid://123942133715172",
		["buttonAngledbottomHorizontalRight"] = "rbxassetid://113637188276134",
		["buttonAngledbottomHorizontalRightFill"] = "rbxassetid://103324610775001",
		["buttonAngledtopVerticalLeft"] = "rbxassetid://127310958476000",
		["buttonAngledtopVerticalLeftFill"] = "rbxassetid://124737537456377",
		["buttonAngledtopVerticalRight"] = "rbxassetid://72737180265307",
		["buttonAngledtopVerticalRightFill"] = "rbxassetid://102557397415618",
		["buttonHorizontal"] = "rbxassetid://89869433999115",
		["buttonHorizontalFill"] = "rbxassetid://94554169943088",
		["buttonHorizontalTopPress"] = "rbxassetid://79953223577947",
		["buttonHorizontalTopPressFill"] = "rbxassetid://132950668501139",
		["buttonProgrammable"] = "rbxassetid://115802779906954",
		["buttonProgrammableSquare"] = "rbxassetid://128948305769440",
		["buttonProgrammableSquareFill"] = "rbxassetid://107393189633512",
		["buttonRoundedbottomHorizontal"] = "rbxassetid://139688387647553",
		["buttonRoundedbottomHorizontalFill"] = "rbxassetid://88109415580290",
		["buttonRoundedtopHorizontal"] = "rbxassetid://87461059045784",
		["buttonRoundedtopHorizontalFill"] = "rbxassetid://84354403826885",
		["buttonVerticalLeftPress"] = "rbxassetid://71757710227477",
		["buttonVerticalLeftPressFill"] = "rbxassetid://93218303828413",
		["buttonVerticalRightPress"] = "rbxassetid://78432364933892",
		["buttonVerticalRightPressFill"] = "rbxassetid://91015801699440",
		["cCircle"] = "rbxassetid://139431771360926",
		["cCircleFill"] = "rbxassetid://105086158279600",
		["cSquare"] = "rbxassetid://86392562689553",
		["cSquareFill"] = "rbxassetid://118810898759104",
		["cabinet"] = "rbxassetid://117939109046665",
		["cabinetFill"] = "rbxassetid://87496272804280",
		["cableCoaxial"] = "rbxassetid://126480673488003",
		["cableConnector"] = "rbxassetid://76793572656021",
		["cableConnectorHorizontal"] = "rbxassetid://128003436998791",
		["cableConnectorSlash"] = "rbxassetid://138009988511903",
		["cableConnectorVideo"] = "rbxassetid://81787685713406",
		["cablecar"] = "rbxassetid://84703971212857",
		["cablecarFill"] = "rbxassetid://81461389662851",
		["calendar"] = "rbxassetid://105164540641328",
		["calendarAndPerson"] = "rbxassetid://118740780914749",
		["calendarBadge"] = "rbxassetid://130252787898462",
		["calendarBadgeCheckmark"] = "rbxassetid://89365467298075",
		["calendarBadgeClock"] = "rbxassetid://113445508292256",
		["calendarBadgeExclamationmark"] = "rbxassetid://91916369222792",
		["calendarBadgeLock"] = "rbxassetid://118756663428958",
		["calendarBadgeMinus"] = "rbxassetid://82308953693338",
		["calendarBadgePlus"] = "rbxassetid://99904240335802",
		["calendarCircle"] = "rbxassetid://97923261201903",
		["calendarCircleFill"] = "rbxassetid://134415097437184",
		["calendarDayTimelineLeading"] = "rbxassetid://92071534684267",
		["calendarDayTimelineLeadingCircle"] = "rbxassetid://123786645364610",
		["calendarDayTimelineLeadingCircleFill"] = "rbxassetid://95263183942485",
		["calendarDayTimelineLeft"] = "rbxassetid://140736157337049",
		["calendarDayTimelineLeftCircle"] = "rbxassetid://128152730753180",
		["calendarDayTimelineLeftCircleFill"] = "rbxassetid://101649394856316",
		["calendarDayTimelineRight"] = "rbxassetid://81354582567686",
		["calendarDayTimelineRightCircle"] = "rbxassetid://106345972168826",
		["calendarDayTimelineRightCircleFill"] = "rbxassetid://78552056440331",
		["calendarDayTimelineTrailing"] = "rbxassetid://98699864273977",
		["calendarDayTimelineTrailingCircle"] = "rbxassetid://106989432306674",
		["calendarDayTimelineTrailingCircleFill"] = "rbxassetid://84897746955767",
		["camera"] = "rbxassetid://106049677807210",
		["cameraAperture"] = "rbxassetid://93748886326097",
		["cameraBadgeClock"] = "rbxassetid://96954869359913",
		["cameraBadgeClockFill"] = "rbxassetid://129572022257677",
		["cameraBadgeEllipsis"] = "rbxassetid://84933908741123",
		["cameraBadgeEllipsisFill"] = "rbxassetid://102950043916587",
		["cameraCircle"] = "rbxassetid://136575450217928",
		["cameraCircleFill"] = "rbxassetid://132722961016601",
		["cameraFill"] = "rbxassetid://105791547551825",
		["cameraFilters"] = "rbxassetid://132438444257023",
		["cameraMacro"] = "rbxassetid://90308044332993",
		["cameraMacroCircle"] = "rbxassetid://96744154304790",
		["cameraMacroCircleFill"] = "rbxassetid://78401776068992",
		["cameraMacroSlash"] = "rbxassetid://125432490230233",
		["cameraMacroSlashCircle"] = "rbxassetid://124019357928403",
		["cameraMacroSlashCircleFill"] = "rbxassetid://79452825367107",
		["cameraMeteringCenterWeighted"] = "rbxassetid://105415399925912",
		["cameraMeteringCenterWeightedAverage"] = "rbxassetid://124373772637912",
		["cameraMeteringMatrix"] = "rbxassetid://72423091421429",
		["cameraMeteringMultispot"] = "rbxassetid://101264837387232",
		["cameraMeteringNone"] = "rbxassetid://108629649478914",
		["cameraMeteringPartial"] = "rbxassetid://136722268952658",
		["cameraMeteringSpot"] = "rbxassetid://131415808991981",
		["cameraMeteringUnknown"] = "rbxassetid://103791550705277",
		["cameraOnRectangle"] = "rbxassetid://113075184701608",
		["cameraOnRectangleFill"] = "rbxassetid://136334711835785",
		["cameraSensorTagRadiowavesLeftAndRight"] = "rbxassetid://124176766677378",
		["cameraSensorTagRadiowavesLeftAndRightFill"] = "rbxassetid://75632082063593",
		["cameraShutterButton"] = "rbxassetid://90456792215761",
		["cameraShutterButtonFill"] = "rbxassetid://84963312707697",
		["cameraViewfinder"] = "rbxassetid://85257199196973",
		["candybarphone"] = "rbxassetid://91875463862137",
		["capslock"] = "rbxassetid://129510873768204",
		["capslockFill"] = "rbxassetid://74070850671559",
		["capsule"] = "rbxassetid://81831381214147",
		["capsuleBottomhalfFilled"] = "rbxassetid://79711489491632",
		["capsuleFill"] = "rbxassetid://101969240257558",
		["capsuleLefthalfFilled"] = "rbxassetid://120935640012724",
		["capsuleOnCapsule"] = "rbxassetid://125962363774490",
		["capsuleOnCapsuleFill"] = "rbxassetid://85499949727796",
		["capsuleOnRectangle"] = "rbxassetid://95040820166081",
		["capsuleOnRectangleFill"] = "rbxassetid://105770621396050",
		["capsulePortrait"] = "rbxassetid://99642816241588",
		["capsulePortraitBottomhalfFilled"] = "rbxassetid://101845181967705",
		["capsulePortraitFill"] = "rbxassetid://134018743561010",
		["capsulePortraitLefthalfFilled"] = "rbxassetid://89543355365748",
		["capsulePortraitRighthalfFilled"] = "rbxassetid://83813796130615",
		["capsulePortraitTophalfFilled"] = "rbxassetid://122165531810954",
		["capsuleRighthalfFilled"] = "rbxassetid://75406213303179",
		["capsuleTophalfFilled"] = "rbxassetid://117681415719315",
		["captionsBubble"] = "rbxassetid://117417929637325",
		["captionsBubbleFill"] = "rbxassetid://131809011691174",
		["car"] = "rbxassetid://128495454882226",
		["car2"] = "rbxassetid://97578883834004",
		["car2Fill"] = "rbxassetid://133721936830795",
		["carBadgeGearshape"] = "rbxassetid://121514836966717",
		["carBadgeGearshapeFill"] = "rbxassetid://94538505333092",
		["carCircle"] = "rbxassetid://93535532040070",
		["carCircleFill"] = "rbxassetid://116413251835553",
		["carFerry"] = "rbxassetid://126066171893470",
		["carFerryFill"] = "rbxassetid://115970310065091",
		["carFill"] = "rbxassetid://120157979001146",
		["carFrontWavesDown"] = "rbxassetid://73974605458298",
		["carFrontWavesDownFill"] = "rbxassetid://112916365434291",
		["carFrontWavesLeftAndRightAndUp"] = "rbxassetid://93776100100461",
		["carFrontWavesLeftAndRightAndUpFill"] = "rbxassetid://100684279352347",
		["carFrontWavesUp"] = "rbxassetid://95563447987178",
		["carFrontWavesUpFill"] = "rbxassetid://113013581989612",
		["carRear"] = "rbxassetid://106736790731856",
		["carRearAndCollisionRoadLane"] = "rbxassetid://73279442408907",
		["carRearAndCollisionRoadLaneSlash"] = "rbxassetid://89753862961614",
		["carRearAndTireMarks"] = "rbxassetid://90284918615637",
		["carRearAndTireMarksOff"] = "rbxassetid://121559243559396",
		["carRearAndTireMarksSlash"] = "rbxassetid://133003297173007",
		["carRearFill"] = "rbxassetid://94875494313831",
		["carRearHazardsign"] = "rbxassetid://81176038582242",
		["carRearHazardsignFill"] = "rbxassetid://118042380942420",
		["carRearRoadLane"] = "rbxassetid://106146900593351",
		["carRearRoadLaneDashed"] = "rbxassetid://72003677424945",
		["carRearRoadLaneDashedArrowtriangle2Outward"] = "rbxassetid://131007235242118",
		["carRearRoadLaneDistance1"] = "rbxassetid://127940734523444",
		["carRearRoadLaneDistance1AndGaugeOpenWithLinesNeedle67percentAndArrowtriangle"] = "rbxassetid://94334222817359",
		["carRearRoadLaneDistance2"] = "rbxassetid://71174865675916",
		["carRearRoadLaneDistance2AndGaugeOpenWithLinesNeedle67percentAndArrowtriangle"] = "rbxassetid://119164907256182",
		["carRearRoadLaneDistance3"] = "rbxassetid://135647159201253",
		["carRearRoadLaneDistance3AndGaugeOpenWithLinesNeedle67percentAndArrowtriangle"] = "rbxassetid://76305713845211",
		["carRearRoadLaneDistance4"] = "rbxassetid://102603761274028",
		["carRearRoadLaneDistance4AndGaugeOpenWithLinesNeedle67percentAndArrowtriangle"] = "rbxassetid://105468736067403",
		["carRearRoadLaneDistance5"] = "rbxassetid://112963693265764",
		["carRearRoadLaneDistance5AndGaugeOpenWithLinesNeedle67percentAndArrowtriangle"] = "rbxassetid://107369882581908",
		["carRearRoadLaneOff"] = "rbxassetid://109767288290225",
		["carRearRoadLaneWaveUp"] = "rbxassetid://100245066913455",
		["carRearTiltRoadLanesCurvedRight"] = "rbxassetid://127430126262647",
		["carRearWavesUp"] = "rbxassetid://129534910434287",
		["carRearWavesUpFill"] = "rbxassetid://132630790194670",
		["carSide"] = "rbxassetid://123727230876023",
		["carSideAirCirculate"] = "rbxassetid://129819788394181",
		["carSideAirCirculateFill"] = "rbxassetid://84434233331006",
		["carSideAirFresh"] = "rbxassetid://96826195272673",
		["carSideAirFreshFill"] = "rbxassetid://119969844288900",
		["carSideAndExclamationmark"] = "rbxassetid://131867351843012",
		["carSideAndExclamationmarkFill"] = "rbxassetid://114889185254237",
		["carSideArrowLeftAndRight"] = "rbxassetid://132025369793047",
		["carSideArrowLeftAndRightFill"] = "rbxassetid://114322757158315",
		["carSideArrowtriangleDown"] = "rbxassetid://70559673683673",
		["carSideArrowtriangleDownFill"] = "rbxassetid://123699022550270",
		["carSideArrowtriangleUp"] = "rbxassetid://86416823330109",
		["carSideArrowtriangleUpArrowtriangleDown"] = "rbxassetid://136484069843029",
		["carSideArrowtriangleUpArrowtriangleDownFill"] = "rbxassetid://112039352485090",
		["carSideArrowtriangleUpFill"] = "rbxassetid://101950075430741",
		["carSideFill"] = "rbxassetid://134365111379084",
		["carSideFrontOpen"] = "rbxassetid://113954965550455",
		["carSideFrontOpenCrop"] = "rbxassetid://82479251905391",
		["carSideFrontOpenCropFill"] = "rbxassetid://104032074636855",
		["carSideFrontOpenFill"] = "rbxassetid://84063705179151",
		["carSideHillDescentControl"] = "rbxassetid://134307743041436",
		["carSideHillDescentControlFill"] = "rbxassetid://70571506563107",
		["carSideHillDown"] = "rbxassetid://127663646775564",
		["carSideHillDownAndGaugeOpenWithLinesNeedle25percentAndArrowtriangle"] = "rbxassetid://135438547755627",
		["carSideHillDownAndGaugeOpenWithLinesNeedle25percentAndArrowtriangleFill"] = "rbxassetid://126863447170500",
		["carSideHillDownFill"] = "rbxassetid://123845478959576",
		["carSideHillUp"] = "rbxassetid://85662738311671",
		["carSideHillUpFill"] = "rbxassetid://137182275581929",
		["carSideLock"] = "rbxassetid://89133577708824",
		["carSideLockFill"] = "rbxassetid://139374257452667",
		["carSideLockOpen"] = "rbxassetid://73799606963227",
		["carSideLockOpenFill"] = "rbxassetid://113815388443315",
		["carSideRearAndCollisionAndCarSideFront"] = "rbxassetid://99933366959957",
		["carSideRearAndCollisionAndCarSideFrontAndArrowForward"] = "rbxassetid://131674539097286",
		["carSideRearAndCollisionAndCarSideFrontAndSteeringwheel"] = "rbxassetid://95675889148537",
		["carSideRearAndCollisionAndCarSideFrontSlash"] = "rbxassetid://126195085802057",
		["carSideRearAndExclamationmarkAndCarSideFront"] = "rbxassetid://140644239188800",
		["carSideRearAndExclamationmarkAndCarSideFrontOff"] = "rbxassetid://138499860628048",
		["carSideRearAndWave3AndCarSideFront"] = "rbxassetid://71923913494011",
		["carSideRearCropTrunkPartition"] = "rbxassetid://84550560822967",
		["carSideRearCropTrunkPartitionFill"] = "rbxassetid://123573397918828",
		["carSideRearOpen"] = "rbxassetid://88012230238253",
		["carSideRearOpenCrop"] = "rbxassetid://129882870954526",
		["carSideRearOpenCropFill"] = "rbxassetid://126796702854347",
		["carSideRearOpenFill"] = "rbxassetid://86788038143818",
		["carSideRearTowHitch"] = "rbxassetid://134168233048942",
		["carSideRearTowHitchFill"] = "rbxassetid://86801046249588",
		["carSideRoofCargoCarrier"] = "rbxassetid://104771078663560",
		["carSideRoofCargoCarrierFill"] = "rbxassetid://90138154580521",
		["carSideRoofCargoCarrierSlash"] = "rbxassetid://138727479392520",
		["carSideRoofCargoCarrierSlashFill"] = "rbxassetid://92406618590649",
		["carTopArrowtriangleFrontLeft"] = "rbxassetid://123222259486467",
		["carTopArrowtriangleFrontLeftFill"] = "rbxassetid://84759596863076",
		["carTopArrowtriangleFrontRight"] = "rbxassetid://117838105385476",
		["carTopArrowtriangleFrontRightFill"] = "rbxassetid://92362685636289",
		["carTopArrowtriangleRearLeft"] = "rbxassetid://73954649933688",
		["carTopArrowtriangleRearLeftFill"] = "rbxassetid://132436036528631",
		["carTopArrowtriangleRearRight"] = "rbxassetid://78772570541846",
		["carTopArrowtriangleRearRightFill"] = "rbxassetid://108137783518479",
		["carTopDoorFrontLeftAndFrontRightAndRearLeftAndRearRightOpen"] = "rbxassetid://80363013214098",
		["carTopDoorFrontLeftAndFrontRightAndRearLeftAndRearRightOpenFill"] = "rbxassetid://108894171052291",
		["carTopDoorFrontLeftAndFrontRightAndRearLeftOpen"] = "rbxassetid://123212226339031",
		["carTopDoorFrontLeftAndFrontRightAndRearLeftOpenFill"] = "rbxassetid://101562090992305",
		["carTopDoorFrontLeftAndFrontRightAndRearRightOpen"] = "rbxassetid://110631034665291",
		["carTopDoorFrontLeftAndFrontRightAndRearRightOpenFill"] = "rbxassetid://139873570903173",
		["carTopDoorFrontLeftAndFrontRightOpen"] = "rbxassetid://74788648223269",
		["carTopDoorFrontLeftAndFrontRightOpenFill"] = "rbxassetid://86215017441713",
		["carTopDoorFrontLeftAndRearLeftAndRearRightOpen"] = "rbxassetid://131484052357343",
		["carTopDoorFrontLeftAndRearLeftAndRearRightOpenFill"] = "rbxassetid://89363125622972",
		["carTopDoorFrontLeftAndRearLeftOpen"] = "rbxassetid://136031029179173",
		["carTopDoorFrontLeftAndRearLeftOpenFill"] = "rbxassetid://137046170507650",
		["carTopDoorFrontLeftAndRearRightOpen"] = "rbxassetid://87031066098040",
		["carTopDoorFrontLeftAndRearRightOpenFill"] = "rbxassetid://128332791898221",
		["carTopDoorFrontLeftOpen"] = "rbxassetid://81445878346757",
		["carTopDoorFrontLeftOpenFill"] = "rbxassetid://109057462580081",
		["carTopDoorFrontRightAndRearLeftAndRearRightOpen"] = "rbxassetid://78018818420040",
		["carTopDoorFrontRightAndRearLeftAndRearRightOpenFill"] = "rbxassetid://84749548678375",
		["carTopDoorFrontRightAndRearLeftOpen"] = "rbxassetid://120269651846295",
		["carTopDoorFrontRightAndRearLeftOpenFill"] = "rbxassetid://78066029950386",
		["carTopDoorFrontRightAndRearRightOpen"] = "rbxassetid://70567122240859",
		["carTopDoorFrontRightAndRearRightOpenFill"] = "rbxassetid://116264095664357",
		["carTopDoorFrontRightOpen"] = "rbxassetid://97417623414623",
		["carTopDoorFrontRightOpenFill"] = "rbxassetid://84331480606171",
		["carTopDoorRearLeftAndRearRightOpen"] = "rbxassetid://89308026145118",
		["carTopDoorRearLeftAndRearRightOpenFill"] = "rbxassetid://110224159210139",
		["carTopDoorRearLeftOpen"] = "rbxassetid://117679988412307",
		["carTopDoorRearLeftOpenFill"] = "rbxassetid://103275469741774",
		["carTopDoorRearRightOpen"] = "rbxassetid://134727516346244",
		["carTopDoorRearRightOpenFill"] = "rbxassetid://76042471844419",
		["carTopDoorSlidingLeftOpen"] = "rbxassetid://114193700451377",
		["carTopDoorSlidingLeftOpenFill"] = "rbxassetid://88845688904454",
		["carTopDoorSlidingRightOpen"] = "rbxassetid://125155196045524",
		["carTopDoorSlidingRightOpenFill"] = "rbxassetid://90631209953802",
		["carTopFrontRadiowavesFrontLeftAndFrontAndFrontRight"] = "rbxassetid://116813641912560",
		["carTopFrontRadiowavesFrontLeftAndFrontAndFrontRightFill"] = "rbxassetid://99204992957472",
		["carTopFrontleftArrowtriangle"] = "rbxassetid://74249929591233",
		["carTopFrontrightArrowtriangle"] = "rbxassetid://109439050535736",
		["carTopLaneDashedArrowtriangleInward"] = "rbxassetid://111343898744983",
		["carTopLaneDashedArrowtriangleInwardFill"] = "rbxassetid://75649906069159",
		["carTopLaneDashedBadgeSteeringwheel"] = "rbxassetid://109175591331591",
		["carTopLaneDashedBadgeSteeringwheelFill"] = "rbxassetid://99737560328566",
		["carTopLaneDashedDepartureLeft"] = "rbxassetid://105946066504996",
		["carTopLaneDashedDepartureLeftFill"] = "rbxassetid://133030233235812",
		["carTopLaneDashedDepartureLeftSlash"] = "rbxassetid://102591664146154",
		["carTopLaneDashedDepartureLeftSlashFill"] = "rbxassetid://134823708023730",
		["carTopLaneDashedDepartureRight"] = "rbxassetid://128417056182752",
		["carTopLaneDashedDepartureRightFill"] = "rbxassetid://117041928860784",
		["carTopLaneDashedDepartureRightSlash"] = "rbxassetid://118261490125488",
		["carTopLaneDashedDepartureRightSlashFill"] = "rbxassetid://130656050187719",
		["carTopRadiowaves2FrontLeftFrontFrontRight"] = "rbxassetid://95526058568755",
		["carTopRadiowaves2FrontLeftFrontFrontRightFill"] = "rbxassetid://77293070849440",
		["carTopRadiowaves2RearLeftRearRearRight"] = "rbxassetid://115935038426649",
		["carTopRadiowaves2RearLeftRearRearRightFill"] = "rbxassetid://82056639801498",
		["carTopRadiowavesFront"] = "rbxassetid://133607318826630",
		["carTopRadiowavesFrontFill"] = "rbxassetid://81383834313147",
		["carTopRadiowavesRear"] = "rbxassetid://125297507525835",
		["carTopRadiowavesRearFill"] = "rbxassetid://78203718067568",
		["carTopRadiowavesRearLeft"] = "rbxassetid://80414529165992",
		["carTopRadiowavesRearLeftAndRearRight"] = "rbxassetid://106289875711195",
		["carTopRadiowavesRearLeftAndRearRightFill"] = "rbxassetid://105696129533991",
		["carTopRadiowavesRearLeftCarTopFront"] = "rbxassetid://76064734358653",
		["carTopRadiowavesRearLeftCarTopFrontFill"] = "rbxassetid://97770197457840",
		["carTopRadiowavesRearLeftFill"] = "rbxassetid://108315739511697",
		["carTopRadiowavesRearRight"] = "rbxassetid://75242343694458",
		["carTopRadiowavesRearRightBadgeExclamationmark"] = "rbxassetid://139745112794803",
		["carTopRadiowavesRearRightBadgeExclamationmarkFill"] = "rbxassetid://83075965159111",
		["carTopRadiowavesRearRightBadgeXmark"] = "rbxassetid://123230437909232",
		["carTopRadiowavesRearRightBadgeXmarkFill"] = "rbxassetid://70407895765158",
		["carTopRadiowavesRearRightCarTopFront"] = "rbxassetid://131947111049560",
		["carTopRadiowavesRearRightCarTopFrontFill"] = "rbxassetid://72077613330190",
		["carTopRadiowavesRearRightFill"] = "rbxassetid://88012174287090",
		["carTopRearRadiowavesRearLeftAndRearAndRearRight"] = "rbxassetid://88120058138309",
		["carTopRearRadiowavesRearLeftAndRearAndRearRightFill"] = "rbxassetid://73216347350191",
		["carTopRearleftArrowtriangle"] = "rbxassetid://132477167189845",
		["carTopRearrightArrowtriangle"] = "rbxassetid://121164497326761",
		["carTopVideoRearLeft"] = "rbxassetid://72271021597106",
		["carTopVideoRearLeftFill"] = "rbxassetid://71654523784960",
		["carTopVideoRearRight"] = "rbxassetid://114116872591998",
		["carTopVideoRearRightFill"] = "rbxassetid://137959831857002",
		["carWindowLeft"] = "rbxassetid://86756481448690",
		["carWindowLeftBadgeExclamationmark"] = "rbxassetid://128521824982284",
		["carWindowLeftBadgeLock"] = "rbxassetid://74945260791121",
		["carWindowLeftBadgeXmark"] = "rbxassetid://126631257556393",
		["carWindowLeftExclamationmark"] = "rbxassetid://73994718634793",
		["carWindowLeftXmark"] = "rbxassetid://99106662522022",
		["carWindowRight"] = "rbxassetid://95397796099425",
		["carWindowRightBadgeExclamationmark"] = "rbxassetid://137691133108353",
		["carWindowRightBadgeLock"] = "rbxassetid://109825199930596",
		["carWindowRightBadgeXmark"] = "rbxassetid://113338395744934",
		["carWindowRightExclamationmark"] = "rbxassetid://98295643301246",
		["carWindowRightXmark"] = "rbxassetid://108600675223720",
		["carbonDioxideCloud"] = "rbxassetid://76366963920532",
		["carbonDioxideCloudFill"] = "rbxassetid://134345598862121",
		["carbonMonoxideCloud"] = "rbxassetid://116628010954326",
		["carbonMonoxideCloudFill"] = "rbxassetid://108732016966215",
		["carrot"] = "rbxassetid://86588469030196",
		["carrotFill"] = "rbxassetid://117181669639260",
		["carseatLeft"] = "rbxassetid://92701856050395",
		["carseatLeft1"] = "rbxassetid://130693652944034",
		["carseatLeft1Fill"] = "rbxassetid://106012772377881",
		["carseatLeft2"] = "rbxassetid://97305403792548",
		["carseatLeft2Fill"] = "rbxassetid://85685205406693",
		["carseatLeft3"] = "rbxassetid://127225716289512",
		["carseatLeft3Fill"] = "rbxassetid://98079963311844",
		["carseatLeftAndHeatWaves"] = "rbxassetid://136058084732653",
		["carseatLeftAndHeatWavesFill"] = "rbxassetid://138059967999511",
		["carseatLeftBackrestUpAndDown"] = "rbxassetid://108455978558375",
		["carseatLeftBackrestUpAndDownFill"] = "rbxassetid://132193352969179",
		["carseatLeftFan"] = "rbxassetid://109491477716325",
		["carseatLeftFanFill"] = "rbxassetid://92653087286034",
		["carseatLeftFill"] = "rbxassetid://118896758627771",
		["carseatLeftForwardAndBackward"] = "rbxassetid://103737852803606",
		["carseatLeftForwardAndBackwardFill"] = "rbxassetid://80914430111661",
		["carseatLeftMassage"] = "rbxassetid://110277390360496",
		["carseatLeftMassageFill"] = "rbxassetid://113778384545082",
		["carseatLeftUpAndDown"] = "rbxassetid://139435554215192",
		["carseatLeftUpAndDownFill"] = "rbxassetid://93609533999754",
		["carseatRight"] = "rbxassetid://139995356802592",
		["carseatRight1"] = "rbxassetid://72264832504032",
		["carseatRight1Fill"] = "rbxassetid://137548535535010",
		["carseatRight2"] = "rbxassetid://125971106368177",
		["carseatRight2Fill"] = "rbxassetid://140561721922196",
		["carseatRight3"] = "rbxassetid://117423139105628",
		["carseatRight3Fill"] = "rbxassetid://92691917532826",
		["carseatRightAndHeatWaves"] = "rbxassetid://131216200983766",
		["carseatRightAndHeatWavesFill"] = "rbxassetid://135515163923925",
		["carseatRightBackrestUpAndDown"] = "rbxassetid://116883448300446",
		["carseatRightBackrestUpAndDownFill"] = "rbxassetid://110724862492710",
		["carseatRightFan"] = "rbxassetid://72695279927845",
		["carseatRightFanFill"] = "rbxassetid://136482229464042",
		["carseatRightFill"] = "rbxassetid://118564586970353",
		["carseatRightForwardAndBackward"] = "rbxassetid://133538142433603",
		["carseatRightForwardAndBackwardFill"] = "rbxassetid://130117771768091",
		["carseatRightMassage"] = "rbxassetid://97404558707824",
		["carseatRightMassageFill"] = "rbxassetid://124278125047452",
		["carseatRightUpAndDown"] = "rbxassetid://103900898320263",
		["carseatRightUpAndDownFill"] = "rbxassetid://81259033424146",
		["cart"] = "rbxassetid://120970975539765",
		["cartBadgeClock"] = "rbxassetid://121047592354792",
		["cartBadgeClockFill"] = "rbxassetid://108098854699224",
		["cartBadgeMinus"] = "rbxassetid://94921095508486",
		["cartBadgePlus"] = "rbxassetid://74497004572470",
		["cartBadgeQuestionmark"] = "rbxassetid://99604576439516",
		["cartCircle"] = "rbxassetid://74390949952121",
		["cartCircleFill"] = "rbxassetid://81723599390977",
		["cartFill"] = "rbxassetid://122095585357706",
		["cartFillBadgeMinus"] = "rbxassetid://78126067125241",
		["cartFillBadgePlus"] = "rbxassetid://109643096003552",
		["cartFillBadgeQuestionmark"] = "rbxassetid://96329797572754",
		["case"] = "rbxassetid://131671593455396",
		["caseFill"] = "rbxassetid://133667743842833",
		["caseGylph"] = "rbxassetid://72684442825623",
		["cat"] = "rbxassetid://76438043402065",
		["catCircle"] = "rbxassetid://125040552553301",
		["catCircleFill"] = "rbxassetid://105496505191189",
		["catFill"] = "rbxassetid://75596623477851",
		["cedisign"] = "rbxassetid://103299702073207",
		["cedisignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://110438377324030",
		["cedisignBankBuilding"] = "rbxassetid://94391063534756",
		["cedisignBankBuildingFill"] = "rbxassetid://98460480681983",
		["cedisignCircle"] = "rbxassetid://130372607949366",
		["cedisignCircleFill"] = "rbxassetid://92011821597293",
		["cedisignGaugeChartLefthalfRighthalf"] = "rbxassetid://130943895529460",
		["cedisignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://91190898873471",
		["cedisignRing"] = "rbxassetid://130183023961084",
		["cedisignRingDashed"] = "rbxassetid://107629417082778",
		["cedisignSquare"] = "rbxassetid://138180702536840",
		["cedisignSquareFill"] = "rbxassetid://111554398707505",
		["cellularbars"] = "rbxassetid://125832308574063",
		["cellularbarsCircle"] = "rbxassetid://106772243084439",
		["cellularbarsCircleFill"] = "rbxassetid://75137148416999",
		["centsign"] = "rbxassetid://105925251377949",
		["centsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://116762184007471",
		["centsignBankBuilding"] = "rbxassetid://97825181867350",
		["centsignBankBuildingFill"] = "rbxassetid://127430294496635",
		["centsignCircle"] = "rbxassetid://82940891704153",
		["centsignCircleFill"] = "rbxassetid://90090839272956",
		["centsignGaugeChartLefthalfRighthalf"] = "rbxassetid://114208104708871",
		["centsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://129300951818917",
		["centsignRing"] = "rbxassetid://140362456321464",
		["centsignRingDashed"] = "rbxassetid://74787978516657",
		["centsignSquare"] = "rbxassetid://111622219613255",
		["centsignSquareFill"] = "rbxassetid://124455198437315",
		["chair"] = "rbxassetid://81031147056732",
		["chairFill"] = "rbxassetid://104928042194690",
		["chairLounge"] = "rbxassetid://86782375467651",
		["chairLoungeFill"] = "rbxassetid://134838176918598",
		["chandelier"] = "rbxassetid://114256133376087",
		["chandelierFill"] = "rbxassetid://140034611273760",
		["character"] = "rbxassetid://70520208661164",
		["characterBookClosed"] = "rbxassetid://98811544621143",
		["characterBookClosedFill"] = "rbxassetid://106951098218047",
		["characterBubble"] = "rbxassetid://135972436057073",
		["characterBubbleFill"] = "rbxassetid://88670019070119",
		["characterCircle"] = "rbxassetid://120600115126394",
		["characterCircleFill"] = "rbxassetid://138588485044134",
		["characterCursorIbeam"] = "rbxassetid://70471184047263",
		["characterDuployan"] = "rbxassetid://126945262264539",
		["characterMagnify"] = "rbxassetid://93955130363457",
		["characterPhonetic"] = "rbxassetid://115826427725683",
		["characterSquare"] = "rbxassetid://74845204135026",
		["characterSquareFill"] = "rbxassetid://73662884801491",
		["characterSutton"] = "rbxassetid://80770715140920",
		["characterTextJustify"] = "rbxassetid://95949746183744",
		["characterTextbox"] = "rbxassetid://111364553064358",
		["characterTextboxBadgeSparkles"] = "rbxassetid://131808194478683",
		["charactersLowercase"] = "rbxassetid://88128764384529",
		["charactersUppercase"] = "rbxassetid://71028973098762",
		["chartBar"] = "rbxassetid://97312304809598",
		["chartBarDocHorizontal"] = "rbxassetid://88206449206082",
		["chartBarFill"] = "rbxassetid://71315621261538",
		["chartBarHorizontalPage"] = "rbxassetid://104809785659828",
		["chartBarHorizontalPageFill"] = "rbxassetid://79906850504673",
		["chartBarXaxis"] = "rbxassetid://70369400252147",
		["chartBarXaxisAscending"] = "rbxassetid://82359236009090",
		["chartBarXaxisAscendingBadgeClock"] = "rbxassetid://124185325005143",
		["chartBarXaxisDescending"] = "rbxassetid://133906778698960",
		["chartBarYaxis"] = "rbxassetid://99099708214794",
		["chartDotsScatter"] = "rbxassetid://121018735962977",
		["chartLineDowntrendXyaxis"] = "rbxassetid://72084011691095",
		["chartLineDowntrendXyaxisCircle"] = "rbxassetid://76215613064769",
		["chartLineDowntrendXyaxisCircleFill"] = "rbxassetid://138273764461717",
		["chartLineFlattrendXyaxis"] = "rbxassetid://110690574915489",
		["chartLineFlattrendXyaxisCircle"] = "rbxassetid://76783856599745",
		["chartLineFlattrendXyaxisCircleFill"] = "rbxassetid://132276486757230",
		["chartLineTextClipboard"] = "rbxassetid://97981178714527",
		["chartLineTextClipboardFill"] = "rbxassetid://96087723608983",
		["chartLineUptrendXyaxis"] = "rbxassetid://139061824225089",
		["chartLineUptrendXyaxisCircle"] = "rbxassetid://96828643866957",
		["chartLineUptrendXyaxisCircleFill"] = "rbxassetid://80941846198870",
		["chartPie"] = "rbxassetid://122200783940691",
		["chartPieFill"] = "rbxassetid://128608698529987",
		["chartXyaxisLine"] = "rbxassetid://92614224702926",
		["checklist"] = "rbxassetid://125339100043044",
		["checklistChecked"] = "rbxassetid://128970854124435",
		["checklistUnchecked"] = "rbxassetid://95294773465186",
		["checkmark"] = "rbxassetid://117709091345748",
		["checkmarkApp"] = "rbxassetid://73945071177652",
		["checkmarkAppFill"] = "rbxassetid://96250250366221",
		["checkmarkApplewatch"] = "rbxassetid://97180578736402",
		["checkmarkArrowTriangleheadClockwise"] = "rbxassetid://107495937127772",
		["checkmarkArrowTriangleheadCounterclockwise"] = "rbxassetid://103676257085698",
		["checkmarkBubble"] = "rbxassetid://113427758353101",
		["checkmarkBubbleFill"] = "rbxassetid://138390397309804",
		["checkmarkCircle"] = "rbxassetid://113497182715811",
		["checkmarkCircleBadgeAirplane"] = "rbxassetid://128585382975580",
		["checkmarkCircleBadgeAirplaneFill"] = "rbxassetid://125423417750617",
		["checkmarkCircleBadgePlus"] = "rbxassetid://117765136842107",
		["checkmarkCircleBadgePlusFill"] = "rbxassetid://135313130011967",
		["checkmarkCircleBadgeQuestionmark"] = "rbxassetid://138820692867130",
		["checkmarkCircleBadgeQuestionmarkFill"] = "rbxassetid://95057426558621",
		["checkmarkCircleBadgeXmark"] = "rbxassetid://81262261190949",
		["checkmarkCircleBadgeXmarkFill"] = "rbxassetid://103457398237353",
		["checkmarkCircleDotted"] = "rbxassetid://95176388046983",
		["checkmarkCircleFill"] = "rbxassetid://80701432625608",
		["checkmarkCircleTrianglebadgeExclamationmark"] = "rbxassetid://70460675920599",
		["checkmarkCircleTrianglebadgeExclamationmarkFill"] = "rbxassetid://70825651489467",
		["checkmarkDiamond"] = "rbxassetid://127964709086707",
		["checkmarkDiamondFill"] = "rbxassetid://126380432099282",
		["checkmarkGobackward"] = "rbxassetid://137921605172447",
		["checkmarkIcloud"] = "rbxassetid://91002425672304",
		["checkmarkIcloudFill"] = "rbxassetid://118772663634007",
		["checkmarkMessage"] = "rbxassetid://115941539799893",
		["checkmarkMessageFill"] = "rbxassetid://106074683578973",
		["checkmarkRectangle"] = "rbxassetid://80011475108827",
		["checkmarkRectangleFill"] = "rbxassetid://109346468847413",
		["checkmarkRectanglePortrait"] = "rbxassetid://110710722715340",
		["checkmarkRectanglePortraitFill"] = "rbxassetid://106934167289889",
		["checkmarkRectangleStack"] = "rbxassetid://105010458802288",
		["checkmarkRectangleStackFill"] = "rbxassetid://101287404944931",
		["checkmarkSeal"] = "rbxassetid://79347843080910",
		["checkmarkSealFill"] = "rbxassetid://108989677395192",
		["checkmarkSealTextPage"] = "rbxassetid://95930917032294",
		["checkmarkSealTextPageFill"] = "rbxassetid://81864860271766",
		["checkmarkShield"] = "rbxassetid://116476478760645",
		["checkmarkShieldFill"] = "rbxassetid://123693100854806",
		["checkmarkSquare"] = "rbxassetid://90140343305408",
		["checkmarkSquareFill"] = "rbxassetid://81712190011585",
		["chevronBackward"] = "rbxassetid://91193161432296",
		["chevronBackward2"] = "rbxassetid://139857646802844",
		["chevronBackwardChevronBackwardDotted"] = "rbxassetid://134698694323812",
		["chevronBackwardCircle"] = "rbxassetid://111843022069820",
		["chevronBackwardCircleFill"] = "rbxassetid://106726041209256",
		["chevronBackwardSquare"] = "rbxassetid://119395442945672",
		["chevronBackwardSquareFill"] = "rbxassetid://137650555775550",
		["chevronBackwardToLine"] = "rbxassetid://119263941294390",
		["chevronCompactBackward"] = "rbxassetid://133203717156144",
		["chevronCompactDown"] = "rbxassetid://100092606470558",
		["chevronCompactForward"] = "rbxassetid://71064478971121",
		["chevronCompactLeft"] = "rbxassetid://102340620945726",
		["chevronCompactLeftChevronCompactRight"] = "rbxassetid://74422735550656",
		["chevronCompactRight"] = "rbxassetid://90848510900151",
		["chevronCompactUp"] = "rbxassetid://129845251522502",
		["chevronCompactUpChevronCompactDown"] = "rbxassetid://101290677380772",
		["chevronCompactUpChevronCompactRightChevronCompactDownChevronCompactLeft"] = "rbxassetid://94444191245039",
		["chevronDown"] = "rbxassetid://116067852952871",
		["chevronDown2"] = "rbxassetid://83293178829681",
		["chevronDownCircle"] = "rbxassetid://106048568785334",
		["chevronDownCircleFill"] = "rbxassetid://137482091804957",
		["chevronDownDotted2"] = "rbxassetid://125100120340183",
		["chevronDownForward2"] = "rbxassetid://80146358470761",
		["chevronDownForwardDotted2"] = "rbxassetid://105001073803635",
		["chevronDownRight2"] = "rbxassetid://117900088200237",
		["chevronDownRightDotted2"] = "rbxassetid://70778643695183",
		["chevronDownSquare"] = "rbxassetid://90429530228079",
		["chevronDownSquareFill"] = "rbxassetid://113144434425347",
		["chevronForward"] = "rbxassetid://85597205001941",
		["chevronForward2"] = "rbxassetid://118305569049773",
		["chevronForwardCircle"] = "rbxassetid://85622575012397",
		["chevronForwardCircleFill"] = "rbxassetid://105928949880596",
		["chevronForwardDottedChevronForward"] = "rbxassetid://118611532406974",
		["chevronForwardSquare"] = "rbxassetid://121248135678052",
		["chevronForwardSquareFill"] = "rbxassetid://136901211975528",
		["chevronForwardToLine"] = "rbxassetid://113251427810828",
		["chevronLeft"] = "rbxassetid://120112805068615",
		["chevronLeft2"] = "rbxassetid://135271611992131",
		["chevronLeftChevronLeftDotted"] = "rbxassetid://89493654076591",
		["chevronLeftChevronRight"] = "rbxassetid://126091837718448",
		["chevronLeftCircle"] = "rbxassetid://79371642062729",
		["chevronLeftCircleFill"] = "rbxassetid://85025727393821",
		["chevronLeftForwardslashChevronRight"] = "rbxassetid://89806716346278",
		["chevronLeftSquare"] = "rbxassetid://76844555323813",
		["chevronLeftSquareFill"] = "rbxassetid://85373254243633",
		["chevronLeftToLine"] = "rbxassetid://110571725143380",
		["chevronRight"] = "rbxassetid://78578344679238",
		["chevronRight2"] = "rbxassetid://128617068570209",
		["chevronRightCircle"] = "rbxassetid://137319086285901",
		["chevronRightCircleFill"] = "rbxassetid://106247315510084",
		["chevronRightDottedChevronRight"] = "rbxassetid://90280104847900",
		["chevronRightSquare"] = "rbxassetid://108383056663215",
		["chevronRightSquareFill"] = "rbxassetid://112928454370933",
		["chevronRightToLine"] = "rbxassetid://88538085601212",
		["chevronUp"] = "rbxassetid://71994936177602",
		["chevronUp2"] = "rbxassetid://79472666988214",
		["chevronUpChevronDown"] = "rbxassetid://115187614425058",
		["chevronUpChevronDownSquare"] = "rbxassetid://90721207484341",
		["chevronUpChevronDownSquareFill"] = "rbxassetid://77237411567916",
		["chevronUpChevronRightChevronDownChevronLeft"] = "rbxassetid://76064929254887",
		["chevronUpCircle"] = "rbxassetid://100279286464112",
		["chevronUpCircleFill"] = "rbxassetid://116618139465058",
		["chevronUpDotted2"] = "rbxassetid://104672280488626",
		["chevronUpForward2"] = "rbxassetid://104274296097003",
		["chevronUpForwardDotted2"] = "rbxassetid://95660075484148",
		["chevronUpRight2"] = "rbxassetid://109081501210155",
		["chevronUpRightDotted2"] = "rbxassetid://81120090509930",
		["chevronUpSquare"] = "rbxassetid://128957757104189",
		["chevronUpSquareFill"] = "rbxassetid://139591043142298",
		["chineseyuanrenminbisign"] = "rbxassetid://106647652850967",
		["chineseyuanrenminbisignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://133627043954478",
		["chineseyuanrenminbisignBankBuilding"] = "rbxassetid://135345149638301",
		["chineseyuanrenminbisignBankBuildingFill"] = "rbxassetid://117468270794690",
		["chineseyuanrenminbisignCircle"] = "rbxassetid://99238289619208",
		["chineseyuanrenminbisignCircleFill"] = "rbxassetid://114815486361826",
		["chineseyuanrenminbisignGaugeChartLefthalfRighthalf"] = "rbxassetid://97094906069731",
		["chineseyuanrenminbisignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://126731737755120",
		["chineseyuanrenminbisignRing"] = "rbxassetid://112854552761514",
		["chineseyuanrenminbisignRingDashed"] = "rbxassetid://115412544764832",
		["chineseyuanrenminbisignSquare"] = "rbxassetid://106069486060345",
		["chineseyuanrenminbisignSquareFill"] = "rbxassetid://138122887058133",
		["circle"] = "rbxassetid://77351764572440",
		["circleAndLineHorizontal"] = "rbxassetid://122925249738775",
		["circleAndLineHorizontalFill"] = "rbxassetid://71198922364962",
		["circleBadgeCheckmark"] = "rbxassetid://76550446292600",
		["circleBadgeCheckmarkFill"] = "rbxassetid://122095089484720",
		["circleBadgeExclamationmark"] = "rbxassetid://118464207416019",
		["circleBadgeExclamationmarkFill"] = "rbxassetid://116397404821243",
		["circleBadgeMinus"] = "rbxassetid://140477954283913",
		["circleBadgeMinusFill"] = "rbxassetid://112082222631971",
		["circleBadgePlus"] = "rbxassetid://74158974124425",
		["circleBadgePlusFill"] = "rbxassetid://102359232710725",
		["circleBadgeQuestionmark"] = "rbxassetid://84105237816535",
		["circleBadgeQuestionmarkFill"] = "rbxassetid://107508739526231",
		["circleBadgeXmark"] = "rbxassetid://75715075079912",
		["circleBadgeXmarkFill"] = "rbxassetid://108800417260586",
		["circleBottomhalfFilled"] = "rbxassetid://93772228869204",
		["circleBottomhalfFilledInverse"] = "rbxassetid://100348037143199",
		["circleBottomrighthalfCheckered"] = "rbxassetid://122575558098594",
		["circleBottomrighthalfPatternCheckered"] = "rbxassetid://94163682140627",
		["circleCircle"] = "rbxassetid://71758569358351",
		["circleCircleFill"] = "rbxassetid://110715985557449",
		["circleDashed"] = "rbxassetid://80873602883859",
		["circleDashedRectangle"] = "rbxassetid://128384956155268",
		["circleDotted"] = "rbxassetid://105302007261428",
		["circleDottedAndCircle"] = "rbxassetid://88524317015989",
		["circleDottedCircle"] = "rbxassetid://73982217657417",
		["circleDottedCircleFill"] = "rbxassetid://74317409458538",
		["circleFill"] = "rbxassetid://132609101842833",
		["circleFilledIpad"] = "rbxassetid://118410279026483",
		["circleFilledIpadFill"] = "rbxassetid://138916749945804",
		["circleFilledIpadLandscape"] = "rbxassetid://98083380583955",
		["circleFilledIpadLandscapeFill"] = "rbxassetid://107790137388850",
		["circleFilledIphone"] = "rbxassetid://122754969849891",
		["circleFilledIphoneFill"] = "rbxassetid://97935781680008",
		["circleFilledPatternDiagonallineRectangle"] = "rbxassetid://84692213314115",
		["circleGrid2x1"] = "rbxassetid://126879867009619",
		["circleGrid2x1Fill"] = "rbxassetid://118105257533357",
		["circleGrid2x1LeftFilled"] = "rbxassetid://107581688387909",
		["circleGrid2x1RightFilled"] = "rbxassetid://75046917797428",
		["circleGrid2x2"] = "rbxassetid://136579717851920",
		["circleGrid2x2Fill"] = "rbxassetid://114454902590504",
		["circleGrid2x2TopleftCheckmarkFilled"] = "rbxassetid://89913344340254",
		["circleGrid3x3"] = "rbxassetid://94448556408587",
		["circleGrid3x3Circle"] = "rbxassetid://132776725985146",
		["circleGrid3x3CircleFill"] = "rbxassetid://81436799538589",
		["circleGrid3x3Fill"] = "rbxassetid://76516952302413",
		["circleGridCross"] = "rbxassetid://111852820274501",
		["circleGridCrossDownFilled"] = "rbxassetid://122925459913152",
		["circleGridCrossFill"] = "rbxassetid://110500814372682",
		["circleGridCrossLeftFilled"] = "rbxassetid://90411348277462",
		["circleGridCrossRightFilled"] = "rbxassetid://73198600977610",
		["circleGridCrossUpFilled"] = "rbxassetid://140639075369170",
		["circleHexagongrid"] = "rbxassetid://115766942150344",
		["circleHexagongridCircle"] = "rbxassetid://134748651158488",
		["circleHexagongridCircleFill"] = "rbxassetid://81549201853724",
		["circleHexagongridFill"] = "rbxassetid://110857449976245",
		["circleHexagonpath"] = "rbxassetid://85916325663168",
		["circleHexagonpathFill"] = "rbxassetid://137583129970644",
		["circleLefthalfFilled"] = "rbxassetid://97825242263995",
		["circleLefthalfFilledInverse"] = "rbxassetid://95093722032121",
		["circleLefthalfFilledRighthalfStripedHorizontal"] = "rbxassetid://108512481868469",
		["circleLefthalfFilledRighthalfStripedHorizontalInverse"] = "rbxassetid://82874739567085",
		["circleLefthalfStripedHorizontal"] = "rbxassetid://93826488584783",
		["circleLefthalfStripedHorizontalInverse"] = "rbxassetid://97829908032507",
		["circleOnSquare"] = "rbxassetid://97779341422775",
		["circleOnSquareIntersectionDotted"] = "rbxassetid://120659491389976",
		["circleOnSquareMerge"] = "rbxassetid://78931485816076",
		["circleRectangleDashed"] = "rbxassetid://125046628567305",
		["circleRectangleFilledPatternDiagonalline"] = "rbxassetid://113655167746204",
		["circleRighthalfFilled"] = "rbxassetid://78313004126214",
		["circleRighthalfFilledInverse"] = "rbxassetid://114210082181728",
		["circleSlash"] = "rbxassetid://116513396479523",
		["circleSlashFill"] = "rbxassetid://72982692904185",
		["circleSquare"] = "rbxassetid://122783494268200",
		["circleSquareFill"] = "rbxassetid://102931934264046",
		["circleTophalfFilled"] = "rbxassetid://91615555048147",
		["circleTophalfFilledInverse"] = "rbxassetid://140511657377882",
		["circlebadge"] = "rbxassetid://91455021015370",
		["circlebadge2"] = "rbxassetid://125133188090635",
		["circlebadge2Fill"] = "rbxassetid://96114399074311",
		["circlebadgeFill"] = "rbxassetid://100596250735760",
		["clear"] = "rbxassetid://86389300199089",
		["clearFill"] = "rbxassetid://94709581536945",
		["clipboard"] = "rbxassetid://131839244113738",
		["clipboardFill"] = "rbxassetid://134384663588746",
		["clock"] = "rbxassetid://118494205518216",
		["clockArrow2Circlepath"] = "rbxassetid://120448260426448",
		["clockArrowCirclepath"] = "rbxassetid://83500708276723",
		["clockArrowTrianglehead2CounterclockwiseRotate90"] = "rbxassetid://115137084749223",
		["clockArrowTriangleheadClockwiseRotate90PathDotted"] = "rbxassetid://109195459563384",
		["clockArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://89226626342302",
		["clockBadge"] = "rbxassetid://115327553111420",
		["clockBadgeAirplane"] = "rbxassetid://88667530307852",
		["clockBadgeAirplaneFill"] = "rbxassetid://91355511171537",
		["clockBadgeCheckmark"] = "rbxassetid://83498643149203",
		["clockBadgeCheckmarkFill"] = "rbxassetid://77828663867935",
		["clockBadgeExclamationmark"] = "rbxassetid://130712128950744",
		["clockBadgeExclamationmarkFill"] = "rbxassetid://120350431132914",
		["clockBadgeFill"] = "rbxassetid://88269624942481",
		["clockBadgeQuestionmark"] = "rbxassetid://140419785571575",
		["clockBadgeQuestionmarkFill"] = "rbxassetid://89682323416952",
		["clockBadgeXmark"] = "rbxassetid://100973182473925",
		["clockBadgeXmarkFill"] = "rbxassetid://81230821710210",
		["clockCircle"] = "rbxassetid://91059286420704",
		["clockCircleFill"] = "rbxassetid://85551007246698",
		["clockFill"] = "rbxassetid://111548973303929",
		["cloud"] = "rbxassetid://105957371924111",
		["cloudBolt"] = "rbxassetid://97438995257422",
		["cloudBoltCircle"] = "rbxassetid://102467209270679",
		["cloudBoltCircleFill"] = "rbxassetid://86605548042299",
		["cloudBoltFill"] = "rbxassetid://108857264198967",
		["cloudBoltRain"] = "rbxassetid://119315902598803",
		["cloudBoltRainCircle"] = "rbxassetid://75667970292186",
		["cloudBoltRainCircleFill"] = "rbxassetid://101185113049432",
		["cloudBoltRainFill"] = "rbxassetid://105734599370391",
		["cloudCircle"] = "rbxassetid://75595371373901",
		["cloudCircleFill"] = "rbxassetid://100351258374804",
		["cloudDrizzle"] = "rbxassetid://118772556442825",
		["cloudDrizzleCircle"] = "rbxassetid://134748373557774",
		["cloudDrizzleCircleFill"] = "rbxassetid://116611455603766",
		["cloudDrizzleFill"] = "rbxassetid://132048424719835",
		["cloudFill"] = "rbxassetid://81929130099582",
		["cloudFog"] = "rbxassetid://88316772996583",
		["cloudFogCircle"] = "rbxassetid://91971244695380",
		["cloudFogCircleFill"] = "rbxassetid://107932107751895",
		["cloudFogFill"] = "rbxassetid://140333418982777",
		["cloudHail"] = "rbxassetid://109477306347948",
		["cloudHailCircle"] = "rbxassetid://111935689657678",
		["cloudHailCircleFill"] = "rbxassetid://113958303878705",
		["cloudHailFill"] = "rbxassetid://88337312532907",
		["cloudHeavyrain"] = "rbxassetid://119601076239239",
		["cloudHeavyrainCircle"] = "rbxassetid://113148606737260",
		["cloudHeavyrainCircleFill"] = "rbxassetid://93841246166430",
		["cloudHeavyrainFill"] = "rbxassetid://88892490794016",
		["cloudMoon"] = "rbxassetid://81142197017787",
		["cloudMoonBolt"] = "rbxassetid://122762071192157",
		["cloudMoonBoltCircle"] = "rbxassetid://130186762815605",
		["cloudMoonBoltCircleFill"] = "rbxassetid://88717135754929",
		["cloudMoonBoltFill"] = "rbxassetid://132632709705945",
		["cloudMoonCircle"] = "rbxassetid://101603611950498",
		["cloudMoonCircleFill"] = "rbxassetid://74403315229993",
		["cloudMoonFill"] = "rbxassetid://131415283779316",
		["cloudMoonRain"] = "rbxassetid://123752971704324",
		["cloudMoonRainCircle"] = "rbxassetid://91321181570006",
		["cloudMoonRainCircleFill"] = "rbxassetid://99999475568772",
		["cloudMoonRainFill"] = "rbxassetid://87465253394705",
		["cloudRain"] = "rbxassetid://73594633942444",
		["cloudRainCircle"] = "rbxassetid://135073289493994",
		["cloudRainCircleFill"] = "rbxassetid://107231577649535",
		["cloudRainFill"] = "rbxassetid://117683267149042",
		["cloudRainbowCrop"] = "rbxassetid://100908348397951",
		["cloudRainbowCropFill"] = "rbxassetid://126657444384304",
		["cloudRainbowHalf"] = "rbxassetid://80949891966526",
		["cloudSleet"] = "rbxassetid://91110633048392",
		["cloudSleetCircle"] = "rbxassetid://96915941810109",
		["cloudSleetCircleFill"] = "rbxassetid://126874750937247",
		["cloudSleetFill"] = "rbxassetid://92708514394653",
		["cloudSnow"] = "rbxassetid://105037978809526",
		["cloudSnowCircle"] = "rbxassetid://133719082885022",
		["cloudSnowCircleFill"] = "rbxassetid://87293225773295",
		["cloudSnowFill"] = "rbxassetid://86264528698010",
		["cloudSun"] = "rbxassetid://90643281481332",
		["cloudSunBolt"] = "rbxassetid://131455198927801",
		["cloudSunBoltCircle"] = "rbxassetid://125648631050001",
		["cloudSunBoltCircleFill"] = "rbxassetid://84471773945729",
		["cloudSunBoltFill"] = "rbxassetid://112333664152593",
		["cloudSunCircle"] = "rbxassetid://113784163787232",
		["cloudSunCircleFill"] = "rbxassetid://129881246784143",
		["cloudSunFill"] = "rbxassetid://124208622832507",
		["cloudSunRain"] = "rbxassetid://85585305376134",
		["cloudSunRainCircle"] = "rbxassetid://101680887245230",
		["cloudSunRainCircleFill"] = "rbxassetid://112862634540035",
		["cloudSunRainFill"] = "rbxassetid://96381809768088",
		["coat"] = "rbxassetid://138683384493955",
		["coatCircle"] = "rbxassetid://92296510927085",
		["coatCircleFill"] = "rbxassetid://96955835035080",
		["coatFill"] = "rbxassetid://85343931320953",
		["coloncurrencysign"] = "rbxassetid://70610561043896",
		["coloncurrencysignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://121730405897063",
		["coloncurrencysignBankBuilding"] = "rbxassetid://70532040854333",
		["coloncurrencysignBankBuildingFill"] = "rbxassetid://112013535327197",
		["coloncurrencysignCircle"] = "rbxassetid://72472930693295",
		["coloncurrencysignCircleFill"] = "rbxassetid://87581274361487",
		["coloncurrencysignGaugeChartLefthalfRighthalf"] = "rbxassetid://81410792250924",
		["coloncurrencysignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://117861383134809",
		["coloncurrencysignRing"] = "rbxassetid://90425639365292",
		["coloncurrencysignRingDashed"] = "rbxassetid://123033006789245",
		["coloncurrencysignSquare"] = "rbxassetid://123318002368880",
		["coloncurrencysignSquareFill"] = "rbxassetid://92584369957351",
		["comb"] = "rbxassetid://91258665510440",
		["combFill"] = "rbxassetid://75935642339195",
		["command"] = "rbxassetid://106412276667065",
		["commandCircle"] = "rbxassetid://132133934704997",
		["commandCircleFill"] = "rbxassetid://129804286574492",
		["commandSquare"] = "rbxassetid://125800470592169",
		["commandSquareFill"] = "rbxassetid://80987808644627",
		["compassDrawing"] = "rbxassetid://132752181112407",
		["computermouse"] = "rbxassetid://74192781750262",
		["computermouseFill"] = "rbxassetid://122971754731281",
		["cone"] = "rbxassetid://136677139752159",
		["coneFill"] = "rbxassetid://102731753185841",
		["contactSensor"] = "rbxassetid://78390045190635",
		["contactSensorFill"] = "rbxassetid://107941147884609",
		["contextualmenuAndCursorarrow"] = "rbxassetid://123228274012415",
		["contextualmenuAndPointerArrow"] = "rbxassetid://104765402938366",
		["control"] = "rbxassetid://122628517345884",
		["convertibleSide"] = "rbxassetid://88056497032702",
		["convertibleSideAirCirculate"] = "rbxassetid://98143091298529",
		["convertibleSideAirCirculateFill"] = "rbxassetid://100789655329813",
		["convertibleSideAirFresh"] = "rbxassetid://133740317868475",
		["convertibleSideAirFreshFill"] = "rbxassetid://102875203407099",
		["convertibleSideAndExclamationmark"] = "rbxassetid://98977481869672",
		["convertibleSideAndExclamationmarkFill"] = "rbxassetid://75447287801799",
		["convertibleSideArrowLeftAndRight"] = "rbxassetid://86781979323180",
		["convertibleSideArrowLeftAndRightFill"] = "rbxassetid://132788293962828",
		["convertibleSideArrowTriangleheadBackward"] = "rbxassetid://78827119413410",
		["convertibleSideArrowTriangleheadBackwardFill"] = "rbxassetid://104495302305788",
		["convertibleSideArrowTriangleheadForward"] = "rbxassetid://74390894600361",
		["convertibleSideArrowTriangleheadForwardAndBackward"] = "rbxassetid://111786845642207",
		["convertibleSideArrowTriangleheadForwardAndBackwardFill"] = "rbxassetid://72089424692194",
		["convertibleSideArrowTriangleheadForwardFill"] = "rbxassetid://78071911288530",
		["convertibleSideArrowtriangleDown"] = "rbxassetid://94542124218390",
		["convertibleSideArrowtriangleDownFill"] = "rbxassetid://106589035606078",
		["convertibleSideArrowtriangleUp"] = "rbxassetid://120865137899154",
		["convertibleSideArrowtriangleUpArrowtriangleDown"] = "rbxassetid://74101665628817",
		["convertibleSideArrowtriangleUpArrowtriangleDownFill"] = "rbxassetid://71804342394234",
		["convertibleSideArrowtriangleUpFill"] = "rbxassetid://110118762963000",
		["convertibleSideFill"] = "rbxassetid://109733797871544",
		["convertibleSideFrontOpen"] = "rbxassetid://131524948510161",
		["convertibleSideFrontOpenCrop"] = "rbxassetid://85705555161852",
		["convertibleSideFrontOpenCropFill"] = "rbxassetid://114271147567717",
		["convertibleSideFrontOpenFill"] = "rbxassetid://95366775755410",
		["convertibleSideHillDescentControl"] = "rbxassetid://71720992446425",
		["convertibleSideHillDescentControlFill"] = "rbxassetid://88324401650008",
		["convertibleSideHillDown"] = "rbxassetid://108529567267858",
		["convertibleSideHillDownAndGaugeOpenWithLinesNeedle25percentAndArrowtriangle"] = "rbxassetid://107975199810052",
		["convertibleSideHillDownAndGaugeOpenWithLinesNeedle25percentAndArrowtriangleFill"] = "rbxassetid://125979092076687",
		["convertibleSideHillDownFill"] = "rbxassetid://131556252117231",
		["convertibleSideHillUp"] = "rbxassetid://105616874495927",
		["convertibleSideHillUpFill"] = "rbxassetid://129311678978143",
		["convertibleSideLock"] = "rbxassetid://112823065019915",
		["convertibleSideLockFill"] = "rbxassetid://111356282511740",
		["convertibleSideLockOpen"] = "rbxassetid://113482904283039",
		["convertibleSideLockOpenFill"] = "rbxassetid://84761446199699",
		["cooktop"] = "rbxassetid://88834174813644",
		["cooktopFill"] = "rbxassetid://129568808107438",
		["cpu"] = "rbxassetid://124308556421451",
		["cpuFill"] = "rbxassetid://103202408856526",
		["creditcard"] = "rbxassetid://81319932685854",
		["creditcardAnd123"] = "rbxassetid://87625010126625",
		["creditcardAndNumbers"] = "rbxassetid://94218302612103",
		["creditcardArrowTrianglehead2ClockwiseRotate90"] = "rbxassetid://137775649489006",
		["creditcardCircle"] = "rbxassetid://115901734894378",
		["creditcardCircleFill"] = "rbxassetid://94325401969577",
		["creditcardFill"] = "rbxassetid://137205665020340",
		["creditcardRewards"] = "rbxassetid://105224490601254",
		["creditcardRewardsFill"] = "rbxassetid://122388666096808",
		["creditcardTrianglebadgeExclamationmark"] = "rbxassetid://128465389472705",
		["creditcardTrianglebadgeExclamationmarkFill"] = "rbxassetid://134046944234972",
		["creditcardViewfinder"] = "rbxassetid://107524109192728",
		["cricketBall"] = "rbxassetid://107557445941992",
		["cricketBallCircle"] = "rbxassetid://108046247330406",
		["cricketBallCircleFill"] = "rbxassetid://97707187254281",
		["cricketBallFill"] = "rbxassetid://124235035918902",
		["crop"] = "rbxassetid://76267866840424",
		["cropRotate"] = "rbxassetid://112208131294712",
		["cross"] = "rbxassetid://117291897053132",
		["crossCase"] = "rbxassetid://85203105573889",
		["crossCaseCircle"] = "rbxassetid://80349542022495",
		["crossCaseCircleFill"] = "rbxassetid://98787370493226",
		["crossCaseFill"] = "rbxassetid://108835778654525",
		["crossCircle"] = "rbxassetid://127430494755623",
		["crossCircleFill"] = "rbxassetid://74611741813087",
		["crossFill"] = "rbxassetid://108668325552210",
		["crossVial"] = "rbxassetid://139445714175616",
		["crossVialFill"] = "rbxassetid://134692391930699",
		["crown"] = "rbxassetid://75313755369933",
		["crownFill"] = "rbxassetid://113744176715187",
		["cruzeirosign"] = "rbxassetid://126565022512426",
		["cruzeirosignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://74744481288811",
		["cruzeirosignBankBuilding"] = "rbxassetid://131787371672007",
		["cruzeirosignBankBuildingFill"] = "rbxassetid://124556542732831",
		["cruzeirosignCircle"] = "rbxassetid://108994326873163",
		["cruzeirosignCircleFill"] = "rbxassetid://92977831088874",
		["cruzeirosignGaugeChartLefthalfRighthalf"] = "rbxassetid://112870188799383",
		["cruzeirosignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://82432008607525",
		["cruzeirosignRing"] = "rbxassetid://73494393849183",
		["cruzeirosignRingDashed"] = "rbxassetid://122245608823787",
		["cruzeirosignSquare"] = "rbxassetid://109516455287703",
		["cruzeirosignSquareFill"] = "rbxassetid://104979541987178",
		["cube"] = "rbxassetid://99085671007116",
		["cubeCircle"] = "rbxassetid://74137474397517",
		["cubeCircleFill"] = "rbxassetid://134571955348253",
		["cubeFill"] = "rbxassetid://98135374759567",
		["cubeTransparent"] = "rbxassetid://80565642502539",
		["cubeTransparentFill"] = "rbxassetid://126536927378991",
		["cupAndHeatWaves"] = "rbxassetid://74078659549582",
		["cupAndHeatWavesFill"] = "rbxassetid://131989311539655",
		["cupAndSaucer"] = "rbxassetid://72514825273993",
		["cupAndSaucerFill"] = "rbxassetid://119230927536360",
		["curlybraces"] = "rbxassetid://129788587428692",
		["curlybracesSquare"] = "rbxassetid://129045503496668",
		["curlybracesSquareFill"] = "rbxassetid://123432376294099",
		["cursorarrow"] = "rbxassetid://76353347413637",
		["cursorarrowAndSquareOnSquareDashed"] = "rbxassetid://123035396911468",
		["cursorarrowClick"] = "rbxassetid://120755931811218",
		["cursorarrowClick2"] = "rbxassetid://131954684779465",
		["cursorarrowClickBadgeClock"] = "rbxassetid://96674815416136",
		["cursorarrowMotionlines"] = "rbxassetid://117420120397428",
		["cursorarrowMotionlinesClick"] = "rbxassetid://81573780818011",
		["cursorarrowRays"] = "rbxassetid://126392116415147",
		["cursorarrowSlash"] = "rbxassetid://91144329352020",
		["cursorarrowSlashSquare"] = "rbxassetid://95513304668296",
		["cursorarrowSquare"] = "rbxassetid://131316405162767",
		["curtainsClosed"] = "rbxassetid://101807311791533",
		["curtainsOpen"] = "rbxassetid://122412153002106",
		["cylinder"] = "rbxassetid://128980035962696",
		["cylinderFill"] = "rbxassetid://111577778638579",
		["cylinderSplit1x2"] = "rbxassetid://127863382272636",
		["cylinderSplit1x2Fill"] = "rbxassetid://88248682215663",
		["dCircle"] = "rbxassetid://139348136095117",
		["dCircleFill"] = "rbxassetid://119613399981436",
		["dSquare"] = "rbxassetid://117814926531634",
		["dSquareFill"] = "rbxassetid://108548965881707",
		["danishkronesign"] = "rbxassetid://131739695626393",
		["danishkronesignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://105778149797087",
		["danishkronesignBankBuilding"] = "rbxassetid://107331257039732",
		["danishkronesignBankBuildingFill"] = "rbxassetid://110654132210408",
		["danishkronesignCircle"] = "rbxassetid://71261610464877",
		["danishkronesignCircleFill"] = "rbxassetid://81494386563215",
		["danishkronesignGaugeChartLefthalfRighthalf"] = "rbxassetid://96925630529917",
		["danishkronesignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://137030980787422",
		["danishkronesignRing"] = "rbxassetid://97079964616730",
		["danishkronesignRingDashed"] = "rbxassetid://133795816793944",
		["danishkronesignSquare"] = "rbxassetid://124245881324486",
		["danishkronesignSquareFill"] = "rbxassetid://85244239694374",
		["decreaseIndent"] = "rbxassetid://88589482580566",
		["decreaseQuotelevel"] = "rbxassetid://116467773015005",
		["degreesignCelsius"] = "rbxassetid://89989256393732",
		["degreesignFahrenheit"] = "rbxassetid://104819176215784",
		["dehumidifier"] = "rbxassetid://124560404977624",
		["dehumidifierFill"] = "rbxassetid://137890774655891",
		["deleteBackward"] = "rbxassetid://97287995124465",
		["deleteBackwardFill"] = "rbxassetid://91714832072413",
		["deleteForward"] = "rbxassetid://126070993467794",
		["deleteForwardFill"] = "rbxassetid://101546743976234",
		["deleteLeft"] = "rbxassetid://129252293455681",
		["deleteLeftFill"] = "rbxassetid://103030116283513",
		["deleteRight"] = "rbxassetid://107553771079065",
		["deleteRightFill"] = "rbxassetid://111969523580666",
		["deskclock"] = "rbxassetid://128981521415034",
		["deskclockFill"] = "rbxassetid://77381200322602",
		["desktopcomputer"] = "rbxassetid://107766434710685",
		["desktopcomputerAndArrowDown"] = "rbxassetid://72903302027184",
		["desktopcomputerAndMacbook"] = "rbxassetid://123097897733245",
		["desktopcomputerBadgeCheckmark"] = "rbxassetid://113146178110887",
		["desktopcomputerBadgeShieldCheckmark"] = "rbxassetid://92532490405861",
		["desktopcomputerTrianglebadgeExclamationmark"] = "rbxassetid://105558126089739",
		["deskview"] = "rbxassetid://121089828258182",
		["deskviewFill"] = "rbxassetid://117267790741411",
		["dialHigh"] = "rbxassetid://73577823641217",
		["dialHighFill"] = "rbxassetid://138768311720985",
		["dialLow"] = "rbxassetid://73103006519174",
		["dialLowFill"] = "rbxassetid://98791719425867",
		["dialMedium"] = "rbxassetid://125486906119866",
		["dialMediumFill"] = "rbxassetid://101803104687767",
		["diamond"] = "rbxassetid://100452260150000",
		["diamondBottomhalfFilled"] = "rbxassetid://119790712303249",
		["diamondCircle"] = "rbxassetid://85000945258354",
		["diamondCircleFill"] = "rbxassetid://130795247628751",
		["diamondFill"] = "rbxassetid://135326379832516",
		["diamondLefthalfFilled"] = "rbxassetid://111934789670996",
		["diamondRighthalfFilled"] = "rbxassetid://116111158801385",
		["diamondTophalfFilled"] = "rbxassetid://110438206140750",
		["dice"] = "rbxassetid://101607867208664",
		["diceFill"] = "rbxassetid://132513568893953",
		["dieFace1"] = "rbxassetid://93511055000612",
		["dieFace1Fill"] = "rbxassetid://101810661456778",
		["dieFace2"] = "rbxassetid://97436037441224",
		["dieFace2Fill"] = "rbxassetid://107358011011984",
		["dieFace3"] = "rbxassetid://120095408336817",
		["dieFace3Fill"] = "rbxassetid://72211886706012",
		["dieFace4"] = "rbxassetid://106899046151642",
		["dieFace4Fill"] = "rbxassetid://84516247319545",
		["dieFace5"] = "rbxassetid://129586843517471",
		["dieFace5Fill"] = "rbxassetid://89575782614538",
		["dieFace6"] = "rbxassetid://118434046380828",
		["dieFace6Fill"] = "rbxassetid://79919588843970",
		["digitalcrownArrowClockwise"] = "rbxassetid://113038599465284",
		["digitalcrownArrowClockwiseFill"] = "rbxassetid://125537117338217",
		["digitalcrownArrowCounterclockwise"] = "rbxassetid://91415160437248",
		["digitalcrownArrowCounterclockwiseFill"] = "rbxassetid://135521665801021",
		["digitalcrownHorizontalArrowClockwise"] = "rbxassetid://103189101099622",
		["digitalcrownHorizontalArrowClockwiseFill"] = "rbxassetid://134814847872732",
		["digitalcrownHorizontalArrowCounterclockwise"] = "rbxassetid://127977551895798",
		["digitalcrownHorizontalArrowCounterclockwiseFill"] = "rbxassetid://128234037577616",
		["digitalcrownHorizontalPress"] = "rbxassetid://96420371236309",
		["digitalcrownHorizontalPressFill"] = "rbxassetid://128765548994947",
		["digitalcrownPress"] = "rbxassetid://78417970263455",
		["digitalcrownPressFill"] = "rbxassetid://117434984032927",
		["directcurrent"] = "rbxassetid://131799886298156",
		["dishwasher"] = "rbxassetid://87710012658252",
		["dishwasherCircle"] = "rbxassetid://101196794042889",
		["dishwasherCircleFill"] = "rbxassetid://125490773916925",
		["dishwasherFill"] = "rbxassetid://107996524055597",
		["display"] = "rbxassetid://129576202104478",
		["display2"] = "rbxassetid://104707340982471",
		["displayAndArrowDown"] = "rbxassetid://125200972320706",
		["displayAndScrewdriver"] = "rbxassetid://88947373615358",
		["displayTrianglebadgeExclamationmark"] = "rbxassetid://74215695749246",
		["distributeHorizontal"] = "rbxassetid://70445662962312",
		["distributeHorizontalCenter"] = "rbxassetid://80437477134490",
		["distributeHorizontalCenterFill"] = "rbxassetid://119697341124280",
		["distributeHorizontalFill"] = "rbxassetid://81547792767797",
		["distributeHorizontalLeft"] = "rbxassetid://107554802550012",
		["distributeHorizontalLeftFill"] = "rbxassetid://94354038132668",
		["distributeHorizontalRight"] = "rbxassetid://108003162032073",
		["distributeHorizontalRightFill"] = "rbxassetid://73286830298055",
		["distributeVertical"] = "rbxassetid://76030980380639",
		["distributeVerticalBottom"] = "rbxassetid://125371761357477",
		["distributeVerticalBottomFill"] = "rbxassetid://101717338101326",
		["distributeVerticalCenter"] = "rbxassetid://118073308636361",
		["distributeVerticalCenterFill"] = "rbxassetid://87414672077654",
		["distributeVerticalFill"] = "rbxassetid://107674189896422",
		["distributeVerticalTop"] = "rbxassetid://76620811418507",
		["distributeVerticalTopFill"] = "rbxassetid://124081343166798",
		["divide"] = "rbxassetid://79215535863886",
		["divideCircle"] = "rbxassetid://113145969264461",
		["divideCircleFill"] = "rbxassetid://123714081526266",
		["divideSquare"] = "rbxassetid://111006580979570",
		["divideSquareFill"] = "rbxassetid://105584343535953",
		["doc"] = "rbxassetid://80680488161934",
		["docAppend"] = "rbxassetid://92502742629439",
		["docBadgeArrowUp"] = "rbxassetid://80297421254328",
		["docBadgeClock"] = "rbxassetid://106217049362270",
		["docBadgeEllipsis"] = "rbxassetid://131787139108704",
		["docBadgeGearshape"] = "rbxassetid://75017579898518",
		["docBadgePlus"] = "rbxassetid://124537298304533",
		["docCircle"] = "rbxassetid://114937888569701",
		["docOnClipboard"] = "rbxassetid://94277113748864",
		["docOnDoc"] = "rbxassetid://74221368188325",
		["docPlaintext"] = "rbxassetid://116104151169652",
		["docRichtext"] = "rbxassetid://94749196343692",
		["docText"] = "rbxassetid://106048817459549",
		["docTextBelowEcg"] = "rbxassetid://111731877748125",
		["docTextImage"] = "rbxassetid://122105011236494",
		["docTextMagnifyingglass"] = "rbxassetid://86983114420254",
		["docViewfinder"] = "rbxassetid://137034209283570",
		["docZipper"] = "rbxassetid://96676285483415",
		["dockArrowDownRectangle"] = "rbxassetid://79678007655929",
		["dockArrowUpRectangle"] = "rbxassetid://103809621231446",
		["dockRectangle"] = "rbxassetid://116915015149373",
		["document"] = "rbxassetid://124796793806383",
		["documentBadgeArrowUp"] = "rbxassetid://123268508542979",
		["documentBadgeArrowUpFill"] = "rbxassetid://90983453010822",
		["documentBadgeClock"] = "rbxassetid://110094088290911",
		["documentBadgeClockFill"] = "rbxassetid://125542031580318",
		["documentBadgeEllipsis"] = "rbxassetid://117158658954997",
		["documentBadgeEllipsisFill"] = "rbxassetid://76114071497838",
		["documentBadgeGearshape"] = "rbxassetid://77928287555730",
		["documentBadgeGearshapeFill"] = "rbxassetid://84274129384253",
		["documentBadgePlus"] = "rbxassetid://131301015581855",
		["documentBadgePlusFill"] = "rbxassetid://119897017745527",
		["documentCircle"] = "rbxassetid://115432124967770",
		["documentCircleFill"] = "rbxassetid://81065392469526",
		["documentFill"] = "rbxassetid://102002749838822",
		["documentOnClipboard"] = "rbxassetid://93839365739605",
		["documentOnClipboardFill"] = "rbxassetid://112586343230192",
		["documentOnDocument"] = "rbxassetid://107508916580138",
		["documentOnDocumentFill"] = "rbxassetid://74882215448372",
		["documentOnTrash"] = "rbxassetid://121400057226892",
		["documentOnTrashFill"] = "rbxassetid://81536752681320",
		["documentViewfinder"] = "rbxassetid://121616818189343",
		["documentViewfinderFill"] = "rbxassetid://70819609607946",
		["dog"] = "rbxassetid://117451448671654",
		["dogCircle"] = "rbxassetid://105450428935772",
		["dogCircleFill"] = "rbxassetid://98543830678397",
		["dogFill"] = "rbxassetid://92378974436965",
		["dollarsign"] = "rbxassetid://114666918383783",
		["dollarsignArrowCirclepath"] = "rbxassetid://111141236452341",
		["dollarsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://89635002789945",
		["dollarsignBankBuilding"] = "rbxassetid://105920028179036",
		["dollarsignBankBuildingFill"] = "rbxassetid://132899638309304",
		["dollarsignCircle"] = "rbxassetid://102492024082780",
		["dollarsignCircleFill"] = "rbxassetid://71830017801030",
		["dollarsignGaugeChartLefthalfRighthalf"] = "rbxassetid://129052029424233",
		["dollarsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://78922584980415",
		["dollarsignRing"] = "rbxassetid://135226063978248",
		["dollarsignRingDashed"] = "rbxassetid://112067357041185",
		["dollarsignSquare"] = "rbxassetid://137446308450569",
		["dollarsignSquareFill"] = "rbxassetid://135191385118976",
		["dongsign"] = "rbxassetid://131470155313598",
		["dongsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://78266004720742",
		["dongsignBankBuilding"] = "rbxassetid://93291038171841",
		["dongsignBankBuildingFill"] = "rbxassetid://134028059678599",
		["dongsignCircle"] = "rbxassetid://78578408861421",
		["dongsignCircleFill"] = "rbxassetid://97359784120063",
		["dongsignGaugeChartLefthalfRighthalf"] = "rbxassetid://126111988758130",
		["dongsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://132144167952188",
		["dongsignRing"] = "rbxassetid://77819742511029",
		["dongsignRingDashed"] = "rbxassetid://74495453626839",
		["dongsignSquare"] = "rbxassetid://101387193682428",
		["dongsignSquareFill"] = "rbxassetid://82247973365677",
		["doorFrenchClosed"] = "rbxassetid://72674657682992",
		["doorFrenchOpen"] = "rbxassetid://71650861494809",
		["doorGarageClosed"] = "rbxassetid://76882327011413",
		["doorGarageClosedTrianglebadgeExclamationmark"] = "rbxassetid://77158083946409",
		["doorGarageDoubleBayClosed"] = "rbxassetid://80981083592931",
		["doorGarageDoubleBayClosedTrianglebadgeExclamationmark"] = "rbxassetid://126845743919696",
		["doorGarageDoubleBayOpen"] = "rbxassetid://80126036062871",
		["doorGarageDoubleBayOpenTrianglebadgeExclamationmark"] = "rbxassetid://81451333563049",
		["doorGarageOpen"] = "rbxassetid://119088880497339",
		["doorGarageOpenTrianglebadgeExclamationmark"] = "rbxassetid://87728457848837",
		["doorLeftHandClosed"] = "rbxassetid://135128964730567",
		["doorLeftHandOpen"] = "rbxassetid://83765067910138",
		["doorRightHandClosed"] = "rbxassetid://110182995960620",
		["doorRightHandOpen"] = "rbxassetid://106043050975592",
		["doorSlidingLeftHandClosed"] = "rbxassetid://87632050696273",
		["doorSlidingLeftHandOpen"] = "rbxassetid://78005731822470",
		["doorSlidingRightHandClosed"] = "rbxassetid://128301725703574",
		["doorSlidingRightHandOpen"] = "rbxassetid://84574799071754",
		["dotArrowtrianglesUpRightDownLeftCircle"] = "rbxassetid://131760626023852",
		["dotCarTopRadiowaves2RearLeftRearRearRight"] = "rbxassetid://90311472253622",
		["dotCarTopRadiowaves2RearLeftRearRearRightFill"] = "rbxassetid://108359832311792",
		["dotCircleAndCursorarrow"] = "rbxassetid://115122421262820",
		["dotCircleAndHandPointUpLeftFill"] = "rbxassetid://128518318617359",
		["dotCircleAndPointerArrow"] = "rbxassetid://111417453409808",
		["dotCircleViewfinder"] = "rbxassetid://96091854795879",
		["dotCrosshair"] = "rbxassetid://111411956958702",
		["dotRadiowavesForward"] = "rbxassetid://107117879701250",
		["dotRadiowavesLeftAndRight"] = "rbxassetid://130013546237645",
		["dotRadiowavesRight"] = "rbxassetid://83521858010518",
		["dotRadiowavesUpForward"] = "rbxassetid://137844140535297",
		["dotScope"] = "rbxassetid://121005306065203",
		["dotScopeDisplay"] = "rbxassetid://133201781049322",
		["dotScopeLaptopcomputer"] = "rbxassetid://90429518888381",
		["dotSquare"] = "rbxassetid://136076872200498",
		["dotSquareFill"] = "rbxassetid://73545757794889",
		["dotSquareshape"] = "rbxassetid://115421844852656",
		["dotSquareshapeFill"] = "rbxassetid://131818751234447",
		["dotSquareshapeSplit2x2"] = "rbxassetid://111473506170578",
		["dotViewfinder"] = "rbxassetid://113016896284675",
		["dotsAndLineVerticalAndCursorarrowRectangle"] = "rbxassetid://82575719013218",
		["dotsAndLineVerticalAndPointerArrowRectangle"] = "rbxassetid://92115593886595",
		["dpad"] = "rbxassetid://112675157052076",
		["dpadDownFilled"] = "rbxassetid://112396763830267",
		["dpadFill"] = "rbxassetid://122140108936845",
		["dpadLeftFilled"] = "rbxassetid://87311733672381",
		["dpadRightFilled"] = "rbxassetid://130745043343873",
		["dpadUpFilled"] = "rbxassetid://134846020479603",
		["drone"] = "rbxassetid://78690133487507",
		["droneFill"] = "rbxassetid://133031915402113",
		["drop"] = "rbxassetid://118377862469616",
		["dropCircle"] = "rbxassetid://71240363811196",
		["dropCircleFill"] = "rbxassetid://88945998378182",
		["dropDegreesign"] = "rbxassetid://77649680596146",
		["dropDegreesignFill"] = "rbxassetid://94362397679873",
		["dropDegreesignSlash"] = "rbxassetid://110482944076581",
		["dropDegreesignSlashFill"] = "rbxassetid://71669882733811",
		["dropFill"] = "rbxassetid://85349169340444",
		["dropHalffull"] = "rbxassetid://91240077152622",
		["dropKeypadRectangle"] = "rbxassetid://70840237003373",
		["dropKeypadRectangleFill"] = "rbxassetid://125931309084435",
		["dropTransmission"] = "rbxassetid://101407191451186",
		["dropTriangle"] = "rbxassetid://84183738522099",
		["dropTriangleFill"] = "rbxassetid://90805606987344",
		["dryer"] = "rbxassetid://104968399783199",
		["dryerCircle"] = "rbxassetid://120074568345505",
		["dryerCircleFill"] = "rbxassetid://111654035272821",
		["dryerFill"] = "rbxassetid://136500520544490",
		["duffleBag"] = "rbxassetid://88923927348266",
		["duffleBagFill"] = "rbxassetid://99592794377634",
		["dumbbell"] = "rbxassetid://131658449144206",
		["dumbbellFill"] = "rbxassetid://102647184300293",
		["eCircle"] = "rbxassetid://103742511836669",
		["eCircleFill"] = "rbxassetid://95162271305994",
		["eSquare"] = "rbxassetid://101495905268164",
		["eSquareFill"] = "rbxassetid://90805151324988",
		["ear"] = "rbxassetid://93167066666811",
		["earBadgeCheckmark"] = "rbxassetid://118287233995960",
		["earBadgeWaveform"] = "rbxassetid://96770578331307",
		["earFill"] = "rbxassetid://74082991593421",
		["earTrianglebadgeExclamationmark"] = "rbxassetid://77722678508145",
		["earbudLeft"] = "rbxassetid://90739084119105",
		["earbudRight"] = "rbxassetid://70630407521257",
		["earbuds"] = "rbxassetid://79401980005894",
		["earbudsBoneConduction"] = "rbxassetid://102719667776865",
		["earbudsBoneConductionLeft"] = "rbxassetid://86650415805297",
		["earbudsBoneConductionRight"] = "rbxassetid://87823184053006",
		["earbudsCase"] = "rbxassetid://140476224814409",
		["earbudsCaseFill"] = "rbxassetid://111148501625727",
		["earbudsInEar"] = "rbxassetid://109063443614950",
		["earbudsInEarLeft"] = "rbxassetid://106492595834880",
		["earbudsInEarRight"] = "rbxassetid://125584398701209",
		["earbudsStemless"] = "rbxassetid://99846906714452",
		["earbudsStemlessLeft"] = "rbxassetid://98848664729808",
		["earbudsStemlessRight"] = "rbxassetid://122917678453047",
		["earpods"] = "rbxassetid://74278614743942",
		["eject"] = "rbxassetid://120765145931209",
		["ejectCircle"] = "rbxassetid://104332244648721",
		["ejectCircleFill"] = "rbxassetid://140628083571758",
		["ejectFill"] = "rbxassetid://71327024184670",
		["electronicTollCollection"] = "rbxassetid://136913224306634",
		["electronicTollCollectionRectangle"] = "rbxassetid://128593575467422",
		["electronicTollCollectionRectangleFill"] = "rbxassetid://112309550756861",
		["electronicTollCollectionRectangleSlash"] = "rbxassetid://95728463970850",
		["electronicTollCollectionRectangleSlashFill"] = "rbxassetid://125346120200754",
		["electronicTollCollectionRectangleTrianglebadgeExclamationmark"] = "rbxassetid://90467983733711",
		["electronicTollCollectionRectangleTrianglebadgeExclamationmarkFill"] = "rbxassetid://94360087978127",
		["ellipsis"] = "rbxassetid://124361135229418",
		["ellipsisBubble"] = "rbxassetid://126798458237130",
		["ellipsisBubbleFill"] = "rbxassetid://79069091642283",
		["ellipsisCalendar"] = "rbxassetid://124805713057261",
		["ellipsisCircle"] = "rbxassetid://113784442485781",
		["ellipsisCircleBadge"] = "rbxassetid://130244717421714",
		["ellipsisCircleBadgeFill"] = "rbxassetid://82159336176596",
		["ellipsisCircleFill"] = "rbxassetid://122334603788097",
		["ellipsisCurlybraces"] = "rbxassetid://107977531225704",
		["ellipsisMessage"] = "rbxassetid://80558243872489",
		["ellipsisMessageFill"] = "rbxassetid://132149801435799",
		["ellipsisRectangle"] = "rbxassetid://83388291144122",
		["ellipsisRectangleFill"] = "rbxassetid://117142929617215",
		["ellipsisVerticalBubble"] = "rbxassetid://72015532400199",
		["ellipsisVerticalBubbleFill"] = "rbxassetid://116203081148848",
		["ellipsisViewfinder"] = "rbxassetid://94637317080093",
		["engineCombustion"] = "rbxassetid://92302125521416",
		["engineCombustionBadgeExclamationmark"] = "rbxassetid://76712122282370",
		["engineCombustionBadgeExclamationmarkFill"] = "rbxassetid://89069786141963",
		["engineCombustionFill"] = "rbxassetid://99487338050460",
		["engineEmissionAndDrop2WaterWaveBelow"] = "rbxassetid://87305393152974",
		["engineEmissionAndExclamationmark"] = "rbxassetid://114464443552928",
		["engineEmissionAndFilter"] = "rbxassetid://127179695323664",
		["entryLeverKeypad"] = "rbxassetid://118027558598911",
		["entryLeverKeypadFill"] = "rbxassetid://118392320417223",
		["entryLeverKeypadTrianglebadgeExclamationmark"] = "rbxassetid://137214809742459",
		["entryLeverKeypadTrianglebadgeExclamationmarkFill"] = "rbxassetid://75303037354493",
		["envelope"] = "rbxassetid://106830949234316",
		["envelopeAndArrow3Down"] = "rbxassetid://117149942819834",
		["envelopeAndArrow3DownFill"] = "rbxassetid://79378848825247",
		["envelopeAndArrowTriangleheadBranch"] = "rbxassetid://104523224983991",
		["envelopeAndArrowTriangleheadBranchFill"] = "rbxassetid://100707359290921",
		["envelopeAndHandRaised"] = "rbxassetid://78356406355168",
		["envelopeAndHandRaisedFill"] = "rbxassetid://107728689664001",
		["envelopeArrowTriangleBranch"] = "rbxassetid://124377309512740",
		["envelopeBadge"] = "rbxassetid://93576600755016",
		["envelopeBadgeFill"] = "rbxassetid://116876097672908",
		["envelopeBadgeMinus"] = "rbxassetid://130814870797193",
		["envelopeBadgeMinusFill"] = "rbxassetid://76642074014671",
		["envelopeBadgePersonCrop"] = "rbxassetid://105705646416572",
		["envelopeBadgePersonCropFill"] = "rbxassetid://79242615918290",
		["envelopeBadgePlus"] = "rbxassetid://107588810121905",
		["envelopeBadgePlusFill"] = "rbxassetid://117435240335216",
		["envelopeBadgeShieldHalfFilled"] = "rbxassetid://140515835641833",
		["envelopeBadgeShieldHalfFilledFill"] = "rbxassetid://81922163345893",
		["envelopeCircle"] = "rbxassetid://136873814874607",
		["envelopeCircleFill"] = "rbxassetid://111051395244412",
		["envelopeFill"] = "rbxassetid://127507072697652",
		["envelopeFront"] = "rbxassetid://122506649095626",
		["envelopeFrontFill"] = "rbxassetid://104299711974123",
		["envelopeOpen"] = "rbxassetid://100877378812997",
		["envelopeOpenBadgeClock"] = "rbxassetid://100228997184187",
		["envelopeOpenBadgeClockFill"] = "rbxassetid://71379109503673",
		["envelopeOpenFill"] = "rbxassetid://85763605331589",
		["envelopeStack"] = "rbxassetid://87145831106000",
		["envelopeStackFill"] = "rbxassetid://123354851119926",
		["environments"] = "rbxassetid://70776273028500",
		["environmentsCircle"] = "rbxassetid://105521855459846",
		["environmentsCircleFill"] = "rbxassetid://104935991380195",
		["environmentsFill"] = "rbxassetid://105632666776458",
		["environmentsSlash"] = "rbxassetid://104765532616958",
		["environmentsSlashCircle"] = "rbxassetid://78007865985283",
		["environmentsSlashCircleFill"] = "rbxassetid://91748220983526",
		["environmentsSlashFill"] = "rbxassetid://75145189219140",
		["equal"] = "rbxassetid://81928889048192",
		["equalCircle"] = "rbxassetid://79382669951914",
		["equalCircleFill"] = "rbxassetid://86371079165197",
		["equalSquare"] = "rbxassetid://79936726576289",
		["equalSquareFill"] = "rbxassetid://104388387477692",
		["eraser"] = "rbxassetid://131139520079799",
		["eraserBadgeXmark"] = "rbxassetid://80645300777635",
		["eraserBadgeXmarkFill"] = "rbxassetid://110922477071984",
		["eraserFill"] = "rbxassetid://108705331076102",
		["eraserLineDashed"] = "rbxassetid://76929643809652",
		["eraserLineDashedFill"] = "rbxassetid://81891295746096",
		["eraserSlash"] = "rbxassetid://136706221907454",
		["eraserSlashFill"] = "rbxassetid://83380933600841",
		["eraserTrianglebadgeExclamationmark"] = "rbxassetid://105319193923389",
		["eraserTrianglebadgeExclamationmarkFill"] = "rbxassetid://98230351518742",
		["escape"] = "rbxassetid://133789976668661",
		["esim"] = "rbxassetid://131303958903026",
		["esimFill"] = "rbxassetid://86636914917717",
		["eurosign"] = "rbxassetid://82925976421520",
		["eurosignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://99526735026701",
		["eurosignBankBuilding"] = "rbxassetid://89483927128263",
		["eurosignBankBuildingFill"] = "rbxassetid://108012299359814",
		["eurosignCircle"] = "rbxassetid://140251138055967",
		["eurosignCircleFill"] = "rbxassetid://87679842728207",
		["eurosignGaugeChartLefthalfRighthalf"] = "rbxassetid://114065360584117",
		["eurosignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://72338154797145",
		["eurosignRing"] = "rbxassetid://134135280297519",
		["eurosignRingDashed"] = "rbxassetid://81105789808808",
		["eurosignSquare"] = "rbxassetid://118857707505659",
		["eurosignSquareFill"] = "rbxassetid://85458107728944",
		["eurozonesign"] = "rbxassetid://106111186723394",
		["eurozonesignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://96687530526973",
		["eurozonesignBankBuilding"] = "rbxassetid://101771619031147",
		["eurozonesignBankBuildingFill"] = "rbxassetid://125592888577896",
		["eurozonesignCircle"] = "rbxassetid://114038615288773",
		["eurozonesignCircleFill"] = "rbxassetid://82301050010699",
		["eurozonesignGaugeChartLefthalfRighthalf"] = "rbxassetid://123642748750595",
		["eurozonesignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://139979957807793",
		["eurozonesignRing"] = "rbxassetid://105011696428140",
		["eurozonesignRingDashed"] = "rbxassetid://93030366645152",
		["eurozonesignSquare"] = "rbxassetid://105016814402384",
		["eurozonesignSquareFill"] = "rbxassetid://112888895324413",
		["evCharger"] = "rbxassetid://97939002186339",
		["evChargerArrowtriangleLeft"] = "rbxassetid://78531181074444",
		["evChargerArrowtriangleLeftFill"] = "rbxassetid://129265466116295",
		["evChargerArrowtriangleRight"] = "rbxassetid://73571516368733",
		["evChargerArrowtriangleRightFill"] = "rbxassetid://133332267515902",
		["evChargerExclamationmark"] = "rbxassetid://71284303991317",
		["evChargerExclamationmarkFill"] = "rbxassetid://73242768019910",
		["evChargerFill"] = "rbxassetid://135357327350082",
		["evChargerSlash"] = "rbxassetid://119392987220859",
		["evChargerSlashFill"] = "rbxassetid://117895186907340",
		["evPlugAcGbT"] = "rbxassetid://124662740249269",
		["evPlugAcGbTFill"] = "rbxassetid://97796850278979",
		["evPlugAcType1"] = "rbxassetid://105942058683839",
		["evPlugAcType1Fill"] = "rbxassetid://87565275880095",
		["evPlugAcType2"] = "rbxassetid://109491714154043",
		["evPlugAcType2Fill"] = "rbxassetid://136749111819862",
		["evPlugDcCcs1"] = "rbxassetid://111896860617304",
		["evPlugDcCcs1Fill"] = "rbxassetid://135258359505207",
		["evPlugDcCcs2"] = "rbxassetid://89215178998105",
		["evPlugDcCcs2Fill"] = "rbxassetid://132543470987109",
		["evPlugDcChademo"] = "rbxassetid://118191687282802",
		["evPlugDcChademoFill"] = "rbxassetid://115432509818358",
		["evPlugDcGbT"] = "rbxassetid://99656496942844",
		["evPlugDcGbTFill"] = "rbxassetid://76353846804034",
		["evPlugDcNacs"] = "rbxassetid://128552750734766",
		["evPlugDcNacsFill"] = "rbxassetid://72083694831744",
		["exclamationmark"] = "rbxassetid://105489810797515",
		["exclamationmark2"] = "rbxassetid://138940800083904",
		["exclamationmark3"] = "rbxassetid://96062819103435",
		["exclamationmarkApplewatch"] = "rbxassetid://70859643783699",
		["exclamationmarkArrowCirclepath"] = "rbxassetid://111446640991646",
		["exclamationmarkArrowTriangle2Circlepath"] = "rbxassetid://121048701816249",
		["exclamationmarkArrowTrianglehead2ClockwiseRotate90"] = "rbxassetid://87427147276965",
		["exclamationmarkArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://120412511808787",
		["exclamationmarkBrakesignal"] = "rbxassetid://73594089484983",
		["exclamationmarkBubble"] = "rbxassetid://95883853598192",
		["exclamationmarkBubbleCircle"] = "rbxassetid://75160551591562",
		["exclamationmarkBubbleCircleFill"] = "rbxassetid://94137052992947",
		["exclamationmarkBubbleFill"] = "rbxassetid://120138139594154",
		["exclamationmarkCircle"] = "rbxassetid://124980468238909",
		["exclamationmarkCircleFill"] = "rbxassetid://118467060972001",
		["exclamationmarkIcloud"] = "rbxassetid://76695078178669",
		["exclamationmarkIcloudFill"] = "rbxassetid://131208143896029",
		["exclamationmarkLock"] = "rbxassetid://106384248542364",
		["exclamationmarkLockFill"] = "rbxassetid://109195138504207",
		["exclamationmarkMagnifyingglass"] = "rbxassetid://92574625679787",
		["exclamationmarkMessage"] = "rbxassetid://138562668016011",
		["exclamationmarkMessageFill"] = "rbxassetid://132448718389247",
		["exclamationmarkOctagon"] = "rbxassetid://137747340644933",
		["exclamationmarkOctagonFill"] = "rbxassetid://105984442012480",
		["exclamationmarkQuestionmark"] = "rbxassetid://92436083739221",
		["exclamationmarkShield"] = "rbxassetid://112276285190661",
		["exclamationmarkShieldFill"] = "rbxassetid://83928233244528",
		["exclamationmarkSquare"] = "rbxassetid://80560347785472",
		["exclamationmarkSquareFill"] = "rbxassetid://116001111235657",
		["exclamationmarkTirepressure"] = "rbxassetid://91238920104209",
		["exclamationmarkTransmission"] = "rbxassetid://102604704591626",
		["exclamationmarkTriangle"] = "rbxassetid://107822175160368",
		["exclamationmarkTriangleFill"] = "rbxassetid://114874558386316",
		["exclamationmarkTriangleTextPage"] = "rbxassetid://129462348942674",
		["exclamationmarkTriangleTextPageFill"] = "rbxassetid://87819250469566",
		["exclamationmarkWarninglight"] = "rbxassetid://129488082492608",
		["exclamationmarkWarninglightFill"] = "rbxassetid://109563951728634",
		["externaldrive"] = "rbxassetid://80232260950078",
		["externaldriveBadgeCheckmark"] = "rbxassetid://127808980665357",
		["externaldriveBadgeExclamationmark"] = "rbxassetid://138816851149625",
		["externaldriveBadgeIcloud"] = "rbxassetid://134043240118451",
		["externaldriveBadgeMinus"] = "rbxassetid://93718911516002",
		["externaldriveBadgePersonCrop"] = "rbxassetid://131468993878865",
		["externaldriveBadgePlus"] = "rbxassetid://120630286835644",
		["externaldriveBadgeQuestionmark"] = "rbxassetid://95288528165880",
		["externaldriveBadgeTimemachine"] = "rbxassetid://98241082446758",
		["externaldriveBadgeWifi"] = "rbxassetid://79557098906550",
		["externaldriveBadgeXmark"] = "rbxassetid://122842097395468",
		["externaldriveConnectedToLineBelow"] = "rbxassetid://130509526753365",
		["externaldriveConnectedToLineBelowFill"] = "rbxassetid://95945834927517",
		["externaldriveFill"] = "rbxassetid://111188851017397",
		["externaldriveFillBadgeCheckmark"] = "rbxassetid://122664727689795",
		["externaldriveFillBadgeExclamationmark"] = "rbxassetid://139443980658229",
		["externaldriveFillBadgeIcloud"] = "rbxassetid://111658236910597",
		["externaldriveFillBadgeMinus"] = "rbxassetid://138322201910424",
		["externaldriveFillBadgePersonCrop"] = "rbxassetid://128003216586005",
		["externaldriveFillBadgePlus"] = "rbxassetid://114554892368455",
		["externaldriveFillBadgeQuestionmark"] = "rbxassetid://76317585194672",
		["externaldriveFillBadgeTimemachine"] = "rbxassetid://106899749894347",
		["externaldriveFillBadgeWifi"] = "rbxassetid://72486197994673",
		["externaldriveFillBadgeXmark"] = "rbxassetid://98595452028940",
		["externaldriveFillTrianglebadgeExclamationmark"] = "rbxassetid://98123683908795",
		["externaldriveTrianglebadgeExclamationmark"] = "rbxassetid://106750675144343",
		["eye"] = "rbxassetid://111055543166389",
		["eyeCircle"] = "rbxassetid://107190923208298",
		["eyeCircleFill"] = "rbxassetid://135793946948356",
		["eyeFill"] = "rbxassetid://77235800413545",
		["eyeHalfClosed"] = "rbxassetid://77207415123898",
		["eyeHalfClosedFill"] = "rbxassetid://113576230437344",
		["eyeSlash"] = "rbxassetid://119498809185323",
		["eyeSlashCircle"] = "rbxassetid://132524732539324",
		["eyeSlashCircleFill"] = "rbxassetid://103154106288950",
		["eyeSlashFill"] = "rbxassetid://81778913526360",
		["eyeSquare"] = "rbxassetid://95242157997285",
		["eyeSquareFill"] = "rbxassetid://126083471525251",
		["eyeTrianglebadgeExclamationmark"] = "rbxassetid://89778592723539",
		["eyeTrianglebadgeExclamationmarkFill"] = "rbxassetid://109952601896975",
		["eyebrow"] = "rbxassetid://138874889430672",
		["eyedropper"] = "rbxassetid://122887134386475",
		["eyedropperFull"] = "rbxassetid://91873383286058",
		["eyedropperHalffull"] = "rbxassetid://110456203480587",
		["eyeglasses"] = "rbxassetid://81029046265930",
		["eyeglassesSlash"] = "rbxassetid://124054712844326",
		["eyes"] = "rbxassetid://78678714479511",
		["eyesInverse"] = "rbxassetid://79358575110860",
		["fCircle"] = "rbxassetid://120350062281724",
		["fCircleFill"] = "rbxassetid://85941153359585",
		["fCursive"] = "rbxassetid://121112615529535",
		["fCursiveCircle"] = "rbxassetid://118145351560598",
		["fCursiveCircleFill"] = "rbxassetid://79867894564651",
		["fCursiveSlash"] = "rbxassetid://82830783756850",
		["fSquare"] = "rbxassetid://138319993082756",
		["fSquareFill"] = "rbxassetid://103704824525018",
		["faceDashed"] = "rbxassetid://115965004314399",
		["faceDashedFill"] = "rbxassetid://85477783339034",
		["faceSmiling"] = "rbxassetid://78636671887809",
		["faceSmilingInverse"] = "rbxassetid://89152469821007",
		["faceid"] = "rbxassetid://95081493927842",
		["facemask"] = "rbxassetid://99230089481142",
		["facemaskFill"] = "rbxassetid://87358950271058",
		["fan"] = "rbxassetid://104236974088032",
		["fanAndLightCeiling"] = "rbxassetid://107305354245185",
		["fanAndLightCeilingFill"] = "rbxassetid://79601447011266",
		["fanBadgeArrowUpAndDownAndArrowLeftAndRight"] = "rbxassetid://113898399220980",
		["fanBadgeArrowUpAndDownAndArrowLeftAndRightFill"] = "rbxassetid://124338705997821",
		["fanBadgeAutomatic"] = "rbxassetid://134431646851799",
		["fanBadgeAutomaticFill"] = "rbxassetid://136476275577129",
		["fanCeiling"] = "rbxassetid://96665114463151",
		["fanCeilingFill"] = "rbxassetid://138987560662626",
		["fanCircle"] = "rbxassetid://70854430102154",
		["fanCircleFill"] = "rbxassetid://117605684696409",
		["fanDesk"] = "rbxassetid://114862891749128",
		["fanDeskFill"] = "rbxassetid://93071498661239",
		["fanFill"] = "rbxassetid://77445753113040",
		["fanFloor"] = "rbxassetid://109401757372728",
		["fanFloorFill"] = "rbxassetid://81956707111904",
		["fanGaugeOpen"] = "rbxassetid://116949823717075",
		["fanOscillation"] = "rbxassetid://140040205782084",
		["fanOscillationFill"] = "rbxassetid://95940480162856",
		["fanSlash"] = "rbxassetid://88988508555905",
		["fanSlashFill"] = "rbxassetid://91132405529736",
		["faxmachine"] = "rbxassetid://98463604203755",
		["faxmachineFill"] = "rbxassetid://133950895418533",
		["ferry"] = "rbxassetid://104552475367467",
		["ferryFill"] = "rbxassetid://135078258733005",
		["fibrechannel"] = "rbxassetid://98030247410028",
		["fieldOfViewUltrawide"] = "rbxassetid://114057852168752",
		["fieldOfViewUltrawideFill"] = "rbxassetid://83751448891679",
		["fieldOfViewWide"] = "rbxassetid://96004890847207",
		["fieldOfViewWideFill"] = "rbxassetid://137899142791405",
		["figure"] = "rbxassetid://110213647176253",
		["figure2"] = "rbxassetid://138808308230792",
		["figure2AndChildHoldinghands"] = "rbxassetid://102771612569539",
		["figure2ArmsOpen"] = "rbxassetid://92288487915619",
		["figure2Circle"] = "rbxassetid://94206481778029",
		["figure2CircleFill"] = "rbxassetid://129196015079328",
		["figure2LeftHoldinghands"] = "rbxassetid://100537110943074",
		["figure2RightHoldinghands"] = "rbxassetid://119526196408433",
		["figureAmericanFootball"] = "rbxassetid://91093899560194",
		["figureAmericanFootballCircle"] = "rbxassetid://73526407862195",
		["figureAmericanFootballCircleFill"] = "rbxassetid://125643881949592",
		["figureAndChildHoldinghands"] = "rbxassetid://98234143469303",
		["figureArchery"] = "rbxassetid://91146536671456",
		["figureArcheryCircle"] = "rbxassetid://126114292998662",
		["figureArcheryCircleFill"] = "rbxassetid://139817967546701",
		["figureArmsOpen"] = "rbxassetid://91747516641055",
		["figureAustralianFootball"] = "rbxassetid://95801007298244",
		["figureAustralianFootballCircle"] = "rbxassetid://114857191814495",
		["figureAustralianFootballCircleFill"] = "rbxassetid://96243863542381",
		["figureBadminton"] = "rbxassetid://76476251455465",
		["figureBadmintonCircle"] = "rbxassetid://89195992414478",
		["figureBadmintonCircleFill"] = "rbxassetid://114444756914155",
		["figureBarre"] = "rbxassetid://110544483608061",
		["figureBarreCircle"] = "rbxassetid://135837012134445",
		["figureBarreCircleFill"] = "rbxassetid://127607577096807",
		["figureBaseball"] = "rbxassetid://97849278832097",
		["figureBaseballCircle"] = "rbxassetid://114304222609888",
		["figureBaseballCircleFill"] = "rbxassetid://123393585149734",
		["figureBasketball"] = "rbxassetid://70458961636702",
		["figureBasketballCircle"] = "rbxassetid://133108362517016",
		["figureBasketballCircleFill"] = "rbxassetid://118516949832825",
		["figureBowling"] = "rbxassetid://87430224954145",
		["figureBowlingCircle"] = "rbxassetid://92291199433832",
		["figureBowlingCircleFill"] = "rbxassetid://83424282699101",
		["figureBoxing"] = "rbxassetid://85849315745014",
		["figureBoxingCircle"] = "rbxassetid://108865178770018",
		["figureBoxingCircleFill"] = "rbxassetid://103918369499522",
		["figureChild"] = "rbxassetid://110064985871757",
		["figureChildAndLock"] = "rbxassetid://73535299980245",
		["figureChildAndLockFill"] = "rbxassetid://71218198833330",
		["figureChildAndLockOpen"] = "rbxassetid://108694793096350",
		["figureChildAndLockOpenFill"] = "rbxassetid://125673450678214",
		["figureChildCircle"] = "rbxassetid://81423849672320",
		["figureChildCircleFill"] = "rbxassetid://82354760379505",
		["figureClimbing"] = "rbxassetid://120678773528166",
		["figureClimbingCircle"] = "rbxassetid://120120038724485",
		["figureClimbingCircleFill"] = "rbxassetid://132240539735275",
		["figureCooldown"] = "rbxassetid://92932298775664",
		["figureCooldownCircle"] = "rbxassetid://116114093190620",
		["figureCooldownCircleFill"] = "rbxassetid://121936218292480",
		["figureCoreTraining"] = "rbxassetid://123052378717278",
		["figureCoreTrainingCircle"] = "rbxassetid://72613470087026",
		["figureCoreTrainingCircleFill"] = "rbxassetid://89955491381206",
		["figureCricket"] = "rbxassetid://116071257091954",
		["figureCricketCircle"] = "rbxassetid://134233377377044",
		["figureCricketCircleFill"] = "rbxassetid://72325772863796",
		["figureCrossTraining"] = "rbxassetid://73418643387339",
		["figureCrossTrainingCircle"] = "rbxassetid://72456662052046",
		["figureCrossTrainingCircleFill"] = "rbxassetid://77850653388101",
		["figureCurling"] = "rbxassetid://133903499695545",
		["figureCurlingCircle"] = "rbxassetid://125787714674084",
		["figureCurlingCircleFill"] = "rbxassetid://119803288536473",
		["figureDance"] = "rbxassetid://82823113185452",
		["figureDanceCircle"] = "rbxassetid://129448865281588",
		["figureDanceCircleFill"] = "rbxassetid://99987979019469",
		["figureDiscSports"] = "rbxassetid://97666785998608",
		["figureDiscSportsCircle"] = "rbxassetid://111401373560932",
		["figureDiscSportsCircleFill"] = "rbxassetid://71691339998044",
		["figureDressLineVerticalFigure"] = "rbxassetid://100940012571116",
		["figureElliptical"] = "rbxassetid://103011240387444",
		["figureEllipticalCircle"] = "rbxassetid://131478855174617",
		["figureEllipticalCircleFill"] = "rbxassetid://104064244810242",
		["figureEquestrianSports"] = "rbxassetid://113004809635168",
		["figureEquestrianSportsCircle"] = "rbxassetid://85892477745919",
		["figureEquestrianSportsCircleFill"] = "rbxassetid://97852470945461",
		["figureFall"] = "rbxassetid://78917096397322",
		["figureFallCircle"] = "rbxassetid://120817219815068",
		["figureFallCircleFill"] = "rbxassetid://131207735766677",
		["figureFencing"] = "rbxassetid://88727868093192",
		["figureFencingCircle"] = "rbxassetid://106032601544162",
		["figureFencingCircleFill"] = "rbxassetid://98217461416689",
		["figureFieldHockey"] = "rbxassetid://97574076033706",
		["figureFieldHockeyCircle"] = "rbxassetid://104931510950353",
		["figureFieldHockeyCircleFill"] = "rbxassetid://130141092753763",
		["figureFishing"] = "rbxassetid://97928619322397",
		["figureFishingCircle"] = "rbxassetid://110360794736175",
		["figureFishingCircleFill"] = "rbxassetid://136506795917678",
		["figureFlexibility"] = "rbxassetid://102643174092557",
		["figureFlexibilityCircle"] = "rbxassetid://107915680316772",
		["figureFlexibilityCircleFill"] = "rbxassetid://131562203565834",
		["figureGolf"] = "rbxassetid://108030447882352",
		["figureGolfCircle"] = "rbxassetid://75259568650212",
		["figureGolfCircleFill"] = "rbxassetid://78581076173636",
		["figureGymnastics"] = "rbxassetid://110639559835087",
		["figureGymnasticsCircle"] = "rbxassetid://123858181191697",
		["figureGymnasticsCircleFill"] = "rbxassetid://102190187170175",
		["figureHandCycling"] = "rbxassetid://105321743988781",
		["figureHandCyclingCircle"] = "rbxassetid://85007285093415",
		["figureHandCyclingCircleFill"] = "rbxassetid://91530596716487",
		["figureHandball"] = "rbxassetid://115838442370626",
		["figureHandballCircle"] = "rbxassetid://70759727291307",
		["figureHandballCircleFill"] = "rbxassetid://119475164895904",
		["figureHighintensityIntervaltraining"] = "rbxassetid://76737326147568",
		["figureHighintensityIntervaltrainingCircle"] = "rbxassetid://80397488456920",
		["figureHighintensityIntervaltrainingCircleFill"] = "rbxassetid://98555009338585",
		["figureHiking"] = "rbxassetid://95596775753518",
		["figureHikingCircle"] = "rbxassetid://138221954074963",
		["figureHikingCircleFill"] = "rbxassetid://88401031990874",
		["figureHockey"] = "rbxassetid://90256454862003",
		["figureHockeyCircle"] = "rbxassetid://94383755687550",
		["figureHockeyCircleFill"] = "rbxassetid://136334583328074",
		["figureHunting"] = "rbxassetid://104331371922960",
		["figureHuntingCircle"] = "rbxassetid://127527976370774",
		["figureHuntingCircleFill"] = "rbxassetid://81475211852623",
		["figureIceHockey"] = "rbxassetid://107583026067878",
		["figureIceHockeyCircle"] = "rbxassetid://118193809208332",
		["figureIceHockeyCircleFill"] = "rbxassetid://111522178102920",
		["figureIceSkating"] = "rbxassetid://135617966638935",
		["figureIceSkatingCircle"] = "rbxassetid://138214165419825",
		["figureIceSkatingCircleFill"] = "rbxassetid://98770013409291",
		["figureIndoorCycle"] = "rbxassetid://80969946389201",
		["figureIndoorCycleCircle"] = "rbxassetid://134390336862454",
		["figureIndoorCycleCircleFill"] = "rbxassetid://95479995212663",
		["figureIndoorRowing"] = "rbxassetid://84240034900060",
		["figureIndoorRowingCircle"] = "rbxassetid://136778375743254",
		["figureIndoorRowingCircleFill"] = "rbxassetid://106705352180779",
		["figureIndoorSoccer"] = "rbxassetid://101995448808644",
		["figureIndoorSoccerCircle"] = "rbxassetid://98693757644611",
		["figureIndoorSoccerCircleFill"] = "rbxassetid://115853013474405",
		["figureJumprope"] = "rbxassetid://112314762824266",
		["figureJumpropeCircle"] = "rbxassetid://131867434437690",
		["figureJumpropeCircleFill"] = "rbxassetid://82475486201404",
		["figureKickboxing"] = "rbxassetid://71547925836213",
		["figureKickboxingCircle"] = "rbxassetid://111712574527276",
		["figureKickboxingCircleFill"] = "rbxassetid://90368178358769",
		["figureLacrosse"] = "rbxassetid://131555411154516",
		["figureLacrosseCircle"] = "rbxassetid://125836289315347",
		["figureLacrosseCircleFill"] = "rbxassetid://128431465303733",
		["figureMartialArts"] = "rbxassetid://135745150496906",
		["figureMartialArtsCircle"] = "rbxassetid://119796908146049",
		["figureMartialArtsCircleFill"] = "rbxassetid://113266429878233",
		["figureMindAndBody"] = "rbxassetid://103860527144324",
		["figureMindAndBodyCircle"] = "rbxassetid://106858535249934",
		["figureMindAndBodyCircleFill"] = "rbxassetid://138656680070798",
		["figureMixedCardio"] = "rbxassetid://121353989624376",
		["figureMixedCardioCircle"] = "rbxassetid://124865593330962",
		["figureMixedCardioCircleFill"] = "rbxassetid://133316587934777",
		["figureOpenWaterSwim"] = "rbxassetid://99134075301751",
		["figureOpenWaterSwimCircle"] = "rbxassetid://135738254961736",
		["figureOpenWaterSwimCircleFill"] = "rbxassetid://73573960201738",
		["figureOutdoorCycle"] = "rbxassetid://94389585238104",
		["figureOutdoorCycleCircle"] = "rbxassetid://104565216263530",
		["figureOutdoorCycleCircleFill"] = "rbxassetid://85407648912798",
		["figureOutdoorRowing"] = "rbxassetid://97214365802337",
		["figureOutdoorRowingCircle"] = "rbxassetid://110435954031642",
		["figureOutdoorRowingCircleFill"] = "rbxassetid://89699495932779",
		["figureOutdoorSoccer"] = "rbxassetid://111514292464663",
		["figureOutdoorSoccerCircle"] = "rbxassetid://78804307665587",
		["figureOutdoorSoccerCircleFill"] = "rbxassetid://84815226618665",
		["figurePickleball"] = "rbxassetid://103908880748936",
		["figurePickleballCircle"] = "rbxassetid://136344983007459",
		["figurePickleballCircleFill"] = "rbxassetid://71182848325604",
		["figurePilates"] = "rbxassetid://108752699363037",
		["figurePilatesCircle"] = "rbxassetid://113467772255977",
		["figurePilatesCircleFill"] = "rbxassetid://132440163880650",
		["figurePlay"] = "rbxassetid://125930862891634",
		["figurePlayCircle"] = "rbxassetid://77583381787661",
		["figurePlayCircleFill"] = "rbxassetid://134400678202309",
		["figurePoolSwim"] = "rbxassetid://137689299313028",
		["figurePoolSwimCircle"] = "rbxassetid://89666987644291",
		["figurePoolSwimCircleFill"] = "rbxassetid://92630998913564",
		["figureRacquetball"] = "rbxassetid://99889129274922",
		["figureRacquetballCircle"] = "rbxassetid://129504301099369",
		["figureRacquetballCircleFill"] = "rbxassetid://78638439110000",
		["figureRoll"] = "rbxassetid://92890687621570",
		["figureRollCircle"] = "rbxassetid://115447965292337",
		["figureRollCircleFill"] = "rbxassetid://78758776592473",
		["figureRollRunningpace"] = "rbxassetid://103258084151079",
		["figureRollRunningpaceCircle"] = "rbxassetid://119394454598856",
		["figureRollRunningpaceCircleFill"] = "rbxassetid://71338146987517",
		["figureRolling"] = "rbxassetid://96544717929655",
		["figureRollingCircle"] = "rbxassetid://130243270009292",
		["figureRollingCircleFill"] = "rbxassetid://81436799482432",
		["figureRower"] = "rbxassetid://101478600974292",
		["figureRugby"] = "rbxassetid://109148647244317",
		["figureRugbyCircle"] = "rbxassetid://121768904436252",
		["figureRugbyCircleFill"] = "rbxassetid://124286693797479",
		["figureRun"] = "rbxassetid://113159658934048",
		["figureRunCircle"] = "rbxassetid://107121944951745",
		["figureRunCircleFill"] = "rbxassetid://134197067094502",
		["figureRunSquareStack"] = "rbxassetid://112190947223332",
		["figureRunSquareStackFill"] = "rbxassetid://79407822771023",
		["figureRunTreadmill"] = "rbxassetid://72845166434800",
		["figureRunTreadmillCircle"] = "rbxassetid://100935270576310",
		["figureRunTreadmillCircleFill"] = "rbxassetid://90094962041285",
		["figureSailing"] = "rbxassetid://101372266533215",
		["figureSailingCircle"] = "rbxassetid://132108643163002",
		["figureSailingCircleFill"] = "rbxassetid://105305283071460",
		["figureSeatedSeatbelt"] = "rbxassetid://106552740060057",
		["figureSeatedSeatbeltAndAirbagOff"] = "rbxassetid://98186865777515",
		["figureSeatedSeatbeltAndAirbagOn"] = "rbxassetid://91150009110532",
		["figureSeatedSeatbeltLeftDriveSeats1"] = "rbxassetid://85946255939735",
		["figureSeatedSeatbeltLeftDriveSeats11"] = "rbxassetid://79678492525730",
		["figureSeatedSeatbeltLeftDriveSeats11Fill"] = "rbxassetid://129089651219076",
		["figureSeatedSeatbeltLeftDriveSeats12"] = "rbxassetid://93143466530275",
		["figureSeatedSeatbeltLeftDriveSeats12Fill"] = "rbxassetid://105065766784936",
		["figureSeatedSeatbeltLeftDriveSeats1Fill"] = "rbxassetid://113481718311782",
		["figureSeatedSeatbeltLeftDriveSeats2"] = "rbxassetid://75226954452926",
		["figureSeatedSeatbeltLeftDriveSeats22"] = "rbxassetid://101101160267265",
		["figureSeatedSeatbeltLeftDriveSeats222"] = "rbxassetid://118909297450613",
		["figureSeatedSeatbeltLeftDriveSeats222Fill"] = "rbxassetid://93791159425519",
		["figureSeatedSeatbeltLeftDriveSeats223"] = "rbxassetid://78036184824175",
		["figureSeatedSeatbeltLeftDriveSeats223Fill"] = "rbxassetid://92266074429811",
		["figureSeatedSeatbeltLeftDriveSeats22Fill"] = "rbxassetid://116221944283747",
		["figureSeatedSeatbeltLeftDriveSeats23"] = "rbxassetid://127024965881932",
		["figureSeatedSeatbeltLeftDriveSeats232"] = "rbxassetid://117513359005767",
		["figureSeatedSeatbeltLeftDriveSeats232Fill"] = "rbxassetid://82664717592655",
		["figureSeatedSeatbeltLeftDriveSeats233"] = "rbxassetid://119483437512021",
		["figureSeatedSeatbeltLeftDriveSeats233Fill"] = "rbxassetid://71345890100600",
		["figureSeatedSeatbeltLeftDriveSeats23Fill"] = "rbxassetid://131875209072674",
		["figureSeatedSeatbeltLeftDriveSeats2Fill"] = "rbxassetid://79587393298221",
		["figureSeatedSeatbeltLeftDriveSeats3"] = "rbxassetid://74148888025573",
		["figureSeatedSeatbeltLeftDriveSeats33"] = "rbxassetid://116237917433348",
		["figureSeatedSeatbeltLeftDriveSeats333"] = "rbxassetid://74481906475225",
		["figureSeatedSeatbeltLeftDriveSeats333Fill"] = "rbxassetid://117037471107630",
		["figureSeatedSeatbeltLeftDriveSeats33Fill"] = "rbxassetid://128363081385683",
		["figureSeatedSeatbeltLeftDriveSeats3Fill"] = "rbxassetid://107990648154861",
		["figureSeatedSide"] = "rbxassetid://103157176969588",
		["figureSeatedSideAirDistributionLower"] = "rbxassetid://120257665940386",
		["figureSeatedSideAirDistributionMiddle"] = "rbxassetid://92433515109818",
		["figureSeatedSideAirDistributionMiddleAndLower"] = "rbxassetid://118216495126795",
		["figureSeatedSideAirDistributionMiddleAndLowerAngled"] = "rbxassetid://132877218661072",
		["figureSeatedSideAirDistributionUpper"] = "rbxassetid://80332126775420",
		["figureSeatedSideAirDistributionUpperAngledAndLowerAngled"] = "rbxassetid://128830311959827",
		["figureSeatedSideAirDistributionUpperAngledAndMiddle"] = "rbxassetid://110778248234270",
		["figureSeatedSideAirDistributionUpperAngledAndMiddleAndLowerAngled"] = "rbxassetid://112235343241027",
		["figureSeatedSideAirbagOff"] = "rbxassetid://104984860910066",
		["figureSeatedSideAirbagOff2"] = "rbxassetid://123574096899524",
		["figureSeatedSideAirbagOn"] = "rbxassetid://112751749735103",
		["figureSeatedSideAirbagOn2"] = "rbxassetid://133224719349931",
		["figureSeatedSideAutomatic"] = "rbxassetid://136215915659039",
		["figureSeatedSideLeft"] = "rbxassetid://77481740371688",
		["figureSeatedSideLeftAirDistributionIndirect"] = "rbxassetid://79336558528852",
		["figureSeatedSideLeftAirDistributionLower"] = "rbxassetid://127392790646826",
		["figureSeatedSideLeftAirDistributionLowerAngledAndUpperAngled"] = "rbxassetid://112078481062843",
		["figureSeatedSideLeftAirDistributionMiddle"] = "rbxassetid://78706747938686",
		["figureSeatedSideLeftAirDistributionMiddleAndLower"] = "rbxassetid://100831410587505",
		["figureSeatedSideLeftAirDistributionMiddleAndLowerAngled"] = "rbxassetid://75259277174467",
		["figureSeatedSideLeftAirDistributionUpper"] = "rbxassetid://74202315829466",
		["figureSeatedSideLeftAirDistributionUpperAndMiddleAndLower"] = "rbxassetid://114743873533519",
		["figureSeatedSideLeftAirDistributionUpperAngledAndDottedlineAndLowerAngled"] = "rbxassetid://74199874956849",
		["figureSeatedSideLeftAirDistributionUpperAngledAndLowerAngled"] = "rbxassetid://105111573378012",
		["figureSeatedSideLeftAirDistributionUpperAngledAndMiddle"] = "rbxassetid://89346514926957",
		["figureSeatedSideLeftAirDistributionUpperAngledAndMiddleAndLowerAngled"] = "rbxassetid://80317618153794",
		["figureSeatedSideLeftAirbagOff"] = "rbxassetid://86363377016551",
		["figureSeatedSideLeftAirbagOff2"] = "rbxassetid://131286776968522",
		["figureSeatedSideLeftAirbagOn"] = "rbxassetid://82060834562607",
		["figureSeatedSideLeftAirbagOn2"] = "rbxassetid://93600189126601",
		["figureSeatedSideLeftAutomatic"] = "rbxassetid://96448990318081",
		["figureSeatedSideLeftFan"] = "rbxassetid://95773073671580",
		["figureSeatedSideLeftSteeringwheel"] = "rbxassetid://99756030999052",
		["figureSeatedSideLeftWindshieldFrontAndHeatWaves"] = "rbxassetid://92505789545181",
		["figureSeatedSideLeftWindshieldFrontAndHeatWavesAirDistributionLower"] = "rbxassetid://137421564202284",
		["figureSeatedSideLeftWindshieldFrontAndHeatWavesAirDistributionMiddle"] = "rbxassetid://81437547930986",
		["figureSeatedSideLeftWindshieldFrontAndHeatWavesAirDistributionMiddleAndLower"] = "rbxassetid://136445257646948",
		["figureSeatedSideLeftWindshieldFrontAndHeatWavesAirDistributionUpper"] = "rbxassetid://88397915417301",
		["figureSeatedSideLeftWindshieldFrontAndHeatWavesAirDistributionUpperAndLower"] = "rbxassetid://92086059777005",
		["figureSeatedSideLeftWindshieldFrontAndHeatWavesAirDistributionUpperAndMiddle"] = "rbxassetid://88932521630743",
		["figureSeatedSideLeftWindshieldFrontAndHeatWavesAirDistributionUpperAndMiddleAndLower"] = "rbxassetid://89902175830534",
		["figureSeatedSideRight"] = "rbxassetid://136726651600980",
		["figureSeatedSideRightAirDistributionIndirect"] = "rbxassetid://89934262166596",
		["figureSeatedSideRightAirDistributionLower"] = "rbxassetid://73300805424690",
		["figureSeatedSideRightAirDistributionLowerAngledAndUpperAngled"] = "rbxassetid://112866271533668",
		["figureSeatedSideRightAirDistributionMiddle"] = "rbxassetid://112098509009862",
		["figureSeatedSideRightAirDistributionMiddleAndLower"] = "rbxassetid://140706729304027",
		["figureSeatedSideRightAirDistributionMiddleAndLowerAngled"] = "rbxassetid://112352134374515",
		["figureSeatedSideRightAirDistributionUpper"] = "rbxassetid://98585139293028",
		["figureSeatedSideRightAirDistributionUpperAndMiddleAndLower"] = "rbxassetid://129371148484159",
		["figureSeatedSideRightAirDistributionUpperAngledAndDottedlineAndLowerAngled"] = "rbxassetid://71258161512054",
		["figureSeatedSideRightAirDistributionUpperAngledAndLowerAngled"] = "rbxassetid://135103013327810",
		["figureSeatedSideRightAirDistributionUpperAngledAndMiddle"] = "rbxassetid://103548517854131",
		["figureSeatedSideRightAirDistributionUpperAngledAndMiddleAndLowerAngled"] = "rbxassetid://134493708141205",
		["figureSeatedSideRightAirbagOff"] = "rbxassetid://94058410986970",
		["figureSeatedSideRightAirbagOff2"] = "rbxassetid://100168980896563",
		["figureSeatedSideRightAirbagOn"] = "rbxassetid://116869659816584",
		["figureSeatedSideRightAirbagOn2"] = "rbxassetid://132818635170679",
		["figureSeatedSideRightAutomatic"] = "rbxassetid://111548991851424",
		["figureSeatedSideRightChildLap"] = "rbxassetid://76765306258341",
		["figureSeatedSideRightFan"] = "rbxassetid://105598745260535",
		["figureSeatedSideRightSteeringwheel"] = "rbxassetid://90687210460576",
		["figureSeatedSideRightWindshieldFrontAndHeatWaves"] = "rbxassetid://86526553476751",
		["figureSeatedSideRightWindshieldFrontAndHeatWavesAirDistributionLower"] = "rbxassetid://81180167854979",
		["figureSeatedSideRightWindshieldFrontAndHeatWavesAirDistributionMiddle"] = "rbxassetid://73749499001488",
		["figureSeatedSideRightWindshieldFrontAndHeatWavesAirDistributionMiddleAndLower"] = "rbxassetid://97986729272402",
		["figureSeatedSideRightWindshieldFrontAndHeatWavesAirDistributionUpper"] = "rbxassetid://86983951557733",
		["figureSeatedSideRightWindshieldFrontAndHeatWavesAirDistributionUpperAndLower"] = "rbxassetid://83534989566232",
		["figureSeatedSideRightWindshieldFrontAndHeatWavesAirDistributionUpperAndMiddle"] = "rbxassetid://110050631545966",
		["figureSeatedSideRightWindshieldFrontAndHeatWavesAirDistributionUpperAndMiddleAndLower"] = "rbxassetid://121091370522998",
		["figureSeatedSideWindshieldFrontAndHeatWaves"] = "rbxassetid://87077410641628",
		["figureSeatedSideWindshieldFrontAndHeatWavesAirDistributionLower"] = "rbxassetid://95211211764474",
		["figureSeatedSideWindshieldFrontAndHeatWavesAirDistributionMiddle"] = "rbxassetid://79055808238898",
		["figureSeatedSideWindshieldFrontAndHeatWavesAirDistributionMiddleAndLower"] = "rbxassetid://95139994219690",
		["figureSeatedSideWindshieldFrontAndHeatWavesAirDistributionUpper"] = "rbxassetid://112780319350991",
		["figureSeatedSideWindshieldFrontAndHeatWavesAirDistributionUpperAndLower"] = "rbxassetid://118828536958349",
		["figureSeatedSideWindshieldFrontAndHeatWavesAirDistributionUpperAndMiddle"] = "rbxassetid://117604588619581",
		["figureSeatedSideWindshieldFrontAndHeatWavesAirDistributionUpperAndMiddleAndLower"] = "rbxassetid://133887310459410",
		["figureSkateboarding"] = "rbxassetid://120531764531561",
		["figureSkateboardingCircle"] = "rbxassetid://89075859489979",
		["figureSkateboardingCircleFill"] = "rbxassetid://107428167276894",
		["figureSkating"] = "rbxassetid://131519789461691",
		["figureSkiingCrosscountry"] = "rbxassetid://95376513080244",
		["figureSkiingCrosscountryCircle"] = "rbxassetid://91319383729536",
		["figureSkiingCrosscountryCircleFill"] = "rbxassetid://100781904758952",
		["figureSkiingDownhill"] = "rbxassetid://94948924926037",
		["figureSkiingDownhillCircle"] = "rbxassetid://124726796339746",
		["figureSkiingDownhillCircleFill"] = "rbxassetid://133873735630410",
		["figureSnowboarding"] = "rbxassetid://93552707410765",
		["figureSnowboardingCircle"] = "rbxassetid://91124188336468",
		["figureSnowboardingCircleFill"] = "rbxassetid://80006732027627",
		["figureSoccer"] = "rbxassetid://116190117656300",
		["figureSocialdance"] = "rbxassetid://98146311664249",
		["figureSocialdanceCircle"] = "rbxassetid://128341017230082",
		["figureSocialdanceCircleFill"] = "rbxassetid://90611956553302",
		["figureSoftball"] = "rbxassetid://121025439420310",
		["figureSoftballCircle"] = "rbxassetid://102433510764523",
		["figureSoftballCircleFill"] = "rbxassetid://72322590245571",
		["figureSquash"] = "rbxassetid://115910960216751",
		["figureSquashCircle"] = "rbxassetid://108255500001887",
		["figureSquashCircleFill"] = "rbxassetid://92599428723725",
		["figureStairStepper"] = "rbxassetid://97526748063558",
		["figureStairStepperCircle"] = "rbxassetid://93435159397362",
		["figureStairStepperCircleFill"] = "rbxassetid://86095743098312",
		["figureStairs"] = "rbxassetid://80928066724578",
		["figureStairsCircle"] = "rbxassetid://108007736984499",
		["figureStairsCircleFill"] = "rbxassetid://97282222240704",
		["figureStand"] = "rbxassetid://94523389012151",
		["figureStandDress"] = "rbxassetid://81879939422801",
		["figureStandDressLineVerticalFigure"] = "rbxassetid://75755749939997",
		["figureStandLineDottedFigureStand"] = "rbxassetid://74698954943767",
		["figureStepTraining"] = "rbxassetid://89082931649415",
		["figureStepTrainingCircle"] = "rbxassetid://83798887901170",
		["figureStepTrainingCircleFill"] = "rbxassetid://103288596282785",
		["figureStrengthtrainingFunctional"] = "rbxassetid://104636472308678",
		["figureStrengthtrainingFunctionalCircle"] = "rbxassetid://71887020003942",
		["figureStrengthtrainingFunctionalCircleFill"] = "rbxassetid://136782284825758",
		["figureStrengthtrainingTraditional"] = "rbxassetid://86384766229916",
		["figureStrengthtrainingTraditionalCircle"] = "rbxassetid://137707664026627",
		["figureStrengthtrainingTraditionalCircleFill"] = "rbxassetid://122169081610135",
		["figureSurfing"] = "rbxassetid://96005835479619",
		["figureSurfingCircle"] = "rbxassetid://97406987955422",
		["figureSurfingCircleFill"] = "rbxassetid://71245429084383",
		["figureTableTennis"] = "rbxassetid://84629739397090",
		["figureTableTennisCircle"] = "rbxassetid://75152334648876",
		["figureTableTennisCircleFill"] = "rbxassetid://103942005472858",
		["figureTaichi"] = "rbxassetid://110478807239910",
		["figureTaichiCircle"] = "rbxassetid://75278727258055",
		["figureTaichiCircleFill"] = "rbxassetid://71467374422500",
		["figureTennis"] = "rbxassetid://109986369675921",
		["figureTennisCircle"] = "rbxassetid://102155111733843",
		["figureTennisCircleFill"] = "rbxassetid://131743158972045",
		["figureTrackAndField"] = "rbxassetid://136538052321610",
		["figureTrackAndFieldCircle"] = "rbxassetid://103736888619277",
		["figureTrackAndFieldCircleFill"] = "rbxassetid://123902162029358",
		["figureVolleyball"] = "rbxassetid://94303634727000",
		["figureVolleyballCircle"] = "rbxassetid://136059877417611",
		["figureVolleyballCircleFill"] = "rbxassetid://79422865723683",
		["figureWalk"] = "rbxassetid://79511822122227",
		["figureWalkArrival"] = "rbxassetid://126341672233316",
		["figureWalkCircle"] = "rbxassetid://103084762751916",
		["figureWalkCircleFill"] = "rbxassetid://91923043437287",
		["figureWalkDeparture"] = "rbxassetid://102119906082019",
		["figureWalkDiamond"] = "rbxassetid://114194884373216",
		["figureWalkDiamondFill"] = "rbxassetid://126938906614617",
		["figureWalkMotion"] = "rbxassetid://112030395820861",
		["figureWalkMotionTrianglebadgeExclamationmark"] = "rbxassetid://106410785966772",
		["figureWalkSuitcaseRolling"] = "rbxassetid://139035074665377",
		["figureWalkSuitcaseRollingCircle"] = "rbxassetid://71150674505180",
		["figureWalkSuitcaseRollingCircleFill"] = "rbxassetid://113530785990351",
		["figureWalkTreadmill"] = "rbxassetid://73060375741248",
		["figureWalkTreadmillCircle"] = "rbxassetid://96470047881214",
		["figureWalkTreadmillCircleFill"] = "rbxassetid://98035075220974",
		["figureWalkTriangle"] = "rbxassetid://78276655377384",
		["figureWalkTriangleFill"] = "rbxassetid://98344113716078",
		["figureWaterFitness"] = "rbxassetid://91138168805690",
		["figureWaterFitnessCircle"] = "rbxassetid://104634803350077",
		["figureWaterFitnessCircleFill"] = "rbxassetid://76002732032150",
		["figureWaterpolo"] = "rbxassetid://139456823152794",
		["figureWaterpoloCircle"] = "rbxassetid://118729585287398",
		["figureWaterpoloCircleFill"] = "rbxassetid://83689434096148",
		["figureWave"] = "rbxassetid://126350733687264",
		["figureWaveCircle"] = "rbxassetid://103869802030971",
		["figureWaveCircleFill"] = "rbxassetid://82754948484397",
		["figureWrestling"] = "rbxassetid://81893433411503",
		["figureWrestlingCircle"] = "rbxassetid://134981808172623",
		["figureWrestlingCircleFill"] = "rbxassetid://94060023878868",
		["figureYoga"] = "rbxassetid://131429815541470",
		["figureYogaCircle"] = "rbxassetid://98261961081745",
		["figureYogaCircleFill"] = "rbxassetid://110744567898624",
		["filemenuAndCursorarrow"] = "rbxassetid://103877132330792",
		["filemenuAndPointerArrow"] = "rbxassetid://80797128300493",
		["filemenuAndSelection"] = "rbxassetid://133250059618545",
		["film"] = "rbxassetid://86941949111966",
		["filmCircle"] = "rbxassetid://124831403308365",
		["filmCircleFill"] = "rbxassetid://110423444595475",
		["filmFill"] = "rbxassetid://93532359201336",
		["filmStack"] = "rbxassetid://93437740666776",
		["filmStackFill"] = "rbxassetid://77875956814737",
		["finder"] = "rbxassetid://105028817444613",
		["fireExtinguisher"] = "rbxassetid://115098785397510",
		["fireExtinguisherFill"] = "rbxassetid://110280038568592",
		["fireplace"] = "rbxassetid://112954869899081",
		["fireplaceFill"] = "rbxassetid://75619406961928",
		["firewall"] = "rbxassetid://126760488734970",
		["firewallFill"] = "rbxassetid://84638883483155",
		["fireworks"] = "rbxassetid://99494540765134",
		["fish"] = "rbxassetid://125194628802668",
		["fishCircle"] = "rbxassetid://124319918102703",
		["fishCircleFill"] = "rbxassetid://77945311435195",
		["fishFill"] = "rbxassetid://106504216014923",
		["flag"] = "rbxassetid://122736846758534",
		["flag2Crossed"] = "rbxassetid://78844784013079",
		["flag2CrossedCircle"] = "rbxassetid://78584216590675",
		["flag2CrossedCircleFill"] = "rbxassetid://86134708117980",
		["flag2CrossedFill"] = "rbxassetid://84296510463315",
		["flagAndFlagFilledCrossed"] = "rbxassetid://100745243139308",
		["flagBadgeEllipsis"] = "rbxassetid://92803573179376",
		["flagBadgeEllipsisFill"] = "rbxassetid://91092814709500",
		["flagCheckered"] = "rbxassetid://78821229595515",
		["flagCheckered2Crossed"] = "rbxassetid://78412090520637",
		["flagCheckeredCircle"] = "rbxassetid://123648433572775",
		["flagCircle"] = "rbxassetid://77170785894950",
		["flagCircleFill"] = "rbxassetid://99647307774250",
		["flagFill"] = "rbxassetid://131669346188016",
		["flagFilledAndFlagCrossed"] = "rbxassetid://118037026885077",
		["flagPatternCheckered"] = "rbxassetid://125386743240339",
		["flagPatternCheckered2Crossed"] = "rbxassetid://115034252105148",
		["flagPatternCheckeredCircle"] = "rbxassetid://88125322330487",
		["flagPatternCheckeredCircleFill"] = "rbxassetid://80253578332366",
		["flagPatternCheckeredLc"] = "rbxassetid://79015272896327",
		["flagSlash"] = "rbxassetid://136165673088536",
		["flagSlashCircle"] = "rbxassetid://92686158250177",
		["flagSlashCircleFill"] = "rbxassetid://111660599139888",
		["flagSlashFill"] = "rbxassetid://71634940997338",
		["flagSquare"] = "rbxassetid://71479706467165",
		["flagSquareFill"] = "rbxassetid://100277208162099",
		["flame"] = "rbxassetid://108768547584054",
		["flameCircle"] = "rbxassetid://82747734852018",
		["flameCircleFill"] = "rbxassetid://86456375644145",
		["flameFill"] = "rbxassetid://119270312720784",
		["flameGaugeOpen"] = "rbxassetid://113126271179041",
		["flashlightOffCircle"] = "rbxassetid://117830570878966",
		["flashlightOffCircleFill"] = "rbxassetid://72961865361048",
		["flashlightOffFill"] = "rbxassetid://101207421230626",
		["flashlightOnCircle"] = "rbxassetid://79621682641826",
		["flashlightOnCircleFill"] = "rbxassetid://122824628666008",
		["flashlightOnFill"] = "rbxassetid://104818867409741",
		["flashlightSlash"] = "rbxassetid://124642568340306",
		["flashlightSlashCircle"] = "rbxassetid://106284752783985",
		["flashlightSlashCircleFill"] = "rbxassetid://131469491577650",
		["flask"] = "rbxassetid://71705325441366",
		["flaskFill"] = "rbxassetid://73156360900679",
		["fleuron"] = "rbxassetid://84029089647656",
		["fleuronFill"] = "rbxassetid://132784812676419",
		["flipphone"] = "rbxassetid://86153595900991",
		["florinsign"] = "rbxassetid://82815295829174",
		["florinsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://131747551393628",
		["florinsignBankBuilding"] = "rbxassetid://101348563612482",
		["florinsignBankBuildingFill"] = "rbxassetid://73257997241079",
		["florinsignCircle"] = "rbxassetid://102666413087615",
		["florinsignCircleFill"] = "rbxassetid://101645622228381",
		["florinsignGaugeChartLefthalfRighthalf"] = "rbxassetid://110044104730017",
		["florinsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://95345432829840",
		["florinsignRing"] = "rbxassetid://140452194895022",
		["florinsignRingDashed"] = "rbxassetid://96409551878599",
		["florinsignSquare"] = "rbxassetid://131511638483506",
		["florinsignSquareFill"] = "rbxassetid://99961037421189",
		["flowchart"] = "rbxassetid://112012575789082",
		["flowchartFill"] = "rbxassetid://85988923904543",
		["fluidBatteryblock"] = "rbxassetid://87171297845261",
		["fluidBrakesignal"] = "rbxassetid://85409681443732",
		["fluidCoolant"] = "rbxassetid://94305313777913",
		["fluidTransmission"] = "rbxassetid://81520433429253",
		["fn"] = "rbxassetid://136973223245238",
		["folder"] = "rbxassetid://125012160621787",
		["folderBadgeGearshape"] = "rbxassetid://110354717501799",
		["folderBadgeMinus"] = "rbxassetid://105424398626891",
		["folderBadgePersonCrop"] = "rbxassetid://118262710565929",
		["folderBadgePlus"] = "rbxassetid://86162465085192",
		["folderBadgeQuestionmark"] = "rbxassetid://96129876038348",
		["folderCircle"] = "rbxassetid://136623654746784",
		["folderCircleFill"] = "rbxassetid://71560799678637",
		["folderFill"] = "rbxassetid://139360049720186",
		["folderFillBadgeGearshape"] = "rbxassetid://86874469728544",
		["folderFillBadgeMinus"] = "rbxassetid://126706256406221",
		["folderFillBadgePersonCrop"] = "rbxassetid://116825460620355",
		["folderFillBadgePlus"] = "rbxassetid://117713198610469",
		["folderFillBadgeQuestionmark"] = "rbxassetid://101253803162337",
		["football"] = "rbxassetid://99824306110508",
		["footballCircle"] = "rbxassetid://82719329435185",
		["forkKnife"] = "rbxassetid://88625690387037",
		["forkKnifeCircle"] = "rbxassetid://114255039792324",
		["forkKnifeCircleFill"] = "rbxassetid://74351929405604",
		["formfittingGamecontroller"] = "rbxassetid://91206901253404",
		["formfittingGamecontrollerFill"] = "rbxassetid://88145883762633",
		["forward"] = "rbxassetid://113037057903118",
		["forwardCircle"] = "rbxassetid://115172960663901",
		["forwardCircleFill"] = "rbxassetid://77543137210165",
		["forwardEnd"] = "rbxassetid://130719114360778",
		["forwardEndAlt"] = "rbxassetid://119828878420743",
		["forwardEndAltFill"] = "rbxassetid://87004210011550",
		["forwardEndCircle"] = "rbxassetid://127570430828500",
		["forwardEndCircleFill"] = "rbxassetid://77630986993530",
		["forwardEndFill"] = "rbxassetid://135891363464093",
		["forwardFill"] = "rbxassetid://118726763278360",
		["forwardFrame"] = "rbxassetid://117425644293321",
		["forwardFrameFill"] = "rbxassetid://119062379885277",
		["fossilShell"] = "rbxassetid://108141425042235",
		["fossilShellFill"] = "rbxassetid://92090095699092",
		["francsign"] = "rbxassetid://104329955978670",
		["francsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://123734401541585",
		["francsignBankBuilding"] = "rbxassetid://140379990360270",
		["francsignBankBuildingFill"] = "rbxassetid://101202870300556",
		["francsignCircle"] = "rbxassetid://92045068970438",
		["francsignCircleFill"] = "rbxassetid://109010950306083",
		["francsignGaugeChartLefthalfRighthalf"] = "rbxassetid://111277658129239",
		["francsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://82217136095508",
		["francsignRing"] = "rbxassetid://124717081982767",
		["francsignRingDashed"] = "rbxassetid://111221536076635",
		["francsignSquare"] = "rbxassetid://117783360698586",
		["francsignSquareFill"] = "rbxassetid://139671995243527",
		["fryingPan"] = "rbxassetid://95665944113167",
		["fryingPanFill"] = "rbxassetid://131190456038889",
		["fuelFilterWater"] = "rbxassetid://114849224744442",
		["fuelpump"] = "rbxassetid://128432265591197",
		["fuelpumpAndFilter"] = "rbxassetid://132403377755564",
		["fuelpumpArrowtriangleLeft"] = "rbxassetid://77219675885475",
		["fuelpumpArrowtriangleLeftFill"] = "rbxassetid://105580200622844",
		["fuelpumpArrowtriangleRight"] = "rbxassetid://78806432937161",
		["fuelpumpArrowtriangleRightFill"] = "rbxassetid://116584326215382",
		["fuelpumpCircle"] = "rbxassetid://92321665086316",
		["fuelpumpCircleFill"] = "rbxassetid://109590002626519",
		["fuelpumpExclamationmark"] = "rbxassetid://124935631685999",
		["fuelpumpExclamationmarkFill"] = "rbxassetid://114211970014735",
		["fuelpumpFill"] = "rbxassetid://89804646715125",
		["fuelpumpSlash"] = "rbxassetid://112344106152981",
		["fuelpumpSlashFill"] = "rbxassetid://131380848022445",
		["fuelpumpThermometer"] = "rbxassetid://105776255539239",
		["fuelpumpThermometerFill"] = "rbxassetid://91014703108179",
		["function"] = "rbxassetid://105988244015471",
		["fx"] = "rbxassetid://133676038076601",
		["gCircle"] = "rbxassetid://92465681841123",
		["gCircleFill"] = "rbxassetid://117703861321064",
		["gSquare"] = "rbxassetid://98413842477799",
		["gSquareFill"] = "rbxassetid://121882609445976",
		["gamecontroller"] = "rbxassetid://136899701592916",
		["gamecontrollerCircle"] = "rbxassetid://115838851199918",
		["gamecontrollerCircleFill"] = "rbxassetid://100513486519514",
		["gamecontrollerFill"] = "rbxassetid://107710782304881",
		["gaugeChartLefthalfRighthalf"] = "rbxassetid://88317515489831",
		["gaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://117914290141041",
		["gaugeOpen"] = "rbxassetid://72661873101783",
		["gaugeOpenRighthalfDottedWithNeedleAndArrowTriangleheadBackward"] = "rbxassetid://106683214692474",
		["gaugeOpenWithLinesNeedle33percent"] = "rbxassetid://96930938614147",
		["gaugeOpenWithLinesNeedle33percentAndArrowTriangleheadFrom0percentTo50percent"] = "rbxassetid://72455258039917",
		["gaugeOpenWithLinesNeedle33percentAndArrowtriangle"] = "rbxassetid://129905955726763",
		["gaugeOpenWithLinesNeedle33percentAndArrowtriangleFrom0percentTo50percent"] = "rbxassetid://81580637007677",
		["gaugeOpenWithLinesNeedle67percentAndArrowtriangle"] = "rbxassetid://104277227320240",
		["gaugeOpenWithLinesNeedle67percentAndArrowtriangleAndCar"] = "rbxassetid://74920052592412",
		["gaugeOpenWithLinesNeedle84percentExclamation"] = "rbxassetid://131118944109256",
		["gaugeWithDotsNeedle0percent"] = "rbxassetid://71374226674159",
		["gaugeWithDotsNeedle100percent"] = "rbxassetid://82175977935882",
		["gaugeWithDotsNeedle33percent"] = "rbxassetid://92757773478553",
		["gaugeWithDotsNeedle50percent"] = "rbxassetid://115384416941293",
		["gaugeWithDotsNeedle67percent"] = "rbxassetid://109864469246268",
		["gaugeWithDotsNeedleBottom0percent"] = "rbxassetid://74885486474683",
		["gaugeWithDotsNeedleBottom100percent"] = "rbxassetid://72579321556049",
		["gaugeWithDotsNeedleBottom50percent"] = "rbxassetid://120735235060336",
		["gaugeWithDotsNeedleBottom50percentBadgeMinus"] = "rbxassetid://140660728462393",
		["gaugeWithDotsNeedleBottom50percentBadgePlus"] = "rbxassetid://104491325572328",
		["gaugeWithNeedle"] = "rbxassetid://77994983474118",
		["gaugeWithNeedleFill"] = "rbxassetid://72397110171923",
		["gear"] = "rbxassetid://133102912527371",
		["gearBadge"] = "rbxassetid://114821006676114",
		["gearBadgeCheckmark"] = "rbxassetid://116948953549356",
		["gearBadgeQuestionmark"] = "rbxassetid://94190722082023",
		["gearBadgeXmark"] = "rbxassetid://102962629872900",
		["gearCircle"] = "rbxassetid://80927635234925",
		["gearCircleFill"] = "rbxassetid://78683348854232",
		["gearshape"] = "rbxassetid://127735318557062",
		["gearshape2"] = "rbxassetid://95807134365871",
		["gearshape2Fill"] = "rbxassetid://132207224797441",
		["gearshapeArrowTriangle2Circlepath"] = "rbxassetid://84641602565527",
		["gearshapeArrowTrianglehead2ClockwiseRotate90"] = "rbxassetid://130625453122583",
		["gearshapeCircle"] = "rbxassetid://70545341819845",
		["gearshapeCircleFill"] = "rbxassetid://105088281654478",
		["gearshapeFill"] = "rbxassetid://98061574923339",
		["gearshiftLayoutSixspeed"] = "rbxassetid://83954102394855",
		["gift"] = "rbxassetid://130378804447034",
		["giftCircle"] = "rbxassetid://105693012395359",
		["giftCircleFill"] = "rbxassetid://75831198909976",
		["giftFill"] = "rbxassetid://122811099954906",
		["giftcard"] = "rbxassetid://74001358275222",
		["giftcardFill"] = "rbxassetid://80648895512474",
		["globe"] = "rbxassetid://75166161739358",
		["globeAmericas"] = "rbxassetid://82208390184303",
		["globeAmericasFill"] = "rbxassetid://117216039216006",
		["globeAsiaAustralia"] = "rbxassetid://101174379892302",
		["globeAsiaAustraliaFill"] = "rbxassetid://125274596435685",
		["globeBadgeChevronBackward"] = "rbxassetid://118399161412796",
		["globeBadgeClock"] = "rbxassetid://81246082209280",
		["globeBadgeClockFill"] = "rbxassetid://133084199012794",
		["globeCentralSouthAsia"] = "rbxassetid://122671652893265",
		["globeCentralSouthAsiaFill"] = "rbxassetid://120361963069758",
		["globeDesk"] = "rbxassetid://74995477837587",
		["globeDeskFill"] = "rbxassetid://98081463950992",
		["globeEuropeAfrica"] = "rbxassetid://136835539161615",
		["globeEuropeAfricaFill"] = "rbxassetid://130908776432341",
		["globeFill"] = "rbxassetid://108905553032102",
		["glowplug"] = "rbxassetid://81022835723835",
		["gobackward"] = "rbxassetid://91320889824011",
		["gobackward10"] = "rbxassetid://90559603880621",
		["gobackward15"] = "rbxassetid://120316938540272",
		["gobackward30"] = "rbxassetid://140354039230051",
		["gobackward45"] = "rbxassetid://93434813605748",
		["gobackward5"] = "rbxassetid://97130008586442",
		["gobackward60"] = "rbxassetid://91215922364999",
		["gobackward75"] = "rbxassetid://140735752535943",
		["gobackward90"] = "rbxassetid://108207845332277",
		["gobackwardMinus"] = "rbxassetid://92431716781150",
		["goforward"] = "rbxassetid://131297950123949",
		["goforward10"] = "rbxassetid://136515914036455",
		["goforward15"] = "rbxassetid://91999877907911",
		["goforward30"] = "rbxassetid://77322694446691",
		["goforward45"] = "rbxassetid://90174945269280",
		["goforward5"] = "rbxassetid://92986838147448",
		["goforward60"] = "rbxassetid://116153177521739",
		["goforward75"] = "rbxassetid://71594405050565",
		["goforward90"] = "rbxassetid://81147746129102",
		["goforwardPlus"] = "rbxassetid://130621369072851",
		["graduationcap"] = "rbxassetid://125671553630065",
		["graduationcapCircle"] = "rbxassetid://113915747930128",
		["graduationcapCircleFill"] = "rbxassetid://105306913757085",
		["graduationcapFill"] = "rbxassetid://133021220811177",
		["graph2d"] = "rbxassetid://115562943064650",
		["graph3d"] = "rbxassetid://78081408845927",
		["greaterthan"] = "rbxassetid://72942886858684",
		["greaterthanCircle"] = "rbxassetid://86205987134419",
		["greaterthanCircleFill"] = "rbxassetid://86221088035316",
		["greaterthanSquare"] = "rbxassetid://138820278327055",
		["greaterthanSquareFill"] = "rbxassetid://82992552700740",
		["greaterthanorequalto"] = "rbxassetid://84817672830093",
		["greaterthanorequaltoCircle"] = "rbxassetid://129245462379395",
		["greaterthanorequaltoCircleFill"] = "rbxassetid://71490024938088",
		["greaterthanorequaltoSquare"] = "rbxassetid://74647437313735",
		["greaterthanorequaltoSquareFill"] = "rbxassetid://116032105238422",
		["greetingcard"] = "rbxassetid://71909891559012",
		["greetingcardFill"] = "rbxassetid://129481097749734",
		["grid"] = "rbxassetid://137977554732401",
		["gridCircle"] = "rbxassetid://110916645524765",
		["gridCircleFill"] = "rbxassetid://128975539852133",
		["guaranisign"] = "rbxassetid://112075506061752",
		["guaranisignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://126343329265137",
		["guaranisignBankBuilding"] = "rbxassetid://83180391553596",
		["guaranisignBankBuildingFill"] = "rbxassetid://75636756682974",
		["guaranisignCircle"] = "rbxassetid://85150493060456",
		["guaranisignCircleFill"] = "rbxassetid://133828485193738",
		["guaranisignGaugeChartLefthalfRighthalf"] = "rbxassetid://96206193501856",
		["guaranisignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://94122115224811",
		["guaranisignRing"] = "rbxassetid://81261354529999",
		["guaranisignRingDashed"] = "rbxassetid://134424671572303",
		["guaranisignSquare"] = "rbxassetid://86259179384477",
		["guaranisignSquareFill"] = "rbxassetid://110801531280759",
		["guidepointHorizontal"] = "rbxassetid://84781782029904",
		["guidepointVertical"] = "rbxassetid://75299633437864",
		["guidepointVerticalArrowtriangleForward"] = "rbxassetid://136880401311404",
		["guidepointVerticalNumbers"] = "rbxassetid://90754353774856",
		["guitars"] = "rbxassetid://89759348254657",
		["guitarsFill"] = "rbxassetid://118628784478150",
		["gymBag"] = "rbxassetid://91936141424860",
		["gyroscope"] = "rbxassetid://87245230868142",
		["hCircle"] = "rbxassetid://79276843950798",
		["hCircleFill"] = "rbxassetid://88400318014142",
		["hSquare"] = "rbxassetid://78518090497793",
		["hSquareFill"] = "rbxassetid://119310296219192",
		["hSquareOnSquare"] = "rbxassetid://73872611085563",
		["hSquareOnSquareFill"] = "rbxassetid://87667186323197",
		["hammer"] = "rbxassetid://112993982210428",
		["hammerCircle"] = "rbxassetid://112608453897290",
		["hammerCircleFill"] = "rbxassetid://115343834000229",
		["hammerFill"] = "rbxassetid://102181818130125",
		["handDraw"] = "rbxassetid://117279982831998",
		["handDrawBadgeEllipsis"] = "rbxassetid://97969102000092",
		["handDrawBadgeEllipsisFill"] = "rbxassetid://139146605060373",
		["handDrawFill"] = "rbxassetid://138962845497785",
		["handPalmFacing"] = "rbxassetid://78824669302390",
		["handPalmFacingFill"] = "rbxassetid://128639333246378",
		["handPinch"] = "rbxassetid://117668308815958",
		["handPinchFill"] = "rbxassetid://133801146028572",
		["handPointDown"] = "rbxassetid://112615598975626",
		["handPointDownFill"] = "rbxassetid://105179986613891",
		["handPointLeft"] = "rbxassetid://77661745009660",
		["handPointLeftFill"] = "rbxassetid://70525211956387",
		["handPointRight"] = "rbxassetid://97538565682591",
		["handPointRightFill"] = "rbxassetid://121327486358231",
		["handPointUp"] = "rbxassetid://117889120409602",
		["handPointUpBraille"] = "rbxassetid://132543668022892",
		["handPointUpBrailleBadgeEllipsis"] = "rbxassetid://70655290798237",
		["handPointUpBrailleBadgeEllipsisFill"] = "rbxassetid://88987354661672",
		["handPointUpBrailleFill"] = "rbxassetid://138549174364488",
		["handPointUpFill"] = "rbxassetid://128174530086050",
		["handPointUpLeft"] = "rbxassetid://75447182366329",
		["handPointUpLeftAndText"] = "rbxassetid://138503170903583",
		["handPointUpLeftAndTextFill"] = "rbxassetid://97238879602996",
		["handPointUpLeftFill"] = "rbxassetid://89676540164824",
		["handRaised"] = "rbxassetid://84405411427687",
		["handRaisedApp"] = "rbxassetid://114135263702771",
		["handRaisedAppFill"] = "rbxassetid://90067463663710",
		["handRaisedBrakesignal"] = "rbxassetid://137730513400429",
		["handRaisedBrakesignalSlash"] = "rbxassetid://100352691199559",
		["handRaisedCircle"] = "rbxassetid://116446437426242",
		["handRaisedCircleFill"] = "rbxassetid://128584434185523",
		["handRaisedFill"] = "rbxassetid://78380006817166",
		["handRaisedFingersSpread"] = "rbxassetid://109788802602461",
		["handRaisedFingersSpreadFill"] = "rbxassetid://100765574389067",
		["handRaisedPalmFacing"] = "rbxassetid://97733489796350",
		["handRaisedPalmFacingFill"] = "rbxassetid://135020525701876",
		["handRaisedSlash"] = "rbxassetid://102308446798846",
		["handRaisedSlashFill"] = "rbxassetid://103883906624498",
		["handRaisedSquare"] = "rbxassetid://139713537529028",
		["handRaisedSquareFill"] = "rbxassetid://132631307297758",
		["handRaisedSquareOnSquare"] = "rbxassetid://92160946199919",
		["handRaisedSquareOnSquareFill"] = "rbxassetid://107064045091001",
		["handRays"] = "rbxassetid://113827578510200",
		["handRaysFill"] = "rbxassetid://81107317241495",
		["handTap"] = "rbxassetid://121078591974451",
		["handTapFill"] = "rbxassetid://107040362271120",
		["handThumbsdown"] = "rbxassetid://86244158573902",
		["handThumbsdownCircle"] = "rbxassetid://131507665718313",
		["handThumbsdownCircleFill"] = "rbxassetid://72570466776202",
		["handThumbsdownFill"] = "rbxassetid://119254958080448",
		["handThumbsdownFilledHandThumbsup"] = "rbxassetid://129312899514257",
		["handThumbsdownHandThumbsup"] = "rbxassetid://137009505636508",
		["handThumbsdownHandThumbsupFill"] = "rbxassetid://105367500517028",
		["handThumbsdownHandThumbsupFilled"] = "rbxassetid://107178383384090",
		["handThumbsdownSlash"] = "rbxassetid://79807256603775",
		["handThumbsdownSlashFill"] = "rbxassetid://74459649358982",
		["handThumbsup"] = "rbxassetid://128825696312922",
		["handThumbsupCircle"] = "rbxassetid://103851740662333",
		["handThumbsupCircleFill"] = "rbxassetid://76110205867291",
		["handThumbsupFill"] = "rbxassetid://99068764072945",
		["handThumbsupSlash"] = "rbxassetid://127685946159633",
		["handThumbsupSlashFill"] = "rbxassetid://125613315163126",
		["handWave"] = "rbxassetid://99003092549916",
		["handWaveFill"] = "rbxassetid://121274581284216",
		["handbag"] = "rbxassetid://119008806614003",
		["handbagCircle"] = "rbxassetid://121699579950837",
		["handbagCircleFill"] = "rbxassetid://119779307441201",
		["handbagFill"] = "rbxassetid://132621634669616",
		["handbagSensorTagRadiowavesLeftAndRight"] = "rbxassetid://120465117885302",
		["handbagSensorTagRadiowavesLeftAndRightFill"] = "rbxassetid://137202755346414",
		["handsAndSparkles"] = "rbxassetid://117743916588668",
		["handsAndSparklesFill"] = "rbxassetid://79507225656287",
		["handsClap"] = "rbxassetid://132285028680230",
		["handsClapFill"] = "rbxassetid://109479694040359",
		["hanger"] = "rbxassetid://110883707987214",
		["hare"] = "rbxassetid://117125651358452",
		["hareCircle"] = "rbxassetid://81410012263740",
		["hareCircleFill"] = "rbxassetid://125075745793371",
		["hareFill"] = "rbxassetid://98813388968086",
		["hatCap"] = "rbxassetid://128042779395199",
		["hatCapFill"] = "rbxassetid://102509811181096",
		["hatWidebrim"] = "rbxassetid://124186898685706",
		["hatWidebrimFill"] = "rbxassetid://86146755083367",
		["hazardsign"] = "rbxassetid://77958913474310",
		["hazardsignFill"] = "rbxassetid://76749713980748",
		["headProfileArrowForwardAndVisionPro"] = "rbxassetid://70678052534847",
		["headProfileArrowForwardAndVisionpro"] = "rbxassetid://121693109509839",
		["headlightDaytime"] = "rbxassetid://84175387087613",
		["headlightDaytimeFill"] = "rbxassetid://111429276707908",
		["headlightFog"] = "rbxassetid://109963635819226",
		["headlightFogFill"] = "rbxassetid://112552940723745",
		["headlightHighBeam"] = "rbxassetid://74121554429267",
		["headlightHighBeamFill"] = "rbxassetid://137245916188907",
		["headlightLowBeam"] = "rbxassetid://125392142355830",
		["headlightLowBeamFill"] = "rbxassetid://81479147676998",
		["headphones"] = "rbxassetid://132794493030809",
		["headphonesCircle"] = "rbxassetid://72972156489516",
		["headphonesCircleFill"] = "rbxassetid://105101131622323",
		["headphonesDots"] = "rbxassetid://99563475077840",
		["headphonesOverEar"] = "rbxassetid://94686833776442",
		["headphonesSensorTagRadiowavesLeftAndRight"] = "rbxassetid://90239603333031",
		["headphonesSensorTagRadiowavesLeftAndRightFill"] = "rbxassetid://127570957315647",
		["headphonesSlash"] = "rbxassetid://111042856026852",
		["headset"] = "rbxassetid://130413167339658",
		["headsetCircle"] = "rbxassetid://102874182756345",
		["headsetCircleFill"] = "rbxassetid://99680766544161",
		["hearingdeviceAndSignalMeter"] = "rbxassetid://122423830802161",
		["hearingdeviceAndSignalMeterFill"] = "rbxassetid://101534259662449",
		["hearingdeviceEar"] = "rbxassetid://116592072523482",
		["hearingdeviceEarFill"] = "rbxassetid://79485233563481",
		["heart"] = "rbxassetid://107768052948480",
		["heartBadgeBolt"] = "rbxassetid://108146593346669",
		["heartBadgeBoltFill"] = "rbxassetid://89201775898085",
		["heartBadgeBoltSlash"] = "rbxassetid://101803582419656",
		["heartBadgeBoltSlashFill"] = "rbxassetid://115081294249357",
		["heartCircle"] = "rbxassetid://74612932649320",
		["heartCircleFill"] = "rbxassetid://112366120879148",
		["heartFill"] = "rbxassetid://133334197582974",
		["heartGaugeOpen"] = "rbxassetid://83392107700158",
		["heartRectangle"] = "rbxassetid://97775143423887",
		["heartRectangleFill"] = "rbxassetid://81040147605111",
		["heartSlash"] = "rbxassetid://102340079577590",
		["heartSlashCircle"] = "rbxassetid://105081950550053",
		["heartSlashCircleFill"] = "rbxassetid://117503908060806",
		["heartSlashFill"] = "rbxassetid://98288490017510",
		["heartSquare"] = "rbxassetid://112292843005652",
		["heartSquareFill"] = "rbxassetid://113665033930324",
		["heartTextClipboard"] = "rbxassetid://135119715100910",
		["heartTextClipboardFill"] = "rbxassetid://97188049534337",
		["heartTextSquare"] = "rbxassetid://74020211110629",
		["heartTextSquareFill"] = "rbxassetid://96589545065469",
		["heatElementWindshield"] = "rbxassetid://85064985076162",
		["heatWaves"] = "rbxassetid://117183214242618",
		["heatWavesAndFan"] = "rbxassetid://131275641266480",
		["heatWavesCircle"] = "rbxassetid://107780936807304",
		["heatWavesCircleFill"] = "rbxassetid://124151920948426",
		["heatWavesGaugeOpen"] = "rbxassetid://109476160740075",
		["heaterVertical"] = "rbxassetid://72918931799735",
		["heaterVerticalFill"] = "rbxassetid://92635624311644",
		["helm"] = "rbxassetid://128890437419395",
		["helmet"] = "rbxassetid://114891866790157",
		["helmetFill"] = "rbxassetid://119174880478810",
		["hexagon"] = "rbxassetid://121821922240266",
		["hexagonBottomhalfFilled"] = "rbxassetid://111107059226028",
		["hexagonFill"] = "rbxassetid://82240827497051",
		["hexagonLefthalfFilled"] = "rbxassetid://101561513084357",
		["hexagonRighthalfFilled"] = "rbxassetid://107562615063917",
		["hexagonTophalfFilled"] = "rbxassetid://132335379358202",
		["hifireceiver"] = "rbxassetid://135361029083378",
		["hifireceiverFill"] = "rbxassetid://99759386860407",
		["hifispeaker"] = "rbxassetid://99164524327344",
		["hifispeaker2"] = "rbxassetid://86111767037300",
		["hifispeaker2BadgeMinus"] = "rbxassetid://118971920951758",
		["hifispeaker2BadgeMinusFill"] = "rbxassetid://101665851094245",
		["hifispeaker2BadgePlus"] = "rbxassetid://115961834970221",
		["hifispeaker2BadgePlusFill"] = "rbxassetid://72006888131536",
		["hifispeaker2Fill"] = "rbxassetid://88815689838039",
		["hifispeakerAndAppletv"] = "rbxassetid://127147046090615",
		["hifispeakerAndAppletvFill"] = "rbxassetid://83573337866673",
		["hifispeakerAndHomepod"] = "rbxassetid://82595174597082",
		["hifispeakerAndHomepodBadgeMinus"] = "rbxassetid://112609157830200",
		["hifispeakerAndHomepodBadgeMinusFill"] = "rbxassetid://74023887981775",
		["hifispeakerAndHomepodBadgePlus"] = "rbxassetid://85291697963379",
		["hifispeakerAndHomepodBadgePlusFill"] = "rbxassetid://123316634293817",
		["hifispeakerAndHomepodFill"] = "rbxassetid://73377066571876",
		["hifispeakerAndHomepodMini"] = "rbxassetid://70934710071244",
		["hifispeakerAndHomepodMiniBadgeMinus"] = "rbxassetid://78650669958266",
		["hifispeakerAndHomepodMiniBadgeMinusFill"] = "rbxassetid://130888989200488",
		["hifispeakerAndHomepodMiniBadgePlus"] = "rbxassetid://101156627050743",
		["hifispeakerAndHomepodMiniBadgePlusFill"] = "rbxassetid://72856342595422",
		["hifispeakerAndHomepodMiniFill"] = "rbxassetid://124757037235263",
		["hifispeakerAndHomepodmini"] = "rbxassetid://104285147267424",
		["hifispeakerArrowForward"] = "rbxassetid://106004965331315",
		["hifispeakerArrowForwardFill"] = "rbxassetid://109292392722010",
		["hifispeakerBadgeMinus"] = "rbxassetid://113543299876891",
		["hifispeakerBadgeMinusFill"] = "rbxassetid://106840703331361",
		["hifispeakerBadgePlus"] = "rbxassetid://86077612672916",
		["hifispeakerBadgePlusFill"] = "rbxassetid://79039318209871",
		["hifispeakerFill"] = "rbxassetid://77801175030655",
		["highlighter"] = "rbxassetid://77046693747579",
		["highlighterBadgeEllipsis"] = "rbxassetid://90559499376399",
		["hockeyPuck"] = "rbxassetid://82861679405783",
		["hockeyPuckCircle"] = "rbxassetid://74508151585209",
		["hockeyPuckCircleFill"] = "rbxassetid://83552419639351",
		["hockeyPuckFill"] = "rbxassetid://112221361054966",
		["holdBrakesignal"] = "rbxassetid://93719484889123",
		["homekit"] = "rbxassetid://129816863247706",
		["homepod"] = "rbxassetid://138665920971606",
		["homepod2"] = "rbxassetid://124703967838105",
		["homepod2BadgeMinus"] = "rbxassetid://72010862188560",
		["homepod2BadgeMinusFill"] = "rbxassetid://122422111268643",
		["homepod2BadgePlus"] = "rbxassetid://95527221485415",
		["homepod2BadgePlusFill"] = "rbxassetid://124657181184492",
		["homepod2Fill"] = "rbxassetid://71022507008871",
		["homepodAndAppletv"] = "rbxassetid://137717079586958",
		["homepodAndAppletvFill"] = "rbxassetid://109445378694806",
		["homepodAndHomepodMini"] = "rbxassetid://121344187904185",
		["homepodAndHomepodMiniBadgeMinus"] = "rbxassetid://111143025398497",
		["homepodAndHomepodMiniBadgeMinusFill"] = "rbxassetid://136855742899911",
		["homepodAndHomepodMiniBadgePlus"] = "rbxassetid://129503453741868",
		["homepodAndHomepodMiniBadgePlusFill"] = "rbxassetid://73815090550857",
		["homepodAndHomepodMiniFill"] = "rbxassetid://82957016359447",
		["homepodAndHomepodmini"] = "rbxassetid://128138460912737",
		["homepodArrowForward"] = "rbxassetid://112827593003603",
		["homepodArrowForwardFill"] = "rbxassetid://111457680101526",
		["homepodBadgeCheckmark"] = "rbxassetid://82279608071963",
		["homepodBadgeCheckmarkFill"] = "rbxassetid://119126537015840",
		["homepodBadgeMinus"] = "rbxassetid://111844922298587",
		["homepodBadgeMinusFill"] = "rbxassetid://114830828502660",
		["homepodBadgePlus"] = "rbxassetid://106645926660190",
		["homepodBadgePlusFill"] = "rbxassetid://89951217734368",
		["homepodFill"] = "rbxassetid://126573700088988",
		["homepodMini"] = "rbxassetid://119380942973091",
		["homepodMini2"] = "rbxassetid://119573077798052",
		["homepodMini2BadgeMinus"] = "rbxassetid://75537675870052",
		["homepodMini2BadgeMinusFill"] = "rbxassetid://89666757230874",
		["homepodMini2BadgePlus"] = "rbxassetid://131253222073711",
		["homepodMini2BadgePlusFill"] = "rbxassetid://122139521655674",
		["homepodMini2Fill"] = "rbxassetid://129534319223398",
		["homepodMiniAndAppletv"] = "rbxassetid://126403464830823",
		["homepodMiniAndAppletvFill"] = "rbxassetid://102930412180504",
		["homepodMiniArrowForward"] = "rbxassetid://103858774531499",
		["homepodMiniArrowForwardFill"] = "rbxassetid://88548291845376",
		["homepodMiniBadgeCheckmark"] = "rbxassetid://95602217269613",
		["homepodMiniBadgeCheckmarkFill"] = "rbxassetid://138452597685198",
		["homepodMiniBadgeMinus"] = "rbxassetid://119379139369139",
		["homepodMiniBadgeMinusFill"] = "rbxassetid://126293519479293",
		["homepodMiniBadgePlus"] = "rbxassetid://118379467986303",
		["homepodMiniBadgePlusFill"] = "rbxassetid://111517543574290",
		["homepodMiniFill"] = "rbxassetid://115748763010662",
		["homepodmini"] = "rbxassetid://93368409427047",
		["homepodmini2"] = "rbxassetid://138072319954848",
		["homepodminiAndAppletv"] = "rbxassetid://96899217298462",
		["horn"] = "rbxassetid://133092229616767",
		["hornBlast"] = "rbxassetid://114595846337741",
		["hornBlastFill"] = "rbxassetid://101724439604991",
		["hornFill"] = "rbxassetid://135647807274226",
		["hourglass"] = "rbxassetid://85321944407184",
		["hourglassBadgeEye"] = "rbxassetid://135319595841957",
		["hourglassBadgeLock"] = "rbxassetid://76338330289232",
		["hourglassBadgePlus"] = "rbxassetid://114268852033821",
		["hourglassBottomhalfFilled"] = "rbxassetid://113354322030926",
		["hourglassCircle"] = "rbxassetid://110733468934387",
		["hourglassCircleFill"] = "rbxassetid://125048992318731",
		["hourglassTophalfFilled"] = "rbxassetid://84671059736173",
		["house"] = "rbxassetid://137977066267668",
		["houseAndFlag"] = "rbxassetid://86134823093935",
		["houseAndFlagCircle"] = "rbxassetid://127330265020154",
		["houseAndFlagCircleFill"] = "rbxassetid://70711300093336",
		["houseAndFlagFill"] = "rbxassetid://109752212574467",
		["houseBadgeExclamationmark"] = "rbxassetid://76429262032538",
		["houseBadgeExclamationmarkFill"] = "rbxassetid://87392853954669",
		["houseBadgeWifi"] = "rbxassetid://135608851537692",
		["houseBadgeWifiFill"] = "rbxassetid://103445459783943",
		["houseCircle"] = "rbxassetid://138648903313463",
		["houseCircleFill"] = "rbxassetid://108559873908847",
		["houseFill"] = "rbxassetid://139946019827392",
		["houseLodge"] = "rbxassetid://85704833980676",
		["houseLodgeCircle"] = "rbxassetid://127650865114252",
		["houseLodgeCircleFill"] = "rbxassetid://71323700043692",
		["houseLodgeFill"] = "rbxassetid://127089968967039",
		["houseSlash"] = "rbxassetid://81400788586332",
		["houseSlashFill"] = "rbxassetid://137443750353131",
		["hryvniasign"] = "rbxassetid://103668150355749",
		["hryvniasignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://91688749623067",
		["hryvniasignBankBuilding"] = "rbxassetid://129621086591675",
		["hryvniasignBankBuildingFill"] = "rbxassetid://104628622071039",
		["hryvniasignCircle"] = "rbxassetid://94474243422007",
		["hryvniasignCircleFill"] = "rbxassetid://101794866939417",
		["hryvniasignGaugeChartLefthalfRighthalf"] = "rbxassetid://106063402550840",
		["hryvniasignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://128998826362994",
		["hryvniasignRing"] = "rbxassetid://118368396656485",
		["hryvniasignRingDashed"] = "rbxassetid://88816425414859",
		["hryvniasignSquare"] = "rbxassetid://75385636486518",
		["hryvniasignSquareFill"] = "rbxassetid://89586571568331",
		["humidifier"] = "rbxassetid://77734577476092",
		["humidifierAndDroplets"] = "rbxassetid://109490683520378",
		["humidifierAndDropletsFill"] = "rbxassetid://81835383574136",
		["humidifierAndEllipsis"] = "rbxassetid://119958476085943",
		["humidifierAndEllipsisFill"] = "rbxassetid://107200405950324",
		["humidifierFill"] = "rbxassetid://127532491737560",
		["humidity"] = "rbxassetid://94944682462623",
		["humidityFill"] = "rbxassetid://116083322385268",
		["hurricane"] = "rbxassetid://95533741958668",
		["hurricaneCircle"] = "rbxassetid://90440100760735",
		["hurricaneCircleFill"] = "rbxassetid://130652138255798",
		["hydrogen"] = "rbxassetid://92886127488787",
		["hydrogenCircle"] = "rbxassetid://86547013940983",
		["hydrogenCircleFill"] = "rbxassetid://89516381077394",
		["hydrogenSquare"] = "rbxassetid://139351374466565",
		["hydrogenSquareFill"] = "rbxassetid://137173913274988",
		["iCircle"] = "rbxassetid://89113344291580",
		["iCircleFill"] = "rbxassetid://104332397605196",
		["iSquare"] = "rbxassetid://96564441985200",
		["iSquareFill"] = "rbxassetid://113037407421563",
		["icloud"] = "rbxassetid://110727461515621",
		["icloudAndArrowDown"] = "rbxassetid://133728071871190",
		["icloudAndArrowDownFill"] = "rbxassetid://91580842064758",
		["icloudAndArrowUp"] = "rbxassetid://82876886918286",
		["icloudAndArrowUpFill"] = "rbxassetid://80667605488140",
		["icloudCircle"] = "rbxassetid://130045045841352",
		["icloudCircleFill"] = "rbxassetid://139289409047379",
		["icloudDashed"] = "rbxassetid://111793754917716",
		["icloudFill"] = "rbxassetid://140102319448039",
		["icloudSlash"] = "rbxassetid://77090637996631",
		["icloudSlashFill"] = "rbxassetid://117065145373314",
		["icloudSquare"] = "rbxassetid://102626362675694",
		["icloudSquareFill"] = "rbxassetid://97104665653244",
		["increaseIndent"] = "rbxassetid://88800434030947",
		["increaseQuotelevel"] = "rbxassetid://104026428447630",
		["indianrupeesign"] = "rbxassetid://111754186050334",
		["indianrupeesignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://112994062871958",
		["indianrupeesignBankBuilding"] = "rbxassetid://119082346279444",
		["indianrupeesignBankBuildingFill"] = "rbxassetid://92479240380407",
		["indianrupeesignCircle"] = "rbxassetid://123695503681843",
		["indianrupeesignCircleFill"] = "rbxassetid://129318061897341",
		["indianrupeesignGaugeChartLefthalfRighthalf"] = "rbxassetid://78225158661344",
		["indianrupeesignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://82863857678210",
		["indianrupeesignRing"] = "rbxassetid://75461897769861",
		["indianrupeesignRingDashed"] = "rbxassetid://84664976795938",
		["indianrupeesignSquare"] = "rbxassetid://122397780894486",
		["indianrupeesignSquareFill"] = "rbxassetid://105131855370809",
		["infinity"] = "rbxassetid://71263460362433",
		["infinityCircle"] = "rbxassetid://71003157985047",
		["infinityCircleFill"] = "rbxassetid://86156332621236",
		["info"] = "rbxassetid://119116685807529",
		["infoBubble"] = "rbxassetid://137273126608579",
		["infoBubbleFill"] = "rbxassetid://124693206931792",
		["infoCircle"] = "rbxassetid://140318155547831",
		["infoCircleFill"] = "rbxassetid://120424810493200",
		["infoCircleTextPage"] = "rbxassetid://125356901438011",
		["infoCircleTextPageFill"] = "rbxassetid://80370826247197",
		["infoSquare"] = "rbxassetid://110012911332380",
		["infoSquareFill"] = "rbxassetid://95776862176830",
		["infoTriangle"] = "rbxassetid://94781493039380",
		["infoTriangleFill"] = "rbxassetid://95650689777625",
		["infoWindshield"] = "rbxassetid://128644339648564",
		["inhaler"] = "rbxassetid://121743497043663",
		["inhalerFill"] = "rbxassetid://71451949590628",
		["insetFilledApplewatchCase"] = "rbxassetid://120279724059828",
		["insetFilledBottomhalfRectangle"] = "rbxassetid://136597041452039",
		["insetFilledBottomhalfRectanglePortrait"] = "rbxassetid://100868664232614",
		["insetFilledBottomhalfTophalfRectangle"] = "rbxassetid://127692599846777",
		["insetFilledBottomleadingBottomtrailingRectangle"] = "rbxassetid://84327980842976",
		["insetFilledBottomleadingRectangle"] = "rbxassetid://101305622798572",
		["insetFilledBottomleadingRectanglePortrait"] = "rbxassetid://139106808860498",
		["insetFilledBottomleftBottomrightRectangle"] = "rbxassetid://135473749561029",
		["insetFilledBottomleftRectangle"] = "rbxassetid://96902285478363",
		["insetFilledBottomleftRectanglePortrait"] = "rbxassetid://128299495559712",
		["insetFilledBottomrightRectangle"] = "rbxassetid://120529833708590",
		["insetFilledBottomrightRectanglePortrait"] = "rbxassetid://126122940689687",
		["insetFilledBottomthirdRectangle"] = "rbxassetid://92508256484902",
		["insetFilledBottomthirdRectanglePortrait"] = "rbxassetid://132794319919125",
		["insetFilledBottomthirdSquare"] = "rbxassetid://76623279068770",
		["insetFilledBottomtrailingRectangle"] = "rbxassetid://121412469782708",
		["insetFilledBottomtrailingRectanglePortrait"] = "rbxassetid://93668101678869",
		["insetFilledCapsule"] = "rbxassetid://90445157526338",
		["insetFilledCapsulePortrait"] = "rbxassetid://108299551226678",
		["insetFilledCenterRectangle"] = "rbxassetid://98977891812691",
		["insetFilledCenterRectangleBadgePlus"] = "rbxassetid://104683887573848",
		["insetFilledCenterRectanglePortrait"] = "rbxassetid://73922453045894",
		["insetFilledCircle"] = "rbxassetid://75917977120341",
		["insetFilledCircleDashed"] = "rbxassetid://116630264943051",
		["insetFilledCircleSlash"] = "rbxassetid://121268175510312",
		["insetFilledDiamond"] = "rbxassetid://126741449338194",
		["insetFilledLeadinghalfArrowLeadingRectangle"] = "rbxassetid://78017625118769",
		["insetFilledLeadinghalfRectangle"] = "rbxassetid://130706184301016",
		["insetFilledLeadinghalfRectanglePortrait"] = "rbxassetid://85919286811701",
		["insetFilledLeadinghalfToptrailingBottomtrailingRectangle"] = "rbxassetid://70494881048997",
		["insetFilledLeadinghalfTrailinghalfRectangle"] = "rbxassetid://134274869575399",
		["insetFilledLeadingthirdRectangle"] = "rbxassetid://136915676163117",
		["insetFilledLeadingthirdRectanglePortrait"] = "rbxassetid://113702527307183",
		["insetFilledLeadingthirdSquare"] = "rbxassetid://109950316628586",
		["insetFilledLefthalfArrowLeftRectangle"] = "rbxassetid://134984195372501",
		["insetFilledLefthalfRectangle"] = "rbxassetid://72023436186359",
		["insetFilledLefthalfRectanglePortrait"] = "rbxassetid://120313318229969",
		["insetFilledLefthalfRighthalfRectangle"] = "rbxassetid://102132835584174",
		["insetFilledLefthalfToprightBottomrightRectangle"] = "rbxassetid://111841202861656",
		["insetFilledLeftthirdMiddlethirdRightthirdRectangle"] = "rbxassetid://77699442899450",
		["insetFilledLeftthirdRectangle"] = "rbxassetid://112754738404469",
		["insetFilledLeftthirdRectanglePortrait"] = "rbxassetid://131316644740016",
		["insetFilledLeftthirdSquare"] = "rbxassetid://122568783815641",
		["insetFilledOval"] = "rbxassetid://111278423834459",
		["insetFilledOvalPortrait"] = "rbxassetid://125501917035259",
		["insetFilledPano"] = "rbxassetid://80590947649666",
		["insetFilledRectangle"] = "rbxassetid://138708382163165",
		["insetFilledRectangleAndPersonFilled"] = "rbxassetid://87154458723474",
		["insetFilledRectangleAndPersonFilledCircle"] = "rbxassetid://95193435746744",
		["insetFilledRectangleAndPersonFilledCircleFill"] = "rbxassetid://71284408528556",
		["insetFilledRectangleAndPointerArrow"] = "rbxassetid://71367104401668",
		["insetFilledRectangleBadgeRecord"] = "rbxassetid://105070640753020",
		["insetFilledRectangleOnRectangle"] = "rbxassetid://120205174258551",
		["insetFilledRectanglePortrait"] = "rbxassetid://100405460391582",
		["insetFilledRighthalfArrowRightRectangle"] = "rbxassetid://136171522595126",
		["insetFilledRighthalfLefthalfRectangle"] = "rbxassetid://131735122239469",
		["insetFilledRighthalfRectangle"] = "rbxassetid://129492638501890",
		["insetFilledRighthalfRectanglePortrait"] = "rbxassetid://125346899504670",
		["insetFilledRightthirdRectangle"] = "rbxassetid://70604242598186",
		["insetFilledRightthirdRectanglePortrait"] = "rbxassetid://105069897135082",
		["insetFilledRightthirdSquare"] = "rbxassetid://104572444958233",
		["insetFilledSquare"] = "rbxassetid://133012340169358",
		["insetFilledSquareDashed"] = "rbxassetid://83067474683427",
		["insetFilledTophalfBottomhalfRectangle"] = "rbxassetid://105407482136406",
		["insetFilledTophalfBottomleftBottomrightRectangle"] = "rbxassetid://126213084936540",
		["insetFilledTophalfRectangle"] = "rbxassetid://102954017318491",
		["insetFilledTophalfRectanglePortrait"] = "rbxassetid://96770534088202",
		["insetFilledTopleadingBottomleadingTrailinghalfRectangle"] = "rbxassetid://133635573770248",
		["insetFilledTopleadingRectangle"] = "rbxassetid://82767537329467",
		["insetFilledTopleadingRectanglePortrait"] = "rbxassetid://103128241995328",
		["insetFilledTopleftBottomleftRighthalfRectangle"] = "rbxassetid://136216039981584",
		["insetFilledTopleftRectangle"] = "rbxassetid://126843838930696",
		["insetFilledTopleftRectanglePortrait"] = "rbxassetid://96032033362183",
		["insetFilledTopleftToprightBottomhalfRectangle"] = "rbxassetid://131903028482382",
		["insetFilledTopleftToprightBottomleftBottomrightRectangle"] = "rbxassetid://108794580005907",
		["insetFilledToprightRectangle"] = "rbxassetid://128249878170636",
		["insetFilledToprightRectanglePortrait"] = "rbxassetid://81500237959732",
		["insetFilledTopthirdMiddlethirdBottomthirdRectangle"] = "rbxassetid://125282916436565",
		["insetFilledTopthirdRectangle"] = "rbxassetid://113341401260201",
		["insetFilledTopthirdRectanglePortrait"] = "rbxassetid://120512386877930",
		["insetFilledTopthirdSquare"] = "rbxassetid://119824385876092",
		["insetFilledToptrailingRectangle"] = "rbxassetid://129029043300013",
		["insetFilledToptrailingRectanglePortrait"] = "rbxassetid://100995703293630",
		["insetFilledTrailinghalfArrowTrailingRectangle"] = "rbxassetid://84836774081264",
		["insetFilledTrailinghalfLeadinghalfRectangle"] = "rbxassetid://103401929210623",
		["insetFilledTrailinghalfRectangle"] = "rbxassetid://133451001758776",
		["insetFilledTrailinghalfRectanglePortrait"] = "rbxassetid://112562041419219",
		["insetFilledTrailingthirdRectangle"] = "rbxassetid://118636064884027",
		["insetFilledTrailingthirdRectanglePortrait"] = "rbxassetid://75897427033432",
		["insetFilledTrailingthirdSquare"] = "rbxassetid://114005042149867",
		["insetFilledTriangle"] = "rbxassetid://121531632404240",
		["insetFilledTv"] = "rbxassetid://109545088046904",
		["internaldrive"] = "rbxassetid://102251712322050",
		["internaldriveFill"] = "rbxassetid://75514367271798",
		["ipad"] = "rbxassetid://131230554306229",
		["ipadAndArrowForward"] = "rbxassetid://110049781892554",
		["ipadAndIphone"] = "rbxassetid://133274203016358",
		["ipadAndIphoneSlash"] = "rbxassetid://98585690423131",
		["ipadBadgeCheckmark"] = "rbxassetid://123793516179129",
		["ipadBadgeExclamationmark"] = "rbxassetid://113541137806339",
		["ipadBadgeLocation"] = "rbxassetid://117276337518182",
		["ipadBadgePlay"] = "rbxassetid://135586545630005",
		["ipadCase"] = "rbxassetid://72648998001913",
		["ipadCaseAndIphoneCase"] = "rbxassetid://105917542288684",
		["ipadGen1"] = "rbxassetid://123061750908863",
		["ipadGen1BadgeExclamationmark"] = "rbxassetid://97502161805065",
		["ipadGen1BadgeLocation"] = "rbxassetid://90300741766128",
		["ipadGen1BadgePlay"] = "rbxassetid://135252945335606",
		["ipadGen1CropHomebuttonCircle"] = "rbxassetid://123435089120942",
		["ipadGen1Landscape"] = "rbxassetid://81891741408956",
		["ipadGen1LandscapeBadgeExclamationmark"] = "rbxassetid://107044013715078",
		["ipadGen1LandscapeBadgeLocation"] = "rbxassetid://124387888974099",
		["ipadGen1LandscapeBadgePlay"] = "rbxassetid://81439451813082",
		["ipadGen1LandscapeSlash"] = "rbxassetid://115395749352607",
		["ipadGen1Sizes"] = "rbxassetid://118294310937760",
		["ipadGen1Slash"] = "rbxassetid://137094723034266",
		["ipadGen2"] = "rbxassetid://72845801035243",
		["ipadGen2BadgeExclamationmark"] = "rbxassetid://86689553406739",
		["ipadGen2BadgeLocation"] = "rbxassetid://123318608980440",
		["ipadGen2BadgePlay"] = "rbxassetid://120431580583179",
		["ipadGen2Landscape"] = "rbxassetid://73336322338582",
		["ipadGen2LandscapeBadgeExclamationmark"] = "rbxassetid://74543577579883",
		["ipadGen2LandscapeBadgeLocation"] = "rbxassetid://72978217701125",
		["ipadGen2LandscapeBadgePlay"] = "rbxassetid://88880081274171",
		["ipadGen2LandscapeSlash"] = "rbxassetid://93298411493155",
		["ipadGen2Sizes"] = "rbxassetid://92860208821978",
		["ipadGen2Slash"] = "rbxassetid://97413632843279",
		["ipadLandscape"] = "rbxassetid://98570913676933",
		["ipadLandscapeAndApplewatch"] = "rbxassetid://78572604978981",
		["ipadLandscapeAndIphone"] = "rbxassetid://103405408625627",
		["ipadLandscapeAndIphoneSlash"] = "rbxassetid://83949384569338",
		["ipadLandscapeAndIpod"] = "rbxassetid://126361538286391",
		["ipadLandscapeBadgeExclamationmark"] = "rbxassetid://79735738496284",
		["ipadLandscapeBadgeLocation"] = "rbxassetid://119487770282833",
		["ipadLandscapeBadgePlay"] = "rbxassetid://131593550438106",
		["ipadRearCamera"] = "rbxassetid://100950321161338",
		["ipadSizes"] = "rbxassetid://117365106864126",
		["iphone"] = "rbxassetid://96785236033941",
		["iphoneAndArrowForward"] = "rbxassetid://117210262149661",
		["iphoneAndArrowForwardInward"] = "rbxassetid://127905379728905",
		["iphoneAndArrowForwardOutward"] = "rbxassetid://80118778349170",
		["iphoneAndArrowLeftAndArrowRight"] = "rbxassetid://104339904723080",
		["iphoneAndArrowLeftAndArrowRightInward"] = "rbxassetid://117948708918605",
		["iphoneAndArrowRightInward"] = "rbxassetid://79888523696187",
		["iphoneAndArrowRightOutward"] = "rbxassetid://122240049510090",
		["iphoneAndIpod"] = "rbxassetid://97511296416293",
		["iphoneAndVisionPro"] = "rbxassetid://120484375912051",
		["iphoneAppSwitcher"] = "rbxassetid://133135376021847",
		["iphoneBadgeCheckmark"] = "rbxassetid://102860706153917",
		["iphoneBadgeExclamationmark"] = "rbxassetid://71713794425391",
		["iphoneBadgeLocation"] = "rbxassetid://122605433839128",
		["iphoneBadgePlay"] = "rbxassetid://99553977604210",
		["iphoneCase"] = "rbxassetid://100408903353145",
		["iphoneCircle"] = "rbxassetid://136014152812869",
		["iphoneCircleFill"] = "rbxassetid://117758615235459",
		["iphoneCropCircle"] = "rbxassetid://71562894009267",
		["iphoneDockMotorizedViewfinder"] = "rbxassetid://132637320368921",
		["iphoneGen1"] = "rbxassetid://94152158848001",
		["iphoneGen1AndArrowLeft"] = "rbxassetid://127049565346505",
		["iphoneGen1BadgeExclamationmark"] = "rbxassetid://77237650629580",
		["iphoneGen1BadgeLocation"] = "rbxassetid://104241024785309",
		["iphoneGen1BadgePlay"] = "rbxassetid://92461645076483",
		["iphoneGen1Circle"] = "rbxassetid://116798852794419",
		["iphoneGen1CircleFill"] = "rbxassetid://94921719612712",
		["iphoneGen1CropCircle"] = "rbxassetid://105220191366334",
		["iphoneGen1CropHomebuttonCircle"] = "rbxassetid://120481565169469",
		["iphoneGen1Landscape"] = "rbxassetid://137867981805693",
		["iphoneGen1LandscapeSlash"] = "rbxassetid://128717452111489",
		["iphoneGen1Motion"] = "rbxassetid://122054190796509",
		["iphoneGen1RadiowavesLeftAndRight"] = "rbxassetid://133529445742502",
		["iphoneGen1RadiowavesLeftAndRightCircle"] = "rbxassetid://125660794021542",
		["iphoneGen1RadiowavesLeftAndRightCircleFill"] = "rbxassetid://106520977934691",
		["iphoneGen1Sizes"] = "rbxassetid://133043833497584",
		["iphoneGen1Slash"] = "rbxassetid://132512376385662",
		["iphoneGen1SlashCircle"] = "rbxassetid://131363565228610",
		["iphoneGen1SlashCircleFill"] = "rbxassetid://139459042705882",
		["iphoneGen2"] = "rbxassetid://126158544332994",
		["iphoneGen2AndArrowLeftAndArrowRightInward"] = "rbxassetid://116971900100346",
		["iphoneGen2BadgeExclamationmark"] = "rbxassetid://124222723580362",
		["iphoneGen2BadgeLocation"] = "rbxassetid://89458034440222",
		["iphoneGen2BadgePlay"] = "rbxassetid://83586848263184",
		["iphoneGen2Circle"] = "rbxassetid://84600552457895",
		["iphoneGen2CircleFill"] = "rbxassetid://102360021492589",
		["iphoneGen2CropCircle"] = "rbxassetid://86170718962353",
		["iphoneGen2Landscape"] = "rbxassetid://90012948331103",
		["iphoneGen2LandscapeSlash"] = "rbxassetid://107053953408192",
		["iphoneGen2Motion"] = "rbxassetid://75209858125378",
		["iphoneGen2RadiowavesLeftAndRight"] = "rbxassetid://137843293377967",
		["iphoneGen2RadiowavesLeftAndRightCircle"] = "rbxassetid://78517623289183",
		["iphoneGen2RadiowavesLeftAndRightCircleFill"] = "rbxassetid://131656745166889",
		["iphoneGen2Sizes"] = "rbxassetid://81272476589028",
		["iphoneGen2Slash"] = "rbxassetid://76336416899694",
		["iphoneGen2SlashCircle"] = "rbxassetid://133859389260522",
		["iphoneGen2SlashCircleFill"] = "rbxassetid://87199768439188",
		["iphoneGen3"] = "rbxassetid://92492572556324",
		["iphoneGen3AndArrowLeftAndArrowRightInward"] = "rbxassetid://118657589793721",
		["iphoneGen3BadgeExclamationmark"] = "rbxassetid://113121813406073",
		["iphoneGen3BadgeLocation"] = "rbxassetid://117982542340771",
		["iphoneGen3BadgePlay"] = "rbxassetid://125330422338100",
		["iphoneGen3Circle"] = "rbxassetid://86912097932476",
		["iphoneGen3CircleFill"] = "rbxassetid://94525449390144",
		["iphoneGen3CropCircle"] = "rbxassetid://94048325413237",
		["iphoneGen3Landscape"] = "rbxassetid://114233975397990",
		["iphoneGen3LandscapeSlash"] = "rbxassetid://132992124593122",
		["iphoneGen3Motion"] = "rbxassetid://98169599088581",
		["iphoneGen3RadiowavesLeftAndRight"] = "rbxassetid://72200807533817",
		["iphoneGen3RadiowavesLeftAndRightCircle"] = "rbxassetid://106374321761914",
		["iphoneGen3RadiowavesLeftAndRightCircleFill"] = "rbxassetid://72465338711976",
		["iphoneGen3Sizes"] = "rbxassetid://76366535677582",
		["iphoneGen3Slash"] = "rbxassetid://90077097271339",
		["iphoneGen3SlashCircle"] = "rbxassetid://111474089697962",
		["iphoneGen3SlashCircleFill"] = "rbxassetid://111157278153150",
		["iphoneLandscape"] = "rbxassetid://127446547566888",
		["iphoneMotion"] = "rbxassetid://130536425029393",
		["iphonePatternDiagonalline"] = "rbxassetid://135162003513277",
		["iphonePatternDiagonallineOnRectanglePortraitDashed"] = "rbxassetid://112745590711907",
		["iphoneRadiowavesLeftAndRight"] = "rbxassetid://100186481961591",
		["iphoneRadiowavesLeftAndRightCircle"] = "rbxassetid://124241232816642",
		["iphoneRadiowavesLeftAndRightCircleFill"] = "rbxassetid://120377260746135",
		["iphoneRearCamera"] = "rbxassetid://120522581577378",
		["iphoneSizes"] = "rbxassetid://135407341947073",
		["iphoneSlash"] = "rbxassetid://90628537365176",
		["iphoneSlashCircle"] = "rbxassetid://122677491004031",
		["iphoneSlashCircleFill"] = "rbxassetid://115785875771965",
		["iphoneSmartbatterycaseGen1"] = "rbxassetid://134849352121716",
		["iphoneSmartbatterycaseGen2"] = "rbxassetid://85196761349659",
		["ipod"] = "rbxassetid://80468906468753",
		["ipodAndApplewatch"] = "rbxassetid://93719301646294",
		["ipodAndVisionPro"] = "rbxassetid://83017359796219",
		["ipodShuffleGen1"] = "rbxassetid://136172132310552",
		["ipodShuffleGen2"] = "rbxassetid://76170036384439",
		["ipodShuffleGen3"] = "rbxassetid://110263498432868",
		["ipodShuffleGen4"] = "rbxassetid://131032367315049",
		["ipodTouch"] = "rbxassetid://105267613849911",
		["ipodTouchLandscape"] = "rbxassetid://116094116999635",
		["ipodTouchSlash"] = "rbxassetid://81927156094607",
		["ipodshuffleGen1"] = "rbxassetid://85956093711602",
		["ipodshuffleGen2"] = "rbxassetid://85111088101023",
		["ipodshuffleGen3"] = "rbxassetid://123523059376894",
		["ipodshuffleGen4"] = "rbxassetid://73762011203526",
		["ipodtouch"] = "rbxassetid://119129980411950",
		["ipodtouchLandscape"] = "rbxassetid://84719307699005",
		["ipodtouchSlash"] = "rbxassetid://71827533045992",
		["italic"] = "rbxassetid://114841606569634",
		["ivfluidBag"] = "rbxassetid://85925137715594",
		["ivfluidBagFill"] = "rbxassetid://112534881575448",
		["jCircle"] = "rbxassetid://113787719639007",
		["jCircleFill"] = "rbxassetid://136066715693266",
		["jSquare"] = "rbxassetid://132663369942785",
		["jSquareFill"] = "rbxassetid://110186942350601",
		["jSquareOnSquare"] = "rbxassetid://70770700564140",
		["jSquareOnSquareFill"] = "rbxassetid://86732752263868",
		["jacket"] = "rbxassetid://110977300370127",
		["jacketCircle"] = "rbxassetid://73905147156647",
		["jacketCircleFill"] = "rbxassetid://87569696632536",
		["jacketFill"] = "rbxassetid://129429549539056",
		["jacketSensorTagRadiowavesLeftAndRight"] = "rbxassetid://81170082341074",
		["jacketSensorTagRadiowavesLeftAndRightFill"] = "rbxassetid://86875701016809",
		["k"] = "rbxassetid://131453804995230",
		["kCircle"] = "rbxassetid://108260281955032",
		["kCircleFill"] = "rbxassetid://127917254878881",
		["kSquare"] = "rbxassetid://76333957199097",
		["kSquareFill"] = "rbxassetid://109715448814787",
		["kashidaArabic"] = "rbxassetid://113587154651306",
		["key"] = "rbxassetid://133434192543807",
		["key2OnRing"] = "rbxassetid://76703793889414",
		["key2OnRingFill"] = "rbxassetid://76588755997300",
		["keyCarRadiowavesForward"] = "rbxassetid://112640775536914",
		["keyCarRadiowavesForwardFill"] = "rbxassetid://113133901858914",
		["keyCarSide"] = "rbxassetid://130777080754266",
		["keyCarSideFill"] = "rbxassetid://97814070412964",
		["keyCard"] = "rbxassetid://115187278538124",
		["keyCardFill"] = "rbxassetid://139348357957386",
		["keyCircle"] = "rbxassetid://108973244339496",
		["keyCircleFill"] = "rbxassetid://110326981381894",
		["keyConvertibleSide"] = "rbxassetid://89421482992474",
		["keyConvertibleSideFill"] = "rbxassetid://72129430413908",
		["keyFill"] = "rbxassetid://100941145516940",
		["keyHorizontal"] = "rbxassetid://136772885372533",
		["keyHorizontalFill"] = "rbxassetid://120752932235278",
		["keyIcloud"] = "rbxassetid://139241478885890",
		["keyIcloudFill"] = "rbxassetid://72564816797669",
		["keyRadiowavesForward"] = "rbxassetid://120443557468351",
		["keyRadiowavesForwardFill"] = "rbxassetid://73268293809232",
		["keyRadiowavesForwardSlash"] = "rbxassetid://91223085154439",
		["keyRadiowavesForwardSlashFill"] = "rbxassetid://131793789575248",
		["keySensorTagRadiowavesLeftAndRight"] = "rbxassetid://96659898144332",
		["keySensorTagRadiowavesLeftAndRightFill"] = "rbxassetid://98758622563103",
		["keyShield"] = "rbxassetid://104889894182978",
		["keyShieldFill"] = "rbxassetid://115236492425793",
		["keySlash"] = "rbxassetid://128541901933913",
		["keySlashFill"] = "rbxassetid://103334949123430",
		["keySuvSide"] = "rbxassetid://113533289572731",
		["keySuvSideFill"] = "rbxassetid://98960872652240",
		["keyTruckPickupSide"] = "rbxassetid://140618494739761",
		["keyTruckPickupSideFill"] = "rbxassetid://72634089700259",
		["keyViewfinder"] = "rbxassetid://102804665349975",
		["keyboard"] = "rbxassetid://105919136330989",
		["keyboardBadgeEllipsis"] = "rbxassetid://138764951588511",
		["keyboardBadgeEllipsisFill"] = "rbxassetid://129826695434297",
		["keyboardBadgeEye"] = "rbxassetid://88947978884486",
		["keyboardBadgeEyeFill"] = "rbxassetid://113136519679576",
		["keyboardChevronCompactDown"] = "rbxassetid://122434132254331",
		["keyboardChevronCompactDownFill"] = "rbxassetid://132119530733764",
		["keyboardChevronCompactLeft"] = "rbxassetid://93873100176471",
		["keyboardChevronCompactLeftFill"] = "rbxassetid://122102681496501",
		["keyboardFill"] = "rbxassetid://107094757259919",
		["keyboardMacwindow"] = "rbxassetid://81009841388075",
		["keyboardOnehandedLeft"] = "rbxassetid://96435588655591",
		["keyboardOnehandedLeftFill"] = "rbxassetid://84926357433136",
		["keyboardOnehandedRight"] = "rbxassetid://99512020372077",
		["keyboardOnehandedRightFill"] = "rbxassetid://114811778842920",
		["kipsign"] = "rbxassetid://139124096600858",
		["kipsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://121587106422922",
		["kipsignBankBuilding"] = "rbxassetid://118184717903574",
		["kipsignBankBuildingFill"] = "rbxassetid://124188099989927",
		["kipsignCircle"] = "rbxassetid://125257177249690",
		["kipsignCircleFill"] = "rbxassetid://87946535077535",
		["kipsignGaugeChartLefthalfRighthalf"] = "rbxassetid://132967067870371",
		["kipsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://73726622341666",
		["kipsignRing"] = "rbxassetid://99797321226540",
		["kipsignRingDashed"] = "rbxassetid://105404390233593",
		["kipsignSquare"] = "rbxassetid://133836203040078",
		["kipsignSquareFill"] = "rbxassetid://80235335357450",
		["kph"] = "rbxassetid://117481583715113",
		["kphCircle"] = "rbxassetid://137148268988469",
		["kphCircleFill"] = "rbxassetid://126101024239774",
		["l1ButtonRoundedbottomHorizontal"] = "rbxassetid://95790368795483",
		["l1ButtonRoundedbottomHorizontalFill"] = "rbxassetid://128440014143027",
		["l1Circle"] = "rbxassetid://102236186726427",
		["l1CircleFill"] = "rbxassetid://116773512326026",
		["l2ButtonAngledtopVerticalLeft"] = "rbxassetid://99495903296844",
		["l2ButtonAngledtopVerticalLeftFill"] = "rbxassetid://110271917565119",
		["l2ButtonRoundedtopHorizontal"] = "rbxassetid://91390095902654",
		["l2ButtonRoundedtopHorizontalFill"] = "rbxassetid://79761826766984",
		["l2Circle"] = "rbxassetid://74248236678335",
		["l2CircleFill"] = "rbxassetid://109925799906152",
		["l3ButtonAngledbottomHorizontalLeft"] = "rbxassetid://123803597683885",
		["l3ButtonAngledbottomHorizontalLeftFill"] = "rbxassetid://134808114449129",
		["l4ButtonHorizontal"] = "rbxassetid://100597686733238",
		["l4ButtonHorizontalFill"] = "rbxassetid://89171783331888",
		["lButtonRoundedbottomHorizontal"] = "rbxassetid://130058952204010",
		["lButtonRoundedbottomHorizontalFill"] = "rbxassetid://105492940635087",
		["lCircle"] = "rbxassetid://88768237168264",
		["lCircleFill"] = "rbxassetid://115654171291345",
		["lJoystick"] = "rbxassetid://124158836435588",
		["lJoystickFill"] = "rbxassetid://72524976304902",
		["lJoystickPressDown"] = "rbxassetid://126988825422704",
		["lJoystickPressDownFill"] = "rbxassetid://122290771310900",
		["lJoystickTiltDown"] = "rbxassetid://98216370037941",
		["lJoystickTiltDownFill"] = "rbxassetid://106818736496317",
		["lJoystickTiltLeft"] = "rbxassetid://117338893439682",
		["lJoystickTiltLeftFill"] = "rbxassetid://115979752014913",
		["lJoystickTiltRight"] = "rbxassetid://104661243170230",
		["lJoystickTiltRightFill"] = "rbxassetid://127932461706178",
		["lJoystickTiltUp"] = "rbxassetid://103418791124625",
		["lJoystickTiltUpFill"] = "rbxassetid://139059621301014",
		["lSquare"] = "rbxassetid://135675870127012",
		["lSquareFill"] = "rbxassetid://92188040928529",
		["ladybug"] = "rbxassetid://106759060151131",
		["ladybugCircle"] = "rbxassetid://79448683961001",
		["ladybugCircleFill"] = "rbxassetid://133960361550152",
		["ladybugFill"] = "rbxassetid://113818385620830",
		["ladybugSlash"] = "rbxassetid://122118980779982",
		["ladybugSlashCircle"] = "rbxassetid://79524457814539",
		["ladybugSlashCircleFill"] = "rbxassetid://135161883645329",
		["ladybugSlashFill"] = "rbxassetid://90687484782825",
		["lampCeiling"] = "rbxassetid://130697710320625",
		["lampCeilingFill"] = "rbxassetid://88194539041083",
		["lampCeilingInverse"] = "rbxassetid://94283461619651",
		["lampDesk"] = "rbxassetid://103868701476630",
		["lampDeskFill"] = "rbxassetid://131947905513117",
		["lampFloor"] = "rbxassetid://118272420344055",
		["lampFloorFill"] = "rbxassetid://81002667912169",
		["lampTable"] = "rbxassetid://131486052019715",
		["lampTableFill"] = "rbxassetid://78919597241075",
		["lane"] = "rbxassetid://86601744938682",
		["lanyardcard"] = "rbxassetid://125357233986697",
		["lanyardcardFill"] = "rbxassetid://118783818997054",
		["laptopcomputer"] = "rbxassetid://93924665405931",
		["laptopcomputerAndArrowDown"] = "rbxassetid://136939371714748",
		["laptopcomputerBadgeCheckmark"] = "rbxassetid://120482812026626",
		["laptopcomputerSlash"] = "rbxassetid://79424129365987",
		["laptopcomputerTrianglebadgeExclamationmark"] = "rbxassetid://120513527990773",
		["larisign"] = "rbxassetid://136485640218866",
		["larisignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://121246946230961",
		["larisignBankBuilding"] = "rbxassetid://111789107676481",
		["larisignBankBuildingFill"] = "rbxassetid://134210738755691",
		["larisignCircle"] = "rbxassetid://92080196175408",
		["larisignCircleFill"] = "rbxassetid://109430195650783",
		["larisignGaugeChartLefthalfRighthalf"] = "rbxassetid://104420126879803",
		["larisignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://112845157907157",
		["larisignRing"] = "rbxassetid://82146466164245",
		["larisignRingDashed"] = "rbxassetid://137685798255874",
		["larisignSquare"] = "rbxassetid://85653556559155",
		["larisignSquareFill"] = "rbxassetid://89054689413231",
		["laserBurst"] = "rbxassetid://117110789250652",
		["lasso"] = "rbxassetid://73650965371496",
		["lassoBadgeSparkles"] = "rbxassetid://100331357189805",
		["latch2Case"] = "rbxassetid://127322944927667",
		["latch2CaseFill"] = "rbxassetid://137373973211444",
		["laurelLeading"] = "rbxassetid://74230370864247",
		["laurelLeadingLaurelTrailing"] = "rbxassetid://121289783441119",
		["laurelTrailing"] = "rbxassetid://100164466613687",
		["lbButtonRoundedbottomHorizontal"] = "rbxassetid://88293514053614",
		["lbButtonRoundedbottomHorizontalFill"] = "rbxassetid://98021114053942",
		["lbCircle"] = "rbxassetid://74325404659334",
		["lbCircleFill"] = "rbxassetid://71487768652535",
		["leaf"] = "rbxassetid://137721714285432",
		["leafArrowTriangleCirclepath"] = "rbxassetid://84475508392251",
		["leafArrowTriangleheadClockwise"] = "rbxassetid://113114088100330",
		["leafCircle"] = "rbxassetid://86174952690199",
		["leafCircleFill"] = "rbxassetid://93634187189693",
		["leafFill"] = "rbxassetid://113484795763411",
		["left"] = "rbxassetid://107416334182822",
		["leftCircle"] = "rbxassetid://119934421439703",
		["leftCircleFill"] = "rbxassetid://105463146320094",
		["lessthan"] = "rbxassetid://94199123453074",
		["lessthanCircle"] = "rbxassetid://111066641037520",
		["lessthanCircleFill"] = "rbxassetid://100079024283083",
		["lessthanSquare"] = "rbxassetid://84887643197832",
		["lessthanSquareFill"] = "rbxassetid://113303675678039",
		["lessthanorequalto"] = "rbxassetid://90520186962478",
		["lessthanorequaltoCircle"] = "rbxassetid://89396258122438",
		["lessthanorequaltoCircleFill"] = "rbxassetid://80241893107159",
		["lessthanorequaltoSquare"] = "rbxassetid://103756445378013",
		["lessthanorequaltoSquareFill"] = "rbxassetid://113570432934713",
		["letterACircle"] = "rbxassetid://102043519807680",
		["letterASquare"] = "rbxassetid://123876841192249",
		["letterBCircle"] = "rbxassetid://81796888108964",
		["letterBSquare"] = "rbxassetid://107926268990493",
		["letterCCircle"] = "rbxassetid://102283325788464",
		["letterCSquare"] = "rbxassetid://77342805733080",
		["letterDCircle"] = "rbxassetid://77271013016863",
		["letterDSquare"] = "rbxassetid://71745998559849",
		["letterECircle"] = "rbxassetid://110939040840018",
		["letterESquare"] = "rbxassetid://130805805047117",
		["letterFCircle"] = "rbxassetid://75292206915955",
		["letterFCursive"] = "rbxassetid://129129749457489",
		["letterFCursiveCircle"] = "rbxassetid://88414197139904",
		["letterFSquare"] = "rbxassetid://80222891036830",
		["letterGCircle"] = "rbxassetid://101617051624970",
		["letterGSquare"] = "rbxassetid://101108516134256",
		["letterHCircle"] = "rbxassetid://104755888415516",
		["letterHSquare"] = "rbxassetid://119444843840302",
		["letterHSquareOnSquare"] = "rbxassetid://138633232751099",
		["letterICircle"] = "rbxassetid://100265252155056",
		["letterISquare"] = "rbxassetid://78227741894490",
		["letterJCircle"] = "rbxassetid://127681856901613",
		["letterJSquare"] = "rbxassetid://70614371401130",
		["letterJSquareOnSquare"] = "rbxassetid://136068707644750",
		["letterK"] = "rbxassetid://93236576104824",
		["letterKCircle"] = "rbxassetid://126766755298208",
		["letterKSquare"] = "rbxassetid://132054295015575",
		["letterLButtonRoundedbottomHorizontal"] = "rbxassetid://86796430696473",
		["letterLCircle"] = "rbxassetid://115151845775938",
		["letterLJoystick"] = "rbxassetid://126954698608958",
		["letterLJoystickPressDown"] = "rbxassetid://101991839887936",
		["letterLJoystickTiltDown"] = "rbxassetid://109426620639396",
		["letterLJoystickTiltLeft"] = "rbxassetid://88760036840814",
		["letterLJoystickTiltRight"] = "rbxassetid://123427118118507",
		["letterLJoystickTiltUp"] = "rbxassetid://108699411245416",
		["letterLSquare"] = "rbxassetid://102129122454965",
		["letterMCircle"] = "rbxassetid://105252616936701",
		["letterMSquare"] = "rbxassetid://91788346353476",
		["letterNCircle"] = "rbxassetid://108501754774630",
		["letterNSquare"] = "rbxassetid://134128630622949",
		["letterOCircle"] = "rbxassetid://102216372092166",
		["letterOSquare"] = "rbxassetid://100189064332452",
		["letterPCircle"] = "rbxassetid://133454893649760",
		["letterPSquare"] = "rbxassetid://121771081041226",
		["letterQCircle"] = "rbxassetid://121158947718797",
		["letterQSquare"] = "rbxassetid://138412895934294",
		["letterRButtonRoundedbottomHorizontal"] = "rbxassetid://127892690915857",
		["letterRCircle"] = "rbxassetid://71266917331154",
		["letterRJoystick"] = "rbxassetid://77839293235193",
		["letterRJoystickPressDown"] = "rbxassetid://101313826207669",
		["letterRJoystickTiltDown"] = "rbxassetid://107724362619264",
		["letterRJoystickTiltLeft"] = "rbxassetid://105136001525486",
		["letterRJoystickTiltRight"] = "rbxassetid://110960582214040",
		["letterRJoystickTiltUp"] = "rbxassetid://71286967299311",
		["letterRSquare"] = "rbxassetid://135777530848446",
		["letterRSquareOnSquare"] = "rbxassetid://123053148394613",
		["letterSCircle"] = "rbxassetid://83393144046860",
		["letterSSquare"] = "rbxassetid://137609708051079",
		["letterTCircle"] = "rbxassetid://75623106527183",
		["letterTSquare"] = "rbxassetid://116018632541398",
		["letterUCircle"] = "rbxassetid://100569535331718",
		["letterUSquare"] = "rbxassetid://76708256054317",
		["letterVCircle"] = "rbxassetid://83920398217229",
		["letterVSquare"] = "rbxassetid://129063617167906",
		["letterWCircle"] = "rbxassetid://107802977183125",
		["letterWSquare"] = "rbxassetid://83322547030564",
		["letterXCircle"] = "rbxassetid://99920343804208",
		["letterXSquare"] = "rbxassetid://123476212380657",
		["letterXSquareroot"] = "rbxassetid://80429022258285",
		["letterYCircle"] = "rbxassetid://120543405393753",
		["letterYSquare"] = "rbxassetid://80658772608290",
		["letterZCircle"] = "rbxassetid://109541227310226",
		["letterZSquare"] = "rbxassetid://139916717288653",
		["level"] = "rbxassetid://75072843777421",
		["levelFill"] = "rbxassetid://128257992127602",
		["licenseplate"] = "rbxassetid://130402934113130",
		["licenseplateFill"] = "rbxassetid://117121209379254",
		["lifepreserver"] = "rbxassetid://125826954375015",
		["lifepreserverFill"] = "rbxassetid://118868969071769",
		["lightBeaconMax"] = "rbxassetid://75066576103161",
		["lightBeaconMaxFill"] = "rbxassetid://87530931992175",
		["lightBeaconMin"] = "rbxassetid://107757740522836",
		["lightBeaconMinFill"] = "rbxassetid://100129869918387",
		["lightCylindricalCeiling"] = "rbxassetid://110334573858912",
		["lightCylindricalCeilingFill"] = "rbxassetid://104211467198230",
		["lightCylindricalCeilingInverse"] = "rbxassetid://75728133446100",
		["lightMax"] = "rbxassetid://84057115606407",
		["lightMin"] = "rbxassetid://125533100436531",
		["lightOverheadLeft"] = "rbxassetid://122835138684644",
		["lightOverheadLeftFill"] = "rbxassetid://111580070717708",
		["lightOverheadRight"] = "rbxassetid://117111693005736",
		["lightOverheadRightFill"] = "rbxassetid://98686619044486",
		["lightPanel"] = "rbxassetid://106777073156176",
		["lightPanelFill"] = "rbxassetid://110860563202036",
		["lightRecessed"] = "rbxassetid://126364480423039",
		["lightRecessed3"] = "rbxassetid://130398146961010",
		["lightRecessed3Fill"] = "rbxassetid://104115923130457",
		["lightRecessed3Inverse"] = "rbxassetid://103615064195110",
		["lightRecessedFill"] = "rbxassetid://88775166873026",
		["lightRecessedInverse"] = "rbxassetid://78252492817119",
		["lightRibbon"] = "rbxassetid://122142963253357",
		["lightRibbonFill"] = "rbxassetid://93066238961423",
		["lightStrip2"] = "rbxassetid://134019470579747",
		["lightStrip2Fill"] = "rbxassetid://127276872174766",
		["lightbulb"] = "rbxassetid://82644985572724",
		["lightbulb2"] = "rbxassetid://112234784324905",
		["lightbulb2Fill"] = "rbxassetid://127418974043306",
		["lightbulbCircle"] = "rbxassetid://126479516799358",
		["lightbulbCircleFill"] = "rbxassetid://120553924518927",
		["lightbulbFill"] = "rbxassetid://73118667835537",
		["lightbulbLed"] = "rbxassetid://86111405001092",
		["lightbulbLedFill"] = "rbxassetid://114870437439505",
		["lightbulbLedWide"] = "rbxassetid://117190619134004",
		["lightbulbLedWideFill"] = "rbxassetid://102938343676175",
		["lightbulbMax"] = "rbxassetid://122168294554782",
		["lightbulbMaxFill"] = "rbxassetid://90138003500408",
		["lightbulbMin"] = "rbxassetid://83516231106615",
		["lightbulbMinBadgeExclamationmark"] = "rbxassetid://97382076149987",
		["lightbulbMinBadgeExclamationmarkFill"] = "rbxassetid://103335346024590",
		["lightbulbMinFill"] = "rbxassetid://70934321968116",
		["lightbulbSlash"] = "rbxassetid://86800234658429",
		["lightbulbSlashFill"] = "rbxassetid://132786331318088",
		["lightrail"] = "rbxassetid://96129918016259",
		["lightrailFill"] = "rbxassetid://76488782471583",
		["lightspectrumHorizontal"] = "rbxassetid://135984270467670",
		["lightswitchOff"] = "rbxassetid://80355295612879",
		["lightswitchOffFill"] = "rbxassetid://128742926647255",
		["lightswitchOffSquare"] = "rbxassetid://97372717984343",
		["lightswitchOffSquareFill"] = "rbxassetid://128134911832629",
		["lightswitchOn"] = "rbxassetid://95538959639294",
		["lightswitchOnFill"] = "rbxassetid://115337416605268",
		["lightswitchOnSquare"] = "rbxassetid://114272644374823",
		["lightswitchOnSquareFill"] = "rbxassetid://117381560381596",
		["line2HorizontalDecreaseCircle"] = "rbxassetid://117477657723597",
		["line2HorizontalDecreaseCircleFill"] = "rbxassetid://118871890045553",
		["line3CrossedSwirlCircle"] = "rbxassetid://118318609660111",
		["line3CrossedSwirlCircleFill"] = "rbxassetid://134883004157167",
		["line3Horizontal"] = "rbxassetid://111782926831220",
		["line3HorizontalButtonAngledtopVerticalRight"] = "rbxassetid://111887877381966",
		["line3HorizontalButtonAngledtopVerticalRightFill"] = "rbxassetid://105369276135548",
		["line3HorizontalCircle"] = "rbxassetid://85990723384739",
		["line3HorizontalCircleFill"] = "rbxassetid://134954138715896",
		["line3HorizontalDecrease"] = "rbxassetid://88784585171582",
		["line3HorizontalDecreaseCircle"] = "rbxassetid://111870154383622",
		["line3HorizontalDecreaseCircleFill"] = "rbxassetid://111120609004176",
		["lineDiagonal"] = "rbxassetid://137379155901548",
		["lineDiagonalArrow"] = "rbxassetid://92568642919457",
		["lineDiagonalTriangleheadUpRight"] = "rbxassetid://99642044971640",
		["lineDiagonalTriangleheadUpRightLeftDown"] = "rbxassetid://117149190547171",
		["lineHorizontalStarFillLineHorizontal"] = "rbxassetid://115363674331340",
		["linesMeasurementHorizontal"] = "rbxassetid://136276260519777",
		["linesMeasurementHorizontalAlignedBottom"] = "rbxassetid://83461597148439",
		["linesMeasurementVertical"] = "rbxassetid://84074029327107",
		["lineweight"] = "rbxassetid://97237441591248",
		["link"] = "rbxassetid://136619733214436",
		["linkBadgePlus"] = "rbxassetid://131321360443285",
		["linkCircle"] = "rbxassetid://87090441280339",
		["linkCircleFill"] = "rbxassetid://107749660504734",
		["linkIcloud"] = "rbxassetid://111707841053107",
		["linkIcloudFill"] = "rbxassetid://105624820343494",
		["lirasign"] = "rbxassetid://84073855052381",
		["lirasignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://112189369114653",
		["lirasignBankBuilding"] = "rbxassetid://73850619799669",
		["lirasignBankBuildingFill"] = "rbxassetid://107050841352588",
		["lirasignCircle"] = "rbxassetid://90679509165073",
		["lirasignCircleFill"] = "rbxassetid://120896567895081",
		["lirasignGaugeChartLefthalfRighthalf"] = "rbxassetid://81758283721386",
		["lirasignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://85227261273468",
		["lirasignRing"] = "rbxassetid://107360539711488",
		["lirasignRingDashed"] = "rbxassetid://120907404527155",
		["lirasignSquare"] = "rbxassetid://81175836370962",
		["lirasignSquareFill"] = "rbxassetid://72540101703939",
		["listAndFilm"] = "rbxassetid://124042334716524",
		["listBullet"] = "rbxassetid://85287233895860",
		["listBulletBadgeEllipsis"] = "rbxassetid://140007423548089",
		["listBulletBelowRectangle"] = "rbxassetid://97820811515269",
		["listBulletCircle"] = "rbxassetid://106489365197935",
		["listBulletCircleFill"] = "rbxassetid://76642065569774",
		["listBulletClipboard"] = "rbxassetid://128179771023669",
		["listBulletClipboardFill"] = "rbxassetid://126582430954250",
		["listBulletIndent"] = "rbxassetid://98732304151282",
		["listBulletRectangle"] = "rbxassetid://92743956457723",
		["listBulletRectangleFill"] = "rbxassetid://133554938646728",
		["listBulletRectanglePortrait"] = "rbxassetid://92563978202451",
		["listBulletRectanglePortraitFill"] = "rbxassetid://85234388613283",
		["listClipboard"] = "rbxassetid://75088463417517",
		["listClipboardFill"] = "rbxassetid://113932200461935",
		["listDash"] = "rbxassetid://100354325683976",
		["listDashBadgeEllipsis"] = "rbxassetid://84510667031315",
		["listDashHeaderRectangle"] = "rbxassetid://76123478093568",
		["listDashHeaderRectangleFill"] = "rbxassetid://137696701087503",
		["listNumber"] = "rbxassetid://125517805939041",
		["listNumberBadgeEllipsis"] = "rbxassetid://106543491819062",
		["listStar"] = "rbxassetid://88814060523780",
		["listTriangle"] = "rbxassetid://137615361230392",
		["livephoto"] = "rbxassetid://101779027126388",
		["livephotoBadgeAutomatic"] = "rbxassetid://98509238080247",
		["livephotoPlay"] = "rbxassetid://76487982956241",
		["livephotoSlash"] = "rbxassetid://88783391904094",
		["lizard"] = "rbxassetid://81394090984711",
		["lizardCircle"] = "rbxassetid://131956914242763",
		["lizardCircleFill"] = "rbxassetid://89102359342570",
		["lizardFill"] = "rbxassetid://129667686919250",
		["lmButtonHorizontal"] = "rbxassetid://124518663294778",
		["lmButtonHorizontalFill"] = "rbxassetid://137794225984963",
		["location"] = "rbxassetid://87454675226726",
		["locationApp"] = "rbxassetid://108285658100441",
		["locationAppFill"] = "rbxassetid://115997390547074",
		["locationCircle"] = "rbxassetid://102031654429688",
		["locationCircleFill"] = "rbxassetid://129255026559329",
		["locationFill"] = "rbxassetid://104193509962276",
		["locationFillViewfinder"] = "rbxassetid://72520718163831",
		["locationMagnifyingglass"] = "rbxassetid://130738172515937",
		["locationNorth"] = "rbxassetid://91961895110874",
		["locationNorthCircle"] = "rbxassetid://92630833006450",
		["locationNorthCircleFill"] = "rbxassetid://115261018724721",
		["locationNorthFill"] = "rbxassetid://82896630625065",
		["locationNorthLine"] = "rbxassetid://124393707860080",
		["locationNorthLineFill"] = "rbxassetid://88364457142872",
		["locationSlash"] = "rbxassetid://91986292380461",
		["locationSlashCircle"] = "rbxassetid://133057661198672",
		["locationSlashCircleFill"] = "rbxassetid://120666508274749",
		["locationSlashFill"] = "rbxassetid://74991633260544",
		["locationSquare"] = "rbxassetid://139433662072438",
		["locationSquareFill"] = "rbxassetid://103262354171629",
		["locationViewfinder"] = "rbxassetid://107082380893473",
		["lock"] = "rbxassetid://75059666276795",
		["lockAppDashed"] = "rbxassetid://73622959173423",
		["lockApplewatch"] = "rbxassetid://137701880303372",
		["lockBadgeCheckmark"] = "rbxassetid://96107980975323",
		["lockBadgeCheckmarkFill"] = "rbxassetid://125253362602913",
		["lockBadgeClock"] = "rbxassetid://125387425242561",
		["lockBadgeClockFill"] = "rbxassetid://103943585601256",
		["lockBadgeXmark"] = "rbxassetid://89080108534797",
		["lockBadgeXmarkFill"] = "rbxassetid://128829841123231",
		["lockCircle"] = "rbxassetid://104937122562252",
		["lockCircleDotted"] = "rbxassetid://129061462044090",
		["lockCircleFill"] = "rbxassetid://88199476099135",
		["lockDesktopcomputer"] = "rbxassetid://123694402953182",
		["lockDisplay"] = "rbxassetid://107733113122735",
		["lockDoc"] = "rbxassetid://122591748345523",
		["lockDocument"] = "rbxassetid://136441673712336",
		["lockDocumentFill"] = "rbxassetid://80722327719292",
		["lockFill"] = "rbxassetid://113641566747489",
		["lockHeart"] = "rbxassetid://112515510772540",
		["lockHeartFill"] = "rbxassetid://100353400294809",
		["lockIcloud"] = "rbxassetid://115234882168637",
		["lockIcloudFill"] = "rbxassetid://90477192363540",
		["lockIpad"] = "rbxassetid://73607136773648",
		["lockIphone"] = "rbxassetid://102130527102632",
		["lockLaptopcomputer"] = "rbxassetid://128883775448444",
		["lockOpen"] = "rbxassetid://102783678054610",
		["lockOpenApplewatch"] = "rbxassetid://128492872401861",
		["lockOpenDesktopcomputer"] = "rbxassetid://127601575525114",
		["lockOpenDisplay"] = "rbxassetid://117843429515636",
		["lockOpenFill"] = "rbxassetid://126165516505365",
		["lockOpenIpad"] = "rbxassetid://115780599199820",
		["lockOpenIphone"] = "rbxassetid://102480932156704",
		["lockOpenLaptopcomputer"] = "rbxassetid://74819525049953",
		["lockOpenRotation"] = "rbxassetid://109151898406267",
		["lockOpenTrianglebadgeExclamationmark"] = "rbxassetid://103088164308480",
		["lockOpenTrianglebadgeExclamationmarkFill"] = "rbxassetid://130688357894527",
		["lockRectangle"] = "rbxassetid://140203888025279",
		["lockRectangleDashed"] = "rbxassetid://92222544678056",
		["lockRectangleFill"] = "rbxassetid://96253959861246",
		["lockRectangleOnRectangle"] = "rbxassetid://119424922741745",
		["lockRectangleOnRectangleDashed"] = "rbxassetid://89856654852797",
		["lockRectangleOnRectangleFill"] = "rbxassetid://107606810987041",
		["lockRectangleStack"] = "rbxassetid://83653436779481",
		["lockRectangleStackFill"] = "rbxassetid://114142898348233",
		["lockRotation"] = "rbxassetid://94299651317583",
		["lockShield"] = "rbxassetid://117164861385150",
		["lockShieldFill"] = "rbxassetid://103824281733541",
		["lockSlash"] = "rbxassetid://109892378159236",
		["lockSlashFill"] = "rbxassetid://135056397155042",
		["lockSquare"] = "rbxassetid://100512753136328",
		["lockSquareDashed"] = "rbxassetid://95009632896829",
		["lockSquareFill"] = "rbxassetid://131560134146883",
		["lockSquareStack"] = "rbxassetid://83170488776527",
		["lockSquareStackFill"] = "rbxassetid://83676185405981",
		["lockTrianglebadgeExclamationmark"] = "rbxassetid://130478937095272",
		["lockTrianglebadgeExclamationmarkFill"] = "rbxassetid://106705811514881",
		["longTextPageAndPencil"] = "rbxassetid://129681886055539",
		["longTextPageAndPencilFill"] = "rbxassetid://110646299611764",
		["loupe"] = "rbxassetid://136500905165325",
		["lsbButtonAngledbottomHorizontalLeft"] = "rbxassetid://97637835138960",
		["lsbButtonAngledbottomHorizontalLeftFill"] = "rbxassetid://136029832054596",
		["ltButtonRoundedtopHorizontal"] = "rbxassetid://96312958043926",
		["ltButtonRoundedtopHorizontalFill"] = "rbxassetid://127843467436825",
		["ltCircle"] = "rbxassetid://132916592513600",
		["ltCircleFill"] = "rbxassetid://108356683738396",
		["lucide-accessibility"] = "rbxassetid://10709751939",
		["lucide-activity"] = "rbxassetid://10709752035",
		["lucide-air-vent"] = "rbxassetid://10709752131",
		["lucide-airplay"] = "rbxassetid://10709752254",
		["lucide-alarm-check"] = "rbxassetid://10709752405",
		["lucide-alarm-clock"] = "rbxassetid://10709752630",
		["lucide-alarm-clock-off"] = "rbxassetid://10709752508",
		["lucide-alarm-minus"] = "rbxassetid://10709752732",
		["lucide-alarm-plus"] = "rbxassetid://10709752825",
		["lucide-album"] = "rbxassetid://10709752906",
		["lucide-alert-circle"] = "rbxassetid://10709752996",
		["lucide-alert-octagon"] = "rbxassetid://10709753064",
		["lucide-alert-triangle"] = "rbxassetid://10709753149",
		["lucide-align-center"] = "rbxassetid://10709753570",
		["lucide-align-center-horizontal"] = "rbxassetid://10709753272",
		["lucide-align-center-vertical"] = "rbxassetid://10709753421",
		["lucide-align-end-horizontal"] = "rbxassetid://10709753692",
		["lucide-align-end-vertical"] = "rbxassetid://10709753808",
		["lucide-align-horizontal-distribute-center"] = "rbxassetid://10747779791",
		["lucide-align-horizontal-distribute-end"] = "rbxassetid://10747784534",
		["lucide-align-horizontal-distribute-start"] = "rbxassetid://10709754118",
		["lucide-align-horizontal-justify-center"] = "rbxassetid://10709754204",
		["lucide-align-horizontal-justify-end"] = "rbxassetid://10709754317",
		["lucide-align-horizontal-justify-start"] = "rbxassetid://10709754436",
		["lucide-align-horizontal-space-around"] = "rbxassetid://10709754590",
		["lucide-align-horizontal-space-between"] = "rbxassetid://10709754749",
		["lucide-align-justify"] = "rbxassetid://10709759610",
		["lucide-align-left"] = "rbxassetid://10709759764",
		["lucide-align-right"] = "rbxassetid://10709759895",
		["lucide-align-start-horizontal"] = "rbxassetid://10709760051",
		["lucide-align-start-vertical"] = "rbxassetid://10709760244",
		["lucide-align-vertical-distribute-center"] = "rbxassetid://10709760351",
		["lucide-align-vertical-distribute-end"] = "rbxassetid://10709760434",
		["lucide-align-vertical-distribute-start"] = "rbxassetid://10709760612",
		["lucide-align-vertical-justify-center"] = "rbxassetid://10709760814",
		["lucide-align-vertical-justify-end"] = "rbxassetid://10709761003",
		["lucide-align-vertical-justify-start"] = "rbxassetid://10709761176",
		["lucide-align-vertical-space-around"] = "rbxassetid://10709761324",
		["lucide-align-vertical-space-between"] = "rbxassetid://10709761434",
		["lucide-anchor"] = "rbxassetid://10709761530",
		["lucide-angry"] = "rbxassetid://10709761629",
		["lucide-annoyed"] = "rbxassetid://10709761722",
		["lucide-aperture"] = "rbxassetid://10709761813",
		["lucide-apple"] = "rbxassetid://10709761889",
		["lucide-archive"] = "rbxassetid://10709762233",
		["lucide-archive-restore"] = "rbxassetid://10709762058",
		["lucide-armchair"] = "rbxassetid://10709762327",
		["lucide-arrow-big-down"] = "rbxassetid://10747796644",
		["lucide-arrow-big-left"] = "rbxassetid://10709762574",
		["lucide-arrow-big-right"] = "rbxassetid://10709762727",
		["lucide-arrow-big-up"] = "rbxassetid://10709762879",
		["lucide-arrow-down"] = "rbxassetid://10709767827",
		["lucide-arrow-down-circle"] = "rbxassetid://10709763034",
		["lucide-arrow-down-left"] = "rbxassetid://10709767656",
		["lucide-arrow-down-right"] = "rbxassetid://10709767750",
		["lucide-arrow-left"] = "rbxassetid://10709768114",
		["lucide-arrow-left-circle"] = "rbxassetid://10709767936",
		["lucide-arrow-left-right"] = "rbxassetid://10709768019",
		["lucide-arrow-right"] = "rbxassetid://10709768347",
		["lucide-arrow-right-circle"] = "rbxassetid://10709768226",
		["lucide-arrow-up"] = "rbxassetid://10709768939",
		["lucide-arrow-up-circle"] = "rbxassetid://10709768432",
		["lucide-arrow-up-down"] = "rbxassetid://10709768538",
		["lucide-arrow-up-left"] = "rbxassetid://10709768661",
		["lucide-arrow-up-right"] = "rbxassetid://10709768787",
		["lucide-asterisk"] = "rbxassetid://10709769095",
		["lucide-at-sign"] = "rbxassetid://10709769286",
		["lucide-award"] = "rbxassetid://10709769406",
		["lucide-axe"] = "rbxassetid://10709769508",
		["lucide-axis-3d"] = "rbxassetid://10709769598",
		["lucide-baby"] = "rbxassetid://10709769732",
		["lucide-backpack"] = "rbxassetid://10709769841",
		["lucide-baggage-claim"] = "rbxassetid://10709769935",
		["lucide-banana"] = "rbxassetid://10709770005",
		["lucide-banknote"] = "rbxassetid://10709770178",
		["lucide-bar-chart"] = "rbxassetid://10709773755",
		["lucide-bar-chart-2"] = "rbxassetid://10709770317",
		["lucide-bar-chart-3"] = "rbxassetid://10709770431",
		["lucide-bar-chart-4"] = "rbxassetid://10709770560",
		["lucide-bar-chart-horizontal"] = "rbxassetid://10709773669",
		["lucide-barcode"] = "rbxassetid://10747360675",
		["lucide-baseline"] = "rbxassetid://10709773863",
		["lucide-bath"] = "rbxassetid://10709773963",
		["lucide-battery"] = "rbxassetid://10709774640",
		["lucide-battery-charging"] = "rbxassetid://10709774068",
		["lucide-battery-full"] = "rbxassetid://10709774206",
		["lucide-battery-low"] = "rbxassetid://10709774370",
		["lucide-battery-medium"] = "rbxassetid://10709774513",
		["lucide-beaker"] = "rbxassetid://10709774756",
		["lucide-bed"] = "rbxassetid://10709775036",
		["lucide-bed-double"] = "rbxassetid://10709774864",
		["lucide-bed-single"] = "rbxassetid://10709774968",
		["lucide-beer"] = "rbxassetid://10709775167",
		["lucide-bell"] = "rbxassetid://10709775704",
		["lucide-bell-minus"] = "rbxassetid://10709775241",
		["lucide-bell-off"] = "rbxassetid://10709775320",
		["lucide-bell-plus"] = "rbxassetid://10709775448",
		["lucide-bell-ring"] = "rbxassetid://10709775560",
		["lucide-bike"] = "rbxassetid://10709775894",
		["lucide-binary"] = "rbxassetid://10709776050",
		["lucide-bitcoin"] = "rbxassetid://10709776126",
		["lucide-bluetooth"] = "rbxassetid://10709776655",
		["lucide-bluetooth-connected"] = "rbxassetid://10709776240",
		["lucide-bluetooth-off"] = "rbxassetid://10709776344",
		["lucide-bluetooth-searching"] = "rbxassetid://10709776501",
		["lucide-bold"] = "rbxassetid://10747813908",
		["lucide-bomb"] = "rbxassetid://10709781460",
		["lucide-bone"] = "rbxassetid://10709781605",
		["lucide-book"] = "rbxassetid://10709781824",
		["lucide-book-open"] = "rbxassetid://10709781717",
		["lucide-bookmark"] = "rbxassetid://10709782154",
		["lucide-bookmark-minus"] = "rbxassetid://10709781919",
		["lucide-bookmark-plus"] = "rbxassetid://10709782044",
		["lucide-bot"] = "rbxassetid://10709782230",
		["lucide-box"] = "rbxassetid://10709782497",
		["lucide-box-select"] = "rbxassetid://10709782342",
		["lucide-boxes"] = "rbxassetid://10709782582",
		["lucide-briefcase"] = "rbxassetid://10709782662",
		["lucide-brush"] = "rbxassetid://10709782758",
		["lucide-bug"] = "rbxassetid://10709782845",
		["lucide-building"] = "rbxassetid://10709783051",
		["lucide-building-2"] = "rbxassetid://10709782939",
		["lucide-bus"] = "rbxassetid://10709783137",
		["lucide-cake"] = "rbxassetid://10709783217",
		["lucide-calculator"] = "rbxassetid://10709783311",
		["lucide-calendar"] = "rbxassetid://10709789505",
		["lucide-calendar-check"] = "rbxassetid://10709783474",
		["lucide-calendar-check-2"] = "rbxassetid://10709783392",
		["lucide-calendar-clock"] = "rbxassetid://10709783577",
		["lucide-calendar-days"] = "rbxassetid://10709783673",
		["lucide-calendar-heart"] = "rbxassetid://10709783835",
		["lucide-calendar-minus"] = "rbxassetid://10709783959",
		["lucide-calendar-off"] = "rbxassetid://10709788784",
		["lucide-calendar-plus"] = "rbxassetid://10709788937",
		["lucide-calendar-range"] = "rbxassetid://10709789053",
		["lucide-calendar-search"] = "rbxassetid://10709789200",
		["lucide-calendar-x"] = "rbxassetid://10709789407",
		["lucide-calendar-x-2"] = "rbxassetid://10709789329",
		["lucide-camera"] = "rbxassetid://10709789686",
		["lucide-camera-off"] = "rbxassetid://10747822677",
		["lucide-car"] = "rbxassetid://10709789810",
		["lucide-carrot"] = "rbxassetid://10709789960",
		["lucide-cast"] = "rbxassetid://10709790097",
		["lucide-charge"] = "rbxassetid://10709790202",
		["lucide-check"] = "rbxassetid://10709790644",
		["lucide-check-circle"] = "rbxassetid://10709790387",
		["lucide-check-circle-2"] = "rbxassetid://10709790298",
		["lucide-check-square"] = "rbxassetid://10709790537",
		["lucide-chef-hat"] = "rbxassetid://10709790757",
		["lucide-cherry"] = "rbxassetid://10709790875",
		["lucide-chevron-down"] = "rbxassetid://10709790948",
		["lucide-chevron-first"] = "rbxassetid://10709791015",
		["lucide-chevron-last"] = "rbxassetid://10709791130",
		["lucide-chevron-left"] = "rbxassetid://10709791281",
		["lucide-chevron-right"] = "rbxassetid://10709791437",
		["lucide-chevron-up"] = "rbxassetid://10709791523",
		["lucide-chevrons-down"] = "rbxassetid://10709796864",
		["lucide-chevrons-down-up"] = "rbxassetid://10709791632",
		["lucide-chevrons-left"] = "rbxassetid://10709797151",
		["lucide-chevrons-left-right"] = "rbxassetid://10709797006",
		["lucide-chevrons-right"] = "rbxassetid://10709797382",
		["lucide-chevrons-right-left"] = "rbxassetid://10709797274",
		["lucide-chevrons-up"] = "rbxassetid://10709797622",
		["lucide-chevrons-up-down"] = "rbxassetid://10709797508",
		["lucide-chrome"] = "rbxassetid://10709797725",
		["lucide-circle"] = "rbxassetid://10709798174",
		["lucide-circle-dot"] = "rbxassetid://10709797837",
		["lucide-circle-ellipsis"] = "rbxassetid://10709797985",
		["lucide-circle-slashed"] = "rbxassetid://10709798100",
		["lucide-citrus"] = "rbxassetid://10709798276",
		["lucide-clapperboard"] = "rbxassetid://10709798350",
		["lucide-clipboard"] = "rbxassetid://10709799288",
		["lucide-clipboard-check"] = "rbxassetid://10709798443",
		["lucide-clipboard-copy"] = "rbxassetid://10709798574",
		["lucide-clipboard-edit"] = "rbxassetid://10709798682",
		["lucide-clipboard-list"] = "rbxassetid://10709798792",
		["lucide-clipboard-signature"] = "rbxassetid://10709798890",
		["lucide-clipboard-type"] = "rbxassetid://10709798999",
		["lucide-clipboard-x"] = "rbxassetid://10709799124",
		["lucide-clock"] = "rbxassetid://10709805144",
		["lucide-clock-1"] = "rbxassetid://10709799535",
		["lucide-clock-10"] = "rbxassetid://10709799718",
		["lucide-clock-11"] = "rbxassetid://10709799818",
		["lucide-clock-12"] = "rbxassetid://10709799962",
		["lucide-clock-2"] = "rbxassetid://10709803876",
		["lucide-clock-3"] = "rbxassetid://10709803989",
		["lucide-clock-4"] = "rbxassetid://10709804164",
		["lucide-clock-5"] = "rbxassetid://10709804291",
		["lucide-clock-6"] = "rbxassetid://10709804435",
		["lucide-clock-7"] = "rbxassetid://10709804599",
		["lucide-clock-8"] = "rbxassetid://10709804784",
		["lucide-clock-9"] = "rbxassetid://10709804996",
		["lucide-cloud"] = "rbxassetid://10709806740",
		["lucide-cloud-cog"] = "rbxassetid://10709805262",
		["lucide-cloud-drizzle"] = "rbxassetid://10709805371",
		["lucide-cloud-fog"] = "rbxassetid://10709805477",
		["lucide-cloud-hail"] = "rbxassetid://10709805596",
		["lucide-cloud-lightning"] = "rbxassetid://10709805727",
		["lucide-cloud-moon"] = "rbxassetid://10709805942",
		["lucide-cloud-moon-rain"] = "rbxassetid://10709805838",
		["lucide-cloud-off"] = "rbxassetid://10709806060",
		["lucide-cloud-rain"] = "rbxassetid://10709806277",
		["lucide-cloud-rain-wind"] = "rbxassetid://10709806166",
		["lucide-cloud-snow"] = "rbxassetid://10709806374",
		["lucide-cloud-sun"] = "rbxassetid://10709806631",
		["lucide-cloud-sun-rain"] = "rbxassetid://10709806475",
		["lucide-cloudy"] = "rbxassetid://10709806859",
		["lucide-clover"] = "rbxassetid://10709806995",
		["lucide-code"] = "rbxassetid://10709810463",
		["lucide-code-2"] = "rbxassetid://10709807111",
		["lucide-codepen"] = "rbxassetid://10709810534",
		["lucide-codesandbox"] = "rbxassetid://10709810676",
		["lucide-coffee"] = "rbxassetid://10709810814",
		["lucide-cog"] = "rbxassetid://10709810948",
		["lucide-coins"] = "rbxassetid://10709811110",
		["lucide-columns"] = "rbxassetid://10709811261",
		["lucide-command"] = "rbxassetid://10709811365",
		["lucide-compass"] = "rbxassetid://10709811445",
		["lucide-component"] = "rbxassetid://10709811595",
		["lucide-concierge-bell"] = "rbxassetid://10709811706",
		["lucide-connection"] = "rbxassetid://10747361219",
		["lucide-contact"] = "rbxassetid://10709811834",
		["lucide-contrast"] = "rbxassetid://10709811939",
		["lucide-cookie"] = "rbxassetid://10709812067",
		["lucide-copy"] = "rbxassetid://10709812159",
		["lucide-copyleft"] = "rbxassetid://10709812251",
		["lucide-copyright"] = "rbxassetid://10709812311",
		["lucide-corner-down-left"] = "rbxassetid://10709812396",
		["lucide-corner-down-right"] = "rbxassetid://10709812485",
		["lucide-corner-left-down"] = "rbxassetid://10709812632",
		["lucide-corner-left-up"] = "rbxassetid://10709812784",
		["lucide-corner-right-down"] = "rbxassetid://10709812939",
		["lucide-corner-right-up"] = "rbxassetid://10709813094",
		["lucide-corner-up-left"] = "rbxassetid://10709813185",
		["lucide-corner-up-right"] = "rbxassetid://10709813281",
		["lucide-cpu"] = "rbxassetid://10709813383",
		["lucide-croissant"] = "rbxassetid://10709818125",
		["lucide-crop"] = "rbxassetid://10709818245",
		["lucide-cross"] = "rbxassetid://10709818399",
		["lucide-crosshair"] = "rbxassetid://10709818534",
		["lucide-crown"] = "rbxassetid://10709818626",
		["lucide-cup-soda"] = "rbxassetid://10709818763",
		["lucide-curly-braces"] = "rbxassetid://10709818847",
		["lucide-currency"] = "rbxassetid://10709818931",
		["lucide-database"] = "rbxassetid://10709818996",
		["lucide-delete"] = "rbxassetid://10709819059",
		["lucide-diamond"] = "rbxassetid://10709819149",
		["lucide-dice-1"] = "rbxassetid://10709819266",
		["lucide-dice-2"] = "rbxassetid://10709819361",
		["lucide-dice-3"] = "rbxassetid://10709819508",
		["lucide-dice-4"] = "rbxassetid://10709819670",
		["lucide-dice-5"] = "rbxassetid://10709819801",
		["lucide-dice-6"] = "rbxassetid://10709819896",
		["lucide-dices"] = "rbxassetid://10723343321",
		["lucide-diff"] = "rbxassetid://10723343416",
		["lucide-disc"] = "rbxassetid://10723343537",
		["lucide-divide"] = "rbxassetid://10723343805",
		["lucide-divide-circle"] = "rbxassetid://10723343636",
		["lucide-divide-square"] = "rbxassetid://10723343737",
		["lucide-dollar-sign"] = "rbxassetid://10723343958",
		["lucide-download"] = "rbxassetid://10723344270",
		["lucide-download-cloud"] = "rbxassetid://10723344088",
		["lucide-droplet"] = "rbxassetid://10723344432",
		["lucide-droplets"] = "rbxassetid://10734883356",
		["lucide-drumstick"] = "rbxassetid://10723344737",
		["lucide-edit"] = "rbxassetid://10734883598",
		["lucide-edit-2"] = "rbxassetid://10723344885",
		["lucide-edit-3"] = "rbxassetid://10723345088",
		["lucide-egg"] = "rbxassetid://10723345518",
		["lucide-egg-fried"] = "rbxassetid://10723345347",
		["lucide-electricity"] = "rbxassetid://10723345749",
		["lucide-electricity-off"] = "rbxassetid://10723345643",
		["lucide-equal"] = "rbxassetid://10723345990",
		["lucide-equal-not"] = "rbxassetid://10723345866",
		["lucide-eraser"] = "rbxassetid://10723346158",
		["lucide-euro"] = "rbxassetid://10723346372",
		["lucide-expand"] = "rbxassetid://10723346553",
		["lucide-external-link"] = "rbxassetid://10723346684",
		["lucide-eye"] = "rbxassetid://10723346959",
		["lucide-eye-off"] = "rbxassetid://10723346871",
		["lucide-factory"] = "rbxassetid://10723347051",
		["lucide-fan"] = "rbxassetid://10723354359",
		["lucide-fast-forward"] = "rbxassetid://10723354521",
		["lucide-feather"] = "rbxassetid://10723354671",
		["lucide-figma"] = "rbxassetid://10723354801",
		["lucide-file"] = "rbxassetid://10723374641",
		["lucide-file-archive"] = "rbxassetid://10723354921",
		["lucide-file-audio"] = "rbxassetid://10723355148",
		["lucide-file-audio-2"] = "rbxassetid://10723355026",
		["lucide-file-axis-3d"] = "rbxassetid://10723355272",
		["lucide-file-badge"] = "rbxassetid://10723355622",
		["lucide-file-badge-2"] = "rbxassetid://10723355451",
		["lucide-file-bar-chart"] = "rbxassetid://10723355887",
		["lucide-file-bar-chart-2"] = "rbxassetid://10723355746",
		["lucide-file-box"] = "rbxassetid://10723355989",
		["lucide-file-check"] = "rbxassetid://10723356210",
		["lucide-file-check-2"] = "rbxassetid://10723356100",
		["lucide-file-clock"] = "rbxassetid://10723356329",
		["lucide-file-code"] = "rbxassetid://10723356507",
		["lucide-file-cog"] = "rbxassetid://10723356830",
		["lucide-file-cog-2"] = "rbxassetid://10723356676",
		["lucide-file-diff"] = "rbxassetid://10723357039",
		["lucide-file-digit"] = "rbxassetid://10723357151",
		["lucide-file-down"] = "rbxassetid://10723357322",
		["lucide-file-edit"] = "rbxassetid://10723357495",
		["lucide-file-heart"] = "rbxassetid://10723357637",
		["lucide-file-image"] = "rbxassetid://10723357790",
		["lucide-file-input"] = "rbxassetid://10723357933",
		["lucide-file-json"] = "rbxassetid://10723364435",
		["lucide-file-json-2"] = "rbxassetid://10723364361",
		["lucide-file-key"] = "rbxassetid://10723364605",
		["lucide-file-key-2"] = "rbxassetid://10723364515",
		["lucide-file-line-chart"] = "rbxassetid://10723364725",
		["lucide-file-lock"] = "rbxassetid://10723364957",
		["lucide-file-lock-2"] = "rbxassetid://10723364861",
		["lucide-file-minus"] = "rbxassetid://10723365254",
		["lucide-file-minus-2"] = "rbxassetid://10723365086",
		["lucide-file-output"] = "rbxassetid://10723365457",
		["lucide-file-pie-chart"] = "rbxassetid://10723365598",
		["lucide-file-plus"] = "rbxassetid://10723365877",
		["lucide-file-plus-2"] = "rbxassetid://10723365766",
		["lucide-file-question"] = "rbxassetid://10723365987",
		["lucide-file-scan"] = "rbxassetid://10723366167",
		["lucide-file-search"] = "rbxassetid://10723366550",
		["lucide-file-search-2"] = "rbxassetid://10723366340",
		["lucide-file-signature"] = "rbxassetid://10723366741",
		["lucide-file-spreadsheet"] = "rbxassetid://10723366962",
		["lucide-file-symlink"] = "rbxassetid://10723367098",
		["lucide-file-terminal"] = "rbxassetid://10723367244",
		["lucide-file-text"] = "rbxassetid://10723367380",
		["lucide-file-type"] = "rbxassetid://10723367606",
		["lucide-file-type-2"] = "rbxassetid://10723367509",
		["lucide-file-up"] = "rbxassetid://10723367734",
		["lucide-file-video"] = "rbxassetid://10723373884",
		["lucide-file-video-2"] = "rbxassetid://10723367834",
		["lucide-file-volume"] = "rbxassetid://10723374172",
		["lucide-file-volume-2"] = "rbxassetid://10723374030",
		["lucide-file-warning"] = "rbxassetid://10723374276",
		["lucide-file-x"] = "rbxassetid://10723374544",
		["lucide-file-x-2"] = "rbxassetid://10723374378",
		["lucide-files"] = "rbxassetid://10723374759",
		["lucide-film"] = "rbxassetid://10723374981",
		["lucide-filter"] = "rbxassetid://10723375128",
		["lucide-fingerprint"] = "rbxassetid://10723375250",
		["lucide-flag"] = "rbxassetid://10723375890",
		["lucide-flag-off"] = "rbxassetid://10723375443",
		["lucide-flag-triangle-left"] = "rbxassetid://10723375608",
		["lucide-flag-triangle-right"] = "rbxassetid://10723375727",
		["lucide-flame"] = "rbxassetid://10723376114",
		["lucide-flashlight"] = "rbxassetid://10723376471",
		["lucide-flashlight-off"] = "rbxassetid://10723376365",
		["lucide-flask-conical"] = "rbxassetid://10734883986",
		["lucide-flask-round"] = "rbxassetid://10723376614",
		["lucide-flip-horizontal"] = "rbxassetid://10723376884",
		["lucide-flip-horizontal-2"] = "rbxassetid://10723376745",
		["lucide-flip-vertical"] = "rbxassetid://10723377138",
		["lucide-flip-vertical-2"] = "rbxassetid://10723377026",
		["lucide-flower"] = "rbxassetid://10747830374",
		["lucide-flower-2"] = "rbxassetid://10723377305",
		["lucide-focus"] = "rbxassetid://10723377537",
		["lucide-folder"] = "rbxassetid://10723387563",
		["lucide-folder-archive"] = "rbxassetid://10723384478",
		["lucide-folder-check"] = "rbxassetid://10723384605",
		["lucide-folder-clock"] = "rbxassetid://10723384731",
		["lucide-folder-closed"] = "rbxassetid://10723384893",
		["lucide-folder-cog"] = "rbxassetid://10723385213",
		["lucide-folder-cog-2"] = "rbxassetid://10723385036",
		["lucide-folder-down"] = "rbxassetid://10723385338",
		["lucide-folder-edit"] = "rbxassetid://10723385445",
		["lucide-folder-heart"] = "rbxassetid://10723385545",
		["lucide-folder-input"] = "rbxassetid://10723385721",
		["lucide-folder-key"] = "rbxassetid://10723385848",
		["lucide-folder-lock"] = "rbxassetid://10723386005",
		["lucide-folder-minus"] = "rbxassetid://10723386127",
		["lucide-folder-open"] = "rbxassetid://10723386277",
		["lucide-folder-output"] = "rbxassetid://10723386386",
		["lucide-folder-plus"] = "rbxassetid://10723386531",
		["lucide-folder-search"] = "rbxassetid://10723386787",
		["lucide-folder-search-2"] = "rbxassetid://10723386674",
		["lucide-folder-symlink"] = "rbxassetid://10723386930",
		["lucide-folder-tree"] = "rbxassetid://10723387085",
		["lucide-folder-up"] = "rbxassetid://10723387265",
		["lucide-folder-x"] = "rbxassetid://10723387448",
		["lucide-folders"] = "rbxassetid://10723387721",
		["lucide-form-input"] = "rbxassetid://10723387841",
		["lucide-forward"] = "rbxassetid://10723388016",
		["lucide-frame"] = "rbxassetid://10723394389",
		["lucide-framer"] = "rbxassetid://10723394565",
		["lucide-frown"] = "rbxassetid://10723394681",
		["lucide-fuel"] = "rbxassetid://10723394846",
		["lucide-function-square"] = "rbxassetid://10723395041",
		["lucide-gamepad"] = "rbxassetid://10723395457",
		["lucide-gamepad-2"] = "rbxassetid://10723395215",
		["lucide-gauge"] = "rbxassetid://10723395708",
		["lucide-gavel"] = "rbxassetid://10723395896",
		["lucide-gem"] = "rbxassetid://10723396000",
		["lucide-ghost"] = "rbxassetid://10723396107",
		["lucide-gift"] = "rbxassetid://10723396402",
		["lucide-gift-card"] = "rbxassetid://10723396225",
		["lucide-git-branch"] = "rbxassetid://10723396676",
		["lucide-git-branch-plus"] = "rbxassetid://10723396542",
		["lucide-git-commit"] = "rbxassetid://10723396812",
		["lucide-git-compare"] = "rbxassetid://10723396954",
		["lucide-git-fork"] = "rbxassetid://10723397049",
		["lucide-git-merge"] = "rbxassetid://10723397165",
		["lucide-git-pull-request"] = "rbxassetid://10723397431",
		["lucide-git-pull-request-closed"] = "rbxassetid://10723397268",
		["lucide-git-pull-request-draft"] = "rbxassetid://10734884302",
		["lucide-glass"] = "rbxassetid://10723397788",
		["lucide-glass-2"] = "rbxassetid://10723397529",
		["lucide-glass-water"] = "rbxassetid://10723397678",
		["lucide-glasses"] = "rbxassetid://10723397895",
		["lucide-globe"] = "rbxassetid://10723404337",
		["lucide-globe-2"] = "rbxassetid://10723398002",
		["lucide-grab"] = "rbxassetid://10723404472",
		["lucide-graduation-cap"] = "rbxassetid://10723404691",
		["lucide-grape"] = "rbxassetid://10723404822",
		["lucide-grid"] = "rbxassetid://10723404936",
		["lucide-grip-horizontal"] = "rbxassetid://10723405089",
		["lucide-grip-vertical"] = "rbxassetid://10723405236",
		["lucide-hammer"] = "rbxassetid://10723405360",
		["lucide-hand"] = "rbxassetid://10723405649",
		["lucide-hand-metal"] = "rbxassetid://10723405508",
		["lucide-hard-drive"] = "rbxassetid://10723405749",
		["lucide-hard-hat"] = "rbxassetid://10723405859",
		["lucide-hash"] = "rbxassetid://10723405975",
		["lucide-haze"] = "rbxassetid://10723406078",
		["lucide-headphones"] = "rbxassetid://10723406165",
		["lucide-heart"] = "rbxassetid://10723406885",
		["lucide-heart-crack"] = "rbxassetid://10723406299",
		["lucide-heart-handshake"] = "rbxassetid://10723406480",
		["lucide-heart-off"] = "rbxassetid://10723406662",
		["lucide-heart-pulse"] = "rbxassetid://10723406795",
		["lucide-help-circle"] = "rbxassetid://10723406988",
		["lucide-hexagon"] = "rbxassetid://10723407092",
		["lucide-highlighter"] = "rbxassetid://10723407192",
		["lucide-history"] = "rbxassetid://10723407335",
		["lucide-home"] = "rbxassetid://10723407389",
		["lucide-hourglass"] = "rbxassetid://10723407498",
		["lucide-ice-cream"] = "rbxassetid://10723414308",
		["lucide-image"] = "rbxassetid://10723415040",
		["lucide-image-minus"] = "rbxassetid://10723414487",
		["lucide-image-off"] = "rbxassetid://10723414677",
		["lucide-image-plus"] = "rbxassetid://10723414827",
		["lucide-import"] = "rbxassetid://10723415205",
		["lucide-inbox"] = "rbxassetid://10723415335",
		["lucide-indent"] = "rbxassetid://10723415494",
		["lucide-indian-rupee"] = "rbxassetid://10723415642",
		["lucide-infinity"] = "rbxassetid://10723415766",
		["lucide-info"] = "rbxassetid://10723415903",
		["lucide-inspect"] = "rbxassetid://10723416057",
		["lucide-italic"] = "rbxassetid://10723416195",
		["lucide-japanese-yen"] = "rbxassetid://10723416363",
		["lucide-joystick"] = "rbxassetid://10723416527",
		["lucide-key"] = "rbxassetid://10723416652",
		["lucide-keyboard"] = "rbxassetid://10723416765",
		["lucide-lamp"] = "rbxassetid://10723417513",
		["lucide-lamp-ceiling"] = "rbxassetid://10723416922",
		["lucide-lamp-desk"] = "rbxassetid://10723417016",
		["lucide-lamp-floor"] = "rbxassetid://10723417131",
		["lucide-lamp-wall-down"] = "rbxassetid://10723417240",
		["lucide-lamp-wall-up"] = "rbxassetid://10723417356",
		["lucide-landmark"] = "rbxassetid://10723417608",
		["lucide-languages"] = "rbxassetid://10723417703",
		["lucide-laptop"] = "rbxassetid://10723423881",
		["lucide-laptop-2"] = "rbxassetid://10723417797",
		["lucide-lasso"] = "rbxassetid://10723424235",
		["lucide-lasso-select"] = "rbxassetid://10723424058",
		["lucide-laugh"] = "rbxassetid://10723424372",
		["lucide-layers"] = "rbxassetid://10723424505",
		["lucide-layout"] = "rbxassetid://10723425376",
		["lucide-layout-dashboard"] = "rbxassetid://10723424646",
		["lucide-layout-grid"] = "rbxassetid://10723424838",
		["lucide-layout-list"] = "rbxassetid://10723424963",
		["lucide-layout-template"] = "rbxassetid://10723425187",
		["lucide-leaf"] = "rbxassetid://10723425539",
		["lucide-library"] = "rbxassetid://10723425615",
		["lucide-life-buoy"] = "rbxassetid://10723425685",
		["lucide-lightbulb"] = "rbxassetid://10723425852",
		["lucide-lightbulb-off"] = "rbxassetid://10723425762",
		["lucide-line-chart"] = "rbxassetid://10723426393",
		["lucide-link"] = "rbxassetid://10723426722",
		["lucide-link-2"] = "rbxassetid://10723426595",
		["lucide-link-2-off"] = "rbxassetid://10723426513",
		["lucide-list"] = "rbxassetid://10723433811",
		["lucide-list-checks"] = "rbxassetid://10734884548",
		["lucide-list-end"] = "rbxassetid://10723426886",
		["lucide-list-minus"] = "rbxassetid://10723426986",
		["lucide-list-music"] = "rbxassetid://10723427081",
		["lucide-list-ordered"] = "rbxassetid://10723427199",
		["lucide-list-plus"] = "rbxassetid://10723427334",
		["lucide-list-start"] = "rbxassetid://10723427494",
		["lucide-list-video"] = "rbxassetid://10723427619",
		["lucide-list-x"] = "rbxassetid://10723433655",
		["lucide-loader"] = "rbxassetid://10723434070",
		["lucide-loader-2"] = "rbxassetid://10723433935",
		["lucide-locate"] = "rbxassetid://10723434557",
		["lucide-locate-fixed"] = "rbxassetid://10723434236",
		["lucide-locate-off"] = "rbxassetid://10723434379",
		["lucide-lock"] = "rbxassetid://10723434711",
		["lucide-log-in"] = "rbxassetid://10723434830",
		["lucide-log-out"] = "rbxassetid://10723434906",
		["lucide-luggage"] = "rbxassetid://10723434993",
		["lucide-magnet"] = "rbxassetid://10723435069",
		["lucide-mail"] = "rbxassetid://10734885430",
		["lucide-mail-check"] = "rbxassetid://10723435182",
		["lucide-mail-minus"] = "rbxassetid://10723435261",
		["lucide-mail-open"] = "rbxassetid://10723435342",
		["lucide-mail-plus"] = "rbxassetid://10723435443",
		["lucide-mail-question"] = "rbxassetid://10723435515",
		["lucide-mail-search"] = "rbxassetid://10734884739",
		["lucide-mail-warning"] = "rbxassetid://10734885015",
		["lucide-mail-x"] = "rbxassetid://10734885247",
		["lucide-mails"] = "rbxassetid://10734885614",
		["lucide-map"] = "rbxassetid://10734886202",
		["lucide-map-pin"] = "rbxassetid://10734886004",
		["lucide-map-pin-off"] = "rbxassetid://10734885803",
		["lucide-maximize"] = "rbxassetid://10734886735",
		["lucide-maximize-2"] = "rbxassetid://10734886496",
		["lucide-medal"] = "rbxassetid://10734887072",
		["lucide-megaphone"] = "rbxassetid://10734887454",
		["lucide-megaphone-off"] = "rbxassetid://10734887311",
		["lucide-meh"] = "rbxassetid://10734887603",
		["lucide-menu"] = "rbxassetid://10734887784",
		["lucide-message-circle"] = "rbxassetid://10734888000",
		["lucide-message-square"] = "rbxassetid://10734888228",
		["lucide-mic"] = "rbxassetid://10734888864",
		["lucide-mic-2"] = "rbxassetid://10734888430",
		["lucide-mic-off"] = "rbxassetid://10734888646",
		["lucide-microscope"] = "rbxassetid://10734889106",
		["lucide-microwave"] = "rbxassetid://10734895076",
		["lucide-milestone"] = "rbxassetid://10734895310",
		["lucide-minimize"] = "rbxassetid://10734895698",
		["lucide-minimize-2"] = "rbxassetid://10734895530",
		["lucide-minus"] = "rbxassetid://10734896206",
		["lucide-minus-circle"] = "rbxassetid://10734895856",
		["lucide-minus-square"] = "rbxassetid://10734896029",
		["lucide-monitor"] = "rbxassetid://10734896881",
		["lucide-monitor-off"] = "rbxassetid://10734896360",
		["lucide-monitor-speaker"] = "rbxassetid://10734896512",
		["lucide-moon"] = "rbxassetid://10734897102",
		["lucide-more-horizontal"] = "rbxassetid://10734897250",
		["lucide-more-vertical"] = "rbxassetid://10734897387",
		["lucide-mountain"] = "rbxassetid://10734897956",
		["lucide-mountain-snow"] = "rbxassetid://10734897665",
		["lucide-mouse"] = "rbxassetid://10734898592",
		["lucide-mouse-pointer"] = "rbxassetid://10734898476",
		["lucide-mouse-pointer-2"] = "rbxassetid://10734898194",
		["lucide-mouse-pointer-click"] = "rbxassetid://10734898355",
		["lucide-move"] = "rbxassetid://10734900011",
		["lucide-move-3d"] = "rbxassetid://10734898756",
		["lucide-move-diagonal"] = "rbxassetid://10734899164",
		["lucide-move-diagonal-2"] = "rbxassetid://10734898934",
		["lucide-move-horizontal"] = "rbxassetid://10734899414",
		["lucide-move-vertical"] = "rbxassetid://10734899821",
		["lucide-music"] = "rbxassetid://10734905958",
		["lucide-music-2"] = "rbxassetid://10734900215",
		["lucide-music-3"] = "rbxassetid://10734905665",
		["lucide-music-4"] = "rbxassetid://10734905823",
		["lucide-navigation"] = "rbxassetid://10734906744",
		["lucide-navigation-2"] = "rbxassetid://10734906332",
		["lucide-navigation-2-off"] = "rbxassetid://10734906144",
		["lucide-navigation-off"] = "rbxassetid://10734906580",
		["lucide-network"] = "rbxassetid://10734906975",
		["lucide-newspaper"] = "rbxassetid://10734907168",
		["lucide-octagon"] = "rbxassetid://10734907361",
		["lucide-option"] = "rbxassetid://10734907649",
		["lucide-outdent"] = "rbxassetid://10734907933",
		["lucide-package"] = "rbxassetid://10734909540",
		["lucide-package-2"] = "rbxassetid://10734908151",
		["lucide-package-check"] = "rbxassetid://10734908384",
		["lucide-package-minus"] = "rbxassetid://10734908626",
		["lucide-package-open"] = "rbxassetid://10734908793",
		["lucide-package-plus"] = "rbxassetid://10734909016",
		["lucide-package-search"] = "rbxassetid://10734909196",
		["lucide-package-x"] = "rbxassetid://10734909375",
		["lucide-paint-bucket"] = "rbxassetid://10734909847",
		["lucide-paintbrush"] = "rbxassetid://10734910187",
		["lucide-paintbrush-2"] = "rbxassetid://10734910030",
		["lucide-palette"] = "rbxassetid://10734910430",
		["lucide-palmtree"] = "rbxassetid://10734910680",
		["lucide-paperclip"] = "rbxassetid://10734910927",
		["lucide-party-popper"] = "rbxassetid://10734918735",
		["lucide-pause"] = "rbxassetid://10734919336",
		["lucide-pause-circle"] = "rbxassetid://10735024209",
		["lucide-pause-octagon"] = "rbxassetid://10734919143",
		["lucide-pen-tool"] = "rbxassetid://10734919503",
		["lucide-pencil"] = "rbxassetid://10734919691",
		["lucide-percent"] = "rbxassetid://10734919919",
		["lucide-person-standing"] = "rbxassetid://10734920149",
		["lucide-phone"] = "rbxassetid://10734921524",
		["lucide-phone-call"] = "rbxassetid://10734920305",
		["lucide-phone-forwarded"] = "rbxassetid://10734920508",
		["lucide-phone-incoming"] = "rbxassetid://10734920694",
		["lucide-phone-missed"] = "rbxassetid://10734920845",
		["lucide-phone-off"] = "rbxassetid://10734921077",
		["lucide-phone-outgoing"] = "rbxassetid://10734921288",
		["lucide-pie-chart"] = "rbxassetid://10734921727",
		["lucide-piggy-bank"] = "rbxassetid://10734921935",
		["lucide-pin"] = "rbxassetid://10734922324",
		["lucide-pin-off"] = "rbxassetid://10734922180",
		["lucide-pipette"] = "rbxassetid://10734922497",
		["lucide-pizza"] = "rbxassetid://10734922774",
		["lucide-plane"] = "rbxassetid://10734922971",
		["lucide-play"] = "rbxassetid://10734923549",
		["lucide-play-circle"] = "rbxassetid://10734923214",
		["lucide-plus"] = "rbxassetid://10734924532",
		["lucide-plus-circle"] = "rbxassetid://10734923868",
		["lucide-plus-square"] = "rbxassetid://10734924219",
		["lucide-podcast"] = "rbxassetid://10734929553",
		["lucide-pointer"] = "rbxassetid://10734929723",
		["lucide-pound-sterling"] = "rbxassetid://10734929981",
		["lucide-power"] = "rbxassetid://10734930466",
		["lucide-power-off"] = "rbxassetid://10734930257",
		["lucide-printer"] = "rbxassetid://10734930632",
		["lucide-puzzle"] = "rbxassetid://10734930886",
		["lucide-quote"] = "rbxassetid://10734931234",
		["lucide-radio"] = "rbxassetid://10734931596",
		["lucide-radio-receiver"] = "rbxassetid://10734931402",
		["lucide-rectangle-horizontal"] = "rbxassetid://10734931777",
		["lucide-rectangle-vertical"] = "rbxassetid://10734932081",
		["lucide-recycle"] = "rbxassetid://10734932295",
		["lucide-redo"] = "rbxassetid://10734932822",
		["lucide-redo-2"] = "rbxassetid://10734932586",
		["lucide-refresh-ccw"] = "rbxassetid://10734933056",
		["lucide-refresh-cw"] = "rbxassetid://10734933222",
		["lucide-refrigerator"] = "rbxassetid://10734933465",
		["lucide-regex"] = "rbxassetid://10734933655",
		["lucide-repeat"] = "rbxassetid://10734933966",
		["lucide-repeat-1"] = "rbxassetid://10734933826",
		["lucide-reply"] = "rbxassetid://10734934252",
		["lucide-reply-all"] = "rbxassetid://10734934132",
		["lucide-rewind"] = "rbxassetid://10734934347",
		["lucide-rocket"] = "rbxassetid://10734934585",
		["lucide-rocking-chair"] = "rbxassetid://10734939942",
		["lucide-rotate-3d"] = "rbxassetid://10734940107",
		["lucide-rotate-ccw"] = "rbxassetid://10734940376",
		["lucide-rotate-cw"] = "rbxassetid://10734940654",
		["lucide-rss"] = "rbxassetid://10734940825",
		["lucide-ruler"] = "rbxassetid://10734941018",
		["lucide-russian-ruble"] = "rbxassetid://10734941199",
		["lucide-sailboat"] = "rbxassetid://10734941354",
		["lucide-save"] = "rbxassetid://10734941499",
		["lucide-scale"] = "rbxassetid://10734941912",
		["lucide-scale-3d"] = "rbxassetid://10734941739",
		["lucide-scaling"] = "rbxassetid://10734942072",
		["lucide-scan"] = "rbxassetid://10734942565",
		["lucide-scan-face"] = "rbxassetid://10734942198",
		["lucide-scan-line"] = "rbxassetid://10734942351",
		["lucide-scissors"] = "rbxassetid://10734942778",
		["lucide-screen-share"] = "rbxassetid://10734943193",
		["lucide-screen-share-off"] = "rbxassetid://10734942967",
		["lucide-scroll"] = "rbxassetid://10734943448",
		["lucide-search"] = "rbxassetid://10734943674",
		["lucide-send"] = "rbxassetid://10734943902",
		["lucide-separator-horizontal"] = "rbxassetid://10734944115",
		["lucide-separator-vertical"] = "rbxassetid://10734944326",
		["lucide-server"] = "rbxassetid://10734949856",
		["lucide-server-cog"] = "rbxassetid://10734944444",
		["lucide-server-crash"] = "rbxassetid://10734944554",
		["lucide-server-off"] = "rbxassetid://10734944668",
		["lucide-settings"] = "rbxassetid://10734950309",
		["lucide-settings-2"] = "rbxassetid://10734950020",
		["lucide-share"] = "rbxassetid://10734950813",
		["lucide-share-2"] = "rbxassetid://10734950553",
		["lucide-sheet"] = "rbxassetid://10734951038",
		["lucide-shield"] = "rbxassetid://10734951847",
		["lucide-shield-alert"] = "rbxassetid://10734951173",
		["lucide-shield-check"] = "rbxassetid://10734951367",
		["lucide-shield-close"] = "rbxassetid://10734951535",
		["lucide-shield-off"] = "rbxassetid://10734951684",
		["lucide-shirt"] = "rbxassetid://10734952036",
		["lucide-shopping-bag"] = "rbxassetid://10734952273",
		["lucide-shopping-cart"] = "rbxassetid://10734952479",
		["lucide-shovel"] = "rbxassetid://10734952773",
		["lucide-shower-head"] = "rbxassetid://10734952942",
		["lucide-shrink"] = "rbxassetid://10734953073",
		["lucide-shrub"] = "rbxassetid://10734953241",
		["lucide-shuffle"] = "rbxassetid://10734953451",
		["lucide-sidebar"] = "rbxassetid://10734954301",
		["lucide-sidebar-close"] = "rbxassetid://10734953715",
		["lucide-sidebar-open"] = "rbxassetid://10734954000",
		["lucide-sigma"] = "rbxassetid://10734954538",
		["lucide-signal"] = "rbxassetid://10734961133",
		["lucide-signal-high"] = "rbxassetid://10734954807",
		["lucide-signal-low"] = "rbxassetid://10734955080",
		["lucide-signal-medium"] = "rbxassetid://10734955336",
		["lucide-signal-zero"] = "rbxassetid://10734960878",
		["lucide-siren"] = "rbxassetid://10734961284",
		["lucide-skip-back"] = "rbxassetid://10734961526",
		["lucide-skip-forward"] = "rbxassetid://10734961809",
		["lucide-skull"] = "rbxassetid://10734962068",
		["lucide-slack"] = "rbxassetid://10734962339",
		["lucide-slash"] = "rbxassetid://10734962600",
		["lucide-slice"] = "rbxassetid://10734963024",
		["lucide-sliders"] = "rbxassetid://10734963400",
		["lucide-sliders-horizontal"] = "rbxassetid://10734963191",
		["lucide-smartphone"] = "rbxassetid://10734963940",
		["lucide-smartphone-charging"] = "rbxassetid://10734963671",
		["lucide-smile"] = "rbxassetid://10734964441",
		["lucide-smile-plus"] = "rbxassetid://10734964188",
		["lucide-snowflake"] = "rbxassetid://10734964600",
		["lucide-sofa"] = "rbxassetid://10734964852",
		["lucide-sort-asc"] = "rbxassetid://10734965115",
		["lucide-sort-desc"] = "rbxassetid://10734965287",
		["lucide-speaker"] = "rbxassetid://10734965419",
		["lucide-sprout"] = "rbxassetid://10734965572",
		["lucide-square"] = "rbxassetid://10734965702",
		["lucide-star"] = "rbxassetid://10734966248",
		["lucide-star-half"] = "rbxassetid://10734965897",
		["lucide-star-off"] = "rbxassetid://10734966097",
		["lucide-stethoscope"] = "rbxassetid://10734966384",
		["lucide-sticker"] = "rbxassetid://10734972234",
		["lucide-sticky-note"] = "rbxassetid://10734972463",
		["lucide-stop-circle"] = "rbxassetid://10734972621",
		["lucide-stretch-horizontal"] = "rbxassetid://10734972862",
		["lucide-stretch-vertical"] = "rbxassetid://10734973130",
		["lucide-strikethrough"] = "rbxassetid://10734973290",
		["lucide-subscript"] = "rbxassetid://10734973457",
		["lucide-sun"] = "rbxassetid://10734974297",
		["lucide-sun-dim"] = "rbxassetid://10734973645",
		["lucide-sun-medium"] = "rbxassetid://10734973778",
		["lucide-sun-moon"] = "rbxassetid://10734973999",
		["lucide-sun-snow"] = "rbxassetid://10734974130",
		["lucide-sunrise"] = "rbxassetid://10734974522",
		["lucide-sunset"] = "rbxassetid://10734974689",
		["lucide-superscript"] = "rbxassetid://10734974850",
		["lucide-swiss-franc"] = "rbxassetid://10734975024",
		["lucide-switch-camera"] = "rbxassetid://10734975214",
		["lucide-sword"] = "rbxassetid://10734975486",
		["lucide-swords"] = "rbxassetid://10734975692",
		["lucide-syringe"] = "rbxassetid://10734975932",
		["lucide-table"] = "rbxassetid://10734976230",
		["lucide-table-2"] = "rbxassetid://10734976097",
		["lucide-tablet"] = "rbxassetid://10734976394",
		["lucide-tag"] = "rbxassetid://10734976528",
		["lucide-tags"] = "rbxassetid://10734976739",
		["lucide-target"] = "rbxassetid://10734977012",
		["lucide-tent"] = "rbxassetid://10734981750",
		["lucide-terminal"] = "rbxassetid://10734982144",
		["lucide-terminal-square"] = "rbxassetid://10734981995",
		["lucide-text-cursor"] = "rbxassetid://10734982395",
		["lucide-text-cursor-input"] = "rbxassetid://10734982297",
		["lucide-thermometer"] = "rbxassetid://10734983134",
		["lucide-thermometer-snowflake"] = "rbxassetid://10734982571",
		["lucide-thermometer-sun"] = "rbxassetid://10734982771",
		["lucide-thumbs-down"] = "rbxassetid://10734983359",
		["lucide-thumbs-up"] = "rbxassetid://10734983629",
		["lucide-ticket"] = "rbxassetid://10734983868",
		["lucide-timer"] = "rbxassetid://10734984606",
		["lucide-timer-off"] = "rbxassetid://10734984138",
		["lucide-timer-reset"] = "rbxassetid://10734984355",
		["lucide-toggle-left"] = "rbxassetid://10734984834",
		["lucide-toggle-right"] = "rbxassetid://10734985040",
		["lucide-tornado"] = "rbxassetid://10734985247",
		["lucide-toy-brick"] = "rbxassetid://10747361919",
		["lucide-train"] = "rbxassetid://10747362105",
		["lucide-trash"] = "rbxassetid://10747362393",
		["lucide-trash-2"] = "rbxassetid://10747362241",
		["lucide-tree-deciduous"] = "rbxassetid://10747362534",
		["lucide-tree-pine"] = "rbxassetid://10747362748",
		["lucide-trees"] = "rbxassetid://10747363016",
		["lucide-trending-down"] = "rbxassetid://10747363205",
		["lucide-trending-up"] = "rbxassetid://10747363465",
		["lucide-triangle"] = "rbxassetid://10747363621",
		["lucide-trophy"] = "rbxassetid://10747363809",
		["lucide-truck"] = "rbxassetid://10747364031",
		["lucide-tv"] = "rbxassetid://10747364593",
		["lucide-tv-2"] = "rbxassetid://10747364302",
		["lucide-type"] = "rbxassetid://10747364761",
		["lucide-umbrella"] = "rbxassetid://10747364971",
		["lucide-underline"] = "rbxassetid://10747365191",
		["lucide-undo"] = "rbxassetid://10747365484",
		["lucide-undo-2"] = "rbxassetid://10747365359",
		["lucide-unlink"] = "rbxassetid://10747365771",
		["lucide-unlink-2"] = "rbxassetid://10747397871",
		["lucide-unlock"] = "rbxassetid://10747366027",
		["lucide-upload"] = "rbxassetid://10747366434",
		["lucide-upload-cloud"] = "rbxassetid://10747366266",
		["lucide-usb"] = "rbxassetid://10747366606",
		["lucide-user"] = "rbxassetid://10747373176",
		["lucide-user-check"] = "rbxassetid://10747371901",
		["lucide-user-cog"] = "rbxassetid://10747372167",
		["lucide-user-minus"] = "rbxassetid://10747372346",
		["lucide-user-plus"] = "rbxassetid://10747372702",
		["lucide-user-x"] = "rbxassetid://10747372992",
		["lucide-users"] = "rbxassetid://10747373426",
		["lucide-utensils"] = "rbxassetid://10747373821",
		["lucide-utensils-crossed"] = "rbxassetid://10747373629",
		["lucide-venetian-mask"] = "rbxassetid://10747374003",
		["lucide-verified"] = "rbxassetid://10747374131",
		["lucide-vibrate"] = "rbxassetid://10747374489",
		["lucide-vibrate-off"] = "rbxassetid://10747374269",
		["lucide-video"] = "rbxassetid://10747374938",
		["lucide-video-off"] = "rbxassetid://10747374721",
		["lucide-view"] = "rbxassetid://10747375132",
		["lucide-voicemail"] = "rbxassetid://10747375281",
		["lucide-volume"] = "rbxassetid://10747376008",
		["lucide-volume-1"] = "rbxassetid://10747375450",
		["lucide-volume-2"] = "rbxassetid://10747375679",
		["lucide-volume-x"] = "rbxassetid://10747375880",
		["lucide-wallet"] = "rbxassetid://10747376205",
		["lucide-wand"] = "rbxassetid://10747376565",
		["lucide-wand-2"] = "rbxassetid://10747376349",
		["lucide-watch"] = "rbxassetid://10747376722",
		["lucide-waves"] = "rbxassetid://10747376931",
		["lucide-webcam"] = "rbxassetid://10747381992",
		["lucide-wifi"] = "rbxassetid://10747382504",
		["lucide-wifi-off"] = "rbxassetid://10747382268",
		["lucide-wind"] = "rbxassetid://10747382750",
		["lucide-wrap-text"] = "rbxassetid://10747383065",
		["lucide-wrench"] = "rbxassetid://10747383470",
		["lucide-x"] = "rbxassetid://10747384394",
		["lucide-x-circle"] = "rbxassetid://10747383819",
		["lucide-x-octagon"] = "rbxassetid://10747384037",
		["lucide-x-square"] = "rbxassetid://10747384217",
		["lucide-zoom-in"] = "rbxassetid://10747384552",
		["lucide-zoom-out"] = "rbxassetid://10747384679",
		["lungs"] = "rbxassetid://117606081876003",
		["lungsFill"] = "rbxassetid://140685394378840",
		["m1ButtonHorizontal"] = "rbxassetid://117446058381458",
		["m1ButtonHorizontalFill"] = "rbxassetid://136281737177063",
		["m2ButtonHorizontal"] = "rbxassetid://119180376696999",
		["m2ButtonHorizontalFill"] = "rbxassetid://91002798049706",
		["m3ButtonHorizontal"] = "rbxassetid://113743093040871",
		["m3ButtonHorizontalFill"] = "rbxassetid://115674075172130",
		["m4ButtonHorizontal"] = "rbxassetid://81579669296004",
		["m4ButtonHorizontalFill"] = "rbxassetid://107318562519231",
		["mCircle"] = "rbxassetid://116476710361493",
		["mCircleFill"] = "rbxassetid://89150182712210",
		["mSquare"] = "rbxassetid://105213421328907",
		["mSquareFill"] = "rbxassetid://100315327640869",
		["macbook"] = "rbxassetid://107619424561359",
		["macbookAndApplewatch"] = "rbxassetid://134730538343771",
		["macbookAndIpad"] = "rbxassetid://84294510781873",
		["macbookAndIphone"] = "rbxassetid://113315563711474",
		["macbookAndIpod"] = "rbxassetid://104381697175744",
		["macbookAndVisionPro"] = "rbxassetid://129796583480947",
		["macbookAndVisionpro"] = "rbxassetid://127278593229556",
		["macbookBadgeCheckmark"] = "rbxassetid://137440139904870",
		["macbookBadgeExclamationmark"] = "rbxassetid://85004643818160",
		["macbookBadgeShieldCheckmark"] = "rbxassetid://88995389590679",
		["macbookGen1"] = "rbxassetid://74836101201182",
		["macbookGen1Sizes"] = "rbxassetid://112015951125344",
		["macbookGen2"] = "rbxassetid://112929584796976",
		["macbookGen2Sizes"] = "rbxassetid://72432237281471",
		["macbookSizes"] = "rbxassetid://107797400966607",
		["macbookSlash"] = "rbxassetid://88363794341187",
		["macbookTrianglebadgeExclamationmark"] = "rbxassetid://98986359944726",
		["macmini"] = "rbxassetid://125932491030705",
		["macminiBadgeCheckmark"] = "rbxassetid://124390002270280",
		["macminiBadgeCheckmarkFill"] = "rbxassetid://134379510662161",
		["macminiFill"] = "rbxassetid://111771453982507",
		["macminiGen2"] = "rbxassetid://124604325683137",
		["macminiGen2Fill"] = "rbxassetid://138242624341969",
		["macminiGen3"] = "rbxassetid://136203836384692",
		["macminiGen3Fill"] = "rbxassetid://108766825519262",
		["macproGen1"] = "rbxassetid://113873630917668",
		["macproGen1Fill"] = "rbxassetid://123589284967809",
		["macproGen2"] = "rbxassetid://94400511740550",
		["macproGen2Fill"] = "rbxassetid://120147027066863",
		["macproGen3"] = "rbxassetid://89147890594992",
		["macproGen3BadgeCkeckmark"] = "rbxassetid://106301224248574",
		["macproGen3BadgeCkeckmarkFill"] = "rbxassetid://84360535979337",
		["macproGen3Fill"] = "rbxassetid://129039223637475",
		["macproGen3Server"] = "rbxassetid://108932834322099",
		["macstudio"] = "rbxassetid://140406615283661",
		["macstudioBadgeCheckmark"] = "rbxassetid://77043299238345",
		["macstudioBadgeCheckmarkFill"] = "rbxassetid://121308069902452",
		["macstudioFill"] = "rbxassetid://140537816153199",
		["macwindow"] = "rbxassetid://120538366729599",
		["macwindowAndCursorarrow"] = "rbxassetid://90741041437063",
		["macwindowAndPointerArrow"] = "rbxassetid://106055489705570",
		["macwindowBadgePlus"] = "rbxassetid://89261664954280",
		["macwindowOnRectangle"] = "rbxassetid://72758136163509",
		["macwindowStack"] = "rbxassetid://134609194698391",
		["magazine"] = "rbxassetid://88500461277714",
		["magazineFill"] = "rbxassetid://91312620388624",
		["magicmouse"] = "rbxassetid://92566698707027",
		["magicmouseFill"] = "rbxassetid://116129840309244",
		["magnifyingglass"] = "rbxassetid://91129038063259",
		["magnifyingglassCircle"] = "rbxassetid://71402731578576",
		["magnifyingglassCircleFill"] = "rbxassetid://98512634782850",
		["magsafeBatterypack"] = "rbxassetid://131576271474358",
		["magsafeBatterypackFill"] = "rbxassetid://93439484481400",
		["mail"] = "rbxassetid://135177457181908",
		["mailAndTextMagnifyingglass"] = "rbxassetid://86308377112063",
		["mailFill"] = "rbxassetid://97466777240439",
		["mailStack"] = "rbxassetid://113856245093303",
		["mailStackFill"] = "rbxassetid://93335421635768",
		["malaysianringgitsign"] = "rbxassetid://122013191520543",
		["malaysianringgitsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://95745537119203",
		["malaysianringgitsignBankBuilding"] = "rbxassetid://95567815149875",
		["malaysianringgitsignBankBuildingFill"] = "rbxassetid://73016241207079",
		["malaysianringgitsignCircle"] = "rbxassetid://86469703884694",
		["malaysianringgitsignCircleFill"] = "rbxassetid://75744193587657",
		["malaysianringgitsignGaugeChartLefthalfRighthalf"] = "rbxassetid://123440228784595",
		["malaysianringgitsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://96465358645429",
		["malaysianringgitsignRing"] = "rbxassetid://133834328268893",
		["malaysianringgitsignRingDashed"] = "rbxassetid://90883710998179",
		["malaysianringgitsignSquare"] = "rbxassetid://85460771757387",
		["malaysianringgitsignSquareFill"] = "rbxassetid://107166651287050",
		["manatsign"] = "rbxassetid://139143453917100",
		["manatsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://70744179468784",
		["manatsignBankBuilding"] = "rbxassetid://76245262473506",
		["manatsignBankBuildingFill"] = "rbxassetid://114034267948261",
		["manatsignCircle"] = "rbxassetid://126199967859257",
		["manatsignCircleFill"] = "rbxassetid://140593155589193",
		["manatsignGaugeChartLefthalfRighthalf"] = "rbxassetid://118055801527619",
		["manatsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://82336814813784",
		["manatsignRing"] = "rbxassetid://109963598001949",
		["manatsignRingDashed"] = "rbxassetid://81986929118943",
		["manatsignSquare"] = "rbxassetid://73346293183441",
		["manatsignSquareFill"] = "rbxassetid://99779949454450",
		["map"] = "rbxassetid://93531590659266",
		["mapCircle"] = "rbxassetid://134601191431751",
		["mapCircleFill"] = "rbxassetid://106092734589750",
		["mapFill"] = "rbxassetid://132139046895902",
		["mappin"] = "rbxassetid://121615146959714",
		["mappinAndEllipse"] = "rbxassetid://121230726923110",
		["mappinAndEllipseCircle"] = "rbxassetid://125429828094681",
		["mappinAndEllipseCircleFill"] = "rbxassetid://139128577846173",
		["mappinCircle"] = "rbxassetid://92261727453112",
		["mappinCircleFill"] = "rbxassetid://92260033202215",
		["mappinSlash"] = "rbxassetid://132771607889983",
		["mappinSlashCircle"] = "rbxassetid://74525734290852",
		["mappinSlashCircleFill"] = "rbxassetid://119484802415308",
		["mappinSquare"] = "rbxassetid://104935304695180",
		["mappinSquareFill"] = "rbxassetid://86746492573973",
		["matterLogo"] = "rbxassetid://102406572400014",
		["mecca"] = "rbxassetid://127812717762114",
		["medal"] = "rbxassetid://71033385043976",
		["medalFill"] = "rbxassetid://90953143843307",
		["medalStar"] = "rbxassetid://120019164471743",
		["medalStarFill"] = "rbxassetid://80020007851214",
		["mediastick"] = "rbxassetid://109549165782172",
		["medicalThermometer"] = "rbxassetid://136280158502496",
		["medicalThermometerFill"] = "rbxassetid://119779476439580",
		["megaphone"] = "rbxassetid://117018716409794",
		["megaphoneFill"] = "rbxassetid://138594117290847",
		["memories"] = "rbxassetid://81385055592525",
		["memoriesBadgeCheckmark"] = "rbxassetid://101694983725997",
		["memoriesBadgeMinus"] = "rbxassetid://85572709182032",
		["memoriesBadgePlus"] = "rbxassetid://89625059340245",
		["memoriesBadgeXmark"] = "rbxassetid://119611626635819",
		["memoriesSlash"] = "rbxassetid://119477438102752",
		["memorychip"] = "rbxassetid://72442769456866",
		["memorychipFill"] = "rbxassetid://108024909200103",
		["menubarArrowDownRectangle"] = "rbxassetid://78264857291724",
		["menubarArrowUpRectangle"] = "rbxassetid://79499600876886",
		["menubarDockRectangle"] = "rbxassetid://73630204597242",
		["menubarDockRectangleBadgeRecord"] = "rbxassetid://70512793203960",
		["menubarRectangle"] = "rbxassetid://138854721784790",
		["menucard"] = "rbxassetid://140366101750659",
		["menucardFill"] = "rbxassetid://124582943019876",
		["message"] = "rbxassetid://74395662017461",
		["messageBadge"] = "rbxassetid://100483745924724",
		["messageBadgeCircle"] = "rbxassetid://106085199916148",
		["messageBadgeCircleFill"] = "rbxassetid://102395002843600",
		["messageBadgeFill"] = "rbxassetid://92248945524593",
		["messageBadgeFilledFill"] = "rbxassetid://89587973073375",
		["messageBadgeWaveform"] = "rbxassetid://83330938459388",
		["messageBadgeWaveformFill"] = "rbxassetid://130089782798576",
		["messageCircle"] = "rbxassetid://102977548422597",
		["messageCircleFill"] = "rbxassetid://98654060282404",
		["messageFill"] = "rbxassetid://78470145456613",
		["metronome"] = "rbxassetid://106160116449584",
		["metronomeFill"] = "rbxassetid://113113603878861",
		["mic"] = "rbxassetid://70559142840213",
		["micAndSignalMeter"] = "rbxassetid://98371685797325",
		["micBadgePlus"] = "rbxassetid://124905697228070",
		["micBadgeXmark"] = "rbxassetid://90776924897027",
		["micCircle"] = "rbxassetid://97798740260123",
		["micSlash"] = "rbxassetid://77413617305085",
		["micSlashCircle"] = "rbxassetid://124310703535746",
		["micSquare"] = "rbxassetid://113336595252301",
		["microbe"] = "rbxassetid://101055634388755",
		["microbeCircle"] = "rbxassetid://71746458377734",
		["microbeCircleFill"] = "rbxassetid://102842672445570",
		["microbeFill"] = "rbxassetid://89507986671859",
		["microphone"] = "rbxassetid://91483706052452",
		["microphoneAndSignalMeter"] = "rbxassetid://92063694320161",
		["microphoneAndSignalMeterFill"] = "rbxassetid://106138035371214",
		["microphoneBadgeEllipsis"] = "rbxassetid://103989002655467",
		["microphoneBadgeEllipsisFill"] = "rbxassetid://110996273867879",
		["microphoneBadgePlus"] = "rbxassetid://117094983790077",
		["microphoneBadgePlusFill"] = "rbxassetid://127145588822404",
		["microphoneBadgeXmark"] = "rbxassetid://74319653306618",
		["microphoneBadgeXmarkFill"] = "rbxassetid://72163348631659",
		["microphoneCircle"] = "rbxassetid://128457079809321",
		["microphoneCircleFill"] = "rbxassetid://124876886582740",
		["microphoneFill"] = "rbxassetid://93919436903011",
		["microphoneSlash"] = "rbxassetid://128089521766130",
		["microphoneSlashCircle"] = "rbxassetid://81904243939624",
		["microphoneSlashCircleFill"] = "rbxassetid://85089208509744",
		["microphoneSlashFill"] = "rbxassetid://114274894150098",
		["microphoneSquare"] = "rbxassetid://114042644452492",
		["microphoneSquareFill"] = "rbxassetid://100514210081121",
		["microwave"] = "rbxassetid://109825403791681",
		["microwaveFill"] = "rbxassetid://72225124273007",
		["millsign"] = "rbxassetid://120612264843894",
		["millsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://113401890675382",
		["millsignBankBuilding"] = "rbxassetid://84067991643769",
		["millsignBankBuildingFill"] = "rbxassetid://137124816253943",
		["millsignCircle"] = "rbxassetid://93145949048334",
		["millsignCircleFill"] = "rbxassetid://119498566433333",
		["millsignGaugeChartLefthalfRighthalf"] = "rbxassetid://87724227677679",
		["millsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://136203853226981",
		["millsignRing"] = "rbxassetid://116690436863629",
		["millsignRingDashed"] = "rbxassetid://110814114561866",
		["millsignSquare"] = "rbxassetid://77492773148562",
		["millsignSquareFill"] = "rbxassetid://106288582641608",
		["minus"] = "rbxassetid://89004332408449",
		["minusArrowTriangleheadClockwise"] = "rbxassetid://114634757784622",
		["minusArrowTriangleheadCounterclockwise"] = "rbxassetid://107045388378537",
		["minusCircle"] = "rbxassetid://137503047808593",
		["minusCircleFill"] = "rbxassetid://114233698275838",
		["minusDiamond"] = "rbxassetid://70626236941066",
		["minusDiamondFill"] = "rbxassetid://137055603164475",
		["minusForwardslashPlus"] = "rbxassetid://139481511724753",
		["minusMagnifyingglass"] = "rbxassetid://134132342538161",
		["minusPlusAndFluidBatteryblock"] = "rbxassetid://101939616357249",
		["minusPlusBatteryblock"] = "rbxassetid://127012882466494",
		["minusPlusBatteryblockExclamationmark"] = "rbxassetid://139500256583872",
		["minusPlusBatteryblockExclamationmarkFill"] = "rbxassetid://96081928780644",
		["minusPlusBatteryblockFill"] = "rbxassetid://117085342503922",
		["minusPlusBatteryblockSlash"] = "rbxassetid://100393676834035",
		["minusPlusBatteryblockSlashFill"] = "rbxassetid://124640512084539",
		["minusPlusBatteryblockStack"] = "rbxassetid://79524287782222",
		["minusPlusBatteryblockStackArrowtriangleLeft"] = "rbxassetid://122261351206637",
		["minusPlusBatteryblockStackArrowtriangleLeftFill"] = "rbxassetid://115291043746629",
		["minusPlusBatteryblockStackArrowtriangleRight"] = "rbxassetid://91966942937693",
		["minusPlusBatteryblockStackArrowtriangleRightAndArrowtriangleLeft"] = "rbxassetid://134386149198478",
		["minusPlusBatteryblockStackArrowtriangleRightAndArrowtriangleLeftFill"] = "rbxassetid://88265395694017",
		["minusPlusBatteryblockStackArrowtriangleRightFill"] = "rbxassetid://121219514043882",
		["minusPlusBatteryblockStackExclamationmark"] = "rbxassetid://123187360686442",
		["minusPlusBatteryblockStackExclamationmarkFill"] = "rbxassetid://72073968796558",
		["minusPlusBatteryblockStackFill"] = "rbxassetid://129390097165145",
		["minusPlusLinesMeasurementHorizontalAlignedBottom"] = "rbxassetid://86287457532753",
		["minusRectangle"] = "rbxassetid://101832378845362",
		["minusRectangleFill"] = "rbxassetid://71255897440595",
		["minusRectanglePortrait"] = "rbxassetid://79554895569395",
		["minusRectanglePortraitFill"] = "rbxassetid://123355657429657",
		["minusSquare"] = "rbxassetid://92869320034967",
		["minusSquareFill"] = "rbxassetid://93926501938010",
		["mirrorSideLeft"] = "rbxassetid://79676503129954",
		["mirrorSideLeftAndArrowTurnDownRight"] = "rbxassetid://112735732212436",
		["mirrorSideLeftAndHeatWaves"] = "rbxassetid://97452704291102",
		["mirrorSideRight"] = "rbxassetid://83056491035621",
		["mirrorSideRightAndArrowTurnDownLeft"] = "rbxassetid://118420715252545",
		["mirrorSideRightAndHeatWaves"] = "rbxassetid://74725135702403",
		["moon"] = "rbxassetid://82139899083256",
		["moonCircle"] = "rbxassetid://85414026848067",
		["moonCircleFill"] = "rbxassetid://127455736032544",
		["moonDust"] = "rbxassetid://80023875298780",
		["moonDustCircle"] = "rbxassetid://137917787774386",
		["moonDustCircleFill"] = "rbxassetid://89884876621538",
		["moonDustFill"] = "rbxassetid://92755134821567",
		["moonFill"] = "rbxassetid://80943018865798",
		["moonHaze"] = "rbxassetid://127865614718648",
		["moonHazeCircle"] = "rbxassetid://104234616092079",
		["moonHazeCircleFill"] = "rbxassetid://72550900291532",
		["moonHazeFill"] = "rbxassetid://132090014257174",
		["moonRoadLanes"] = "rbxassetid://116463811762109",
		["moonStars"] = "rbxassetid://87321082119205",
		["moonStarsCircle"] = "rbxassetid://75028167300841",
		["moonStarsCircleFill"] = "rbxassetid://83056445144978",
		["moonStarsFill"] = "rbxassetid://117208258351328",
		["moonZzz"] = "rbxassetid://90271070534923",
		["moonZzzFill"] = "rbxassetid://120704152209521",
		["moonphaseFirstQuarter"] = "rbxassetid://117116577141627",
		["moonphaseFirstQuarterInverse"] = "rbxassetid://111603319059305",
		["moonphaseFullMoon"] = "rbxassetid://101123767009739",
		["moonphaseFullMoonInverse"] = "rbxassetid://87181814547523",
		["moonphaseLastQuarter"] = "rbxassetid://125883223406968",
		["moonphaseLastQuarterInverse"] = "rbxassetid://113591277926901",
		["moonphaseNewMoon"] = "rbxassetid://91400655736524",
		["moonphaseNewMoonInverse"] = "rbxassetid://94223725414952",
		["moonphaseWaningCrescent"] = "rbxassetid://71889864039420",
		["moonphaseWaningCrescentInverse"] = "rbxassetid://97971828509046",
		["moonphaseWaningGibbous"] = "rbxassetid://125561957914316",
		["moonphaseWaningGibbousInverse"] = "rbxassetid://133040082683778",
		["moonphaseWaxingCrescent"] = "rbxassetid://109118424981772",
		["moonphaseWaxingCrescentInverse"] = "rbxassetid://83389541865251",
		["moonphaseWaxingGibbous"] = "rbxassetid://117103885736080",
		["moonphaseWaxingGibbousInverse"] = "rbxassetid://81404317227610",
		["moonrise"] = "rbxassetid://115339490944432",
		["moonriseCircle"] = "rbxassetid://136045524355967",
		["moonriseCircleFill"] = "rbxassetid://128404111997844",
		["moonriseFill"] = "rbxassetid://103140476284194",
		["moonset"] = "rbxassetid://72866577933832",
		["moonsetCircle"] = "rbxassetid://74071623128842",
		["moonsetCircleFill"] = "rbxassetid://132376217303310",
		["moonsetFill"] = "rbxassetid://82467208130648",
		["moped"] = "rbxassetid://132510221978497",
		["mopedFill"] = "rbxassetid://118529287468863",
		["mosaic"] = "rbxassetid://89243776028649",
		["mosaicFill"] = "rbxassetid://95720390375780",
		["motorcycle"] = "rbxassetid://82758135256909",
		["motorcycleFill"] = "rbxassetid://129675811040460",
		["mount"] = "rbxassetid://118225973874297",
		["mountFill"] = "rbxassetid://136416370964291",
		["mountain2"] = "rbxassetid://73789953244069",
		["mountain2Circle"] = "rbxassetid://120539292840338",
		["mountain2CircleFill"] = "rbxassetid://126616357820763",
		["mountain2Fill"] = "rbxassetid://72619625972809",
		["mouth"] = "rbxassetid://72658267669640",
		["mouthFill"] = "rbxassetid://100047036743743",
		["move3d"] = "rbxassetid://112398672404328",
		["movieclapper"] = "rbxassetid://80954194772844",
		["movieclapperFill"] = "rbxassetid://135561411591078",
		["mph"] = "rbxassetid://128529074792406",
		["mphCircle"] = "rbxassetid://81809274837519",
		["mphCircleFill"] = "rbxassetid://121437826766049",
		["mug"] = "rbxassetid://110628058332506",
		["mugFill"] = "rbxassetid://139140377653653",
		["multiply"] = "rbxassetid://136891818007188",
		["multiplyCircle"] = "rbxassetid://127978128794846",
		["multiplyCircleFill"] = "rbxassetid://127229291230155",
		["multiplySquare"] = "rbxassetid://97309344874453",
		["multiplySquareFill"] = "rbxassetid://112070371616255",
		["musicMic"] = "rbxassetid://126510932173223",
		["musicMicCircle"] = "rbxassetid://121995856123205",
		["musicMicrophone"] = "rbxassetid://100824169660656",
		["musicMicrophoneCircle"] = "rbxassetid://131498749144552",
		["musicMicrophoneCircleFill"] = "rbxassetid://120791444280471",
		["musicNote"] = "rbxassetid://126082822807584",
		["musicNoteArrowTriangleheadClockwise"] = "rbxassetid://133288353146842",
		["musicNoteHouse"] = "rbxassetid://91704654202540",
		["musicNoteHouseFill"] = "rbxassetid://99180255941950",
		["musicNoteList"] = "rbxassetid://96230339803471",
		["musicNoteSlash"] = "rbxassetid://127771624449291",
		["musicNoteSquareStack"] = "rbxassetid://88198486537881",
		["musicNoteSquareStackFill"] = "rbxassetid://136399162566805",
		["musicNoteTv"] = "rbxassetid://118014044046358",
		["musicNoteTvFill"] = "rbxassetid://101072939696766",
		["musicPages"] = "rbxassetid://98131195358883",
		["musicPagesFill"] = "rbxassetid://100815742404062",
		["musicQuarternote3"] = "rbxassetid://72571169895421",
		["mustache"] = "rbxassetid://81213625247949",
		["mustacheFill"] = "rbxassetid://135889093221272",
		["nCircle"] = "rbxassetid://119692721835646",
		["nCircleFill"] = "rbxassetid://139590129950612",
		["nSquare"] = "rbxassetid://82639756767208",
		["nSquareFill"] = "rbxassetid://77756021605509",
		["nairasign"] = "rbxassetid://106795085125512",
		["nairasignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://136163098752557",
		["nairasignBankBuilding"] = "rbxassetid://118269030455068",
		["nairasignBankBuildingFill"] = "rbxassetid://102921613899751",
		["nairasignCircle"] = "rbxassetid://75558341136080",
		["nairasignCircleFill"] = "rbxassetid://74947644324829",
		["nairasignGaugeChartLefthalfRighthalf"] = "rbxassetid://129556356646485",
		["nairasignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://96821649386281",
		["nairasignRing"] = "rbxassetid://117523908784311",
		["nairasignRingDashed"] = "rbxassetid://105742853876513",
		["nairasignSquare"] = "rbxassetid://135120380049763",
		["nairasignSquareFill"] = "rbxassetid://132052855718549",
		["network"] = "rbxassetid://120498202241355",
		["networkBadgeShieldHalfFilled"] = "rbxassetid://113813057412690",
		["networkSlash"] = "rbxassetid://101003667032615",
		["newspaper"] = "rbxassetid://104839010601075",
		["newspaperCircle"] = "rbxassetid://115347908928306",
		["newspaperCircleFill"] = "rbxassetid://105464060542335",
		["newspaperFill"] = "rbxassetid://137360183744130",
		["norwegiankronesign"] = "rbxassetid://119731208635088",
		["norwegiankronesignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://101411001215020",
		["norwegiankronesignBankBuilding"] = "rbxassetid://85695886048676",
		["norwegiankronesignBankBuildingFill"] = "rbxassetid://95684757727036",
		["norwegiankronesignCircle"] = "rbxassetid://81846373779456",
		["norwegiankronesignCircleFill"] = "rbxassetid://109254117252040",
		["norwegiankronesignGaugeChartLefthalfRighthalf"] = "rbxassetid://113781025133033",
		["norwegiankronesignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://78092984701784",
		["norwegiankronesignRing"] = "rbxassetid://138947979267546",
		["norwegiankronesignRingDashed"] = "rbxassetid://77241946000543",
		["norwegiankronesignSquare"] = "rbxassetid://95995824513915",
		["norwegiankronesignSquareFill"] = "rbxassetid://96123508833499",
		["nose"] = "rbxassetid://74544706026614",
		["noseFill"] = "rbxassetid://124371438722659",
		["nosign"] = "rbxassetid://110675356214733",
		["nosignApp"] = "rbxassetid://90400743739520",
		["nosignAppFill"] = "rbxassetid://107658749612961",
		["nosignBadgeClock"] = "rbxassetid://137939836191842",
		["note"] = "rbxassetid://93279801394323",
		["noteText"] = "rbxassetid://128260562606530",
		["noteTextBadgePlus"] = "rbxassetid://103069459660634",
		["notequal"] = "rbxassetid://86562600167503",
		["notequalCircle"] = "rbxassetid://135789760267660",
		["notequalCircleFill"] = "rbxassetid://75312888708455",
		["notequalSquare"] = "rbxassetid://81897503982741",
		["notequalSquareFill"] = "rbxassetid://72731357908400",
		["number"] = "rbxassetid://127208629756456",
		["number00Circle"] = "rbxassetid://131779637005640",
		["number00Square"] = "rbxassetid://81236373352019",
		["number01Circle"] = "rbxassetid://138017951861028",
		["number01Square"] = "rbxassetid://97241538934163",
		["number02Circle"] = "rbxassetid://133242670562001",
		["number02Square"] = "rbxassetid://99179290111993",
		["number03Circle"] = "rbxassetid://105983470184277",
		["number03Square"] = "rbxassetid://132291497347326",
		["number04Circle"] = "rbxassetid://116987436384055",
		["number04Square"] = "rbxassetid://104100419385488",
		["number05Circle"] = "rbxassetid://130314809611820",
		["number05Square"] = "rbxassetid://114379850471491",
		["number06Circle"] = "rbxassetid://137452105712472",
		["number06Square"] = "rbxassetid://103212010162769",
		["number07Circle"] = "rbxassetid://102549222409891",
		["number07Square"] = "rbxassetid://80554919883042",
		["number08Circle"] = "rbxassetid://133051884093292",
		["number08Square"] = "rbxassetid://128176821770996",
		["number09Circle"] = "rbxassetid://76455988018714",
		["number09Square"] = "rbxassetid://87408221362281",
		["number0Circle"] = "rbxassetid://112630144563845",
		["number0Square"] = "rbxassetid://83690626547054",
		["number10Circle"] = "rbxassetid://96193951740646",
		["number10Lane"] = "rbxassetid://81314525759681",
		["number10Square"] = "rbxassetid://81808119537499",
		["number11Circle"] = "rbxassetid://121287509877595",
		["number11Lane"] = "rbxassetid://103036455180106",
		["number11Square"] = "rbxassetid://137943364469277",
		["number123Rectangle"] = "rbxassetid://115605993616370",
		["number12Circle"] = "rbxassetid://95488831711839",
		["number12Lane"] = "rbxassetid://122996912273287",
		["number12Square"] = "rbxassetid://134346701257530",
		["number13Circle"] = "rbxassetid://117905874629917",
		["number13Square"] = "rbxassetid://117293639837435",
		["number14Circle"] = "rbxassetid://108407748009645",
		["number14Square"] = "rbxassetid://87120163705904",
		["number15Circle"] = "rbxassetid://101007633009470",
		["number15Square"] = "rbxassetid://78052584911395",
		["number16Circle"] = "rbxassetid://107648080370730",
		["number16Square"] = "rbxassetid://127190639879155",
		["number17Circle"] = "rbxassetid://104117985546346",
		["number17Square"] = "rbxassetid://73499070638265",
		["number18Circle"] = "rbxassetid://102380885337705",
		["number18Square"] = "rbxassetid://80311469813477",
		["number19Circle"] = "rbxassetid://134713999920408",
		["number19Square"] = "rbxassetid://102272936095513",
		["number1Brakesignal"] = "rbxassetid://79144309389823",
		["number1Circle"] = "rbxassetid://90420045405973",
		["number1Lane"] = "rbxassetid://125260612972564",
		["number1Magnifyingglass"] = "rbxassetid://111096049925424",
		["number1Square"] = "rbxassetid://108186243137995",
		["number20Circle"] = "rbxassetid://119790353650997",
		["number20Square"] = "rbxassetid://73427706736721",
		["number21Circle"] = "rbxassetid://115011080119497",
		["number21Square"] = "rbxassetid://100575245011241",
		["number22Circle"] = "rbxassetid://79147656530403",
		["number22Square"] = "rbxassetid://107808365980228",
		["number23Circle"] = "rbxassetid://113967161448579",
		["number23Square"] = "rbxassetid://126327561252667",
		["number24Circle"] = "rbxassetid://77688026724586",
		["number24Square"] = "rbxassetid://102948515141281",
		["number25Circle"] = "rbxassetid://103932230280729",
		["number25Square"] = "rbxassetid://85964236323828",
		["number26Circle"] = "rbxassetid://110095157711014",
		["number26Square"] = "rbxassetid://72769891775076",
		["number27Circle"] = "rbxassetid://80413679989648",
		["number27Square"] = "rbxassetid://78907626263409",
		["number28Circle"] = "rbxassetid://77630558937328",
		["number28Square"] = "rbxassetid://101516015146640",
		["number29Circle"] = "rbxassetid://112151950673070",
		["number29Square"] = "rbxassetid://126060868481076",
		["number2Brakesignal"] = "rbxassetid://130026522834900",
		["number2Circle"] = "rbxassetid://115644023941063",
		["number2Lane"] = "rbxassetid://76895941784764",
		["number2Square"] = "rbxassetid://135434406067611",
		["number30Circle"] = "rbxassetid://93539842298014",
		["number30Square"] = "rbxassetid://92360148508407",
		["number31Circle"] = "rbxassetid://117202855882818",
		["number31Square"] = "rbxassetid://72665219530870",
		["number32Circle"] = "rbxassetid://102701322952852",
		["number32Square"] = "rbxassetid://97548734649989",
		["number33Circle"] = "rbxassetid://76331950936098",
		["number33Square"] = "rbxassetid://91723950606376",
		["number34Circle"] = "rbxassetid://76108893775703",
		["number34Square"] = "rbxassetid://98356773601222",
		["number35Circle"] = "rbxassetid://128638587888904",
		["number35Square"] = "rbxassetid://114874576219731",
		["number36Circle"] = "rbxassetid://124580301053177",
		["number36Square"] = "rbxassetid://128676757513519",
		["number37Circle"] = "rbxassetid://105355724679695",
		["number37Square"] = "rbxassetid://111356313667440",
		["number38Circle"] = "rbxassetid://140658654909786",
		["number38Square"] = "rbxassetid://87276444787352",
		["number39Circle"] = "rbxassetid://127160538226349",
		["number39Square"] = "rbxassetid://110607591007885",
		["number3Circle"] = "rbxassetid://82210102360256",
		["number3Lane"] = "rbxassetid://123566814024217",
		["number3Square"] = "rbxassetid://100151903595968",
		["number40Circle"] = "rbxassetid://76284811463961",
		["number40Square"] = "rbxassetid://108964733911464",
		["number41Circle"] = "rbxassetid://81051156411638",
		["number41Square"] = "rbxassetid://108180042091768",
		["number42Circle"] = "rbxassetid://105367690120970",
		["number42Square"] = "rbxassetid://121398683227303",
		["number43Circle"] = "rbxassetid://116742062830209",
		["number43Square"] = "rbxassetid://114456062917463",
		["number44Circle"] = "rbxassetid://95645523276973",
		["number44Square"] = "rbxassetid://74196270639498",
		["number45Circle"] = "rbxassetid://131982584078162",
		["number45Square"] = "rbxassetid://112633410131411",
		["number46Circle"] = "rbxassetid://98121889785827",
		["number46Square"] = "rbxassetid://71827970370485",
		["number47Circle"] = "rbxassetid://110683991524351",
		["number47Square"] = "rbxassetid://130355817586206",
		["number48Circle"] = "rbxassetid://100680920554029",
		["number48Square"] = "rbxassetid://137504486853690",
		["number49Circle"] = "rbxassetid://85012410965666",
		["number49Square"] = "rbxassetid://112216977302610",
		["number4AltCircle"] = "rbxassetid://120280636483094",
		["number4AltSquare"] = "rbxassetid://122930727055244",
		["number4Circle"] = "rbxassetid://113950512097158",
		["number4Lane"] = "rbxassetid://80369915269072",
		["number4Square"] = "rbxassetid://85342885629372",
		["number50Circle"] = "rbxassetid://76596482604277",
		["number50Square"] = "rbxassetid://89126185617207",
		["number5Circle"] = "rbxassetid://84249571663594",
		["number5Lane"] = "rbxassetid://80082125386311",
		["number5Square"] = "rbxassetid://92555254652509",
		["number6AltCircle"] = "rbxassetid://132108212531324",
		["number6AltSquare"] = "rbxassetid://133921705918574",
		["number6Circle"] = "rbxassetid://139508584419391",
		["number6Lane"] = "rbxassetid://120411900425268",
		["number6Square"] = "rbxassetid://136827465810666",
		["number7Circle"] = "rbxassetid://91048231428377",
		["number7Lane"] = "rbxassetid://89152600086974",
		["number7Square"] = "rbxassetid://128474224252993",
		["number8Circle"] = "rbxassetid://90175124244732",
		["number8Lane"] = "rbxassetid://135579479621822",
		["number8Square"] = "rbxassetid://103037928409169",
		["number9AltCircle"] = "rbxassetid://89157942477413",
		["number9AltSquare"] = "rbxassetid://127573342279334",
		["number9Circle"] = "rbxassetid://122405410433743",
		["number9Lane"] = "rbxassetid://118878335756561",
		["number9Square"] = "rbxassetid://113640399773664",
		["numberCircle"] = "rbxassetid://91537062236961",
		["numberCircleFill"] = "rbxassetid://128309928890652",
		["numberSquare"] = "rbxassetid://82329567357914",
		["numberSquareFill"] = "rbxassetid://126805206921861",
		["numbers"] = "rbxassetid://84498045988050",
		["numbersRectangle"] = "rbxassetid://94260654225058",
		["numbersRectangleFill"] = "rbxassetid://94598633915174",
		["numbersign"] = "rbxassetid://95244886174960",
		["numeric2h"] = "rbxassetid://105497397405088",
		["numeric2hCircle"] = "rbxassetid://70624293530403",
		["numeric4a"] = "rbxassetid://86756867568912",
		["numeric4aCircle"] = "rbxassetid://80949635570356",
		["numeric4h"] = "rbxassetid://111499849309749",
		["numeric4hCircle"] = "rbxassetid://108759735497325",
		["numeric4kTv"] = "rbxassetid://138479967752101",
		["numeric4l"] = "rbxassetid://132669284716581",
		["numeric4lCircle"] = "rbxassetid://81144013373119",
		["oCircle"] = "rbxassetid://106397024350624",
		["oCircleFill"] = "rbxassetid://76217943049253",
		["oSquare"] = "rbxassetid://73833935065451",
		["oSquareFill"] = "rbxassetid://96189217216385",
		["oar2Crossed"] = "rbxassetid://87527605793944",
		["oar2CrossedCircle"] = "rbxassetid://136436924320890",
		["oar2CrossedCircleFill"] = "rbxassetid://101685289108994",
		["octagon"] = "rbxassetid://79038916131641",
		["octagonBottomhalfFilled"] = "rbxassetid://114692214649659",
		["octagonFill"] = "rbxassetid://107625404272807",
		["octagonLefthalfFilled"] = "rbxassetid://99209930883951",
		["octagonRighthalfFilled"] = "rbxassetid://112842649283426",
		["octagonTophalfFilled"] = "rbxassetid://114065832521760",
		["oilcan"] = "rbxassetid://135272223692064",
		["oilcanAndThermometer"] = "rbxassetid://117495873565426",
		["oilcanAndThermometerFill"] = "rbxassetid://112607162891091",
		["oilcanFill"] = "rbxassetid://118078317492971",
		["opticaldisc"] = "rbxassetid://123902479206565",
		["opticaldiscFill"] = "rbxassetid://93483653186548",
		["opticaldiscdrive"] = "rbxassetid://73954391898782",
		["opticaldiscdriveFill"] = "rbxassetid://134334854298944",
		["opticid"] = "rbxassetid://122071408513811",
		["opticidFill"] = "rbxassetid://120138153821378",
		["option"] = "rbxassetid://132861598935618",
		["oval"] = "rbxassetid://113810873605238",
		["ovalBottomhalfFilled"] = "rbxassetid://126916332045325",
		["ovalFill"] = "rbxassetid://94952343843714",
		["ovalLefthalfFilled"] = "rbxassetid://113389656237279",
		["ovalPortrait"] = "rbxassetid://132483754313621",
		["ovalPortraitBottomhalfFilled"] = "rbxassetid://71422335054914",
		["ovalPortraitFill"] = "rbxassetid://79131278329666",
		["ovalPortraitLefthalfFilled"] = "rbxassetid://109381437626839",
		["ovalPortraitRighthalfFilled"] = "rbxassetid://111288429681074",
		["ovalPortraitTophalfFilled"] = "rbxassetid://123536161343998",
		["ovalRighthalfFilled"] = "rbxassetid://104199544496623",
		["ovalTophalfFilled"] = "rbxassetid://101770441746408",
		["oven"] = "rbxassetid://86234645623692",
		["ovenFill"] = "rbxassetid://83900517666474",
		["p1ButtonHorizontal"] = "rbxassetid://126562898638354",
		["p1ButtonHorizontalFill"] = "rbxassetid://110710525929608",
		["p2ButtonHorizontal"] = "rbxassetid://77218364525379",
		["p2ButtonHorizontalFill"] = "rbxassetid://133839416874548",
		["p3ButtonHorizontal"] = "rbxassetid://138792223238109",
		["p3ButtonHorizontalFill"] = "rbxassetid://106186118395145",
		["p4ButtonHorizontal"] = "rbxassetid://77853304593628",
		["p4ButtonHorizontalFill"] = "rbxassetid://130778443695025",
		["pCircle"] = "rbxassetid://117640721311754",
		["pCircleFill"] = "rbxassetid://87813691082387",
		["pSquare"] = "rbxassetid://107762110453705",
		["pSquareFill"] = "rbxassetid://96012467396262",
		["padHeader"] = "rbxassetid://92020313753615",
		["paddleshifterLeft"] = "rbxassetid://126265871847369",
		["paddleshifterLeftFill"] = "rbxassetid://125673273656120",
		["paddleshifterRight"] = "rbxassetid://117840207563380",
		["paddleshifterRightFill"] = "rbxassetid://80336378319314",
		["paintBucketClassic"] = "rbxassetid://85152836091310",
		["paintbrush"] = "rbxassetid://109533740362394",
		["paintbrushFill"] = "rbxassetid://99513788554382",
		["paintbrushPointed"] = "rbxassetid://127402849243896",
		["paintbrushPointedFill"] = "rbxassetid://88165121517273",
		["paintpalette"] = "rbxassetid://138490319699379",
		["paintpaletteFill"] = "rbxassetid://131716243676081",
		["pano"] = "rbxassetid://107256596811076",
		["panoBadgePlay"] = "rbxassetid://105599907508172",
		["panoBadgePlayFill"] = "rbxassetid://131513740947262",
		["panoFill"] = "rbxassetid://89694664506298",
		["paperclip"] = "rbxassetid://137882336475940",
		["paperclipBadgeEllipsis"] = "rbxassetid://134936619429895",
		["paperclipCircle"] = "rbxassetid://110142955736619",
		["paperclipCircleFill"] = "rbxassetid://133602092264853",
		["paperplane"] = "rbxassetid://80974571487117",
		["paperplaneCircle"] = "rbxassetid://137118091888490",
		["paperplaneCircleFill"] = "rbxassetid://71065495715325",
		["paperplaneFill"] = "rbxassetid://74965599538986",
		["paragraphsign"] = "rbxassetid://94556416337049",
		["parentheses"] = "rbxassetid://130009418294104",
		["parkinglight"] = "rbxassetid://109225690951003",
		["parkinglightFill"] = "rbxassetid://99882392916301",
		["parkingsign"] = "rbxassetid://75870889123264",
		["parkingsignBrakesignal"] = "rbxassetid://112789415747617",
		["parkingsignBrakesignalSlash"] = "rbxassetid://71858648062530",
		["parkingsignCircle"] = "rbxassetid://99556995799552",
		["parkingsignCircleFill"] = "rbxassetid://87920284156496",
		["parkingsignRadiowavesDownRightOff"] = "rbxassetid://138123234771263",
		["parkingsignRadiowavesLeftAndRight"] = "rbxassetid://103933467168122",
		["parkingsignRadiowavesLeftAndRightSlash"] = "rbxassetid://97814507902059",
		["parkingsignRadiowavesRightAndSafetycone"] = "rbxassetid://104481497468858",
		["parkingsignSquare"] = "rbxassetid://77549829356466",
		["parkingsignSquareFill"] = "rbxassetid://94937107598603",
		["parkingsignSteeringwheel"] = "rbxassetid://113877456839912",
		["partyPopper"] = "rbxassetid://97097770522299",
		["partyPopperFill"] = "rbxassetid://126854429415327",
		["pause"] = "rbxassetid://86021151376401",
		["pauseCircle"] = "rbxassetid://121043050488805",
		["pauseCircleFill"] = "rbxassetid://113265459725055",
		["pauseFill"] = "rbxassetid://133135421688612",
		["pauseRectangle"] = "rbxassetid://79118144830856",
		["pauseRectangleFill"] = "rbxassetid://98884467605829",
		["pawprint"] = "rbxassetid://72805687268685",
		["pawprintCircle"] = "rbxassetid://82961293618699",
		["pawprintCircleFill"] = "rbxassetid://133414719283799",
		["pawprintFill"] = "rbxassetid://120051601058569",
		["pc"] = "rbxassetid://84697360225761",
		["peacesign"] = "rbxassetid://83716327577706",
		["pedalAccelerator"] = "rbxassetid://107951710156857",
		["pedalAcceleratorFill"] = "rbxassetid://130529659230331",
		["pedalBrake"] = "rbxassetid://127337111670528",
		["pedalBrakeFill"] = "rbxassetid://71467964364715",
		["pedalClutch"] = "rbxassetid://73279295635737",
		["pedalClutchFill"] = "rbxassetid://103699453075905",
		["pedestrianGateClosed"] = "rbxassetid://110977038522546",
		["pedestrianGateClosedTrianglebadgeExclamationmark"] = "rbxassetid://84254696178218",
		["pedestrianGateOpen"] = "rbxassetid://131872346865052",
		["pedestrianGateOpenTrianglebadgeExclamationmark"] = "rbxassetid://131146459812890",
		["pencil"] = "rbxassetid://130705269869803",
		["pencilAndListClipboard"] = "rbxassetid://108221324478019",
		["pencilAndOutline"] = "rbxassetid://71370761213291",
		["pencilAndRuler"] = "rbxassetid://130053969230904",
		["pencilAndRulerFill"] = "rbxassetid://135794725468905",
		["pencilAndScribble"] = "rbxassetid://71841329049910",
		["pencilCircle"] = "rbxassetid://126091045493595",
		["pencilCircleFill"] = "rbxassetid://120665154874259",
		["pencilLine"] = "rbxassetid://114694675953537",
		["pencilSlash"] = "rbxassetid://99813950298838",
		["pencilTip"] = "rbxassetid://72990698962317",
		["pencilTipCropCircle"] = "rbxassetid://116258147913478",
		["pencilTipCropCircleBadgeArrowForward"] = "rbxassetid://138569973971114",
		["pencilTipCropCircleBadgeArrowForwardFill"] = "rbxassetid://80339580243434",
		["pencilTipCropCircleBadgeMinus"] = "rbxassetid://137149264289620",
		["pencilTipCropCircleBadgeMinusFill"] = "rbxassetid://106175372040589",
		["pencilTipCropCircleBadgePlus"] = "rbxassetid://81912638436848",
		["pencilTipCropCircleBadgePlusFill"] = "rbxassetid://135279218878675",
		["pencilTipCropCircleFill"] = "rbxassetid://123542970215827",
		["pentagon"] = "rbxassetid://113187250562484",
		["pentagonBottomhalfFilled"] = "rbxassetid://77804606585420",
		["pentagonFill"] = "rbxassetid://107612785851729",
		["pentagonLefthalfFilled"] = "rbxassetid://102272146625100",
		["pentagonRighthalfFilled"] = "rbxassetid://71901071200525",
		["pentagonTophalfFilled"] = "rbxassetid://124042937629059",
		["percent"] = "rbxassetid://127492144708581",
		["person"] = "rbxassetid://110701632373035",
		["person2"] = "rbxassetid://112399905717309",
		["person2ArrowTriangleheadCounterclockwise"] = "rbxassetid://123475483919631",
		["person2Badge"] = "rbxassetid://81421024779982",
		["person2BadgeFill"] = "rbxassetid://138318005759141",
		["person2BadgeGearshape"] = "rbxassetid://132573815056374",
		["person2BadgeGearshapeFill"] = "rbxassetid://73944930602710",
		["person2BadgeKey"] = "rbxassetid://93647666096573",
		["person2BadgeKeyFill"] = "rbxassetid://136470113852487",
		["person2BadgeMinus"] = "rbxassetid://84645992076966",
		["person2BadgeMinusFill"] = "rbxassetid://77898589792614",
		["person2BadgePlus"] = "rbxassetid://135162242901966",
		["person2BadgePlusFill"] = "rbxassetid://123701745548055",
		["person2Circle"] = "rbxassetid://91806733116755",
		["person2CircleFill"] = "rbxassetid://130770498958716",
		["person2CropSquareStack"] = "rbxassetid://116331579710856",
		["person2CropSquareStackFill"] = "rbxassetid://132329087604078",
		["person2Fill"] = "rbxassetid://140041117183015",
		["person2Gobackward"] = "rbxassetid://77336790373231",
		["person2Shield"] = "rbxassetid://124016438026144",
		["person2ShieldFill"] = "rbxassetid://139070659357420",
		["person2Slash"] = "rbxassetid://87644578467719",
		["person2SlashFill"] = "rbxassetid://137522706511369",
		["person2Wave2"] = "rbxassetid://122652213620435",
		["person2Wave2Fill"] = "rbxassetid://76240613584680",
		["person3"] = "rbxassetid://129473219512684",
		["person3Fill"] = "rbxassetid://105740784710191",
		["person3Sequence"] = "rbxassetid://107389006554677",
		["person3SequenceFill"] = "rbxassetid://85888945527165",
		["personAndArrowLeftAndArrowRight"] = "rbxassetid://128164370218812",
		["personAndArrowLeftAndArrowRightOutward"] = "rbxassetid://101409421769868",
		["personAndBackgroundDotted"] = "rbxassetid://83784991200691",
		["personAndBackgroundStripedHorizontal"] = "rbxassetid://75509951269289",
		["personBadgeClock"] = "rbxassetid://97908584137499",
		["personBadgeClockFill"] = "rbxassetid://76924073855200",
		["personBadgeKey"] = "rbxassetid://98218511075004",
		["personBadgeKeyFill"] = "rbxassetid://140402839580918",
		["personBadgeMinus"] = "rbxassetid://125565222576571",
		["personBadgePlus"] = "rbxassetid://115656988628904",
		["personBadgeShieldCheckmark"] = "rbxassetid://83267413868149",
		["personBadgeShieldCheckmarkFill"] = "rbxassetid://131283863488112",
		["personBadgeShieldExclamationmark"] = "rbxassetid://84408939526129",
		["personBadgeShieldExclamationmarkFill"] = "rbxassetid://87987647501843",
		["personBubble"] = "rbxassetid://133030906481167",
		["personBubbleFill"] = "rbxassetid://117517528643201",
		["personBust"] = "rbxassetid://87620323313188",
		["personBustCircle"] = "rbxassetid://79288327836334",
		["personBustCircleFill"] = "rbxassetid://101400531456668",
		["personBustFill"] = "rbxassetid://111810892942700",
		["personCheckmarkAndXmark"] = "rbxassetid://94288741955083",
		["personCircle"] = "rbxassetid://135997814266617",
		["personCircleFill"] = "rbxassetid://90118396547869",
		["personCropArtframe"] = "rbxassetid://90385788840374",
		["personCropBadgeMagnifyingglass"] = "rbxassetid://97394616198512",
		["personCropBadgeMagnifyingglassFill"] = "rbxassetid://132389329009693",
		["personCropCircle"] = "rbxassetid://118995818358156",
		["personCropCircleBadge"] = "rbxassetid://131364710689047",
		["personCropCircleBadgeCheckmark"] = "rbxassetid://103344345950122",
		["personCropCircleBadgeClock"] = "rbxassetid://127451044762338",
		["personCropCircleBadgeClockFill"] = "rbxassetid://76718758852507",
		["personCropCircleBadgeEllipsis"] = "rbxassetid://96642912386901",
		["personCropCircleBadgeEllipsisFill"] = "rbxassetid://88343482632492",
		["personCropCircleBadgeExclamationmark"] = "rbxassetid://139365729353052",
		["personCropCircleBadgeExclamationmarkFill"] = "rbxassetid://109742792874521",
		["personCropCircleBadgeFill"] = "rbxassetid://107018668861828",
		["personCropCircleBadgeMinus"] = "rbxassetid://97855563994788",
		["personCropCircleBadgeMoon"] = "rbxassetid://133337215391424",
		["personCropCircleBadgeMoonFill"] = "rbxassetid://122077316360614",
		["personCropCircleBadgePlus"] = "rbxassetid://81853344224695",
		["personCropCircleBadgeQuestionmark"] = "rbxassetid://139239900008701",
		["personCropCircleBadgeQuestionmarkFill"] = "rbxassetid://99804179170835",
		["personCropCircleBadgeXmark"] = "rbxassetid://91489653759413",
		["personCropCircleDashed"] = "rbxassetid://82498046222304",
		["personCropCircleDashedCircle"] = "rbxassetid://71063283330455",
		["personCropCircleDashedCircleFill"] = "rbxassetid://137889244981033",
		["personCropCircleFill"] = "rbxassetid://124171421403082",
		["personCropCircleFillBadgeCheckmark"] = "rbxassetid://104885997312791",
		["personCropCircleFillBadgeMinus"] = "rbxassetid://81459239482197",
		["personCropCircleFillBadgePlus"] = "rbxassetid://79413393740430",
		["personCropCircleFillBadgeXmark"] = "rbxassetid://75776588765496",
		["personCropRectangle"] = "rbxassetid://80086996421928",
		["personCropRectangleBadgePlus"] = "rbxassetid://102909379035898",
		["personCropRectangleBadgePlusFill"] = "rbxassetid://76635295827459",
		["personCropRectangleFill"] = "rbxassetid://105492427236467",
		["personCropRectangleStack"] = "rbxassetid://100303396427325",
		["personCropRectangleStackFill"] = "rbxassetid://121443905592285",
		["personCropSquare"] = "rbxassetid://73096364605342",
		["personCropSquareBadgeCamera"] = "rbxassetid://135346755645322",
		["personCropSquareBadgeCameraFill"] = "rbxassetid://92729904669185",
		["personCropSquareBadgeVideo"] = "rbxassetid://78518587851789",
		["personCropSquareBadgeVideoFill"] = "rbxassetid://114816625385618",
		["personCropSquareFill"] = "rbxassetid://105841006579983",
		["personCropSquareFilledAndAtRectangle"] = "rbxassetid://118924461813330",
		["personCropSquareFilledAndAtRectangleFill"] = "rbxassetid://80381762756864",
		["personCropSquareOnSquareAngled"] = "rbxassetid://85148546794958",
		["personCropSquareOnSquareAngledFill"] = "rbxassetid://97667541433512",
		["personFill"] = "rbxassetid://87697331384088",
		["personFillAndArrowLeftAndArrowRightOutward"] = "rbxassetid://122634217727119",
		["personFillBadgeMinus"] = "rbxassetid://81924980008824",
		["personFillBadgePlus"] = "rbxassetid://134231365958570",
		["personFillCheckmark"] = "rbxassetid://103977509186960",
		["personFillCheckmarkAndXmark"] = "rbxassetid://101086334574836",
		["personFillQuestionmark"] = "rbxassetid://84568714854237",
		["personFillTurnDown"] = "rbxassetid://138058666704795",
		["personFillTurnLeft"] = "rbxassetid://126438219715870",
		["personFillTurnRight"] = "rbxassetid://78937173520484",
		["personFillViewfinder"] = "rbxassetid://118288055558650",
		["personFillXmark"] = "rbxassetid://125072040338347",
		["personIcloud"] = "rbxassetid://120820184523425",
		["personIcloudFill"] = "rbxassetid://133378049835063",
		["personLineDottedPerson"] = "rbxassetid://102084674613931",
		["personLineDottedPersonFill"] = "rbxassetid://135829432223513",
		["personSlash"] = "rbxassetid://72782294100335",
		["personSlashFill"] = "rbxassetid://121955009050346",
		["personSpatialaudio3dFill"] = "rbxassetid://84698678474801",
		["personSpatialaudioFill"] = "rbxassetid://78014656341517",
		["personSpatialaudioStereo3dFill"] = "rbxassetid://97758734740805",
		["personSpatialaudioStereoFill"] = "rbxassetid://120513790757334",
		["personTextRectangle"] = "rbxassetid://128884463766600",
		["personTextRectangleFill"] = "rbxassetid://137564215419438",
		["personTextRectangleTrianglebadgeExclamationmark"] = "rbxassetid://80430192542431",
		["personTextRectangleTrianglebadgeExclamationmarkFill"] = "rbxassetid://95425946810987",
		["personWave2"] = "rbxassetid://107176133016557",
		["personWave2Fill"] = "rbxassetid://119313962458106",
		["personalhotspot"] = "rbxassetid://100375127059556",
		["personalhotspotCircle"] = "rbxassetid://75798505357181",
		["personalhotspotCircleFill"] = "rbxassetid://91105949987614",
		["personalhotspotSlash"] = "rbxassetid://121054134249173",
		["perspective"] = "rbxassetid://126209555168111",
		["peruviansolessign"] = "rbxassetid://118377143493294",
		["peruviansolessignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://128283504294445",
		["peruviansolessignBankBuilding"] = "rbxassetid://102898750065832",
		["peruviansolessignBankBuildingFill"] = "rbxassetid://74069927107160",
		["peruviansolessignCircle"] = "rbxassetid://73491243272124",
		["peruviansolessignCircleFill"] = "rbxassetid://88303394405719",
		["peruviansolessignGaugeChartLefthalfRighthalf"] = "rbxassetid://95412355379458",
		["peruviansolessignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://105242621393318",
		["peruviansolessignRing"] = "rbxassetid://70902936676598",
		["peruviansolessignRingDashed"] = "rbxassetid://73633708956892",
		["peruviansolessignSquare"] = "rbxassetid://73308117343401",
		["peruviansolessignSquareFill"] = "rbxassetid://102892314110416",
		["pesetasign"] = "rbxassetid://85532413742774",
		["pesetasignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://95814949182701",
		["pesetasignBankBuilding"] = "rbxassetid://70435245510011",
		["pesetasignBankBuildingFill"] = "rbxassetid://76828425934083",
		["pesetasignCircle"] = "rbxassetid://73689448530780",
		["pesetasignCircleFill"] = "rbxassetid://129145068296499",
		["pesetasignGaugeChartLefthalfRighthalf"] = "rbxassetid://135650251052406",
		["pesetasignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://125057752565087",
		["pesetasignRing"] = "rbxassetid://138901454310015",
		["pesetasignRingDashed"] = "rbxassetid://139127402491166",
		["pesetasignSquare"] = "rbxassetid://120082289628623",
		["pesetasignSquareFill"] = "rbxassetid://92637657922110",
		["pesosign"] = "rbxassetid://131506373872953",
		["pesosignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://95176369235434",
		["pesosignBankBuilding"] = "rbxassetid://133065437589460",
		["pesosignBankBuildingFill"] = "rbxassetid://133018359221072",
		["pesosignCircle"] = "rbxassetid://82936186087157",
		["pesosignCircleFill"] = "rbxassetid://122355951938355",
		["pesosignGaugeChartLefthalfRighthalf"] = "rbxassetid://71731520831769",
		["pesosignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://79927907535836",
		["pesosignRing"] = "rbxassetid://96568771428940",
		["pesosignRingDashed"] = "rbxassetid://114760367933760",
		["pesosignSquare"] = "rbxassetid://99221907869730",
		["pesosignSquareFill"] = "rbxassetid://104090017006574",
		["petCarrier"] = "rbxassetid://92747235907572",
		["petCarrierCircle"] = "rbxassetid://89684260845982",
		["petCarrierCircleFill"] = "rbxassetid://136795292748871",
		["petCarrierFill"] = "rbxassetid://118526244393497",
		["phone"] = "rbxassetid://130274090404678",
		["phoneArrowDownLeft"] = "rbxassetid://132462917948039",
		["phoneArrowDownLeftFill"] = "rbxassetid://87805128798557",
		["phoneArrowRight"] = "rbxassetid://72030777597334",
		["phoneArrowRightFill"] = "rbxassetid://121404647674426",
		["phoneArrowUpRight"] = "rbxassetid://79872298851136",
		["phoneArrowUpRightCircle"] = "rbxassetid://70948578186592",
		["phoneArrowUpRightCircleFill"] = "rbxassetid://84134830279781",
		["phoneArrowUpRightFill"] = "rbxassetid://133725301955212",
		["phoneBadgeCheckmark"] = "rbxassetid://133676619626440",
		["phoneBadgeClock"] = "rbxassetid://105195846197897",
		["phoneBadgeClockFill"] = "rbxassetid://76558752952090",
		["phoneBadgePlus"] = "rbxassetid://77530999977499",
		["phoneBadgeWaveform"] = "rbxassetid://82744515131009",
		["phoneBadgeWaveformFill"] = "rbxassetid://115162205181132",
		["phoneBubble"] = "rbxassetid://107177706753542",
		["phoneBubbleFill"] = "rbxassetid://116143288406977",
		["phoneCircle"] = "rbxassetid://99640263570255",
		["phoneCircleFill"] = "rbxassetid://111534598395128",
		["phoneConnection"] = "rbxassetid://107182975371124",
		["phoneConnectionFill"] = "rbxassetid://132948841358108",
		["phoneDown"] = "rbxassetid://102456970457868",
		["phoneDownCircle"] = "rbxassetid://82910023145953",
		["phoneDownCircleFill"] = "rbxassetid://72377511837884",
		["phoneDownFill"] = "rbxassetid://86552310564370",
		["phoneDownWavesLeftAndRight"] = "rbxassetid://136971996615575",
		["phoneFill"] = "rbxassetid://120429135463665",
		["phoneFillBadgeCheckmark"] = "rbxassetid://115261691430286",
		["phoneFillBadgePlus"] = "rbxassetid://87819134346668",
		["phonePause"] = "rbxassetid://134150100031688",
		["phonePauseCircle"] = "rbxassetid://110785714836445",
		["phonePauseCircleFill"] = "rbxassetid://78369532938975",
		["phonePauseFill"] = "rbxassetid://95822352892272",
		["photo"] = "rbxassetid://132914683561588",
		["photoArtframe"] = "rbxassetid://87277781880011",
		["photoArtframeCircle"] = "rbxassetid://130558529142621",
		["photoArtframeCircleFill"] = "rbxassetid://137928811461182",
		["photoBadgeArrowDown"] = "rbxassetid://111884951858150",
		["photoBadgeArrowDownFill"] = "rbxassetid://107871390721167",
		["photoBadgeCheckmark"] = "rbxassetid://87641114310982",
		["photoBadgeCheckmarkFill"] = "rbxassetid://135388635005016",
		["photoBadgeExclamationmark"] = "rbxassetid://85889142841805",
		["photoBadgeExclamationmarkFill"] = "rbxassetid://70564106880729",
		["photoBadgeMagnifyingglass"] = "rbxassetid://135894823011821",
		["photoBadgeMagnifyingglassFill"] = "rbxassetid://104248787134254",
		["photoBadgePlus"] = "rbxassetid://139218119153470",
		["photoBadgePlusFill"] = "rbxassetid://137533733758015",
		["photoBadgeShieldExclamationmark"] = "rbxassetid://93485639865954",
		["photoBadgeShieldExclamationmarkFill"] = "rbxassetid://106649923225765",
		["photoCircle"] = "rbxassetid://82562621732217",
		["photoCircleFill"] = "rbxassetid://94004054038412",
		["photoFill"] = "rbxassetid://111680668639782",
		["photoFillOnRectangleFill"] = "rbxassetid://139880248650794",
		["photoOnRectangle"] = "rbxassetid://74009493246173",
		["photoOnRectangleAngled"] = "rbxassetid://78929588928496",
		["photoOnRectangleAngledFill"] = "rbxassetid://116615960255503",
		["photoStack"] = "rbxassetid://116744098593728",
		["photoStackFill"] = "rbxassetid://136351647084409",
		["photoTrianglebadgeExclamationmark"] = "rbxassetid://127380965749556",
		["photoTrianglebadgeExclamationmarkFill"] = "rbxassetid://138953418202254",
		["photoTv"] = "rbxassetid://83951502842716",
		["pi"] = "rbxassetid://137262054651372",
		["piCircle"] = "rbxassetid://135373869294798",
		["piCircleFill"] = "rbxassetid://120888427088049",
		["piSquare"] = "rbxassetid://87692915899283",
		["piSquareFill"] = "rbxassetid://134420038676982",
		["pianokeys"] = "rbxassetid://100398610027172",
		["pianokeysInverse"] = "rbxassetid://79698280620441",
		["pill"] = "rbxassetid://126278443123311",
		["pillCircle"] = "rbxassetid://113470872116477",
		["pillCircleFill"] = "rbxassetid://102134863235143",
		["pillFill"] = "rbxassetid://118865334913811",
		["pills"] = "rbxassetid://135654600545618",
		["pillsCircle"] = "rbxassetid://101748290464454",
		["pillsCircleFill"] = "rbxassetid://83035294003188",
		["pillsFill"] = "rbxassetid://80480569153430",
		["pin"] = "rbxassetid://134143049313259",
		["pinCircle"] = "rbxassetid://140386216854767",
		["pinCircleFill"] = "rbxassetid://125997437793325",
		["pinFill"] = "rbxassetid://105480877942834",
		["pinSlash"] = "rbxassetid://133152106066233",
		["pinSlashFill"] = "rbxassetid://108270742635671",
		["pinSquare"] = "rbxassetid://96954048377270",
		["pinSquareFill"] = "rbxassetid://119024645426263",
		["pip"] = "rbxassetid://71575912606161",
		["pipEnter"] = "rbxassetid://128947069900942",
		["pipExit"] = "rbxassetid://100796125872672",
		["pipFill"] = "rbxassetid://124361284867478",
		["pipRemove"] = "rbxassetid://124134881366416",
		["pipSwap"] = "rbxassetid://108274050795309",
		["pipeAndDrop"] = "rbxassetid://138939198499930",
		["pipeAndDropFill"] = "rbxassetid://95117828700088",
		["placeholdertextFill"] = "rbxassetid://96792035090493",
		["platter2FilledIpad"] = "rbxassetid://128464213678375",
		["platter2FilledIpadLandscape"] = "rbxassetid://72335641279980",
		["platter2FilledIphone"] = "rbxassetid://137441342349837",
		["platter2FilledIphoneLandscape"] = "rbxassetid://85490241202606",
		["platterBottomApplewatchCase"] = "rbxassetid://89203668651377",
		["platterFilledBottomAndArrowDownIphone"] = "rbxassetid://78340878366169",
		["platterFilledBottomApplewatchCase"] = "rbxassetid://117063618828962",
		["platterFilledBottomIphone"] = "rbxassetid://89570583999672",
		["platterFilledTopAndArrowUpIphone"] = "rbxassetid://140598804745662",
		["platterFilledTopApplewatchCase"] = "rbxassetid://107739762615230",
		["platterFilledTopIphone"] = "rbxassetid://103028129852720",
		["platterTopApplewatchCase"] = "rbxassetid://127796874000587",
		["play"] = "rbxassetid://128461418943884",
		["playCircle"] = "rbxassetid://87454676201433",
		["playCircleFill"] = "rbxassetid://124194494139839",
		["playDesktopcomputer"] = "rbxassetid://74705756726462",
		["playDiamond"] = "rbxassetid://131173183307365",
		["playDiamondFill"] = "rbxassetid://78111564875160",
		["playDisplay"] = "rbxassetid://136301237559742",
		["playFill"] = "rbxassetid://74081916085124",
		["playHouse"] = "rbxassetid://74331836079552",
		["playHouseFill"] = "rbxassetid://70509927496555",
		["playLaptopcomputer"] = "rbxassetid://112462416731590",
		["playRectangle"] = "rbxassetid://132181670569066",
		["playRectangleFill"] = "rbxassetid://123039425293555",
		["playRectangleOnRectangle"] = "rbxassetid://91792326674527",
		["playRectangleOnRectangleCircle"] = "rbxassetid://99863288190795",
		["playRectangleOnRectangleCircleFill"] = "rbxassetid://139424729084085",
		["playRectangleOnRectangleFill"] = "rbxassetid://103121137803119",
		["playSlash"] = "rbxassetid://82231292976761",
		["playSlashFill"] = "rbxassetid://74138387205614",
		["playSquare"] = "rbxassetid://99287717986788",
		["playSquareFill"] = "rbxassetid://100136882189765",
		["playSquareStack"] = "rbxassetid://136134360831800",
		["playSquareStackFill"] = "rbxassetid://77854517062047",
		["playTv"] = "rbxassetid://127415500882482",
		["playTvFill"] = "rbxassetid://124672671078352",
		["playpause"] = "rbxassetid://132431310473376",
		["playpauseCircle"] = "rbxassetid://72027567560609",
		["playpauseCircleFill"] = "rbxassetid://118948449910159",
		["playpauseFill"] = "rbxassetid://107001358735898",
		["playstationLogo"] = "rbxassetid://101885651661801",
		["plus"] = "rbxassetid://104140268501180",
		["plusApp"] = "rbxassetid://134819696943007",
		["plusAppFill"] = "rbxassetid://139827794242362",
		["plusArrowTriangleheadClockwise"] = "rbxassetid://81474708153460",
		["plusArrowTriangleheadCounterclockwise"] = "rbxassetid://90333321199077",
		["plusBubble"] = "rbxassetid://128128287086136",
		["plusBubbleFill"] = "rbxassetid://88837705212786",
		["plusCapsule"] = "rbxassetid://82351860129396",
		["plusCapsuleFill"] = "rbxassetid://104771688220153",
		["plusCircle"] = "rbxassetid://134903849508497",
		["plusCircleDashed"] = "rbxassetid://119427886715979",
		["plusCircleFill"] = "rbxassetid://126835916552120",
		["plusDiamond"] = "rbxassetid://134706332882585",
		["plusDiamondFill"] = "rbxassetid://72471945998883",
		["plusForwardslashMinus"] = "rbxassetid://133024001773788",
		["plusMagnifyingglass"] = "rbxassetid://82229255785570",
		["plusMessage"] = "rbxassetid://139025440106833",
		["plusMessageFill"] = "rbxassetid://114656782830996",
		["plusMinusCapsule"] = "rbxassetid://95862408206488",
		["plusMinusCapsuleFill"] = "rbxassetid://137433402562537",
		["plusRectangle"] = "rbxassetid://89928096593027",
		["plusRectangleFill"] = "rbxassetid://123873894242124",
		["plusRectangleFillOnRectangleFill"] = "rbxassetid://84851475351254",
		["plusRectangleOnFolder"] = "rbxassetid://135314696846977",
		["plusRectangleOnFolderFill"] = "rbxassetid://113831084139629",
		["plusRectangleOnRectangle"] = "rbxassetid://89954508073842",
		["plusRectanglePortrait"] = "rbxassetid://88469415424027",
		["plusRectanglePortraitFill"] = "rbxassetid://88043287673951",
		["plusSquare"] = "rbxassetid://132384125062898",
		["plusSquareDashed"] = "rbxassetid://117358731219699",
		["plusSquareFill"] = "rbxassetid://105523739695601",
		["plusSquareFillOnSquareFill"] = "rbxassetid://102251470244460",
		["plusSquareOnSquare"] = "rbxassetid://112818981162820",
		["plusViewfinder"] = "rbxassetid://84219920382349",
		["plusminus"] = "rbxassetid://131496757526861",
		["plusminusCircle"] = "rbxassetid://75924435734916",
		["plusminusCircleFill"] = "rbxassetid://139932340069454",
		["point3ConnectedTrianglepathDotted"] = "rbxassetid://128994831109851",
		["point3FilledConnectedTrianglepathDotted"] = "rbxassetid://87411273022672",
		["pointBottomleftFilledForwardToPointToprightScurvepath"] = "rbxassetid://72345610995933",
		["pointBottomleftForwardToArrowTriangleScurvepath"] = "rbxassetid://121105380488921",
		["pointBottomleftForwardToArrowTriangleScurvepathFill"] = "rbxassetid://86439950360839",
		["pointBottomleftForwardToArrowTriangleUturnScurvepath"] = "rbxassetid://94608869275416",
		["pointBottomleftForwardToArrowTriangleUturnScurvepathFill"] = "rbxassetid://127677527213790",
		["pointBottomleftForwardToArrowtriangleUturnScurvepath"] = "rbxassetid://137756040106336",
		["pointBottomleftForwardToPointToprightFilledScurvepath"] = "rbxassetid://78467837682881",
		["pointBottomleftForwardToPointToprightScurvepath"] = "rbxassetid://105949443136809",
		["pointBottomleftForwardToPointToprightScurvepathFill"] = "rbxassetid://90155416426752",
		["pointForwardToPointCapsulepath"] = "rbxassetid://79088115694851",
		["pointForwardToPointCapsulepathFill"] = "rbxassetid://133249842443694",
		["pointTopleftDownToPointBottomrightCurvepath"] = "rbxassetid://96359498330738",
		["pointTopleftDownToPointBottomrightCurvepathFill"] = "rbxassetid://131034155006095",
		["pointTopleftDownToPointBottomrightFilledCurvepath"] = "rbxassetid://109330439433857",
		["pointTopleftFilledDownToPointBottomrightCurvepath"] = "rbxassetid://119244357459528",
		["pointToprightArrowTriangleBackwardToPointBottomleftFilledScurvepath"] = "rbxassetid://125761722930816",
		["pointToprightArrowTriangleBackwardToPointBottomleftScurvepath"] = "rbxassetid://101374675671818",
		["pointToprightArrowTriangleBackwardToPointBottomleftScurvepathFill"] = "rbxassetid://95471389312772",
		["pointToprightFilledArrowTriangleBackwardToPointBottomleftScurvepath"] = "rbxassetid://106008918139871",
		["pointerArrow"] = "rbxassetid://93575391711601",
		["pointerArrowAndSquareOnSquareDashed"] = "rbxassetid://112982475519464",
		["pointerArrowClick"] = "rbxassetid://79734702283129",
		["pointerArrowClick2"] = "rbxassetid://140079580041973",
		["pointerArrowClickBadgeClock"] = "rbxassetid://87250670163722",
		["pointerArrowIpad"] = "rbxassetid://98232849648450",
		["pointerArrowIpadAndSquareOnSquareDashed"] = "rbxassetid://108327718703042",
		["pointerArrowIpadRays"] = "rbxassetid://137810650560332",
		["pointerArrowIpadSlash"] = "rbxassetid://82866450058915",
		["pointerArrowIpadSlashSquare"] = "rbxassetid://84816174673121",
		["pointerArrowIpadSlashSquareFill"] = "rbxassetid://75197308300656",
		["pointerArrowIpadSquare"] = "rbxassetid://82086279301281",
		["pointerArrowIpadSquareFill"] = "rbxassetid://128704735814595",
		["pointerArrowMotionlines"] = "rbxassetid://82915304520768",
		["pointerArrowMotionlinesClick"] = "rbxassetid://120030717856082",
		["pointerArrowRays"] = "rbxassetid://122560061254398",
		["pointerArrowSlash"] = "rbxassetid://115758764584094",
		["pointerArrowSlashSquare"] = "rbxassetid://94514670924898",
		["pointerArrowSlashSquareFill"] = "rbxassetid://90831995454066",
		["pointerArrowSquare"] = "rbxassetid://123890299712468",
		["pointerArrowSquareFill"] = "rbxassetid://118743928429611",
		["polishzlotysign"] = "rbxassetid://71190576997998",
		["polishzlotysignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://139116746882232",
		["polishzlotysignBankBuilding"] = "rbxassetid://103554770878168",
		["polishzlotysignBankBuildingFill"] = "rbxassetid://100219158970095",
		["polishzlotysignCircle"] = "rbxassetid://133425103954783",
		["polishzlotysignCircleFill"] = "rbxassetid://85302846852426",
		["polishzlotysignGaugeChartLefthalfRighthalf"] = "rbxassetid://112861300466078",
		["polishzlotysignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://91379228929120",
		["polishzlotysignRing"] = "rbxassetid://115900998535144",
		["polishzlotysignRingDashed"] = "rbxassetid://133083266308972",
		["polishzlotysignSquare"] = "rbxassetid://116010000718053",
		["polishzlotysignSquareFill"] = "rbxassetid://126842829605701",
		["popcorn"] = "rbxassetid://106164924042161",
		["popcornCircle"] = "rbxassetid://132014547567987",
		["popcornCircleFill"] = "rbxassetid://70873676213803",
		["popcornFill"] = "rbxassetid://133726972459236",
		["power"] = "rbxassetid://91472904792853",
		["powerCircle"] = "rbxassetid://128963948777063",
		["powerCircleFill"] = "rbxassetid://88039046868989",
		["powerDotted"] = "rbxassetid://129852471510614",
		["powercord"] = "rbxassetid://101999056711715",
		["powercordFill"] = "rbxassetid://94896872366691",
		["powermeter"] = "rbxassetid://102108395105231",
		["poweroff"] = "rbxassetid://98968411908379",
		["poweron"] = "rbxassetid://91641740625722",
		["poweroutletStrip"] = "rbxassetid://73585415920677",
		["poweroutletStripFill"] = "rbxassetid://74011653309219",
		["poweroutletTypeA"] = "rbxassetid://73898196043019",
		["poweroutletTypeAFill"] = "rbxassetid://126838690734726",
		["poweroutletTypeASquare"] = "rbxassetid://100201655940379",
		["poweroutletTypeASquareFill"] = "rbxassetid://134442831578984",
		["poweroutletTypeB"] = "rbxassetid://120104867205082",
		["poweroutletTypeBFill"] = "rbxassetid://102950626262427",
		["poweroutletTypeBSquare"] = "rbxassetid://126307738972122",
		["poweroutletTypeBSquareFill"] = "rbxassetid://114873968799324",
		["poweroutletTypeC"] = "rbxassetid://98862353177781",
		["poweroutletTypeCFill"] = "rbxassetid://79114190266484",
		["poweroutletTypeCSquare"] = "rbxassetid://108182409003389",
		["poweroutletTypeCSquareFill"] = "rbxassetid://105015853211076",
		["poweroutletTypeD"] = "rbxassetid://78983099018117",
		["poweroutletTypeDFill"] = "rbxassetid://131871506048623",
		["poweroutletTypeDSquare"] = "rbxassetid://78796990769278",
		["poweroutletTypeDSquareFill"] = "rbxassetid://117146065393423",
		["poweroutletTypeE"] = "rbxassetid://101410063610134",
		["poweroutletTypeEFill"] = "rbxassetid://119773723139439",
		["poweroutletTypeESquare"] = "rbxassetid://84827194983461",
		["poweroutletTypeESquareFill"] = "rbxassetid://131818068004254",
		["poweroutletTypeF"] = "rbxassetid://75994498593867",
		["poweroutletTypeFFill"] = "rbxassetid://108147822804278",
		["poweroutletTypeFSquare"] = "rbxassetid://114669882203509",
		["poweroutletTypeFSquareFill"] = "rbxassetid://129347734091030",
		["poweroutletTypeG"] = "rbxassetid://130509534014794",
		["poweroutletTypeGFill"] = "rbxassetid://73751279322201",
		["poweroutletTypeGSquare"] = "rbxassetid://132654111874788",
		["poweroutletTypeGSquareFill"] = "rbxassetid://139171546199909",
		["poweroutletTypeH"] = "rbxassetid://121221625495909",
		["poweroutletTypeHFill"] = "rbxassetid://104469280742634",
		["poweroutletTypeHSquare"] = "rbxassetid://102349433186821",
		["poweroutletTypeHSquareFill"] = "rbxassetid://87225476098525",
		["poweroutletTypeI"] = "rbxassetid://108432173595940",
		["poweroutletTypeIFill"] = "rbxassetid://90953576052611",
		["poweroutletTypeISquare"] = "rbxassetid://85563920583968",
		["poweroutletTypeISquareFill"] = "rbxassetid://92987652110826",
		["poweroutletTypeJ"] = "rbxassetid://126517587735560",
		["poweroutletTypeJFill"] = "rbxassetid://70372330202631",
		["poweroutletTypeJSquare"] = "rbxassetid://108455386185985",
		["poweroutletTypeJSquareFill"] = "rbxassetid://110671250365058",
		["poweroutletTypeK"] = "rbxassetid://90986976673417",
		["poweroutletTypeKFill"] = "rbxassetid://104105946842300",
		["poweroutletTypeKSquare"] = "rbxassetid://71665389391339",
		["poweroutletTypeKSquareFill"] = "rbxassetid://100252749143408",
		["poweroutletTypeL"] = "rbxassetid://102082292598917",
		["poweroutletTypeLFill"] = "rbxassetid://95679765765332",
		["poweroutletTypeLSquare"] = "rbxassetid://101581018956257",
		["poweroutletTypeLSquareFill"] = "rbxassetid://108089600610800",
		["poweroutletTypeM"] = "rbxassetid://77038437139981",
		["poweroutletTypeMFill"] = "rbxassetid://102565240968296",
		["poweroutletTypeMSquare"] = "rbxassetid://137482102637754",
		["poweroutletTypeMSquareFill"] = "rbxassetid://101061604726738",
		["poweroutletTypeN"] = "rbxassetid://131231933791747",
		["poweroutletTypeNFill"] = "rbxassetid://122521914168552",
		["poweroutletTypeNSquare"] = "rbxassetid://88193045014774",
		["poweroutletTypeNSquareFill"] = "rbxassetid://117707236613750",
		["poweroutletTypeO"] = "rbxassetid://71518035241990",
		["poweroutletTypeOFill"] = "rbxassetid://124355652039674",
		["poweroutletTypeOSquare"] = "rbxassetid://93155191747385",
		["poweroutletTypeOSquareFill"] = "rbxassetid://75876768217678",
		["powerplug"] = "rbxassetid://113915951601980",
		["powerplugFill"] = "rbxassetid://72971139891393",
		["powerplugPortrait"] = "rbxassetid://134444701296189",
		["powerplugPortraitFill"] = "rbxassetid://129569799503764",
		["powersleep"] = "rbxassetid://136441993961962",
		["printer"] = "rbxassetid://92726076996600",
		["printerDotmatrix"] = "rbxassetid://71926967169220",
		["printerDotmatrixFill"] = "rbxassetid://87728661853490",
		["printerDotmatrixFilledAndPaper"] = "rbxassetid://105425549423600",
		["printerDotmatrixFilledAndPaperInverse"] = "rbxassetid://74443986062725",
		["printerDotmatrixInverse"] = "rbxassetid://91372868092556",
		["printerFill"] = "rbxassetid://77630139933554",
		["printerFilledAndPaper"] = "rbxassetid://97682473483014",
		["printerFilledAndPaperInverse"] = "rbxassetid://137162835775605",
		["printerInverse"] = "rbxassetid://96106141032867",
		["progressIndicator"] = "rbxassetid://89634242697334",
		["projective"] = "rbxassetid://73010755604065",
		["purchased"] = "rbxassetid://89342661938554",
		["purchasedCircle"] = "rbxassetid://119930548891031",
		["purchasedCircleFill"] = "rbxassetid://125749909647263",
		["puzzlepiece"] = "rbxassetid://127623471300702",
		["puzzlepieceExtension"] = "rbxassetid://106644636346231",
		["puzzlepieceExtensionFill"] = "rbxassetid://75203726915481",
		["puzzlepieceFill"] = "rbxassetid://117289958016840",
		["pyramid"] = "rbxassetid://112564763709051",
		["pyramidFill"] = "rbxassetid://92297972398994",
		["qCircle"] = "rbxassetid://134479590621303",
		["qCircleFill"] = "rbxassetid://85104022920098",
		["qSquare"] = "rbxassetid://126798899208180",
		["qSquareFill"] = "rbxassetid://131372232713091",
		["qrcode"] = "rbxassetid://135429731093760",
		["qrcodeViewfinder"] = "rbxassetid://70376735626959",
		["questionmark"] = "rbxassetid://135728947505125",
		["questionmarkApp"] = "rbxassetid://125486303792695",
		["questionmarkAppDashed"] = "rbxassetid://93908191503686",
		["questionmarkAppFill"] = "rbxassetid://132390651792916",
		["questionmarkBubble"] = "rbxassetid://79680750661243",
		["questionmarkBubbleFill"] = "rbxassetid://109480620904091",
		["questionmarkCircle"] = "rbxassetid://106563268903746",
		["questionmarkCircleDashed"] = "rbxassetid://90578083008627",
		["questionmarkCircleFill"] = "rbxassetid://84091622533619",
		["questionmarkDiamond"] = "rbxassetid://133039366755179",
		["questionmarkDiamondFill"] = "rbxassetid://96713509421435",
		["questionmarkFolder"] = "rbxassetid://123509903209077",
		["questionmarkFolderFill"] = "rbxassetid://109535614084769",
		["questionmarkKeyFilled"] = "rbxassetid://115154856009498",
		["questionmarkMessage"] = "rbxassetid://120735530943822",
		["questionmarkMessageFill"] = "rbxassetid://138648428289642",
		["questionmarkSquare"] = "rbxassetid://80342776780001",
		["questionmarkSquareDashed"] = "rbxassetid://100367436719082",
		["questionmarkSquareFill"] = "rbxassetid://76990513345923",
		["questionmarkTextPage"] = "rbxassetid://77522269508702",
		["questionmarkTextPageFill"] = "rbxassetid://74250116725322",
		["questionmarkVideo"] = "rbxassetid://96965650538855",
		["questionmarkVideoFill"] = "rbxassetid://102872787704052",
		["quoteBubble"] = "rbxassetid://120785470678014",
		["quoteBubbleFill"] = "rbxassetid://134548894341595",
		["quoteClosing"] = "rbxassetid://128300262716157",
		["quoteOpening"] = "rbxassetid://85648900225966",
		["quotelevel"] = "rbxassetid://133835140047628",
		["r1ButtonRoundedbottomHorizontal"] = "rbxassetid://73494380889514",
		["r1ButtonRoundedbottomHorizontalFill"] = "rbxassetid://87732102079281",
		["r1Circle"] = "rbxassetid://135769834088860",
		["r1CircleFill"] = "rbxassetid://130502350729327",
		["r2ButtonAngledtopVerticalRight"] = "rbxassetid://133768730605538",
		["r2ButtonAngledtopVerticalRightFill"] = "rbxassetid://88773533237354",
		["r2ButtonRoundedtopHorizontal"] = "rbxassetid://98251601517278",
		["r2ButtonRoundedtopHorizontalFill"] = "rbxassetid://106192967203243",
		["r2Circle"] = "rbxassetid://106631267824223",
		["r2CircleFill"] = "rbxassetid://132126702469862",
		["r3ButtonAngledbottomHorizontalRight"] = "rbxassetid://137304943113639",
		["r3ButtonAngledbottomHorizontalRightFill"] = "rbxassetid://89807708696162",
		["r4ButtonHorizontal"] = "rbxassetid://101176118558083",
		["r4ButtonHorizontalFill"] = "rbxassetid://111110114987717",
		["rButtonRoundedbottomHorizontal"] = "rbxassetid://106791314037092",
		["rButtonRoundedbottomHorizontalFill"] = "rbxassetid://127088507444504",
		["rCircle"] = "rbxassetid://100474397953607",
		["rCircleFill"] = "rbxassetid://109515288026300",
		["rJoystick"] = "rbxassetid://82799323747888",
		["rJoystickFill"] = "rbxassetid://88376161432211",
		["rJoystickPressDown"] = "rbxassetid://130205975134988",
		["rJoystickPressDownFill"] = "rbxassetid://82709360617451",
		["rJoystickTiltDown"] = "rbxassetid://125350323338775",
		["rJoystickTiltDownFill"] = "rbxassetid://122451980946728",
		["rJoystickTiltLeft"] = "rbxassetid://100163992653880",
		["rJoystickTiltLeftFill"] = "rbxassetid://126371751528008",
		["rJoystickTiltRight"] = "rbxassetid://73216566650577",
		["rJoystickTiltRightFill"] = "rbxassetid://95154512055976",
		["rJoystickTiltUp"] = "rbxassetid://89422740003979",
		["rJoystickTiltUpFill"] = "rbxassetid://124671519494711",
		["rSquare"] = "rbxassetid://71910946326643",
		["rSquareFill"] = "rbxassetid://93196796932773",
		["rSquareOnSquare"] = "rbxassetid://107811193096025",
		["rSquareOnSquareFill"] = "rbxassetid://113609306294519",
		["radio"] = "rbxassetid://83922658753052",
		["radioFill"] = "rbxassetid://122048912816887",
		["rainbow"] = "rbxassetid://91453713893762",
		["rays"] = "rbxassetid://82549830905060",
		["rbButtonRoundedbottomHorizontal"] = "rbxassetid://99388233415918",
		["rbButtonRoundedbottomHorizontalFill"] = "rbxassetid://115801079364851",
		["rbCircle"] = "rbxassetid://138035345745553",
		["rbCircleFill"] = "rbxassetid://101169325937487",
		["receipt"] = "rbxassetid://76381361847492",
		["receiptFill"] = "rbxassetid://89891989598979",
		["recordCircle"] = "rbxassetid://108217106941598",
		["recordCircleFill"] = "rbxassetid://105698081236112",
		["recordingtape"] = "rbxassetid://127308726768030",
		["recordingtapeCircle"] = "rbxassetid://104143200089711",
		["recordingtapeCircleFill"] = "rbxassetid://80198600120854",
		["rectangle"] = "rbxassetid://111414459754261",
		["rectangle2Swap"] = "rbxassetid://131330634853965",
		["rectangle3Group"] = "rbxassetid://135787395657285",
		["rectangle3GroupBubble"] = "rbxassetid://116160459807032",
		["rectangle3GroupBubbleFill"] = "rbxassetid://139621481371395",
		["rectangle3GroupDashed"] = "rbxassetid://110904729324036",
		["rectangle3GroupFill"] = "rbxassetid://93139300368934",
		["rectangleAndArrowUpRightAndArrowDownLeft"] = "rbxassetid://93638105367907",
		["rectangleAndArrowUpRightAndArrowDownLeftSlash"] = "rbxassetid://106369518263199",
		["rectangleAndHandPointUpLeft"] = "rbxassetid://93683011357377",
		["rectangleAndHandPointUpLeftFill"] = "rbxassetid://99025075004423",
		["rectangleAndHandPointUpLeftFilled"] = "rbxassetid://76034474354386",
		["rectangleAndPaperclip"] = "rbxassetid://105337301519485",
		["rectangleAndPencilAndEllipsis"] = "rbxassetid://78563329334131",
		["rectangleAndTextMagnifyingglass"] = "rbxassetid://127177835398113",
		["rectangleArrowtriangle2Inward"] = "rbxassetid://138600951302016",
		["rectangleArrowtriangle2Outward"] = "rbxassetid://136346043617802",
		["rectangleBadgeCheckmark"] = "rbxassetid://72076028531820",
		["rectangleBadgeMinus"] = "rbxassetid://102402218146653",
		["rectangleBadgePersonCrop"] = "rbxassetid://70527611658257",
		["rectangleBadgePlus"] = "rbxassetid://106486906660779",
		["rectangleBadgeXmark"] = "rbxassetid://108083111117375",
		["rectangleBottomhalfFilled"] = "rbxassetid://101103984667014",
		["rectangleCheckered"] = "rbxassetid://93153326915076",
		["rectangleCompressVertical"] = "rbxassetid://121411068286936",
		["rectangleConnectedToLineBelow"] = "rbxassetid://77423923606068",
		["rectangleDashed"] = "rbxassetid://138713016735236",
		["rectangleDashedAndPaperclip"] = "rbxassetid://110455441885522",
		["rectangleDashedBadgeRecord"] = "rbxassetid://128289633292737",
		["rectangleExpandDiagonal"] = "rbxassetid://122288568531399",
		["rectangleExpandVertical"] = "rbxassetid://115245648914946",
		["rectangleFill"] = "rbxassetid://130588385351314",
		["rectangleFillBadgeCheckmark"] = "rbxassetid://101292450070677",
		["rectangleFillBadgeMinus"] = "rbxassetid://87052252529460",
		["rectangleFillBadgePersonCrop"] = "rbxassetid://79555531925800",
		["rectangleFillBadgePlus"] = "rbxassetid://78893754793162",
		["rectangleFillBadgeXmark"] = "rbxassetid://103536021556291",
		["rectangleFillOnRectangleAngledFill"] = "rbxassetid://91215625396644",
		["rectangleFillOnRectangleFill"] = "rbxassetid://138672467195296",
		["rectangleFilledAndHandPointUpLeft"] = "rbxassetid://129165814821096",
		["rectangleGrid1x2"] = "rbxassetid://90808025440357",
		["rectangleGrid1x2Fill"] = "rbxassetid://73911101625046",
		["rectangleGrid1x3"] = "rbxassetid://117353042982000",
		["rectangleGrid1x3Fill"] = "rbxassetid://111448923249339",
		["rectangleGrid2x2"] = "rbxassetid://92889258947698",
		["rectangleGrid2x2Fill"] = "rbxassetid://79589884272899",
		["rectangleGrid3x1"] = "rbxassetid://76689994608928",
		["rectangleGrid3x1Fill"] = "rbxassetid://131318740621070",
		["rectangleGrid3x2"] = "rbxassetid://137686973180621",
		["rectangleGrid3x2Fill"] = "rbxassetid://76899837809257",
		["rectangleGrid3x3"] = "rbxassetid://111445407298994",
		["rectangleGrid3x3Fill"] = "rbxassetid://117660783834604",
		["rectangleInsetBadgeRecord"] = "rbxassetid://80945153582789",
		["rectangleLandscapeRotate"] = "rbxassetid://92428477483439",
		["rectangleLandscapeRotateSlash"] = "rbxassetid://82008920679309",
		["rectangleLeadinghalfFilled"] = "rbxassetid://79972096403571",
		["rectangleLefthalfFilled"] = "rbxassetid://131457794136852",
		["rectangleOnRectangle"] = "rbxassetid://125190929833969",
		["rectangleOnRectangleAngled"] = "rbxassetid://122398141357009",
		["rectangleOnRectangleBadgeGearshape"] = "rbxassetid://101252695124574",
		["rectangleOnRectangleButtonAngledtopVerticalLeft"] = "rbxassetid://124890917881545",
		["rectangleOnRectangleButtonAngledtopVerticalLeftFill"] = "rbxassetid://122574969411469",
		["rectangleOnRectangleCircle"] = "rbxassetid://73017118558797",
		["rectangleOnRectangleCircleFill"] = "rbxassetid://106477109606197",
		["rectangleOnRectangleDashed"] = "rbxassetid://100408401861363",
		["rectangleOnRectangleSlash"] = "rbxassetid://77613589607929",
		["rectangleOnRectangleSlashCircle"] = "rbxassetid://91428157222160",
		["rectangleOnRectangleSlashCircleFill"] = "rbxassetid://140066340357199",
		["rectangleOnRectangleSlashFill"] = "rbxassetid://79680969346171",
		["rectangleOnRectangleSquare"] = "rbxassetid://71711185277015",
		["rectangleOnRectangleSquareFill"] = "rbxassetid://80274524367727",
		["rectanglePatternCheckered"] = "rbxassetid://107724057059604",
		["rectanglePortrait"] = "rbxassetid://125236374031015",
		["rectanglePortraitAndArrowForward"] = "rbxassetid://120445430817911",
		["rectanglePortraitAndArrowForwardFill"] = "rbxassetid://91657691983927",
		["rectanglePortraitAndArrowRight"] = "rbxassetid://78586132872195",
		["rectanglePortraitAndArrowRightFill"] = "rbxassetid://100165849200729",
		["rectanglePortraitArrowtriangle2Inward"] = "rbxassetid://140269657314813",
		["rectanglePortraitArrowtriangle2Outward"] = "rbxassetid://137195383116487",
		["rectanglePortraitBadgePlus"] = "rbxassetid://98290274050547",
		["rectanglePortraitBadgePlusFill"] = "rbxassetid://122337836606239",
		["rectanglePortraitBottomhalfFilled"] = "rbxassetid://114165508753177",
		["rectanglePortraitFill"] = "rbxassetid://98444426893441",
		["rectanglePortraitLefthalfFilled"] = "rbxassetid://118614403436193",
		["rectanglePortraitOnRectanglePortrait"] = "rbxassetid://88124841316261",
		["rectanglePortraitOnRectanglePortraitAngled"] = "rbxassetid://100172422875638",
		["rectanglePortraitOnRectanglePortraitAngledFill"] = "rbxassetid://131829103874258",
		["rectanglePortraitOnRectanglePortraitFill"] = "rbxassetid://90599203086952",
		["rectanglePortraitOnRectanglePortraitSlash"] = "rbxassetid://91665771440270",
		["rectanglePortraitOnRectanglePortraitSlashFill"] = "rbxassetid://109451249077103",
		["rectanglePortraitRighthalfFilled"] = "rbxassetid://100066536343390",
		["rectanglePortraitRotate"] = "rbxassetid://81490858477590",
		["rectanglePortraitRotateSlash"] = "rbxassetid://114808604031742",
		["rectanglePortraitSlash"] = "rbxassetid://72406543095141",
		["rectanglePortraitSlashFill"] = "rbxassetid://136630733879613",
		["rectanglePortraitSplit2x1"] = "rbxassetid://87323130284872",
		["rectanglePortraitSplit2x1Fill"] = "rbxassetid://85586482314976",
		["rectanglePortraitSplit2x1Slash"] = "rbxassetid://118538465517234",
		["rectanglePortraitSplit2x1SlashFill"] = "rbxassetid://103708519113694",
		["rectanglePortraitTophalfFilled"] = "rbxassetid://108433047247888",
		["rectangleRatio16To9"] = "rbxassetid://137417821446334",
		["rectangleRatio16To9Fill"] = "rbxassetid://88975270022668",
		["rectangleRatio3To4"] = "rbxassetid://80074563926947",
		["rectangleRatio3To4Fill"] = "rbxassetid://93688722112538",
		["rectangleRatio4To3"] = "rbxassetid://113646253383623",
		["rectangleRatio4To3Fill"] = "rbxassetid://118821190872382",
		["rectangleRatio9To16"] = "rbxassetid://78790871575968",
		["rectangleRatio9To16Fill"] = "rbxassetid://86914887040905",
		["rectangleRighthalfFilled"] = "rbxassetid://114536690093297",
		["rectangleSlash"] = "rbxassetid://93912868038495",
		["rectangleSlashFill"] = "rbxassetid://125060844525663",
		["rectangleSplit1x2"] = "rbxassetid://78612147332368",
		["rectangleSplit1x2Fill"] = "rbxassetid://80761667288444",
		["rectangleSplit2x1"] = "rbxassetid://119372955276022",
		["rectangleSplit2x1Fill"] = "rbxassetid://139921639891469",
		["rectangleSplit2x1Slash"] = "rbxassetid://104484575664164",
		["rectangleSplit2x1SlashFill"] = "rbxassetid://114315803976014",
		["rectangleSplit2x2"] = "rbxassetid://83495194872523",
		["rectangleSplit2x2Fill"] = "rbxassetid://114784847338074",
		["rectangleSplit3x1"] = "rbxassetid://105846009511841",
		["rectangleSplit3x1Fill"] = "rbxassetid://113328142141984",
		["rectangleSplit3x3"] = "rbxassetid://78793707576857",
		["rectangleSplit3x3Fill"] = "rbxassetid://78131312150919",
		["rectangleStack"] = "rbxassetid://105605876322301",
		["rectangleStackBadgeMinus"] = "rbxassetid://127965533772535",
		["rectangleStackBadgePersonCrop"] = "rbxassetid://129251589155547",
		["rectangleStackBadgePersonCropFill"] = "rbxassetid://79977200721454",
		["rectangleStackBadgePlay"] = "rbxassetid://103484646951126",
		["rectangleStackBadgePlayFill"] = "rbxassetid://74796728731284",
		["rectangleStackBadgePlus"] = "rbxassetid://79107569318116",
		["rectangleStackFill"] = "rbxassetid://135855303627369",
		["rectangleStackFillBadgeMinus"] = "rbxassetid://107768535623331",
		["rectangleStackFillBadgePlus"] = "rbxassetid://97606185836694",
		["rectangleStackSlash"] = "rbxassetid://104855023839912",
		["rectangleStackSlashFill"] = "rbxassetid://94713737257399",
		["rectangleTophalfFilled"] = "rbxassetid://116794907916061",
		["rectangleTrailinghalfFilled"] = "rbxassetid://116099294996666",
		["refrigerator"] = "rbxassetid://115470198294720",
		["refrigeratorFill"] = "rbxassetid://91481483660716",
		["repeat"] = "rbxassetid://89312130153366",
		["repeat1"] = "rbxassetid://95914998265758",
		["repeat1Circle"] = "rbxassetid://125048734108902",
		["repeat1CircleFill"] = "rbxassetid://103291311712495",
		["repeatBadgeXmark"] = "rbxassetid://136313092066440",
		["repeatCircle"] = "rbxassetid://103368260994746",
		["repeatCircleFill"] = "rbxassetid://75689548597847",
		["repeatGlyph"] = "rbxassetid://94715683784128",
		["restart"] = "rbxassetid://79478375893990",
		["restartCircle"] = "rbxassetid://74213777320248",
		["restartCircleFill"] = "rbxassetid://93709981958260",
		["retarderBrakesignal"] = "rbxassetid://116812543667964",
		["retarderBrakesignalAndExclamationmark"] = "rbxassetid://128582163780524",
		["retarderBrakesignalSlash"] = "rbxassetid://91774982651852",
		["return"] = "rbxassetid://93686227671158",
		["returnGlyph"] = "rbxassetid://125022377592914",
		["returnLeft"] = "rbxassetid://110666344633227",
		["returnRight"] = "rbxassetid://125304385375369",
		["rhombus"] = "rbxassetid://130322524489833",
		["rhombusFill"] = "rbxassetid://137003561050469",
		["richtextPage"] = "rbxassetid://101913089792940",
		["richtextPageFill"] = "rbxassetid://120660865942330",
		["right"] = "rbxassetid://93581059929312",
		["rightCircle"] = "rbxassetid://126673356006020",
		["rightCircleFill"] = "rbxassetid://107888523128870",
		["righttriangle"] = "rbxassetid://98781907340244",
		["righttriangleFill"] = "rbxassetid://97751299193494",
		["righttriangleSplitDiagonal"] = "rbxassetid://140267826439171",
		["righttriangleSplitDiagonalFill"] = "rbxassetid://134486346049833",
		["ring"] = "rbxassetid://134891574217355",
		["ringDashed"] = "rbxassetid://79016816094406",
		["rmButtonHorizontal"] = "rbxassetid://112649649945799",
		["rmButtonHorizontalFill"] = "rbxassetid://101555031791001",
		["roadLaneArrowtriangle2Inward"] = "rbxassetid://83028812738091",
		["roadLaneArrowtriangle2Outward"] = "rbxassetid://125107735583240",
		["roadLanes"] = "rbxassetid://121827579804737",
		["roadLanesCurvedLeft"] = "rbxassetid://114689746540833",
		["roadLanesCurvedRight"] = "rbxassetid://76090752203397",
		["roboticVacuum"] = "rbxassetid://85432635849466",
		["roboticVacuumAndArrowtriangleUp"] = "rbxassetid://99360183176046",
		["roboticVacuumAndArrowtriangleUpFill"] = "rbxassetid://133281032251829",
		["roboticVacuumAndEllipsis"] = "rbxassetid://133526596908702",
		["roboticVacuumAndEllipsisFill"] = "rbxassetid://71988250367062",
		["roboticVacuumFill"] = "rbxassetid://129505593002521",
		["rollerShadeClosed"] = "rbxassetid://104900591917665",
		["rollerShadeOpen"] = "rbxassetid://88571033999479",
		["romanShadeClosed"] = "rbxassetid://96918750802866",
		["romanShadeOpen"] = "rbxassetid://90499680966105",
		["rosette"] = "rbxassetid://128397706826097",
		["rotate3d"] = "rbxassetid://79997216476659",
		["rotate3dCircle"] = "rbxassetid://134023839176423",
		["rotate3dCircleFill"] = "rbxassetid://136024177936496",
		["rotate3dFill"] = "rbxassetid://140259573440265",
		["rotateLeft"] = "rbxassetid://104293817458403",
		["rotateLeftFill"] = "rbxassetid://108834532920454",
		["rotateRight"] = "rbxassetid://101811576269464",
		["rotateRightFill"] = "rbxassetid://132494268034794",
		["rsbButtonAngledbottomHorizontalRight"] = "rbxassetid://104443343478623",
		["rsbButtonAngledbottomHorizontalRightFill"] = "rbxassetid://105946161113872",
		["rtButtonRoundedtopHorizontal"] = "rbxassetid://88197217150788",
		["rtButtonRoundedtopHorizontalFill"] = "rbxassetid://137834814026503",
		["rtCircle"] = "rbxassetid://130736157262549",
		["rtCircleFill"] = "rbxassetid://90688963975051",
		["rublesign"] = "rbxassetid://79995340276002",
		["rublesignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://107533533773481",
		["rublesignBankBuilding"] = "rbxassetid://112367554211189",
		["rublesignBankBuildingFill"] = "rbxassetid://74276645461175",
		["rublesignCircle"] = "rbxassetid://138616838615062",
		["rublesignCircleFill"] = "rbxassetid://117918611348729",
		["rublesignGaugeChartLefthalfRighthalf"] = "rbxassetid://121997111268342",
		["rublesignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://124825936849158",
		["rublesignRing"] = "rbxassetid://102327958941047",
		["rublesignRingDashed"] = "rbxassetid://127403954235716",
		["rublesignSquare"] = "rbxassetid://93428290716501",
		["rublesignSquareFill"] = "rbxassetid://91069416883880",
		["rugbyball"] = "rbxassetid://107813412868735",
		["rugbyballCircle"] = "rbxassetid://74520104438728",
		["rugbyballCircleFill"] = "rbxassetid://132264267384386",
		["rugbyballFill"] = "rbxassetid://133697647276958",
		["ruler"] = "rbxassetid://137893325259884",
		["rulerFill"] = "rbxassetid://95614061471677",
		["rupeesign"] = "rbxassetid://109206009121524",
		["rupeesignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://128550816369153",
		["rupeesignBankBuilding"] = "rbxassetid://105737039771832",
		["rupeesignBankBuildingFill"] = "rbxassetid://131896695518623",
		["rupeesignCircle"] = "rbxassetid://131458084468081",
		["rupeesignCircleFill"] = "rbxassetid://76182665186164",
		["rupeesignGaugeChartLefthalfRighthalf"] = "rbxassetid://125393632929329",
		["rupeesignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://96777336576753",
		["rupeesignRing"] = "rbxassetid://125467764440847",
		["rupeesignRingDashed"] = "rbxassetid://82381851316657",
		["rupeesignSquare"] = "rbxassetid://111461203852733",
		["rupeesignSquareFill"] = "rbxassetid://108460282949877",
		["sCircle"] = "rbxassetid://70797943728324",
		["sCircleFill"] = "rbxassetid://114752832731487",
		["sSquare"] = "rbxassetid://97768874847459",
		["sSquareFill"] = "rbxassetid://124722554149961",
		["safari"] = "rbxassetid://76428111544714",
		["safariFill"] = "rbxassetid://85821469115818",
		["sailboat"] = "rbxassetid://99246226977355",
		["sailboatCircle"] = "rbxassetid://92706155026002",
		["sailboatCircleFill"] = "rbxassetid://119525831244370",
		["sailboatFill"] = "rbxassetid://125556225154215",
		["scale3d"] = "rbxassetid://116105033501936",
		["scalemass"] = "rbxassetid://117780975283623",
		["scalemassFill"] = "rbxassetid://78891902031658",
		["scanner"] = "rbxassetid://73017296718236",
		["scannerFill"] = "rbxassetid://86721241098861",
		["scissors"] = "rbxassetid://95513121521151",
		["scissorsBadgeEllipsis"] = "rbxassetid://116175702980810",
		["scissorsCircle"] = "rbxassetid://100442513150877",
		["scissorsCircleFill"] = "rbxassetid://133071884128532",
		["scooter"] = "rbxassetid://106371037983152",
		["scope"] = "rbxassetid://114797558688010",
		["screwdriver"] = "rbxassetid://128552531928875",
		["screwdriverFill"] = "rbxassetid://111697095003710",
		["scribble"] = "rbxassetid://73635938346366",
		["scribbleVariable"] = "rbxassetid://95857213844977",
		["scroll"] = "rbxassetid://100024126240372",
		["scrollFill"] = "rbxassetid://86513801307528",
		["sdcard"] = "rbxassetid://91999340306150",
		["sdcardFill"] = "rbxassetid://86816824579142",
		["seal"] = "rbxassetid://112968110857352",
		["sealFill"] = "rbxassetid://111595007269811",
		["selectionPinInOut"] = "rbxassetid://81834666710003",
		["sensor"] = "rbxassetid://79957599284236",
		["sensorFill"] = "rbxassetid://100348356748640",
		["sensorRadiowavesLeftAndRight"] = "rbxassetid://137434009722117",
		["sensorRadiowavesLeftAndRightFill"] = "rbxassetid://106680582974812",
		["sensorTagRadiowavesForward"] = "rbxassetid://106463263648802",
		["sensorTagRadiowavesForwardFill"] = "rbxassetid://99279214867737",
		["serverRack"] = "rbxassetid://83940756291905",
		["serviceDog"] = "rbxassetid://139343512896351",
		["serviceDogFill"] = "rbxassetid://81589591908524",
		["shadow"] = "rbxassetid://115420710489840",
		["sharedWithYou"] = "rbxassetid://99587894742741",
		["sharedWithYouCircle"] = "rbxassetid://105105656683870",
		["sharedWithYouSlash"] = "rbxassetid://110559749416219",
		["sharedwithyou"] = "rbxassetid://98071581699327",
		["sharedwithyouCircle"] = "rbxassetid://76114224177131",
		["sharedwithyouCircleFill"] = "rbxassetid://81557681633469",
		["sharedwithyouSlash"] = "rbxassetid://86347172828564",
		["shareplay"] = "rbxassetid://102891055337180",
		["shareplaySlash"] = "rbxassetid://116971365339623",
		["shazamLogo"] = "rbxassetid://92839379188348",
		["shazamLogoFill"] = "rbxassetid://103713552773129",
		["shekelsign"] = "rbxassetid://129156275836476",
		["shekelsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://88176105509519",
		["shekelsignBankBuilding"] = "rbxassetid://83980545208734",
		["shekelsignBankBuildingFill"] = "rbxassetid://75899516654392",
		["shekelsignCircle"] = "rbxassetid://118065137678244",
		["shekelsignCircleFill"] = "rbxassetid://110241676766230",
		["shekelsignGaugeChartLefthalfRighthalf"] = "rbxassetid://138077316594571",
		["shekelsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://106188539296043",
		["shekelsignRing"] = "rbxassetid://96814236600555",
		["shekelsignRingDashed"] = "rbxassetid://77084151086437",
		["shekelsignSquare"] = "rbxassetid://98662725701428",
		["shekelsignSquareFill"] = "rbxassetid://138075137740999",
		["shield"] = "rbxassetid://140526681233529",
		["shieldCheckered"] = "rbxassetid://122359446295344",
		["shieldFill"] = "rbxassetid://124747829928806",
		["shieldLefthalfFilled"] = "rbxassetid://117577138863097",
		["shieldLefthalfFilledBadgeCheckmark"] = "rbxassetid://87003650517234",
		["shieldLefthalfFilledSlash"] = "rbxassetid://135125468470118",
		["shieldLefthalfFilledTrianglebadgeExclamationmark"] = "rbxassetid://72778955082789",
		["shieldPatternCheckered"] = "rbxassetid://130283063693178",
		["shieldRighthalfFilled"] = "rbxassetid://121059176356852",
		["shieldSlash"] = "rbxassetid://110010335990680",
		["shieldSlashFill"] = "rbxassetid://90727030243014",
		["shift"] = "rbxassetid://139605024762137",
		["shiftFill"] = "rbxassetid://103534834680447",
		["shippingbox"] = "rbxassetid://135179382969903",
		["shippingboxAndArrowBackward"] = "rbxassetid://121360973310421",
		["shippingboxAndArrowBackwardFill"] = "rbxassetid://93727205953096",
		["shippingboxCircle"] = "rbxassetid://96682399196466",
		["shippingboxCircleFill"] = "rbxassetid://132322216128885",
		["shippingboxFill"] = "rbxassetid://90240043893822",
		["shoe"] = "rbxassetid://70988953478341",
		["shoe2"] = "rbxassetid://103120492305654",
		["shoe2Fill"] = "rbxassetid://140691495305840",
		["shoeArrowTriangleheadUpAndDown"] = "rbxassetid://127847462147663",
		["shoeArrowTriangleheadUpAndDownFill"] = "rbxassetid://110267382636824",
		["shoeArrowTriangleheadUpRight"] = "rbxassetid://84029339972591",
		["shoeArrowTriangleheadUpRightCircle"] = "rbxassetid://130133214377534",
		["shoeArrowTriangleheadUpRightCircleFill"] = "rbxassetid://83387140921529",
		["shoeArrowTriangleheadUpRightFill"] = "rbxassetid://114661642297786",
		["shoeCircle"] = "rbxassetid://139385430751379",
		["shoeCircleFill"] = "rbxassetid://96913294618430",
		["shoeFill"] = "rbxassetid://70447777963358",
		["shoeprintsFill"] = "rbxassetid://83128922492077",
		["shower"] = "rbxassetid://136336766208797",
		["showerFill"] = "rbxassetid://128574689734106",
		["showerHandheld"] = "rbxassetid://123682140353662",
		["showerHandheldFill"] = "rbxassetid://105769933058151",
		["showerSidejet"] = "rbxassetid://79554964698952",
		["showerSidejetFill"] = "rbxassetid://127129458580502",
		["shuffle"] = "rbxassetid://75346543378152",
		["shuffleCircle"] = "rbxassetid://116411175114787",
		["shuffleCircleFill"] = "rbxassetid://102012828566108",
		["sidebarLeading"] = "rbxassetid://83956276332602",
		["sidebarLeft"] = "rbxassetid://71643705896266",
		["sidebarRight"] = "rbxassetid://114611117811607",
		["sidebarSquaresLeading"] = "rbxassetid://126932130215814",
		["sidebarSquaresLeft"] = "rbxassetid://102411145840494",
		["sidebarSquaresRight"] = "rbxassetid://81074371398892",
		["sidebarSquaresTrailing"] = "rbxassetid://132148034874544",
		["sidebarTrailing"] = "rbxassetid://95429731716641",
		["signature"] = "rbxassetid://110131488283477",
		["signpostAndArrowtriangleUp"] = "rbxassetid://97583682433894",
		["signpostAndArrowtriangleUpCircle"] = "rbxassetid://108385973369296",
		["signpostAndArrowtriangleUpCircleFill"] = "rbxassetid://107743240413148",
		["signpostAndArrowtriangleUpFill"] = "rbxassetid://138825662345098",
		["signpostLeft"] = "rbxassetid://95412606669027",
		["signpostLeftCircle"] = "rbxassetid://115318963051502",
		["signpostLeftCircleFill"] = "rbxassetid://91336762767303",
		["signpostLeftFill"] = "rbxassetid://75163090487583",
		["signpostRight"] = "rbxassetid://101774272755085",
		["signpostRightAndLeft"] = "rbxassetid://113062367181841",
		["signpostRightAndLeftCircle"] = "rbxassetid://81815780687045",
		["signpostRightAndLeftCircleFill"] = "rbxassetid://89749102061487",
		["signpostRightAndLeftFill"] = "rbxassetid://72053416932561",
		["signpostRightCircle"] = "rbxassetid://128089922540621",
		["signpostRightCircleFill"] = "rbxassetid://81406314178274",
		["signpostRightFill"] = "rbxassetid://136784047816620",
		["simcard"] = "rbxassetid://102108051244372",
		["simcard2"] = "rbxassetid://138566470635829",
		["simcard2Fill"] = "rbxassetid://103016244826117",
		["simcardFill"] = "rbxassetid://126517779550731",
		["singaporedollarsign"] = "rbxassetid://134448746581237",
		["singaporedollarsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://76846054562178",
		["singaporedollarsignBankBuilding"] = "rbxassetid://72931926178709",
		["singaporedollarsignBankBuildingFill"] = "rbxassetid://107456617296294",
		["singaporedollarsignCircle"] = "rbxassetid://112775243884034",
		["singaporedollarsignCircleFill"] = "rbxassetid://88834107058222",
		["singaporedollarsignGaugeChartLefthalfRighthalf"] = "rbxassetid://105134570441636",
		["singaporedollarsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://119200364920688",
		["singaporedollarsignRing"] = "rbxassetid://120499586212229",
		["singaporedollarsignRingDashed"] = "rbxassetid://134361953001558",
		["singaporedollarsignSquare"] = "rbxassetid://137523797948046",
		["singaporedollarsignSquareFill"] = "rbxassetid://117230157948981",
		["sink"] = "rbxassetid://97332507094909",
		["sinkFill"] = "rbxassetid://119601343432289",
		["siri"] = "rbxassetid://78943861759065",
		["skateboard"] = "rbxassetid://96609489094400",
		["skateboardFill"] = "rbxassetid://125654589784907",
		["skew"] = "rbxassetid://103633680634238",
		["skis"] = "rbxassetid://114314985218926",
		["skisFill"] = "rbxassetid://128694681935126",
		["slashCircle"] = "rbxassetid://91525074193799",
		["slashCircleFill"] = "rbxassetid://113050340993198",
		["sleep"] = "rbxassetid://112657466251253",
		["sleepCircle"] = "rbxassetid://135948050894103",
		["sleepCircleFill"] = "rbxassetid://110524174707079",
		["sliderHorizontal2ArrowTriangleheadCounterclockwise"] = "rbxassetid://86778232183781",
		["sliderHorizontal2Gobackward"] = "rbxassetid://82873088218553",
		["sliderHorizontal2RectangleAndArrowTriangle2Circlepath"] = "rbxassetid://114334030505190",
		["sliderHorizontal2RectangleAndArrowTrianglehead2ClockwiseRotate90"] = "rbxassetid://86330070759013",
		["sliderHorizontal2Square"] = "rbxassetid://90937235818005",
		["sliderHorizontal2SquareBadgeArrowDown"] = "rbxassetid://110530322362077",
		["sliderHorizontal2SquareOnSquare"] = "rbxassetid://102145308436014",
		["sliderHorizontal3"] = "rbxassetid://99890330649872",
		["sliderHorizontalBelowCircleLefthalfFilled"] = "rbxassetid://104764044327011",
		["sliderHorizontalBelowCircleLefthalfFilledInverse"] = "rbxassetid://138896643212114",
		["sliderHorizontalBelowCircleRighthalfFilled"] = "rbxassetid://115251627584565",
		["sliderHorizontalBelowCircleRighthalfFilledInverse"] = "rbxassetid://83816451711529",
		["sliderHorizontalBelowRectangle"] = "rbxassetid://119305687087086",
		["sliderHorizontalBelowSquareAndSquareFilled"] = "rbxassetid://120455732453266",
		["sliderHorizontalBelowSquareFilledAndSquare"] = "rbxassetid://129990694640165",
		["sliderHorizontalBelowSunMax"] = "rbxassetid://105031304876055",
		["sliderVertical3"] = "rbxassetid://102020200694699",
		["slowmo"] = "rbxassetid://114262094447775",
		["smallcircleCircle"] = "rbxassetid://120436203127403",
		["smallcircleCircleFill"] = "rbxassetid://102648410553101",
		["smallcircleFilledCircle"] = "rbxassetid://85691773230977",
		["smallcircleFilledCircleFill"] = "rbxassetid://111196996738405",
		["smartphone"] = "rbxassetid://93476228253050",
		["smoke"] = "rbxassetid://104871896251732",
		["smokeCircle"] = "rbxassetid://108737671657911",
		["smokeCircleFill"] = "rbxassetid://129640575733880",
		["smokeFill"] = "rbxassetid://127452968050922",
		["snowboard"] = "rbxassetid://113780393933543",
		["snowboardFill"] = "rbxassetid://108936879402105",
		["snowflake"] = "rbxassetid://125255611954484",
		["snowflakeCircle"] = "rbxassetid://113404635828886",
		["snowflakeCircleFill"] = "rbxassetid://137890067722669",
		["snowflakeRoadLane"] = "rbxassetid://100143850770605",
		["snowflakeRoadLaneDashed"] = "rbxassetid://104817339834131",
		["snowflakeSlash"] = "rbxassetid://99651415315718",
		["soccerball"] = "rbxassetid://125849468854224",
		["soccerballCircle"] = "rbxassetid://130263604545849",
		["soccerballCircleFill"] = "rbxassetid://119282850587959",
		["soccerballCircleFillInverse"] = "rbxassetid://112192357428946",
		["soccerballCircleInverse"] = "rbxassetid://74573317455595",
		["soccerballInverse"] = "rbxassetid://98858584469175",
		["sofa"] = "rbxassetid://120600522494597",
		["sofaFill"] = "rbxassetid://114779564549333",
		["sos"] = "rbxassetid://84474540582122",
		["sosCircle"] = "rbxassetid://79680196200371",
		["sosCircleFill"] = "rbxassetid://133944108925355",
		["space"] = "rbxassetid://88505792015757",
		["sparkle"] = "rbxassetid://105137821962797",
		["sparkleMagnifyingglass"] = "rbxassetid://103946109249635",
		["sparkleTextClipboard"] = "rbxassetid://110580783587021",
		["sparkleTextClipboardFill"] = "rbxassetid://106843999265230",
		["sparkles"] = "rbxassetid://105054419961789",
		["sparkles2"] = "rbxassetid://101006703552517",
		["sparklesRectangleStack"] = "rbxassetid://86520437063065",
		["sparklesRectangleStackFill"] = "rbxassetid://130420912432593",
		["sparklesSquareFilledOnSquare"] = "rbxassetid://70460348597208",
		["sparklesTv"] = "rbxassetid://134275091244818",
		["sparklesTvFill"] = "rbxassetid://82800085062329",
		["spatialCapture"] = "rbxassetid://127355928805920",
		["spatialCaptureFill"] = "rbxassetid://115385600235982",
		["spatialCaptureOnHexagon"] = "rbxassetid://105807064072492",
		["spatialCaptureOnHexagonFill"] = "rbxassetid://98568195175603",
		["spatialCaptureSlash"] = "rbxassetid://83328140433280",
		["spatialCaptureSlashFill"] = "rbxassetid://77330821689586",
		["speaker"] = "rbxassetid://90795640862724",
		["speakerBadgeExclamationmark"] = "rbxassetid://79417919763353",
		["speakerBadgeExclamationmarkFill"] = "rbxassetid://101773223278790",
		["speakerCircle"] = "rbxassetid://79358452707141",
		["speakerCircleFill"] = "rbxassetid://80055212262386",
		["speakerFill"] = "rbxassetid://97746085265210",
		["speakerMinus"] = "rbxassetid://87806168928121",
		["speakerMinusFill"] = "rbxassetid://82240551019132",
		["speakerPlus"] = "rbxassetid://84033072891945",
		["speakerPlusFill"] = "rbxassetid://102724697463555",
		["speakerSlash"] = "rbxassetid://111943193498500",
		["speakerSlashCircle"] = "rbxassetid://90600051448985",
		["speakerSlashCircleFill"] = "rbxassetid://130708719346289",
		["speakerSlashFill"] = "rbxassetid://110093423263690",
		["speakerSquare"] = "rbxassetid://71945065645813",
		["speakerSquareFill"] = "rbxassetid://129912752069784",
		["speakerTrianglebadgeExclamationmark"] = "rbxassetid://98367643133076",
		["speakerTrianglebadgeExclamationmarkFill"] = "rbxassetid://139026865817721",
		["speakerWave1"] = "rbxassetid://76621154546819",
		["speakerWave1ArrowtrianglesUpRightDownLeft"] = "rbxassetid://73074603671410",
		["speakerWave1Fill"] = "rbxassetid://117491707887443",
		["speakerWave2"] = "rbxassetid://93687295077826",
		["speakerWave2Bubble"] = "rbxassetid://118881789849031",
		["speakerWave2BubbleFill"] = "rbxassetid://106305154684153",
		["speakerWave2Circle"] = "rbxassetid://84575739119409",
		["speakerWave2CircleFill"] = "rbxassetid://85071023796255",
		["speakerWave2Fill"] = "rbxassetid://103180330131669",
		["speakerWave3"] = "rbxassetid://79826224325031",
		["speakerWave3Fill"] = "rbxassetid://114293469707588",
		["speakerZzz"] = "rbxassetid://118545156089427",
		["speakerZzzFill"] = "rbxassetid://86985126077561",
		["spigot"] = "rbxassetid://106805522407528",
		["spigotFill"] = "rbxassetid://99217504785092",
		["spoonServing"] = "rbxassetid://138932624792540",
		["sportscourt"] = "rbxassetid://82512117398294",
		["sportscourtCircle"] = "rbxassetid://99070240252051",
		["sportscourtCircleFill"] = "rbxassetid://74270844136365",
		["sportscourtFill"] = "rbxassetid://135388374191975",
		["sprinkler"] = "rbxassetid://129645897217574",
		["sprinklerAndDroplets"] = "rbxassetid://102114964726064",
		["sprinklerAndDropletsFill"] = "rbxassetid://97896768650190",
		["sprinklerFill"] = "rbxassetid://73036232822178",
		["square"] = "rbxassetid://85143053995767",
		["square2Layers3d"] = "rbxassetid://70552485257532",
		["square2Layers3dBottomFilled"] = "rbxassetid://125761993163696",
		["square2Layers3dFill"] = "rbxassetid://124738920278180",
		["square2Layers3dTopFilled"] = "rbxassetid://136259102006947",
		["square3Layers3d"] = "rbxassetid://115210073684938",
		["square3Layers3dBottomFilled"] = "rbxassetid://129811646195969",
		["square3Layers3dDownBackward"] = "rbxassetid://72949225714356",
		["square3Layers3dDownForward"] = "rbxassetid://135710811999897",
		["square3Layers3dDownLeft"] = "rbxassetid://106845150399737",
		["square3Layers3dDownLeftSlash"] = "rbxassetid://127231103569358",
		["square3Layers3dDownRight"] = "rbxassetid://71437542849844",
		["square3Layers3dDownRightSlash"] = "rbxassetid://76582107849526",
		["square3Layers3dMiddleFilled"] = "rbxassetid://123108929754648",
		["square3Layers3dSlash"] = "rbxassetid://101399839734504",
		["square3Layers3dTopFilled"] = "rbxassetid://106415948057755",
		["squareAndArrowDown"] = "rbxassetid://128746411462402",
		["squareAndArrowDownBadgeCheckmark"] = "rbxassetid://130768898099008",
		["squareAndArrowDownBadgeCheckmarkFill"] = "rbxassetid://86242132249455",
		["squareAndArrowDownBadgeClock"] = "rbxassetid://121820372914588",
		["squareAndArrowDownBadgeClockFill"] = "rbxassetid://72247714968114",
		["squareAndArrowDownBadgeXmark"] = "rbxassetid://105432945173625",
		["squareAndArrowDownBadgeXmarkFill"] = "rbxassetid://75948895538876",
		["squareAndArrowDownFill"] = "rbxassetid://120212545963289",
		["squareAndArrowDownOnSquare"] = "rbxassetid://119110082141361",
		["squareAndArrowDownOnSquareFill"] = "rbxassetid://110434202328008",
		["squareAndArrowUp"] = "rbxassetid://113313553903045",
		["squareAndArrowUpBadgeCheckmark"] = "rbxassetid://89060462360490",
		["squareAndArrowUpBadgeCheckmarkFill"] = "rbxassetid://87427475669342",
		["squareAndArrowUpBadgeClock"] = "rbxassetid://132739866805226",
		["squareAndArrowUpBadgeClockFill"] = "rbxassetid://91052085672226",
		["squareAndArrowUpCircle"] = "rbxassetid://103969691300137",
		["squareAndArrowUpCircleFill"] = "rbxassetid://76698142129351",
		["squareAndArrowUpFill"] = "rbxassetid://90828927970385",
		["squareAndArrowUpOnSquare"] = "rbxassetid://135435626478341",
		["squareAndArrowUpOnSquareFill"] = "rbxassetid://95336766785015",
		["squareAndArrowUpTrianglebadgeExclamationmark"] = "rbxassetid://109390466933337",
		["squareAndArrowUpTrianglebadgeExclamationmarkFill"] = "rbxassetid://139318666375380",
		["squareAndAtRectangle"] = "rbxassetid://119683592096853",
		["squareAndAtRectangleFill"] = "rbxassetid://104255435377085",
		["squareAndLineVerticalAndSquare"] = "rbxassetid://79431983646769",
		["squareAndLineVerticalAndSquareFilled"] = "rbxassetid://112081990601652",
		["squareAndPencil"] = "rbxassetid://76634037563084",
		["squareAndPencilCircle"] = "rbxassetid://139505288481527",
		["squareAndPencilCircleFill"] = "rbxassetid://82248531304358",
		["squareArrowtriangle4Outward"] = "rbxassetid://77298189568568",
		["squareBadgePlus"] = "rbxassetid://98210383623230",
		["squareBadgePlusFill"] = "rbxassetid://103356838075193",
		["squareBottomhalfFilled"] = "rbxassetid://96604220147547",
		["squareCircle"] = "rbxassetid://139790165393025",
		["squareCircleFill"] = "rbxassetid://103079992812239",
		["squareDashed"] = "rbxassetid://119064141453799",
		["squareDotted"] = "rbxassetid://117586347327317",
		["squareFill"] = "rbxassetid://89837132511355",
		["squareFillAndLineVerticalAndSquareFill"] = "rbxassetid://75144623179474",
		["squareFillOnCircleFill"] = "rbxassetid://115476599238356",
		["squareFillOnSquareFill"] = "rbxassetid://89417266423147",
		["squareFillTextGrid1x2"] = "rbxassetid://84290036715096",
		["squareFilledAndLineVerticalAndSquare"] = "rbxassetid://80885900269249",
		["squareFilledOnSquare"] = "rbxassetid://124428264818823",
		["squareGrid2x2"] = "rbxassetid://80913360698670",
		["squareGrid2x2Fill"] = "rbxassetid://71760249952566",
		["squareGrid3x1BelowLineGrid1x2"] = "rbxassetid://81912688426584",
		["squareGrid3x1BelowLineGrid1x2Fill"] = "rbxassetid://119653016618376",
		["squareGrid3x1FolderBadgePlus"] = "rbxassetid://74842079191055",
		["squareGrid3x1FolderFillBadgePlus"] = "rbxassetid://106031789047089",
		["squareGrid3x2"] = "rbxassetid://97502417328341",
		["squareGrid3x2Fill"] = "rbxassetid://95159780378426",
		["squareGrid3x3"] = "rbxassetid://87652573110584",
		["squareGrid3x3BottomleftFilled"] = "rbxassetid://130862064876074",
		["squareGrid3x3BottommiddleFilled"] = "rbxassetid://116581882016989",
		["squareGrid3x3BottomrightFilled"] = "rbxassetid://137824218288354",
		["squareGrid3x3Fill"] = "rbxassetid://110325541887257",
		["squareGrid3x3MiddleFilled"] = "rbxassetid://99768140128642",
		["squareGrid3x3MiddleleftFilled"] = "rbxassetid://131771722713881",
		["squareGrid3x3MiddlerightFilled"] = "rbxassetid://128882572939518",
		["squareGrid3x3Square"] = "rbxassetid://107787495576279",
		["squareGrid3x3SquareBadgeEllipsis"] = "rbxassetid://96252060080671",
		["squareGrid3x3TopleftFilled"] = "rbxassetid://111902279638097",
		["squareGrid3x3TopmiddleFilled"] = "rbxassetid://100251003844223",
		["squareGrid3x3ToprightFilled"] = "rbxassetid://77522429310417",
		["squareGrid4x3Fill"] = "rbxassetid://89822928143221",
		["squareLefthalfFilled"] = "rbxassetid://123727097279981",
		["squareOnCircle"] = "rbxassetid://87453442013043",
		["squareOnSquare"] = "rbxassetid://112515729133848",
		["squareOnSquareBadgePersonCrop"] = "rbxassetid://81628150473526",
		["squareOnSquareBadgePersonCropFill"] = "rbxassetid://70798178911051",
		["squareOnSquareDashed"] = "rbxassetid://85708721830387",
		["squareOnSquareIntersectionDashed"] = "rbxassetid://123685576963261",
		["squareOnSquareSquareshapeControlhandles"] = "rbxassetid://132317434182442",
		["squareResize"] = "rbxassetid://103137389011632",
		["squareResizeDown"] = "rbxassetid://131580684994902",
		["squareResizeUp"] = "rbxassetid://96408134862696",
		["squareRighthalfFilled"] = "rbxassetid://83773994148405",
		["squareSlash"] = "rbxassetid://121563515816803",
		["squareSlashFill"] = "rbxassetid://81337393217510",
		["squareSplit1x2"] = "rbxassetid://102758119479068",
		["squareSplit1x2Fill"] = "rbxassetid://126457976074520",
		["squareSplit2x1"] = "rbxassetid://85495348203340",
		["squareSplit2x1Fill"] = "rbxassetid://99719747307469",
		["squareSplit2x2"] = "rbxassetid://103048676495294",
		["squareSplit2x2Fill"] = "rbxassetid://91776792312073",
		["squareSplitBottomrightquarter"] = "rbxassetid://78077560669550",
		["squareSplitBottomrightquarterFill"] = "rbxassetid://103695791513241",
		["squareSplitDiagonal"] = "rbxassetid://107073898601138",
		["squareSplitDiagonal2x2"] = "rbxassetid://87887098327053",
		["squareSplitDiagonal2x2Fill"] = "rbxassetid://115495101484518",
		["squareSplitDiagonalFill"] = "rbxassetid://123204849485732",
		["squareStack"] = "rbxassetid://112149539989443",
		["squareStack3dDownForward"] = "rbxassetid://123371888588139",
		["squareStack3dDownForwardFill"] = "rbxassetid://92818923054422",
		["squareStack3dDownRight"] = "rbxassetid://126509104158127",
		["squareStack3dDownRightFill"] = "rbxassetid://101922856349607",
		["squareStack3dForwardDottedline"] = "rbxassetid://77002442081347",
		["squareStack3dForwardDottedlineFill"] = "rbxassetid://136457639194171",
		["squareStack3dUp"] = "rbxassetid://117987207006038",
		["squareStack3dUpBadgeAutomatic"] = "rbxassetid://135930328075691",
		["squareStack3dUpBadgeAutomaticFill"] = "rbxassetid://113654146090095",
		["squareStack3dUpFill"] = "rbxassetid://91370889810852",
		["squareStack3dUpSlash"] = "rbxassetid://115258770745856",
		["squareStack3dUpSlashFill"] = "rbxassetid://126902421297621",
		["squareStack3dUpTrianglebadgeExclamationmark"] = "rbxassetid://75728258130488",
		["squareStack3dUpTrianglebadgeExclamationmarkFill"] = "rbxassetid://94716024705571",
		["squareStackFill"] = "rbxassetid://122760509196742",
		["squareTextSquare"] = "rbxassetid://130921034757762",
		["squareTextSquareFill"] = "rbxassetid://84685736764504",
		["squareTophalfFilled"] = "rbxassetid://104415472214123",
		["squareroot"] = "rbxassetid://122874159989395",
		["squaresBelowRectangle"] = "rbxassetid://102583434437834",
		["squaresLeadingRectangle"] = "rbxassetid://84658886266010",
		["squaresLeadingRectangleFill"] = "rbxassetid://77216416187205",
		["squareshape"] = "rbxassetid://108626932621362",
		["squareshapeControlhandlesOnSquareshapeControlhandles"] = "rbxassetid://136325582686841",
		["squareshapeDottedSplit2x2"] = "rbxassetid://91166447813616",
		["squareshapeDottedSquareshape"] = "rbxassetid://92681355705894",
		["squareshapeFill"] = "rbxassetid://140350880119310",
		["squareshapeSplit2x2"] = "rbxassetid://107381495625763",
		["squareshapeSplit2x2Dotted"] = "rbxassetid://128554723537974",
		["squareshapeSplit2x2DottedInside"] = "rbxassetid://137947623907113",
		["squareshapeSplit2x2DottedInsideAndOutside"] = "rbxassetid://120474492600718",
		["squareshapeSplit2x2DottedOutside"] = "rbxassetid://123897485566440",
		["squareshapeSplit3x3"] = "rbxassetid://133278932515243",
		["squareshapeSquareshapeDotted"] = "rbxassetid://108989106976024",
		["stairs"] = "rbxassetid://70523530478444",
		["star"] = "rbxassetid://97208341574073",
		["starBubble"] = "rbxassetid://137118519724278",
		["starBubbleFill"] = "rbxassetid://95375870183734",
		["starCircle"] = "rbxassetid://74436398890361",
		["starCircleFill"] = "rbxassetid://117124119701813",
		["starFill"] = "rbxassetid://112524490690853",
		["starHexagon"] = "rbxassetid://94649353014438",
		["starHexagonFill"] = "rbxassetid://97287319969332",
		["starLeadinghalfFilled"] = "rbxassetid://76971128862533",
		["starSlash"] = "rbxassetid://70849976350941",
		["starSlashFill"] = "rbxassetid://134310116619944",
		["starSquare"] = "rbxassetid://91348274885593",
		["starSquareFill"] = "rbxassetid://100772579100177",
		["starSquareOnSquare"] = "rbxassetid://70718742076403",
		["starSquareOnSquareFill"] = "rbxassetid://119810588488900",
		["staroflife"] = "rbxassetid://114798584744904",
		["staroflifeCircle"] = "rbxassetid://76564007357028",
		["staroflifeCircleFill"] = "rbxassetid://111984257276107",
		["staroflifeFill"] = "rbxassetid://71371042350725",
		["staroflifeShield"] = "rbxassetid://103781038038265",
		["staroflifeShieldFill"] = "rbxassetid://120953658795745",
		["steeringwheel"] = "rbxassetid://98041075523701",
		["steeringwheelAndHands"] = "rbxassetid://87829430123778",
		["steeringwheelAndHeatWaves"] = "rbxassetid://118659521340187",
		["steeringwheelAndKey"] = "rbxassetid://114365366703405",
		["steeringwheelAndLiquidWave"] = "rbxassetid://132962907493387",
		["steeringwheelAndLock"] = "rbxassetid://74743575328404",
		["steeringwheelArrowTriangleheadCounterclockwiseAndClockwise"] = "rbxassetid://114349664849833",
		["steeringwheelArrowtriangleLeft"] = "rbxassetid://133696680147741",
		["steeringwheelArrowtriangleRight"] = "rbxassetid://119016823583713",
		["steeringwheelBadgeExclamationmark"] = "rbxassetid://138427420451609",
		["steeringwheelBadgeLock"] = "rbxassetid://126529278950442",
		["steeringwheelCircle"] = "rbxassetid://124168726734871",
		["steeringwheelCircleFill"] = "rbxassetid://107253978218132",
		["steeringwheelExclamationmark"] = "rbxassetid://136154239115325",
		["steeringwheelRoadLane"] = "rbxassetid://89255699549572",
		["steeringwheelRoadLaneDashed"] = "rbxassetid://132868959701894",
		["steeringwheelSlash"] = "rbxassetid://91448583789774",
		["sterlingsign"] = "rbxassetid://126562532499500",
		["sterlingsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://136352701272619",
		["sterlingsignBankBuilding"] = "rbxassetid://129465260320590",
		["sterlingsignBankBuildingFill"] = "rbxassetid://89415549253328",
		["sterlingsignCircle"] = "rbxassetid://128090877950956",
		["sterlingsignCircleFill"] = "rbxassetid://96577595539313",
		["sterlingsignGaugeChartLefthalfRighthalf"] = "rbxassetid://74815105245464",
		["sterlingsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://90408777058185",
		["sterlingsignRing"] = "rbxassetid://109328496049218",
		["sterlingsignRingDashed"] = "rbxassetid://126044081571443",
		["sterlingsignSquare"] = "rbxassetid://123909441953591",
		["sterlingsignSquareFill"] = "rbxassetid://97561315012730",
		["stethoscope"] = "rbxassetid://108847491450617",
		["stethoscopeCircle"] = "rbxassetid://112416231109184",
		["stethoscopeCircleFill"] = "rbxassetid://133482297875986",
		["stop"] = "rbxassetid://132098862323602",
		["stopCircle"] = "rbxassetid://128321680998373",
		["stopCircleFill"] = "rbxassetid://118901612585535",
		["stopFill"] = "rbxassetid://74225402177219",
		["stopwatch"] = "rbxassetid://98740179195407",
		["stopwatchFill"] = "rbxassetid://107592823329819",
		["storefront"] = "rbxassetid://135841176957124",
		["storefrontCircle"] = "rbxassetid://74529585747704",
		["storefrontCircleFill"] = "rbxassetid://82510167755966",
		["storefrontFill"] = "rbxassetid://129684177323455",
		["stove"] = "rbxassetid://117736045694658",
		["stoveFill"] = "rbxassetid://106652953751053",
		["strikethrough"] = "rbxassetid://119273162148826",
		["strikethroughDouble"] = "rbxassetid://102575177328559",
		["strokeLineDiagonal"] = "rbxassetid://77560205356047",
		["strokeLineDiagonalSlash"] = "rbxassetid://140086402893267",
		["stroller"] = "rbxassetid://133514081157613",
		["strollerFill"] = "rbxassetid://132666279884023",
		["studentdesk"] = "rbxassetid://81200616483866",
		["suitClub"] = "rbxassetid://115355448500067",
		["suitClubFill"] = "rbxassetid://106423658416550",
		["suitDiamond"] = "rbxassetid://102316895916267",
		["suitDiamondFill"] = "rbxassetid://136303405954770",
		["suitHeart"] = "rbxassetid://102805929221332",
		["suitHeartFill"] = "rbxassetid://122686479848611",
		["suitSpade"] = "rbxassetid://85616337997149",
		["suitSpadeFill"] = "rbxassetid://88147851638314",
		["suitcase"] = "rbxassetid://87609836872373",
		["suitcaseCart"] = "rbxassetid://125186079383688",
		["suitcaseCartFill"] = "rbxassetid://80277015090553",
		["suitcaseCircle"] = "rbxassetid://119900683591433",
		["suitcaseCircleFill"] = "rbxassetid://135347326350559",
		["suitcaseFill"] = "rbxassetid://136958536826666",
		["suitcaseRolling"] = "rbxassetid://75357230115730",
		["suitcaseRollingAndFilm"] = "rbxassetid://122394094533244",
		["suitcaseRollingAndFilmCircle"] = "rbxassetid://97301794440482",
		["suitcaseRollingAndFilmCircleFill"] = "rbxassetid://99640827791378",
		["suitcaseRollingAndFilmFill"] = "rbxassetid://93468357058716",
		["suitcaseRollingAndSuitcase"] = "rbxassetid://121055774157302",
		["suitcaseRollingAndSuitcaseCircle"] = "rbxassetid://121378802217257",
		["suitcaseRollingAndSuitcaseCircleFill"] = "rbxassetid://92889078287104",
		["suitcaseRollingAndSuitcaseFill"] = "rbxassetid://104192984670894",
		["suitcaseRollingCircle"] = "rbxassetid://129768986866053",
		["suitcaseRollingCircleFill"] = "rbxassetid://73955642672556",
		["suitcaseRollingFill"] = "rbxassetid://74877686253838",
		["sum"] = "rbxassetid://121256596249395",
		["sunDust"] = "rbxassetid://103445379416568",
		["sunDustCircle"] = "rbxassetid://121983227528375",
		["sunDustCircleFill"] = "rbxassetid://89732002886704",
		["sunDustFill"] = "rbxassetid://80641416859494",
		["sunHaze"] = "rbxassetid://135475190059548",
		["sunHazeCircle"] = "rbxassetid://85520066827867",
		["sunHazeCircleFill"] = "rbxassetid://114146986427142",
		["sunHazeFill"] = "rbxassetid://119817446395343",
		["sunHorizon"] = "rbxassetid://84120651165632",
		["sunHorizonCircle"] = "rbxassetid://94640978320968",
		["sunHorizonCircleFill"] = "rbxassetid://73242682466487",
		["sunHorizonFill"] = "rbxassetid://100176954875747",
		["sunLefthalfFilled"] = "rbxassetid://99948010377860",
		["sunMax"] = "rbxassetid://136191950602850",
		["sunMaxCircle"] = "rbxassetid://84176626743969",
		["sunMaxCircleFill"] = "rbxassetid://135937714886387",
		["sunMaxFill"] = "rbxassetid://129021699626953",
		["sunMaxTrianglebadgeExclamationmark"] = "rbxassetid://135358000268431",
		["sunMaxTrianglebadgeExclamationmarkFill"] = "rbxassetid://99021447947882",
		["sunMin"] = "rbxassetid://103991364155847",
		["sunMinFill"] = "rbxassetid://106524277066060",
		["sunRain"] = "rbxassetid://117346545789896",
		["sunRainCircle"] = "rbxassetid://116714247993788",
		["sunRainCircleFill"] = "rbxassetid://72120512860534",
		["sunRainFill"] = "rbxassetid://119708329959073",
		["sunRighthalfFilled"] = "rbxassetid://130384758326055",
		["sunSnow"] = "rbxassetid://140218841895149",
		["sunSnowCircle"] = "rbxassetid://85080431656012",
		["sunSnowCircleFill"] = "rbxassetid://139753867511118",
		["sunSnowFill"] = "rbxassetid://79961567888677",
		["sunglasses"] = "rbxassetid://139478408108550",
		["sunglassesFill"] = "rbxassetid://83172262555556",
		["sunrise"] = "rbxassetid://84294788506747",
		["sunriseCircle"] = "rbxassetid://85082595836648",
		["sunriseCircleFill"] = "rbxassetid://134981377023180",
		["sunriseFill"] = "rbxassetid://88724560564927",
		["sunset"] = "rbxassetid://84258742471324",
		["sunsetCircle"] = "rbxassetid://74528127670070",
		["sunsetCircleFill"] = "rbxassetid://111819138531245",
		["sunsetFill"] = "rbxassetid://72039785697529",
		["surfboard"] = "rbxassetid://140238778372965",
		["surfboardFill"] = "rbxassetid://103281693034156",
		["suspensionShock"] = "rbxassetid://82815963336131",
		["suvSide"] = "rbxassetid://113818306073178",
		["suvSideAirCirculate"] = "rbxassetid://101209179997042",
		["suvSideAirCirculateFill"] = "rbxassetid://95604708193928",
		["suvSideAirFresh"] = "rbxassetid://119537195789706",
		["suvSideAirFreshFill"] = "rbxassetid://128602482925386",
		["suvSideAndExclamationmark"] = "rbxassetid://70935742116781",
		["suvSideAndExclamationmarkFill"] = "rbxassetid://134726230610351",
		["suvSideArrowLeftAndRight"] = "rbxassetid://139550769625928",
		["suvSideArrowLeftAndRightFill"] = "rbxassetid://135409490346330",
		["suvSideArrowtriangleDown"] = "rbxassetid://71707878766537",
		["suvSideArrowtriangleDownFill"] = "rbxassetid://88284067475836",
		["suvSideArrowtriangleUp"] = "rbxassetid://109244877917656",
		["suvSideArrowtriangleUpArrowtriangleDown"] = "rbxassetid://118056351833978",
		["suvSideArrowtriangleUpArrowtriangleDownFill"] = "rbxassetid://125999031098593",
		["suvSideArrowtriangleUpFill"] = "rbxassetid://90910642207609",
		["suvSideFill"] = "rbxassetid://82704988425727",
		["suvSideFrontOpen"] = "rbxassetid://72250378572119",
		["suvSideFrontOpenCrop"] = "rbxassetid://120980559843625",
		["suvSideFrontOpenCropFill"] = "rbxassetid://125542014790146",
		["suvSideFrontOpenFill"] = "rbxassetid://132460379724922",
		["suvSideHillDescentControl"] = "rbxassetid://126063797863800",
		["suvSideHillDescentControlFill"] = "rbxassetid://77045237271977",
		["suvSideHillDown"] = "rbxassetid://134786730212068",
		["suvSideHillDownAndGaugeOpenWithLinesNeedle25percentAndArrowtriangle"] = "rbxassetid://83945172818973",
		["suvSideHillDownAndGaugeOpenWithLinesNeedle25percentAndArrowtriangleFill"] = "rbxassetid://114026491508514",
		["suvSideHillDownFill"] = "rbxassetid://72730443837671",
		["suvSideHillUp"] = "rbxassetid://129652117525451",
		["suvSideHillUpFill"] = "rbxassetid://134588895330123",
		["suvSideLock"] = "rbxassetid://135078968309336",
		["suvSideLockFill"] = "rbxassetid://123003915936036",
		["suvSideLockOpen"] = "rbxassetid://115230659352541",
		["suvSideLockOpenFill"] = "rbxassetid://129135935833817",
		["suvSideRearOpen"] = "rbxassetid://139226380860692",
		["suvSideRearOpenCrop"] = "rbxassetid://88433095209406",
		["suvSideRearOpenCropFill"] = "rbxassetid://71941757962126",
		["suvSideRearOpenFill"] = "rbxassetid://121255200757213",
		["suvSideRoofCargoCarrier"] = "rbxassetid://90680771893599",
		["suvSideRoofCargoCarrierFill"] = "rbxassetid://133507228256677",
		["suvSideRoofCargoCarrierSlash"] = "rbxassetid://73339283777162",
		["suvSideRoofCargoCarrierSlashFill"] = "rbxassetid://72759140430639",
		["swatchpalette"] = "rbxassetid://125516289768416",
		["swatchpaletteFill"] = "rbxassetid://111232642263672",
		["swedishkronasign"] = "rbxassetid://115059054061881",
		["swedishkronasignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://107015130866436",
		["swedishkronasignBankBuilding"] = "rbxassetid://94661078864168",
		["swedishkronasignBankBuildingFill"] = "rbxassetid://122674758234286",
		["swedishkronasignCircle"] = "rbxassetid://130820223023461",
		["swedishkronasignCircleFill"] = "rbxassetid://96231802699012",
		["swedishkronasignGaugeChartLefthalfRighthalf"] = "rbxassetid://90449849273258",
		["swedishkronasignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://85748624360232",
		["swedishkronasignRing"] = "rbxassetid://105958553353498",
		["swedishkronasignRingDashed"] = "rbxassetid://115761962010012",
		["swedishkronasignSquare"] = "rbxassetid://128931505796379",
		["swedishkronasignSquareFill"] = "rbxassetid://86509975102581",
		["swift"] = "rbxassetid://135681872987394",
		["swiftdata"] = "rbxassetid://74282041662791",
		["swirlCircleRighthalfFilled"] = "rbxassetid://103405176082247",
		["swirlCircleRighthalfFilledInverse"] = "rbxassetid://75696463542233",
		["switch2"] = "rbxassetid://99218016450501",
		["switchProgrammable"] = "rbxassetid://84251494436351",
		["switchProgrammableFill"] = "rbxassetid://85826821975584",
		["switchProgrammableSquare"] = "rbxassetid://109202516688828",
		["switchProgrammableSquareFill"] = "rbxassetid://140038440376679",
		["syringe"] = "rbxassetid://134779716432867",
		["syringeFill"] = "rbxassetid://105718946268724",
		["tCircle"] = "rbxassetid://113271024609284",
		["tCircleFill"] = "rbxassetid://119571720599814",
		["tSquare"] = "rbxassetid://87546740989322",
		["tSquareFill"] = "rbxassetid://117186355627025",
		["tableFurniture"] = "rbxassetid://118809430961100",
		["tableFurnitureFill"] = "rbxassetid://128445581622810",
		["tablecells"] = "rbxassetid://85004798836302",
		["tablecellsBadgeEllipsis"] = "rbxassetid://79889013681142",
		["tablecellsFill"] = "rbxassetid://109601246909544",
		["tablecellsFillBadgeEllipsis"] = "rbxassetid://129079091406121",
		["tachometer"] = "rbxassetid://100567385026177",
		["tag"] = "rbxassetid://104278823123794",
		["tagCircle"] = "rbxassetid://74061891188761",
		["tagCircleFill"] = "rbxassetid://114556711951516",
		["tagFill"] = "rbxassetid://89746504735605",
		["tagSlash"] = "rbxassetid://76661632603924",
		["tagSlashFill"] = "rbxassetid://109012633470146",
		["tagSquare"] = "rbxassetid://87621218946117",
		["tagSquareFill"] = "rbxassetid://114890035110337",
		["taillightFog"] = "rbxassetid://82333208021035",
		["taillightFogFill"] = "rbxassetid://99709323035641",
		["takeoutbagAndCupAndStraw"] = "rbxassetid://135148907059856",
		["takeoutbagAndCupAndStrawFill"] = "rbxassetid://103318663213516",
		["target"] = "rbxassetid://84037566052726",
		["teddybear"] = "rbxassetid://89621151313364",
		["teddybearFill"] = "rbxassetid://81297274380624",
		["teletype"] = "rbxassetid://107362767762739",
		["teletypeAnswer"] = "rbxassetid://139631101200787",
		["teletypeAnswerCircle"] = "rbxassetid://90200447484716",
		["teletypeAnswerCircleFill"] = "rbxassetid://111381178181644",
		["teletypeCircle"] = "rbxassetid://138872701729896",
		["teletypeCircleFill"] = "rbxassetid://80115468549244",
		["tengesign"] = "rbxassetid://76988463911430",
		["tengesignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://75892461467217",
		["tengesignBankBuilding"] = "rbxassetid://112391984014443",
		["tengesignBankBuildingFill"] = "rbxassetid://126608973721961",
		["tengesignCircle"] = "rbxassetid://111459092131195",
		["tengesignCircleFill"] = "rbxassetid://123410462749809",
		["tengesignGaugeChartLefthalfRighthalf"] = "rbxassetid://95846595281122",
		["tengesignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://133479365260141",
		["tengesignRing"] = "rbxassetid://134859673001983",
		["tengesignRingDashed"] = "rbxassetid://118456008853764",
		["tengesignSquare"] = "rbxassetid://108744664506456",
		["tengesignSquareFill"] = "rbxassetid://137042676059462",
		["tennisRacket"] = "rbxassetid://117271664113564",
		["tennisRacketCircle"] = "rbxassetid://76019214542356",
		["tennisRacketCircleFill"] = "rbxassetid://125737548729214",
		["tennisball"] = "rbxassetid://104744228251964",
		["tennisballCircle"] = "rbxassetid://121952139494198",
		["tennisballCircleFill"] = "rbxassetid://75309517708716",
		["tennisballFill"] = "rbxassetid://94298365160647",
		["tent"] = "rbxassetid://107006023598958",
		["tent2"] = "rbxassetid://95982406617723",
		["tent2Circle"] = "rbxassetid://131199860472116",
		["tent2CircleFill"] = "rbxassetid://85668483723444",
		["tent2Fill"] = "rbxassetid://91088067443876",
		["tentCircle"] = "rbxassetid://70607897797397",
		["tentCircleFill"] = "rbxassetid://135778310997601",
		["tentFill"] = "rbxassetid://71561855929740",
		["testtube2"] = "rbxassetid://80066702459692",
		["textAligncenter"] = "rbxassetid://71237993847541",
		["textAlignleft"] = "rbxassetid://126414082317242",
		["textAlignright"] = "rbxassetid://84350767056630",
		["textAndCommandMacwindow"] = "rbxassetid://86957010693702",
		["textAppend"] = "rbxassetid://108335281304146",
		["textBadgeCheckmark"] = "rbxassetid://105812612281248",
		["textBadgeMinus"] = "rbxassetid://83327763553474",
		["textBadgePlus"] = "rbxassetid://129239148873683",
		["textBadgeStar"] = "rbxassetid://128027608333717",
		["textBadgeXmark"] = "rbxassetid://101988186707064",
		["textBelowFolder"] = "rbxassetid://87822055347956",
		["textBelowFolderFill"] = "rbxassetid://130066865275998",
		["textBelowPhoto"] = "rbxassetid://139379154126272",
		["textBelowPhotoFill"] = "rbxassetid://134160367064989",
		["textBookClosed"] = "rbxassetid://111192629904131",
		["textBookClosedFill"] = "rbxassetid://97841285729388",
		["textBubble"] = "rbxassetid://128793402405217",
		["textBubbleBadgeClock"] = "rbxassetid://93907819124534",
		["textBubbleBadgeClockFill"] = "rbxassetid://88289318147358",
		["textBubbleFill"] = "rbxassetid://116249834530262",
		["textDocument"] = "rbxassetid://124309426221022",
		["textDocumentFill"] = "rbxassetid://124730277333625",
		["textInsert"] = "rbxassetid://97126037596934",
		["textJustify"] = "rbxassetid://92189821886998",
		["textJustifyLeading"] = "rbxassetid://99075460859575",
		["textJustifyLeft"] = "rbxassetid://131541181777984",
		["textJustifyRight"] = "rbxassetid://129280972878245",
		["textJustifyTrailing"] = "rbxassetid://129652399217283",
		["textLine2Summary"] = "rbxassetid://140230863430130",
		["textLine2SummaryBadgeXmark"] = "rbxassetid://70429489437963",
		["textLine3Summary"] = "rbxassetid://81766828169006",
		["textLineFirstAndArrowtriangleForward"] = "rbxassetid://85328963821966",
		["textLineLastAndArrowtriangleForward"] = "rbxassetid://108463662081854",
		["textLineMagnify"] = "rbxassetid://95577209625603",
		["textMagnifyingglass"] = "rbxassetid://114116769689132",
		["textPadHeader"] = "rbxassetid://106064080795897",
		["textPadHeaderBadgeClock"] = "rbxassetid://124262662260972",
		["textPadHeaderBadgePlus"] = "rbxassetid://136283903785863",
		["textPage"] = "rbxassetid://92314254916759",
		["textPageBadgeMagnifyingglass"] = "rbxassetid://127124929104557",
		["textPageFill"] = "rbxassetid://139449259721285",
		["textPageSlash"] = "rbxassetid://113189115705323",
		["textPageSlashFill"] = "rbxassetid://105274129885608",
		["textQuote"] = "rbxassetid://71027928151952",
		["textRectangle"] = "rbxassetid://130318963677643",
		["textRectangleFill"] = "rbxassetid://108940510434765",
		["textRectanglePage"] = "rbxassetid://86723219970269",
		["textRectanglePageFill"] = "rbxassetid://114057346576950",
		["textRedaction"] = "rbxassetid://105235021121957",
		["textSquareFilled"] = "rbxassetid://112727132354588",
		["textViewfinder"] = "rbxassetid://95798719444148",
		["textWordSpacing"] = "rbxassetid://75789106006521",
		["textformat"] = "rbxassetid://107710559061740",
		["textformat12"] = "rbxassetid://96656679869431",
		["textformat123"] = "rbxassetid://134142879344254",
		["textformatAbc"] = "rbxassetid://138305677898152",
		["textformatAbcDottedunderline"] = "rbxassetid://94626317959618",
		["textformatAlt"] = "rbxassetid://132159623766191",
		["textformatCharacters"] = "rbxassetid://117802849867936",
		["textformatCharactersArrowLeftAndRight"] = "rbxassetid://129388475589128",
		["textformatCharactersDottedunderline"] = "rbxassetid://78315218057352",
		["textformatNumbers"] = "rbxassetid://124177082221864",
		["textformatSize"] = "rbxassetid://93771567593788",
		["textformatSizeLarger"] = "rbxassetid://93387252147805",
		["textformatSizeSmaller"] = "rbxassetid://109995000982679",
		["textformatSubscript"] = "rbxassetid://86381798212299",
		["textformatSuperscript"] = "rbxassetid://81076327481935",
		["theatermaskAndPaintbrush"] = "rbxassetid://88404865436421",
		["theatermaskAndPaintbrushFill"] = "rbxassetid://127636624966411",
		["theatermasks"] = "rbxassetid://119325864262704",
		["theatermasksCircle"] = "rbxassetid://80160373236658",
		["theatermasksCircleFill"] = "rbxassetid://122778091246019",
		["theatermasksFill"] = "rbxassetid://118820244647209",
		["thermometerAndEllipsis"] = "rbxassetid://106404759350042",
		["thermometerAndLiquidWaves"] = "rbxassetid://110474674863751",
		["thermometerAndLiquidWavesSnowflake"] = "rbxassetid://127007809849613",
		["thermometerAndLiquidWavesTrianglebadgeExclamationmark"] = "rbxassetid://74515683264588",
		["thermometerBrakesignal"] = "rbxassetid://78708806961918",
		["thermometerGaugeOpen"] = "rbxassetid://122264305417542",
		["thermometerHigh"] = "rbxassetid://89229451444519",
		["thermometerLow"] = "rbxassetid://131420426530700",
		["thermometerMedium"] = "rbxassetid://71148830790297",
		["thermometerMediumSlash"] = "rbxassetid://118717870879578",
		["thermometerSnowflake"] = "rbxassetid://75391106253368",
		["thermometerSnowflakeCircle"] = "rbxassetid://131952215879048",
		["thermometerSnowflakeCircleFill"] = "rbxassetid://133994251139774",
		["thermometerSun"] = "rbxassetid://107951087495619",
		["thermometerSunCircle"] = "rbxassetid://82549716179412",
		["thermometerSunCircleFill"] = "rbxassetid://74970074280056",
		["thermometerSunFill"] = "rbxassetid://120808413699971",
		["thermometerTirepressure"] = "rbxassetid://89391830630971",
		["thermometerTransmission"] = "rbxassetid://84090975599959",
		["thermometerVariable"] = "rbxassetid://123361025458437",
		["thermometerVariableAndFigure"] = "rbxassetid://71146322185292",
		["thermometerVariableAndFigureCircle"] = "rbxassetid://126503466826501",
		["thermometerVariableAndFigureCircleFill"] = "rbxassetid://112639012001535",
		["thermometerVariableBadgeClock"] = "rbxassetid://77637851179488",
		["thermometerVariableBadgePlay"] = "rbxassetid://138406770912999",
		["ticket"] = "rbxassetid://78850938480744",
		["ticketCircle"] = "rbxassetid://125548492810962",
		["ticketCircleFill"] = "rbxassetid://81789279996088",
		["ticketFill"] = "rbxassetid://134666026768258",
		["timelapse"] = "rbxassetid://96365441062279",
		["timelineSelection"] = "rbxassetid://93679306913299",
		["timer"] = "rbxassetid://131232244017070",
		["timerCircle"] = "rbxassetid://104963768880474",
		["timerCircleFill"] = "rbxassetid://74781722205278",
		["timerSquare"] = "rbxassetid://136926278456877",
		["tire"] = "rbxassetid://121804115558084",
		["tireBadgeSnowflake"] = "rbxassetid://118870916845492",
		["tirepressure"] = "rbxassetid://139354888430441",
		["togglepower"] = "rbxassetid://126792360918660",
		["toilet"] = "rbxassetid://139322044959527",
		["toiletCircle"] = "rbxassetid://132862220807496",
		["toiletCircleFill"] = "rbxassetid://86592804374521",
		["toiletFill"] = "rbxassetid://89608461240931",
		["tornado"] = "rbxassetid://93394540448953",
		["tornadoCircle"] = "rbxassetid://120622162002991",
		["tornadoCircleFill"] = "rbxassetid://119975169838498",
		["tortoise"] = "rbxassetid://89207957369788",
		["tortoiseCircle"] = "rbxassetid://138114227730926",
		["tortoiseCircleFill"] = "rbxassetid://113462643523462",
		["tortoiseFill"] = "rbxassetid://108775029902688",
		["torus"] = "rbxassetid://132235380088261",
		["touchid"] = "rbxassetid://127151466748359",
		["towHitch"] = "rbxassetid://98604376318167",
		["towHitchExclamationmark"] = "rbxassetid://117587622340065",
		["towHitchExclamationmarkFill"] = "rbxassetid://77885472071490",
		["towHitchFill"] = "rbxassetid://136757672238841",
		["tractionControlTirepressure"] = "rbxassetid://89446879516569",
		["tractionControlTirepressureExclamationmark"] = "rbxassetid://129579264199158",
		["tractionControlTirepressureSlash"] = "rbxassetid://82258262400115",
		["trainSideFrontCar"] = "rbxassetid://81352707597032",
		["trainSideMiddleCar"] = "rbxassetid://84241439668483",
		["trainSideRearCar"] = "rbxassetid://114688400647868",
		["tram"] = "rbxassetid://84554772135786",
		["tramCard"] = "rbxassetid://94311647704427",
		["tramCardFill"] = "rbxassetid://72197519771173",
		["tramCircle"] = "rbxassetid://99917178213901",
		["tramCircleFill"] = "rbxassetid://84107263038489",
		["tramFill"] = "rbxassetid://124882868874709",
		["tramFillTunnel"] = "rbxassetid://82427435127609",
		["translate"] = "rbxassetid://74057651757937",
		["transmission"] = "rbxassetid://78486925087835",
		["trapezoidAndLineHorizontal"] = "rbxassetid://117248222414382",
		["trapezoidAndLineHorizontalFill"] = "rbxassetid://83400087360136",
		["trapezoidAndLineVertical"] = "rbxassetid://122849535680037",
		["trapezoidAndLineVerticalFill"] = "rbxassetid://83143223589474",
		["trash"] = "rbxassetid://138210305619993",
		["trashCircle"] = "rbxassetid://73759030470557",
		["trashCircleFill"] = "rbxassetid://108682997886275",
		["trashFill"] = "rbxassetid://106522682727620",
		["trashSlash"] = "rbxassetid://137129524605524",
		["trashSlashCircle"] = "rbxassetid://75985404698667",
		["trashSlashCircleFill"] = "rbxassetid://119475662673602",
		["trashSlashFill"] = "rbxassetid://86415395411354",
		["trashSlashSquare"] = "rbxassetid://75415733626570",
		["trashSlashSquareFill"] = "rbxassetid://111819411879473",
		["trashSquare"] = "rbxassetid://139489659801239",
		["trashSquareFill"] = "rbxassetid://109042030275157",
		["tray"] = "rbxassetid://73132187606290",
		["tray2"] = "rbxassetid://109273606771685",
		["tray2Fill"] = "rbxassetid://114990115453763",
		["trayAndArrowDown"] = "rbxassetid://138530153829354",
		["trayAndArrowDownFill"] = "rbxassetid://91720907960301",
		["trayAndArrowUp"] = "rbxassetid://77418052891963",
		["trayAndArrowUpFill"] = "rbxassetid://111348199178010",
		["trayBadge"] = "rbxassetid://99876442266432",
		["trayBadgeFill"] = "rbxassetid://101926737161042",
		["trayCircle"] = "rbxassetid://98784166534236",
		["trayCircleFill"] = "rbxassetid://131639114232091",
		["trayFill"] = "rbxassetid://122084538861944",
		["trayFull"] = "rbxassetid://132151007573012",
		["trayFullFill"] = "rbxassetid://91743715077166",
		["tree"] = "rbxassetid://131434292632259",
		["treeCircle"] = "rbxassetid://77869416588663",
		["treeCircleFill"] = "rbxassetid://118871328720111",
		["treeFill"] = "rbxassetid://127929585101588",
		["triangle"] = "rbxassetid://103147443822886",
		["triangleBottomhalfFilled"] = "rbxassetid://91709533626215",
		["triangleCircle"] = "rbxassetid://111397146609147",
		["triangleCircleFill"] = "rbxassetid://131784417798929",
		["triangleFill"] = "rbxassetid://98911778107051",
		["triangleLefthalfFilled"] = "rbxassetid://122088513245439",
		["triangleRighthalfFilled"] = "rbxassetid://133484476485466",
		["triangleTophalfFilled"] = "rbxassetid://114334455043672",
		["triangleshape"] = "rbxassetid://103860060139536",
		["triangleshapeFill"] = "rbxassetid://137360750563384",
		["trophy"] = "rbxassetid://113423520493674",
		["trophyCircle"] = "rbxassetid://80943025177785",
		["trophyCircleFill"] = "rbxassetid://76982971562787",
		["trophyFill"] = "rbxassetid://74977361750490",
		["tropicalstorm"] = "rbxassetid://97305087052372",
		["tropicalstormCircle"] = "rbxassetid://117783495371346",
		["tropicalstormCircleFill"] = "rbxassetid://90338028011988",
		["truckBox"] = "rbxassetid://83851227799136",
		["truckBoxBadgeClock"] = "rbxassetid://89308426660825",
		["truckBoxBadgeClockFill"] = "rbxassetid://132276325552498",
		["truckBoxFill"] = "rbxassetid://110475724637231",
		["truckPickupSide"] = "rbxassetid://123433678430058",
		["truckPickupSideAirCirculate"] = "rbxassetid://80768683207277",
		["truckPickupSideAirCirculateFill"] = "rbxassetid://101108911081174",
		["truckPickupSideAirFresh"] = "rbxassetid://71635746134403",
		["truckPickupSideAirFreshFill"] = "rbxassetid://87057182945703",
		["truckPickupSideAndExclamationmark"] = "rbxassetid://139134957787137",
		["truckPickupSideAndExclamationmarkFill"] = "rbxassetid://95516163286881",
		["truckPickupSideArrowLeftAndRight"] = "rbxassetid://134277371887972",
		["truckPickupSideArrowLeftAndRightFill"] = "rbxassetid://120454836734609",
		["truckPickupSideArrowtriangleDown"] = "rbxassetid://132765732566337",
		["truckPickupSideArrowtriangleDownFill"] = "rbxassetid://126435076757533",
		["truckPickupSideArrowtriangleUp"] = "rbxassetid://129927853101620",
		["truckPickupSideArrowtriangleUpArrowtriangleDown"] = "rbxassetid://76463006668039",
		["truckPickupSideArrowtriangleUpArrowtriangleDownFill"] = "rbxassetid://102914968611680",
		["truckPickupSideArrowtriangleUpFill"] = "rbxassetid://103734412692534",
		["truckPickupSideFill"] = "rbxassetid://97841418868342",
		["truckPickupSideFrontOpen"] = "rbxassetid://130338401662393",
		["truckPickupSideFrontOpenCrop"] = "rbxassetid://130602145974071",
		["truckPickupSideFrontOpenCropFill"] = "rbxassetid://80394069134521",
		["truckPickupSideFrontOpenFill"] = "rbxassetid://140564339078125",
		["truckPickupSideHillDown"] = "rbxassetid://81855572295261",
		["truckPickupSideHillDownAndGaugeOpenWithLinesNeedle25percentAndArrowtriangle"] = "rbxassetid://120535414775272",
		["truckPickupSideHillDownAndGaugeOpenWithLinesNeedle25percentAndArrowtriangleFill"] = "rbxassetid://96717003085498",
		["truckPickupSideHillDownFill"] = "rbxassetid://129981288263838",
		["truckPickupSideHillUp"] = "rbxassetid://120531308583244",
		["truckPickupSideHillUpFill"] = "rbxassetid://118462546162839",
		["truckPickupSideLock"] = "rbxassetid://90874238611008",
		["truckPickupSideLockFill"] = "rbxassetid://139300624211362",
		["truckPickupSideLockOpen"] = "rbxassetid://111751710170128",
		["truckPickupSideLockOpenFill"] = "rbxassetid://117854506670260",
		["truckSideHillDescentControl"] = "rbxassetid://106358378146490",
		["truckSideHillDescentControlFill"] = "rbxassetid://100686764237291",
		["truckSideRoofCargoCarrier"] = "rbxassetid://71548640889981",
		["truckSideRoofCargoCarrierFill"] = "rbxassetid://70901858186322",
		["truckSideRoofCargoCarrierSlash"] = "rbxassetid://107972634370880",
		["truckSideRoofCargoCarrierSlashFill"] = "rbxassetid://122020656964646",
		["tsa"] = "rbxassetid://134948426765455",
		["tsaCircle"] = "rbxassetid://108199751556422",
		["tsaCircleFill"] = "rbxassetid://72935539681008",
		["tsaSlash"] = "rbxassetid://99849566895544",
		["tshirt"] = "rbxassetid://78149665788013",
		["tshirtCircle"] = "rbxassetid://124062591825671",
		["tshirtCircleFill"] = "rbxassetid://95738553763485",
		["tshirtFill"] = "rbxassetid://93980224214143",
		["tugriksign"] = "rbxassetid://81138137513450",
		["tugriksignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://126226333785383",
		["tugriksignBankBuilding"] = "rbxassetid://110652295230466",
		["tugriksignBankBuildingFill"] = "rbxassetid://109410303282690",
		["tugriksignCircle"] = "rbxassetid://100568170639157",
		["tugriksignCircleFill"] = "rbxassetid://86051072080818",
		["tugriksignGaugeChartLefthalfRighthalf"] = "rbxassetid://122980287842808",
		["tugriksignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://71970544968459",
		["tugriksignRing"] = "rbxassetid://114551163304551",
		["tugriksignRingDashed"] = "rbxassetid://131188971913163",
		["tugriksignSquare"] = "rbxassetid://113572701477700",
		["tugriksignSquareFill"] = "rbxassetid://102159003271983",
		["tuningfork"] = "rbxassetid://101642064626347",
		["turkishlirasign"] = "rbxassetid://100432595691389",
		["turkishlirasignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://125963477298669",
		["turkishlirasignBankBuilding"] = "rbxassetid://86988859548682",
		["turkishlirasignBankBuildingFill"] = "rbxassetid://101316166861444",
		["turkishlirasignCircle"] = "rbxassetid://129136113627430",
		["turkishlirasignCircleFill"] = "rbxassetid://96077985019311",
		["turkishlirasignGaugeChartLefthalfRighthalf"] = "rbxassetid://132308066882364",
		["turkishlirasignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://135569336786362",
		["turkishlirasignRing"] = "rbxassetid://126842663496567",
		["turkishlirasignRingDashed"] = "rbxassetid://89470219812321",
		["turkishlirasignSquare"] = "rbxassetid://80810143950534",
		["turkishlirasignSquareFill"] = "rbxassetid://81730250023213",
		["tv"] = "rbxassetid://134683634154697",
		["tvAndHifispeakerFill"] = "rbxassetid://126365816064099",
		["tvAndMediabox"] = "rbxassetid://86190133697909",
		["tvAndMediaboxFill"] = "rbxassetid://70794673467646",
		["tvBadgeWifi"] = "rbxassetid://134114499802296",
		["tvBadgeWifiFill"] = "rbxassetid://99921301995389",
		["tvCircle"] = "rbxassetid://108467456786283",
		["tvCircleFill"] = "rbxassetid://104378375131972",
		["tvFill"] = "rbxassetid://134052066796282",
		["tvSlash"] = "rbxassetid://87329837865736",
		["tvSlashFill"] = "rbxassetid://138613370587055",
		["uCircle"] = "rbxassetid://133864802523646",
		["uCircleFill"] = "rbxassetid://83802229447704",
		["uSquare"] = "rbxassetid://70478293186949",
		["uSquareFill"] = "rbxassetid://103098702036404",
		["uiwindowSplit2x1"] = "rbxassetid://94654002409260",
		["umbrella"] = "rbxassetid://107688268920202",
		["umbrellaCircle"] = "rbxassetid://78176157826476",
		["umbrellaCircleFill"] = "rbxassetid://90379909796237",
		["umbrellaFill"] = "rbxassetid://125319557780841",
		["umbrellaGaugeOpen"] = "rbxassetid://115390159124102",
		["umbrellaPercent"] = "rbxassetid://74004447484301",
		["umbrellaPercentFill"] = "rbxassetid://98934968468500",
		["umbrellaSensorTagRadiowavesLeftAndRight"] = "rbxassetid://111616368640765",
		["umbrellaSensorTagRadiowavesLeftAndRightFill"] = "rbxassetid://84410220519393",
		["underline"] = "rbxassetid://79716535798546",
		["underlineDouble"] = "rbxassetid://95042272345021",
		["vCircle"] = "rbxassetid://78905420701975",
		["vCircleFill"] = "rbxassetid://109231824858777",
		["vSquare"] = "rbxassetid://112544504091047",
		["vSquareFill"] = "rbxassetid://95651976776858",
		["ventHeatWavesUpward"] = "rbxassetid://81373110761347",
		["vialViewfinder"] = "rbxassetid://120653091554663",
		["video"] = "rbxassetid://75234641923007",
		["videoBadgeCheckmark"] = "rbxassetid://93588020970649",
		["videoBadgeEllipsis"] = "rbxassetid://73931355581093",
		["videoBadgePlus"] = "rbxassetid://77189160054067",
		["videoBadgeWaveform"] = "rbxassetid://94770313707904",
		["videoBadgeWaveformFill"] = "rbxassetid://91311029131545",
		["videoBubble"] = "rbxassetid://111260570124310",
		["videoBubbleFill"] = "rbxassetid://98571132429169",
		["videoCircle"] = "rbxassetid://126991025094281",
		["videoCircleFill"] = "rbxassetid://102639060158177",
		["videoDoorbell"] = "rbxassetid://127205026449016",
		["videoDoorbellFill"] = "rbxassetid://87815257505023",
		["videoFill"] = "rbxassetid://139148806818337",
		["videoFillBadgeCheckmark"] = "rbxassetid://94758158365454",
		["videoFillBadgeEllipsis"] = "rbxassetid://115997809417535",
		["videoFillBadgePlus"] = "rbxassetid://71066361916528",
		["videoSlash"] = "rbxassetid://77940555638934",
		["videoSlashCircle"] = "rbxassetid://78499840932408",
		["videoSlashCircleFill"] = "rbxassetid://106447121815942",
		["videoSlashFill"] = "rbxassetid://85954124688252",
		["videoSquare"] = "rbxassetid://74932084950455",
		["videoSquareFill"] = "rbxassetid://108239592630600",
		["videoprojector"] = "rbxassetid://102503253637538",
		["videoprojectorFill"] = "rbxassetid://123004409391173",
		["view2d"] = "rbxassetid://137344398414768",
		["view3d"] = "rbxassetid://108397171176671",
		["viewfinder"] = "rbxassetid://94783896988587",
		["viewfinderCircle"] = "rbxassetid://121365827431194",
		["viewfinderCircleFill"] = "rbxassetid://123480648427476",
		["viewfinderRectangular"] = "rbxassetid://92938228120219",
		["viewfinderTrianglebadgeExclamationmark"] = "rbxassetid://110389074265828",
		["visionPro"] = "rbxassetid://86658888521866",
		["visionProAndArrowForward"] = "rbxassetid://92640289852602",
		["visionProAndArrowForwardFill"] = "rbxassetid://131506122489642",
		["visionProBadgeCheckmark"] = "rbxassetid://91300537956331",
		["visionProBadgeCheckmarkFill"] = "rbxassetid://131430228822693",
		["visionProBadgeExclamationmark"] = "rbxassetid://131951123332852",
		["visionProBadgeExclamationmarkFill"] = "rbxassetid://127300971189191",
		["visionProBadgePlay"] = "rbxassetid://86395593898709",
		["visionProBadgePlayFill"] = "rbxassetid://97801624322845",
		["visionProCircle"] = "rbxassetid://97576563076177",
		["visionProCircleFill"] = "rbxassetid://139552674437388",
		["visionProFill"] = "rbxassetid://108432448592279",
		["visionProSlash"] = "rbxassetid://109140558729897",
		["visionProSlashCircle"] = "rbxassetid://88113051707571",
		["visionProSlashCircleFill"] = "rbxassetid://135642237204795",
		["visionProSlashFill"] = "rbxassetid://121260021824503",
		["visionProTrianglebadgeExclamationmark"] = "rbxassetid://134894440127646",
		["visionProTrianglebadgeExclamationmarkFill"] = "rbxassetid://91237961536763",
		["visionpro"] = "rbxassetid://76932342920990",
		["visionproAndArrowForward"] = "rbxassetid://108237299822657",
		["visionproBadgeExclamationmark"] = "rbxassetid://78812515285709",
		["visionproBadgePlay"] = "rbxassetid://122979325623328",
		["visionproCircle"] = "rbxassetid://70783957641063",
		["visionproSlash"] = "rbxassetid://118082278749251",
		["visionproSlashCircle"] = "rbxassetid://116051094478142",
		["voiceover"] = "rbxassetid://136800595376174",
		["volleyball"] = "rbxassetid://73970433297176",
		["volleyballCircle"] = "rbxassetid://76121885043459",
		["volleyballCircleFill"] = "rbxassetid://139162144058450",
		["volleyballFill"] = "rbxassetid://78657080282621",
		["wCircle"] = "rbxassetid://83697484178752",
		["wCircleFill"] = "rbxassetid://82337186361293",
		["wSquare"] = "rbxassetid://71979974267181",
		["wSquareFill"] = "rbxassetid://81077708796392",
		["wake"] = "rbxassetid://134066791044326",
		["wakeCircle"] = "rbxassetid://96591606910274",
		["wakeCircleFill"] = "rbxassetid://79093975624302",
		["walletBifold"] = "rbxassetid://136364251846065",
		["walletBifoldFill"] = "rbxassetid://119240717399847",
		["walletPass"] = "rbxassetid://134909953531837",
		["walletPassFill"] = "rbxassetid://96808145241944",
		["walletSensorTagRadiowavesLeftAndRight"] = "rbxassetid://126915780100901",
		["walletSensorTagRadiowavesLeftAndRightFill"] = "rbxassetid://81271116607581",
		["wandAndOutline"] = "rbxassetid://129284003313828",
		["wandAndOutlineInverse"] = "rbxassetid://71138507542324",
		["wandAndRays"] = "rbxassetid://92752161512332",
		["wandAndRaysInverse"] = "rbxassetid://125975271070513",
		["wandAndSparkles"] = "rbxassetid://72040453503595",
		["wandAndSparklesInverse"] = "rbxassetid://79333469702486",
		["wandAndStars"] = "rbxassetid://95449961416091",
		["wandAndStarsInverse"] = "rbxassetid://108387310992441",
		["warninglight"] = "rbxassetid://84007946028451",
		["warninglightFill"] = "rbxassetid://109840072719326",
		["washer"] = "rbxassetid://93685448107607",
		["washerCircle"] = "rbxassetid://105378880332708",
		["washerCircleFill"] = "rbxassetid://119955243167699",
		["washerFill"] = "rbxassetid://89945593257514",
		["watchAnalog"] = "rbxassetid://88617234755283",
		["watchfaceApplewatchCase"] = "rbxassetid://73863272801256",
		["waterWaves"] = "rbxassetid://138305668238725",
		["waterWavesAndArrowDown"] = "rbxassetid://108671761307420",
		["waterWavesAndArrowDownTrianglebadgeExclamationmark"] = "rbxassetid://126530403017273",
		["waterWavesAndArrowTriangleheadDown"] = "rbxassetid://90118761233028",
		["waterWavesAndArrowTriangleheadDownTrianglebadgeExclamationmark"] = "rbxassetid://85387752450910",
		["waterWavesAndArrowTriangleheadUp"] = "rbxassetid://127164136396826",
		["waterWavesAndArrowUp"] = "rbxassetid://117956742428464",
		["waterWavesSlash"] = "rbxassetid://111588668015905",
		["waterbottle"] = "rbxassetid://138004611200910",
		["waterbottleFill"] = "rbxassetid://121256533818085",
		["wave3Backward"] = "rbxassetid://80847645712657",
		["wave3BackwardCircle"] = "rbxassetid://136031088324218",
		["wave3BackwardCircleFill"] = "rbxassetid://71061533127513",
		["wave3Down"] = "rbxassetid://108832060215003",
		["wave3DownCarSide"] = "rbxassetid://123655331264678",
		["wave3DownCarSideFill"] = "rbxassetid://115209382072100",
		["wave3DownCircle"] = "rbxassetid://114336657044130",
		["wave3DownCircleFill"] = "rbxassetid://74329989717731",
		["wave3DownConvertibleSide"] = "rbxassetid://131401811268042",
		["wave3DownConvertibleSideFill"] = "rbxassetid://79499527400603",
		["wave3DownPickupSide"] = "rbxassetid://97436480627142",
		["wave3DownPickupSideFill"] = "rbxassetid://129019641239034",
		["wave3DownSuvSide"] = "rbxassetid://71035812422373",
		["wave3DownSuvSideFill"] = "rbxassetid://134610119907297",
		["wave3Forward"] = "rbxassetid://111357002729843",
		["wave3ForwardCircle"] = "rbxassetid://80066074333627",
		["wave3ForwardCircleFill"] = "rbxassetid://80719773619963",
		["wave3Left"] = "rbxassetid://117436129898300",
		["wave3LeftCircle"] = "rbxassetid://85305739132620",
		["wave3LeftCircleFill"] = "rbxassetid://93517609770045",
		["wave3Right"] = "rbxassetid://92963290455418",
		["wave3RightCircle"] = "rbxassetid://91349038271768",
		["wave3RightCircleFill"] = "rbxassetid://140061124860963",
		["wave3Up"] = "rbxassetid://128528619550054",
		["wave3UpCircle"] = "rbxassetid://133995083701260",
		["wave3UpCircleFill"] = "rbxassetid://96665619623184",
		["waveform"] = "rbxassetid://136809466139252",
		["waveformAndPersonFilled"] = "rbxassetid://126270512457294",
		["waveformBadgeCheckmark"] = "rbxassetid://128595421098352",
		["waveformBadgeExclamationmark"] = "rbxassetid://120204943860124",
		["waveformBadgeMagnifyingglass"] = "rbxassetid://121985661181170",
		["waveformBadgeMic"] = "rbxassetid://140630166066509",
		["waveformBadgeMicrophone"] = "rbxassetid://87232803530574",
		["waveformBadgeMinus"] = "rbxassetid://102741667650470",
		["waveformBadgePlus"] = "rbxassetid://102403202693811",
		["waveformBadgeXmark"] = "rbxassetid://120155576829911",
		["waveformCircle"] = "rbxassetid://84018574438696",
		["waveformCircleFill"] = "rbxassetid://98502737702633",
		["waveformLow"] = "rbxassetid://95721363422192",
		["waveformMid"] = "rbxassetid://73459359791943",
		["waveformPath"] = "rbxassetid://72307154936317",
		["waveformPathBadgeMinus"] = "rbxassetid://136232811740839",
		["waveformPathBadgePlus"] = "rbxassetid://127759512381534",
		["waveformPathEcg"] = "rbxassetid://128118780008401",
		["waveformPathEcgMagnifyingglass"] = "rbxassetid://79598417522204",
		["waveformPathEcgRectangle"] = "rbxassetid://70398715649395",
		["waveformPathEcgRectangleFill"] = "rbxassetid://90914728496991",
		["waveformPathEcgText"] = "rbxassetid://116861166666873",
		["waveformPathEcgTextClipboard"] = "rbxassetid://81460112831245",
		["waveformPathEcgTextClipboardFill"] = "rbxassetid://130425262607160",
		["waveformPathEcgTextPage"] = "rbxassetid://101998995563939",
		["waveformPathEcgTextPageFill"] = "rbxassetid://85336259615594",
		["waveformSlash"] = "rbxassetid://101318589553195",
		["webCamera"] = "rbxassetid://85276511025498",
		["webCameraFill"] = "rbxassetid://86988545799263",
		["wheelchair"] = "rbxassetid://130234014770883",
		["widgetExtralarge"] = "rbxassetid://87179649600036",
		["widgetExtralargeBadgePlus"] = "rbxassetid://87961000171364",
		["widgetLarge"] = "rbxassetid://138302819665976",
		["widgetLargeBadgePlus"] = "rbxassetid://102309628278255",
		["widgetMedium"] = "rbxassetid://123766243611909",
		["widgetMediumBadgePlus"] = "rbxassetid://129502000388063",
		["widgetSmall"] = "rbxassetid://133222809195444",
		["widgetSmallBadgePlus"] = "rbxassetid://106813307987533",
		["wifi"] = "rbxassetid://127365451355653",
		["wifiBadgeLock"] = "rbxassetid://105865344224961",
		["wifiCircle"] = "rbxassetid://131659272048007",
		["wifiCircleFill"] = "rbxassetid://123823896793006",
		["wifiExclamationmark"] = "rbxassetid://117799256745502",
		["wifiExclamationmarkCircle"] = "rbxassetid://133542793616716",
		["wifiExclamationmarkCircleFill"] = "rbxassetid://103666079404717",
		["wifiRouter"] = "rbxassetid://107283421485159",
		["wifiRouterFill"] = "rbxassetid://127625180753277",
		["wifiSlash"] = "rbxassetid://105782001663907",
		["wifiSquare"] = "rbxassetid://101097897107565",
		["wifiSquareFill"] = "rbxassetid://135210787558367",
		["wind"] = "rbxassetid://80700050884353",
		["windCircle"] = "rbxassetid://129546295733216",
		["windCircleFill"] = "rbxassetid://96079739586089",
		["windSnow"] = "rbxassetid://92339772641709",
		["windSnowCircle"] = "rbxassetid://111653489867204",
		["windSnowCircleFill"] = "rbxassetid://132514124832058",
		["windowAwning"] = "rbxassetid://136043702603149",
		["windowAwningClosed"] = "rbxassetid://75144791958276",
		["windowCasement"] = "rbxassetid://75282400690778",
		["windowCasementClosed"] = "rbxassetid://118468264534240",
		["windowCeiling"] = "rbxassetid://120918397527890",
		["windowCeilingClosed"] = "rbxassetid://72533185677487",
		["windowHorizontal"] = "rbxassetid://92196780376848",
		["windowHorizontalClosed"] = "rbxassetid://77912685751805",
		["windowShadeClosed"] = "rbxassetid://99464758323012",
		["windowShadeOpen"] = "rbxassetid://74340846109012",
		["windowVerticalClosed"] = "rbxassetid://77549144479343",
		["windowVerticalOpen"] = "rbxassetid://116989707350034",
		["windshieldFrontAndFluidAndSpray"] = "rbxassetid://104140821821775",
		["windshieldFrontAndHeatWaves"] = "rbxassetid://139231996805155",
		["windshieldFrontAndSpray"] = "rbxassetid://118383554311432",
		["windshieldFrontAndWiper"] = "rbxassetid://90221744279393",
		["windshieldFrontAndWiperAndDrop"] = "rbxassetid://84550752400798",
		["windshieldFrontAndWiperAndSpray"] = "rbxassetid://127696811498029",
		["windshieldFrontAndWiperExclamationmark"] = "rbxassetid://113077812388437",
		["windshieldFrontAndWiperIntermittent"] = "rbxassetid://130126356387267",
		["windshieldRearAndFluidAndSpray"] = "rbxassetid://71902151124766",
		["windshieldRearAndHeatWaves"] = "rbxassetid://85175322908644",
		["windshieldRearAndSpray"] = "rbxassetid://74325024162387",
		["windshieldRearAndWiper"] = "rbxassetid://132496191383598",
		["windshieldRearAndWiperAndDrop"] = "rbxassetid://91997491758687",
		["windshieldRearAndWiperAndSpray"] = "rbxassetid://70577185858512",
		["windshieldRearAndWiperExclamationmark"] = "rbxassetid://103508258069471",
		["windshieldRearAndWiperIntermittent"] = "rbxassetid://112006728415524",
		["wineglass"] = "rbxassetid://101074630979300",
		["wineglassFill"] = "rbxassetid://114802765580227",
		["wonsign"] = "rbxassetid://138881045027066",
		["wonsignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://127138253634243",
		["wonsignBankBuilding"] = "rbxassetid://111293124675993",
		["wonsignBankBuildingFill"] = "rbxassetid://84415197244225",
		["wonsignCircle"] = "rbxassetid://88823142706925",
		["wonsignCircleFill"] = "rbxassetid://137966197891409",
		["wonsignGaugeChartLefthalfRighthalf"] = "rbxassetid://111492435126131",
		["wonsignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://121709795250122",
		["wonsignRing"] = "rbxassetid://76574048523234",
		["wonsignRingDashed"] = "rbxassetid://133779937082970",
		["wonsignSquare"] = "rbxassetid://132391856360168",
		["wonsignSquareFill"] = "rbxassetid://90329995457020",
		["wrenchAdjustable"] = "rbxassetid://136627575678034",
		["wrenchAdjustableFill"] = "rbxassetid://113988495428000",
		["wrenchAndScrewdriver"] = "rbxassetid://103452076936452",
		["wrenchAndScrewdriverFill"] = "rbxassetid://105571024016922",
		["wrongwaysign"] = "rbxassetid://76431850074308",
		["wrongwaysignFill"] = "rbxassetid://83735880477861",
		["xCircle"] = "rbxassetid://91981193078729",
		["xCircleFill"] = "rbxassetid://94299891039084",
		["xSquare"] = "rbxassetid://114578513610753",
		["xSquareFill"] = "rbxassetid://111170360358521",
		["xSquareroot"] = "rbxassetid://78470545377271",
		["xboxLogo"] = "rbxassetid://89705591865004",
		["xmark"] = "rbxassetid://80129517509086",
		["xmarkApp"] = "rbxassetid://77614287062581",
		["xmarkAppFill"] = "rbxassetid://70913517985061",
		["xmarkBin"] = "rbxassetid://115092753402225",
		["xmarkBinCircle"] = "rbxassetid://100527660496479",
		["xmarkBinCircleFill"] = "rbxassetid://72818314748638",
		["xmarkBinFill"] = "rbxassetid://93339862156011",
		["xmarkCircle"] = "rbxassetid://74086380322275",
		["xmarkCircleBadgeAirplane"] = "rbxassetid://107048545652410",
		["xmarkCircleBadgeAirplaneFill"] = "rbxassetid://107260850906533",
		["xmarkCircleFill"] = "rbxassetid://76720364341917",
		["xmarkDiamond"] = "rbxassetid://123566993050169",
		["xmarkDiamondFill"] = "rbxassetid://93992936564694",
		["xmarkIcloud"] = "rbxassetid://94493472046695",
		["xmarkIcloudFill"] = "rbxassetid://76302466621348",
		["xmarkOctagon"] = "rbxassetid://91338686100699",
		["xmarkOctagonFill"] = "rbxassetid://90341839195452",
		["xmarkRectangle"] = "rbxassetid://121990685238111",
		["xmarkRectangleFill"] = "rbxassetid://74076416348699",
		["xmarkRectanglePortrait"] = "rbxassetid://76998319704304",
		["xmarkRectanglePortraitFill"] = "rbxassetid://108883994990659",
		["xmarkSeal"] = "rbxassetid://135175848462028",
		["xmarkSealFill"] = "rbxassetid://138857703888143",
		["xmarkShield"] = "rbxassetid://112602820350263",
		["xmarkShieldFill"] = "rbxassetid://129190191318804",
		["xmarkSquare"] = "rbxassetid://94780384109918",
		["xmarkSquareFill"] = "rbxassetid://113379805795943",
		["xmarkTriangleCircleSquare"] = "rbxassetid://93482352448078",
		["xmarkTriangleCircleSquareFill"] = "rbxassetid://92930583604823",
		["xserve"] = "rbxassetid://100936689010686",
		["xserveRaid"] = "rbxassetid://96204733517915",
		["yCircle"] = "rbxassetid://104458771421352",
		["yCircleFill"] = "rbxassetid://82033787913749",
		["ySquare"] = "rbxassetid://103183886841769",
		["ySquareFill"] = "rbxassetid://72405810989202",
		["yensign"] = "rbxassetid://99734954362670",
		["yensignArrowTriangleheadCounterclockwiseRotate90"] = "rbxassetid://80201233274715",
		["yensignBankBuilding"] = "rbxassetid://72141299288880",
		["yensignBankBuildingFill"] = "rbxassetid://110179200008310",
		["yensignCircle"] = "rbxassetid://108854048682589",
		["yensignCircleFill"] = "rbxassetid://112746170982965",
		["yensignGaugeChartLefthalfRighthalf"] = "rbxassetid://115445828866168",
		["yensignGaugeChartLeftthirdTopthirdRightthird"] = "rbxassetid://90119523470045",
		["yensignRing"] = "rbxassetid://80789867463387",
		["yensignRingDashed"] = "rbxassetid://78763231940715",
		["yensignSquare"] = "rbxassetid://124557047246185",
		["yensignSquareFill"] = "rbxassetid://96601254376112",
		["yieldsign"] = "rbxassetid://80696636377723",
		["yieldsignFill"] = "rbxassetid://99571675480041",
		["zCircle"] = "rbxassetid://122572624815216",
		["zCircleFill"] = "rbxassetid://79133738654460",
		["zSquare"] = "rbxassetid://96274174435903",
		["zSquareFill"] = "rbxassetid://91137135507817",
		["zipperPage"] = "rbxassetid://74105406352571",
		["zlButtonRoundedtopHorizontal"] = "rbxassetid://92649509158613",
		["zlButtonRoundedtopHorizontalFill"] = "rbxassetid://88379112766255",
		["zrButtonRoundedtopHorizontal"] = "rbxassetid://126371346858487",
		["zrButtonRoundedtopHorizontalFill"] = "rbxassetid://95978592996094",
		["zzz"] = "rbxassetid://81661835392914",
	},
}

end

__modules["AppRecorder"] = function()
    local require = __require
    local Source = Source
    local script = Source

local HttpService = game:GetService("HttpService")

local AppRecorder = {}
AppRecorder.__index = AppRecorder

function AppRecorder.new(app)
    local self = setmetatable({
        _app = app,
        _active = false,
    }, AppRecorder)
    return self
end

function AppRecorder:Start()
    self._active = true
end

function AppRecorder:Stop()
    self._active = false
end

function AppRecorder:Dump()
    local Store = require(Source.Store)
    local state = Store._state
    
    local dumpData = {}
    
    local function traverse(elements, tabName)
        for _, el in ipairs(elements) do
            if el.value ~= nil and el.name then
                dumpData[tabName] = dumpData[tabName] or {}
                local val = el.value
                if typeof(val) == "Color3" then
                    val = { R = val.R, G = val.G, B = val.B, _type = "Color3" }
                elseif typeof(val) == "EnumItem" then
                    val = { Name = val.Name, EnumType = tostring(val.EnumType), _type = "EnumItem" }
                end
                dumpData[tabName][el.name] = val
            end
            if el.elements then
                traverse(el.elements, tabName)
            end
            if el.leftElements then
                traverse(el.leftElements, tabName)
            end
            if el.rightElements then
                traverse(el.rightElements, tabName)
            end
        end
    end
    
    for _, s in ipairs(state.sections or {}) do
        for _, tab in ipairs(s.tabs or {}) do
            if tab.pageSections then
                traverse(tab.pageSections, tab.title or "Tab")
            end
        end
    end
    
    return HttpService:JSONEncode(dumpData)
end

function AppRecorder:Load(jsonData)
    local success, dumpData = pcall(function()
        return HttpService:JSONDecode(jsonData)
    end)
    if not success or type(dumpData) ~= "table" then return end
    
    local Store = require(Source.Store)
    
    local function deserializeValue(val)
        if type(val) == "table" and val._type == "Color3" then
            return Color3.new(val.R, val.G, val.B)
        elseif type(val) == "table" and val._type == "EnumItem" then
            local enumType = val.EnumType
            local enumName = val.Name
            local enumObj = Enum[enumType]
            if enumObj and enumObj[enumName] then
                return enumObj[enumName]
            end
        end
        return val
    end
    
    Store:Update(function(state)
        local function traverseAndLoad(elements, tabName)
            for _, el in ipairs(elements) do
                local tabDump = dumpData[tabName]
                if tabDump and el.name and tabDump[el.name] ~= nil then
                    el.value = deserializeValue(tabDump[el.name])
                end
                if el.elements then
                    traverseAndLoad(el.elements, tabName)
                end
                if el.leftElements then
                    traverseAndLoad(el.leftElements, tabName)
                end
                if el.rightElements then
                    traverseAndLoad(el.rightElements, tabName)
                end
            end
        end
        
        for _, s in ipairs(state.sections or {}) do
            for _, tab in ipairs(s.tabs or {}) do
                if tab.pageSections then
                    traverseAndLoad(tab.pageSections, tab.title or "Tab")
                end
            end
        end
    end)
end

return AppRecorder

end

__modules["Components/BarChart"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local TweenService = game:GetService("TweenService")
local TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local AnimatedBar = React.Component:extend("AnimatedBar")
function AnimatedBar:init()
    self.ref = React.createRef()
end
function AnimatedBar:didMount()
    local frame = self.ref and self.ref.current
    if frame then
        frame.Size = self.props.targetSize
    end
end
function AnimatedBar:didUpdate(prevProps)
    local frame = self.ref and self.ref.current
    if frame and prevProps.targetSize ~= self.props.targetSize then
        frame.Size = prevProps.targetSize
        TweenService:Create(frame, TWEEN_INFO, {
            Size = self.props.targetSize,
        }):Play()
    end
end
function AnimatedBar:render()
    local p = self.props
    return React.createElement("Frame", {
        ref = self.ref,
        Position = UDim2.new(0.5, 0, 1, 0),
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = p.color,
        BorderSizePixel = 0,
    }, p.children)
end

local BarChart = React.Component:extend("BarChart")

function BarChart:render()
    local el = self.props.element
    
    local title = el.title or "Bar Chart"
    local subtitle = el.subtitle
    local height = el.height or 180
    local data = el.data or {}
    local N = #data
    
    local maxVal = 0
    for _, item in ipairs(data) do
        local val = 0
        if type(item) == "table" then
            val = item.value or item.Value or 0
        elseif type(item) == "number" then
            val = item
        end
        if val > maxVal then
            maxVal = val
        end
    end
    if maxVal == 0 then maxVal = 1 end
    
    -- Calculate Header Height for layout offset
    local headerHeight = 0
    if title or subtitle then
        if title then headerHeight = headerHeight + 16 end
        if subtitle then headerHeight = headerHeight + 12 end
        if title and subtitle then headerHeight = headerHeight + 2 end -- list padding
        headerHeight = headerHeight + 10 -- list layout padding between header and chart
    end
    
    local gap = 12
    local barElements = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, gap),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }
    
    for i, item in ipairs(data) do
        local val = 0
        local color = Theme.Colors.Accent
        
        if type(item) == "table" then
            val = item.value or item.Value or 0
            color = item.color or item.Color or Theme.Colors.Accent
        elseif type(item) == "number" then
            val = item
        end
        
        local percentage = math.clamp(val / maxVal, 0.05, 1) -- Keep minimum height so it is visible
        
        local scale = 1 / N
        local offset = -gap * (1 - scale)
        
        barElements["BarCol_" .. tostring(i)] = React.createElement("Frame", {
            Size = UDim2.new(scale, offset, 1, 0),
            BackgroundTransparency = 1,
            LayoutOrder = i,
        }, {
            -- The Bar Frame (Anchored at the bottom with smooth animation)
            Bar = React.createElement(AnimatedBar, {
                targetSize = UDim2.new(0.6, 0, percentage * 0.85, 0),
                color = color,
            }, {
                Corner = React.createElement("UICorner", {
                    CornerRadius = Theme.CornerRadius.Element,
                }),
                
                -- Value Label above the bar
                ValLabel = React.createElement("TextLabel", {
                    Size = UDim2.new(1.5, 0, 0, 14),
                    Position = UDim2.new(0.5, 0, 0, -16),
                    AnchorPoint = Vector2.new(0.5, 0),
                    BackgroundTransparency = 1,
                    Text = tostring(val),
                    TextColor3 = Theme.Colors.Text,
                    Font = Theme.Fonts.Bold,
                    TextSize = 9,
                }),
            }),
        })
    end
    
    -- X-Axis Labels Row
    local xLabelElements = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, gap),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }
    
    for i, item in ipairs(data) do
        local labelText = ""
        if type(item) == "table" then
            labelText = item.label or item.Label or ""
        else
            labelText = tostring(i)
        end
        local scale = 1 / N
        local offset = -gap * (1 - scale)
        
        xLabelElements["Label_" .. tostring(i)] = React.createElement("TextLabel", {
            Size = UDim2.new(scale, offset, 1, 0),
            BackgroundTransparency = 1,
            Text = labelText,
            TextColor3 = Theme.Colors.TextSecondary,
            Font = Theme.Fonts.Medium,
            TextSize = 9,
            LayoutOrder = i,
        })
    end
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = Theme.Colors.Element,
        BorderSizePixel = 0,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Card,
        }),
        
        Stroke = React.createElement("UIStroke", {
            Color = Theme.Colors.Border,
            Thickness = 1,
        }),
        
        Padding = React.createElement("UIPadding", {
            PaddingTop = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
        }),
        
        List = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        
        -- Header text
        Header = (title or subtitle) and React.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1,
        }, {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 2),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            
            TitleLabel = title and React.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                Text = title,
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Bold,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
            }),
            
            SubLabel = subtitle and React.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 12),
                BackgroundTransparency = 1,
                Text = subtitle,
                TextColor3 = Theme.Colors.TextSecondary,
                Font = Theme.Fonts.Regular,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 2,
            }),
        }),
        
        -- Chart Canvas (With Y-Axis on the left and Plot Container on the right)
        Canvas = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 1, -headerHeight),
            BackgroundTransparency = 1,
            LayoutOrder = 2,
        }, {
            -- Y-Axis Labels
            YAxis = React.createElement("Frame", {
                Name = "YAxis",
                Size = UDim2.new(0, 24, 1, -16),
                BackgroundTransparency = 1,
            }, {
                Max = React.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 10),
                    Position = UDim2.fromScale(0, 0.15),
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundTransparency = 1,
                    Text = tostring(maxVal),
                    TextColor3 = Theme.Colors.TextSecondary,
                    Font = Theme.Fonts.Medium,
                    TextSize = 8,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }),
                Mid = React.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 10),
                    Position = UDim2.fromScale(0, 0.575),
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundTransparency = 1,
                    Text = tostring(math.round(maxVal / 2)),
                    TextColor3 = Theme.Colors.TextSecondary,
                    Font = Theme.Fonts.Medium,
                    TextSize = 8,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }),
                Min = React.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 10),
                    Position = UDim2.fromScale(0, 1),
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundTransparency = 1,
                    Text = "0",
                    TextColor3 = Theme.Colors.TextSecondary,
                    Font = Theme.Fonts.Medium,
                    TextSize = 8,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }),
            }),
            
            -- Plot Container (GridLines, YAxisLine, XAxisLine, Bars, X-Labels)
            PlotContainer = React.createElement("Frame", {
                Name = "PlotContainer",
                Size = UDim2.new(1, -28, 1, 0),
                Position = UDim2.new(0, 28, 0, 0),
                BackgroundTransparency = 1,
            }, {
                -- Grid Lines
                GridLine_Top = React.createElement("Frame", {
                    Size = UDim2.new(1, 0, 0, 1),
                    Position = UDim2.fromScale(0, 0.15),
                    BackgroundColor3 = Theme.Colors.Border,
                    BackgroundTransparency = 0.6,
                    BorderSizePixel = 0,
                }),
                GridLine_Mid = React.createElement("Frame", {
                    Size = UDim2.new(1, 0, 0, 1),
                    Position = UDim2.fromScale(0, 0.575),
                    BackgroundColor3 = Theme.Colors.Border,
                    BackgroundTransparency = 0.6,
                    BorderSizePixel = 0,
                }),
                GridLine_Bottom = React.createElement("Frame", {
                    Size = UDim2.new(1, 0, 0, 1),
                    Position = UDim2.fromScale(0, 1),
                    BackgroundColor3 = Theme.Colors.Border,
                    BackgroundTransparency = 0.6,
                    BorderSizePixel = 0,
                }),
                
                -- Y-Axis Line
                YAxisLine = React.createElement("Frame", {
                    Size = UDim2.new(0, 1, 1, -16),
                    Position = UDim2.fromScale(0, 0),
                    BackgroundColor3 = Theme.Colors.Border,
                    BorderSizePixel = 0,
                }),
                
                -- Plot Area (The Bars)
                BarArea = React.createElement("Frame", {
                    Size = UDim2.new(1, 0, 1, -16),
                    BackgroundTransparency = 1,
                }, barElements),
                
                -- Labels Row (X-Labels)
                LabelsArea = React.createElement("Frame", {
                    Size = UDim2.new(1, 0, 0, 16),
                    Position = UDim2.new(0, 0, 1, -16),
                    BackgroundTransparency = 1,
                }, xLabelElements),
            })
        }),
    })
end

return BarChart

end

__modules["Components/Button"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local Button = React.Component:extend("Button")

function Button:init()
    self.state = {
        hovered = false,
        pressed = false,
    }
    self.btnRef = React.createRef()
    self.strokeRef = React.createRef()
end

function Button:didMount()
    local btn = self.btnRef and self.btnRef.current
    local stroke = self.strokeRef and self.strokeRef.current
    local hovered = self.state.hovered
    local pressed = self.state.pressed
    
    if btn then
        btn.BackgroundColor3 = pressed and Theme.Colors.Accent or (hovered and Theme.Colors.ElementHover or Theme.Colors.Element)
    end
    if stroke then
        stroke.Color = hovered and Theme.Colors.BorderHover or Theme.Colors.Border
    end
end

function Button:didUpdate(prevProps, prevState)
    local btn = self.btnRef and self.btnRef.current
    local stroke = self.strokeRef and self.strokeRef.current
    local hovered = self.state.hovered
    local pressed = self.state.pressed
    
    local valChanged = (hovered ~= prevState.hovered) or (pressed ~= prevState.pressed)
    if valChanged then
        local targetColor = pressed and Theme.Colors.Accent or (hovered and Theme.Colors.ElementHover or Theme.Colors.Element)
        local targetBorder = hovered and Theme.Colors.BorderHover or Theme.Colors.Border
        
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if btn then
            TweenService:Create(btn, tweenInfo, { BackgroundColor3 = targetColor }):Play()
        end
        if stroke then
            TweenService:Create(stroke, tweenInfo, { Color = targetBorder }):Play()
        end
    end
end

function Button:render()
    local el = self.props.element
    
    local hovered = self.state.hovered
    local pressed = self.state.pressed
    
    return React.createElement("TextButton", {
        ref = self.btnRef,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = pressed and Theme.Colors.Accent or (hovered and Theme.Colors.ElementHover or Theme.Colors.Element),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        [React.Event.MouseEnter] = function() self:setState({ hovered = true }) end,
        [React.Event.MouseLeave] = function() 
            self:setState({ hovered = false, pressed = false }) 
        end,
        [React.Event.MouseButton1Down] = function() self:setState({ pressed = true }) end,
        [React.Event.MouseButton1Up] = function() 
            if pressed then
                self:setState({ pressed = false })
                if el.callback then
                    task.spawn(el.callback)
                end
            end
        end,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Element,
        }),
        
        Stroke = React.createElement("UIStroke", {
            ref = self.strokeRef,
            Color = hovered and Theme.Colors.BorderHover or Theme.Colors.Border,
            Thickness = 1,
        }),
        
        Content = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
        }, {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 8),
            }),
            
            Icon = el.icon and React.createElement("ImageLabel", {
                Size = UDim2.new(0, 16, 0, 16),
                BackgroundTransparency = 1,
                Image = el.icon,
                ImageColor3 = Theme.Colors.Text,
            }) or nil,
            
            Label = React.createElement("TextLabel", {
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Text = el.name or "Button",
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Bold,
                TextSize = 13,
            }),
        }),
    })
end

return Button

end

__modules["Components/ColorPicker"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local ColorPicker = React.Component:extend("ColorPicker")

function ColorPicker:init()
    self.state = {
        hovered = false,
    }
end

function ColorPicker:render()
    local el = self.props.element
    local Store = self.props.Store
    
    local currentColor = el.value or Color3.fromRGB(255, 255, 255)
    local currentTrans = el.transparency or 0
    local hovered = self.state.hovered
    
    local r = math.round(currentColor.R * 255)
    local g = math.round(currentColor.G * 255)
    local b = math.round(currentColor.B * 255)
    local tPct = math.round((1 - currentTrans) * 100)
    
    local hexStr = string.format("#%02X%02X%02X (%d%%)", r, g, b, tPct)
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
    }, {
        List = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        
        -- Hex & Transparency Label
        HexLabel = React.createElement("TextLabel", {
            Size = UDim2.new(0, 100, 1, 0),
            BackgroundTransparency = 1,
            Text = hexStr,
            TextColor3 = Theme.Colors.Text,
            Font = Theme.Fonts.Bold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
            LayoutOrder = 1,
        }),
        
        -- Clickable Square Color Button (Cascade UI Style)
        ColorButton = React.createElement("TextButton", {
            Size = UDim2.fromOffset(24, 24),
            BackgroundColor3 = currentColor,
            BackgroundTransparency = currentTrans,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = 2,
            [React.Event.MouseEnter] = function() self:setState({ hovered = true }) end,
            [React.Event.MouseLeave] = function() self:setState({ hovered = false }) end,
            [React.Event.MouseButton1Click] = function()
                Store:SetColorPicker({
                    id = el.id,
                    name = el.name or "Select Color",
                    value = currentColor,
                    transparency = currentTrans,
                    callback = el.callback,
                })
            end,
        }, {
            Corner = React.createElement("UICorner", {
                CornerRadius = UDim.new(0, 5),
            }),
            Stroke = React.createElement("UIStroke", {
                Color = hovered and Theme.Colors.BorderHover or Theme.Colors.Border,
                Thickness = 1.5,
            }),
        }),
    })
end

return ColorPicker

end

__modules["Components/ColorPickerDialog"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)
local UserInputService = game:GetService("UserInputService")

local Theme = require(Source.Theme)

local ColorPickerDialog = React.Component:extend("ColorPickerDialog")

function ColorPickerDialog:init()
    local el = self.props.colorPickerActive
    local currentColor = el.value or Color3.fromRGB(255, 255, 255)
    local currentTrans = el.transparency or 0
    
    local h, s, v = currentColor:ToHSV()
    
    self.state = {
        h = h,
        s = s,
        v = v,
        a = 1 - currentTrans,
    }
    
    self.wheelRef = React.createRef()
    self.brightnessRef = React.createRef()
    self.opacityRef = React.createRef()
end

function ColorPickerDialog:didMount()
    self.inputEndedConnection = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self.isDraggingWheel = false
            self.isDraggingBrightness = false
            self.isDraggingOpacity = false
        end
    end)
end

function ColorPickerDialog:willUnmount()
    if self.inputEndedConnection then
        self.inputEndedConnection:Disconnect()
        self.inputEndedConnection = nil
    end
end

function ColorPickerDialog:render()
    local props = self.props
    local el = props.colorPickerActive
    local Store = props.Store
    
    local h = self.state.h
    local s = self.state.s
    local v = self.state.v
    local a = self.state.a
    
    local initialColor = el.value or Color3.fromRGB(255, 255, 255)
    local initialTrans = el.transparency or 0
    
    local activeColor = Color3.fromHSV(h, s, v)
    local activeTrans = 1 - a
    
    local r = math.round(activeColor.R * 255)
    local g = math.round(activeColor.G * 255)
    local b = math.round(activeColor.B * 255)
    local aPct = math.round(a * 100)
    
    local hexStr = string.format("#%02X%02X%02X", r, g, b)
    
    -- Math helpers for dragging
    local function updateWheel(input)
        local wheelFrame = self.wheelRef and self.wheelRef.current
        if not wheelFrame then return end
        
        local absPos = wheelFrame.AbsolutePosition
        local absSize = wheelFrame.AbsoluteSize
        local center = absPos + absSize / 2
        
        local mousePos = Vector2.new(input.Position.X, input.Position.Y)
        local offset = mousePos - center
        
        local d = offset.Magnitude
        local radius = absSize.X / 2
        
        local nextS = math.clamp(d / radius, 0, 1)
        local theta = math.atan2(-offset.Y, offset.X)
        local nextH = (theta + math.pi) / (2 * math.pi)
        
        self:setState({
            h = nextH,
            s = nextS,
        })
    end
    
    local function updateBrightness(input)
        local bar = self.brightnessRef and self.brightnessRef.current
        if not bar then return end
        local absPos = bar.AbsolutePosition
        local absSize = bar.AbsoluteSize
        local nextV = math.clamp((input.Position.X - absPos.X) / absSize.X, 0, 1)
        self:setState({ v = nextV })
    end
    
    local function updateOpacity(input)
        local bar = self.opacityRef and self.opacityRef.current
        if not bar then return end
        local absPos = bar.AbsolutePosition
        local absSize = bar.AbsoluteSize
        local nextA = math.clamp((input.Position.X - absPos.X) / absSize.X, 0, 1)
        self:setState({ a = nextA })
    end
    
    -- Drag triggers
    local function onWheelInput(frame, input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self.isDraggingWheel = true
            updateWheel(input)
        end
    end
    
    local function onWheelChange(frame, input)
        if self.isDraggingWheel and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateWheel(input)
        end
    end
    
    local function onBrightnessInput(frame, input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self.isDraggingBrightness = true
            updateBrightness(input)
        end
    end
    
    local function onBrightnessChange(frame, input)
        if self.isDraggingBrightness and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateBrightness(input)
        end
    end
    
    local function onOpacityInput(frame, input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self.isDraggingOpacity = true
            updateOpacity(input)
        end
    end
    
    local function onOpacityChange(frame, input)
        if self.isDraggingOpacity and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateOpacity(input)
        end
    end
    
    -- Keyboard input parsers
    local function setHex(text)
        text = text:gsub("#", "")
        if #text == 6 then
            local rHex = tonumber(text:sub(1, 2), 16)
            local gHex = tonumber(text:sub(3, 4), 16)
            local bHex = tonumber(text:sub(5, 6), 16)
            if rHex and gHex and bHex then
                local nextColor = Color3.fromRGB(rHex, gHex, bHex)
                local nextH, nextS, nextV = nextColor:ToHSV()
                self:setState({ h = nextH, s = nextS, v = nextV })
            end
        end
    end
    
    local function setRGB(channel, valueText)
        local val = tonumber(valueText)
        if val then
            val = math.clamp(math.round(val), 0, 255)
            local currentR = channel == "R" and val or r
            local currentG = channel == "G" and val or g
            local currentB = channel == "B" and val or b
            local nextColor = Color3.fromRGB(currentR, currentG, currentB)
            local nextH, nextS, nextV = nextColor:ToHSV()
            self:setState({ h = nextH, s = nextS, v = nextV })
        end
    end
    
    local function setAlpha(valueText)
        local val = tonumber(valueText)
        if val then
            val = math.clamp(val, 0, 100)
            self:setState({ a = val / 100 })
        end
    end
    
    
    -- Wheel selection dot coordinates
    local theta = (h * 2 * math.pi) - math.pi
    local knobX = s * 50 * math.cos(theta)
    local knobY = -s * 50 * math.sin(theta)
    
    local inputFieldRow = function(labelText, valueText, layoutOrder, onTextChanged)
        return React.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            LayoutOrder = layoutOrder,
        }, {
            Box = React.createElement("TextBox", {
                Size = UDim2.new(0, 60, 1, 0),
                BackgroundColor3 = Theme.Colors.Element,
                BorderSizePixel = 0,
                Text = valueText,
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Medium,
                TextSize = 10,
                ClearTextOnFocus = false,
                [React.Event.FocusLost] = function(box)
                    onTextChanged(box.Text)
                end,
            }, {
                Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 3) }),
                Stroke = React.createElement("UIStroke", { Color = Theme.Colors.Border, Thickness = 1 }),
            }),
            
            Label = React.createElement("TextLabel", {
                Size = UDim2.new(1, -66, 1, 0),
                Position = UDim2.new(0, 66, 0, 0),
                BackgroundTransparency = 1,
                Text = labelText,
                TextColor3 = Theme.Colors.TextSecondary,
                Font = Theme.Fonts.Medium,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        })
    end
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 1000,
    }, {
        -- Dark Backdrop
        Backdrop = React.createElement("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 1,
            [React.Event.MouseButton1Down] = function()
                Store:SetColorPicker(nil)
            end,
        }),
        
        Card = React.createElement("TextButton", {
            Size = UDim2.new(0, 250, 0, 340),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Theme.Colors.Card,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            Active = true,
            ZIndex = 2,
        }, {
            Corner = React.createElement("UICorner", { CornerRadius = Theme.CornerRadius.Card }),
            Stroke = React.createElement("UIStroke", { Color = Theme.Colors.Border, Thickness = 1 }),
            
            Padding = React.createElement("UIPadding", {
                PaddingTop = UDim.new(0, 12),
                PaddingBottom = UDim.new(0, 12),
                PaddingLeft = UDim.new(0, 12),
                PaddingRight = UDim.new(0, 12),
            }),
            
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 10),
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            
            -- Title
            Title = React.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                Text = el.name or "Accent Tint Color",
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Bold,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Center,
                LayoutOrder = 1,
            }),
            
            -- Main Wheel & Field Area
            MainRow = React.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 100),
                BackgroundTransparency = 1,
                LayoutOrder = 2,
            }, {
                -- Color Wheel
                Wheel = React.createElement("ImageLabel", {
                    ref = self.wheelRef,
                    Size = UDim2.new(0, 100, 0, 100),
                    BackgroundTransparency = 1,
                    Image = "rbxassetid://6020299385",
                    Active = true,
                    [React.Event.InputBegan] = onWheelInput,
                    [React.Event.InputChanged] = onWheelChange,
                }, {
                    Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
                    
                    -- Knob
                    Knob = React.createElement("Frame", {
                        Size = UDim2.new(0, 8, 0, 8),
                        Position = UDim2.new(0.5, knobX, 0.5, knobY),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BorderSizePixel = 0,
                    }, {
                        Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
                        Stroke = React.createElement("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Thickness = 1.5 }),
                    }),
                }),
                
                -- Right-aligned Fields
                Fields = React.createElement("Frame", {
                    Size = UDim2.new(1, -110, 1, 0),
                    Position = UDim2.new(1, 0, 0, 0),
                    AnchorPoint = Vector2.new(1, 0),
                    BackgroundTransparency = 1,
                }, {
                    List = React.createElement("UIListLayout", {
                        FillDirection = Enum.FillDirection.Vertical,
                        Padding = UDim.new(0, 2),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    }),
                    
                    HexRow = inputFieldRow("Hex", hexStr, 1, setHex),
                    RedRow = inputFieldRow("Red", tostring(r), 2, function(t) setRGB("R", t) end),
                    GreenRow = inputFieldRow("Green", tostring(g), 3, function(t) setRGB("G", t) end),
                    BlueRow = inputFieldRow("Blue", tostring(b), 4, function(t) setRGB("B", t) end),
                    AlphaRow = inputFieldRow("Alpha", tostring(aPct), 5, setAlpha),
                }),
            }),
            
            -- Brightness & Opacity Sliders
            Sliders = React.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 48),
                BackgroundTransparency = 1,
                LayoutOrder = 3,
            }, {
                List = React.createElement("UIListLayout", {
                    FillDirection = Enum.FillDirection.Vertical,
                    Padding = UDim.new(0, 6),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),
                
                -- Brightness
                Brightness = React.createElement("Frame", {
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundTransparency = 1,
                    LayoutOrder = 1,
                }, {
                    Label = React.createElement("TextLabel", {
                        Size = UDim2.new(0, 60, 1, 0),
                        BackgroundTransparency = 1,
                        Text = "Brightness",
                        TextColor3 = Theme.Colors.TextSecondary,
                        Font = Theme.Fonts.Medium,
                        TextSize = 10,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }),
                    
                    Bar = React.createElement("Frame", {
                        ref = self.brightnessRef,
                        Size = UDim2.new(1, -65, 0, 8),
                        Position = UDim2.new(0, 65, 0.5, -4),
                        BorderSizePixel = 0,
                        Active = true,
                        [React.Event.InputBegan] = onBrightnessInput,
                        [React.Event.InputChanged] = onBrightnessChange,
                    }, {
                        Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
                        Gradient = React.createElement("UIGradient", {
                            Color = ColorSequence.new({
                                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
                                ColorSequenceKeypoint.new(1, Color3.fromHSV(h, s, 1)),
                            }),
                        }),
                        
                        Knob = React.createElement("Frame", {
                            Size = UDim2.new(0, 6, 0, 14),
                            Position = UDim2.new(v, 0, 0.5, 0),
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                            BorderSizePixel = 0,
                        }, {
                            Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 2) }),
                            Stroke = React.createElement("UIStroke", { Color = Theme.Colors.Border, Thickness = 1 }),
                        }),
                    }),
                }),
                
                -- Opacity
                Opacity = React.createElement("Frame", {
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundTransparency = 1,
                    LayoutOrder = 2,
                }, {
                    Label = React.createElement("TextLabel", {
                        Size = UDim2.new(0, 60, 1, 0),
                        BackgroundTransparency = 1,
                        Text = "Opacity",
                        TextColor3 = Theme.Colors.TextSecondary,
                        Font = Theme.Fonts.Medium,
                        TextSize = 10,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }),
                    
                    Bar = React.createElement("Frame", {
                        ref = self.opacityRef,
                        Size = UDim2.new(1, -65, 0, 8),
                        Position = UDim2.new(0, 65, 0.5, -4),
                        BorderSizePixel = 0,
                        Active = true,
                        [React.Event.InputBegan] = onOpacityInput,
                        [React.Event.InputChanged] = onOpacityChange,
                    }, {
                        Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
                        Gradient = React.createElement("UIGradient", {
                            Color = ColorSequence.new({
                                ColorSequenceKeypoint.new(0, Color3.fromHSV(h, s, v)),
                                ColorSequenceKeypoint.new(1, Color3.fromHSV(h, s, v)),
                            }),
                            Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0, 1), -- Transparent
                                NumberSequenceKeypoint.new(1, 0), -- Opaque
                            }),
                        }),
                        
                        Knob = React.createElement("Frame", {
                            Size = UDim2.new(0, 6, 0, 14),
                            Position = UDim2.new(a, 0, 0.5, 0),
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                            BorderSizePixel = 0,
                        }, {
                            Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 2) }),
                            Stroke = React.createElement("UIStroke", { Color = Theme.Colors.Border, Thickness = 1 }),
                        }),
                    }),
                }),
            }),
            
            PreviewRow = React.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundTransparency = 1,
                LayoutOrder = 4,
            }, {
                Stroke = React.createElement("UIStroke", { Color = Theme.Colors.Border, Thickness = 1 }),
                
                NewColor = React.createElement("Frame", {
                    Size = UDim2.new(0.5, 0, 1, 0),
                    Position = UDim2.new(0, 0, 0, 0),
                    BackgroundColor3 = activeColor,
                    BackgroundTransparency = activeTrans,
                    BorderSizePixel = 0,
                }),
                
                Initial = React.createElement("Frame", {
                    Size = UDim2.new(0.5, 0, 1, 0),
                    Position = UDim2.new(0.5, 0, 0, 0),
                    BackgroundColor3 = initialColor,
                    BackgroundTransparency = initialTrans,
                    BorderSizePixel = 0,
                }),
            }),
            
            -- Action Buttons
            ActionRow = React.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 56),
                BackgroundTransparency = 1,
                LayoutOrder = 5,
            }, {
                List = React.createElement("UIListLayout", {
                    FillDirection = Enum.FillDirection.Vertical,
                    Padding = UDim.new(0, 4),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),
                
                Confirm = React.createElement("TextButton", {
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundColor3 = Theme.Colors.Accent,
                    BorderSizePixel = 0,
                    Text = "Confirm",
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    Font = Theme.Fonts.Bold,
                    TextSize = 11,
                    LayoutOrder = 1,
                    [React.Event.MouseButton1Click] = function()
                        Store:UpdateElement(el.id, function(element)
                            element.value = activeColor
                            element.transparency = activeTrans
                        end)
                        if el.callback then
                            task.spawn(el.callback, activeColor, activeTrans)
                        end
                        Store:SetColorPicker(nil)
                    end,
                }, {
                    Corner = React.createElement("UICorner", { CornerRadius = Theme.CornerRadius.Element }),
                }),
                
                Cancel = React.createElement("TextButton", {
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundColor3 = Theme.Colors.Element,
                    BorderSizePixel = 0,
                    Text = "Cancel",
                    TextColor3 = Theme.Colors.Text,
                    Font = Theme.Fonts.Medium,
                    TextSize = 11,
                    LayoutOrder = 2,
                    [React.Event.MouseButton1Click] = function()
                        Store:SetColorPicker(nil)
                    end,
                }, {
                    Corner = React.createElement("UICorner", { CornerRadius = Theme.CornerRadius.Element }),
                    Stroke = React.createElement("UIStroke", { Color = Theme.Colors.Border, Thickness = 1 }),
                }),
            }),
        }),
    })
end

return ColorPickerDialog

end

__modules["Components/ColorPickerWidget"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local ColorPickerWidget = React.Component:extend("ColorPickerWidget")

function ColorPickerWidget:init()
end

function ColorPickerWidget:render()
    local el = self.props.element
    local Store = self.props.Store
    
    local currentColor = el.value or Color3.fromRGB(255, 255, 255)
    local currentTrans = el.transparency or 0 -- 0 is opaque, 1 is fully transparent
    
    local function triggerCallback(color, trans)
        if el.callback then
            task.spawn(el.callback, color, trans)
        end
    end
    
    local function updateColor(r, g, b, t)
        local newColor = Color3.fromRGB(r, g, b)
        Store:UpdateElement(el.id, function(element)
            element.value = newColor
            element.transparency = t
        end)
        triggerCallback(newColor, t)
    end
    
    local r = math.round(currentColor.R * 255)
    local g = math.round(currentColor.G * 255)
    local b = math.round(currentColor.B * 255)
    local tPct = math.round(currentTrans * 100)
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.Colors.Element,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Element,
        }),
        
        Stroke = React.createElement("UIStroke", {
            Color = Theme.Colors.Border,
            Thickness = 1,
        }),
        
        Padding = React.createElement("UIPadding", {
            PaddingTop = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
        }),
        
        List = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        
        -- Header (Static)
        Header = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
        }, {
            -- Title
            Title = React.createElement("TextLabel", {
                Size = UDim2.new(0.5, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = el.name or "Color Picker",
                TextColor3 = Theme.Colors.TextSecondary,
                Font = Theme.Fonts.Medium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            
            -- Info Tag
            Info = React.createElement("TextLabel", {
                Size = UDim2.new(0.5, -24, 1, 0),
                Position = UDim2.new(1, -24, 0, 0),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Text = string.format("#%02X%02X%02X (%d%%)", r, g, b, tPct),
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Bold,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Right,
            }),
            
            -- Color Preview
            ColorPreview = React.createElement("Frame", {
                Size = UDim2.new(0, 16, 0, 16),
                Position = UDim2.new(1, -16, 0.5, -8),
                BackgroundColor3 = currentColor,
                BackgroundTransparency = currentTrans,
                BorderSizePixel = 0,
            }, {
                Corner = React.createElement("UICorner", {
                    CornerRadius = Theme.CornerRadius.Element,
                }),
                Stroke = React.createElement("UIStroke", {
                    Color = Theme.Colors.Border,
                    Thickness = 1,
                }),
            }),
        }),
        
        -- Red Slider
        Red = React.createElement(require(Source.Components.Slider), {
            Store = Store,
            element = {
                name = "Red",
                min = 0,
                max = 255,
                value = r,
                callback = function(newR)
                    updateColor(newR, g, b, currentTrans)
                end
            },
            LayoutOrder = 2,
        }),
        
        -- Green Slider
        Green = React.createElement(require(Source.Components.Slider), {
            Store = Store,
            element = {
                name = "Green",
                min = 0,
                max = 255,
                value = g,
                callback = function(newG)
                    updateColor(r, newG, b, currentTrans)
                end
            },
            LayoutOrder = 3,
        }),
        
        -- Blue Slider
        Blue = React.createElement(require(Source.Components.Slider), {
            Store = Store,
            element = {
                name = "Blue",
                min = 0,
                max = 255,
                value = b,
                callback = function(newB)
                    updateColor(r, g, newB, currentTrans)
                end
            },
            LayoutOrder = 4,
        }),
        
        -- Transparency Slider
        Transparency = React.createElement(require(Source.Components.Slider), {
            Store = Store,
            element = {
                name = "Transparency",
                min = 0,
                max = 100,
                value = tPct,
                callback = function(newT)
                    updateColor(r, g, b, newT / 100)
                end
            },
            LayoutOrder = 5,
        }),
    })
end

return ColorPickerWidget

end

__modules["Components/Dropdown"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local TweenService = game:GetService("TweenService")

local table_find = table.find or function(tbl, val)
    for i, v in ipairs(tbl) do
        if v == val then
            return i
        end
    end
    return nil
end

local table_clone = table.clone or function(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

local DropdownOption = React.Component:extend("DropdownOption")

function DropdownOption:init()
    self.state = { hovered = false }
end

function DropdownOption:render()
    local props = self.props
    local opt = props.opt
    local isSelected = props.isSelected
    local isMulti = props.isMulti
    local layoutOrder = props.LayoutOrder
    local hovered = self.state.hovered
    
    local optBg = (not isMulti and isSelected) and Theme.Colors.Accent or (hovered and Theme.Colors.ElementHover or Theme.Colors.Element)
    
    return React.createElement("TextButton", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = optBg,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = layoutOrder,
        [React.Event.MouseEnter] = function() self:setState({ hovered = true }) end,
        [React.Event.MouseLeave] = function() self:setState({ hovered = false }) end,
        [React.Event.MouseButton1Click] = props.OnClick,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Element,
        }),
        
        Content = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
        }, {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            
            Padding = React.createElement("UIPadding", {
                PaddingLeft = UDim.new(0, 8),
            }),
            
            -- Checkbox visual for multi-select
            Checkbox = isMulti and React.createElement("Frame", {
                Size = UDim2.fromOffset(14, 14),
                BackgroundColor3 = isSelected and Theme.Colors.Accent or Theme.Colors.Element,
                BorderSizePixel = 0,
                LayoutOrder = 1,
            }, {
                Corner = React.createElement("UICorner", {
                    CornerRadius = UDim.new(0, 3),
                }),
                Stroke = React.createElement("UIStroke", {
                    Color = (isSelected or hovered) and Theme.Colors.BorderHover or Theme.Colors.Border,
                    Thickness = 1,
                }),
                -- Checkmark inner box
                Inner = isSelected and React.createElement("Frame", {
                    Size = UDim2.fromOffset(6, 6),
                    Position = UDim2.fromScale(0.5, 0.5),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BorderSizePixel = 0,
                }, {
                    Corner = React.createElement("UICorner", {
                        CornerRadius = UDim.new(0, 1),
                    }),
                }) or nil,
            }) or nil,
            
            -- Option text
            Label = React.createElement("TextLabel", {
                Size = UDim2.new(1, isMulti and -22 or 0, 1, 0),
                BackgroundTransparency = 1,
                Text = tostring(opt),
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Medium,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 2,
            }),
        }),
    })
end

local Dropdown = React.Component:extend("Dropdown")

function Dropdown:init()
    self.state = {
        hovered = false,
        isOpen = false,
    }
    self.strokeRef = React.createRef()
    self.arrowRef = React.createRef()
    self.optionsRef = React.createRef()
end

function Dropdown:didMount()
    local stroke = self.strokeRef and self.strokeRef.current
    local arrow = self.arrowRef and self.arrowRef.current
    local optionsFrame = self.optionsRef and self.optionsRef.current
    
    local hovered = self.state.hovered
    local isOpen = self.state.isOpen
    
    if stroke then
        stroke.Color = (hovered or isOpen) and Theme.Colors.BorderHover or Theme.Colors.Border
    end
    if arrow then
        arrow.Rotation = isOpen and 180 or 0
    end
    if optionsFrame then
        local options = self.props.element.options or {}
        local numOptions = #options
        local targetHeight = numOptions > 0 and (numOptions * 28 + (numOptions - 1) * 4 + 8) or 0
        
        optionsFrame.Size = isOpen and UDim2.new(1, 0, 0, targetHeight) or UDim2.new(1, 0, 0, 0)
        optionsFrame.GroupTransparency = isOpen and 0 or 1
        optionsFrame.Visible = isOpen
    end
end

function Dropdown:didUpdate(prevProps, prevState)
    local stroke = self.strokeRef and self.strokeRef.current
    local arrow = self.arrowRef and self.arrowRef.current
    local optionsFrame = self.optionsRef and self.optionsRef.current
    
    local hovered = self.state.hovered
    local isOpen = self.state.isOpen
    
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    if hovered ~= prevState.hovered or isOpen ~= prevState.isOpen then
        if stroke then
            local targetColor = (hovered or isOpen) and Theme.Colors.BorderHover or Theme.Colors.Border
            TweenService:Create(stroke, tweenInfo, { Color = targetColor }):Play()
        end
    end
    
    if isOpen ~= prevState.isOpen then
        if arrow then
            TweenService:Create(arrow, tweenInfo, { Rotation = isOpen and 180 or 0 }):Play()
        end
        
        if optionsFrame then
            local options = self.props.element.options or {}
            local numOptions = #options
            local targetHeight = numOptions > 0 and (numOptions * 28 + (numOptions - 1) * 4 + 8) or 0
            
            if isOpen then
                optionsFrame.Visible = true
                optionsFrame.GroupTransparency = 1
                optionsFrame.Size = UDim2.new(1, 0, 0, 0)
                
                TweenService:Create(optionsFrame, tweenInfo, {
                    Size = UDim2.new(1, 0, 0, targetHeight),
                    GroupTransparency = 0,
                }):Play()
            else
                local collapseTween = TweenService:Create(optionsFrame, tweenInfo, {
                    Size = UDim2.new(1, 0, 0, 0),
                    GroupTransparency = 1,
                })
                collapseTween:Play()
                collapseTween.Completed:Connect(function()
                    if not self.state.isOpen then
                        optionsFrame.Visible = false
                    end
                end)
            end
        end
    end
end

function Dropdown:render()
    local el = self.props.element
    local Store = self.props.Store
    
    local options = el.options or {}
    local isMulti = el.maximum ~= nil and el.maximum > 1
    
    local hovered = self.state.hovered
    local isOpen = self.state.isOpen
    
    local currentVal = el.value
    if isMulti then
        if type(currentVal) ~= "table" then
            currentVal = type(currentVal) == "number" and { currentVal } or {}
        end
    else
        currentVal = currentVal or 1 -- Default to index 1
    end
    
    -- Compute header text display
    local headerDisplay = "Select..."
    if isMulti then
        if #currentVal > 0 then
            local selectedNames = {}
            for _, idx in ipairs(currentVal) do
                if options[idx] then
                    table.insert(selectedNames, tostring(options[idx]))
                end
            end
            headerDisplay = table.concat(selectedNames, ", ")
        end
    else
        headerDisplay = tostring(options[currentVal] or "Select...")
    end
    
    local optionButtons = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        
        Padding = React.createElement("UIPadding", {
            PaddingTop = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 4),
        }),
    }
    
    for i, opt in ipairs(options) do
        local isSelected = false
        if isMulti then
            isSelected = table_find(currentVal, i) ~= nil
        else
            isSelected = i == currentVal
        end
        
        optionButtons["Opt_" .. tostring(i)] = React.createElement(DropdownOption, {
            opt = opt,
            isSelected = isSelected,
            isMulti = isMulti,
            LayoutOrder = i,
            OnClick = function()
                if isMulti then
                    local newVal = table_clone(currentVal)
                    local existingIdx = table_find(newVal, i)
                    if existingIdx then
                        table.remove(newVal, existingIdx)
                    else
                        if #newVal < el.maximum then
                            table.insert(newVal, i)
                        end
                    end
                    
                    Store:UpdateElement(el.id, function(element)
                        element.value = newVal
                    end)
                    
                    if el.callback then
                        task.spawn(el.callback, newVal)
                    end
                else
                    Store:UpdateElement(el.id, function(element)
                        element.value = i
                    end)
                    self:setState({ isOpen = false })
                    if el.callback then
                        task.spawn(el.callback, i)
                    end
                end
            end,
        })
    end
    
    local hideLabel = el.hideLabel
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, {
        List = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        
        -- Main Dropdown Button
        Header = React.createElement("TextButton", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Theme.Colors.Element,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = 1,
            [React.Event.MouseEnter] = function() self:setState({ hovered = true }) end,
            [React.Event.MouseLeave] = function() self:setState({ hovered = false }) end,
            [React.Event.MouseButton1Click] = function()
                self:setState({ isOpen = not isOpen })
            end,
        }, {
            Corner = React.createElement("UICorner", {
                CornerRadius = Theme.CornerRadius.Element,
            }),
            
            Stroke = React.createElement("UIStroke", {
                ref = self.strokeRef,
                Color = (hovered or isOpen) and Theme.Colors.BorderHover or Theme.Colors.Border,
                Thickness = 1,
            }),
            
            -- Title / Label
            Title = not hideLabel and React.createElement("TextLabel", {
                Size = UDim2.new(0.5, 0, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = el.name or "Dropdown",
                TextColor3 = Theme.Colors.TextSecondary,
                Font = Theme.Fonts.Medium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            }) or nil,
            
            -- Selected Value (Right side, or expanded left side if hideLabel)
            Selected = React.createElement("TextLabel", {
                Size = hideLabel and UDim2.new(1, -40, 1, 0) or UDim2.new(0.5, -30, 1, 0),
                Position = hideLabel and UDim2.new(0, 10, 0, 0) or UDim2.new(1, -30, 0, 0),
                AnchorPoint = hideLabel and Vector2.new(0, 0) or Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Text = headerDisplay,
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Bold,
                TextSize = 12,
                TextXAlignment = hideLabel and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }),
            
            -- Arrow Icon
            Arrow = React.createElement("ImageLabel", {
                ref = self.arrowRef,
                Size = UDim2.new(0, 14, 0, 14),
                Position = UDim2.new(1, -22, 0.5, -7),
                BackgroundTransparency = 1,
                Image = "rbxassetid://10747383844", -- Arrow down
                ImageColor3 = Theme.Colors.TextSecondary,
            }),
        }),
        
        -- Options List
        Options = React.createElement("CanvasGroup", {
            ref = self.optionsRef,
            BackgroundTransparency = 1,
            LayoutOrder = 2,
            ClipsDescendants = true,
        }, optionButtons),
    })
end

return Dropdown

end

__modules["Components/ElementRenderer"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local CustomComponentPlaceholder = React.Component:extend("CustomComponentPlaceholder")

function CustomComponentPlaceholder:init()
    self.frameRef = React.createRef()
end

function CustomComponentPlaceholder:didMount()
    local container = self.frameRef and self.frameRef.current
    local el = self.props.element
    if container and el.instance then
        el.instance.Parent = container
        el.instance.Size = UDim2.new(1, 0, 1, 0)
        el.instance.Position = UDim2.new(0, 0, 0, 0)
    end
end

function CustomComponentPlaceholder:didUpdate(prevProps)
    local container = self.frameRef and self.frameRef.current
    local el = self.props.element
    local prevEl = prevProps.element
    
    if prevEl and prevEl.instance and prevEl.instance ~= el.instance then
        prevEl.instance.Parent = nil
    end
    
    if container and el.instance then
        el.instance.Parent = container
        el.instance.Size = UDim2.new(1, 0, 1, 0)
        el.instance.Position = UDim2.new(0, 0, 0, 0)
    end
end

function CustomComponentPlaceholder:willUnmount()
    local el = self.props.element
    if el.instance then
        el.instance.Parent = nil
    end
end

function CustomComponentPlaceholder:render()
    local el = self.props.element
    local size = el.instance and el.instance.Size or UDim2.new(1, 0, 0, 70) -- Match test.lua custom component height
    return React.createElement("Frame", {
        ref = self.frameRef,
        Size = size,
        BackgroundTransparency = 1,
    })
end

local ElementRenderer = {}

function ElementRenderer.render(el, Store)
    local elType = el.type
    
    if elType == "Button" then
        return React.createElement(require(Source.Components.Button), { element = el, Store = Store })
    elseif elType == "Toggle" then
        return React.createElement(require(Source.Components.Toggle), { element = el, Store = Store })
    elseif elType == "Slider" then
        return React.createElement(require(Source.Components.Slider), { element = el, Store = Store })
    elseif elType == "Dropdown" then
        return React.createElement(require(Source.Components.Dropdown), { element = el, Store = Store })
    elseif elType == "TextBox" then
        return React.createElement(require(Source.Components.TextBox), { element = el, Store = Store })
    elseif elType == "Label" then
        return React.createElement(require(Source.Components.Label), { element = el, Store = Store })
    elseif elType == "Paragraph" then
        return React.createElement(require(Source.Components.Paragraph), { element = el, Store = Store })
    elseif elType == "InfoGrid" then
        return React.createElement(require(Source.Components.InfoGrid), { element = el, Store = Store })
    elseif elType == "VStack" then
        return React.createElement(require(Source.Components.VStack), { element = el, Store = Store })
    elseif elType == "HStack" then
        return React.createElement(require(Source.Components.HStack), { element = el, Store = Store })
    elseif elType == "ColorPicker" then
        return React.createElement(require(Source.Components.ColorPicker), { element = el, Store = Store })
    elseif elType == "ColorPickerWidget" then
        return React.createElement(require(Source.Components.ColorPickerWidget), { element = el, Store = Store })
    elseif elType == "KeybindField" then
        return React.createElement(require(Source.Components.KeybindField), { element = el, Store = Store })
    elseif elType == "Stepper" then
        return React.createElement(require(Source.Components.Stepper), { element = el, Store = Store })
    elseif elType == "RadioButtonGroup" then
        return React.createElement(require(Source.Components.RadioButtonGroup), { element = el, Store = Store })
    elseif elType == "BarChart" then
        return React.createElement(require(Source.Components.BarChart), { element = el, Store = Store })
    elseif elType == "LineChart" then
        return React.createElement(require(Source.Components.LineChart), { element = el, Store = Store })
    elseif elType == "PieChart" then
        return React.createElement(require(Source.Components.PieChart), { element = el, Store = Store })
    elseif elType == "PullDownButton" then
        return React.createElement(require(Source.Components.PullDownButton), { element = el, Store = Store })
    elseif elType == "TitleStack" then
        return React.createElement(require(Source.Components.TitleStack), { element = el, Store = Store })
    elseif elType == "Row" then
        return React.createElement(require(Source.Components.Row), { element = el, Store = Store })
    elseif elType == "Form" then
        return React.createElement(require(Source.Components.Form), { element = el, Store = Store })
    elseif elType == "Section" then
        return React.createElement(require(Source.Components.Section), { section = el, Store = Store })
    elseif elType == "CustomComponentPlaceholder" then
        return React.createElement(CustomComponentPlaceholder, { element = el })
    end
    
    return nil
end

return ElementRenderer

end

__modules["Components/Form"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local ElementRenderer = require(Source.Components.ElementRenderer)

local Form = React.Component:extend("Form")

function Form:render()
    local el = self.props.element
    local Store = self.props.Store
    
    local children = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }
    
    for i, subEl in ipairs(el.elements or {}) do
        local elementComponent = ElementRenderer.render(subEl, Store)
        if elementComponent then
            children["Row_" .. subEl.id] = React.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = i,
            }, {
                Content = elementComponent,
            })
        end
    end
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, children)
end

return Form

end

__modules["Components/HStack"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local ElementRenderer = require(Source.Components.ElementRenderer)

local HStack = React.Component:extend("HStack")

function HStack:render()
    local el = self.props.element
    local Store = self.props.Store
    
    local N = #el.elements
    local gap = el.padding and el.padding.Offset or 6
    
    local children = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, gap),
            HorizontalAlignment = el.horizontalAlignment or Enum.HorizontalAlignment.Left,
            VerticalAlignment = el.verticalAlignment or Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }
    
    for i, subEl in ipairs(el.elements or {}) do
        local elementComponent = ElementRenderer.render(subEl, Store)
        if elementComponent then
            local scale = 1 / N
            local offset = -gap * (1 - scale)
            
            children["El_" .. subEl.id] = React.createElement("Frame", {
                Size = UDim2.new(scale, offset, 0, 0),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = i,
            }, {
                Content = elementComponent,
            })
        end
    end
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, children)
end

return HStack

end

__modules["Components/InfoGrid"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local InfoGridBlock = React.Component:extend("InfoGridBlock")

function InfoGridBlock:init()
    self.state = { hovered = false }
end

function InfoGridBlock:render()
    local props = self.props
    local block = props.block
    local scale = props.scale
    local widthOffset = props.widthOffset
    local layoutOrder = props.LayoutOrder
    local hovered = self.state.hovered
    
    local hasCallback = block.callback ~= nil
    
    local bg = (hasCallback and hovered) and Theme.Colors.ElementHover or Theme.Colors.Element
    local border = (hasCallback and hovered) and Theme.Colors.BorderHover or Theme.Colors.Border
        
    local elementProps = {
        Size = UDim2.new(scale, widthOffset, 1, 0),
        BackgroundColor3 = bg,
        BorderSizePixel = 0,
        LayoutOrder = layoutOrder,
    }
    
    if hasCallback then
        elementProps.Text = ""
        elementProps.AutoButtonColor = false
        elementProps[React.Event.MouseEnter] = function() self:setState({ hovered = true }) end
        elementProps[React.Event.MouseLeave] = function() self:setState({ hovered = false }) end
        elementProps[React.Event.MouseButton1Click] = function()
            if block.callback then
                task.spawn(block.callback)
            end
        end
    end
    
    return React.createElement(hasCallback and "TextButton" or "Frame", elementProps, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Element,
        }),
        
        Stroke = React.createElement("UIStroke", {
            Color = border,
            Thickness = 1,
        }),
        
        Padding = React.createElement("UIPadding", {
            PaddingTop = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
        }),
        
        Content = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
        }, {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 2),
            }),
            
            Title = React.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 12),
                BackgroundTransparency = 1,
                Text = block.title or "",
                TextColor3 = Theme.Colors.TextSecondary,
                Font = Theme.Fonts.Medium,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }),
            
            Val = React.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 1, -14),
                BackgroundTransparency = 1,
                Text = block.content or "",
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Bold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
            }),
        }),
    })
end

local InfoGrid = React.Component:extend("InfoGrid")

function InfoGrid:render()
    local el = self.props.element
    local rows = el.rows or {}
    
    local rowElements = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }
    
    local gap = 8 -- Gap between columns
    
    for i, row in ipairs(rows) do
        local totalWeight = 0
        for _, block in ipairs(row) do
            totalWeight = totalWeight + (block.weight or 1)
        end
        
        local blockElements = {
            Layout = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, gap),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        }
        
        for j, block in ipairs(row) do
            local weight = block.weight or 1
            local scale = weight / totalWeight
            local widthOffset = -gap * (1 - scale)
            
            blockElements["Block_" .. tostring(j)] = React.createElement(InfoGridBlock, {
                block = block,
                scale = scale,
                widthOffset = widthOffset,
                LayoutOrder = j,
            })
        end
        
        rowElements["Row_" .. tostring(i)] = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 50),
            BackgroundTransparency = 1,
            LayoutOrder = i,
        }, blockElements)
    end
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, rowElements)
end

return InfoGrid

end

__modules["Components/KeybindField"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local KeybindField = React.Component:extend("KeybindField")

function KeybindField:init()
    self.connection = nil
    self.state = {
        hovered = false,
        listening = false,
    }
end

function KeybindField:willUnmount()
    if self.connection then
        self.connection:Disconnect()
    end
end

function KeybindField:render()
    local el = self.props.element
    local Store = self.props.Store
    
    local currentBind = el.value or Enum.KeyCode.Unknown
    local isUnknown = currentBind == Enum.KeyCode.Unknown
    local label = isUnknown and "None" or currentBind.Name
    
    local hovered = self.state.hovered
    local listening = self.state.listening
    local buttonText = listening and "..." or label
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
    }, {
        -- Left text label
        Label = React.createElement("TextLabel", {
            Size = UDim2.new(1, -120, 1, 0),
            BackgroundTransparency = 1,
            Text = el.name or "Keybind",
            TextColor3 = Theme.Colors.Text,
            Font = Theme.Fonts.Medium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }),
        
        -- Right Bind Button
        BindButton = React.createElement("TextButton", {
            Size = UDim2.new(0, 100, 0, 26),
            Position = UDim2.new(1, -100, 0.5, -13),
            BackgroundColor3 = listening and Theme.Colors.Accent or Theme.Colors.Element,
            BorderSizePixel = 0,
            Text = buttonText,
            TextColor3 = Theme.Colors.Text,
            Font = Theme.Fonts.Bold,
            TextSize = 11,
            AutoButtonColor = false,
            [React.Event.MouseEnter] = function() self:setState({ hovered = true }) end,
            [React.Event.MouseLeave] = function() self:setState({ hovered = false }) end,
            [React.Event.MouseButton1Click] = function()
                if listening then return end
                
                self:setState({ listening = true })
                
                if self.connection then
                    self.connection:Disconnect()
                end
                
                self.connection = UserInputService.InputBegan:Connect(function(input, processed)
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        local key = input.KeyCode
                        
                        if key == Enum.KeyCode.Escape then
                            key = Enum.KeyCode.Unknown
                        end
                        
                        Store:UpdateElement(el.id, function(element)
                            element.value = key
                        end)
                        
                        self:setState({ listening = false })
                        if self.connection then
                            self.connection:Disconnect()
                            self.connection = nil
                        end
                        
                        if el.callback then
                            task.spawn(el.callback, key)
                        end
                    end
                end)
            end,
        }, {
            Corner = React.createElement("UICorner", {
                CornerRadius = Theme.CornerRadius.Element,
            }),
            
            Stroke = React.createElement("UIStroke", {
                Color = (hovered or listening) and Theme.Colors.BorderHover or Theme.Colors.Border,
                Thickness = 1,
            }),
        }),
    })
end

return KeybindField

end

__modules["Components/Label"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local Label = React.Component:extend("Label")

function Label:render()
    local el = self.props.element
    
    return React.createElement("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = el.text or "Label",
        TextColor3 = el.color or Theme.Colors.Text,
        Font = el.font or Theme.Fonts.Medium,
        TextSize = el.textSize or 13,
        TextXAlignment = el.alignment or Enum.TextXAlignment.Left,
        RichText = true,
    })
end

return Label

end

__modules["Components/LineChart"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local TweenService = game:GetService("TweenService")
local TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local AnimatedLine = React.Component:extend("AnimatedLine")
function AnimatedLine:init()
    self.ref = React.createRef()
end
function AnimatedLine:didMount()
    local frame = self.ref and self.ref.current
    if frame then
        local p = self.props
        frame.Size = p.targetSize
        frame.Position = p.targetPosition
        frame.Rotation = p.targetRotation
    end
end
function AnimatedLine:didUpdate(prevProps)
    local frame = self.ref and self.ref.current
    if frame then
        local p = self.props
        if prevProps.targetSize ~= p.targetSize or prevProps.targetPosition ~= p.targetPosition or prevProps.targetRotation ~= p.targetRotation then
            frame.Size = prevProps.targetSize
            frame.Position = prevProps.targetPosition
            frame.Rotation = prevProps.targetRotation
            TweenService:Create(frame, TWEEN_INFO, {
                Size = p.targetSize,
                Position = p.targetPosition,
                Rotation = p.targetRotation,
            }):Play()
        end
    end
end
function AnimatedLine:render()
    local p = self.props
    return React.createElement("Frame", {
        ref = self.ref,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = p.color,
        BorderSizePixel = 0,
        ZIndex = 1,
    })
end

local AnimatedDot = React.Component:extend("AnimatedDot")
function AnimatedDot:init()
    self.ref = React.createRef()
end
function AnimatedDot:didMount()
    local frame = self.ref and self.ref.current
    if frame then
        frame.Position = self.props.targetPosition
    end
end
function AnimatedDot:didUpdate(prevProps)
    local frame = self.ref and self.ref.current
    if frame and prevProps.targetPosition ~= self.props.targetPosition then
        frame.Position = prevProps.targetPosition
        TweenService:Create(frame, TWEEN_INFO, {
            Position = self.props.targetPosition,
        }):Play()
    end
end
function AnimatedDot:render()
    local p = self.props
    return React.createElement("Frame", {
        ref = self.ref,
        Size = UDim2.new(0, 6, 0, 6),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 2,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Circle,
        }),
        Stroke = React.createElement("UIStroke", {
            Color = p.color,
            Thickness = 1.5,
        }),
    })
end

local LineChart = React.Component:extend("LineChart")

function LineChart:init()
    self.canvasRef = React.createRef()
    self.state = {
        canvasSize = Vector2.new(300, 100) -- Default fallback size
    }
end

function LineChart:didMount()
    local canvas = self.canvasRef and self.canvasRef.current
    if canvas then
        self.sizeConnection = canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            self:setState({
                canvasSize = canvas.AbsoluteSize
            })
        end)
        -- Set initial size
        self:setState({
            canvasSize = canvas.AbsoluteSize
        })
    end
end

function LineChart:willUnmount()
    if self.sizeConnection then
        self.sizeConnection:Disconnect()
    end
end

function LineChart:render()
    local el = self.props.element
    
    local title = el.title or "Line Chart"
    local subtitle = el.subtitle
    local height = el.height or 180
    local data = el.data or {}
    local labels = el.labels or {}
    local lineColor = el.color or Theme.Colors.Accent
    local N = #data
    
    local canvasSize = self.state.canvasSize
    
    local maxVal = 0
    for _, item in ipairs(data) do
        local val = type(item) == "table" and (item.value or item.Value or 0) or (tonumber(item) or 0)
        if val > maxVal then maxVal = val end
    end
    if maxVal == 0 then maxVal = 1 end
    
    -- Calculate screen coordinates for points
    local points = {}
    for i = 1, N do
        local item = data[i]
        local val = type(item) == "table" and (item.value or item.Value or 0) or (tonumber(item) or 0)
        local pct = val / maxVal
        local x = canvasSize.X * (i - 1) / math.max(N - 1, 1)
        -- Leave 15% padding at top and bottom of canvas
        local y = canvasSize.Y * (1 - (pct * 0.7 + 0.15))
        table.insert(points, Vector2.new(x, y))
    end
    
    local chartElements = {}
    
    -- Draw lines between points
    if N > 1 then
        for i = 1, N - 1 do
            local p1 = points[i]
            local p2 = points[i+1]
            
            local diff = p2 - p1
            local dist = diff.Magnitude
            local angle = math.deg(math.atan2(diff.Y, diff.X))
            
            chartElements["Line_" .. tostring(i)] = React.createElement(AnimatedLine, {
                targetSize = UDim2.new(0, dist, 0, 2),
                targetPosition = UDim2.new(0, p1.X + diff.X/2, 0, p1.Y + diff.Y/2),
                targetRotation = angle,
                color = lineColor,
            })
        end
    end
    
    -- Draw point dot handles
    for i, p in ipairs(points) do
        chartElements["Dot_" .. tostring(i)] = React.createElement(AnimatedDot, {
            targetPosition = UDim2.new(0, p.X, 0, p.Y),
            color = lineColor,
        })
    end
    
    -- Draw bottom label tags
    local labelElements = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }
    
    for i = 1, N do
        local labelText = labels[i] or ""
        local scale = 1 / N
        
        labelElements["Label_" .. tostring(i)] = React.createElement("TextLabel", {
            Size = UDim2.new(scale, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = labelText,
            TextColor3 = Theme.Colors.TextSecondary,
            Font = Theme.Fonts.Medium,
            TextSize = 9,
            LayoutOrder = i,
        })
    end
    
    -- Calculate Header Height for layout offset
    local headerHeight = 0
    if title or subtitle then
        if title then headerHeight = headerHeight + 16 end
        if subtitle then headerHeight = headerHeight + 12 end
        if title and subtitle then headerHeight = headerHeight + 2 end -- list padding
        headerHeight = headerHeight + 10 -- list layout padding between header and chart
    end
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = Theme.Colors.Element,
        BorderSizePixel = 0,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Card,
        }),
        
        Stroke = React.createElement("UIStroke", {
            Color = Theme.Colors.Border,
            Thickness = 1,
        }),
        
        Padding = React.createElement("UIPadding", {
            PaddingTop = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
        }),
        
        List = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        
        -- Header text
        Header = (title or subtitle) and React.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1,
        }, {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 2),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            
            TitleLabel = title and React.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                Text = title,
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Bold,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
            }),
            
            SubLabel = subtitle and React.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 12),
                BackgroundTransparency = 1,
                Text = subtitle,
                TextColor3 = Theme.Colors.TextSecondary,
                Font = Theme.Fonts.Regular,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 2,
            }),
        }),
        
        -- Main Graph Area (Canvas & Axis & Labels)
        ChartContainer = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 1, -headerHeight),
            BackgroundTransparency = 1,
            LayoutOrder = 2,
        }, {
            -- Y-Axis Labels
            YAxis = React.createElement("Frame", {
                Name = "YAxis",
                Size = UDim2.new(0, 24, 1, -16),
                BackgroundTransparency = 1,
            }, {
                Max = React.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 10),
                    Position = UDim2.fromScale(0, 0.15),
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundTransparency = 1,
                    Text = tostring(maxVal),
                    TextColor3 = Theme.Colors.TextSecondary,
                    Font = Theme.Fonts.Medium,
                    TextSize = 8,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }),
                Mid = React.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 10),
                    Position = UDim2.fromScale(0, 0.5),
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundTransparency = 1,
                    Text = tostring(math.round(maxVal / 2)),
                    TextColor3 = Theme.Colors.TextSecondary,
                    Font = Theme.Fonts.Medium,
                    TextSize = 8,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }),
                Min = React.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 10),
                    Position = UDim2.fromScale(0, 0.85),
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundTransparency = 1,
                    Text = "0",
                    TextColor3 = Theme.Colors.TextSecondary,
                    Font = Theme.Fonts.Medium,
                    TextSize = 8,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }),
            }),
            
            -- Plot Container (GridLines, YAxisLine, Canvas, X-Labels)
            PlotContainer = React.createElement("Frame", {
                Name = "PlotContainer",
                Size = UDim2.new(1, -28, 1, 0),
                Position = UDim2.new(0, 28, 0, 0),
                BackgroundTransparency = 1,
            }, {
                -- Grid Lines
                GridLine_Top = React.createElement("Frame", {
                    Size = UDim2.new(1, 0, 0, 1),
                    Position = UDim2.fromScale(0, 0.15),
                    BackgroundColor3 = Theme.Colors.Border,
                    BackgroundTransparency = 0.6,
                    BorderSizePixel = 0,
                }),
                GridLine_Mid = React.createElement("Frame", {
                    Size = UDim2.new(1, 0, 0, 1),
                    Position = UDim2.fromScale(0, 0.5),
                    BackgroundColor3 = Theme.Colors.Border,
                    BackgroundTransparency = 0.6,
                    BorderSizePixel = 0,
                }),
                GridLine_Bottom = React.createElement("Frame", {
                    Size = UDim2.new(1, 0, 0, 1),
                    Position = UDim2.fromScale(0, 0.85),
                    BackgroundColor3 = Theme.Colors.Border,
                    BackgroundTransparency = 0.6,
                    BorderSizePixel = 0,
                }),
                
                -- Y-Axis Line
                YAxisLine = React.createElement("Frame", {
                    Size = UDim2.new(0, 1, 1, -16),
                    Position = UDim2.fromScale(0, 0),
                    BackgroundColor3 = Theme.Colors.Border,
                    BorderSizePixel = 0,
                }),
                
                -- Canvas for lines & dots
                Canvas = React.createElement("Frame", {
                    ref = self.canvasRef,
                    Size = UDim2.new(1, 0, 1, -16),
                    BackgroundTransparency = 1,
                }, chartElements),
                
                -- Labels row at the bottom
                LabelsRow = React.createElement("Frame", {
                    Size = UDim2.new(1, 0, 0, 16),
                    Position = UDim2.new(0, 0, 1, -16),
                    BackgroundTransparency = 1,
                }, labelElements),
            })
        }),
    })
end

return LineChart

end

__modules["Components/Notification"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local NotificationItem = React.Component:extend("NotificationItem")

function NotificationItem:init()
    self.groupRef = React.createRef()
    self.scaleRef = React.createRef()
end

function NotificationItem:didMount()
    local group = self.groupRef and self.groupRef.current
    if group then
        -- Entrance Slide & Fade Animation
        group.Position = UDim2.new(1, 50, 0, 0)
        group.GroupTransparency = 1
        
        local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        TweenService:Create(group, tweenInfo, {
            Position = UDim2.new(0, 0, 0, 0),
            GroupTransparency = 0,
        }):Play()
    end
end

function NotificationItem:didUpdate(prevProps)
    if self.props.item.count ~= prevProps.item.count then
        local scale = self.scaleRef and self.scaleRef.current
        if scale then
            -- Pop scale up and smoothly bounce back to 1
            scale.Scale = 1.08
            local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            TweenService:Create(scale, tweenInfo, {
                Scale = 1,
            }):Play()
        end
    end
end

function NotificationItem:render()
    local item = self.props.item
    local title = item.title or "Notification"
    local subtitle = item.subtitle or ""
    local icon = item.icon or "rbxassetid://10747373111" -- Default checkmark
    local count = item.count or 1
    
    local children = {}
    
    -- Stack Card 2 (backmost duplicate card)
    if count >= 3 then
        children.StackCard2 = React.createElement("Frame", {
            Size = UDim2.new(0.92, 0, 1, 0),
            Position = UDim2.new(0.04, 0, 0, -8),
            BackgroundColor3 = Theme.Colors.Card,
            BorderSizePixel = 0,
            ZIndex = 1,
        }, {
            Corner = React.createElement("UICorner", {
                CornerRadius = Theme.CornerRadius.Card,
            }),
            Stroke = React.createElement("UIStroke", {
                Color = Theme.Colors.Border,
                Thickness = 1,
                Transparency = 0.6,
            }),
        })
    end
    
    -- Stack Card 1 (middle duplicate card)
    if count >= 2 then
        children.StackCard1 = React.createElement("Frame", {
            Size = UDim2.new(0.96, 0, 1, 0),
            Position = UDim2.new(0.02, 0, 0, -4),
            BackgroundColor3 = Theme.Colors.Card,
            BorderSizePixel = 0,
            ZIndex = 2,
        }, {
            Corner = React.createElement("UICorner", {
                CornerRadius = Theme.CornerRadius.Card,
            }),
            Stroke = React.createElement("UIStroke", {
                Color = Theme.Colors.Border,
                Thickness = 1,
                Transparency = 0.3,
            }),
        })
    end
    
    -- Main Card (frontmost card)
    children.MainCard = React.createElement("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Theme.Colors.Card,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Card,
        }),
        
        Stroke = React.createElement("UIStroke", {
            Color = Theme.Colors.Border,
            Thickness = 1,
        }),
        
        Padding = React.createElement("UIPadding", {
            PaddingTop = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
        }),
        
        List = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 10),
        }),
        
        -- App Icon
        AppIcon = React.createElement("ImageLabel", {
            Size = UDim2.new(0, 24, 0, 24),
            BackgroundTransparency = 1,
            Image = icon,
            ImageColor3 = Theme.Colors.Accent,
        }),
        
        -- Text labels
        TextFrame = React.createElement("Frame", {
            Size = UDim2.new(1, -34, 1, 0),
            BackgroundTransparency = 1,
        }, {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 2),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            
            TitleLabel = React.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                Text = (count > 1) 
                    and (title .. " <font color=\"" .. string.format("#%02x%02x%02x", math.floor(Theme.Colors.Accent.R * 255), math.floor(Theme.Colors.Accent.G * 255), math.floor(Theme.Colors.Accent.B * 255)) .. "\">x" .. tostring(count) .. "</font>") 
                    or title,
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Bold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                RichText = true,
                LayoutOrder = 1,
            }),
            
            SubLabel = React.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 14),
                BackgroundTransparency = 1,
                Text = subtitle,
                TextColor3 = Theme.Colors.TextSecondary,
                Font = Theme.Fonts.Regular,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                LayoutOrder = 2,
            }),
        }),
    })
    
    -- Add UIScale for bounce animation
    children.Scale = React.createElement("UIScale", {
        ref = self.scaleRef,
        Scale = 1,
    })
    
    return React.createElement("CanvasGroup", {
        ref = self.groupRef,
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundTransparency = 1,
    }, children)
end


local NotificationList = React.Component:extend("NotificationList")

function NotificationList:render()
    local list = self.props.notifications or {}
    
    local notificationElements = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 10),
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }
    
    for i, item in ipairs(list) do
        notificationElements["Item_" .. tostring(item.id)] = React.createElement(NotificationItem, {
            item = item,
            LayoutOrder = i,
        })
    end
    
    return React.createElement("Frame", {
        Size = UDim2.new(0, 280, 0, 0),
        Position = UDim2.new(1, -20, 1, -20),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 9999, -- Render on top of everything
    }, notificationElements)
end

return {
    List = NotificationList,
    Item = NotificationItem,
}

end

__modules["Components/Paragraph"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local Paragraph = React.Component:extend("Paragraph")

function Paragraph:render()
    local el = self.props.element
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, {
        List = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        
        Title = el.title and React.createElement("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = el.title,
            TextColor3 = Theme.Colors.Text,
            Font = Theme.Fonts.Bold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
        }),
        
        Body = React.createElement("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = el.content or "",
            TextColor3 = Theme.Colors.TextSecondary,
            Font = Theme.Fonts.Regular,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 2,
        }),
    })
end

return Paragraph

end

__modules["Components/PieChart"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local TWEEN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Semi-Circle UIGradient Wedge component (Zero overlap, zero gaps, zero flickering, perfect clipping)
local AnimatedWedge = React.Component:extend("AnimatedWedge")

function AnimatedWedge:init()
    self.containerRef = React.createRef()
    self.gradientRef = React.createRef()
end

function AnimatedWedge:didMount()
    local container = self.containerRef and self.containerRef.current
    local gradient = self.gradientRef and self.gradientRef.current
    if container and gradient then
        container.Rotation = self.props.startAngle
        gradient.Rotation = math.clamp(self.props.sweepAngle, 0.1, 180)
    end
end

function AnimatedWedge:didUpdate(prevProps)
    local container = self.containerRef and self.containerRef.current
    local gradient = self.gradientRef and self.gradientRef.current
    if container and gradient then
        local p = self.props
        local targetSweep = math.clamp(p.sweepAngle, 0.1, 180)
        
        if prevProps.startAngle ~= p.startAngle then
            container.Rotation = prevProps.startAngle
            TweenService:Create(container, TWEEN_INFO, {
                Rotation = p.startAngle
            }):Play()
        end
        
        if prevProps.sweepAngle ~= p.sweepAngle then
            local prevSweep = math.clamp(prevProps.sweepAngle or 0, 0.1, 180)
            gradient.Rotation = prevSweep
            TweenService:Create(gradient, TWEEN_INFO, {
                Rotation = targetSweep
            }):Play()
        end
    end
end

function AnimatedWedge:render()
    local p = self.props
    return React.createElement("Frame", {
        ref = self.containerRef,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = p.zIndex or 1,
    }, {
        ClipBox = React.createElement("Frame", {
            Size = UDim2.new(0.5, 0, 1, 0),
            Position = UDim2.new(0.5, 0, 0, 0),
            AnchorPoint = Vector2.new(0, 0),
            ClipsDescendants = true,
            BackgroundTransparency = 1,
        }, {
            CircleSegment = React.createElement("Frame", {
                Size = UDim2.new(2, 0, 1, 0),
                Position = UDim2.new(-1, 0, 0, 0),
                AnchorPoint = Vector2.new(0, 0),
                BackgroundColor3 = p.color,
                BorderSizePixel = 0,
            }, {
                Corner = React.createElement("UICorner", {
                    CornerRadius = UDim.new(0.5, 0),
                }),
                Gradient = React.createElement("UIGradient", {
                    ref = self.gradientRef,
                    Rotation = math.clamp(p.sweepAngle, 0.1, 180),
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0),
                        NumberSequenceKeypoint.new(0.5, 0),
                        NumberSequenceKeypoint.new(0.5001, 1),
                        NumberSequenceKeypoint.new(1, 1),
                    }),
                }),
            }),
        }),
    })
end

local PieChart = React.Component:extend("PieChart")

function PieChart:render()
    local el = self.props.element
    
    local title = el.title
    local subtitle = el.subtitle
    local size = el.size or 140
    local isDonut = el.donut == true
    local data = el.data or {}
    local align = el.align or "Right"
    
    local totalSum = 0
    for _, item in ipairs(data) do
        local val = type(item) == "table" and (item.value or item.Value or 0) or (tonumber(item) or 0)
        totalSum = totalSum + val
    end
    
    local wedges = {}
    if totalSum <= 0 then
        wedges.Placeholder = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(80, 80, 80),
            BorderSizePixel = 0,
        }, {
            Corner = React.createElement("UICorner", {
                CornerRadius = UDim.new(0.5, 0),
            }),
        })
    else
        local currentAngle = 0
        for i, item in ipairs(data) do
            local val = type(item) == "table" and (item.value or item.Value or 0) or (tonumber(item) or 0)
            if val > 0 then
                local sweep = (val / totalSum) * 360
                local color = type(item) == "table" and (item.color or item.Color or Theme.Colors.Accent) or Theme.Colors.Accent
                
                if sweep <= 180 then
                    wedges["Slice_" .. tostring(i) .. "_1"] = React.createElement(AnimatedWedge, {
                        startAngle = currentAngle,
                        sweepAngle = sweep,
                        color = color,
                        zIndex = i,
                    })
                else
                    wedges["Slice_" .. tostring(i) .. "_1"] = React.createElement(AnimatedWedge, {
                        startAngle = currentAngle,
                        sweepAngle = 180,
                        color = color,
                        zIndex = i,
                    })
                    wedges["Slice_" .. tostring(i) .. "_2"] = React.createElement(AnimatedWedge, {
                        startAngle = currentAngle + 180,
                        sweepAngle = sweep - 180,
                        color = color,
                        zIndex = i,
                    })
                end
                
                currentAngle = currentAngle + sweep
            end
        end
    end
    
    -- Donut Hollow Center
    if isDonut then
        wedges.DonutHollow = React.createElement("Frame", {
            Name = "DonutCenter",
            Size = UDim2.new(0.6, 0, 0.6, 0),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Theme.Colors.Element, -- Matches card background
            BorderSizePixel = 0,
            ZIndex = 100,
        }, {
            Corner = React.createElement("UICorner", {
                CornerRadius = UDim.new(0.5, 0),
            }),
        })
    end
    
    -- Legend list items
    local legendItems = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 6),
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }
    
    for i, item in ipairs(data) do
        local val = type(item) == "table" and (item.value or item.Value or 0) or (tonumber(item) or 0)
        local labelText = type(item) == "table" and (item.label or item.Label or "Category") or ("Category " .. tostring(i))
        local color = type(item) == "table" and (item.color or item.Color or Theme.Colors.Accent) or Theme.Colors.Accent
        local pct = totalSum > 0 and math.round((val / totalSum) * 100) or 0
        
        legendItems["Legend_" .. tostring(i)] = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            LayoutOrder = i,
        }, {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            
            -- Color square indicator
            Indicator = React.createElement("Frame", {
                Size = UDim2.fromOffset(8, 8),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                LayoutOrder = 1,
            }, {
                Corner = React.createElement("UICorner", {
                    CornerRadius = UDim.new(0, 2),
                }),
            }),
            
            -- Label text
            Label = React.createElement("TextLabel", {
                Size = UDim2.new(0.5, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = labelText,
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Medium,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 2,
            }),
            
            -- Percentage text
            Percent = React.createElement("TextLabel", {
                Size = UDim2.new(0.5, -16, 1, 0),
                BackgroundTransparency = 1,
                Text = tostring(pct) .. "%",
                TextColor3 = Theme.Colors.TextSecondary,
                Font = Theme.Fonts.Bold,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Right,
                LayoutOrder = 3,
            }),
        })
    end
    
    local textOrder = align == "Right" and 1 or 3
    local chartOrder = align == "Right" and 3 or 1
    
    local contentChildren = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 12),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        
        -- Chart circle/donut visual wrapped inside CanvasGroup
        ChartArea = React.createElement("Frame", {
            Name = "ChartArea",
            Size = UDim2.fromOffset(size, size),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = chartOrder,
        }, {
            OuterCircleClip = React.createElement("CanvasGroup", {
                Size = UDim2.fromScale(1, 1),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                GroupTransparency = 0,
                BorderSizePixel = 0,
            }, {
                Corner = React.createElement("UICorner", {
                    CornerRadius = UDim.new(0.5, 0),
                }),
                WedgeContainer = React.createElement("Frame", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundTransparency = 1,
                }, wedges),
            }),
        }),
        
        -- Legend
        LegendStack = React.createElement("Frame", {
            Size = UDim2.new(1, -size - 12, 1, 0),
            BackgroundTransparency = 1,
            LayoutOrder = 2,
        }, legendItems),
    }
    
    -- If there's a title block on the left (or right)
    local headerElements = nil
    if title or subtitle then
        headerElements = React.createElement("Frame", {
            Size = UDim2.new(0.35, -12, 1, 0),
            BackgroundTransparency = 1,
            LayoutOrder = textOrder,
        }, {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            
            TitleLabel = title and React.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                Text = title,
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Bold,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
            }),
            
            SubLabel = subtitle and React.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 36),
                BackgroundTransparency = 1,
                Text = subtitle,
                TextColor3 = Theme.Colors.TextSecondary,
                Font = Theme.Fonts.Regular,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                LayoutOrder = 2,
            }),
        })
    end
    
    local bodyChildren = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 12),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }
    
    if headerElements then
        bodyChildren.HeaderArea = headerElements
        bodyChildren.Divider = React.createElement("Frame", {
            Size = UDim2.new(0, 1, 1, -10),
            BackgroundColor3 = Theme.Colors.Border,
            BorderSizePixel = 0,
            LayoutOrder = 2,
        })
    end
    
    bodyChildren.ChartAndLegend = React.createElement("Frame", {
        Size = UDim2.new(headerElements and 0.65 or 1, -12, 1, 0),
        BackgroundTransparency = 1,
        LayoutOrder = 3,
    }, contentChildren)
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, size + 20),
        BackgroundColor3 = Theme.Colors.Element,
        BorderSizePixel = 0,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Card,
        }),
        
        Stroke = React.createElement("UIStroke", {
            Color = Theme.Colors.Border,
            Thickness = 1,
        }),
        
        Padding = React.createElement("UIPadding", {
            PaddingTop = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
        }),
        
        Body = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
        }, bodyChildren),
    })
end

return PieChart

end

__modules["Components/Profile"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local Profile = React.Component:extend("Profile")

function Profile:render()
    local username = self.props.username or "Guest"
    local subtext = self.props.subtext or "Welcome to Selene"
    local userId = self.props.userId or 1
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.Colors.Card,
        BorderSizePixel = 0,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Card,
        }),
        
        Stroke = React.createElement("UIStroke", {
            Color = Theme.Colors.Border,
            Thickness = 1,
        }),
        
        Padding = React.createElement("UIPadding", {
            PaddingTop = UDim.new(0, 12),
            PaddingBottom = UDim.new(0, 12),
            PaddingLeft = UDim.new(0, 15),
            PaddingRight = UDim.new(0, 15),
        }),
        
        Content = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
        }, {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 15),
            }),
            
            -- User Thumbnail Image
            Avatar = React.createElement("ImageLabel", {
                Size = UDim2.new(0, 48, 0, 48),
                BackgroundColor3 = Theme.Colors.Element,
                BorderSizePixel = 0,
                Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(userId) .. "&width=150&height=150&format=png",
            }, {
                Corner = React.createElement("UICorner", {
                    CornerRadius = Theme.CornerRadius.Circle,
                }),
                Stroke = React.createElement("UIStroke", {
                    Color = Theme.Colors.Border,
                    Thickness = 1,
                }),
            }),
            
            -- Text block
            Info = React.createElement("Frame", {
                Size = UDim2.new(1, -63, 0, 40),
                BackgroundTransparency = 1,
            }, {
                List = React.createElement("UIListLayout", {
                    FillDirection = Enum.FillDirection.Vertical,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDim.new(0, 2),
                }),
                
                Greeting = React.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundTransparency = 1,
                    Text = "Hello, " .. username,
                    TextColor3 = Theme.Colors.Text,
                    Font = Theme.Fonts.Bold,
                    TextSize = 16,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }),
                
                Sub = React.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 16),
                    BackgroundTransparency = 1,
                    Text = subtext,
                    TextColor3 = Theme.Colors.TextSecondary,
                    Font = Theme.Fonts.Regular,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }),
            }),
        }),
    })
end

return Profile

end

__modules["Components/PullDownButton"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local PullDownOption = React.Component:extend("PullDownOption")

function PullDownOption:init()
    self.state = { hovered = false }
end

function PullDownOption:render()
    local props = self.props
    local opt = props.opt
    local layoutOrder = props.LayoutOrder
    local hovered = self.state.hovered
    
    return React.createElement("TextButton", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = hovered and Theme.Colors.ElementHover or Theme.Colors.Element,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = layoutOrder,
        [React.Event.MouseEnter] = function() self:setState({ hovered = true }) end,
        [React.Event.MouseLeave] = function() self:setState({ hovered = false }) end,
        [React.Event.MouseButton1Click] = props.OnClick,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Element,
        }),
        
        Label = React.createElement("TextLabel", {
            Size = UDim2.new(1, -16, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = tostring(opt),
            TextColor3 = Theme.Colors.Text,
            Font = Theme.Fonts.Medium,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
        }),
    })
end

local PullDownButton = React.Component:extend("PullDownButton")

function PullDownButton:init()
    self.state = {
        hovered = false,
        isOpen = false,
    }
    self.strokeRef = React.createRef()
    self.arrowRef = React.createRef()
    self.optionsRef = React.createRef()
end

function PullDownButton:didMount()
    local stroke = self.strokeRef and self.strokeRef.current
    local arrow = self.arrowRef and self.arrowRef.current
    local optionsFrame = self.optionsRef and self.optionsRef.current
    
    local hovered = self.state.hovered
    local isOpen = self.state.isOpen
    
    if stroke then
        stroke.Color = (hovered or isOpen) and Theme.Colors.BorderHover or Theme.Colors.Border
    end
    if arrow then
        arrow.Rotation = isOpen and 180 or 0
    end
    if optionsFrame then
        local options = self.props.element.options or {}
        local numOptions = #options
        local targetHeight = numOptions > 0 and (numOptions * 28 + (numOptions - 1) * 4 + 8) or 0
        
        optionsFrame.Size = isOpen and UDim2.new(1, 0, 0, targetHeight) or UDim2.new(1, 0, 0, 0)
        optionsFrame.GroupTransparency = isOpen and 0 or 1
        optionsFrame.Visible = isOpen
    end
end

function PullDownButton:didUpdate(prevProps, prevState)
    local stroke = self.strokeRef and self.strokeRef.current
    local arrow = self.arrowRef and self.arrowRef.current
    local optionsFrame = self.optionsRef and self.optionsRef.current
    
    local hovered = self.state.hovered
    local isOpen = self.state.isOpen
    
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    if hovered ~= prevState.hovered or isOpen ~= prevState.isOpen then
        if stroke then
            local targetColor = (hovered or isOpen) and Theme.Colors.BorderHover or Theme.Colors.Border
            TweenService:Create(stroke, tweenInfo, { Color = targetColor }):Play()
        end
    end
    
    if isOpen ~= prevState.isOpen then
        if arrow then
            TweenService:Create(arrow, tweenInfo, { Rotation = isOpen and 180 or 0 }):Play()
        end
        
        if optionsFrame then
            local options = self.props.element.options or {}
            local numOptions = #options
            local targetHeight = numOptions > 0 and (numOptions * 28 + (numOptions - 1) * 4 + 8) or 0
            
            if isOpen then
                optionsFrame.Visible = true
                optionsFrame.GroupTransparency = 1
                optionsFrame.Size = UDim2.new(1, 0, 0, 0)
                
                TweenService:Create(optionsFrame, tweenInfo, {
                    Size = UDim2.new(1, 0, 0, targetHeight),
                    GroupTransparency = 0,
                }):Play()
            else
                local collapseTween = TweenService:Create(optionsFrame, tweenInfo, {
                    Size = UDim2.new(1, 0, 0, 0),
                    GroupTransparency = 1,
                })
                collapseTween:Play()
                collapseTween.Completed:Connect(function()
                    if not self.state.isOpen then
                        optionsFrame.Visible = false
                    end
                end)
            end
        end
    end
end

function PullDownButton:render()
    local el = self.props.element
    
    local label = el.name or el.label or "Menu"
    local options = el.options or {}
    
    local hovered = self.state.hovered
    local isOpen = self.state.isOpen
    
    local optionButtons = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        
        Padding = React.createElement("UIPadding", {
            PaddingTop = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 4),
        }),
    }
    
    for i, opt in ipairs(options) do
        optionButtons["Opt_" .. tostring(i)] = React.createElement(PullDownOption, {
            opt = opt,
            LayoutOrder = i,
            OnClick = function()
                self:setState({ isOpen = false })
                if el.callback then
                    task.spawn(el.callback, i)
                end
            end,
        })
    end
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, {
        List = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        
        -- Main Menu Button
        Header = React.createElement("TextButton", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Theme.Colors.Element,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = 1,
            [React.Event.MouseEnter] = function() self:setState({ hovered = true }) end,
            [React.Event.MouseLeave] = function() self:setState({ hovered = false }) end,
            [React.Event.MouseButton1Click] = function()
                self:setState({ isOpen = not isOpen })
            end,
        }, {
            Corner = React.createElement("UICorner", {
                CornerRadius = Theme.CornerRadius.Element,
            }),
            
            Stroke = React.createElement("UIStroke", {
                ref = self.strokeRef,
                Color = (hovered or isOpen) and Theme.Colors.BorderHover or Theme.Colors.Border,
                Thickness = 1,
            }),
            
            -- Menu Title Label
            Title = React.createElement("TextLabel", {
                Size = UDim2.new(1, -30, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = label,
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Bold,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            
            -- Arrow Icon
            Arrow = React.createElement("ImageLabel", {
                ref = self.arrowRef,
                Size = UDim2.new(0, 14, 0, 14),
                Position = UDim2.new(1, -22, 0.5, -7),
                BackgroundTransparency = 1,
                Image = "rbxassetid://10747383844", -- Arrow down
                ImageColor3 = Theme.Colors.TextSecondary,
            }),
        }),
        
        -- Options List
        Options = React.createElement("CanvasGroup", {
            ref = self.optionsRef,
            BackgroundTransparency = 1,
            LayoutOrder = 2,
            ClipsDescendants = true,
        }, optionButtons),
    })
end

return PullDownButton

end

__modules["Components/RadioButtonGroup"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local RadioOption = React.Component:extend("RadioOption")

function RadioOption:init()
    self.state = { hovered = false }
end

function RadioOption:render()
    local props = self.props
    local opt = props.opt
    local isSelected = props.isSelected
    local layoutOrder = props.LayoutOrder
    local hovered = self.state.hovered
    
    return React.createElement("TextButton", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = layoutOrder,
        [React.Event.MouseEnter] = function() self:setState({ hovered = true }) end,
        [React.Event.MouseLeave] = function() self:setState({ hovered = false }) end,
        [React.Event.MouseButton1Click] = props.OnClick,
    }, {
        List = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        
        -- Radio Outer Circle
        RadioCircle = React.createElement("Frame", {
            Size = UDim2.new(0, 16, 0, 16),
            BackgroundColor3 = isSelected and Theme.Colors.Accent or Theme.Colors.Element,
            BorderSizePixel = 0,
            LayoutOrder = 1,
        }, {
            Corner = React.createElement("UICorner", {
                CornerRadius = Theme.CornerRadius.Circle,
            }),
            
            Stroke = React.createElement("UIStroke", {
                Color = (hovered or isSelected) and Theme.Colors.BorderHover or Theme.Colors.Border,
                Thickness = 1,
            }),
            
            -- Inner Fill Circle (only if selected)
            Fill = isSelected and React.createElement("Frame", {
                Size = UDim2.new(0, 6, 0, 6),
                Position = UDim2.new(0.5, -3, 0.5, -3),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
            }, {
                Corner = React.createElement("UICorner", {
                    CornerRadius = Theme.CornerRadius.Circle,
                }),
            }) or nil,
        }),
        
        -- Option text label
        OptionLabel = React.createElement("TextLabel", {
            Size = UDim2.new(1, -24, 1, 0),
            BackgroundTransparency = 1,
            Text = opt,
            TextColor3 = isSelected and Theme.Colors.Text or Theme.Colors.TextSecondary,
            Font = isSelected and Theme.Fonts.Bold or Theme.Fonts.Medium,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 2,
        }),
    })
end

local RadioButtonGroup = React.Component:extend("RadioButtonGroup")

function RadioButtonGroup:render()
    local el = self.props.element
    local Store = self.props.Store
    
    local options = el.options or {}
    local selectedIndex = el.value or 1
    
    local optionElements = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }
    
    for i, opt in ipairs(options) do
        local isSelected = i == selectedIndex
        
        optionElements["Opt_" .. tostring(i)] = React.createElement(RadioOption, {
            opt = opt,
            isSelected = isSelected,
            LayoutOrder = i,
            OnClick = function()
                Store:UpdateElement(el.id, function(element)
                    element.value = i
                end)
                
                if el.callback then
                    task.spawn(el.callback, i)
                end
            end,
        })
    end
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, {
        List = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        
        -- Header Title
        Title = el.name and React.createElement("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = el.name,
            TextColor3 = Theme.Colors.Text,
            Font = Theme.Fonts.Medium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
        }),
        
        -- Options List
        OptionsFrame = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 2,
        }, optionElements),
    })
end

return RadioButtonGroup

end

__modules["Components/Row"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)
local ElementRenderer = require(Source.Components.ElementRenderer)

local Row = React.Component:extend("Row")

function Row:render()
    local el = self.props.element
    local Store = self.props.Store
    
    local leftChildren = {}
    for i, subEl in ipairs(el.leftElements or {}) do
        leftChildren["Left_" .. subEl.id] = ElementRenderer.render(subEl, Store)
    end
    
    local rightChildren = {}
    local isFullWidth = false
    
    for i, subEl in ipairs(el.rightElements or {}) do
        rightChildren["Right_" .. subEl.id] = ElementRenderer.render(subEl, Store)
        
        -- Check if it should be stacked vertically (full width)
        local t = subEl.type
        if t == "Slider" or t == "Stepper" or t == "BarChart" or t == "LineChart" or t == "PieChart" or t == "VStack" or t == "HStack" or t == "ColorPickerWidget" then
            isFullWidth = true
        end
    end
    
    -- If there's only Right elements and no Left elements, we also make it full-width
    if #el.leftElements == 0 then
        isFullWidth = true
    end
    
    if isFullWidth then
        -- Vertical Layout (Stacked)
        return React.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
        }, {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            
            LeftArea = #el.leftElements > 0 and React.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 1,
            }, leftChildren) or nil,
            
            RightArea = React.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 2,
            }, rightChildren),
        })
    else
        -- Horizontal Layout (Side-by-Side)
        local leftContainerChildren = {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                VerticalAlignment = Enum.VerticalAlignment.Center,
            }),
        }
        for k, v in pairs(leftChildren) do
            leftContainerChildren[k] = v
        end
        
        local rightContainerChildren = {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        }
        for k, v in pairs(rightChildren) do
            rightContainerChildren[k] = v
        end
        
        return React.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        }, {
            -- Left column
            LeftArea = React.createElement("Frame", {
                Size = UDim2.new(0.5, -6, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
            }, leftContainerChildren),
            
            -- Right column (aligned to right)
            RightArea = React.createElement("Frame", {
                Size = UDim2.new(0.5, -6, 0, 0),
                Position = UDim2.new(0.5, 6, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
            }, rightContainerChildren),
        })
    end
end

return Row

end

__modules["Components/Section"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local ElementRenderer = require(Source.Components.ElementRenderer)

local Section = React.Component:extend("Section")

local Presets = {
    Discord = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(27, 35, 96)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 17, 21)),
    }),
    Wave = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 20, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 17, 21)),
    }),
    Friends = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 90, 15)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 17, 21)),
    }),
    Server = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 75, 45)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 17, 21)),
    }),
}

function Section:render()
    local sec = self.props.section
    local Store = self.props.Store
    
    local gradient = nil
    if sec.gradientPreset and Presets[sec.gradientPreset] then
        gradient = Presets[sec.gradientPreset]
    elseif sec.gradient then
        gradient = sec.gradient
    end
    
    local elements = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
        }),
    }
    
    -- Dynamically render elements
    for i, el in ipairs(sec.elements) do
        local elementComponent = ElementRenderer.render(el, Store)
        
        if elementComponent then
            elements["El_" .. el.id] = React.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = i,
            }, {
                Content = elementComponent,
            })
        end
    end
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.Colors.Card,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self.props.LayoutOrder,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Card,
        }),
        
        Stroke = React.createElement("UIStroke", {
            Color = Theme.Colors.Border,
            Thickness = 1,
        }),
        
        -- Apply gradient if provided
        Gradient = gradient and React.createElement("UIGradient", {
            Color = gradient,
            Rotation = 135,
        }),
        
        Padding = React.createElement("UIPadding", {
            PaddingTop = UDim.new(0, 14),
            PaddingBottom = UDim.new(0, 14),
            PaddingLeft = UDim.new(0, 14),
            PaddingRight = UDim.new(0, 14),
        }),
        
        -- Header and elements vertical container
        Content = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
        }, {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 10),
            }),
            
            -- Section Title Header
            Header = (sec.name or sec.description) and React.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 1,
            }, {
                List = React.createElement("UIListLayout", {
                    FillDirection = Enum.FillDirection.Vertical,
                    Padding = UDim.new(0, 2),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),
                
                Title = sec.name and React.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    Text = sec.name,
                    TextColor3 = Theme.Colors.Text,
                    Font = Theme.Fonts.Bold,
                    TextSize = 15,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    LayoutOrder = 1,
                }),
                
                Desc = sec.description and React.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 14),
                    BackgroundTransparency = 1,
                    Text = sec.description,
                    TextColor3 = Theme.Colors.TextSecondary,
                    Font = Theme.Fonts.Regular,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    LayoutOrder = 2,
                }),
            }),
            
            -- Divider line if there are elements
            Divider = (#sec.elements > 0 and (sec.name or sec.description)) and React.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Theme.Colors.Border,
                BorderSizePixel = 0,
                LayoutOrder = 2,
            }),
            
            -- Inner Elements
            ElementsArea = React.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 3,
            }, elements),
        }),
    })
end

return Section

end

__modules["Components/Sidebar"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local TweenService = game:GetService("TweenService")

-- Extracted TabButton Component to avoid closure capture & definition recreation bugs
local TabButton = React.Component:extend("TabButton")

function TabButton:init()
    self.state = {
        hovered = false
    }
    self.btnRef = React.createRef()
    self.activeBarRef = React.createRef()
    self.labelRef = React.createRef()
    self.iconRef = React.createRef()
end

function TabButton:didMount()
    local btn = self.btnRef and self.btnRef.current
    local activeBar = self.activeBarRef and self.activeBarRef.current
    local label = self.labelRef and self.labelRef.current
    local icon = self.iconRef and self.iconRef.current
    
    local props = self.props
    local isActive = props.isActive
    local hovered = self.state.hovered
    
    if btn then
        btn.BackgroundColor3 = isActive and Theme.Colors.Element or (hovered and Theme.Colors.ElementHover or Color3.fromRGB(0, 0, 0))
        btn.BackgroundTransparency = (isActive or hovered) and 0 or 1
    end
    
    if activeBar then
        activeBar.Size = isActive and UDim2.new(0, 3, 0, 14) or UDim2.new(0, 3, 0, 0)
        activeBar.BackgroundTransparency = isActive and 0 or 1
    end
    
    local targetColor = (isActive or hovered) and Theme.Colors.Text or Theme.Colors.TextSecondary
    if label then
        label.TextColor3 = targetColor
    end
    if icon then
        icon.ImageColor3 = targetColor
    end
end

function TabButton:didUpdate(prevProps, prevState)
    local btn = self.btnRef and self.btnRef.current
    local activeBar = self.activeBarRef and self.activeBarRef.current
    local label = self.labelRef and self.labelRef.current
    local icon = self.iconRef and self.iconRef.current
    
    local props = self.props
    local isActive = props.isActive
    local hovered = self.state.hovered
    
    local valChanged = (isActive ~= prevProps.isActive) or (hovered ~= prevState.hovered)
    if valChanged then
        local targetColor = isActive and Theme.Colors.Element or (hovered and Theme.Colors.ElementHover or Color3.fromRGB(0, 0, 0))
        local targetTrans = (isActive or hovered) and 0 or 1
        
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if btn then
            TweenService:Create(btn, tweenInfo, {
                BackgroundColor3 = targetColor,
                BackgroundTransparency = targetTrans,
            }):Play()
        end
        
        local targetTextColor = (isActive or hovered) and Theme.Colors.Text or Theme.Colors.TextSecondary
        if label then
            TweenService:Create(label, tweenInfo, { TextColor3 = targetTextColor }):Play()
        end
        if icon then
            TweenService:Create(icon, tweenInfo, { ImageColor3 = targetTextColor }):Play()
        end
    end
    
    if isActive ~= prevProps.isActive then
        if activeBar then
            local targetSize = isActive and UDim2.new(0, 3, 0, 14) or UDim2.new(0, 3, 0, 0)
            local targetTrans = isActive and 0 or 1
            
            local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(activeBar, tweenInfo, {
                Size = targetSize,
                BackgroundTransparency = targetTrans,
            }):Play()
        end
    end
end

function TabButton:render()
    local props = self.props
    local tab = props.tab
    local isActive = props.isActive
    local Store = props.Store
    local layoutOrder = props.LayoutOrder
    local hovered = self.state.hovered
    
    local isSubTab = tab.parentTabId ~= nil
    local xOffset = isSubTab and 16 or 0
    local widthDim = isSubTab and UDim2.new(1, -16, 0, 32) or UDim2.new(1, 0, 0, 32)
    
    return React.createElement("TextButton", {
        ref = self.btnRef,
        Size = widthDim,
        Position = UDim2.new(0, xOffset, 0, 0),
        BackgroundColor3 = isActive and Theme.Colors.Element or Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = isActive and 0 or 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = layoutOrder,
        [React.Event.MouseEnter] = function() self:setState({ hovered = true }) end,
        [React.Event.MouseLeave] = function() self:setState({ hovered = false }) end,
        [React.Event.MouseButton1Click] = function()
            Store:Update(function(s)
                s.activeTab = tab.id
            end)
        end,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Element,
        }),
        
        ActiveBar = React.createElement("Frame", {
            ref = self.activeBarRef,
            Size = isActive and UDim2.new(0, 3, 0, 14) or UDim2.new(0, 3, 0, 0),
            Position = UDim2.new(0, 4, 0.5, -7),
            BackgroundColor3 = Theme.Colors.Accent,
            BackgroundTransparency = isActive and 0 or 1,
            BorderSizePixel = 0,
        }, {
            Corner = React.createElement("UICorner", {
                CornerRadius = Theme.CornerRadius.Circle,
            }),
        }),
        
        Content = React.createElement("Frame", {
            Size = UDim2.new(1, isActive and -15 or -10, 1, 0),
            Position = UDim2.new(0, isActive and 12 or 8, 0, 0),
            BackgroundTransparency = 1,
        }, {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 8),
            }),
            
            Icon = tab.icon and React.createElement("ImageLabel", {
                ref = self.iconRef,
                Size = UDim2.new(0, 14, 0, 14),
                BackgroundTransparency = 1,
                Image = tab.icon,
                ImageColor3 = (isActive or hovered) and Theme.Colors.Text or Theme.Colors.TextSecondary,
            }) or nil,
            
            Label = React.createElement("TextLabel", {
                ref = self.labelRef,
                Size = UDim2.new(1, tab.icon and -22 or 0, 1, 0),
                BackgroundTransparency = 1,
                Text = tab.title,
                TextColor3 = (isActive or hovered) and Theme.Colors.Text or Theme.Colors.TextSecondary,
                Font = isActive and Theme.Fonts.Bold or Theme.Fonts.Medium,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        }),
    })
end

local Sidebar = React.Component:extend("Sidebar")

function Sidebar:render()
    local state = self.props.state
    local Store = self.props.Store
    local layoutOrderProp = self.props.LayoutOrder
    
    local sidebarElements = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
        }),
        
        Padding = React.createElement("UIPadding", {
            PaddingTop = UDim.new(0, 12),
            PaddingBottom = UDim.new(0, 12),
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
        }),
    }
    
    local layoutOrder = 1
    for _, sec in ipairs(state.sections or {}) do
        -- Section Header (only if title is not empty)
        if sec.title and sec.title ~= "" then
            sidebarElements["SecHeader_" .. sec.id] = React.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                Text = string.upper(sec.title),
                TextColor3 = Theme.Colors.TextSecondary,
                Font = Theme.Fonts.Bold,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = layoutOrder,
            })
            layoutOrder = layoutOrder + 1
        end
        
        -- Tabs under this section
        for _, tab in ipairs(sec.tabs or {}) do
            local isActive = state.activeTab == tab.id
            
            sidebarElements["Tab_" .. tab.id] = React.createElement(TabButton, {
                tab = tab,
                isActive = isActive,
                Store = Store,
                LayoutOrder = layoutOrder,
            })
            layoutOrder = layoutOrder + 1
        end
    end
    
    return React.createElement("Frame", {
        Size = UDim2.new(0, 180, 1, 0),
        BackgroundColor3 = Theme.Colors.Sidebar,
        BorderSizePixel = 0,
        LayoutOrder = layoutOrderProp,
    }, {
        Border = React.createElement("Frame", {
            Size = UDim2.new(0, 1, 1, 0),
            Position = UDim2.new(1, -1, 0, 0),
            BackgroundColor3 = Theme.Colors.Border,
            BorderSizePixel = 0,
        }),
        
        -- Navigation List
        NavList = React.createElement("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, -65),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 1,
            ScrollBarImageColor3 = Theme.Colors.Border,
        }, sidebarElements),
        
        -- User profile at bottom of sidebar (if set)
        ProfileArea = state.profile and React.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 65),
            Position = UDim2.new(0, 0, 1, -65),
            BackgroundTransparency = 1,
        }, {
            Divider = React.createElement("Frame", {
                Size = UDim2.new(1, -20, 0, 1),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundColor3 = Theme.Colors.Border,
                BorderSizePixel = 0,
            }),
            
            Container = React.createElement("Frame", {
                Size = UDim2.new(1, -20, 1, -1),
                Position = UDim2.new(0, 10, 0, 1),
                BackgroundTransparency = 1,
            }, {
                List = React.createElement("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDim.new(0, 10),
                }),
                
                Avatar = React.createElement("ImageLabel", {
                    Size = UDim2.new(0, 36, 0, 36),
                    BackgroundColor3 = Theme.Colors.Element,
                    BorderSizePixel = 0,
                    Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(state.profile.userId or 1) .. "&width=150&height=150&format=png",
                }, {
                    Corner = React.createElement("UICorner", {
                        CornerRadius = Theme.CornerRadius.Circle,
                    }),
                    Stroke = React.createElement("UIStroke", {
                        Color = Theme.Colors.Border,
                        Thickness = 1,
                    }),
                }),
                
                Info = React.createElement("Frame", {
                    Size = UDim2.new(1, -46, 0, 36),
                    BackgroundTransparency = 1,
                }, {
                    List = React.createElement("UIListLayout", {
                        FillDirection = Enum.FillDirection.Vertical,
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                    }),
                    
                    Username = React.createElement("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 16),
                        BackgroundTransparency = 1,
                        Text = state.profile.username,
                        TextColor3 = Theme.Colors.Text,
                        Font = Theme.Fonts.Bold,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                    }),
                    
                    Role = React.createElement("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 14),
                        BackgroundTransparency = 1,
                        Text = state.profile.subtext or "User",
                        TextColor3 = Theme.Colors.TextSecondary,
                        Font = Theme.Fonts.Regular,
                        TextSize = 10,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                    }),
                }),
            }),
        }),
    })
end

return Sidebar

end

__modules["Components/Slider"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local Slider = React.Component:extend("Slider")

function Slider:init(props)
    self.trackRef = React.createRef()
    self.fillRef = React.createRef()
    self.knobRef = React.createRef()
    self.strokeRef = React.createRef()
    self.dragConnection = nil
    self.releaseConnection = nil
    self.state = {
        hovered = false,
        value = props.element.value or (props.element.min or 0)
    }
end

function Slider:didMount()
    local fill = self.fillRef and self.fillRef.current
    local knob = self.knobRef and self.knobRef.current
    local stroke = self.strokeRef and self.strokeRef.current
    
    local el = self.props.element
    local min = el.min or 0
    local max = el.max or 100
    local currentVal = self.state.value
    local percentage = math.clamp((currentVal - min) / (max - min), 0, 1)
    local hovered = self.state.hovered
    
    if fill then
        fill.Size = UDim2.new(percentage, 0, 1, 0)
    end
    if knob then
        knob.Position = UDim2.new(percentage, -6, 0.5, -6)
    end
    if stroke then
        stroke.Color = hovered and Theme.Colors.BorderHover or Theme.Colors.Border
    end
end

function Slider:didUpdate(prevProps, prevState)
    local fill = self.fillRef and self.fillRef.current
    local knob = self.knobRef and self.knobRef.current
    local stroke = self.strokeRef and self.strokeRef.current
    
    local el = self.props.element
    local min = el.min or 0
    local max = el.max or 100
    local currentVal = self.state.value
    
    -- Sync external prop change
    if el.value ~= currentVal and el.value ~= prevProps.element.value then
        self:setState({ value = el.value })
        return
    end
    
    local percentage = math.clamp((currentVal - min) / (max - min), 0, 1)
    local prevPercentage = math.clamp((prevState.value - min) / (max - min), 0, 1)
    local hovered = self.state.hovered
    
    if percentage ~= prevPercentage then
        local tweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if fill then
            TweenService:Create(fill, tweenInfo, { Size = UDim2.new(percentage, 0, 1, 0) }):Play()
        end
        if knob then
            TweenService:Create(knob, tweenInfo, { Position = UDim2.new(percentage, -6, 0.5, -6) }):Play()
        end
    end
    
    if hovered ~= prevState.hovered then
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if stroke then
            TweenService:Create(stroke, tweenInfo, { Color = hovered and Theme.Colors.BorderHover or Theme.Colors.Border }):Play()
        end
    end
end

function Slider:willUnmount()
    if self.dragConnection then
        self.dragConnection:Disconnect()
    end
    if self.releaseConnection then
        self.releaseConnection:Disconnect()
    end
end

function Slider:render()
    local el = self.props.element
    local Store = self.props.Store
    
    local min = el.min or 0
    local max = el.max or 100
    local currentVal = self.state.value
    
    local percentage = math.clamp((currentVal - min) / (max - min), 0, 1)
    local hovered = self.state.hovered
    
    local function updateValue(input)
        local track = self.trackRef and self.trackRef.current
        if not track then return end
        
        local trackSize = track.AbsoluteSize.X
        local trackPos = track.AbsolutePosition.X
        local mouseX = input.Position.X
        
        local pct = math.clamp((mouseX - trackPos) / trackSize, 0, 1)
        local newValue = math.round(min + (pct * (max - min)))
        
        self:setState({ value = newValue })
        
        Store:UpdateElement(el.id, function(element)
            element.value = newValue
        end)
        
        if el.callback then
            task.spawn(el.callback, newValue)
        end
    end
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 1,
    }, {
        List = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 6),
        }),
        
        -- Title and value label
        Header = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
        }, {
            Title = React.createElement("TextLabel", {
                Size = UDim2.new(1, -60, 1, 0),
                BackgroundTransparency = 1,
                Text = el.name or "Slider",
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Medium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            
            Value = React.createElement("TextLabel", {
                Size = UDim2.new(0, 50, 1, 0),
                Position = UDim2.new(1, -50, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(currentVal),
                TextColor3 = Theme.Colors.TextSecondary,
                Font = Theme.Fonts.Bold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
            }),
        }),
        
        -- Progress Bar row
        BarRow = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
        }, {
            -- Left icon (optional)
            LeftIcon = el.leftIcon and React.createElement("ImageLabel", {
                Size = UDim2.new(0, 16, 0, 16),
                Position = UDim2.new(0, 0, 0.5, -8),
                BackgroundTransparency = 1,
                Image = el.leftIcon,
                ImageColor3 = Theme.Colors.TextSecondary,
            }) or nil,
            
            -- Right icon (optional)
            RightIcon = el.rightIcon and React.createElement("ImageLabel", {
                Size = UDim2.new(0, 16, 0, 16),
                Position = UDim2.new(1, -16, 0.5, -8),
                BackgroundTransparency = 1,
                Image = el.rightIcon,
                ImageColor3 = Theme.Colors.TextSecondary,
            }) or nil,
            
            -- Main Slider Track
            Track = React.createElement("TextButton", {
                ref = self.trackRef,
                Size = UDim2.new(1, (el.leftIcon and -24 or 0) + (el.rightIcon and -24 or 0), 0, 8),
                Position = UDim2.new(0, el.leftIcon and 20 or 0, 0.5, -4),
                BackgroundColor3 = Theme.Colors.Element,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                [React.Event.MouseEnter] = function() self:setState({ hovered = true }) end,
                [React.Event.MouseLeave] = function() self:setState({ hovered = false }) end,
                [React.Event.InputBegan] = function(rbx, input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        updateValue(input)
                        
                        if self.dragConnection then self.dragConnection:Disconnect() end
                        if self.releaseConnection then self.releaseConnection:Disconnect() end
                        
                        self.dragConnection = UserInputService.InputChanged:Connect(function(moveInput)
                            if moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch then
                                updateValue(moveInput)
                            end
                        end)
                        
                        self.releaseConnection = UserInputService.InputEnded:Connect(function(endInput)
                            if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                                if self.dragConnection then
                                    self.dragConnection:Disconnect()
                                    self.dragConnection = nil
                                end
                                if self.releaseConnection then
                                    self.releaseConnection:Disconnect()
                                    self.releaseConnection = nil
                                end
                            end
                        end)
                    end
                end,
            }, {
                Corner = React.createElement("UICorner", {
                    CornerRadius = Theme.CornerRadius.Circle,
                }),
                
                Stroke = React.createElement("UIStroke", {
                    ref = self.strokeRef,
                    Color = hovered and Theme.Colors.BorderHover or Theme.Colors.Border,
                    Thickness = 1,
                }),
                
                -- Filled Active Area
                Fill = React.createElement("Frame", {
                    ref = self.fillRef,
                    BackgroundColor3 = Theme.Colors.Accent,
                    BorderSizePixel = 0,
                    ZIndex = 1,
                }, {
                    Corner = React.createElement("UICorner", {
                        CornerRadius = Theme.CornerRadius.Circle,
                    }),
                }),
                
                -- Handle Knob
                Knob = React.createElement("Frame", {
                    ref = self.knobRef,
                    Size = UDim2.new(0, 12, 0, 12),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BorderSizePixel = 0,
                    ZIndex = 2,
                }, {
                    Corner = React.createElement("UICorner", {
                        CornerRadius = Theme.CornerRadius.Circle,
                    }),
                    
                    Stroke = React.createElement("UIStroke", {
                        Color = Theme.Colors.Border,
                        Thickness = 1,
                    }),
                }),
            }),
        }),
    })
end

return Slider

end

__modules["Components/Stepper"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local StepperDecButton = React.Component:extend("StepperDecButton")

function StepperDecButton:init()
    self.state = { hovered = false }
end

function StepperDecButton:render()
    local props = self.props
    local hovered = self.state.hovered
    
    return React.createElement("TextButton", {
        Size = UDim2.new(0, 26, 0, 26),
        BackgroundColor3 = hovered and Theme.Colors.ElementHover or Theme.Colors.Element,
        BorderSizePixel = 0,
        Text = "-",
        TextColor3 = Theme.Colors.Text,
        Font = Theme.Fonts.Bold,
        TextSize = 14,
        LayoutOrder = 1,
        AutoButtonColor = false,
        [React.Event.MouseEnter] = function() self:setState({ hovered = true }) end,
        [React.Event.MouseLeave] = function() self:setState({ hovered = false }) end,
        [React.Event.MouseButton1Click] = props.OnClick,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Element,
        }),
        Stroke = React.createElement("UIStroke", {
            Color = hovered and Theme.Colors.BorderHover or Theme.Colors.Border,
            Thickness = 1,
        }),
    })
end

local StepperIncButton = React.Component:extend("StepperIncButton")

function StepperIncButton:init()
    self.state = { hovered = false }
end

function StepperIncButton:render()
    local props = self.props
    local hovered = self.state.hovered
    
    return React.createElement("TextButton", {
        Size = UDim2.new(0, 26, 0, 26),
        BackgroundColor3 = hovered and Theme.Colors.ElementHover or Theme.Colors.Element,
        BorderSizePixel = 0,
        Text = "+",
        TextColor3 = Theme.Colors.Text,
        Font = Theme.Fonts.Bold,
        TextSize = 14,
        LayoutOrder = 3,
        AutoButtonColor = false,
        [React.Event.MouseEnter] = function() self:setState({ hovered = true }) end,
        [React.Event.MouseLeave] = function() self:setState({ hovered = false }) end,
        [React.Event.MouseButton1Click] = props.OnClick,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Element,
        }),
        Stroke = React.createElement("UIStroke", {
            Color = hovered and Theme.Colors.BorderHover or Theme.Colors.Border,
            Thickness = 1,
        }),
    })
end

local Stepper = React.Component:extend("Stepper")

function Stepper:render()
    local el = self.props.element
    local Store = self.props.Store
    
    local min = el.min or 0
    local max = el.max or 100
    local step = el.step or 1
    local currentVal = el.value or min
    
    local function updateValue(newVal)
        newVal = math.clamp(newVal, min, max)
        -- Round to nearest step decimal to prevent float issues
        local precision = 1 / step
        if precision == math.floor(precision) then
            newVal = math.round(newVal * precision) / precision
        end
        
        Store:UpdateElement(el.id, function(element)
            element.value = newVal
        end)
        
        if el.callback then
            task.spawn(el.callback, newVal)
        end
    end
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
    }, {
        -- Left text label
        Label = React.createElement("TextLabel", {
            Size = UDim2.new(1, -130, 1, 0),
            BackgroundTransparency = 1,
            Text = el.name or "Stepper",
            TextColor3 = Theme.Colors.Text,
            Font = Theme.Fonts.Medium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }),
        
        -- Right Stepper Controls Container
        Container = React.createElement("Frame", {
            Size = UDim2.new(0, 120, 0, 26),
            Position = UDim2.new(1, -120, 0.5, -13),
            BackgroundTransparency = 1,
        }, {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            
            -- Decrement Button (-)
            DecButton = React.createElement(StepperDecButton, {
                OnClick = function()
                    updateValue(currentVal - step)
                end,
            }),
            
            -- Value Display field (either TextBox for manual entry, or TextLabel)
            Display = React.createElement("Frame", {
                Size = UDim2.new(0, 68, 0, 26),
                BackgroundTransparency = 1,
                LayoutOrder = 2,
            }, {
                Input = el.fielded and React.createElement("TextBox", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = tostring(currentVal),
                    TextColor3 = Theme.Colors.Text,
                    Font = Theme.Fonts.Bold,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    ClearTextOnFocus = false,
                    [React.Event.FocusLost] = function(box)
                        local num = tonumber(box.Text)
                        if num then
                            updateValue(num)
                        else
                            box.Text = tostring(currentVal)
                        end
                    end,
                }) or React.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = tostring(currentVal),
                    TextColor3 = Theme.Colors.Text,
                    Font = Theme.Fonts.Bold,
                    TextSize = 12,
                }),
            }),
            
            -- Increment Button (+)
            IncButton = React.createElement(StepperIncButton, {
                OnClick = function()
                    updateValue(currentVal + step)
                end,
            }),
        }),
    })
end

return Stepper

end

__modules["Components/TabContainer"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local table_clone = table.clone or function(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end
local Section = require(Source.Components.Section)
local ProfileComponent = require(Source.Components.Profile)

local TabContainer = React.Component:extend("TabContainer")

function TabContainer:init()
    self.groupRef = React.createRef()
end

function TabContainer:didMount()
    local group = self.groupRef and self.groupRef.current
    if group then
        group.Position = UDim2.new(0, 0, 0, 8)
        group.GroupTransparency = 1
        
        local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(group, tweenInfo, {
            Position = UDim2.new(0, 0, 0, 0),
            GroupTransparency = 0,
        }):Play()
    end
end

function TabContainer:didUpdate(prevProps)
    if self.props.state.activeTab ~= prevProps.state.activeTab then
        local group = self.groupRef and self.groupRef.current
        if group then
            group.Position = UDim2.new(0, 0, 0, 8)
            group.GroupTransparency = 1
            
            local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(group, tweenInfo, {
                Position = UDim2.new(0, 0, 0, 0),
                GroupTransparency = 0,
            }):Play()
        end
    end
end

function TabContainer:render()
    local state = self.props.state
    local Store = self.props.Store
    local layoutOrder = self.props.LayoutOrder
    
    local activeTab = nil
    for _, tab in ipairs(state.tabs) do
        if tab.id == state.activeTab then
            activeTab = tab
            break
        end
    end
    
    if not activeTab then
        return React.createElement("CanvasGroup", {
            ref = self.groupRef,
            Size = UDim2.new(1, -180, 1, 0),
            BackgroundTransparency = 1,
            LayoutOrder = layoutOrder,
        }, {
            NoTab = React.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "No Tab Selected",
                TextColor3 = Theme.Colors.TextSecondary,
                Font = Theme.Fonts.Medium,
                TextSize = 14,
            }),
        })
    end
    
    -- Check if tab has any profile header banner (e.g., Welcome banner at top of tab)
    local tabBanner = activeTab.banner
    
    local query = string.lower(state.searchQuery or "")
    
    -- Separate sections into Column 1 (Left) and Column 2 (Right)
    local leftSections = {}
    local rightSections = {}
    
    local pageSections = activeTab.pageSections or activeTab.sections or {}
    for i, sec in ipairs(pageSections) do
        local showSection = false
        local filteredElements = nil
        
        if query == "" then
            showSection = true
        else
            local secNameMatch = sec.name and string.find(string.lower(sec.name), query) ~= nil
            local secDescMatch = sec.description and string.find(string.lower(sec.description), query) ~= nil
            
            if secNameMatch or secDescMatch then
                showSection = true
            else
                local matchingElements = {}
                for _, el in ipairs(sec.elements) do
                    local elNameMatch = el.name and string.find(string.lower(el.name), query) ~= nil
                    local elTextMatch = el.text and string.find(string.lower(el.text), query) ~= nil
                    
                    if elNameMatch or elTextMatch then
                        table.insert(matchingElements, el)
                    end
                    
                    -- Check VStack/HStack sub-elements
                    if el.type == "VStack" or el.type == "HStack" then
                        local hasNestedMatch = false
                        for _, sub in ipairs(el.elements or {}) do
                            local subNameMatch = sub.name and string.find(string.lower(sub.name), query) ~= nil
                            local subTextMatch = sub.text and string.find(string.lower(sub.text), query) ~= nil
                            if subNameMatch or subTextMatch then
                                hasNestedMatch = true
                                break
                            end
                        end
                        if hasNestedMatch then
                            table.insert(matchingElements, el)
                        end
                    end
                end
                
                if #matchingElements > 0 then
                    showSection = true
                    filteredElements = matchingElements
                end
            end
        end
        
        if showSection then
            local sectionData = sec
            if filteredElements then
                sectionData = table_clone(sec)
                sectionData.elements = filteredElements
            end
            
            local sectionElement = React.createElement(Section, {
                key = "Section_" .. sec.id,
                section = sectionData,
                Store = Store,
                LayoutOrder = i,
            })
            
            if sec.column == 2 or sec.column == "Right" then
                table.insert(rightSections, sectionElement)
            else
                table.insert(leftSections, sectionElement)
            end
        end
    end
    
    local useDualColumns = #rightSections > 0
    local gridChildren = nil
    
    if useDualColumns then
        local leftColChildren = {
            ColLayout = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 12),
                SortOrder = Enum.SortOrder.LayoutOrder,
            })
        }
        for idx, secEl in ipairs(leftSections) do
            leftColChildren["Sec_" .. tostring(idx)] = secEl
        end
        
        local rightColChildren = {
            ColLayout = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 12),
                SortOrder = Enum.SortOrder.LayoutOrder,
            })
        }
        for idx, secEl in ipairs(rightSections) do
            rightColChildren["Sec_" .. tostring(idx)] = secEl
        end
        
        gridChildren = {
            ColumnsList = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 12),
            }),
            
            LeftCol = React.createElement("Frame", {
                Size = UDim2.new(0.5, -6, 0, 0),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 1,
            }, leftColChildren),
            
            RightCol = React.createElement("Frame", {
                Size = UDim2.new(0.5, -6, 0, 0),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 2,
            }, rightColChildren),
        }
    else
        local singleColChildren = {
            SingleColLayout = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 12),
                SortOrder = Enum.SortOrder.LayoutOrder,
            })
        }
        for idx, secEl in ipairs(leftSections) do
            singleColChildren["Sec_" .. tostring(idx)] = secEl
        end
        gridChildren = singleColChildren
    end
    
    return React.createElement("CanvasGroup", {
        ref = self.groupRef,
        Size = UDim2.new(1, -180, 1, 0),
        BackgroundTransparency = 1,
        LayoutOrder = layoutOrder,
    }, {
        ScrollFrame = React.createElement("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = Theme.Colors.Border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
        }, {
            Layout = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 12),
            }),
            
            Padding = React.createElement("UIPadding", {
                PaddingTop = UDim.new(0, 12),
                PaddingBottom = UDim.new(0, 15),
                PaddingLeft = UDim.new(0, 12),
                PaddingRight = UDim.new(0, 12),
            }),
            
            Banner = tabBanner and React.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 80),
                BackgroundTransparency = 1,
                LayoutOrder = 1,
            }, {
                Content = React.createElement(ProfileComponent, {
                    username = tabBanner.username,
                    subtext = tabBanner.subtext,
                    userId = tabBanner.userId,
                }),
            }),
            
            GridArea = React.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 2,
            }, gridChildren),
        }),
    })
end

return TabContainer

end

__modules["Components/TextBox"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local TextBox = React.Component:extend("TextBox")

function TextBox:init()
    self.state = {
        hovered = false
    }
end

function TextBox:render()
    local el = self.props.element
    local Store = self.props.Store
    
    local hovered = self.state.hovered
    local currentVal = el.value or ""
    local hideLabel = el.hideLabel
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
    }, {
        -- Left text label
        Label = not hideLabel and React.createElement("TextLabel", {
            Size = UDim2.new(0, 150, 1, 0),
            BackgroundTransparency = 1,
            Text = el.name or "Input",
            TextColor3 = Theme.Colors.Text,
            Font = Theme.Fonts.Medium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }) or nil,
        
        -- Right Input Box
        InputContainer = React.createElement("Frame", {
            Size = hideLabel and UDim2.new(1, 0, 0, 28) or UDim2.new(1, -160, 0, 28),
            Position = hideLabel and UDim2.new(0, 0, 0.5, -14) or UDim2.new(1, -160, 0.5, -14),
            BackgroundColor3 = Theme.Colors.Element,
            BorderSizePixel = 0,
        }, {
            Corner = React.createElement("UICorner", {
                CornerRadius = Theme.CornerRadius.Element,
            }),
            
            Stroke = React.createElement("UIStroke", {
                Color = hovered and Theme.Colors.BorderHover or Theme.Colors.Border,
                Thickness = 1,
            }),
            
            TextInput = React.createElement("TextBox", {
                Size = UDim2.new(1, -16, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                Text = currentVal,
                PlaceholderText = el.placeholder or "Type here...",
                PlaceholderColor3 = Theme.Colors.TextSecondary,
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Regular,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                ClearTextOnFocus = false,
                [React.Event.MouseEnter] = function() self:setState({ hovered = true }) end,
                [React.Event.MouseLeave] = function() self:setState({ hovered = false }) end,
                [React.Event.FocusLost] = function(box, enterPressed)
                    local text = box.Text
                    Store:UpdateElement(el.id, function(element)
                        element.value = text
                    end)
                    if el.callback then
                        task.spawn(el.callback, text, enterPressed)
                    end
                end,
            }),
        }),
    })
end

return TextBox

end

__modules["Components/TitleStack"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local TitleStack = React.Component:extend("TitleStack")

local function TagComponent(props)
    local color = props.color or Theme.Colors.Accent
    local isGradient = type(color) == "table"
    
    return React.createElement("Frame", {
        Size = UDim2.new(0, 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = not isGradient and color or Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        LayoutOrder = props.LayoutOrder,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = UDim.new(0, 4),
        }),
        
        Padding = React.createElement("UIPadding", {
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6),
            PaddingTop = UDim.new(0, 1),
            PaddingBottom = UDim.new(0, 1),
        }),
        
        Gradient = isGradient and React.createElement("UIGradient", {
            Color = ColorSequence.new(unpack(color)),
            Rotation = 45,
        }),
        
        Label = React.createElement("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = string.upper(props.text),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Font = Theme.Fonts.Bold,
            TextSize = 8,
        }),
    })
end

function TitleStack:render()
    local el = self.props.element
    
    local title = el.title or el.Title or "Title"
    local subtitle = el.subtitle or el.Subtitle
    
    local titleTag = el.titleTag or el.TitleTag
    local titleTagColor = el.titleTagColor or el.TitleTagColor
    
    local subtitleTag = el.subtitleTag or el.SubtitleTag
    local subtitleTagColor = el.subtitleTagColor or el.SubtitleTagColor
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, {
        List = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        
        -- Row 1: Title and TitleTag
        TitleRow = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
        }, {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            
            Label = React.createElement("TextLabel", {
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Text = title,
                TextColor3 = Theme.Colors.Text,
                Font = Theme.Fonts.Bold,
                TextSize = 13,
                LayoutOrder = 1,
            }),
            
            Tag = titleTag and React.createElement(TagComponent, {
                text = titleTag,
                color = titleTagColor,
                LayoutOrder = 2,
            }) or nil,
        }),
        
        -- Row 2: Subtitle and SubtitleTag (only if subtitle exists)
        SubtitleRow = subtitle and React.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            LayoutOrder = 2,
        }, {
            List = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            
            Label = React.createElement("TextLabel", {
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Text = subtitle,
                TextColor3 = Theme.Colors.TextSecondary,
                Font = Theme.Fonts.Regular,
                TextSize = 10,
                LayoutOrder = 1,
            }),
            
            Tag = subtitleTag and React.createElement(TagComponent, {
                text = subtitleTag,
                color = subtitleTagColor,
                LayoutOrder = 2,
            }) or nil,
        }) or nil,
    })
end

return TitleStack

end

__modules["Components/Toggle"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)

local Toggle = React.Component:extend("Toggle")

function Toggle:init(props)
    self.state = {
        hovered = false,
        value = props.element.value or false
    }
    self.switchRef = React.createRef()
    self.knobRef = React.createRef()
    self.strokeRef = React.createRef()
end

function Toggle:didMount()
    local switch = self.switchRef and self.switchRef.current
    local knob = self.knobRef and self.knobRef.current
    local stroke = self.strokeRef and self.strokeRef.current
    local currentVal = self.state.value
    local hovered = self.state.hovered
    
    if switch then
        switch.BackgroundColor3 = currentVal and Theme.Colors.Accent or Theme.Colors.Element
    end
    if knob then
        knob.Position = currentVal and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    end
    if stroke then
        stroke.Color = hovered and Theme.Colors.BorderHover or Theme.Colors.Border
    end
end

function Toggle:didUpdate(prevProps, prevState)
    local switch = self.switchRef and self.switchRef.current
    local knob = self.knobRef and self.knobRef.current
    local stroke = self.strokeRef and self.strokeRef.current
    
    local el = self.props.element
    local currentVal = self.state.value
    
    -- Sync external prop change to local state
    if el.value ~= currentVal and el.value ~= prevProps.element.value then
        self:setState({ value = el.value })
        return
    end
    
    if currentVal ~= prevState.value then
        local targetColor = currentVal and Theme.Colors.Accent or Theme.Colors.Element
        local targetPos = currentVal and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if switch then
            TweenService:Create(switch, tweenInfo, { BackgroundColor3 = targetColor }):Play()
        end
        if knob then
            TweenService:Create(knob, tweenInfo, { Position = targetPos }):Play()
        end
    end
    
    local hovered = self.state.hovered
    if hovered ~= prevState.hovered then
        local targetBorder = hovered and Theme.Colors.BorderHover or Theme.Colors.Border
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if stroke then
            TweenService:Create(stroke, tweenInfo, { Color = targetBorder }):Play()
        end
    end
end

function Toggle:render()
    local el = self.props.element
    local Store = self.props.Store
    
    local hovered = self.state.hovered
    local currentVal = self.state.value
    local hideLabel = el.hideLabel
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
    }, {
        -- Left text label
        Label = not hideLabel and React.createElement("TextLabel", {
            Size = UDim2.new(1, -60, 1, 0),
            BackgroundTransparency = 1,
            Text = el.name or "Toggle",
            TextColor3 = Theme.Colors.Text,
            Font = Theme.Fonts.Medium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }) or nil,
        
        -- Right Toggle Pill Switch
        Switch = React.createElement("TextButton", {
            ref = self.switchRef,
            Size = UDim2.new(0, 42, 0, 22),
            Position = UDim2.new(1, -42, 0.5, -11),
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            [React.Event.MouseEnter] = function() self:setState({ hovered = true }) end,
            [React.Event.MouseLeave] = function() self:setState({ hovered = false }) end,
            [React.Event.MouseButton1Click] = function()
                local newValue = not currentVal
                self:setState({ value = newValue })
                
                -- Update Store
                Store:UpdateElement(el.id, function(element)
                    element.value = newValue
                end)
                
                if el.callback then
                    task.spawn(el.callback, newValue)
                end
            end,
        }, {
            Corner = React.createElement("UICorner", {
                CornerRadius = Theme.CornerRadius.Circle,
            }),
            
            Stroke = React.createElement("UIStroke", {
                ref = self.strokeRef,
                Color = hovered and Theme.Colors.BorderHover or Theme.Colors.Border,
                Thickness = 1,
            }),
            
            -- Sliding Knob
            Knob = React.createElement("Frame", {
                ref = self.knobRef,
                Size = UDim2.new(0, 16, 0, 16),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
            }, {
                Corner = React.createElement("UICorner", {
                    CornerRadius = Theme.CornerRadius.Circle,
                }),
            }),
        }),
    })
end

return Toggle

end

__modules["Components/VStack"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local ElementRenderer = require(Source.Components.ElementRenderer)

local VStack = React.Component:extend("VStack")

function VStack:render()
    local el = self.props.element
    local Store = self.props.Store
    
    local children = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = el.padding or UDim.new(0, 4),
            HorizontalAlignment = el.horizontalAlignment or Enum.HorizontalAlignment.Left,
            VerticalAlignment = el.verticalAlignment or Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }
    
    for i, subEl in ipairs(el.elements or {}) do
        local elementComponent = ElementRenderer.render(subEl, Store)
        if elementComponent then
            children["El_" .. subEl.id] = React.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = i,
            }, {
                Content = elementComponent,
            })
        end
    end
    
    return React.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, children)
end

return VStack

end

__modules["Components/Window"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Source = (script and typeof(script) == "Instance" and script.Parent and script.Parent.Parent) or Source or {}
local React = require(Source.React)

local Theme = require(Source.Theme)
local Sidebar = require(Source.Components.Sidebar)
local TabContainer = require(Source.Components.TabContainer)
local Icons = require(Source.Icons).assets

local Window = React.Component:extend("Window")

-- Helper Tag Component
local function TagComponent(props)
    local color = props.color or Theme.Colors.Accent
    local isGradient = type(color) == "table"
    
    return React.createElement("Frame", {
        Size = UDim2.new(0, 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = not isGradient and color or Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        LayoutOrder = props.LayoutOrder,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = UDim.new(0, 4),
        }),
        
        Padding = React.createElement("UIPadding", {
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6),
            PaddingTop = UDim.new(0, 1),
            PaddingBottom = UDim.new(0, 1),
        }),
        
        Gradient = isGradient and React.createElement("UIGradient", {
            Color = ColorSequence.new(unpack(color)),
            Rotation = 45,
        }),
        
        Label = React.createElement("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = string.upper(props.text),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Font = Theme.Fonts.Bold,
            TextSize = 8,
        }),
    })
end

function Window:init()
    self.windowRef = React.createRef()
    self.containerRef = React.createRef()
    self.dragConnection = nil
    self.dragInputConnection = nil
    
    self.state = {
        position = (self.props and self.props.state and self.props.state.windowPosition) or UDim2.new(0.5, -375, 0.5, -240),
        closing = false,
    }
end

function Window:didMount()
    local dragFrame = self.windowRef and self.windowRef.current
    local container = self.containerRef and self.containerRef.current
    if not dragFrame then return end
    
    -- Setup initial entry animation (slide-up/pop)
    local isMaximized = self.props.state.maximized
    local isMinimized = self.props.state.minimized
    
    local targetPos = isMaximized and UDim2.new(0, 0, 0, 0) or self.state.position
    local startPos = UDim2.new(
        targetPos.X.Scale,
        targetPos.X.Offset,
        targetPos.Y.Scale,
        targetPos.Y.Offset + 15
    )
    dragFrame.Position = startPos
    
    local targetSize = isMaximized and UDim2.new(1, 0, 1, 0) or (isMinimized and UDim2.new(0, 750, 0, 45) or UDim2.new(0, 750, 0, 480))
    dragFrame.Size = targetSize
    
    -- Entry transition: fade in
    dragFrame.GroupTransparency = 1
    
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(dragFrame, tweenInfo, {
        Position = targetPos,
        GroupTransparency = 0,
    }):Play()
    
    if container then
        container.GroupTransparency = isMinimized and 1 or 0
        container.Visible = not isMinimized
    end
    
    local dragging = false
    local dragInput
    local dragStart
    local startPosition
    
    local function update(input)
        if self.props.state.maximized then return end
        
        local delta = input.Position - dragStart
        local newPos = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
        self:setState({ position = newPos })
        if self.props and self.props.Store and self.props.Store._state then
            self.props.Store._state.windowPosition = newPos
        end
    end
    
    local titlebar = dragFrame:WaitForChild("TitleBar", 1)
    if titlebar then
        self.dragConnection = titlebar.InputBegan:Connect(function(input)
            if self.props.state.maximized then return end
            if not self.props.state.draggable and self.props.state.draggable ~= nil then return end
            
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPosition = dragFrame.Position
                
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        
        self.dragInputConnection = titlebar.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                update(input)
            end
        end)
    end
end

function Window:willUnmount()
    if self.dragConnection then self.dragConnection:Disconnect() end
    if self.dragInputConnection then self.dragInputConnection:Disconnect() end
end

function Window:didUpdate(prevProps, prevState)
    local dragFrame = self.windowRef and self.windowRef.current
    local container = self.containerRef and self.containerRef.current
    if not dragFrame then return end
    
    local isMinimized = self.props.state.minimized
    local isMaximized = self.props.state.maximized
    
    -- If visibility toggled back to true, reset closing state
    if self.props.state.visible and not prevProps.state.visible then
        self:setState({ closing = false })
        dragFrame.GroupTransparency = 0
    end
    
    local sizeChanged = (isMinimized ~= prevProps.state.minimized) or (isMaximized ~= prevProps.state.maximized)
    local posChanged = (isMaximized ~= prevProps.state.maximized)
    
    if sizeChanged or posChanged then
        local targetSize = isMaximized and UDim2.new(1, 0, 1, 0) or (isMinimized and UDim2.new(0, 750, 0, 45) or UDim2.new(0, 750, 0, 480))
        local targetPos = isMaximized and UDim2.new(0, 0, 0, 0) or self.state.position
        
        local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(dragFrame, tweenInfo, {
            Size = targetSize,
            Position = targetPos,
        }):Play()
        
        -- Handle container fade in/out during minimize
        if isMinimized ~= prevProps.state.minimized then
            if container then
                if isMinimized then
                    -- Fade out container content
                    local fadeTween = TweenService:Create(container, tweenInfo, { GroupTransparency = 1 })
                    fadeTween:Play()
                    fadeTween.Completed:Connect(function()
                        if self.props.state.minimized then
                            container.Visible = false
                        end
                    end)
                else
                    -- Fade in container content
                    container.Visible = true
                    container.GroupTransparency = 1
                    TweenService:Create(container, tweenInfo, { GroupTransparency = 0 }):Play()
                end
            end
        end
    elseif prevState.position ~= self.state.position and not isMaximized then
        -- Update position instantly if dragged
        dragFrame.Position = self.state.position
    end
end

function Window:render()
    local state = self.props.state
    local Store = self.props.Store
    
    local isMinimized = state.minimized
    local isMaximized = state.maximized
    
    local size = isMaximized and UDim2.new(1, 0, 1, 0) or (isMinimized and UDim2.new(0, 750, 0, 45) or UDim2.new(0, 750, 0, 480))
    local pos = isMaximized and UDim2.new(0, 0, 0, 0) or self.state.position
    
    local controlButtons = {
        Layout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }
    
    -- Minimize Button (-)
    if state.canMinimize ~= false then
        controlButtons.Minimize = React.createElement("ImageButton", {
            Size = UDim2.new(0, 14, 0, 14),
            BackgroundTransparency = 1,
            Image = Icons["lucide-minus"],
            ImageColor3 = Theme.Colors.TextSecondary,
            LayoutOrder = 1,
            [React.Event.MouseButton1Click] = function()
                Store:Update(function(s)
                    s.minimized = not s.minimized
                    if s.minimized then
                        s.maximized = false
                    end
                end)
            end,
        })
    end
    
    -- Maximize Button (+)
    if state.canZoom ~= false then
        controlButtons.Maximize = React.createElement("ImageButton", {
            Size = UDim2.new(0, 14, 0, 14),
            BackgroundTransparency = 1,
            Image = isMaximized and Icons["lucide-minimize-2"] or Icons["lucide-maximize-2"],
            ImageColor3 = Theme.Colors.TextSecondary,
            LayoutOrder = 2,
            [React.Event.MouseButton1Click] = function()
                Store:Update(function(s)
                    s.maximized = not s.maximized
                    if s.maximized then
                        s.minimized = false
                    end
                end)
            end,
        })
    end
    
    -- Close Button (X)
    if state.canExit ~= false then
        controlButtons.Close = React.createElement("ImageButton", {
            Size = UDim2.new(0, 14, 0, 14),
            BackgroundTransparency = 1,
            Image = Icons["lucide-x"],
            ImageColor3 = Theme.Colors.TextSecondary,
            LayoutOrder = 3,
            [React.Event.MouseButton1Click] = function()
                if self.state.closing then return end
                self:setState({ closing = true })
                
                local dragFrame = self.windowRef and self.windowRef.current
                if dragFrame then
                    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    local tween = TweenService:Create(dragFrame, tweenInfo, {
                        Position = UDim2.new(
                            dragFrame.Position.X.Scale,
                            dragFrame.Position.X.Offset,
                            dragFrame.Position.Y.Scale,
                            dragFrame.Position.Y.Offset + 15
                        ),
                        GroupTransparency = 1,
                    })
                    tween:Play()
                    tween.Completed:Connect(function()
                        Store:Update(function(s)
                            s.visible = false
                        end)
                    end)
                else
                    Store:Update(function(s)
                        s.visible = false
                    end)
                end
            end,
        })
    end
    
    return React.createElement("CanvasGroup", {
        ref = self.windowRef,
        Size = size,
        Position = pos,
        BackgroundColor3 = Theme.Colors.Background,
        BorderSizePixel = 0,
        Active = true,
        ClipsDescendants = true,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = Theme.CornerRadius.Window,
        }),
        
        Stroke = React.createElement("UIStroke", {
            Color = Theme.Colors.Border,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }),
        
        -- TitleBar / DragBar
        TitleBar = React.createElement("Frame", {
            Name = "TitleBar",
            Size = UDim2.new(1, 0, 0, 45),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 2,
        }, {
            -- Moon / App Icon
            Icon = React.createElement("ImageLabel", {
                Size = UDim2.new(0, 20, 0, 20),
                Position = UDim2.new(0, 15, 0.5, -10),
                BackgroundTransparency = 1,
                Image = "rbxassetid://10734950309", -- Moon icon
                ImageColor3 = Theme.Colors.Accent,
            }),
            
            -- Title Stack Area (Horizontal list layout)
            TitleArea = React.createElement("Frame", {
                Size = state.searching and UDim2.new(1, -310, 1, 0) or UDim2.new(1, -180, 1, 0),
                Position = UDim2.new(0, 45, 0, 0),
                BackgroundTransparency = 1,
            }, {
                Layout = React.createElement("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDim.new(0, 8),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),
                
                Title = React.createElement("TextLabel", {
                    Size = UDim2.new(0, 0, 1, 0),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundTransparency = 1,
                    Text = state.title,
                    TextColor3 = Theme.Colors.Text,
                    Font = Theme.Fonts.Bold,
                    TextSize = 14,
                    LayoutOrder = 1,
                }),
                
                TitleTag = state.titleTag and React.createElement(TagComponent, {
                    text = state.titleTag,
                    color = state.titleTagColor,
                    LayoutOrder = 2,
                }),
                
                Subtitle = state.subtitle ~= "" and React.createElement("TextLabel", {
                    Size = UDim2.new(0, 0, 1, 0),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundTransparency = 1,
                    Text = state.subtitle,
                    TextColor3 = Theme.Colors.TextSecondary,
                    Font = Theme.Fonts.Medium,
                    TextSize = 11,
                    LayoutOrder = 3,
                }),
                
                SubtitleTag = state.subtitleTag and React.createElement(TagComponent, {
                    text = state.subtitleTag,
                    color = state.subtitleTagColor,
                    LayoutOrder = 4,
                }),
            }),
            
            -- Top-bar Search Box
            SearchBar = state.searching and React.createElement("Frame", {
                Size = UDim2.new(0, 160, 0, 24),
                Position = UDim2.new(1, -290, 0.5, -12),
                BackgroundColor3 = Theme.Colors.Element,
                BorderSizePixel = 0,
                ZIndex = 3,
            }, {
                Corner = React.createElement("UICorner", {
                    CornerRadius = Theme.CornerRadius.Element,
                }),
                Stroke = React.createElement("UIStroke", {
                    Color = Theme.Colors.Border,
                    Thickness = 1,
                }),
                Padding = React.createElement("UIPadding", {
                    PaddingLeft = UDim.new(0, 8),
                    PaddingRight = UDim.new(0, 8),
                }),
                Icon = React.createElement("ImageLabel", {
                    Size = UDim2.new(0, 12, 0, 12),
                    Position = UDim2.new(0, 0, 0.5, -6),
                    BackgroundTransparency = 1,
                    Image = Icons["lucide-search"] or "rbxassetid://10734943674",
                    ImageColor3 = Theme.Colors.TextSecondary,
                }),
                Input = React.createElement("TextBox", {
                    Size = UDim2.new(1, -16, 1, 0),
                    Position = UDim2.new(0, 16, 0, 0),
                    BackgroundTransparency = 1,
                    Text = state.searchQuery,
                    PlaceholderText = "Search...",
                    PlaceholderColor3 = Theme.Colors.TextSecondary,
                    TextColor3 = Theme.Colors.Text,
                    Font = Theme.Fonts.Regular,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ClearTextOnFocus = false,
                    [React.Change.Text] = function(box)
                        Store:Update(function(s)
                            s.searchQuery = box.Text
                        end)
                    end,
                }),
            }),
            
            -- Window Controls
            Controls = React.createElement("Frame", {
                Size = UDim2.new(0, 100, 1, 0),
                Position = UDim2.new(1, -115, 0, 0),
                BackgroundTransparency = 1,
            }, controlButtons),
        }),
        
        -- Main split window container (only visible if NOT minimized)
        Container = React.createElement("CanvasGroup", {
            ref = self.containerRef,
            Size = UDim2.new(1, 0, 1, -45),
            Position = UDim2.new(0, 0, 0, 45),
            BackgroundTransparency = 1,
            Visible = not isMinimized,
        }, {
            Layout = React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            
            -- Sidebar Navigation
            Sidebar = React.createElement(Sidebar, {
                state = state,
                Store = Store,
                LayoutOrder = 1,
            }),
            
            -- Main Page Content
            MainContent = React.createElement(TabContainer, {
                state = state,
                Store = Store,
                LayoutOrder = 2,
            }),
        }),
        
        -- Color Picker Overlay inside Window (only dims/covers the GUI window!)
        ColorPickerOverlay = state.colorPickerActive and React.createElement(require(Source.Components.ColorPickerDialog), {
            colorPickerActive = state.colorPickerActive,
            Store = Store,
        }) or nil,
    })
end

return Window

end

__modules["init"] = function()
    local require = __require
    local Source = Source
    local script = Source

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Source = (script and typeof(script) == "Instance" and script:IsA("ModuleScript")) and script or Source or {}

local React = require(Source.React)
local ReactRoblox = require(Source.ReactRoblox)

local Theme = require(Source.Theme)
local Store = require(Source.Store)
local AppRecorderObj = require(Source.AppRecorder)

local Library = {}
Library.Theme = Theme
Library.Themes = Theme.Themes
Library.Accents = Theme.Accents
Library.AppRecorder = AppRecorderObj
Library.Icons = require(Source.Icons)
Library._customComponents = {}
local Icons = Library.Icons.assets

local function toKebabCase(str)
    local result = str:gsub("(%u)", "-%1"):gsub("(%d+)", "-%1"):lower()
    if result:sub(1, 1) == "-" then
        result = result:sub(2)
    end
    return result
end

local Symbols = {
    checkmark = "rbxassetid://10747373111",
    switch2 = "rbxassetid://10747372910",
    sliderHorizontal3 = "rbxassetid://10747381986",
    folder = "rbxassetid://10747372910",
    network = "rbxassetid://10747381881",
    pieChart = "rbxassetid://10747381986",
    gear = "rbxassetid://10747372251",
    house = "rbxassetid://10747379658",
}

setmetatable(Symbols, {
    __index = function(self, key)
        if type(key) ~= "string" then return nil end
        
        -- Try direct lookup
        local asset = Icons[key]
        if asset then return asset end
        
        -- Try lucide- prefix
        asset = Icons["lucide-" .. key]
        if asset then return asset end
        
        -- Convert to kebab case and try with lucide- prefix
        local kebab = toKebabCase(key)
        asset = Icons["lucide-" .. kebab]
        if asset then return asset end
        
        -- Fallback aliases
        if key == "gear" or key == "settings" then
            return Icons["lucide-settings"]
        elseif key == "house" or key == "home" then
            return Icons["lucide-home"]
        elseif key == "checkmark" or key == "check" then
            return Icons["lucide-check"]
        end
        
        return nil
    end
})

Library.Symbols = Symbols

-- Creator Support (declarative instance creation)
Library.Creator = {
    Create = function(className)
        return function(props)
            local instance = Instance.new(className)
            for k, v in pairs(props) do
                if type(k) == "string" then
                    local rawValue = v
                    if type(v) == "table" then
                        if v.__instance then
                            rawValue = v.__instance
                        else
                            rawValue = nil
                        end
                    end
                    if rawValue ~= nil or k ~= "Parent" then
                        instance[k] = rawValue
                    end
                else
                    -- Child element (handle wrapped and raw instances)
                    local rawInstance = (type(v) == "table" and v.__instance) and v.__instance or v
                    if rawInstance then
                        rawInstance.Parent = instance
                    end
                end
            end
            
            local wrapped = {
                __instance = instance,
            }
            setmetatable(wrapped, {
                __index = function(t, k)
                    if k == "__instance" then
                        return instance
                    else
                        return instance[k]
                    end
                end,
                __newindex = function(t, k, v)
                    instance[k] = v
                end
            })
            return wrapped
        end
    end
}

function Library.RegisterComponent(name, builder)
    Library._customComponents[name] = builder
end

local table_clone = table.clone or function(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

local root = nil
local screenGui = nil

local function getGuiParent()
    local success, CoreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if success and CoreGui then
        return CoreGui
    end
    
    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer
    if localPlayer then
        local playerGui = localPlayer:FindFirstChild("PlayerGui") or localPlayer:WaitForChild("PlayerGui", 5)
        if playerGui then
            return playerGui
        end
    end
    
    local success2, StarterGui = pcall(function()
        return game:GetService("StarterGui")
    end)
    if success2 and StarterGui then
        return StarterGui
    end
    
    return nil
end

local function wrapCallback(elementObj, configCallback)
    if not configCallback then return nil end
    return function(...)
        return configCallback(elementObj, ...)
    end
end

-- Helper to inject container methods for forms, stacks, rows recursively
local function setupContainerMethods(container, insertCallback)
    -- Row
    function container:Row(rowConfig)
        rowConfig = rowConfig or {}
        local rowId = math.random(1, 100000)
        local rowData = {
            id = rowId,
            type = "Row",
            leftElements = {},
            rightElements = {},
        }
        insertCallback(rowData)
        
        local RowObj = {}
        
        function RowObj:Left()
            local LeftObj = {}
            setupContainerMethods(LeftObj, function(el)
                table.insert(rowData.leftElements, el)
                Store:Update(function(state) end)
            end)
            return LeftObj
        end
        
        function RowObj:Right()
            local RightObj = {}
            setupContainerMethods(RightObj, function(el)
                el.hideLabel = true
                table.insert(rowData.rightElements, el)
                Store:Update(function(state) end)
            end)
            return RightObj
        end
        
        return RowObj
    end
    
    -- TitleStack (Left element)
    function container:TitleStack(config)
        config = config or {}
        local elData = {
            id = math.random(1, 100000),
            type = "TitleStack",
            title = config.Title,
            subtitle = config.Subtitle,
            titleTag = config.TitleTag,
            titleTagColor = config.TitleTagColor,
            subtitleTag = config.SubtitleTag,
            subtitleTagColor = config.SubtitleTagColor,
        }
        insertCallback(elData)
        
        local Element = {}
        function Element:SetTitle(txt)
            elData.title = txt
            Store:Update(function(state) end)
        end
        function Element:SetSubtitle(txt)
            elData.subtitle = txt
            Store:Update(function(state) end)
        end
        return Element
    end
    
    -- Label (Left or Right element)
    function container:Label(config)
        config = config or {}
        local elData = {
            id = math.random(1, 100000),
            type = "Label",
            text = config.Text or "Label",
            color = config.TextColor3,
            font = config.Font,
            textSize = config.TextSize,
            alignment = config.TextXAlignment,
        }
        insertCallback(elData)
        
        local Element = {}
        function Element:SetText(txt)
            elData.text = txt
            Store:Update(function(state) end)
        end
        return Element
    end
    
    -- Paragraph (Left or Right element)
    function container:Paragraph(config)
        config = config or {}
        local elData = {
            id = math.random(1, 100000),
            type = "Paragraph",
            title = config.Title,
            content = config.Content,
        }
        insertCallback(elData)
        
        local Element = {}
        function Element:SetTitle(txt)
            elData.title = txt
            Store:Update(function(state) end)
        end
        function Element:SetContent(txt)
            elData.content = txt
            Store:Update(function(state) end)
        end
        return Element
    end
    
    -- Toggle
    function container:Toggle(config)
        config = config or {}
        local Element = {}
        local elData = {
            id = math.random(1, 100000),
            type = "Toggle",
            name = config.Label or "Toggle",
            value = config.Value or false,
            callback = wrapCallback(Element, config.ValueChanged),
        }
        insertCallback(elData)
        
        function Element:SetValue(val)
            elData.value = val
            Store:Update(function(state) end)
        end
        function Element:SetText(txt)
            elData.name = txt
            Store:Update(function(state) end)
        end
        function Element:SetCallback(func)
            elData.callback = wrapCallback(Element, func)
        end
        return Element
    end
    
    -- TextField (TextBox)
    function container:TextField(config)
        config = config or {}
        local Element = {}
        local elData = {
            id = math.random(1, 100000),
            type = "TextBox",
            name = config.Label or "Text Field",
            placeholder = config.Placeholder,
            value = config.Value or "",
            callback = wrapCallback(Element, config.ValueChanged),
        }
        insertCallback(elData)
        
        function Element:SetValue(val)
            elData.value = val
            Store:Update(function(state) end)
        end
        function Element:SetText(txt)
            elData.name = txt
            Store:Update(function(state) end)
        end
        function Element:SetPlaceholder(txt)
            elData.placeholder = txt
            Store:Update(function(state) end)
        end
        function Element:SetCallback(func)
            elData.callback = wrapCallback(Element, func)
        end
        return Element
    end
    
    -- KeybindField
    function container:KeybindField(config)
        config = config or {}
        local Element = {}
        local elData = {
            id = math.random(1, 100000),
            type = "KeybindField",
            name = config.Label or "Keybind",
            value = config.Value,
            callback = wrapCallback(Element, config.ValueChanged),
        }
        insertCallback(elData)
        
        function Element:SetValue(val)
            elData.value = val
            Store:Update(function(state) end)
        end
        function Element:SetText(txt)
            elData.name = txt
            Store:Update(function(state) end)
        end
        function Element:SetCallback(func)
            elData.callback = wrapCallback(Element, func)
        end
        return Element
    end
    
    -- ColorPicker
    function container:ColorPicker(config)
        config = config or {}
        local Element = {}
        local elData = {
            id = math.random(1, 100000),
            type = "ColorPicker",
            name = config.Title or "Color Picker",
            value = config.Value or Color3.fromRGB(255, 255, 255),
            transparency = config.Transparency or 0,
            callback = wrapCallback(Element, config.ValueChanged),
        }
        insertCallback(elData)
        
        function Element:SetValue(val, trans)
            elData.value = val
            if trans then elData.transparency = trans end
            Store:Update(function(state) end)
        end
        function Element:SetText(txt)
            elData.name = txt
            Store:Update(function(state) end)
        end
        function Element:SetCallback(func)
            elData.callback = wrapCallback(Element, func)
        end
        return Element
    end
    
    -- ColorPickerWidget
    function container:ColorPickerWidget(config)
        config = config or {}
        local Element = {}
        local elData = {
            id = math.random(1, 100000),
            type = "ColorPickerWidget",
            name = config.Title or "Color Picker",
            value = config.Value or Color3.fromRGB(255, 255, 255),
            transparency = config.Transparency or 0,
            callback = wrapCallback(Element, config.ValueChanged),
        }
        insertCallback(elData)
        
        function Element:SetValue(val, trans)
            elData.value = val
            if trans then elData.transparency = trans end
            Store:Update(function(state) end)
        end
        function Element:SetText(txt)
            elData.name = txt
            Store:Update(function(state) end)
        end
        function Element:SetCallback(func)
            elData.callback = wrapCallback(Element, func)
        end
        return Element
    end
    
    -- Button
    function container:Button(config)
        config = config or {}
        local Element = {}
        local elData = {
            id = math.random(1, 100000),
            type = "Button",
            name = config.Label or "Button",
            icon = config.Icon,
            state = config.State,
            callback = wrapCallback(Element, config.Pushed),
        }
        insertCallback(elData)
        
        function Element:SetText(txt)
            elData.name = txt
            Store:Update(function(state) end)
        end
        function Element:SetIcon(icon)
            elData.icon = icon
            Store:Update(function(state) end)
        end
        function Element:SetCallback(func)
            elData.callback = wrapCallback(Element, func)
        end
        return Element
    end
    
    -- Slider
    function container:Slider(config)
        config = config or {}
        local Element = {}
        local elData = {
            id = math.random(1, 100000),
            type = "Slider",
            name = config.Label or "Slider",
            min = config.Minimum or 0,
            max = config.Maximum or 100,
            value = config.Value or config.Minimum or 0,
            callback = wrapCallback(Element, config.ValueChanged),
        }
        insertCallback(elData)
        
        function Element:SetValue(val)
            elData.value = val
            Store:Update(function(state) end)
        end
        function Element:SetMin(min)
            elData.min = min
            Store:Update(function(state) end)
        end
        function Element:SetMax(max)
            elData.max = max
            Store:Update(function(state) end)
        end
        function Element:SetText(txt)
            elData.name = txt
            Store:Update(function(state) end)
        end
        function Element:SetCallback(func)
            elData.callback = wrapCallback(Element, func)
        end
        return Element
    end
    
    -- Stepper
    function container:Stepper(config)
        config = config or {}
        local Element = {}
        local elData = {
            id = math.random(1, 100000),
            type = "Stepper",
            name = config.Label or "Stepper",
            min = config.Minimum or 0,
            max = config.Maximum or 100,
            step = config.Step or 1,
            value = config.Value or config.Minimum or 0,
            fielded = config.Fielded ~= false,
            callback = wrapCallback(Element, config.ValueChanged),
        }
        insertCallback(elData)
        
        function Element:SetValue(val)
            elData.value = val
            Store:Update(function(state) end)
        end
        function Element:SetText(txt)
            elData.name = txt
            Store:Update(function(state) end)
        end
        function Element:SetCallback(func)
            elData.callback = wrapCallback(Element, func)
        end
        return Element
    end
    
    -- RadioButtonGroup
    function container:RadioButtonGroup(config)
        config = config or {}
        local Element = {}
        local elData = {
            id = math.random(1, 100000),
            type = "RadioButtonGroup",
            name = config.Label or "Radio Group",
            options = config.Options or {},
            value = config.Value or 1,
            callback = wrapCallback(Element, config.ValueChanged),
        }
        insertCallback(elData)
        
        function Element:SetValue(val)
            elData.value = val
            Store:Update(function(state) end)
        end
        function Element:SetText(txt)
            elData.name = txt
            Store:Update(function(state) end)
        end
        function Element:SetCallback(func)
            elData.callback = wrapCallback(Element, func)
        end
        return Element
    end
    
    -- PopUpButton (Dropdown, supports multi-selection)
    function container:PopUpButton(config)
        config = config or {}
        local Element = {}
        local elData = {
            id = math.random(1, 100000),
            type = "Dropdown",
            name = config.Label or "Dropdown",
            options = config.Options or {},
            value = config.Value,
            maximum = config.Maximum or (config.Multi and 9999 or (type(config.Value) == "table" and 9999 or 1)),
            callback = wrapCallback(Element, config.ValueChanged),
        }
        insertCallback(elData)
        
        function Element:SetValue(val)
            elData.value = val
            Store:Update(function(state) end)
        end
        function Element:SetOptions(opts)
            elData.options = opts
            Store:Update(function(state) end)
        end
        function Element:SetText(txt)
            elData.name = txt
            Store:Update(function(state) end)
        end
        function Element:SetCallback(func)
            elData.callback = wrapCallback(Element, func)
        end
        return Element
    end
    
    -- PullDownButton
    function container:PullDownButton(config)
        config = config or {}
        local Element = {}
        local elData = {
            id = math.random(1, 100000),
            type = "PullDownButton",
            name = config.Label or "Menu",
            options = config.Options or {},
            callback = wrapCallback(Element, config.ValueChanged),
        }
        insertCallback(elData)
        
        function Element:SetOptions(opts)
            elData.options = opts
            Store:Update(function(state) end)
        end
        function Element:SetText(txt)
            elData.name = txt
            Store:Update(function(state) end)
        end
        function Element:SetCallback(func)
            elData.callback = wrapCallback(Element, func)
        end
        return Element
    end
    
    -- VStack
    function container:VStack(config)
        config = config or {}
        local elData = {
            id = math.random(1, 100000),
            type = "VStack",
            padding = config.Padding,
            horizontalAlignment = config.HorizontalAlignment,
            verticalAlignment = config.VerticalAlignment,
            elements = {},
        }
        insertCallback(elData)
        
        local VStackObj = {}
        setupContainerMethods(VStackObj, function(el)
            table.insert(elData.elements, el)
            Store:Update(function(state) end)
        end)
        return VStackObj
    end
    
    -- HStack
    function container:HStack(config)
        config = config or {}
        local elData = {
            id = math.random(1, 100000),
            type = "HStack",
            padding = config.Padding,
            horizontalAlignment = config.HorizontalAlignment,
            verticalAlignment = config.VerticalAlignment,
            elements = {},
        }
        insertCallback(elData)
        
        local HStackObj = {}
        setupContainerMethods(HStackObj, function(el)
            table.insert(elData.elements, el)
            Store:Update(function(state) end)
        end)
        return HStackObj
    end
    
    -- BarChart
    function container:BarChart(config)
        config = config or {}
        local elData = {
            id = math.random(1, 100000),
            type = "BarChart",
            title = config.Title,
            subtitle = config.Subtitle,
            height = config.Height,
            data = config.Data or {},
        }
        insertCallback(elData)
        
        local Element = {}
        function Element:SetData(newData)
            elData.data = newData or {}
            Store:Update(function(state) end)
        end
        function Element:PushData(val, maxPoints)
            table.insert(elData.data, val)
            maxPoints = maxPoints or 10
            while #elData.data > maxPoints do
                table.remove(elData.data, 1)
            end
            Store:Update(function(state) end)
        end
        function Element:SetTitle(txt)
            elData.title = txt
            Store:Update(function(state) end)
        end
        function Element:SetSubtitle(txt)
            elData.subtitle = txt
            Store:Update(function(state) end)
        end
        return Element
    end
    
    -- LineChart
    function container:LineChart(config)
        config = config or {}
        local elData = {
            id = math.random(1, 100000),
            type = "LineChart",
            title = config.Title,
            subtitle = config.Subtitle,
            height = config.Height,
            data = config.Data or {},
            labels = config.Labels or {},
            color = config.Color,
        }
        insertCallback(elData)
        
        local Element = {}
        function Element:SetData(newData, newLabels)
            elData.data = newData or {}
            if newLabels then
                elData.labels = newLabels
            end
            Store:Update(function(state) end)
        end
        function Element:PushData(val, label, maxPoints)
            table.insert(elData.data, val)
            if label ~= nil or #elData.labels > 0 then
                table.insert(elData.labels, label or "")
            end
            maxPoints = maxPoints or 10
            while #elData.data > maxPoints do
                table.remove(elData.data, 1)
                if #elData.labels > 0 then
                    table.remove(elData.labels, 1)
                end
            end
            Store:Update(function(state) end)
        end
        function Element:SetTitle(txt)
            elData.title = txt
            Store:Update(function(state) end)
        end
        function Element:SetSubtitle(txt)
            elData.subtitle = txt
            Store:Update(function(state) end)
        end
        function Element:SetColor(color)
            elData.color = color
            Store:Update(function(state) end)
        end
        return Element
    end
    
    -- PieChart
    function container:PieChart(config)
        config = config or {}
        local elData = {
            id = math.random(1, 100000),
            type = "PieChart",
            title = config.Title,
            subtitle = config.Subtitle,
            size = config.Size,
            donut = config.Donut,
            align = config.Align,
            data = config.Data or {},
        }
        insertCallback(elData)
        
        local Element = {}
        function Element:SetData(newData)
            elData.data = newData or {}
            Store:Update(function(state) end)
        end
        function Element:SetTitle(txt)
            elData.title = txt
            Store:Update(function(state) end)
        end
        function Element:SetSubtitle(txt)
            elData.subtitle = txt
            Store:Update(function(state) end)
        end
        return Element
    end
    
    -- InfoGrid
    function container:InfoGrid(config)
        config = config or {}
        local elData = {
            id = math.random(1, 100000),
            type = "InfoGrid",
            rows = config.Rows or {},
        }
        insertCallback(elData)
        
        local Element = {}
        function Element:UpdateRow(rowIdx, rowData)
            elData.rows[rowIdx] = rowData
            Store:Update(function(state) end)
        end
        return Element
    end
    
    -- PageSection (styled Card container in tab)
    function container:PageSection(config)
        config = config or {}
        local sectionId = math.random(1, 100000)
        local secData = {
            id = sectionId,
            type = "Section",
            name = config.Title,
            description = config.Subtitle,
            column = config.Column or 1,
            gradientPreset = config.GradientPreset,
            gradient = config.Gradient,
            elements = {},
        }
        insertCallback(secData)
        
        local PageSecObj = {}
        function PageSecObj:Form()
            local FormObj = {}
            FormObj.type = "Form"
            FormObj.elements = {}
            table.insert(secData.elements, FormObj)
            
            setupContainerMethods(FormObj, function(el)
                table.insert(FormObj.elements, el)
                Store:Update(function(state) end)
            end)
            return FormObj
        end
        
        return PageSecObj
    end
    
    -- ImageSurface
    function container:ImageSurface(config)
        config = config or {}
        local elData = {
            id = math.random(1, 100000),
            type = "Label",
            text = "",
            icon = config.Image,
            color = config.SurfaceColor,
        }
        insertCallback(elData)
        return elData
    end
    
    -- Custom Component dynamic registration routing
    setmetatable(container, {
        __index = function(t, k)
            if Library._customComponents[k] then
                return function(self, properties)
                    properties = properties or {}
                    
                    -- Setup element placeholder in react
                    local elData = {
                        id = math.random(1, 100000),
                        type = "CustomComponentPlaceholder",
                        instance = nil,
                    }
                    insertCallback(elData)
                    
                    properties.Parent = nil
                    local customObj = Library._customComponents[k](self, properties)
                    
                    -- Capture the created instance
                    elData.instance = customObj and customObj.__instance
                    Store:Update(function(state) end)
                    
                    return customObj
                end
            end
            return nil
        end
    })
end

-- New Application Setup
function Library.New(properties)
    properties = properties or {}
    
    local initialTheme = "Dark"
    local initialAccent = "Blue"
    
    if properties.Theme then
        for name, themeObj in pairs(Theme.Themes) do
            if themeObj == properties.Theme or name == properties.Theme then
                initialTheme = name
                break
            end
        end
    end
    
    if properties.Accent then
        for name, accentObj in pairs(Theme.Accents) do
            if accentObj == properties.Accent or name == properties.Accent then
                initialAccent = name
                break
            end
        end
    end
    
    Store:Update(function(state)
        state.theme = initialTheme
        state.accent = initialAccent
    end)
    
    -- App Instance supporting live setting of Theme/Accent using metatables
    local app = setmetatable({
        _id = "app",
    }, {
        __index = function(t, k)
            if k == "Theme" then
                return Theme.Themes[Store._state.theme]
            elseif k == "Accent" then
                return Theme.Accents[Store._state.accent]
            elseif k == "Notification" then
                return function(self, config)
                    Library:Notification(config)
                end
            elseif k == "Page" then
                return function(self)
                    return Library:Page()
                end
            elseif k == "Window" then
                return function(self, config)
                    return Library:CreateWindow(config)
                end
            end
            return nil
        end,
        
        __newindex = function(t, k, v)
            if k == "Theme" then
                local themeName = nil
                for name, themeObj in pairs(Theme.Themes) do
                    if themeObj == v or name == v then
                        themeName = name
                        break
                    end
                end
                if themeName then
                    Store:Update(function(state)
                        state.theme = themeName
                    end)
                end
            elseif k == "Accent" then
                local accentName = nil
                for name, accentObj in pairs(Theme.Accents) do
                    if accentObj == v or name == v then
                        accentName = name
                        break
                    end
                end
                if accentName then
                    Store:Update(function(state)
                        state.accent = accentName
                    end)
                end
            else
                rawset(t, k, v)
            end
        end
    })
    
    return app
end

-- Create Window (Cascade Sequoia specification)
function Library:CreateWindow(config)
    config = config or {}
    
    Store:Update(function(state)
        state.title = config.Title or config.Name or "Selene UI"
        state.subtitle = config.Subtitle or ""
        
        state.titleTag = config.TitleTag
        state.titleTagColor = config.TitleTagColor
        state.subtitleTag = config.SubtitleTag
        state.subtitleTagColor = config.SubtitleTagColor
        
        state.searching = config.Searching ~= false
        state.draggable = config.Draggable ~= false
        state.canExit = config.CanExit ~= false
        state.canMinimize = config.CanMinimize ~= false
        state.canZoom = config.CanZoom ~= false
        state.minimized = config.Minimized == true
        state.maximized = config.Maximized == true
        
        state.sections = {}
        state.activeTab = nil
        state.visible = true
        state.profile = nil
    end)
    
    local parent = getGuiParent()
    if not parent then
        error("Cannot find Gui parent (CoreGui or PlayerGui).")
    end
    
    local existing = parent:FindFirstChild("SeleneUILibrary")
    if existing then
        existing:Destroy()
    end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SeleneUILibrary"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = parent

    -- Setup Keybind toggling (minimize)
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightControl
    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == toggleKey then
            Store:Update(function(state)
                state.visible = not state.visible
            end)
        end
    end)
    
    -- Mount React root
    local AppComponent = React.Component:extend("App")
    
    function AppComponent:init()
        self.state = Store._state
    end
    
    local pendingRerender = false
    function AppComponent:didMount()
        self.unsubscribe = Store:Subscribe(function(newState)
            -- Apply Theme changes globally before rendering
            local activeTheme = Theme.Themes[newState.theme or "Dark"]
            if activeTheme then
                for k, v in pairs(activeTheme) do
                    Theme.Colors[k] = v
                end
                Theme.Colors.Accent = Theme.Accents[newState.accent or "Blue"]
            end
            
            if not pendingRerender then
                pendingRerender = true
                task.defer(function()
                    pendingRerender = false
                    self:setState(table_clone(Store._state))
                end)
            end
        end)
    end
    
    function AppComponent:willUnmount()
        if self.unsubscribe then
            self.unsubscribe()
        end
    end
    
    function AppComponent:render()
        local state = self.state
        local WindowComponent = require(Source.Components.Window)
        local NotificationComponent = require(Source.Components.Notification)
        
        return React.createElement("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
        }, {
            Window = state.visible and React.createElement(WindowComponent, {
                state = state,
                Store = Store,
            }) or nil,
            
            Notifications = React.createElement(NotificationComponent.List, {
                notifications = state.notifications,
                Store = Store,
            }),
        })
    end
    
    root = ReactRoblox.createRoot(screenGui)
    root:render(React.createElement(AppComponent))
    
    -- Window OOP Object
    local Window = {}
    
    -- Destroying signal emulation
    local destroyingBindable = Instance.new("BindableEvent")
    Window.Destroying = destroyingBindable.Event
    
    -- Metatable support to let users set properties directly like window.Minimized = ...
    setmetatable(Window, {
        __index = function(t, k)
            if k == "Minimized" then
                return Store._state.minimized
            elseif k == "Maximized" then
                return Store._state.maximized
            elseif k == "Visible" then
                return Store._state.visible
            else
                return rawget(t, k)
            end
        end,
        __newindex = function(t, k, v)
            if k == "Minimized" then
                Store:Update(function(state)
                    state.minimized = v
                end)
            elseif k == "Maximized" then
                Store:Update(function(state)
                    state.maximized = v
                end)
            elseif k == "Visible" then
                Store:Update(function(state)
                    state.visible = v
                end)
            else
                rawset(t, k, v)
            end
        end
    })
    
    function Window:SetProfile(profileConfig)
        Store:Update(function(state)
            state.profile = {
                username = profileConfig.Username or "User",
                subtext = profileConfig.Subtext or "Developer",
                userId = profileConfig.UserId or 1,
            }
        end)
    end
    
    -- Section (sidebar collapsible category)
    function Window:Section(secConfig)
        secConfig = secConfig or {}
        local sectionId = #Store._state.sections + 1
        local secData = {
            id = sectionId,
            title = secConfig.Title or "",
            disclosure = secConfig.Disclosure == true,
            tabs = {},
        }
        
        Store:Update(function(state)
            table.insert(state.sections, secData)
        end)
        
        local SectionObj = {}
        
        -- Tab under section
        function SectionObj:Tab(tabConfig)
            tabConfig = tabConfig or {}
            local tabId = math.random(1, 100000)
            local tabData = {
                id = tabId,
                title = tabConfig.Title or "Tab",
                icon = tabConfig.Icon,
                pageSections = {},
            }
            
            Store:Update(function(state)
                for _, s in ipairs(state.sections) do
                    if s.id == sectionId then
                        table.insert(s.tabs, tabData)
                        break
                    end
                end
                table.insert(state.tabs, tabData)
                
                if not state.activeTab then
                    state.activeTab = tabId
                end
            end)
            
            local function buildTabObj(currentTabId, currentSectionId)
                local TabObj = {}
                
                function TabObj:SetBanner(bannerConfig)
                    Store:Update(function(state)
                        for _, s in ipairs(state.sections) do
                            for _, t in ipairs(s.tabs) do
                                if t.id == currentTabId then
                                    t.banner = {
                                        username = bannerConfig.Username or "User",
                                        subtext = bannerConfig.Subtext or "",
                                        userId = bannerConfig.UserId or 1,
                                    }
                                    break
                                end
                            end
                        end
                    end)
                end
                
                function TabObj:Navigate(page)
                    Store:Update(function(state)
                        for _, s in ipairs(state.sections) do
                            for _, t in ipairs(s.tabs) do
                                if t.id == currentTabId then
                                    t.pageSections = page.elements
                                    break
                                end
                            end
                        end
                    end)
                end
                
                function TabObj:Form()
                    local FormObj = {
                        id = math.random(1, 100000),
                        type = "Form",
                        elements = {},
                    }
                    
                    Store:Update(function(state)
                        for _, s in ipairs(state.sections) do
                            for _, t in ipairs(s.tabs) do
                                if t.id == currentTabId then
                                    table.insert(t.pageSections, FormObj)
                                    break
                                end
                            end
                        end
                    end)
                    
                    setupContainerMethods(FormObj, function(el)
                        table.insert(FormObj.elements, el)
                        Store:Update(function(state) end)
                    end)
                    return FormObj
                end
                
                function TabObj:PageSection(config)
                    config = config or {}
                    local pageSecId = math.random(1, 100000)
                    local pageSecData = {
                        id = pageSecId,
                        type = "Section",
                        name = config.Title,
                        description = config.Subtitle,
                        column = config.Column or 1,
                        gradientPreset = config.GradientPreset,
                        gradient = config.Gradient,
                        elements = {},
                    }
                    
                    Store:Update(function(state)
                        for _, s in ipairs(state.sections) do
                            for _, t in ipairs(s.tabs) do
                                if t.id == currentTabId then
                                    table.insert(t.pageSections, pageSecData)
                                    break
                                end
                            end
                        end
                    end)
                    
                    local PageSecObj = {}
                    function PageSecObj:Form()
                        local FormObj = {
                            id = math.random(1, 100000),
                            type = "Form",
                            elements = {},
                        }
                        table.insert(pageSecData.elements, FormObj)
                        
                        setupContainerMethods(FormObj, function(el)
                            table.insert(FormObj.elements, el)
                            Store:Update(function(state) end)
                        end)
                        return FormObj
                    end
                    
                    return PageSecObj
                end
                
                -- Support nesting Tab inside another Tab
                function TabObj:Tab(subTabConfig)
                    subTabConfig = subTabConfig or {}
                    local subTabId = math.random(1, 100000)
                    local subTabData = {
                        id = subTabId,
                        title = subTabConfig.Title or "Sub Tab",
                        icon = subTabConfig.Icon,
                        parentTabId = currentTabId,
                        pageSections = {},
                    }
                    
                    Store:Update(function(state)
                        for _, s in ipairs(state.sections) do
                            if s.id == currentSectionId then
                                local parentIndex = nil
                                for idx, t in ipairs(s.tabs) do
                                    if t.id == currentTabId then
                                        parentIndex = idx
                                        break
                                    end
                                end
                                if parentIndex then
                                    table.insert(s.tabs, parentIndex + 1, subTabData)
                                else
                                    table.insert(s.tabs, subTabData)
                                end
                                break
                            end
                        end
                        table.insert(state.tabs, subTabData)
                    end)
                    
                    return buildTabObj(subTabId, currentSectionId)
                end
                
                return TabObj
            end
            
            return buildTabObj(tabId, sectionId)
        end
        
        return SectionObj
    end
    
    function Window:Destroy()
        destroyingBindable:Fire()
        if root then
            root:unmount()
            root = nil
        end
        if screenGui then
            screenGui:Destroy()
            screenGui = nil
        end
    end
    
    return Window
end

-- Spawn stack notifications
function Library:Notification(config)
    config = config or {}
    local title = config.Title or "Notification"
    local subtitle = config.Subtitle or ""
    local icon = config.AppIcon or config.Icon
    local duration = config.Duration or 5
    
    local targetId = nil
    local currentTime = os.clock()
    
    Store:Update(function(state)
        local existingNotif = nil
        -- Find existing notification with identical title and subtitle
        for _, notif in ipairs(state.notifications) do
            if notif.title == title and notif.subtitle == subtitle then
                existingNotif = notif
                break
            end
        end
        
        if existingNotif then
            targetId = existingNotif.id
            existingNotif.count = (existingNotif.count or 1) + 1
            existingNotif.spawnTime = currentTime
            existingNotif.duration = duration
        else
            targetId = math.random(1, 100000)
            local newNotif = {
                id = targetId,
                title = title,
                subtitle = subtitle,
                icon = icon,
                duration = duration,
                count = 1,
                spawnTime = currentTime,
            }
            table.insert(state.notifications, newNotif)
        end
        
        -- Clone array reference so React detects state change
        state.notifications = table_clone(state.notifications)
    end)
    
    -- Auto dismiss after duration
    task.spawn(function()
        task.wait(duration)
        Store:Update(function(state)
            local index = nil
            for k, v in ipairs(state.notifications) do
                if v.id == targetId then
                    -- Verify if the notification was refreshed during wait
                    if os.clock() >= (v.spawnTime or 0) + (v.duration or 5) - 0.05 then
                        index = k
                    end
                    break
                end
            end
            if index then
                table.remove(state.notifications, index)
                state.notifications = table_clone(state.notifications) -- Clone array reference on removal
            end
        end)
    end)
end

-- Page constructor for dynamic routing
function Library:Page()
    local Page = {}
    Page.elements = {}
    
    function Page:Form()
        local FormObj = {
            id = math.random(1, 100000),
            type = "Form",
            elements = {},
        }
        table.insert(Page.elements, FormObj)
        
        setupContainerMethods(FormObj, function(el)
            table.insert(FormObj.elements, el)
            Store:Update(function(state) end)
        end)
        return FormObj
    end
    
    return Page
end

return Library

end

return __require("init")
