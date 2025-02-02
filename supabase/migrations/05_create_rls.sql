-- Enable RLS
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Device policies
CREATE POLICY "Devices are only accessible by matching fingerprint"
  ON devices FOR ALL USING (
    fingerprint = current_setting('app.device_fingerprint')::text
  );

-- Session policies
CREATE POLICY "Sessions are accessible by device"
  ON sessions FOR ALL USING (
    device_id IN (
      SELECT id FROM devices 
      WHERE fingerprint = current_setting('app.device_fingerprint')::text
    )
  );

-- Reservation policies
CREATE POLICY "Reservations are accessible by session"
  ON reservations FOR ALL USING (
    session_id IN (
      SELECT s.id FROM sessions s
      JOIN devices d ON s.device_id = d.id
      WHERE d.fingerprint = current_setting('app.device_fingerprint')::text
    )
  );

-- Admin policies
CREATE POLICY "Admin access to audit logs"
  ON audit_logs FOR ALL USING (
    EXISTS (
      SELECT 1 FROM sessions s
      JOIN devices d ON s.device_id = d.id
      WHERE d.fingerprint = current_setting('app.device_fingerprint')::text
      AND s.is_admin = true
    )
  );