import { NextResponse } from "next/server";

export async function POST(request) {
  try {
    const { url } = await request.json();
    const input = new URL(url);
    if (input.protocol !== "https:" || !["vt.tiktok.com", "vm.tiktok.com"].includes(input.hostname.toLowerCase())) {
      return NextResponse.json({ error: "Link encurtado inválido." }, { status: 400 });
    }
    let current = input.toString();
    for (let i = 0; i < 5; i++) {
      const response = await fetch(current, { method: "GET", redirect: "manual", cache: "no-store", signal: AbortSignal.timeout(8000), headers: { "User-Agent": "Mozilla/5.0" } });
      const location = response.headers.get("location");
      if (!location) break;
      const next = new URL(location, current);
      if (next.protocol !== "https:" || !["vt.tiktok.com","vm.tiktok.com","www.tiktok.com","m.tiktok.com","tiktok.com"].includes(next.hostname.toLowerCase())) break;
      current = next.toString();
      const id = next.pathname.match(/\/video\/(\d+)/)?.[1];
      if (id) return NextResponse.json({ url: "https://www.tiktok.com/@user/video/" + id });
    }
    return NextResponse.json({ error: "Não foi possível identificar o vídeo. Copie o link completo do TikTok." }, { status: 422 });
  } catch {
    return NextResponse.json({ error: "Não foi possível resolver o link do TikTok." }, { status: 422 });
  }
}
