import { scrapeReddit } from "./reddit";
import { scrapeYouTube } from "./youtube";
import { scrapeNews } from "./news";
import { scrapeGoogleNews } from "./google";
import type { RawContent } from "./reddit";

export type { RawContent };

export async function scrapeAll(): Promise<RawContent[]> {
  const [reddit, youtube, news, google] = await Promise.allSettled([
    scrapeReddit(),
    scrapeYouTube(),
    scrapeNews(),
    scrapeGoogleNews(),
  ]);

  const results: RawContent[] = [];

  if (reddit.status === "fulfilled") results.push(...reddit.value);
  if (youtube.status === "fulfilled") results.push(...youtube.value);
  if (news.status === "fulfilled") results.push(...news.value);
  if (google.status === "fulfilled") results.push(...google.value);

  const seen = new Set<string>();
  return results.filter((r) => {
    if (seen.has(r.source_url)) return false;
    seen.add(r.source_url);
    return true;
  });
}
