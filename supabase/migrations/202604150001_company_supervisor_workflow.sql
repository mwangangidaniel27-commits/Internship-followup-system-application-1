-- Adds company supervisor support and a two-step weekly-log review flow.

alter table public.supervisors
  add column if not exists supervisor_type text not null default 'university'
    check (supervisor_type in ('university', 'company')),
  add column if not exists company_name text;

alter table public.supervisor_assignments
  add column if not exists assignment_type text not null default 'university'
    check (assignment_type in ('university', 'company'));

-- Replace legacy one-assignment-per-student behavior with one per assignment type.
do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'supervisor_assignments_student_id_key'
      and conrelid = 'public.supervisor_assignments'::regclass
  ) then
    alter table public.supervisor_assignments
      drop constraint supervisor_assignments_student_id_key;
  end if;
end $$;

create unique index if not exists supervisor_assignments_student_type_key
  on public.supervisor_assignments(student_id, assignment_type);

alter table public.weekly_logs
  add column if not exists company_verification_status text not null default 'pending'
    check (company_verification_status in ('pending', 'verified', 'rejected')),
  add column if not exists company_verified_by uuid references public.users(id),
  add column if not exists company_verified_at timestamp with time zone;
