export type RawContent = {
  title: string;
  content: string;
  source_url: string;
  source_platform: string;
};

let accessToken: string | null = null;
let tokenExpiry = 0;

async function getAccessToken(): Promise<string> {
  if (accessToken && Date.now() < tokenExpiry) return accessToken;

  const auth = Buffer.from(
    `${process.env.REDDIT_CLIENT_ID}:${process.env.REDDIT_CLIENT_SECRET}`
  ).toString("base64");

  const res = await fetch("https://www.reddit.com/api/v1/access_token", {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
      "User-Agent": "TheSignal/1.0",
    },
    body: "grant_type=client_credentials",
  });

  const data = await res.json();
  accessToken = data.access_token;
  tokenExpiry = Date.now() + data.expires_in * 1000 - 60000;
  return accessToken!;
}

const SUBREDDITS = [
  "TrueCrime",
  "UnresolvedMysteries",
  "HobbyDrama",
  "SubredditDrama",
  "bestoflegaladvice",
  "FloridaMan",
  "nottheonion",
  "LocalNews",
  "smalltown",
  "Documentaries",
  "internetdrama",
  "DeepIntoYouTube",
  "ObscureMedia",
];

export async function scrapeReddit(): Promise<RawContent[]> {
  const token = await getAccessToken();
  const results: RawContent[] = [];

  for (const sub of SUBREDDITS) {
    try {
      const res = await fetch(
        `https://oauth.reddit.com/r/${sub}/hot?limit=10`,
        {
          headers: {
            Authorization: `Bearer ${token}`,
            "User-Agent": "TheSignal/1.0",
          },
        }
      );

      if (!res.ok) continue;

      const data = await res.json();
      const posts = data?.data?.children || [];

      for (const post of posts) {
        const d = post.data;
        if (!d || d.stickied) continue;

        results.push({
          title: d.title,
          content: (d.selftext || d.title).slice(0, 2000),
          source_url: `https://reddit.com${d.permalink}`,
          source_platform: "reddit",
        });
      }
    } catch {
      // Skip failed subreddits
    }
  }

  return results;
}
