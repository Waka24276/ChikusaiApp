window.addEventListener('load', function () {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('flutter_service_worker.js')
      .then(function (registration) {
        // 新しいService Workerがインストールされるのを監視
        registration.onupdatefound = function () {
          const installingWorker = registration.installing;
          if (installingWorker == null) {
            return;
          }
          installingWorker.onstatechange = function () {
            if (installingWorker.state === 'installed') {
              if (navigator.serviceWorker.controller) {
                // 古いService Workerがまだアクティブな場合、
                // 更新通知を表示
                console.log('New content is available and will be used when all ' +
                  'tabs for this page are closed. See https://bit.ly/CRA-PWA.');
                
                const notification = document.getElementById('update-notification');
                if (notification) {
                  notification.style.display = 'block';
                  notification.onclick = () => {
                    // Service Workerに待機をスキップするようメッセージを送信
                    installingWorker.postMessage({ type: 'SKIP_WAITING' });
                  };
                }
              }
            }
          };
        };
        // Service Workerからのメッセージをリッスン
        navigator.serviceWorker.addEventListener('message', event => {
          if (event.data && event.data.type === 'RELOAD_PAGE') {
            window.location.reload();
          }
        });
      }).catch(function (error) {
        console.error('Service Worker registration failed:', error);
      });
  }
});