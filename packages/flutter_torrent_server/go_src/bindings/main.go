package torrServer

import (
	server "server"
)

// StartTorrentServer starts the embedded server on loopback.
//
// authToken is the per-launch secret the host app must present on privileged
// HTTP endpoints (see web.TokenHeader). Generate a fresh unguessable value per
// launch on the host side and keep it in process memory only. Passing "" locks
// the privileged endpoints instead of opening them.
func StartTorrentServer(pathdb, authToken string) error {
	return server.Start(pathdb, "", authToken, false, false)
}

func WaitTorrentServer() {
	server.WaitServer()
}

func StopTorrentServer() {
	server.Stop()
}

func AddTrackers(trackers string) {
	server.AddTrackers(trackers)
}

// AddTorrent submits a magnet URI or torrent URL to the server.
// Returns the torrent's InfoHash hex string.
func AddTorrent(link, title, poster string, saveToDB bool) (string, error) {
	return server.AddTorrentViaHTTP(link, title, poster, saveToDB)
}

// TorrentStatus returns the status of a torrent by InfoHash.
func TorrentStatus(infoHash string) (string, error) {
	return server.TorrentStatusByHash(infoHash)
}

// RemoveTorrent removes a torrent by InfoHash.
func RemoveTorrent(infoHash string) {
	server.RemoveTorrentByHash(infoHash)
}
