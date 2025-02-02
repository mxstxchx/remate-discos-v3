import { redirect } from 'next/navigation'
import { SessionForm } from './components/SessionForm'
import { headers } from 'next/headers'

export default async function SessionPage() {
  // Using headers for initial server-side handling
  const userAgent = headers().get('user-agent') || ''
  
  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-24">
      <SessionForm />
    </main>
  )
}