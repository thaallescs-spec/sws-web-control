-- @description SWS Web Control - mostrar QR code para abrir a setlist no celular
-- @author Thalles
-- @noindex (incluído pelo pacote "SWS Web Control.lua")
-- Abre uma janela com o QR code do endereço da setlist (http://IP:porta/playlist.html).
-- Aponte a câmera do celular/tablet (na mesma rede Wi-Fi) e abra o link.
-- Clique na janela para alternar entre IPs (se o computador tiver mais de uma rede). Esc fecha.

local SEP        = package.config:sub(1, 1)
local SCRIPT_DIR = (debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)[/\\]") or "."
local PAGE       = "playlist.html"

local qr = dofile(SCRIPT_DIR .. SEP .. "qrencode.lua")

-------------------------------------------------
-- Porta da interface web (reaper.ini)
-------------------------------------------------
local function webPort()
    local f = io.open(reaper.get_ini_file(), "rb")
    if not f then return nil end
    local ini = f:read("*a")
    f:close()
    local first
    for line in ini:gmatch("[^\r\n]+") do
        local port = line:match("^csurf_%d+=HTTP%s+%-?%d+%s+(%d+)")
        if port then
            if line:find(PAGE, 1, true) then return port end
            first = first or port
        end
    end
    return first
end

-------------------------------------------------
-- IPs da rede local
-------------------------------------------------
-- prioridade: Wi-Fi/rede de casa (192.168.x) > 10.x > 172.16-31.x > resto
local function rank(ip)
    local a, b = ip:match("^(%d+)%.(%d+)")
    a, b = tonumber(a), tonumber(b)
    if a == 192 and b == 168 then return 1 end
    if a == 10 then return 2 end
    if a == 172 and b >= 16 and b <= 31 then return 3 end
    return 4
end

-- adaptadores virtuais (WSL, Hyper-V, VirtualBox, VMware, Docker) ficam por último
local VIRTUAL = { "vethernet", "wsl", "hyper%-v", "virtualbox", "vmware", "docker", "loopback", "bridge", "utun", "awdl", "llw" }
local function isVirtual(name)
    name = (name or ""):lower()
    for _, v in ipairs(VIRTUAL) do
        if name:find(v) then return true end
    end
    return false
end

local function localIPs()
    local win = (SEP == "\\")
    local out = reaper.ExecProcess(win and "ipconfig" or "/sbin/ifconfig", 5000) or ""
    local list, seen, adapter = {}, {}, ""
    for line in out:gmatch("[^\r\n]+") do
        -- cabeçalho de adaptador: linha sem recuo (Windows "Adaptador ... :" / Mac "en0: flags=...")
        if not line:match("^%s") and line:match("%S") then
            adapter = win and line or (line:match("^([%w]+):") or line)
        end
        local ip
        if win then
            if line:find("IPv4", 1, true) then ip = line:match("(%d+%.%d+%.%d+%.%d+)") end
        else
            ip = line:match("^%s*inet%s+(%d+%.%d+%.%d+%.%d+)")
        end
        if ip and not seen[ip] and not ip:match("^127%.") and not ip:match("^169%.254%.") then
            seen[ip] = true
            list[#list + 1] = { ip = ip, score = rank(ip) + (isVirtual(adapter) and 10 or 0) }
        end
    end
    table.sort(list, function(x, y)
        if x.score ~= y.score then return x.score < y.score end
        return x.ip < y.ip
    end)
    local ips = {}
    for i, e in ipairs(list) do ips[i] = e.ip end
    return ips
end

-------------------------------------------------
-- Janela
-------------------------------------------------
local port = webPort()
local ips  = localIPs()
local idx  = 1
local matrix, url

local function build()
    if not port or #ips == 0 then matrix = nil; return end
    url = string.format("http://%s:%s/%s", ips[idx], port, PAGE)
    local ok, tab = qr.qrcode(url)
    matrix = ok and tab or nil
end
build()

local W, H = 440, 560
gfx.init("SWS Web Control - abrir no celular", W, H)
gfx.setfont(1, "Arial", 18)
gfx.setfont(2, "Arial", 15)

local function centerText(txt, y, font)
    gfx.setfont(font)
    local tw = gfx.measurestr(txt)
    gfx.x, gfx.y = math.max(8, (gfx.w - tw) / 2), y
    gfx.drawstr(txt)
end

local lastClick = 0

local function draw()
    local c = gfx.getchar()
    if c < 0 or c == 27 then gfx.quit(); return end

    -- clique alterna o IP
    if gfx.mouse_cap & 1 == 1 and lastClick == 0 and #ips > 1 then
        idx = idx % #ips + 1
        build()
    end
    lastClick = gfx.mouse_cap & 1

    gfx.set(0.08, 0.09, 0.1, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, 1)

    if not port then
        gfx.set(1, 0.8, 0.2, 1)
        centerText("Interface web do REAPER não configurada.", 40, 1)
        gfx.set(1, 1, 1, 1)
        centerText("Preferences > Control/OSC/web > Add >", 80, 2)
        centerText("Web browser interface > " .. PAGE, 104, 2)
    elseif not matrix then
        gfx.set(1, 0.8, 0.2, 1)
        centerText("Não encontrei o IP da rede local.", 40, 1)
        gfx.set(1, 1, 1, 1)
        centerText("Veja o endereço em Preferences > Control/OSC/web.", 80, 2)
    else
        local n = #matrix
        local quiet = 4
        local size = math.min(gfx.w - 40, gfx.h - 140)
        local cell = math.max(1, math.floor(size / (n + quiet * 2)))
        local total = cell * (n + quiet * 2)
        local ox = math.floor((gfx.w - total) / 2)
        local oy = 20
        gfx.set(1, 1, 1, 1)
        gfx.rect(ox, oy, total, total, 1)
        gfx.set(0, 0, 0, 1)
        for x = 1, n do
            for y = 1, n do
                if matrix[x][y] > 0 then
                    gfx.rect(ox + (x - 1 + quiet) * cell, oy + (y - 1 + quiet) * cell, cell, cell, 1)
                end
            end
        end
        gfx.set(1, 1, 1, 1)
        centerText(url, oy + total + 16, 1)
        gfx.set(0.6, 0.62, 0.65, 1)
        centerText("Celular na mesma rede Wi-Fi deste computador.", oy + total + 46, 2)
        if #ips > 1 then
            centerText(string.format("Rede %d de %d - clique para trocar", idx, #ips), oy + total + 68, 2)
        end
    end

    gfx.update()
    reaper.defer(draw)
end

draw()
