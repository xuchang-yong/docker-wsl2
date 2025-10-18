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
Open PowerShell, navigate to the repository folder, and run:
```powershell
cd "C:\Users\yxuchang\OneDrive - Capgemini\Documents\999. Dev\docker-wsl2"

# Example: create context for Ubuntu-22.04 on port 2375 and set it as default
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



# Part 1 - Installing docker on WSL2. Use Ubuntu WSL2 if possible.

# Step 1: Check that systemd is working

systemctl status | grep -I State:

# Step 1.1 - if systemd is not working, then check in /etc/wsl.conf if it is booted by default, if not run the following:
{
cat <<EOT
[boot]
systemd=true
EOT
} | sudo tee /etc/wsl.conf

# Step 2: Update Environment

sudo apt update && sudo apt upgrade -y

# Step 3: Install required dependencies

sudo apt install apt-transport-https ca-certificates curl software-properties-common -y

# Step 4: Download and add Docker GPG keys

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Step 5: Add stable repo

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Step 6: Install Docker. If root is required, perform sudo su before installing.

sudo apt update && apt install -y docker-ce docker-ce-cli containerd.io

# Step 7: Exit and restart wsl as well
# Ubuntu
exit
# WSL
wsl --shutdown

# Step 8: Open WSL2 distro and launch docker

sudo service docker start

# Step 8.1: If service will not start, update iptables by selecting "1" for "iptables-legacy".

sudo update-alternatives --config iptables

# Step 9: Verify Docker is running

sudo docker --version

# Step 10: Test if docker container can run

sudo docker run --rm -it hello-world

# Step 11 - Add daemon for docker to run on both local socket and discoverable via tcp

mkdir /etc/docker

{
cat <<EOT
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"],  # host sockets
  "tls": false,
  "ip-forward": true, # add this line for ip forwarding
  "iptables": true    # add this line to turn on iptables legacy
}
EOT
} | sudo tee /etc/docker/daemon.json

# Step 11 - Restart systemd daemon and docker service, and check if docker can be accessible on both sockets.

sudo systemctl daemon-reload
sudo systemctl restart docker

sudo docker -H 127.0.0.1 --rm -it hello-world
sudo docker run --rm -it hello-world

# Step 11.1 - If there is issue, check whether docker service is running:

systemctl status docker
# check if there is a tcp port 2375 listening
ss -peanut

# Step 11.2 - Add systemd docker service override if there are issues

mkdir /etc/systemd/system/docker.service.d
{
cat <<EOT
[Services]
ExecStart=
ExecStart=/usr/bin/dockerd
EOT
} | sudo tee /etc/systemd/system/docker.service.d/override.json


# Step 101.1 - Optional - Add current user to launch Docker without sudo

sudo usermod -aG docker $USER


# Part 2 - Install docker on windows host

# Step 1 - Check if Chocolatey is installed in windows

choco --version

# Step 1.1 - If there is no chocolatey, download and install it:

https://community.chocolatey.org/install.ps1

# Step 2 - Install docker-cli

choco install docker-cli

# Step 3 - Set WSL2 docker into docker context

# Step 3.1 - Verify that the remote WSL2 docker has exposed the tcp connection

See your `daemon.json` for:  
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"]
}

# Step 3.2 - Run powershell script

   ```powershell
   # Example for Ubuntu WSL2, using port 2375, and setting as default context
   .\docker-wsl2-context.ps1 -Wsl2VmName "Ubuntu-22.04" -Port 2375 -SetDefault $true
   ```
   - Replace `"Ubuntu-22.04"` with the name of your WSL2 distro (see `wsl -l` for a list).
   - Change `-Port` if your Docker daemon uses a different port.
   - Set `-SetDefault $false` if you do **not** want to make this the default Docker context.

4. **Verify the context**

   ```powershell
   docker context ls
   ```

   You should see a context named like `wsl2-Ubuntu-22.04` (or your distro name), and it will be marked as the default if you used `-SetDefault $true`.

5. **Test Docker CLI**

   ```powershell
   docker info
   docker run --rm hello-world
   ```

   These commands should now connect to your WSL2 Docker engine.

---

## Troubleshooting

- **Connection errors?**
  - Make sure Docker is running in your WSL2 distro:  
    `sudo service docker start` or `sudo systemctl start docker`
  - Ensure the Docker daemon is listening on the TCP port (check `/etc/docker/daemon.json`).
  - Check your firewall settings.

- **Wrong WSL2 distro name?**
  - Run `wsl -l` in PowerShell to list available distributions.

- **Want to remove a context?**
  ```powershell
  docker context rm <context-name>
  ```

---

## Script Parameters

- `-Wsl2VmName` (required): Name of your WSL2 distribution.
- `-Port` (required): TCP port Docker is listening on (default is 2375).
- `-SetDefault` (optional): Set the new context as default (`$true` or `$false`, default is `$true`).

---

Enjoy seamless Docker CLI integration with your WSL2 environment!