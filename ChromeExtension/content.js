console.log('🎵 [DropBeat] Content script loaded for YouTube Music');

let isConnected = false;
let lastTrackInfo = null;
let currentTrackId = null;
let lastTrackSignature = null;

// Listen for messages from background script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    console.log('📥 [DropBeat] Content received message:', message);

    try {
        if (message.type === 'CONNECTION_STATUS') {
            const oldState = isConnected;
            isConnected = message.status.isConnected;
            console.log('🔌 [DropBeat] Connection status updated:', isConnected);
            
            // If we just got connected, send initial track info
            if (!oldState && isConnected) {
                console.log('🎵 [DropBeat] Initially connected, sending track info');
                updateTrackInfo(true); // force update
            }
            sendResponse({ received: true });
        } else if (message.type === 'COMMAND') {
            console.log('🎮 [DropBeat] Handling command:', message.command, 'with data:', message.data);
            handleCommand(message.command, message);
            sendResponse({ received: true });
        } else if (message.type === 'PING') {
            console.log('🏓 [DropBeat] Ping received, sending pong');
            sendResponse({ pong: true });
        }
    } catch (error) {
        console.error('❌ [DropBeat] Error handling message:', error);
        sendResponse({ error: error.message });
    }
    
    return true; // Keep the message channel open for async response
});

function findElement(selectors) {
    for (const selector of selectors) {
        const element = document.querySelector(selector);
        if (element) return element;
    }
    return null;
}

function handleCommand(command, message) {
    console.log('🎮 [DropBeat] Handling command:', command, 'with full message:', message);
    
    // Define multiple selectors for each control, ordered by reliability
    const selectors = {
        playPause: [
            // By aria-label
            'button[aria-label*="Play"], button[aria-label*="Pause"]',
            // By class
            '.play-pause-button',
            // By role and title
            'button[role="button"][title*="Play"], button[role="button"][title*="Pause"]',
            // By data attribute
            '[data-testid="play-pause-button"]',
            // Generic player controls
            '.ytmusic-player-bar button[aria-label*="Play"], .ytmusic-player-bar button[aria-label*="Pause"]'
        ],
        next: [
            'button[aria-label*="Next"]',
            '.next-button',
            'button[role="button"][title*="Next"]',
            '[data-testid="next-button"]',
            '.ytmusic-player-bar button[aria-label*="Next"]'
        ],
        previous: [
            'button[aria-label*="Previous"]',
            '.previous-button',
            'button[role="button"][title*="Previous"]',
            '[data-testid="previous-button"]',
            '.ytmusic-player-bar button[aria-label*="Previous"]'
        ],
        like: [
            'ytmusic-like-button-renderer',
            'button[aria-label*="like"]',
            '[data-testid="like-button-renderer"]'
        ]
    };
    
    try {
        switch (command) {
            case 'play':
            case 'pause': {
                const button = findElement(selectors.playPause);
                if (button) {
                    console.log('▶️ [DropBeat] Found play/pause button, clicking...');
                    // Store current track info before clicking
                    const prevTrackInfo = lastTrackInfo;
                    button.click();
                    // Update track info with reversed playing state
                    if (prevTrackInfo) {
                        const updatedTrackInfo = {
                            ...prevTrackInfo,
                            isPlaying: !prevTrackInfo.isPlaying
                        };
                        lastTrackInfo = updatedTrackInfo;
                        // Send immediate update
                        chrome.runtime.sendMessage({
                            type: 'TRACK_INFO',
                            data: updatedTrackInfo
                        });
                    }
                } else {
                    console.warn('⚠️ [DropBeat] Play/pause button not found');
                }
                break;
            }
            case 'seek': {
                const video = document.querySelector('video');
                if (video && message?.data?.position !== undefined) {
                    const position = Number(message.data.position);
                    if (isNaN(position)) {
                        console.warn('⚠️ [DropBeat] Invalid seek position:', message.data.position);
                        return;
                    }
                    
                    console.log('⏩ [DropBeat] Seeking to position:', position);
                    
                    try {
                        // Store current track info before seeking
                        const prevTrackInfo = lastTrackInfo;
                        
                        // Set the video position
                        video.currentTime = position;
                        
                        // Force video to play if it was playing
                        if (prevTrackInfo?.isPlaying) {
                            video.play();
                        }
                        
                        // Update track info immediately
                        if (prevTrackInfo) {
                            const updatedTrackInfo = {
                                ...prevTrackInfo,
                                currentTime: position
                            };
                            lastTrackInfo = updatedTrackInfo;
                            
                            console.log('📤 [DropBeat] Sending updated track info after seek:', updatedTrackInfo);
                            chrome.runtime.sendMessage({
                                type: 'TRACK_INFO',
                                data: updatedTrackInfo
                            });
                        }
                    } catch (error) {
                        console.error('❌ [DropBeat] Error seeking:', error);
                    }
                } else {
                    console.warn('⚠️ [DropBeat] Video element not found or invalid position:', {
                        videoFound: !!video,
                        position: message?.data?.position
                    });
                }
                break;
            }
            case 'next': {
                const button = findElement(selectors.next);
                if (button) {
                    console.log('⏭️ [DropBeat] Found next button, clicking...');
                    button.click();
                } else {
                    console.warn('⚠️ [DropBeat] Next button not found');
                }
                break;
            }
            case 'previous': {
                const button = findElement(selectors.previous);
                if (button) {
                    console.log('⏮️ [DropBeat] Found previous button, clicking...');
                    button.click();
                } else {
                    console.warn('⚠️ [DropBeat] Previous button not found');
                }
                break;
            }
            case 'toggleLike': {
                const button = findElement(selectors.like);
                if (button) {
                    console.log('❤️ [DropBeat] Found like button, clicking...');
                    button.click();
                } else {
                    console.warn('⚠️ [DropBeat] Like button not found');
                }
                break;
            }
        }
    } catch (error) {
        console.error('❌ [DropBeat] Error handling command:', error);
    }
}

function getTrackInfo() {
    const video = document.querySelector('video');
    if (!video) {
        console.log('⚠️ [DropBeat] No video element found');
        return null;
    }

    // More specific selectors for YouTube Music
    const titleElement = document.querySelector('.ytmusic-player-bar .title.style-scope.ytmusic-player-bar');
    const artistElement = document.querySelector('.ytmusic-player-bar .byline.style-scope.ytmusic-player-bar');
    const albumArtElement = document.querySelector('.ytmusic-player-bar img.image.style-scope.ytmusic-player-bar');
    const likeButton = document.querySelector('ytmusic-like-button-renderer');
    
    const title = titleElement?.textContent?.trim() || 'No Track Playing';
    const artist = artistElement?.textContent?.trim() || 'Unknown Artist';
    
    // Generate a unique ID based on title and artist if it's a new track
    const trackSignature = `${title}-${artist}`;
    if (trackSignature !== lastTrackSignature) {
        currentTrackId = crypto.randomUUID();
        lastTrackSignature = trackSignature;
    }

    console.log('🔍 [DropBeat] Found elements:', {
        title: title,
        artist: artist,
        albumArt: albumArtElement?.src,
        video: video ? 'Yes' : 'No',
        isPlaying: !video.paused,
        currentTime: video.currentTime,
        duration: video.duration
    });

    return {
        id: currentTrackId,
        title: title,
        artist: artist,
        albumArt: albumArtElement?.src,
        isPlaying: !video.paused,
        currentTime: video.currentTime,
        duration: video.duration || 0,
        isLiked: likeButton?.getAttribute('like-status') === 'LIKE'
    };
}

function updateTrackInfo(force = false) {
    if (!isConnected) {
        console.log('⏳ [DropBeat] Not connected, skipping track update');
        return;
    }

    const trackInfo = getTrackInfo();
    if (!trackInfo) return;

    // Send if forced or if info has changed
    if (force || JSON.stringify(trackInfo) !== JSON.stringify(lastTrackInfo)) {
        console.log('🎵 [DropBeat] Sending track info:', trackInfo);
        lastTrackInfo = trackInfo;

        chrome.runtime.sendMessage({
            type: 'TRACK_INFO',
            data: trackInfo
        }, response => {
            if (response?.sent) {
                console.log('✅ [DropBeat] Track info sent successfully');
            } else {
                console.log('⚠️ [DropBeat] Failed to send track info');
            }
        });
    }
}

function observePlayer() {
    console.log('👀 [DropBeat] Setting up player observers');

    // Watch for player bar changes
    const playerBar = document.querySelector('ytmusic-player-bar');
    if (playerBar) {
        const observer = new MutationObserver((mutations) => {
            console.log('👁️ [DropBeat] Player changes detected');
            updateTrackInfo();
        });

        observer.observe(playerBar, {
            subtree: true,
            childList: true,
            attributes: true
        });
        console.log('✅ [DropBeat] Player bar observer set up');
    }

    // Watch video element
    const video = document.querySelector('video');
    if (video) {
        video.addEventListener('play', () => {
            console.log('▶️ [DropBeat] Video play event');
            updateTrackInfo(true);
        });

        video.addEventListener('pause', () => {
            console.log('⏸️ [DropBeat] Video pause event');
            updateTrackInfo(true);
        });

        video.addEventListener('seeked', () => {
            console.log('⏩ [DropBeat] Video seek event');
            updateTrackInfo(true);
        });

        console.log('✅ [DropBeat] Video element listeners set up');
    }
}

// Start observing when page is ready
function initialize() {
    console.log('🚀 [DropBeat] Initializing content script');
    
    // Check if we're already on YouTube Music
    if (document.querySelector('ytmusic-player-bar')) {
        observePlayer();
        updateTrackInfo(true);
    } else {
        // Wait for player to be ready
        const observer = new MutationObserver((mutations, obs) => {
            if (document.querySelector('ytmusic-player-bar')) {
                console.log('✅ [DropBeat] Player detected, starting observation');
                obs.disconnect();
                observePlayer();
                updateTrackInfo(true);
            }
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    }
}

// Get initial connection status
chrome.runtime.sendMessage({ type: 'GET_CONNECTION_STATUS' }, (response) => {
    if (response) {
        isConnected = response.isConnected;
        console.log('🔌 [DropBeat] Initial connection status:', isConnected);
    }
});

// Start when page is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initialize);
} else {
    initialize();
}