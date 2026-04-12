import { NextRequest, NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";

export async function GET() {
  const { data, error } = await supabase
    .from("daily_photos")
    .select("id, photo_url, taken_at, created_at")
    .order("taken_at", { ascending: false })
    .limit(60);

  if (error) {
    return NextResponse.json({ photos: [] });
  }

  return NextResponse.json({ photos: data || [] });
}

export async function POST(request: NextRequest) {
  // Auth check — use CRON_SECRET as upload key
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const formData = await request.formData();
  const file = formData.get("photo") as File | null;
  const takenAt = formData.get("taken_at") as string | null;

  if (!file) {
    return NextResponse.json({ error: "No photo provided" }, { status: 400 });
  }

  const ALLOWED_TYPES = ["image/jpeg", "image/png", "image/webp"];
  if (!ALLOWED_TYPES.includes(file.type)) {
    return NextResponse.json({ error: "Invalid file type" }, { status: 400 });
  }

  // Upload to Supabase Storage
  const timestamp = takenAt || new Date().toISOString();
  const dateStr = new Date(timestamp).toISOString().split("T")[0];
  const fileName = `glanceback/${dateStr}-${Date.now()}.jpg`;

  const arrayBuffer = await file.arrayBuffer();
  const { error: uploadError } = await supabase.storage
    .from("photos")
    .upload(fileName, arrayBuffer, {
      contentType: file.type,
      upsert: false,
    });

  if (uploadError) {
    console.error("Photo upload failed:", uploadError.message);
    return NextResponse.json({ error: "Failed to upload photo" }, { status: 500 });
  }

  // Get public URL
  const { data: urlData } = supabase.storage
    .from("photos")
    .getPublicUrl(fileName);

  // Save to database
  const { data, error: dbError } = await supabase
    .from("daily_photos")
    .insert({
      photo_url: urlData.publicUrl,
      taken_at: timestamp,
    })
    .select()
    .single();

  if (dbError) {
    console.error("Photo DB insert failed:", dbError.message);
    return NextResponse.json({ error: "Failed to save photo" }, { status: 500 });
  }

  return NextResponse.json({ photo: data });
}
