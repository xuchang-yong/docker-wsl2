# Docker on WSL2 — Install and Configure (Ubuntu recommended)

This guide shows how to install Docker inside a WSL2 distribution (Ubuntu recommended), expose the Docker daemon on a TCP port, and add a Docker context on Windows so the Windows Docker CLI can target the WSL2 engine.

## Part 1 — Install and configure Docker inside WSL2

### 1. Verify systemd (recommended)
Check if systemd is available:
```bash
systemctl status | grep -i state
```
If systemd is not enabled, ensure `/etc/wsl.conf` contains:
```ini
[boot]
systemd=true
```
If needed, add it:
```bash
sudo tee /etc/wsl.conf > /dev/null <<'EOT'
[boot]
systemd=true
EOT
```
Then restart WSL from Windows:
```powershell
wsl --shutdown
# reopen your distro afterwards
```

### 2. Update packages
```bash
sudo apt update && sudo apt upgrade -y
```

### 3. Install required dependencies
```bash
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg
```

### 4. Add Docker GPG key and repo
```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### 5. Install Docker
```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
```

### 6. Start Docker and enable on boot
Start the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now docker
```
If service fails to start, check status:
```bash
systemctl status docker
journalctl -u docker --no-pager | tail -n 200
```

### 7. Expose Docker daemon on TCP (for Windows Docker CLI)
Create `/etc/docker/daemon.json` with the TCP listener and unix socket. Use a valid JSON file (no comments):
```json
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"],  # host sockets
  "tls": false,
  "ip-forward": true, # add this line for ip forwarding
  "iptables": true    # add this line to turn on iptables legacy
}
```
Write the file:
```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<'EOT'
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"],
  "tls": false,
  "ip-forward": true,
  "iptables": true
}
EOT
```
Then restart Docker:
```bash
sudo systemctl restart docker
```
Verify listening port:
```bash
ss -tulpen | grep 2375
```
Test locally:
```bash
docker -H tcp://127.0.0.1:2375 info
docker -H tcp://127.0.0.1:2375 run --rm hello-world
```

> Notes:
> - Exposing Docker over TCP without TLS is insecure. Use only on trusted networks or add TLS.
> - If iptables alternatives are needed, run `sudo update-alternatives --config iptables` and select `iptables-legacy` if required by your distro/docker setup.

### 8. Optional: run Docker without sudo
Add your user to the docker group (log out/in or restart shell after):
```bash
sudo usermod -aG docker $USER
newgrp docker
```

## Part 2 — Configure Windows host to use the WSL2 Docker daemon

### Prerequisites on Windows
- Docker CLI installed on Windows (e.g., `choco install docker-cli`) or Docker Desktop CLI available.
- PowerShell script `docker-wsl2-context.ps1` (included in this repo) to create a Docker context that points to the WSL2 TCP endpoint.

### 1. Verify WSL2 daemon is listening
From Windows PowerShell:
```powershell
# inside Windows PowerShell
wsl -d <YourDistroName> -- ss -tulpen | Select-String 2375
# or test using docker client:
docker -H tcp://<WSL_IP>:2375 info
```

To get WSL distro name(s):
```powershell
wsl -l -v
```

### 2. Run the helper script to add Docker context
Open PowerShell, navigate to the repository folder, and run `docker-wsl2-context.ps1`.

#### Example: create context for Ubuntu-22.04 on port 2375 and set it as default
```powershell
.\docker-wsl2-context.ps1 -Wsl2VmName "Ubuntu-22.04" -Port 2375 -SetDefault $true
```
Script parameters:
- `-Wsl2VmName` (required) — WSL distro name shown by `wsl -l`.
- `-Port` (optional) — TCP port Docker listens on inside WSL (default: 2375).
- `-SetDefault` (optional) — `$true` to make the new context the default for Docker CLI.

### 3. Verify and test the new Docker context
```powershell
docker context ls
docker --context wsl2-<YourDistroName> info
docker --context wsl2-<YourDistroName> run --rm hello-world
```
If you set the context as default, plain `docker info` and `docker run` should target the WSL2 engine.

## Troubleshooting

- If the script cannot determine the WSL IP:
  - Ensure the distro is running: `wsl -d <name> -- bash -lc "echo running"`
  - Manually obtain the WSL IP inside the distro: `hostname -I` or from Windows `wsl -d <name> -- hostname -I`.

- If Docker fails to start in WSL2:
  - Check `systemctl status docker` and `journalctl -u docker`.
  - Try switching iptables backend: `sudo update-alternatives --config iptables`.

- Firewall/Connectivity:
  - Ensure Windows firewall allows connecting to the WSL2 IP/port if you are using a routed approach.
  - For local-only usage, prefer connecting to 127.0.0.1 forwarding or use SSH/tunneling.

## Security reminder
Exposing Docker over TCP without TLS allows anyone who can reach the port to control your Docker daemon. Use TLS or restrict access to trusted hosts/networks.

---

Enjoy seamless Docker CLI integration with your WSL2 environment!
