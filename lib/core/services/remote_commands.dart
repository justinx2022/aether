import 'dart:async';

/// A playback command from another device on the home network.
class RemoteCommand {
  final String action;
  final int? positionMs;

  const RemoteCommand(this.action, {this.positionMs});
}

/// The TV player listens. The LAN server writes.
final StreamController<RemoteCommand> remoteCommands =
    StreamController<RemoteCommand>.broadcast();
