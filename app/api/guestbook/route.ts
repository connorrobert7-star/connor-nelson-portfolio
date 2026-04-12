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

// Simple in-memory rate limiter
const rateLimit = new Map<string, number[]>();
const RATE_LIMIT_WINDOW = 60_000; // 1 minute
const RATE_LIMIT_MAX = 5; // 5 posts per minute

function isRateLimited(ip: string): boolean {
  const now = Date.now();
  const timestamps = (rateLimit.get(ip) || []).filter(t => now - t < RATE_LIMIT_WINDOW);
  if (timestamps.length >= RATE_LIMIT_MAX) return true;
  timestamps.push(now);
  rateLimit.set(ip, timestamps);
  return false;
}

function stripHtml(str: string): string {
  return str.replace(/[<>]/g, "");
}

export async function POST(request: NextRequest) {
  const ip = request.headers.get("x-forwarded-for") || "unknown";
  if (isRateLimited(ip)) {
    return NextResponse.json({ error: "Too many requests" }, { status: 429 });
  }

  const { name, message } = await request.json();

  if (!message || typeof message !== "string" || message.trim().length === 0) {
    return NextResponse.json({ error: "Message required" }, { status: 400 });
  }

  if (message.trim().length > 500) {
    return NextResponse.json({ error: "Message too long (500 chars max)" }, { status: 400 });
  }

  const cleanName = stripHtml((name && typeof name === "string" ? name.trim() : "Anonymous").slice(0, 50));
  const cleanMessage = stripHtml(message.trim().slice(0, 500));

  const { data, error } = await supabase
    .from("guestbook")
    .insert({ name: cleanName, message: cleanMessage })
    .select()
    .single();

  if (error) {
    console.error("Guestbook insert failed:", error.message);
    return NextResponse.json({ error: "Failed to save entry" }, { status: 500 });
  }

  return NextResponse.json({ entry: data });
}
