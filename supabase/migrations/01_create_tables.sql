-- Create enum types
CREATE TYPE reservation_status AS ENUM (
  'available',
  'in_cart',
  'reserved',
  'in_queue',
  'sold',
  'expired',
  'cancelled'
);

-- Create tables
CREATE TABLE devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fingerprint TEXT NOT NULL UNIQUE,
  last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID REFERENCES devices(id) ON DELETE CASCADE,
  alias TEXT NOT NULL,
  language TEXT DEFAULT 'es-ES',
  is_admin BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE,
  CONSTRAINT valid_language CHECK (language IN ('es-ES', 'en-UK'))
);

-- Note: releases table already exists in production
-- This is just for reference
/* 
CREATE TABLE IF NOT EXISTS releases (
  id BIGINT PRIMARY KEY,
  title TEXT NOT NULL,
  artists TEXT[] NOT NULL,
  labels JSONB NOT NULL,
  styles TEXT[] NOT NULL,
  year TEXT,
  country TEXT,
  condition TEXT NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  images JSONB NOT NULL,
  tracklist JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT valid_condition CHECK (condition IN ('M', 'NM', 'VG+', 'VG', 'G+', 'G', 'F'))
);
*/

CREATE TABLE reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  release_id BIGINT,
  session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  status reservation_status NOT NULL DEFAULT 'available',
  position_in_queue INTEGER,
  reserved_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  details JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create updated_at triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_devices_updated_at
  BEFORE UPDATE ON devices
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_reservations_updated_at
  BEFORE UPDATE ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();