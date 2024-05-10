#!/usr/bin/env bash

RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

export PATH="./scripts:$PATH"

ubuntu_vm="ubuntu22.04"
debian_vm="debian12"

function allowed_os() {
  if [ "$1" != "$ubuntu_vm" ] && [ "$1" != "$debian_vm" ]; then
    echo -e "${RED}Invalid argument: $1, use either '$ubuntu_vm' or '$debian_vm'${ENDCOLOR}"
    exit 1
  fi
}

case "$1" in
"libvirt")
  ./setup.sh create_vm libvirt
  ./setup.sh prepare_vm libvirt
  ./setup.sh create_box libvirt
  ;;
"virtualbox")
  ./setup.sh create_vm virtualbox
  ./setup.sh prepare_vm virtualbox
  ./setup.sh create_box virtualbox
  ;;
"download_latest")
  echo -e "${GREEN}Cleaning old files ...${ENDCOLOR}"
  rm -f ./"$ubuntu_vm"/*.img
  rm -f ./"$debian_vm"/*.raw
  rm -f ./"$debian_vm"/*.qcow2
  rm -f ./files/vboxtools.iso
  echo -e "${GREEN}Downloading latest ubuntu 22.04 image ...${ENDCOLOR}"
  wget -P ./"$ubuntu_vm" https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img
  echo -e "${GREEN}Downloading latest debian 12 image ...${ENDCOLOR}"
  wget -P ./"$debian_vm" https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.raw
  wget -P ./"$debian_vm" https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
  guest_tools_latest=$(curl https://download.virtualbox.org/virtualbox/LATEST-STABLE.TXT)
  echo -e "${GREEN}Downloading latest stable Virtualbox tools ${guest_tools_latest} ...${ENDCOLOR}"
  wget https://download.virtualbox.org/virtualbox/"${guest_tools_latest}"/VBoxGuestAdditions_"${guest_tools_latest}".iso \
    -O ./files/vboxtools.iso
  ;;
"create_vm")
  shift 1
  if [ "$1" = 'libvirt' ] || [ "$1" = 'virtualbox' ]; then
    TYPE="$1"
    shift 1
    case "$TYPE" in
    libvirt)
      if [ "$1" = "$ubuntu_vm" ] || [ "$1" = "$debian_vm" ]; then
        OS="$1"
        shift 1
        setup_libvirt_vm.sh "$OS" "$@"
      else
        setup_libvirt_vm.sh "$debian_vm" "$@"
        setup_libvirt_vm.sh "$ubuntu_vm" "$@"
      fi
      ;;
    virtualbox)
      if [ "$1" = "$ubuntu_vm" ] || [ "$1" = "$debian_vm" ]; then
        OS="$1"
        shift 1
        setup_vbox_vm.sh "$OS" "$@"
      else
        setup_vbox_vm.sh "$debian_vm" "$@"
        setup_vbox_vm.sh "$ubuntu_vm" "$@"
      fi
      ;;
    esac
  else
    # You must provide at least the type: libvirt or virtualbox
    echo -e "${RED}You must provide at least one argument: 'libvirt' or 'virtualbox'${ENDCOLOR}"
    exit 1
  fi
  ;;
"prepare_vm")
  # you can pass any number of ansible arguments
  # i.e. to remove snapd: ./setup.sh prepare_vm --extra-vars(or '-e') "remove_snapd=true"
  shift 1
  # Depending on the OS if it exists as first argument, we need to pass a limit to ansible-playbook
  if [ "$1" = 'libvirt' ] || [ "$1" = 'virtualbox' ]; then
    TYPE="$1"
    shift 1
    case "$TYPE" in
    libvirt)
      if [ "$1" = "$ubuntu_vm" ] || [ "$1" = "$debian_vm" ]; then
        OS="$1"
        shift 1
        ansible-playbook setup_host.yml -l "$OS"-libvirt "$@"
      else
        ansible-playbook setup_host.yml -l libvirt "$@"
      fi
      ;;
    virtualbox)
      if [ "$1" = "$ubuntu_vm" ] || [ "$1" = "$debian_vm" ]; then
        OS="$1"
        shift 1
        ansible-playbook setup_host.yml -l "$OS" "$@"
      else
        ansible-playbook setup_host.yml -l virtualbox "$@"
      fi
      ;;
    esac
  else
    # You must provide at least the type: libvirt or virtualbox
    echo -e "${RED}You must provide at least one argument: 'libvirt' or 'virtualbox'${ENDCOLOR}"
  fi
  ;;
"create_box")
  shift 1
  if [ "$1" = 'libvirt' ] || [ "$1" = 'virtualbox' ]; then
    TYPE="$1"
    shift 1
    case "$TYPE" in
    libvirt)
      if [ "$1" = "$ubuntu_vm" ] || [ "$1" = "$debian_vm" ]; then
        OS="$1"
        shift 1
        create_box.sh libvirt "$OS" "$@"
      else
        create_box.sh libvirt "$debian_vm" "$@"
        create_box.sh libvirt "$ubuntu_vm" "$@"
      fi
      ;;
    virtualbox)
      if [ "$1" = "$ubuntu_vm" ] || [ "$1" = "$debian_vm" ]; then
        OS="$1"
        shift 1
        create_box.sh virtualbox "$OS" "$@"
      else
        create_box.sh virtualbox "$debian_vm" "$@"
        create_box.sh virtualbox "$ubuntu_vm" "$@"
      fi
      ;;
    esac
  else
    # You must provide at least the type: libvirt or virtualbox
    echo -e "${RED}You must provide at least one argument: 'libvirt' or 'virtualbox'${ENDCOLOR}"
  fi
  ;;
"clean")
  shift 1
  if [ "$1" = 'libvirt' ] || [ "$1" = 'virtualbox' ]; then
    TYPE="$1"
    shift 1
    case "$TYPE" in
    libvirt)
      if [ -n "$1" ]; then
        allowed_os "$1"
        clean_up.sh libvirt "$1"
      else
        clean_up.sh libvirt "$debian_vm"
        clean_up.sh libvirt "$ubuntu_vm"
      fi
      ;;
    virtualbox)
      if [ -n "$1" ]; then
        allowed_os "$1"
        clean_up.sh virtualbox "$1"
      else
        clean_up.sh virtualbox "$debian_vm"
        clean_up.sh virtualbox "$ubuntu_vm"
      fi
      ;;
    esac
  else
    # we want to remove all boxes at the same time
    clean_up.sh libvirt "$debian_vm"
    clean_up.sh libvirt "$ubuntu_vm"
    clean_up.sh virtualbox "$debian_vm"
    clean_up.sh virtualbox "$ubuntu_vm"
  fi
  ;;
"publish")
  shift 1
  if [ -z "$1" ]; then
    echo -e "${RED}Please provide the box name to publish${ENDCOLOR}"
    exit 1
  fi
  if [ -z "$2" ]; then
    echo -e "${RED}Please provide the box provider to publish${ENDCOLOR}"
    exit 1
  fi
  . "${1}/vars"
  TYPE="$2"
  box="${1}/package-${BOX_VERSION}-${TYPE}.box"
  checksum=$(sha256sum "${box}" | awk '{print $1}')
  whoami=$(vagrant cloud auth whoami --no-tty | awk '{print $5}')
  vagrant cloud publish -f -c "$checksum" -C sha256 --no-private "$whoami"/"$1" "$BOX_VERSION" "$TYPE" "$box"
  echo -e "${RED}Need to set description and release it!${ENDCOLOR}"
  ;;
*)
  echo -e "\nSelect appropriate action:\n"
  echo -e "            ${GREEN}all${ENDCOLOR}:  Run everything except for publish: ./setup.sh all <--no-downloads>\n"
  echo -e "      ${GREEN}create_vm${ENDCOLOR}:  Create and run the virtualbox vm (download the images before running this command)\n \
     ubuntu 22.04:  ./setup.sh create_vm ubuntu22.04\n \
        debian 12:  ./setup.sh create_vm debian12\n \
        both vms:  ./setup.sh create_vm\n"
  echo -e "     ${GREEN}prepare_vm${ENDCOLOR}:  Prepare the vm using ansible\n"
  echo -e "     ${GREEN}create_box${ENDCOLOR}:  Convert the vm to a vagrant box: ./setup.sh create_box <debian12 | ubuntu22.04>\n"
  echo -e "${GREEN}download_latest${ENDCOLOR}:  Download the latest debian 12 and ubuntu 22.04 images\n"
  echo -e "          ${GREEN}clean${ENDCOLOR}:  Destroy and remove the vm and it's resources: ./setup.sh clean <debian12 | ubuntu22.04>\n"
  echo -e "        ${GREEN}publish${ENDCOLOR}:  Publish the box to vagrant cloud (you need to be logged in): ./setup.sh publish <debian12 | ubuntu22.04>\n"
  echo -e "Usage: ${GREEN}./setup.sh${ENDCOLOR} <all | create_vm | prepare_vm | create_box | download_latest | clean | publish>"
  exit 1
  ;;
esac

exit 0
