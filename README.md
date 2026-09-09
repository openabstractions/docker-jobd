# docker-jobd

**In development.** The image is built from a published module, never from a
copy of jobd's source, and it is **not signed**: it carries a GitHub build
provenance attestation, which records which workflow and commit produced it,
and no signature from a certificate this project holds.

**A download manager for any NAS that runs Docker, with no web page.** A
program on your PC drops a request into a shared folder; `jobd` on the NAS
fetches the file, resumes it after any interruption, checks its sha256, and
leaves it on the share for when the PC comes back. Your laptop can sleep,
close, or leave the building.

On a Synology you can instead install it as a native DSM package, through
Package Center and with a window on the DSM desktop:
[addon-synology](https://github.com/openabstractions/addon-synology). Same
program, same behaviour; only the way it is installed differs.

```
docker run -d --name jobd --restart unless-stopped --user "$(id -u):$(id -g)" \
  -v /volume1/docker/jobd:/store -v /etc/ssl/certs:/etc/ssl/certs:ro \
  ghcr.io/openabstractions/jobd
```

`linux/amd64` and `linux/arm64`; `docker` picks the one your NAS has. To build
it yourself instead, which needs no registry:

```
docker build -t jobd https://github.com/openabstractions/docker-jobd.git
```

What the published image claims about its own origin, and what it does not:

```
gh attestation verify oci://ghcr.io/openabstractions/jobd --owner openabstractions
```

Files land in `/volume1/docker/jobd/files/` — `\\nas\docker\jobd\files\` from
Windows. Create that folder before the first run, as the user who will use the
share. `docker logs jobd` says `jobd: watching /store` and nothing else until
there is work.

## Asking it for a file

Put a text file in `wanted/` on the share — `\\nas\docker\jobd\wanted\` — with
one URL per line:

```
https://huggingface.co/HuggingFaceTB/SmolLM2-135M-Instruct-GGUF/resolve/main/smollm2-135m-instruct-q8_0.gguf
```

Within a sweep the file is renamed `.accepted`; when the download has landed in
`files/` it is renamed `.done`, and inside it says where and how big. A URL may
be followed, in either order, by `sha256:<64 hex>` to have the bytes verified
and by a folder such as `models/` to choose where under the share they land. A
request the NAS will not act on is renamed `.refused` and one that broke is
renamed `.failed`, with the reason inside either; fix it and rename it back.
Nothing is installed on the PC.

Any program built on [abstraction-download] hands work over on its own; the
command-line one is `dl`. On the PC, with Go 1.26 installed:

```
go install github.com/openabstractions/abstraction-download/go/cmd/dl@v0.2.1
setx ABSTRACTION_NAS_STORE \\nas\docker\jobd
```

Open a new terminal, then:

```
dl https://huggingface.co/HuggingFaceTB/SmolLM2-135M-Instruct-GGUF/resolve/main/smollm2-135m-instruct-q8_0.gguf -o D:\models
```

`dl` says `fetched by nas`, shows progress, and copies the finished file to
`D:\models`. Close it and the NAS carries on; `dl list` shows where things
stand. A copy stays in `files/` on the share.

## Settings

| what | where | default |
|---|---|---|
| the store | `-v <folder>:/store` — a folder the PC can also reach as a share | required |
| who writes | `--user uid:gid` — the owner of that folder; `id -u` and `id -g` on the NAS | `1024:100`, Synology's `admin` |
| TLS roots | `-v /etc/ssl/certs:/etc/ssl/certs:ro` — the NAS's own; none are built in | required for `https` |
| Hugging Face token | `-e ABSTRACTION_CRED_HF=hf_EXAMPLE` — gated repositories | none |
| how often it looks | `run --interval 30s` after the image name | 30s |
| which `jobd` | `--build-arg JOBD=github.com/openabstractions/service-jobd@v0.2.0` | that version |

Nothing else. `compose.yml` in this repository is the same five lines for
`docker compose up -d` or a Container Manager project.

## Synology

**DSM 6** has no `docker` command for a normal user and cannot build images.
Build on any machine with Docker, `docker save jobd > jobd.tar`, copy the file to
a share, then Docker → Image → Add → Add From File. Launch it with one volume,
`docker/jobd` → `/store`, and one more, `/etc/ssl/certs` → `/etc/ssl/certs`
read-only. The DSM 6 UI has no user field, so the image's `1024:100` applies; if
`id -u` over SSH says something else, rebuild with that number in the
`Dockerfile`. Enable auto-restart after the first log line.

**DSM 7** is unproven: nobody has run this on it. Container Manager takes the
compose file as a project; if that works or fails, say so in an issue.

## What may break

- **`https` fails with `no TLS trust store`**: the NAS keeps its roots somewhere
  other than `/etc/ssl/certs`. Mount that directory instead.
- **`not usable as a store`**: the folder is owned by somebody else. Fix
  `--user`, or `chmod -R a+rwX` the folder.
- **Two supervisors on one store** is untested. Run one `jobd` per folder.
- **`arm64`** is published and has never been run: no arm64 machine has started
  this image. Only the `amd64` one is exercised before it is pushed.
- **A partly fetched download restarts from zero** on the NAS rather than
  resuming, and bytes already fetched on the PC are not handed over.

The image is one static binary and two empty directories, about 7 MB; there is
no shell in it, so there is nothing to exec into and nothing to attack.

[abstraction-download]: https://github.com/openabstractions/abstraction-download
