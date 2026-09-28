import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json({ error: "Authentication required" }, 401);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anonKey) return json({ error: "Function configuration is incomplete" }, 500);

  const userClient = createClient(url, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: authorization } },
  });
  const token = authorization.slice("Bearer ".length);
  const { data: auth, error: authError } = await userClient.auth.getUser(token);
  if (authError || !auth.user) return json({ error: "Authentication required" }, 401);

  let input: Record<string, unknown>;
  try {
    const body: unknown = await request.json();
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return json({ error: "Invalid request" }, 400);
    }
    input = body as Record<string, unknown>;
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const action = input.action;
  let rpcName: string;
  let params: Record<string, unknown>;
  switch (action) {
    case "create": {
      const name = typeof input.name === "string" ? input.name.trim() : "";
      if (!name || name.length > 60) return json({ error: "Tên gia đình phải từ 1 đến 60 ký tự." }, 400);
      rpcName = "create_household";
      params = { p_name: name };
      break;
    }
    case "join": {
      const code = typeof input.code === "string" ? input.code.trim().toUpperCase() : "";
      if (!/^[A-F0-9]{16}$/.test(code)) return json({ error: "Mã gia đình không hợp lệ." }, 400);
      rpcName = "join_household";
      params = { p_invite_code: code };
      break;
    }
    case "rotate": {
      const householdId = typeof input.householdId === "string" ? input.householdId : "";
      if (!householdId) return json({ error: "Thiếu mã gia đình." }, 400);
      rpcName = "rotate_household_invite_code";
      params = { p_household_id: householdId };
      break;
    }
    case "leave": {
      const householdId = typeof input.householdId === "string" ? input.householdId : "";
      if (!householdId) return json({ error: "Thiếu mã gia đình." }, 400);
      rpcName = "leave_household";
      params = { p_household_id: householdId };
      break;
    }
    default:
      return json({ error: "Unsupported action" }, 400);
  }

  const { data, error } = await userClient.rpc(rpcName, params);
  if (error) {
    const message = error.message.toLowerCase().includes("invalid household invite code")
      ? "Mã gia đình không đúng hoặc đã được đổi."
      : error.message;
    return json({ error: message }, error.code === "42501" ? 403 : 400);
  }

  if (action === "create" || action === "join") {
    const row = Array.isArray(data) ? data[0] : data;
    if (!row) return json({ error: "Không nhận được thông tin gia đình." }, 502);
    return json({
      id: row.out_id,
      name: row.out_name,
      role: row.out_role ?? "owner",
      invite_code: row.out_invite_code,
    });
  }
  if (action === "rotate") return json({ inviteCode: data });
  return json({ success: data === true });
});
