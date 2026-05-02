// Vercel-style serverless function: proxies Claude Messages requests.
// Deploy this folder to Vercel; set ANTHROPIC_API_KEY and APP_AUTH_TOKEN as
// environment variables. The iOS app POSTs to {your-domain}/v1/messages
// with `Authorization: Bearer <APP_AUTH_TOKEN>`.

export const config = { runtime: 'edge' };

export default async function handler(req) {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  // Verify the app's bearer token matches our shared secret.
  const auth = req.headers.get('authorization') || '';
  const expected = `Bearer ${process.env.APP_AUTH_TOKEN || ''}`;
  if (!process.env.APP_AUTH_TOKEN || auth !== expected) {
    return new Response(
      JSON.stringify({ type: 'error', error: { type: 'authentication_error', message: 'invalid bearer token' } }),
      { status: 401, headers: { 'content-type': 'application/json' } }
    );
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return new Response(
      JSON.stringify({ type: 'error', error: { type: 'configuration', message: 'ANTHROPIC_API_KEY not set' } }),
      { status: 500, headers: { 'content-type': 'application/json' } }
    );
  }

  // Forward the body verbatim. The app already constructs valid Messages
  // payloads (model, max_tokens, messages: [...]).
  const body = await req.text();

  const upstream = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body,
  });

  // Pipe the response straight back. The app expects Anthropic's shape.
  const respText = await upstream.text();
  return new Response(respText, {
    status: upstream.status,
    headers: { 'content-type': 'application/json' },
  });
}
