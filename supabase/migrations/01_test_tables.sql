-- Create test releases table
CREATE TABLE IF NOT EXISTS test_releases (
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
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT valid_condition CHECK (condition IN ('M', 'NM', 'VG+', 'VG', 'G+', 'G', 'F'))
);