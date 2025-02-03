-- Test devices with different states
INSERT INTO devices (id, fingerprint, is_active) VALUES
  ('11111111-1111-1111-1111-111111111111', 'device_1_fp', true),
  ('22222222-2222-2222-2222-222222222222', 'device_2_fp', true),
  ('33333333-3333-3333-3333-333333333333', 'device_3_fp', false);

-- Test sessions including admin
INSERT INTO user_sessions (id, device_id, alias, language, is_admin, expires_at) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'regular_user', 'es-ES', false, NOW() + INTERVAL '7 days'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'admin_user', 'en-UK', true, NOW() + INTERVAL '7 days'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '33333333-3333-3333-3333-333333333333', 'expired_user', 'es-ES', false, NOW() - INTERVAL '1 day');

-- Test releases (assuming releases table exists)
INSERT INTO releases (id, title, artists, labels, styles, condition, price, images) VALUES
  (1, 'Test Release 1', ARRAY['Artist 1'], '{"name": "Label 1", "catno": "CAT1"}'::jsonb, ARRAY['Style 1'], 'NM', 25.00, '{"primary": "img1.jpg"}'::jsonb),
  (2, 'Test Release 2', ARRAY['Artist 2'], '{"name": "Label 2", "catno": "CAT2"}'::jsonb, ARRAY['Style 2'], 'VG+', 15.00, '{"primary": "img2.jpg"}'::jsonb);

-- Test reservations with different statuses
INSERT INTO reservations (id, release_id, session_id, status, position_in_queue, expires_at) VALUES
  ('55555555-5555-5555-5555-555555555555', 1, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'reserved', NULL, NOW() + INTERVAL '3 days'),
  ('66666666-6666-6666-6666-666666666666', 2, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'in_queue', 1, NULL),
  ('77777777-7777-7777-7777-777777777777', 1, 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'cancelled', NULL, NULL);

-- Test audit logs
INSERT INTO audit_logs (session_id, action, details) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'create_reservation', '{"release_id": 1}'::jsonb),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'admin_force_expire', '{"reservation_id": "77777777-7777-7777-7777-777777777777"}'::jsonb);