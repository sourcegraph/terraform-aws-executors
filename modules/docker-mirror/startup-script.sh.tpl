#!/usr/bin/env bash
set -euxo pipefail

# Pull the terraform-provided CloudWatch log group name into the environment.
CLOUDWATCH_LOG_GROUP_NAME="${cloudwatch_log_group_name}"

# Point the host's CloudWatch agent at the configured log group. The docker-mirror
# AMI ships syslog to a fixed "executors_docker_mirror" group by default; when a
# specific (e.g. randomized) log group name is configured we reconfigure the agent
# at boot so multiple deployments in the same account/region don't collide on one
# shared log group.
if [ "$${CLOUDWATCH_LOG_GROUP_NAME}" != '' ]; then
  CLOUDWATCH_CONFIG_FILE_PATH=/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  if [ -x /usr/local/bin/configure-cloudwatch-agent-log-group ]; then
    # Newer AMIs ship a helper that owns the agent config layout.
    /usr/local/bin/configure-cloudwatch-agent-log-group "$${CLOUDWATCH_LOG_GROUP_NAME}"
  elif [ -x /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl ]; then
    # Fallback for AMIs predating the helper: (re)write the agent config with the
    # desired log group name and reload. fetch-config consumes this file into the
    # agent's own managed config, so we always write it fresh rather than assume
    # the build-time source file is still present.
    cat <<CWCONFIG >"$${CLOUDWATCH_CONFIG_FILE_PATH}"
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "$${CLOUDWATCH_LOG_GROUP_NAME}",
            "timezone": "UTC"
          }
        ]
      }
    },
    "log_stream_name": "{instance_id}-syslog"
  }
}
CWCONFIG
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:"$${CLOUDWATCH_CONFIG_FILE_PATH}"
  fi
fi

# Wait until the block device is attached.
while true; do
  sleep 1
  test -e /dev/nvme1n1 && break
done

# Alias the nvme devices to /dev/sdX.
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html#available-ec2-device-names
VOLUMES_NAME="$(find /dev -maxdepth 1 | grep -i 'nvme[0-21]n1$')"
for VOLUME in $${VOLUMES_NAME}; do
  ALIAS=$(sudo nvme id-ctrl -H -v "$${VOLUME}" | { grep -Po '/dev/(sd[b-z]|xvd[b-z])' || test $? = 1; })
  if [ -n "$${ALIAS}" ]; then
    sudo ln -s "$${VOLUME}" "$${ALIAS}"
  fi
done

REALPATH="$(realpath /dev/sdh)"
# Ensure /dev/sdh has a file system.
if [ "$(sudo file -s "$REALPATH")" == "$REALPATH: data" ]; then
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
