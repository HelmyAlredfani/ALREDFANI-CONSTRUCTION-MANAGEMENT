-- ALREDFANI RETAIL ERP
-- Stage 1: central permission helpers based on the verified schema.
-- This migration is intentionally non-disruptive:
-- it does NOT drop or replace existing RLS policies and does NOT alter ERP data.
-- Existing permissive policies must be replaced in a separately reviewed rollout
-- before these helpers can be considered database-level enforcement.

begin;

create or replace function public.has_workspace_permission(
  p_workspace_id uuid,
  p_permission_key text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_legacy_role text;
  v_role_key text;
  v_user_override boolean;
  v_role_allowed boolean;
begin
  v_user_id := auth.uid();

  if v_user_id is null
     or p_workspace_id is null
     or p_permission_key is null
     or length(trim(p_permission_key)) = 0 then
    return false;
  end if;

  select wm.role, wr.role_key
    into v_legacy_role, v_role_key
  from public.workspace_members wm
  left join public.workspace_roles wr
    on wr.id = wm.role_id
   and wr.workspace_id = wm.workspace_id
  where wm.workspace_id = p_workspace_id
    and wm.user_id = v_user_id
  limit 1;

  if not found then
    return false;
  end if;

  -- Preserve the established owner role during the staged rollout.
  if lower(coalesce(v_role_key, '')) = 'owner'
     or lower(coalesce(v_legacy_role, '')) = 'owner' then
    return true;
  end if;

  select up.allowed
    into v_user_override
  from public.user_permissions up
  where up.workspace_id = p_workspace_id
    and up.user_id = v_user_id
    and up.permission_key = p_permission_key;

  if found then
    return coalesce(v_user_override, false);
  end if;

  select rp.allowed
    into v_role_allowed
  from public.workspace_members wm
  join public.role_permissions rp
    on rp.workspace_id = wm.workspace_id
   and rp.role_id = wm.role_id
  where wm.workspace_id = p_workspace_id
    and wm.user_id = v_user_id
    and rp.permission_key = p_permission_key
  limit 1;

  return coalesce(v_role_allowed, false);
end;
$$;

create or replace function public.has_branch_access(
  p_workspace_id uuid,
  p_branch_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_legacy_role text;
  v_role_key text;
begin
  v_user_id := auth.uid();

  if v_user_id is null
     or p_workspace_id is null
     or p_branch_id is null then
    return false;
  end if;

  if not exists (
    select 1
    from public.branches b
    where b.id = p_branch_id
      and b.workspace_id = p_workspace_id
  ) then
    return false;
  end if;

  select wm.role, wr.role_key
    into v_legacy_role, v_role_key
  from public.workspace_members wm
  left join public.workspace_roles wr
    on wr.id = wm.role_id
   and wr.workspace_id = wm.workspace_id
  where wm.workspace_id = p_workspace_id
    and wm.user_id = v_user_id
  limit 1;

  if not found then
    return false;
  end if;

  if lower(coalesce(v_role_key, '')) = 'owner'
     or lower(coalesce(v_legacy_role, '')) = 'owner' then
    return true;
  end if;

  return exists (
    select 1
    from public.user_branch_access uba
    where uba.workspace_id = p_workspace_id
      and uba.user_id = v_user_id
      and uba.branch_id = p_branch_id
  );
end;
$$;

revoke all on function public.has_workspace_permission(uuid, text) from public, anon;
revoke all on function public.has_branch_access(uuid, uuid) from public, anon;
grant execute on function public.has_workspace_permission(uuid, text) to authenticated;
grant execute on function public.has_branch_access(uuid, uuid) to authenticated;

commit;
