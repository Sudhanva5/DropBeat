chrome.runtime.onInstalled.addListener(() => {
    console.log('DropBeat extension installed');
});

// Handle messages from content script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === 'TRACK_INFO') {
        // Forward to WebSocket if needed
        sendResponse({ status: 'received' });
    }
});
