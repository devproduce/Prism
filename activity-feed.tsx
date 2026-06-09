"use client"

import { useRouter } from "next/navigation"
import { formatDistanceToNow, isToday, isYesterday, isThisWeek, isThisMonth } from "date-fns"
import { ProfileAvatar } from "@/components/ui/profile-avatar"
import { Button } from "@/components/ui/button"
import { Check, X, ChevronRight } from "lucide-react"
import { apiClient } from "@/lib/api"
import { useAuth } from "@/contexts/auth-context"
import { cn } from "@/lib/utils"
import { RetroactiveSharePrompt } from "@/components/recommendations/RetroactiveSharePrompt"

const ACTION_VERBS_REGEX = /(.*?)( started| requested| liked| commented| shared)(.*)/;

function ActivityTitle({ title }: { title: string }) {
    const match = title.match(ACTION_VERBS_REGEX);
    if (match) {
        return (
            <>
                <b>{match[1]}</b>
                {match[2]}
                {match[3]}
            </>
        );
    }
    return <>{title}</>;
}

export interface ActivityItem {
    id: string | number
    date: Date
    type: 'notification' | 'request_sent' | 'request_received'
    title: string
    subtitle?: string
    image?: string
    data: any
}

interface ActivityFeedProps {
    activities: ActivityItem[]
    onAccept?: (id: number) => void
    onDecline?: (id: number) => void
    onNavigateToRequests?: () => void
    friendRequestsCount?: number
    friendRequestsPreview?: { username: string, profile_pic_id?: string }[]
    showFriendRequestsHeader?: boolean
    /** Called after a retroactive share prompt is acted on (Share or Skip) — use to re-fetch data */
    onRetroactiveSuccess?: () => void
}

export function ActivityFeed({
    activities,
    onAccept,
    onDecline,
    onNavigateToRequests,
    friendRequestsCount = 0,
    friendRequestsPreview = [],
    showFriendRequestsHeader = false,
    onRetroactiveSuccess
}: ActivityFeedProps) {
    const router = useRouter()
    const { user } = useAuth()

    const groupedConfirm: Record<string, ActivityItem[]> = {
        'Today': [],
        'Yesterday': [],
        'This Week': [],
        'This Month': [],
        'Earlier': []
    }

    // Grouping Logic
    const grouped = activities.reduce((acc, item) => {
        if (isToday(item.date)) acc['Today'].push(item)
        else if (isYesterday(item.date)) acc['Yesterday'].push(item)
        else if (isThisWeek(item.date)) acc['This Week'].push(item)
        else if (isThisMonth(item.date)) acc['This Month'].push(item)
        else acc['Earlier'].push(item)
        return acc
    }, groupedConfirm)

    const orderedKeys = ['Today', 'Yesterday', 'This Week', 'This Month', 'Earlier']

    // Internal handler if not provided
    const handleAccept = async (id: number) => {
        if (onAccept) {
            onAccept(id)
            return
        }
        if (!user) return
        try {
            await apiClient(`/friends/${id}/accept`, {
                method: "POST",
                body: { user_id: user.id }
            })
            // If we manipulate local state it would be hard here without parent control, 
            // so we assume parent handles state update or we force reliance on props only.
            // For now, let's just log or reload. Real usage should pass onAccept.
            router.refresh()
        } catch (e) {
            console.error(e)
        }
    }

    const handleDecline = async (id: number) => {
        if (onDecline) {
            onDecline(id)
            return
        }
        if (!user) return
        try {
            await apiClient(`/friends/${id}/reject`, {
                method: "POST",
                body: { user_id: user.id }
            })
            router.refresh()
        } catch (e) {
            console.error(e)
        }
    }

    return (
        <div className="space-y-6">
            {/* Friend Requests Header (Optional) */}
            {showFriendRequestsHeader && friendRequestsCount > 0 && (
                <>
                    <div
                        className="flex items-center justify-between py-2 cursor-pointer group px-2 rounded-xl hover:bg-white/5 transition-colors -mx-2"
                        onClick={onNavigateToRequests || (() => router.push('/notifications/requests'))}
                    >
                        <div className="flex items-center space-x-3">
                            <div className="relative w-10 h-10">
                                {friendRequestsCount === 1 ? (
                                    <ProfileAvatar
                                        profilePicId={friendRequestsPreview[0]?.profile_pic_id}
                                        name={friendRequestsPreview[0]?.username}
                                        size="md"
                                    />
                                ) : (
                                    <div className="relative w-10 h-10">
                                        <ProfileAvatar
                                            profilePicId={friendRequestsPreview[0]?.profile_pic_id}
                                            name={friendRequestsPreview[0]?.username}
                                            size="sm"
                                            className="absolute top-0 left-0 ring-2 ring-background z-10"
                                        />
                                        <div className="absolute bottom-0 right-0 w-6 h-6 rounded-full bg-zinc-800 ring-2 ring-background flex items-center justify-center text-[10px] font-bold">
                                            +{friendRequestsCount - 1}
                                        </div>
                                    </div>
                                )}
                            </div>
                            <div>
                                <p className="font-bold text-white text-sm">Friend Requests</p>
                                <p className="text-zinc-500 text-xs text-left">Approve or ignore</p>
                            </div>
                        </div>
                        <div className="flex items-center space-x-2">
                            <div className="w-1.5 h-1.5 rounded-full bg-accent-gold"></div>
                            <ChevronRight className="w-4 h-4 text-zinc-500" />
                        </div>
                    </div>
                    <div className="h-px bg-white/10" />
                </>
            )}

            {/* Timeline */}
            {orderedKeys.map(key => {
                const items = grouped[key]
                if (!items || items.length === 0) return null

                return (
                    <div key={key} className="space-y-3">
                        <h3 className="font-bold text-white text-sm px-2">{key}</h3>
                        <div className="space-y-3">
                            {items.map(item => {
                                const isContactFound = item.type === 'notification' && item.data?.type === 'contact_found_in_batch';
                                const isRetroactivePrompt = item.type === 'notification' && item.data?.type === 'retroactive_share_prompt';

                                if (isRetroactivePrompt) {
                                    const meta = typeof item.data.metadata === 'string' ? (() => {
                                        try { return JSON.parse(item.data.metadata); } catch { return {}; }
                                    })() : item.data.metadata || {};
                                    return (
                                        <div key={item.id} className="w-full px-2" onClick={(e) => e.stopPropagation()}>
                                            <RetroactiveSharePrompt
                                                notificationId={item.data.id}
                                                friendId={meta.friend_id}
                                                friendUsername={meta.friend_username}
                                                matchedFaceIds={meta.matched_face_ids}
                                                contactFaceIds={meta.contact_face_ids}
                                                unknownFaceIds={meta.unknown_face_ids}
                                                imageIds={meta.image_ids}
                                                onSuccess={onRetroactiveSuccess || (() => router.refresh())}
                                            />
                                        </div>
                                    );
                                }

                                return (
                                    <div
                                        key={item.id}
                                        className={cn(
                                            "flex items-start justify-between px-2 py-1.5 group transition-colors rounded-xl",
                                            isContactFound && "cursor-pointer hover:bg-white/5"
                                        )}
                                        onClick={() => {
                                            if (isContactFound) {
                                                const meta = typeof item.data.metadata === 'string' ? (() => {
                                                    try { return JSON.parse(item.data.metadata); } catch { return {}; }
                                                })() : item.data.metadata || {};
                                                if (meta.contact_name) {
                                                    router.push(`/friends?search=${encodeURIComponent(meta.contact_name)}`);
                                                }
                                            }
                                        }}
                                    >
                                        <div className="flex items-start space-x-3 max-w-[80%]">
                                            <ProfileAvatar
                                                profilePicId={item.image}
                                                name={item.title.split(' ')[0]}
                                                size="sm"
                                                className="mt-0.5"
                                            />
                                            <div>
                                                <p className="text-sm text-white leading-tight">
                                                    <span>
                                                        <ActivityTitle title={item.title} />
                                                    </span>
                                                </p>
                                                <p className="text-[10px] text-zinc-500 mt-0.5">
                                                    {formatDistanceToNow(item.date, { addSuffix: true })}
                                                </p>
                                            </div>
                                        </div>

                                        {/* Action Buttons */}
                                        {item.type === 'request_received' ? (
                                            <div className="flex items-center space-x-1">
                                                <Button
                                                    size="icon"
                                                    className="h-7 w-7 rounded-sm bg-accent-gold text-black hover:bg-accent-gold/90"
                                                    onClick={(e) => {
                                                        e.stopPropagation();
                                                        handleAccept(item.data.friendship_id);
                                                    }}
                                                    title="Confirm"
                                                >
                                                    <Check className="h-4 w-4" />
                                                </Button>
                                                <Button
                                                    size="icon"
                                                    variant="secondary"
                                                    className="h-7 w-7 rounded-sm bg-zinc-800 text-zinc-400 hover:bg-zinc-700 hover:text-white"
                                                    onClick={(e) => {
                                                        e.stopPropagation();
                                                        handleDecline(item.data.friendship_id);
                                                    }}
                                                    title="Delete"
                                                >
                                                    <X className="h-4 w-4" />
                                                </Button>
                                            </div>
                                        ) : item.type === 'request_sent' ? (
                                            <Button
                                                variant="secondary"
                                                className="rounded-lg bg-zinc-800 text-zinc-400 hover:bg-zinc-800 cursor-default h-6 px-2 text-[10px] font-semibold"
                                                onClick={(e) => e.stopPropagation()}
                                            >
                                                Pending
                                            </Button>

                                        ) : item.type === 'notification' && item.data?.type === 'contact_found_in_batch' ? (
                                            <Button
                                                size="sm"
                                                variant="outline"
                                                className="h-8 rounded-full px-4 text-xs bg-white/5 border-white/10 hover:bg-white/10 text-white"
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    const meta = typeof item.data.metadata === 'string' ? (() => {
                                                        try { return JSON.parse(item.data.metadata); } catch { return {}; }
                                                    })() : item.data.metadata || {};
                                                    if (meta.contact_name) {
                                                        router.push(`/friends?search=${encodeURIComponent(meta.contact_name)}`);
                                                    }
                                                }}
                                            >
                                                View
                                            </Button>
                                        ) : (
                                            /* General Notification Actions if any */
                                            /* Removing 'Message' button as requested */
                                            null
                                        )}
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                )
            })}
            {activities.length === 0 && (
                <div className="py-8 text-center text-sm text-zinc-500">
                    No new activity
                </div>
            )}
        </div>
    )
}
