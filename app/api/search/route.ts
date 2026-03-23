import { NextRequest, NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { semanticSearch } from "@/lib/claude";

export async function GET(request: NextRequest) {
  const query = request.nextUrl.searchParams.get("q");
  if (!query) {
    return NextResponse.json({ results: [] });
  }

  const { data: stories } = await supabase
    .from("stories")
    .select("id, headline, dek, body")
    .order("found_at", { ascending: false })
    .limit(50);

  if (!stories || stories.length === 0) {
    return NextResponse.json({ results: [] });
  }

  const matches = await semanticSearch(query, stories);

  const matchedIds = matches.map((m) => m.id).filter(Boolean);
  const { data: fullStories } = await supabase
    .from("stories")
    .select("*")
    .in("id", matchedIds);

  const results = matches
    .map((match) => ({
      story: fullStories?.find((s) => s.id === match.id),
      explanation: match.explanation,
    }))
    .filter((r) => r.story);

  return NextResponse.json({ results });
}
