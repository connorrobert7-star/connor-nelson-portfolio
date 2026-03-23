import type { RawContent } from "./reddit";

const SEARCH_QUERIES = [
  "small town america documentary",
  "niche community documentary",
  "internet famous micro celebrity",
  "weird local news america",
  "underground subculture usa",
  "internet drama explained",
];

export async function scrapeYouTube(): Promise<RawContent[]> {
  const apiKey = process.env.YOUTUBE_API_KEY;
  if (!apiKey) return [];

  const results: RawContent[] = [];

  for (const query of SEARCH_QUERIES) {
    try {
      const params = new URLSearchParams({
        part: "snippet",
        q: query,
        type: "video",
        regionCode: "US",
        maxResults: "5",
        order: "date",
        publishedAfter: new Date(
          Date.now() - 7 * 24 * 60 * 60 * 1000
        ).toISOString(),
        key: apiKey,
      });

      const res = await fetch(
        `https://www.googleapis.com/youtube/v3/search?${params}`
      );
      if (!res.ok) continue;

      const data = await res.json();

      for (const item of data.items || []) {
        const snippet = item.snippet;
        results.push({
          title: snippet.title,
          content: snippet.description || snippet.title,
          source_url: `https://www.youtube.com/watch?v=${item.id.videoId}`,
          source_platform: "youtube",
        });
      }
    } catch {
      // Skip failed queries
    }
  }

  return results;
}
