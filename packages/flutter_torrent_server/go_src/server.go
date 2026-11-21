package server

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"

	"server/log"
	"server/settings"
	"server/torr"
	"server/torr/state"
	"server/torr/utils"
	"server/web"
)

// Start brings up the embedded torrent server.
//
// authToken is the per-launch secret that privileged HTTP endpoints require.
// Callers that need to talk to those endpoints (the Flutter plugin) generate
// one and pass it in. Passing "" mints an unguessable token that nobody holds,
// which locks the privileged surface rather than opening it.
func Start(pathdb, port, authToken string, roSets, searchWA bool) error {
	settings.Path = pathdb
	settings.InitSets(roSets, searchWA)
	if roSets {
		log.TLogln("Enabled Read-only DB mode!")
	}

	if authToken == "" {
		authToken = web.NewAuthToken()
	}
	settings.AuthToken = authToken

	// http checks
	if port == "" {
		port = "8090"
	}
	log.TLogln("Check web port", port)
	// Probe the same loopback address web.Start will bind, not every
	// interface: a bare ":port" probe both reports false conflicts and hides
	// the fact that the real listener is loopback-only.
	l, err := net.Listen("tcp", net.JoinHostPort(web.LoopbackHost, port))
	if l != nil {
		l.Close()
	}
	if err != nil {
		log.TLogln("Port", port, "already in use! Please set different sslport for HTTP.")
		return fmt.Errorf("port %s already in use", port)
	}
	// remove old disk caches
	go cleanCache()
	// set settings http Start web server.
	settings.Port = port
	web.Start()
	return nil
}

func cleanCache() {
	if !settings.BTsets.UseDisk || settings.BTsets.TorrentsSavePath == "/" || settings.BTsets.TorrentsSavePath == "" {
		return
	}

	dirs, err := os.ReadDir(settings.BTsets.TorrentsSavePath)
	if err != nil {
		return
	}

	torrs := settings.ListTorrent()

	log.TLogln("Remove unused cache in dir:", settings.BTsets.TorrentsSavePath)
	for _, d := range dirs {
		if len(d.Name()) != 40 {
			// Not a hash
			continue
		}

		if !settings.BTsets.RemoveCacheOnDrop {
			for _, t := range torrs {
				if d.IsDir() && d.Name() != t.InfoHash.HexString() {
					log.TLogln("Remove unused cache:", d.Name())
					removeAllFiles(filepath.Join(settings.BTsets.TorrentsSavePath, d.Name()))
					break
				}
			}
		} else {
			if d.IsDir() {
				log.TLogln("Remove unused cache:", d.Name())
				removeAllFiles(filepath.Join(settings.BTsets.TorrentsSavePath, d.Name()))
			}
		}
	}
}

func removeAllFiles(path string) {
	err := os.RemoveAll(path)
	if err != nil {
		log.TLogln("RemoveAll failed for", path, ":", err)
	}
}

func WaitServer() string {
	err := web.Wait()
	if err != nil {
		return err.Error()
	}
	return ""
}

func Stop() {
	web.Stop()
	settings.CloseDB()
}

func AddTrackers(trackers string) {
	tracks := strings.Split(trackers, ",\n")
	utils.SetDefTrackers(tracks)
}

// AddTorrentViaHTTP submits a magnet URI or torrent URL. Returns the torrent's
// InfoHash hex string.
func AddTorrentViaHTTP(link, title, poster string, saveToDB bool) (string, error) {
	spec, err := utils.ParseLink(link)
	if err != nil {
		return "", fmt.Errorf("parse link: %w", err)
	}

	tor, err := torr.AddTorrent(spec, title, poster, "")
	if err != nil {
		return "", fmt.Errorf("add torrent: %w", err)
	}

	if tor.Stat != state.TorrentInDB && saveToDB {
		torr.SaveTorrentToDB(tor)
	}

	return tor.Hash().HexString(), nil
}

// TorrentStatusByHash returns the status string of a torrent by InfoHash.
func TorrentStatusByHash(infoHash string) (string, error) {
	tor := torr.GetTorrent(infoHash)
	if tor == nil {
		return "", fmt.Errorf("torrent not found")
	}
	return tor.Status().Hash, nil
}

// RemoveTorrentByHash removes a torrent by InfoHash.
func RemoveTorrentByHash(infoHash string) {
	torr.RemTorrent(infoHash)
}
