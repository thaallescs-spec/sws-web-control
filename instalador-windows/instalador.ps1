# Instalador do SWS Web Control (setlist web para REAPER + SWS Region Playlist)
# Uso: dê dois cliques em "Instalar SWS Web Control.cmd" (ou em Instalar.bat / Desinstalar.bat).
param(
    [switch]$Desinstalar,
    [string]$Reaper = "",     # pasta de recursos do REAPER (opcional; detecta sozinho)
    [string]$Src = ""         # pasta com os arquivos a instalar (o instalador de arquivo único passa uma pasta temporária)
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$NOME   = "SWS Web Control"
$LUA    = "SWS Web Control.lua"
$HTML   = "playlist.html"
$BEGIN  = "-- >>> SWS Web Control (auto) >>>"
$END    = "-- <<< SWS Web Control (auto) <<<"
$PORTA_PADRAO = 8080

if (-not $Src) { $Src = Split-Path -Parent $MyInvocation.MyCommand.Path }
$UTF8   = New-Object Text.UTF8Encoding($false)
$LATIN1 = [Text.Encoding]::GetEncoding(28591)   # lê/grava o reaper.ini byte a byte, sem estragar acentos

function Titulo($t) { Write-Host ""; Write-Host "== $t ==" -ForegroundColor Cyan }
function Ok($t)     { Write-Host "  [OK] $t" -ForegroundColor Green }
function Aviso($t)  { Write-Host "  [!]  $t" -ForegroundColor Yellow }
function Erro($t)   { Write-Host "  [X]  $t" -ForegroundColor Red }
function Fim($cod)  { Write-Host ""; [void](Read-Host "Aperte ENTER para fechar"); exit $cod }

function Remover-Bloco([string]$txt) {
    $re = "(?s)" + [regex]::Escape($BEGIN) + ".*?" + [regex]::Escape($END) + "\r?\n?"
    return [regex]::Replace($txt, $re, "")
}

Write-Host ""
Write-Host "  SWS Web Control - " -NoNewline -ForegroundColor White
if ($Desinstalar) { Write-Host "desinstalação" } else { Write-Host "instalação" }

# ------------------------------------------------------------------
# 1. Pasta do REAPER
# ------------------------------------------------------------------
Titulo "Procurando o REAPER"
if (-not $Reaper) {
    $padrao = Join-Path $env:APPDATA "REAPER"
    if (Test-Path (Join-Path $padrao "reaper.ini")) {
        $Reaper = $padrao
    } else {
        Aviso "Não achei o REAPER em $padrao (instalação portátil?)."
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Escolha a pasta de recursos do REAPER (a que contém o reaper.ini). No REAPER: Options > Show REAPER resource path in explorer."
        if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { Erro "Cancelado."; Fim 1 }
        $Reaper = $dlg.SelectedPath
    }
}
$INI_PATH = Join-Path $Reaper "reaper.ini"
if (-not (Test-Path $INI_PATH)) { Erro "Não existe reaper.ini em: $Reaper"; Fim 1 }
Ok "REAPER: $Reaper"

# ------------------------------------------------------------------
# 2. REAPER precisa estar fechado (ele regrava o reaper.ini ao sair)
# ------------------------------------------------------------------
$reaperExe = $null
$proc = Get-Process -Name "reaper" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($proc) {
    try { $reaperExe = $proc.Path } catch {}
    Aviso "O REAPER está aberto. Salve o seu projeto e feche o REAPER: a instalação continua sozinha."
    while (Get-Process -Name "reaper" -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 700 }
    Start-Sleep -Seconds 1     # tempo para o REAPER terminar de gravar o reaper.ini
    Ok "REAPER fechado"
}

$DEST    = Join-Path $Reaper ("Scripts\" + $NOME)
$WWW     = Join-Path $Reaper "reaper_www_root"
$STARTUP = Join-Path $Reaper "Scripts\__startup.lua"

# ------------------------------------------------------------------
# DESINSTALAR
# ------------------------------------------------------------------
if ($Desinstalar) {
    Titulo "Removendo"
    if (Test-Path $STARTUP) {
        $cur = [IO.File]::ReadAllText($STARTUP, $UTF8)
        $novo = Remover-Bloco $cur
        if ($novo -ne $cur) { [IO.File]::WriteAllText($STARTUP, $novo, $UTF8); Ok "Removido do __startup.lua" }
    }
    $wwwHtml = Join-Path $WWW $HTML
    $nossoHtml = Join-Path $DEST $HTML
    if ((Test-Path $wwwHtml) -and (Test-Path $nossoHtml) -and
        ((Get-FileHash $wwwHtml).Hash -eq (Get-FileHash $nossoHtml).Hash)) {
        Remove-Item $wwwHtml -Force; Ok "Removido $HTML do reaper_www_root"
    }
    if (Test-Path $DEST) { Remove-Item $DEST -Recurse -Force; Ok "Removida a pasta Scripts\$NOME" }
    Aviso "A interface web (Preferences > Control/OSC/web) foi mantida. Remova por lá se quiser."
    Aviso "A ação 'SWS Web Control.lua' pode continuar na lista de ações; é só removê-la por lá."
    Fim 0
}

# ------------------------------------------------------------------
# 3. SWS instalado?
# ------------------------------------------------------------------
Titulo "Verificando a extensão SWS"
$swsDirs = @((Join-Path $Reaper "UserPlugins"), "$env:ProgramFiles\REAPER (x64)\Plugins", "$env:ProgramFiles\REAPER\Plugins")
$sws = $swsDirs | Where-Object { Test-Path $_ } | ForEach-Object { Get-ChildItem $_ -Filter "reaper_sws*.dll" -ErrorAction SilentlyContinue }
if ($sws) { Ok "SWS encontrado" } else { Aviso "SWS não encontrado. Instale em https://www.sws-extension.org (sem ele a setlist não funciona)." }

# ------------------------------------------------------------------
# 4. Copiar arquivos
# ------------------------------------------------------------------
Titulo "Copiando arquivos"
foreach ($f in @($LUA, $HTML)) {
    if (-not (Test-Path (Join-Path $SRC $f))) { Erro "Arquivo faltando no pacote: $f"; Fim 1 }
}
New-Item -ItemType Directory -Force -Path $DEST | Out-Null
Get-ChildItem $SRC -File | Where-Object { $_.Name -ne "instalador.ps1" } | ForEach-Object {
    Copy-Item $_.FullName $DEST -Force
}
Ok "Scripts\$NOME (script, página, QR code)"

New-Item -ItemType Directory -Force -Path $WWW | Out-Null
$wwwHtml = Join-Path $WWW $HTML
if ((Test-Path $wwwHtml) -and ((Get-FileHash $wwwHtml).Hash -ne (Get-FileHash (Join-Path $SRC $HTML)).Hash)) {
    $bak = $wwwHtml + ".antigo-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    Copy-Item $wwwHtml $bak
    Aviso "Já existia um $HTML no reaper_www_root; cópia de segurança: $(Split-Path -Leaf $bak)"
}
Copy-Item (Join-Path $SRC $HTML) $WWW -Force
Ok "reaper_www_root\$HTML"

# ------------------------------------------------------------------
# 5. Iniciar junto com o REAPER (__startup.lua)
# ------------------------------------------------------------------
Titulo "Configurando início automático"
$luaPath = (Join-Path $DEST $LUA).Replace('\', '\\').Replace('"', '\"')
$bloco = "$BEGIN`n" +
         "do local f = `"$luaPath`"`n" +
         "  if reaper.file_exists(f) then SWS_WEB_CONTROL_STARTUP = true; dofile(f) end`n" +
         "end`n" +
         "$END`n"
$cur = ""
if (Test-Path $STARTUP) { $cur = [IO.File]::ReadAllText($STARTUP, $UTF8) }
$cur = Remover-Bloco $cur
if ($cur.Length -gt 0 -and -not $cur.EndsWith("`n")) { $cur += "`n" }
[IO.File]::WriteAllText($STARTUP, $cur + $bloco, $UTF8)
Ok "Scripts\__startup.lua"

# ------------------------------------------------------------------
# 6. Interface web do REAPER (reaper.ini)
# ------------------------------------------------------------------
Titulo "Configurando a interface web do REAPER"
$ini = [IO.File]::ReadAllText($INI_PATH, $LATIN1)
$nl = if ($ini.Contains("`r`n")) { "`r`n" } else { "`n" }
$http = [regex]::Matches($ini, "(?m)^csurf_(\d+)=HTTP\s+\S+\s+(\d+)\s+(.*)$")
$porta = $null

foreach ($m in $http) {
    if ($m.Groups[3].Value -match [regex]::Escape($HTML)) { $porta = $m.Groups[2].Value }
}
if ($porta) {
    Ok "Já configurada (porta $porta)"
} elseif ($http.Count -gt 0) {
    $porta = $http[0].Groups[2].Value
    Aviso "Já existe uma interface web na porta $porta com outra página inicial; não mexi nela."
    Aviso "A setlist abre no endereço com /$HTML no final (veja abaixo)."
} else {
    # escolhe uma porta livre a partir da 8080
    $porta = $PORTA_PADRAO
    $ocupadas = @()
    try { $ocupadas = @(Get-NetTCPConnection -State Listen -ErrorAction Stop | ForEach-Object { $_.LocalPort }) } catch {}
    while ($ocupadas -contains $porta) { $porta++ }

    Copy-Item $INI_PATH ($INI_PATH + ".antes-sws-web-control-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    $linha = "HTTP 0 $porta '' '$HTML' 0 ''"
    $mc = [regex]::Match($ini, "(?m)^csurf_cnt=(\d+)(?=\r?$)")
    if ($mc.Success) {
        $n = [int]$mc.Groups[1].Value
        $novo = "csurf_cnt=$($n + 1)$nl" + "csurf_$n=$linha"
        $ini = $ini.Substring(0, $mc.Index) + $novo + $ini.Substring($mc.Index + $mc.Length)
    } else {
        $mr = [regex]::Match($ini, "(?m)^\[reaper\](?=\r?$)")
        if (-not $mr.Success) { Erro "Não achei a seção [reaper] no reaper.ini"; Fim 1 }
        $pos = $mr.Index + $mr.Length
        $ini = $ini.Substring(0, $pos) + "$nl" + "csurf_cnt=1$nl" + "csurf_0=$linha" + $ini.Substring($pos)
    }
    [IO.File]::WriteAllText($INI_PATH, $ini, $LATIN1)
    Ok "Interface web criada na porta $porta (cópia de segurança do reaper.ini feita)"
}

# ------------------------------------------------------------------
# 7. Pronto
# ------------------------------------------------------------------
Titulo "Pronto!"
Write-Host "  1. Abra o REAPER e o projeto do show (com a Region Playlist do SWS) e salve."
Write-Host "  2. No celular/tablet, na mesma rede, abra:"
$ips = @()
try {
    $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
        Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
        ForEach-Object { $_.IPAddress })
} catch {}
if ($ips.Count -eq 0) { $ips = @("IP-DESTE-PC") }
foreach ($ip in $ips) { Write-Host "       http://${ip}:$porta/$HTML" -ForegroundColor Green }
Write-Host "     (neste computador: http://localhost:$porta/$HTML)"
Write-Host "  3. Para abrir no celular sem digitar: no REAPER, rode a ação 'SWS Web Control - QR code'."
Write-Host ""
Write-Host "  Se o Windows perguntar sobre o firewall ao abrir o REAPER, permita em 'Redes privadas'."

# abre o REAPER de novo: o SWS Web Control já inicia junto
$candidatos = @($reaperExe, (Join-Path $Reaper "reaper.exe"),
    "$env:ProgramFiles\REAPER (x64)\reaper.exe", "$env:ProgramFiles\REAPER\reaper.exe",
    "${env:ProgramFiles(x86)}\REAPER\reaper.exe") | Where-Object { $_ -and (Test-Path $_) }
if ($candidatos) {
    Start-Process -FilePath @($candidatos)[0]
    Write-Host ""
    Ok "Abrindo o REAPER..."
}
Fim 0
