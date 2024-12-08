// YouTube Music Track Observer
let currentTrack = null;
let wsConnection = null;

function connectWebSocket() {
    wsConnection = new WebSocket('ws://localhost:8089');
    
    wsConnection.onopen = () => {
        console.log('Connected to DropBeat');
        updateTrackInfo();
    };
    
    wsConnection.onclose = () => {
        console.log('Disconnected from DropBeat');
        setTimeout(connectWebSocket, 5000); // Reconnect after 5 seconds
    };
}

function updateTrackInfo() {
    const songTitle = document.querySelector('.ytmusic-player-bar .title')?.textContent;
    const artist = document.querySelector('.ytmusic-player-bar .byline')?.textContent;
    const albumArt = document.querySelector('.ytmusic-player-bar img')?.src;
    const isPlaying = !document.querySelector('video')?.paused;
    
    const trackInfo = {
        title: songTitle || 'No Track Playing',
        artist: artist || 'Unknown Artist',
        albumArt,
        isPlaying
    };
    
    if (wsConnection?.readyState === WebSocket.OPEN) {
        wsConnection.send(JSON.stringify({
            type: 'TRACK_INFO',
            data: trackInfo
        }));
    }
}

// Watch for player changes
const observer = new MutationObserver(updateTrackInfo);

// Start observing
function startObserving() {
    const playerBar = document.querySelector('ytmusic-player-bar');
    if (playerBar) {
        observer.observe(playerBar, {
            subtree: true,
            childList: true,
            attributes: true
        });
        connectWebSocket();
    }
}

// Initialize
document.addEventListener('DOMContentLoaded', startObserving);