# list_smith example

A runnable showcase for [`list_smith`](../), built on a platform-adaptive stack so the package's
neutral surfaces can be seen dropping into a Material shell (Android) and a Cupertino shell (iOS)
unchanged.

## Demos

The app opens on a hub linking to:

- **Basic feed**: `ListSmith.async` with pull-to-refresh and the neutral default surfaces.
- **Custom surfaces**: every surface (loading, error, empty, end, pull indicator) replaced with a
  platform-adaptive one, plus a toggle to inject fetch failures and exercise the error and retry
  path.
- **Playground**: live knobs for page size, the end policy, fetch latency, pull-to-refresh, and
  separators.

Tap the app-bar control on any screen to flip light and dark.

## Running

```sh
cd example
flutter run
```

Targets Android and iOS (the platform-adaptive stack is mobile-only).
