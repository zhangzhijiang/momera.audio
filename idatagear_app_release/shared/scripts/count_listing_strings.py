# -*- coding: utf-8 -*-
"""Authoritative character counts for the McRecorder App Store listing.

Apple counts CHARACTERS, not bytes. len() on a Python 3 str is the right
measure for every field here.
"""

NAME = {
    "en-US": "McRecorder",
    "ja": "McRecorder",
    "ko": "McRecorder",
    "zh-Hans": "McRecorder",
    "zh-Hant": "McRecorder",
}

SUBTITLE = {
    "en-US": "Record and transcribe offline",
    "ja": "オフライン文字起こしレコーダー",
    "ko": "오프라인 받아쓰기 음성 녹음기",
    "zh-Hans": "离线转文字的录音机",
    "zh-Hant": "離線轉文字的錄音機",
}

KEYWORDS = {
    "en-US": "voice,memo,dictation,speech,text,audio,note,interview,lecture,meeting,caption,wav,录音,文字起こし,녹음",
    "ja": "録音,ボイスメモ,音声認識,書き起こし,議事録,会議,講義,インタビュー,字幕,テキスト化,文字変換,voice,memo,speech,transcribe",
    "ko": "음성메모,음성인식,전사,회의록,회의,강의,인터뷰,자막,텍스트변환,오디오,기록,voice,memo,speech,dictation,transcribe",
    "zh-Hans": "录音笔,语音转文字,会议记录,采访,讲座,字幕,听写,音频,文本,语音识别,粤语,普通话,voice,memo,speech,dictation",
    "zh-Hant": "錄音筆,語音轉文字,會議記錄,採訪,講座,字幕,聽寫,音訊,文字稿,語音辨識,粵語,國語,voice,memo,speech,dictation",
}

PROMO = {
    "en-US": "Speech-to-text that runs on your iPhone, not on a server. Record, transcribe in five languages, and search by what you actually said — with the network off.",
    "ja": "音声認識は端末の中だけで動きます。5言語を自動判別して文字にし、話した言葉で検索できます。ネットワークを切ったままで。",
    "ko": "음성 인식이 기기 안에서만 동작합니다. 5개 언어를 자동으로 판별해 글로 옮기고, 말한 내용으로 검색할 수 있습니다. 네트워크를 끈 채로.",
    "zh-Hans": "语音识别只在这台设备上运行，不上传服务器。自动判别五种语言并转成文字，还能按你说过的话搜索——全程可以断网。",
    "zh-Hant": "語音辨識只在這台裝置上執行，不上傳伺服器。自動判別五種語言並轉成文字，還能用你說過的話搜尋——全程可以斷網。",
}

PRIVACY_URL = "https://www.idatagear.com/privacy-policy-mcrecorder.html"

DESCRIPTION = {
"en-US": """McRecorder is a voice recorder that turns what you said into text — and does it entirely on your own iPhone.

RECORDING
• Tap once to record. Audio is saved as 16 kHz mono WAV: a plain, universal file you can open anywhere, not a format that locks you in.
• Keeps recording when you leave the app or lock the screen. iOS shows its own recording indicator the whole time.
• Pause and resume without ending the recording.
• Skip silence, so an hour in a quiet room does not become an hour of audio.
• A storage limit you choose, and an auto-save interval so an interruption costs you seconds rather than the whole session.

TRANSCRIPTION, OFFLINE
• Speech-to-text runs on the device. No account, no upload, no server.
• Mandarin, Cantonese, English, Japanese and Korean — detected automatically, phrase by phrase, so a conversation that switches language is transcribed in both.
• Hold the subtitles button while recording and watch the text arrive as each phrase finishes.
• The speech model is downloaded once (about 228 MB) and then kept on the device. After that, transcription works in Airplane Mode.

FINDING IT AGAIN
• Search by recording name or by what was actually said.
• Tap a result to start playing from the exact moment that phrase was spoken.
• A month calendar marks every day you recorded on; tap a day to see just that day.
• The home screen keeps today's recordings out of the way of the next one. History keeps everything.

THE REST
• A waveform you can scrub to any point.
• Rename a recording, share the audio, copy or share the transcript, remove a transcript without touching the audio.
• Light and dark themes, or follow the device.
• Interface in English, 简体中文, 繁體中文, 日本語 and 한국어.

PRIVACY
Your recordings never leave the iPhone. The app makes exactly one kind of network request in its life: downloading the speech model. There are no ads, no analytics, no account, no tracking and no in-app purchases. Recordings are stored in the app's own folder and are yours to share or delete.

Privacy Policy: """ + PRIVACY_URL,

"ja": """McRecorder は、話した内容をその場で文字にするボイスレコーダーです。処理はすべて iPhone の中で完結します。

録音
• タップするだけで録音開始。16 kHz モノラルの WAV で保存するので、どこでも開ける普通のファイルです。独自形式に縛られません。
• アプリを離れても画面をロックしても録音は続きます。その間は iOS の録音インジケータが表示されます。
• 録音を終了せずに一時停止・再開ができます。
• 無音をスキップ。静かな部屋で一時間置いても、一時間分の音声にはなりません。
• 保存容量の上限と自動保存の間隔を選べます。中断されても失われるのは数秒だけです。

文字起こし（オフライン）
• 音声認識は端末上で動きます。アカウントもアップロードもサーバーもありません。
• 中国語（標準語）・広東語・英語・日本語・韓国語に対応。フレーズごとに自動で判別するので、途中で言語が切り替わる会話も両方そのまま文字になります。
• 録音中に字幕ボタンを長押しすると、一区切りごとにテキストが表示されます。
• 音声モデルは初回だけダウンロード（約 228 MB）して端末に保存します。以降は機内モードでも文字起こしできます。

あとから見つける
• 録音名でも、話した言葉でも検索できます。
• 検索結果をタップすると、その言葉が話された時点から再生します。
• カレンダーが録音した日に印を付けます。日付をタップすればその日だけ表示。
• ホームは今日の録音だけ。それ以外はすべて履歴にあります。

そのほか
• 波形をドラッグして好きな位置へ。
• 名前の変更、音声の共有、文字起こしのコピーと共有、音声を残したまま文字起こしだけ削除。
• ライトテーマ／ダークテーマ、または端末の設定に追従。
• 表示言語は日本語、English、简体中文、繁體中文、한국어。

プライバシー
録音が iPhone から出ることはありません。このアプリが行う通信は、音声モデルのダウンロードだけです。広告も、解析も、アカウントも、トラッキングも、アプリ内課金もありません。

プライバシーポリシー: """ + PRIVACY_URL,

"ko": """McRecorder는 말한 내용을 그대로 글로 옮겨 주는 음성 녹음기입니다. 모든 처리는 iPhone 안에서 끝납니다.

녹음
• 한 번 누르면 녹음 시작. 16 kHz 모노 WAV로 저장하므로 어디서나 열 수 있는 평범한 파일이며, 독자 형식에 묶이지 않습니다.
• 앱을 벗어나거나 화면을 잠가도 녹음은 계속되고, 그동안 iOS의 녹음 표시가 켜져 있습니다.
• 녹음을 끝내지 않고 일시정지하고 다시 이어갈 수 있습니다.
• 무음 건너뛰기. 조용한 방에서 한 시간을 두어도 한 시간짜리 음성이 되지 않습니다.
• 저장 용량 한도와 자동 저장 간격을 직접 고를 수 있어, 중단되어도 잃는 것은 몇 초뿐입니다.

받아쓰기, 오프라인으로
• 음성 인식이 기기에서 실행됩니다. 계정도, 업로드도, 서버도 없습니다.
• 중국어(표준어), 광둥어, 영어, 일본어, 한국어를 문장 단위로 자동 인식하므로 도중에 언어가 바뀌는 대화도 양쪽 모두 받아씁니다.
• 녹음 중 자막 버튼을 누르고 있으면 한 구절이 끝날 때마다 글자가 나타납니다.
• 음성 모델은 처음 한 번만 내려받아(약 228 MB) 기기에 보관합니다. 그 뒤로는 비행기 모드에서도 받아쓰기가 됩니다.

다시 찾기
• 녹음 이름으로도, 말한 내용으로도 검색됩니다.
• 검색 결과를 누르면 그 말을 한 바로 그 지점부터 재생됩니다.
• 달력이 녹음한 날을 표시하고, 날짜를 누르면 그날만 볼 수 있습니다.
• 홈에는 오늘 것만, 나머지는 모두 기록에 있습니다.

그 밖에
• 파형을 끌어 원하는 지점으로 이동.
• 이름 바꾸기, 음성 공유, 받아쓴 글 복사와 공유, 음성은 두고 받아쓴 글만 삭제.
• 라이트·다크 테마 또는 기기 설정 따르기.
• 표시 언어는 한국어, English, 简体中文, 繁體中文, 日本語.

개인정보
녹음은 iPhone 밖으로 나가지 않습니다. 이 앱이 하는 통신은 음성 모델을 내려받는 것 하나뿐입니다. 광고도, 분석도, 계정도, 추적도, 인앱 구입도 없습니다.

개인정보 처리방침: """ + PRIVACY_URL,

"zh-Hans": """McRecorder 是一款把你说过的话直接变成文字的录音机，而且全部在 iPhone 本机完成。

录音
• 点一下就开始录。音频保存为 16 kHz 单声道 WAV——到哪儿都能打开的普通文件，不会被专有格式绑住。
• 离开应用或锁屏后继续录音，期间 iOS 会显示自己的录音指示标志。
• 可以暂停再继续，不必结束这一段录音。
• 跳过静音：在安静的房间里放一个小时，不会变成一个小时的音频。
• 存储上限和自动保存间隔都可以自己选，中断时最多只损失几秒。

离线转文字
• 语音识别在设备上运行。不需要账号，不上传，没有服务器。
• 支持普通话、粤语、英语、日语和韩语，按句自动识别语种，中途换语言的对话两种都能转出来。
• 录音时按住字幕按钮，说完一句就出现一句。
• 语音模型只需下载一次（约 228 MB），之后保存在设备上，飞行模式下也能转写。

再找回来
• 既能按录音名称搜索，也能搜你说过的话。
• 点搜索结果，就从说那句话的时间点开始播放。
• 日历标出录过音的每一天，点某一天只看那天的。
• 主屏只留今天的录音，其余全部在历史里。

其他
• 波形可以拖动到任意位置。
• 重命名、分享音频、复制或分享文字稿，也可以只删文字稿、保留音频。
• 浅色和深色主题，也可以跟随系统。
• 界面语言：简体中文、繁體中文、English、日本語、한국어。

隐私
录音不会离开这台 iPhone。这个应用一生中只发起一类网络请求：下载语音模型。没有广告，没有统计，没有账号，没有追踪，也没有任何应用内购买。

隐私政策：""" + PRIVACY_URL,

"zh-Hant": """McRecorder 是一款把你說過的話直接變成文字的錄音機，而且全部在 iPhone 本機完成。

錄音
• 按一下就開始錄。音訊存成 16 kHz 單聲道 WAV——到哪裡都打得開的普通檔案，不會被專有格式綁住。
• 離開應用程式或鎖定螢幕後繼續錄音，期間 iOS 會顯示自己的錄音指示標誌。
• 可以暫停再繼續，不必結束這一段錄音。
• 略過靜音：在安靜的房間裡放一小時，不會變成一小時的音訊。
• 儲存上限和自動儲存間隔都能自己選，中斷時最多只損失幾秒。

離線轉文字
• 語音辨識在裝置上執行。不需要帳號，不上傳，沒有伺服器。
• 支援國語、粵語、英語、日語和韓語，逐句自動判斷語言，中途換語言的對話兩種都轉得出來。
• 錄音時按住字幕按鈕，說完一句就出現一句。
• 語音模型只需下載一次（約 228 MB），之後保存在裝置上，飛航模式下也能轉寫。

再找回來
• 可以用錄音名稱搜尋，也可以搜你說過的話。
• 點搜尋結果，就從說那句話的時間點開始播放。
• 月曆標出錄過音的每一天，點某一天只看那天的。
• 主畫面只留今天的錄音，其餘全部在歷史紀錄裡。

其他
• 波形可以拖到任意位置。
• 重新命名、分享音訊、複製或分享文字稿，也可以只刪文字稿、保留音訊。
• 淺色與深色主題，也可以跟隨系統。
• 介面語言：繁體中文、简体中文、English、日本語、한국어。

隱私
錄音不會離開這支 iPhone。這個應用程式一生中只發出一種網路請求：下載語音模型。沒有廣告，沒有統計，沒有帳號，沒有追蹤，也沒有任何 App 內購買。

隱私權政策：""" + PRIVACY_URL,
}

RELEASE_NOTES = {
"en-US": """First release on the App Store.

• Record with one tap. Audio is saved as 16 kHz mono WAV, and recording continues when you leave the app or lock the screen.
• Pause and resume, and skip silence so a quiet stretch does not fill your storage.
• Offline speech-to-text in Mandarin, Cantonese, English, Japanese and Korean, detected automatically phrase by phrase. Nothing is uploaded.
• Live text while you record — hold the subtitles button.
• Search by what was said, and tap a result to play from that exact moment.
• History with a month calendar, a scrubable waveform, rename, and sharing for both audio and transcript.
• Light and dark themes; interface in English, 简体中文, 繁體中文, 日本語 and 한국어.""",

"ja": """App Store での最初のリリースです。

• ワンタップで録音。16 kHz モノラル WAV で保存し、アプリを離れても画面をロックしても録音は続きます。
• 一時停止と再開、そして無音スキップ。静かな時間で保存容量が埋まりません。
• オフラインの文字起こし。中国語（標準語）・広東語・英語・日本語・韓国語をフレーズごとに自動判別します。アップロードは一切ありません。
• 録音中のライブ字幕 — 字幕ボタンを長押し。
• 話した言葉で検索し、結果をタップするとその時点から再生します。
• カレンダー付きの履歴、ドラッグできる波形、名前の変更、音声と文字起こしの共有。
• ライト／ダークテーマ、表示言語は English、简体中文、繁體中文、日本語、한국어。""",

"ko": """App Store 첫 번째 릴리스입니다.

• 한 번 눌러 녹음. 16 kHz 모노 WAV로 저장되고, 앱을 벗어나거나 화면을 잠가도 녹음이 이어집니다.
• 일시정지와 재개, 그리고 무음 건너뛰기로 조용한 구간이 저장 공간을 채우지 않습니다.
• 오프라인 받아쓰기. 중국어(표준어), 광둥어, 영어, 일본어, 한국어를 문장 단위로 자동 인식합니다. 업로드는 전혀 없습니다.
• 녹음 중 실시간 자막 — 자막 버튼을 누르고 있으면 됩니다.
• 말한 내용으로 검색하고, 결과를 누르면 바로 그 지점부터 재생됩니다.
• 달력이 있는 기록 화면, 끌 수 있는 파형, 이름 바꾸기, 음성과 받아쓴 글 공유.
• 라이트·다크 테마, 표시 언어는 English, 简体中文, 繁體中文, 日本語, 한국어.""",

"zh-Hans": """App Store 首个版本。

• 一键录音。音频保存为 16 kHz 单声道 WAV，离开应用或锁屏后继续录。
• 暂停与继续，以及跳过静音，安静的时段不会占满存储。
• 离线转文字，支持普通话、粤语、英语、日语、韩语，按句自动识别语种。全程不上传。
• 录音时按住字幕按钮，实时出字。
• 按说过的话搜索，点击结果即从那一刻开始播放。
• 带日历的历史记录、可拖动的波形、重命名，音频与文字稿都能分享。
• 浅色与深色主题；界面语言：English、简体中文、繁體中文、日本語、한국어。""",

"zh-Hant": """App Store 首個版本。

• 一鍵錄音。音訊存成 16 kHz 單聲道 WAV，離開應用程式或鎖定螢幕後繼續錄。
• 暫停與繼續，以及略過靜音，安靜的時段不會佔滿儲存空間。
• 離線轉文字，支援國語、粵語、英語、日語、韓語，逐句自動判斷語言。全程不上傳。
• 錄音時按住字幕按鈕，即時出字。
• 用說過的話搜尋，點擊結果即從那一刻開始播放。
• 附月曆的歷史紀錄、可拖曳的波形、重新命名，音訊與文字稿都能分享。
• 淺色與深色主題；介面語言：English、简体中文、繁體中文、日本語、한국어。""",
}

LOCALES = ["en-US", "ja", "ko", "zh-Hans", "zh-Hant"]

LIMITS = {
    "App name": 30,
    "Subtitle": 30,
    "Keywords": 100,
    "Promotional text": 170,
    "Description": 4000,
    "What's New": 4000,
}

FIELDS = [
    ("App name", NAME),
    ("Subtitle", SUBTITLE),
    ("Keywords", KEYWORDS),
    ("Promotional text", PROMO),
    ("Description", DESCRIPTION),
    ("What's New", RELEASE_NOTES),
]


def main():
    fail = 0
    print(f"{'locale':9} {'field':18} {'n/limit':>10}  {'head':>5}  ok")
    print("-" * 56)
    for loc in LOCALES:
        for label, table in FIELDS:
            s = table[loc]
            n = len(s)
            lim = LIMITS[label]
            ok = n <= lim
            if not ok:
                fail += 1
            print(f"{loc:9} {label:18} {str(n)+'/'+str(lim):>10}  "
                  f"{lim-n:>5}  {'PASS' if ok else 'OVER'}")
        print()

    # Keyword hygiene: no space after comma, no term repeated from name/subtitle.
    print("keyword hygiene")
    print("-" * 56)
    for loc in LOCALES:
        kw = KEYWORDS[loc]
        terms = kw.split(",")
        problems = []
        if ", " in kw:
            problems.append("space after comma")
        reserved = (NAME[loc] + " " + SUBTITLE[loc]).lower()
        for t in terms:
            if t.lower() in reserved:
                problems.append(f"'{t}' repeats name/subtitle")
        if len(set(terms)) != len(terms):
            problems.append("duplicate term")
        print(f"{loc:9} {len(terms):>2} terms  "
              f"{'; '.join(problems) if problems else 'clean'}")
        if problems:
            fail += 1

    # Privacy URL must appear byte-identical in every description.
    print()
    print("privacy URL present and byte-identical in every description")
    print("-" * 56)
    for loc in LOCALES:
        present = PRIVACY_URL in DESCRIPTION[loc]
        print(f"{loc:9} {'PASS' if present else 'FAIL'}")
        if not present:
            fail += 1

    print()
    print("FAILURES:", fail)
    return fail


if __name__ == "__main__":
    raise SystemExit(1 if main() else 0)
