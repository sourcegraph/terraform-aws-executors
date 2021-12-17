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

# Create a file system on /dev/sdh.
sudo mkfs.ext4 /dev/sdh

# Mount /dev/sdh to /mnt/data0.
sudo mkdir -p /mnt/data0
echo "/dev/sdh /mnt/data0 ext4 defaults 0 2" | sudo tee -a /etc/fstab
sudo mount -a
sudo chown ubuntu:ubuntu /mnt/data0

# Configure docker to put data in local disk.
mkdir -p /etc/docker
echo "{\"data-root\": [\"/mnt/data0\"]}" >/etc/docker/daemon.json
systemctl restart --now docker

## Pull terraform variables into the environment.
%{ for key, value in environment_variables }
${key}="${value}"
%{ endfor ~}

# Conditionally set below
STARTUP_SCRIPT_LINE=''

# If a docker registry mirror is configured, create a startup script
# that will configure docker to use the mirror. This requires writing
# a docker configuration file and restarting the service.
if [ "$${EXECUTOR_DOCKER_REGISTRY_MIRROR}" != '' ]; then
  cat <<EOF >/vm-startup.sh
set +ex
mkdir -p /etc/docker
echo "{\"registry-mirrors\": [\"$${EXECUTOR_DOCKER_REGISTRY_MIRROR}\"]}" > /etc/docker/daemon.json
systemctl restart --now docker
EOF

  chmod +x /vm-startup.sh
  STARTUP_SCRIPT_LINE='EXECUTOR_VM_STARTUP_SCRIPT_PATH=/vm-startup.sh'
fi

# Write the systemd environment file used by the executor service
cat <<EOF >/etc/systemd/system/executor.env
EXECUTOR_QUEUE_NAME="$${EXECUTOR_QUEUE_NAME}"
EXECUTOR_MAXIMUM_RUNTIME_PER_JOB="$${EXECUTOR_MAXIMUM_RUNTIME_PER_JOB}"
EXECUTOR_MAXIMUM_NUM_JOBS="$${EXECUTOR_MAXIMUM_NUM_JOBS}"
EXECUTOR_FIRECRACKER_NUM_CPUS="$${EXECUTOR_FIRECRACKER_NUM_CPUS}"
EXECUTOR_FIRECRACKER_MEMORY="$${EXECUTOR_FIRECRACKER_MEMORY}"
EXECUTOR_FIRECRACKER_DISK_SPACE="$${EXECUTOR_FIRECRACKER_DISK_SPACE}"
EXECUTOR_FRONTEND_URL="$${SOURCEGRAPH_EXTERNAL_URL}"
EXECUTOR_FRONTEND_PASSWORD="$${SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD}"
EXECUTOR_NUM_TOTAL_JOBS="$${EXECUTOR_NUM_TOTAL_JOBS}"
EXECUTOR_MAX_ACTIVE_TIME="$${EXECUTOR_MAX_ACTIVE_TIME}"
$${STARTUP_SCRIPT_LINE}
EOF

# Enable and start the executor service
systemctl enable executor
systemctl start executor
