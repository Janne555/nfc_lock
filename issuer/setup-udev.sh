#!/bin/bash
# Set up udev permissions and blacklist the pn533 kernel driver so libnfc
# can access the NFC reader without sudo.
#
# Usage: sudo issuer/setup-udev.sh <vendor_id> <product_id>
#   e.g. sudo issuer/setup-udev.sh 04cc 2533
#
# Find your reader's IDs with: lsusb

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "error: run as root (sudo $0 $*)" >&2
    exit 1
fi

if [ $# -ne 2 ]; then
    echo "Usage: sudo $0 <vendor_id> <product_id>" >&2
    echo "Find your reader's IDs with: lsusb" >&2
    exit 1
fi

VENDOR="$1"
PRODUCT="$2"

echo "==> Writing udev rule for $VENDOR:$PRODUCT..."
echo "SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"$VENDOR\", ATTRS{idProduct}==\"$PRODUCT\", MODE=\"0664\", GROUP=\"plugdev\"" \
    > /etc/udev/rules.d/99-nfc.rules
udevadm control --reload-rules && udevadm trigger
echo "    -> /etc/udev/rules.d/99-nfc.rules"

echo "==> Adding current user to plugdev group..."
usermod -aG plugdev "$SUDO_USER"
echo "    -> $SUDO_USER added (log out and back in to take effect)"

echo "==> Blacklisting pn533 kernel driver..."
echo -e "blacklist pn533\nblacklist pn533_usb" > /etc/modprobe.d/nfc-blacklist.conf
update-initramfs -u
echo "    -> /etc/modprobe.d/nfc-blacklist.conf"

echo "==> Unloading pn533 now..."
modprobe -r pn533_usb pn533 nfc 2>/dev/null || true

echo ""
echo "Done. Reboot to make the blacklist permanent."
