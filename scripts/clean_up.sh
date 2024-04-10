#!/bin/sh

if [ "$#" -ne 1 ]; then
  echo "1 argument is required: <Virtualbox VM name>"
  exit 1
fi

GIT_ROOT=$(git rev-parse --show-toplevel)
OS="$1"

# shellcheck disable=SC1090
. "${GIT_ROOT}/${OS}/vars"

# Clean up VM
vboxmanage controlvm "$OS" poweroff 2>/dev/null
vboxmanage unregistervm --delete "$OS" 2>/dev/null
vboxmanage closemedium dvd "${GIT_ROOT}/files/cloud-init.iso" --delete 2>/dev/null

if echo "$OS" | grep -q ubuntu
then
  rm -f "${GIT_ROOT}/${OS}"/*.raw
fi

# Clean up vagrant box
rm -f "${GIT_ROOT}/${OS}/package-${BOX_VERSION}.box"
vagrant box list | grep "$OS"_"$BOX_VERSION" && vagrant box remove "$OS"_"$BOX_VERSION"

exit 0
