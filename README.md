# Linux mudo por falta do `ln`

Estudo de caso de diagnóstico: um Linux iniciado por USB parecia morto, e a causa era um comando ausente de duas letras, o `ln`. O repositório mostra a cadeia **hipótese, controle, medida, resultado**, com a prova ao lado de cada afirmação.

> **Aviso de escopo.** O Linux rodou **só em RAM** (a memória de trabalho). Em 07/10 não houve flash de firmware, apagamento (`erase`) nem desbloqueio (`unlock`), e o envio por Fastboot e a prova final **não** usaram `saveenv`. **Mas houve uma gravação persistente:** às 16h08 de 07/10, antes dos envios pelo PC, o comando `saveenv` do U-Boot gravou na memória interna do aparelho (eMMC) as variáveis de ambiente, com um `bootcmd` (o que o U-Boot executa ao ligar) que tenta iniciar a partir de um pendrive e, se não houver, segue para o boot original do Android. Este repositório não acompanha o que aconteceu com essas variáveis depois. É um registro de método, **não é um guia para modificar aparelho**, e menos ainda aparelho de terceiros.

Autor: Diego Câmara. Datas: 07/10/2026, fuso UTC-3.

## O caso em um minuto

- **Aparelho:** Xiaomi Mi TV Stick (modelo MiTV-AESP0, firmware PI.832), um aparelho de TV com Android. Prova: [`evidencias/resultado-primeiro-envio.json`](evidencias/resultado-primeiro-envio.json).
- **Objetivo:** fazer um Linux rodar nele, como passo para usá-lo de forma contínua como servidor. Prova: diário do projeto (não publicado), seção "Resultado final".
- **Primeiro teste:** enviar o sistema pelo cabo USB direto para a **RAM** (a memória de trabalho), com o **Fastboot** (protocolo de comandos do programa de partida do aparelho). O aparelho aceitou o comando e o Android voltou a iniciar. Prova: [`evidencias/resultado-primeiro-envio.json`](evidencias/resultado-primeiro-envio.json), campos `comando_boot_aceito: true` e `linux_novo_confirmado: false`.
- **Problema:** aceitar o comando **não prova** que o Linux iniciou. Sem sinal nenhum, o Linux parecia morto.
- **Causa do silêncio:** o kernel já iniciava (passo 4 abaixo). Quem falhava era o script de partida (o `/init`, primeiro programa que o Linux executa). Ele precisava do comando `ln` para criar o **canal USB** por onde o aparelho falaria com o PC. O mini-sistema inicial (**initramfs**, um pequeno sistema de arquivos carregado na RAM) não tinha esse comando. Sem canal, silêncio. Prova: [`evidencias/qemu-log-ln-not-found.log`](evidencias/qemu-log-ln-not-found.log), linha 259, e [`scripts/init-diagnostico.sh`](scripts/init-diagnostico.sh). Que o initramfs real do aparelho também não tinha o `ln` está no diário do projeto (não publicado).
- **Resultado:** com o comando incluído, o aparelho apareceu no PC como dispositivo USB e respondeu `Linux 7.1.1`, `uptime 2,62 s`, às 22h52. Repetido às 23h32, mesmo resultado. Prova: [`evidencias/prova-linux-usb.txt`](evidencias/prova-linux-usb.txt), [`evidencias/prova-linux-usb-233314.txt`](evidencias/prova-linux-usb-233314.txt), [`evidencias/console-23h32.jpg`](evidencias/console-23h32.jpg).

**A lição:** silêncio não é evidência de falha. Antes de consertar, faça o sistema dizer onde está. E confira cada hipótese na fonte, inclusive a sua.

## A cadeia, passo a passo

1. **Medida inicial.** Envio à RAM concluído e comando aceito, sem prova de Linux. Prova: [`resultado-primeiro-envio.json`](evidencias/resultado-primeiro-envio.json).
2. **Suspeitos, todos como hipótese.** Formato da imagem (FIT), conflito de endereço de memória, **watchdog** (cão de guarda: temporizador que reinicia o aparelho se ele travar) e a porta USB que não subia. Cada um está em [`HIPOTESES.md`](HIPOTESES.md) com veredito e prova.
3. **Mudança de método.** Parte dos ajustes iniciais foi exploratória e não achou a causa. A partir de uma marca no diário, cada tentativa passou a declarar hipótese, controle alterado, resultado esperado e observação. Prova: diário do projeto (não publicado), seção "Limitação de método reconhecida".
4. **Controles que devolvem o aparelho ao ponto seguro.** Cada controle usa um **stub** (trecho mínimo de código) que anota onde o processador estava e volta ao Fastboot, preservando a RAM. O PC lê a anotação depois. Os dois controles usaram uma **cópia modificada** da Image (o kernel, o núcleo do Linux).
   - **Controle 1 (EL2).** O ponto de entrada da imagem aponta para um stub anexado ao fim da cópia. O nível de execução do processador (`CurrentEL`) era `0x8`, que é EL2. Isso prova que o U-Boot passou o controle ao stub; **não prova que o kernel executou**. Prova: [`controle-handoff-fit.json`](evidencias/controle-handoff-fit.json), endereço `0x7f00008`.
   - **Controle 2 (EL1).** Quatro bytes trocados em `__enable_mmu` desviam para o stub antes da primeira instrução que liga a **MMU** (o circuito de memória virtual). `CurrentEL` era `0x4`, que é EL1. Só este controle prova que **código do kernel executou**: as primeiras rotinas já tinham rodado, inclusive a passagem de EL2 para EL1. Prova: [`controle-antes-mmu.json`](evidencias/controle-antes-mmu.json), endereço `0x7f00008`.
   - Nos dois, a marca `0x51c7b001` em `0x7f00000` foi lida de volta. Quem a escreve é o próprio stub, como primeira ação, depois de o U-Boot zerar a região. Ela prova que o stub executou; que ainda estava lá quando o PC leu mostra que a RAM sobreviveu à volta ao Fastboot.
5. **Simulação.** O mesmo kernel e o mesmo script de partida rodaram no **QEMU** (programa que simula um computador). Saiu `/init: line 24: ln: not found`. Prova: [`qemu-log-ln-not-found.log`](evidencias/qemu-log-ln-not-found.log).
6. **Correção e prova.** Incluído o link `bin/ln` no initramfs (o `ln` é um atalho para o **BusyBox**, pacote de comandos mínimos), o aparelho passou a anunciar um dispositivo USB e a enviar um marcador exclusivo. Depois de um segundo ajuste, no terminal do console (`setsid -c` no lugar de `cttyhack`), passou a responder aos comandos. Prova da resposta: [`prova-linux-usb.txt`](evidencias/prova-linux-usb.txt). O ajuste do terminal e o marcador sem comandos estão no diário (não publicado).

A hora de cada passo está em [`CRONOLOGIA.md`](CRONOLOGIA.md).

## O que está provado, o que é hipótese, o que não foi testado

Os vereditos desta tabela valem para 07/10/2026.

| Situação | Afirmação | Prova |
|---|---|---|
| Provado | O envio à RAM foi concluído e o comando `boot` foi aceito, mas isso não confirma Linux iniciado. | [`resultado-primeiro-envio.json`](evidencias/resultado-primeiro-envio.json) |
| Provado | No envio por Fastboot (comando `boot` às 20h47) e na prova final não houve desbloqueio, flash, apagamento nem `saveenv`. | [`resultado-primeiro-envio.json`](evidencias/resultado-primeiro-envio.json); para a prova final, diário (não publicado) |
| Provado | **Houve uma gravação persistente em 07/10:** às 16h08, `saveenv` gravou na eMMC o `bootcmd` que tenta o pendrive. | Registro do console do U-Boot e `configuracao-usb-confirmada.json` (não publicados) |
| Provado | Controle 1: o U-Boot passou o controle a um stub no fim de uma cópia modificada da Image, com o processador em EL2. Isso prova handoff ao stub, **não** execução do kernel. | [`controle-handoff-fit.json`](evidencias/controle-handoff-fit.json) |
| Provado | Controle 2: código do kernel executou. O processador estava em EL1 antes de ligar a MMU (cópia modificada, quatro bytes trocados em `__enable_mmu`). | [`controle-antes-mmu.json`](evidencias/controle-antes-mmu.json) |
| Provado | No QEMU, o `/init` falha na linha 24 com `ln: not found`. | [`qemu-log-ln-not-found.log`](evidencias/qemu-log-ln-not-found.log), [`init-diagnostico.sh`](scripts/init-diagnostico.sh) |
| Provado | Com o `ln` incluído, Linux 7.1.1 (aarch64) respondeu no aparelho, com uptime de 2,62 s, e repetiu o resultado mais tarde. | [`prova-linux-usb.txt`](evidencias/prova-linux-usb.txt), [`prova-linux-usb-233314.txt`](evidencias/prova-linux-usb-233314.txt), [`console-23h32.jpg`](evidencias/console-23h32.jpg) |
| Provado | O aparelho se identificou como `xiaomi,aquaman amlogic,s805y amlogic,meson-gxl` e só tinha sistemas virtuais montados (nenhuma partição de armazenamento). | [`prova-linux-usb.txt`](evidencias/prova-linux-usb.txt) |
| Provado (A1, da auditoria) | Uma tentativa anterior carregava o arquivo de descrição do hardware (DTB) em endereço dentro de uma região reservada do próprio DTB. | Auditoria (não publicada); método em [`verificar_enderecos_boot.py`](scripts/verificar_enderecos_boot.py) |
| Hipótese (A2, da auditoria) | Essa colisão de endereço causou os reinícios daquela tentativa. A colisão existe; a relação de causa **não foi observada**. O primeiro envio por Fastboot (20h47) já usou o DTB no endereço revisado e o Linux não foi confirmado, o que não decide a causa porque o `ln` ainda faltava. | [`HIPOTESES.md`](HIPOTESES.md), A2 |
| Hipótese | O watchdog (sem driver) reiniciava o aparelho antes do primeiro contato. Um controle sem kernel o isolou: voltou sozinho ao Android, que informou `watchdog_reboot`. O diário relata que uma variante com módulos watchdog/HDMI rodou sem prova de Linux. Se esse reinício era a causa do silêncio, não foi decidido. | [`HIPOTESES.md`](HIPOTESES.md), H4 |
| Hipótese | Causa da dessincronização do Fastboot (respostas chegando no comando seguinte). O fenômeno foi observado; a causa **não foi determinada**. | [`HIPOTESES.md`](HIPOTESES.md), H6 |
| Não testado em 07/10 | Uso contínuo como servidor, comunicação em rede, saída de vídeo e início autônomo, sem o PC. | Diário, "Resultado final" (não publicado) |
| Não testado em 07/10 | Funcionamento além da guarda de 60 segundos do watchdog usada nos testes. | Diário, "Resultado final" (não publicado) |
| Não testado | Que o último comando de reinício enviado tenha sido executado: o aparelho voltou ao Android, mas a saída capturada não confirma o comando. | Diário, "Resultado final", item 6 (não publicado) |

## Evidências e SHA-256

Os hashes foram calculados **depois** da limpeza de dados. Os dois textos de prova (`prova-linux-usb*.txt`) têm o mesmo SHA-256 que os manifestos originais do projeto registravam (conferido na limpeza).

| Arquivo | O que mostra | Removido da cópia pública | SHA-256 |
|---|---|---|---|
| `evidencias/prova-linux-usb.txt` | Resposta do console USB, 22h52 | nada | `bfb8c5cfb204b9cbd4bdead88806a68d3ccca94b8325de46d9956e6cca71eaee` |
| `evidencias/prova-linux-usb-233314.txt` | Repetição, 23h32 (sobre o sufixo `233314`, veja abaixo) | nada | `8216718ec168ba0ab3e3d6a6003ac01d86db2f1fb1dbedc72546416bfeed0756` |
| `evidencias/console-23h32.jpg` | Captura do visualizador do registro, 23h32 | trecho com a porta COM do computador coberto por um retângulo da cor do fundo; imagem regravada só com os pixels, sem metadados | `4374f49d9a1260347b3fca632441d4ea482e228a80fb475856fdd5f5f7ab2a6a` |
| `evidencias/controle-handoff-fit.json` | Controle 1: handoff ao stub no fim da Image (EL2) | chaves `transcript`, `device`, `interface` | `ed466bbc53fe4c8528f6e0f05503bd0de97f9485d1738a54c07ddedd9c02d172` |
| `evidencias/controle-antes-mmu.json` | Controle 2: kernel executando antes de ligar a MMU (EL1) | chaves `transcript`, `device`, `interface` | `86086cd3b3831a4b42c53e363b5e342612c34451a59a0751473f67816109ca0c` |
| `evidencias/qemu-log-ln-not-found.log` | Log do QEMU, com `ln: not found` na linha 259 | nada (não havia caminho do computador a trocar) | `c96768fcef7d2c547b8ce08518bc8ea423ba87df311dfd37e13b596693620ffa` |
| `evidencias/resultado-primeiro-envio.json` | Primeiro envio à RAM (comando `boot` às 20h47; resultado escrito às 20h53) | chaves `ip_android`, `mudanca_persistente_no_pc` | `8cf659c2305911d05c22ea292b629be4895b69aa5261c154537d4caa4ec3f072` |

Sobre o nome `prova-linux-usb-233314.txt`: o sufixo `233314` é a hora de gravação indicada no nome do arquivo de captura (23h33m14s), não a hora do boot. A hora do evento, 23h32, vem do manifesto do projeto (`data_boot_local`, 23:32:39), do diário e do próprio visualizador na imagem; o carimbo de modificação do arquivo original é 23:32:43. A fonte não explica a diferença de cerca de 30 segundos até o sufixo.

Como conferir:

```
sha256sum evidencias/*                          # Linux, macOS, Git Bash
Get-FileHash evidencias\* -Algorithm SHA256     # PowerShell
grep -n "ln: not found" evidencias/qemu-log-ln-not-found.log     # deve dar a linha 259
```

O arquivo `.gitattributes` impede que o Git converta finais de linha e altere os hashes.

Duas observações sobre os JSONs. Em `controle-*.json`, as chaves `pipes` e `pending` ficaram como estavam (descrevem os canais de transferência USB, sem identificar o aparelho). Em `resultado-primeiro-envio.json`, a lista `evidencias` cita arquivos do projeto original que **não** foram publicados.

## Scripts

- [`scripts/init-diagnostico.sh`](scripts/init-diagnostico.sh): o `/init` do initramfs, na versão inspecionada no QEMU, com a linha do `ln` anotada. A correção real foi incluir o link `bin/ln` no initramfs, não alterar esta linha.
- [`scripts/verificar_enderecos_boot.py`](scripts/verificar_enderecos_boot.py): confere se os endereços de carga de um script de boot caem fora das regiões reservadas do DTB. Recebe a pasta dos arquivos e os scripts por argumento. Precisa do `dtc` e de arquivos que **não** estão neste repositório; foi validado só com dados sintéticos. Não substitui o boot real.

## Limites do método

- Parte dos ajustes iniciais foi às cegas e não estabeleceu causa. O diário registra que alguns JSONs antigos de tentativas malsucedidas foram sobrescritos antes de existir um histórico, então a **cobertura do passado é incompleta**.
- A prova do boot é um boot **temporário em RAM, com guarda de watchdog de 60 s**. Em 07/10 não era um sistema instalado.
- O QEMU simula um computador genérico. Ele não reproduz o hardware, o DTB, a memória reservada nem a porta USB do aparelho. Ele mostrou **o que o script faz sem o `ln`**; a prova no aparelho veio depois.
- Os dois controles usaram cópias modificadas da Image (as duas com o stub anexado ao fim; no controle 1, o ponto de entrada foi trocado para o stub; no controle 2, a entrada continuou a do kernel e só quatro bytes em `__enable_mmu` foram desviados para o stub). Nenhuma delas foi usada no boot final.
- Parte das fontes (diário e auditoria) não é publicada porque mistura outros assuntos do projeto. Onde a prova está só nelas, o texto diz.

## Glossário

- **RAM:** memória de trabalho. Some ao desligar; por isso o Linux deste teste não ficou instalado. A gravação do `saveenv` descrita no aviso de escopo não foi em RAM.
- **eMMC:** a memória interna permanente do aparelho.
- **`saveenv`:** comando do U-Boot que grava as variáveis de ambiente (como o `bootcmd`, o que ele executa ao ligar) na eMMC. Ao contrário da RAM, isso permanece depois de desligar.
- **Stub:** trecho mínimo de código usado nos controles para anotar o estado do processador e voltar ao Fastboot.
- **Fastboot:** protocolo de comandos do programa de partida, via USB.
- **U-Boot:** o programa de partida do aparelho, que carrega o kernel.
- **Kernel:** o núcleo do Linux.
- **initramfs / `/init`:** mini-sistema carregado na RAM e seu primeiro programa.
- **BusyBox:** um programa único que oferece comandos básicos (`ln`, `ls`...) por meio de links.
- **Gadget USB / CDC ACM:** o Linux se apresenta ao PC como dispositivo USB; CDC ACM é o tipo que vira uma porta de texto (console).
- **DTB / FDT:** arquivo que descreve o hardware ao kernel, incluindo regiões de memória reservadas.
- **FIT:** formato de pacote do U-Boot com kernel, DTB e initramfs juntos.
- **EL1 / EL2:** níveis de privilégio do processador ARM. O kernel entra em EL2 e passa para EL1.
- **MMU:** circuito de memória virtual.
- **Watchdog:** temporizador que reinicia o aparelho se ninguém o "alimenta".
- **QEMU:** simulador de computadores.
- **`/proc/uptime`:** primeiro número é o tempo ligado, em segundos.

## Licença

Scripts em MIT; textos em CC BY 4.0. Detalhes em [`LICENSE`](LICENSE).
