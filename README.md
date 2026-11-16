# beets-web-import

A web terminal for importing music with beets.

## Beets configuration

Mount your beets configuration at `/config/beets/config.yaml`. The supplied
`docker-compose.yml` mounts `./config.yaml` there; replace that file or change
the mount to use your own configuration.

By default, each `beet` invocation uses a fresh, writable temporary database,
which is deleted when the command exits. Imported music remains in `/music`,
but library records do not carry over between invocations.

When supplying your own configuration, add this top-level setting:

```yaml
create_backup_before_migrations: no
```

Beets otherwise creates migration backups each time it initializes the fresh
database and prints a message for each backup. This setting skips creating
those backups entirely. The bundled configuration already includes it.

To retain the library between invocations, set the container environment
variable `BEETS_WEB_IMPORT_LIBRARY_MODE=persistent` and mount a persistent
volume at `/data/beets`. In that mode, leave migration backups enabled by
omitting `create_backup_before_migrations` or setting it to `yes`.
