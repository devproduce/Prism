"use client"

import React, { useState } from "react"
import { Button } from "@/components/ui/button"
import { Spinner } from "@/components/ui/spinner"
import { acceptRetroactiveShare, apiClient, API_BASE_URL } from "@/lib/api"
import { useAuth } from "@/contexts/auth-context"
import { Check, Share2, Sparkles, X } from "lucide-react"

interface RetroactiveSharePromptProps {
    notificationId: number
    friendId: string
    friendUsername?: string
    matchedFaceIds?: any
    contactFaceIds?: any
    unknownFaceIds?: any
    imageIds: any
    onSuccess?: () => void
}

export function RetroactiveSharePrompt({
    notificationId,
    friendId,
    friendUsername = "your friend",
    matchedFaceIds,
    contactFaceIds,
    unknownFaceIds,
    imageIds,
    onSuccess
}: RetroactiveSharePromptProps) {
    const { user } = useAuth()
    const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle")

    const parseArray = (val: any): string[] => {
        if (Array.isArray(val)) return val
        if (typeof val === "string") {
            try {
                const parsed = JSON.parse(val)
                return Array.isArray(parsed) ? parsed : []
            } catch {
                return []
            }
        }
        return []
    }

    const images = parseArray(imageIds)
    const totalMemories = images.length

    const handleShare = async (e: React.MouseEvent) => {
        e.stopPropagation()
        if (!user?.id) return

        setStatus("loading")
        try {
            const cFaceIds = parseArray(contactFaceIds)
            const uFaceIds = [
                ...parseArray(unknownFaceIds),
                ...parseArray(matchedFaceIds)
            ]
            const uniqueContactFaceIds = Array.from(new Set(cFaceIds))
            const uniqueUnknownFaceIds = Array.from(new Set(uFaceIds))

            // 1. Accept retroactive share
            await acceptRetroactiveShare(user.id, friendId, uniqueContactFaceIds, uniqueUnknownFaceIds, images)

            // 2. Try to mark individual notification as read
            try {
                await apiClient(`/notifications/${notificationId}/mark-read`, {
                    method: "POST",
                    body: { user_id: user.id }
                })
            } catch (err) {
                console.warn("Could not mark individual notification as read (endpoint may not exist):", err)
            }

            setStatus("success")
            if (onSuccess) {
                setTimeout(() => {
                    onSuccess()
                }, 1500)
            }
        } catch (err) {
            console.error("Failed to accept retroactive share prompt:", err)
            setStatus("error")
        }
    }

    const handleSkip = async (e: React.MouseEvent) => {
        e.stopPropagation()
        if (!user?.id) return

        // Try to mark individual notification as read
        try {
            await apiClient(`/notifications/${notificationId}/mark-read`, {
                method: "POST",
                body: { user_id: user.id }
            })
        } catch (err) {
            console.warn("Could not mark individual notification as read (endpoint may not exist):", err)
        }

        if (onSuccess) {
            onSuccess()
        }
    }

    if (status === "success") {
        return (
            <div className="flex flex-col items-center justify-center p-6 bg-white/5 border-l-2 border-accent-gold rounded-r-xl transition-all">
                <div className="h-10 w-10 rounded-full bg-accent-gold/20 flex items-center justify-center mb-3">
                    <Check className="h-5 w-5 text-accent-gold" />
                </div>
                <p className="text-sm font-semibold text-accent-gold">
                    ✓ Shared {totalMemories} {totalMemories === 1 ? "memory" : "memories"}!
                </p>
            </div>
        )
    }

    return (
        <div className="w-full flex flex-col p-4 bg-white/5 hover:bg-white/[0.07] border-l-2 border-accent-gold rounded-r-xl transition-all duration-300">
            {/* Header */}
            <div className="flex items-center gap-2 mb-3">
                <span className="p-1 rounded-full bg-accent-gold/20 text-accent-gold shrink-0">
                    <Sparkles className="h-4 w-4" />
                </span>
                <div>
                    <h4 className="text-sm font-semibold text-white leading-tight">
                        You & {friendUsername} are now friends!
                    </h4>
                    <p className="text-xs text-zinc-400 mt-0.5">
                        We found {totalMemories} {totalMemories === 1 ? "memory" : "memories"} with them
                    </p>
                </div>
            </div>

            {/* Image Grid (first 3 images) */}
            {images.length > 0 && (
                <div className="grid grid-cols-3 gap-2 mb-4 max-w-sm">
                    {images.slice(0, 3).map((imgId, idx) => {
                        const showOverlay = idx === 2 && images.length > 3
                        const remaining = images.length - 3
                        return (
                            <div key={imgId} className="relative aspect-square rounded-lg overflow-hidden bg-zinc-900 border border-white/5">
                                {/* eslint-disable-next-line @next/next/no-img-element */}
                                <img
                                    src={`${API_BASE_URL}/images/${imgId}`}
                                    alt={`Memory ${idx + 1}`}
                                    className="h-full w-full object-cover"
                                    loading="lazy"
                                />
                                {showOverlay && (
                                    <div className="absolute inset-0 bg-black/60 flex items-center justify-center">
                                        <span className="text-xs font-semibold text-white">
                                            +{remaining} more
                                        </span>
                                    </div>
                                )}
                            </div>
                        )
                    })}
                </div>
            )}

            {/* Actions */}
            <div className="flex items-center gap-3">
                <Button
                    size="sm"
                    onClick={handleShare}
                    disabled={status === "loading"}
                    className="h-9 px-4 rounded-lg bg-accent-gold text-black font-semibold text-xs hover:bg-accent-gold/90 transition-transform active:scale-[0.98] flex items-center gap-1.5 shadow-md shadow-accent-gold/10"
                >
                    {status === "loading" ? (
                        <Spinner size="sm" />
                    ) : (
                        <>
                            <Share2 className="h-3.5 w-3.5" />
                            Prism Share
                        </>
                    )}
                </Button>
                <Button
                    size="sm"
                    variant="ghost"
                    onClick={handleSkip}
                    disabled={status === "loading"}
                    className="h-9 px-4 rounded-lg hover:bg-white/10 text-zinc-400 hover:text-white font-medium text-xs flex items-center gap-1 transition-colors"
                >
                    <X className="h-3.5 w-3.5" />
                    Skip
                </Button>
            </div>
        </div>
    )
}
