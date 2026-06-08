import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DraftViewModel()
    
    var body: some View {
        TabView {
            DraftRoomView(viewModel: viewModel)
                .tabItem {
                    Label("選秀大廳", systemImage: "arrow.triangle.2.circlepath")
                }
                .preferredColorScheme(.dark)
            MyRosterView(viewModel: viewModel)
                .tabItem {
                    Label("我的陣容", systemImage: "person.3.fill")
                }
        }
    }
}

// ==========================================
// 畫面一：選秀大廳 (Draft Room)
// ==========================================
struct DraftRoomView: View {
    @ObservedObject var viewModel: DraftViewModel
    @State private var selectedTab = 0 // 0: 野手, 1: 先發, 2: 牛棚
    
    // --- 新增：守位快速尋找過濾狀態 ---
    @State private var batterFilter = "ALL" // ALL, C, 1B, 2B, 3B, SS, OF, DH
    @State private var pitcherFilter = "ALL" // ALL, SP, RP, CP
    
    @State private var batterToDraft: BatterCard?
    @State private var pitcherToDraft: PitcherCard?
    @State private var showAlert = false
    
    let batterFilterOptions = ["ALL", "C", "1B", "2B", "3B", "SS", "OF", "DH"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 頂部資訊看板
                VStack(spacing: 6) {
                    Text(viewModel.isDraftComplete ? "選秀完畢！" : "第 \(min(viewModel.draftRound, 17)) / 17 輪")
                        .font(.headline).foregroundColor(.secondary)
                    Text("\(viewModel.currentDecade) \(viewModel.currentTeam)")
                        .font(.title2).fontWeight(.bold)
                }
                .padding(.top)
                
                // 旋轉與重骰按鈕區
                VStack(spacing: 8) {
                    if viewModel.isDraftComplete {
                        Text("17 人名單已滿！請前往「我的陣容」模擬賽季。")
                            .foregroundColor(.green).fontWeight(.bold).padding(.vertical, 8)
                    } else {
                        // 旋轉輪盤按鈕 (依照新規則：沒選人之前不准再按 Spin)
                        Button(action: { viewModel.spinAndDraft() }) {
                            Text(viewModel.isSpinning ? "資料讀取中..." : "旋轉輪盤 (Spin!)")
                                .font(.headline).fontWeight(.bold).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(viewModel.canSpin ? Color.blue : Color.gray)
                                .cornerRadius(10)
                        }
                        .disabled(!viewModel.canSpin)
                        
                        // 重骰功能列 (抽到隊伍後才顯示)
                        if !viewModel.currentTeamID.isEmpty {
                            HStack(spacing: 12) {
                                Button(action: { viewModel.rerollTeam() }) {
                                    HStack {
                                        Image(systemName: "shield.fill")
                                        Text(viewModel.hasRerolledTeam ? "球隊已重骰" : "重骰球隊 (限1次)")
                                    }
                                    .font(.caption).fontWeight(.semibold)
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                                    .background(viewModel.hasRerolledTeam ? Color.gray.opacity(0.3) : Color.orange.opacity(0.2))
                                    .foregroundColor(viewModel.hasRerolledTeam ? .gray : .orange)
                                    .cornerRadius(8)
                                }
                                .disabled(viewModel.hasRerolledTeam || viewModel.isSpinning)
                                
                                Button(action: { viewModel.rerollDecade() }) {
                                    HStack {
                                        Image(systemName: "calendar")
                                        Text(viewModel.hasRerolledDecade ? "年份已重骰" : "重骰年份 (限1次)")
                                    }
                                    .font(.caption).fontWeight(.semibold)
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                                    .background(viewModel.hasRerolledDecade ? Color.gray.opacity(0.3) : Color.purple.opacity(0.2))
                                    .foregroundColor(viewModel.hasRerolledDecade ? .gray : .purple)
                                    .cornerRadius(8)
                                }
                                .disabled(viewModel.hasRerolledDecade || viewModel.isSpinning)
                            }
                        }
                    }
                }
                .padding()
                
                // 大分類切換
                Picker("選擇位置", selection: $selectedTab) {
                    Text("野手").tag(0)
                    Text("先發 SP").tag(1)
                    Text("牛棚").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle()).padding(.horizontal)
                
                // --- 新增：守位快速尋找橫向滾動過濾列 ---
                if selectedTab == 0 && !viewModel.availableBatters.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(batterFilterOptions, id: \.self) { opt in
                                Text(opt)
                                    .font(.caption).fontWeight(.bold)
                                    .padding(.horizontal, 14).padding(.vertical, 6)
                                    .background(batterFilter == opt ? Color.orange : Color(.systemGray5))
                                    .foregroundColor(batterFilter == opt ? .white : .primary)
                                    .cornerRadius(12)
                                    .onTapGesture { batterFilter = opt }
                            }
                        }
                        .padding(.horizontal).padding(.vertical, 8)
                    }
                    .background(Color(.systemBackground))
                }
                
                // 球員清單，加入快速尋找過濾邏輯
                List {
                    if selectedTab == 0 {
                        let filteredBatters = viewModel.availableBatters.filter { batter in
                            if batterFilter == "ALL" { return true }
                            if batterFilter == "OF" {
                                return batter.eligiblePositions.contains("OF") || batter.eligiblePositions.contains("LF") || batter.eligiblePositions.contains("CF") || batter.eligiblePositions.contains("RF")
                            }
                            return batter.eligiblePositions.contains(batterFilter)
                        }
                        
                        ForEach(filteredBatters) { batter in
                            BatterRow(batter: batter)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if viewModel.getAvailableSlots(for: batter).isEmpty {
                                        showAlert = true
                                    } else { batterToDraft = batter }
                                }
                        }
                    } else if selectedTab == 1 {
                        ForEach(viewModel.availablePitchers.filter { $0.eligiblePositions.contains("SP") }) { pitcher in
                            PitcherRow(pitcher: pitcher)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if viewModel.getAvailableSlots(for: pitcher).isEmpty {
                                        showAlert = true
                                    } else { pitcherToDraft = pitcher }
                                }
                        }
                    } else if selectedTab == 2 {
                        ForEach(viewModel.availablePitchers.filter { $0.eligiblePositions.contains("RP") || $0.eligiblePositions.contains("CP") }) { pitcher in
                            PitcherRow(pitcher: pitcher)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if viewModel.getAvailableSlots(for: pitcher).isEmpty {
                                        showAlert = true
                                    } else { pitcherToDraft = pitcher }
                                }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("選秀大廳")
            .navigationBarTitleDisplayMode(.inline)
            .alert("沒有合法空缺", isPresented: $showAlert) {
                Button("確定", role: .cancel) { }
            } message: {
                Text("這個球員的合法守備位置，在你的陣容中已經客滿了！請選擇其他球員。")
            }
            .confirmationDialog("簽約球員", isPresented: Binding(
                get: { batterToDraft != nil },
                set: { if !$0 { batterToDraft = nil } }
            ), presenting: batterToDraft) { batter in
                ForEach(viewModel.getAvailableSlots(for: batter), id: \.self) { pos in
                    Button("放入 \(pos)") { viewModel.draftBatter(batter, to: pos) }
                }
            } message: { batter in
                Text("你要讓 \(batter.name) 守哪個位置？")
            }
            .confirmationDialog("簽約球員", isPresented: Binding(
                get: { pitcherToDraft != nil },
                set: { if !$0 { pitcherToDraft = nil } }
            ), presenting: pitcherToDraft) { pitcher in
                ForEach(viewModel.getAvailableSlots(for: pitcher), id: \.self) { pos in
                    Button("擔任 \(pos)") { viewModel.draftPitcher(pitcher, to: pos) }
                }
            } message: { pitcher in
                Text("你要讓 \(pitcher.name) 擔任哪個角色？")
            }
        }
    }
}

// ==========================================
// 畫面二：我的陣容 (My Roster)
// ==========================================
struct MyRosterView: View {
    @ObservedObject var viewModel: DraftViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("先發打線 (Starting Lineup)")) {
                        ForEach(viewModel.allBatterPositions, id: \.self) { pos in
                            HStack {
                                Text(pos).fontWeight(.bold).frame(width: 40, alignment: .leading)
                                if let player = viewModel.rosterBatters[pos] {
                                    VStack(alignment: .leading) {
                                        Text("\(player.name) (\(String(player.year)))").font(.headline)
                                        Text("OPS: \(String(format: "%.3f", player.ops)) | HR: \(player.hr)").font(.caption).foregroundColor(.gray)
                                    }
                                } else {
                                    Text("空缺 (尚未選秀)").foregroundColor(.gray).italic()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Section(header: Text("投手陣容 (Pitching Staff)")) {
                        ForEach(viewModel.allPitcherPositions, id: \.self) { pos in
                            HStack {
                                Text(pos).fontWeight(.bold).frame(width: 40, alignment: .leading)
                                if let player = viewModel.rosterPitchers[pos] {
                                    VStack(alignment: .leading) {
                                        Text("\(player.name) (\(String(player.year)))").font(.headline)
                                        Text("ERA: \(String(format: "%.2f", player.era))").font(.caption).foregroundColor(.gray)
                                    }
                                } else {
                                    Text("空缺 (尚未選秀)").foregroundColor(.gray).italic()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                
                if viewModel.isDraftComplete {
                    Button(action: { viewModel.simulateSeason() }) {
                        Text("開始賽季模擬 (Simulate 162 Games)")
                            .font(.title3).fontWeight(.bold).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.orange).cornerRadius(12).shadow(radius: 5)
                    }
                    .padding()
                }
            }
            .navigationTitle("我的 17 人陣容")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("重開一局") { viewModel.resetGame() }
                        .foregroundColor(.red)
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel.seasonResult != nil },
                set: { isPresented in if !isPresented { viewModel.seasonResult = nil } }
            )) {
                if let result = viewModel.seasonResult {
                    SeasonReportView(result: result)
                }
            }
        }
    }
}

// 結算報告
struct SeasonReportView: View {
    @Environment(\.presentationMode) var presentationMode
    let result: SeasonResult
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack {
                        Text("FINAL RECORD").font(.headline).foregroundColor(.secondary).padding(.top)
                        Text("\(result.wins) - \(result.losses)")
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundColor(result.wins >= 116 ? .orange : (result.wins >= 90 ? .green : .red))
                        Text(result.comment).font(.subheadline).italic().multilineTextAlignment(.center).padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity).background(Color(UIColor.secondarySystemBackground)).cornerRadius(16)
                    
                    HStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("團隊攻擊").font(.headline)
                            Text("總得分: \(result.runsScored)").fontWeight(.bold)
                            Text("Team OPS: \(String(format: "%.3f", result.teamOPS))").font(.caption).foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity).padding().background(Color.orange.opacity(0.1)).cornerRadius(12)
                        
                        VStack(spacing: 8) {
                            Text("團隊防守").font(.headline)
                            Text("總失分: \(result.runsAllowed)").fontWeight(.bold)
                            Text("Team ERA: \(String(format: "%.2f", result.teamERA))").font(.caption).foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity).padding().background(Color.blue.opacity(0.1)).cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("🏆 賽季個人獎項").font(.title2).fontWeight(.bold)
                        VStack(alignment: .leading) {
                            Text("年度 MVP (Team MVP)").font(.subheadline).foregroundColor(.secondary)
                            BatterRow(batter: result.mvp).background(Color.yellow.opacity(0.1)).cornerRadius(8)
                        }
                        VStack(alignment: .leading) {
                            Text("賽揚獎 (Cy Young)").font(.subheadline).foregroundColor(.secondary)
                            PitcherRow(pitcher: result.cyYoung).background(Color.cyan.opacity(0.1)).cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("賽季總結")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

// 升級版：電競風格球員卡
struct BatterRow: View {
    let batter: BatterCard
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(batter.name).font(.system(.headline, design: .rounded)).bold()
                HStack {
                    Text(String(batter.year)).font(.caption2).foregroundColor(.secondary)
                    Text(batter.eligiblePositions.joined(separator: "/"))
                        .font(.system(size: 10, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.red.opacity(0.2)).cornerRadius(4).foregroundColor(.red)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("OPS \(String(format: "%.3f", batter.ops))").font(.system(.subheadline, design: .monospaced)).bold().foregroundColor(.red)
                Text("AVG \(String(format: "%.3f", batter.avg)) | HR \(batter.hr)").font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
            }
        }
        .padding()
        .background(CardBackground(isPitcher: false)) // 套用我們新設計的漸層底
    }
}

struct PitcherRow: View {
    let pitcher: PitcherCard
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(pitcher.name).font(.system(.headline, design: .rounded)).bold()
                HStack {
                    Text(String(pitcher.year)).font(.caption2).foregroundColor(.secondary)
                    Text(pitcher.eligiblePositions.joined(separator: "/"))
                        .font(.system(size: 10, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2)).cornerRadius(4).foregroundColor(.blue)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("ERA \(String(format: "%.2f", pitcher.era))").font(.system(.subheadline, design: .monospaced)).bold().foregroundColor(.blue)
                Text("IP \(String(format: "%.1f", pitcher.ip)) | WHIP \(String(format: "%.2f", pitcher.whip))").font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
            }
        }
        .padding()
        .background(CardBackground(isPitcher: true))
    }
}
#Preview {
    ContentView()
}
