script_name("SA-MP Chat")
script_author("Zoom Developer")
script_version("0.3.2")
script_properties("work-in-pause")

local effil = require 'effil'
local encoding = require 'encoding'
local imgui = require 'imgui'
local sampev = require 'lib.samp.events'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local colors = {
    tag = "{666666}",
    tag_hex = 0x666666,
    text = "{E5B884}",
    text_hex = 0xE5B884,
    selection = "{999999}",
    sms = "{279E0F}"
}

local page = "main"
local opened = imgui.ImBool(false)
local name_input = imgui.ImBuffer(128)
local regname_input = imgui.ImBuffer(128)

local url = "http://example.com:9999/"
local sms_url = "http://example.com/sms.mp3"

function main()
    if not isSampfuncsLoaded() or not isSampLoaded() then
        return
    end
    while not isSampAvailable() do
        wait(0)
    end

    token = getToken()

    sampRegisterChatCommand("chat", send_message)
    sampRegisterChatCommand("chat.sms", send_sms)
    sampRegisterChatCommand("chat.menu", function()
        opened.v = not opened.v
    end)

    wait(500)

    imgui.Process = false

    imgui.SwitchContext()
    setColorTheme()

    chatMessage(colors.selection, script.this.name, " ", script.this.version, colors.text, " успешно загружен.")
    chatMessage("Доступные команды: ", colors.selection, "/chat, /chat.sms, /chat.menu")

    auth = false
    accesed = false
    interier = nil
    markered_user = 0
    message_id = -1

    if token ~= 0 then
        local args = {headers = {["Authorization"] = token}}
        asyncHttpRequest("GET", url .. "member", args, 
            function(response)
                if response.status_code == 200 then 
                    print("Auth completed")
                    data = decodeJson(response.text)
                    id = data.id
                    name = data.name
                    vk = data.vk
                    name_input.v = name
                    auth = true 
                    accesed = true
                else
                    chatMessage("Неверный ", colors.selection, "Auth Token", colors.text, ", обратитесь за помощью к администратору чата.")
                end
            end
        )
    else
        chatMessage("Вы не зарегистрированы в системе. Пройдите регистрацию в ", colors.selection, "/chat.menu")
    end

    while true do

        imgui.Process = opened.v

        if auth and accesed then
            local args = {headers = {["Authorization"] = token}}
            asyncHttpRequest("GET", url .. "messages/" .. message_id, args, 
                function(response)
                    data = decodeJson(response.text)
                    if data.error then
                        if data.error == "Invalid user" then 
                            chatMessage("Неверный ", colors.selection, "Auth Token", colors.text, ", обратитесь за помощью к администратору чата")
                            auth = false
                        elseif data.error == "Access denied" then
                            chatMessage("Доступ к просмотру чата запрещён, обратитесь к администратору чата для его получения")
                            accesed = false
                        else
                            chatMessage("Неизвестная ошибка ", colors.selection, data.error, colors.text, ", обратитесь к разработчику.")
                        end
                    else
                        if data.messages[1] then
                            if message_id == -1 then
                                message_id = data.messages[1].id
                            else
                                for _, msg in pairs(data.messages) do
                                    message_id = msg.id
                                    local ip, port = sampGetCurrentServerAddress()
                                    server = ""
                                    userid = " [" .. msg.user .. "]"
                                    if msg.type == "vk" then server = " (ВК)" end
                                    if msg.type == "samp" and msg.ip ~= ip .. ":" .. port then server = " (" .. u8:decode(msg.server) .. ")" end
                                    if msg.type == "sms" then 
                                        chatMessage(colors.selection, u8:decode(msg.name), userid, colors.sms, " >> ", colors.selection, u8:decode(msg.receiver_name), ": ", colors.text, u8:decode(msg.text))
                                        if msg.receiver == tostring(id) then
                                            audio = loadAudioStream(sms_url)
                                            setAudioStreamState(audio, as_action.PLAY)
                                        end
                                    else chatMessage(colors.selection, u8:decode(msg.name), userid, server, ": ", colors.text, u8:decode(msg.text)) end
                                end
                            end
                        end
                    end
                end
            )
            local positionX, positionZ, in_int
            if interier then
                positionX, positionZ = interier[1], interier[2]
                in_int = 1
            else
                positionX, positionZ = getCharCoordinates(PLAYER_PED)
                in_int = 0
            end
            local ip, port = sampGetCurrentServerAddress()
            local sv_name = sampGetCurrentServerName()
            asyncHttpRequest("POST", url .. "member/ping?online=1&x="..positionX.."&y="..positionZ.."&server="..urlencode(sv_name).."&ip="..urlencode(ip..":"..port).."&in_int="..in_int, args, 
                function(response)
                    if response.status_code == 200 then
                        data = decodeJson(response.text)
                        id = data.user.id
                        name = data.user.name
                        vk = data.user.vk
                        accesed = data.user.rank > 0
                        users = data.users
                        if markered_user ~= 0 then
                            for _, usr in pairs(users) do
                                if usr.id == markered_user then
                                    local ip, port = sampGetCurrentServerAddress()
                                    if not usr.online or usr.ip ~= ip..":"..port then chatMessage("Игрок за которым вы следили вышел из игры"); markered_user = 0
                                    else
                                        setMarker(usr.x, usr.y)
                                    end
                                end
                            end
                        else 
                            deleteCheckpoint(checkpoint)
                            removeBlip(marker)
                        end
                    end
                end
            )
        end
        wait(500)
    end
end

function imgui.OnDrawFrame()
    if opened.v then
        local sw, sh = getScreenResolution()
        imgui.SetNextWindowSizeConstraints(imgui.ImVec2(400, 0), imgui.ImVec2(sw / 2, sh / 2))
        imgui.SetNextWindowPos(imgui.ImVec2(sw / 2 - 150, sh / 2 - 100), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.Begin(u8(script.this.name .. " | by Zoom Developer (vk.com/id380487228)"), opened, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
        if imgui.Button(u8"Главная", imgui.ImVec2(200,40)) then page = "main" end
        imgui.SameLine()
        if imgui.Button(u8"Пользователи", imgui.ImVec2(200,40)) then page = "members" end
        imgui.Separator()
        if page == "main" then
            imgui.TextColoredRGB("Версия скрипта: " .. colors.selection .. script.this.version)
            imgui.NewLine()
            if token == 0 then 
                imgui.Text(u8"Вы не зарегистрированы.")
                imgui.InputText(u8"Желаемый ник", regname_input)
                if imgui.Button(u8"Зарегистрироваться") then
                    local regname = string.trim(u8:decode(regname_input.v))
                    if string.len(regname) < 1 then chatMessage("Имя не должно быть пустым")
                    elseif string.len(regname) > 25 then chatMessage("Максимальная длина ника - 25 символов")
                    else
                        asyncHttpRequest("POST", url .. "member?name=" .. urlencode(regname), nil, 
                            function(response)
                                data = decodeJson(response.text)
                                token = data.token
                                id = data.id
                                writeToken(data.token)
                                auth = true
                                chatMessage("Регистрация в системе прошла успешно. Ваш ID: ", colors.selection, data.id)
                            end
                        )
                    end
                end
            elseif not auth then imgui.Text(u8"Вы не авторизованы")
            else
                local args = {headers = {["Authorization"] = token}}
                imgui.TextColoredRGB("Ваш ID: " .. colors.selection .. id)
                if accesed then
                    if vk then
                        imgui.TextColoredRGB("ВКонтакте: {25950F} Привязан")
                        imgui.SameLine()
                        if imgui.Button(u8"Отвязать") then
                            asyncHttpRequest("DELETE", url .. "vk", args, 
                                function(response)
                                    if response.status_code == 200 then chatMessage("Ваш ВКонтакте успешно отвязан.")
                                    else chatMessage("Произошла ошибка при отвязке ВК") end
                                end
                            )
                        end
                    else
                        imgui.TextColoredRGB("ВКонтакте: {FF1404} Не привязан")
                        imgui.SameLine()
                        if imgui.Button(u8"Привязать") then
                            asyncHttpRequest("GET", url .. "vk", args, 
                                function(response)
                                    if response.status_code == 200 then
                                        code = decodeJson(response.text).code
                                        chatMessage("Ваш код для привязки ВКонтакте: ", colors.selection, code, colors.text, ", введите /connect [КОД] в беседе ВК.")
                                    else chatMessage("Произошла ошибка при получении кода привязки.") end
                                end
                            )
                        end
                    end
                    imgui.PushItemWidth(150)
                    imgui.InputText(u8"Ваш ник", name_input)
                    imgui.PopItemWidth()
                    if name_input.v ~= name then
                        imgui.SameLine()
                        if imgui.Button(u8"Изменить") then 
                            local newname = string.trim(u8:decode(name_input.v))
                            if string.len(newname) < 1 then chatMessage("Имя не должно быть пустым")
                            elseif string.len(newname) > 25 then chatMessage("Максимальная длина ника - 25 символов")
                            else
                                asyncHttpRequest("PATCH", url .. "member?name=" .. urlencode(newname), args, 
                                    function(response)
                                        if response.status_code == 200 then
                                            chatMessage("Ваш ник успешно сменён")
                                            name = newname
                                        else
                                            chatMessage("Произошла ошибка при смене ника.")
                                        end
                                    end
                                )
                            end
                        end
                        imgui.SameLine()
                        if imgui.Button(u8"Отмена") then name_input.v = name end
                    else name_input.v = name end
                end
            end
            imgui.NewLine()
            if imgui.Button(u8"Перезагрузить скрипт") then
                reload = true
                thisScript():reload()
            end
            imgui.End()
        elseif page == "members" then
            local sw, sh = getScreenResolution()
            if token == 0 then imgui.Text(u8"Вы не зарегистрированы.")
            elseif not auth then imgui.Text(u8"Вы не авторизованы")
            elseif not accesed then imgui.Text(u8"Доступ запрещён")
            else
                imgui.BeginChild("Members", imgui.ImVec2(550, 155))
                for _, usr in pairs(users) do
                    imgui.TextColoredRGB(colors.text .. u8:decode(usr.name) .. " [" .. usr.id .. "]")
                    if usr.online > 0 then
                        imgui.SameLine()
                        imgui.TextColoredRGB(colors.selection .. " | на " .. u8:decode(usr.server))
                        local ip, port = sampGetCurrentServerAddress()
                        if usr.ip == ip .. ":" .. port and usr.id ~= id then
                            if imgui.Button(u8"Поставить маркер##"..usr.id) then markered_user = usr.id end
                        end
                    end
                end
                imgui.EndChild()
                if markered_user ~= 0 and imgui.Button(u8"Удалить маркер") then markered_user = 0 end
            end
            imgui.End()
        end
    end
end

function sampev.onSetInterior(int_id)
    if int_id == 0 then interier = nil
    else 
        local positionX, positionZ = getCharCoordinates(PLAYER_PED)
        interier = {positionX, positionZ}
    end
end

function chatMessage(...)
    local text = "[SampChat]: " .. colors.text
    for _, v in pairs({...}) do
      text = text .. v
    end
    lastline = ""
    color = colors.tag_hex
    while string.len(text) > 0 do
        line = string.sub(text, 1, 128)
        lastcolor = lastline:match(".*({.*}).*") or ""
        sampAddChatMessage(lastcolor .. line, color)
        text = string.sub(text, 129)
        lastline = lastcolor .. line
        color = colors.text_hex
    end
end

function writeToken(newtoken)
    local file = io.open(getWorkingDirectory() .. "//sampchat.key", "w")
    file:write(newtoken)
    file:close()
end

function getToken()
    local file = io.open(getWorkingDirectory() .. "//sampchat.key", "r")
    if not file then return 0 end
    local token = file:read()
    file:close()
    return token
end

function send_message(text)
    if token == 0 then return chatMessage("Вы не зарегистрированы в системе. Пройдите регистрацию в ", colors.selection, "/chat.menu") end
    if not auth then return chatMessage("Вы не авторизованы") end
    if not accesed then return chatMessage("Вы не имеете доступа") end
    local ip, port = sampGetCurrentServerAddress()
    local sv_name = sampGetCurrentServerName()
    local args = {headers = {["Authorization"] = token}}
    asyncHttpRequest("POST", url .. "messages?text=" .. urlencode(text) .. "&ip=" .. urlencode(ip .. ":" .. port) .. "&server=" .. urlencode(sv_name), args)
end

function send_sms(arg)
    if token == 0 then return chatMessage("Вы не зарегистрированы в системе. Пройдите регистрацию в ", colors.selection, "/chat.menu") end
    if not auth then return chatMessage("Вы не авторизованы") end
    if not accesed then return chatMessage("Вы не имеете доступа") end
    if arg:find('(.+) (.+)') then
        receiver, text = arg:match('([^ ]+) (.+)')
        local args = {headers = {["Authorization"] = token}}
        asyncHttpRequest("POST", url .. "sms?receiver=" .. urlencode(receiver) .. "&text=" .. urlencode(text), args, 
            function(response)
                if response.status_code == 470 then chatMessage("Пользователь не найден или он не в сети")
                elseif response.status_code ~= 200 then chatMessage("При отправке сообщения произошла неизвестная ошибка") end
            end
        )
    else
        chatMessage("Используйте: ", colors.selection, "/chat.sms ID|Имя Текст ", colors.text, "(ID* - Chat ID, не SAMP)")
    end
end

function onScriptTerminate(script, quitGame)
    if script == thisScript() then
        deleteCheckpoint(checkpoint)
        removeBlip(marker)
        if not quitGame and not reload then chatMessage("Работа скрипта была завершена по неизвестной причине.") end
        local args = {headers = {["Authorization"] = id}}
        asyncHttpRequest("POST", url .. "member/ping?online=0", args)
    end
end

function setMarker(x, y)
    deleteCheckpoint(checkpoint)
    removeBlip(marker)
    marker = addBlipForCoord(x, y)
    checkpoint = createCheckpoint(2, x, y, 1, 1, 1, 1, 2.5)
end

function string.trim(s)
    return s:match("^%s*(.-)%s*$")
end

function asyncHttpRequest(method, url, args, resolve, reject)
    local request_thread = effil.thread(function (method, url, args)
       local requests = require 'requests'
       local result, response = pcall(requests.request, method, url, args)
       if result then
          response.json, response.xml = nil, nil
          return true, response
       else
          return false, response
       end
    end)(method, url, args)
    -- Если запрос без функций обработки ответа и ошибок.
    if not resolve then resolve = function() end end
    if not reject then reject = function() end end
    -- Проверка выполнения потока
    lua_thread.create(function()
       local runner = request_thread
       while true do
          local status, err = runner:status()
          if not err then
             if status == 'completed' then
                local result, response = runner:get()
                if result then
                   resolve(response)
                else
                   reject(response)
                end
                return
             elseif status == 'canceled' then
                return reject(status)
             end
          else
             return reject(err)
          end
          wait(0)
       end
    end)
end

function urlencode(str)
    str = u8:encode(str)
    if (str) then
       str = string.gsub (str, "\n", "\r\n")
       str = string.gsub (str, "([^%w ])",
          function (c) return string.format ("%%%02X", string.byte(c)) end)
       str = string.gsub (str, " ", "+")
    end
    return str
end

function imgui.TextColoredRGB(text)
    local style = imgui.GetStyle()
    local colors = style.Colors
    local ImVec4 = imgui.ImVec4

    local explode_argb = function(argb)
        local a = bit.band(bit.rshift(argb, 24), 0xFF)
        local r = bit.band(bit.rshift(argb, 16), 0xFF)
        local g = bit.band(bit.rshift(argb, 8), 0xFF)
        local b = bit.band(argb, 0xFF)
        return a, r, g, b
    end

    local getcolor = function(color)
        if color:sub(1, 6):upper() == 'SSSSSS' then
            local r, g, b = colors[1].x, colors[1].y, colors[1].z
            local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
            return ImVec4(r, g, b, a / 255)
        end
        local color = type(color) == 'string' and tonumber(color, 16) or color
        if type(color) ~= 'number' then return end
        local r, g, b, a = explode_argb(color)
        return imgui.ImColor(r, g, b, a):GetVec4()
    end

    local render_text = function(text_)
        for w in text_:gmatch('[^\r\n]+') do
            local text, colors_, m = {}, {}, 1
            w = w:gsub('{(......)}', '{%1FF}')
            while w:find('{........}') do
                local n, k = w:find('{........}')
                local color = getcolor(w:sub(n + 1, k - 1))
                if color then
                    text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
                    colors_[#colors_ + 1] = color
                    m = n
                end
                w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
            end
            if text[0] then
                for i = 0, #text do
                    imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
                    imgui.SameLine(nil, 0)
                end
                imgui.NewLine()
            else imgui.Text(u8(w)) end
        end
    end

    render_text(text)
end

function setColorTheme()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    
    style.WindowPadding = imgui.ImVec2(15, 15)
    style.WindowRounding = 1.5
    style.FramePadding = imgui.ImVec2(5, 5)
    style.FrameRounding = 4.0
    style.ItemSpacing = imgui.ImVec2(12, 8)
    style.ItemInnerSpacing = imgui.ImVec2(8, 6)
    style.IndentSpacing = 25.0
    style.ScrollbarSize = 15.0
    style.ScrollbarRounding = 9.0
    style.GrabMinSize = 5.0
    style.GrabRounding = 3.0
    
    colors[clr.Text] = ImVec4(0.80, 0.80, 0.83, 1.00)
    colors[clr.TextDisabled] = ImVec4(0.24, 0.23, 0.29, 1.00)
    colors[clr.WindowBg] = ImVec4(0.06, 0.05, 0.07, 1.00)
    colors[clr.ChildWindowBg] = ImVec4(0.07, 0.07, 0.09, 1.00)
    colors[clr.PopupBg] = ImVec4(0.07, 0.07, 0.09, 1.00)
    colors[clr.Border] = ImVec4(0.80, 0.80, 0.83, 0.88)
    colors[clr.BorderShadow] = ImVec4(0.92, 0.91, 0.88, 0.00)
    colors[clr.FrameBg] = ImVec4(0.10, 0.09, 0.12, 1.00)
    colors[clr.FrameBgHovered] = ImVec4(0.24, 0.23, 0.29, 1.00)
    colors[clr.FrameBgActive] = ImVec4(0.56, 0.56, 0.58, 1.00)
    colors[clr.TitleBg] = ImVec4(0.10, 0.09, 0.12, 1.00)
    colors[clr.TitleBgCollapsed] = ImVec4(1.00, 0.98, 0.95, 0.75)
    colors[clr.TitleBgActive] = ImVec4(0.07, 0.07, 0.09, 1.00)
    colors[clr.MenuBarBg] = ImVec4(0.10, 0.09, 0.12, 1.00)
    colors[clr.ScrollbarBg] = ImVec4(0.10, 0.09, 0.12, 1.00)
    colors[clr.ScrollbarGrab] = ImVec4(0.80, 0.80, 0.83, 0.31)
    colors[clr.ScrollbarGrabHovered] = ImVec4(0.56, 0.56, 0.58, 1.00)
    colors[clr.ScrollbarGrabActive] = ImVec4(0.06, 0.05, 0.07, 1.00)
    colors[clr.ComboBg] = ImVec4(0.19, 0.18, 0.21, 1.00)
    colors[clr.CheckMark] = ImVec4(0.80, 0.80, 0.83, 0.31)
    colors[clr.SliderGrab] = ImVec4(0.80, 0.80, 0.83, 0.31)
    colors[clr.SliderGrabActive] = ImVec4(0.06, 0.05, 0.07, 1.00)
    colors[clr.Button] = ImVec4(0.10, 0.09, 0.12, 1.00)
    colors[clr.ButtonHovered] = ImVec4(0.24, 0.23, 0.29, 1.00)
    colors[clr.ButtonActive] = ImVec4(0.56, 0.56, 0.58, 1.00)
    colors[clr.Header] = ImVec4(0.10, 0.09, 0.12, 1.00)
    colors[clr.HeaderHovered] = ImVec4(0.56, 0.56, 0.58, 1.00)
    colors[clr.HeaderActive] = ImVec4(0.06, 0.05, 0.07, 1.00)
    colors[clr.ResizeGrip] = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[clr.ResizeGripHovered] = ImVec4(0.56, 0.56, 0.58, 1.00)
    colors[clr.ResizeGripActive] = ImVec4(0.06, 0.05, 0.07, 1.00)
    colors[clr.CloseButton] = ImVec4(0.40, 0.39, 0.38, 0.5)
    colors[clr.CloseButtonHovered] = ImVec4(0.40, 0.39, 0.38, 0.5)
    colors[clr.CloseButtonActive] = ImVec4(0.40, 0.39, 0.38, 0.5)
    colors[clr.PlotLines] = ImVec4(0.40, 0.39, 0.38, 0.63)
    colors[clr.PlotLinesHovered] = ImVec4(0.25, 1.00, 0.00, 1.00)
    colors[clr.PlotHistogram] = ImVec4(0.40, 0.39, 0.38, 0.63)
    colors[clr.PlotHistogramHovered] = ImVec4(0.25, 1.00, 0.00, 1.00)
    colors[clr.TextSelectedBg] = ImVec4(0.25, 1.00, 0.00, 0.43)
    colors[clr.ModalWindowDarkening] = ImVec4(1.00, 0.98, 0.95, 0.73)
end
