
import Foundation
import SQLite

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: Connection?

    private init() {
        connectToDatabase()
    }

    private func connectToDatabase() {
        guard let path = Bundle.main.path(forResource: "lahman", ofType: "sqlite") else {
            print("錯誤：找不到 lahman.sqlite 檔案")
            return
        }
        do {
            db = try Connection(path, readonly: true)
            print("成功連接到本地 Lahman 資料庫")
        } catch {
            print("資料庫連接失敗: \(error)")
        }
    }

    func fetchBestBatters(team: String, startYear: Int, endYear: Int) -> [BatterCard] {
            var batters: [BatterCard] = []
            guard let db = db else { return [] }

            // 新增了一行子查詢，去 Fielding 資料表撈取守備位置並用逗號串接
            let sql = """
            WITH RankedBatters AS (
                SELECT 
                    p.playerID, p.nameFirst, p.nameLast, b.yearID, b.teamID, b.G, b.HR, b.AB, b.H, b.BB,
                    b.RBI, b.SB,
                    (CAST((b.H + b.BB) AS REAL) / NULLIF((b.AB + b.BB), 0)) AS OBP,
                    (CAST((b.H + b."2B" + 2*b."3B" + 3*b.HR) AS REAL) / NULLIF(b.AB, 0)) AS SLG,
                    ROW_NUMBER() OVER (
                        PARTITION BY b.playerID 
                        ORDER BY (CAST((b.H + b.BB) AS REAL) / NULLIF((b.AB + b.BB), 0) + CAST((b.H + b."2B" + 2*b."3B" + 3*b.HR) AS REAL) / NULLIF(b.AB, 0)) DESC
                    ) as rn,
                    (SELECT GROUP_CONCAT(DISTINCT POS) FROM Fielding f WHERE f.playerID = b.playerID AND f.yearID = b.yearID AND f.G > 10) as POS_LIST
                FROM Batting b
                JOIN People p ON b.playerID = p.playerID
                WHERE b.teamID = ? AND b.yearID BETWEEN ? AND ? AND b.AB >= 150
            )
            SELECT * FROM RankedBatters WHERE rn = 1 ORDER BY (OBP + SLG) DESC;
            """

            do {
                let stmt = try db.prepare(sql)
                for row in try stmt.run(team, startYear, endYear) {
                    let playerID = row[0] as? String ?? ""
                    let firstName = row[1] as? String ?? ""
                    let lastName = row[2] as? String ?? ""
                    let year = Int(row[3] as? Int64 ?? 0)
                    let teamID = row[4] as? String ?? ""
                    let g = Int(row[5] as? Int64 ?? 0)
                    let hr = Int(row[6] as? Int64 ?? 0)
                    let ab = Int(row[7] as? Int64 ?? 0)
                    let h = Int(row[8] as? Int64 ?? 0)
                    let rbi = Int(row[10] as? Int64 ?? 0)
                    let sb = Int(row[11] as? Int64 ?? 0)
                    let obp = row[12] as? Double ?? 0.0
                    let slg = row[13] as? Double ?? 0.0
                    
                    // 解析守備位置 (並預設所有人都能打 DH)
                    let posString = row[15] as? String ?? ""
                    var positions = posString.components(separatedBy: ",").filter { !$0.isEmpty }
                    positions.append("DH") // 所有人都能當指定打擊
                    
                    let avg = ab > 0 ? Double(h) / Double(ab) : 0.0
                    
                    let card = BatterCard(id: playerID, name: "\(firstName) \(lastName)", year: year, team: teamID, eligiblePositions: positions, g: g, ab: ab, h: h, hr: hr, rbi: rbi, sb: sb, avg: avg, obp: obp, slg: slg)
                    batters.append(card)
                }
            } catch {
                print("打者查詢失敗: \(error)")
            }
            return batters
        }

    func fetchBestPitchers(team: String, startYear: Int, endYear: Int) -> [PitcherCard] {
            var pitchers: [PitcherCard] = []
            guard let db = db else { return [] }

            // 修正：加入更嚴格的局數門檻，排除投不滿 40 局的「假神獸」
            let sql = """
            WITH RankedPitchers AS (
                SELECT 
                    p.playerID, p.nameFirst, p.nameLast, pi.yearID, pi.teamID, pi.G, pi.IPouts, pi.ERA, pi.SV, pi.SO, pi.BB, pi.H,
                    pi.W, pi.L, pi.GS,
                    (CAST((pi.H + pi.BB) AS REAL) / NULLIF((pi.IPouts / 3.0), 0)) AS WHIP,
                    ROW_NUMBER() OVER (
                        PARTITION BY pi.playerID 
                        ORDER BY pi.ERA ASC
                    ) as rn
                FROM Pitching pi
                JOIN People p ON pi.playerID = p.playerID
                WHERE pi.teamID = ? AND pi.yearID BETWEEN ? AND ? 
                  AND (
                      (pi.GS >= 15 AND pi.IPouts >= 300) -- SP 需滿 100 局
                      OR 
                      (pi.GS < 15 AND pi.IPouts >= 120)  -- RP 需滿 40 局
                  )
            )
            SELECT * FROM RankedPitchers WHERE rn = 1 ORDER BY ERA ASC;
            """

            do {
                let stmt = try db.prepare(sql)
                for row in try stmt.run(team, startYear, endYear) {
                    let playerID = row[0] as? String ?? ""
                    let firstName = row[1] as? String ?? ""
                    let lastName = row[2] as? String ?? ""
                    let year = Int(row[3] as? Int64 ?? 0)
                    let teamID = row[4] as? String ?? ""
                    let g = Int(row[5] as? Int64 ?? 0)
                    let ipOuts = row[6] as? Int64 ?? 0
                    let era = row[7] as? Double ?? 0.0
                    let sv = Int(row[8] as? Int64 ?? 0)
                    let so = Int(row[9] as? Int64 ?? 0)
                    let w = Int(row[12] as? Int64 ?? 0)
                    let l = Int(row[13] as? Int64 ?? 0)
                    let gs = Int(row[14] as? Int64 ?? 0)
                    let whip = row[15] as? Double ?? 0.0
                    
                    var positions: [String] = []
                    if gs >= 10 { positions.append("SP") }
                    if sv >= 5 { positions.append(contentsOf: ["CP", "RP"]) }
                    if positions.isEmpty { positions.append("RP") }
                    
                    let ip = Double(ipOuts) / 3.0
                    let kPer9 = ip > 0 ? (Double(so) * 9.0) / ip : 0.0
                    
                    let card = PitcherCard(id: playerID, name: "\(firstName) \(lastName)", year: year, team: teamID, eligiblePositions: positions, g: g, w: w, l: l, so: so, sv: sv, ip: ip, era: era, whip: whip, kPer9: kPer9)
                    pitchers.append(card)
                }
            } catch {
                print("投手查詢失敗: \(error)")
            }
            return pitchers
        }
}
