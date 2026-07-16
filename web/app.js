// このスクリプトは、アプリの新しいバージョンがデプロイされたかを定期的にチェックし、
// 更新があればユーザーに通知します。

window.addEventListener('load', function () {
  // アプリの初回読み込み時のバージョンを保存
  let initialVersion;
  // 1分ごとに更新をチェック
  const checkInterval = 60 * 1000;

  // サーバーから最新のindex.htmlを取得する関数
  async function fetchLatestVersion() {
    try {
      // キャッシュをバイパスして、常にサーバーから最新のindex.htmlを取得
      const response = await fetch('/index.html?t=' + new Date().getTime(), {
        cache: 'no-store',
      });
      const htmlText = await response.text();
      return htmlText;
    } catch (error) {
      console.error('Failed to check for updates:', error);
      return null;
    }
  }

  // 更新通知を表示する関数
  function showUpdateNotification() {
    const notification = document.getElementById('update-notification');
    if (notification) {
      notification.style.display = 'block';
      notification.onclick = () => {
        // ページを強制的に再読み込みして更新を適用
        window.location.reload(true);
      };
    }
  }

  // ページ読み込み時に最初のバージョンを取得し、定期チェックを開始
  fetchLatestVersion().then(html => {
    if (html) {
      initialVersion = html;
      setInterval(async () => {
        const latestVersion = await fetchLatestVersion();
        // 読み込み時と現在のバージョンが異なれば、更新があったと判断
        if (latestVersion && initialVersion !== latestVersion) {
          showUpdateNotification();
        }
      }, checkInterval);
    }
  });
});