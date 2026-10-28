# Phase 36 audit — accounts, access and approvals

Written before any Phase 36 code, from the repository as it stood at
`f20efa1`. What the application was, what that means for real accounts, and
the architecture chosen.

## What there is today

| Area | Today |
| --- | --- |
| Entry | `main.dart` reads the language, `ProFrameApp` opens `LaunchScreen`, which replaces itself with `CustomersScreen`. No URL routes: every screen is a `Navigator.push`. |
| Persistence | Every record is in `SharedPreferences` (the browser's `localStorage` on the web): `CustomerStore`, `DesignStore`, `PriceListStore`, `PriceRecordStore`, `QuotationStore`, `ExtraCatalogStore`, `MeasurementDefaultsStore`, `StaffStore`, `OwnerAccessStore`. Each record is a key; indexes are derived lines kept beside them. |
| Identifiers | Designs `design-<micros>`, customers `customer-<micros>-<n>`, staff `staff-…`, transactions `PAY-…`/`REF-…`, receipts `RCP-000001`, quotations `Q-000001`. All made on the device. |
| Who is at the device | `actorProvider` (`lib/app/state/access.dart`): the owner by a PIN (salted SHA-256 in `proframe.owner-pin.v1`), a member of staff by their own PIN (`StaffStore`), or nobody. `Capability` / `Authority` (`pricing_access.dart`) are checked in the stores (`by:` / `readsAs:`), and the workspace refuses edits from anybody without `designs.edit` (`WorkspaceController.state` setter). |
| What that is | A lock on a device. Everything — the PINs, the role, the capabilities, the records — is in storage the person at the device controls. Clearing it, or editing it in the browser's developer tools, gives anybody everything. The code says so (`pricing_access.dart`). |
| Platform | A static Flutter web build on Vercel (`vercel-build.sh`, `vercel.json`). There is no server of any kind and no secret. Android and iOS folders exist, unbuilt. |
| Completion and pricing | `PriceReadiness` is the one answer to "finished"; `DesignCompletion` fingerprints a completed design; a price is current only for `PriceInputs`. All local. |
| Money records | Payments, refunds, receipts, discounts and the job's extras are on the customer record; quotations under their own keys. Nothing is ever edited or deleted. |
| Language and theme | English and Central Kurdish from ARB files; two separate controls on the customers' header. |
| Tests | ~240 test files, run with `flutter test`; storage is in memory (`test/flutter_test_config.dart`). |

## What that means for Phase 36

Nothing in the application can be made secure on its own. Every check it
has runs in code the user controls, against data the user controls — the
"fake security" the brief lists, in every form. Real accounts need three
things the repository did not have:

1. **Somebody else to hold the password.** An identity provider that keeps
   credentials hashed, issues signed sessions, confirms email addresses and
   resets passwords.
2. **Somebody else to hold the records.** A database the browser cannot
   write to directly, which decides on every read and write who may do it,
   from the signed session and its own tables — never from anything the
   client sends.
3. **Atomic rules there.** The three-worker limit, "exactly once" approval,
   revision conflicts and tenant isolation can only be kept by the database
   itself, in a transaction, with the rows locked.

## The architecture chosen

**Supabase**: its Auth service (GoTrue) for 1, Postgres with row-level
security and `SECURITY DEFINER` functions for 2 and 3.

- **The database is the authority.** `supabase/migrations/` holds the whole
  schema: factories, accounts, invitations, customers, designs, design
  revisions, assignments, requests, notifications and owner-only factory
  documents. Every table has row-level security on and no client grant
  beyond `select` where a role may read; every write goes through a
  function that reads the caller from `auth.uid()` and the caller's role
  and factory from `accounts` — a table no client can write.
- **Roles are assigned by the database.** A sign-up with no invitation
  makes a factory and its owner; a sign-up with an invitation code makes a
  labour account in the inviting factory, if the code is valid, unused,
  unexpired, for that email address, and a seat is free. What the client
  sends as its role is never read.
- **The limit is a lock.** Inviting and reactivating lock the factory's row
  and count active labour accounts and open invitations together, so two
  invitations at once cannot both take the last seat.
- **Approval is one transaction.** Approving a request locks it, checks it
  is still pending and the caller owns its factory and did not make it,
  writes the customer and design (or the change, against the revision it
  was based on), records the decision, the history and the notification,
  and returns the same answer if called again.
- **The application is a client of it.** Signed in, its local stores are a
  cache of what the server gave this account, cleared on sign-out. An
  owner's edits are pushed through the owner's functions with the revision
  they were based on; a labour account has nothing to push — its device
  can write anything into its own cache and none of it reaches the
  database.
- **Local mode stays.** Built without the backend's address the application
  is exactly what it was, on one device, and says so. Nothing is uploaded
  without the owner signing in and choosing to.

## What cannot be done from here, stated

- **No Supabase project exists for ProFrame and none can be made from this
  environment**: supabase.com is not reachable from it, and there are no
  credentials. The migration, the functions and every rule are written and
  tested against a real PostgreSQL 16 with a stand-in for the `auth`
  schema (`test/backend/`), but nothing has run against Supabase itself.
  The deployed site stays in local mode until the owner creates the
  project, applies the migration and gives the build its address — see
  `docs/accounts_and_backend.md`.
- **No HTTP end-to-end test.** The services Supabase runs in front of
  Postgres (GoTrue, PostgREST) cannot be downloaded here, so the
  application's client is tested against an in-memory stand-in with the
  same contract, and the contract itself is tested in SQL.
- **Geometry is validated by the owner's application, not the database.**
  The canonical geometry is Dart. On approval the owner's application
  reads the proposal through it and refuses one it cannot read; the
  database enforces who, which factory, which revision, and once.
