#!/bin/sh

if [ "$#" -ne 1 ]; then
  echo "1 argument is required: <Virtualbox VM name>"
  exit 1
fi

GIT_ROOT=$(git rev-parse --show-toplevel)
OS="$1"

vboxmanage controlvm "$OS" poweroff 2>/dev/null
vboxmanage unregistervm --delete "$OS" 2>/dev/null
vboxmanage closemedium dvd "${GIT_ROOT}/files/cloud-init.iso" --delete 2>/dev/null

if echo "$OS" | grep -q ubuntu
then
  rm -f "${GIT_ROOT}/${OS}"/*.raw
fi

exit 0
