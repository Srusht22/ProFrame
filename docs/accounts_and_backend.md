# Accounts and the backend — setting it up

Phase 36 gives ProFrame real accounts: an owner who signs up, up to three
workers they invite, design access, and requests the owner approves. The
rules are kept by a database, not by the application. This page is what has
to be done, once, to switch that on — none of it could be done from the
environment the code was written in (see *What was not possible here*).

Until it is done, the deployed site runs exactly as before: on one device,
with no accounts, and it says nothing about signing in.

## 1. Create the backend

1. Create a project at [supabase.com](https://supabase.com) (any region; the
   free plan is enough to start).
2. In **SQL Editor**, run the whole of
   `supabase/migrations/20261013000000_accounts_and_approvals.sql`, as it is.
   Or, with the Supabase CLI: `supabase link` and `supabase db push`.
   It creates the tables, row-level security, the functions every write goes
   through, and the trigger that gives every new user their account.
3. In **Authentication → Providers → Email**: email sign-in on, **Confirm
   email** on (an owner's and a worker's address is then proved before they
   can sign in).
4. In **Authentication → URL Configuration**: set **Site URL** to the
   deployed address (for example `https://proframe.vercel.app`) and add it to
   **Redirect URLs**. The confirmation and password-reset links come back
   there; the application reads the session from the link.
5. Optional, recommended: **Authentication → Rate limits** as you like, and
   a custom SMTP sender so the emails come from the workshop's own address.

Do not add any other policy or grant. Supabase gives `anon` and
`authenticated` every privilege on new tables by default; the migration takes
all of that back and gives only `select` where row-level security allows it.

## 2. Give the build the backend's address

In **Project Settings → API**, copy the **Project URL** and the **anon
public** key. The anon key is public by design — it identifies the project
and allows nothing row-level security does not. **Never use the
`service_role` key in the application.**

In the Vercel project: **Settings → Environment Variables**:

| Name | Value |
| --- | --- |
| `PROFRAME_SUPABASE_URL` | the Project URL |
| `PROFRAME_SUPABASE_ANON_KEY` | the anon public key |

Redeploy. `vercel-build.sh` passes both to `flutter build web` as
`--dart-define`s; without them it builds as before. Locally:

```
flutter run -d chrome \
  --dart-define=PROFRAME_SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=PROFRAME_SUPABASE_ANON_KEY=ey...
```

## 3. The first owner

The first person to open the deployed site signs up with **Create an owner
account**. The database makes them a factory and the owner role — a role is
never sent by the application. If their device already holds customers and
designs from before (the browser they used ProFrame in), they are asked
whether to **bring them into the factory** or **keep them aside on the
device**. Nothing is deleted either way, and nothing is uploaded without that
answer. A worker signing in on such a device has it moved aside, never
uploaded.

Each browser is its own device. Records kept in another browser are not
seen, merged or uploaded by this one: an owner who wants them signs in there
and brings them in from there — into a factory that is then theirs.

## 4. Workers

The owner opens **Workers** from the account menu and invites by name and
email. The database holds one of the three places and returns a one-time
code, shown once. The owner gives it to the worker however they like; it is
useless without the matching email address, works once and lapses after
seven days. The worker chooses **Join with an invitation**, sets their own
password, confirms their address, and signs in.

A new worker sees no designs. The owner gives them designs on the worker's
page (**Manage access**), and can take them away. Suspending a worker stops
everything they can do at once — every function and policy asks for an
active account — and deletes nothing.

## What each role may do

| | Owner | Worker |
| --- | --- | --- |
| Customers, designs, drawing, sizes | everything, as before | look at assigned designs only |
| Prices, payments, refunds, receipts, discounts, quotations, extras | everything, as before | nothing, and nothing is shown |
| Factory prices and defaults | yes | refused |
| Workers, assignments, approvals | yes | refused |
| Requests | decides them | makes them: a new design for one of their customers, a new customer and design, a change to an assigned design |

Every financial action stays the owner's. A worker never sees what a design
costs: the database gives them a design without its prices.

## What was not possible here

- **No Supabase project, and none reachable.** supabase.com could not be
  reached from the environment this was written in, and there were no
  credentials. Everything above is for the owner to do.
- **The database rules are tested against real PostgreSQL** (16), with a
  stand-in for the parts of Supabase the migration uses — the `auth.users`
  table, `auth.uid()`, the `anon` / `authenticated` roles and their default
  privileges: `test/backend/backend_security_test.dart`, 44 tests. They skip,
  saying why, where PostgreSQL is not installed.
- **The Auth service and the REST API themselves were not run.** Their
  downloads were blocked. The application's client
  (`lib/infrastructure/cloud/supabase_backend.dart`) follows their documented
  endpoints and is tested only through an in-memory stand-in with the same
  contract. The first real sign-up is its first end-to-end test.
- **Suspension is enforced on data, not on the sign-in itself.** A suspended
  worker's password still opens a session at the Auth service; every call it
  can make is then refused, and the application signs it out and says so.
  Blocking the sign-in too needs Supabase's admin API (a server function with
  the service key), which is not part of this.
- **The geometry of a proposed change is checked by the owner's
  application**, which is the only place the canonical geometry is. The
  database checks who, which factory, which revision, and once.
