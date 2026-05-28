# T3Code Server Image

Builds a server-only T3Code image by cloning upstream T3Code, copying only the server app and workspace packages it needs, then installing Claude Code, Codex CLI, and OpenCode.

## Build

```bash
docker buildx build \
  --platform linux/amd64 \
  -t arvigeus/t3code-server:latest \
  images/t3code-server
```

To pin upstream T3Code:

```bash
docker buildx build \
  --platform linux/amd64 \
  --build-arg T3CODE_REF=<tag-or-commit> \
  -t arvigeus/t3code-server:<tag> \
  images/t3code-server
```

## Push

Log in to Docker Hub first:

```bash
docker login docker.io
```

Use the Docker Hub username that owns the `arvigeus` namespace. If Docker Hub requires a password, use an access token from Docker Hub account settings instead of the account password.

Then publish and enter the version when prompted:

```bash
./images/t3code-server/publish.sh
```

The script tags and pushes both `arvigeus/t3code-server:<version>` and `arvigeus/t3code-server:latest`.

If push fails with `requested access to the resource is denied`, the local tag is valid but Docker Hub rejected the upload. Check:

- You are logged in as the `arvigeus` Docker Hub account, or an account with write access to `arvigeus/t3code-server`.
- The Docker Hub repository exists, unless the account is allowed to auto-create repositories.
- If using Podman or `podman-docker`, log in with `podman login docker.io` too.

## Subscription Auth

The container keeps provider homes in `/home/node`. With the compose file, that maps to `${DATA}/t3code/home`, so logins persist across restarts.

```bash
docker exec -it t3code claude auth login
docker exec -it t3code codex login
docker exec -it t3code opencode auth
```

Codex and Claude subscription logins do not need API keys in `.env`.

On startup, the logs show:

- `Field 2 - Actual server URL`, from `T3CODE_PUBLIC_URL`
- `pairingUrl: http://localhost:3773/pair#token=...`, which is Field 1 for `https://t3code.web.app/pair`
