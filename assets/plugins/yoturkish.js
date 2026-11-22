var PluginModule = (() => {
  const defaultHeaders = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Referer": "https://yoturkish.to/"
  };
  let allSeriesCache = null;

  function base64Encode(str) {
    if (typeof btoa === "function") {
      try { return btoa(str); } catch (e) {}
    }
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    let output = "";
    for (let i = 0; i < str.length; i += 3) {
      let b1 = str.charCodeAt(i);
      let b2 = i + 1 < str.length ? str.charCodeAt(i + 1) : NaN;
      let b3 = i + 2 < str.length ? str.charCodeAt(i + 2) : NaN;
      let e1 = b1 >> 2;
      let e2 = ((b1 & 3) << 4) | (isNaN(b2) ? 0 : b2 >> 4);
      let e3 = isNaN(b2) ? 64 : ((b2 & 15) << 2) | (isNaN(b3) ? 0 : b3 >> 6);
      let e4 = isNaN(b3) ? 64 : b3 & 63;
      output += chars.charAt(e1) + chars.charAt(e2) + chars.charAt(e3) + chars.charAt(e4);
    }
    return output;
  }

  function decodeBase64(str) {
    if (typeof atob === "function") {
      try { return atob(str); } catch (e) {}
    }
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    let output = "";
    str = String(str).replace(/=+$/, "");
    for (let bc = 0, bs, buffer, idx = 0; buffer = str.charAt(idx++); ~buffer && (bs = bc % 4 ? bs * 64 + buffer : buffer, bc++ % 4) ? output += String.fromCharCode(255 & bs >> (-2 * bc & 6)) : 0) {
      buffer = chars.indexOf(buffer);
    }
    return output;
  }

  function decodeDataS(raw) {
    let b64 = Array.isArray(raw) ? raw.join("") : String(raw || "").replace(/\|/g, "");
    let bin = decodeBase64(b64);
    let rev = "";
    for (let i = bin.length - 1; i >= 0; i--) {
      rev += bin.charAt(i);
    }
    let shifted = "";
    let shift = 5;
    for (let i = 0; i < rev.length; i++) {
      shifted += String.fromCharCode(((rev.charCodeAt(i) - shift) % 256 + 256) % 256);
    }
    let key = [86, 110, 51, 72, 106, 87, 56, 102];
    let res = "";
    for (let i = 0; i < shifted.length; i++) {
      res += String.fromCharCode(shifted.charCodeAt(i) ^ key[i % key.length]);
    }
    return res;
  }

  function unpackDeanEdwards(code) {
    if (!code) return null;
    try {
      const match = code.match(/}\s*\('(.*)',\s*(.*?),\s*(\d+),\s*'(.*?)'\.split\('\|'\)/s);
      if (!match || match.length < 5) return null;

      const payload = match[1].replace(/\\'/g, "'");
      const radix = parseInt(match[2], 10) || 36;
      const symtab = match[4].split('|');

      const alphabet62 = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
      function unbase(str) {
        if (radix <= 36) {
          const v = parseInt(str, radix);
          return isNaN(v) ? -1 : v;
        }
        let res = 0;
        for (let i = 0; i < str.length; i++) {
          const idx = alphabet62.indexOf(str[i]);
          if (idx === -1) return -1;
          res = res * radix + idx;
        }
        return res;
      }

      return payload.replace(/\b[a-zA-Z0-9_]+\b/g, (word) => {
        const idx = unbase(word);
        if (idx >= 0 && idx < symtab.length && symtab[idx]) {
          return symtab[idx];
        }
        return word;
      });
    } catch (e) {
      return null;
    }
  }

  async function getHome(callback) {
    try {
      let res = await http_get("https://yoturkish.to/home/", defaultHeaders);
      if (!res || !res.body) {
        if (callback && typeof callback === "function") callback({ success: false, errorCode: "SITE_OFFLINE", message: "No response from site" });
        return { "New Episodes": [], "Turkish Series": [] };
      }

      let html = res.body;

      // 1. New Episodes section
      let newEpisodes = [];
      let newEpSectionStart = html.indexOf("<h2>New Episodes</h2>");
      let seriesSectionStart = html.indexOf("<h2>Series List</h2>");

      if (newEpSectionStart !== -1 && seriesSectionStart !== -1) {
        let newEpHtml = html.slice(newEpSectionStart, seriesSectionStart);
        let epRegex = /<a\s+[^>]*href="([^"]+)"\s+title="([^"]+)"\s+class="poster">[\s\S]*?<img[^>]+src="([^"]+)"/gi;
        let em;
        let seenEps = new Set();
        while ((em = epRegex.exec(newEpHtml)) !== null) {
          let u = em[1].trim();
          if (seenEps.has(u)) continue;
          seenEps.add(u);
          newEpisodes.push(new MultimediaItem({
            title: em[2].replace(/&#8211;/g, "-").trim(),
            url: u,
            posterUrl: em[3].trim(),
            type: "series"
          }));
        }
      }

      // 2. Turkish Series section
      let seriesList = [];
      let seriesHtml = seriesSectionStart !== -1 ? html.slice(seriesSectionStart) : html;
      let sRegex = /<a\s+[^>]*href="([^"]+)"\s+title="([^"]+)"\s+class="poster">[\s\S]*?<img[^>]+src="([^"]+)"/gi;
      let sm;
      let seenSeries = new Set();
      while ((sm = sRegex.exec(seriesHtml)) !== null) {
        let u = sm[1].trim();
        if (seenSeries.has(u)) continue;
        seenSeries.add(u);
        seriesList.push(new MultimediaItem({
          title: sm[2].replace(/&#8211;/g, "-").trim(),
          url: u,
          posterUrl: sm[3].trim(),
          type: "series"
        }));
      }

      let homeData = {
        "New Episodes": newEpisodes,
        "Turkish Series": seriesList
      };

      if (callback && typeof callback === "function") {
        callback({ success: true, data: homeData });
      }
      return homeData;
    } catch (e) {
      if (callback && typeof callback === "function") {
        callback({ success: false, errorCode: "FETCH_ERROR", message: e.message || String(e) });
      }
      return { "New Episodes": [], "Turkish Series": [] };
    }
  }

  async function getCategoryPage(category, page, offset) {
    const start = Math.max(0, Number(offset) || 0);
    const pageSize = 24;
    if (category === "New Episodes") {
      if (page < 2) return [];
      const res = await http_get("https://yoturkish.to/episodes/page/" + page + "/", defaultHeaders);
      if (!res || !res.body) return [];
      const items = [];
      const seen = new Set();
      const regex = /<a\s+[^>]*href="([^"]+)"\s+title="([^"]+)"\s+class="poster">[\s\S]*?<img[^>]+src="([^"]+)"/gi;
      let match;
      while ((match = regex.exec(res.body)) !== null) {
        const url = match[1].trim();
        if (seen.has(url)) continue;
        seen.add(url);
        items.push(new MultimediaItem({
          title: match[2].replace(/&#8211;/g, "-").trim(),
          url,
          posterUrl: match[3].trim(),
          type: "series"
        }));
      }
      return items;
    }

    if (category !== "Turkish Series") return [];
    if (!allSeriesCache) {
      const res = await http_get("https://yoturkish.to/series/", defaultHeaders);
      if (!res || !res.body) return [];
      const items = [];
      const seen = new Set();
      const regex = /<a\s+[^>]*href="([^"]+)"\s+title="([^"]+)"\s+class="poster">[\s\S]*?<img[^>]+src="([^"]+)"/gi;
      let match;
      while ((match = regex.exec(res.body)) !== null) {
        const url = match[1].trim();
        if (seen.has(url)) continue;
        seen.add(url);
        items.push(new MultimediaItem({
          title: match[2].replace(/&#8211;/g, "-").trim(),
          url,
          posterUrl: match[3].trim(),
          type: "series"
        }));
      }
      allSeriesCache = items;
    }
    return allSeriesCache.slice(start, start + pageSize);
  }

  async function search(query, callback) {
    try {
      let searchUrl = "https://yoturkish.to/?s=" + encodeURIComponent(query);
      let res = await http_get(searchUrl, defaultHeaders);
      if (!res || !res.body) {
        if (callback && typeof callback === "function") callback({ success: true, data: [] });
        return [];
      }

      let postRegex = /<a\s+[^>]*href="([^"]+)"\s+title="([^"]+)"\s+class="poster">[\s\S]*?<img[^>]+src="([^"]+)"/gi;
      let items = [];
      let m;
      let seen = new Set();
      while ((m = postRegex.exec(res.body)) !== null) {
        let u = m[1].trim();
        if (seen.has(u)) continue;
        seen.add(u);
        items.push(new MultimediaItem({
          title: m[2].replace(/&#8211;/g, "-").trim(),
          url: u,
          posterUrl: m[3].trim(),
          type: "series"
        }));
      }

      if (callback && typeof callback === "function") callback({ success: true, data: items });
      return items;
    } catch (e) {
      if (callback && typeof callback === "function") callback({ success: true, data: [] });
      return [];
    }
  }

  async function load(url, callback) {
    try {
      let res = await http_get(url, defaultHeaders);
      if (!res || !res.body) {
        if (callback && typeof callback === "function") callback({ success: false, errorCode: "PARSE_ERROR", message: "Failed to load page" });
        return null;
      }

      let html = res.body;
      let titleMatch = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
      let rawTitle = titleMatch ? titleMatch[1].replace(/<[^>]+>/g, "").replace(/&#8211;/g, "-").trim() : "Unknown";
      let title = rawTitle.replace(/\s+/g, " ");

      let imgMatch = html.match(/class="poster"[^>]*>[\s\S]*?<img[^>]+src="([^"]+)"/i);
      let posterUrl = imgMatch ? imgMatch[1].trim() : "";

      let descMatch = html.match(/<div class="entry-content">([\s\S]*?)<\/div>/i);
      let description = descMatch ? descMatch[1].replace(/<[^>]+>/g, "").trim() : "";

      let epRegex = /<a\s+class="episod"\s+href="([^"]+)">([\s\S]*?)<\/a>/gi;
      let episodes = [];
      let em;
      let epIndex = 1;
      let seen = new Set();

      while ((em = epRegex.exec(html)) !== null) {
        let epUrl = em[1].trim();
        if (seen.has(epUrl)) continue;
        seen.add(epUrl);

        let epRawText = em[2].replace(/<[^>]+>/g, "").replace(/\s+/g, " ").trim();
        let seasonMatch = em[2].match(/Season\s*(\d+)/i);
        let season = seasonMatch ? parseInt(seasonMatch[1], 10) : 1;

        let epNumMatch = epRawText.match(/Episode\s*(\d+)/i);
        let episodeNum = epNumMatch ? parseInt(epNumMatch[1], 10) : epIndex;

        episodes.push(new Episode({
          name: epRawText || ("Episode " + episodeNum),
          season: season,
          episode: episodeNum,
          posterUrl: posterUrl,
          url: epUrl
        }));
        epIndex++;
      }

      // Standalone single episode fallback if no list found
      if (episodes.length === 0) {
        episodes.push(new Episode({
          name: title,
          season: 1,
          episode: 1,
          posterUrl: posterUrl,
          url: url
        }));
      }

      let item = new MultimediaItem({
        title: title,
        url: url,
        posterUrl: posterUrl,
        type: "series",
        description: description,
        episodes: episodes
      });

      if (callback && typeof callback === "function") callback({ success: true, data: item });
      return item;
    } catch (e) {
      if (callback && typeof callback === "function") callback({ success: false, errorCode: "PARSE_ERROR", message: e.message || String(e) });
      return null;
    }
  }

  async function loadStreams(episodeUrl, callback) {
    try {
      let res = await http_get(episodeUrl, defaultHeaders);
      let streams = [];

      if (res && res.body) {
        let html = res.body;

        // 1. Extract and decrypt server tokens (data-s1, data-s2, etc.)
        let tokenRegex = /data-s\d+="([^"]+)"/g;
        let tm;
        let serverUrls = [];

        while ((tm = tokenRegex.exec(html)) !== null) {
          try {
            let decHtml = decodeDataS(tm[1]);
            let srcMatch = decHtml.match(/src="([^"]+)"/i);
            if (srcMatch && srcMatch[1]) {
              serverUrls.push(srcMatch[1].trim());
            }
          } catch (e) {}
        }

        // 2. Process each server URL (Engifuosi is the primary direct HLS CDN on YoTurkish)
        for (let sUrl of serverUrls) {
          if (!sUrl.startsWith("http")) continue;

          if (sUrl.includes("engifuosi")) {
            try {
              let eRes = await http_get(sUrl, {
                "User-Agent": defaultHeaders["User-Agent"],
                "Referer": "https://yoturkish.to/"
              });
              if (eRes && eRes.body) {
                let unpacked = unpackDeanEdwards(eRes.body);
                if (unpacked) {
                  let m3u8Match = unpacked.match(/https?:\/\/[^"'\s<>]+\.m3u8[^"'\s<>]*/i);
                  if (m3u8Match) {
                    let masterUrl = m3u8Match[0];

                    // Keep the adaptive master and direct renditions. The app
                    // enforces the viewer's quality and buffer settings.
                    streams.push(new StreamResult({
                      source: "YoTurkish 1080p FHD (Engi Master)",
                      name: "Engi FHD (Auto)",
                      url: masterUrl,
                      quality: "1080p",
                      type: "m3u8",
                      headers: {
                        "Referer": "https://engifuosi.com/",
                        "User-Agent": defaultHeaders["User-Agent"]
                      }
                    }));

                    // Priority 2: Direct Quality-Specific Sub-Streams
                    let prefixMatch = masterUrl.match(/^(https?:\/\/[^\/]+\/hls2\/[^\/]+\/[^\/]+\/)([^\/]+)_,([^.]+)\.urlset\/master\.m3u8(\?.*)?$/i);
                    if (prefixMatch) {
                      let base = prefixMatch[1];
                      let slug = prefixMatch[2];
                      let tags = prefixMatch[3].split(",").filter(Boolean);
                      let query = prefixMatch[4] || "";

                      // Sort tags so higher qualities come first (x = 1080p, h = 720p, n = 480p)
                      tags.sort((a, b) => (a === 'x' ? -1 : b === 'x' ? 1 : a === 'h' ? -1 : 1));

                      for (let tag of tags) {
                        let quality = tag === 'x' ? '1080p' : tag === 'h' ? '720p' : tag === 'n' ? '480p' : 'Auto';
                        let subUrl = base + slug + '_' + tag + '/index-v1-a1.m3u8' + query;
                        streams.push(new StreamResult({
                          source: "YoTurkish " + quality + " (Direct)",
                          name: "Engi " + quality,
                          url: subUrl,
                          quality: quality,
                          type: "m3u8",
                          headers: {
                            "Referer": "https://engifuosi.com/",
                            "User-Agent": defaultHeaders["User-Agent"]
                          }
                        }));
                      }
                    }

                    // The proxied master was consistently much slower than
                    // direct HLS in playback history, so don't offer it as a
                    // competing fallback. Direct HLS carries the same headers.
                  }
                }
              }
            } catch (err) {}
          }
        }
      }

      if (callback && typeof callback === "function") {
        callback({ success: true, data: streams });
      }
      return streams;
    } catch (e) {
      if (callback && typeof callback === "function") {
        callback({ success: true, data: [] });
      }
      return [];
    }
  }

  return {
    getHome: getHome,
    getCategoryPage: getCategoryPage,
    search: search,
    load: load,
    loadStreams: loadStreams
  };
})();

Object.assign(globalThis, PluginModule);
