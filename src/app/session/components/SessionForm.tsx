'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useSessionStore } from '@/lib/hooks/useSession'

interface SessionFormProps {
  deviceId: string
}

export function SessionForm({ deviceId }: SessionFormProps) {
  const [alias, setAlias] = useState('')
  const [language, setLanguage] = useState<'es-ES' | 'en-UK'>('es-ES')
  const router = useRouter()
  const initSession = useSessionStore((state) => state.initialize)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    await initSession({ alias, language, deviceId })
    router.push('/browse')
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4 w-full max-w-md">
      <input
        type="text"
        value={alias}
        onChange={(e) => setAlias(e.target.value)}
        placeholder="Enter alias"
        className="w-full p-2 border rounded"
        required
      />
      <select
        value={language}
        onChange={(e) => setLanguage(e.target.value as 'es-ES' | 'en-UK')}
        className="w-full p-2 border rounded"
      >
        <option value="es-ES">Español</option>
        <option value="en-UK">English</option>
      </select>
      <button
        type="submit"
        className="w-full bg-slate-800 text-white p-2 rounded hover:bg-slate-700"
      >
        Continue
      </button>
    </form>
  )
}