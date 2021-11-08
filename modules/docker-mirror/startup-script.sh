#!/usr/bin/env bash
set -euxo pipefail

# Alias the nvme devices to /dev/sdX.
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html#available-ec2-device-names
VOLUMES_NAME="$(find /dev -maxdepth 1 | grep -i 'nvme[0-21]n1$')"
for VOLUME in ${VOLUMES_NAME}; do
  ALIAS=$(sudo nvme id-ctrl -H -v "${VOLUME}" | { grep -Po '/dev/(sd[b-z]|xvd[b-z])' || test $? = 1; })
  if [ -n "${ALIAS}" ]; then
    sudo ln -s "${VOLUME}" "${ALIAS}"
  fi
done

REALPATH="$(realpath /dev/sdh)"
# Ensure /dev/sdh has a file system.
if [ "$(file -s "$REALPATH")" == "$REALPATH: data" ]; then
  sudo mkfs.ext4 /dev/sdh
fi

# Mount /dev/sdh to /mnt/registry.
sudo mkdir -p /mnt/registry
echo "/dev/sdh /mnt/registry ext4 defaults 0 2" | sudo tee -a /etc/fstab
sudo mount -a
sudo chown ubuntu:ubuntu /mnt/registry

# Enable and start the registry service.
sudo systemctl enable docker_registry
sudo systemctl start docker_registry
