"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { useAuth } from "@/contexts/auth-context"
import { apiClient } from "@/lib/api"
import { PageWrapper } from "@/components/layout/page-wrapper"
import { Spinner } from "@/components/ui/spinner"
import { parseISO } from "date-fns"
import { ActivityFeed, ActivityItem } from "@/components/notifications/activity-feed"

interface FriendRequest {
    friendship_id: number
    username: string
    created_at: string
    profile_pic_id?: string
}

interface Notification {
    id: number
    type: string
    title: string
    message?: string
    created_at: string
    is_read: boolean
    resource_id?: string
}

export default function NotificationsPage() {
    const { user } = useAuth()
    const router = useRouter()
    const [receivedRequests, setReceivedRequests] = useState<FriendRequest[]>([])
    const [activities, setActivities] = useState<ActivityItem[]>([])
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        if (user) {
            fetchData()
        }

        const handleNewNotification = () => {
            if (user) {
                fetchData();
            }
        };

        window.addEventListener('prism-new-notification', handleNewNotification);
        return () => window.removeEventListener('prism-new-notification', handleNewNotification);
    }, [user])

    const fetchData = async () => {
        if (!user?.id) return
        try {
            const [sentData, receivedData, notifsData] = await Promise.all([
                apiClient("/friends/sent", { params: { user_id: user.id } }),
                apiClient("/friends/pending", { params: { user_id: user.id } }),
                apiClient("/notifications", { params: { user_id: user.id } }),
            ])

            setReceivedRequests((receivedData as FriendRequest[]) || [])

            const newActivities: ActivityItem[] = []

            // 1. Notifications
            if (notifsData) {
                (notifsData as Notification[]).forEach((n: Notification) => {
                    // Retroactive share prompts are actionable — once read (acted on or skipped),
                    // hide them from the feed so they don't reappear and cause re-submission errors.
                    if (n.type === 'retroactive_share_prompt' && n.is_read) return

                    // For "You shared/sent/etc.", use current user's profile_pic_id
                    let image: string | undefined = undefined
                    if (n.title.startsWith("You") && user?.profile_pic_id) {
                        image = user.profile_pic_id
                    }

                    newActivities.push({
                        id: `notif-${n.id}`,
                        date: parseISO(n.created_at),
                        type: 'notification',
                        title: n.title,
                        image: image,
                        data: n
                    })
                })
            }

            // 2. Sent Requests
            if (sentData) {
                (sentData as FriendRequest[]).forEach((r: FriendRequest) => {
                    newActivities.push({
                        id: `sent-${r.friendship_id}`,
                        date: parseISO(r.created_at),
                        type: 'request_sent',
                        title: `You requested to follow ${r.username}`,
                        image: r.profile_pic_id,
                        data: r
                    })
                })
            }

            // 3. Received Requests
            if (receivedData) {
                (receivedData as FriendRequest[]).forEach((r: FriendRequest) => {
                    const exists = newActivities.find(a => a.type === 'notification' && a.title.includes(r.username) && a.title.includes('request'))
                    if (!exists) {
                        newActivities.push({
                            id: `received-${r.friendship_id}`,
                            date: parseISO(r.created_at),
                            type: 'request_received',
                            title: `${r.username} requested to follow you`,
                            image: r.profile_pic_id,
                            data: r
                        })
                    }
                })
            }

            newActivities.sort((a, b) => b.date.getTime() - a.date.getTime())
            setActivities(newActivities)

        } catch (err) {
            console.error("Failed to fetch data", err)
        } finally {
            setLoading(false)
        }
    }

    const markAsRead = async () => {
        if (!user?.id) return
        try {
            await apiClient("/notifications/mark-read", {
                method: "POST",
                body: { user_id: user.id }
            })
        } catch (err) {
            console.error("Failed to mark notifications as read", err)
        }
    }

    const handleAccept = async (id: number) => {
        if (!user) return
        try {
            await apiClient(`/friends/${id}/accept`, {
                method: "POST",
                body: { user_id: user.id }
            })
            fetchData()
        } catch (e) {
            console.error(e)
        }
    }

    const handleDecline = async (id: number) => {
        if (!user) return
        try {
            await apiClient(`/friends/${id}/reject`, {
                method: "POST",
                body: { user_id: user.id }
            })
            fetchData()
        } catch (e) {
            console.error(e)
        }
    }

    if (loading) {
        return (
            <PageWrapper>
                <div className="flex h-full items-center justify-center">
                    <Spinner size="lg" />
                </div>
            </PageWrapper>
        )
    }

    return (
        <PageWrapper title="">
            <div className="max-w-2xl mx-auto pb-10">
                <ActivityFeed
                    activities={activities}
                    onAccept={handleAccept}
                    onDecline={handleDecline}
                    friendRequestsCount={receivedRequests.length}
                    friendRequestsPreview={receivedRequests}
                    showFriendRequestsHeader={true}
                    onRetroactiveSuccess={fetchData}
                />
            </div>
        </PageWrapper>
    )
}
