
import os
import re
import json

def scan_and_update_xcstrings(project_root, xcstrings_path):
    # 1. Scan for localized strings
    localized_strings = set()
    swift_files = []
    
    regex = re.compile(r'"([^"]+)"\.localized\(for: language\)')

    for root, dirs, files in os.walk(project_root):
        for file in files:
            if file.endswith(".swift"):
                file_path = os.path.join(root, file)
                swift_files.append(file_path)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    matches = regex.findall(content)
                    for match in matches:
                        localized_strings.add(match)

    print(f"Docs scanned: {len(swift_files)}")
    print(f"Found {len(localized_strings)} unique localized keys.")

    # 2. Update xcstrings
    with open(xcstrings_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    if "strings" not in data:
        data["strings"] = {}

    # Comprehensive Translation Dictionary (Restored from existing xcstrings)
    translations = {
    "--": {
        "en": "--",
        "ja": "--",
        "ko": "--",
        "zh-Hant": "--"
    },
    "[http://][USER:PASSWORD@]HOST[:PORT]": {
        "en": "[http://][USER:PASSWORD@]HOST[:PORT]",
        "ja": "[http://][USER:PASSWORD@]HOST[:PORT]",
        "ko": "[http://][USER:PASSWORD@]HOST[:PORT]",
        "zh-Hant": "[http://][USER:PASSWORD@]HOST[:PORT]"
    },
    "%@ / %@": {
        "zh-Hans": "%1$@ / %2$@",
        "en": "%@ / %@",
        "ja": "%@ / %@",
        "ko": "%@ / %@",
        "zh-Hant": "%@ / %@"
    },
    "%lld": {
        "en": "%lld",
        "ja": "%lld",
        "ko": "%lld",
        "zh-Hant": "%lld"
    },
    "%lld 分块": {
        "en": "%lld Pieces",
        "ja": "%lld ピース",
        "ko": "%lld 조각",
        "zh-Hant": "%lld 分塊"
    },
    "%lld 线程": {
        "en": "%lld Threads",
        "ja": "%lld スレッド",
        "ko": "%lld 스레드",
        "zh-Hant": "%lld 線程"
    },
    "%lld%%": {
        "en": "%lld%%",
        "ja": "%lld%%",
        "ko": "%lld%%",
        "zh-Hant": "%lld%%"
    },
    "BT 下载完成": {
        "en": "BT Download Complete",
        "ja": "BT ダウンロード完了",
        "ko": "BT 다운로드 완료",
        "zh-Hant": "BT 下載完成"
    },
    "https://example.com/trackers.txt": {
        "en": "https://example.com/trackers.txt",
        "ja": "https://example.com/trackers.txt",
        "ko": "https://example.com/trackers.txt",
        "zh-Hant": "https://example.com/trackers.txt"
    },
    "KB/s": {
        "en": "KB/s",
        "ja": "KB/s",
        "ko": "KB/s",
        "zh-Hant": "KB/s"
    },
    "MB/s": {
        "en": "MB/s",
        "ja": "MB/s",
        "ko": "MB/s",
        "zh-Hant": "MB/s"
    },
    "MotrixMac": {
        "en": "MotrixMac",
        "ja": "MotrixMac",
        "ko": "MotrixMac",
        "zh-Hant": "MotrixMac"
    },
    "RPC 错误：%@": {
        "en": "RPC Error: %@",
        "ja": "RPC エラー: %@",
        "ko": "RPC 오류: %@",
        "zh-Hant": "RPC 錯誤：%@"
    },
    "shawnrain.me@gmail.com": {
        "en": "shawnrain.me@gmail.com",
        "ja": "shawnrain.me@gmail.com",
        "ko": "shawnrain.me@gmail.com",
        "zh-Hant": "shawnrain.me@gmail.com"
    },
    "Speed": {
        "en": "Speed",
        "ja": "速度",
        "ko": "속도",
        "zh-Hant": "速度"
    },
    "Time": {
        "en": "Time",
        "ja": "時間",
        "ko": "시간",
        "zh-Hant": "時間"
    },
    "Tracker": {
        "en": "Trackers",
        "ja": "トラッカー",
        "ko": "트래커",
        "zh-Hant": "Tracker"
    },
    "v%@": {
        "en": "v%@",
        "ja": "v%@",
        "ko": "v%@",
        "zh-Hant": "v%@"
    },
    "下载中": {
        "en": "Downloading",
        "ja": "ダウンロード中",
        "ko": "다운로드 중",
        "zh-Hant": "下載中"
    },
    "下载失败": {
        "en": "Download Failed",
        "ja": "ダウンロード失敗",
        "ko": "다운로드 실패",
        "zh-Hant": "下載失敗"
    },
    "下载完成": {
        "en": "Download Complete",
        "ja": "ダウンロード完了",
        "ko": "다운로드 완료",
        "zh-Hant": "下載完成"
    },
    "不再提示": {
        "en": "Do not show again",
        "ja": "今後表示しない",
        "ko": "다시 표시 안 함",
        "zh-Hant": "不再提示"
    },
    "个任务": {
        "en": "Tasks",
        "ja": "個のタスク",
        "ko": "개 작업",
        "zh-Hant": "個任務"
    },
    "主页": {
        "en": "Home",
        "ja": "ホーム",
        "ko": "홈",
        "zh-Hant": "主頁"
    },
    "传输中": {
        "en": "Transferring",
        "ja": "転送中",
        "ko": "전송 중",
        "zh-Hant": "傳輸中"
    },
    "做种中": {
        "en": "Seeding",
        "ja": "シード中",
        "ko": "배포 중",
        "zh-Hant": "做種中"
    },
    "做种者": {
        "en": "Seeder",
        "ja": "シーダー",
        "ko": "시더",
        "zh-Hant": "做種者"
    },
    "全选": {
        "en": "Select All",
        "ja": "すべて選択",
        "ko": "모두 선택",
        "zh-Hant": "全選"
    },
    "全部清除": {
        "en": "Clear All",
        "ja": "すべてクリア",
        "ko": "모두 지우기",
        "zh-Hant": "全部清除"
    },
    "全部移除": {
        "en": "Remove All",
        "ja": "すべて削除",
        "ko": "모두 삭제",
        "zh-Hant": "全部移除"
    },
    "全量列表 (All IP)": {
        "en": "Full List (All IP)",
        "ja": "全リスト (All IP)",
        "ko": "전체 목록 (All IP)",
        "zh-Hant": "全量列表 (All IP)"
    },
    "全量列表 (All)": {
        "en": "Full List (All)",
        "ja": "全リスト (All)",
        "ko": "전체 목록 (All)",
        "zh-Hant": "全量列表 (All)"
    },
    "关于 MotrixMac": {
        "en": "About MotrixMac",
        "ja": "MotrixMac について",
        "ko": "MotrixMac 정보",
        "zh-Hant": "關於 MotrixMac"
    },
    "出现错误": {
        "en": "Error",
        "ja": "エラー",
        "ko": "오류 발생",
        "zh-Hant": "出現錯誤"
    },
    "分块进度": {
        "en": "Piece Progress",
        "ja": "ピース進行状況",
        "ko": "조각 진행률",
        "zh-Hant": "分塊進度"
    },
    "删除所有任务": {
        "en": "Delete All Tasks",
        "ja": "すべてのタスクを削除",
        "ko": "모든 작업 삭제",
        "zh-Hant": "刪除所有任務"
    },
    "剩余时间": {
        "en": "ETA",
        "ja": "残り時間",
        "ko": "남은 시간",
        "zh-Hant": "剩餘時間"
    },
    "取消": {
        "en": "Cancel",
        "ja": "キャンセル",
        "ko": "취소",
        "zh-Hant": "取消"
    },
    "名称": {
        "en": "Name",
        "ja": "名前",
        "ko": "이름",
        "zh-Hant": "名稱"
    },
    "复制下载链接": {
        "en": "Copy URL",
        "ja": "URL をコピー",
        "ko": "URL 복사",
        "zh-Hant": "複製下載連結"
    },
    "大小": {
        "en": "Size",
        "ja": "サイズ",
        "ko": "크기",
        "zh-Hant": "大小"
    },
    "完成": {
        "en": "Done",
        "ja": "完了",
        "ko": "완료",
        "zh-Hant": "完成"
    },
    "已下载完成": {
        "en": "has finished downloading",
        "ja": "ダウンロードが完了しました",
        "ko": "다운로드가 완료되었습니다",
        "zh-Hant": "已下載完成"
    },
    "已取消": {
        "en": "Cancelled",
        "ja": "キャンセル済み",
        "ko": "취소됨",
        "zh-Hant": "已取消"
    },
    "已完成": {
        "en": "Completed",
        "ja": "完了",
        "ko": "완료됨",
        "zh-Hant": "已完成"
    },
    "已开始下载": {
        "en": "has started downloading",
        "ja": "ダウンロードを開始しました",
        "ko": "다운로드를 시작했습니다",
        "zh-Hant": "已開始下載"
    },
    "已暂停": {
        "en": "Paused",
        "ja": "一時停止",
        "ko": "일시 중지됨",
        "zh-Hant": "已暫停"
    },
    "已用时间": {
        "en": "Elapsed",
        "ja": "経過時間",
        "ko": "소요 시간",
        "zh-Hant": "已用時間"
    },
    "已移除": {
        "en": "Removed",
        "ja": "削除済み",
        "ko": "삭제됨",
        "zh-Hant": "已移除"
    },
    "常规": {
        "en": "General",
        "ja": "一般",
        "ko": "일반",
        "zh-Hant": "常規"
    },
    "应用设置": {
        "en": "Apply Settings",
        "ja": "設定を適用",
        "ko": "설정 적용",
        "zh-Hant": "應用設置"
    },
    "开始下载": {
        "en": "Start Download",
        "ja": "ダウンロード開始",
        "ko": "ダウンロード開始",
        "zh-Hant": "開始下載"
    },
    "开始时间": {
        "en": "Started",
        "ja": "開始時間",
        "ko": "시작 시간",
        "zh-Hant": "開始時間"
    },
    "开源许可": {
        "en": "Open Source License",
        "ja": "オープンソースライセンス",
        "ko": "오픈 소스 라이선스",
        "zh-Hant": "開源許可"
    },
    "强行重置并修复": {
        "en": "Force Reset & Repair",
        "ja": "強制リセットと修復",
        "ko": "강제 초기화 및 복구",
        "zh-Hant": "強行重置並修復"
    },
    "恢复": {
        "en": "Restore",
        "ja": "復元",
        "ko": "복구",
        "zh-Hant": "恢復"
    },
    "恢复初始设置": {
        "en": "Restore Initial Settings",
        "ja": "初期設定に戻す",
        "ko": "초기 설정 복원",
        "zh-Hant": "恢復初始設置"
    },
    "感谢这些伟大的开源项目，它们让 MotrixMac 的诞生成为可能。": {
        "en": "Thanks to these great open source projects that made MotrixMac possible.",
        "ja": "MotrixMac を可能にした素晴らしいオープンソースプロジェクトに感謝します。",
        "ko": "MotrixMac을 가능하게 한 훌륭한 오픈 소스 프로젝트에 감사드립니다.",
        "zh-Hant": "感謝這些偉大的開源項目，它們讓 MotrixMac 的誕生與發展成為可能。"
    },
    "所有下载任务": {
        "en": "All Tasks",
        "ja": "すべてのタスク",
        "ko": "모든 작업",
        "zh-Hant": "所有下載任務"
    },
    "搜索": {
        "en": "Search",
        "ja": "検索",
        "ko": "검색",
        "zh-Hant": "搜索"
    },
    "文件": {
        "en": "File",
        "ja": "ファイル",
        "ko": "파일",
        "zh-Hant": "檔案"
    },
    "文件夹": {
        "en": "Folder",
        "ja": "フォルダー",
        "ko": "폴더",
        "zh-Hant": "資料夾"
    },
    "暂无下载任务": {
        "en": "No Tasks",
        "ja": "タスクなし",
        "ko": "작업 없음",
        "zh-Hant": "暫無下載任務"
    },
    "暂无已完成任务": {
        "en": "No Completed Tasks",
        "ja": "完了したタスクなし",
        "ko": "완료된 작업 없음",
        "zh-Hant": "暫無已完成任務"
    },
    "更新日志": {
        "en": "Changelog",
        "ja": "変更履歴",
        "ko": "변경 로그",
        "zh-Hant": "更新日誌"
    },
    "未知错误": {
        "en": "Unknown Error",
        "ja": "未知のエラー",
        "ko": "알 수 없는 오류",
        "zh-Hant": "未知錯誤"
    },
    "正在启动下载引擎...": {
        "en": "Starting engine...",
        "ja": "エンジンを起動中...",
        "ko": "엔진 시작 중...",
        "zh-Hant": "正在啟動下載引擎..."
    },
    "添加": {
        "en": "Add",
        "ja": "追加",
        "ko": "추가",
        "zh-Hant": "添加"
    },
    "添加下载": {
        "en": "Add Download",
        "ja": "ダウンロードを追加",
        "ko": "다운로드 추가",
        "zh-Hant": "添加下載"
    },
    "添加时间": {
        "en": "Added",
        "ja": "追加日時",
        "ko": "추가됨",
        "zh-Hant": "添加時間"
    },
    "清空已选": {
        "en": "Clear Selected",
        "ja": "選択を解除",
        "ko": "선택 해제",
        "zh-Hant": "清空已選"
    },
    "清除下载历史": {
        "en": "Clear Download History",
        "ja": "ダウンロード履歴を消去",
        "ko": "다운로드 기록 삭제",
        "zh-Hant": "清除下載歷史"
    },
    "状态": {
        "en": "Status",
        "ja": "状態",
        "ko": "상태",
        "zh-Hant": "狀態"
    },
    "用户": {
        "en": "Peers",
        "ja": "ピア",
        "ko": "피어",
        "zh-Hant": "用戶"
    },
    "由于上次异常退出，正在尝试自愈系统以确保稳定。": {
        "en": "The system is attempting to self-heal for stability.",
        "ja": "異常終了のため、安定性のためにシステムの自動修復を試みています。",
        "ko": "비정상적인 종료가 발생하여 시스템을 자동으로 복구하고 있습니다.",
        "zh-Hant": "由於上次異常退出，正在嘗試自癒系統以確保穩定。"
    },
    "确定": {
        "en": "OK",
        "ja": "OK",
        "ko": "확인",
        "zh-Hant": "確定"
    },
    "等待上传": {
        "en": "Interested",
        "ja": "アップロード待機",
        "ko": "업로드 대기",
        "zh-Hant": "等待上傳"
    },
    "等待下载": {
        "en": "Choked",
        "ja": "ダウンロード待機",
        "ko": "다운로드 대기",
        "zh-Hant": "等待下載"
    },
    "等待中": {
        "en": "Waiting",
        "ja": "待機中",
        "ko": "대기 중",
        "zh-Hant": "等待中"
    },
    "精选列表 (Best IP)": {
        "en": "Best IP List",
        "ja": "ベスト IP リスト",
        "ko": "베스트 IP 리스트",
        "zh-Hant": "精選列表 (Best IP)"
    },
    "精选列表 (Best)": {
        "en": "Best List",
        "ja": "ベストリスト",
        "ko": "베스트 리스트",
        "zh-Hant": "精選列表 (Best)"
    },
    "记录 MotrixMac 进化的点点滴滴。": {
        "en": "Recording the evolution of MotrixMac.",
        "ja": "MotrixMac の進化を記録。",
        "ko": "MotrixMac의 진화 기록.",
        "zh-Hant": "記錄 MotrixMac 進化的點點滴滴。"
    },
    "设置": {
        "en": "Settings",
        "ja": "設定",
        "ko": "설정",
        "zh-Hant": "設置"
    },
    "进度": {
        "en": "Progress",
        "ja": "進行状況",
        "ko": "진행률",
        "zh-Hant": "進度"
    },
    "进行中": {
        "en": "Downloading",
        "ja": "進行中",
        "ko": "진행 중",
        "zh-Hant": "進行中"
    },
    "连接中...": {
        "en": "Connecting...",
        "ja": "接続中...",
        "ko": "연결 중...",
        "zh-Hant": "連接中..."
    },
    "选择...": {
        "en": "Select...",
        "ja": "選択...",
        "ko": "선택...",
        "zh-Hant": "選擇..."
    },
    "速度": {
        "en": "Speed",
        "ja": "速度",
        "ko": "속도",
        "zh-Hant": "速度"
    },
    "重新开始": {
        "en": "Restart",
        "ja": "再表示",
        "ko": "다시 시작",
        "zh-Hant": "重新開始"
    },
    "重置所有设置": {
        "en": "Reset All Settings",
        "ja": "すべての設定をリセット",
        "ko": "모든 설정 초기화",
        "zh-Hant": "重置所有設置"
    },
    "阻塞中": {
        "en": "Choking",
        "ja": "チョーキング",
        "ko": "차단됨",
        "zh-Hant": "阻塞中"
    },
    "重新下载": {
        "en": "Redownload",
        "ja": "再ダウンロード",
        "ko": "再ダウンロード",
        "zh-Hant": "重新下載"
    },
    "下载磁力链接时，自动保存 .torrent 种子文件到下载目录": {
        "en": "Auto-save .torrent file when downloading Magnet links",
        "ja": "Magnet リンクのダウンロード時に .torrent ファイルを自動保存",
        "ko": "마그넷 링크 다운로드 시 .torrent 파일 자동 저장",
        "zh-Hant": "下載磁力連結時，自動保存 .torrent 種子檔案到下載目錄"
    },
    "RPC 监听端口": {
        "en": "RPC Listen Port",
        "ja": "RPC リッスンポート",
        "ko": "RPC 수신 포트",
        "zh-Hant": "RPC 監聽端口"
    },
    "1 个月": {
        "en": "1 Month",
        "ja": "1ヶ月",
        "ko": "1개월",
        "zh-Hant": "1 個月"
    },
    "自定义订阅": {
        "en": "Custom Subscription",
        "ja": "カスタム購読",
        "ko": "사용자 지정 구독",
        "zh-Hant": "自定義訂閱"
    },
    "7 天": {
        "en": "7 Days",
        "ja": "7日",
        "ko": "7일",
        "zh-Hant": "7 天"
    },
    "全部恢复": {
        "en": "Resume All",
        "ja": "すべて再開",
        "ko": "모두 재개",
        "zh-Hant": "全部恢復"
    },
    "应用": {
        "en": "Apply",
        "ja": "適用",
        "ko": "적용",
        "zh-Hant": "應用"
    },
    "如果您的网络环境不支持 IPv6，启用此选项可能导致连接超时。": {
        "en": "Enabling IPv6 may cause connection timeouts if not supported by your network.",
        "ja": "ネットワークがIPv6をサポートしていない場合、これを有効にすると接続タイムアウトが発生する可能性があります。",
        "ko": "네트워크가 IPv6를 지원하지 않는 경우 이 옵션을 활성화하면 연결 시간 초과가 발생할 수 있습니다。",
        "zh-Hant": "如果您的網絡環境不支持 IPv6，啟用此選項可能導致連接超時。"
    },
    "开机启动": {
        "en": "Launch at Login",
        "ja": "ログイン時に起動",
        "ko": "로그인 시 실행",
        "zh-Hant": "開機啟動"
    },
    "引擎启动失败": {
        "en": "Engine Start Failed",
        "ja": "エンジン起動失敗",
        "ko": "엔진 시작 실패",
        "zh-Hant": "引擎啟動失敗"
    },
    "一个轻量化的、全原生 Swift 实现的下载工具。": {
        "en": "A lightweight, fully native download tool built with Swift.",
        "ja": "Swiftで構築された軽量で完全にネイティブなダウンロードツール。",
        "ko": "Swift로 구축된 가볍고 완전히 네이티브한 다운로드 도구입니다.",
        "zh-Hant": "一個輕量化的、全原生 Swift 實現的下載工具。"
    },
    "格式：Header-Name: Value （每行一个）": {
        "en": "Format: Header-Name: Value (One per line)",
        "ja": "形式: Header-Name: Value (1行に1つ)",
        "ko": "형식: Header-Name: Value (한 줄에 하나)",
        "zh-Hant": "格式：Header-Name: Value （每行一個）"
    },
    "启用 IPv6": {
        "en": "Enable IPv6",
        "ja": "IPv6 を有効化",
        "ko": "IPv6 활성화",
        "zh-Hant": "啟用 IPv6"
    },
    "自动清除任务": {
        "en": "Auto-remove Tasks",
        "ja": "タスクの自動削除",
        "ko": "작업 자동 삭제",
        "zh-Hant": "自動清除任務"
    },
    "此操作将重置所有偏好设置，但不会删除您的下载文件。确定要继续吗？": {
        "en": "This will reset all preferences but will not delete your downloaded files. Continue?",
        "ja": "すべての設定がリセットされますが、ダウンロードされたファイルは削除されません。続行しますか？",
        "ko": "모든 기본 설정이 초기화되지만 다운로드한 파일은 삭제되지 않습니다. 계속하시겠습니까?",
        "zh-Hant": "此操作將重置所有偏好設置，但不會刪除您的下載檔案。確定要繼續嗎？"
    },
    "跟随系统": {
        "en": "System",
        "ja": "システム",
        "ko": "시스템",
        "zh-Hant": "跟隨系統"
    },
    "版本 %1$@ (%2$@)": {
        "en": "Version %1$@ (%2$@)",
        "ja": "バージョン %1$@ (%2$@)",
        "ko": "버전 %1$@ (%2$@)",
        "zh-Hant": "版本 %1$@ (%2$@)"
    },
    "断点续传": {
        "en": "Resume Support",
        "ja": "レジューム対応",
        "ko": "이어받기 지원",
        "zh-Hant": "斷點續傳"
    },
    "上传限速": {
        "en": "Max Upload Speed",
        "ja": "最大アップロード速度",
        "ko": "최대 업로드 속도",
        "zh-Hant": "上傳限速"
    },
    "1 个任务": {
        "en": "1 Task",
        "ja": "1 つのタスク",
        "ko": "1개 작업",
        "zh-Hant": "1 個任務"
    },
    "每 12 小时": {
        "en": "Every 12 Hours",
        "ja": "12時間ごと",
        "ko": "12시간마다",
        "zh-Hant": "每 12 小時"
    },
    "应用并离开": {
        "en": "Apply & Exit",
        "ja": "適用して終了",
        "ko": "적용 및 나가기",
        "zh-Hant": "應用並離開"
    },
    "启用 DHT (去中心化网络)": {
        "en": "Enable DHT (Decentralized Network)",
        "ja": "DHT (分散型ネットワーク) を有効化",
        "ko": "DHT (분산 네트워크) 활성화",
        "zh-Hant": "啟用 DHT (去中心化網絡)"
    },
    "启用 Peer Exchange 以找到更多用户 (Peers)": {
        "en": "Enable Peer Exchange to find more peers",
        "ja": "Peer Exchange を有効化してより多くのピアを見つける",
        "ko": "더 많은 피어를 찾기 위해 피어 교환 활성화",
        "zh-Hant": "啟用 Peer Exchange 以找到更多用戶 (Peers)"
    },
    "高级选项": {
        "en": "Advanced Options",
        "ja": "詳細オプション",
        "ko": "고급 옵션",
        "zh-Hant": "高級選項"
    },
    "自动重命名已存在文件": {
        "en": "Auto-rename existing files",
        "ja": "既存のファイルを自動リネーム",
        "ko": "기존 파일 자동 이름 변경",
        "zh-Hant": "自動重命名已存在檔案"
    },
    "HTTP": {
        "en": "HTTP",
        "ja": "HTTP",
        "ko": "HTTP",
        "zh-Hant": "HTTP"
    },
    "移除记录并删除本地文件": {
        "en": "Remove Record & Delete Files",
        "ja": "履歴とファイルを削除",
        "ko": "기록 및 파일 삭제",
        "zh-Hant": "移除記錄並刪除本地檔案"
    },
    "保存磁力链接元数据为种子文件": {
        "en": "Save Magnet Metadata as .torrent",
        "ja": "Magnet メタデータを .torrent として保存",
        "ko": "마그넷 메타데이터를 .torrent로 저장",
        "zh-Hant": "保存磁力連結元數據為種子檔案"
    },
    "新建种子下载": {
        "en": "New Torrent Download",
        "ja": "新規 Torrent ダウンロード",
        "ko": "새 토렌트 다운로드",
        "zh-Hant": "新建種子下載"
    },
    "强制加密": {
        "en": "Force Encryption",
        "ja": "暗号化を強制",
        "ko": "암호화 강제",
        "zh-Hant": "強制加密"
    },
    "单列表模式": {
        "en": "Single List Mode",
        "ja": "シングルリストモード",
        "ko": "단일 목록 모드",
        "zh-Hant": "單列表模式"
    },
    "取消下载": {
        "en": "Cancel Download",
        "ja": "ダウンロードをキャンセル",
        "ko": "다운로드 취소",
        "zh-Hant": "取消下載"
    },
    "已下载": {
        "en": "Downloaded",
        "ja": "ダウンロード済み",
        "ko": "다운로드됨",
        "zh-Hant": "已下載"
    },
    "内置的 aria2.conf 路径": {
        "en": "Built-in aria2.conf path",
        "ja": "組み込み aria2.conf パス",
        "ko": "내장 aria2.conf 경로",
        "zh-Hant": "內置的 aria2.conf 路徑"
    },
    "快速删除任务": {
        "en": "Quick Delete",
        "ja": "クイック削除",
        "ko": "빠른 삭제",
        "zh-Hant": "快速刪除任務"
    },
    "最大同时下载数：": {
        "en": "Max Concurrent Downloads:",
        "ja": "最大同時ダウンロード数:",
        "ko": "최대 동시 다운로드 수:",
        "zh-Hant": "最大同時下載數："
    },
    "任务管理": {
        "en": "Task Management",
        "ja": "タスク管理",
        "ko": "작업 관리",
        "zh-Hant": "任務管理"
    },
    "单任务最大线程数：": {
        "en": "Max Threads per Task:",
        "ja": "タスクごとの最大スレッド数:",
        "ko": "작업당 최대 스레드 수:",
        "zh-Hant": "單任務最大線程數："
    },
    "迅雷链接 [ thunder:// ]": {
        "en": "Thunder Link [ thunder:// ]",
        "ja": "Thunder リンク [ thunder:// ]",
        "ko": "Thunder 링크 [ thunder:// ]",
        "zh-Hant": "迅雷連結 [ thunder:// ]"
    },
    "在 Dock 中显示": {
        "en": "Show in Dock",
        "ja": "Dock に表示",
        "ko": "Dock에 표시",
        "zh-Hant": "在 Dock 中顯示"
    },
    "BT 监听端口": {
        "en": "BT Listen Port",
        "ja": "BT リッスンポート",
        "ko": "BT 수신 포트",
        "zh-Hant": "BT 監聽端口"
    },
    "每月": {
        "en": "Monthly",
        "ja": "毎月",
        "ko": "매월",
        "zh-Hant": "每月"
    },
    "上传速度": {
        "en": "Upload Speed",
        "ja": "アップロード速度",
        "ko": "업로드 속도",
        "zh-Hant": "上傳速度"
    },
    "设为 0 表示无限制": {
        "en": "Set to 0 for unlimited",
        "ja": "0 に設定すると無制限",
        "ko": "무제한으로 설정하려면 0으로 설정",
        "zh-Hant": "設為 0 表示無限制"
    },
    "Info Hash": {
        "en": "Info Hash",
        "ja": "Info Hash",
        "ko": "Info Hash",
        "zh-Hant": "Info Hash"
    },
    "通用": {
        "en": "General",
        "ja": "一般",
        "ko": "일반",
        "zh-Hant": "常規"
    },
    "刷新任务列表": {
        "en": "Refresh Task List",
        "ja": "タスクリストを更新",
        "ko": "작업 목록 새로 고침",
        "zh-Hant": "刷新任務列表"
    },
    "日志级别": {
        "en": "Log Level",
        "ja": "ログレベル",
        "ko": "로그 수준",
        "zh-Hant": "日誌級別"
    },
    "持续做种，直到手动停止": {
        "en": "Seed until manually stopped",
        "ja": "手動で停止するまでシード",
        "ko": "수동으로 중지할 때까지 배포",
        "zh-Hant": "持續做種，直到手動停止"
    },
    "做种分享率": {
        "en": "Seed Ratio",
        "ja": "シード比",
        "ko": "배포 비율",
        "zh-Hant": "做種分享率"
    },
    "设置未保存": {
        "en": "Unsaved Settings",
        "ja": "未保存の設定",
        "ko": "저장되지 않은 설정",
        "zh-Hant": "設置未保存"
    },
    "RPC 授权密钥": {
        "en": "RPC Secret Token",
        "ja": "RPC シークレットトークン",
        "ko": "RPC 비밀 토큰",
        "zh-Hant": "RPC 授權密鑰"
    },
    "添加任务后自动开始下载，无需手动确认": {
        "en": "Auto-start download after adding task",
        "ja": "タスク追加後に自動開始（確認なし）",
        "ko": "작업 추가 후 자동 다운로드 시작 (확인 없음)",
        "zh-Hant": "添加任務後自動開始下載，無需手動確認"
    },
    "移除记录": {
        "en": "Remove Record",
        "ja": "履歴を削除",
        "ko": "기록 삭제",
        "zh-Hant": "移除記錄"
    },
    "留空使用默认值": {
        "en": "Leave empty for default",
        "ja": "空欄でデフォルト値を使用",
        "ko": "기본값을 사용하려면 비워 두십시오",
        "zh-Hant": "留空使用默認值"
    },
    "打开日志目录": {
        "en": "Open Log Directory",
        "ja": "ログディレクトリを開く",
        "ko": "로그 경로 열기",
        "zh-Hant": "打開日誌目錄"
    },
    "BT 设置": {
        "en": "BT Settings",
        "ja": "BT 設定",
        "ko": "BT 설정",
        "zh-Hant": "BT 設置"
    },
    "10 天": {
        "en": "10 Days",
        "ja": "10日",
        "ko": "10일",
        "zh-Hant": "10 天"
    },
    "自定义文件名": {
        "en": "Custom Filename",
        "ja": "カスタムファイル名",
        "ko": "사용자 지정 파일 이름",
        "zh-Hant": "自定義檔案名"
    },
    "输入 URL 或磁力链接...": {
        "en": "Enter URL or Magnet link...",
        "ja": "URL または Magnet リンクを入力...",
        "ko": "URL 또는 마그넷 링크 입력...",
        "zh-Hant": "輸入 URL 或磁力連結..."
    },
    "拖放种子文件到此处": {
        "en": "Drag & Drop Torrent File Here",
        "ja": "ここに Torrent ファイルをドラッグ＆ドロップ",
        "ko": "여기에 토렌트 파일 드래그 앤 드롭",
        "zh-Hant": "拖放種子檔案到此處"
    },
    "在任务列表中移除": {
        "en": "Remove from Task List",
        "ja": "タスクリストから削除",
        "ko": "작업 목록에서 제거",
        "zh-Hant": "在任務列表中移除"
    },
    "下载链接": {
        "en": "Download Link",
        "ja": "ダウンロードリンク",
        "ko": "다운로드 링크",
        "zh-Hant": "下載連結"
    },
    "启用 Local Peer Discovery 以找到更多用户 (Peers)": {
        "en": "Enable Local Peer Discovery to find more peers",
        "ja": "Local Peer Discovery を有効化してより多くのピアを見つける",
        "ko": "더 많은 피어를 찾기 위해 로컬 피어 검색 활성화",
        "zh-Hant": "啟用 Local Peer Discovery 以找到更多用戶 (Peers)"
    },
    "确认移除任务？": {
        "en": "Remove Task?",
        "ja": "タスクを削除しますか？",
        "ko": "작업을 삭제하시겠습니까?",
        "zh-Hant": "確認移除任務？"
    },
    "暂停": {
        "en": "Pause",
        "ja": "一時停止",
        "ko": "일시 정지",
        "zh-Hant": "暫停"
    },
    "在菜单栏显示速度": {
        "en": "Show Speed in Menu Bar",
        "ja": "メニューバーに速度を表示",
        "ko": "메뉴 막대에 속도 표시",
        "zh-Hant": "在菜單欄顯示速度"
    },
    "重试": {
        "en": "Retry",
        "ja": "再試行",
        "ko": "재시도",
        "zh-Hant": "重試"
    },
    "设置应用程序日志的详细程度": {
        "en": "Set application log verbosity",
        "ja": "アプリケーションログの詳細レベルを設定",
        "ko": "애플리케이션 로그 상세 수준 설정",
        "zh-Hant": "設置應用程式日誌的詳細程度"
    },
    "常规行为": {
        "en": "General Behavior",
        "ja": "一般的な動作",
        "ko": "일반 동작",
        "zh-Hant": "常規行為"
    },
    "速度走势": {
        "en": "Speed Trend",
        "ja": "速度推移",
        "ko": "속도 추세",
        "zh-Hant": "速度走勢"
    },
    "新建下载 (⌘N)": {
        "en": "New Download (⌘N)",
        "ja": "新規ダウンロード (⌘N)",
        "ko": "새 다운로드 (⌘N)",
        "zh-Hant": "新建下載 (⌘N)"
    },
    "启用用户交换 (PeX)": {
        "en": "Enable Peer Exchange (PeX)",
        "ja": "ピア交換 (PeX) を有効化",
        "ko": "피어 교환 (PeX) 활성화",
        "zh-Hant": "啟用用戶交換 (PeX)"
    },
    "新建下载任务": {
        "en": "New Download Task",
        "ja": "新規ダウンロードタスク",
        "ko": "새 다운로드 작업",
        "zh-Hant": "新建下載任務"
    },
    "显示": {
        "en": "Display",
        "ja": "表示",
        "ko": "표시",
        "zh-Hant": "顯示"
    },
    "在系统菜单栏实时显示当前下载和上传速度": {
        "en": "Show current download/upload speed in menu bar",
        "ja": "現在のダウンロード/アップロード速度をメニューバーに表示",
        "ko": "현재 다운로드/업로드 속도를 메뉴 막대에 표시",
        "zh-Hant": "在系統菜單欄實時顯示當前下載和上傳速度"
    },
    "选择文件...": {
        "en": "Select File...",
        "ja": "ファイルを選択...",
        "ko": "파일 선택...",
        "zh-Hant": "選擇檔案..."
    },
    "高级": {
        "en": "Advanced",
        "ja": "詳細",
        "ko": "고급",
        "zh-Hant": "高級"
    },
    "网络": {
        "en": "Network",
        "ja": "ネットワーク",
        "ko": "네트워크",
        "zh-Hant": "網絡"
    },
    "添加 Torrent 任务": {
        "en": "Add Torrent Task",
        "ja": "Torrent タスクを追加",
        "ko": "토렌트 작업 추가",
        "zh-Hant": "添加 Torrent 任務"
    },
    "主机": {
        "en": "Host",
        "ja": "ホスト",
        "ko": "호스트",
        "zh-Hant": "主機"
    },
    "下载": {
        "en": "Downloads",
        "ja": "ダウンロード",
        "ko": "다운로드",
        "zh-Hant": "下載"
    },
    "您在设置页面有未保存的更改。离开前是否应用这些更改？": {
        "en": "You have unsaved changes. Apply them before leaving?",
        "ja": "未保存の変更があります。移動する前に適用しますか？",
        "ko": "저장되지 않은 변경 사항이 있습니다. 나가기 전에 적용하시겠습니까?",
        "zh-Hant": "您在設置頁面有未保存的更改。離開前是否應用這些更改？"
    },
    "刷新": {
        "en": "Refresh",
        "ja": "更新",
        "ko": "새로 고침",
        "zh-Hant": "刷新"
    },
    "RPC": {
        "en": "RPC",
        "ja": "RPC",
        "ko": "RPC",
        "zh-Hant": "RPC"
    },
    "自动跳转到下载页面": {
        "en": "Auto-switch to Download Page",
        "ja": "ダウンロードページに自動遷移",
        "ko": "다운로드 페이지로 자동 전환",
        "zh-Hant": "自動跳轉到下載頁面"
    },
    "日志": {
        "en": "Logs",
        "ja": "ログ",
        "ko": "로그",
        "zh-Hant": "日誌"
    },
    "MIT Copyright (c) 2026-present Shawn Rain": {
        "en": "MIT Copyright (c) 2026-present Shawn Rain",
        "ja": "MIT Copyright (c) 2026-present Shawn Rain",
        "ko": "MIT Copyright (c) 2026-present Shawn Rain",
        "zh-Hant": "MIT Copyright (c) 2026-present Shawn Rain"
    },
    "下载速度": {
        "en": "Download Speed",
        "ja": "ダウンロード速度",
        "ko": "다운로드 속도",
        "zh-Hant": "下載速度"
    },
    "Tracker 服务器 (订阅)": {
        "en": "Tracker Servers (Subscription)",
        "ja": "トラッカーサーバー (購読)",
        "ko": "트래커 서버 (구독)",
        "zh-Hant": "Tracker 伺服器 (訂閱)"
    },
    "用户代理": {
        "en": "User-Agent",
        "ja": "User-Agent",
        "ko": "User-Agent",
        "zh-Hant": "用戶代理"
    },
    "Made with ❤️ by Shawn Rain": {
        "en": "Made with ❤️ by Shawn Rain",
        "ja": "Made with ❤️ by Shawn Rain",
        "ko": "Made with ❤️ by Shawn Rain",
        "zh-Hant": "Made with ❤️ by Shawn Rain"
    },
    "连接数": {
        "en": "Connections",
        "ja": "接続数",
        "ko": "연결 수",
        "zh-Hant": "連接數"
    },
    "保存位置": {
        "en": "Save Path",
        "ja": "保存先",
        "ko": "저장 경로",
        "zh-Hant": "保存位置"
    },
    "语言": {
        "en": "Language",
        "ja": "言語",
        "ko": "언어",
        "zh-Hant": "語言"
    },
    "放弃修改": {
        "en": "Discard Changes",
        "ja": "変更を破棄",
        "ko": "변경 사항 취소",
        "zh-Hant": "放棄修改"
    },
    "自动同步 Tracker 服务器列表": {
        "en": "Auto-sync Tracker List",
        "ja": "トラッカーリストを自動同期",
        "ko": "트래커 목록 자동 동기화",
        "zh-Hant": "自動同步 Tracker 伺服器列表"
    },
    "未选择文件": {
        "en": "No File Selected",
        "ja": "ファイルが選択されていません",
        "ko": "선택된 파일 없음",
        "zh-Hant": "未選擇檔案"
    },
    "退出 MotrixMac (⌘Q)": {
        "en": "Quit MotrixMac (⌘Q)",
        "ja": "MotrixMac を終了 (⌘Q)",
        "ko": "MotrixMac 종료 (⌘Q)",
        "zh-Hant": "退出 MotrixMac (⌘Q)"
    },
    "下载会话路径": {
        "en": "Download Session Path",
        "ja": "ダウンロードセッションパス",
        "ko": "다운로드 세션 경로",
        "zh-Hant": "下載會話路徑"
    },
    "更新频率": {
        "en": "Update Check Interval",
        "ja": "更新確認頻度",
        "ko": "업데이트 확인 주기",
        "zh-Hant": "更新頻率"
    },
    "User-Agent": {
        "en": "User-Agent",
        "ja": "User-Agent",
        "ko": "User-Agent",
        "zh-Hant": "User-Agent"
    },
    "传输设置": {
        "en": "Transmission",
        "ja": "転送設定",
        "ko": "전송 설정",
        "zh-Hant": "傳輸設置"
    },
    "外观": {
        "en": "Appearance",
        "ja": "外観",
        "ko": "모양",
        "zh-Hant": "外觀"
    },
    "做种时间 (分钟)": {
        "en": "Seeding Time (min)",
        "ja": "シード時間 (分)",
        "ko": "배포 시간 (분)",
        "zh-Hant": "做種時間 (分鐘)"
    },
    "显示详情": {
        "en": "Show Details",
        "ja": "詳細を表示",
        "ko": "세부 정보 표시",
        "zh-Hant": "顯示詳情"
    },
    "端口": {
        "en": "Port",
        "ja": "ポート",
        "ko": "포트",
        "zh-Hant": "端口"
    },
    "请输入有效的 URL 或磁力链接": {
        "en": "Please enter a valid URL or Magnet link",
        "ja": "有効なURLまたはMagnetリンクを入力してください",
        "ko": "유효한 URL 또는 마그넷 링크를 입력하십시오",
        "zh-Hant": "請輸入有效的 URL 或磁力連結"
    },
    "浅色": {
        "en": "Light",
        "ja": "ライト",
        "ko": "라이트",
        "zh-Hant": "淺色"
    },
    "时间": {
        "en": "Time",
        "ja": "時間",
        "ko": "시간",
        "zh-Hant": "時間"
    },
    "waiting": {
        "en": "Waiting",
        "ja": "待機中",
        "ko": "대기 중",
        "zh-Hant": "等待中"
    },
    "下载完成时通知": {
        "en": "Notify on completion",
        "ja": "完了時に通知",
        "ko": "완료 시 알림",
        "zh-Hant": "下載完成時通知"
    },
    "暂无用户": {
        "en": "No Peers",
        "ja": "ピアなし",
        "ko": "피어 없음",
        "zh-Hant": "暫無用戶"
    },
    "用户名 （可选）": {
        "en": "Username (Optional)",
        "ja": "ユーザー名（オプション）",
        "ko": "사용자 이름 (선택 사항)",
        "zh-Hant": "用戶名 （可選）"
    },
    "或": {
        "en": "or",
        "ja": "または",
        "ko": "또는",
        "zh-Hant": "或"
    },
    "复制": {
        "en": "Copy",
        "ja": "コピー",
        "ko": "복사",
        "zh-Hant": "複製"
    },
    "已选 %d 个文件，共 %@": {
        "en": "Selected %d files, total %@",
        "ja": "%d 個のファイルを選択, 合計 %@",
        "ko": "%d개 파일 선택됨, 총 %@",
        "zh-Hant": "已選 %d 個檔案，共 %@"
    },
    "修改 RPC 设置后将自动热重启引擎生效": {
        "en": "Engine will hot-restart after changing RPC settings",
        "ja": "RPC設定を変更した後、エンジンは自動的にホットリスタートします",
        "ko": "RPC 설정을 변경하면 엔진이 자동으로 핫 리스타트됩니다",
        "zh-Hant": "修改 RPC 設置後將自動熱重啟引擎生效"
    },
    "请输入一个包含 Tracker 列表的完整 URL 地址。": {
        "en": "Please enter a full URL containing a list of trackers.",
        "ja": "トラッカーリストを含む完全なURLを入力してください。",
        "ko": "트래커 목록이 포함된 전체 URL을 입력하십시오.",
        "zh-Hant": "請輸入一個包含 Tracker 列表的完整 URL 地址。"
    },
    "启用本地用户发现 (LPD)": {
        "en": "Enable Local Peer Discovery (LPD)",
        "ja": "ローカルピア検出 (LPD) を有効化",
        "ko": "로컬 피어 검색 (LPD) 활성화",
        "zh-Hant": "啟用本地用戶發現 (LPD)"
    },
    "选择来源": {
        "en": "Select Source",
        "ja": "ソースを選択",
        "ko": "소스 선택",
        "zh-Hant": "選擇來源"
    },
    "融合下载中和已完成列表，将所有任务显示在同一个主页视图中。": {
        "en": "Combine downloading and completed lists into one view.",
        "ja": "ダウンロード中と完了済みのリストを統合して表示します。",
        "ko": "다운로드 중인 목록과 완료된 목록을 하나의 뷰로 통합합니다.",
        "zh-Hant": "融合下載中和已完成列表，將所有任務顯示在同一個主頁視圖中。"
    },
    "error": {
        "en": "Error",
        "ja": "エラー",
        "ko": "오류",
        "zh-Hant": "錯誤"
    },
    "引擎连接失败": {
        "en": "Engine Connection Failed",
        "ja": "エンジン接続失敗",
        "ko": "엔진 연결 실패",
        "zh-Hant": "引擎連接失敗"
    },
    "任务完成后继续做种，直到手动移除或暂停": {
        "en": "Continue seeding until manually removed or paused",
        "ja": "手動で削除または一時停止するまでシードを継続",
        "ko": "수동으로 제거하거나 일시 중지할 때까지 배포 계속",
        "zh-Hant": "任務完成後繼續做種，直到手動移除或暫停"
    },
    "停止做种": {
        "en": "Stop Seeding",
        "ja": "シード停止",
        "ko": "배포 중지",
        "zh-Hant": "停止做種"
    },
    "留空使用原始文件名": {
        "en": "Leave empty to use original filename",
        "ja": "空欄で元のファイル名を使用",
        "ko": "원래 파일 이름을 사용하려면 비워 두십시오",
        "zh-Hant": "留空使用原始文件名"
    },
    "添加后跳转到下载页面": {
        "en": "Jump to Download Page",
        "ja": "ダウンロードページへ移動",
        "ko": "다운로드 페이지로 이동",
        "zh-Hant": "添加後跳轉到下載頁面"
    },
    "保存到": {
        "en": "Save to",
        "ja": "保存先",
        "ko": "저장 위치",
        "zh-Hant": "儲存到"
    },
    "启用后，开机启动时不会自动显示主窗口": {
        "en": "Hide main window when launching at login",
        "ja": "ログイン時にメインウィンドウを表示しない",
        "ko": "로그인 시 메인 창 숨기기",
        "zh-Hant": "啟用後，開機啟動時不會自動顯示主視窗"
    },
    "在 Finder 中显示": {
        "en": "Show in Finder",
        "ja": "Finder で表示",
        "ko": "Finder에서 보기",
        "zh-Hant": "在 Finder 中顯示"
    },
    "检查更新": {
        "en": "Check for Updates",
        "ja": "アップデートを確認",
        "ko": "업데이트 확인",
        "zh-Hant": "檢查更新"
    },
    "线程数": {
        "en": "Threads",
        "ja": "スレッド数",
        "ko": "스레드 수",
        "zh-Hant": "線程數"
    },
    "隐私 & BitTorrent": {
        "en": "Privacy & BitTorrent",
        "ja": "プライバシー & BitTorrent",
        "ko": "개인정보 & BitTorrent",
        "zh-Hant": "隱私 & BitTorrent"
    },
    "3 天": {
        "en": "3 Days",
        "ja": "3日",
        "ko": "3일",
        "zh-Hant": "3 天"
    },
    "未配置或未连接到任何 Tracker": {
        "en": "No trackers configured or connected",
        "ja": "トラッカーが設定されていないか、接続されていません",
        "ko": "트래커가 구성되지 않았거나 연결되지 않았습니다",
        "zh-Hant": "未配置或未連接到任何 Tracker"
    },
    "磁力链接 [ magnet:// ]": {
        "en": "Magnet Link [ magnet:// ]",
        "ja": "Magnet リンク [ magnet:// ]",
        "ko": "마그넷 링크 [ magnet:// ]",
        "zh-Hant": "磁力連結 [ magnet:// ]"
    },
    "强制重置引擎": {
        "en": "Force Reset Engine",
        "ja": "エンジンを強制リセット",
        "ko": "엔진 강제 초기화",
        "zh-Hant": "強制重置引擎"
    },
    "打开主面板": {
        "en": "Open Main Panel",
        "ja": "メインパネルを開く",
        "ko": "메인 패널 열기",
        "zh-Hant": "打開主面板"
    },
    "active": {
        "en": "Active",
        "ja": "アクティブ",
        "ko": "활성",
        "zh-Hant": "活躍"
    },
    "链接": {
        "en": "Link",
        "ja": "リンク",
        "ko": "링크",
        "zh-Hant": "連結"
    },
    "新建下载": {
        "en": "New Download",
        "ja": "新規ダウンロード",
        "ko": "새 다운로드",
        "zh-Hant": "新建下載"
    },
    "开发者": {
        "en": "Developer",
        "ja": "開発者",
        "ko": "개발자",
        "zh-Hant": "開發者"
    },
    "当前系统可能存在一个旧的 aria2 进程正在使用此端口，且其密钥与当前设置不符。": {
        "en": "An old aria2 process might be using this port with a mismatched token.",
        "ja": "古いaria2プロセスがこのポートを使用しており、トークンが一致しない可能性があります。",
        "ko": "이전 aria2 프로세스가 이 포트를 사용 중이며 토큰이 일치하지 않을 수 있습니다.",
        "zh-Hant": "當前系統可能存在一個舊的 aria2 進程正在使用此端口，且其密鑰與當前設置不符。"
    },
    "启用 UPnP/NAT-PMP": {
        "en": "Enable UPnP/NAT-PMP",
        "ja": "UPnP/NAT-PMP を有効化",
        "ko": "UPnP/NAT-PMP 활성화",
        "zh-Hant": "啟用 UPnP/NAT-PMP"
    },
    "客户端": {
        "en": "Client",
        "ja": "クライアント",
        "ko": "클라이언트",
        "zh-Hant": "客戶端"
    },
    "每天": {
        "en": "Daily",
        "ja": "毎日",
        "ko": "매일",
        "zh-Hant": "每天"
    },
    "自定义请求头": {
        "en": "Custom Headers",
        "ja": "カスタムヘッダー",
        "ko": "사용자 지정 헤더",
        "zh-Hant": "自定義請求頭"
    },
    "总大小": {
        "en": "Total Size",
        "ja": "合計サイズ",
        "ko": "総サイズ",
        "zh-Hant": "總大小"
    },
    "立即同步 Tracker 列表": {
        "en": "Sync Trackers Now",
        "ja": "トラッカーリストを今すぐ同期",
        "ko": "트래커 목록 즉시 동기화",
        "zh-Hant": "立即同步 Tracker 列表"
    },
    "下载限速": {
        "en": "Max Download Speed",
        "ja": "最大ダウンロード速度",
        "ko": "최대 다운로드 속도",
        "zh-Hant": "下載限速"
    },
    "加密模式": {
        "en": "Encryption Mode",
        "ja": "暗号化モード",
        "ko": "암호화 모드",
        "zh-Hant": "加密模式"
    },
    "3 个月": {
        "en": "3 Months",
        "ja": "3ヶ月",
        "ko": "3개월",
        "zh-Hant": "3 個月"
    },
    "可能由于残留进程或密钥不一致导致。建议尝试强行重置。": {
        "en": "Possible residual process or token mismatch. Force Reset recommended.",
        "ja": "残留プロセスまたはトークンの不一致の可能性があります。強制リセットを推奨します。",
        "ko": "잔류 프로세스 또는 토큰 불일치 가능성. 강제 초기화 권장.",
        "zh-Hant": "可能由於殘留進程或密鑰不一致導致。建議嘗試強行重置。"
    },
    "深色": {
        "en": "Dark",
        "ja": "ダーク",
        "ko": "다크",
        "zh-Hant": "深色"
    },
    "随机生成": {
        "en": "Generate Random",
        "ja": "ランダム生成",
        "ko": "무작위 생성",
        "zh-Hant": "隨機生成"
    },
    "1 天": {
        "en": "1 Day",
        "ja": "1日",
        "ko": "1일",
        "zh-Hant": "1 天"
    },
    "自动开始下载磁力链接、种子文件": {
        "en": "Auto-start BitTorrent tasks",
        "ja": "BitTorrentタスクを自動開始",
        "ko": "BitTorrent 작업 자동 시작",
        "zh-Hant": "自動開始下載磁力連結、種子檔案"
    },
    "当前 Tracker 列表 (手动编辑)": {
        "en": "Current Trackers (Edit)",
        "ja": "現在のトラッカー（編集）",
        "ko": "현재 트래커 (편집)",
        "zh-Hant": "當前 Tracker 列表 (手動編輯)"
    },
    "代理": {
        "en": "Proxy",
        "ja": "プロキシ",
        "ko": "프록시",
        "zh-Hant": "代理"
    },
    "启用代理": {
        "en": "Enable Proxy",
        "ja": "プロキシを有効にする",
        "ko": "프록시 활성화",
        "zh-Hant": "啟用代理"
    },
    "常规重置": {
        "en": "Reset",
        "ja": "リセット",
        "ko": "초기화",
        "zh-Hant": "常規重置"
    },
    "从列表中选择一个下载任务以查看详情": {
        "en": "Select a task to view details",
        "ja": "タスクを選択して詳細を表示",
        "ko": "작업을 선택하여 세부 정보 보기",
        "zh-Hant": "從列表中選擇一個下載任務以查看詳情"
    },
    "启用 aria2 内置的异步 DNS 解析。如果您使用了代理软件，建议关闭此选项以防止 DNS 污染。": {
        "en": "Enable aria2 built-in async DNS. Disable if using proxy to prevent DNS pollution.",
        "ja": "aria2内蔵の非同期DNS解決を有効にします。プロキシを使用している場合は、DNS汚染を防ぐために無効にすることをお勧めします。",
        "ko": "aria2 내장 비동기 DNS을 활성화합니다. 프록시를 사용하는 경우 DNS 오염을 방지하기 위해 이 옵션을 비활성화하는 것이 좋습니다。",
        "zh-Hant": "啟用 aria2 內置的異步 DNS 解析。如果您使用了代理軟件，建議關閉此選項以防止 DNS 污染。"
    },
    "选择内置 Tracker 源...": {
        "en": "Select Built-in Tracker Source...",
        "ja": "組み込みトラッカーソースを選択...",
        "ko": "내장 트래커 소스 선택...",
        "zh-Hant": "選擇內置 Tracker 源..."
    },
    "同时删除本地文件": {
        "en": "Also delete local files",
        "ja": "ローカルファイルも削除",
        "ko": "로컬 파일도 삭제",
        "zh-Hant": "同時刪除本地檔案"
    },
    "启用异步 DNS": {
        "en": "Enable Async DNS",
        "ja": "非同期DNSを有効化",
        "ko": "비동기 DNS 활성화",
        "zh-Hant": "啟用異步 DNS"
    },
    "来源": {
        "en": "Source",
        "ja": "ソース",
        "ko": "소스",
        "zh-Hant": "來源"
    },
    "Cookie": {
        "en": "Cookie",
        "ja": "Cookie",
        "ko": "Cookie",
        "zh-Hant": "Cookie"
    },
    "关闭": {
        "en": "Close",
        "ja": "閉じる",
        "ko": "닫기",
        "zh-Hant": "關閉"
    },
    "添加自定义订阅 URL": {
        "en": "Add Custom Subscription URL",
        "ja": "カスタム購読URLを追加",
        "ko": "사용자 지정 구독 URL 추가",
        "zh-Hant": "添加自定義訂閱 URL"
    },
    "重置下载会话记录": {
        "en": "Reset Download Session History",
        "ja": "ダウンロードセッション履歴をリセット",
        "ko": "다운로드 세션 기록 초기화",
        "zh-Hant": "重置下載會話記錄"
    },
    "删除任务前无需确认": {
        "en": "Skip delete confirmation",
        "ja": "削除確認をスキップ",
        "ko": "삭제 확인 건너뛰기",
        "zh-Hant": "刪除任務前無需確認"
    },
    "密码 （可选）": {
        "en": "Password (Optional)",
        "ja": "パスワード（オプション）",
        "ko": "비밀번호 (선택 사항)",
        "zh-Hant": "密碼 （可選）"
    },
    "静默启动": {
        "en": "Silent Start",
        "ja": "サイレント起動",
        "ko": "무음 실행",
        "zh-Hant": "靜默啟動"
    },
    "新建任务后自动跳转到下载页面": {
        "en": "Switch to download page after adding task",
        "ja": "タスク追加後にダウンロードページに遷移",
        "ko": "작업 추가 후 다운로드 페이지로 전환",
        "zh-Hant": "新建任務後自動跳轉到下載頁面"
    },
    "分块数": {
        "en": "Split",
        "ja": "分割数",
        "ko": "분할 수",
        "zh-Hant": "分塊數"
    },
    "下载协议: 设置为以下协议的默认客户端": {
        "en": "Protocol Associations: Set as default client for",
        "ja": "プロトコル関連付け: デフォルトのクライアントとして設定",
        "ko": "프로토콜 연결: 다음 프로토콜의 기본 클라이언트로 설정",
        "zh-Hant": "下載協議: 設置為以下協議的默認客戶端"
    },
    "做种数": {
        "en": "Seeds",
        "ja": "シード数",
        "ko": "시드 수",
        "zh-Hant": "做種數"
    },
    "允许加密": {
        "en": "Allow Encryption",
        "ja": "暗号化を許可",
        "ko": "암호화 허용",
        "zh-Hant": "允許加密"
    },
    "未选择下载任务": {
        "en": "No Task Selected",
        "ja": "タスクが選択されていません",
        "ko": "선택된 작업 없음",
        "zh-Hant": "未選擇下載任務"
    },
    "Connecting...": {
        "en": "Connecting...",
        "ja": "接続中...",
        "ko": "연결 중...",
        "zh-Hant": "連接中..."
    },
    "以后不再询问": {
        "en": "Don't ask again",
        "ja": "今後表示しない",
        "ko": "다시 묻지 않음",
        "zh-Hant": "以後不再詢問"
    },
    "复制路径": {
        "en": "Copy Path",
        "ja": "パスをコピー",
        "ko": "경로 복사",
        "zh-Hant": "複製路徑"
    },
    "选择其他文件": {
        "en": "Select Other File",
        "ja": "別のファイルを選択",
        "ko": "다른 파일選択",
        "zh-Hant": "選擇其他檔案"
    },
    "暂无 Tracker": {
        "en": "No Trackers",
        "ja": "トラッカーなし",
        "ko": "트래커 없음",
        "zh-Hant": "暫無 Tracker"
    },
    "上传": {
        "en": "Upload",
        "ja": "アップロード",
        "ko": "업로드",
        "zh-Hant": "上傳"
    },
    "是否在 macOS Dock 栏显示应用图标": {
        "en": "Show app icon in macOS Dock",
        "ja": "macOS Dock にアプリアイコンを表示する",
        "ko": "macOS Dock에 앱 아이콘 표시",
        "zh-Hant": "是否在 macOS Dock 欄顯示應用程式圖標"
    },
    "全部暂停": {
        "en": "Pause All",
        "ja": "すべて一時停止",
        "ko": "모두 일시 정지",
        "zh-Hant": "全部暫停"
    },
    "现在": {
        "en": "Now",
        "ja": "今",
        "ko": "지금",
        "zh-Hant": "現在"
    },
    "请至少选择一个文件以开始下载。": {
        "en": "Please select at least one file to start.",
        "ja": "ダウンロードを開始するには少なくとも1つのファイルを選択してください。",
        "ko": "다운로드를 시작하려면 파일을 하나 이상 선택하십시오.",
        "zh-Hant": "請至少選擇一個檔案以開始下載。"
    },
    "高级网络": {
        "en": "Advanced Network",
        "ja": "高度なネットワーク",
        "ko": "고급 네트워크",
        "zh-Hant": "高級網絡"
    },
    "授权失败 （密钥不匹配）": {
        "en": "Unauthorized (Token Mismatch)",
        "ja": "認証失敗（トークン不一致）",
        "ko": "인증 실패 (토큰 불일치)",
        "zh-Hant": "授權失敗 （密鑰不匹配）"
    },
    "禁用加密": {
        "en": "Disable Encryption",
        "ja": "暗号化を無効化",
        "ko": "암호화 비활성화",
        "zh-Hant": "禁用加密"
    },
    "启用 Distributed Hash Table 以找到更多用户 (Peers)": {
        "en": "Enable Distributed Hash Table to find more peers",
        "ja": "DHTを有効にしてより多くのピアを見つける",
        "ko": "더 많은 피어를 찾기 위해 분산 해시 테이블(DHT) 활성화",
        "zh-Hant": "啟用 Distributed Hash Table 以找到更多用戶 (Peers)"
    },
    "应用日志路径": {
        "en": "App Log Path",
        "ja": "アプリログのパス",
        "ko": "앱 로그 경로",
        "zh-Hant": "應用日誌路徑"
    },
    "隐藏": {
        "en": "Hide",
        "ja": "隠す",
        "ko": "숨기기",
        "zh-Hant": "隱藏"
    },
    "每周": {
        "en": "Weekly",
        "ja": "毎週",
        "ko": "매주",
        "zh-Hant": "每週"
    },
    "设为默认下载目录": {
        "en": "Make Default",
        "ja": "デフォルトにする",
        "ko": "기본값으로 설정",
        "zh-Hant": "設為默認下載目錄"
    },
    "下载目录": {
        "en": "Download Directory",
        "ja": "保存先",
        "ko": "다운로드 경로",
        "zh-Hant": "下載目錄"
    },
    "更改": {
        "en": "Change",
        "ja": "変更",
        "ko": "변경",
        "zh-Hant": "更改"
    },
    "默认下载设置": {
        "en": "Default Download Settings",
        "ja": "デフォルトのダウンロード設定",
        "ko": "기본 다운로드 설정",
        "zh-Hant": "默認下載設置"
    },
    "最大连接数": {
        "en": "Max Connections",
        "ja": "最大接続数",
        "ko": "최대 연결 수",
        "zh-Hant": "最大連接數"
    },
    "针对每个任务的默认最大连接数": {
        "en": "Default max connections per task",
        "ja": "タスクごとのデフォルト最大接続数",
        "ko": "작업당 기본 최대 연결 수",
        "zh-Hant": "針對每個任務的默認最大連接數"
    },
    "删除任务时同时删除文件": {
        "en": "Delete Files with Task",
        "ja": "タスク削除時にファイルを削除",
        "ko": "작업 삭제 시 파일도 삭제",
        "zh-Hant": "刪除任務時同時刪除檔案"
    },
    "删除": {
        "en": "Delete",
        "ja": "削除",
        "ko": "삭제",
        "zh-Hant": "刪除"
    },
    "保留": {
        "en": "Keep",
        "ja": "保持",
        "ko": "유지",
        "zh-Hant": "保留"
    },
    "每次询问": {
        "en": "Ask Every Time",
        "ja": "毎回確認",
        "ko": "매번 묻기",
        "zh-Hant": "每次詢問"
    },
    "从不": {
        "en": "Never",
        "ja": "しない",
        "ko": "안 함",
        "zh-Hant": "從不"
    },
    "7 天前": {
        "en": "7 Days Ago",
        "ja": "7日前",
        "ko": "7일 전",
        "zh-Hant": "7 天前"
    },
    "30 天前": {
        "en": "30 Days Ago",
        "ja": "30日前",
        "ko": "30일 전",
        "zh-Hant": "30 天前"
    },
    "90 天前": {
        "en": "90 Days Ago",
        "ja": "90日前",
        "ko": "90일 전",
        "zh-Hant": "90 天前"
    },
    "代理配置": {
        "en": "Proxy Configuration",
        "ja": "プロキシ設定",
        "ko": "프록시 구성",
        "zh-Hant": "代理配置"
    },
    "需要重启应用以生效": {
        "en": "Restart required to apply",
        "ja": "適用するには再起動が必要です",
        "ko": "적용하려면 재시작 필요",
        "zh-Hant": "需要重啟應用以生效"
    },
    "代理服务器地址": {
        "en": "Proxy Server Address",
        "ja": "プロキシサーバーのアドレス",
        "ko": "프록시 서버 주소",
        "zh-Hant": "代理伺服器地址"
    },
    "认证 (可选)": {
        "en": "Authentication (Optional)",
        "ja": "認証（オプション）",
        "ko": "인증 (선택 사항)",
        "zh-Hant": "認證 (可選)"
    },
    "用户名": {
        "en": "Username",
        "ja": "ユーザー名",
        "ko": "사용자 이름",
        "zh-Hant": "用戶名"
    },
    "密码": {
        "en": "Password",
        "ja": "パスワード",
        "ko": "비밀번호",
        "zh-Hant": "密碼"
    },
    "RPC 设置": {
        "en": "RPC Settings",
        "ja": "RPC 設定",
        "ko": "RPC 설정",
        "zh-Hant": "RPC 設置"
    },
    "端口 (默认 16800)": {
        "en": "Port (Default 16800)",
        "ja": "ポート (デフォルト 16800)",
        "ko": "포트 (기본값 16800)",
        "zh-Hant": "端口 (默認 16800)"
    },
    "密钥 (Token)": {
        "en": "Secret Token",
        "ja": "シークレットトークン",
        "ko": "비밀 토큰",
        "zh-Hant": "密鑰 (Token)"
    },
    "协议关联": {
        "en": "Protocol Associations",
        "ja": "プロトコル関連付け",
        "ko": "프로토콜 연결",
        "zh-Hant": "協議關聯"
    },
    "拦截磁力链接 (Magnet)": {
        "en": "Intercept Magnet Links",
        "ja": "Magnet リンクを捕捉",
        "ko": "Magnet 링크 가로채기",
        "zh-Hant": "攔截磁力連結 (Magnet)"
    },
    "拦截迅雷链接 (Thunder)": {
        "en": "Intercept Thunder Links",
        "ja": "Thunder リンクを捕捉",
        "ko": "Thunder 링크 가로채기",
        "zh-Hant": "攔截迅雷連結 (Thunder)"
    },
    "开发者选项": {
        "en": "Developer Options",
        "ja": "開発者オプション",
        "ko": "개발자 옵션",
        "zh-Hant": "開發者選項"
    },
    "日志目录": {
        "en": "Log Directory",
        "ja": "ログディレクトリ",
        "ko": "로그 경로",
        "zh-Hant": "日誌目錄"
    },
    "打开": {
        "en": "Open",
        "ja": "開く",
        "ko": "열기",
        "zh-Hant": "打開"
    },
    "查看应用运行日志": {
        "en": "View app logs",
        "ja": "アプリログを表示",
        "ko": "앱 로그 보기",
        "zh-Hant": "查看應用運行日誌"
    },
    "退出 MotrixMac": {
        "en": "Quit MotrixMac",
        "ja": "MotrixMac を終了",
        "ko": "MotrixMac 종료",
        "zh-Hant": "退出 MotrixMac"
    },
    "6 个月": {
        "en": "6 Months",
        "ja": "6ヶ月",
        "ko": "6개월",
        "zh-Hant": "6 個月"
    },
    "授权失败": {
        "en": "Unauthorized",
        "ja": "認証失敗",
        "ko": "인증 실패",
        "zh-Hant": "授權失敗"
    },
    "最低允许分块大小": {
        "en": "Min Split Size",
        "ja": "最小分割サイズ",
        "ko": "최소 분할 크기",
        "zh-Hant": "最低允許分塊大小"
    },
    "Referer": {
        "en": "Referer",
        "ja": "Referer",
        "ko": "Referer",
        "zh-Hant": "Referer"
    },
    "峰值": {
        "en": "Peak",
        "ja": "ピーク",
        "ko": "피크",
        "zh-Hant": "峰值"
    },
    "添加后跳转到...": {
        "en": "Jump to...",
        "ja": "移動...",
        "ko": "이동...",
        "zh-Hant": "添加後跳轉到..."
    },
    "还有 %d 个任务": {
        "en": "%d more tasks",
        "ja": "あと %d 個のタスク",
        "ko": "%d개 작업 더 있음",
        "zh-Hant": "還有 %d 個任務"
    },
    "en": {
        "en": "en",
        "ja": "en",
        "ko": "en",
        "zh-Hant": "en"
    },
    "zh-CN": {
        "en": "zh-CN",
        "ja": "zh-CN",
        "ko": "zh-CN",
        "zh-Hant": "zh-CN"
    },
    "zh-TW": {
        "en": "zh-TW",
        "ja": "zh-TW",
        "ko": "zh-TW",
        "zh-Hant": "zh-TW"
    },
    "ja": {
        "en": "ja",
        "ja": "ja",
        "ko": "ja",
        "zh-Hant": "ja"
    },
    "ko": {
        "en": "ko",
        "ja": "ko",
        "ko": "ko",
        "zh-Hant": "ko"
    }
}
    
    # 3. Apply translations
    added_count = 0
    
    # Add newly scanned keys
    for key in localized_strings:
        if key not in data["strings"]:
             data["strings"][key] = {
                "extractionState": "manual",
                "localizations": {}
            }
             added_count += 1

    # Force update translations for KNOWN keys (both scanned and statically defined in dict)
    for key, val in translations.items():
        if key not in data["strings"]:
             data["strings"][key] = {
                "extractionState": "manual",
                "localizations": {}
            }
             added_count += 1
        
        # Always update localizations
        if "localizations" not in data["strings"][key]:
            data["strings"][key]["localizations"] = {}
            
        for lang, value in val.items():
            # Mark state as translated
            data["strings"][key]["localizations"][lang] = {
                "stringUnit": {
                    "state": "translated",
                    "value": value
                }
            }

    print(f"Updates applied. Total known keys processed: {len(translations)}")

    with open(xcstrings_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

if __name__ == "__main__":
    scan_and_update_xcstrings(
        "/Users/shawnrain/MotrixMac/MotrixMac", 
        "/Users/shawnrain/MotrixMac/MotrixMac/Resources/Localizable.xcstrings"
    )
    print("Localization update complete.")
