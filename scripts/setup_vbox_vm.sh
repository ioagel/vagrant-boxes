#!/bin/sh

set -e

if [ "$#" -ne 2 ]; then
  echo "2 arguments are required in this order (max 3): <OS dir> <image> [OPTIONAL: <size of vdi image in MB>]"
  exit 1
fi

GIT_ROOT=$(git rev-parse --show-toplevel)
OS="$1"

# shellcheck disable=SC1090
. "${GIT_ROOT}/${OS}/vars"

DISK_IMG="$2"
DISK_RAW="$DISK_IMG"
VDI_SIZE_IN_MB="${3:-30000}"
DISK_VDI="${GIT_ROOT}/${OS}/${OS}.vdi"
FILES="${GIT_ROOT}/files"
SCRIPTS="${GIT_ROOT}/scripts"
GUEST_TOOLS_ISO="${GIT_ROOT}/files/vboxtools.iso"

# Clean up first
"${SCRIPTS}"/clean_up.sh "$OS"

# prepare cloud init iso
cloud-localds "${FILES}/cloud-init.iso" "${FILES}/user-data"

# Convert img to raw if Ubuntu
if echo "$OS" | grep -q ubuntu
then
  DISK_RAW="${DISK_IMG%.img}.raw"
  qemu-img convert -O raw "$DISK_IMG" "$DISK_RAW"
fi
# Convert raw to vdi and resize it
vboxmanage convertfromraw "$DISK_RAW" "$DISK_VDI"
vboxmanage modifymedium disk "$DISK_VDI" --resize "$VDI_SIZE_IN_MB"

# Create VM
vboxmanage createvm --name "$OS" --ostype "$OS_TYPE" --register
vboxmanage modifyvm "$OS" --cpus 2 --memory 2048 --vram 16 --graphicscontroller=vmsvga \
  --usb-ehci=off --usb-ohci=off --usb-xhci=off \
  --audio-enabled=off \
  --uart1 off \
  --nic-type1 virtio --nic1 nat --natpf1 "guestssh,tcp,,$SSH_PORT,,22" \
  --boot1 disk --boot2 dvd --boot3 none --boot4 none
vboxmanage storagectl "$OS" --name "SATA Controller" --add sata --bootable on --portcount 1
vboxmanage storageattach "$OS" --storagectl "SATA Controller" \
  --port 0 --type hdd --medium "$DISK_VDI"
vboxmanage storagectl "$OS" --name "IDE Controller" --add ide
vboxmanage storageattach "$OS" --storagectl "IDE Controller" \
  --port 0 --device 0 --type dvddrive --medium "${FILES}/cloud-init.iso"

# Start VM
vboxmanage startvm "$OS" --type headless

# clean known hosts
# shellcheck disable=SC2102
ssh-keygen -R [localhost]:"$SSH_PORT" >/dev/null 2>&1

# Wait till machine is ready
until ssh -o "StrictHostKeyChecking no" -i "${FILES}/id_rsa.devel" -p "$SSH_PORT" root@localhost 2> /dev/null 'uptime'
do
  sleep 2
done

echo "Unmounting cloud init iso"
vboxmanage storageattach "$OS" --storagectl "IDE Controller" \
  --port 0 --device 0 --type dvddrive --forceunmount --medium emptydrive
echo "Attaching Guest Tools"
vboxmanage storageattach "$OS" --storagectl "IDE Controller" \
  --port 0 --device 0 --type dvddrive --medium "$GUEST_TOOLS_ISO"

echo
echo "Machine successfully provisioned!"
echo "To log in use: ssh -i ${FILES}/id_rsa.devel -p $SSH_PORT root@localhost"

exit 0
