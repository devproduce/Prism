"use client"

import { useState, useRef, useEffect, useMemo, useCallback } from "react"
import { useQuery } from "@tanstack/react-query"
import Image from "next/image"
import { useSearchParams, useRouter } from "next/navigation"
import { Upload, X, Share2, Loader2, Check, UserPlus, Mail, Terminal, Video, Star, Archive, Trash2, MessageCircle, MessageSquare } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Switch } from "@/components/ui/switch"
import { apiClient, API_BASE_URL } from "@/lib/api"
import { fetchFriends, friendKeys } from "@/lib/queries"
import { useAuth } from "@/contexts/auth-context"
import { ProfileAvatar } from "@/components/ui/profile-avatar"
import { ImageRecipientPopover } from "@/components/features/share/image-recipient-popover"
import { useShareStore } from "@/store/share-store"

// Video extensions for detection
const VIDEO_EXTENSIONS = ['.mp4', '.avi', '.mov', '.mkv', '.webm', '.m4v', '.wmv', '.flv']

// Helper: Check if file is a video
const isVideoFile = (file: File): boolean => {
    return file.type.startsWith('video/') ||
        VIDEO_EXTENSIONS.some(ext => file.name.toLowerCase().endsWith(ext))
}

// Helper: Check if URL points to a video
const isVideoUrl = (url: string): boolean => {
    if (!url) return false
    return VIDEO_EXTENSIONS.some(ext => url.toLowerCase().includes(ext))
}

// Helper: Get display text for photo/video count
const getMediaCountText = (files: File[]): string => {
    const photos = files.filter(f => !isVideoFile(f)).length
    const videos = files.filter(f => isVideoFile(f)).length
    const parts: string[] = []
    if (photos > 0) parts.push(`${photos} Photo${photos !== 1 ? 's' : ''}`)
    if (videos > 0) parts.push(`${videos} Video${videos !== 1 ? 's' : ''}`)
    return parts.join(' & ') || '0 items'
}

// Helper: Get display text for recipient count (photos vs videos)
const getRecipientMediaCountText = (count: number, storagePaths?: string[]): string => {
    // If we have storage paths, count photos vs videos
    // For now just use "media found" as we don't have per-recipient breakdown
    if (count === 0) return 'No media found'
    if (count === 1) return '1 media found'
    return `${count} media found`
}

interface CroppedFaceProps {
    representativeImageId: string
    bbox?: { x1?: number; y1?: number; x2?: number; y2?: number } | null
}

/**
 * CroppedFace — canvas-based face thumbnail.
 *
 * Why canvas instead of CSS positioning math?
 * 1. CSS independent scaleX/scaleY → aspect-ratio warp when cropW ≠ cropH.
 * 2. Canvas drawImage() gives pixel-perfect square crop, zero distortion.
 * 3. naturalWidth/naturalHeight after browser decode matches CV bbox coords
 *    (both work in EXIF-applied space once the browser renders the image).
 */
function CroppedFace({ representativeImageId, bbox }: CroppedFaceProps) {
    const [cropDataUrl, setCropDataUrl] = useState<string | null>(null)
    const [loadFailed, setLoadFailed] = useState(false)
    const imageUrl = `${API_BASE_URL}/images/${representativeImageId}`

    useEffect(() => {
        // Reset when inputs change
        setCropDataUrl(null)
        setLoadFailed(false)

        if (!representativeImageId) return

        const img = new window.Image()
        img.crossOrigin = 'anonymous'

        img.onload = () => {
            const naturalWidth = img.naturalWidth
            const naturalHeight = img.naturalHeight
            const OUTPUT_PX = 96 // 3× for retina sharpness on 32px display

            if (
                bbox &&
                bbox.x1 !== undefined && bbox.y1 !== undefined &&
                bbox.x2 !== undefined && bbox.y2 !== undefined
            ) {
                const { x1, y1, x2, y2 } = bbox
                const w = x2 - x1
                const h = y2 - y1

                if (w > 0 && h > 0) {
                    const cx = (x1 + x2) / 2
                    const cy = (y1 + y2) / 2

                    // Expand to a square with 70% head room
                    const side = Math.max(w, h) * 1.7

                    // Place square centred on face, clamped to image bounds
                    let sx = cx - side / 2
                    let sy = cy - side / 2
                    let sw = side
                    let sh = side

                    if (sx + sw > naturalWidth)  sx = naturalWidth - sw
                    if (sy + sh > naturalHeight) sy = naturalHeight - sh
                    sx = Math.max(0, sx)
                    sy = Math.max(0, sy)
                    sw = Math.min(sw, naturalWidth  - sx)
                    sh = Math.min(sh, naturalHeight - sy)

                    if (sw > 0 && sh > 0) {
                        try {
                            const canvas = document.createElement('canvas')
                            canvas.width  = OUTPUT_PX
                            canvas.height = OUTPUT_PX
                            const ctx = canvas.getContext('2d')
                            if (ctx) {
                                ctx.drawImage(img, sx, sy, sw, sh, 0, 0, OUTPUT_PX, OUTPUT_PX)
                                setCropDataUrl(canvas.toDataURL('image/jpeg', 0.88))
                                return
                            }
                        } catch {
                            // CORS taint — fall through to full-image fallback
                        }
                    }
                }
            }
            // No bbox or canvas failed — signal to show full image fallback
            setLoadFailed(true)
        }

        img.onerror = () => setLoadFailed(true)
        img.src = imageUrl
    // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [representativeImageId, bbox?.x1, bbox?.y1, bbox?.x2, bbox?.y2])

    return (
        <div className="relative w-8 h-8 rounded-full overflow-hidden border border-white/10 bg-zinc-900/50 shrink-0">
            {cropDataUrl ? (
                // Perfect canvas crop
                // eslint-disable-next-line @next/next/no-img-element
                <img
                    src={cropDataUrl}
                    alt="Face cutout"
                    className="absolute inset-0 w-full h-full object-cover"
                />
            ) : (
                // Full-image fallback (no bbox, CORS block, or still loading)
                // eslint-disable-next-line @next/next/no-img-element
                <img
                    src={imageUrl}
                    alt="Face cutout"
                    className={`absolute inset-0 w-full h-full object-cover transition-opacity duration-300 ${loadFailed || !bbox ? 'opacity-100' : 'opacity-0'}`}
                    loading="lazy"
                />
            )}
        </div>
    )
}

export default function SharePage() {
    const { user } = useAuth()
    const router = useRouter()
    const searchParams = useSearchParams()
    const urlBatchId = searchParams.get('batchId')

    const [showSMS, setShowSMS] = useState(false)
    
    useEffect(() => {
        if (typeof window !== "undefined" && typeof navigator !== "undefined") {
            // NextJS/Vercel-level precision via modern userAgentData
            if ((navigator as any).userAgentData) {
                setShowSMS((navigator as any).userAgentData.mobile)
                return
            }
            // Fallback for Safari/Firefox
            const ua = navigator.userAgent.toLowerCase()
            const isMobileDevice = /iphone|ipad|ipod|android|blackberry|mini|windows\sphone|iemobile/i.test(ua)
            setShowSMS(isMobileDevice)
        }
    }, [])

    const [selectedFiles, setSelectedFiles] = useState<File[]>([])
    const [previewUrls, setPreviewUrls] = useState<string[]>([])
    const [isUploading, setIsUploading] = useState(false)
    const [uploadStatus, setUploadStatus] = useState<"idle" | "analyzing" | "review" | "success" | "error">("idle")
    const [batchId, setBatchId] = useState<string | null>(null)
    const [analysisResult, setAnalysisResult] = useState<any>(null)
    const [autoClean, setAutoClean] = useState(false)
    const fileInputRef = useRef<HTMLInputElement>(null)

    // Global share store
    const globalRecipients = useShareStore(state => state.globalRecipients)
    const setGlobalRecipients = useShareStore(state => state.setGlobalRecipients)
    const toggleGlobalRecipient = useShareStore(state => state.toggleGlobalRecipient)
    const perImageOverrides = useShareStore(state => state.perImageOverrides)
    const perImageAlbums = useShareStore(state => state.perImageAlbums)
    const setImageRecipients = useShareStore(state => state.setImageRecipients)
    const setImageAlbums = useShareStore(state => state.setImageAlbums)
    const clearShareState = useShareStore(state => state.clearState)

    // Per-image selection state
    const [selectedImageForEdit, setSelectedImageForEdit] = useState<any>(null)

    // All friends for the popover via React Query
    const { data: friendsList = [] } = useQuery({
        queryKey: friendKeys.all(user?.id || ''),
        queryFn: () => fetchFriends(user!.id),
        enabled: !!user?.id,
    })

    // Track sent friend request usernames to show status
    const [sentRequests, setSentRequests] = useState<Set<string>>(new Set())

    const handleSendFriendRequest = async (targetUsername: string) => {
        if (!user?.id) return
        try {
            await apiClient("/friends/request", {
                method: "POST",
                body: { user_id: user.id, username: targetUsername },
            })
        } catch (err: any) {
            // A 409 "already sent" is not a real error — the request exists, which is what we want.
            // Any other error is a genuine failure we should surface.
            if (!err.message?.includes("Friend request already sent")) {
                console.error("Failed to send friend request:", err)
                return
            }
        }
        // Optimistically mark as sent regardless of whether it was a fresh send or a duplicate.
        setSentRequests(prev => {
            const next = new Set(prev)
            next.add(targetUsername)
            return next
        })
    }

    // Memoized media list to prevent flickering on re-renders
    const mediaItems = useMemo(() => {
        if (analysisResult?.images) {
            return analysisResult.images
        }
        return previewUrls.map((url, i) => ({
            image_url: url,
            storage_path: selectedFiles[i]?.name || '',
            id: `preview-${i}`,
            detected_faces: []
        }))
    }, [analysisResult?.images, previewUrls, selectedFiles])

    // Get recipients for a specific image (considering overrides AND global toggle)
    const getImageRecipients = useCallback((imageId: string, detectedFaces: any[]): Set<string> => {
        if (perImageOverrides[imageId]) {
            // User customized this image - show friends who are in override AND globally enabled
            return new Set(
                [...perImageOverrides[imageId]].filter(userId => globalRecipients.has(userId))
            )
        }
        // Default: show detected faces that are globally enabled
        const detectedUserIds = detectedFaces
            .filter((f: any) => f.user_id && globalRecipients.has(f.user_id))
            .map((f: any) => f.user_id)
        return new Set(detectedUserIds)
    }, [perImageOverrides, globalRecipients])

    // Handle per-image recipient change - also auto-enable friends globally
    const handleImageRecipientChange = (imageId: string, recipients: Set<string>) => {
        setImageRecipients(imageId, recipients)
    }

    // Get raw recipients for an image (for popover display, ignores global toggle)
    const getRawImageRecipients = (imageId: string, detectedFaces: any[]): Set<string> => {
        if (perImageOverrides[imageId]) {
            return perImageOverrides[imageId]
        }
        // Default to detected faces
        return new Set(
            detectedFaces
                .filter((f: any) => f.user_id)
                .map((f: any) => f.user_id)
        )
    }

    // Handle per-image album change
    const handleImageAlbumChange = (imageId: string, albums: Set<string>) => {
        setImageAlbums(imageId, albums)
    }

    // Get raw albums for an image
    const getRawImageAlbums = (imageId: string): Set<string> => {
        return perImageAlbums[imageId] || new Set()
    }

    // Get all friends for the popover (sorted alphabetically)
    const allFriends = useMemo(() => {
        return [...friendsList]
            .sort((a, b) => a.username.toLowerCase().localeCompare(b.username.toLowerCase()))
            .map((f: any) => ({
                id: f.id,
                username: f.username,
                first_name: f.first_name,
                profile_pic_id: f.profile_pic_id
            }))
    }, [friendsList])

    // Compute relevant recipients: friends who are either detected OR manually added to any image
    const relevantRecipients = useMemo(() => {
        const recipientSet = new Set<string>()

        // Add CV-detected friends
        analysisResult?.recipients?.forEach((r: any) => {
            recipientSet.add(r.user_id)
        })

        // Add manually added friends from per-image overrides
        Object.values(perImageOverrides).forEach((recipients: Set<string>) => {
            recipients.forEach(userId => recipientSet.add(userId))
        })

        // Get full friend data for relevant recipients, sorted alphabetically
        return allFriends
            .filter(f => recipientSet.has(f.id))
            .map(f => ({
                ...f,
                isDetected: analysisResult?.recipients?.some((r: any) => r.user_id === f.id) || false
            }))
    }, [analysisResult?.recipients, perImageOverrides, allFriends])

    // Get display faces for a specific image (detected + manually added, filtered by global toggle)
    const getDisplayFaces = useCallback((imageId: string, detectedFaces: any[]): any[] => {
        const overrideRecipients = perImageOverrides[imageId]
        if (overrideRecipients) {
            // With override, show friends from override list that are globally enabled
            return allFriends
                .filter(f => overrideRecipients.has(f.id) && globalRecipients.has(f.id))
                .map(f => ({ face_id: f.id, user_id: f.id, username: f.username, profile_pic_id: f.profile_pic_id }))
        }
        // No override: show detected faces that are globally enabled
        return detectedFaces.filter((f: any) => f.user_id && globalRecipients.has(f.user_id))
    }, [allFriends, perImageOverrides, globalRecipients])

    const displayFacesByImageId = useMemo(() => {
        const byImageId: Record<string, any[]> = {}

        mediaItems.forEach((img: any) => {
            const seen = new Set<string>()
            byImageId[img.id] = getDisplayFaces(img.id, img.detected_faces || []).filter((face: any) => {
                const key = face.user_id || face.face_id
                if (!key || seen.has(key)) return false
                seen.add(key)
                return true
            })
        })

        return byImageId
    }, [getDisplayFaces, mediaItems])

    const unknownPreviewFaces = useMemo(() => {
        return analysisResult?.unknowns?.slice(0, 4) || []
    }, [analysisResult?.unknowns])

    // Calculate media counts per recipient (photos vs videos) considering overrides
    const recipientMediaCounts = useMemo(() => {
        const counts: Record<string, { photos: number; videos: number }> = {}

        // Initialize all friends with zero counts
        allFriends.forEach(f => {
            counts[f.id] = { photos: 0, videos: 0 }
        })

        // Count each media item
        mediaItems.forEach((img: any) => {
            const imageId = img.id
            const storagePath = img.storage_path || ''
            const mediaUrl = img.image_url || ''
            const isVideo = isVideoUrl(mediaUrl) || isVideoUrl(storagePath)

            // Get recipients for this image (considering overrides)
            const recipients = getImageRecipients(imageId, img.detected_faces || [])

            recipients.forEach(userId => {
                if (!counts[userId]) {
                    counts[userId] = { photos: 0, videos: 0 }
                }
                if (isVideo) {
                    counts[userId].videos++
                } else {
                    counts[userId].photos++
                }
            })
        })

        return counts
    }, [mediaItems, getImageRecipients, allFriends])

    // Get formatted media count text for a recipient
    const getRecipientMediaText = (userId: string): string => {
        const counts = recipientMediaCounts[userId]
        if (!counts) return 'No media'
        const { photos, videos } = counts
        if (photos === 0 && videos === 0) return 'No media'
        const parts: string[] = []
        if (photos > 0) parts.push(`${photos} Photo${photos !== 1 ? 's' : ''}`)
        if (videos > 0) parts.push(`${videos} Video${videos !== 1 ? 's' : ''}`)
        return parts.join(' & ')
    }

    // Initialize state from URL or LocalStorage
    useEffect(() => {
        if (!user) return // Wait for user to be loaded

        // Priority 1: URL param
        if (urlBatchId) {
            // Verify ownership before using
            apiClient(`/images/batch/${urlBatchId}`, { params: { user_id: user.id } })
                .then(() => {
                    setBatchId(urlBatchId)
                    setUploadStatus("analyzing")
                    localStorage.setItem('activeBatchId', urlBatchId)
                })
                .catch(() => {
                    // Not our batch or doesn't exist - redirect to clean share page
                    localStorage.removeItem('activeBatchId')
                    router.replace('/share')
                })
            return
        }

        // Priority 2: LocalStorage restoration (with ownership check)
        const savedBatchId = localStorage.getItem('activeBatchId')
        if (savedBatchId) {
            // Verify we still own this batch before restoring
            apiClient(`/images/batch/${savedBatchId}`, { params: { user_id: user.id } })
                .then(() => {
                    setBatchId(savedBatchId)
                    setUploadStatus("analyzing")
                    router.replace(`/share?batchId=${savedBatchId}`)
                })
                .catch(() => {
                    // Not our batch or doesn't exist - clean up localStorage
                    localStorage.removeItem('activeBatchId')
                })
        }
    }, [urlBatchId, router, user])

    const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
        if (e.target.files && e.target.files.length > 0) {
            const newFiles = Array.from(e.target.files)
            setSelectedFiles((prev) => [...prev, ...newFiles])

            const newUrls = newFiles.map(file => URL.createObjectURL(file))
            setPreviewUrls((prev) => [...prev, ...newUrls])

            setUploadStatus("idle")
        }
    }

    const handleDrop = (e: React.DragEvent) => {
        e.preventDefault()
        if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
            // Accept both images AND videos
            const newFiles = Array.from(e.dataTransfer.files).filter(
                file => file.type.startsWith('image/') || file.type.startsWith('video/')
            )
            if (newFiles.length > 0) {
                setSelectedFiles((prev) => [...prev, ...newFiles])

                const newUrls = newFiles.map(file => URL.createObjectURL(file))
                setPreviewUrls((prev) => [...prev, ...newUrls])

                setUploadStatus("idle")
            }
        }
    }

    const removeFile = (index: number) => {
        setSelectedFiles(prev => prev.filter((_, i) => i !== index))
        setPreviewUrls(prev => {
            const newUrls = [...prev]
            URL.revokeObjectURL(newUrls[index])
            return newUrls.filter((_, i) => i !== index)
        })
    }

    const clearState = () => {
        setSelectedFiles([])
        setPreviewUrls([])
        setUploadStatus("idle")
        setBatchId(null)
        setAnalysisResult(null)
        clearShareState()
        localStorage.removeItem('activeBatchId')
        router.replace('/share')
    }

    const handleCancel = async () => {
        // Call backend to clean up data if we have an active batch
        if (batchId && user) {
            try {
                const formData = new FormData()
                formData.append('user_id', user.id)
                await apiClient(`/images/batch/${batchId}/cancel`, {
                    method: 'DELETE',
                    body: formData
                })
            } catch (err: any) {
                // A 409 "already cancelled" means the batch was cleaned up by a prior operation
                // (e.g. the completing→completed race resolved before cancel arrived). This is
                // not an error from the user's perspective — treat it as a clean cancel.
                if (!err.message?.includes("already cancelled")) {
                    console.error("Failed to cancel batch:", err)
                }
            }
        }
        // Clear local state regardless of backend outcome
        clearState()
    }

    const handleUpload = async () => {
        if (selectedFiles.length === 0 || !user) return

        setIsUploading(true)
        const formData = new FormData()
        selectedFiles.forEach(file => {
            formData.append("images", file)
        })
        formData.append("user_id", user.id)

        try {
            const response = await apiClient("/images/upload", {
                method: "POST",
                body: formData,
            })
            setBatchId(response.batch_id)
            setUploadStatus("analyzing")
            localStorage.setItem('activeBatchId', response.batch_id)
            router.push(`/share?batchId=${response.batch_id}`)
        } catch (err) {
            console.error("Upload failed", err)
            setUploadStatus("error")
            setIsUploading(false)
        }
    }

    // SSE stream for real-time batch status (replaces 2s polling)
    useEffect(() => {
        if (uploadStatus !== "analyzing" || !batchId || !user) return

        let eventSource: EventSource | null = null
        let fallbackInterval: NodeJS.Timeout | null = null
        let closed = false

        // Fetch full batch data and transition to review
        const fetchBatchAndTransition = async () => {
            try {
                const status = await apiClient(`/images/batch/${batchId}`, {
                    params: { user_id: user.id }
                })
                if (status.status === "completed") {
                    setAnalysisResult(status)
                    const recipientIds = status.recipients.map((r: any) => r.user_id)
                    setGlobalRecipients(new Set(recipientIds))
                    setUploadStatus("review")
                    setIsUploading(false)
                } else if (status.status === "failed" || status.status === "error") {
                    setUploadStatus("error")
                    setIsUploading(false)
                    localStorage.removeItem('activeBatchId')
                }
            } catch (err) {
                console.error("Failed to fetch batch result:", err)
            }
        }

        // Fallback: slow polling (5s instead of 2s) if SSE fails
        const startFallbackPolling = () => {
            if (closed || fallbackInterval) return
            console.log("[SSE] Falling back to polling")
            fallbackInterval = setInterval(fetchBatchAndTransition, 5000)
        }

        // Try SSE first
        try {
            const sseUrl = `${API_BASE_URL}/images/batch/${batchId}/stream`
            eventSource = new EventSource(sseUrl)

            eventSource.addEventListener("status", (event: MessageEvent) => {
                try {
                    const data = JSON.parse(event.data)
                    if (data.status === "completed" || data.status === "failed" || data.status === "error") {
                        // Terminal state — fetch full batch data from REST API
                        fetchBatchAndTransition()
                        closed = true
                        eventSource?.close()
                    }
                } catch (e) {
                    console.error("[SSE] Failed to parse event:", e)
                }
            })

            eventSource.onerror = () => {
                if (closed) return
                // SSE connection failed — fall back to polling
                eventSource?.close()
                startFallbackPolling()
            }
        } catch {
            // EventSource not supported or URL construction failed
            startFallbackPolling()
        }

        // Also do one immediate check (batch may have completed before SSE connected)
        fetchBatchAndTransition()

        return () => {
            closed = true
            eventSource?.close()
            if (fallbackInterval) clearInterval(fallbackInterval)
        }
    }, [uploadStatus, batchId, user])

    const toggleRecipient = (userId: string) => {
        toggleGlobalRecipient(userId)
    }

    const handleConfirmShare = async () => {
        if (!batchId) return

        setIsUploading(true)

        try {
            // Build image_recipient_map: for each image, which recipients should receive it + albums
            const imageRecipientMap: Record<string, string[]> = {}
            mediaItems.forEach((img: any) => {
                const recipients = getImageRecipients(img.id, img.detected_faces || [])
                const albums = perImageAlbums[img.id] || new Set()

                // Combine recipients (user IDs) with albums (special strings)
                const combined = [...Array.from(recipients), ...Array.from(albums)]
                if (combined.length > 0) {
                    imageRecipientMap[img.id] = combined
                }
            })

            await apiClient("/images/share/confirm", {
                method: "POST",
                body: {
                    batch_id: batchId,
                    user_id: user?.id,
                    recipients: Array.from(globalRecipients),
                    auto_clean: autoClean,
                    image_recipient_map: imageRecipientMap
                }
            })

            setUploadStatus("success")
            localStorage.removeItem('activeBatchId')
            setTimeout(() => {
                clearState()
            }, 3000)
        } catch (err) {
            console.error("Share confirmation failed", err)
            setUploadStatus("error")
        } finally {
            setIsUploading(false)
        }
    }

    // Split Pane View for Analyzing/Review
    if (uploadStatus === "analyzing" || (uploadStatus === "review" && analysisResult)) {
        return (
            <div className="flex flex-col lg:flex-row h-full gap-6 p-6 overflow-hidden">
                {/* Left Panel: Media Grid */}
                <div className="flex-1 overflow-hidden rounded-2xl border border-white/10 bg-surface/30 p-4 backdrop-blur-sm lg:h-full h-[50vh]">
                    <div className="grid grid-cols-2 gap-4 overflow-y-auto pr-2 sm:grid-cols-3 lg:grid-cols-4 content-start h-full">
                        {mediaItems.map((img: any, idx: number) => {
                            const mediaUrl = img.image_url || img
                            const storagePath = img.storage_path || ''
                            const isVideo = isVideoUrl(mediaUrl) || isVideoUrl(storagePath)

                            return (
                                <div
                                    key={img.id || `media-${idx}`}
                                    className="relative aspect-square overflow-hidden rounded-xl bg-white/5 ring-1 ring-white/10 cursor-pointer hover:ring-2 hover:ring-accent-gold/50 transition-all"
                                    onClick={() => uploadStatus === "review" && setSelectedImageForEdit(img)}
                                >
                                    {isVideo ? (
                                        <>
                                            <video
                                                src={mediaUrl}
                                                className="w-full h-full object-cover"
                                                muted
                                                playsInline
                                                poster=""
                                            />
                                            <div className="absolute bottom-2 left-2 bg-black/60 rounded px-1.5 py-0.5 flex items-center gap-1">
                                                <Video className="h-3 w-3 text-white" />
                                                <span className="text-[10px] text-white">Video</span>
                                            </div>
                                        </>
                                    ) : (
                                        /* eslint-disable-next-line @next/next/no-img-element */
                                        <img
                                            src={mediaUrl}
                                            alt="Content"
                                            className="absolute inset-0 w-full h-full object-cover"
                                        />
                                    )}
                                    {uploadStatus === "analyzing" && (
                                        <div className="absolute inset-0 bg-linear-to-b from-transparent via-cyan-500/20 to-transparent animate-scan" />
                                    )}
                                    {/* Album icons - top right */}
                                    {uploadStatus === "review" && (() => {
                                        const albums = perImageAlbums[img.id] || new Set()
                                        return albums.size > 0 && (
                                            <div className="absolute top-2 right-2 flex gap-1">
                                                {albums.has("favourite") && (
                                                    <div className="p-1 rounded bg-black/40 backdrop-blur-sm">
                                                        <Star className="h-3.5 w-3.5 text-yellow-400 fill-yellow-400" />
                                                    </div>
                                                )}
                                                {albums.has("archive") && (
                                                    <div className="p-1 rounded bg-black/40 backdrop-blur-sm">
                                                        <Archive className="h-3.5 w-3.5 text-purple-400" />
                                                    </div>
                                                )}
                                                {albums.has("bin") && (
                                                    <div className="p-1 rounded bg-black/40 backdrop-blur-sm">
                                                        <Trash2 className="h-3.5 w-3.5 text-red-400" />
                                                    </div>
                                                )}
                                            </div>
                                        )
                                    })()}
                                    {/* Stacked avatars for selected recipients */}
                                    {uploadStatus === "review" && (() => {
                                        const uniqueDisplayFaces = displayFacesByImageId[img.id] || []
                                        return uniqueDisplayFaces.length > 0 && (
                                            <div className="absolute bottom-2 right-2 flex -space-x-2">
                                                {uniqueDisplayFaces.slice(0, 3).map((face: any) => (
                                                    <ProfileAvatar
                                                        key={`${face.face_id}-${face.user_id}`}
                                                        profilePicId={face.profile_pic_id}
                                                        name={face.username || face.first_name || '?'}
                                                        size="sm"
                                                        className="ring-2 ring-surface"
                                                    />
                                                ))}
                                                {uniqueDisplayFaces.length > 3 && (
                                                    <div className="h-8 w-8 rounded-full bg-white/20 flex items-center justify-center text-xs font-medium text-white ring-2 ring-surface backdrop-blur-sm">
                                                        +{uniqueDisplayFaces.length - 3}
                                                    </div>
                                                )}
                                            </div>
                                        )
                                    })()}
                                </div>
                            )
                        })}
                    </div>
                </div>

                {/* Right Panel: Control Center */}
                <div className="w-full lg:w-96 shrink-0 rounded-2xl border border-white/10 bg-surface p-6 shadow-xl flex flex-col">
                    <div className="mb-6">
                        <h2 className="text-xl font-bold text-white flex items-center gap-2">
                            {uploadStatus === "analyzing" ? (
                                <>
                                    <Loader2 className="h-5 w-5 animate-spin text-cyan-400" />
                                    Analyzing Content
                                </>
                            ) : (
                                <>
                                    <Check className="h-5 w-5 text-green-400" />
                                    Review & Share
                                </>
                            )}
                        </h2>
                        <p className="text-sm text-muted-foreground mt-1">
                            {uploadStatus === "analyzing"
                                ? "Prism AI is detecting faces and scenes..."
                                : "Confirm recipients and share your moments."}
                        </p>
                    </div>

                    <ScrollArea className="flex-1 pr-4 -mr-4">
                        {uploadStatus === "analyzing" ? (
                            <div className="space-y-4 font-mono text-sm p-4 rounded-xl bg-black/40 border border-white/5">
                                <div className="flex items-center gap-3 text-green-400">
                                    <Terminal className="h-4 w-4" />
                                    <span>System initialized</span>
                                </div>
                                <div className="flex items-center gap-3 text-cyan-400">
                                    <Loader2 className="h-4 w-4 animate-spin" />
                                    <span>Extracting embeddings...</span>
                                </div>
                                <div className="flex items-center gap-3 text-muted-foreground">
                                    <div className="h-4 w-4 rounded-full border border-current opacity-20" />
                                    <span>Matching faces...</span>
                                </div>
                                <div className="flex items-center gap-3 text-muted-foreground">
                                    <div className="h-4 w-4 rounded-full border border-current opacity-20" />
                                    <span>Scene classification...</span>
                                </div>
                            </div>
                        ) : (
                            <div className="space-y-8 pb-4">
                                {/* Group A: Recipients */}
                                <div>
                                    <div className="flex items-center justify-between mb-3">
                                        <h3 className="text-sm font-medium text-white">Recipients</h3>
                                        <span className="text-xs text-muted-foreground bg-white/10 px-2 py-0.5 rounded-full">
                                            {relevantRecipients.filter(f => globalRecipients.has(f.id)).length} selected
                                        </span>
                                    </div>
                                    <div className="space-y-2">
                                        {relevantRecipients.map((friend: any) => {
                                            const mediaText = getRecipientMediaText(friend.id)
                                            const isEnabled = globalRecipients.has(friend.id)
                                            return (
                                                <div
                                                    key={friend.id}
                                                    className={`flex items-center justify-between rounded-lg border p-2 transition-all ${isEnabled
                                                        ? 'border-green-500/30 bg-green-500/10'
                                                        : 'border-white/5 bg-white/5'
                                                        }`}
                                                >
                                                    <div className="flex items-center gap-3">
                                                        <ProfileAvatar
                                                            profilePicId={friend.profile_pic_id}
                                                            name={friend.username}
                                                            size="sm"
                                                        />
                                                        <div className="text-sm">
                                                            <div className="flex items-center gap-2">
                                                                <p className="font-medium text-white">{friend.username}</p>
                                                                {friend.isDetected && (
                                                                    <span className="text-[10px] text-cyan-400 bg-cyan-400/10 px-1.5 py-0.5 rounded">
                                                                        Detected
                                                                    </span>
                                                                )}
                                                            </div>
                                                            <p className="text-xs text-muted-foreground">{isEnabled ? mediaText : 'Disabled'}</p>
                                                        </div>
                                                    </div>
                                                    <Switch
                                                        checked={isEnabled}
                                                        onCheckedChange={() => toggleRecipient(friend.id)}
                                                    />
                                                </div>
                                            )
                                        })}
                                        {relevantRecipients.length === 0 && (
                                            <div className="text-center p-4 rounded-lg border border-dashed border-white/10">
                                                <p className="text-xs text-muted-foreground">No friends detected. Click on images to add friends manually.</p>
                                            </div>
                                        )}
                                    </div>
                                </div>

                                {/* Group B: New Connections */}
                                {analysisResult?.contacts.length > 0 && (
                                    <div>
                                        <h3 className="mb-3 text-sm font-medium text-white">Found Contacts ({analysisResult.contacts.length})</h3>
                                        <div className="space-y-2">
                                            {analysisResult.contacts.map((contact: any) => (
                                                <div key={contact.user_id} className="flex items-center justify-between rounded-lg border border-white/5 bg-white/5 p-2">
                                                    <div className="flex items-center gap-3">
                                                        <ProfileAvatar
                                                            profilePicId={contact.profile_pic_id}
                                                            name={contact.username}
                                                            size="sm"
                                                        />
                                                        <div className="text-sm">
                                                            <p className="font-medium text-white">{contact.username}</p>
                                                            <p className="text-xs text-muted-foreground">On Prism</p>
                                                        </div>
                                                    </div>
                                                    {sentRequests.has(contact.username) ? (
                                                        <Button size="sm" variant="ghost" className="h-8 rounded-full text-green-400 font-medium text-xs px-2" disabled>
                                                            <Check className="h-4 w-4 mr-1" />
                                                            Sent
                                                        </Button>
                                                    ) : (
                                                        <Button
                                                            size="sm"
                                                            variant="ghost"
                                                            className="h-8 w-8 p-0 hover:bg-white/10 hover:text-white text-muted-foreground"
                                                            onClick={() => handleSendFriendRequest(contact.username)}
                                                        >
                                                            <UserPlus className="h-4 w-4" />
                                                        </Button>
                                                    )}
                                                </div>
                                            ))}
                                        </div>
                                    </div>
                                )}

                                {/* Group C: Unknowns */}
                                {analysisResult?.unknowns.length > 0 && (
                                    <div>
                                        <h3 className="mb-3 text-sm font-medium text-white">
                                            {analysisResult.unknowns.length} {analysisResult.unknowns.length === 1 ? 'Person' : 'People'} Found, Invite them to Prism!
                                        </h3>
                                        <div className="space-y-2">
                                            {analysisResult.unknowns.map((u: any, i: number) => (
                                                <div key={u.face_id || i} className="flex items-center justify-between rounded-lg border border-white/5 bg-white/5 p-2.5">
                                                    <div className="flex items-center gap-3">
                                                        <CroppedFace
                                                            representativeImageId={u.representative_image_id}
                                                            bbox={u.bbox}
                                                        />
                                                        <div className="text-sm">
                                                            <p className="font-medium text-white text-xs">Person {i + 1}</p>
                                                            <p className="text-[10px] text-muted-foreground">{u.count} {u.count === 1 ? 'photo' : 'photos'}</p>
                                                        </div>
                                                    </div>
                                                    <div className="flex gap-1">
                                                        <Button
                                                            size="sm"
                                                            variant="outline"
                                                            className="h-7 text-[10px] px-2 bg-white/5 border-white/10 hover:bg-white/10 text-white flex items-center gap-1 rounded-full"
                                                            onClick={() => window.open(u.whatsapp_link, '_blank')}
                                                        >
                                                            <MessageCircle className="h-3 w-3 text-[#25D366]" />
                                                            WhatsApp
                                                        </Button>
                                                        {showSMS && (
                                                            <Button
                                                                size="sm"
                                                                variant="outline"
                                                                className="h-7 text-[10px] px-2 bg-white/5 border-white/10 hover:bg-white/10 text-white flex items-center gap-1 rounded-full"
                                                                onClick={() => window.open(u.sms_link, '_blank')}
                                                            >
                                                                <MessageSquare className="h-3 w-3 text-sky-400" />
                                                                SMS
                                                            </Button>
                                                        )}
                                                    </div>
                                                </div>
                                            ))}
                                        </div>
                                    </div>
                                )}
                            </div>
                        )}
                    </ScrollArea>

                    <div className="mt-6 space-y-4 border-t border-white/10 pt-6">
                        <div className="flex items-center justify-between">
                            <div className="space-y-0.5">
                                <span className="text-sm font-medium text-white">Auto-clean</span>
                                <p className="text-xs text-muted-foreground">Remove irrelevant photos</p>
                            </div>
                            <Switch checked={autoClean} onCheckedChange={setAutoClean} />
                        </div>
                        <div className="flex gap-3">
                            <Button
                                variant="outline"
                                className="flex-1"
                                onClick={handleCancel}
                            >
                                Cancel
                            </Button>
                            <Button
                                className="flex-2 bg-primary text-primary-foreground hover:bg-primary/90"
                                disabled={uploadStatus !== "review" || isUploading}
                                onClick={handleConfirmShare}
                            >
                                {isUploading ? (
                                    <>
                                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                        Sharing...
                                    </>
                                ) : (
                                    "Prism Share"
                                )}
                            </Button>
                        </div>
                    </div>
                </div>

                {/* Per-image recipient popover */}
                {selectedImageForEdit && (
                    <ImageRecipientPopover
                        imageId={selectedImageForEdit.id}
                        imageUrl={selectedImageForEdit.image_url}
                        isVideo={isVideoUrl(selectedImageForEdit.image_url) || isVideoUrl(selectedImageForEdit.storage_path || '')}
                        detectedFaces={selectedImageForEdit.detected_faces || []}
                        allFriends={allFriends}
                        selectedRecipients={getRawImageRecipients(selectedImageForEdit.id, selectedImageForEdit.detected_faces || [])}
                        selectedAlbums={getRawImageAlbums(selectedImageForEdit.id)}
                        onRecipientChange={handleImageRecipientChange}
                        onAlbumChange={handleImageAlbumChange}
                        onClose={() => setSelectedImageForEdit(null)}
                    />
                )}
            </div>
        )
    }

    // Initial Upload View
    return (
        <div className="flex h-full flex-col">
            <div className="mb-8">
                <h1 className="text-2xl font-bold text-white">Share Photos</h1>
                <p className="text-muted-foreground">Upload photos to your gallery and share them with friends.</p>
            </div>

            <div className="flex flex-1 flex-col items-center justify-start gap-8 overflow-y-auto pb-8">
                <Card className="w-full max-w-4xl border-dashed border-white/10 bg-surface/50 backdrop-blur-sm">
                    <CardContent className="p-6">
                        {previewUrls.length > 0 ? (
                            <div className="space-y-6">
                                <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4">
                                    {previewUrls.map((url, index) => {
                                        const file = selectedFiles[index]
                                        const isVideo = file && isVideoFile(file)

                                        return (
                                            <div key={url} className="relative aspect-square w-full overflow-hidden rounded-lg group ring-1 ring-white/10">
                                                {isVideo ? (
                                                    <>
                                                        <video
                                                            src={url}
                                                            className="w-full h-full object-cover"
                                                            muted
                                                            playsInline
                                                        />
                                                        <div className="absolute bottom-2 left-2 bg-black/60 rounded px-1.5 py-0.5 flex items-center gap-1">
                                                            <Video className="h-3 w-3 text-white" />
                                                            <span className="text-[10px] text-white">Video</span>
                                                        </div>
                                                    </>
                                                ) : (
                                                    <Image
                                                        src={url}
                                                        alt={`Preview ${index + 1}`}
                                                        fill
                                                        className="object-cover transition-transform group-hover:scale-105"
                                                    />
                                                )}
                                                <Button
                                                    size="icon"
                                                    variant="destructive"
                                                    className="absolute right-2 top-2 h-6 w-6 rounded-full opacity-0 transition-opacity group-hover:opacity-100"
                                                    onClick={() => removeFile(index)}
                                                >
                                                    <X className="h-3 w-3" />
                                                </Button>
                                            </div>
                                        )
                                    })}
                                    <div
                                        className="flex aspect-square cursor-pointer flex-col items-center justify-center rounded-lg border-2 border-dashed border-white/10 bg-white/5 transition-colors hover:bg-white/10"
                                        onClick={() => fileInputRef.current?.click()}
                                    >
                                        <Upload className="h-6 w-6 text-muted-foreground" />
                                        <span className="mt-2 text-xs text-muted-foreground">Add more</span>
                                    </div>
                                </div>
                                <div className="flex justify-end">
                                    <Button
                                        variant="outline"
                                        onClick={clearState}
                                    >
                                        Clear All
                                    </Button>
                                </div>
                            </div>
                        ) : (
                            <div
                                className="flex flex-col items-center justify-center py-20 text-center transition-colors hover:bg-surface-hover/50 cursor-pointer"
                                onDragOver={(e) => e.preventDefault()}
                                onDrop={handleDrop}
                                onClick={() => fileInputRef.current?.click()}
                            >
                                <div className="mb-4 rounded-full bg-surface p-4 shadow-lg ring-1 ring-white/10">
                                    <Upload className="h-8 w-8 text-primary" />
                                </div>
                                <p className="mb-2 text-lg font-medium text-white">Click to upload</p>
                                <p className="mb-6 text-sm text-muted-foreground">Drag and drop or click to browse multiple files</p>
                                <Button variant="secondary">Select Files</Button>
                            </div>
                        )}
                        <input
                            type="file"
                            ref={fileInputRef}
                            className="hidden"
                            accept="image/*,video/*"
                            multiple
                            onChange={handleFileSelect}
                        />
                    </CardContent>
                </Card>

                {previewUrls.length > 0 && !isUploading && uploadStatus !== "success" && (
                    <div className="flex justify-center gap-4">
                        <Button
                            size="lg"
                            className="w-full max-w-xs rounded-full"
                            onClick={handleUpload}
                        >
                            <Share2 className="mr-2 h-5 w-5" />
                            Share {getMediaCountText(selectedFiles)}
                        </Button>
                    </div>
                )}

                {isUploading && (
                    <div className="flex flex-col items-center gap-4">
                        <Loader2 className="h-8 w-8 animate-spin text-primary" />
                        <p className="text-sm text-muted-foreground">Uploading {getMediaCountText(selectedFiles)}...</p>
                    </div>
                )}

                {uploadStatus === "success" && (
                    <div className="rounded-full bg-green-500/10 px-6 py-3 text-green-500 animate-in fade-in slide-in-from-bottom-4">
                        <p className="font-medium">Photos uploaded successfully!</p>
                    </div>
                )}

                {uploadStatus === "error" && (
                    <div className="rounded-full bg-destructive/10 px-6 py-3 text-destructive animate-in fade-in slide-in-from-bottom-4">
                        <p className="font-medium">Failed to upload photos. Please try again.</p>
                    </div>
                )}
            </div>
        </div>
    )
}
