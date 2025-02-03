ALTER TABLE reservations
  ADD CONSTRAINT fk_test_release 
  FOREIGN KEY (release_id) 
  REFERENCES test_releases(id);

ALTER TABLE reservations
  ADD CONSTRAINT fk_session 
  FOREIGN KEY (session_id) 
  REFERENCES user_sessions(id)
  ON DELETE CASCADE;