'use client'
import FingerprintJS from '@fingerprintjs/fingerprintjs'

let fpPromise: Promise<any> | null = null

export const getDeviceId = async () => {
  if (typeof window === 'undefined') return null
  
  if (!fpPromise) {
    fpPromise = FingerprintJS.load()
  }

  const fp = await fpPromise
  const result = await fp.get()
  return result.visitorId
}