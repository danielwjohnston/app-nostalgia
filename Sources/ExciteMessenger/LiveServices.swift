import Foundation
import AVFoundation
import AppKit

// MARK: - Data Models

struct NewsItem {
    let title: String
    let subtitle: String
    let source: String
    let url: URL?
}

struct StockQuote {
    let symbol: String
    var price: String
    var change: String
    var isPositive: Bool
    var url: URL?
}

struct WeatherDay {
    let dayName: String
    let highF: Int
    let lowF: Int
    let condition: String
    let spriteIndex: Int // 0=Sunny, 1=PartlyCloudy, 2=Cloudy, 3=Rain, 4=Storm, 5=Snow
}

struct TVListingItem {
    let time: String
    let network: String
    let showTitle: String
    let episodeTitle: String
    let rating: String
    let url: URL?
}

struct DealItem {
    let title: String
    let salePrice: String
    let normalPrice: String
    let savingsPct: String
    let url: URL?
}

struct RadioStation {
    let id: String
    let network: String
    let name: String
    let genre: String
    let streamURL: URL
    var currentArtist: String
    var currentSong: String
    var currentAlbum: String
}

struct ChatMessage {
    let sender: String
    let text: String
    let timestamp: String
    let isFromUser: Bool
}

struct BuddyContact {
    let handle: String
    let displayName: String
    let role: String
    var status: String // "Online", "Away", "Offline"
    var statusMessage: String
    var messages: [ChatMessage]
    var unreadCount: Int
}

// MARK: - Live Services Coordinator

@MainActor
final class LiveServices {
    static let shared = LiveServices()

    var onUpdate: (() -> Void)?
    var onIncomingIM: ((String, ChatMessage) -> Void)?

    // 1. TuneIn Radio State
    private var avPlayer: AVPlayer?
    private(set) var radioPlaying: Bool = false
    private(set) var radioPaused: Bool = false
    private(set) var radioVolume: Float = 0.72 {
        didSet {
            avPlayer?.volume = radioVolume
        }
    }
    private(set) var currentStationIndex: Int = 0
    private(set) var stations: [RadioStation] = [
        RadioStation(
            id: "groovesalad",
            network: "SomaFM",
            name: "Groove Salad",
            genre: "Ambient / Downtempo",
            streamURL: URL(string: "https://ice2.somafm.com/groovesalad-128-mp3")!,
            currentArtist: "Zero 7",
            currentSong: "In The Waiting Line",
            currentAlbum: "Simple Things"
        ),
        RadioStation(
            id: "secretagent",
            network: "SomaFM",
            name: "Secret Agent",
            genre: "Spy Lounge & Soundtracks",
            streamURL: URL(string: "https://ice2.somafm.com/secretagent-128-mp3")!,
            currentArtist: "Lalo Schifrin",
            currentSong: "Mission: Impossible",
            currentAlbum: "OST (1999 Remaster)"
        ),
        RadioStation(
            id: "defcon",
            network: "SomaFM",
            name: "DEF CON Radio",
            genre: "Hacker & Electronica",
            streamURL: URL(string: "https://ice2.somafm.com/defcon-128-mp3")!,
            currentArtist: "The Crystal Method",
            currentSong: "Keep Hope Alive",
            currentAlbum: "Vegas"
        ),
        RadioStation(
            id: "u80s",
            network: "SomaFM",
            name: "Underground 80s",
            genre: "Early Synthpop & New Wave",
            streamURL: URL(string: "https://ice2.somafm.com/u80s-128-mp3")!,
            currentArtist: "New Order",
            currentSong: "Blue Monday",
            currentAlbum: "Power, Corruption & Lies"
        ),
        RadioStation(
            id: "seventies",
            network: "SomaFM",
            name: "Left Coast 70s",
            genre: "Mellow 70s Album Rock",
            streamURL: URL(string: "https://ice2.somafm.com/seventies-128-mp3")!,
            currentArtist: "Steely Dan",
            currentSong: "Deacon Blues",
            currentAlbum: "Aja"
        ),
        RadioStation(
            id: "lush",
            network: "SomaFM",
            name: "Lush",
            genre: "Dream Pop & Shoegaze",
            streamURL: URL(string: "https://ice2.somafm.com/lush-128-mp3")!,
            currentArtist: "Massive Attack",
            currentSong: "Teardrop",
            currentAlbum: "Mezzanine"
        )
    ]

    // 2. Weather State (Open-Meteo)
    private(set) var weatherCity: String = "Redwood City, CA"
    private(set) var weatherLat: Double = 37.4852
    private(set) var weatherLon: Double = -122.2364
    private(set) var currentTempF: Int = 72
    private(set) var currentCondition: String = "Mostly Sunny"
    private(set) var weatherDays: [WeatherDay] = [
        WeatherDay(dayName: "Today", highF: 72, lowF: 54, condition: "Sunny", spriteIndex: 0),
        WeatherDay(dayName: "Tom", highF: 70, lowF: 53, condition: "Pt Cloudy", spriteIndex: 1),
        WeatherDay(dayName: "Wed", highF: 68, lowF: 51, condition: "Cloudy", spriteIndex: 2),
        WeatherDay(dayName: "Thu", highF: 65, lowF: 49, condition: "Showers", spriteIndex: 3),
        WeatherDay(dayName: "Fri", highF: 71, lowF: 52, condition: "Sunny", spriteIndex: 0)
    ]

    // 3. News State (6 sub-tabs: Top News, Business, Sci/Tech, Odd, Sports, Photos)
    private(set) var newsBySubtab: [[NewsItem]] = Array(repeating: [], count: 6)

    // 4. Stocks State
    private(set) var stocks: [StockQuote] = [
        StockQuote(symbol: "BTC-USD", price: "Loading...", change: "+0.0%", isPositive: true, url: URL(string: "https://www.coingecko.com/en/coins/bitcoin")),
        StockQuote(symbol: "ETH-USD", price: "Loading...", change: "+0.0%", isPositive: true, url: URL(string: "https://www.coingecko.com/en/coins/ethereum")),
        StockQuote(symbol: "SOL-USD", price: "Loading...", change: "+0.0%", isPositive: true, url: URL(string: "https://www.coingecko.com/en/coins/solana")),
        StockQuote(symbol: "NVDA", price: "138.60", change: "+2.4%", isPositive: true, url: URL(string: "https://finance.yahoo.com/quote/NVDA")),
        StockQuote(symbol: "AAPL", price: "231.40", change: "+0.8%", isPositive: true, url: URL(string: "https://finance.yahoo.com/quote/AAPL")),
        StockQuote(symbol: "MSFT", price: "428.15", change: "+1.1%", isPositive: true, url: URL(string: "https://finance.yahoo.com/quote/MSFT")),
        StockQuote(symbol: "GOOG", price: "182.50", change: "+1.5%", isPositive: true, url: URL(string: "https://finance.yahoo.com/quote/GOOG")),
        StockQuote(symbol: "ATHM", price: "94.38", change: "+12.5%", isPositive: true, url: URL(string: "https://web.archive.org/web/19991012041509/http://excite.com/"))
    ]

    // 5. TV Listings State (TVMaze)
    private(set) var tvListings: [TVListingItem] = []

    // 6. Deals State (CheapShark)
    private(set) var deals: [DealItem] = []

    // 7. Search Results State (Wikipedia / DuckDuckGo)
    private(set) var searchQuery: String = "Excite@Home"
    private(set) var searchResults: [NewsItem] = []

    // 8. Horoscopes State
    let zodiacSigns = [
        "Aries (Mar 21-Apr 19)", "Taurus (Apr 20-May 20)", "Gemini (May 21-Jun 20)",
        "Cancer (Jun 21-Jul 22)", "Leo (Jul 23-Aug 22)", "Virgo (Aug 23-Sep 22)",
        "Libra (Sep 23-Oct 22)", "Scorpio (Oct 23-Nov 21)", "Sagittarius (Nov 22-Dec 21)",
        "Capricorn (Dec 22-Jan 19)", "Aquarius (Jan 20-Feb 18)", "Pisces (Feb 19-Mar 20)"
    ]
    private(set) var selectedZodiacIndex: Int = 7 // Scorpio

    // 9. Excite Messenger Buddies & Inbox
    private(set) var buddies: [BuddyContact] = [
        BuddyContact(
            handle: "swerndorfer@excite.com",
            displayName: "Scott Werndorfer",
            role: "Excite Assistant Lead Engineer (1999)",
            status: "Online",
            statusMessage: "Debugging TSlidingWins SetWindowRgn...",
            messages: [
                ChatMessage(sender: "Scott Werndorfer", text: "Hey! Welcome back to Excite Assistant v1.1.3.3. Notice how smooth that `sar ecx, 3` drawer slide still feels on macOS?", timestamp: "12:01 PM", isFromUser: false)
            ],
            unreadCount: 1
        ),
        BuddyContact(
            handle: "kkurtz@excite.com",
            displayName: "Kevin Kurtz",
            role: "Excite@Home UI & Region Engineer",
            status: "Online",
            statusMessage: "Carving scalloped tabs with RGN_DIFF",
            messages: [
                ChatMessage(sender: "Kevin Kurtz", text: "We used pure blue #0000FF for the transparent region mask and #CCFF00 lime for the sprite gutter in bmp_317!", timestamp: "12:02 PM", isFromUser: false)
            ],
            unreadCount: 0
        ),
        BuddyContact(
            handle: "cjklug@excite.com",
            displayName: "C.J. klug",
            role: "Excite Desktop Architecture",
            status: "Online",
            statusMessage: "Listening to SomaFM on TuneIn",
            messages: [
                ChatMessage(sender: "C.J. klug", text: "Click Play on the bottom TuneIn bar to stream real live SomaFM radio through AVPlayer!", timestamp: "12:03 PM", isFromUser: false)
            ],
            unreadCount: 0
        ),
        BuddyContact(
            handle: "ask_excite@excite.com",
            displayName: "Excite Live Bot",
            role: "Wikipedia / Weather / News Assistant",
            status: "Online",
            statusMessage: "Ask me any topic for instant live lookup!",
            messages: [
                ChatMessage(sender: "Excite Live Bot", text: "Hi! Send me any question or keyword and I will query Wikipedia, Open-Meteo Weather, and Hacker News for you in real time!", timestamp: "12:04 PM", isFromUser: false)
            ],
            unreadCount: 0
        )
    ]

    private init() {
        populateInitialSeedData()
    }

    func refreshAllLiveFeeds() {
        fetchSomaFMChannels()
        fetchOpenMeteoWeather()
        fetchLiveCryptoAndStocks()
        fetchHackerNewsTopStories()
        fetchSpaceflightSciTechNews()
        fetchRedditOddAndBusinessNews()
        fetchESPNSportsNews()
        fetchTVMazeSchedule()
        fetchCheapSharkDeals()
        performLiveSearch(query: searchQuery)
    }

    // MARK: - Radio Controls (AVPlayer)

    var currentStation: RadioStation {
        stations[currentStationIndex]
    }

    func playRadio() {
        let station = stations[currentStationIndex]
        if avPlayer == nil || !radioPaused {
            let item = AVPlayerItem(url: station.streamURL)
            avPlayer = AVPlayer(playerItem: item)
            avPlayer?.volume = radioVolume
        }
        avPlayer?.play()
        radioPlaying = true
        radioPaused = false
        fetchSomaFMChannels()
        onUpdate?()
    }

    func pauseRadio() {
        guard radioPlaying else { return }
        avPlayer?.pause()
        radioPlaying = false
        radioPaused = true
        onUpdate?()
    }

    func stopRadio() {
        avPlayer?.pause()
        avPlayer = nil
        radioPlaying = false
        radioPaused = false
        onUpdate?()
    }

    func nextRadioChannel() {
        currentStationIndex = (currentStationIndex + 1) % stations.count
        if radioPlaying {
            radioPaused = false
            playRadio()
        } else {
            onUpdate?()
        }
    }

    func prevRadioChannel() {
        currentStationIndex = (currentStationIndex - 1 + stations.count) % stations.count
        if radioPlaying {
            radioPaused = false
            playRadio()
        } else {
            onUpdate?()
        }
    }

    func setVolume(_ vol: Float) {
        radioVolume = max(0.0, min(1.0, vol))
        onUpdate?()
    }

    // MARK: - Dual-Ballistic VU Meter Engine (Instant Attack, 300ms Decay, Peak Hold)

    private(set) var currentRMSLevel: Float = 0.0
    private(set) var peakHoldLevel: Float = 0.0
    private var peakHoldFrames: Int = 0

    func updateMeterBallistics() {
        guard radioPlaying && !radioPaused else {
            currentRMSLevel = max(0.0, currentRMSLevel - 0.12)
            peakHoldLevel = max(0.0, peakHoldLevel - 0.08)
            return
        }

        // Real-time dynamic audio energy modeling scaled by volume:
        // Combines bass envelope (~120bpm), rhythm modulation, and vocal transients
        let t = Date().timeIntervalSinceReferenceDate
        let beat1 = Float(sin(t * 8.2)) * 0.24
        let beat2 = Float(cos(t * 16.4)) * 0.16
        let jitter = Float(sin(t * 33.1)) * 0.10
        let baseLevel = max(0.10, radioVolume * 0.70)
        let dynamicEnergy = max(0.0, min(1.0, baseLevel + (beat1 + beat2 + jitter) * radioVolume))

        // Fast attack (instant jump)
        if dynamicEnergy > currentRMSLevel {
            currentRMSLevel = dynamicEnergy
        } else {
            // 300ms smooth exponential decay
            currentRMSLevel = max(0.0, currentRMSLevel * 0.84)
        }

        // Peak Hold logic
        if currentRMSLevel >= peakHoldLevel {
            peakHoldLevel = currentRMSLevel
            peakHoldFrames = 12 // hold for ~350ms
        } else {
            if peakHoldFrames > 0 {
                peakHoldFrames -= 1
            } else {
                peakHoldLevel = max(0.0, peakHoldLevel - 0.05)
            }
        }
    }

    func fetchSomaFMChannels() {
        guard let url = URL(string: "https://api.somafm.com/channels.json") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let channels = json["channels"] as? [[String: Any]] else { return }

            var parsedById: [String: (String, String)] = [:]
            for ch in channels {
                if let id = ch["id"] as? String,
                   let lastPlaying = ch["lastPlaying"] as? String {
                    let parts = lastPlaying.components(separatedBy: " - ")
                    let artist = parts.first?.trimmingCharacters(in: .whitespaces) ?? "SomaFM"
                    let song = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                    parsedById[id] = (artist, song.isEmpty ? lastPlaying : song)
                }
            }

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                for i in 0..<self.stations.count {
                    let id = self.stations[i].id
                    if let (artist, song) = parsedById[id] {
                        self.stations[i].currentArtist = artist
                        self.stations[i].currentSong = song
                        self.stations[i].currentAlbum = "\(self.stations[i].name) Live Stream"
                    }
                }
                self.onUpdate?()
            }
        }.resume()
    }

    // MARK: - Live Weather (Open-Meteo)

    func updateWeatherLocation(cityQuery: String) {
        let encoded = cityQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Redwood%20City"
        guard let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=en&format=json") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let name = first["name"] as? String,
                  let lat = first["latitude"] as? Double,
                  let lon = first["longitude"] as? Double else { return }
            let admin1 = first["admin1"] as? String ?? ""
            let label = admin1.isEmpty ? name : "\(name), \(admin1.prefix(2).uppercased())"
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.weatherCity = label
                self.weatherLat = lat
                self.weatherLon = lon
                self.fetchOpenMeteoWeather()
            }
        }.resume()
    }

    func fetchOpenMeteoWeather() {
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(weatherLat)&longitude=\(weatherLon)&current_weather=true&daily=weathercode,temperature_2m_max,temperature_2m_min&temperature_unit=fahrenheit&timezone=auto"
        guard let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            var curTemp = 72
            var curCond = "Sunny"
            if let cw = json["current_weather"] as? [String: Any] {
                if let t = cw["temperature"] as? Double { curTemp = Int(t.rounded()) }
                if let code = cw["weathercode"] as? Int {
                    curCond = Self.mapWMOCode(code).label
                }
            }

            var days: [WeatherDay] = []
            if let daily = json["daily"] as? [String: Any],
               let times = daily["time"] as? [String],
               let maxs = daily["temperature_2m_max"] as? [Double],
               let mins = daily["temperature_2m_min"] as? [Double],
               let codes = daily["weathercode"] as? [Int] {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                let outDf = DateFormatter()
                outDf.dateFormat = "EEE"

                let count = min(5, min(times.count, min(maxs.count, min(mins.count, codes.count))))
                for i in 0..<count {
                    let dayLabel: String
                    if i == 0 {
                        dayLabel = "Today"
                    } else if let d = df.date(from: times[i]) {
                        dayLabel = outDf.string(from: d)
                    } else {
                        dayLabel = times[i]
                    }
                    let mapped = Self.mapWMOCode(codes[i])
                    days.append(WeatherDay(
                        dayName: dayLabel,
                        highF: Int(maxs[i].rounded()),
                        lowF: Int(mins[i].rounded()),
                        condition: mapped.label,
                        spriteIndex: mapped.sprite
                    ))
                }
            }

            let finalTemp = curTemp
            let finalCond = curCond
            let finalDays = days

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentTempF = finalTemp
                self.currentCondition = finalCond
                if !finalDays.isEmpty {
                    self.weatherDays = finalDays
                }
                self.onUpdate?()
            }
        }.resume()
    }

    nonisolated private static func mapWMOCode(_ code: Int) -> (label: String, sprite: Int) {
        switch code {
        case 0: return ("Sunny", 0)
        case 1, 2: return ("Pt Cloudy", 1)
        case 3, 45, 48: return ("Cloudy", 2)
        case 51...67, 80...82: return ("Rain", 3)
        case 71...77, 85, 86: return ("Snow", 5)
        case 95...99: return ("T-Storms", 4)
        default: return ("Pt Cloudy", 1)
        }
    }

    // MARK: - Live Stocks & Crypto (CoinGecko + Stooq/Yahoo)

    func fetchLiveCryptoAndStocks() {
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,solana,dogecoin&vs_currencies=usd&include_24hr_change=true") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Double]] else { return }

            let mapping: [(String, String, String)] = [
                ("bitcoin", "BTC-USD", "https://www.coingecko.com/en/coins/bitcoin"),
                ("ethereum", "ETH-USD", "https://www.coingecko.com/en/coins/ethereum"),
                ("solana", "SOL-USD", "https://www.coingecko.com/en/coins/solana"),
                ("dogecoin", "DOGE", "https://www.coingecko.com/en/coins/dogecoin")
            ]

            var updatedCrypto: [StockQuote] = []
            for (id, sym, link) in mapping {
                if let entry = json[id], let usd = entry["usd"] {
                    let chg = entry["usd_24h_change"] ?? 0.0
                    let priceStr = usd >= 100 ? String(format: "%.0f", usd) : String(format: "%.2f", usd)
                    let chgStr = String(format: "%@%.1f%%", chg >= 0 ? "+" : "", chg)
                    updatedCrypto.append(StockQuote(
                        symbol: sym,
                        price: priceStr,
                        change: chgStr,
                        isPositive: chg >= 0,
                        url: URL(string: link)
                    ))
                }
            }

            let finalCrypto = updatedCrypto
            Task { @MainActor [weak self] in
                guard let self = self, !finalCrypto.isEmpty else { return }
                let existingEquities = self.stocks.filter { !["BTC-USD", "ETH-USD", "SOL-USD", "DOGE"].contains($0.symbol) }
                self.stocks = finalCrypto + existingEquities
                self.onUpdate?()
            }
        }.resume()
    }

    // MARK: - Live News (6 Sub-tabs)

    func fetchHackerNewsTopStories() {
        guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let ids = try? JSONSerialization.jsonObject(with: data) as? [Int] else { return }
            let topIds = Array(ids.prefix(8))
            let group = DispatchGroup()
            let lock = NSLock()
            var fetched: [(Int, NewsItem)] = []

            for (idx, id) in topIds.enumerated() {
                group.enter()
                let itemURL = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json")!
                URLSession.shared.dataTask(with: itemURL) { iData, _, _ in
                    defer { group.leave() }
                    guard let iData = iData,
                          let obj = try? JSONSerialization.jsonObject(with: iData) as? [String: Any],
                          let title = obj["title"] as? String else { return }
                    let score = obj["score"] as? Int ?? 0
                    let by = obj["by"] as? String ?? "hn"
                    let urlStr = obj["url"] as? String ?? "https://news.ycombinator.com/item?id=\(id)"
                    let item = NewsItem(
                        title: title,
                        subtitle: "\(score) pts by \(by) — Click to open article",
                        source: "Hacker News Live",
                        url: URL(string: urlStr)
                    )
                    lock.lock()
                    fetched.append((idx, item))
                    lock.unlock()
                }.resume()
            }

            group.notify(queue: .main) { [weak self] in
                let sorted = fetched.sorted { $0.0 < $1.0 }.map { $0.1 }
                Task { @MainActor [weak self] in
                    guard let self = self, !sorted.isEmpty else { return }
                    self.newsBySubtab[0] = sorted
                    self.onUpdate?()
                }
            }
        }.resume()
    }

    func fetchSpaceflightSciTechNews() {
        guard let url = URL(string: "https://api.spaceflightnewsapi.net/v4/articles/?limit=8") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else { return }
            var items: [NewsItem] = []
            for r in results {
                let title = r["title"] as? String ?? "Sci/Tech Headline"
                let summary = r["summary"] as? String ?? ""
                let site = r["news_site"] as? String ?? "Spaceflight News"
                let link = r["url"] as? String ?? ""
                items.append(NewsItem(
                    title: title,
                    subtitle: String(summary.prefix(90)),
                    source: site,
                    url: URL(string: link)
                ))
            }
            let finalItems = items
            Task { @MainActor [weak self] in
                guard let self = self, !finalItems.isEmpty else { return }
                self.newsBySubtab[2] = finalItems // Sci/Tech
                self.onUpdate?()
            }
        }.resume()
    }

    func fetchRedditOddAndBusinessNews() {
        let feeds: [(Int, String, String)] = [
            (1, "https://www.reddit.com/r/business/hot.json?limit=8", "Business Wire / Reddit"),
            (3, "https://www.reddit.com/r/nottheonion/hot.json?limit=8", "Oddly Enough / r/nottheonion"),
            (5, "https://www.reddit.com/r/EarthPorn/hot.json?limit=8", "Featured Photos")
        ]
        for (subtabIdx, urlStr, sourceLabel) in feeds {
            guard let url = URL(string: urlStr) else { continue }
            var req = URLRequest(url: url)
            req.setValue("ExciteMessenger/2.0 (macOS)", forHTTPHeaderField: "User-Agent")
            URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataObj = json["data"] as? [String: Any],
                      let children = dataObj["children"] as? [[String: Any]] else { return }
                var items: [NewsItem] = []
                for child in children {
                    guard let post = child["data"] as? [String: Any],
                          let title = post["title"] as? String else { continue }
                    if post["stickied"] as? Bool == true { continue }
                    let domain = post["domain"] as? String ?? sourceLabel
                    let ups = post["ups"] as? Int ?? 0
                    let link = post["url"] as? String ?? "https://www.reddit.com"
                    items.append(NewsItem(
                        title: title,
                        subtitle: "\(ups) upvotes • \(domain)",
                        source: sourceLabel,
                        url: URL(string: link)
                    ))
                }
                let finalItems = items
                Task { @MainActor [weak self] in
                    guard let self = self, !finalItems.isEmpty else { return }
                    self.newsBySubtab[subtabIdx] = finalItems
                    self.onUpdate?()
                }
            }.resume()
        }
    }

    func fetchESPNSportsNews() {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/news?limit=8") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let articles = json["articles"] as? [[String: Any]] else { return }
            var items: [NewsItem] = []
            for a in articles {
                let headline = a["headline"] as? String ?? "Sports Update"
                let desc = a["description"] as? String ?? "Click to view full coverage on ESPN"
                var webUrl = "https://www.espn.com"
                if let links = a["links"] as? [String: Any],
                   let web = links["web"] as? [String: Any],
                   let href = web["href"] as? String {
                    webUrl = href
                }
                items.append(NewsItem(
                    title: headline,
                    subtitle: String(desc.prefix(90)),
                    source: "ESPN Live Sports",
                    url: URL(string: webUrl)
                ))
            }
            let finalItems = items
            Task { @MainActor [weak self] in
                guard let self = self, !finalItems.isEmpty else { return }
                self.newsBySubtab[4] = finalItems // Sports
                self.onUpdate?()
            }
        }.resume()
    }

    // MARK: - Live TV Listings (TVMaze API)

    func fetchTVMazeSchedule() {
        guard let url = URL(string: "https://api.tvmaze.com/schedule?country=US") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
            var items: [TVListingItem] = []
            for entry in arr.suffix(18) {
                let airtime = entry["airtime"] as? String ?? "20:00"
                let epName = entry["name"] as? String ?? "Episode"
                var showName = "Program"
                var netName = "TV"
                var showUrl = "https://www.tvmaze.com"
                if let show = entry["show"] as? [String: Any] {
                    showName = show["name"] as? String ?? "Program"
                    if let u = show["url"] as? String { showUrl = u }
                    if let net = show["network"] as? [String: Any], let n = net["name"] as? String {
                        netName = n
                    } else if let web = show["webChannel"] as? [String: Any], let n = web["name"] as? String {
                        netName = n
                    }
                }
                items.append(TVListingItem(
                    time: airtime,
                    network: String(netName.prefix(8)).uppercased(),
                    showTitle: showName,
                    episodeTitle: epName,
                    rating: "TV-PG",
                    url: URL(string: showUrl)
                ))
            }
            let finalItems = items
            Task { @MainActor [weak self] in
                guard let self = self, !finalItems.isEmpty else { return }
                self.tvListings = finalItems
                self.onUpdate?()
            }
        }.resume()
    }

    // MARK: - Live Deals (CheapShark API)

    func fetchCheapSharkDeals() {
        guard let url = URL(string: "https://www.cheapshark.com/api/1.0/deals?pageSize=10") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
            var items: [DealItem] = []
            for d in arr {
                let title = d["title"] as? String ?? "Special Deal"
                let sale = d["salePrice"] as? String ?? "0.00"
                let normal = d["normalPrice"] as? String ?? "0.00"
                let savRaw = Double(d["savings"] as? String ?? "0") ?? 0
                let dealID = d["dealID"] as? String ?? ""
                items.append(DealItem(
                    title: title,
                    salePrice: "$\(sale)",
                    normalPrice: "$\(normal)",
                    savingsPct: String(format: "-%.0f%%", savRaw),
                    url: URL(string: "https://www.cheapshark.com/redirect?dealID=\(dealID)")
                ))
            }
            let finalItems = items
            Task { @MainActor [weak self] in
                guard let self = self, !finalItems.isEmpty else { return }
                self.deals = finalItems
                self.onUpdate?()
            }
        }.resume()
    }

    // MARK: - Live Search (Wikipedia API)

    func performLiveSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        self.searchQuery = trimmed
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Excite"
        guard let url = URL(string: "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=\(encoded)&utf8=&format=json&srlimit=8") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let qObj = json["query"] as? [String: Any],
                  let searchArr = qObj["search"] as? [[String: Any]] else { return }
            var results: [NewsItem] = []
            for s in searchArr {
                let title = s["title"] as? String ?? "Result"
                let rawSnippet = s["snippet"] as? String ?? ""
                let cleanSnippet = rawSnippet.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                let pageUrl = "https://en.wikipedia.org/wiki/\(title.replacingOccurrences(of: " ", with: "_"))"
                results.append(NewsItem(
                    title: title,
                    subtitle: cleanSnippet,
                    source: "Excite / Wikipedia Instant Search",
                    url: URL(string: pageUrl)
                ))
            }
            let finalResults = results
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.searchResults = finalResults
                self.onUpdate?()
            }
        }.resume()
    }

    // MARK: - Horoscope Generator

    func cycleZodiacSign() {
        selectedZodiacIndex = (selectedZodiacIndex + 1) % zodiacSigns.count
        onUpdate?()
    }

    func currentHoroscopeText() -> (sign: String, forecast: String, lucky: String) {
        let sign = zodiacSigns[selectedZodiacIndex]
        let forecasts = [
            "Mercury trine Jupiter energizes your creative communications today. An old 1999 project or interface idea returns with unexpected modern momentum.",
            "Venus aligns with Saturn in your house of craftsmanship. Tactile attention to pixel bevels and clean architecture pays dividends this afternoon.",
            "Mars sparks rapid problem-solving in your network sector. A conversation on Excite Messenger opens a promising collaborative doorway.",
            "The Moon illuminates your analytical sixth house. Trust your intuition when refactoring legacy systems into crisp modern engines."
        ]
        let idx = (selectedZodiacIndex + Calendar.current.component(.day, from: Date())) % forecasts.count
        return (
            sign: sign,
            forecast: forecasts[idx],
            lucky: "Lucky Numbers: 99, 317, 42, 8 • Star Rating: ★★★★☆"
        )
    }

    // MARK: - Excite Messenger Instant Messaging

    func clearUnread(forHandle handle: String) {
        if let idx = buddies.firstIndex(where: { $0.handle == handle }) {
            buddies[idx].unreadCount = 0
            onUpdate?()
        }
    }

    func sendInstantMessage(toHandle handle: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = buddies.firstIndex(where: { $0.handle == handle }) else { return }

        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        let nowStr = df.string(from: Date())

        let userMsg = ChatMessage(sender: "You", text: trimmed, timestamp: nowStr, isFromUser: true)
        buddies[idx].messages.append(userMsg)
        AssetManager.shared.playSound("wav418")
        onUpdate?()

        let buddyName = buddies[idx].displayName

        // 1. In-Chat Slash Commands for Ollama & 1Password
        if trimmed.hasPrefix("/") {
            let parts = trimmed.components(separatedBy: " ")
            let cmd = parts[0].lowercased()
            let arg = parts.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

            switch cmd {
            case "/key":
                if arg.isEmpty {
                    deliverBuddyReply(handle: handle, sender: "System", text: "Usage: /key <your_ollama_api_key_from_1password>")
                } else {
                    OllamaService.shared.updateSettings(host: nil, apiKey: arg, model: nil, opItem: nil)
                    deliverBuddyReply(handle: handle, sender: "System", text: "Saved Ollama API key from 1Password! Chatbot sessions will now use this key.")
                }
                return

            case "/model":
                if arg.isEmpty {
                    let curModel = OllamaService.shared.config.model
                    deliverBuddyReply(handle: handle, sender: "System", text: "Current model: \(curModel). Usage: /model <model_name> (e.g. /model qwen2.5-coder:3b or /model gemma4:26b)")
                } else {
                    OllamaService.shared.updateSettings(host: nil, apiKey: nil, model: arg, opItem: nil)
                    deliverBuddyReply(handle: handle, sender: "System", text: "Active Ollama model set to '\(arg)'.")
                }
                return

            case "/host":
                if arg.isEmpty {
                    deliverBuddyReply(handle: handle, sender: "System", text: "Usage: /host <url> (e.g. /host http://localhost:11434)")
                } else {
                    OllamaService.shared.updateSettings(host: arg, apiKey: nil, model: nil, opItem: nil)
                    deliverBuddyReply(handle: handle, sender: "System", text: "Ollama host set to '\(arg)'.")
                }
                return

            case "/op":
                let itemName = arg.isEmpty ? OllamaService.shared.config.opItem : arg
                if let key = OllamaService.shared.fetchKeyFrom1Password(itemName: itemName) {
                    deliverBuddyReply(handle: handle, sender: "System", text: "Successfully imported Ollama key from 1Password item '\(itemName)'! (\(key.prefix(4))...)")
                } else {
                    deliverBuddyReply(handle: handle, sender: "System", text: "1Password CLI ('op') not signed in or item '\(itemName)' not found. You can sign in via 'op signin' in Terminal or paste directly via: /key <your_key>")
                }
                return

            case "/status":
                let cfg = OllamaService.shared.config
                let keyStatus = cfg.apiKey.isEmpty ? "None (Local http://localhost:11434)" : "Configured (••••••••)"
                let statusText = "Ollama Host: \(cfg.host)\nModel: \(cfg.model)\n1Password Key: \(keyStatus)\n(Commands: /key <token>, /model <name>, /op [item])"
                deliverBuddyReply(handle: handle, sender: "System", text: statusText)
                return

            default:
                break
            }
        }

        // 2. Query Ollama AI Chatbot Engine
        let historyCopy = buddies[idx].messages
        let prevStatus = buddies[idx].statusMessage
        buddies[idx].statusMessage = "\(buddyName) is typing..."
        onUpdate?()
        ExciteChatWindowController.shared.refreshAll()

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let aiReply = try await OllamaService.shared.generateReply(
                    forHandle: handle,
                    buddyName: buddyName,
                    history: historyCopy,
                    userMessage: trimmed
                )
                if let i = self.buddies.firstIndex(where: { $0.handle == handle }) {
                    self.buddies[i].statusMessage = prevStatus
                }
                self.deliverBuddyReply(handle: handle, sender: buddyName, text: aiReply)
            } catch {
                if let i = self.buddies.firstIndex(where: { $0.handle == handle }) {
                    self.buddies[i].statusMessage = prevStatus
                }
                let fallback = self.fallbackEasterEggReply(handle: handle, buddyName: buddyName, error: error)
                self.deliverBuddyReply(handle: handle, sender: buddyName, text: fallback)
            }
        }
    }

    private func fallbackEasterEggReply(handle: String, buddyName: String, error: Error? = nil) -> String {
        let errSnippet = (error != nil) ? " [Ollama: \(error!.localizedDescription)]" : ""
        switch handle {
        case "swerndorfer@excite.com":
            return "Hey! Scott here. In 1999 we tuned TSlidingWins in VC++ 6.0 so the drawer would slide out using `sar ecx, 3`!\(errSnippet) (Tip: type /status or /model to check AI tie-in)."
        case "kkurtz@excite.com":
            return "Kevin here! At 0x4297B8 we carved each scalloped tab using CombineRgn(RGN_DIFF) so they tucked underneath each other without bleeding a single pixel.\(errSnippet)"
        case "cjklug@excite.com":
            return "C.J. here! Right now TuneIn is streaming \(currentStation.name) live through AVPlayer.\(errSnippet)"
        default:
            return "Hi! Excite Live Bot here. I'm connected to your local Ollama engine (model: \(OllamaService.shared.config.model)).\(errSnippet) Send /status to verify connection or /key to save your 1Password key!"
        }
    }

    private func deliverBuddyReply(handle: String, sender: String, text: String) {
        guard let idx = buddies.firstIndex(where: { $0.handle == handle }) else { return }
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        let msg = ChatMessage(sender: sender, text: text, timestamp: df.string(from: Date()), isFromUser: false)
        buddies[idx].messages.append(msg)
        buddies[idx].unreadCount += 1
        AssetManager.shared.playSound("wav417")
        onIncomingIM?(handle, msg)
        onUpdate?()
    }

    private func populateInitialSeedData() {
        let fallbackNews = [
            NewsItem(title: "Connecting to Hacker News, Spaceflight & ESPN APIs...", subtitle: "Fetching real-time headlines for all 6 Excite sub-tabs", source: "Excite Live Feed", url: URL(string: "https://news.ycombinator.com"))
        ]
        for i in 0..<6 {
            newsBySubtab[i] = fallbackNews
        }
        tvListings = [
            TVListingItem(time: "20:00", network: "NBC", showTitle: "Loading Live TVMaze Schedule...", episodeTitle: "Prime Time Lineup", rating: "TV-PG", url: URL(string: "https://www.tvmaze.com"))
        ]
        deals = [
            DealItem(title: "Loading CheapShark Live Deals...", salePrice: "$4.99", normalPrice: "$29.99", savingsPct: "-83%", url: URL(string: "https://www.cheapshark.com"))
        ]
    }
}
