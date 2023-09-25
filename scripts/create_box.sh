#!/bin/sh

set -e

if [ "$#" -ne 1 ]; then
  echo "1 argument is required: <Virtualbox VM name>"
  exit 1
fi

GIT_ROOT=$(git rev-parse --show-toplevel)
OS="$1"

# shellcheck disable=SC1090
. "${GIT_ROOT}/${OS}/vars"

BOX="${GIT_ROOT}/${OS}/package-${BOX_VERSION}.box"

# Shutdown the VM
vboxmanage controlvm "$OS" acpipowerbutton 2> /dev/null

while vboxmanage showvminfo "$OS" | grep -c "running (since" >/dev/null
do
  echo "Waiting for machine to shutdown ..."
  sleep 1
done

if vboxmanage showvminfo "$OS" | grep -A1 'IDE Controller' | grep 'Port 0' >/dev/null
then
  # Clear any cdrom/iso mount
  vboxmanage storageattach "$OS" --storagectl "IDE Controller" \
    --port 0 --device 0 --type dvddrive --medium none
fi

# Export box
rm -f "${BOX}"
vagrant package --base "$OS" --output "${BOX}"
# Import box for testing
vagrant box list | grep "$OS"_"$BOX_VERSION" && vagrant box remove "$OS"_"$BOX_VERSION"
vagrant box add "${BOX}" --name "$OS"_"$BOX_VERSION"

exit 0
