#!/usr/bin/env bash
set -euo pipefail

## Pull terraform variables into the environment. Tracing starts after this
## block so secrets passed inline don't land in the console output. Values are
## single-quoted so bash takes them literally, whatever characters they hold.
%{ for key, value in environment_variables }
${key}='${replace(value, "'", "'\\''")}'
%{ endfor ~}
set -x

# Hardware GRO packets can fail software segmentation inside Firecracker guests.
# systemd 250 introduced GenericReceiveOffloadHardware in .link files.
systemd_version=$(systemctl --version | awk 'NR == 1 {print $2}')
if [ "$systemd_version" -lt 250 ]; then
  echo "Executor hosts require systemd 250 or later to disable hardware GRO." >&2
  exit 1
fi

for interface in /sys/class/net/*; do
  [ -L "$interface/device/driver" ] || continue
  driver=$(basename "$(readlink "$interface/device/driver")")
  [ "$driver" = "ena" ] || continue

  # Preserve naming rules, including netplan files used only after a reboot.
  for link_file in /usr/lib/systemd/network/*.link /run/systemd/network/*.link /etc/systemd/network/*.link; do
    [ -f "$link_file" ] || continue
    link_drop_in="/etc/systemd/network/$(basename "$link_file").d"
    mkdir -p "$link_drop_in"
    cat >"$link_drop_in/90-executor-offloads.conf" <<'EOF'
[Link]
GenericReceiveOffloadHardware=no
EOF
  done

  # Startup runs after NIC initialization. Apply the setting on first boot too.
  features=$(ethtool -k "$(basename "$interface")")
  if grep -q '^rx-gro-hw: on' <<<"$features"; then
    ethtool -K "$(basename "$interface")" rx-gro-hw off
  fi
done
udevadm control --reload

# Conditionally set below
DOCKER_REGISTRY_NODE_EXPORTER_URL_LINE=''

# If a docker registry mirror is configured, create a startup script
# that will configure docker to use the mirror. This requires writing
# a docker configuration file and restarting the service.
if [ "$${EXECUTOR_DOCKER_REGISTRY_MIRROR}" != '' ]; then
  # Allow access to the docker registry from the VM.
  IP=$(echo $${EXECUTOR_DOCKER_REGISTRY_MIRROR} | grep -oE '//(.*?):' | sed 's/[\/:]//g')
  PORT=$(echo $${EXECUTOR_DOCKER_REGISTRY_MIRROR} | grep -oE "(:[0-9]{1,6})" | sed 's/://g')

  iptables -I CNI-ADMIN -p tcp -d $${IP} --dport $${PORT} -j ACCEPT

  # Store the iptables config.
  iptables-save >/etc/iptables/rules.v4

  if [ "$${DOCKER_REGISTRY_NODE_EXPORTER_URL}" != '' ]; then
    DOCKER_REGISTRY_NODE_EXPORTER_URL_LINE="DOCKER_REGISTRY_NODE_EXPORTER_URL=$${DOCKER_REGISTRY_NODE_EXPORTER_URL}"
  fi
fi

if [ "$${PRIVATE_CA_CERTIFICATE}" != '' ]; then
  echo "$${PRIVATE_CA_CERTIFICATE}" > /etc/ssl/certs/private_ca_cert.pem
fi

# Read the proxy password from Secrets Manager with the instance role. The AMI
# has no AWS CLI, so curl signs the request itself (--aws-sigv4) with the
# role's credentials from IMDSv2. Tracing is off here so the password and the
# credentials don't land in the console output; the credentials reach curl
# through its config on stdin, not the command line.
if [ "$${SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD_SECRET_NAME}" != '' ]; then
  set +x
  read_secret() {
    local imds_token role_name key_id secret_key session_token region curl_credentials
    imds_token=$(curl -sSf -X PUT -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' http://169.254.169.254/latest/api/token)
    role_name=$(curl -sSf -H "X-aws-ec2-metadata-token: $${imds_token}" http://169.254.169.254/latest/meta-data/iam/security-credentials/)
    read -r key_id secret_key session_token < <(curl -sSf -H "X-aws-ec2-metadata-token: $${imds_token}" \
      "http://169.254.169.254/latest/meta-data/iam/security-credentials/$${role_name}" \
      | python3 -c 'import json, sys; c = json.load(sys.stdin); print(c["AccessKeyId"], c["SecretAccessKey"], c["Token"])')
    region=$(cut -d: -f4 <<<"$${SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD_SECRET_NAME}")
    curl_credentials=$(printf '%s\n' \
      "user = \"$${key_id}:$${secret_key}\"" \
      "header = \"x-amz-security-token: $${session_token}\"")
    curl -sSf -X POST "https://secretsmanager.$${region}.amazonaws.com/" \
      --aws-sigv4 "aws:amz:$${region}:secretsmanager" --config - <<<"$${curl_credentials}" \
      -H 'x-amz-target: secretsmanager.GetSecretValue' -H 'content-type: application/x-amz-json-1.1' \
      -d "{\"SecretId\":\"$${SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD_SECRET_NAME}\"}" \
      | python3 -c 'import json, sys; print(json.load(sys.stdin)["SecretString"].rstrip("\n"))'
  }
  for attempt in 1 2 3 4 5; do
    SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD=$(read_secret) && break
    sleep $((attempt * 5))
  done
  if [ "$${SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD}" = '' ]; then
    echo "Could not read a non-empty executor proxy password from $${SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD_SECRET_NAME}" >&2
    exit 1
  fi
  set -x
fi

# Write the systemd environment file used by the executor service. It holds
# the proxy password and docker auth config, so only root may read it.
# Inside the double quotes below, systemd treats only backslash and double
# quote specially, so escape those two in the values that may contain them.
# Tracing is off here so the password doesn't land in the console output.
set +x
SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD=$${SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD//\\/\\\\}
SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD=$${SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD//\"/\\\"}
EXECUTOR_DOCKER_AUTH_CONFIG=$${EXECUTOR_DOCKER_AUTH_CONFIG//\\/\\\\}
EXECUTOR_DOCKER_AUTH_CONFIG=$${EXECUTOR_DOCKER_AUTH_CONFIG//\"/\\\"}
set -x
install -m 600 /dev/null /etc/systemd/system/executor.env
cat <<EOF >/etc/systemd/system/executor.env
EXECUTOR_QUEUE_NAME="$${EXECUTOR_QUEUE_NAME}"
EXECUTOR_QUEUE_NAMES="$${EXECUTOR_QUEUE_NAMES}"
EXECUTOR_MAXIMUM_RUNTIME_PER_JOB="$${EXECUTOR_MAXIMUM_RUNTIME_PER_JOB}"
EXECUTOR_MAXIMUM_NUM_JOBS="$${EXECUTOR_MAXIMUM_NUM_JOBS}"
EXECUTOR_JOB_NUM_CPUS="$${EXECUTOR_JOB_NUM_CPUS}"
EXECUTOR_JOB_MEMORY="$${EXECUTOR_JOB_MEMORY}"
EXECUTOR_FIRECRACKER_DISK_SPACE="$${EXECUTOR_FIRECRACKER_DISK_SPACE}"
EXECUTOR_FRONTEND_URL="$${SOURCEGRAPH_EXTERNAL_URL}"
EXECUTOR_FRONTEND_PASSWORD="$${SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD}"
EXECUTOR_NUM_TOTAL_JOBS="$${EXECUTOR_NUM_TOTAL_JOBS}"
EXECUTOR_MAX_ACTIVE_TIME="$${EXECUTOR_MAX_ACTIVE_TIME}"
EXECUTOR_USE_FIRECRACKER="$${EXECUTOR_USE_FIRECRACKER}"
EXECUTOR_DOCKER_REGISTRY_MIRROR_URL="$${EXECUTOR_DOCKER_REGISTRY_MIRROR}"
EXECUTOR_DOCKER_AUTH_CONFIG="$${EXECUTOR_DOCKER_AUTH_CONFIG}"
$${DOCKER_REGISTRY_NODE_EXPORTER_URL_LINE}
EOF

# Point the host's CloudWatch agent at the configured log group. The executor
# AMI ships syslog to a fixed "executors" group by default; when a specific
# (e.g. randomized) log group name is configured we reconfigure the agent at
# boot so multiple executor deployments in the same account/region don't collide
# on one shared log group.
if [ "$${CLOUDWATCH_LOG_GROUP_NAME}" != '' ]; then
  CLOUDWATCH_CONFIG_FILE_PATH=/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  if [ -x /usr/local/bin/configure-cloudwatch-agent-log-group ]; then
    # Newer executor AMIs ship a helper that owns the agent config layout.
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

# Enable and start the executor service
systemctl enable executor
systemctl start executor
