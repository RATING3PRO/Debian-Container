set -e

if [ -n "${TZ}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
  ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
  echo "${TZ}" > /etc/timezone
fi

if [ -n "${SSH_PORT}" ]; then
  sed -i "s/^#\?Port .*/Port ${SSH_PORT}/" /etc/ssh/sshd_config
fi

if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
  ssh-keygen -A
fi

if id -u "${SSH_USER}" >/dev/null 2>&1; then
  true
else
  useradd -m -s /bin/bash "${SSH_USER}"
fi

if [ ! -d "/home/${SSH_USER}" ]; then
  mkdir -p "/home/${SSH_USER}"
fi
chown "${SSH_USER}:${SSH_USER}" "/home/${SSH_USER}"

echo "${SSH_USER}:${SSH_PASSWORD}" | chpasswd
usermod -aG sudo "${SSH_USER}"
echo "${SSH_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${SSH_USER}"
chmod 0440 "/etc/sudoers.d/${SSH_USER}"

if [ -n "${ROOT_PASSWORD}" ]; then
  echo "root:${ROOT_PASSWORD}" | chpasswd
fi

if [ "${SSH_ALLOW_PASSWORD_AUTH}" = "false" ]; then
  sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication no/" /etc/ssh/sshd_config
else
  sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication yes/" /etc/ssh/sshd_config
fi

if [ "${SSH_ALLOW_ROOT_LOGIN}" = "true" ]; then
  sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin yes/" /etc/ssh/sshd_config
else
  sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
fi

# Komari Agent Integration
if [ -n "${KOMARI_TOKEN}" ] && [ -n "${KOMARI_SERVER}" ]; then
  KOMARI_DIR="/opt/komari-agent"
  KOMARI_BIN="${KOMARI_DIR}/komari-agent"
  
  # Download and install if not present
  if [ ! -f "${KOMARI_BIN}" ]; then
    echo "Komari Agent not found, installing..."
    mkdir -p "${KOMARI_DIR}"
    
    # Detect architecture
    ARCH=$(uname -m)
    case "${ARCH}" in
      x86_64) KOMARI_ARCH="amd64" ;;
      aarch64) KOMARI_ARCH="arm64" ;;
      *) echo "Unsupported architecture for Komari Agent: ${ARCH}"; exit 1 ;;
    esac

    # Download latest release
    # Get latest version tag from GitHub redirect
    LATEST_VERSION=$(curl -sI "https://github.com/komari-monitor/komari-agent/releases/latest" | grep -i "location:" | awk -F '/' '{print $NF}' | tr -d '\r')
    
    if [ -z "${LATEST_VERSION}" ]; then
       echo "Error: Could not determine latest version tag. Please check network."
    else
       # Construct download URL with version
       DOWNLOAD_URL="https://github.com/komari-monitor/komari-agent/releases/download/${LATEST_VERSION}/komari-agent-linux-${KOMARI_ARCH}"
       
       echo "Downloading Komari Agent ${LATEST_VERSION} from ${DOWNLOAD_URL}..."
       curl -L -f -o "${KOMARI_BIN}" "${DOWNLOAD_URL}"
       
       if [ $? -eq 0 ]; then
         chmod +x "${KOMARI_BIN}"
         echo "Komari Agent installed successfully."
       else
         echo "Error: Failed to download Komari Agent from ${DOWNLOAD_URL}. Please check network connection."
         rm -f "${KOMARI_BIN}"
       fi
    fi
  fi

  if [ -f "${KOMARI_BIN}" ]; then
    echo "Starting Komari Agent..."
    # Build arguments - we construct the command string
    # Note: We use an array for arguments to handle spacing correctly if needed, 
    # but for simple flags string concatenation is often sufficient in sh.
    # However, to be safe with shell expansion:
    
    KOMARI_CMD="${KOMARI_BIN} -e ${KOMARI_SERVER} -t ${KOMARI_TOKEN}"
    
    # Note: host-id and hostname flags are not standard in all versions of komari-agent or might be auto-discovered.
    # Based on help output, there are no --host-id or --hostname flags.
    # If these are needed, they might need to be passed via config file or other means.
    # For now, we will skip adding them as flags to avoid errors, unless specific flags exist (e.g. --auto-discovery).
    
    if [ "${KOMARI_DISABLE_WEB_SSH}" = "true" ]; then
      KOMARI_CMD="${KOMARI_CMD} --disable-web-ssh"
    fi

    if [ "${KOMARI_DISABLE_AUTO_UPDATE}" = "true" ]; then
      KOMARI_CMD="${KOMARI_CMD} --disable-auto-update"
    fi

    if [ "${KOMARI_IGNORE_UNSAFE_CERT}" = "true" ]; then
      KOMARI_CMD="${KOMARI_CMD} --ignore-unsafe-cert"
    fi

    if [ "${KOMARI_MEMORY_INCLUDE_CACHE}" = "true" ]; then
      KOMARI_CMD="${KOMARI_CMD} --memory-include-cache"
    fi
    
    # --disable-command-exec and --disable-file-manager are not in the help output provided by user.
    # However, --disable-web-ssh IS in the help output.
    # Assuming other disable flags might not exist or were missed. 
    # Let's keep only validated flags based on user input log.
    # User log shows: --disable-web-ssh
    # It does NOT show: --disable-command-exec, --disable-file-manager, --host-id, --hostname
    
    # If user insists on other flags, they might need a newer version or check docs.
    # For stability, we remove unknown flags.
    
    # Run in background
    # We use 'nohup' and redirect output to log file
    echo "Executing: ${KOMARI_CMD}"
    nohup ${KOMARI_CMD} > /var/log/komari-agent.log 2>&1 &
    
    echo "Komari Agent started in background."
  else
    echo "Warning: Komari Agent binary not found at ${KOMARI_BIN}. Skipping start."
  fi
fi

exec /usr/sbin/sshd -D -e
