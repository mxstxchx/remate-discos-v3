import { redirect } from 'next/navigation'
import { getDeviceId } from '@/lib/utils/fingerprint'

export default async function SessionPage() {
  const deviceId = await getDeviceId()
  
  // Check for existing session
  const session = await getSessionByDevice(deviceId)
  if (session && !isExpired(session)) {
    redirect('/browse')
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-24">
      <SessionForm deviceId={deviceId} />
    </main>
  )
}