#!/bin/sh

if [ "$#" -ne 2 ]; then
  echo "2 arguments are required: virtualization type (libvirt or virtualbox) and OS"
  exit 1
fi

GIT_ROOT=$(git rev-parse --show-toplevel)
TYPE="$1"
OS="$2"

# shellcheck disable=SC1090
. "${GIT_ROOT}/${OS}/vars"

if [ "$TYPE" = 'libvirt' ]; then
  echo "Cleaning libvirt $OS"
  virsh destroy "$OS" 2>/dev/null
  virsh undefine "$OS" --nvram --remove-all-storage 2>/dev/null
  # Clean vagrant box in libvirt default pool after, if it exists
  VOL_TO_RM=$(virsh vol-list --pool default | grep "$OS"_"$BOX_VERSION" | awk '{print $1}')
  [ -n "$VOL_TO_RM" ] && virsh vol-delete --pool default "$VOL_TO_RM"
  rm -f "${GIT_ROOT}/${OS}/cloud-init-$OS".qcow2
  rm -f "${GIT_ROOT}/${OS}/$OS".img
else
  echo "Cleaning Virtualbox $OS"
  vboxmanage controlvm "$OS" poweroff 2>/dev/null
  vboxmanage unregistervm --delete "$OS" 2>/dev/null
  vboxmanage closemedium dvd "${GIT_ROOT}/files/cloud-init-virtualbox.iso" --delete 2>/dev/null
  if echo "$OS" | grep -q ubuntu; then
    rm -f "${GIT_ROOT}/${OS}"/*.raw
  fi
  rm -f "${GIT_ROOT}/${OS}"/*.vdi
fi

# Clean up vagrant box used for testing
vagrant box list | grep "$OS"_"$BOX_VERSION" && vagrant box remove "$OS"_"$BOX_VERSION" --provider "$TYPE"

exit 0
