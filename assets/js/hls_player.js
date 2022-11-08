import Hls from 'hls.js';

function media_hls_player() {
    if (Hls.isSupported()) {
        var media = document.getElementById('media');
        if (media !== null) {
            var static_url = document.getElementById('static_url').dataset.static_url;
            var hls = new Hls();
            hls.attachMedia(media);
            hls.loadSource(static_url);
            hls.attachMedia(media);
        }
    }
}

media_hls_player();
