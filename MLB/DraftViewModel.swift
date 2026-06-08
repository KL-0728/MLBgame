import Foundation
import SwiftUI
import Combine

struct SeasonResult {
    let wins: Int
    let losses: Int
    let runsScored: Int
    let runsAllowed: Int
    let teamOPS: Double
    let teamERA: Double
    let mvp: BatterCard
    let cyYoung: PitcherCard
    let comment: String
}

class DraftViewModel: ObservableObject {
    @Published var availableBatters: [BatterCard] = []
    @Published var availablePitchers: [PitcherCard] = []
    @Published var isSpinning = false
    
    @Published var currentTeamID = ""
    @Published var currentTeam = "尚未抽籤"
    @Published var currentDecadeInt = 2000
    @Published var currentDecade = ""
    
    // --- 新增：重骰限制機制 ---
    @Published var hasRerolledTeam = false
    @Published var hasRerolledDecade = false
    
    // 只有在「目前名單是空的」且「選秀尚未結束」時，才允許玩家按 Spin
    var canSpin: Bool {
        availableBatters.isEmpty && availablePitchers.isEmpty && !isDraftComplete && !isSpinning
    }
    // -----------------------
    
    @Published var draftRound = 1
    var isDraftComplete: Bool {
        rosterBatters.count + rosterPitchers.count == 17
    }
    
    @Published var rosterBatters: [String: BatterCard] = [:]
    @Published var rosterPitchers: [String: PitcherCard] = [:]
    @Published var seasonResult: SeasonResult? = nil
    
    let allBatterPositions = ["C", "1B", "2B", "3B", "SS", "OF1", "OF2", "OF3", "DH"]
    let allPitcherPositions = ["SP1", "SP2", "SP3", "SP4", "SP5", "RP1", "RP2", "CP"]
    
    func getAvailableSlots(for batter: BatterCard) -> [String] {
        var validSlots: [String] = []
        let ePos = batter.eligiblePositions
        
        for pos in allBatterPositions {
            if rosterBatters[pos] == nil {
                if pos == "DH" { validSlots.append(pos) }
                else if pos.hasPrefix("OF") && (ePos.contains("OF") || ePos.contains("LF") || ePos.contains("CF") || ePos.contains("RF")) {
                    validSlots.append(pos)
                }
                else if ePos.contains(pos) { validSlots.append(pos) }
            }
        }
        return validSlots
    }
    
    func getAvailableSlots(for pitcher: PitcherCard) -> [String] {
        var validSlots: [String] = []
        let ePos = pitcher.eligiblePositions
        
        for pos in allPitcherPositions {
            if rosterPitchers[pos] == nil {
                if pos.hasPrefix("SP") && ePos.contains("SP") { validSlots.append(pos) }
                else if pos.hasPrefix("RP") && (ePos.contains("RP") || ePos.contains("CP")) { validSlots.append(pos) }
                else if pos == "CP" && (ePos.contains("CP") || ePos.contains("RP")) { validSlots.append(pos) }
            }
        }
        return validSlots
    }
    
    func draftBatter(_ batter: BatterCard, to position: String) {
        rosterBatters[position] = batter
        completeRound()
    }
    
    func draftPitcher(_ pitcher: PitcherCard, to position: String) {
        rosterPitchers[position] = pitcher
        completeRound()
    }
    
    private func completeRound() {
        availableBatters = []
        availablePitchers = []
        currentTeam = "請轉盤"
        currentDecade = ""
        currentTeamID = ""
        draftRound += 1
    }
    
    // --- 核心安全抽籤：確保絕對不會抽到空資料的隊伍 ---
    func spinAndDraft() {
        if !canSpin { return }
        isSpinning = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var batters: [BatterCard] = []
            var pitchers: [PitcherCard] = []
            var selectedTeamID = ""
            var selectedTeamName = ""
            var selectedDecade = 2000
            
            // 迴圈防禦：如果撈出來兩邊都是空的（年代斷層或球隊尚未成立），自動在背景繼續抽，直到有資料
            while batters.isEmpty && pitchers.isEmpty {
                selectedDecade = self.decades.randomElement() ?? 2000
                selectedTeamID = self.mlbTeams.keys.randomElement() ?? "NYA"
                selectedTeamName = self.mlbTeams[selectedTeamID] ?? "未知球隊"
                
                batters = DatabaseManager.shared.fetchBestBatters(team: selectedTeamID, startYear: selectedDecade, endYear: selectedDecade + 9)
                pitchers = DatabaseManager.shared.fetchBestPitchers(team: selectedTeamID, startYear: selectedDecade, endYear: selectedDecade + 9)
            }
            
            DispatchQueue.main.async {
                self.currentTeamID = selectedTeamID
                self.currentTeam = selectedTeamName
                self.currentDecadeInt = selectedDecade
                self.currentDecade = "\(selectedDecade)s"
                self.availableBatters = batters
                self.availablePitchers = pitchers
                self.isSpinning = false
            }
        }
    }
    
    // --- 新增：重骰球隊功能 (保留當前年代) ---
    func rerollTeam() {
        if hasRerolledTeam || isSpinning || currentTeamID.isEmpty { return }
        isSpinning = true
        hasRerolledTeam = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var batters: [BatterCard] = []
            var pitchers: [PitcherCard] = []
            var selectedTeamID = ""
            var selectedTeamName = ""
            let fixedDecade = self.currentDecadeInt
            
            while batters.isEmpty && pitchers.isEmpty {
                selectedTeamID = self.mlbTeams.keys.randomElement() ?? "NYA"
                selectedTeamName = self.mlbTeams[selectedTeamID] ?? "未知球隊"
                
                batters = DatabaseManager.shared.fetchBestBatters(team: selectedTeamID, startYear: fixedDecade, endYear: fixedDecade + 9)
                pitchers = DatabaseManager.shared.fetchBestPitchers(team: selectedTeamID, startYear: fixedDecade, endYear: fixedDecade + 9)
            }
            
            DispatchQueue.main.async {
                self.currentTeamID = selectedTeamID
                self.currentTeam = selectedTeamName
                self.availableBatters = batters
                self.availablePitchers = pitchers
                self.isSpinning = false
            }
        }
    }
    
    // --- 新增：重骰年份功能 (保留當前球隊) ---
    func rerollDecade() {
        if hasRerolledDecade || isSpinning || currentTeamID.isEmpty { return }
        isSpinning = true
        hasRerolledDecade = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var batters: [BatterCard] = []
            var pitchers: [PitcherCard] = []
            let fixedTeamID = self.currentTeamID
            var selectedDecade = 2000
            
            while batters.isEmpty && pitchers.isEmpty {
                selectedDecade = self.decades.randomElement() ?? 2000
                batters = DatabaseManager.shared.fetchBestBatters(team: fixedTeamID, startYear: selectedDecade, endYear: selectedDecade + 9)
                pitchers = DatabaseManager.shared.fetchBestPitchers(team: fixedTeamID, startYear: selectedDecade, endYear: selectedDecade + 9)
            }
            
            DispatchQueue.main.async {
                self.currentDecadeInt = selectedDecade
                self.currentDecade = "\(selectedDecade)s"
                self.availableBatters = batters
                self.availablePitchers = pitchers
                self.isSpinning = false
            }
        }
    }
    
    // 重置遊戲
    func resetGame() {
        rosterBatters = [:]
        rosterPitchers = [:]
        availableBatters = []
        availablePitchers = []
        currentTeam = "尚未抽籤"
        currentDecade = ""
        currentTeamID = ""
        draftRound = 1
        hasRerolledTeam = false
        hasRerolledDecade = false
        seasonResult = nil
    }
    
    func simulateSeason() {
        guard isDraftComplete else { return }
        
        let batters = Array(rosterBatters.values)
        let teamOPS = batters.map { $0.ops }.reduce(0, +) / Double(batters.count)
        let runsScored = Int((teamOPS / 0.730) * 730)
        
        let sps = rosterPitchers.filter { $0.key.hasPrefix("SP") }.map { $0.value }
        let rps = rosterPitchers.filter { $0.key.hasPrefix("RP") || $0.key == "CP" }.map { $0.value }
        
        let spERA = sps.map { $0.era }.reduce(0, +) / Double(sps.count)
        let rpERA = rps.map { $0.era }.reduce(0, +) / Double(rps.count)
        let teamERA = (spERA * 0.65) + (rpERA * 0.35)
        let runsAllowed = Int(teamERA * 162)
        
        let rs2 = pow(Double(runsScored), 2)
        let ra2 = pow(Double(runsAllowed), 2)
        let winPct = rs2 / (rs2 + ra2)
        
        var wins = Int(round(winPct * 162))
        if wins > 162 { wins = 162 }
        let losses = 162 - wins
        
        let mvp = batters.max(by: { $0.ops < $1.ops })!
        let cyYoung = rosterPitchers.values.min(by: { $0.era < $1.era })!
        
        let comment: String
        if wins == 162 {
            comment = "162 勝 0 敗！棒球之神降臨，這是人類歷史上最完美的賽季，前無古人，後無來者！"
        } else if wins >= 116 {
            comment = "打破大聯盟歷史單季最多勝紀錄！這是一支不可阻擋的超級王朝球隊！"
        } else if wins >= 100 {
            comment = "破百勝的史詩級賽季！毫無疑問的奪冠大熱門，季後賽的各隊夢魘。"
        } else if wins >= 90 {
            comment = "成功打進季後賽！陣容相當有競爭力，但可能缺乏幾位決定性的關鍵球星。"
        } else if wins >= 81 {
            comment = "五成勝率保衛戰。表現平庸，選秀策略與神獸的化學效應顯然不太好。"
        } else {
            comment = "這是一場災難...總教練和總管準備被球迷炎上並開除吧！"
        }
        
        self.seasonResult = SeasonResult(wins: wins, losses: losses, runsScored: runsScored, runsAllowed: runsAllowed, teamOPS: teamOPS, teamERA: teamERA, mvp: mvp, cyYoung: cyYoung, comment: comment)
    }
    
    private let mlbTeams: [String: String] = [
        "NYA": "紐約洋基", "BOS": "波士頓紅襪", "BAL": "巴爾的摩金鶯", "TBA": "坦帕灣光芒", "TOR": "多倫多藍鳥",
        "CHA": "芝加哥白襪", "CLE": "克里夫蘭守護者", "DET": "底特律老虎", "KCA": "堪薩斯皇家", "MIN": "明尼蘇達雙城",
        "HOU": "休士頓太空人", "LAA": "洛杉磯天使", "OAK": "奧克蘭運動家", "SEA": "西雅圖水手", "TEX": "德州遊騎兵",
        "NYN": "紐約大都會", "ATL": "亞特蘭大勇士", "MIA": "邁阿密馬林魚", "PHI": "費城費城人", "WAS": "華盛頓國民",
        "CHN": "芝加哥小熊", "CIN": "辛辛那提紅人", "MIL": "密爾瓦基釀酒人", "PIT": "匹茲堡海盜", "SLN": "聖路易紅雀",
        "LAN": "洛杉磯道奇", "ARI": "亞利桑那響尾蛇", "COL": "科羅拉多落磯", "SDN": "聖地牙哥教士", "SFN": "舊金山巨人"
    ]
    
    private let decades = [1980, 1990, 2000, 2010]
}
