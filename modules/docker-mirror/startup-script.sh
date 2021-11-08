#!/usr/bin/env bash
set -euxo pipefail

# Alias the nvme devices to /dev/sdX.
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html#available-ec2-device-names
VOLUMES_NAME="$(find /dev -maxdepth 1 | grep -i 'nvme[0-21]n1$')"
for VOLUME in ${VOLUMES_NAME}; do
  ALIAS=$(nvme id-ctrl -H -v "${VOLUME}" | grep -Po '/dev/(sd[b-z]|xvd[b-z])')
  if [ -n "${ALIAS}" ]; then
    ln -s "${VOLUME}" "${ALIAS}"
  fi
done

REALPATH="$(realpath /dev/sdh)"
# Ensure /dev/sdh has a file system.
if [ "$(file -s "$REALPATH")" == "$REALPATH: data" ]; then
  mkfs.ext4 /dev/sdh
fi

# Mount /dev/sdh to /mnt/registry.
mkdir -p /mnt/registry
echo "/dev/sdh /mnt/registry ext4 defaults 0 2" >>/etc/fstab
mount -a
chown ubuntu:ubuntu /mnt/registry

# Enable and start the registry service.
systemctl enable docker_registry
systemctl start docker_registry
