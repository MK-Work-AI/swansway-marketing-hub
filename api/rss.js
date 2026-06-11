/* api/rss.js — Swansway Marketing Hub Vercel proxy                    */
/* Fetches RSS XML server-side, parses to JSON, returns with CORS      */
/* Allowed domains whitelist prevents abuse                            */

const ALLOWED = [
  'news.google.com',
  'www.autocar.co.uk',
  'www.autoexpress.co.uk',
  'cardealermagazine.co.uk',
  'www.fleetnews.co.uk',
  'www.electrifying.com',
  'www.am-online.com'
];

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET')    return res.status(405).json({ error: 'GET only' });

  const { url } = req.query;
  if (!url) return res.status(400).json({ error: 'Missing url param' });

  // Validate against allowlist
  let parsed;
  try { parsed = new URL(url); } catch(e) {
    return res.status(400).json({ error: 'Invalid URL' });
  }
  if (!ALLOWED.includes(parsed.hostname)) {
    return res.status(403).json({ error: 'Domain not allowed' });
  }

  try {
    const response = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0 (compatible; SwanswayPortal/1.0)' },
      signal: AbortSignal.timeout(8000)
    });

    if (!response.ok) {
      return res.status(502).json({ error: 'Upstream HTTP ' + response.status });
    }

    const xml = await response.text();
    const items = parseRSS(xml);

    // Cache for 10 minutes at Vercel edge
    res.setHeader('Cache-Control', 's-maxage=600, stale-while-revalidate=60');
    return res.status(200).json({ status: 'ok', items });

  } catch(err) {
    return res.status(500).json({ error: err.message });
  }
};

/* ── Minimal RSS/Atom XML parser (no dependencies) ── */
function parseRSS(xml) {
  const items = [];

  // Match <item> or <entry> blocks
  const blockRe = /<(?:item|entry)[\s>]([\s\S]*?)<\/(?:item|entry)>/gi;
  let block;

  while ((block = blockRe.exec(xml)) !== null) {
    const raw = block[1];

    const title   = extractTag(raw, 'title');
    const link    = extractLink(raw);
    const pubDate = extractTag(raw, 'pubDate') || extractTag(raw, 'published') || extractTag(raw, 'updated');
    const desc    = extractTag(raw, 'description') || extractTag(raw, 'summary') || extractTag(raw, 'content');
    const source  = extractAttr(raw, 'source');

    if (!title || !link) continue;

    items.push({
      title:   stripHtml(title).substring(0, 200),
      link:    link.trim(),
      pubDate: pubDate ? pubDate.trim() : '',
      description: stripHtml(desc || '').substring(0, 300),
      source:  source ? stripHtml(source).substring(0, 80) : ''
    });
  }

  return items;
}

function extractTag(xml, tag) {
  // Handle <tag>...</tag> and <tag><![CDATA[...]]></tag>
  const re = new RegExp('<' + tag + '[^>]*>([\\s\\S]*?)<\\/' + tag + '>', 'i');
  const m  = re.exec(xml);
  if (!m) return '';
  let val = m[1];
  // Strip CDATA wrapper
  val = val.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1');
  return val.trim();
}

function extractLink(xml) {
  // Try <link>url</link> first
  let m = /<link[^>]*>([^<]+)<\/link>/i.exec(xml);
  if (m && m[1].trim().startsWith('http')) return m[1].trim();
  // Try <link href="url" /> (Atom)
  m = /<link[^>]+href=["']([^"']+)["']/i.exec(xml);
  if (m) return m[1].trim();
  // Try <guid>url</guid>
  m = /<guid[^>]*>([^<]+)<\/guid>/i.exec(xml);
  if (m && m[1].trim().startsWith('http')) return m[1].trim();
  return '';
}

function extractAttr(xml, tag) {
  // <source url="...">Publisher Name</source>
  const re = new RegExp('<' + tag + '[^>]*>([\\s\\S]*?)<\\/' + tag + '>', 'i');
  const m  = re.exec(xml);
  if (!m) return '';
  let val = m[1];
  val = val.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1');
  return val.trim();
}

function stripHtml(html) {
  return html
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g,  ' ')
    .replace(/&amp;/g,   '&')
    .replace(/&lt;/g,    '<')
    .replace(/&gt;/g,    '>')
    .replace(/&quot;/g,  '"')
    .replace(/&#39;/g,   "'")
    .replace(/\s+/g,     ' ')
    .trim();
}
