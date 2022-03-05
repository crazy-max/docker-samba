<p align="center"><a href="https://github.com/crazy-max/docker-samba" target="_blank"><img height="128" src="https://raw.githubusercontent.com/crazy-max/docker-samba/master/.github/docker-samba.jpg"></a></p>

<p align="center">
  <a href="https://hub.docker.com/r/crazymax/samba/tags?page=1&ordering=last_updated"><img src="https://img.shields.io/github/v/tag/crazy-max/docker-samba?label=version&style=flat-square" alt="Latest Version"></a>
  <a href="https://github.com/crazy-max/docker-samba/actions?workflow=build"><img src="https://img.shields.io/github/workflow/status/crazy-max/docker-samba/build?label=build&logo=github&style=flat-square" alt="Build Status"></a>
  <a href="https://hub.docker.com/r/crazymax/samba/"><img src="https://img.shields.io/docker/stars/crazymax/samba.svg?style=flat-square&logo=docker" alt="Docker Stars"></a>
  <a href="https://hub.docker.com/r/crazymax/samba/"><img src="https://img.shields.io/docker/pulls/crazymax/samba.svg?style=flat-square&logo=docker" alt="Docker Pulls"></a>
  <br /><a href="https://github.com/sponsors/crazy-max"><img src="https://img.shields.io/badge/sponsor-crazy--max-181717.svg?logo=github&style=flat-square" alt="Become a sponsor"></a>
  <a href="https://www.paypal.me/crazyws"><img src="https://img.shields.io/badge/donate-paypal-00457c.svg?logo=paypal&style=flat-square" alt="Donate Paypal"></a>
</p>

## About

[Samba](https://wiki.samba.org) Docker image based on Alpine Linux.<br />
If you are interested, [check out](https://hub.docker.com/r/crazymax/) my other Docker images!

💡 Want to be notified of new releases? Check out 🔔 [Diun (Docker Image Update Notifier)](https://github.com/crazy-max/diun) project!

___

* [Features](#features)
* [Build locally](#build-locally)
* [Image](#image)
* [Environment variables](#environment-variables)
* [Volumes](#volumes)
* [Ports](#ports)
* [Configuration](#configuration)
* [Usage](#usage)
  * [Docker Compose](#docker-compose)
  * [Command line](#command-line)
* [Notes](#notes)
  * [Status](#status)
* [Upgrade](#upgrade)
* [Contributing](#contributing)
* [License](#license)

## Features

* Multi-platform image
* Easy [configuration](#configuration) through YAML
* Improve [operability with Mac OS X clients](https://wiki.samba.org/index.php/Configure_Samba_to_Work_Better_with_Mac_OS_X)
* Drop support for legacy protocols including NetBIOS, WINS, and Samba port 139

## Build locally

```shell
git clone https://github.com/crazy-max/docker-samba.git
cd docker-samba

# Build image and output to docker (default)
docker buildx bake

# Build multi-platform image
docker buildx bake image-all
```

## Image

| Registry                                                                                         | Image                           |
|--------------------------------------------------------------------------------------------------|---------------------------------|
| [Docker Hub](https://hub.docker.com/r/crazymax/samba/)                                           | `crazymax/samba`                |
| [GitHub Container Registry](https://github.com/users/crazy-max/packages/container/package/samba) | `ghcr.io/crazy-max/samba`       |

Following platforms for this image are available:

```
$ docker run --rm mplatform/mquery crazymax/samba:latest
Image: crazymax/samba:latest
 * Manifest List: Yes
 * Supported platforms:
   - linux/amd64
   - linux/arm/v6
   - linux/arm/v7
   - linux/arm64
   - linux/386
   - linux/ppc64le
   - linux/s390x
```

## Environment variables

* `TZ`: Timezone assigned to the container (default `UTC`)
* `SAMBA_WORKGROUP`: NT-Domain-Name or [Workgroup-Name](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#WORKGROUP). (default `WORKGROUP`)
* `SAMBA_SERVER_STRING`: [Server string](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#SERVERSTRING) is the equivalent of the NT Description field. (default `Docker Samba Server`)
* `SAMBA_LOG_LEVEL`: [Log level](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#LOGLEVEL). (default `0`)
* `SAMBA_FOLLOW_SYMLINKS`: Allow to [follow symlinks](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#FOLLOWSYMLINKS). (default `yes`)
* `SAMBA_WIDE_LINKS`: Controls whether or not links in the UNIX file system may be followed by the server. (default `yes`)
* `SAMBA_HOSTS_ALLOW`: Set of hosts which are permitted to access a service. (default `127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16`)
* `SAMBA_INTERFACES`: Allows you to override the default network interfaces list.

> More info: https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html

## Volumes

* `/data`: Contains cache, configuration and runtime data

## Ports

* `445`: SMB over TCP port

> More info: https://wiki.samba.org/index.php/Samba_NT4_PDC_Port_Usage

## Configuration

Before using this image you have to create the YAML configuration file `/data/config.yml` to be able to create users,
provide global options and add shares. Here is an example:

```yaml
auth:
  - user: foo
    group: foo
    uid: 1000
    gid: 1000
    password: bar
  - user: baz
    group: xxx
    uid: 1100
    gid: 1200
    password_file: /run/secrets/baz_password

global:
  - "force user = foo"
  - "force group = foo"

share:
  - name: foo
    path: /samba/foo
    browsable: yes
    readonly: no
    guestok: no
    validusers: foo
    writelist: foo
    veto: no
    hidefiles: /_*/
```

`veto: no` is a list of predefined files and directories that will not be
visible or accessible:

```
/._*/.apdisk/.AppleDouble/.DS_Store/.TemporaryItems/.Trashes/desktop.ini/ehthumbs.db/Network Trash Folder/Temporary Items/Thumbs.db/
```

*More info: https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#VETOFILES*

`hidefiles: /_*/` is a list of predefined files and directories that will not be visible, but are accessible:

```
/_*/
```
In this example, all files and directories beginning with an underscore (`_`) will be hidden.

*More info: https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#HIDEFILES*

A more complete `config.yml` example is available [here](examples/compose/data/config.yml).

### Add users

## Usage

### Docker Compose

Docker compose is the recommended way to run this image. Copy the content of folder [examples/compose](examples/compose)
in `/var/samba/` on your host for example. Edit the compose and configuration files with your preferences and run the
following commands:

```bash
docker-compose up -d
docker-compose logs -f
```

### Command line

You can also use the following minimal command:

```shell
docker run -d --network host \
  -v "$(pwd)/data:/data" \
  --name samba crazymax/samba
```

## Upgrade

Recreate the container whenever I push an update:

```bash
docker-compose pull
docker-compose up -d
```

## Notes

### Status

Use the following commands to check the logs and status:

```shell
docker-compose logs samba
docker-compose exec samba smbstatus
```

## Contributing

Want to contribute? Awesome! The most basic way to show your support is to star the project, or to raise issues. You
can also support this project by [**becoming a sponsor on GitHub**](https://github.com/sponsors/crazy-max) or by making
a [Paypal donation](https://www.paypal.me/crazyws) to ensure this journey continues indefinitely!

Thanks again for your support, it is much appreciated! :pray:

## License

MIT. See `LICENSE` for more details.
