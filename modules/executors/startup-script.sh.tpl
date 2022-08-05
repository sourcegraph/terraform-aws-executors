#!/usr/bin/env bash
set -euxo pipefail

## Pull terraform variables into the environment.
%{ for key, value in environment_variables }
${key}="${value}"
%{ endfor ~}

# Conditionally set below
STARTUP_SCRIPT_LINE=''
DOCKER_REGISTRY_NODE_EXPORTER_URL_LINE=''

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

  IP=$(echo $${EXECUTOR_DOCKER_REGISTRY_MIRROR} | grep -oE '//(.*?):' | sed 's/[\/:]//g')
  PORT=$(echo $${EXECUTOR_DOCKER_REGISTRY_MIRROR} | grep -oE "(:[0-9]{1,6})" | sed 's/://g')

  iptables -I CNI-ADMIN -p tcp -d $${IP} -dport $${PORT}

  # Store the iptables config.
  iptables-save >/etc/iptables-store.conf
  # And make sure it gets loaded on boot.
  cat <<EOF >/etc/network/if-up.d/iptables
#!/bin/sh
iptables-restore < /etc/iptables-store.conf
EOF
  chmod +x /etc/network/if-up.d/iptables

  chmod +x /vm-startup.sh
  STARTUP_SCRIPT_LINE='EXECUTOR_VM_STARTUP_SCRIPT_PATH=/vm-startup.sh'

  if [ "$${DOCKER_REGISTRY_NODE_EXPORTER_URL}" != '' ]; then
    DOCKER_REGISTRY_NODE_EXPORTER_URL_LINE="DOCKER_REGISTRY_NODE_EXPORTER_URL=$${DOCKER_REGISTRY_NODE_EXPORTER_URL}"
  fi
fi

# Write the systemd environment file used by the executor service
cat <<EOF >/etc/systemd/system/executor.env
EXECUTOR_QUEUE_NAME="$${EXECUTOR_QUEUE_NAME}"
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
$${STARTUP_SCRIPT_LINE}
$${DOCKER_REGISTRY_NODE_EXPORTER_URL_LINE}
EOF

# Enable and start the executor service
systemctl enable executor
systemctl start executor
