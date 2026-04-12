import { NextRequest, NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";

export async function GET(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const sixMonthsAgo = new Date();
  sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

  const { error, count } = await supabase
    .from("stories")
    .delete({ count: "exact" })
    .lt("found_at", sixMonthsAgo.toISOString());

  if (error) {
    console.error("Cleanup failed:", error.message);
    return NextResponse.json({ error: "Cleanup failed" }, { status: 500 });
  }

  return NextResponse.json({ deleted: count, cutoff: sixMonthsAgo.toISOString() });
}
