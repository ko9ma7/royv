-- 1) Supabase SQL Editor에서 이 파일을 1회 실행하세요.
create extension if not exists pgcrypto;

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  source_key text not null unique,
  sort_order integer not null default 0,
  no_text text, process text, item text not null, spec text, unit text, qty numeric, vendor text,
  primary_action text, action_tags jsonb not null default '[]'::jsonb, source_data jsonb not null default '{}'::jsonb,
  status text not null default 'not_started' check (status in ('not_started','in_progress','review','blocked','completed')),
  progress integer not null default 0 check (progress between 0 and 100),
  owner text, department text, due_date date, priority text not null default 'normal' check(priority in ('low','normal','high','critical')),
  work_note text, memo_count integer not null default 0,
  updated_by uuid references auth.users(id), updated_by_email text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists idx_tasks_status on public.tasks(status);
create index if not exists idx_tasks_owner on public.tasks(owner);
create index if not exists idx_tasks_process on public.tasks(process);

create table if not exists public.task_notes (
  id uuid primary key default gen_random_uuid(), task_source_key text not null references public.tasks(source_key) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000), author_id uuid not null references auth.users(id), author_email text, created_at timestamptz not null default now()
);
create index if not exists idx_task_notes_task on public.task_notes(task_source_key,created_at desc);

create table if not exists public.activity_logs (
  id bigint generated always as identity primary key, action text not null, task_source_key text, task_name text, actor_id uuid, actor_email text, before_data jsonb, after_data jsonb, created_at timestamptz not null default now()
);
create index if not exists idx_activity_logs_created on public.activity_logs(created_at desc);

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;
drop trigger if exists trg_tasks_updated_at on public.tasks;
create trigger trg_tasks_updated_at before update on public.tasks for each row execute function public.set_updated_at();

create or replace function public.log_task_update() returns trigger language plpgsql security definer set search_path=public as $$
begin
 -- 메모 개수 증가처럼 사용자 업무값이 바뀌지 않은 내부 업데이트는 별도 업무수정 로그를 만들지 않음
 if (to_jsonb(old) - 'memo_count' - 'updated_at') = (to_jsonb(new) - 'memo_count' - 'updated_at') then
   return new;
 end if;
 insert into public.activity_logs(action,task_source_key,task_name,actor_id,actor_email,before_data,after_data)
 values('task_update',new.source_key,new.item,new.updated_by,new.updated_by_email,to_jsonb(old)-'source_data',to_jsonb(new)-'source_data');
 return new;
end $$;
drop trigger if exists trg_log_task_update on public.tasks;
create trigger trg_log_task_update after update on public.tasks for each row execute function public.log_task_update();

create or replace function public.log_note_insert() returns trigger language plpgsql security definer set search_path=public as $$
declare tname text; begin
 select item into tname from public.tasks where source_key=new.task_source_key;
 insert into public.activity_logs(action,task_source_key,task_name,actor_id,actor_email,after_data) values('note_add',new.task_source_key,tname,new.author_id,new.author_email,jsonb_build_object('body',new.body));
 update public.tasks set memo_count=memo_count+1 where source_key=new.task_source_key; return new; end $$;
drop trigger if exists trg_log_note_insert on public.task_notes;
create trigger trg_log_note_insert after insert on public.task_notes for each row execute function public.log_note_insert();

alter table public.tasks enable row level security; alter table public.task_notes enable row level security; alter table public.activity_logs enable row level security;
-- 로그인 사용자라면 전체 조회/업데이트 가능. 필요 시 이메일 도메인/역할별 정책으로 더 좁히세요.
drop policy if exists "tasks read authenticated" on public.tasks; create policy "tasks read authenticated" on public.tasks for select to authenticated using (true);
drop policy if exists "tasks update authenticated" on public.tasks; create policy "tasks update authenticated" on public.tasks for update to authenticated using (true) with check (updated_by=(select auth.uid()));
drop policy if exists "notes read authenticated" on public.task_notes; create policy "notes read authenticated" on public.task_notes for select to authenticated using (true);
drop policy if exists "notes insert authenticated" on public.task_notes; create policy "notes insert authenticated" on public.task_notes for insert to authenticated with check (author_id=(select auth.uid()));
drop policy if exists "logs read authenticated" on public.activity_logs; create policy "logs read authenticated" on public.activity_logs for select to authenticated using (true);

-- Realtime: 이 소규모 현장 협업 시스템은 Postgres Changes가 가장 단순합니다.
do $$ begin
  alter publication supabase_realtime add table public.tasks;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.task_notes;
exception when duplicate_object then null; end $$;
