#!/usr/bin/env bash
set -euo pipefail

## Pull terraform variables into the environment. Tracing starts after this
## block so secrets passed inline don't land in the console output.
%{ for key, value in environment_variables }
${key}="${replace(value, "\"", "\\\\\\\"")}"
%{ endfor ~}
set -x

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
# has no AWS CLI, so the request is signed (SigV4) with the Python standard
# library. Tracing is off here so the password and the role credentials don't
# land in the console output.
if [ "$${SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD_SECRET}" != '' ]; then
  set +x
  for attempt in 1 2 3 4 5; do
    SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD=$(python3 - "$${SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD_SECRET}" "$${SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD_SECRET_KEY}" <<'PYTHON'
import datetime, hashlib, hmac, json, sys, urllib.request

secret_arn, secret_key = sys.argv[1], sys.argv[2]
region = secret_arn.split(":")[3]


def metadata(path, token=None):
    headers = {"X-aws-ec2-metadata-token": token} if token else {"X-aws-ec2-metadata-token-ttl-seconds": "60"}
    request = urllib.request.Request("http://169.254.169.254" + path, headers=headers, method="GET" if token else "PUT")
    return urllib.request.urlopen(request, timeout=5).read().decode()


token = metadata("/latest/api/token")
role_name = metadata("/latest/meta-data/iam/security-credentials/", token)
credentials = json.loads(metadata("/latest/meta-data/iam/security-credentials/" + role_name, token))

host = f"secretsmanager.{region}.amazonaws.com"
body = json.dumps({"SecretId": secret_arn})
now = datetime.datetime.now(datetime.timezone.utc)
amz_date, date_stamp = now.strftime("%Y%m%dT%H%M%SZ"), now.strftime("%Y%m%d")
headers = {  # sorted by name, as SigV4 canonicalisation requires
    "content-type": "application/x-amz-json-1.1",
    "host": host,
    "x-amz-date": amz_date,
    "x-amz-security-token": credentials["Token"],
    "x-amz-target": "secretsmanager.GetSecretValue",
}
signed_headers = ";".join(headers)
canonical_request = "\n".join(["POST", "/", "", *(f"{name}:{value}" for name, value in headers.items()), "", signed_headers, hashlib.sha256(body.encode()).hexdigest()])
scope = f"{date_stamp}/{region}/secretsmanager/aws4_request"
string_to_sign = "\n".join(["AWS4-HMAC-SHA256", amz_date, scope, hashlib.sha256(canonical_request.encode()).hexdigest()])


def sign(key, message):
    return hmac.new(key, message.encode(), hashlib.sha256).digest()


signing_key = sign(sign(sign(sign(("AWS4" + credentials["SecretAccessKey"]).encode(), date_stamp), region), "secretsmanager"), "aws4_request")
signature = hmac.new(signing_key, string_to_sign.encode(), hashlib.sha256).hexdigest()
headers["authorization"] = f"AWS4-HMAC-SHA256 Credential={credentials['AccessKeyId']}/{scope}, SignedHeaders={signed_headers}, Signature={signature}"

request = urllib.request.Request(f"https://{host}/", data=body.encode(), headers=headers, method="POST")
payload = json.load(urllib.request.urlopen(request, timeout=10))["SecretString"]
print(json.loads(payload)[secret_key] if secret_key else payload.rstrip("\n"))
PYTHON
    ) && break
    sleep $((attempt * 5))
  done
  if [ "$${SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD}" = '' ]; then
    echo "Could not read a non-empty executor proxy password from $${SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD_SECRET}" >&2
    exit 1
  fi
  set -x
fi

# Write the systemd environment file used by the executor service. It holds
# the proxy password and docker auth config, so only root may read it.
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
