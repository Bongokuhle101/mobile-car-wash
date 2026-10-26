-- ShineGo Car Wash database schema
create type booking_status as enum (
  'pending_payment','confirmed','assigned','en_route','washing','completed','cancelled'
);

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text unique not null,
  role text not null default 'customer',
  created_at timestamptz default now()
);

create table vehicles (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references profiles(id) on delete cascade,
  vehicle_type text not null,
  license_plate text not null,
  colour text,
  created_at timestamptz default now()
);

create table services (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  price_cents int not null,
  duration_minutes int not null,
  is_active boolean default true
);

create table washers (
  id uuid primary key references profiles(id),
  is_available boolean default true,
  current_latitude numeric,
  current_longitude numeric
);

create table bookings (
  id uuid primary key default gen_random_uuid(),
  reference text unique,
  customer_id uuid not null references profiles(id),
  vehicle_id uuid not null references vehicles(id),
  service_id uuid not null references services(id),
  washer_id uuid references washers(id),
  vehicle_class text not null default 'suv_4x4',
  total_price_zar integer not null default 0,
  booking_date date not null,
  start_time time not null,
  end_time time not null,
  status booking_status not null default 'pending_payment',
  address text not null,
  latitude numeric,
  longitude numeric,
  notes text,
  payment_provider text,
  payment_reference text,
  created_at timestamptz default now()
);

create table booking_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references bookings(id) on delete cascade,
  status booking_status not null,
  created_at timestamptz default now()
);

create or replace function set_booking_reference()
returns trigger as $$
begin
  new.reference := 'SG-' || upper(substr(replace(new.id::text, '-', ''), 1, 8));
  return new;
end;
$$ language plpgsql;

create trigger booking_reference_trigger
before insert on bookings
for each row execute function set_booking_reference();

create or replace function is_slot_available(
  p_date date, p_start time, p_end time, p_washer uuid
)
returns boolean as $$
  select not exists (
    select 1 from bookings
    where booking_date = p_date
      and washer_id = p_washer
      and status in ('confirmed','assigned','en_route','washing')
      and (p_start, p_end) overlaps (start_time, end_time)
  );
$$ language sql;

-- Seed services
insert into services (name, description, price_cents, duration_minutes) values
('Basic Wash','Exterior wash, wheels and dry',12000,45),
('Standard Wash','Exterior wash, interior vacuum and windows',22000,60),
('Premium Detail','Full interior and exterior detailing',45000,120),
('Wax & Polish','Hand wax, polish and tyre shine',35000,90)
on conflict do nothing;

-- RLS
alter table profiles enable row level security;
alter table vehicles enable row level security;
alter table bookings enable row level security;
alter table booking_events enable row level security;

create policy "read own profile" on profiles for select to authenticated using (auth.uid() = id);
create policy "update own profile" on profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
create policy "manage own vehicles" on vehicles for all to authenticated using (auth.uid() = customer_id) with check (auth.uid() = customer_id);
create policy "read own bookings" on bookings for select to authenticated using (auth.uid() = customer_id);
create policy "create own bookings" on bookings for insert to authenticated with check (auth.uid() = customer_id);
create policy "cancel own bookings" on bookings for update to authenticated using (auth.uid() = customer_id) with check (auth.uid() = customer_id);
create policy "read own booking events" on booking_events for select to authenticated using (booking_id in (select id from bookings where customer_id = auth.uid()));

create or replace function create_profile()
returns trigger as $$
begin
  insert into profiles (id, full_name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name','New customer'),
    coalesce(new.phone,new.raw_user_meta_data->>'phone','')
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function create_profile();