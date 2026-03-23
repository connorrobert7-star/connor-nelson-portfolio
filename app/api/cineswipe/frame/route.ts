import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

let _client: ReturnType<typeof createClient> | null = null;

function getClient() {
  if (!_client) {
    _client = createClient(
      process.env.CINESWIPE_SUPABASE_URL || process.env.SUPABASE_URL!,
      process.env.CINESWIPE_SUPABASE_KEY || process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_ANON_KEY!
    );
  }
  return _client;
}

export async function GET(request: NextRequest) {
  const excludeParam = request.nextUrl.searchParams.get("exclude");
  const exclude: string[] = excludeParam ? excludeParam.split(",") : [];

  const client = getClient();

  let query = client
    .from("frames")
    .select("id, film_title, director, year, cinematographer, aspect_ratio, r2_key, thumbnail_r2_key, lighting_tags, lens_tags, color_tags, emotional_register_tags, composition_tags, era_tags, subject_tags, movement_tags, folder_tags")
    .eq("is_active", true)
    .limit(50);

  if (exclude.length > 0) {
    query = query.not("id", "in", `(${exclude.join(",")})`);
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const { data: frames, error } = await query as { data: any[] | null; error: any };

  if (error || !frames || frames.length === 0) {
    return NextResponse.json({ frame: null });
  }

  // Pick a random frame
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const frame: any = frames[Math.floor(Math.random() * frames.length)];

  // Build CDN URLs from R2 keys
  const cdnBase = process.env.CINESWIPE_CDN_URL || "";
  const cdnUrl = frame.r2_key ? `${cdnBase}/${frame.r2_key}` : null;
  const thumbUrl = frame.thumbnail_r2_key ? `${cdnBase}/${frame.thumbnail_r2_key}` : null;

  return NextResponse.json({
    frame: {
      id: frame.id,
      film_title: frame.film_title,
      director: frame.director,
      year: frame.year,
      cinematographer: frame.cinematographer,
      aspect_ratio: frame.aspect_ratio || "16:9",
      cdn_url: cdnUrl,
      thumbnail_url: thumbUrl,
      tags: {
        lighting: frame.lighting_tags || [],
        lens: frame.lens_tags || [],
        color: frame.color_tags || [],
        emotional_register: frame.emotional_register_tags || [],
        composition: frame.composition_tags || [],
        era: frame.era_tags || [],
        subject: frame.subject_tags || [],
        movement: frame.movement_tags || [],
        folder: frame.folder_tags || [],
      },
      camera_model: null,
      lens_info: null,
      film_stock: null,
      film_notes: null,
    },
  });
}
