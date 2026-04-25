"use client"

import { useState, useRef, useEffect, Suspense } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import Image from "next/image"
import { useAuth } from "@/contexts/auth-context"
import { apiClient } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Camera, Loader2, Sparkles, Video, RefreshCw, Eye, EyeOff, Check, X, AlertCircle } from "lucide-react"
import { cn } from "@/lib/utils"
import { FaceScanTutorial } from "@/components/auth/face-scan-tutorial"
import { parseContactsCsv } from "@/utils/csv-parser"

// Feature flag: Set to false to disable WebSocket-based multi-view registration
// This is temporarily disabled due to Mixed Content issues with Vercel (HTTPS) + AWS (HTTP)
// Re-enable once AWS CV server has WSS support
const MULTI_VIEW_ENABLED = true // Requires nginx WebSocket headers (Upgrade, Connection)

function LoginPageContent() {
    const { login } = useAuth()
    const router = useRouter()
    const searchParams = useSearchParams()
    const [activeTab, setActiveTab] = useState<"login" | "signup">(
        searchParams.get("tab") === "signup" ? "signup" : "login"
    )
    const [isLoading, setIsLoading] = useState(false)
    const [error, setError] = useState("")

    // Login Form State
    const [loginIdentifier, setLoginIdentifier] = useState("")
    const [loginPassword, setLoginPassword] = useState("")
    const [showLoginPassword, setShowLoginPassword] = useState(false)

    // Signup Form State
    const [signupUsername, setSignupUsername] = useState("")
    const [signupCountryCode, setSignupCountryCode] = useState("+91")
    const [signupPhoneNumber, setSignupPhoneNumber] = useState("")
    const [signupPassword, setSignupPassword] = useState("")
    const [signupConfirmPassword, setSignupConfirmPassword] = useState("")
    const [showSignupPassword, setShowSignupPassword] = useState(false)
    const [showSignupConfirmPassword, setShowSignupConfirmPassword] = useState(false)
    const [signupImage, setSignupImage] = useState<File | null>(null)
    const [signupCsvFile, setSignupCsvFile] = useState<File | null>(null)

    // Availability Check State
    const [usernameAvailable, setUsernameAvailable] = useState<boolean | null>(null)
    const [isCheckingUsername, setIsCheckingUsername] = useState(false)

    // Webcam State
    const videoRef = useRef<HTMLVideoElement>(null)
    const canvasRef = useRef<HTMLCanvasElement>(null)
    const streamRef = useRef<MediaStream | null>(null)
    const [isCameraActive, setIsCameraActive] = useState(false)
    const [capturedImage, setCapturedImage] = useState<string | null>(null)

    // Multi-View State
    const wsRef = useRef<WebSocket | null>(null)
    const [faceIds, setFaceIds] = useState<string[]>([])
    const [capturedIndices, setCapturedIndices] = useState<number[]>([])
    const [capturedFrames, setCapturedFrames] = useState<Record<number, string>>({}) // Map index -> frame URL
    const framesRef = useRef<Record<number, string>>({}) // Ref to track frames inside WS closure
    const [currentGridIndex, setCurrentGridIndex] = useState<number | null>(null)
    const [wsMessage, setWsMessage] = useState<string>("Align your face")
    const [isMultiViewComplete, setIsMultiViewComplete] = useState(false)

    // Webcam Functions
    const startCamera = async () => {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({
                video: { width: 1280, height: 720 }
            })
            streamRef.current = stream
            // Assign stream to video element
            if (videoRef.current) {
                videoRef.current.srcObject = stream
            }
            setIsCameraActive(true)
            setCapturedImage(null)
        } catch (err) {
            setError("Failed to access camera. Please use file upload instead.")
        }
    }

    const stopCamera = () => {
        if (streamRef.current) {
            streamRef.current.getTracks().forEach(track => track.stop())
            streamRef.current = null
        }
        setIsCameraActive(false)
        if (wsRef.current) {
            wsRef.current.close()
            wsRef.current = null
        }
    }

    const captureImage = () => {
        if (videoRef.current && canvasRef.current) {
            const video = videoRef.current
            const canvas = canvasRef.current
            canvas.width = video.videoWidth
            canvas.height = video.videoHeight
            const ctx = canvas.getContext('2d')
            if (ctx) {
                ctx.drawImage(video, 0, 0)
                const imageDataUrl = canvas.toDataURL('image/jpeg')
                setCapturedImage(imageDataUrl)

                // Convert to File for upload
                canvas.toBlob((blob) => {
                    if (blob) {
                        const file = new File([blob], "face-capture.jpg", { type: "image/jpeg" })
                        setSignupImage(file)
                    }
                }, 'image/jpeg')
            }
        }
    }

    const retakeImage = () => {
        setCapturedImage(null)
        setSignupImage(null)
        // Reset multi-view state
        setFaceIds([])
        setCapturedIndices([])
        setCapturedFrames({})
        framesRef.current = {}
        setIsMultiViewComplete(false)
        setWsMessage("Align your face")
        // Restart camera for new capture
        startCamera()
    }

    // Cleanup on unmount or tab switch
    useEffect(() => {
        return () => {
            stopCamera()
        }
    }, [])

    useEffect(() => {
        if (activeTab === 'login') {
            stopCamera()
            setCapturedImage(null)
        } else if (activeTab === 'signup') {
            // Auto-start camera when switching to signup
            startCamera()
        }
    }, [activeTab])

    // Effect to assign stream to video element when it becomes available
    useEffect(() => {
        if (isCameraActive && !capturedImage && videoRef.current && streamRef.current) {
            videoRef.current.srcObject = streamRef.current
        }
    }, [isCameraActive, capturedImage])

    // Debounced Username Check
    useEffect(() => {
        const checkUsername = async () => {
            if (signupUsername.length < 3) {
                setUsernameAvailable(null)
                return
            }

            setIsCheckingUsername(true)
            try {
                const response = await apiClient("/auth/check-availability", {
                    params: { type: "username", value: signupUsername }
                })
                setUsernameAvailable(response.available)
            } catch (error) {
                console.error("Failed to check username availability", error)
                setUsernameAvailable(null)
            } finally {
                setIsCheckingUsername(false)
            }
        }

        const timeoutId = setTimeout(() => {
            if (activeTab === 'signup' && signupUsername) {
                checkUsername()
            }
        }, 500)

        return () => clearTimeout(timeoutId)
    }, [signupUsername, activeTab])

    const handleCheckEmail = async () => {
        // Removed: email availability check no longer needed
    }

    const handleLogin = async (e: React.FormEvent) => {
        e.preventDefault()
        setIsLoading(true)
        setError("")

        try {
            const response = await apiClient("/auth/login", {
                method: "POST",
                body: { identifier: loginIdentifier, password: loginPassword },
            })

            const user = {
                ...response,
                id: response.user_id,
            }

            login(user)
            router.push("/gallery")
        } catch (err: any) {
            setError(err.message || "Login failed")
        } finally {
            setIsLoading(false)
        }
    }

    const handleSignup = async (e: React.FormEvent) => {
        e.preventDefault()
        setIsLoading(true)
        setError("")

        // Client-side validation for instant feedback
        if (signupUsername.length < 3) {
            setError("Username must be at least 3 characters")
            setIsLoading(false)
            return
        }

        if (signupPassword.length < 6) {
            setError("Password must be at least 6 characters")
            setIsLoading(false)
            return
        }

        if (signupPassword !== signupConfirmPassword) {
            setError("Passwords do not match")
            setIsLoading(false)
            return
        }

        if (usernameAvailable === false) {
            setError("Username is already taken")
            setIsLoading(false)
            return
        }

        if (!signupImage) {
            setError("Please capture or upload a profile photo")
            setIsLoading(false)
            return
        }

        try {
            const formData = new FormData()
            formData.append("username", signupUsername)
            formData.append("password", signupPassword)
            formData.append("country_code", signupCountryCode)
            formData.append("phone_number", signupPhoneNumber)
            formData.append("image", signupImage)

            if (faceIds.length > 0) {
                formData.append("face_ids", JSON.stringify(faceIds))
            }

            const response = await apiClient("/auth/register", {
                method: "POST",
                body: formData,
            })

            // Auto-login
            const user = {
                ...response,
                id: response.user_id,
            }

            login(user)

            // Wait a moment for auth context to settle, then process optional CSV logic
            if (signupCsvFile) {
                try {
                    const text = await signupCsvFile.text()
                    const parsedResult = parseContactsCsv(text, signupCountryCode || "+91")
                    if (parsedResult.contacts.length > 0) {
                        await apiClient("/contacts/sync", {
                            method: "POST",
                            body: {
                                user_id: user.id,
                                contacts: parsedResult.contacts
                            }
                        })
                        console.log(`Synced ${parsedResult.contacts.length} contacts automatically on signup! (Skipped ${parsedResult.skipped_count})`)
                    }
                } catch (e) {
                    console.error("Failed to sync initial CSV contacts during signup", e)
                    // Non-blocking error
                }
            }

            router.push("/gallery")
        } catch (err: any) {
            setError(err.message || "Registration failed")
        } finally {
            setIsLoading(false)
        }
    }

    // WebSocket Logic (disabled when MULTI_VIEW_ENABLED is false)
    useEffect(() => {
        // Skip WebSocket connection if multi-view is disabled
        if (!MULTI_VIEW_ENABLED) {
            return
        }

        if (activeTab !== 'signup' || !isCameraActive || isMultiViewComplete) {
            return
        }

        // Prevent double connection
        if (wsRef.current?.readyState === WebSocket.OPEN || wsRef.current?.readyState === WebSocket.CONNECTING) {
            console.log("WS already active")
            return
        }

        let wsUrl = process.env.NEXT_PUBLIC_CV_WS_URL || "ws://localhost:8000/ws/register_multi_views"

        // Ensure the URL points to the correct WebSocket endpoint
        // This handles cases where the env var is just the base URL (e.g. wss://app.onrender.com)
        if (!wsUrl.includes("/ws/register_multi_views")) {
            if (wsUrl.endsWith("/")) {
                wsUrl = wsUrl.slice(0, -1)
            }
            wsUrl += "/ws/register_multi_views"
        }

        console.log("Connecting to:", wsUrl)

        const socket = new WebSocket(wsUrl)
        wsRef.current = socket

        socket.onopen = () => {
            console.log("✓ Connected to CV service")
            setWsMessage("Connected. Align your face.")
        }

        socket.onmessage = (event) => {
            const data = JSON.parse(event.data)
            // console.log("← WS Message:", data)

            if (data.status === "processing") {
                const newIndices: number[] = data.captured_indices || []

                // Check if we have any new indices that we haven't captured a frame for yet
                let stateUpdated = false

                newIndices.forEach(index => {
                    // If we haven't captured this index yet
                    if (!framesRef.current[index] && videoRef.current && canvasRef.current) {
                        const video = videoRef.current

                        // Only capture if video is playing/ready
                        if (video.readyState === 4) { // HAVE_ENOUGH_DATA
                            const canvas = canvasRef.current
                            canvas.width = video.videoWidth
                            canvas.height = video.videoHeight
                            const ctx = canvas.getContext('2d')

                            if (ctx) {
                                ctx.drawImage(video, 0, 0)
                                const frameUrl = canvas.toDataURL('image/jpeg', 0.7)
                                framesRef.current[index] = frameUrl
                                stateUpdated = true
                            }
                        }
                    }
                })

                if (stateUpdated) {
                    setCapturedFrames({ ...framesRef.current })
                }

                setCapturedIndices(newIndices)
                if (data.current_pose) {
                    setCurrentGridIndex(data.current_pose.grid_index)
                } else {
                    setCurrentGridIndex(null)
                }
                setWsMessage(data.message || "Processing...")
            } else if (data.status === "completed") {
                setIsMultiViewComplete(true)
                setWsMessage("Face ID Setup Complete!")
                if (data.backend_data?.face_ids) {
                    setFaceIds(data.backend_data.face_ids)
                }

                // Ensure all frames are captured (fix for black last frame)
                if (videoRef.current && canvasRef.current) {
                    const video = videoRef.current
                    // Only capture if video is playing/ready
                    if (video.readyState === 4) {
                        const canvas = canvasRef.current
                        canvas.width = video.videoWidth
                        canvas.height = video.videoHeight
                        const ctx = canvas.getContext('2d')
                        if (ctx) {
                            // Fill any missing spots caused by race condition
                            const allIndices = [0, 1, 2]
                            let filledMissing = false
                            allIndices.forEach(idx => {
                                if (!framesRef.current[idx]) {
                                    ctx.drawImage(video, 0, 0)
                                    framesRef.current[idx] = canvas.toDataURL('image/jpeg', 0.7)
                                    filledMissing = true
                                }
                            })
                            if (filledMissing) {
                                setCapturedFrames({ ...framesRef.current })
                            }
                        }
                    }
                }

                // Auto-capture profile pic (use center frame/index 1 if available, else current frame)
                if (framesRef.current[1]) {
                    const centerFrame = framesRef.current[1]
                    setCapturedImage(centerFrame) // Ensure this is set for UI consistency

                    fetch(centerFrame)
                        .then(res => res.blob())
                        .then(blob => {
                            const file = new File([blob], "face-capture.jpg", { type: "image/jpeg" })
                            setSignupImage(file)
                        })
                } else {
                    captureImage()
                }

                // Delay stop slightly to ensure UI updates cleanly
                setTimeout(() => {
                    if (streamRef.current) {
                        streamRef.current.getTracks().forEach(track => track.stop())
                    }
                    socket.close()
                    wsRef.current = null
                }, 500)
            }
        }

        socket.onerror = (error) => {
            console.error("✗ WebSocket error:", error)
            setWsMessage("Connection error")
        }

        socket.onclose = (event) => {
            console.log("WebSocket closed:", event.code, event.reason || "No reason")
            wsRef.current = null
        }

        return () => {
            console.log("Cleanup: closing WebSocket")
            if (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING) {
                socket.close()
            }
            wsRef.current = null
        }
    }, [activeTab, isCameraActive, isMultiViewComplete])

    // Frame sending loop (disabled when MULTI_VIEW_ENABLED is false)
    useEffect(() => {
        // Skip frame sending if multi-view is disabled
        if (!MULTI_VIEW_ENABLED) {
            return
        }

        const interval = setInterval(() => {
            const ws = wsRef.current
            if (!ws || ws.readyState !== WebSocket.OPEN || isMultiViewComplete) {
                return
            }

            if (!videoRef.current || !canvasRef.current) {
                return
            }

            const video = videoRef.current
            const canvas = canvasRef.current

            if (video.videoWidth === 0) {
                return
            }

            const ctx = canvas.getContext('2d')
            if (!ctx) return

            canvas.width = video.videoWidth
            canvas.height = video.videoHeight
            ctx.drawImage(video, 0, 0)

            canvas.toBlob((blob) => {
                if (blob && wsRef.current?.readyState === WebSocket.OPEN) {
                    wsRef.current.send(blob)
                }
            }, 'image/jpeg', 0.8)
        }, 100)

        return () => clearInterval(interval)
    }, [isMultiViewComplete])

    return (
        <div className="flex min-h-screen w-full">
            {/* Left Side - Form */}
            <div className="flex w-full flex-col justify-center px-8 lg:w-1/2 lg:px-24 xl:px-32">
                <div className="mx-auto w-full max-w-md space-y-8">
                    <div className="space-y-2 text-center lg:text-left">
                        <div className="mb-6 inline-flex items-center justify-center">
                            <Image src="/logo.png" alt="Prism Logo" width={100} height={100} className="h-[100px] w-[100px] object-contain" />
                        </div>
                        <h1 className="text-4xl font-bold tracking-tight text-white">
                            {activeTab === "login" ? "Welcome back" : "Create an account"}
                        </h1>
                        <p className="text-muted-foreground">
                            {activeTab === "login"
                                ? "Enter your credentials to access your gallery."
                                : "Join Prism to experience intelligent photo sharing."}
                        </p>
                    </div>

                    {/* Tabs */}
                    <div className="grid w-full grid-cols-2 rounded-full bg-surface p-1">
                        <button
                            onClick={() => setActiveTab("login")}
                            className={cn(
                                "rounded-full py-2.5 text-sm font-medium transition-all duration-300",
                                activeTab === "login"
                                    ? "bg-primary text-primary-foreground shadow-sm"
                                    : "text-muted-foreground hover:text-white"
                            )}
                        >
                            Login
                        </button>
                        <button
                            onClick={() => setActiveTab("signup")}
                            className={cn(
                                "rounded-full py-2.5 text-sm font-medium transition-all duration-300",
                                activeTab === "signup"
                                    ? "bg-primary text-primary-foreground shadow-sm"
                                    : "text-muted-foreground hover:text-white"
                            )}
                        >
                            Sign Up
                        </button>
                    </div>

                    {error && (
                        <div className="rounded-xl bg-destructive/10 p-4 text-sm text-destructive border border-destructive/20">
                            {error}
                        </div>
                    )}

                    {activeTab === "login" ? (
                        <form onSubmit={handleLogin} className="space-y-5">
                            <div className="space-y-2">
                                <Input
                                    type="text"
                                    placeholder="Username"
                                    value={loginIdentifier}
                                    onChange={(e) => setLoginIdentifier(e.target.value)}
                                    required
                                    className="h-14 bg-surface border-transparent focus:bg-surface-hover"
                                />
                            </div>
                            <div className="space-y-2">
                                <div className="relative">
                                    <Input
                                        type={showLoginPassword ? "text" : "password"}
                                        placeholder="Password"
                                        value={loginPassword}
                                        onChange={(e) => setLoginPassword(e.target.value)}
                                        required
                                        className="h-14 bg-surface border-transparent focus:bg-surface-hover pr-10"
                                    />
                                    <button
                                        type="button"
                                        onClick={() => setShowLoginPassword(!showLoginPassword)}
                                        className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-white"
                                    >
                                        {showLoginPassword ? (
                                            <EyeOff className="h-5 w-5" />
                                        ) : (
                                            <Eye className="h-5 w-5" />
                                        )}
                                    </button>
                                </div>
                            </div>
                            <Button type="submit" className="w-full h-14 text-base font-semibold" disabled={isLoading}>
                                {isLoading ? <Loader2 className="mr-2 h-5 w-5 animate-spin" /> : null}
                                Sign In
                            </Button>
                        </form>
                    ) : (
                        <form onSubmit={handleSignup} className="space-y-5">
                            <div className="space-y-2 relative">
                                <Input
                                    placeholder="Username"
                                    value={signupUsername}
                                    onChange={(e) => {
                                        setSignupUsername(e.target.value)
                                        setUsernameAvailable(null) // Reset on type before debounce kicks in
                                    }}
                                    required
                                    className={cn(
                                        "h-14 bg-surface focus:bg-surface-hover pr-10",
                                        usernameAvailable === true ? "border-green-500/50 focus-visible:ring-green-500/50" :
                                            usernameAvailable === false ? "border-destructive/50 focus-visible:ring-destructive/50" :
                                                "border-transparent"
                                    )}
                                />
                                <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center justify-center">
                                    {isCheckingUsername ? (
                                        <Loader2 className="h-4 w-4 animate-spin text-muted-foreground" />
                                    ) : usernameAvailable === true ? (
                                        <Check className="h-4 w-4 text-green-500" />
                                    ) : usernameAvailable === false ? (
                                        <X className="h-4 w-4 text-destructive" />
                                    ) : null}
                                </div>
                                {usernameAvailable === false && (
                                    <p className="absolute top-full mt-0.5 text-xs text-destructive px-1">Username is already taken</p>
                                )}
                            </div>
                            <div className="grid grid-cols-3 gap-4">
                                <div className="space-y-2">
                                    <Input
                                        placeholder="+91"
                                        value={signupCountryCode}
                                        onChange={(e) => setSignupCountryCode(e.target.value)}
                                        required
                                        className="h-14 bg-surface border-transparent focus:bg-surface-hover"
                                    />
                                </div>
                                <div className="col-span-2 space-y-2">
                                    <Input
                                        placeholder="Phone Number"
                                        type="tel"
                                        value={signupPhoneNumber}
                                        onChange={(e) => setSignupPhoneNumber(e.target.value)}
                                        required
                                        className="h-14 bg-surface border-transparent focus:bg-surface-hover"
                                    />
                                </div>
                            </div>
                            <div className="space-y-2">
                                <div className="relative">
                                    <Input
                                        type={showSignupPassword ? "text" : "password"}
                                        placeholder="Password"
                                        value={signupPassword}
                                        onChange={(e) => setSignupPassword(e.target.value)}
                                        required
                                        className="h-14 bg-surface border-transparent focus:bg-surface-hover pr-10"
                                    />
                                    <button
                                        type="button"
                                        onClick={() => setShowSignupPassword(!showSignupPassword)}
                                        className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-white"
                                    >
                                        {showSignupPassword ? (
                                            <EyeOff className="h-5 w-5" />
                                        ) : (
                                            <Eye className="h-5 w-5" />
                                        )}
                                    </button>
                                </div>
                            </div>
                            <div className="space-y-2">
                                <div className="relative">
                                    <Input
                                        type={showSignupConfirmPassword ? "text" : "password"}
                                        placeholder="Confirm Password"
                                        value={signupConfirmPassword}
                                        onChange={(e) => setSignupConfirmPassword(e.target.value)}
                                        required
                                        className={cn(
                                            "h-14 bg-surface focus:bg-surface-hover pr-10",
                                            signupConfirmPassword && signupPassword === signupConfirmPassword ? "border-green-500/50 focus-visible:ring-green-500/50" :
                                                signupConfirmPassword && signupPassword !== signupConfirmPassword ? "border-destructive/50 focus-visible:ring-destructive/50" :
                                                    "border-transparent"
                                        )}
                                    />
                                    <button
                                        type="button"
                                        onClick={() => setShowSignupConfirmPassword(!showSignupConfirmPassword)}
                                        className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-white"
                                    >
                                        {showSignupConfirmPassword ? (
                                            <EyeOff className="h-5 w-5" />
                                        ) : (
                                            <Eye className="h-5 w-5" />
                                        )}
                                    </button>
                                </div>
                                {signupConfirmPassword && signupPassword !== signupConfirmPassword && (
                                    <p className="text-xs text-destructive px-1 flex items-center gap-1">
                                        <AlertCircle className="h-3 w-3" /> Passwords do not match
                                    </p>
                                )}
                            </div>
                            <div className="space-y-2">
                                <div className="relative">
                                    <Input
                                        type="file"
                                        accept="image/*"
                                        onChange={(e) => {
                                            setSignupImage(e.target.files?.[0] || null)
                                            setCapturedImage(null)
                                        }}
                                        disabled={isMultiViewComplete}
                                        className={cn(
                                            "h-14 bg-surface border-transparent focus:bg-surface-hover pt-3 file:mr-4 file:rounded-full file:border-0 file:bg-primary/10 file:px-4 file:py-1 file:text-sm file:font-semibold file:text-primary hover:file:bg-primary/20",
                                            isMultiViewComplete && "opacity-50 cursor-not-allowed"
                                        )}
                                    />
                                </div>
                                <p className="text-xs text-muted-foreground px-1">
                                    {isMultiViewComplete
                                        ? "✓ Face captured via webcam - file upload disabled"
                                        : "Or upload a photo if webcam isn't available"}
                                </p>
                            </div>

                            <div className="space-y-2 border-t border-white/5 pt-4">
                                <label className="text-sm text-muted-foreground px-1 mb-1 block">Optional: Upload Contacts (.csv, .vcf)</label>
                                <div className="relative">
                                    <Input
                                        type="file"
                                        accept=".csv,.vcf,.txt"
                                        onChange={(e) => setSignupCsvFile(e.target.files?.[0] || null)}
                                        className="h-12 bg-surface/50 border-transparent focus:bg-surface-hover file:mr-4 file:rounded-full file:border-0 file:bg-white/10 file:px-4 file:py-1 file:text-xs file:font-semibold file:text-white hover:file:bg-white/20 text-sm"
                                    />
                                </div>
                                <p className="text-xs text-muted-foreground/50 px-1 italic">
                                    Upload your phonebook export to instantly find friends.
                                </p>
                            </div>

                            <Button type="submit" className="w-full h-14 text-base font-semibold" disabled={isLoading || !signupImage}>
                                {isLoading ? <Loader2 className="mr-2 h-5 w-5 animate-spin" /> : null}
                                Create Account
                            </Button>
                        </form>
                    )}
                </div>
            </div>

            {/* Right Side - Visual */}
            <div className="relative hidden w-0 flex-1 lg:block">
                <div className="absolute inset-0 h-full w-full bg-surface">
                    {activeTab === "signup" && isCameraActive ? (
                        // Webcam View
                        <div className="absolute inset-0 flex flex-col items-center justify-center p-8">
                            <div className="relative w-full max-w-lg space-y-4">
                                <h2 className="text-2xl font-bold text-white text-center">
                                    Capture Your Face
                                </h2>

                                {/* Tutorial Animation - shown during active scanning */}
                                {!isMultiViewComplete && (
                                    <FaceScanTutorial
                                        capturedIndices={capturedIndices}
                                        currentGridIndex={currentGridIndex}
                                    />
                                )}

                                <div className="relative aspect-4/3 w-full overflow-hidden rounded-2xl bg-black">
                                    {isMultiViewComplete && Object.keys(capturedFrames).length > 0 ? (
                                        // Show captured frames grid on completion (1x3 horizontal row)
                                        <div className="h-full w-full grid grid-cols-3 grid-rows-1 gap-2 p-4 bg-surface items-center">
                                            {[0, 1, 2].map((index) => (
                                                <div key={index} className="relative overflow-hidden rounded-lg border-2 border-green-500/30 bg-black/50 aspect-square">
                                                    {capturedFrames[index] && (
                                                        <img
                                                            src={capturedFrames[index]}
                                                            alt={`Angle ${index}`}
                                                            className="h-full w-full object-cover"
                                                            style={{ transform: "scaleX(-1)" }} // Mirror effect for grid items too
                                                        />
                                                    )}
                                                </div>
                                            ))}
                                        </div>
                                    ) : capturedImage && !MULTI_VIEW_ENABLED ? (
                                        <img
                                            src={capturedImage}
                                            alt="Captured face"
                                            className="h-full w-full object-cover"
                                        />
                                    ) : (
                                        <video
                                            ref={videoRef}
                                            autoPlay
                                            playsInline
                                            muted
                                            className="h-full w-full object-cover mirror"
                                        />
                                    )}

                                    {/* Face detection overlay - only show when not complete */}
                                    {!isMultiViewComplete && (
                                        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                                            <div className="w-64 h-64 border-4 border-primary/50 rounded-full" />
                                        </div>
                                    )}
                                </div>

                                <div className="flex gap-4">
                                    {!MULTI_VIEW_ENABLED && !capturedImage && (
                                        <Button
                                            type="button"
                                            onClick={captureImage}
                                            className="w-full h-12 text-base font-semibold"
                                        >
                                            <Camera className="mr-2 h-5 w-5" />
                                            Capture Photo
                                        </Button>
                                    )}
                                    {isMultiViewComplete && (
                                        <Button
                                            type="button"
                                            onClick={retakeImage}
                                            className="w-full h-12 text-base font-semibold"
                                            variant="outline"
                                        >
                                            <RefreshCw className="mr-2 h-5 w-5" />
                                            Retake Scan
                                        </Button>
                                    )}
                                    {!isMultiViewComplete && capturedImage && (
                                        <Button
                                            type="button"
                                            onClick={retakeImage}
                                            className="w-full h-12 text-base font-semibold"
                                            variant="outline"
                                        >
                                            <RefreshCw className="mr-2 h-5 w-5" />
                                            Retake
                                        </Button>
                                    )}
                                </div>

                                {isMultiViewComplete ? (
                                    <div className="rounded-xl bg-green-500/10 p-4 text-sm text-green-500 border border-green-500/20 flex items-center justify-center">
                                        <Sparkles className="mr-2 h-4 w-4" />
                                        Face ID Setup Complete - Fill out the form to continue
                                    </div>
                                ) : (
                                    <p className="text-sm text-muted-foreground text-center">
                                        {MULTI_VIEW_ENABLED ? wsMessage : (capturedImage ? "Photo captured! Fill out the form to continue." : "Position your face in the circle and click Capture")}
                                    </p>
                                )}
                            </div>

                            {/* Hidden canvas for image capture */}
                            <canvas ref={canvasRef} className="hidden" />
                        </div>
                    ) : (
                        // Default 3D Model View
                        <>
                            <div className="absolute inset-0 flex items-center justify-center">
                                <div className="relative h-[500px] w-[500px]">
                                    <Image src="/face_scan.png" alt="Face Scan" fill className="object-contain opacity-80" />
                                    <div className="absolute inset-0 bg-linear-to-t from-surface via-transparent to-transparent" />
                                </div>
                            </div>
                            <div className="absolute bottom-0 left-0 right-0 p-20">
                                <blockquote className="space-y-2">
                                    <p className="text-lg font-medium text-white">
                                        &ldquo;Prism has completely transformed how I organize my memories. The face recognition is like magic.&rdquo;
                                    </p>
                                    <footer className="text-sm text-muted-foreground">Neil Gala</footer>
                                </blockquote>
                            </div>
                        </>
                    )}
                </div>
            </div>
        </div>
    )
}

export default function LoginPage() {
    return (
        <Suspense>
            <LoginPageContent />
        </Suspense>
    )
}
