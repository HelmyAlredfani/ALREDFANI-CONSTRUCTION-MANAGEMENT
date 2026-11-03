-- ALREDFANI RETAIL ERP
-- Link legacy workspace memberships to configurable workspace roles.
-- Keeps workspace_members.role intact for backward compatibility.
-- Requires 002_role_permission_foundation.sql and 003_seed_default_roles.sql.

begin;

-- Nullable during rollout: legacy clients continue to work unchanged.
alter table public.workspace_members
  add column if not exists role_id uuid;

-- Ensure the composite target exists (created in migration 002).
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'workspace_members_workspace_role_fk'
      and conrelid = 'public.workspace_members'::regclass
  ) then
    alter table public.workspace_members
      add constraint workspace_members_workspace_role_fk
      foreign key (workspace_id, role_id)
      references public.workspace_roles(workspace_id, id)
      on delete set null (role_id);
  end if;
end
$$;

create index if not exists workspace_members_workspace_role_idx
  on public.workspace_members(workspace_id, role_id);

-- Backfill only recognized legacy roles. Unknown values receive the
-- deliberately unprivileged custom role; the legacy role column is untouched.
update public.workspace_members wm
set role_id = wr.id
from public.workspace_roles wr
where wr.workspace_id = wm.workspace_id
  and wr.role_key = case lower(coalesce(wm.role, ''))
    when 'owner' then 'owner'
    when 'manager' then 'general_manager'
    when 'cashier' then 'cashier'
    else 'custom'
  end
  and wm.role_id is null;

-- Keep role_id populated for memberships created by the legacy client.
create or replace function public.sync_workspace_member_role_id()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role_key text;
begin
  if tg_op = 'INSERT' or new.role is distinct from old.role then
    v_role_key := case lower(coalesce(new.role, ''))
      when 'owner' then 'owner'
      when 'manager' then 'general_manager'
      when 'cashier' then 'cashier'
      else 'custom'
    end;

    select id into new.role_id
    from public.workspace_roles
    where workspace_id = new.workspace_id
      and role_key = v_role_key;
  elsif new.role_id is null then
    v_role_key := case lower(coalesce(new.role, ''))
      when 'owner' then 'owner'
      when 'manager' then 'general_manager'
      when 'cashier' then 'cashier'
      else 'custom'
    end;

    select id into new.role_id
    from public.workspace_roles
    where workspace_id = new.workspace_id
      and role_key = v_role_key;
  end if;

  return new;
end;
$$;

drop trigger if exists workspace_member_role_id_sync on public.workspace_members;
create trigger workspace_member_role_id_sync
before insert or update of role, role_id, workspace_id
on public.workspace_members
for each row execute function public.sync_workspace_member_role_id();

-- Seed default roles and least-privilege grants for workspaces created after
-- this migration. Existing workspaces are already handled by migration 003.
create or replace function public.seed_workspace_default_roles(p_workspace_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.workspace_roles (workspace_id, name, role_key, is_system)
  values
    (p_workspace_id, 'مالك النظام', 'owner', true),
    (p_workspace_id, 'مدير عام', 'general_manager', true),
    (p_workspace_id, 'مدير فرع', 'branch_manager', true),
    (p_workspace_id, 'محاسب', 'accountant', true),
    (p_workspace_id, 'كاشير', 'cashier', true),
    (p_workspace_id, 'أمين مخزن', 'stockkeeper', true),
    (p_workspace_id, 'مستخدم مخصص', 'custom', true)
  on conflict (workspace_id, role_key) do nothing;

  with role_grants(role_key, permission_keys) as (
    values
    ('general_manager', array[
      'dashboard.view','pos.view','pos.create_sale',
      'sales.view','sales.create','sales.update','sales.delete','sales.approve','sales.print','sales.export',
      'products.view','products.create','products.update','products.delete',
      'inventory.view','inventory.adjust',
      'purchases.view','purchases.create','purchases.approve',
      'customers.view','customers.manage','suppliers.view','suppliers.manage',
      'expenses.view','expenses.create','expenses.approve',
      'reports.view','reports.export','users.view','users.manage',
      'branches.view','branches.manage','audit.view','backup.create'
    ]::text[]),
    ('branch_manager', array[
      'dashboard.view','pos.view','pos.create_sale',
      'sales.view','sales.create','sales.update','sales.approve','sales.print',
      'products.view','products.create','products.update',
      'inventory.view','inventory.adjust',
      'purchases.view','purchases.create',
      'customers.view','customers.manage','suppliers.view',
      'expenses.view','expenses.create','reports.view','reports.export',
      'branches.view'
    ]::text[]),
    ('accountant', array[
      'dashboard.view','sales.view','sales.print','sales.export',
      'purchases.view','purchases.create','purchases.approve',
      'customers.view','customers.manage','suppliers.view','suppliers.manage',
      'expenses.view','expenses.create','expenses.approve',
      'reports.view','reports.export','products.view','inventory.view'
    ]::text[]),
    ('cashier', array[
      'dashboard.view','pos.view','pos.create_sale',
      'sales.view','sales.print','products.view','inventory.view','customers.view'
    ]::text[]),
    ('stockkeeper', array[
      'dashboard.view','products.view','products.create','products.update',
      'inventory.view','inventory.adjust','purchases.view','purchases.create',
      'suppliers.view'
    ]::text[])
  )
  insert into public.role_permissions (workspace_id, role_id, permission_key, allowed)
  select p_workspace_id, wr.id, pc.permission_key, true
  from public.workspace_roles wr
  join role_grants rg on rg.role_key = wr.role_key
  cross join lateral unnest(rg.permission_keys) as granted(permission_key)
  join public.permission_catalog pc on pc.permission_key = granted.permission_key
  where wr.workspace_id = p_workspace_id
  on conflict (workspace_id, role_id, permission_key)
  do update set allowed = excluded.allowed;

  insert into public.role_permissions (workspace_id, role_id, permission_key, allowed)
  select p_workspace_id, wr.id, pc.permission_key, true
  from public.workspace_roles wr
  cross join public.permission_catalog pc
  where wr.workspace_id = p_workspace_id
    and wr.role_key = 'owner'
  on conflict (workspace_id, role_id, permission_key)
  do update set allowed = excluded.allowed;
end;
$$;

create or replace function public.on_workspace_create_seed_roles()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.seed_workspace_default_roles(new.id);
  return new;
end;
$$;

drop trigger if exists workspaces_seed_default_roles on public.workspaces;
create trigger workspaces_seed_default_roles
after insert on public.workspaces
for each row execute function public.on_workspace_create_seed_roles();

-- Functions are invoked only by trusted triggers / migration owner.
revoke all on function public.sync_workspace_member_role_id() from public, anon, authenticated;
revoke all on function public.seed_workspace_default_roles(uuid) from public, anon, authenticated;
revoke all on function public.on_workspace_create_seed_roles() from public, anon, authenticated;

commit;
