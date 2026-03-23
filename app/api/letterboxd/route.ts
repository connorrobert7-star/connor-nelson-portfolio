import { NextResponse } from "next/server";

type LetterboxdReview = {
  title: string;
  year: string;
  rating: string;
  review: string;
  link: string;
  date: string;
  image: string;
};

export async function GET() {
  const username = process.env.LETTERBOXD_USERNAME || "connornelson";

  try {
    // Letterboxd exposes an RSS feed at /USERNAME/rss/
    const res = await fetch(`https://letterboxd.com/${username}/rss/`, {
      headers: { "User-Agent": "ConnorNelsonPortfolio/1.0" },
      next: { revalidate: 3600 }, // cache for 1 hour
    });

    if (!res.ok) {
      return NextResponse.json({ reviews: [] });
    }

    const xml = await res.text();
    const reviews: LetterboxdReview[] = [];

    // Parse RSS XML manually (no dependency needed)
    const items = xml.split("<item>").slice(1, 6); // last 5

    for (const item of items) {
      const getTag = (tag: string): string => {
        const match = item.match(new RegExp(`<${tag}><!\\[CDATA\\[(.+?)\\]\\]></${tag}>`, "s"))
          || item.match(new RegExp(`<${tag}>(.+?)</${tag}>`, "s"));
        return match?.[1]?.trim() || "";
      };

      const title = getTag("title");
      const link = getTag("link") || getTag("guid");
      const pubDate = getTag("pubDate");
      const description = getTag("description");

      // Extract rating from title (e.g., "Film Name, 2024 - ★★★★")
      const ratingMatch = title.match(/- (★+½?)/);
      const rating = ratingMatch?.[1] || "";

      // Extract film title and year
      const titleClean = title.replace(/\s*-\s*★+½?\s*$/, "").trim();
      const yearMatch = titleClean.match(/,\s*(\d{4})\s*$/);
      const year = yearMatch?.[1] || "";
      const filmTitle = titleClean.replace(/,\s*\d{4}\s*$/, "").trim();

      // Extract image from description HTML
      const imgMatch = description.match(/<img\s+src="([^"]+)"/);
      const image = imgMatch?.[1] || "";

      // Extract review text (strip HTML)
      const reviewText = description
        .replace(/<img[^>]*>/g, "")
        .replace(/<[^>]+>/g, "")
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, '"')
        .replace(/&#039;/g, "'")
        .replace(/Watched on .+/, "")
        .trim();

      reviews.push({
        title: filmTitle,
        year,
        rating,
        review: reviewText.slice(0, 300),
        link,
        date: pubDate ? new Date(pubDate).toLocaleDateString("en-US", { month: "short", day: "numeric" }) : "",
        image,
      });
    }

    return NextResponse.json({ reviews });
  } catch {
    return NextResponse.json({ reviews: [] });
  }
}
