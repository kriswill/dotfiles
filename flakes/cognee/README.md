# Cognee on Apple Silicon

This flake packages Cognee 1.6.11 for Apple Silicon Macs running macOS 15 or
newer. The `cognee` and `default` package outputs provide a Python 3.12
environment with `cognee-cli`, `uvicorn`, FastEmbed, and the Postgres drivers.
Graph extraction requires a configured LLM provider. The offline GLiNER
extractor is not packaged: it pulls in Transformers, whose patched releases
require a newer Hugging Face Hub than the pinned Cognee release allows. Local
FastEmbed embeddings do not need Transformers.
`uv.lock` pins the wheel and source hashes. Dependencies install during the
Nix build. Local model weights download into the service's cache on first use.
The optional `cognee-frontend` package builds the Next.js dashboard from the
matching upstream tag and npm lockfile. Its standalone bundle includes the
static assets and Nix-packaged Geist fonts.
The `lib.mkHermesPlugin` output builds the pinned native Cognee memory
plugin against Hermes' Python package set for use in
`services.hermes-agent.extraPythonPackages`.

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

For a shared LAN deployment, pick a reserved LAN address and DNS name. The
dashboard requires the HTTPS proxy. Enable `postgresql.enable` separately
if the deployment needs PostgreSQL and pgvector. The example values are
placeholders.

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
    frontend.enable = true;
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
The initial administrator email defaults to `default_user@example.com`.
Set `DEFAULT_USER_EMAIL` before the first startup to choose a different email.
Set `DEFAULT_USER_PASSWORD` to give a passwordless default account a login.
Use the configured password in the browser. The sign-in form supports
password-manager autofill. To provision additional accounts, register them on
loopback. Optional provider keys belong in the same runtime file.
`services.cognee.environment` is for non-secret settings.
When `nrs` installs changed dotenv contents, launchd restarts Cognee so the
new process reads them. Rotating the JWT signing key invalidates existing
login tokens.

Verify the service account IDs are free on the target host before enabling
the system jobs. The defaults are 451 for the API, 452 for PostgreSQL, 453
for Caddy, and 454 for the dashboard. Each ID is configurable.
On the dotfiles hosts, apply the enabled configuration with `nrs`.

## Connect and operate

- Check `/health` on loopback after activation. For HTTPS, the example URL
  is `https://cognee.home.arpa:8443`. With the dashboard enabled, that URL
  opens the sign-in page. Caddy forwards `/api/v1/*` to the loopback API
  and serves the dashboard from its loopback service on port 3000. Both use
  the same HTTPS origin so the browser can use the Cognee login cookie.
- With `tls internal`, Caddy generates its CA and certificates under
  `/var/lib/cognee-proxy` by default. Copy the public CA certificate from
  `/var/lib/cognee-proxy/caddy/pki/authorities/local/root.crt` over an
  authenticated channel and trust it on the clients that use the dashboard.
- Signup through the LAN proxy is disabled. On the host, log in using
  `POST /api/v1/auth/login` with the email as `username` and the password
  as form fields. HTTPS mode sets the `Secure` flag on the login cookie.
  Use the resulting bearer token to call
  `POST /api/v1/auth/api-keys` with a JSON `name`. Save the returned key
  when it is issued. For everyday clients, provision agent accounts with
  the dataset permissions they need, then configure each harness with
  `COGNEE_BASE_URL` and `COGNEE_API_KEY`.
- The self-hosted dashboard can create and revoke keys through **API Keys**.
  The Codex, Claude Code, and Hermes setup dialogs create keys on request
  and show their setup instructions. Save the key when it is issued. The
  server stores its hash, and the dashboard can only list a masked value
  afterward.
- The system jobs are `org.nixos.cognee`, `org.nixos.cognee-postgresql`,
  `org.nixos.cognee-proxy`, and `org.nixos.cognee-frontend` for the enabled
  components. Inspect them with
  `launchctl print system/<label>`. The jobs write logs in their state
  directories. With default paths these are
  `/var/lib/cognee/cognee.log`,
  `/var/lib/cognee-postgresql/cluster/cognee-postgresql.log`, and
  `/var/lib/cognee-proxy/cognee-proxy.log`, with the dashboard log at
  `/var/lib/cognee-frontend/cognee-frontend.log`.
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

The service starts one API worker,
limits active datasets to two, and sets the Ladybug buffer pool to 256 MiB
per graph. Measure memory during ingestion and concurrent recall before
expanding capture. Size the model cache, data directory, database, and
backups using the amount of content you plan to ingest.

## Trust the CA on clients

Import `inputs.cognee.darwinModules.clientTrust` on macOS or
`inputs.cognee.nixosModules.clientTrust` on NixOS. Set
`services.cognee.clientTrust.enable = true` and point `certificateFile` at
the public root PEM available to the Nix build. The client module adds the
root to the system CA bundle. On macOS it also manages TLS trust in the
System Keychain. On NixOS, set `chromiumDnsNames` to issue a managed Chromium
policy for the dashboard hostname.

The dotfiles hosts `k` and `nebula` use the same pinned certificate from
`lib/cognee-root-ca.nix`. Seed the public PEM into the Nix store on a new
build machine with `nix-store --add-fixed sha256 cognee-root.crt` after
checking its fingerprint against `mini`. Keep the signing keys with Caddy.
Changing the root CA requires seeding its replacement and updating the
hash. For macOS removal, keep the client module imported and switch once
with `clientTrust.enable = false` to remove its admin trust entry.

## Updating

Change the Python pin in `pyproject.toml` and run `uv lock`. Update the
matching dashboard tag and hashes in `frontend.nix` and check its source
substitutions against the new tag. Build both packages on Apple Silicon and
check dashboard access and an authenticated remember and recall. Back up
existing state before activating a new version because Cognee can migrate
data on startup.

For 1.6.11, `mini` keeps its explicit FastEmbed provider and
`BAAI/bge-small-en-v1.5` model. The migration to the new default local embedding
model is for installs that leave the provider and model unconfigured; do not
drop the existing pins during the upgrade. The 1.6.11 frontend uses the same
npm lockfile and accepts the existing downstream patches.
