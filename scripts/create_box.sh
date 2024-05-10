#!/bin/sh

set -e

if [ "$#" -ne 2 ]; then
  echo "2 arguments are required: virtualization type (libvirt or virtualbox) and OS"
  exit 1
fi

GIT_ROOT=$(git rev-parse --show-toplevel)
TYPE="$1"
OS="$2"

# shellcheck disable=SC1090
. "${GIT_ROOT}/${OS}/vars"

BOX="${GIT_ROOT}/${OS}/package-${BOX_VERSION}-${TYPE}.box"
rm -f "${BOX}"

if [ "$TYPE" = 'libvirt' ]; then
  # Shutdown the VM
  virsh list --state-running | grep "$OS" && virsh shutdown "$OS"
  # Wait for the VM to shutdown
  echo "Waiting for machine to shutdown ..."
  until virsh list --state-shutoff | grep "$OS" 2>/dev/null; do
    sleep 1
  done
  # System prep
  echo "Syspreping $OS"
  virt-sysprep -a "$GIT_ROOT/$OS/$OS.img" --operations machine-id --firstboot-command 'dpkg-reconfigure openssh-server'
  # Create box
  "$GIT_ROOT/files/libvirt/create_box.sh" "$GIT_ROOT/$OS/$OS.img" "$BOX"
else
  # Shutdown the VM
  vboxmanage controlvm "$OS" acpipowerbutton 2>/dev/null || echo "Machine is already off"

  while vboxmanage showvminfo "$OS" | grep -c "running (since" >/dev/null; do
    echo "Waiting for machine to shutdown ..."
    sleep 1
  done

  if vboxmanage showvminfo "$OS" | grep -A1 'IDE Controller' | grep 'Port 0' >/dev/null; then
    # Clear any cdrom/iso mount
    vboxmanage storageattach "$OS" --storagectl "IDE Controller" \
      --port 0 --device 0 --type dvddrive --medium none
  fi
  vagrant package --base "$OS" --output "${BOX}"
fi

# Import box for testing
vagrant box list | grep "$OS"_"$BOX_VERSION" && vagrant box remove "$OS"_"$BOX_VERSION" --provider "$TYPE"
vagrant box add "${BOX}" --name "$OS"_"$BOX_VERSION" --provider "$TYPE"

exit 0
