import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic();

function extractJson(text: string): string {
  return text.replace(/^```(?:json)?\s*\n?/i, "").replace(/\n?```\s*$/i, "").trim();
}

export type ClassificationResult = {
  documentary_score: number;
  audience_size_estimate: number;
  category: "subcultures" | "small-town" | "micro-celebrity";
  passes: boolean;
};

export type StoryWriteUp = {
  headline: string;
  dek: string;
  body: string;
};

export async function classifyContent(
  title: string,
  content: string,
  source: string
): Promise<ClassificationResult> {
  const response = await anthropic.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 500,
    messages: [
      {
        role: "user",
        content: `You are a documentary researcher evaluating raw internet content for story potential.

Evaluate this content found on ${source}:

Title: ${title}
Content: ${content}

Score this on:
1. Documentary potential (1-10): How compelling would this be as a short documentary subject?
2. Niche community size (estimated number of people involved)
3. Category — pick exactly one:
   - "subcultures" (niche communities, unusual hobbies, underground scenes)
   - "small-town" (local drama, municipal feuds, regional oddities)
   - "micro-celebrity" (internet-famous individuals, niche influencers, local legends)

Respond in JSON only, no other text:
{"documentary_score": number, "audience_size_estimate": number, "category": "subcultures"|"small-town"|"micro-celebrity"}`,
      },
    ],
  });

  const raw =
    response.content[0].type === "text" ? response.content[0].text : "";
  const parsed = JSON.parse(extractJson(raw));

  return {
    ...parsed,
    passes: parsed.documentary_score >= 5,
  };
}

export async function writeStory(
  title: string,
  content: string,
  source: string,
  isLead: boolean
): Promise<StoryWriteUp> {
  const lengthGuide = isLead ? "6-8 sentences" : "3-4 sentences";

  const response = await anthropic.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 1000,
    messages: [
      {
        role: "user",
        content: `You are a wire journalist. Write this story straight. Short sentences. Let the weird speak for itself. No adjectives that aren't necessary. ${lengthGuide}.

Source: ${source}
Title: ${title}
Raw content: ${content}

Respond in JSON only:
{"headline": "string", "dek": "one-line subheadline", "body": "the story"}`,
      },
    ],
  });

  const raw =
    response.content[0].type === "text" ? response.content[0].text : "";
  return JSON.parse(extractJson(raw));
}

export async function generateEmbedding(text: string): Promise<number[]> {
  const dim = 1536;
  const vec = new Array(dim).fill(0);
  const words = text.toLowerCase().split(/\s+/);

  for (let i = 0; i < words.length; i++) {
    const word = words[i];
    for (let j = 0; j < word.length; j++) {
      const idx = (word.charCodeAt(j) * 31 + i * 7 + j * 13) % dim;
      vec[idx] += 1;
    }
  }

  const magnitude = Math.sqrt(vec.reduce((sum, v) => sum + v * v, 0)) || 1;
  return vec.map((v) => v / magnitude);
}

export async function semanticSearch(
  query: string,
  stories: Array<{ id: string; headline: string; dek: string | null; body: string }>
): Promise<Array<{ id: string; explanation: string }>> {
  const storyList = stories
    .map(
      (s, i) =>
        `[${i}] "${s.headline}" — ${s.dek || ""} ${s.body.slice(0, 200)}`
    )
    .join("\n");

  const response = await anthropic.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 500,
    messages: [
      {
        role: "user",
        content: `You are a search engine for a newspaper about niche American stories.

User query: "${query}"

Stories in the database:
${storyList}

Return the 3 most relevant stories as JSON array. Each entry should have the story index and a one-line explanation of why it matches.
Respond in JSON only:
[{"index": number, "explanation": "string"}, ...]`,
      },
    ],
  });

  const raw =
    response.content[0].type === "text" ? response.content[0].text : "";
  const results = JSON.parse(extractJson(raw));

  return results.map((r: { index: number; explanation: string }) => ({
    id: stories[r.index]?.id,
    explanation: r.explanation,
  })).filter((r: { id: string | undefined }) => r.id);
}
