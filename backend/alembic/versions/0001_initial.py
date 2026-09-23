# alembic/versions/0001_initial.py
from collections.abc import Sequence
from alembic import op

revision: str = "0001_initial"
down_revision: str | None = None
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    op.execute(
        "DO $$ BEGIN "
        "IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'auth_provider') THEN "
        "CREATE TYPE auth_provider AS ENUM ('password', 'google'); "
        "END IF; END $$"
    )
    op.execute(
        "DO $$ BEGIN "
        "IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'project_status') THEN "
        "CREATE TYPE project_status AS ENUM ('active', 'on_hold', 'completed', 'archived'); "
        "END IF; END $$"
    )
    op.execute(
        "DO $$ BEGIN "
        "IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_status') THEN "
        "CREATE TYPE task_status AS ENUM ('todo', 'in_progress', 'done', 'archived'); "
        "END IF; END $$"
    )
    op.execute(
        "DO $$ BEGIN "
        "IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_priority') THEN "
        "CREATE TYPE task_priority AS ENUM ('low', 'medium', 'high', 'urgent'); "
        "END IF; END $$"
    )
    op.execute(
        "DO $$ BEGIN "
        "IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'goal_status') THEN "
        "CREATE TYPE goal_status AS ENUM ('active', 'achieved', 'abandoned'); "
        "END IF; END $$"
    )
    op.execute(
        "DO $$ BEGIN "
        "IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'habit_frequency') THEN "
        "CREATE TYPE habit_frequency AS ENUM ('daily', 'weekly', 'custom'); "
        "END IF; END $$"
    )
    op.execute(
        "DO $$ BEGIN "
        "IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'device_connection_platform') THEN "
        "CREATE TYPE device_connection_platform AS ENUM "
        "('apple_health', 'google_health_connect', 'fitbit', 'garmin', 'other'); "
        "END IF; END $$"
    )
    op.execute(
        "DO $$ BEGIN "
        "IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'device_connection_status') THEN "
        "CREATE TYPE device_connection_status AS ENUM ('connected', 'disconnected', 'error'); "
        "END IF; END $$"
    )
    op.execute(
        "DO $$ BEGIN "
        "IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_channel') THEN "
        "CREATE TYPE notification_channel AS ENUM ('in_app', 'push', 'email'); "
        "END IF; END $$"
    )

    op.execute(
        "CREATE TABLE IF NOT EXISTS users ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "email TEXT NOT NULL, "
        "hashed_password TEXT, "
        "name TEXT NOT NULL, "
        "avatar_url TEXT, "
        "avatar_public_id TEXT, "
        "timezone TEXT NOT NULL DEFAULT 'UTC', "
        "auth_provider auth_provider NOT NULL DEFAULT 'password', "
        "google_user_id TEXT, "
        "is_email_verified BOOLEAN NOT NULL DEFAULT false"
        ")"
    )
    op.execute("CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email ON users (email)")
    op.execute("CREATE UNIQUE INDEX IF NOT EXISTS ix_users_google_user_id ON users (google_user_id)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS google_connections ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE, "
        "google_account_email TEXT NOT NULL, "
        "access_token TEXT NOT NULL, "
        "refresh_token TEXT NOT NULL, "
        "scope TEXT NOT NULL, "
        "token_expires_at TIMESTAMPTZ NOT NULL"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_google_connections_user_id ON google_connections (user_id)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS folders ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "parent_folder_id UUID REFERENCES folders(id) ON DELETE SET NULL, "
        "name TEXT NOT NULL"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_folders_user_id ON folders (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_folders_parent_folder_id ON folders (parent_folder_id)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS notes ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "folder_id UUID REFERENCES folders(id) ON DELETE SET NULL, "
        "title TEXT NOT NULL, "
        "content TEXT NOT NULL, "
        "is_pinned BOOLEAN NOT NULL DEFAULT false, "
        "last_accessed_at TIMESTAMPTZ"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_notes_user_id ON notes (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_notes_folder_id ON notes (folder_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_notes_last_accessed_at ON notes (last_accessed_at)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_notes_user_id_folder_id ON notes (user_id, folder_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_notes_title_trgm ON notes USING gin (title gin_trgm_ops)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS note_versions ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE, "
        "content TEXT NOT NULL"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_note_versions_note_id ON note_versions (note_id)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS note_links ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "from_note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE, "
        "to_note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE, "
        "CONSTRAINT uq_note_links_from_note_id UNIQUE (from_note_id, to_note_id)"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_note_links_from_note_id ON note_links (from_note_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_note_links_to_note_id ON note_links (to_note_id)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS quick_captures ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "raw_text TEXT NOT NULL, "
        "is_processed BOOLEAN NOT NULL DEFAULT false"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_quick_captures_user_id ON quick_captures (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_quick_captures_is_processed ON quick_captures (is_processed)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS clients ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "name TEXT NOT NULL, "
        "email TEXT, "
        "phone TEXT, "
        "notes TEXT"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_clients_user_id ON clients (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_clients_name_trgm ON clients USING gin (name gin_trgm_ops)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS project_templates ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "name TEXT NOT NULL, "
        "blueprint JSONB NOT NULL"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_project_templates_user_id ON project_templates (user_id)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS projects ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "client_id UUID REFERENCES clients(id) ON DELETE SET NULL, "
        "name TEXT NOT NULL, "
        "description TEXT, "
        "status project_status NOT NULL DEFAULT 'active', "
        "cover_image_url TEXT, "
        "cover_image_public_id TEXT, "
        "start_date DATE, "
        "due_date DATE"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_projects_user_id ON projects (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_projects_client_id ON projects (client_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_projects_status ON projects (status)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_projects_due_date ON projects (due_date)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_projects_user_id_status ON projects (user_id, status)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_projects_name_trgm ON projects USING gin (name gin_trgm_ops)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS milestones ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE, "
        "title TEXT NOT NULL, "
        "due_date DATE, "
        "is_completed BOOLEAN NOT NULL DEFAULT false, "
        "completed_at TIMESTAMPTZ"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_milestones_project_id ON milestones (project_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_milestones_due_date ON milestones (due_date)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_milestones_is_completed ON milestones (is_completed)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS tasks ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "project_id UUID REFERENCES projects(id) ON DELETE CASCADE, "
        "milestone_id UUID REFERENCES milestones(id) ON DELETE SET NULL, "
        "parent_task_id UUID REFERENCES tasks(id) ON DELETE CASCADE, "
        "title TEXT NOT NULL, "
        "description TEXT, "
        "status task_status NOT NULL DEFAULT 'todo', "
        "priority task_priority NOT NULL DEFAULT 'medium', "
        "due_date TIMESTAMPTZ, "
        "completed_at TIMESTAMPTZ, "
        "position INTEGER NOT NULL DEFAULT 0"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_tasks_user_id ON tasks (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_tasks_project_id ON tasks (project_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_tasks_milestone_id ON tasks (milestone_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_tasks_parent_task_id ON tasks (parent_task_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_tasks_status ON tasks (status)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_tasks_priority ON tasks (priority)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_tasks_due_date ON tasks (due_date)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_tasks_user_id_status ON tasks (user_id, status)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_tasks_user_id_due_date ON tasks (user_id, due_date)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_tasks_project_id_status ON tasks (project_id, status)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_tasks_title_trgm ON tasks USING gin (title gin_trgm_ops)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS dependencies ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE, "
        "depends_on_task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE, "
        "CONSTRAINT uq_dependencies_task_id UNIQUE (task_id, depends_on_task_id), "
        "CONSTRAINT task_not_self_dependent CHECK (task_id != depends_on_task_id)"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_dependencies_task_id ON dependencies (task_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_dependencies_depends_on_task_id ON dependencies (depends_on_task_id)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS focus_sessions ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "task_id UUID REFERENCES tasks(id) ON DELETE SET NULL, "
        "project_id UUID REFERENCES projects(id) ON DELETE SET NULL, "
        "start_at TIMESTAMPTZ NOT NULL, "
        "end_at TIMESTAMPTZ, "
        "duration_seconds INTEGER"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_focus_sessions_user_id ON focus_sessions (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_focus_sessions_task_id ON focus_sessions (task_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_focus_sessions_project_id ON focus_sessions (project_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_focus_sessions_start_at ON focus_sessions (start_at)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS activity_log_entries ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE, "
        "action TEXT NOT NULL, "
        "entry_metadata JSONB"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_activity_log_entries_user_id ON activity_log_entries (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_activity_log_entries_project_id ON activity_log_entries (project_id)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS goals ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "title TEXT NOT NULL, "
        "description TEXT, "
        "status goal_status NOT NULL DEFAULT 'active', "
        "target_date DATE"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_goals_user_id ON goals (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_goals_status ON goals (status)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_goals_target_date ON goals (target_date)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_goals_user_id_status ON goals (user_id, status)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_goals_title_trgm ON goals USING gin (title gin_trgm_ops)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS key_results ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "goal_id UUID NOT NULL REFERENCES goals(id) ON DELETE CASCADE, "
        "title TEXT NOT NULL, "
        "target_value DOUBLE PRECISION NOT NULL, "
        "current_value DOUBLE PRECISION NOT NULL DEFAULT 0, "
        "unit TEXT NOT NULL"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_key_results_goal_id ON key_results (goal_id)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS habits ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "name TEXT NOT NULL, "
        "frequency habit_frequency NOT NULL DEFAULT 'daily', "
        "target_count INTEGER NOT NULL DEFAULT 1, "
        "is_archived BOOLEAN NOT NULL DEFAULT false"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_habits_user_id ON habits (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_habits_is_archived ON habits (is_archived)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_habits_name_trgm ON habits USING gin (name gin_trgm_ops)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS habit_logs ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "habit_id UUID NOT NULL REFERENCES habits(id) ON DELETE CASCADE, "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "date DATE NOT NULL, "
        "count INTEGER NOT NULL DEFAULT 1, "
        "CONSTRAINT uq_habit_logs_habit_id UNIQUE (habit_id, date)"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_habit_logs_habit_id ON habit_logs (habit_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_habit_logs_user_id ON habit_logs (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_habit_logs_date ON habit_logs (date)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS journal_entries ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "title TEXT, "
        "content TEXT NOT NULL, "
        "mood TEXT, "
        "entry_date DATE NOT NULL"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_journal_entries_user_id ON journal_entries (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_journal_entries_entry_date ON journal_entries (entry_date)")
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_journal_entries_content_trgm "
        "ON journal_entries USING gin (content gin_trgm_ops)"
    )

    op.execute(
        "CREATE TABLE IF NOT EXISTS events ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "title TEXT NOT NULL, "
        "description TEXT, "
        "start_at TIMESTAMPTZ NOT NULL, "
        "end_at TIMESTAMPTZ NOT NULL, "
        "location TEXT"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_events_user_id ON events (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_events_start_at ON events (start_at)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_events_end_at ON events (end_at)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_events_title_trgm ON events USING gin (title gin_trgm_ops)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS time_blocks ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "title TEXT NOT NULL, "
        "start_at TIMESTAMPTZ NOT NULL, "
        "end_at TIMESTAMPTZ NOT NULL, "
        "task_id UUID REFERENCES tasks(id) ON DELETE SET NULL, "
        "event_id UUID REFERENCES events(id) ON DELETE SET NULL"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_time_blocks_user_id ON time_blocks (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_time_blocks_start_at ON time_blocks (start_at)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_time_blocks_end_at ON time_blocks (end_at)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_time_blocks_task_id ON time_blocks (task_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_time_blocks_event_id ON time_blocks (event_id)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS daily_activities ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "title TEXT NOT NULL, "
        "category TEXT NOT NULL, "
        "duration_minutes INTEGER, "
        "activity_date DATE NOT NULL"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_daily_activities_user_id ON daily_activities (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_daily_activities_category ON daily_activities (category)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_daily_activities_activity_date ON daily_activities (activity_date)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS daily_metrics ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "metric_date DATE NOT NULL, "
        "steps INTEGER NOT NULL DEFAULT 0, "
        "distance_meters DOUBLE PRECISION NOT NULL DEFAULT 0, "
        "active_calories DOUBLE PRECISION NOT NULL DEFAULT 0, "
        "CONSTRAINT uq_daily_metrics_user_id UNIQUE (user_id, metric_date)"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_daily_metrics_user_id ON daily_metrics (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_daily_metrics_metric_date ON daily_metrics (metric_date)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS sleep_records ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "sleep_date DATE NOT NULL, "
        "start_at TIMESTAMPTZ NOT NULL, "
        "end_at TIMESTAMPTZ NOT NULL, "
        "duration_minutes INTEGER NOT NULL, "
        "quality TEXT, "
        "CONSTRAINT uq_sleep_records_user_id UNIQUE (user_id, sleep_date)"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_sleep_records_user_id ON sleep_records (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_sleep_records_sleep_date ON sleep_records (sleep_date)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS workouts ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "workout_type TEXT NOT NULL, "
        "start_at TIMESTAMPTZ NOT NULL, "
        "end_at TIMESTAMPTZ, "
        "duration_minutes INTEGER, "
        "calories DOUBLE PRECISION, "
        "distance_meters DOUBLE PRECISION"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_workouts_user_id ON workouts (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_workouts_workout_type ON workouts (workout_type)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_workouts_start_at ON workouts (start_at)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS device_connections ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "platform device_connection_platform NOT NULL, "
        "status device_connection_status NOT NULL DEFAULT 'connected', "
        "connected_at TIMESTAMPTZ, "
        "disconnected_at TIMESTAMPTZ, "
        "CONSTRAINT uq_device_connections_user_id UNIQUE (user_id, platform)"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_device_connections_user_id ON device_connections (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_device_connections_platform ON device_connections (platform)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_device_connections_status ON device_connections (status)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS daily_reviews ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "review_date DATE NOT NULL, "
        "wins TEXT, "
        "blockers TEXT, "
        "mood TEXT, "
        "notes TEXT, "
        "CONSTRAINT uq_daily_reviews_user_id UNIQUE (user_id, review_date)"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_daily_reviews_user_id ON daily_reviews (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_daily_reviews_review_date ON daily_reviews (review_date)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS weekly_reviews ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "week_start_date DATE NOT NULL, "
        "wins TEXT, "
        "blockers TEXT, "
        "mood TEXT, "
        "notes TEXT, "
        "CONSTRAINT uq_weekly_reviews_user_id UNIQUE (user_id, week_start_date)"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_weekly_reviews_user_id ON weekly_reviews (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_weekly_reviews_week_start_date ON weekly_reviews (week_start_date)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS reflections ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "reflection_date DATE NOT NULL, "
        "prompt TEXT, "
        "content TEXT NOT NULL"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_reflections_user_id ON reflections (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_reflections_reflection_date ON reflections (reflection_date)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS notifications ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "notification_type TEXT NOT NULL, "
        "channel notification_channel NOT NULL, "
        "payload JSONB NOT NULL, "
        "read_at TIMESTAMPTZ, "
        "sent_at TIMESTAMPTZ, "
        "delivery_attempts INTEGER NOT NULL DEFAULT 0, "
        "last_attempted_at TIMESTAMPTZ, "
        "failed_at TIMESTAMPTZ"
        ")"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_notifications_user_id ON notifications (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_notifications_notification_type ON notifications (notification_type)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_notifications_channel ON notifications (channel)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_notifications_read_at ON notifications (read_at)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_notifications_sent_at ON notifications (sent_at)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_notifications_failed_at ON notifications (failed_at)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_notifications_user_id_read_at ON notifications (user_id, read_at)")

    op.execute(
        "CREATE TABLE IF NOT EXISTS notification_preferences ("
        "id UUID PRIMARY KEY DEFAULT gen_random_uuid(), "
        "created_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), "
        "user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
        "push_tasks BOOLEAN NOT NULL DEFAULT true, "
        "push_habits BOOLEAN NOT NULL DEFAULT true, "
        "push_reviews BOOLEAN NOT NULL DEFAULT true, "
        "push_goals BOOLEAN NOT NULL DEFAULT true, "
        "push_milestones BOOLEAN NOT NULL DEFAULT true, "
        "email_digest BOOLEAN NOT NULL DEFAULT true, "
        "email_reviews BOOLEAN NOT NULL DEFAULT true, "
        "inapp_tasks BOOLEAN NOT NULL DEFAULT true, "
        "inapp_habits BOOLEAN NOT NULL DEFAULT true, "
        "inapp_reviews BOOLEAN NOT NULL DEFAULT true, "
        "inapp_goals BOOLEAN NOT NULL DEFAULT true, "
        "inapp_milestones BOOLEAN NOT NULL DEFAULT true"
        ")"
    )
    op.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS ix_notification_preferences_user_id "
        "ON notification_preferences (user_id)"
    )


def downgrade() -> None:
    op.drop_table("notification_preferences")
    op.drop_table("notifications")
    op.drop_table("reflections")
    op.drop_table("weekly_reviews")
    op.drop_table("daily_reviews")
    op.drop_table("device_connections")
    op.drop_table("workouts")
    op.drop_table("sleep_records")
    op.drop_table("daily_metrics")
    op.drop_table("daily_activities")
    op.drop_table("time_blocks")
    op.drop_table("events")
    op.drop_table("journal_entries")
    op.drop_table("habit_logs")
    op.drop_table("habits")
    op.drop_table("key_results")
    op.drop_table("goals")
    op.drop_table("activity_log_entries")
    op.drop_table("focus_sessions")
    op.drop_table("dependencies")
    op.drop_table("tasks")
    op.drop_table("milestones")
    op.drop_table("projects")
    op.drop_table("project_templates")
    op.drop_table("clients")
    op.drop_table("quick_captures")
    op.drop_table("note_links")
    op.drop_table("note_versions")
    op.drop_table("notes")
    op.drop_table("folders")
    op.drop_table("google_connections")
    op.drop_table("users")
    op.execute("DROP TYPE IF EXISTS notification_channel")
    op.execute("DROP TYPE IF EXISTS device_connection_status")
    op.execute("DROP TYPE IF EXISTS device_connection_platform")
    op.execute("DROP TYPE IF EXISTS habit_frequency")
    op.execute("DROP TYPE IF EXISTS goal_status")
    op.execute("DROP TYPE IF EXISTS task_priority")
    op.execute("DROP TYPE IF EXISTS task_status")
    op.execute("DROP TYPE IF EXISTS project_status")
    op.execute("DROP TYPE IF EXISTS auth_provider")