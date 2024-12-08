document.addEventListener('DOMContentLoaded', function() {
    const status = document.getElementById('status');
    const title = document.getElementById('track-title');
    const artist = document.getElementById('track-artist');
    
    // Check WebSocket connection
    function checkConnection() {
        const ws = new WebSocket('ws://localhost:8089');
        
        ws.onopen = function() {
            status.textContent = 'Connected to DropBeat';
            status.className = 'status connected';
        };
        
        ws.onclose = function() {
            status.textContent = 'Disconnected from DropBeat';
            status.className = 'status disconnected';
        };
        
        ws.onmessage = function(event) {
            try {
                const data = JSON.parse(event.data);
                if (data.type === 'TRACK_INFO') {
                    title.textContent = data.data.title;
                    artist.textContent = data.data.artist;
                }
            } catch (error) {
                console.error('Error parsing message:', error);
            }
        };
    }
    
    checkConnection();
});