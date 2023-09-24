#!/bin/sh

set -e

if [ "$#" -ne 2 ]; then
  echo "2 arguments are required in this order: <OS dir> <image> [OPTIONAL: <size of vdi image in MB>]"
  exit 1
fi

OS="$1"
DISK_IMG="$2"
DISK_RAW="$DISK_IMG"
VDI_SIZE_IN_MB="${3:-30000}"

# Clean up first
./clean_up.sh "$OS"

. "$OS/vars"

# prepare cloud init iso
cloud-localds cloud-init.iso user-data

# Convert img to raw if Ubuntu
if echo "$OS" | grep -q ubuntu
then
  DISK_RAW="${DISK_IMG%.img}.raw"
  qemu-img convert -O raw "$DISK_IMG" "$DISK_RAW"
fi
# Convert raw to vdi and resize it
vboxmanage convertfromraw "$DISK_RAW" "$OS/$OS".vdi
vboxmanage modifymedium disk "$OS/$OS".vdi --resize "$VDI_SIZE_IN_MB"

# Create VM
vboxmanage createvm --name "$OS" --ostype "$OS_TYPE" --register
vboxmanage modifyvm "$OS" --cpus 2 --memory 2048 --vram 16 --graphicscontroller=vmsvga \
  --usb-ehci=off --usb-ohci=off --usb-xhci=off \
  --audio-enabled=off \
  --uart1 off \
  --natpf1 "guestssh,tcp,,$SSH_PORT,,22" \
  --boot1 disk --boot2 dvd --boot3 none --boot4 none
vboxmanage storagectl "$OS" --name "SATA Controller" --add sata --bootable on --portcount 1
vboxmanage storageattach "$OS" --storagectl "SATA Controller" \
  --port 0 --device 0 --type hdd \
  --medium "$OS/$OS".vdi
vboxmanage storagectl "$OS" --name "IDE Controller" --add ide
vboxmanage storageattach "$OS" --storagectl "IDE Controller" \
  --port 0 --device 0 --type dvddrive --medium cloud-init.iso
# Start VM
vboxmanage startvm "$OS" --type headless

# clean known hosts
# shellcheck disable=SC2102
ssh-keygen -R [localhost]:"$SSH_PORT" >/dev/null 2>&1

# Wait till machine is ready
until ssh -o "StrictHostKeyChecking no" -i ~/.ssh/id_rsa.devel -p "$SSH_PORT" root@localhost 2> /dev/null 'exit'
do
  sleep 1
done

echo "Unmounting cloud init iso"
vboxmanage storageattach "$OS" --storagectl "IDE Controller" \
  --port 0 --device 0 --type dvddrive --forceunmount --medium emptydrive
echo "Attaching Guest Tools"
tools_iso=$(vboxmanage list dvds | grep -B3 'VBoxGuestAdditions.iso' | head -n1 | awk '{printf $2}')
vboxmanage storageattach "$OS" --storagectl "IDE Controller" \
  --port 0 --device 0 --type dvddrive --medium "$tools_iso"

echo
echo "Machine successfully provisioned!"
echo "To log in use: ssh -i ~/.ssh/id_rsa.devel -p $SSH_PORT root@localhost"
