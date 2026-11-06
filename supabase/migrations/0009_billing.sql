-- Stage 8: firm-scoped billing, append-only payments, and reportable snapshots.
-- Amounts are numeric rupees, rounded half-up to two decimal places by the database.
begin;

create table public.billing_profiles (
  firm_id uuid primary key references public.firms(id) on delete restrict,
  billing_entity_name text not null check (char_length(trim(billing_entity_name)) between 1 and 240),
  address text,
  tax_code text,
  tax_rate numeric(5,2) not null default 0 check (tax_rate >= 0 and tax_rate <= 100),
  currency text not null default 'INR' check (currency ~ '^[A-Z]{3}$'),
  payment_terms_days integer not null default 30 check (payment_terms_days between 0 and 3650),
  updated_by_profile_id uuid,
  updated_at timestamptz not null default timezone('utc', now()),
  foreign key (firm_id, updated_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete set null
);

create table public.invoice_number_counters (
  firm_id uuid primary key references public.firms(id) on delete restrict,
  next_number bigint not null default 1 check (next_number > 0)
);

create table public.invoices (
  id uuid primary key default gen_random_uuid(), firm_id uuid not null, client_id uuid not null,
  status text not null default 'DRAFT' check (status in ('DRAFT','PROFORMA','ISSUED','VOID')),
  invoice_number text, currency text not null default 'INR' check (currency ~ '^[A-Z]{3}$'),
  issue_date date, due_date date, payment_terms_days integer not null default 30 check (payment_terms_days between 0 and 3650),
  billing_entity_name text not null, billing_entity_address text, billing_tax_code text,
  client_name_snapshot text not null, client_tax_identifier_snapshot text,
  subtotal numeric(18,2) not null default 0 check (subtotal >= 0), tax_total numeric(18,2) not null default 0 check (tax_total >= 0), total numeric(18,2) not null default 0 check (total >= 0),
  notes text, created_by_profile_id uuid not null, issued_by_profile_id uuid, voided_by_profile_id uuid, voided_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()), updated_at timestamptz not null default timezone('utc', now()),
  unique (firm_id, id), unique (firm_id, invoice_number),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, client_id) references public.clients(firm_id,id) on delete restrict,
  foreign key (firm_id, created_by_profile_id) references public.firm_memberships(firm_id,profile_id) on delete restrict,
  foreign key (firm_id, issued_by_profile_id) references public.firm_memberships(firm_id,profile_id) on delete restrict,
  foreign key (firm_id, voided_by_profile_id) references public.firm_memberships(firm_id,profile_id) on delete restrict,
  check ((status in ('ISSUED','VOID') and invoice_number is not null and issue_date is not null) or status in ('DRAFT','PROFORMA')),
  check (due_date is null or issue_date is null or due_date >= issue_date)
);

create table public.invoice_lines (
  id uuid primary key default gen_random_uuid(), firm_id uuid not null, invoice_id uuid not null,
  client_id uuid not null, service_id uuid, task_id uuid, description text not null check (char_length(trim(description)) between 1 and 500),
  quantity numeric(18,2) not null check (quantity > 0), rate numeric(18,2) not null check (rate >= 0), tax_rate numeric(5,2) not null default 0 check (tax_rate >= 0 and tax_rate <= 100), tax_code text,
  line_subtotal numeric(18,2) not null default 0, line_tax numeric(18,2) not null default 0, line_total numeric(18,2) not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  unique (firm_id,id), foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, invoice_id) references public.invoices(firm_id,id) on delete restrict,
  foreign key (firm_id, client_id) references public.clients(firm_id,id) on delete restrict,
  foreign key (firm_id, service_id) references public.services(firm_id,id) on delete restrict,
  foreign key (firm_id, task_id) references public.tasks(firm_id,id) on delete restrict,
  check (line_subtotal = round(quantity * rate, 2)), check (line_tax = round(line_subtotal * tax_rate / 100, 2)), check (line_total = line_subtotal + line_tax)
);

create table public.payment_entries (
  id uuid primary key default gen_random_uuid(), firm_id uuid not null, invoice_id uuid not null,
  entry_type text not null default 'PAYMENT' check (entry_type in ('PAYMENT','REVERSAL','ADJUSTMENT')),
  amount numeric(18,2) not null check (amount > 0), payment_date date not null default current_date, reference text, note text, created_by_profile_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  unique(firm_id,id), foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id,invoice_id) references public.invoices(firm_id,id) on delete restrict,
  foreign key (firm_id,created_by_profile_id) references public.firm_memberships(firm_id,profile_id) on delete restrict
);

create index invoices_firm_status_date_idx on public.invoices(firm_id,status,issue_date);
create index invoices_firm_client_idx on public.invoices(firm_id,client_id,created_at desc);
create index invoice_lines_task_idx on public.invoice_lines(firm_id,task_id);
create index payments_invoice_idx on public.payment_entries(firm_id,invoice_id,created_at);
create unique index invoice_lines_one_task_idx on public.invoice_lines(firm_id,task_id) where task_id is not null;

create or replace function public.billing_recalculate_invoice(p_invoice_id uuid) returns void language plpgsql security definer set search_path=public as $$
declare i public.invoices; s numeric(18,2); t numeric(18,2);
begin select * into i from public.invoices where id=p_invoice_id for update; if i.id is null then raise exception 'invoice not found'; end if;
 select coalesce(sum(line_subtotal),0),coalesce(sum(line_tax),0) into s,t from public.invoice_lines where firm_id=i.firm_id and invoice_id=i.id;
 if i.status not in ('DRAFT','PROFORMA') then raise exception 'issued invoice is immutable'; end if;
 update public.invoices set subtotal=round(s,2),tax_total=round(t,2),total=round(s+t,2) where id=i.id;
end; $$;

create or replace function public.create_invoice(p_client_id uuid,p_status text default 'DRAFT',p_due_date date default null,p_notes text default null) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare m public.firm_memberships; c public.clients; b public.billing_profiles; result uuid;
begin select * into m from public.firm_memberships where profile_id=auth.uid() and status='ACTIVE' and archived_at is null limit 1; if m.firm_id is null then raise exception 'firm membership required' using errcode='42501'; end if;
 if p_status not in ('DRAFT','PROFORMA') then raise exception 'invoice may only be created as draft or proforma'; end if;
 select * into c from public.clients where id=p_client_id and firm_id=m.firm_id and archived_at is null; if c.id is null then raise exception 'client unavailable' using errcode='P0002'; end if;
 select * into b from public.billing_profiles where firm_id=m.firm_id;
 insert into public.invoices(firm_id,client_id,status,currency,payment_terms_days,due_date,billing_entity_name,billing_entity_address,billing_tax_code,client_name_snapshot,client_tax_identifier_snapshot,notes,created_by_profile_id)
 values(m.firm_id,c.id,p_status,coalesce(b.currency,'INR'),coalesce(b.payment_terms_days,30),p_due_date,coalesce(b.billing_entity_name,(select name from public.firms where id=m.firm_id)),b.address,b.tax_code,c.legal_name,c.tax_identifier,nullif(trim(p_notes),''),auth.uid()) returning id into result;
 insert into public.audit_events(firm_id,actor_profile_id,action,entity_table,entity_id,metadata) values(m.firm_id,auth.uid(),'invoice.created','invoices',result,jsonb_build_object('client_id',c.id,'status',p_status)); return result;
end; $$;

create or replace function public.add_invoice_line(p_invoice_id uuid,p_description text,p_quantity numeric,p_rate numeric,p_tax_rate numeric default 0,p_tax_code text default null,p_service_id uuid default null,p_task_id uuid default null) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare m public.firm_memberships; i public.invoices; l uuid; sub numeric(18,2); tax numeric(18,2);
begin select * into m from public.firm_memberships where profile_id=auth.uid() and status='ACTIVE' and archived_at is null limit 1; select * into i from public.invoices where id=p_invoice_id and firm_id=m.firm_id for update; if i.id is null or i.status not in ('DRAFT','PROFORMA') then raise exception 'editable invoice not found'; end if; if p_quantity<=0 or p_rate<0 or p_tax_rate<0 or p_tax_rate>100 then raise exception 'invalid line amounts'; end if; sub:=round(p_quantity*p_rate,2); tax:=round(sub*p_tax_rate/100,2);
 insert into public.invoice_lines(firm_id,invoice_id,client_id,service_id,task_id,description,quantity,rate,tax_rate,tax_code,line_subtotal,line_tax,line_total) values(m.firm_id,i.id,i.client_id,p_service_id,p_task_id,trim(p_description),p_quantity,p_rate,p_tax_rate,nullif(trim(p_tax_code),''),sub,tax,sub+tax) returning id into l; perform public.billing_recalculate_invoice(i.id); return l; end; $$;

create or replace function public.issue_invoice(p_invoice_id uuid) returns text language plpgsql security definer set search_path=public,auth as $$
declare m public.firm_memberships; i public.invoices; n bigint; result text;
begin select * into m from public.firm_memberships where profile_id=auth.uid() and status='ACTIVE' and archived_at is null limit 1; select * into i from public.invoices where id=p_invoice_id and firm_id=m.firm_id for update; if i.id is null then raise exception 'invoice not found'; end if; if i.status='ISSUED' then return i.invoice_number; end if; if i.status='VOID' then raise exception 'void invoice cannot be issued'; end if; if not exists(select 1 from public.invoice_lines where firm_id=m.firm_id and invoice_id=i.id) then raise exception 'invoice requires a line'; end if; perform public.billing_recalculate_invoice(i.id); insert into public.invoice_number_counters(firm_id) values(m.firm_id) on conflict do nothing; select next_number into n from public.invoice_number_counters where firm_id=m.firm_id for update; update public.invoice_number_counters set next_number=n+1 where firm_id=m.firm_id; result:=format('INV-%s-%s',to_char(current_date,'YYYY'),lpad(n::text,6,'0')); update public.invoices set status='ISSUED',invoice_number=result,issue_date=current_date,due_date=coalesce(due_date,current_date+payment_terms_days),issued_by_profile_id=auth.uid() where id=i.id; insert into public.audit_events(firm_id,actor_profile_id,action,entity_table,entity_id,metadata) values(m.firm_id,auth.uid(),'invoice.issued','invoices',i.id,jsonb_build_object('invoice_number',result,'total',i.total)); return result; end; $$;

create or replace function public.record_invoice_payment(p_invoice_id uuid,p_amount numeric,p_payment_date date default current_date,p_reference text default null,p_note text default null,p_entry_type text default 'PAYMENT') returns uuid language plpgsql security definer set search_path=public,auth as $$
declare m public.firm_memberships; i public.invoices; paid numeric(18,2); balance numeric(18,2); result uuid;
begin select * into m from public.firm_memberships where profile_id=auth.uid() and status='ACTIVE' and archived_at is null limit 1; select * into i from public.invoices where id=p_invoice_id and firm_id=m.firm_id for update; if i.id is null or i.status not in ('ISSUED','VOID') then raise exception 'payable invoice not found'; end if; if p_amount<=0 then raise exception 'payment amount must be positive'; end if; if p_entry_type not in ('PAYMENT','REVERSAL','ADJUSTMENT') then raise exception 'invalid payment entry type'; end if; select coalesce(sum(case when entry_type='PAYMENT' then amount else -amount end),0) into paid from public.payment_entries where firm_id=m.firm_id and invoice_id=i.id; balance:=round(i.total-paid,2); if p_entry_type='PAYMENT' and p_amount>balance then raise exception 'payment exceeds outstanding balance'; end if; if p_entry_type<>'PAYMENT' and p_amount>paid then raise exception 'adjustment exceeds recorded payments'; end if; insert into public.payment_entries(firm_id,invoice_id,entry_type,amount,payment_date,reference,note,created_by_profile_id) values(m.firm_id,i.id,p_entry_type,p_amount,p_payment_date,nullif(trim(p_reference),''),nullif(trim(p_note),''),auth.uid()) returning id into result; insert into public.audit_events(firm_id,actor_profile_id,action,entity_table,entity_id,metadata) values(m.firm_id,auth.uid(),'payment.recorded','payment_entries',result,jsonb_build_object('invoice_id',i.id,'entry_type',p_entry_type,'amount',p_amount)); return result; end; $$;

create or replace function public.invoice_completed_task(p_task_id uuid,p_rate numeric,p_tax_rate numeric default 0,p_tax_code text default null) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare m public.firm_memberships; t public.tasks; existing uuid; i uuid;
begin select * into m from public.firm_memberships where profile_id=auth.uid() and status='ACTIVE' and archived_at is null limit 1; select * into t from public.tasks where id=p_task_id and firm_id=m.firm_id and archived_at is null for update; if t.id is null or t.status<>'COMPLETED' or t.client_id is null then raise exception 'only completed client tasks can be invoiced'; end if; select invoice_id into existing from public.invoice_lines where firm_id=m.firm_id and task_id=t.id limit 1; if existing is not null then return existing; end if; i:=public.create_invoice(t.client_id,'DRAFT',null,'Created from completed task'); perform public.add_invoice_line(i,t.title,1,p_rate,p_tax_rate,p_tax_code,t.service_id,t.id); return i; exception when unique_violation then select invoice_id into existing from public.invoice_lines where firm_id=m.firm_id and task_id=t.id; return existing; end; $$;

create or replace function public.void_invoice(p_invoice_id uuid,p_reason text) returns void language plpgsql security definer set search_path=public,auth as $$
declare m public.firm_memberships; i public.invoices;
begin select * into m from public.firm_memberships where profile_id=auth.uid() and status='ACTIVE' and archived_at is null limit 1; if not public.has_firm_role(m.firm_id,array['OWNER','PARTNER','MANAGER']::public.firm_role[]) then raise exception 'manager permission required' using errcode='42501'; end if; select * into i from public.invoices where id=p_invoice_id and firm_id=m.firm_id for update; if i.id is null or i.status<>'ISSUED' then raise exception 'only issued invoices can be voided'; end if; if exists(select 1 from public.payment_entries where firm_id=m.firm_id and invoice_id=i.id and entry_type='PAYMENT') then raise exception 'paid invoices require payment reversal before void'; end if; update public.invoices set status='VOID',voided_by_profile_id=auth.uid(),voided_at=timezone('utc',now()),notes=concat_ws(E'\n',notes,'Void reason: '||nullif(trim(p_reason),'')) where id=i.id; insert into public.audit_events(firm_id,actor_profile_id,action,entity_table,entity_id,metadata) values(m.firm_id,auth.uid(),'invoice.voided','invoices',i.id,jsonb_build_object('reason',p_reason)); end; $$;

revoke all on function public.create_invoice(uuid,text,date,text),public.add_invoice_line(uuid,text,numeric,numeric,numeric,text,uuid,uuid),public.issue_invoice(uuid),public.record_invoice_payment(uuid,numeric,date,text,text,text) from public;
grant execute on function public.create_invoice(uuid,text,date,text),public.add_invoice_line(uuid,text,numeric,numeric,numeric,text,uuid,uuid),public.issue_invoice(uuid),public.record_invoice_payment(uuid,numeric,date,text,text,text) to authenticated,service_role;
grant execute on function public.invoice_completed_task(uuid,numeric,numeric,text),public.void_invoice(uuid,text) to authenticated,service_role;

alter table public.billing_profiles enable row level security; alter table public.billing_profiles force row level security;
alter table public.invoice_number_counters enable row level security; alter table public.invoice_number_counters force row level security;
alter table public.invoices enable row level security; alter table public.invoices force row level security;
alter table public.invoice_lines enable row level security; alter table public.invoice_lines force row level security;
alter table public.payment_entries enable row level security; alter table public.payment_entries force row level security;
create policy billing_profile_member on public.billing_profiles for select to authenticated using (public.is_firm_member(firm_id));
create policy invoice_member on public.invoices for select to authenticated using (public.is_firm_member(firm_id));
create policy invoice_lines_member on public.invoice_lines for select to authenticated using (public.is_firm_member(firm_id));
create policy payment_member on public.payment_entries for select to authenticated using (public.is_firm_member(firm_id));
grant select,insert,update,delete on all tables in schema public to authenticated;
comment on table public.billing_profiles is 'Firm-configured software billing fields. Tax fields are not professional tax advice.';
comment on table public.invoices is 'Issued rows contain immutable client and billing-entity snapshots.';
comment on table public.payment_entries is 'Append-only ledger; corrections use REVERSAL or ADJUSTMENT entries.';
commit;
