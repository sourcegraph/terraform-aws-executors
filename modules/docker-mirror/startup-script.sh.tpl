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

# The data volume is an NVMe device whose serial number is the volume ID
# without its hyphen, and udev links it under /dev/disk/by-id. That path is
# stable across reboots and device enumeration order, unlike the /dev/sdh
# name from the attachment, which nothing on Ubuntu creates.
# https://docs.aws.amazon.com/ebs/latest/userguide/identify-nvme-ebs-device.html
DATA_DEVICE="/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${replace(docker_storage_volume_id, "-", "")}"

# Wait until the volume is attached.
until test -e "$${DATA_DEVICE}"; do
  sleep 1
done

# Ensure the volume has a file system.
if [ -z "$(sudo blkid -s TYPE -o value "$${DATA_DEVICE}")" ]; then
  sudo mkfs.ext4 "$${DATA_DEVICE}"
fi

# Mount the volume to /mnt/registry.
sudo mkdir -p /mnt/registry
echo "$${DATA_DEVICE} /mnt/registry ext4 defaults 0 2" | sudo tee -a /etc/fstab
sudo mount -a
sudo chown ubuntu:ubuntu /mnt/registry

# Enable and start the registry service.
sudo systemctl enable docker_registry
sudo systemctl start docker_registry
