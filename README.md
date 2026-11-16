# SWS Web Control

Setlist no celular ou tablet para a **Region Playlist do SWS** no REAPER.

Mostra a música atual, o tempo restante da música e do show e a próxima música. Tem botões para iniciar, parar (segurando), ir para a próxima/anterior e **tocar a partir de qualquer música** da setlist, inclusive músicas repetidas. Funciona com o celular ou tablet em pé ou deitado e com vários aparelhos conectados ao mesmo tempo.

## Requisitos

- REAPER (Windows ou Mac)
- Extensão [SWS](https://www.sws-extension.org)
- Um projeto com uma Region Playlist do SWS (Extensions > SWS/S&M > Region Playlist)

## Instalação com 1 clique

| Sistema | Baixe | Depois |
|---|---|---|
| **Windows** | [Instalar SWS Web Control.cmd](https://github.com/thaallescs-spec/sws-web-control/raw/main/dist/Instalar%20SWS%20Web%20Control.cmd) | Dois cliques no arquivo |
| **Mac** | [SWS-Web-Control-Mac.zip](https://github.com/thaallescs-spec/sws-web-control/raw/main/dist/SWS-Web-Control-Mac.zip) | Abra o zip e dê dois cliques em **Instalar SWS Web Control.command** |

O instalador:
- espera você fechar o REAPER, se ele estiver aberto (salve o projeto antes);
- copia o script, a página e o QR code;
- faz o SWS Web Control abrir junto com o REAPER;
- ativa a interface web do REAPER na porta 8080 (ou na próxima livre), com backup do `reaper.ini`;
- abre o REAPER de novo e mostra o endereço para o celular.

Depois, rode a ação **SWS Web Control - QR code** e aponte a câmera do celular. O celular precisa estar no mesmo Wi-Fi do computador.

**Avisos de segurança na primeira vez.** O instalador não tem assinatura digital paga, por isso o sistema avisa:
- **Windows:** "O Windows protegeu o computador" → **Mais informações** → **Executar assim mesmo**. Se o navegador avisar sobre o download, escolha **Manter**.
- **Mac:** "não pode ser aberto porque é de um desenvolvedor não identificado" → **Ajustes do Sistema → Privacidade e Segurança** → **Abrir Mesmo Assim**. Depois, se perguntar se o REAPER pode aceitar conexões de rede, clique em **Permitir**.

Para desinstalar: **Desinstalar SWS Web Control** ([Windows](https://github.com/thaallescs-spec/sws-web-control/raw/main/dist/Desinstalar%20SWS%20Web%20Control.cmd); no Mac está dentro do mesmo zip).

## Instalação pelo ReaPack (Windows e Mac, com atualização automática)

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

## Uso

| Ação | Como |
|---|---|
| Iniciar o show | **INICIAR** (com o show tocando, precisa segurar: evita voltar para a 1ª música sem querer) |
| Parar | Segure **PARAR** |
| Próxima / anterior | Pulam na hora; só funcionam com o show tocando |
| Tocar a partir de uma música | Toque na música da lista e segure **TOCAR DAQUI** |
| Atualizar a setlist | Salve o projeto (Ctrl+S / Cmd+S): a página atualiza sozinha |
| Testar uma região fora da playlist | Aba **Regiões do projeto** → toque na região → segure **TOCAR REGIÃO**. Toca só ela e para no fim; o topo da tela fica laranja ("Região avulsa"). **INICIAR** cancela e começa o show |

Atualizações do script (pelo ReaPack ou pelo instalador) entram sozinhas em até 3 segundos, sem reiniciar o REAPER.

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

O script atualiza o `index.xml` do ReaPack, o `@version` do script principal e os instaladores em `dist/` (Windows e Mac).

O QR code usa a biblioteca [luaqrcode](https://github.com/speedata/luaqrcode) (licença BSD, ver `Live/qrencode-LICENSE.md`).
