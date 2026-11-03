-- ALREDFANI RETAIL ERP
-- Seed a safe default role catalog for every existing workspace.
-- Additive and idempotent: does not alter memberships, snapshots, or existing ERP records.
-- Requires 002_role_permission_foundation.sql to have been applied first.

begin;

-- Create the standard role definitions once per workspace.
insert into public.workspace_roles (workspace_id, name, role_key, is_system)
select w.id, r.name, r.role_key, true
from public.workspaces w
cross join (values
  ('owner', 'مالك النظام'),
  ('general_manager', 'مدير عام'),
  ('branch_manager', 'مدير فرع'),
  ('accountant', 'محاسب'),
  ('cashier', 'كاشير'),
  ('stockkeeper', 'أمين مخزن'),
  ('custom', 'مستخدم مخصص')
) as r(role_key, name)
on conflict (workspace_id, role_key) do nothing;

-- Define the initial least-privilege permission sets.
-- Owner receives every permission in the catalog, including future additions.
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
select wr.workspace_id, wr.id, p.permission_key, true
from public.workspace_roles wr
join role_grants rg on rg.role_key = wr.role_key
cross join lateral unnest(rg.permission_keys) as granted(permission_key)
join public.permission_catalog p on p.permission_key = granted.permission_key
on conflict (workspace_id, role_id, permission_key)
do update set allowed = excluded.allowed;

-- The owner role is always granted every catalog permission.
insert into public.role_permissions (workspace_id, role_id, permission_key, allowed)
select wr.workspace_id, wr.id, pc.permission_key, true
from public.workspace_roles wr
cross join public.permission_catalog pc
where wr.role_key = 'owner'
on conflict (workspace_id, role_id, permission_key)
do update set allowed = excluded.allowed;

-- 'custom' deliberately starts with no permissions. The owner configures it explicitly.

commit;
