import { NextRequest, NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { classifyContent, writeStory, generateEmbedding } from "@/lib/claude";
import { scrapeAll } from "@/lib/scrapers";

export const maxDuration = 300;

export async function GET(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const raw = await scrapeAll();
  let processed = 0;
  let stored = 0;
  const errors: string[] = [];

  for (const item of raw) {
    try {
      processed++;

      const { data: existing } = await supabase
        .from("stories")
        .select("id")
        .eq("source_url", item.source_url)
        .limit(1);

      if (existing && existing.length > 0) continue;

      const classification = await classifyContent(
        item.title,
        item.content,
        item.source_platform
      );

      if (!classification.passes) continue;

      const isLead = classification.documentary_score >= 9;
      const story = await writeStory(
        item.title,
        item.content,
        item.source_platform,
        isLead
      );

      const { error } = await supabase.from("stories").insert({
        headline: story.headline,
        dek: story.dek,
        body: story.body,
        source_url: item.source_url,
        source_platform: item.source_platform,
        category: classification.category,
        audience_size_estimate: classification.audience_size_estimate,
        documentary_score: classification.documentary_score,
      });

      if (error) {
        errors.push(`${error.message} (cat: ${classification.category}, score: ${classification.documentary_score})`);
      } else {
        stored++;
      }
    } catch {
      // Continue with next item
    }
  }

  return NextResponse.json({ processed, stored, errors: errors.slice(0, 5), timestamp: new Date().toISOString() });
}
