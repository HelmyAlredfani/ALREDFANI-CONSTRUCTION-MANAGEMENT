-- ALREDFANI RETAIL ERP: cloud snapshot persistence, phase 1
-- Run once in Supabase SQL Editor before deploying the frontend changes.
create table if not exists public.workspace_snapshots (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table public.workspace_snapshots enable row level security;
drop policy if exists "Members can read workspace snapshot" on public.workspace_snapshots;
create policy "Members can read workspace snapshot"
on public.workspace_snapshots for select to authenticated
using (public.is_workspace_member(workspace_id));
drop policy if exists "Managers can create workspace snapshot" on public.workspace_snapshots;
create policy "Managers can create workspace snapshot"
on public.workspace_snapshots for insert to authenticated
with check (
  public.has_workspace_role(workspace_id, array['owner','manager'])
  and (updated_by is null or updated_by = auth.uid())
);
drop policy if exists "Managers can update workspace snapshot" on public.workspace_snapshots;
create policy "Managers can update workspace snapshot"
on public.workspace_snapshots for update to authenticated
using (public.has_workspace_role(workspace_id, array['owner','manager']))
with check (
  public.has_workspace_role(workspace_id, array['owner','manager'])
  and (updated_by is null or updated_by = auth.uid())
);
grant select, insert, update on public.workspace_snapshots to authenticated;
