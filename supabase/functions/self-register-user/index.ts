import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type UserRole = "student" | "supervisor";
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
    } = body;

    if (!full_name || !email || !password || !role) {
      throw new Error("full_name, email, password and role are required");
    }

    if (!["student", "supervisor"].includes(role)) {
      throw new Error("Self-registration only supports student or supervisor roles");
    }

    const normalizedRole = role as UserRole;
    const normalizedSupervisorType: SupervisorType =
      supervisor_type === "company" ? "company" : "university";

    const { data: existingUsers } = await adminClient.auth.admin.listUsers();
    const existing = existingUsers?.users?.find(
      (existingUser: any) => existingUser.email === email,
    );

    if (existing) {
      throw new Error("An account with this email already exists");
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
      throw new Error("No UID returned from auth");
    }

    const { error: userErr } = await adminClient.from("users").insert({
      id: uid,
      full_name,
      email,
      role: normalizedRole,
      is_active: false,
      approval_status: "pending",
    });

    if (userErr) {
      throw new Error(`users: ${userErr.message}`);
    }

    if (normalizedRole === "student") {
      const { error: studentErr } = await adminClient.from("students").insert({
        user_id: uid,
        student_id: student_id || `PENDING-${Date.now()}`,
        department: department || "Unassigned",
        company_name: company_name || null,
        company_address: company_address || null,
        internship_start_date: internship_start_date || null,
        internship_end_date: internship_end_date || null,
        total_weeks: total_weeks ? parseInt(total_weeks) : 12,
        status: "active",
      });

      if (studentErr) {
        throw new Error(`students: ${studentErr.message}`);
      }
    }

    if (normalizedRole === "supervisor") {
      const { error: supervisorErr } = await adminClient
        .from("supervisors")
        .insert({
          user_id: uid,
          department: department || "Unassigned",
          title: title || null,
          supervisor_type: normalizedSupervisorType,
          company_name:
            normalizedSupervisorType === "company"
              ? company_name || "Unassigned Company"
              : null,
        });

      if (supervisorErr) {
        throw new Error(`supervisors: ${supervisorErr.message}`);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Registration submitted. Awaiting admin approval.",
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ success: false, error: message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
