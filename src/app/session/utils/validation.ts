import { supabase } from '@/lib/supabase/client'

export async function getSessionByDevice(deviceId: string) {
  const { data, error } = await supabase
    .from('sessions')
    .select('*')
    .eq('device_id', deviceId)
    .order('created_at', { ascending: false })
    .limit(1)
    .single()

  if (error || !data) return null
  return data
}

export function isExpired(session: any) {
  if (!session.expires_at) return true
  return new Date(session.expires_at) < new Date()
}