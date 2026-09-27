# list_smith example

A runnable showcase for [`list_smith`](../), on a platform-adaptive stack so the package's neutral
surfaces can be seen dropping into a Material shell (Android) and a Cupertino shell (iOS)
unchanged.

## Demos

[`home_view.dart`](lib/features/core/views/home_view.dart) is the list, one tile per demo with its
own one-line description, and the app opens on it.

Every screen carries a `DemoIntro` explaining what it exercises, and the app-bar control flips light
and dark.

## Running

```sh
cd example
flutter run
```

Android and iOS only, since the platform-adaptive stack is mobile-only.
