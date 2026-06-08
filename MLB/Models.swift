import Foundation

protocol BaseballCard: Identifiable {
    var id: String { get }
    var name: String { get }
    var year: Int { get }
    var team: String { get }
    var isPitcher: Bool { get }
    var eligiblePositions: [String] { get } // 新增：可守備位置清單
}

struct BatterCard: BaseballCard {
    var id: String
    var name: String
    var year: Int
    var team: String
    var isPitcher: Bool = false
    var eligiblePositions: [String] = [] // 例如：["1B", "3B", "DH"]
    
    var g: Int
    var ab: Int
    var h: Int
    var hr: Int
    var rbi: Int
    var sb: Int
    
    var avg: Double
    var obp: Double
    var slg: Double
    var ops: Double { obp + slg }
}

struct PitcherCard: BaseballCard {
    var id: String
    var name: String
    var year: Int
    var team: String
    var isPitcher: Bool = true
    var eligiblePositions: [String] = [] // 例如：["SP"] 或 ["RP", "CP"]
    
    var g: Int
    var w: Int
    var l: Int
    var so: Int
    var sv: Int
    
    var ip: Double
    var era: Double
    var whip: Double
    var kPer9: Double
}
