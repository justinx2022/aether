# Aether Extension Compatibility

Aether currently accepts JavaScript extensions using the SkyStream-compatible `.sky` and `.js` formats. Existing compatible repositories can be added in **Settings → Extensions → Add Repository**.

Aether keeps the `SkyStreamProvider` API and legacy `skystream://` repository-link scheme so existing extensions and saved links continue to work. These names are compatibility interfaces; Aether's app identity and release services are separate. New extension work should be checked against the provider bridge in `lib/core/extensions/base_provider.dart` and the examples in `lib/core/extensions/providers/`.

Extensions are user installed and run through Aether's JavaScript extension engine. Review an extension before installing it and use only sources you are authorized to access.
