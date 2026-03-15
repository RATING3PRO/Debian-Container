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

exec /usr/sbin/sshd -D -e
