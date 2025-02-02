import { redirect } from 'next/navigation'
import { SessionForm } from './components/SessionForm'
import { headers } from 'next/headers'

export default async function SessionPage() {
  const headersList = await headers()
  const userAgent = headersList.get('user-agent') || ''
  
  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-24">
      <SessionForm />
    </main>
  )
}