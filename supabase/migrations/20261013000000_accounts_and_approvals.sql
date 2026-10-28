-- ProFrame Phase 36: accounts, access and approvals.
--
-- The database is the authority. Every rule below is kept here, in the
-- database, against the signed session (`auth.uid()`) and this schema's own
-- tables — never against a role, an owner id, a factory id or a decision
-- sent by the client.
--
--   factories            one a workshop; its owner is fixed when it is made
--   accounts             who each signed-in user is: owner or labour, which
--                        factory, active or suspended. No client writes it.
--   worker_invites       a seat held for somebody invited, by a one-time code
--   customers, designs   the factory's records; the owner's alone to write
--   design_revisions     every version a design has had
--   design_assignments   which labour account may see which design
--   requests             what labour asks for; only the owner decides
--   notifications        in-app, to one account
--   factory_documents    the owner's other records (prices, quotations, …)
--   audit_events         who did what to whom, and when
--
-- Clients get `select` on what row-level security lets them see, and
-- nothing else: every write is a function below that reads the caller from
-- the session, checks them, and writes in one transaction.
--
-- Errors are raised as `PF:<code>`, which the application says in words.

create schema if not exists private;
revoke all on schema private from public;

-- ------------------------------------------------------------------ tables

create table public.factories (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  owner_id uuid not null unique references auth.users (id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.accounts (
  user_id uuid primary key references auth.users (id) on delete restrict,
  factory_id uuid not null references public.factories (id),
  role text not null check (role in ('owner', 'labour')),
  name text not null check (char_length(name) between 1 and 120),
  login text not null,
  status text not null default 'active'
    check (status in ('active', 'suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index accounts_one_owner on public.accounts (factory_id)
  where role = 'owner';
create index accounts_factory on public.accounts (factory_id);

create table public.worker_invites (
  id uuid primary key default gen_random_uuid(),
  factory_id uuid not null references public.factories (id),
  email text not null check (email = lower(email) and position('@' in email) > 1),
  name text not null check (char_length(name) between 1 and 120),
  code_hash text not null unique,
  status text not null default 'open'
    check (status in ('open', 'used', 'revoked')),
  expires_at timestamptz not null,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  used_by uuid references auth.users (id),
  used_at timestamptz
);
create index worker_invites_factory on public.worker_invites (factory_id);

create table public.customers (
  factory_id uuid not null references public.factories (id),
  id text not null check (char_length(id) between 1 and 200),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  name text not null default '',
  revision integer not null default 1,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id),
  primary key (factory_id, id)
);

create table public.designs (
  factory_id uuid not null references public.factories (id),
  id text not null check (char_length(id) between 1 and 200),
  customer_id text not null,
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  name text not null default '',
  category text,
  revision integer not null default 1,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id),
  primary key (factory_id, id),
  foreign key (factory_id, customer_id)
    references public.customers (factory_id, id)
);
create index designs_customer on public.designs (factory_id, customer_id);

create table public.design_revisions (
  factory_id uuid not null,
  design_id text not null,
  revision integer not null,
  data jsonb not null,
  changed_by uuid,
  changed_at timestamptz not null default now(),
  source text not null default 'owner',
  request_id uuid,
  primary key (factory_id, design_id, revision)
);

create table public.design_assignments (
  id uuid primary key default gen_random_uuid(),
  factory_id uuid not null,
  design_id text not null,
  worker_id uuid not null references public.accounts (user_id),
  status text not null default 'active' check (status in ('active', 'removed')),
  assigned_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  removed_by uuid references auth.users (id),
  removed_at timestamptz,
  foreign key (factory_id, design_id) references public.designs (factory_id, id)
);
create unique index design_assignments_once
  on public.design_assignments (factory_id, design_id, worker_id)
  where status = 'active';
create index design_assignments_worker
  on public.design_assignments (worker_id) where status = 'active';

create table public.requests (
  id uuid primary key default gen_random_uuid(),
  factory_id uuid not null references public.factories (id),
  kind text not null
    check (kind in ('new_design', 'new_customer_design', 'design_change')),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'cancelled', 'failed')),
  requested_by uuid not null references public.accounts (user_id),
  client_key uuid not null,
  customer_id text,
  design_id text,
  base_revision integer,
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  description text not null default '',
  created_at timestamptz not null default now(),
  decided_by uuid references auth.users (id),
  decided_at timestamptz,
  decision_note text,
  result_customer_id text,
  result_design_id text,
  result_revision integer,
  failure text,
  unique (requested_by, client_key)
);
create index requests_factory_status on public.requests (factory_id, status);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  factory_id uuid not null references public.factories (id),
  recipient uuid not null references auth.users (id),
  kind text not null,
  request_id uuid references public.requests (id),
  body jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index notifications_recipient on public.notifications (recipient, created_at desc);

create table public.factory_documents (
  factory_id uuid not null references public.factories (id),
  key text not null check (key like 'proframe.%' and char_length(key) <= 300),
  value text not null,
  revision integer not null default 1,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id),
  primary key (factory_id, key)
);

create table public.audit_events (
  id bigint generated always as identity primary key,
  factory_id uuid not null,
  at timestamptz not null default now(),
  actor uuid,
  action text not null,
  subject text,
  detail jsonb not null default '{}'::jsonb
);
create index audit_events_factory on public.audit_events (factory_id, at desc);

-- ------------------------------------------------------- who is asking

-- The caller's own account, active — or an error. Every function that does
-- anything starts here, so a session without an account, or a suspended
-- one, can do nothing at all.
create function private.me() returns public.accounts
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  a public.accounts;
begin
  if auth.uid() is null then
    raise exception 'PF:not_signed_in';
  end if;
  select * into a from public.accounts where user_id = auth.uid();
  if not found then
    raise exception 'PF:no_account';
  end if;
  if a.status <> 'active' then
    raise exception 'PF:suspended';
  end if;
  return a;
end $$;

create function private.owner() returns public.accounts
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  a public.accounts := private.me();
begin
  if a.role <> 'owner' then
    raise exception 'PF:not_owner';
  end if;
  return a;
end $$;

create function private.labour() returns public.accounts
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  a public.accounts := private.me();
begin
  if a.role <> 'labour' then
    raise exception 'PF:not_labour';
  end if;
  return a;
end $$;

-- For row-level security: the factory the caller owns, if they are its
-- active owner; null otherwise. Never raises, so a policy simply sees no
-- rows.
create function private.owned_factory() returns uuid
language sql stable security definer set search_path = '' as $$
  select factory_id from public.accounts
  where user_id = auth.uid() and role = 'owner' and status = 'active'
$$;

create function private.active_account() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.accounts
    where user_id = auth.uid() and status = 'active'
  )
$$;

create function private.audit(
  p_factory uuid, p_action text, p_subject text, p_detail jsonb
) returns void
language sql security definer set search_path = '' as $$
  insert into public.audit_events (factory_id, actor, action, subject, detail)
  values (p_factory, auth.uid(), p_action, p_subject, coalesce(p_detail, '{}'::jsonb))
$$;

create function private.notify(
  p_factory uuid, p_recipient uuid, p_kind text, p_request uuid, p_body jsonb
) returns void
language sql security definer set search_path = '' as $$
  insert into public.notifications (factory_id, recipient, kind, request_id, body)
  values (p_factory, p_recipient, p_kind, p_request, coalesce(p_body, '{}'::jsonb))
$$;

-- How many seats are taken: active labour accounts and open, unexpired
-- invitations. Called with the factory's row locked.
create function private.seats_taken(p_factory uuid) returns integer
language sql stable security definer set search_path = '' as $$
  select (
    select count(*) from public.accounts
    where factory_id = p_factory and role = 'labour' and status = 'active'
  )::integer + (
    select count(*) from public.worker_invites
    where factory_id = p_factory and status = 'open' and expires_at > now()
  )::integer
$$;

create function private.max_workers() returns integer
language sql immutable as $$ select 3 $$;

create function private.known_category(p text) returns boolean
language sql immutable as $$
  select p in ('door', 'window', 'sliding', 'both', 'angled')
$$;

create function private.clean(p text, p_max integer) returns text
language sql immutable as $$
  select left(btrim(coalesce(p, '')), p_max)
$$;

-- ------------------------------------------------------------ sign-up

-- Every new user is given their account here, by the database. A sign-up
-- with no invitation code is an owner, with a factory of their own. One
-- with a code is labour in the factory that invited them — if the code is
-- open, unexpired, for this email address, and a seat is free. Anything
-- the client put in its metadata as a role is never read.
create function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_name text := private.clean(meta ->> 'name', 120);
  v_code text := private.clean(meta ->> 'invite_code', 200);
  v_email text := lower(coalesce(new.email, ''));
  v_factory uuid;
  inv public.worker_invites;
begin
  if v_name = '' then
    raise exception 'PF:name_required';
  end if;
  if v_code = '' then
    insert into public.factories (name, owner_id)
    values (coalesce(nullif(private.clean(meta ->> 'factory_name', 120), ''), v_name),
            new.id)
    returning id into v_factory;
    insert into public.accounts (user_id, factory_id, role, name, login)
    values (new.id, v_factory, 'owner', v_name, v_email);
    perform private.audit(v_factory, 'owner.signed_up', new.id::text, '{}');
    return new;
  end if;

  select * into inv from public.worker_invites
  where code_hash = encode(sha256(convert_to(v_code, 'UTF8')), 'hex')
  for update;
  if not found or inv.status <> 'open' or inv.expires_at <= now()
     or inv.email <> v_email then
    raise exception 'PF:invite_invalid';
  end if;
  -- The seat was held by the invitation; it becomes the account's.
  perform 1 from public.factories where id = inv.factory_id for update;
  insert into public.accounts (user_id, factory_id, role, name, login)
  values (new.id, inv.factory_id, 'labour', v_name, v_email);
  update public.worker_invites
     set status = 'used', used_by = new.id, used_at = now()
   where id = inv.id;
  perform private.audit(inv.factory_id, 'worker.joined', new.id::text,
                        jsonb_build_object('invite', inv.id));
  perform private.notify(inv.factory_id,
    (select owner_id from public.factories where id = inv.factory_id),
    'worker_joined', null, jsonb_build_object('name', v_name));
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ------------------------------------------------------------ accounts

-- The caller's own account, whatever its status, so the application can
-- say "suspended" rather than nothing.
create function public.my_account() returns table (
  user_id uuid, factory_id uuid, factory_name text, role text,
  name text, login text, status text
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if auth.uid() is null then
    raise exception 'PF:not_signed_in';
  end if;
  return query
    select a.user_id, a.factory_id, f.name, a.role, a.name, a.login, a.status
    from public.accounts a join public.factories f on f.id = a.factory_id
    where a.user_id = auth.uid();
end $$;

-- ------------------------------------------------------------- workers

create function public.factory_workers() returns table (
  user_id uuid, name text, login text, status text,
  assigned integer, pending integer, created_at timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
begin
  return query
    select a.user_id, a.name, a.login, a.status,
      (select count(*) from public.design_assignments x
         where x.worker_id = a.user_id and x.status = 'active')::integer,
      (select count(*) from public.requests r
         where r.requested_by = a.user_id and r.status = 'pending')::integer,
      a.created_at
    from public.accounts a
    where a.factory_id = o.factory_id and a.role = 'labour'
    order by a.created_at;
end $$;

create function public.open_invites() returns table (
  id uuid, name text, email text, expires_at timestamptz, created_at timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
begin
  return query
    select i.id, i.name, i.email, i.expires_at, i.created_at
    from public.worker_invites i
    where i.factory_id = o.factory_id and i.status = 'open'
      and i.expires_at > now()
    order by i.created_at;
end $$;

-- An invitation for [p_email], holding one of the factory's three seats.
-- The code is returned once and only its hash is kept. The factory's row
-- is locked first, so two invitations at once cannot both take the last
-- seat.
create function public.invite_worker(p_name text, p_email text)
returns table (invite_id uuid, code text, expires_at timestamptz)
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
  v_name text := private.clean(p_name, 120);
  v_email text := lower(private.clean(p_email, 320));
  v_code text := replace(gen_random_uuid()::text, '-', '')
              || replace(gen_random_uuid()::text, '-', '');
  v_id uuid;
  v_until timestamptz := now() + interval '7 days';
begin
  if v_name = '' then raise exception 'PF:name_required'; end if;
  if position('@' in v_email) < 2 then raise exception 'PF:email_invalid'; end if;
  perform 1 from public.factories where id = o.factory_id for update;
  if exists (select 1 from public.accounts where login = v_email) then
    raise exception 'PF:email_taken';
  end if;
  if exists (select 1 from public.worker_invites
             where factory_id = o.factory_id and email = v_email
               and status = 'open' and expires_at > now()) then
    raise exception 'PF:already_invited';
  end if;
  if private.seats_taken(o.factory_id) >= private.max_workers() then
    raise exception 'PF:worker_limit';
  end if;
  insert into public.worker_invites
    (factory_id, email, name, code_hash, expires_at, created_by)
  values (o.factory_id, v_email, v_name,
          encode(sha256(convert_to(v_code, 'UTF8')), 'hex'), v_until, o.user_id)
  returning id into v_id;
  perform private.audit(o.factory_id, 'worker.invited', v_id::text,
                        jsonb_build_object('email', v_email));
  return query select v_id, v_code, v_until;
end $$;

create function public.revoke_invite(p_invite uuid) returns void
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
begin
  update public.worker_invites set status = 'revoked'
   where id = p_invite and factory_id = o.factory_id and status = 'open';
  if not found then raise exception 'PF:not_found'; end if;
  perform private.audit(o.factory_id, 'worker.invite_revoked', p_invite::text, '{}');
end $$;

-- Suspends or reactivates a worker of the caller's factory. Suspending
-- takes effect at once: every function and policy asks for an active
-- account. Nothing of the factory's is deleted. Reactivating takes a seat,
-- so it is held to the limit under the same lock as an invitation.
create function public.set_worker_status(p_worker uuid, p_status text)
returns void
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
  w public.accounts;
begin
  if p_status not in ('active', 'suspended') then
    raise exception 'PF:invalid';
  end if;
  perform 1 from public.factories where id = o.factory_id for update;
  select * into w from public.accounts
   where user_id = p_worker and factory_id = o.factory_id and role = 'labour'
   for update;
  if not found then raise exception 'PF:not_found'; end if;
  if w.status = p_status then return; end if;
  if p_status = 'active'
     and private.seats_taken(o.factory_id) >= private.max_workers() then
    raise exception 'PF:worker_limit';
  end if;
  update public.accounts set status = p_status, updated_at = now()
   where user_id = p_worker;
  perform private.audit(o.factory_id, 'worker.' || p_status, p_worker::text, '{}');
end $$;

-- --------------------------------------------------------- assignments

create function public.assign_design(p_design text, p_worker uuid)
returns void
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
begin
  if not exists (select 1 from public.accounts
                 where user_id = p_worker and factory_id = o.factory_id
                   and role = 'labour') then
    raise exception 'PF:not_found';
  end if;
  if not exists (select 1 from public.designs
                 where factory_id = o.factory_id and id = p_design
                   and deleted_at is null) then
    raise exception 'PF:not_found';
  end if;
  insert into public.design_assignments (factory_id, design_id, worker_id, assigned_by)
  values (o.factory_id, p_design, p_worker, o.user_id)
  on conflict (factory_id, design_id, worker_id) where status = 'active'
  do nothing;
  if found then
    perform private.audit(o.factory_id, 'design.assigned', p_design,
                          jsonb_build_object('worker', p_worker));
    perform private.notify(o.factory_id, p_worker, 'design_assigned', null,
      jsonb_build_object('design', p_design));
  end if;
end $$;

create function public.unassign_design(p_design text, p_worker uuid)
returns void
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
begin
  update public.design_assignments
     set status = 'removed', removed_by = o.user_id, removed_at = now()
   where factory_id = o.factory_id and design_id = p_design
     and worker_id = p_worker and status = 'active';
  if found then
    perform private.audit(o.factory_id, 'design.unassigned', p_design,
                          jsonb_build_object('worker', p_worker));
  end if;
end $$;

-- Who each of the factory's designs is assigned to now.
create function public.factory_assignments() returns table (
  design_id text, worker_id uuid, assigned_by uuid, created_at timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
begin
  return query
    select x.design_id, x.worker_id, x.assigned_by, x.created_at
    from public.design_assignments x
    where x.factory_id = o.factory_id and x.status = 'active';
end $$;

-- ------------------------------------------------- the owner's records

-- A design's history row, written whenever its data changes.
create function private.design_history() returns trigger
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if tg_op = 'INSERT' or new.data is distinct from old.data then
    insert into public.design_revisions
      (factory_id, design_id, revision, data, changed_by, source, request_id)
    values (new.factory_id, new.id, new.revision, new.data, auth.uid(),
            coalesce(nullif(current_setting('proframe.source', true), ''), 'owner'),
            nullif(current_setting('proframe.request', true), '')::uuid)
    on conflict do nothing;
  end if;
  return new;
end $$;

create trigger designs_history
  after insert or update on public.designs
  for each row execute function private.design_history();

-- The owner keeps a customer: made where there is none, changed where the
-- revision they had is still the one kept. Returns the new revision.
create function public.owner_put_customer(
  p_id text, p_data jsonb, p_expected integer
) returns integer
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
  c public.customers;
begin
  if jsonb_typeof(p_data) <> 'object' or p_data ->> 'id' is distinct from p_id then
    raise exception 'PF:invalid';
  end if;
  select * into c from public.customers
   where factory_id = o.factory_id and id = p_id for update;
  if not found then
    insert into public.customers (factory_id, id, data, name, updated_by)
    values (o.factory_id, p_id, p_data, coalesce(p_data ->> 'name', ''), o.user_id);
    return 1;
  end if;
  if c.deleted_at is null and c.revision is distinct from p_expected then
    raise exception 'PF:conflict';
  end if;
  update public.customers
     set data = p_data, name = coalesce(p_data ->> 'name', ''),
         revision = c.revision + 1, deleted_at = null,
         updated_at = now(), updated_by = o.user_id
   where factory_id = o.factory_id and id = p_id;
  return c.revision + 1;
end $$;

create function public.owner_put_design(
  p_id text, p_data jsonb, p_expected integer
) returns integer
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
  d public.designs;
  v_customer text := p_data ->> 'customerId';
begin
  if jsonb_typeof(p_data) <> 'object' or p_data ->> 'id' is distinct from p_id
     or v_customer is null then
    raise exception 'PF:invalid';
  end if;
  if not exists (select 1 from public.customers
                 where factory_id = o.factory_id and id = v_customer) then
    raise exception 'PF:customer_missing';
  end if;
  select * into d from public.designs
   where factory_id = o.factory_id and id = p_id for update;
  if not found then
    insert into public.designs
      (factory_id, id, customer_id, data, name, category, updated_by)
    values (o.factory_id, p_id, v_customer, p_data,
            coalesce(p_data ->> 'name', ''), p_data ->> 'category', o.user_id);
    return 1;
  end if;
  if d.deleted_at is null and d.revision is distinct from p_expected then
    raise exception 'PF:conflict';
  end if;
  if d.data = p_data and d.deleted_at is null then
    return d.revision;
  end if;
  update public.designs
     set data = p_data, customer_id = v_customer,
         name = coalesce(p_data ->> 'name', ''), category = p_data ->> 'category',
         revision = d.revision + 1, deleted_at = null,
         updated_at = now(), updated_by = o.user_id
   where factory_id = o.factory_id and id = p_id;
  return d.revision + 1;
end $$;

-- A design taken off the list. Kept, with its history, and every
-- assignment to it ended — so nobody can open it.
create function public.owner_delete_design(p_id text) returns void
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
begin
  update public.designs set deleted_at = now(), updated_by = o.user_id
   where factory_id = o.factory_id and id = p_id and deleted_at is null;
  update public.design_assignments
     set status = 'removed', removed_by = o.user_id, removed_at = now()
   where factory_id = o.factory_id and design_id = p_id and status = 'active';
end $$;

create function public.owner_delete_customer(p_id text) returns void
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
begin
  if exists (select 1 from public.designs
             where factory_id = o.factory_id and customer_id = p_id
               and deleted_at is null) then
    raise exception 'PF:customer_has_designs';
  end if;
  update public.customers set deleted_at = now(), updated_by = o.user_id
   where factory_id = o.factory_id and id = p_id and deleted_at is null;
end $$;

create function public.owner_put_document(
  p_key text, p_value text, p_expected integer
) returns integer
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
  v integer;
begin
  select revision into v from public.factory_documents
   where factory_id = o.factory_id and key = p_key for update;
  if not found then
    insert into public.factory_documents (factory_id, key, value, updated_by)
    values (o.factory_id, p_key, p_value, o.user_id);
    return 1;
  end if;
  if v is distinct from p_expected then raise exception 'PF:conflict'; end if;
  update public.factory_documents
     set value = p_value, revision = v + 1, updated_at = now(), updated_by = o.user_id
   where factory_id = o.factory_id and key = p_key;
  return v + 1;
end $$;

create function public.owner_delete_document(p_key text) returns void
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
begin
  delete from public.factory_documents
   where factory_id = o.factory_id and key = p_key;
end $$;

-- ----------------------------------------------- what labour may see

-- A design, as labour sees it: everything that is drawn, and nothing of
-- what it costs.
create function private.for_labour(p jsonb) returns jsonb
language sql immutable as $$ select p - 'pricing' $$;

create function public.my_assigned_designs() returns table (
  id text, customer_id text, customer_name text, name text, category text,
  revision integer, data jsonb, assigned_at timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  me public.accounts := private.labour();
begin
  return query
    select d.id, d.customer_id, c.name, d.name, d.category, d.revision,
           private.for_labour(d.data), x.created_at
    from public.design_assignments x
    join public.designs d on d.factory_id = x.factory_id and d.id = x.design_id
    join public.customers c on c.factory_id = d.factory_id and c.id = d.customer_id
    where x.worker_id = me.user_id and x.status = 'active'
      and x.factory_id = me.factory_id and d.deleted_at is null
    order by x.created_at desc;
end $$;

-- One design by id — only if it is assigned to the caller now.
create function public.assigned_design(p_id text) returns table (
  id text, customer_id text, customer_name text, name text, category text,
  revision integer, data jsonb
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  me public.accounts := private.labour();
begin
  if not exists (select 1 from public.design_assignments x
                 where x.worker_id = me.user_id and x.factory_id = me.factory_id
                   and x.design_id = p_id and x.status = 'active') then
    raise exception 'PF:not_assigned';
  end if;
  return query
    select d.id, d.customer_id, c.name, d.name, d.category, d.revision,
           private.for_labour(d.data)
    from public.designs d
    join public.customers c on c.factory_id = d.factory_id and c.id = d.customer_id
    where d.factory_id = me.factory_id and d.id = p_id and d.deleted_at is null;
end $$;

-- The customers a worker may name in a request: those whose designs are
-- assigned to them. Their names and nothing else — no phone, no address,
-- no money.
create function public.my_customers() returns table (id text, name text)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  me public.accounts := private.labour();
begin
  return query
    select distinct c.id, c.name
    from public.design_assignments x
    join public.designs d on d.factory_id = x.factory_id and d.id = x.design_id
    join public.customers c on c.factory_id = d.factory_id and c.id = d.customer_id
    where x.worker_id = me.user_id and x.factory_id = me.factory_id
      and x.status = 'active' and d.deleted_at is null and c.deleted_at is null
    order by c.name;
end $$;

-- ------------------------------------------------------------ requests

create function private.new_request(
  me public.accounts, p_kind text, p_client_key uuid, p_customer text,
  p_design text, p_base integer, p_payload jsonb, p_description text
) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_id uuid;
begin
  if p_client_key is null then raise exception 'PF:invalid'; end if;
  select id into v_id from public.requests
   where requested_by = me.user_id and client_key = p_client_key;
  if found then return v_id; end if;
  insert into public.requests (factory_id, kind, requested_by, client_key,
    customer_id, design_id, base_revision, payload, description)
  values (me.factory_id, p_kind, me.user_id, p_client_key, p_customer, p_design,
    p_base, p_payload, private.clean(p_description, 2000))
  returning id into v_id;
  perform private.audit(me.factory_id, 'request.submitted', v_id::text,
                        jsonb_build_object('kind', p_kind));
  perform private.notify(me.factory_id,
    (select owner_id from public.factories where id = me.factory_id),
    'request_submitted', v_id, jsonb_build_object('kind', p_kind, 'by', me.name));
  return v_id;
end $$;

-- Asks for a new design for a customer the worker already works for. It
-- makes a request, never a design.
create function public.submit_new_design_request(
  p_customer text, p_name text, p_category text, p_description text,
  p_client_key uuid
) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  me public.accounts := private.labour();
  v_name text := private.clean(p_name, 200);
begin
  if v_name = '' then raise exception 'PF:name_required'; end if;
  if not private.known_category(p_category) then raise exception 'PF:invalid'; end if;
  if not exists (select 1 from public.my_customers() c where c.id = p_customer) then
    raise exception 'PF:customer_out_of_scope';
  end if;
  return private.new_request(me, 'new_design', p_client_key, p_customer, null, null,
    jsonb_build_object('name', v_name, 'category', p_category), p_description);
end $$;

-- Asks for a new customer and their first design.
create function public.submit_new_customer_request(
  p_customer jsonb, p_name text, p_category text, p_description text,
  p_client_key uuid
) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  me public.accounts := private.labour();
  v_customer text := private.clean(p_customer ->> 'name', 200);
  v_name text := private.clean(p_name, 200);
begin
  if v_customer = '' or v_name = '' then raise exception 'PF:name_required'; end if;
  if not private.known_category(p_category) then raise exception 'PF:invalid'; end if;
  return private.new_request(me, 'new_customer_design', p_client_key, null, null, null,
    jsonb_build_object(
      'customer', jsonb_build_object(
        'name', v_customer,
        'phone', private.clean(p_customer ->> 'phone', 100),
        'address', private.clean(p_customer ->> 'address', 500),
        'notes', private.clean(p_customer ->> 'notes', 2000)),
      'name', v_name, 'category', p_category),
    p_description);
end $$;

-- Proposes a change to an assigned design: the whole proposed design, as
-- drawn, against the revision it was drawn from. The design is not
-- touched.
create function public.submit_change_request(
  p_design text, p_base_revision integer, p_proposed jsonb, p_description text,
  p_client_key uuid
) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  me public.accounts := private.labour();
  d public.designs;
begin
  if jsonb_typeof(p_proposed) is distinct from 'object'
     or octet_length(p_proposed::text) > 4000000
     or p_proposed ->> 'id' is distinct from p_design then
    raise exception 'PF:invalid';
  end if;
  if not exists (select 1 from public.design_assignments x
                 where x.worker_id = me.user_id and x.factory_id = me.factory_id
                   and x.design_id = p_design and x.status = 'active') then
    raise exception 'PF:not_assigned';
  end if;
  select * into d from public.designs
   where factory_id = me.factory_id and id = p_design and deleted_at is null;
  if not found then raise exception 'PF:not_assigned'; end if;
  if p_base_revision is null or p_base_revision > d.revision then
    raise exception 'PF:invalid';
  end if;
  return private.new_request(me, 'design_change', p_client_key, d.customer_id,
    p_design, p_base_revision,
    jsonb_build_object('design', private.for_labour(p_proposed)), p_description);
end $$;

create function public.cancel_request(p_request uuid) returns void
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  me public.accounts := private.labour();
begin
  update public.requests set status = 'cancelled', decided_at = now(),
         decided_by = me.user_id
   where id = p_request and requested_by = me.user_id and status = 'pending';
  if not found then raise exception 'PF:not_pending'; end if;
  perform private.audit(me.factory_id, 'request.cancelled', p_request::text, '{}');
end $$;

-- The request, locked, for its factory's owner to decide — or an error.
-- A request decided already is returned as it is, so the caller can answer
-- a retry with what was done the first time.
create function private.to_decide(o public.accounts, p_request uuid)
returns public.requests
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  r public.requests;
begin
  select * into r from public.requests
   where id = p_request and factory_id = o.factory_id for update;
  if not found then raise exception 'PF:not_found'; end if;
  if r.requested_by = o.user_id then raise exception 'PF:self_approval'; end if;
  return r;
end $$;

create function private.decided(
  o public.accounts, r public.requests, p_status text, p_note text
) returns void
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform private.audit(o.factory_id, 'request.' || p_status, r.id::text,
    jsonb_build_object('note', p_note, 'customer', r.result_customer_id,
                       'design', r.result_design_id));
  perform private.notify(o.factory_id, r.requested_by, 'request_' || p_status, r.id,
    jsonb_build_object('kind', r.kind, 'note', p_note));
end $$;

-- Approves a new design for an existing customer. The design is the one
-- the owner's application made through its own creation rules; it is
-- checked against what was asked and inserted once — a retry is answered
-- with the design made the first time.
create function public.approve_new_design_request(
  p_request uuid, p_design jsonb, p_assign boolean, p_note text
) returns table (design_id text, customer_id text)
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
  r public.requests := private.to_decide(o, p_request);
  v_id text := p_design ->> 'id';
begin
  if r.status = 'approved' then
    return query select r.result_design_id, r.result_customer_id; return;
  end if;
  if r.status <> 'pending' then raise exception 'PF:already_decided'; end if;
  if r.kind <> 'new_design' then raise exception 'PF:invalid'; end if;
  if jsonb_typeof(p_design) is distinct from 'object' or v_id is null
     or p_design ->> 'customerId' is distinct from r.customer_id
     or p_design ->> 'category' is distinct from r.payload ->> 'category' then
    raise exception 'PF:invalid';
  end if;
  if exists (select 1 from public.designs d
             where d.factory_id = o.factory_id and d.id = v_id) then
    raise exception 'PF:invalid';
  end if;
  if not exists (select 1 from public.customers c
                 where c.factory_id = o.factory_id and c.id = r.customer_id
                   and c.deleted_at is null) then
    raise exception 'PF:customer_missing';
  end if;
  perform set_config('proframe.source', 'request', true);
  perform set_config('proframe.request', r.id::text, true);
  insert into public.designs (factory_id, id, customer_id, data, name, category, updated_by)
  values (o.factory_id, v_id, r.customer_id, p_design,
          coalesce(p_design ->> 'name', ''), p_design ->> 'category', o.user_id);
  update public.requests
     set status = 'approved', decided_by = o.user_id, decided_at = now(),
         decision_note = private.clean(p_note, 2000),
         result_design_id = v_id, result_customer_id = r.customer_id,
         result_revision = 1
   where id = r.id
  returning * into r;
  if coalesce(p_assign, false) then
    insert into public.design_assignments (factory_id, design_id, worker_id, assigned_by)
    values (o.factory_id, v_id, r.requested_by, o.user_id)
    on conflict do nothing;
  end if;
  perform private.decided(o, r, 'approved', p_note);
  return query select v_id, r.customer_id;
end $$;

-- Approves a new customer and their first design, both in this one
-- transaction: either both are made, or neither.
create function public.approve_new_customer_request(
  p_request uuid, p_customer jsonb, p_design jsonb, p_assign boolean, p_note text
) returns table (design_id text, customer_id text)
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
  r public.requests := private.to_decide(o, p_request);
  v_customer text := p_customer ->> 'id';
  v_design text := p_design ->> 'id';
begin
  if r.status = 'approved' then
    return query select r.result_design_id, r.result_customer_id; return;
  end if;
  if r.status <> 'pending' then raise exception 'PF:already_decided'; end if;
  if r.kind <> 'new_customer_design' then raise exception 'PF:invalid'; end if;
  if jsonb_typeof(p_customer) is distinct from 'object'
     or jsonb_typeof(p_design) is distinct from 'object'
     or v_customer is null or v_design is null
     or p_design ->> 'customerId' is distinct from v_customer
     or p_design ->> 'category' is distinct from r.payload ->> 'category' then
    raise exception 'PF:invalid';
  end if;
  if exists (select 1 from public.customers c
             where c.factory_id = o.factory_id and c.id = v_customer)
     or exists (select 1 from public.designs d
                where d.factory_id = o.factory_id and d.id = v_design) then
    raise exception 'PF:invalid';
  end if;
  insert into public.customers (factory_id, id, data, name, updated_by)
  values (o.factory_id, v_customer, p_customer,
          coalesce(p_customer ->> 'name', ''), o.user_id);
  perform set_config('proframe.source', 'request', true);
  perform set_config('proframe.request', r.id::text, true);
  insert into public.designs (factory_id, id, customer_id, data, name, category, updated_by)
  values (o.factory_id, v_design, v_customer, p_design,
          coalesce(p_design ->> 'name', ''), p_design ->> 'category', o.user_id);
  update public.requests
     set status = 'approved', decided_by = o.user_id, decided_at = now(),
         decision_note = private.clean(p_note, 2000),
         result_design_id = v_design, result_customer_id = v_customer,
         result_revision = 1
   where id = r.id
  returning * into r;
  if coalesce(p_assign, false) then
    insert into public.design_assignments (factory_id, design_id, worker_id, assigned_by)
    values (o.factory_id, v_design, r.requested_by, o.user_id)
    on conflict do nothing;
  end if;
  perform private.decided(o, r, 'approved', p_note);
  return query select v_design, v_customer;
end $$;

-- What a change request keeps of the design as it is: who it is, whose,
-- what it is called and what it is, what it costs and whether it was
-- completed. Everything else is the proposal.
create function private.kept_keys() returns text[]
language sql immutable as $$
  select array['id', 'name', 'category', 'kind', 'customer', 'customerId',
               'createdAt', 'pricing', 'completedAs']
$$;

-- Approves a proposed change: only if the design is still at the revision
-- the proposal was drawn from, once, with the old version kept in its
-- history. Returns the design as it now is.
create function public.approve_change_request(p_request uuid, p_note text)
returns table (design_id text, revision integer, data jsonb)
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
  r public.requests := private.to_decide(o, p_request);
  d public.designs;
  v_new jsonb;
begin
  if r.status = 'approved' then
    return query select x.id, x.revision, x.data from public.designs x
                  where x.factory_id = o.factory_id and x.id = r.design_id;
    return;
  end if;
  if r.status <> 'pending' then raise exception 'PF:already_decided'; end if;
  if r.kind <> 'design_change' then raise exception 'PF:invalid'; end if;
  select * into d from public.designs x
   where x.factory_id = o.factory_id and x.id = r.design_id for update;
  if not found or d.deleted_at is not null then raise exception 'PF:not_found'; end if;
  if d.revision <> r.base_revision then raise exception 'PF:conflict'; end if;
  v_new := (r.payload -> 'design') - private.kept_keys();
  v_new := v_new || coalesce((
    select jsonb_object_agg(k, d.data -> k)
    from unnest(private.kept_keys()) k where d.data ? k), '{}'::jsonb);
  perform set_config('proframe.source', 'request', true);
  perform set_config('proframe.request', r.id::text, true);
  update public.designs x
     set data = v_new, revision = d.revision + 1, updated_at = now(),
         updated_by = o.user_id
   where x.factory_id = o.factory_id and x.id = d.id;
  update public.requests
     set status = 'approved', decided_by = o.user_id, decided_at = now(),
         decision_note = private.clean(p_note, 2000),
         result_design_id = d.id, result_customer_id = d.customer_id,
         result_revision = d.revision + 1
   where id = r.id
  returning * into r;
  perform private.decided(o, r, 'approved', p_note);
  return query select d.id, d.revision + 1, v_new;
end $$;

create function public.reject_request(p_request uuid, p_note text) returns void
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
  r public.requests := private.to_decide(o, p_request);
begin
  if r.status = 'rejected' then return; end if;
  if r.status <> 'pending' then raise exception 'PF:already_decided'; end if;
  update public.requests
     set status = 'rejected', decided_by = o.user_id, decided_at = now(),
         decision_note = private.clean(p_note, 2000)
   where id = r.id
  returning * into r;
  perform private.decided(o, r, 'rejected', p_note);
end $$;

-- The original of a change request, for the owner to compare against: the
-- design as it was at the revision the proposal was drawn from.
create function public.request_base(p_request uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.accounts := private.owner();
  r public.requests;
begin
  select * into r from public.requests where id = p_request and factory_id = o.factory_id;
  if not found or r.kind <> 'design_change' then raise exception 'PF:not_found'; end if;
  return (select v.data from public.design_revisions v
          where v.factory_id = o.factory_id and v.design_id = r.design_id
            and v.revision = r.base_revision);
end $$;

create function public.mark_notification_read(p_id uuid) returns void
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  me public.accounts := private.me();
begin
  update public.notifications set read_at = coalesce(read_at, now())
   where id = p_id and recipient = me.user_id;
end $$;

-- ------------------------------------------------------ row-level security
--
-- Supabase grants every table in `public` to `anon` and `authenticated`
-- by default. All of that is taken back here, and only `select` is given,
-- on rows the policy allows.

alter table public.factories enable row level security;
alter table public.accounts enable row level security;
alter table public.worker_invites enable row level security;
alter table public.customers enable row level security;
alter table public.designs enable row level security;
alter table public.design_revisions enable row level security;
alter table public.design_assignments enable row level security;
alter table public.requests enable row level security;
alter table public.notifications enable row level security;
alter table public.factory_documents enable row level security;
alter table public.audit_events enable row level security;

revoke all on public.factories, public.accounts, public.worker_invites,
  public.customers, public.designs, public.design_revisions,
  public.design_assignments, public.requests, public.notifications,
  public.factory_documents, public.audit_events
  from anon, authenticated, public;

grant select on public.factories, public.accounts, public.customers,
  public.designs, public.design_revisions, public.design_assignments,
  public.requests, public.notifications, public.factory_documents,
  public.audit_events
  to authenticated;

create policy factory_members on public.factories for select to authenticated
  using (id in (select factory_id from public.accounts
                where user_id = auth.uid() and status = 'active'));

-- An owner sees every account of their factory; anybody sees their own.
create policy accounts_read on public.accounts for select to authenticated
  using (user_id = auth.uid() or factory_id = private.owned_factory());

create policy customers_owner on public.customers for select to authenticated
  using (factory_id = private.owned_factory());

-- Only the owner reads designs directly. Labour reads its assigned designs
-- through `my_assigned_designs` and `assigned_design`, without prices.
create policy designs_owner on public.designs for select to authenticated
  using (factory_id = private.owned_factory());

create policy revisions_owner on public.design_revisions for select to authenticated
  using (factory_id = private.owned_factory());

create policy assignments_read on public.design_assignments for select to authenticated
  using (factory_id = private.owned_factory()
         or (worker_id = auth.uid() and private.active_account()));

create policy requests_read on public.requests for select to authenticated
  using (factory_id = private.owned_factory()
         or (requested_by = auth.uid() and private.active_account()));

create policy notifications_own on public.notifications for select to authenticated
  using (recipient = auth.uid() and private.active_account());

create policy documents_owner on public.factory_documents for select to authenticated
  using (factory_id = private.owned_factory());

create policy audit_owner on public.audit_events for select to authenticated
  using (factory_id = private.owned_factory());

-- The functions in `private` are not reachable through the API; the ones
-- in `public` are callable by a signed-in user, and each checks who.
revoke all on all functions in schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.owned_factory(), private.active_account()
  to authenticated;

revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated;
