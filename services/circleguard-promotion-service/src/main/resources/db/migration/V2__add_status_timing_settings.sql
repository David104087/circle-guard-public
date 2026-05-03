-- Create system_settings table if it was not created in V1
CREATE TABLE IF NOT EXISTS system_settings (
    id SERIAL PRIMARY KEY,
    unconfirmed_fencing_enabled BOOLEAN NOT NULL DEFAULT false,
    auto_threshold_seconds BIGINT NOT NULL DEFAULT 86400
);

-- Add timing columns (idempotent)
ALTER TABLE system_settings
ADD COLUMN IF NOT EXISTS mandatory_fence_days INTEGER NOT NULL DEFAULT 14,
ADD COLUMN IF NOT EXISTS encounter_window_days INTEGER NOT NULL DEFAULT 14;

-- Seed initial row if table is empty
INSERT INTO system_settings (unconfirmed_fencing_enabled, auto_threshold_seconds, mandatory_fence_days, encounter_window_days)
SELECT false, 86400, 14, 14
WHERE NOT EXISTS (SELECT 1 FROM system_settings);
