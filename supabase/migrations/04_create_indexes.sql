-- Session lookup optimization
CREATE INDEX idx_session_lookup 
  ON sessions (device_id, expires_at DESC);
  
CREATE INDEX idx_session_active 
  ON sessions (last_active);

-- Reservation status indexing
CREATE INDEX idx_reservation_status 
  ON reservations (release_id, status, reserved_at DESC);

CREATE INDEX idx_reservation_expiry
  ON reservations (expires_at);

-- Audit log indexing
CREATE INDEX idx_audit_session
  ON audit_logs (session_id, created_at DESC);