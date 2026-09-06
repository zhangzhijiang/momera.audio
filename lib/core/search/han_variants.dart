/// Traditional → Simplified Han folding, for search only.
///
/// **Why this exists.** The app ships both Chinese scripts and transcribes
/// Mandarin and Cantonese, so the same words are routinely written both ways —
/// a transcript may contain 会议 while the user types 會議. Without folding,
/// neither finds the other, which reads as "search is broken" rather than as a
/// script difference.
///
/// **What this is not.** It is not a general-purpose Chinese converter. It is a
/// curated table of frequently used characters that differ between the scripts,
/// used to normalise both sides of a comparison. It does not handle
/// one-to-many mappings (e.g. 乾/幹/干 all folding to 干 loses a distinction),
/// which is acceptable when the only consumer is a substring match but would
/// not be acceptable for displaying converted text. **Do not use it to convert
/// text shown to a user.**
///
/// Extending it is deliberately trivial: add a pair to [_pairs]. Characters
/// absent from the table pass through unchanged, so an incomplete table
/// degrades to "that character only matches itself" rather than to wrong
/// results.
library;

/// Traditional/Simplified pairs, flattened: even index is the traditional
/// form, the odd index immediately after it is the simplified form.
///
/// A flat string keeps this compact and makes misalignment detectable — a test
/// asserts the length is even and that no character maps to itself.
const String _pairs =
    // Pronouns, particles, everyday verbs
    '們们個个這这來来時时對对為为與与從从過过還还進进開开關关應应學学樣样'
    '種种點点實实現现發发動动電电機机業业產产經经濟济場场內内兩两東东車车'
    '買买賣卖錢钱銀银長长門门問问間间聞闻書书畫画讀读寫写記记認认識识見见'
    '觀观覺觉親亲華华國国圖图團团園园員员圓圆醫医藥药體体頭头顯显願愿類类'
    '風风飛飞馬马鳥鸟魚鱼鳳凤龍龙龜龟齊齐齒齿專专絲丝練练綠绿線线給给結结'
    '統统網网續续總总織织繼继約约級级紀纪純纯紙纸細细組组終终絕绝緊紧縣县'
    '縮缩績绩職职聯联聲声聽听腦脑臉脸舉举萬万葉叶號号蟲虫補补裝装複复規规'
    '視视覽览角角計计訂订討讨論论設设訪访評评譯译試试話话該该詳详語语誠诚'
    '說说課课調调誰谁請请諸诸諾诺謀谋謝谢證证議议護护讚赞豐丰貴贵費费資资'
    '賽赛贏赢軍军軟软載载輪轮輸输轉转農农運运達达違违遠远適适選选遺遗邊边'
    '鄉乡郵邮鄭郑酬酬釋释量量錄录鐘钟鐵铁鑑鉴閉闭閒闲閱阅闆板闊阔防防陸陆'
    '陽阳階阶際际隨随險险難难雲云需需靜静靠靠韓韩響响頁页頂顶項项順顺須须'
    '預预領领頸颈顆颗題题額额顏颜顧顾食食飯饭飲饮餅饼養养餐餐館馆首首香香'
    '駕驾騎骑驗验驚惊高高髮发鬥斗鮮鲜鳴鸣鴨鸭鵝鹅麗丽麥麦麵面黃黄黨党鼓鼓'
    '鼠鼠愛爱備备貝贝筆笔幣币標标賓宾補补參参蠶蚕層层產产長长償偿廠厂車车'
    '徹彻陳陈稱称遲迟衝冲蟲虫醜丑處处傳传瘡疮純纯詞词從从竄窜錯错達达帶带'
    '單单擔担黨党當当燈灯鄧邓敵敌遞递點点電电墊垫調调釘钉頂顶東东動动斷断'
    '隊队對对噸吨奪夺兒儿爾尔範范飯饭訪访費费墳坟豐丰風风鳳凤膚肤婦妇復复'
    '該该趕赶剛刚鋼钢個个給给龔龚溝沟構构購购穀谷顧顾關关觀观館馆廣广歸归'
    '龜龟國国過过韓韩漢汉號号閡阂護护劃划懷怀壞坏歡欢環环還还回回夥伙獲获'
    '擊击雞鸡積积極极幾几擠挤計计記记際际繼继家家價价檢检減减簡简見见劍剑'
    '講讲醬酱膠胶轎轿較较階阶節节結结誡诫緊紧盡尽進进經经驚惊競竞舊旧劇剧'
    '據据懼惧鋸锯開开課课墾垦懇恳誇夸塊块寬宽礦矿虧亏困困擴扩來来賴赖藍蓝'
    '欄栏爛烂勞劳樂乐壘垒類类離离禮礼裡里麗丽曆历隸隶連连煉炼練练糧粮兩两'
    '遼辽獵猎臨临鄰邻齡龄靈灵劉刘龍龙婁娄樓楼盧卢爐炉陸陆錄录慮虑亂乱掄抡'
    '羅罗絡络驢驴媽妈馬马嗎吗買买賣卖麥麦滿满貓猫黴霉夢梦廟庙滅灭憫悯畝亩'
    '難难腦脑鬧闹擬拟釀酿寧宁農农膿脓瘧疟歐欧嘔呕龐庞盤盘賠赔騙骗飄飘貧贫'
    '評评憑凭僕仆撲扑鋪铺樸朴齊齐騎骑豈岂啟启氣气棄弃遷迁籤签鉛铅錢钱潛潜'
    '淺浅槍枪牆墙強强搶抢橋桥竅窍竊窃親亲寢寝輕轻氫氢傾倾窮穷趨趋區区軀躯'
    '驅驱權权勸劝確确讓让擾扰熱热認认榮荣軟软灑洒傘伞喪丧掃扫澀涩殺杀曬晒'
    '傷伤賞赏燒烧紹绍設设攝摄審审滲渗聲声勝胜濕湿實实識识時时蝕蚀獸兽書书'
    '術术樹树雙双誰谁稅税順顺說说絲丝聳耸摻掺歲岁孫孙鎖锁態态攤摊癱瘫壇坛'
    '談谈嘆叹湯汤燙烫濤涛騰腾題题體体條条鐵铁聽听廳厅頭头圖图塗涂團团頹颓'
    '襪袜彎弯萬万網网圍围違违為为維维偉伟偽伪衛卫溫温聞闻問问穩稳務务霧雾'
    '犧牺習习係系蝦虾嚇吓鮮鲜纖纤鹹咸現现線线憲宪縣县鄉乡詳详響响項项象象'
    '嚮向蕭萧曉晓協协寫写瀉泻謝谢鋅锌釁衅興兴須须許许選选學学勳勋詢询壓压'
    '鴉鸦鹽盐顏颜閹阉嚴严顏颜癢痒樣样謠谣藥药爺爷業业頁页醫医儀仪億亿義义'
    '藝艺陰阴銀银飲饮應应纓缨營营蠅蝇穎颖硬硬擁拥傭佣踴踊優优郵邮猶犹遊游'
    '誘诱魚鱼漁渔語语獄狱預预譽誉淵渊園园遠远願愿約约躍跃鑰钥雲云運运韻韵'
    '雜杂災灾贊赞髒脏鑿凿棗枣責责擇择則则澤泽賊贼贈赠氈毡戰战棧栈張张漲涨'
    '賬账帳帐趙赵這这針针偵侦診诊鎮镇爭争睜睁證证鄭郑幟帜擲掷質质滯滞終终'
    '種种腫肿眾众軸轴皺皱晝昼豬猪囑嘱燭烛矚瞩專专轉转莊庄裝装壯壮狀状錐锥'
    '準准濁浊資资漬渍蹤踪縱纵鄒邹組组鑽钻'
    // Addendum: high-frequency characters the first pass missed. Found by
    // auditing common words against the table, not by guesswork.
    '會会師师檔档沒没麼么後后將将報报決决執执測测屬属數数導导辦办變变'
    '創创獨独惡恶負负雖虽誤误慶庆蘇苏訴诉損损貪贪貼贴壽寿勢势詩诗帥帅'
    '憂忧貨货禍祸換换揮挥匯汇監监堅坚漸渐腳脚潔洁僅仅淨净淚泪勵励輛辆'
    '療疗惱恼濃浓頻频貿贸塵尘襯衬廚厨觸触闖闯聰聪膽胆頓顿罰罚廢废紛纷'
    '蓋盖夠够貫贯軌轨隻只罷罢擺摆錶表財财採采慘惨側侧嘗尝暢畅鈔钞賀贺'
    '橫横貝贝閱阅陣阵嚴严屆届潤润潛潜緩缓潰溃騷骚攜携嶼屿';

/// Lazily built lookup, so the table is parsed once rather than per character.
final Map<String, String> _table = _buildTable();

Map<String, String> _buildTable() {
  assert(_pairs.length.isEven,
      'han variant table is misaligned: odd number of characters');
  final map = <String, String>{};
  for (var i = 0; i + 1 < _pairs.length; i += 2) {
    final traditional = _pairs[i];
    final simplified = _pairs[i + 1];
    if (traditional != simplified) map[traditional] = simplified;
  }
  return map;
}

/// Folds a single character to its Simplified form, or returns it unchanged.
String simplifyHan(String char) => _table[char] ?? char;

/// Number of folding rules, for tests and diagnostics.
int get hanVariantRuleCount => _table.length;
