# Hipóteses, controles e vereditos

Cada linha segue o mesmo molde: **hipótese**, **controle** (o que foi mudado ou medido para testá-la), **resultado** e **veredito**. Termos técnicos estão definidos no [glossário do README](README.md#glossário).

Vereditos usados:

- **provada:** há medida direta que sustenta a afirmação.
- **descartada:** há medida que contradiz a afirmação, no alcance dito.
- **aberta:** não há medida que decida. Inclui o que foi observado, mas teve a causa não determinada.

A numeração H1 a H7 segue a seção "Hipóteses e resultado" do diário do projeto (não publicado); nela, H3 é a relocação do `booti` em memória reservada. H8 e H9 foram formuladas na mesma noite e recebem rótulo só neste repositório. O conflito do DTB em `0x10000000` vem da **auditoria** (não publicada), não do diário, e por isso ganha rótulos próprios, A1 e A2. O diário registra H4 e H5 como abertas naquela seção; o resultado final da noite resolve H5 (veja abaixo).

Os vereditos valem para a sessão de testes de outubro de 2026.

## Tabela

| # | Hipótese | Controle | Resultado | Veredito | Prova |
|---|---|---|---|---|---|
| H1 | O PC não consegue falar com o aparelho por USB (Fastboot, comandos OEM, script). | Envio de dados e comandos pelo PC; comando `boot` ao fim. | Transferência completa e comando `boot` aceito. O diário também registra execução de script e de comandos do U-Boot por esse caminho. | **descartada** para o caminho pelo PC | [`resultado-primeiro-envio.json`](evidencias/resultado-primeiro-envio.json) (`transferencia_completa_confirmada`, `comando_boot_aceito`); o restante, no diário (não publicado) |
| H2 | O U-Boot não reconhece o formato FIT. | Passo `bootm start` com o FIT. | Retornou sucesso no próprio aparelho. | **descartada** para o FIT testado | Diário (não publicado); sem arquivo de prova publicado |
| H3 | O `booti` relocava a Image para dentro de memória reservada. | Comparação da Image com a fonte pública usada como referência (cabeçalho com `text_offset` = 0; a referência move a Image para a base da DRAM) e ajuste do FIT para carga e entrada em `0x02000000`. | Segundo o diário: o DTB reserva de 0 a 16 MiB e o FIT passa a terminar em `0x04bd0000`, antes da reserva em `0x05000000`. O conflito foi demonstrado contra a fonte de referência. No aparelho, a causa continua hipótese: não há o binário nem a fonte exata do firmware PI.832 para comparar. | **aberta** | Diário (não publicado) |
| A1 (auditoria) | O DTB era carregado em endereço dentro de uma região de memória reservada. | Conferir o endereço de carga contra as reservas declaradas no próprio DTB. | O DTB (28.381 bytes) era carregado em `0x10000000`; o DTB declara `secmon@10000000` reservado de `0x10000000` a `0x10200000`. | **provada** (conflito de endereços) | Auditoria (não publicada); método em [`verificar_enderecos_boot.py`](scripts/verificar_enderecos_boot.py) |
| A2 (auditoria) | O conflito de A1 causou os reinícios da tentativa por pendrive. | Mover o DTB para `0x18000000` e conferir por script. | A conferência de endereços passou. O primeiro envio por Fastboot já usou o DTB no endereço revisado e o Linux não foi confirmado (o aparelho voltou ao Android); isso não decide a causa, porque o `ln` ainda faltava. O teste por pendrive com o DTB revisado ficou pendente na auditoria. A conferência não valida a realocação feita pelo U-Boot, e a relação de causa **não foi observada**. | **aberta** | Auditoria (não publicada); [`resultado-primeiro-envio.json`](evidencias/resultado-primeiro-envio.json) |
| H4 | O watchdog, ativo e sem driver, reinicia o aparelho antes do primeiro contato. | Controle sem kernel (`go` para uma espera em RAM, com o watchdog configurado por registradores); boot FIT mínimo; variante com módulos watchdog/HDMI. | O controle sem kernel voltou sozinho ao Android, que informou `watchdog_reboot`. O boot FIT mínimo também voltou sozinho. O diário relata que a variante com módulos watchdog/HDMI **rodou** sem produzir prova de Linux e não recuperou no intervalo observado, e que atribuir a diferença só ao módulo seria hipótese. A prova final rodou com o watchdog armado por 60 s. Fica provado que o watchdog reinicia o aparelho; que ele era a causa do silêncio, não. | **aberta** | Diário (não publicado) |
| H5 | O gadget USB (a porta de console) não iniciou. | Incluir o link `bin/ln` e observar se o aparelho aparece no USB. | O QEMU mostra a falha do `ln` na linha 24 do `/init`, que é a linha que liga a porta ao gadget. Com o link incluído, o aparelho apareceu no USB e enviou o marcador. | **provada** para o initramfs desta noite (a falta do `ln` impedia o USB) | [`qemu-log-ln-not-found.log`](evidencias/qemu-log-ln-not-found.log) linha 259, [`init-diagnostico.sh`](scripts/init-diagnostico.sh), [`prova-linux-usb.txt`](evidencias/prova-linux-usb.txt); o "antes e depois" no aparelho está no diário (não publicado) |
| H6 | Há uma causa identificável para a dessincronização do Fastboot (respostas de consultas anteriores chegando em comandos posteriores). | Reiniciar canais (`ResetPipe`, `FlushPipe`), enviar pacotes vazios, reconfigurar a interface. | O fenômeno foi observado diretamente. Nenhuma das medidas produziu correção estável. O diário manda não atribuir causa a esses mecanismos sem teste. | **aberta** | Diário (não publicado) |
| H7 | O final curto da transferência (tamanho não múltiplo de 4096) causa a falha. | Enviar o FIT original e uma variante preenchida até múltiplo de 4096. | Os dois terminaram sem status final legível. Uma retomada posterior conseguiu executar o FIT. O diário conclui que isso não sustenta o alinhamento como causa suficiente. | **aberta** (sem sustentação como causa) | Diário (não publicado) |
| H8 | O kernel nem chegava a executar. | Controle 1 (stub no fim da Image, entrada trocada) e controle 2 (quatro bytes trocados em `__enable_mmu`), ambos voltando ao Fastboot. | Controle 1: `CurrentEL` = `0x8` (EL2) lido pelo stub; prova handoff ao stub, não execução do kernel. Controle 2: `CurrentEL` = `0x4` (EL1) antes da MMU; prova que as primeiras rotinas do kernel executaram, inclusive a passagem de EL2 para EL1. A marca `0x51c7b001` foi lida de volta nos dois. | **descartada** (pelo controle 2) | [`controle-handoff-fit.json`](evidencias/controle-handoff-fit.json), [`controle-antes-mmu.json`](evidencias/controle-antes-mmu.json) (palavra em `0x7f00008`) |
| H9 | O `/init` falhava antes de abrir o canal USB, por falta de um comando. | Rodar o mesmo kernel e o mesmo `/init` no QEMU. | `/init: line 24: ln: not found`. | **provada** no QEMU; no aparelho, ver H5 | [`qemu-log-ln-not-found.log`](evidencias/qemu-log-ln-not-found.log), [`init-diagnostico.sh`](scripts/init-diagnostico.sh) |

## Como ler as provas dos controles (H8)

Cada controle guarda, na RAM a partir de `0x7f00000`, valores lidos do processador e devolve o aparelho ao Fastboot sem seguir para o resto do Linux. No controle 1, o ponto de entrada aponta para um stub anexado ao fim da Image, então o kernel nem começa. No controle 2, o kernel executa até `__enable_mmu`, onde quatro bytes trocados desviam para o stub. O PC lê os valores depois. Os arquivos [`controle-handoff-fit.json`](evidencias/controle-handoff-fit.json) e [`controle-antes-mmu.json`](evidencias/controle-antes-mmu.json) trazem a lista `ram_words` (endereço e valor).

| Endereço | Controle 1 (stub no fim da Image) | Controle 2 (antes da MMU) | Significado |
|---|---|---|---|
| `0x7f00000` | `0x51c7b001` | `0x51c7b001` | Marca escrita pelo próprio stub, como primeira ação, depois de o U-Boot zerar a região. Se está lá, o stub executou; que ainda estava lá quando o PC leu mostra que a RAM sobreviveu à volta ao Fastboot. |
| `0x7f00008` | `0x8` | `0x4` | `CurrentEL`: `0x8` é EL2, `0x4` é EL1. Pelo diário. |

Limites: os dois controles usaram cópias modificadas da Image (controle 1: 42.732.152 bytes contra 42.732.032 da original, por causa do stub anexado; controle 2: além disso, quatro bytes trocados em `__enable_mmu`). Nenhuma delas foi usada no boot final.

## O que a tabela mostra sobre o método

- Das onze linhas, cinco terminam **abertas** (H3, A2, H4, H6, H7). Ficam abertas porque faltou medida que decida.
- Quem localizou a causa foi a **simulação** (H9). **Marcar onde o aparelho estava** (H8) mostrou que o kernel já executava.
- Um conflito de endereço **provado** (A1) não vira causa **provada** (A2) só por ser real.
- A ausência de USB não era prova de falha do kernel (H5 e H8).
