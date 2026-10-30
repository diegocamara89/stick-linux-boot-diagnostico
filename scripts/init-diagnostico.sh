#!/bin/sh
# /init do initramfs de diagnostico, na versao inspecionada no QEMU (antes da correcao).
#
# Papel: montar os sistemas virtuais, criar um gadget USB com uma porta de
# console (CDC ACM) e abrir um shell nela. E por essa porta que o aparelho
# "fala" com o PC. Sem a porta, o aparelho parece morto.
#
# Esta e a versao ANTERIOR a correcao. Diferencas conhecidas (pelo diario do
# projeto, nao publicado; a lista pode nao ser completa) para o init que rodou no
# aparelho na prova das 22h52 (ver CRONOLOGIA.md):
#   1. A correcao do ln NAO esta neste arquivo: foi incluir o link bin/ln -> busybox
#      dentro do initramfs.
#   2. Nesta versao o shell abre com "cttyhack"; na prova final foi trocado por
#      "setsid -c" (o shell passou a responder a comandos).
#   3. Na prova final o init passou a enviar sozinho o resumo do sistema.
# Os comentarios abaixo foram acrescentados para este repositorio; o restante e
# o original. Com os comentarios, a linha do ln -s fica deslocada; no original
# ela era a linha 24, a que o log cita (evidencias/qemu-log-ln-not-found.log).
#
# Texto que aparece como fabricante/produto USB (OpenAI, "Aquaman Linux USB ...")
# e so rotulo escolhido no teste; nao identifica o aparelho.
export PATH=/bin
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mkdir -p /sys/kernel/config
mount -t configfs configfs /sys/kernel/config || while true; do sleep 60; done
modprobe libcomposite || while true; do sleep 60; done
modprobe usb_f_acm || while true; do sleep 60; done
G=/sys/kernel/config/usb_gadget/diag
mkdir -p "$G/strings/0x409" "$G/configs/c.1/strings/0x409" "$G/functions/acm.usb0"
echo 0x0525 > "$G/idVendor"
echo 0xa4a7 > "$G/idProduct"
echo 0x0200 > "$G/bcdUSB"
echo 0x0100 > "$G/bcdDevice"
echo 0x02 > "$G/bDeviceClass"
echo 0x02 > "$G/bDeviceSubClass"
echo 0x01 > "$G/bDeviceProtocol"
echo AQUAMAN-DIAG-20261007-7F4C91D2 > "$G/strings/0x409/serialnumber"
echo OpenAI > "$G/strings/0x409/manufacturer"
echo 'Aquaman Linux USB diagnostic console' > "$G/strings/0x409/product"
echo 'CDC ACM console' > "$G/configs/c.1/strings/0x409/configuration"
echo 250 > "$G/configs/c.1/MaxPower"
# A LINHA DO ln: cria a ligacao da funcao "acm" (a porta de console) dentro da
# configuracao do gadget. Com PATH=/bin e sem o arquivo /bin/ln no initramfs, o
# shell responde "/init: line 24: ln: not found" e a ligacao nao e criada.
# Foi o que o QEMU mostrou (evidencias/qemu-log-ln-not-found.log, linha 259).
ln -s "$G/functions/acm.usb0" "$G/configs/c.1/acm.usb0"
UDC=
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    for path in /sys/class/udc/*; do
        [ -e "$path" ] || continue
        name=${path##*/}
        if echo "$name" > "$G/UDC"; then UDC=$name; break; fi
    done
    [ -n "$UDC" ] && break
    sleep 1
done
[ -n "$UDC" ] || while true; do sleep 60; done
SERIAL=/dev/ttyGS0
while [ ! -c "$SERIAL" ]; do sleep 1; done
while true; do
    printf '\r\nAQUAMAN-USB-DIAG-20261007-7F4C91D2\r\n' > "$SERIAL"
    printf 'Linux mainline em RAM; nenhuma particao de armazenamento foi montada.\r\n' > "$SERIAL"
    cat /etc/usb-diag-help > "$SERIAL"
    setsid cttyhack sh -i < "$SERIAL" > "$SERIAL" 2>&1
    sleep 1
done
