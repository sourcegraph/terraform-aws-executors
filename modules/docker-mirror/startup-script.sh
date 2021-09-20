#!/usr/bin/env bash
set -euxo pipefail

## Install Ops Agent for Google Cloud instances.
## Reference: https://cloud.google.com/logging/docs/agent/ops-agent/installation
function install_ops_agent() {
  curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
  sudo bash add-google-cloud-ops-agent-repo.sh --also-install
}

## Install CloudWatch agent for AWS instances.
## Reference: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html
function install_cloudwatch_agent() {
  wget -q https://s3.us-west-2.amazonaws.com/amazoncloudwatch-agent-us-west-2/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
  dpkg -i -E ./amazon-cloudwatch-agent.deb
  rm ./amazon-cloudwatch-agent.deb

  CLOUDWATCH_CONFIG_FILE_PATH=/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  cat <<EOF >"${CLOUDWATCH_CONFIG_FILE_PATH}"
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "sourcegraph_executors_docker_mirror",
            "timezone": "UTC"
          }
        ]
      }
    },
    "log_stream_name": "{instance_id}-syslog"
  }
}
EOF
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:"${CLOUDWATCH_CONFIG_FILE_PATH}"
}

## Install Docker
function install_docker() {
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  apt-get update -y
  apt-cache policy docker-ce
  apt-get install -y binutils docker-ce docker-ce-cli containerd.io

  DOCKER_DAEMON_CONFIG_FILE='/etc/docker/daemon.json'

  if [ ! -f "${DOCKER_DAEMON_CONFIG_FILE}" ]; then
    mkdir -p "$(dirname "${DOCKER_DAEMON_CONFIG_FILE}")"
    echo '{"log-driver": "journald"}' >"${DOCKER_DAEMON_CONFIG_FILE}"
  fi

  # Restart Docker daemon to pick up our changes.
  systemctl restart --now docker
}

## Run docker registry as a pull-through cache
## Reference: https://docs.docker.com/registry/recipes/mirror/
function setup_pull_through_docker_cache() {
  local DOCKER_REGISTRY_CONFIG_FILE='/etc/docker/registry_config.json'
  mkdir -p "$(dirname "${DOCKER_REGISTRY_CONFIG_FILE}")"
  cat <<EOF >"${DOCKER_REGISTRY_CONFIG_FILE}"
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
proxy:
  remoteurl: https://registry-1.docker.io
EOF

  # Run registry as a persistent daemon container.
  docker run -d --restart=always -p 5000:5000 -v ${DOCKER_REGISTRY_CONFIG_FILE}:/etc/docker/registry/config.yml --name registry registry:2
}

function cleanup() {
  apt-get -y autoremove
  apt-get clean
  rm -rf /var/cache/*
  rm -rf /var/lib/apt/lists/*
  history -c
}

# Prerequisites
## This endpoint only exists on EC2 instances, so it lets us distinguish between
## AWS and GCP.
if curl --fail -s --connect-timeout 5 http://169.254.169.254/latest/dynamic/instance-identity/; then
  install_cloudwatch_agent
else
  install_ops_agent
fi
install_docker

# Services
setup_pull_through_docker_cache

# Cleanup
cleanup
