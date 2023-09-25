#!/bin/bash
# Credits to https://github.com/lavabit/robox

# If the apt configuration directory exists, we add our own config options.
if [ -d /etc/apt/apt.conf.d/ ]; then
  # Disable periodic activities of apt.
  printf "APT::Periodic::Enable \"0\";\n" > /etc/apt/apt.conf.d/10periodic

  # We disable APT retries, to avoid inconsistent error handling, as it only retries some errors. Instead we let the retry function detect, and retry a given command regardless of the error.
  printf "APT::Acquire::Retries \"0\";\n" > /etc/apt/apt.conf.d/20retries
fi

# Keep the daily apt updater from deadlocking our installs.
systemctl stop apt-daily.service apt-daily.timer

exit 0
