# Cronologia de 07/10/2026

Todas as horas são locais (UTC-3). Termos técnicos estão no [glossário do README](README.md#glossário).

**De onde vem cada hora.** Há quatro origens, indicadas na coluna "Hora":

- **registro:** a hora está escrita no arquivo de prova, no nome do arquivo de captura ou no diário do projeto (publicados ou não).
- **carimbo:** hora do primeiro comando no registro original de um controle. O carimbo estava na parte do JSON removida da cópia pública, então só pode ser conferido no original.
- **arquivo:** hora de modificação do arquivo no computador do autor.
- **sem hora:** o diário não dá a hora; o evento é colocado na ordem em que o diário o descreve.

"Diário" e "auditoria" são os registros do projeto, **não publicados** por misturarem outros assuntos. Onde a prova está só neles, a tabela diz.

## Preparação e tentativas por pendrive (16h08 até 19h59)

| Hora | Hipótese ou controle | O que se fez | Resultado | Prova |
|---|---|---|---|---|
| 16h08 (registro) | Preparação: fazer o U-Boot tentar o pendrive ao ligar. | Comando `saveenv` no console do U-Boot, que gravou as variáveis de ambiente na eMMC, com um `bootcmd` que tenta o pendrive e, se não houver, segue para o boot original do Android. **É uma gravação persistente no aparelho.** A hora está no nome do arquivo de captura (`uboot-20261007-160858`). | `Writing to MMC(1)... done`. O aparelho foi reiniciado e procurou o pendrive. As tentativas por pendrive abaixo dependem dessa gravação. O restante do dia (envio por Fastboot e prova final) não usou `saveenv`. | Registros do U-Boot e `configuracao-usb-confirmada.json` (não publicados) |
| sem hora | Hipótese: o script de partida original, gravado num pendrive, inicia o Linux. | Pendrive gravado e relido no PC (SHA-256 igual). | Reinícios relatados com o script ativo. Com o script desativado e com um controle de carga, o Android iniciou. **Inconclusivo**: nada provava que o U-Boot leu a mídia, porque o controle só emitia mensagens na porta de depuração (UART), que não estava conectada. | Auditoria (não publicada) |
| sem hora | Controle: conferir o endereço de carga do DTB contra as reservas do próprio DTB. | `aquaman.dtb` era carregado em `0x10000000`. | O DTB declara `secmon@10000000` reservado de `0x10000000` a `0x10200000`. **Conflito provado**; a relação de causa com os reinícios **não foi observada**. Correção preparada: `0x18000000`. | Auditoria (não publicada); método em [`scripts/verificar_enderecos_boot.py`](scripts/verificar_enderecos_boot.py) |
| sem hora | Controle: mostrar marcadores na tela. | Script que exibe imagens. | Nenhuma mensagem apareceu e o Android iniciou. **Inconclusivo.** | Auditoria (não publicada) |
| 19h59 (registro) | Controle: registro gravado no próprio pendrive. | Instalação de um controle que escreve marcadores na mídia. | Resultado físico ainda não existia quando a auditoria foi escrita. | Auditoria (não publicada) |

## Primeiro envio pelo PC, em RAM

| Hora | Hipótese ou controle | O que se fez | Resultado | Prova |
|---|---|---|---|---|
| 20h47 (registro) | Hipótese: enviar o sistema pelo USB, direto para a RAM, inicia o Linux. | Envio de 87.574.528 bytes por Fastboot, com o DTB já no endereço revisado `0x18000000` (ver A2 em [`HIPOTESES.md`](HIPOTESES.md)). O comando `boot` foi enviado às 20h47; o JSON de resultado foi escrito às 20h53. Sem desbloqueio, flash, apagamento ou `saveenv` **neste envio**. | Transferência completa e comando `boot` aceito. Linux **não** confirmado. O Android voltou a iniciar. Causa do retorno: não determinada (o Android não permite ler o registro de falhas do kernel). Isso não decide a causa do silêncio, porque o `ln` ainda faltava. | [`resultado-primeiro-envio.json`](evidencias/resultado-primeiro-envio.json) (20h53); hora do comando `boot` no registro original (não publicado) |

## Depois do primeiro envio e antes de 22h25: hipóteses e a mudança de método

O diário descreve esta fase sem horas. A ordem abaixo é a do diário e este posicionamento é inferido dela.

| Hora | Hipótese ou controle | O que se fez | Resultado | Prova |
|---|---|---|---|---|
| sem hora | H1: o PC não fala com o aparelho. | Comandos e script por Fastboot. | Descartada para o caminho pelo PC. | [`resultado-primeiro-envio.json`](evidencias/resultado-primeiro-envio.json); diário (não publicado) |
| sem hora | Observação: primeiro `booti`. | Comando de boot. | O USB desconectou e depois o Android apareceu. O Android informou `watchdog_reboot`, o que classifica o reinício, mas não prova que o kernel executou. | Diário (não publicado) |
| sem hora | H2: o U-Boot não reconhece o FIT. | `bootm start`. | Sucesso no próprio aparelho. Descartada para o FIT testado. | Diário (não publicado) |
| sem hora | Observação: execução do FIT. | `bootm go`. | O USB desapareceu por mais de 60 s e o logotipo da fabricante ficou parado, segundo o relato do autor. | Diário (não publicado) |
| sem hora | **Mudança de método.** Parte dos ajustes no transporte USB tinha sido exploratória e não achou a causa. | Passou-se a declarar, a cada tentativa, hipótese, controle alterado, resultado esperado e observação. | Registro: parte do histórico antigo foi sobrescrita; a cobertura do passado é incompleta. | Diário, "Limitação de método" (não publicado) |

## Da noite ao boot provado

| Hora | Hipótese ou controle | O que se fez | Resultado | Prova |
|---|---|---|---|---|
| 21h53 a 22h07 (arquivo) | Controle: separar as etapas do boot FIT. | Os passos `start`, `loados`, `ramdisk`, `fdt` e `prep` foram executados um a um. | Todos voltaram ao Fastboot. A perda de USB ficou **delimitada ao `bootm go`** (execução de 22h09), sem provar entrada no kernel. | Diário (não publicado) |
| 22h20 a 22h22 (arquivo) | Controle: separar o watchdog do kernel. | Salto para uma espera em RAM, sem kernel, com o watchdog configurado por registradores. | Voltou sozinho ao Android, sem o autor tocar no cabo; o Android informou `watchdog_reboot`. | Diário (não publicado) |
| 22h25 (registro) | H4: o watchdog reinicia o aparelho. | Boot FIT mínimo. | O aparelho voltou sozinho ao Android (Fastboot sumiu às 22h25 e o Android apareceu às 22h26, conforme o diário). O Android informou `watchdog_reboot`. O diário também relata, sem hora, que a variante com módulos watchdog/HDMI rodou sem prova de Linux e não recuperou no intervalo observado. | Diário, "Atualização medida — 22h40" (não publicado) |
| 22h33 a 22h37 (arquivo) | Controle: a marca gravada na RAM sobrevive? | Leitura e gravação de uma marca (`0x51c7a001`) em quatro pontos da RAM. | A marca sobrevive a um reinício direto Fastboot para Fastboot e some depois de passar pelo Android, então **ausência de marca depois do Android é inconclusiva**. | Diário (não publicado) |
| 22h42 (carimbo) | H8: o kernel executa? Controle 1, de handoff. | O ponto de entrada de uma cópia modificada da Image aponta para um stub anexado ao fim dela; o stub anota o estado e volta ao Fastboot. | `CurrentEL` = `0x8` (EL2); a marca `0x51c7b001`, escrita pelo próprio stub depois de o U-Boot zerar a região, foi lida de volta. Prova handoff ao stub, **não** execução do kernel. | [`controle-handoff-fit.json`](evidencias/controle-handoff-fit.json) |
| 22h46 (arquivo) | H9: o `/init` falha antes do USB? | Mesmo kernel e mesmo `/init` no QEMU. | `/init: line 24: ln: not found`. | [`qemu-log-ln-not-found.log`](evidencias/qemu-log-ln-not-found.log) linha 259; [`init-diagnostico.sh`](scripts/init-diagnostico.sh) |
| 22h47 (carimbo) | H8: o kernel passa da primeira etapa? Controle 2, antes da MMU. | Quatro bytes trocados em `__enable_mmu`, na cópia modificada da Image, desviam para o stub antes da primeira instrução que liga a MMU; o stub volta ao Fastboot. | `CurrentEL` = `0x4` (EL1); marca escrita pelo stub e lida de volta. **Prova execução de código do kernel**: as primeiras rotinas rodaram, inclusive a passagem de EL2 para EL1. | [`controle-antes-mmu.json`](evidencias/controle-antes-mmu.json) |
| 22h49 (carimbo; inferido) | H5: com o `ln`, o USB aparece? | Link `bin/ln` incluído no initramfs; novo boot em RAM. | O aparelho passou a anunciar um dispositivo USB e enviou o marcador exclusivo, mas a primeira sessão não devolveu comandos antes do watchdog. É inferência que esta seja a execução do diário: o registro tem "ln corrigido" no nome e hora compatível, e o diário não dá a hora. | Diário (não publicado) |
| sem hora | Ajuste do terminal. | `cttyhack` substituído por `setsid -c`; o `/init` passou a enviar o resumo do sistema sozinho. | Preparou a captura das 22h52. | Diário (não publicado) |
| 22h52 (registro) | Prova principal. | Captura pelo console USB. | `Linux (none) 7.1.1 ... aarch64`, `/proc/uptime` = `2.62 7.11`, marcador `AQUAMAN-USB-DIAG-20261007-7F4C91D2`, `xiaomi,aquaman amlogic,s805y amlogic,meson-gxl`. Só rootfs, proc, sysfs, devtmpfs e configfs montados. | [`prova-linux-usb.txt`](evidencias/prova-linux-usb.txt) |
| depois das 22h52 (sem hora) | Controle de retorno. | Comando de reinício enviado em seguida. | A porta fechou antes de registrar a resposta. O Android voltou sem intervenção física e informou `cold_boot`. O retorno está provado; **a execução do comando não foi confirmada** pela saída capturada. | Diário, "Resultado final", item 6 (não publicado) |

## Repetição

| Hora | Hipótese ou controle | O que se fez | Resultado | Prova |
|---|---|---|---|---|
| 23h32 (registro) | Controle: o resultado se repete. | Mesmo boot em RAM, de novo. | Linux 7.1.1 aarch64, `/proc/uptime` = `2.62 7.05`. Com comandos do PC, `3.45 10.33`. | [`prova-linux-usb-233314.txt`](evidencias/prova-linux-usb-233314.txt); captura em [`console-23h32.jpg`](evidencias/console-23h32.jpg). O sufixo `233314` do nome é explicado no [README](README.md#evidências-e-sha-256) |
| 23h34 (registro) | Observação. | Aparelho observado no USB. | Reapareceu com outro identificador USB, diferente do `0525:A4A7` do diagnóstico. | Diário, "Nova confirmação física — 23h32" (não publicado) |

A captura mostra o **registro** do console USB num visualizador local. Não é uma sessão remota nem um servidor configurado.

## O que a cronologia mostra

- Nas tentativas por pendrive, o "silêncio" era inconclusivo e foi tratado como tal.
- Dos controles de 22h42 e 22h47, só o segundo prova execução de código do kernel. Eles e a simulação de 22h46 aconteceram no mesmo intervalo de minutos. Foi a simulação que deu a pista do `ln`.
- Dez minutos separam o primeiro controle de handoff (22h42) da prova de Linux respondendo (22h52). Marca na RAM já tinha sido usada antes, só que no teste de retenção (22h33 a 22h37).
