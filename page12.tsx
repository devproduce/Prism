"use client"

import { useState, useRef, useEffect, useMemo } from "react"
import Image from "next/image"
import { useSearchParams, useRouter } from "next/navigation"
import { Upload, X, Share2, Loader2, Check, UserPlus, Mail, Terminal, Video, Star, Archive, Trash2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Switch } from "@/components/ui/switch"
import { apiClient } from "@/lib/api"
import { useAuth } from "@/contexts/auth-context"
import { ProfileAvatar } from "@/components/ui/profile-avatar"
import { ImageRecipientPopover } from "@/components/features/share/image-recipient-popover"

// Video extensions for detection
const VIDEO_EXTENSIONS = ['.mp4', '.avi', '.mov', '.mkv', '.webm', '.m4v']

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

export default function SharePage() {
    const { user } = useAuth()
    const router = useRouter()
    const searchParams = useSearchParams()
    const urlBatchId = searchParams.get('batchId')

    const [selectedFiles, setSelectedFiles] = useState<File[]>([])
    const [previewUrls, setPreviewUrls] = useState<string[]>([])
    const [isUploading, setIsUploading] = useState(false)
    const [uploadStatus, setUploadStatus] = useState<"idle" | "analyzing" | "review" | "success" | "error">("idle")
    const [batchId, setBatchId] = useState<string | null>(null)
    const [analysisResult, setAnalysisResult] = useState<any>(null)
    const [selectedRecipients, setSelectedRecipients] = useState<Set<string>>(new Set())
    const [autoClean, setAutoClean] = useState(false)
    const fileInputRef = useRef<HTMLInputElement>(null)

    // Per-image selection state
    const [selectedImageForEdit, setSelectedImageForEdit] = useState<any>(null)
    const [perImageOverrides, setPerImageOverrides] = useState<Record<string, Set<string>>>({})
    const [perImageAlbums, setPerImageAlbums] = useState<Record<string, Set<string>>>({})

    // All friends for the popover
    const [friendsList, setFriendsList] = useState<any[]>([])

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
    const getImageRecipients = (imageId: string, detectedFaces: any[]): Set<string> => {
        if (perImageOverrides[imageId]) {
            // User customized this image - show friends who are in override AND globally enabled
            return new Set(
                [...perImageOverrides[imageId]].filter(userId => selectedRecipients.has(userId))
            )
        }
        // Default: show detected faces that are globally enabled
        const detectedUserIds = detectedFaces
            .filter((f: any) => f.user_id && selectedRecipients.has(f.user_id))
            .map((f: any) => f.user_id)
        return new Set(detectedUserIds)
    }

    // Handle per-image recipient change - also auto-enable friends globally
    const handleImageRecipientChange = (imageId: string, recipients: Set<string>) => {
        // Update per-image override
        setPerImageOverrides(prev => ({
            ...prev,
            [imageId]: recipients
        }))

        // Auto-enable any newly added friends globally
        setSelectedRecipients(prev => {
            const newSet = new Set(prev)
            recipients.forEach(userId => {
                if (!prev.has(userId)) {
                    newSet.add(userId)
                }
            })
            return newSet
        })
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
        setPerImageAlbums(prev => ({ ...prev, [imageId]: albums }))
    }

    // Get raw albums for an image
    const getRawImageAlbums = (imageId: string): Set<string> => {
        return perImageAlbums[imageId] || new Set()
    }

    // Fetch all friends when user is available
    useEffect(() => {
        if (!user) return
        const fetchFriends = async () => {
            try {
                const friends = await apiClient('/friends', { params: { user_id: user.id } })
                setFriendsList(friends || [])
            } catch (err) {
                console.error('Failed to fetch friends:', err)
            }
        }
        fetchFriends()
    }, [user])

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
    const getDisplayFaces = (imageId: string, detectedFaces: any[]): any[] => {
        const overrideRecipients = perImageOverrides[imageId]
        if (overrideRecipients) {
            // With override, show friends from override list that are globally enabled
            return allFriends
                .filter(f => overrideRecipients.has(f.id) && selectedRecipients.has(f.id))
                .map(f => ({ face_id: f.id, user_id: f.id, username: f.username, profile_pic_id: f.profile_pic_id }))
        }
        // No override: show detected faces that are globally enabled
        return detectedFaces.filter((f: any) => f.user_id && selectedRecipients.has(f.user_id))
    }

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
    }, [mediaItems, perImageOverrides, selectedRecipients, allFriends])

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
            } catch (err) {
                console.error("Failed to cancel batch:", err)
            }
        }
        // Clear local state regardless
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

    // Polling for batch status - ONLY during analyzing phase
    useEffect(() => {
        // Stop polling once we enter review mode to prevent flickering
        if (uploadStatus === "analyzing" && batchId) {
            const poll = async () => {
                if (!user) return
                try {
                    const status = await apiClient(`/images/batch/${batchId}`, {
                        params: { user_id: user.id }
                    })
                    if (status.status === "completed") {
                        setAnalysisResult(status)
                        // Transition to review state and stop polling
                        const recipientIds = status.recipients.map((r: any) => r.user_id)
                        setSelectedRecipients(new Set(recipientIds))
                        setUploadStatus("review")
                        setIsUploading(false)
                    } else if (status.status === "failed" || status.status === "error") {
                        setUploadStatus("error")
                        setIsUploading(false)
                        localStorage.removeItem('activeBatchId')
                    }
                } catch (err) {
                    console.error("Polling failed", err)
                }
            }

            // Poll immediately then interval
            poll()
            const interval = setInterval(poll, 2000)
            return () => clearInterval(interval)
        }
    }, [uploadStatus, batchId, user])

    const toggleRecipient = (userId: string) => {
        const newSelected = new Set(selectedRecipients)
        if (newSelected.has(userId)) {
            newSelected.delete(userId)
        } else {
            newSelected.add(userId)
        }
        setSelectedRecipients(newSelected)
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
                    recipients: Array.from(selectedRecipients),
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
            <div className="flex h-full gap-6 p-6">
                {/* Left Panel: Media Grid */}
                <div className="flex-1 overflow-hidden rounded-2xl border border-white/10 bg-surface/30 p-4 backdrop-blur-sm">
                    <div className="grid grid-cols-2 gap-4 overflow-y-auto pr-2 sm:grid-cols-3 lg:grid-cols-4 content-start h-full">
                        {mediaItems.map((img: any, idx: number) => {
                            const mediaUrl = img.image_url || img
                            const storagePath = img.storage_path || ''
                            const isVideo = isVideoUrl(mediaUrl) || isVideoUrl(storagePath)
                            const detectedFaces = img.detected_faces || []

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
                                        const displayFaces = getDisplayFaces(img.id, detectedFaces)
                                        return displayFaces.length > 0 && (
                                            <div className="absolute bottom-2 right-2 flex -space-x-2">
                                                {displayFaces.slice(0, 3).map((face: any) => (
                                                    <ProfileAvatar
                                                        key={face.face_id || face.user_id}
                                                        profilePicId={face.profile_pic_id}
                                                        name={face.username || face.first_name || '?'}
                                                        size="sm"
                                                        className="ring-2 ring-surface"
                                                    />
                                                ))}
                                                {displayFaces.length > 3 && (
                                                    <div className="h-8 w-8 rounded-full bg-white/20 flex items-center justify-center text-xs font-medium text-white ring-2 ring-surface backdrop-blur-sm">
                                                        +{displayFaces.length - 3}
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
                <div className="w-96 shrink-0 rounded-2xl border border-white/10 bg-surface p-6 shadow-xl flex flex-col">
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
                                            {relevantRecipients.filter(f => selectedRecipients.has(f.id)).length} selected
                                        </span>
                                    </div>
                                    <div className="space-y-2">
                                        {relevantRecipients.map((friend: any) => {
                                            const mediaText = getRecipientMediaText(friend.id)
                                            const isEnabled = selectedRecipients.has(friend.id)
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
                                                        <div className="h-8 w-8 rounded-full bg-white/10 flex items-center justify-center">
                                                            <UserPlus className="h-4 w-4 text-muted-foreground" />
                                                        </div>
                                                        <div className="text-sm">
                                                            <p className="font-medium text-white">{contact.username}</p>
                                                            <p className="text-xs text-muted-foreground">On Prism</p>
                                                        </div>
                                                    </div>
                                                    <Button size="sm" variant="ghost" className="h-8 w-8 p-0">
                                                        <UserPlus className="h-4 w-4" />
                                                    </Button>
                                                </div>
                                            ))}
                                        </div>
                                    </div>
                                )}

                                {/* Group C: Unknowns */}
                                {analysisResult?.unknowns.length > 0 && (
                                    <div>
                                        <h3 className="mb-3 text-sm font-medium text-white">Unknown Faces ({analysisResult.unknowns.length})</h3>
                                        <div className="flex items-center justify-between rounded-lg border border-white/5 bg-white/5 p-3">
                                            <div className="flex -space-x-2">
                                                {analysisResult.unknowns.slice(0, 4).map((u: any, i: number) => (
                                                    <div key={i} className="h-8 w-8 rounded-full bg-white/10 ring-2 ring-background flex items-center justify-center text-[10px] text-muted-foreground">
                                                        ?
                                                    </div>
                                                ))}
                                            </div>
                                            <Button size="sm" variant="outline" className="h-8 text-xs">
                                                <Mail className="mr-2 h-3 w-3" />
                                                Invite
                                            </Button>
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
