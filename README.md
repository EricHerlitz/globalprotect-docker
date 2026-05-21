# GlobalProtect VPN client (GUI) in a Docker container with microsocks
## About this fork
This fork is a fork of [dmikushin/globalprotect-docker](https://github.com/dmikushin/globalprotect-docker) with the following changes:
- Use microsocks instead of socks5-proxy
- Use the latest version of GlobalProtect
- It will run in both Linux and WSL2 environments, if you are running it in a windows host ensure to start the container FROM the WSL terminal.

If you build this container in WSL you might need to install `libgtk-3-0` and `libnss3` packages manually.

**The entire idea behind this fork is to isolage GlobalProtect from the host system and to run it in a Docker container with microsocks. Thus having this option to run it in WSL and any other Linux based docker environment.**

The docker-compose file has a static route to ensure that the VPN connection is made available after the socks proxy is started.
`DOCKER_STATIC_ROUTES: 10.11.0.0/16 via 172.19.0.1 dev eth0` 

Modify this to your needs. If you are on a class C network you might need to change the CIDR to something like `192.168.1.0/24` of similar. But this must not overlap with any other network, which include the network of the VPN server.
172.19.0.1 is the address of the container.


## Overview
This is an implementation of GlobalProtect VPN client (GUI), which runs in a Docker container and exposes the VPN connection to the users as a SOCKS5 proxy via microsocks.

Technically, the Docker container runs a fork of [GlobalProtect-openconnect](https://github.com/yuezk/GlobalProtect-openconnect), redesigned to come as a single executable, without client-server separation.

<img src="screenshots/screenshot1.png"><img src="screenshots/screenshot2.png">

## Features

- Similar user experience as the official client in macOS.
- Supports both SAML and non-SAML authentication modes.
- Supports automatically selecting the preferred gateway from the multiple gateways.
- Supports switching gateway from the system tray menu manually.
- Memorizes credentials and authenticates automatically without a dialog.

# Docker
 
```
git clone --recurse-submodules https://github.com/EricHerlitz/globalprotect-docker.git
cd globalprotect-docker
docker build -t globalprotect-docker -f docker/Dockerfile .
docker-compose up -d
```
 
On the first run, navigate to `http://localhost:8083` or the address of your docker host in the web browser to provide authentication credentials. On subsequent invocations, the container will  try to use the cached credentials.

When the connection is established, configure your applications to use the provided SOCKS5 proxy. For example, Firefox:

**THIS FORK IS SETUP TO USE PORT 1080!**

<img src="screenshots/screenshot3.png">

## Manual Installation

Prerequisites:

```
sudo apt-get install -y \
     build-essential \
     qtbase5-dev \
     libqt5websockets5-dev \
     qtwebengine5-dev \
     qttools5-dev \
     qt5keychain-dev \
     openconnect
```

Building:

```
git clone --recurse-submodules https://github.com/EricHerlitz/globalprotect-docker.git
cd globalprotect-docker
mkdir build
cd build
cmake -G Ninja ..
cmake --build .
sudo cmake --install .
```

Without client-server separation, the binary must be executed with elevated priviledges:

```
sudo ./gpagent
```

## Troubleshooting

Run `docker-compose logs` in the Terminal and collect the logs.

