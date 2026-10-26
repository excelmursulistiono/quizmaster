-- QUIZMASTER database schema (Supabase / PostgreSQL)
-- Review and test RLS policies before using real student data.
create extension if not exists pgcrypto;
create type public.app_role as enum ('administrator','guru','peserta');
create type public.quiz_status as enum ('draft','published','archived');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role public.app_role not null default 'peserta',
  class_name text,
  created_at timestamptz not null default now()
);
create table public.subjects (
  id uuid primary key default gen_random_uuid(), name text not null unique,
  description text, created_at timestamptz not null default now()
);
create table public.classes (
  id uuid primary key default gen_random_uuid(), name text not null unique,
  grade_level smallint check (grade_level between 7 and 9), created_at timestamptz not null default now()
);
create table public.quizzes (
  id uuid primary key default gen_random_uuid(), creator_id uuid not null references public.profiles(id),
  title text not null, description text default '', subject_id uuid references public.subjects(id),
  class_id uuid references public.classes(id), difficulty text not null default 'Sedang' check (difficulty in ('Mudah','Sedang','Sulit')),
  mode text not null default 'latihan' check (mode in ('latihan','ujian')), duration_seconds integer not null default 900 check(duration_seconds between 60 and 10800),
  passing_score numeric(5,2) not null default 75 check(passing_score between 0 and 100), max_attempts integer not null default 1 check(max_attempts > 0),
  randomize_questions boolean not null default false, randomize_options boolean not null default false,
  opens_at timestamptz, closes_at timestamptz, show_explanations boolean not null default true,
  status public.quiz_status not null default 'draft', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.questions (
  id uuid primary key default gen_random_uuid(), quiz_id uuid references public.quizzes(id) on delete cascade,
  created_by uuid not null references public.profiles(id), subject_id uuid references public.subjects(id),
  class_id uuid references public.classes(id), prompt text not null, question_type text not null default 'single_choice'
    check(question_type in ('single_choice','multiple_choice','true_false','short_answer','fill_blank','matching','image','case_study')),
  options jsonb not null default '[]'::jsonb, answer_key jsonb not null default '{}'::jsonb,
  explanation text, image_path text, points numeric(7,2) not null default 1 check(points >= 0), difficulty text default 'Sedang', created_at timestamptz not null default now()
);
create table public.quiz_questions (
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  position integer not null default 0, points numeric(7,2) not null default 1 check(points >= 0),
  primary key(quiz_id,question_id)
);
create table public.quiz_attempts (
  id uuid primary key default gen_random_uuid(), quiz_id uuid not null references public.quizzes(id),
  participant_id uuid not null references public.profiles(id), attempt_no integer not null default 1,
  started_at timestamptz not null default now(), deadline_at timestamptz not null,
  submitted_at timestamptz, status text not null default 'in_progress' check(status in ('in_progress','submitted','expired','graded')),
  score numeric(5,2), correct_count integer, wrong_count integer, unanswered_count integer,
  created_at timestamptz not null default now(), unique(quiz_id,participant_id,attempt_no)
);
create table public.attempt_answers (
  id uuid primary key default gen_random_uuid(), attempt_id uuid not null references public.quiz_attempts(id) on delete cascade,
  question_id uuid not null references public.questions(id), answer jsonb, is_correct boolean,
  points_awarded numeric(7,2) not null default 0, flagged_for_review boolean not null default false,
  saved_at timestamptz not null default now(), unique(attempt_id,question_id)
);
create table public.audit_events (
  id bigint generated always as identity primary key, actor_id uuid references public.profiles(id),
  event_type text not null, quiz_id uuid references public.quizzes(id), details jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index quizzes_status_idx on public.quizzes(status,created_at desc);
create index questions_quiz_idx on public.questions(quiz_id);
create index attempts_participant_idx on public.quiz_attempts(participant_id,created_at desc);
create index attempts_quiz_idx on public.quiz_attempts(quiz_id,created_at desc);
create index answers_attempt_idx on public.attempt_answers(attempt_id);

-- Create a profile automatically for new Auth users. Role defaults to peserta;
-- privileged roles should be assigned by a trusted administrator, never from public signup metadata.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id,full_name,role)
  values(new.id, coalesce(new.raw_user_meta_data->>'full_name',''), 'peserta')
  on conflict (id) do nothing;
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.current_role() returns public.app_role language sql stable security definer set search_path = '' as $$
  select role from public.profiles where id = auth.uid();
$$;
create or replace function public.is_staff() returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(public.current_role() in ('administrator','guru'),false);
$$;

alter table public.profiles enable row level security;
alter table public.subjects enable row level security;
alter table public.classes enable row level security;
alter table public.quizzes enable row level security;
alter table public.questions enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.quiz_attempts enable row level security;
alter table public.attempt_answers enable row level security;
alter table public.audit_events enable row level security;

create policy "Profiles: user reads self, staff reads all" on public.profiles for select to authenticated using (id=auth.uid() or public.is_staff());
create policy "Profiles: user updates limited self profile" on public.profiles for update to authenticated using (id=auth.uid()) with check (id=auth.uid() and role=(select p.role from public.profiles p where p.id=auth.uid()));
create policy "Subjects readable by signed in users" on public.subjects for select to authenticated using (true);
create policy "Staff manage subjects" on public.subjects for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "Classes readable by signed in users" on public.classes for select to authenticated using (true);
create policy "Staff manage classes" on public.classes for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "Published quizzes readable, staff sees own or all" on public.quizzes for select to authenticated using (status='published' or public.current_role()='administrator' or creator_id=auth.uid());
create policy "Staff create quizzes" on public.quizzes for insert to authenticated with check (public.is_staff() and (creator_id=auth.uid() or public.current_role()='administrator'));
create policy "Creator or admin updates quizzes" on public.quizzes for update to authenticated using (creator_id=auth.uid() or public.current_role()='administrator') with check (creator_id=auth.uid() or public.current_role()='administrator');
create policy "Creator or admin deletes quizzes" on public.quizzes for delete to authenticated using (creator_id=auth.uid() or public.current_role()='administrator');
-- Answer keys are stored on questions: direct reads are restricted to staff/creator.
create policy "Staff reads question bank" on public.questions for select to authenticated using (public.is_staff() and (created_by=auth.uid() or public.current_role()='administrator'));
create policy "Staff manages question bank" on public.questions for all to authenticated using (public.is_staff() and (created_by=auth.uid() or public.current_role()='administrator')) with check (public.is_staff() and (created_by=auth.uid() or public.current_role()='administrator'));
create policy "Staff reads quiz question mapping" on public.quiz_questions for select to authenticated using (public.is_staff());
create policy "Staff manages quiz question mapping" on public.quiz_questions for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "Participant reads own attempts, staff reads relevant attempts" on public.quiz_attempts for select to authenticated using (participant_id=auth.uid() or public.current_role()='administrator' or exists(select 1 from public.quizzes q where q.id=quiz_id and q.creator_id=auth.uid()));
create policy "Participant starts own attempts" on public.quiz_attempts for insert to authenticated with check (participant_id=auth.uid() and status='in_progress');
create policy "Participant updates own in-progress attempt" on public.quiz_attempts for update to authenticated using (participant_id=auth.uid() and status='in_progress') with check (participant_id=auth.uid());
create policy "Participant or staff reads attempt answers" on public.attempt_answers for select to authenticated using (exists(select 1 from public.quiz_attempts a where a.id=attempt_id and (a.participant_id=auth.uid() or public.current_role()='administrator' or exists(select 1 from public.quizzes q where q.id=a.quiz_id and q.creator_id=auth.uid()))));
create policy "Participant saves answers to own active attempt" on public.attempt_answers for insert to authenticated with check (exists(select 1 from public.quiz_attempts a where a.id=attempt_id and a.participant_id=auth.uid() and a.status='in_progress' and now()<a.deadline_at));
create policy "Participant updates answers to own active attempt" on public.attempt_answers for update to authenticated using (exists(select 1 from public.quiz_attempts a where a.id=attempt_id and a.participant_id=auth.uid() and a.status='in_progress' and now()<a.deadline_at)) with check (exists(select 1 from public.quiz_attempts a where a.id=attempt_id and a.participant_id=auth.uid() and a.status='in_progress' and now()<a.deadline_at));
create policy "Staff reads audit events" on public.audit_events for select to authenticated using (public.is_staff());

-- IMPORTANT: This schema is a foundation, not a completed secure exam engine.
-- Do not expose answer_key to participant-facing queries. Implement grading, deadline enforcement,
-- attempt finalization, role assignment, and idempotency in trusted Edge Functions/RPC before production.
