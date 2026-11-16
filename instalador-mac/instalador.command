#!/bin/bash
# Instalador do SWS Web Control para macOS (setlist web para REAPER + SWS Region Playlist).
# Dois cliques neste arquivo. Para desinstalar: ./"Instalar SWS Web Control.command" --desinstalar
# Os arquivos do script vão embutidos no fim deste arquivo (depois de __PAYLOAD__).

set -u
NOME="SWS Web Control"
LUA="SWS Web Control.lua"
HTML="playlist.html"
BEGIN_TAG="-- >>> SWS Web Control (auto) >>>"
END_TAG="-- <<< SWS Web Control (auto) <<<"
PORTA_PADRAO=8080

azul()    { printf '\n\033[36m== %s ==\033[0m\n' "$1"; }
ok()      { printf '  \033[32m[OK]\033[0m %s\n' "$1"; }
aviso()   { printf '  \033[33m[!]\033[0m  %s\n' "$1"; }
erro()    { printf '  \033[31m[X]\033[0m  %s\n' "$1"; }
fim()     { echo; read -r -p "Aperte ENTER para fechar " _; exit "$1"; }

DESINSTALAR=0
[ "${1:-}" = "--desinstalar" ] && DESINSTALAR=1

echo
if [ $DESINSTALAR = 1 ]; then echo "  SWS Web Control - desinstalação"; else echo "  SWS Web Control - instalação"; fi

# ------------------------------------------------------------------
# 1. Pasta do REAPER
# ------------------------------------------------------------------
azul "Procurando o REAPER"
RES="${REAPER_RESOURCE:-$HOME/Library/Application Support/REAPER}"
if [ ! -f "$RES/reaper.ini" ]; then
    aviso "Não achei o REAPER em $RES (instalação portátil?)."
    RES=$(osascript -e 'POSIX path of (choose folder with prompt "Escolha a pasta de recursos do REAPER (a que contém o reaper.ini)")' 2>/dev/null) || { erro "Cancelado."; fim 1; }
    RES="${RES%/}"
fi
INI="$RES/reaper.ini"
[ -f "$INI" ] || { erro "Não existe reaper.ini em: $RES"; fim 1; }
ok "REAPER: $RES"

# ------------------------------------------------------------------
# 2. REAPER precisa estar fechado (ele regrava o reaper.ini ao sair)
# ------------------------------------------------------------------
reaper_aberto() { pgrep -x REAPER >/dev/null 2>&1 || pgrep -x REAPER64 >/dev/null 2>&1; }
if reaper_aberto; then
    aviso "O REAPER está aberto. Salve o seu projeto e feche o REAPER: a instalação continua sozinha."
    while reaper_aberto; do sleep 0.7; done
    sleep 1
    ok "REAPER fechado"
fi

DEST="$RES/Scripts/$NOME"
WWW="$RES/reaper_www_root"
STARTUP="$RES/Scripts/__startup.lua"

remover_bloco() {   # remove o bloco do SWS Web Control do __startup.lua
    [ -f "$STARTUP" ] || return 0
    awk -v b="$BEGIN_TAG" -v e="$END_TAG" '
        $0 == b {skip=1; next}
        skip && $0 == e {skip=0; next}
        !skip {print}' "$STARTUP" > "$STARTUP.tmp" && mv "$STARTUP.tmp" "$STARTUP"
}

# ------------------------------------------------------------------
# DESINSTALAR
# ------------------------------------------------------------------
if [ $DESINSTALAR = 1 ]; then
    azul "Removendo"
    remover_bloco && ok "Removido do __startup.lua"
    if [ -f "$WWW/$HTML" ] && [ -f "$DEST/$HTML" ] && cmp -s "$WWW/$HTML" "$DEST/$HTML"; then
        rm -f "$WWW/$HTML" && ok "Removido $HTML do reaper_www_root"
    fi
    [ -d "$DEST" ] && rm -rf "$DEST" && ok "Removida a pasta Scripts/$NOME"
    aviso "A interface web (Preferences > Control/OSC/web) foi mantida. Remova por lá se quiser."
    fim 0
fi

# ------------------------------------------------------------------
# 3. SWS instalado?
# ------------------------------------------------------------------
azul "Verificando a extensão SWS"
if ls "$RES/UserPlugins/"reaper_sws* >/dev/null 2>&1; then
    ok "SWS encontrado"
else
    aviso "SWS não encontrado. Instale em https://www.sws-extension.org (sem ele a setlist não funciona)."
fi

# ------------------------------------------------------------------
# 4. Copiar arquivos (extraídos do fim deste arquivo)
# ------------------------------------------------------------------
azul "Copiando arquivos"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
LINHA=$(awk '/^__PAYLOAD__$/ {print NR + 1; exit}' "$0")
tail -n +"$LINHA" "$0" | base64 --decode | tar -xzf - -C "$TMP" || { erro "Pacote corrompido."; fim 1; }
for f in "$LUA" "$HTML"; do
    [ -f "$TMP/$f" ] || { erro "Arquivo faltando no pacote: $f"; fim 1; }
done
mkdir -p "$DEST" "$WWW"
cp -f "$TMP"/* "$DEST"/
ok "Scripts/$NOME (script, página, QR code)"
if [ -f "$WWW/$HTML" ] && ! cmp -s "$WWW/$HTML" "$TMP/$HTML"; then
    BAK="$WWW/$HTML.antigo-$(date +%Y%m%d-%H%M%S)"
    cp "$WWW/$HTML" "$BAK"
    aviso "Já existia um $HTML no reaper_www_root; cópia de segurança: $(basename "$BAK")"
fi
cp -f "$TMP/$HTML" "$WWW/$HTML"
ok "reaper_www_root/$HTML"

# ------------------------------------------------------------------
# 5. Iniciar junto com o REAPER (__startup.lua)
# ------------------------------------------------------------------
azul "Configurando início automático"
mkdir -p "$RES/Scripts"
remover_bloco
LUA_PATH=$(printf '%s' "$DEST/$LUA" | sed 's/\\/\\\\/g; s/"/\\"/g')
[ -s "$STARTUP" ] && [ -n "$(tail -c1 "$STARTUP")" ] && echo >> "$STARTUP"
{
    echo "$BEGIN_TAG"
    echo "do local f = \"$LUA_PATH\""
    echo "  if reaper.file_exists(f) then SWS_WEB_CONTROL_STARTUP = true; dofile(f) end"
    echo "end"
    echo "$END_TAG"
} >> "$STARTUP"
ok "Scripts/__startup.lua"

# ------------------------------------------------------------------
# 6. Interface web do REAPER (reaper.ini)
# ------------------------------------------------------------------
azul "Configurando a interface web do REAPER"
PORTA=$(grep -E "^csurf_[0-9]+=HTTP" "$INI" | grep -F "'$HTML'" | head -1 | awk '{print $3}')
if [ -n "$PORTA" ]; then
    ok "Já configurada (porta $PORTA)"
else
    OUTRA=$(grep -E "^csurf_[0-9]+=HTTP" "$INI" | head -1 | awk '{print $3}')
    if [ -n "$OUTRA" ]; then
        PORTA=$OUTRA
        aviso "Já existe uma interface web na porta $PORTA com outra página inicial; não mexi nela."
        aviso "A setlist abre no endereço com /$HTML no final (veja abaixo)."
    else
        PORTA=$PORTA_PADRAO
        while lsof -nP -iTCP:"$PORTA" -sTCP:LISTEN >/dev/null 2>&1; do PORTA=$((PORTA + 1)); done
        cp "$INI" "$INI.antes-sws-web-control-$(date +%Y%m%d-%H%M%S)"
        LINHA_HTTP="HTTP 0 $PORTA '' '$HTML' 0 ''"
        if grep -qE "^csurf_cnt=[0-9]+" "$INI"; then
            awk -v l="$LINHA_HTTP" '
                /^csurf_cnt=[0-9]+/ && !feito { n = substr($0, 11) + 0; print "csurf_cnt=" n + 1; print "csurf_" n "=" l; feito = 1; next }
                {print}' "$INI" > "$INI.tmp"
        else
            awk -v l="$LINHA_HTTP" '
                {print}
                /^\[reaper\]/ && !feito { print "csurf_cnt=1"; print "csurf_0=" l; feito = 1 }' "$INI" > "$INI.tmp"
        fi
        if grep -q "'$HTML'" "$INI.tmp"; then
            mv "$INI.tmp" "$INI"
            ok "Interface web criada na porta $PORTA (cópia de segurança do reaper.ini feita)"
        else
            rm -f "$INI.tmp"
            erro "Não consegui configurar a interface web. Faça em Preferences > Control/OSC/web."
        fi
    fi
fi

# ------------------------------------------------------------------
# 7. Pronto
# ------------------------------------------------------------------
azul "Pronto!"
echo "  1. Abra o projeto do show (com a Region Playlist do SWS) e salve."
echo "  2. No celular/tablet, na mesma rede Wi-Fi, abra:"
ACHOU=0
for IF in en0 en1 en2 en3; do
    IP=$(ipconfig getifaddr "$IF" 2>/dev/null)
    if [ -n "$IP" ]; then printf '       \033[32mhttp://%s:%s/%s\033[0m\n' "$IP" "$PORTA" "$HTML"; ACHOU=1; fi
done
[ $ACHOU = 0 ] && echo "       http://IP-DESTE-MAC:$PORTA/$HTML"
echo "  3. Ou rode no REAPER a ação 'SWS Web Control - QR code' e aponte a câmera."
echo
echo "  Se o macOS perguntar se o REAPER pode aceitar conexões de rede, clique em Permitir."
open -a REAPER 2>/dev/null || open -a REAPER64 2>/dev/null || true
ok "Abrindo o REAPER..."
fim 0
exit 0
__PAYLOAD__
