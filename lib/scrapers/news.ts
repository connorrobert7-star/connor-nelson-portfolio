import type { RawContent } from "./reddit";

export async function scrapeNews(): Promise<RawContent[]> {
  const apiKey = process.env.NEWS_API_KEY;
  if (!apiKey) return [];

  const results: RawContent[] = [];

  const queries = [
    "small town controversy",
    "niche community",
    "internet famous",
    "local drama america",
    "underground subculture",
  ];

  for (const q of queries) {
    try {
      const params = new URLSearchParams({
        q,
        language: "en",
        sortBy: "publishedAt",
        pageSize: "10",
        apiKey,
      });

      const res = await fetch(
        `https://newsapi.org/v2/everything?${params}`
      );
      if (!res.ok) continue;

      const data = await res.json();

      for (const article of data.articles || []) {
        if (!article.title) continue;
        results.push({
          title: article.title,
          content: article.description || article.content || article.title,
          source_url: article.url,
          source_platform: "news",
        });
      }
    } catch {
      // Skip failures
    }
  }

  return results;
}
