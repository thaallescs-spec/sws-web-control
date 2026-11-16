-- @description SWS Web Control - setlist web (celular/tablet) para a Region Playlist do SWS
-- @author Thalles
-- @version 2.3.0
-- @provides
--   playlist.html
--   qrencode.lua
--   qrencode-LICENSE.md
--   [main] SWS Web Control - QR code.lua
-- @about
--   Mostra e controla a Region Playlist do SWS pelo navegador do celular ou tablet:
--   música atual, tempo restante, iniciar, parar, próxima/anterior e tocar a partir
--   de qualquer música (inclusive músicas repetidas na setlist).
--
--   PRIMEIRA VEZ (Windows ou Mac):
--     1. Rode esta ação uma vez (Actions > "SWS Web Control.lua" > Run). Ela copia
--        o playlist.html para o reaper_www_root e passa a abrir junto com o REAPER.
--     2. Preferences > Control/OSC/web > Add > "Web browser interface",
--        Default interface: playlist.html.
--     3. Rode "SWS Web Control - QR code.lua" e aponte a câmera do celular.

local SECTION   = "SWSWebControl"
local HTML_FILE = "playlist.html"
local BEGIN_TAG = "-- >>> SWS Web Control (auto) >>>"
local END_TAG   = "-- <<< SWS Web Control (auto) <<<"
local SKIP_IMMEDIATE = true  -- true: "Próxima/Anterior" pulam na hora; false: no fim da música (smooth seek do SWS)
local CHECK_INTERVAL = 0.2   -- segundos entre verificações
local BEAT_INTERVAL  = 0.5   -- segundos entre sinais de "vivo"

local SEP          = package.config:sub(1, 1)
local RES          = reaper.GetResourcePath()
local SCRIPT_PATH  = (debug.getinfo(1, "S").source:gsub("^@", ""))
local SCRIPT_DIR   = SCRIPT_PATH:match("^(.*)[/\\]") or "."
local FROM_STARTUP = (SWS_WEB_CONTROL_STARTUP == true)
SWS_WEB_CONTROL_STARTUP = nil

local SWS = {}   -- IDs dos comandos do SWS (preenchido em loadSwsCommands)

-------------------------------------------------
-- ARQUIVOS
-------------------------------------------------

local function readFile(p)
    local f = io.open(p, "rb")
    if not f then return nil end
    local d = f:read("*a")
    f:close()
    return d
end

local function writeFile(p, d)
    local f = io.open(p, "wb")
    if not f then return false end
    f:write(d)
    f:close()
    return true
end

-------------------------------------------------
-- INSTALAÇÃO (idempotente: roda sempre, só muda o que faltar)
-------------------------------------------------

local function installHtml(msgs)
    local html = readFile(SCRIPT_DIR .. SEP .. HTML_FILE)
    if not html then
        msgs[#msgs + 1] = "AVISO: " .. HTML_FILE .. " não foi encontrado ao lado do script."
        return
    end
    local www = RES .. SEP .. "reaper_www_root"
    reaper.RecursiveCreateDirectory(www, 0)
    local dest = www .. SEP .. HTML_FILE
    if readFile(dest) ~= html then
        if writeFile(dest, html) then
            msgs[#msgs + 1] = "• " .. HTML_FILE .. " copiado para reaper_www_root"
        else
            msgs[#msgs + 1] = "ERRO: não consegui gravar " .. dest
        end
    end
end

local function installStartup(msgs)
    local startup = RES .. SEP .. "Scripts" .. SEP .. "__startup.lua"
    local cur = readFile(startup) or ""
    local block = BEGIN_TAG .. "\n"
        .. string.format("do local f = %q\n", SCRIPT_PATH)
        .. "  if reaper.file_exists(f) then SWS_WEB_CONTROL_STARTUP = true; dofile(f) end\n"
        .. "end\n"
        .. END_TAG .. "\n"

    local new
    local b = cur:find(BEGIN_TAG, 1, true)
    if b then
        local _, e = cur:find(END_TAG, b, true)
        if e then
            local tail = (cur:sub(e + 1):gsub("^\r?\n", ""))
            new = cur:sub(1, b - 1) .. block .. tail
        end
    else
        local glue = (cur ~= "" and not cur:match("\n$")) and "\n" or ""
        new = cur .. glue .. block
    end

    if new and new ~= cur then
        if writeFile(startup, new) then
            msgs[#msgs + 1] = "• Inicia automaticamente com o REAPER (__startup.lua)"
        else
            msgs[#msgs + 1] = "ERRO: não consegui gravar " .. startup
        end
    end
end

local function webInterfaceHint()
    local ini = readFile(reaper.get_ini_file()) or ""
    for line in ini:gmatch("[^\r\n]+") do
        if line:match("^csurf_%d+=HTTP") and line:find(HTML_FILE, 1, true) then
            local port = line:match("^csurf_%d+=HTTP%s+%-?%d+%s+(%d+)")
            return (port and ("A interface web já está configurada (porta " .. port .. ").")
                          or "A interface web já está configurada.")
                .. "\nPara abrir no celular, rode a ação \"SWS Web Control - QR code\"."
        end
    end
    return "Falta 1 passo: Options > Preferences > Control/OSC/web > Add >\n"
        .. "\"Web browser interface\", em \"Default interface\" escolha "
        .. HTML_FILE .. ".\n\nDepois rode a ação \"SWS Web Control - QR code\" e aponte a câmera do celular.\n"
        .. "(No Mac, se aparecer o aviso de conexões de rede para o REAPER, clique em Permitir.)"
end

-------------------------------------------------
-- LEITURA DA PLAYLIST DO SWS (do .rpp salvo)
-------------------------------------------------

local function parsePlaylists(content)
    local lists, cur = {}, nil
    for line in content:gmatch("[^\r\n]+") do
        if cur then
            if line:match("^%s*>%s*$") then
                lists[#lists + 1] = cur
                cur = nil
            else
                local id, loops = line:match("^%s*(%d+)%s*(%-?%d*)")
                if id then
                    id = tonumber(id)
                    if id >= 0x40000000 then id = id - 0x40000000 end
                    cur.entries[#cur.entries + 1] = { region = id, loops = tonumber(loops) or 1 }
                end
            end
        else
            local rest = line:match("^%s*<S&M_RGN_PLAYLIST%s*(.-)%s*$")
            if rest then
                -- formato do SWS: <S&M_RGN_PLAYLIST nome [1 = playlist ativa]
                -- nome com espaço vem entre " ' ou `
                local name, flag
                local q = rest:sub(1, 1)
                if q == '"' or q == "'" or q == "`" then
                    local close = rest:find(q, 2, true)
                    name = close and rest:sub(2, close - 1) or rest:sub(2)
                    flag = close and rest:sub(close + 1):match("(%d+)") or nil
                else
                    name, flag = rest:match("^(%S+)%s*(%d*)")
                end
                name = name or ""
                cur = { name = name, active = (flag == "1"), entries = {} }
            end
        end
    end
    return lists
end

local cache = {}

local function loadFromFile(path)
    cache = { readAt = os.date("%H:%M:%S") }
    if path == "" then
        cache.err = "Projeto ainda não foi salvo. Salve (Ctrl+S) para carregar a setlist."
        return
    end
    local content = readFile(path)
    if not content then
        cache.err = "Não foi possível ler o arquivo do projeto."
        return
    end
    local lists = parsePlaylists(content)
    if #lists == 0 then
        cache.err = "Nenhuma Region Playlist do SWS no projeto salvo."
        return
    end
    local chosen
    for _, l in ipairs(lists) do
        if l.active then chosen = l; break end
    end
    cache.list  = chosen or lists[1]
    cache.count = #lists
end

-------------------------------------------------
-- REGIÕES (lidas ao vivo do projeto aberto)
-------------------------------------------------

local function hexColor(c)
    if not c or c == 0 then return nil end
    local r, g, b = reaper.ColorFromNative(c & 0xFFFFFF)
    return string.format("#%02x%02x%02x", r, g, b)
end

local function getRegions(proj)
    local t = {}
    local total = reaper.CountProjectMarkers(proj)
    for i = 0, total - 1 do
        local _, isRgn, pos, rgnEnd, name, idx, color = reaper.EnumProjectMarkers3(proj, i)
        if isRgn then
            t[idx] = { name = name, start = pos, finish = rgnEnd, color = hexColor(color) }
        end
    end
    return t
end

-------------------------------------------------
-- JSON
-- Textos vão em "percent-encoding" (decodeURIComponent no navegador):
-- assim o JSON nunca tem barra invertida, tab ou quebra de linha, e passa
-- intacto pelo ExtState e pela interface web do REAPER.
-------------------------------------------------

local function enc(s)
    return (tostring(s):gsub('[%%"\\%c]', function(c)
        return string.format("%%%02X", c:byte())
    end))
end

local function num(n) return string.format("%.3f", n) end

local function buildJSON(proj, path)
    local projName = (path ~= "" and (path:match("([^/\\]+)$") or path)) or "(sem título)"
    local head = string.format('"project":"%s","dirty":%s,"readAt":"%s","sws":%s',
        enc(projName),
        reaper.IsProjectDirty(proj) ~= 0 and "true" or "false",
        cache.readAt or "",
        SWS.ok and "true" or "false")

    -- todas as regiões do projeto (aba "Regiões" da página), em ordem de posição
    local regions = getRegions(proj)
    local list = {}
    for idx, r in pairs(regions) do list[#list + 1] = { idx = idx, r = r } end
    table.sort(list, function(a, b) return a.r.start < b.r.start end)
    local rj = {}
    for _, e in ipairs(list) do
        rj[#rj + 1] = string.format('{"id":%d,"name":"%s","start":%s,"end":%s,"color":%s}',
            e.idx, enc(e.r.name), num(e.r.start), num(e.r.finish),
            e.r.color and ('"' .. e.r.color .. '"') or "null")
    end
    head = head .. ',"regions":[' .. table.concat(rj, ",") .. ']'

    if cache.err then
        return string.format('{"ok":false,%s,"error":"%s"}', head, enc(cache.err))
    end

    local items, missing, total = {}, {}, 0

    -- Mesma regra do SWS para item válido: região existe e repetição ~= 0.
    -- A ordem (e as músicas repetidas) é preservada: o índice aqui é o mesmo
    -- índice que o SWS percorre com "próxima", usado no "tocar a partir de".
    for _, e in ipairs(cache.list.entries) do
        local r = regions[e.region]
        if r and e.loops ~= 0 then
            local infinite = e.loops < 0
            local n = math.abs(e.loops)
            local dur = (r.finish - r.start) * n
            total = total + dur
            items[#items + 1] = string.format(
                '{"region":%d,"name":"%s","start":%s,"end":%s,"loops":%d,"infinite":%s,"duration":%s,"color":%s}',
                e.region, enc(r.name), num(r.start), num(r.finish), n,
                infinite and "true" or "false", num(dur),
                r.color and ('"' .. r.color .. '"') or "null")
        elseif not r then
            missing[#missing + 1] = tostring(e.region)
        end
    end

    return string.format(
        '{"ok":true,%s,"playlist":"%s","playlists":%d,"items":[%s],"missing":[%s],"total":%s}',
        head, enc(cache.list.name), cache.count,
        table.concat(items, ","), table.concat(missing, ","), num(total))
end

-------------------------------------------------
-- COMANDOS DO SWS
-- O SWS não tem "tocar item N". Truque: ligar o seek imediato do Region
-- Playlist, dar Play (começa no 1º item) e chamar "Play next region" N vezes
-- na mesma chamada. Cada "next" anda um ITEM da playlist (não uma região),
-- então músicas repetidas funcionam. Depois o modo de seek volta ao que era.
-------------------------------------------------

local function cmd(name)
    local id = reaper.NamedCommandLookup(name)
    return (id and id ~= 0) and id or nil
end

local function loadSwsCommands()
    SWS.play       = cmd("_S&M_PLAY_RGN_PLAYLIST")
    SWS.next       = cmd("_S&M_PLAY_NEXT_RGN_PLAYLIST")
    SWS.prev       = cmd("_S&M_PLAY_PREV_RGN_PLAYLIST")
    SWS.nextCur    = cmd("_S&M_PLAY_NEXT_CUR_BASED_RGN_PLAYLIST")   -- SWS mais recente
    SWS.prevCur    = cmd("_S&M_PLAY_PREV_CUR_BASED_RGN_PLAYLIST")
    SWS.tglSeek    = cmd("_S&M_PLAYLIST_OPT_TGL_SMOOTHSEEK")       -- estado 1 = seek imediato
    SWS.seekNow    = cmd("_S&M_PLAYLIST_OPT_SMOOTHSEEK_OFF")
    SWS.seekSmooth = cmd("_S&M_PLAYLIST_OPT_SMOOTHSEEK_ON")
    SWS.ok = (SWS.play and SWS.next and SWS.prev) and true or false
    SWS.canImmediate = (SWS.tglSeek and SWS.seekNow and SWS.seekSmooth) and true or false
end

local function withImmediateSeek(fn)
    local restore = false
    if SWS.canImmediate and reaper.GetToggleCommandState(SWS.tglSeek) ~= 1 then
        reaper.Main_OnCommand(SWS.seekNow, 0)
        restore = true
    end
    reaper.PreventUIRefresh(1)
    local ok, err = pcall(fn)
    reaper.PreventUIRefresh(-1)
    if restore then reaper.Main_OnCommand(SWS.seekSmooth, 0) end
    if not ok then reaper.ShowConsoleMsg("SWS Web Control: " .. tostring(err) .. "\n") end
end

local jumpSeq = 0
local function announceJump(index)
    jumpSeq = jumpSeq + 1
    reaper.SetExtState(SECTION, "jump", jumpSeq .. ":" .. index, false)
end

local function playFrom(index)            -- index começa em 0
    if not SWS.ok then return end
    withImmediateSeek(function()
        reaper.Main_OnCommand(SWS.play, 0)
        for _ = 1, index do reaper.Main_OnCommand(SWS.next, 0) end
    end)
    announceJump(index)
end

-------------------------------------------------
-- REGIÃO AVULSA (fora da playlist): para o que estiver tocando, toca a região
-- do começo e para sozinho no fim dela. Útil para testar o som antes do show.
-------------------------------------------------

local isolated          -- { id, start, finish } enquanto uma região avulsa toca
local STOP_EARLY = 0.04 -- para um pouco antes do fim (o loop roda ~30x/s)

local function clearIsolated()
    if isolated then
        isolated = nil
        reaper.DeleteExtState(SECTION, "isolated", false)
    end
end

local function playRegion(id)
    local r = getRegions(0)[id]
    if not r then return end
    reaper.Main_OnCommand(1016, 0)                     -- Stop (encerra também a playlist do SWS)
    reaper.SetEditCurPos(r.start, false, false)
    reaper.Main_OnCommand(1007, 0)                     -- Play a partir do cursor
    isolated = { id = id, start = r.start, finish = r.finish }
    reaper.SetExtState(SECTION, "isolated", tostring(id), false)
end

local function watchIsolated()
    if not isolated then return end
    if (reaper.GetPlayState() & 1) ~= 1 then clearIsolated(); return end
    local pos = reaper.GetPlayPosition()
    if pos >= isolated.finish - STOP_EARLY then
        reaper.Main_OnCommand(1016, 0)
        clearIsolated()
    elseif pos < isolated.start - 0.5 or pos > isolated.finish + 0.5 then
        clearIsolated()                                -- alguém mudou a posição: não interfere mais
    end
end

local function skip(dir)
    if not SWS.ok then return end
    if (reaper.GetPlayState() & 1) ~= 1 then return end   -- parado: não começa o show sem querer
    if isolated then return end                           -- região avulsa: próxima/anterior não valem
    local id
    if dir > 0 then id = SWS.nextCur or SWS.next else id = SWS.prevCur or SWS.prev end
    if SKIP_IMMEDIATE then
        withImmediateSeek(function() reaper.Main_OnCommand(id, 0) end)
    else
        reaper.Main_OnCommand(id, 0)
    end
end

-------------------------------------------------
-- INÍCIO
-------------------------------------------------

loadSwsCommands()

local msgs = {}
if not SWS.ok then
    msgs[#msgs + 1] = "AVISO: extensão SWS não encontrada. Instale em sws-extension.org"
end
installHtml(msgs)
installStartup(msgs)

-- Quando instalado pelo instalador do Windows, o script nunca passou pelo
-- "Load ReaScript": registra uma vez na lista de ações para dar pra achar lá.
-- Vale para este script e para a ação do QR code que vem junto.
if FROM_STARTUP and reaper.AddRemoveReaScript then
    local acoes = {
        registered    = SCRIPT_PATH,
        registered_qr = SCRIPT_DIR .. SEP .. "SWS Web Control - QR code.lua",
    }
    for chave, caminho in pairs(acoes) do
        if reaper.file_exists(caminho) and reaper.GetExtState(SECTION, chave) ~= caminho then
            if reaper.AddRemoveReaScript(true, 0, caminho, true) ~= 0 then
                reaper.SetExtState(SECTION, chave, caminho, true)
            end
        end
    end
end

-- Já existe uma cópia rodando? Então só pede uma atualização e sai.
local aliveT = tonumber(reaper.GetExtState(SECTION, "alive_t"))
if aliveT and (reaper.time_precise() - aliveT) < 2 then
    reaper.SetExtState(SECTION, "cmd", "refresh", false)
    if not FROM_STARTUP then
        local txt = (#msgs > 0 and (table.concat(msgs, "\n") .. "\n\n") or "")
            .. "O serviço já está rodando. Setlist atualizada."
        reaper.ShowMessageBox(txt, "SWS Web Control", 0)
    end
    return
end

if not FROM_STARTUP and #msgs > 0 then
    reaper.ShowMessageBox(
        "Instalado!\n\n" .. table.concat(msgs, "\n") .. "\n\n" .. webInterfaceHint(),
        "SWS Web Control", 0)
end

-------------------------------------------------
-- LOOP EM SEGUNDO PLANO
-------------------------------------------------

local lastKey, lastDirty, lastState, lastJSON
local lastCheck, lastBeat, beat = 0, 0, 0

-- Atualização sem reiniciar o REAPER: se este arquivo mudar no disco (ReaPack,
-- instalador), o serviço carrega a versão nova e encerra a antiga.
local selfSource = readFile(SCRIPT_PATH)
local lastSelfCheck = 0
local function reloadIfUpdated(now)
    if now - lastSelfCheck < 3 then return false end
    lastSelfCheck = now
    local src = readFile(SCRIPT_PATH)
    if not src or src == selfSource then return false end
    selfSource = src
    reaper.DeleteExtState(SECTION, "alive_t", false)   -- deixa a versão nova assumir
    SWS_WEB_CONTROL_STARTUP = true                      -- sem janelas de mensagem
    local ok, err = pcall(dofile, SCRIPT_PATH)
    if ok then return true end                          -- a nova já está rodando
    reaper.ShowConsoleMsg("SWS Web Control: falha ao carregar a versão nova: " .. tostring(err) .. "\n")
    return false                                        -- continua com a versão atual
end

local function publish(proj, path)
    local json = buildJSON(proj, path)
    if json ~= lastJSON then
        reaper.SetExtState(SECTION, "playlist", json, false)
        lastJSON = json
    end
end

local function loop()
    local now = reaper.time_precise()

    if now - lastBeat >= BEAT_INTERVAL then
        lastBeat = now
        beat = beat + 1
        reaper.SetExtState(SECTION, "alive_t", tostring(now), false)
        reaper.SetExtState(SECTION, "beat", tostring(beat), false)
    end

    -- comandos vindos da página: lidos a cada ciclo para responder rápido
    local c = reaper.GetExtState(SECTION, "cmd")
    local wantRefresh = false
    if c ~= "" then
        reaper.DeleteExtState(SECTION, "cmd", false)
        local from = c:match("^playfrom:(%d+)$")
        local rgn  = c:match("^playregion:(%d+)$")
        if from then clearIsolated(); playFrom(tonumber(from))
        elseif rgn then playRegion(tonumber(rgn))
        elseif c == "playlist" then clearIsolated(); if SWS.ok then reaper.Main_OnCommand(SWS.play, 0) end
        elseif c == "next" then skip(1)
        elseif c == "prev" then skip(-1)
        elseif c == "refresh" then wantRefresh = true; lastCheck = 0
        end
    end

    watchIsolated()

    if now - lastCheck >= CHECK_INTERVAL then
        lastCheck = now

        local proj, path = reaper.EnumProjects(-1)
        path = path or ""
        local key   = tostring(proj) .. "|" .. path
        local dirty = reaper.IsProjectDirty(proj)
        local state = reaper.GetProjectStateChangeCount(proj)

        -- Relê o .rpp quando: trocou de projeto/aba, acabou de salvar, ou a web pediu.
        local reread = (key ~= lastKey) or wantRefresh
            or (lastDirty == 1 and dirty == 0)

        if reread then loadFromFile(path) end

        -- Regiões (nome, posição, cor) são lidas ao vivo a cada mudança no projeto.
        if reread or state ~= lastState or dirty ~= lastDirty then
            publish(proj, path)
        end

        lastKey, lastDirty, lastState = key, dirty, state
    end

    if reloadIfUpdated(now) then return end
    reaper.defer(loop)
end

reaper.atexit(function()
    reaper.DeleteExtState(SECTION, "alive_t", false)
    reaper.DeleteExtState(SECTION, "beat", false)
    reaper.SetExtState(SECTION, "playlist",
        '{"ok":false,"error":"Servi%C3%A7o parado no REAPER."}', false)
end)

loop()
