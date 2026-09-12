alter table public.swap_requests
add column if not exists status text not null default 'pending';

update public.swap_requests
set status = 'success'
where status is null;

alter table public.swap_requests
drop constraint if exists swap_requests_status_check;

alter table public.swap_requests
add constraint swap_requests_status_check
check (status in ('pending', 'success', 'failed'));
