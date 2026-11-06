export function hasSameOrigin(request: Request) {
  const origin = request.headers.get("origin");
  if (!origin) return false;

  try {
    const configuredOrigin = process.env.APP_ORIGIN?.replace(/\/$/, "");
    return origin === (configuredOrigin || new URL(request.url).origin);
  } catch {
    return false;
  }
}
