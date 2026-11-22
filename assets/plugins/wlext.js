var PluginModule = (() => {
  const defaultHeaders = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Referer": "https://wlext.is/"
  };

  function cleanString(str) {
    if (!str) return "";
    return String(str)
      .replace(/<[^>]+>/g, "")
      .replace(/&#8211;/g, "-")
      .replace(/&#8217;/g, "'")
      .replace(/&#8220;/g, '"')
      .replace(/&#8221;/g, '"')
      .replace(/&amp;/g, "&")
      .replace(/&quot;/g, '"')
      .replace(/\s+/g, " ")
      .trim();
  }

  function parseCards(html) {
    const regex = /<a\s+[^>]*href="(https:\/\/wlext\.is\/series\/[^"]+)"[^>]*>([\s\S]*?)<\/a>/gi;
    let m;
    const items = [];
    const seen = new Set();
    while ((m = regex.exec(html)) !== null) {
      const url = m[1].trim();
      if (seen.has(url)) continue;

      const tag = m[0];
      const inner = m[2];

      const tm = tag.match(/title="([^"]+)"/i) || 
                 tag.match(/alt="([^"]+)"/i) || 
                 inner.match(/title="([^"]+)"/i) || 
                 inner.match(/alt="([^"]+)"/i);
      const rawTitle = tm ? tm[1] : "";
      const cleanTitle = cleanString(rawTitle);
      if (!cleanTitle) continue;

      const im = inner.match(/data-lazy-src="([^"]+)"/i) || inner.match(/src="([^"]+)"/i);
      let poster = im ? im[1].trim() : "";
      if (poster.startsWith("data:image")) {
        const im2 = inner.match(/data-lazy-srcset="([^",\s]+)/i);
        poster = im2 ? im2[1].trim() : "";
      }

      seen.add(url);
      items.push(new MultimediaItem({
        title: cleanTitle,
        url: url,
        posterUrl: poster,
        type: "series"
      }));
    }
    return items;
  }

  async function getHome(callback) {
    try {
      // 1. Featured Telenovelas from /telenovela-world-1/
      let featured = [];
      try {
        let res1 = await http_get("https://wlext.is/telenovela-world-1/", defaultHeaders);
        if (res1 && res1.body) {
          featured = parseCards(res1.body);
        }
      } catch (e1) {}

      // 2. Catalog from /genre/telenovela/
      let catalog = [];
      try {
        let res2 = await http_get("https://wlext.is/genre/telenovela/", defaultHeaders);
        if (res2 && res2.body) {
          catalog = parseCards(res2.body);
        }
      } catch (e2) {}

      let homeData = {
        "Featured Telenovelas": featured,
        "Telenovela World": catalog
      };

      if (callback && typeof callback === "function") {
        callback({ success: true, data: homeData });
      }
      return homeData;
    } catch (e) {
      if (callback && typeof callback === "function") {
        callback({ success: false, errorCode: "FETCH_ERROR", message: e.message || String(e) });
      }
      return { "Featured Telenovelas": [], "Telenovela World": [] };
    }
  }

  async function getCategoryPage(category, page) {
    const routes = {
      "Featured Telenovelas": "https://wlext.is/telenovela-world-1/",
      "Telenovela World": "https://wlext.is/genre/telenovela/"
    };
    const root = routes[category];
    if (!root || page < 2) return [];
    const res = await http_get(root + "page/" + page + "/", defaultHeaders);
    return res && res.body ? parseCards(res.body) : [];
  }

  async function search(query, callback) {
    try {
      let searchUrl = "https://wlext.is/?s=" + encodeURIComponent(query);
      let res = await http_get(searchUrl, defaultHeaders);
      if (!res || !res.body) {
        if (callback && typeof callback === "function") callback({ success: true, data: [] });
        return [];
      }

      let html = res.body;
      let regex = /<article[\s\S]*?<\/article>/gi;
      let m;
      let items = [];
      let seen = new Set();

      while ((m = regex.exec(html)) !== null) {
        let art = m[0];
        let lm = art.match(/<h2 class="entry-title">\s*<a\s+[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/i) ||
                 art.match(/<a\s+[^>]*href="([^"]+)"[^>]*title="([^"]+)"/i);
        if (!lm) continue;

        let u = lm[1].trim();
        if (!u.includes("/series/")) continue;
        if (seen.has(u)) continue;
        seen.add(u);

        let title = cleanString(lm[2]);
        let im = art.match(/data-lazy-src="([^"]+)"/i) || art.match(/src="([^"]+)"/i);
        let poster = im ? im[1].trim() : "";
        if (poster.startsWith("data:image")) {
          let im2 = art.match(/data-lazy-srcset="([^",\s]+)/i);
          poster = im2 ? im2[1].trim() : "";
        }

        items.push(new MultimediaItem({
          title: title,
          url: u,
          posterUrl: poster,
          type: "series"
        }));
      }

      // Fallback to parseCards if no articles matched
      if (items.length === 0) {
        items = parseCards(html).filter(it => it.url && it.url.includes("/series/"));
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
      let titleMatch = html.match(/<h1[^>]*class="[^"]*entry-title[^"]*"[^>]*>([\s\S]*?)<\/h1>/i) ||
                       html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
      let title = titleMatch ? cleanString(titleMatch[1]) : "Unknown Telenovela";

      let posterUrl = "";
      let imgRegex = /<img[^>]+(?:data-lazy-src|src)="([^"]+)"/gi;
      let im;
      while ((im = imgRegex.exec(html)) !== null) {
        let src = im[1].trim();
        if (src.includes("data:image")) continue;
        if (src.includes("LOGO") || src.includes("VIP") || src.includes("sticker") || src.includes("icon") || src.includes("banner")) continue;
        if (src.includes("/uploads/")) {
          posterUrl = src;
          break;
        }
      }

      let descMatch = html.match(/<div class="entry-content">([\s\S]*?)<\/div>/i);
      let description = descMatch ? cleanString(descMatch[1]) : "";

      let epSelectMatch = html.match(/<select[^>]*id="loadepisode"[^>]*>([\s\S]*?)<\/select>/i);
      let episodes = [];

      if (epSelectMatch) {
        let optRegex = /<option[^>]+value="([^"]+)"[^>]*>([\s\S]*?)<\/option>/gi;
        let om;
        let epIndex = 1;
        let seenEps = new Set();

        while ((om = optRegex.exec(epSelectMatch[1])) !== null) {
          let val = om[1].trim();
          let epRaw = cleanString(om[2]);
          if (!val || val.includes("select") || val.includes("server")) continue;

          let numMatch = epRaw.match(/(\d+)/) || val.match(/(\d+)/);
          let epNum = numMatch ? parseInt(numMatch[1], 10) : epIndex;

          let sep = url.includes("?") ? "&" : "?";
          let epFullUrl = url + sep + val;
          if (seenEps.has(epFullUrl)) continue;
          seenEps.add(epFullUrl);

          episodes.push(new Episode({
            name: epRaw || ("Episode " + epNum),
            season: 1,
            episode: epNum,
            posterUrl: posterUrl,
            url: epFullUrl
          }));
          epIndex++;
        }
      }

      // Standalone single episode fallback if no episode dropdown exists
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

  async function extractOkRu(embedUrl, streams) {
    try {
      let cleanUrl = embedUrl;
      if (cleanUrl.startsWith("//")) cleanUrl = "https:" + cleanUrl;
      let res = await http_get(cleanUrl, {
        "User-Agent": defaultHeaders["User-Agent"],
        "Referer": "https://ok.ru/"
      });
      if (!res || !res.body) return;

      let html = res.body;
      let optMatch = html.match(/data-options="([^"]+)"/i);
      if (!optMatch) return;

      let rawOpt = optMatch[1].replace(/&quot;/g, '"').replace(/&amp;/g, '&');
      let opt = JSON.parse(rawOpt);
      if (opt.flashvars && opt.flashvars.metadata) {
        let meta = typeof opt.flashvars.metadata === "string" 
          ? JSON.parse(opt.flashvars.metadata) 
          : opt.flashvars.metadata;

        // 1. Master Adaptive HLS Stream (1080p Auto)
        if (meta.hlsManifestUrl) {
          streams.push(new StreamResult({
            source: "WLEXT OK.ru (HLS Auto 1080p)",
            name: "OK.ru Auto FHD",
            url: meta.hlsManifestUrl,
            quality: "1080p",
            type: "m3u8",
            headers: {
              "Referer": "https://ok.ru/",
              "User-Agent": defaultHeaders["User-Agent"]
            }
          }));
        }

        // 2. Direct MP4 Streams
        if (Array.isArray(meta.videos)) {
          for (let v of meta.videos) {
            if (!v.url) continue;
            let q = "480p";
            if (v.name === "full") q = "1080p";
            else if (v.name === "hd") q = "720p";
            else if (v.name === "sd") q = "480p";
            else if (v.name === "low") q = "360p";
            else if (v.name === "lowest") q = "240p";
            else if (v.name === "mobile") q = "144p";

            streams.push(new StreamResult({
              source: "WLEXT OK.ru (" + q + " Direct)",
              name: "OK.ru " + q,
              url: v.url,
              quality: q,
              type: "mp4",
              headers: {
                "Referer": "https://ok.ru/",
                "User-Agent": defaultHeaders["User-Agent"]
              }
            }));
          }
        }
      }
    } catch (err) {}
  }

  function normalizeEmbedUrl(url, baseUrl) {
    let value = String(url || "")
      .replace(/&amp;/g, "&")
      .replace(/&#038;/g, "&")
      .replace(/&quot;/g, '"')
      .trim();
    if (value.startsWith("//")) return "https:" + value;
    if (value.startsWith("/")) {
      let origin = String(baseUrl || "").match(/^(https?:\/\/[^/]+)/i);
      return origin ? origin[1] + value : value;
    }
    return value;
  }

  function withServer(url, server) {
    let clean = String(url || "").replace(/([?&])server=[^&#]*&?/i, "$1");
    clean = clean.replace(/[?&]$/, "");
    let hash = "";
    let hashAt = clean.indexOf("#");
    if (hashAt >= 0) {
      hash = clean.substring(hashAt);
      clean = clean.substring(0, hashAt);
    }
    return clean + (clean.includes("?") ? "&" : "?") + "server=" + encodeURIComponent(server) + hash;
  }

  function mediaQuality(text) {
    let value = String(text || "");
    let dimensions = value.match(/\b\d{3,5}\s*[x×]\s*(\d{3,5})\b/i);
    let height = dimensions ? parseInt(dimensions[1], 10) : 0;
    if (!height) {
      let scan = value.match(/(?:^|[^0-9])(2160|1440|1080|720|576|480|360|240)(?:p\b|(?=[_.?/#&-]))/i);
      height = scan ? parseInt(scan[1], 10) : 0;
    }
    if (!height && /\b(?:4k|uhd)\b/i.test(value)) return "4K";
    if (!height && /\b(?:2k|qhd)\b/i.test(value)) return "2K";
    if (!height && /\b(?:fhd|full\s*hd)\b/i.test(value)) return "1080p";
    if (height >= 1800) return "4K";
    if (height >= 1260) return "2K";
    if (height >= 900) return "1080p";
    if (height >= 600) return "720p";
    if (height >= 420) return "480p";
    if (height > 0) return "360p";
    return "Auto";
  }

  function resolveMediaUrl(url, baseUrl) {
    let value = String(url || "").trim().replace(/&amp;/g, "&");
    if (/^https?:\/\//i.test(value)) return value;
    if (value.startsWith("//")) {
      let protocol = String(baseUrl || "").match(/^(https?:)/i);
      return (protocol ? protocol[1] : "https:") + value;
    }
    let origin = String(baseUrl || "").match(/^(https?:\/\/[^/]+)/i);
    if (!origin) return "";
    if (value.startsWith("/")) return origin[1] + value;
    let cleanBase = String(baseUrl).split(/[?#]/)[0];
    let pathPart = cleanBase.substring(origin[1].length);
    let basePath = pathPart.substring(0, pathPart.lastIndexOf("/") + 1);
    let parts = (basePath + value).split("/");
    let normalized = [];
    for (let part of parts) {
      if (!part || part === ".") continue;
      if (part === "..") normalized.pop();
      else normalized.push(part);
    }
    return origin[1] + "/" + normalized.join("/");
  }

  function addMediaCandidate(url, referer, streams, seen, sourceName, hint) {
    let mediaUrl = resolveMediaUrl(url, referer);
    if (!mediaUrl || seen.has(mediaUrl)) return;
    seen.add(mediaUrl);
    let isHls = /\.m3u8(?:\?|$)/i.test(mediaUrl);
    let quality = mediaQuality(String(hint || "") + " " + mediaUrl);
    streams.push(new StreamResult({
      // SkyStream derives quality from `source`; the JS bridge does not carry
      // separate `quality` or `type` fields from plugin objects.
      source: sourceName + " " + quality + (isHls ? " HLS" : " Direct"),
      name: quality + (isHls ? " HLS" : ""),
      url: mediaUrl,
      headers: {
        "Referer": referer,
        "User-Agent": defaultHeaders["User-Agent"]
      }
    }));
  }

  async function collectMedia(body, referer, streams, seen, sourceName) {
    let html = String(body || "")
      .replace(/\\\//g, "/")
      .replace(/\\u0026/gi, "&")
      .replace(/&#038;/g, "&")
      .replace(/&amp;/g, "&");
    let regex = /(?:https?:)?\/\/[^"'\s<>]+?\.(?:m3u8|mp4)(?:\?[^"'\s<>]*)?/gi;
    let match;
    let candidates = [];
    while ((match = regex.exec(html)) !== null) {
      let mediaUrl = match[0].replace(/[),;]+$/, "");
      candidates.push({ url: mediaUrl, hint: html.substring(Math.max(0, match.index - 96), match.index) });
    }
    let relativeRegex = /(?:^|[\s"'=(])((?:\.\.?\/|\/)[^"'\s<>]+?\.(?:m3u8|mp4)(?:\?[^"'\s<>]*)?)/gim;
    while ((match = relativeRegex.exec(html)) !== null) {
      let mediaUrl = match[1].replace(/[),;]+$/, "");
      candidates.push({ url: mediaUrl, hint: html.substring(Math.max(0, match.index - 96), match.index) });
    }

    // Static hosts often expose a master playlist rather than variant links.
    // Expand its renditions so SkyStream's at-or-below quality cap can filter
    // them using the source label instead of letting mpv choose an uncapped HD
    // rendition behind the cap.
    for (let candidate of candidates) {
      let mediaUrl = resolveMediaUrl(candidate.url, referer);
      if (/\.m3u8(?:\?|$)/i.test(mediaUrl) && !seen.has(mediaUrl)) {
        try {
          let playlist = await quickHttpGet(mediaUrl, {
            "User-Agent": defaultHeaders["User-Agent"],
            "Referer": referer
          }, 4500);
          let playlistBody = playlist && playlist.body ? String(playlist.body) : "";
          let variants = [];
          if (playlistBody.indexOf("#EXTM3U") >= 0) {
            let lines = playlistBody.replace(/\r/g, "").split("\n");
            for (let i = 0; i < lines.length; i++) {
              if (!/^\s*#EXT-X-STREAM-INF:/i.test(lines[i])) continue;
              let attrs = lines[i];
              let uri = "";
              for (let j = i + 1; j < lines.length; j++) {
                if (lines[j].trim() && lines[j].trim().charAt(0) !== "#") {
                  uri = lines[j].trim();
                  break;
                }
              }
              if (uri) variants.push({ url: uri, hint: attrs });
            }
          }
          if (variants.length) {
            seen.add(mediaUrl);
            for (let variant of variants) {
              addMediaCandidate(variant.url, mediaUrl, streams, seen, sourceName, variant.hint);
            }
            continue;
          }
        } catch (playlistError) {}
      }
      addMediaCandidate(mediaUrl, referer, streams, seen, sourceName, candidate.hint);
    }
  }

  function iframeUrls(body, baseUrl) {
    let result = [];
    let regex = /<iframe\b[^>]*\bsrc\s*=\s*(["'])(.*?)\1/gi;
    let match;
    while ((match = regex.exec(String(body || ""))) !== null) {
      let value = normalizeEmbedUrl(match[2], baseUrl);
      if (value && !result.includes(value)) result.push(value);
    }
    return result;
  }

  function responseStatus(response) {
    let status = Number(response && (response.statusCode || response.status || 0));
    return status > 0 ? status : 0;
  }

  function responseHasContent(response) {
    let status = responseStatus(response);
    return !!(response && response.body) && (!status || (status >= 200 && status < 300));
  }

  function safeHost(url) {
    let match = String(url || "").match(/^https?:\/\/([^/:?#]+)/i);
    return match ? match[1].toLowerCase() : "unknown-host";
  }

  async function quickHttpGet(url, headers, timeoutMs) {
    let timer = null;
    let request = http_get(url, headers || {});
    try {
      return await Promise.race([
        request,
        new Promise(resolve => {
          timer = setTimeout(() => resolve(null), timeoutMs || 4500);
        })
      ]);
    } finally {
      if (timer !== null) clearTimeout(timer);
    }
  }

  async function inspectSpaFolder(iframe, streams, seenUrls, diagnostics) {
    let originMatch = String(iframe).match(/^(https?:\/\/[^/]+)/i);
    let folderMatch = String(iframe).match(/#([^?&#/]+)/);
    if (!originMatch || !folderMatch) return false;
    let origin = originMatch[1];
    let folderId = folderMatch[1];
    let apiUrl = origin + "/api/v1/folder?id=" + encodeURIComponent(folderId);
    try {
      let response = await quickHttpGet(apiUrl, {
        "User-Agent": defaultHeaders["User-Agent"],
        "Referer": iframe,
        "Origin": origin,
        "Accept": "application/json, text/plain, */*"
      }, 4500);
      if (!response) {
        diagnostics.push(safeHost(iframe) + "=folder-api-timeout");
        return true;
      }
      let status = responseStatus(response);
      let body = String(response.body || "");
      if (status === 404 || /folder not found or deleted/i.test(body)) {
        diagnostics.push(safeHost(iframe) + "=folder-deleted");
        return true;
      }
      if (!responseHasContent(response)) {
        diagnostics.push(safeHost(iframe) + "=folder-api-" + (status || "unavailable"));
        return true;
      }
      let before = streams.length;
      await collectMedia(body, apiUrl, streams, seenUrls, "WLEXT " + safeHost(iframe));
      diagnostics.push(safeHost(iframe) + (streams.length > before ? "=media-found" : "=folder-without-direct-media"));
      return true;
    } catch (error) {
      diagnostics.push(safeHost(iframe) + "=folder-api-error");
      return true;
    }
  }

  async function loadStreams(episodeUrl, callback) {
    try {
      let streams = [];
      let res = await quickHttpGet(episodeUrl, defaultHeaders, 6000);

      if (!responseHasContent(res)) {
        throw new Error("WLEXT episode page returned HTTP " + (responseStatus(res) || "timeout or no response") + ".");
      }

      let html = res.body;
      let serverOpts = [];
      let sMatch = html.match(/<select\b(?=[^>]*(?:id=["']servers["']|name=["']server["']))[^>]*>([\s\S]*?)<\/select>/i);
      if (sMatch) {
        let optRegex = /<option\b[^>]*value=["']([^"']+)["'][^>]*>([\s\S]*?)<\/option>/gi;
        let option;
        while ((option = optRegex.exec(sMatch[1])) !== null) {
          let value = option[1].trim();
          if (value && !/select/i.test(value) && !serverOpts.some(item => item.value === value)) {
            serverOpts.push({ value: value, label: cleanString(option[2]) || value });
          }
        }
      }

      let pages = [{ body: html, url: episodeUrl, referer: "https://wlext.is/", source: "WLEXT" }];
      let serverDiagnostics = [];
      let embedDiagnostics = [];
      // WLEXT replaces the player iframe when ?server=<option> is selected.
      // Fetch every server advertised by the episode, including current SOAP
      // BOX and HYDRA values, instead of relying on obsolete hard-coded IDs.
      let serverPages = await Promise.all(serverOpts.map(async (server) => {
        try {
          let serverUrl = withServer(episodeUrl, server.value);
          let serverRes = await quickHttpGet(serverUrl, defaultHeaders, 5000);
          let status = responseStatus(serverRes);
          serverDiagnostics.push(server.value + "=" + (status || (responseHasContent(serverRes) ? "ok" : "timeout-or-no-response")));
          if (responseHasContent(serverRes)) {
            return {
              body: serverRes.body,
              url: serverUrl,
              referer: "https://wlext.is/",
              source: "WLEXT " + cleanString(server.label).replace(/^SERVER:\s*/i, "")
            };
          }
        } catch (serverError) {
          serverDiagnostics.push(server.value + "=request-error");
        }
        return null;
      }));
      pages.push(...serverPages.filter(Boolean));

      let seenFrames = new Set();
      let seenUrls = new Set();
      for (let page of pages) {
        await collectMedia(page.body, page.referer, streams, seenUrls, page.source);
        for (let iframe of iframeUrls(page.body, page.url)) {
          if (seenFrames.has(iframe)) continue;
          seenFrames.add(iframe);

          if (iframe.includes("elitecloud.top/")) {
            iframe = iframe.replace("elitecloud.top/", "elite.rpmhub.site/");
          }
          if (iframe.includes("ok.ru/videoembed/")) {
            await extractOkRu(iframe, streams);
            continue;
          }

          // Scrape static provider embeds for direct media and one nested
          // iframe level. SOAP BOX serves a JavaScript player shell rather
          // than a media URL, so don't hand its HTML page to the video player.
          if (/sobox\.top/i.test(iframe)) {
            await inspectSpaFolder(iframe, streams, seenUrls, embedDiagnostics);
            continue;
          }
          if (/elite\.rpmhub\.site/i.test(iframe)) {
            await inspectSpaFolder(iframe, streams, seenUrls, embedDiagnostics);
            continue;
          }
          try {
            let embedRes = await quickHttpGet(iframe, {
              "User-Agent": defaultHeaders["User-Agent"],
              "Referer": page.url
            }, 4500);
            if (!responseHasContent(embedRes)) {
              embedDiagnostics.push(safeHost(iframe) + "=" + (responseStatus(embedRes) || "unavailable"));
              continue;
            }
            let embedBase = embedRes.finalUrl || iframe;
            await collectMedia(embedRes.body, embedBase, streams, seenUrls, page.source + " " + safeHost(embedBase));
            for (let nested of iframeUrls(embedRes.body, embedBase)) {
              if (seenFrames.has(nested) || nested.includes("sobox.top")) continue;
              seenFrames.add(nested);
              if (nested.includes("ok.ru/videoembed/")) {
                await extractOkRu(nested, streams);
                continue;
              }
              try {
                let nestedRes = await quickHttpGet(nested, {
                  "User-Agent": defaultHeaders["User-Agent"],
                  "Referer": embedBase
                }, 4500);
                if (responseHasContent(nestedRes)) {
                  await collectMedia(nestedRes.body, nestedRes.finalUrl || nested, streams, seenUrls, page.source + " " + safeHost(nested));
                } else {
                  embedDiagnostics.push(safeHost(nested) + "=" + (responseStatus(nestedRes) || "unavailable"));
                }
              } catch (nestedError) {}
            }
          } catch (embedError) {
            embedDiagnostics.push(safeHost(iframe) + "=request-error");
          }
        }
      }

      if (callback && typeof callback === "function") {
        callback(streams.length
          ? { success: true, data: streams }
          : { success: false, errorCode: "STREAMS_UNAVAILABLE", message: "WLEXT listed servers, but none exposed a playable media URL. SOAP BOX currently uses a JavaScript player, and the advertised HYDRA link may be unavailable." });
      }
      if (!streams.length) {
        console.error("[WLEXT] No playable media URLs. Servers=" + (serverDiagnostics.join(",") || "none") + "; embeds=" + (embedDiagnostics.join(",") || "none"));
      }
      return streams;
    } catch (e) {
      if (callback && typeof callback === "function") {
        callback({ success: false, errorCode: "STREAMS_UNAVAILABLE", message: e.message || "WLEXT did not return a playable server." });
      }
      console.error("[WLEXT] Stream extraction failed: " + (e.message || String(e)));
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
