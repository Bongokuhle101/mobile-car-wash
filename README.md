ShineGo Car Wash
Mobile-first car wash booking website with Supabase authentication/database, Yoco payments, Twilio WhatsApp reminders, availability checking, and an admin dashboard.

Project structure
components/ contains reusable landing-page UI and vehicle-class illustrations.
data/ contains service, vehicle-class, and editable site content.
lib/ contains server-side booking storage and authentication helpers.
pages/ contains Next.js pages and API routes.
public/images/vehicles/ contains locally served vehicle photography and its license credits.
styles/ contains global and reusable component styles.

Setup
Create a Supabase project.

Run supabase/schema.sql in the Supabase SQL Editor.

Copy env.example to .env.local and set the values. Use unique random secrets for ADMIN_PASSWORD, ADMIN_SESSION_SECRET, and CRON_SECRET; never reuse or commit credentials.

Install dependencies:

bash
npm install
npm run dev

The app runs locally with a file-backed booking fallback when Supabase is not configured.
Open http://localhost:3000 to use the booking flow and http://localhost:3000/admin to access the protected dashboard.

Admin security
Use the generated local ADMIN_PASSWORD from `.env.local` to sign in at `/admin/login`. The offline recovery code is configured as `ADMIN_RECOVERY_CODE` in the same file. Keep a separate copy in a password manager. At `/admin/forgot-password`, enter the code to reset the admin password; a replacement recovery code is displayed once and invalidates the previous one. Reset passwords are stored as salted hashes in the ignored `data/admin-auth-state.json` file and all existing admin sessions are invalidated. Do not share or commit `.env.local` or the recovery-state file.

Password recovery requires a persistent writable application filesystem. For serverless or multi-instance production deployments, change `ADMIN_PASSWORD` through the deployment secret manager instead and use shared persistent storage before enabling UI-based recovery. If the recovery code is lost on a local install, stop the app, remove `data/admin-auth-state.json`, restore `ADMIN_PASSWORD` and `ADMIN_RECOVERY_CODE` in `.env.local`, then restart. To rotate the admin password manually, update `ADMIN_PASSWORD`, remove `data/admin-auth-state.json`, and restart.

The admin dashboard requires sign-in. Its session cookie is HttpOnly, SameSite=Strict, and expires after eight hours. Booking data access requires an admin session. The reminders endpoint requires an Authorization: Bearer <CRON_SECRET> header. Login throttling is in-memory; production deployments with multiple instances should also enforce rate limiting at the hosting provider.

For production, use HTTPS, rotate credentials if they were shared, and replace the local JSON booking fallback with a persistent database.

Vehicle imagery
The home hero uses a three-vehicle fleet collage. Basic Wash is illustrated with a Toyota Yaris, Standard Wash with a Chery Tiggo 8, and Premium Detail with a Mercedes-Benz S-Class. Image sources and CC BY-SA 4.0 attribution are documented in public/images/vehicles/ATTRIBUTION.md.

The service cards use a compact car for Basic Wash, a Chery Tiggo 8 for Standard Wash, and a Mercedes-Benz S-Class for Premium Detail. Photos are darkened for the premium visual treatment, and visible license plates are covered. Vehicle-class photos and their licenses are documented in `public/images/vehicles/classes/ATTRIBUTION.md`.

Booking prices use the listed service price for a hatchback/compact vehicle. Other vehicle classes use these multipliers: sedan 1.15x, SUV/4x4 1.3x, bakkie 1.35x, panel van 1.45x, and minibus 1.5x. Final totals round to the nearest R10 and are recalculated by the server. The booking form shows the prices for all vehicle classes for the selected service.

Bookings store `vehicle_class` and `total_price_zar`. For an existing Supabase database, apply `alter table bookings add column if not exists vehicle_class text not null default 'suv_4x4'; alter table bookings add column if not exists total_price_zar integer not null default 0;` before deploying this change.

Add a washer in Supabase:

sql
insert into washers (id, is_available)
values ('your-auth-user-uuid', true);
Configure the Yoco webhook URL:

text
https://your-domain.com/api/webhooks/yoco
Schedule this endpoint every 15 minutes for reminders, passing CRON_SECRET in the Authorization header:

text
https://your-domain.com/api/cron/reminders
Security notes
Never expose SUPABASE_SERVICE_ROLE_KEY, YOCO_SECRET_KEY, or Twilio credentials to the browser.

Verify all payment webhooks before changing booking status.

Use HTTPS in production.
