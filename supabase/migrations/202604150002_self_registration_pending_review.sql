-- Adds explicit approval status for self-registered users.

alter table public.users
  add column if not exists approval_status text not null default 'approved'
    check (approval_status in ('pending', 'approved', 'rejected'));

-- Existing users are assumed to be approved.
update public.users
set approval_status = 'approved'
where approval_status is null;
