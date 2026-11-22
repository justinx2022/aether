var PluginModule = (() => {
  (function() {
    'use strict';

    var mt = typeof MultimediaItem !== 'undefined' ? MultimediaItem : class { constructor(t) { Object.assign(this, t); } };
    var gt = typeof Episode !== 'undefined' ? Episode : class { constructor(t) { Object.assign(this, t); } };
    var Nt = typeof StreamResult !== 'undefined' ? StreamResult : class {
      constructor(t) {
        this.url = t.url;
        this.source = t.source || t.name;
        this.name = t.name || t.source;
        this.providerName = t.providerName || '';
        this.headers = t.headers || {};
        this.protocol = t.protocol || 'hls';
        this.file_index = t.file_index;
        if (t.quality) this.quality = t.quality;
        if (t.size) this.size = t.size;
        if (t.type) this.type = t.type;
        if (t.isM3U8) this.isM3U8 = t.isM3U8;
      }
    };
    var Ht = typeof Actor !== 'undefined' ? Actor : class { constructor(t) { Object.assign(this, t); } };

    var CINEMETA_CATALOG = 'https://cinemeta-catalogs.strem.io/top/catalog';
    var CINEMETA_V3 = 'https://v3-cinemeta.strem.io';

    var DEFAULT_HEADERS = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Accept': 'application/json, text/plain, */*'
    };
    var CATEGORY_PAGE_SIZE = 24;

    function parseQuality(str) {
      var s = String(str || '').toLowerCase();
      if (s.includes('4k') || s.includes('2160p') || s.includes('uhd')) return 2160;
      if (s.includes('1080p') || s.includes('fhd') || s.includes('bluray') || s.includes('blu-ray')) return 1080;
      if (s.includes('720p') || s.includes('hd')) return 720;
      if (s.includes('480p')) return 480;
      return 1080;
    }

    async function fetchJson(url, headers) {
      try {
        var h = headers || DEFAULT_HEADERS;
        var res = await http_get(url, h);
        if (!res) return null;
        var body = typeof res === 'string' ? res : (res.body || '');
        if (!body) return null;
        return JSON.parse(body);
      } catch (e) {
        return null;
      }
    }

    async function fetchText(url, headers) {
      try {
        var h = headers || DEFAULT_HEADERS;
        var res = await http_get(url, h);
        if (!res) return '';
        return typeof res === 'string' ? res : (res.body || '');
      } catch (e) {
        return '';
      }
    }

    async function getHome(cb) {
      try {
        var feeds = [
          { title: 'Popular Movies', url: CINEMETA_CATALOG + '/movie/top.json', type: 'movie' },
          { title: 'Popular Series', url: CINEMETA_CATALOG + '/series/top.json', type: 'series' },
          { title: 'Top Rated Movies', url: CINEMETA_CATALOG + '/movie/imdbRating.json', type: 'movie' },
          { title: 'Top Rated Series', url: CINEMETA_CATALOG + '/series/imdbRating.json', type: 'series' },
          { title: 'Action & Adventure', url: CINEMETA_CATALOG + '/movie/top/genre=Action.json', type: 'movie' },
          { title: 'Sci-Fi & Fantasy', url: CINEMETA_CATALOG + '/series/top/genre=Sci-Fi.json', type: 'series' }
        ];

        var data = {};
        for (var i = 0; i < feeds.length; i++) {
          var feed = feeds[i];
          var json = await fetchJson(feed.url);
          if (json && Array.isArray(json.metas)) {
            var items = [];
            var metas = json.metas.slice(0, 24);
            for (var j = 0; j < metas.length; j++) {
              var m = metas[j];
              items.push(new mt({
                title: m.name,
                url: JSON.stringify({ id: m.imdb_id || m.id, type: feed.type, title: m.name, year: m.releaseInfo }),
                posterUrl: m.poster || '',
                bannerUrl: m.background || '',
                description: m.description || '',
                year: parseInt(m.releaseInfo, 10) || undefined,
                score: parseFloat(m.imdbRating) || undefined,
                type: feed.type
              }));
            }
            if (items.length > 0) {
              data[feed.title] = items;
            }
          }
        }
        cb({ success: true, data: data });
      } catch (err) {
        cb({ success: false, errorCode: 'SITE_OFFLINE', message: err.message || String(err) });
      }
    }

    async function getCategoryPage(category, page, offset) {
      var feeds = [
        { title: 'Popular Movies', url: CINEMETA_CATALOG + '/movie/top.json', type: 'movie' },
        { title: 'Popular Series', url: CINEMETA_CATALOG + '/series/top.json', type: 'series' },
        { title: 'Top Rated Movies', url: CINEMETA_CATALOG + '/movie/imdbRating.json', type: 'movie' },
        { title: 'Top Rated Series', url: CINEMETA_CATALOG + '/series/imdbRating.json', type: 'series' },
        { title: 'Action & Adventure', url: CINEMETA_CATALOG + '/movie/top/genre=Action.json', type: 'movie' },
        { title: 'Sci-Fi & Fantasy', url: CINEMETA_CATALOG + '/series/top/genre=Sci-Fi.json', type: 'series' }
      ];
      var feed = feeds.find(function(item) { return item.title === category; });
      if (!feed) return [];
      var start = Math.max(0, Number(offset) || 0);
      // This catalogue endpoint accepts `skip` for the unfiltered catalogs,
      // but silently drops genre filters when both extras are combined. Its
      // genre feeds return one 50-item result, so page those locally.
      var isGenreFeed = feed.url.indexOf('/genre=') >= 0;
      var url = isGenreFeed
        ? feed.url
        : feed.url.replace(/\.json$/, '/skip=' + start + '.json');
      var json = await fetchJson(url);
      if (!json || !Array.isArray(json.metas)) return [];
      var metas = isGenreFeed
        ? json.metas.slice(start, start + CATEGORY_PAGE_SIZE)
        : json.metas.slice(0, CATEGORY_PAGE_SIZE);
      return metas.map(function(m) {
        return new mt({
          title: m.name,
          url: JSON.stringify({ id: m.imdb_id || m.id, type: feed.type, title: m.name, year: m.releaseInfo }),
          posterUrl: m.poster || '',
          bannerUrl: m.background || '',
          description: m.description || '',
          year: parseInt(m.releaseInfo, 10) || undefined,
          score: parseFloat(m.imdbRating) || undefined,
          type: feed.type
        });
      });
    }

    async function search(query, cb) {
      try {
        var q = encodeURIComponent(String(query || '').trim());
        var movPromise = fetchJson(CINEMETA_V3 + '/catalog/movie/top/search=' + q + '.json');
        var serPromise = fetchJson(CINEMETA_V3 + '/catalog/series/top/search=' + q + '.json');

        var results = [];
        var resList = await Promise.all([movPromise, serPromise]);

        var types = ['movie', 'series'];
        for (var i = 0; i < resList.length; i++) {
          var json = resList[i];
          var t = types[i];
          if (json && Array.isArray(json.metas)) {
            for (var j = 0; j < json.metas.length; j++) {
              var m = json.metas[j];
              results.push(new mt({
                title: m.name,
                url: JSON.stringify({ id: m.imdb_id || m.id, type: t, title: m.name, year: m.releaseInfo }),
                posterUrl: m.poster || '',
                bannerUrl: m.background || '',
                description: m.description || '',
                year: parseInt(m.releaseInfo, 10) || undefined,
                score: parseFloat(m.imdbRating) || undefined,
                type: t
              }));
            }
          }
        }
        cb({ success: true, data: results });
      } catch (err) {
        cb({ success: true, data: [] });
      }
    }

    async function load(rawUrl, cb) {
      try {
        var parsed = null;
        try {
          parsed = JSON.parse(rawUrl);
        } catch (e) {
          var parts = String(rawUrl).split('|');
          parsed = { id: parts[0], type: parts[1] || 'movie' };
        }

        var id = parsed.id || parsed.imdbId;
        var type = parsed.type || 'movie';

        var metaUrl = CINEMETA_V3 + '/meta/' + type + '/' + id + '.json';
        var json = await fetchJson(metaUrl);

        if (!json || !json.meta) {
          return cb({ success: false, errorCode: 'NOT_FOUND', message: 'Title not found' });
        }

        var m = json.meta;
        var tmdbId = m.moviedb_id || undefined;
        var cast = [];
        if (Array.isArray(m.cast)) {
          for (var i = 0; i < Math.min(m.cast.length, 15); i++) {
            cast.push(new Ht({ name: m.cast[i] }));
          }
        }

        var episodes = [];
        if (type === 'movie') {
          episodes.push(new gt({
            name: 'Full Movie',
            season: 1,
            episode: 1,
            posterUrl: m.poster || '',
            description: m.description || '',
            url: JSON.stringify({ imdbId: id, tmdbId: tmdbId, type: 'movie', title: m.name, year: m.releaseInfo || m.year })
          }));
        } else {
          if (Array.isArray(m.videos) && m.videos.length > 0) {
            for (var k = 0; k < m.videos.length; k++) {
              var v = m.videos[k];
              episodes.push(new gt({
                name: v.title || v.name || ('Episode ' + (v.episode || v.number || (k + 1))),
                season: v.season || 1,
                episode: v.episode || v.number || (k + 1),
                posterUrl: v.thumbnail || m.poster || '',
                description: v.overview || v.description || '',
                airDate: v.released || '',
                url: JSON.stringify({
                  imdbId: id,
                  tmdbId: tmdbId,
                  type: 'series',
                  season: v.season || 1,
                  episode: v.episode || v.number || (k + 1),
                  title: m.name,
                  epTitle: v.title || v.name
                })
              }));
            }
          } else {
            episodes.push(new gt({
              name: 'Episode 1',
              season: 1,
              episode: 1,
              posterUrl: m.poster || '',
              url: JSON.stringify({ imdbId: id, tmdbId: tmdbId, type: 'series', season: 1, episode: 1, title: m.name })
            }));
          }
        }

        var item = new mt({
          title: m.name,
          url: rawUrl,
          posterUrl: m.poster || '',
          bannerUrl: m.background || '',
          logoUrl: m.logo || '',
          description: m.description || '',
          year: parseInt(m.releaseInfo || m.year, 10) || undefined,
          score: parseFloat(m.imdbRating) || undefined,
          cast: cast,
          type: type,
          episodes: episodes
        });

        cb({ success: true, data: item });
      } catch (err) {
        cb({ success: false, errorCode: 'PARSE_ERROR', message: err.message || String(err) });
      }
    }

    function withTimeout(promise, ms, fallback) {
      var fb = fallback !== undefined ? fallback : null;
      return Promise.race([
        promise,
        new Promise(function(resolve) {
          setTimeout(function() { resolve(fb); }, ms);
        })
      ]);
    }

    var cachedMdBase = null;
    async function getMoviesDriveBase() {
      if (cachedMdBase) return cachedMdBase;
      try {
        var data = await fetchJson('https://raw.githubusercontent.com/SaurabhKaperwan/Utils/refs/heads/main/urls.json');
        if (data && data.moviesdrive) {
          cachedMdBase = data.moviesdrive.replace(/\/+$/, '');
          return cachedMdBase;
        }
      } catch (e) {}
      cachedMdBase = 'https://new5.moviesdrive.beer';
      return cachedMdBase;
    }

    function cleanTitle(title) {
      return String(title || '')
        .replace(/\s*\(\d{4}\).*$/, '')
        .replace(/[^a-zA-Z0-9\s]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
    }

    function extractLinkParam(urlStr) {
      var curr = String(urlStr || '');
      for (var i = 0; i < 3; i++) {
        var m = curr.match(/[?&]link=([^#&]+)/i);
        if (!m) break;
        var target = m[1];
        if (!/^https?:\/\//i.test(target)) {
          try { target = decodeURIComponent(target); } catch (e) { break; }
        }
        if (/^https?:\/\//i.test(target)) {
          curr = target;
        } else {
          break;
        }
      }
      return /^https?:\/\//i.test(curr) && curr !== urlStr ? curr : null;
    }

    async function resolveHubCloudDirect(gpdlUrl) {
      try {
        var res = await http_get(gpdlUrl, {
          'User-Agent': DEFAULT_HEADERS['User-Agent'],
          'Referer': 'https://gamerxyt.com/'
        });
        if (!res) return null;
        var final = res.finalUrl || '';
        var direct = extractLinkParam(final);
        if (direct) return direct;

        if (final.includes('workers.dev') || final.includes('hubcloud')) {
          var res2 = await http_get(final, {
            'User-Agent': DEFAULT_HEADERS['User-Agent']
          });
          if (res2) {
            var direct2 = extractLinkParam(res2.finalUrl);
            if (direct2) return direct2;
            if (res2.finalUrl) return res2.finalUrl;
          }
        }
        return final || null;
      } catch (e) {
        return null;
      }
    }

    async function extractHcsStreams(hubUrl, qualityHint) {
      var results = [];
      try {
        var hubHeaders = {
          'User-Agent': DEFAULT_HEADERS['User-Agent'],
          'Cookie': 'xla=s4t'
        };
        var html1 = await fetchText(hubUrl, hubHeaders);
        if (!html1) return results;

        var targetHtml = html1;
        var referer = hubUrl;

        var dlMatch = html1.match(/id=["']download["'][^>]*href=["']([^"']+)["']/i);
        if (dlMatch) {
          var nextUrl = dlMatch[1].startsWith('http') ? dlMatch[1] : (new URL(dlMatch[1], hubUrl).href);
          var html2 = await fetchText(nextUrl, Object.assign({}, hubHeaders, { Referer: hubUrl }));
          if (html2) {
            targetHtml = html2;
            referer = nextUrl;
          }
        }

        var pxlMatch = targetHtml.match(/var\s+pxl\w*\s*=\s*["']([^"']+)["']/i);
        var pxlId = null;
        if (pxlMatch) {
          var idM = pxlMatch[1].match(/\/u\/([a-zA-Z0-9]+)/);
          if (idM) pxlId = idM[1];
        }

        var linkMatches = [...targetHtml.matchAll(/<a[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi)];
        for (var i = 0; i < linkMatches.length; i++) {
          var m = linkMatches[i];
          var href = m[1];
          var text = m[2].replace(/<[^>]+>/g, '').trim();
          var lower = text.toLowerCase();
          var isBtn = /btn/i.test(m[0]);

          if (!pxlId && /pixeldrain|pixel\s*server/i.test(lower)) {
            var pxlM = href.match(/\/u\/([a-zA-Z0-9]+)/);
            if (pxlM) pxlId = pxlM[1];
          }

          if ((lower.includes('10gbps') || /gpdl\.hubcloud\./i.test(href)) && isBtn) {
            var fullHref = href.startsWith('http') ? href : (new URL(href, referer).href);
            var direct = await resolveHubCloudDirect(fullHref);
            var resolvedUrl = direct || fullHref;
            results.push({
              url: resolvedUrl,
              name: '🚀 HCS • HubCloud 10Gbps [' + (qualityHint || '1080p') + ']',
              source: 'HubCloud 10Gbps',
              quality: parseQuality(qualityHint || '1080p'),
              type: 'mkv',
              isM3U8: false,
              isHcs: true,
              headers: { 'User-Agent': DEFAULT_HEADERS['User-Agent'] }
            });
          } else if ((lower.includes('download file') || lower.includes('fsl server') || lower.includes('s3 server')) && isBtn) {
            if (!href.startsWith('#') && !href.startsWith('javascript:')) {
              var directHref = href.startsWith('http') ? href : (new URL(href, referer).href);
              results.push({
                url: directHref,
                name: '⚡ HCS • HighSpeed Direct [' + (qualityHint || '1080p') + ']',
                source: 'HubCloud Direct',
                quality: parseQuality(qualityHint || '1080p'),
                type: 'mkv',
                isM3U8: false,
                isHcs: true,
                headers: { 'User-Agent': DEFAULT_HEADERS['User-Agent'] }
              });
            }
          }
        }

        if (pxlId) {
          results.unshift({
            url: 'https://pixeldrain.com/api/file/' + pxlId + '?download',
            name: '⚡ HCS • PixelDrain Direct [' + (qualityHint || '1080p') + ']',
            source: 'PixelDrain Direct',
            quality: parseQuality(qualityHint || '1080p'),
            type: 'mkv',
            isM3U8: false,
            isHcs: true,
            headers: { 'User-Agent': DEFAULT_HEADERS['User-Agent'] }
          });
        }
      } catch (e) {}
      return results;
    }

    function normalizeArchiveTitle(value) {
      return String(value || '')
        .replace(/\s*\(\d{4}\).*$/, '')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, ' ')
        .trim();
    }

    async function findArchivePublicDomainStreams(title, year) {
      if (!title) return [];

      try {
        var cleanTitleValue = String(title).replace(/["\\]/g, ' ').replace(/\s+/g, ' ').trim();
        var query = 'title:"' + cleanTitleValue + '" AND mediatype:movies AND licenseurl:*publicdomain*';
        var searchUrl = 'https://archive.org/advancedsearch.php?q=' + encodeURIComponent(query) +
          '&fl%5B%5D=identifier&fl%5B%5D=title&fl%5B%5D=year&fl%5B%5D=licenseurl&output=json&rows=8';
        var searchData = await fetchJson(searchUrl);
        var docs = searchData && searchData.response && Array.isArray(searchData.response.docs)
          ? searchData.response.docs
          : [];
        var normalizedTitle = normalizeArchiveTitle(title);
        var wantedYear = year ? String(year).slice(0, 4) : '';

        var matches = docs.filter(function(doc) {
          if (!doc || !doc.identifier || normalizeArchiveTitle(doc.title) !== normalizedTitle) return false;
          return !wantedYear || !doc.year || String(doc.year).slice(0, 4) === wantedYear;
        });

        for (var i = 0; i < matches.length; i++) {
          var item = matches[i];
          var metadata = await fetchJson('https://archive.org/metadata/' + encodeURIComponent(item.identifier));
          var license = String(metadata && metadata.metadata && metadata.metadata.licenseurl || item.licenseurl || '').toLowerCase();
          var hasAllowedLicense = /creativecommons\.org\/(publicdomain\/(mark|zero)\/1\.0|licenses\/publicdomain\/)/.test(license);
          if (!hasAllowedLicense || !metadata.metadata || metadata.metadata.mediatype !== 'movies' || !Array.isArray(metadata.files)) continue;

          var metadataYear = String(metadata.metadata.year || metadata.metadata.date || '').slice(0, 4);
          if (wantedYear && (!metadataYear || metadataYear !== wantedYear)) continue;

          var videoFiles = metadata.files.filter(function(file) {
            return file && typeof file.name === 'string' && /\.(mp4|m4v)$/i.test(file.name) &&
              !/(sample|thumbnail|preview)/i.test(file.name);
          });
          videoFiles.sort(function(a, b) {
            var aQuality = parseQuality(a.name);
            var bQuality = parseQuality(b.name);
            return (bQuality - aQuality) || (parseInt(b.size, 10) || 0) - (parseInt(a.size, 10) || 0);
          });
          if (videoFiles.length === 0) continue;

          var file = videoFiles[0];
          var fileUrl = 'https://archive.org/download/' + encodeURIComponent(item.identifier) + '/' +
            file.name.split('/').map(encodeURIComponent).join('/');
          return [{
            url: fileUrl,
            name: 'Internet Archive • CC0/Public Domain • MP4',
            source: 'Internet Archive Public Domain',
            type: 'mp4',
            isM3U8: false,
            headers: { 'User-Agent': DEFAULT_HEADERS['User-Agent'] }
          }];
        }
      } catch (e) {}

      return [];
    }

    async function loadStreams(rawUrl, cb) {
      try {
        var parsed = null;
        try {
          parsed = JSON.parse(rawUrl);
        } catch (e) {
          var parts = String(rawUrl).split('|');
          parsed = {
            imdbId: parts[0],
            type: parts[1] || 'movie',
            season: parseInt(parts[2], 10) || 1,
            episode: parseInt(parts[3], 10) || 1
          };
        }

        var imdbId = parsed.imdbId || parsed.id;
        var type = parsed.type || 'movie';
        var season = parsed.season || 1;
        var episode = parsed.episode || 1;
        var title = parsed.title || imdbId;
        var tmdbId = parsed.tmdbId;

        // Resolve TMDB ID in parallel if missing
        var cinemetaPromise = (!tmdbId && imdbId) ? (async function() {
          try {
            var meta = await fetchJson(CINEMETA_V3 + '/meta/' + type + '/' + imdbId + '.json');
            if (meta && meta.meta && meta.meta.moviedb_id) {
              return meta.meta.moviedb_id;
            }
          } catch (e) {}
          return null;
        })() : Promise.resolve(tmdbId);

        var streams = [];
        var seenUrls = new Set();

        // Public-domain/CC0 recordings from the Internet Archive are a direct
        // file fallback for exact movie title/year matches. No embed page is
        // returned to the player.
        var archivePromise = (async function() {
          try {
            if (type !== 'movie') return;
            var archiveStreams = await findArchivePublicDomainStreams(title, parsed.year);
            archiveStreams.forEach(function(stream) {
              if (stream && stream.url && !seenUrls.has(stream.url)) {
                seenUrls.add(stream.url);
                streams.push(new Nt(stream));
              }
            });
          } catch (e) {}
        })();

        // 0. High-Speed Cloud Sources (HCS) - HubCloud 10Gbps & PixelDrain Direct
        var hcsPromise = (async function() {
          try {
            var rawTitle = parsed.title;
            if (!rawTitle && imdbId) {
              try {
                var metaRes = await fetchJson(CINEMETA_V3 + '/meta/' + type + '/' + imdbId + '.json');
                if (metaRes && metaRes.meta && metaRes.meta.name) rawTitle = metaRes.meta.name;
              } catch (e) {}
            }
            if (!rawTitle) return;

            var cleanQuery = cleanTitle(rawTitle);
            if (!cleanQuery) return;

            var mdBase = await getMoviesDriveBase();
            var searchData = await fetchJson(mdBase + '/search.php?q=' + encodeURIComponent(cleanQuery) + '&page=1');
            if (!searchData || !Array.isArray(searchData.hits) || searchData.hits.length === 0) return;

            if (type === 'series') {
              var sPad = season < 10 ? ('0' + season) : String(season);
              var ePad = episode < 10 ? ('0' + episode) : String(episode);
              var matchingHits = searchData.hits.filter(function(h) {
                var pt = ((h.document && h.document.post_title) || '').toLowerCase();
                var words = cleanQuery.toLowerCase().split(' ').filter(function(w) { return w.length > 2; });
                return words.length === 0 || words.every(function(w) { return pt.includes(w); });
              });
              if (matchingHits.length === 0) return;

              var seriesHit = matchingHits.find(function(h) {
                var pt = (h.document && h.document.post_title) || '';
                return /season|series/i.test(pt);
              }) || matchingHits[0];

              if (!seriesHit || !seriesHit.document || !seriesHit.document.permalink) return;
              var pageUrl = seriesHit.document.permalink.startsWith('http') ? seriesHit.document.permalink : (mdBase + seriesHit.document.permalink);
              var pageHtml = await fetchText(pageUrl);

              var recMatches = [...pageHtml.matchAll(/href=["'](https?:\/\/[^"']*\/search-recover\.php\?[^"']*)["']/gi)];
              if (recMatches.length === 0) return;

              var recUrl = recMatches[0][1].replace(/&amp;/g, '&');
              var u = new URL(recUrl);
              var from_ac = u.searchParams.get('from_ac');
              if (!from_ac) return;

              var seasonQuery = cleanQuery + ' S' + sPad;
              var apiUrl = u.origin + u.pathname + '?api=search&page=1&from_ac=' + from_ac + '&q=' + encodeURIComponent(seasonQuery);
              var searchRes = await fetchJson(apiUrl);
              var hits = (searchRes && Array.isArray(searchRes.hits)) ? searchRes.hits : [];

              if (hits.length === 0) {
                var fallbackApiUrl = u.origin + u.pathname + '?api=search&page=1&from_ac=' + from_ac + '&q=' + encodeURIComponent(cleanQuery);
                var fbRes = await fetchJson(fallbackApiUrl);
                hits = (fbRes && Array.isArray(fbRes.hits)) ? fbRes.hits : [];
              }

              var targetHits = hits.filter(function(h) {
                var fn = (h.file_name || '').toLowerCase();
                return (fn.includes('s' + sPad + 'e' + ePad) ||
                        fn.includes('s' + season + 'e' + episode) ||
                        fn.includes('e' + ePad) ||
                        fn.includes('episode ' + episode) ||
                        fn.includes('ep ' + episode)) &&
                        !fn.includes('.zip');
              });

              if (targetHits.length === 0) return;

              targetHits.sort(function(a, b) {
                return parseQuality(b.file_name) - parseQuality(a.file_name);
              });

              for (var th = 0; th < Math.min(2, targetHits.length); th++) {
                var epHit = targetHits[th];
                var qHint = parseQuality(epHit.file_name) + 'p';
                var extracted = await extractHcsStreams(epHit.url, qHint);
                for (var ex = 0; ex < extracted.length; ex++) {
                  var st = extracted[ex];
                  if (st && st.url && !seenUrls.has(st.url)) {
                    seenUrls.add(st.url);
                    streams.push(new Nt(st));
                  }
                }
              }
            } else {
              var matchingMovieHits = searchData.hits.filter(function(h) {
                var pt = ((h.document && h.document.post_title) || '').toLowerCase();
                var words = cleanQuery.toLowerCase().split(' ').filter(function(w) { return w.length > 2; });
                return words.length === 0 || words.every(function(w) { return pt.includes(w); });
              });
              if (matchingMovieHits.length === 0) return;

              var movieHit = matchingMovieHits.find(function(h) {
                var pt = (h.document && h.document.post_title) || '';
                return !/season|series/i.test(pt);
              }) || matchingMovieHits[0];

              if (!movieHit || !movieHit.document || !movieHit.document.permalink) return;
              var pageUrl = movieHit.document.permalink.startsWith('http') ? movieHit.document.permalink : (mdBase + movieHit.document.permalink);
              var pageHtml = await fetchText(pageUrl);

              var hubUrls = [];
              var archiveMatches = [...pageHtml.matchAll(/href=["'](https?:\/\/[^"']*\/archive\/\d+\/?)["']/gi)];

              for (var a = 0; a < Math.min(3, archiveMatches.length); a++) {
                var arcUrl = archiveMatches[a][1];
                var arcHtml = await fetchText(arcUrl);
                var hubM = arcHtml.match(/href=["'](https?:\/\/[^"']*hubcloud[^"']*)["']/i);
                if (hubM) {
                  hubUrls.push({ url: hubM[1], quality: '1080p' });
                }
              }

              if (hubUrls.length === 0) {
                var directHub = [...pageHtml.matchAll(/href=["'](https?:\/\/[^"']*hubcloud[^"']*)["']/gi)];
                for (var d = 0; d < Math.min(2, directHub.length); d++) {
                  hubUrls.push({ url: directHub[d][1], quality: '1080p' });
                }
              }

              for (var hu = 0; hu < hubUrls.length; hu++) {
                var item = hubUrls[hu];
                var extracted = await extractHcsStreams(item.url, item.quality);
                for (var ex = 0; ex < extracted.length; ex++) {
                  var st = extracted[ex];
                  if (st && st.url && !seenUrls.has(st.url)) {
                    seenUrls.add(st.url);
                    streams.push(new Nt(st));
                  }
                }
              }
            }
          } catch (e) {}
        })();

        // Helper: VidRock AES-256-GCM URL Decryption
        async function decryptVidrockUrl(enc) {
          try {
            var b64 = enc.replace(/-/g, '+').replace(/_/g, '/');
            while (b64.length % 4 !== 0) b64 += '=';
            var raw = atob(b64);
            if (raw.length < 28) return null;
            var ivStr = btoa(raw.slice(0, 12));
            var cipherTagStr = btoa(raw.slice(12));
            var keyHex = '7f3e9c2a8b5d1f4e6a9c3b7d2e5f8a1c4b6d9e2f5a8c1b4d7e9f2a5c8b1d4e7f';
            var keyBytes = '';
            for (var i = 0; i < keyHex.length; i += 2) {
              keyBytes += String.fromCharCode(parseInt(keyHex.substr(i, 2), 16));
            }
            var keyB64 = btoa(keyBytes);
            if (globalThis.crypto && typeof globalThis.crypto.decryptAES === 'function') {
              var plain = await globalThis.crypto.decryptAES(cipherTagStr, keyB64, ivStr, { mode: 'gcm' });
              if (plain && plain.startsWith('http')) return plain;
            }
          } catch (e) {}
          return null;
        }

        var resolvedTmdb = tmdbId || await cinemetaPromise;

        // 1. VidZee Multi-Server HLS Streams (High-Speed .m3u8 from Vercetti & NGCloud CDNs)
        var vidzeePromise = (async function() {
          try {
            if (!resolvedTmdb) return;
            var path = type === 'movie' ? ('movie/' + resolvedTmdb) : ('tv/' + resolvedTmdb + '/' + season + '/' + episode);
            var zServers = type === 'movie' ? ['peak', 'dcloud', 'tik'] : ['dcloud', 'tik', 'v6:English'];
            for (var s = 0; s < zServers.length; s++) {
              var sId = zServers[s];
              var zUrl = 'https://core.vidzee.wtf/streams/' + path + '?s=' + encodeURIComponent(sId);
              var json = await fetchJson(zUrl, {
                'User-Agent': DEFAULT_HEADERS['User-Agent'],
                'Referer': 'https://player.vidzee.wtf/',
                'Origin': 'https://player.vidzee.wtf'
              });
              if (json && json.url && !seenUrls.has(json.url)) {
                seenUrls.add(json.url);
                var isHLS = !json.url.includes('.mp4') && !json.url.includes('.mkv');
                var sLabel = sId.replace('v6:', '');
                streams.push(new Nt({
                  url: json.url,
                  source: 'VidZee ' + sLabel,
                  name: '⚡ VidZee ' + sLabel + ' [1080p Master HLS]',
                  quality: 1080,
                  type: isHLS ? 'hls' : 'mp4',
                  isM3U8: isHLS,
                  protocol: isHLS ? 'hls' : 'direct',
                  headers: {
                    'User-Agent': DEFAULT_HEADERS['User-Agent'],
                    'Referer': 'https://player.vidzee.wtf/',
                    'Origin': 'https://player.vidzee.wtf'
                  }
                }));
              }
            }
          } catch (e) {}
        })();

        // 2. VidRock Multi-CDN HLS Streams (Decrypted AES-256-GCM from Vercetti, NGCloud, HSCOW)
        var vidrockPromise = (async function() {
          try {
            if (!resolvedTmdb) return;
            var path = type === 'movie' ? ('movie/' + resolvedTmdb) : ('tv/' + resolvedTmdb + '/' + season + '/' + episode);
            var vrUrl = 'https://vidrock.net/api/' + path;
            var json = await fetchJson(vrUrl, {
              'User-Agent': DEFAULT_HEADERS['User-Agent'],
              'Referer': 'https://vidrock.net/' + path,
              'Origin': 'https://vidrock.net'
            });
            if (json && typeof json === 'object') {
              var sKeys = ['Nova', 'Atlas', 'Astra', 'Lyra', 'Elara'];
              for (var i = 0; i < sKeys.length; i++) {
                var sName = sKeys[i];
                var sObj = json[sName];
                if (sObj && sObj.url) {
                  var plainUrl = await decryptVidrockUrl(sObj.url);
                  if (plainUrl && !seenUrls.has(plainUrl) && plainUrl.includes('.m3u8')) {
                    seenUrls.add(plainUrl);
                    streams.push(new Nt({
                      url: plainUrl,
                      source: 'VidRock ' + sName,
                      name: '⚡ VidRock ' + sName + ' [1080p Master HLS]',
                      quality: 1080,
                      type: 'hls',
                      isM3U8: true,
                      protocol: 'hls',
                      headers: {
                        'User-Agent': DEFAULT_HEADERS['User-Agent'],
                        'Referer': 'https://vidrock.net/',
                        'Origin': 'https://vidrock.net'
                      }
                    }));
                  }
                }
              }
            }
          } catch (e) {}
        })();

        // 3. VidSpark (Vidora Cloudflare Workers CDN)
        var vidsparkPromise = (async function() {
          try {
            if (!resolvedTmdb) return;
            var path = type === 'movie' ? ('movie/' + resolvedTmdb) : ('tv/' + resolvedTmdb + '/' + season + '/' + episode);
            var spUrl = 'https://vidspark.to/api/vidora/v1/' + path;
            var json = await fetchJson(spUrl, {
              'User-Agent': DEFAULT_HEADERS['User-Agent'],
              'Referer': 'https://vidspark.to/' + path,
              'x-player-key': '3a67e8866ae1d2bb9e81fe7f73315a56eb3bdf5e3e755c7554c8be6910aa6b13'
            });
            if (json && json.sources && Array.isArray(json.sources)) {
              for (var i = 0; i < json.sources.length; i++) {
                var s = json.sources[i];
                if (s && s.url && !seenUrls.has(s.url)) {
                  seenUrls.add(s.url);
                  streams.push(new Nt({
                    url: s.url,
                    source: 'VidSpark Cloudflare',
                    name: '⚡ VidSpark Cloudflare [1080p Master HLS]',
                    quality: 1080,
                    type: 'hls',
                    isM3U8: true,
                    protocol: 'hls',
                    headers: {
                      'User-Agent': DEFAULT_HEADERS['User-Agent'],
                      'Referer': 'https://vidspark.to/'
                    }
                  }));
                }
              }
            }
          } catch (e) {}
        })();

        // 4. VixSrc Multi-Audio Direct Master HLS Streams
        var vixsrcPromise = (async function() {
          try {
            var idsToTry = [];
            if (resolvedTmdb) idsToTry.push(resolvedTmdb);
            if (imdbId && imdbId !== resolvedTmdb) idsToTry.push(imdbId);
            if (idsToTry.length === 0) return;

            var domain = 'https://vixsrc.to';
            for (var m = 0; m < idsToTry.length; m++) {
              var idToUse = idsToTry[m];
              var tvPath = type === 'movie' ? ('/api/movie/' + idToUse) : ('/api/tv/' + idToUse + '/' + season + '/' + episode);
              var json = await fetchJson(domain + tvPath, {
                'User-Agent': DEFAULT_HEADERS['User-Agent'],
                'Referer': domain,
                'Origin': domain
              });

              if (json && json.src) {
                var embedUrl = json.src.startsWith('http') ? json.src : (domain + json.src);
                var embedHtml = await fetchText(embedUrl, {
                  'User-Agent': DEFAULT_HEADERS['User-Agent'],
                  'Referer': domain
                });

                var tokenMatch = embedHtml.match(/token["']\s*:\s*["']([^"']+)/) || embedHtml.match(/token\s*=\s*["']([^"']+)/);
                var expiresMatch = embedHtml.match(/expires["']\s*:\s*["']([^"']+)/) || embedHtml.match(/expires\s*=\s*["']([^"']+)/);
                var playlistMatch = embedHtml.match(/url\s*:\s*["']([^"']+)/) || embedHtml.match(/source\s*:\s*["']([^"']+)/);

                if (playlistMatch && tokenMatch && expiresMatch) {
                  var playlistUrl = playlistMatch[1];
                  var sep = playlistUrl.includes('?') ? '&' : '?';
                  var masterUrl = playlistUrl + sep + 'token=' + tokenMatch[1] + '&expires=' + expiresMatch[1] + '&h=1';
                  if (!seenUrls.has(masterUrl)) {
                    seenUrls.add(masterUrl);
                    streams.push(new Nt({
                      url: masterUrl,
                      source: 'VixSrc Multi-Audio',
                      name: '⚡ VixSrc Multi-Audio [1080p Master HLS]',
                      quality: 1080,
                      type: 'hls',
                      isM3U8: true,
                      headers: {
                        'User-Agent': DEFAULT_HEADERS['User-Agent'],
                        'Referer': embedUrl,
                        'Origin': domain
                      }
                    }));
                    return;
                  }
                }
              }
            }
          } catch (e) {}
        })();

        // 5. VidApi Legacy Fallback
        var vidapiPromise = (async function() {
          try {
            var idsToTry = [];
            if (resolvedTmdb) idsToTry.push(resolvedTmdb);
            if (imdbId) idsToTry.push('imdb=' + imdbId);
            if (idsToTry.length === 0) return;
            var tvQuery = type === 'movie' ? '' : ('&season=' + season + '&episode=' + episode);
            var apiUrl = 'https://streamdata.vaplayer.ru/api.php?' + idsToTry[0] + '&type=' + (type === 'movie' ? 'movie' : 'tv') + tvQuery;
            var json = await fetchJson(apiUrl, {
              'User-Agent': DEFAULT_HEADERS['User-Agent'],
              'Referer': 'https://brightpathsignals.com/',
              'Origin': 'https://brightpathsignals.com'
            });
            if (json && (json.status_code == 200 || json.status_code === '200') && json.data && json.data.stream_urls) {
              var list = json.data.stream_urls;
              var urlArray = Array.isArray(list) ? list : Object.values(list);
              for (var i = 0; i < urlArray.length; i++) {
                var streamUrl = urlArray[i];
                if (streamUrl && !seenUrls.has(streamUrl) && (streamUrl.includes('.m3u8') || streamUrl.includes('.mp4'))) {
                  seenUrls.add(streamUrl);
                  var isHLS = !streamUrl.includes('.mp4') && !streamUrl.includes('.mkv');
                  var q = parseQuality(streamUrl);
                  streams.push(new Nt({
                    url: streamUrl,
                    source: 'VidApi Server ' + (i + 1),
                    name: '⚡ VidApi Server ' + (i + 1) + ' [' + q + 'p ' + (isHLS ? 'HLS' : 'MP4') + ']',
                    quality: q,
                    type: isHLS ? 'hls' : 'mp4',
                    isM3U8: isHLS,
                    protocol: isHLS ? 'hls' : 'direct',
                    headers: { 'User-Agent': DEFAULT_HEADERS['User-Agent'] }
                  }));
                }
              }
            }
          } catch (e) {}
        })();

        // 6. Torrentio Multi-Tracker Streams (P2P Torrent Fallback - Strictly Demoted)
        var torrentioPromise = (async function() {
          try {
            var tType = type === 'movie' ? 'movie' : 'series';
            var resolvedImdb = imdbId;
            if (!resolvedImdb && title) {
              try {
                var cmSearch = await fetchJson(CINEMETA_V3 + '/catalog/' + tType + '/top/search=' + encodeURIComponent(title) + '.json');
                if (cmSearch && Array.isArray(cmSearch.metas) && cmSearch.metas.length > 0) {
                  resolvedImdb = cmSearch.metas[0].imdb_id || cmSearch.metas[0].id;
                }
              } catch (e) {}
            }
            if (!resolvedImdb) return;

            var tId = resolvedImdb + (type === 'series' ? (':' + season + ':' + episode) : '');
            var tUrl = 'https://torrentio.strem.fun/qualityfilter=4k,other,scr,cam/stream/' + tType + '/' + tId + '.json';
            var tData = await fetchJson(tUrl, {
              'User-Agent': DEFAULT_HEADERS['User-Agent']
            });

            if (tData && Array.isArray(tData.streams) && tData.streams.length > 0) {
              tData.streams.sort(function(a, b) {
                var sa = (a.title || '').match(/👤\s*(\d+)/);
                var sb = (b.title || '').match(/👤\s*(\d+)/);
                var na = sa ? parseInt(sa[1], 10) : 0;
                var nb = sb ? parseInt(sb[1], 10) : 0;
                return nb - na;
              });

              var trackers = [
                'udp://tracker.opentrackr.org:1337/announce',
                'udp://open.stealth.si:80/announce',
                'udp://tracker.torrent.eu.org:451/announce',
                'udp://open.demonii.com:1337/announce',
                'udp://open.tracker.cl:1337/announce',
                'udp://explodie.org:6969/announce',
                'udp://tracker.qu.ax:6969/announce',
                'udp://tracker.coppersurfer.tk:6969/announce',
                'http://tracker.opentrackr.org:1337/announce',
                'udp://tracker.openbittorrent.com:6969/announce'
              ];
              var trackerParams = trackers.map(function(tr) {
                return '&tr=' + encodeURIComponent(tr);
              }).join('');

              var count = 0;
              for (var ti = 0; ti < tData.streams.length && count < 6; ti++) {
                var item = tData.streams[ti];
                if (!item || !item.infoHash) continue;

                var titleLines = (item.title || '').split('\n');
                var rawTitle = titleLines[0] || (item.name ? item.name.replace(/\n/g, ' ') : title);
                var q = parseQuality(rawTitle || item.name);
                if (q > 1080) continue;

                var statsLine = titleLines.slice(1).join(' ').trim();
                var magnet = 'magnet:?xt=urn:btih:' + item.infoHash + '&dn=' + encodeURIComponent(rawTitle) + trackerParams;

                if (!seenUrls.has(magnet)) {
                  seenUrls.add(magnet);
                  count++;
                  var qLabel = q ? (q + 'p') : '1080p';
                  var cleanSource = rawTitle + (statsLine ? (' · ' + statsLine) : '');
                  var fIdx = item.fileIdx !== undefined ? item.fileIdx : 0;
                  streams.push(new Nt({
                    url: magnet,
                    source: cleanSource,
                    providerName: 'Torrentio',
                    name: '⚡ Torrentio [' + qLabel + '] ' + (statsLine ? statsLine : rawTitle),
                    quality: q || 1080,
                    protocol: 'torrent',
                    type: 'torrent',
                    file_index: fIdx,
                    fileIndex: fIdx,
                    isM3U8: false
                  }));
                }
              }
            }
          } catch (e) {}
        })();

        // Execute all extractors in parallel with timeout protection
        await Promise.all([
          withTimeout(vidzeePromise, 7000),
          withTimeout(vidrockPromise, 7000),
          withTimeout(vidsparkPromise, 7000),
          withTimeout(vixsrcPromise, 7000),
          withTimeout(vidapiPromise, 6000),
          withTimeout(hcsPromise, 8000),
          withTimeout(archivePromise, 6000),
          withTimeout(torrentioPromise, 6000)
        ]);

        // Prioritize fast, high-performance Direct HLS sources over everything:
        // Rank 0: VidZee and VidRock Multi-CDN HLS (Vercetti, NGCloud, HSCOW)
        // Rank 1: VidSpark Cloudflare Workers CDN
        // Rank 2: VixSrc Multi-Audio Master HLS
        // Rank 3: VidApi Server
        // Rank 4: Direct HCS / Archive
        // Rank 99: Torrentio (absolute last-resort fallback)
        streams.sort(function(a, b) {
          function rank(stream) {
            if (/^Torrentio/i.test(stream.source || '') || stream.protocol === 'torrent' || stream.type === 'torrent') return 99;
            if (/^VidZee/i.test(stream.source || '')) return 0;
            if (/^VidRock/i.test(stream.source || '')) return 0;
            if (/^VidSpark/i.test(stream.source || '')) return 1;
            if (/^VixSrc/i.test(stream.source || '')) return 2;
            if (/^VidApi/i.test(stream.source || '')) return 3;
            if (stream.isHcs || stream.type === 'mkv' || stream.type === 'mp4' || (!stream.isM3U8 && stream.protocol !== 'torrent')) return 4;
            if (stream.isM3U8) return 5;
            return 6;
          }
          var aRank = rank(a);
          var bRank = rank(b);
          if (aRank !== bRank) return aRank - bRank;
          return (b.quality || 0) - (a.quality || 0);
        });
        cb({ success: true, data: streams });
      } catch (err) {
        cb({ success: true, data: [] });
      }
    }

    globalThis.getHome = getHome;
    globalThis.getCategoryPage = getCategoryPage;
    globalThis.search = search;
    globalThis.load = load;
    globalThis.loadStreams = loadStreams;
  })();
})();

Object.assign(globalThis, PluginModule);
