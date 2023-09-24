#!/bin/sh

set -e

if [ "$#" -ne 1 ]; then
  echo "1 argument is required: <Virtualbox VM name>"
  exit 1
fi

OS="$1"

. "$OS/vars"

ansible-playbook setup_host.yml

# Shutdown the VM
vboxmanage controlvm "$OS" acpipowerbutton

while vboxmanage showvminfo "$OS" | grep -c "running (since" >/dev/null
do
  echo "Waiting for machine to shutdown ..."
  sleep 1
done

# Clear any cdrom/iso mount
vboxmanage storageattach "$OS" --storagectl "IDE Controller" \
  --port 0 --device 0 --type dvddrive --medium none

# Export box
vagrant package --base "$OS" --output "$OS/package-$BOX_VERSION".box
# Import box for testing
vagrant box add "$OS/package-$BOX_VERSION".box --name "$OS"_"$BOX_VERSION" --force