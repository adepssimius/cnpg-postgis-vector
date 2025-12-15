# cnpg-postgis-vector

Custom wrapper around `ghcr.io/cloudnative-pg/postgis` that compiles and installs the [`pgvector`](https://github.com/pgvector/pgvector) extension so you can pull an image that matches the upstream CloudNativePG PostGIS tag.

## Image build

The `Dockerfile` reuses the upstream base image (selected via the `BASE_TAG` build argument) and compiles `pgvector` from source (via `PGVECTOR_VERSION`). The default versions are declared in `versions.yml`, but you can build locally with the same arguments that the workflow uses:

```bash
docker build \
  --build-arg BASE_TAG=17-3.5 \
  --build-arg PGVECTOR_VERSION=0.8.1 \
  -t ghcr.io/<your-gh-user-or-org>/cnpg-postgis-vector:17-3.5-pgvector-0.8.1 \
  .
```

## Version catalog

`versions.yml` is the source of truth for the combinations that should be published. Each entry now pairs a single CNPG/PostGIS tag with a single pgvector version, so the file stays flat and easy to edit:

```yaml
builds:
  - postgis: 17-3.5
    vector: 0.8.1
```

The workflow builds every combination from this file and publishes the resulting image to `ghcr.io/<owner>/cnpg-postgis-vector:<postgis>-pgvector-<pgvector>`, e.g. `ghcr.io/<owner>/cnpg-postgis-vector:17-3.5-pgvector-0.8.1`.

When a new PostGIS base or pgvector release should be exposed, edit `versions.yml`, commit, and push.

## GitHub Actions automation

`.github/workflows/build.yml` reads `versions.yml` and:

1. Triggers on any push that touches `versions.yml` (or via `workflow_dispatch` if you specify a path to a custom file).
2. Parses the list into a matrix of `BASE_TAG`/`PGVECTOR_VERSION` combinations.
3. Logs into GHCR with `GITHUB_TOKEN` (requires `packages: write`/`contents: read` permissions).
4. Builds and pushes each image with Docker Buildx so the published tags can expose every architecture supported by the upstream base image.

The manual trigger accepts a `versions_file` input, so you can rerun the workflow with an alternate catalog (or a temporary set of versions) without touching the default file.

## Release flow

1. Update `versions.yml` to add or remove the PostGIS/pgvector combinations you want published.
2. Commit the change and push it to GitHub.
3. The workflow will rebuild and publish every entry listed in `versions.yml`; each tag follows the `postgis-pgvector` suffix convention.

Wait for the workflow run to finish, then pull the desired image:

```bash
docker pull ghcr.io/<owner>/cnpg-postgis-vector:17-3.5-pgvector-0.8.1
```
