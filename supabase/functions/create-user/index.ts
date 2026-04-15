import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type Role = "student" | "supervisor" | "admin";
type SupervisorType = "university" | "company";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const body = await req.json();
    const users = Array.isArray(body) ? body : [body];
    const results = [];

    for (const u of users) {
      const {
        full_name,
        email,
        password,
        role,
        department,
        title,
        student_id,
        company_name,
        company_address,
        internship_start_date,
        internship_end_date,
        total_weeks,
        supervisor_type,
      } = u;

      if (!["student", "supervisor", "admin"].includes(role)) {
        results.push({
          email,
          success: false,
          error: `Invalid role: ${role}`,
        });
        continue;
      }

      try {
        const { data: existingUsers } = await adminClient.auth.admin.listUsers();
        const ghost = existingUsers?.users?.find(
          (existingUser: any) =>
            existingUser.email === email && !existingUser.email_confirmed_at,
        );

        if (ghost) {
          await adminClient.auth.admin.deleteUser(ghost.id);
        }

        const confirmed = existingUsers?.users?.find(
          (existingUser: any) =>
            existingUser.email === email && existingUser.email_confirmed_at,
        );

        if (confirmed) {
          results.push({
            email,
            success: false,
            error: `User ${email} already exists`,
          });
          continue;
        }

        const { data: authData, error: authError } =
          await adminClient.auth.admin.createUser({
            email,
            password,
            email_confirm: true,
          });

        if (authError) {
          throw new Error(`Auth: ${authError.message}`);
        }

        const uid = authData.user?.id;
        if (!uid) {
          throw new Error("No UID returned");
        }

        const { error: userErr } = await adminClient.from("users").insert({
          id: uid,
          full_name,
          email,
          role: role as Role,
          is_active: true,
          approval_status: "approved",
        });

        if (userErr) {
          throw new Error(`users: ${userErr.message}`);
        }

        if (role === "supervisor") {
          const normalizedSupervisorType: SupervisorType =
            supervisor_type === "company" ? "company" : "university";

          const { error: supErr } = await adminClient.from("supervisors").insert({
            user_id: uid,
            department: department || "Unassigned",
            title: title || null,
            supervisor_type: normalizedSupervisorType,
            company_name:
              normalizedSupervisorType === "company"
                ? company_name || "Unassigned Company"
                : null,
          });

          if (supErr) {
            throw new Error(`supervisors: ${supErr.message}`);
          }
        }

        if (role === "student") {
          const { error: stuErr } = await adminClient.from("students").insert({
            user_id: uid,
            student_id: student_id || `STU-${Date.now()}`,
            department: department || "Unassigned",
            company_name: company_name || null,
            company_address: company_address || null,
            internship_start_date: internship_start_date || null,
            internship_end_date: internship_end_date || null,
            total_weeks: total_weeks ? parseInt(total_weeks) : 0,
            status: "active",
          });

          if (stuErr) {
            throw new Error(`students: ${stuErr.message}`);
          }
        }

        results.push({ email, success: true });
      } catch (e) {
        const message = e instanceof Error ? e.message : String(e);
        console.error(`Error for ${email}:`, message);
        results.push({ email, success: false, error: message });
      }
    }

    return new Response(JSON.stringify(results), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
