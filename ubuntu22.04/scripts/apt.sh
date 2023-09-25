#!/bin/bash -xe
# Credits to https://github.com/lavabit/robox

# Disable upgrades to new releases, and prevent notifications from being added to motd.
sed -i -e 's/^Prompt=.*$/Prompt=never/' /etc/update-manager/release-upgrades

if [ -f /usr/lib/ubuntu-release-upgrader/release-upgrade-motd ]; then
cat <<-EOF > /usr/lib/ubuntu-release-upgrader/release-upgrade-motd
#!/bin/sh
if [ -d /var/lib/ubuntu-release-upgrader/ ]; then
  date +%s > /var/lib/ubuntu-release-upgrader/release-upgrade-available
fi
exit 0
EOF
fi

# If the APT configuration directory exists, we add our own config options.
if [ -d /etc/apt/apt.conf.d/ ]; then

  # Disable APT periodic so it doesn't cause problems.
  if [ -f  /etc/apt/apt.conf.d/10periodic ]; then
    sed -i "/^APT::Periodic::Enable/d" /etc/apt/apt.conf.d/10periodic
    sed -i "/^APT::Periodic::AutocleanInterval/d" /etc/apt/apt.conf.d/10periodic
    sed -i "/^APT::Periodic::Unattended-Upgrade/d" /etc/apt/apt.conf.d/10periodic
    sed -i "/^APT::Periodic::Update-Package-Lists/d" /etc/apt/apt.conf.d/10periodic
    sed -i "/^APT::Periodic::Download-Upgradeable-Packages/d" /etc/apt/apt.conf.d/10periodic
  fi

cat <<-EOF >> /etc/apt/apt.conf.d/10periodic

APT::Periodic::Enable "0";
APT::Periodic::AutocleanInterval "0";
APT::Periodic::Unattended-Upgrade "0";
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";

EOF

# We disable APT retries, to avoid inconsistent error handling, as it only retries some errors. Instead we let the retry function detect, and retry a given command regardless of the error.
cat <<-EOF > /etc/apt/apt.conf.d/20retries

APT::Acquire::Retries "0";

EOF

fi

# Stop the active services/timers.
systemctl stop apt-daily.timer
systemctl stop apt-daily-upgrade.timer
systemctl stop update-notifier-download.timer
systemctl stop apt-daily.service
systemctl stop packagekit.service
systemctl stop apt-daily-upgrade.service
systemctl stop unattended-upgrades.service
systemctl stop update-notifier-download.service

# Disable them so they don't restart.
systemctl disable apt-daily.timer
systemctl disable apt-daily-upgrade.timer
systemctl disable update-notifier-download.timer
systemctl disable unattended-upgrades.service
systemctl mask apt-daily.service
systemctl mask apt-daily-upgrade.service
systemctl mask update-notifier-download.service

exit 0
