-- Session lookup optimizations
CREATE INDEX idx_sessions_device_lookup 
  ON sessions (device_id, expires_at DESC);

-- Changed: Removed function call from WHERE clause
CREATE INDEX idx_sessions_active 
  ON sessions (last_active DESC, expires_at);

-- Reservation management
CREATE INDEX idx_reservations_status 
  ON reservations (release_id, status, reserved_at DESC);

CREATE INDEX idx_reservations_queue 
  ON reservations (release_id, position_in_queue)
  WHERE status = 'in_queue'::reservation_status;

-- Changed: Added proper type casting for ENUM comparison
CREATE INDEX idx_reservations_expiry 
  ON reservations (expires_at, status)
  WHERE status = ANY(ARRAY['reserved'::reservation_status, 'in_cart'::reservation_status]);

-- JSONB operations
CREATE INDEX idx_release_labels 
  ON releases USING GIN (labels);

CREATE INDEX idx_release_styles 
  ON releases USING GIN (to_tsvector('english', styles::text));

-- Audit trail
CREATE INDEX idx_audit_logs_session 
  ON audit_logs (session_id, created_at DESC);

CREATE INDEX idx_audit_logs_search 
  ON audit_logs USING GIN (details);
