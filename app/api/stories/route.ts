import { NextRequest, NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";

export async function GET(request: NextRequest) {
  const category = request.nextUrl.searchParams.get("category");

  let query = supabase
    .from("stories")
    .select("*")
    .order("documentary_score", { ascending: false })
    .order("found_at", { ascending: false });

  if (category && category !== "all") {
    query = query.eq("category", category);
  }

  const { data, error } = await query.limit(20);

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ stories: data || [] });
}
