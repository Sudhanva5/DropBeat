console.log('🎵 [DropBeat] Content script loaded for YouTube Music');

let isConnected = false;
let lastTrackInfo = null;

// Listen for messages from background script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    console.log('📥 [DropBeat] Content received message:', message);

    if (message.type === 'CONNECTION_STATUS') {
        const oldState = isConnected;
        isConnected = message.status.isConnected;
        console.log('🔌 [DropBeat] Connection status updated:', isConnected);
        
        // If we just got connected, send initial track info
        if (!oldState && isConnected) {
            console.log('🎵 [DropBeat] Initially connected, sending track info');
            updateTrackInfo(true); // force update
        }
    }
});

function getTrackInfo() {
    const video = document.querySelector('video');
    if (!video) {
        console.log('⚠️ [DropBeat] No video element found');
        return null;
    }

    const titleElement = document.querySelector('ytmusic-player-bar .title');
    const artistElement = document.querySelector('ytmusic-player-bar .byline');
    const albumArtElement = document.querySelector('ytmusic-player-bar img');
    const likeButton = document.querySelector('ytmusic-like-button-renderer');

    console.log('🔍 [DropBeat] Found elements:', {
        title: titleElement?.textContent,
        artist: artistElement?.textContent,
        albumArt: albumArtElement ? 'Yes' : 'No',
        video: video ? 'Yes' : 'No'
    });

    return {
        title: titleElement?.textContent || 'No Track Playing',
        artist: artistElement?.textContent || 'Unknown Artist',
        albumArt: albumArtElement?.src,
        isPlaying: !video.paused,
        currentTime: video.currentTime,
        duration: video.duration,
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