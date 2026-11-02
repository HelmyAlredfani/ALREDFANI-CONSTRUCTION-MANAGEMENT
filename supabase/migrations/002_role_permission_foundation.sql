-- ALREDFANI RETAIL ERP
-- Additive foundation for configurable roles, granular permissions and branch assignments.
-- Safe to apply after 001_workspace_snapshots.sql. Does not alter or delete existing data/policies.

begin;

create table if not exists public.workspace_roles (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null,
  role_key text not null,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  unique (workspace_id, role_key),
  unique (workspace_id, id)
);

create table if not exists public.permission_catalog (
  permission_key text primary key,
  module text not null,
  action text not null,
  description text not null
);

create table if not exists public.role_permissions (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  role_id uuid not null,
  permission_key text not null references public.permission_catalog(permission_key) on delete cascade,
  allowed boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (workspace_id, role_id, permission_key),
  constraint role_permissions_role_workspace_fk
    foreign key (workspace_id, role_id)
    references public.workspace_roles(workspace_id, id) on delete cascade
);

create table if not exists public.user_permissions (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  permission_key text not null references public.permission_catalog(permission_key) on delete cascade,
  allowed boolean not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  primary key (workspace_id, user_id, permission_key)
);

create table if not exists public.user_branch_access (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  branch_id uuid not null references public.branches(id) on delete cascade,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  primary key (workspace_id, user_id, branch_id)
);

create index if not exists workspace_roles_workspace_idx
  on public.workspace_roles(workspace_id);
create index if not exists role_permissions_workspace_key_idx
  on public.role_permissions(workspace_id, permission_key);
create index if not exists user_permissions_user_workspace_idx
  on public.user_permissions(user_id, workspace_id);
create index if not exists user_branch_access_user_workspace_idx
  on public.user_branch_access(user_id, workspace_id);
create index if not exists user_branch_access_branch_idx
  on public.user_branch_access(branch_id);

insert into public.permission_catalog(permission_key,module,action,description) values
 ('dashboard.view','dashboard','view','عرض لوحة التحكم'),
 ('pos.view','pos','view','فتح نقطة البيع'),
 ('pos.create_sale','pos','create','إنشاء فاتورة بيع'),
 ('sales.view','sales','view','عرض المبيعات والفواتير'),
 ('sales.create','sales','create','إنشاء فاتورة'),
 ('sales.update','sales','update','تعديل فاتورة'),
 ('sales.delete','sales','delete','حذف فاتورة'),
 ('sales.approve','sales','approve','اعتماد فاتورة'),
 ('sales.print','sales','print','طباعة فاتورة'),
 ('sales.export','sales','export','تصدير المبيعات'),
 ('products.view','products','view','عرض المنتجات'),
 ('products.create','products','create','إضافة منتج'),
 ('products.update','products','update','تعديل منتج'),
 ('products.delete','products','delete','حذف منتج'),
 ('inventory.view','inventory','view','عرض المخزون'),
 ('inventory.adjust','inventory','update','تسوية المخزون'),
 ('purchases.view','purchases','view','عرض المشتريات'),
 ('purchases.create','purchases','create','إنشاء مشتريات'),
 ('purchases.approve','purchases','approve','اعتماد المشتريات'),
 ('customers.view','customers','view','عرض العملاء'),
 ('customers.manage','customers','manage','إدارة العملاء'),
 ('suppliers.view','suppliers','view','عرض الموردين'),
 ('suppliers.manage','suppliers','manage','إدارة الموردين'),
 ('expenses.view','expenses','view','عرض المصروفات'),
 ('expenses.create','expenses','create','إضافة مصروف'),
 ('expenses.approve','expenses','approve','اعتماد المصروفات'),
 ('reports.view','reports','view','عرض التقارير'),
 ('reports.export','reports','export','تصدير التقارير'),
 ('users.view','users','view','عرض المستخدمين'),
 ('users.manage','users','manage','إدارة المستخدمين'),
 ('roles.manage','roles','manage','إدارة الأدوار والصلاحيات'),
 ('branches.view','branches','view','عرض الفروع'),
 ('branches.manage','branches','manage','إدارة الفروع'),
 ('audit.view','audit','view','عرض سجل التدقيق'),
 ('backup.create','backup','create','إنشاء نسخة احتياطية'),
 ('backup.restore','backup','restore','استعادة نسخة احتياطية'),
 ('settings.manage','settings','manage','إدارة إعدادات النظام')
on conflict (permission_key) do nothing;

alter table public.workspace_roles enable row level security;
alter table public.permission_catalog enable row level security;
alter table public.role_permissions enable row level security;
alter table public.user_permissions enable row level security;
alter table public.user_branch_access enable row level security;

drop policy if exists workspace_roles_member_read on public.workspace_roles;
create policy workspace_roles_member_read on public.workspace_roles
for select to authenticated
using (public.is_workspace_member(workspace_id));

drop policy if exists workspace_roles_owner_manage on public.workspace_roles;
create policy workspace_roles_owner_manage on public.workspace_roles
for all to authenticated
using (public.has_workspace_role(workspace_id, array['owner']::text[]))
with check (public.has_workspace_role(workspace_id, array['owner']::text[]));

drop policy if exists permission_catalog_authenticated_read on public.permission_catalog;
create policy permission_catalog_authenticated_read on public.permission_catalog
for select to authenticated using (true);

drop policy if exists role_permissions_member_read on public.role_permissions;
create policy role_permissions_member_read on public.role_permissions
for select to authenticated
using (public.is_workspace_member(workspace_id));

drop policy if exists role_permissions_owner_manage on public.role_permissions;
create policy role_permissions_owner_manage on public.role_permissions
for all to authenticated
using (public.has_workspace_role(workspace_id, array['owner']::text[]))
with check (public.has_workspace_role(workspace_id, array['owner']::text[]));

drop policy if exists user_permissions_self_or_owner_read on public.user_permissions;
create policy user_permissions_self_or_owner_read on public.user_permissions
for select to authenticated
using (
  user_id = auth.uid()
  or public.has_workspace_role(workspace_id, array['owner']::text[])
);

drop policy if exists user_permissions_owner_manage on public.user_permissions;
create policy user_permissions_owner_manage on public.user_permissions
for all to authenticated
using (public.has_workspace_role(workspace_id, array['owner']::text[]))
with check (public.has_workspace_role(workspace_id, array['owner']::text[]));

drop policy if exists user_branch_access_self_or_owner_read on public.user_branch_access;
create policy user_branch_access_self_or_owner_read on public.user_branch_access
for select to authenticated
using (
  user_id = auth.uid()
  or public.has_workspace_role(workspace_id, array['owner']::text[])
);

drop policy if exists user_branch_access_owner_manage on public.user_branch_access;
create policy user_branch_access_owner_manage on public.user_branch_access
for all to authenticated
using (public.has_workspace_role(workspace_id, array['owner']::text[]))
with check (public.has_workspace_role(workspace_id, array['owner']::text[]));

grant select on public.permission_catalog to authenticated;
grant select, insert, update, delete on
  public.workspace_roles,
  public.role_permissions,
  public.user_permissions,
  public.user_branch_access
to authenticated;


-- Enforce same-workspace membership and branch ownership for assignments.
create unique index if not exists branches_workspace_id_id_key
  on public.branches(workspace_id, id);
create unique index if not exists workspace_members_workspace_user_key
  on public.workspace_members(workspace_id, user_id);

do $
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'user_permissions_workspace_member_fk'
      and conrelid = 'public.user_permissions'::regclass
  ) then
    alter table public.user_permissions
      add constraint user_permissions_workspace_member_fk
      foreign key (workspace_id, user_id)
      references public.workspace_members(workspace_id, user_id)
      on delete cascade;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'user_branch_access_workspace_member_fk'
      and conrelid = 'public.user_branch_access'::regclass
  ) then
    alter table public.user_branch_access
      add constraint user_branch_access_workspace_member_fk
      foreign key (workspace_id, user_id)
      references public.workspace_members(workspace_id, user_id)
      on delete cascade;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'user_branch_access_workspace_branch_fk'
      and conrelid = 'public.user_branch_access'::regclass
  ) then
    alter table public.user_branch_access
      add constraint user_branch_access_workspace_branch_fk
      foreign key (workspace_id, branch_id)
      references public.branches(workspace_id, id)
      on delete cascade;
  end if;
end $;

commit;
