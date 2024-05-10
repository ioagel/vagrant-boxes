#!/bin/sh

set -e

if [ "$#" -lt 1 ]; then
  echo "1 argument is required: <OS dir> [OPTIONAL: <size of image in MB>]"
  exit 1
fi

GIT_ROOT=$(git rev-parse --show-toplevel)
OS="$1"

# shellcheck disable=SC1090
. "${GIT_ROOT}/${OS}/vars"

DISK_IMG="${OS}.img"
DISK_SIZE="${2:-30G}" # default 30GB
FILES="${GIT_ROOT}/files"
SCRIPTS="${GIT_ROOT}/scripts"
CLOUD_INIT_IMG="cloud-init-${OS}.qcow2"

# Clean up first
"${SCRIPTS}"/clean_up.sh libvirt "$OS"

cd "$GIT_ROOT/$OS"

# prepare cloud init iso
cloud-localds -v --network-config=./libvirt/network-config "$CLOUD_INIT_IMG" "$FILES/user-data" "$FILES/meta-data"

# Clone and Resize disk image
if echo "$OS" | grep 'ubuntu'; then
  cp -f "$DOWNLOADED_IMG".img "$DISK_IMG"
else
  cp -f "$DOWNLOADED_IMG".qcow2 "$DISK_IMG"
fi
qemu-img resize "$DISK_IMG" +"$DISK_SIZE"

# Run kvm image
virt-install --name "$OS" \
  --connect qemu:///system \
  --import \
  --noautoconsole \
  --virt-type kvm \
  --memory 2048 \
  --vcpus 2 \
  --boot hd,menu=on \
  --disk path="$DISK_IMG",device=disk \
  --disk path="$CLOUD_INIT_IMG",device=disk \
  --os-variant "$OS" \
  --network network=default,model=virtio,mac="$MAC"

# clean known hosts
# shellcheck disable=SC2102
ssh-keygen -R "$IP_LIBVIRT" >/dev/null 2>&1

# Wait till machine is ready
echo "Waiting for machine to be ready ..."
until ssh -o "StrictHostKeyChecking no" -i "${FILES}/id_rsa.devel" root@"$IP_LIBVIRT" 'uptime' 2>/dev/null; do
  sleep 2
done

echo
echo "Machine successfully provisioned!"
echo "To log in use: ssh -i ${FILES}/id_rsa.devel root@${IP_LIBVIRT}"

exit 0
