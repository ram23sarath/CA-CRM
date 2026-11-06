-- Stage 10 release hardening: keep the current automation implementation preview-only
-- and make the storage bucket's policy agree with the server-side upload validator.
-- Apply after 0010. This migration is intentionally forward-only.

begin;

update storage.buckets
set allowed_mime_types = array[
  'application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'text/plain',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
]
where id = 'firm-documents';

update public.automation_settings
set safe_preview_mode = true
where safe_preview_mode is distinct from true;

alter table public.automation_settings
  drop constraint if exists automation_settings_preview_only;
alter table public.automation_settings
  add constraint automation_settings_preview_only check (safe_preview_mode is true);

create or replace function public.set_automation_kill_switch(p_paused boolean, p_safe_preview_mode boolean default true)
returns void language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships;
begin
  m := public.team_active_membership();
  if not public.has_firm_role(m.firm_id, array['OWNER','PARTNER','MANAGER']::public.firm_role[]) then
    raise exception 'manager automation permission required' using errcode = '42501';
  end if;
  if p_safe_preview_mode is not true then
    raise exception 'external automation delivery is not supported in this release' using errcode = '22023';
  end if;
  insert into public.automation_settings(firm_id, paused, safe_preview_mode, updated_by_profile_id)
  values(m.firm_id, p_paused, true, auth.uid())
  on conflict (firm_id) do update set paused = excluded.paused, safe_preview_mode = true,
    updated_by_profile_id = excluded.updated_by_profile_id, updated_at = timezone('utc', now());
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, metadata)
  values(m.firm_id, auth.uid(), auth.uid(), 'automation.settings_updated', 'automation_settings', jsonb_build_object('paused', p_paused, 'safe_preview_mode', true));
end;
$$;

commit;
