#!/bin/sh

if [ "$#" -ne 1 ]; then
	echo "1 argument is required: <Virtualbox VM name>"
	exit 1
fi

OS="$1"

vboxmanage controlvm "$OS" poweroff 2>/dev/null
vboxmanage unregistervm --delete "$OS" 2>/dev/null
vboxmanage closemedium disk "$OS/$OS".vdi --delete 2>/dev/null
rm -f "$OS/$OS".vdi
