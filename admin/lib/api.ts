const BASE = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3000/api/v1';
export function getToken() { return typeof window === 'undefined' ? null : localStorage.getItem('admin_access_token'); }

async function safeFetch(url: string, init: RequestInit = {}, timeoutMs = 7000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try { return await fetch(url, { ...init, signal: controller.signal }); }
  catch (error: any) {
    if (error?.name === 'AbortError') throw new Error('API connection timed out. Check that the backend is running on port 3000.');
    throw new Error('Failed to reach the API. Check the backend, Docker, and VPN/network settings.');
  } finally { clearTimeout(timer); }
}

let refreshing: Promise<boolean> | null = null;
async function refreshAccessToken() {
  if (typeof window === 'undefined') return false;
  if (refreshing) return refreshing;
  refreshing = (async () => {
    const refreshToken = localStorage.getItem('admin_refresh_token');
    if (!refreshToken) return false;
    try {
      const response = await safeFetch(`${BASE}/auth/refresh`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refreshToken }) });
      if (!response.ok) return false;
      const result = await response.json();
      localStorage.setItem('admin_access_token', result.accessToken);
      localStorage.setItem('admin_refresh_token', result.refreshToken);
      return true;
    } catch { return false; }
  })().finally(() => { refreshing = null; });
  return refreshing;
}

export async function api<T>(path: string, init: RequestInit = {}, allowRefresh = true): Promise<T> {
  const token = getToken();
  const response = await safeFetch(`${BASE}${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...init.headers },
    cache: 'no-store',
  });
  if (response.status === 401 && allowRefresh && await refreshAccessToken()) return api<T>(path, init, false);
  if (response.status === 401 && typeof window !== 'undefined') {
    localStorage.removeItem('admin_access_token'); localStorage.removeItem('admin_refresh_token'); window.location.href = '/login';
  }
  if (!response.ok) {
    const payload = await response.json().catch(() => ({}));
    const message = Array.isArray(payload.message) ? payload.message.join('\n') : payload.message;
    throw new Error(message ?? `Request failed (${response.status})`);
  }
  return response.status === 204 ? (undefined as T) : response.json();
}

export async function uploadFile(path: string, file: File): Promise<{url:string;fileId?:string}> {
  const token = getToken();
  const form = new FormData(); form.append('file', file);
  const response = await safeFetch(`${BASE}${path}`, { method: 'POST', headers: token ? { Authorization: `Bearer ${token}` } : {}, body: form }, 30000);
  if (response.status === 401 && await refreshAccessToken()) return uploadFile(path, file);
  if (!response.ok) { const payload = await response.json().catch(() => ({})); throw new Error(payload.message ?? `Upload failed (${response.status})`); }
  return response.json();
}

export function assetUrl(raw?: string | null) {
  const value = (raw ?? '').trim();
  if (!value) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  const root = BASE.endsWith('/api/v1') ? BASE.slice(0, -7) : BASE;
  return value.startsWith('/') ? `${root}${value}` : `${root}/${value}`;
}
