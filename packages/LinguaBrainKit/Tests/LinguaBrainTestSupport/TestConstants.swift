import Foundation

public enum TestConstants {
    public static let germanPersianPair = (source: "de", target: "fa")
    public static let englishPersianPair = (source: "en", target: "fa")
    public static let a1Level = "A1"
    public static let a2Level = "A2"
    
    public static let defaultCount = 20
    public static let defaultTopic = "daily life"
    public static let defaultDirections = ["de→fa", "fa→de"]
}

public struct FakeProviderConfig {
    public static let textProvider = "fake-text"
    public static let audioProvider = "fake-audio"
    public static let imageProvider = "fake-image"
    
    public init() {}
}