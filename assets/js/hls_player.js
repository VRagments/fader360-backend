import Hls from 'hls.js';

function media_hls_player(static_url) {
    if (Hls.isSupported()) {
        var media = document.getElementById('media');
        if (media !== null) {
            var hls = new Hls();
            hls.attachMedia(media);
            hls.loadSource(static_url);
            hls.attachMedia(media);
        }
    }
}

export { media_hls_player };
