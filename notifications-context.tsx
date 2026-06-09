"use client"

import React, { createContext, useContext, useEffect, useMemo } from "react"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import { useAuth } from "./auth-context"
import { fetchNotifications, friendKeys, notificationKeys, fetchPendingFriends, fetchSentFriends } from "@/lib/queries"
import { parseISO } from "date-fns"
import { ActivityItem } from "@/components/notifications/activity-feed"
import { FriendRequest } from "@/components/notifications/friend-request-list"

interface Notification {
    id: number
    type: string
    title: string
    message?: string
    created_at: string
    is_read: boolean
    resource_id?: string
}

interface NotificationsContextValue {
    activities: ActivityItem[]
    receivedRequests: FriendRequest[]
    sentRequests: FriendRequest[]
    isLoading: boolean
    refetch: () => void
}

const NotificationsContext = createContext<NotificationsContextValue | undefined>(undefined)

export function NotificationsProvider({ children }: { children: React.ReactNode }) {
    const { user } = useAuth()
    const queryClient = useQueryClient()

    const { data: notifications = [], isPending: isLoadingNotifs } = useQuery({
        queryKey: notificationKeys.all(user?.id || ''),
        queryFn: () => fetchNotifications(user!.id),
        enabled: !!user?.id,
    })

    const { data: receivedRequests = [], isPending: isLoadingPending } = useQuery({
        queryKey: friendKeys.pending(user?.id || ''),
        queryFn: () => fetchPendingFriends(user!.id),
        enabled: !!user?.id,
    })

    const { data: sentRequests = [], isPending: isLoadingSent } = useQuery({
        queryKey: friendKeys.sent(user?.id || ''),
        queryFn: () => fetchSentFriends(user!.id),
        enabled: !!user?.id,
    })

    const refetch = () => {
        if (user?.id) {
            queryClient.invalidateQueries({ queryKey: notificationKeys.all(user.id) })
            queryClient.invalidateQueries({ queryKey: friendKeys.pending(user.id) })
            queryClient.invalidateQueries({ queryKey: friendKeys.sent(user.id) })
        }
    }

    useEffect(() => {
        const handleNewNotification = () => {
            if (user?.id) refetch();
        };

        window.addEventListener('prism-new-notification', handleNewNotification);
        return () => window.removeEventListener('prism-new-notification', handleNewNotification);
    }, [user])

    const activities = useMemo(() => {
        const newActivities: ActivityItem[] = []

        if (notifications) {
            (notifications as Notification[]).forEach((n: Notification) => {
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

        sentRequests.forEach((r: FriendRequest) => {
            newActivities.push({
                id: `sent-${r.friendship_id}`,
                date: parseISO(r.created_at),
                type: 'request_sent',
                title: `You requested to follow ${r.username}`,
                image: r.profile_pic_id,
                data: r
            })
        })

        receivedRequests.forEach((r: FriendRequest) => {
            const exists = newActivities.find(a => a.type === 'notification' && a.title.includes(r.username) && a.title.includes('request'))
            if (exists) {
                const idx = newActivities.indexOf(exists)
                if (idx > -1) newActivities.splice(idx, 1)
            }

            newActivities.push({
                id: `received-${r.friendship_id}`,
                date: parseISO(r.created_at),
                type: 'request_received',
                title: `${r.username} requested to follow you`,
                image: r.profile_pic_id,
                data: r
            })
        })

        newActivities.sort((a, b) => b.date.getTime() - a.date.getTime())
        return newActivities
    }, [notifications, sentRequests, receivedRequests, user?.profile_pic_id])

    return (
        <NotificationsContext.Provider value={{
            activities,
            receivedRequests,
            sentRequests,
            isLoading: isLoadingNotifs || isLoadingPending || isLoadingSent,
            refetch
        }}>
            {children}
        </NotificationsContext.Provider>
    )
}

export function useNotifications() {
    const context = useContext(NotificationsContext)
    if (context === undefined) {
        throw new Error("useNotifications must be used within a NotificationsProvider")
    }
    return context
}
