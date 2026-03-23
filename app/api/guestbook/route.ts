import { NextRequest, NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";

export async function GET() {
  const { data, error } = await supabase
    .from("guestbook")
    .select("id, name, message, created_at")
    .order("created_at", { ascending: false })
    .limit(50);

  if (error) {
    return NextResponse.json({ entries: [] });
  }

  return NextResponse.json({ entries: data || [] });
}

export async function POST(request: NextRequest) {
  const { name, message } = await request.json();

  if (!message || typeof message !== "string" || message.trim().length === 0) {
    return NextResponse.json({ error: "Message required" }, { status: 400 });
  }

  if (message.trim().length > 500) {
    return NextResponse.json({ error: "Message too long (500 chars max)" }, { status: 400 });
  }

  const cleanName = (name && typeof name === "string" ? name.trim() : "Anonymous").slice(0, 50);
  const cleanMessage = message.trim().slice(0, 500);

  const { data, error } = await supabase
    .from("guestbook")
    .insert({ name: cleanName, message: cleanMessage })
    .select()
    .single();

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ entry: data });
}
