# SWS Web Control

Setlist no celular ou tablet para a **Region Playlist do SWS** no REAPER.

Mostra a música atual, o tempo restante da música e do show e a próxima música. Tem botões para iniciar, parar (segurando), ir para a próxima/anterior e **tocar a partir de qualquer música** da setlist, inclusive músicas repetidas. Funciona com o celular ou tablet em pé ou deitado e com vários aparelhos conectados ao mesmo tempo.

## Requisitos

- REAPER (Windows ou Mac)
- Extensão [SWS](https://www.sws-extension.org)
- Um projeto com uma Region Playlist do SWS (Extensions > SWS/S&M > Region Playlist)

## Instalação pelo ReaPack (Windows e Mac, recomendada)

1. No REAPER: **Extensions > ReaPack > Import repositories...** e cole:
   ```
   https://raw.githubusercontent.com/thaallescs-spec/sws-web-control/main/index.xml
   ```
2. **Extensions > ReaPack > Browse packages**, procure **SWS Web Control**, clique com o botão direito > *Install* e depois *Apply*.
3. **Actions > Show action list**, procure **SWS Web Control.lua** e clique em **Run** (só uma vez). O script:
   - copia o `playlist.html` para o `reaper_www_root`;
   - passa a abrir sozinho sempre que o REAPER abrir.
4. **Uma vez só:** Options > Preferences > **Control/OSC/web** > **Add** > *Web browser interface*. Em *Default interface* escolha `playlist.html` e confirme.
5. Rode a ação **SWS Web Control - QR code** e aponte a câmera do celular. O celular precisa estar no mesmo Wi-Fi do computador.

> **Mac:** se aparecer o aviso perguntando se o REAPER pode aceitar conexões de rede, clique em **Permitir**.

As atualizações aparecem no ReaPack (Extensions > ReaPack > Synchronize packages).

## Instalação no Windows sem ReaPack

Baixe [`dist/SWS-Web-Control-Windows.zip`](dist/SWS-Web-Control-Windows.zip) e descompacte. Feche o REAPER e dê dois cliques em **Instalar.bat**. Esse instalador já configura a interface web.

O Windows vai mostrar o aviso de "fornecedor desconhecido": o instalador não é assinado. Clique em **Executar**.

## Uso

| Ação | Como |
|---|---|
| Iniciar o show | **INICIAR** (com o show tocando, precisa segurar: evita voltar para a 1ª música sem querer) |
| Parar | Segure **PARAR** |
| Próxima / anterior | Pulam na hora; só funcionam com o show tocando |
| Tocar a partir de uma música | Toque na música da lista e segure **TOCAR DAQUI** |
| Atualizar a setlist | Salve o projeto (Ctrl+S / Cmd+S): a página atualiza sozinha |

A setlist é lida do projeto **salvo**, porque o SWS não oferece a playlist de outra forma. Quando há alterações não salvas, o rodapé mostra "⚠ não salvo".

## Dicas para o show

- **Reserve o IP do computador no roteador** (procure por "reserva DHCP" ou "IP fixo"). Assim o endereço não muda entre um ensaio e o show.
- Use a mesma rede Wi-Fi no computador e no celular. Redes de convidados costumam bloquear a conexão entre aparelhos.
- No celular, use "Adicionar à tela de início" para abrir a setlist como um app.

## Para quem mantém o projeto

Publicar uma versão nova:

```
python tools/publicar.py 2.1.1 "O que mudou"
git add -A && git commit -m "v2.1.1" && git push
```

O script atualiza o `index.xml` do ReaPack, o `@version` do script principal e o `dist/SWS-Web-Control-Windows.zip`.

O QR code usa a biblioteca [luaqrcode](https://github.com/speedata/luaqrcode) (licença BSD, ver `Live/qrencode-LICENSE.md`).
