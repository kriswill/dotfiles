# Cognee on Apple Silicon

This flake packages Cognee 1.6.10 for Apple Silicon Macs running macOS 15 or
newer. The `cognee` and `default` package outputs provide a Python 3.12
environment with `cognee-cli`, `uvicorn`, GLiNER, and the Postgres drivers.
`uv.lock` pins the wheel and source hashes. Dependencies install during the
Nix build. Local model weights download into the service's cache on first use.

```sh
nix build .#cognee
./result/bin/cognee-cli --version
```

For direct CLI use, point `DATA_ROOT_DIRECTORY` and
`SYSTEM_ROOT_DIRECTORY` at writable directories. Connect to the shared
service over its API so it owns access to its live graph files.

The dotfiles root imports this flake via `./flakes/cognee` and follows its
own nixpkgs and flake-parts inputs. Other flakes can consume
`inputs.cognee.darwinModules.cognee` in a nix-darwin host.

## Host configuration

For loopback with the embedded databases, import the module and set
`services.cognee.enable = true`. The API listens at
`http://127.0.0.1:8000`. The package and this module are available from the
dotfiles root. Enable the service in the host you choose.

For a shared LAN deployment with local Postgres, pick a reserved LAN
address and DNS name. The example values are placeholders.

```nix
{ config, ... }:
{
  sops.secrets.cognee-env = {
    sopsFile = ./cognee-secrets.yaml;
    owner = "_cognee";
    mode = "0400";
  };

  services.cognee = {
    enable = true;
    postgresql.enable = true;
    secretsFile = config.sops.secrets.cognee-env.path;
    https = {
      enable = true;
      hostName = "cognee.home.arpa";
      listenAddress = "192.168.1.10";
    };
  };
}
```

Set the encrypted `cognee-env` value to dotenv lines. Use a long random
`FASTAPI_USERS_JWT_SECRET` to preserve login tokens across restarts.
To provision the initial administrator, set `DEFAULT_USER_EMAIL` and
`DEFAULT_USER_PASSWORD` before the first startup. Cognee applies that password
only to a passwordless default account. Omit those lines if you prefer to
register an account on loopback. Optional provider keys belong in the same
runtime file. `services.cognee.environment` is for non-secret settings.
When `nrs` installs changed dotenv contents, launchd restarts Cognee so the
new process reads them. Rotating the JWT signing key invalidates existing
login tokens.

Verify the default service account IDs (451, 452, and 453) are free on the
target host before enabling the system jobs. Each ID is configurable.
On the dotfiles hosts, apply the enabled configuration with `nrs`.

## Connect and operate

- Check `/health` on loopback after activation. For HTTPS, the example URL
  is `https://cognee.home.arpa:8443`. With `tls internal`, Caddy generates
  its CA, certificates, and private keys on the host under
  `/var/lib/cognee-proxy` by default. Git holds the Caddy configuration.
  Distribute only the public CA certificate at
  `/var/lib/cognee-proxy/caddy/pki/authorities/local/root.crt` to clients.
  On a fresh local-model setup, allow time for the first download. The
  health check also probes the database adapters and embedder.
- Signup through the LAN proxy is disabled. On the host, log in using
  `POST /api/v1/auth/login` with the email as `username` and the password
  as form fields. HTTPS mode sets the `Secure` flag on the login cookie.
  Use the resulting bearer token to call
  `POST /api/v1/auth/api-keys` with a JSON `name`. Save the returned key
  when it is issued. For everyday clients, provision agent accounts with
  the dataset permissions they need, then configure each harness with
  `COGNEE_BASE_URL` and `COGNEE_API_KEY`.
- The system jobs are `org.nixos.cognee`, `org.nixos.cognee-postgresql`,
  and `org.nixos.cognee-proxy` for the enabled components. Inspect them with
  `launchctl print system/<label>`. The jobs write logs in their state
  directories. With default paths these are
  `/var/lib/cognee/cognee.log`,
  `/var/lib/cognee-postgresql/cluster/cognee-postgresql.log`, and
  `/var/lib/cognee-proxy/cognee-proxy.log`.
  Cognee waits for a successful authenticated database query when managed
  PostgreSQL is enabled.
- Managed PostgreSQL 17 listens on loopback port 55432 and starts before
  login. Its data directory and generated password live under
  `/var/lib/cognee-postgresql`. The administrator can connect over the private
  socket as `_cognee-postgres`. Each Cognee dataset gets a pgvector schema
  inside the `cognee` database. Ladybug and ingested files remain on disk.
  Use separate sibling directories if overriding both state paths, since
  the service users need separate writable homes.
- Back up Cognee state together with the database and generated credential.
  Keep Caddy CA state in an encrypted backup if clients rely on its trust
  chain. The CA state includes signing keys. Switching
  an existing embedded instance to Postgres requires an explicit data
  migration. A Nix generation rollback does not restore database contents.

The service starts one API worker, limits GLiNER to one inference batch,
limits active datasets to two, and sets the Ladybug buffer pool to 256 MiB
per graph. Measure memory during ingestion and concurrent recall before
expanding capture. Size the model cache, data directory, database, and
backups using the amount of content you plan to ingest.

## Updating

Change the Cognee pin in `pyproject.toml`, run `uv lock`, then build on
Apple Silicon and check an authenticated remember and recall against a fresh
Postgres instance. Back up existing state before activating a new version
because Cognee can migrate data on startup.
