import type { RawContent } from "./reddit";

const SEARCH_QUERIES = [
  "niche community america",
  "small town controversy usa",
  "internet micro celebrity",
  "underground subculture united states",
  "local drama america story",
  "bizarre local news america",
];

export async function scrapeGoogleNews(): Promise<RawContent[]> {
  const results: RawContent[] = [];

  for (const query of SEARCH_QUERIES) {
    try {
      // Google News RSS feed — no API key needed
      const rssUrl = `https://news.google.com/rss/search?q=${encodeURIComponent(query + " when:7d")}&hl=en-US&gl=US&ceid=US:en`;
      const res = await fetch(rssUrl, {
        headers: { "User-Agent": "TheSignal/1.0" },
      });

      if (!res.ok) continue;

      const xml = await res.text();
      const items = xml.split("<item>").slice(1, 6);

      for (const item of items) {
        const getTag = (tag: string): string => {
          const match = item.match(
            new RegExp(`<${tag}><!\\[CDATA\\[(.+?)\\]\\]></${tag}>`, "s")
          ) || item.match(new RegExp(`<${tag}>(.+?)</${tag}>`, "s"));
          return match?.[1]?.trim() || "";
        };

        const title = getTag("title");
        const link = getTag("link");
        const description = getTag("description");

        if (!title || !link) continue;

        results.push({
          title,
          content: description || title,
          source_url: link,
          source_platform: "google-news",
        });
      }
    } catch {
      // Skip failed queries
    }
  }

  return results;
}
