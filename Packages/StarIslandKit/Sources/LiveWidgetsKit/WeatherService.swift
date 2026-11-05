import Combine
import CoreLocation
import Foundation
import IslandCore

public enum WeatherParseError: LocalizedError, Equatable, Sendable {
    case invalidPayload
    case missingCurrentWeather
    case networkFailure(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "天气数据格式无法解析"
        case .missingCurrentWeather:
            return "返回结果缺少实时气象字段"
        case .networkFailure(let detail):
            return "获取天气失败：\(detail)"
        }
    }
}

public struct HourlyWeatherPoint: Codable, Equatable, Identifiable, Sendable {
    public var id: String { time }
    public let time: String
    public let displayHour: String
    public let temperatureC: Double
    public let precipitationProbability: Int
    public let weatherCode: Int
    public let symbolName: String

    public init(
        time: String,
        displayHour: String,
        temperatureC: Double,
        precipitationProbability: Int,
        weatherCode: Int,
        symbolName: String
    ) {
        self.time = time
        self.displayHour = displayHour
        self.temperatureC = temperatureC
        self.precipitationProbability = precipitationProbability
        self.weatherCode = weatherCode
        self.symbolName = symbolName
    }
}

public struct DailyWeatherForecast: Codable, Equatable, Identifiable, Sendable {
    public var id: String { date }
    public let date: String
    public let maxTempC: Double
    public let minTempC: Double
    public let weatherCode: Int
    public let precipitationProbabilityMax: Int
    public let conditionText: String
    public let symbolName: String

    public init(
        date: String,
        maxTempC: Double,
        minTempC: Double,
        weatherCode: Int,
        precipitationProbabilityMax: Int,
        conditionText: String,
        symbolName: String
    ) {
        self.date = date
        self.maxTempC = maxTempC
        self.minTempC = minTempC
        self.weatherCode = weatherCode
        self.precipitationProbabilityMax = precipitationProbabilityMax
        self.conditionText = conditionText
        self.symbolName = symbolName
    }
}

public struct WeatherSnapshot: Codable, Equatable, Sendable {
    public let cityName: String
    public let temperatureC: Double
    public let apparentTemperatureC: Double
    public let weatherCode: Int
    public let conditionText: String
    public let symbolName: String
    public let highTempC: Double
    public let lowTempC: Double
    public let humidityPercent: Int
    public let windSpeedKmh: Double
    public let precipitationProbability: Int
    public let hourly: [HourlyWeatherPoint]
    public let daily: [DailyWeatherForecast]
    public let updatedAt: Date

    public init(
        cityName: String,
        temperatureC: Double,
        apparentTemperatureC: Double,
        weatherCode: Int,
        conditionText: String,
        symbolName: String,
        highTempC: Double,
        lowTempC: Double,
        humidityPercent: Int = 50,
        windSpeedKmh: Double = 0,
        precipitationProbability: Int = 0,
        hourly: [HourlyWeatherPoint] = [],
        daily: [DailyWeatherForecast] = [],
        updatedAt: Date = Date()
    ) {
        self.cityName = cityName
        self.temperatureC = temperatureC
        self.apparentTemperatureC = apparentTemperatureC
        self.weatherCode = weatherCode
        self.conditionText = conditionText
        self.symbolName = symbolName
        self.highTempC = highTempC
        self.lowTempC = lowTempC
        self.humidityPercent = humidityPercent
        self.windSpeedKmh = windSpeedKmh
        self.precipitationProbability = precipitationProbability
        self.hourly = hourly
        self.daily = daily
        self.updatedAt = updatedAt
    }
}

public struct GeocodedCity: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let admin1: String?
    public let country: String?
    public let latitude: Double
    public let longitude: Double

    public var displayTitle: String {
        let parts = [name, admin1, country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var deduplicated: [String] = []
        for part in parts where !deduplicated.contains(part) {
            deduplicated.append(part)
        }
        return deduplicated.joined(separator: " · ")
    }
}

public enum OpenMeteoParser {
    private struct ForecastDTO: Decodable {
        struct CurrentDTO: Decodable {
            let time: String?
            let temperature_2m: Double
            let apparent_temperature: Double?
            let is_day: Int?
            let weather_code: Int
            let relative_humidity_2m: Int?
            let wind_speed_10m: Double?
            let precipitation_probability: Int?
        }

        struct HourlyDTO: Decodable {
            let time: [String]?
            let temperature_2m: [Double?]?
            let precipitation_probability: [Int?]?
            let weather_code: [Int?]?
        }

        struct DailyDTO: Decodable {
            let time: [String]?
            let weather_code: [Int?]?
            let temperature_2m_max: [Double?]?
            let temperature_2m_min: [Double?]?
            let precipitation_probability_max: [Int?]?
        }

        let current: CurrentDTO?
        let hourly: HourlyDTO?
        let daily: DailyDTO?
    }

    private struct GeocodingResponseDTO: Decodable {
        let results: [GeocodedCity]?
    }

    public static func parse(data: Data, cityName: String, now: Date = Date()) throws -> WeatherSnapshot {
        let dto: ForecastDTO
        do {
            dto = try JSONDecoder().decode(ForecastDTO.self, from: data)
        } catch {
            throw WeatherParseError.invalidPayload
        }

        guard let current = dto.current else {
            throw WeatherParseError.missingCurrentWeather
        }

        let isDay = (current.is_day ?? 1) != 0
        let mapped = mapWeatherCode(current.weather_code, isDay: isDay)

        var dailyForecasts: [DailyWeatherForecast] = []
        if let daily = dto.daily, let dates = daily.time {
            for idx in dates.indices {
                let maxT = daily.temperature_2m_max?.indices.contains(idx) == true
                    ? (daily.temperature_2m_max?[idx] ?? current.temperature_2m)
                    : current.temperature_2m
                let minT = daily.temperature_2m_min?.indices.contains(idx) == true
                    ? (daily.temperature_2m_min?[idx] ?? current.temperature_2m)
                    : current.temperature_2m
                let code = daily.weather_code?.indices.contains(idx) == true
                    ? (daily.weather_code?[idx] ?? current.weather_code)
                    : current.weather_code
                let precip = daily.precipitation_probability_max?.indices.contains(idx) == true
                    ? (daily.precipitation_probability_max?[idx] ?? 0)
                    : 0
                let dayMapped = mapWeatherCode(code, isDay: true)
                dailyForecasts.append(
                    DailyWeatherForecast(
                        date: dates[idx],
                        maxTempC: maxT,
                        minTempC: minT,
                        weatherCode: code,
                        precipitationProbabilityMax: precip,
                        conditionText: dayMapped.text,
                        symbolName: dayMapped.symbol
                    )
                )
            }
        }

        var hourlyPoints: [HourlyWeatherPoint] = []
        if let hourly = dto.hourly, let times = hourly.time {
            let limit = min(times.count, 24)
            for idx in 0..<limit {
                let rawTime = times[idx]
                let hourLabel = extractHourLabel(from: rawTime)
                let temp = hourly.temperature_2m?.indices.contains(idx) == true
                    ? (hourly.temperature_2m?[idx] ?? current.temperature_2m)
                    : current.temperature_2m
                let precip = hourly.precipitation_probability?.indices.contains(idx) == true
                    ? (hourly.precipitation_probability?[idx] ?? 0)
                    : 0
                let code = hourly.weather_code?.indices.contains(idx) == true
                    ? (hourly.weather_code?[idx] ?? current.weather_code)
                    : current.weather_code
                let symbol = mapWeatherCode(code, isDay: true).symbol
                hourlyPoints.append(
                    HourlyWeatherPoint(
                        time: rawTime,
                        displayHour: hourLabel,
                        temperatureC: temp,
                        precipitationProbability: precip,
                        weatherCode: code,
                        symbolName: symbol
                    )
                )
            }
        }

        let highTemp = dailyForecasts.first?.maxTempC ?? current.temperature_2m
        let lowTemp = dailyForecasts.first?.minTempC ?? current.temperature_2m
        let precipNow = current.precipitation_probability
            ?? hourlyPoints.first?.precipitationProbability
            ?? dailyForecasts.first?.precipitationProbabilityMax
            ?? 0

        return WeatherSnapshot(
            cityName: cityName,
            temperatureC: current.temperature_2m,
            apparentTemperatureC: current.apparent_temperature ?? current.temperature_2m,
            weatherCode: current.weather_code,
            conditionText: mapped.text,
            symbolName: mapped.symbol,
            highTempC: highTemp,
            lowTempC: lowTemp,
            humidityPercent: current.relative_humidity_2m ?? 50,
            windSpeedKmh: current.wind_speed_10m ?? 0,
            precipitationProbability: precipNow,
            hourly: hourlyPoints,
            daily: dailyForecasts,
            updatedAt: now
        )
    }

    public static func parseCities(data: Data) throws -> [GeocodedCity] {
        do {
            let decoded = try JSONDecoder().decode(GeocodingResponseDTO.self, from: data)
            return decoded.results ?? []
        } catch {
            throw WeatherParseError.invalidPayload
        }
    }

    public static func mapWeatherCode(_ code: Int, isDay: Bool = true) -> (text: String, symbol: String) {
        switch code {
        case 0:
            return ("晴朗", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1:
            return ("晴间少云", isDay ? "sun.min.fill" : "cloud.moon.fill")
        case 2:
            return ("局部多云", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3:
            return ("阴天", "cloud.fill")
        case 45, 48:
            return ("雾霭", "cloud.fog.fill")
        case 51, 53, 55:
            return ("毛毛雨", "cloud.drizzle.fill")
        case 56, 57:
            return ("冻毛毛雨", "cloud.sleet.fill")
        case 61:
            return ("小雨", "cloud.rain.fill")
        case 63:
            return ("中雨", "cloud.rain.fill")
        case 65:
            return ("大雨", "cloud.heavyrain.fill")
        case 66, 67:
            return ("冻雨", "cloud.sleet.fill")
        case 71:
            return ("小雪", "cloud.snow.fill")
        case 73:
            return ("中雪", "cloud.snow.fill")
        case 75, 77:
            return ("大雪", "snowflake")
        case 80, 81, 82:
            return ("阵雨", "cloud.sun.rain.fill")
        case 85, 86:
            return ("阵雪", "cloud.snow.fill")
        case 95:
            return ("雷阵雨", "cloud.bolt.rain.fill")
        case 96, 99:
            return ("冰雹雷暴", "cloud.bolt.rain.fill")
        default:
            return ("多云", "cloud.fill")
        }
    }

    private static func extractHourLabel(from rawTime: String) -> String {
        if let tIndex = rawTime.firstIndex(of: "T") {
            let afterT = rawTime[rawTime.index(after: tIndex)...]
            return String(afterT.prefix(5))
        }
        return rawTime
    }
}

@MainActor
public final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = WeatherService()

    @Published public private(set) var snapshot: WeatherSnapshot?
    @Published public private(set) var searchResults: [GeocodedCity] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?

    private let settingsStore: SettingsStore
    private let stateMachine: IslandStateMachine
    private let session: URLSession
    private let cacheURL: URL
    private let locationManager = CLLocationManager()
    private var refreshTask: Task<Void, Never>?
    private var consecutiveFailures: Int = 0

    public init(
        settingsStore: SettingsStore? = nil,
        stateMachine: IslandStateMachine? = nil,
        session: URLSession? = nil,
        cacheURL: URL? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared
        self.stateMachine = stateMachine ?? .shared
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 8
            config.timeoutIntervalForResource = 12
            self.session = URLSession(configuration: config)
        }
        self.cacheURL = cacheURL ?? StarIslandPaths.cachesDirectory.appendingPathComponent("weather-cache.json")
        super.init()
        self.locationManager.delegate = self
        loadCachedSnapshot()
    }

    public func startAutoRefresh(interval: TimeInterval = 900) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                let backoff = min(300.0, pow(2.0, Double(self.consecutiveFailures)) * 5.0)
                let delay = self.consecutiveFailures > 0 ? backoff : max(60.0, interval)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    public func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    public func refresh() async {
        guard settingsStore.settings.enableWeatherWidget else { return }
        isLoading = true
        defer { isLoading = false }

        let lat = settingsStore.settings.weatherLatitude
        let lon = settingsStore.settings.weatherLongitude
        let city = settingsStore.settings.weatherCityName

        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        comps?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", lat)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", lon)),
            URLQueryItem(
                name: "current",
                value: "temperature_2m,apparent_temperature,is_day,weather_code,relative_humidity_2m,wind_speed_10m,precipitation_probability"
            ),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability,weather_code"),
            URLQueryItem(
                name: "daily",
                value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            ),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7")
        ]

        guard let url = comps?.url else { return }
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw WeatherParseError.networkFailure("HTTP \(http.statusCode)")
            }
            let parsed = try OpenMeteoParser.parse(data: data, cityName: city)
            snapshot = parsed
            errorMessage = nil
            consecutiveFailures = 0
            persistSnapshot(parsed)
        } catch {
            consecutiveFailures += 1
            errorMessage = error.localizedDescription
        }
    }

    public func searchCities(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        var comps = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        comps?.queryItems = [
            URLQueryItem(name: "name", value: trimmed),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: "zh"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = comps?.url else { return }
        do {
            let (data, _) = try await session.data(from: url)
            searchResults = try OpenMeteoParser.parseCities(data: data)
        } catch {
            errorMessage = "城市搜索失败：\(error.localizedDescription)"
        }
    }

    public func selectCity(_ city: GeocodedCity) async {
        settingsStore.settings.weatherCityName = city.name
        settingsStore.settings.weatherLatitude = city.latitude
        settingsStore.settings.weatherLongitude = city.longitude
        searchResults = []
        await refresh()
    }

    public func requestCurrentLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    public func formattedTemperature(_ celsius: Double) -> String {
        if settingsStore.settings.weatherUseCelsius {
            return String(format: "%.0f°C", celsius.rounded())
        } else {
            let fahrenheit = celsius * 9.0 / 5.0 + 32.0
            return String(format: "%.0f°F", fahrenheit.rounded())
        }
    }

    public func presentWeatherPeekOnIsland() {
        guard let snap = snapshot else { return }
        stateMachine.submit(
            IslandActivityItem(
                id: "weather.peek",
                category: .weather,
                title: "\(snap.cityName) · \(formattedTemperature(snap.temperatureC))",
                subtitle: "\(snap.conditionText) · 最高 \(formattedTemperature(snap.highTempC)) / 最低 \(formattedTemperature(snap.lowTempC))",
                iconSymbol: snap.symbolName,
                trailingBadge: "\(snap.precipitationProbability)%",
                priority: .ambient,
                isPeek: true,
                allowsOnLockScreen: true,
                autoDismissAfter: 3.5
            )
        )
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.settingsStore.settings.weatherLatitude = lat
            self.settingsStore.settings.weatherLongitude = lon
            let geocoder = CLGeocoder()
            if let placemarks = try? await geocoder.reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lon)),
               let name = placemarks.first?.locality ?? placemarks.first?.administrativeArea {
                self.settingsStore.settings.weatherCityName = name
            }
            await self.refresh()
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            self?.errorMessage = "定位获取失败：\(message)"
        }
    }

    private func loadCachedSnapshot() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cached = try? JSONDecoder().decode(WeatherSnapshot.self, from: data) else {
            return
        }
        snapshot = cached
    }

    private func persistSnapshot(_ item: WeatherSnapshot) {
        let dir = cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(item) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }
}
