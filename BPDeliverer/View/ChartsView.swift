//
//  ChartsView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import Combine
import ComposableArchitecture

struct ChartsReducer: Reducer {
    struct State: Equatable {
        let sections = Section.allCases
        
        @UserDefault("measures", defaultValue: [])
        var measures: [Measurement]
        
        @PresentationState var proportion: ProportionReducer.State? = nil
        @PresentationState var bp: BPTrendsReducer.State? = nil
        @PresentationState var map: MAPTrendsReducer.State? = nil
        @PresentationState var heart: HeartReducer.State? = nil
        
        @PresentationState var detail: ReadingDetailReducer.State? = nil
    }
    enum Action: Equatable {
        case historyButtonTapped
        
        case proportion(PresentationAction<ProportionReducer.Action>)
        case bp(PresentationAction<BPTrendsReducer.Action>)
        case map(PresentationAction<MAPTrendsReducer.Action>)
        case heart(PresentationAction<HeartReducer.Action>)
        case detail(PresentationAction<ReadingDetailReducer.Action>)
        case itemDidSelected(State.Item)
        case showEnterAD(State.Item)
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            if case let .itemDidSelected(item) = action {
                state.itemDidSelected(item)
                if !item.isAnalytics {
                    Request.tbaRequest(event: .versionRed, parameters: ["red": "\(item.count)"])
                }
            }
            if case .proportion(.presented(.dismiss)) = action {
                if CacheUtil.shared.isUserGo {
                    GADUtil.share.load(.enter)
                }
                state.dismissProportionView()
            }
            if case .bp(.presented(.dismiss)) = action {
                if CacheUtil.shared.isUserGo {
                    GADUtil.share.load(.enter)
                }
                state.dismissBPView()
            }
            if case .map(.presented(.dismiss)) = action {
                if CacheUtil.shared.isUserGo {
                    GADUtil.share.load(.enter)
                }
                state.dismissMAPView()
            }
            if case .heart(.presented(.dismiss)) = action {
                if CacheUtil.shared.isUserGo {
                    GADUtil.share.load(.enter)
                }
                state.dismissHeartView()
            }
            if case .detail(.presented(.dismiss)) = action {
                if CacheUtil.shared.isUserGo {
                    GADUtil.share.load(.enter)
                }
                state.dismissDetailView()
            }
            if case let .showEnterAD(item) = action {
                Request.tbaRequest(event: .enterAD)
                if CacheUtil.shared.isUserGo {
                    let publisher = Future<Action, Never> { [item = item] promiss in
                        GADUtil.share.show(.enter) { _ in
                            promiss(.success(.itemDidSelected(item)))
                        }
                    }
                    return .publisher {
                        publisher
                    }
                } else {
                    return .run { send in
                        await send(.itemDidSelected(item))
                    }
                }
            }
            return .none
        }.ifLet(\.$proportion, action: /Action.proportion) {
            ProportionReducer()
        }.ifLet(\.$bp, action: /Action.bp) {
            BPTrendsReducer()
        }.ifLet(\.$map, action: /Action.map) {
            MAPTrendsReducer()
        }.ifLet(\.$heart, action: /Action.heart) {
            HeartReducer()
        }.ifLet(\.$detail, action: /Action.detail) {
            ReadingDetailReducer()
        }
    }
}

extension ChartsReducer.State {
    var progress: Double {
        if measures.isEmpty {
            return 0.0
        }
        return Double(measures.filter({$0.status == .normal}).count) / Double(measures.count)
    }
    
    func getItems(_ section: Section) -> [Item] {
        if section == .analytics {
            return Item.allCases.filter({$0.isAnalytics})
        } else {
            return Item.allCases.filter({!$0.isAnalytics})
        }
    }
    
    mutating func itemDidSelected(_ item: Item) {
        switch item {
        case .proportion:
            presentProportionView()
        case .bp:
            presentBPView()
        case .map:
            presentMAPView()
        case .heart:
            presentHeartView()
        default:
            presentDetailView(item)
        }
    }
    
    mutating func presentDetailView(_ item: Item) {
        detail = .init(item: item)
    }
    
    mutating func presentProportionView() {
        proportion = .init()
    }
    
    mutating func dismissProportionView() {
        proportion = nil
    }
    
    mutating func presentBPView() {
        bp = .init()
    }
    
    mutating func dismissBPView() {
        bp = nil
    }
    
    mutating func presentMAPView() {
        map = .init()
    }
    mutating func dismissMAPView() {
        map = nil
    }
    
    mutating func presentHeartView() {
        heart = .init()
    }
    mutating func dismissHeartView() {
        heart = nil
    }
    mutating func dismissDetailView() {
        detail = nil
    }
}

extension ChartsReducer.State {
    enum Section: CaseIterable {
        case analytics, reading
        var title: String {
            switch self {
            case .analytics:
                return "Analytics Data"
            case .reading:
                return "Reading"
            }
        }
    }
    
    enum Item: String, CaseIterable {
        case proportion, bp, map, heart, basic, balance, exercise, burden
        var url: String {
            switch self{
            case .basic:
                return "https://sites.google.com/view/bp-artical-1/%E9%A6%96%E9%A0%81";
            case .balance:
                return "https://sites.google.com/view/bp-artical-2/%E9%A6%96%E9%A0%81"
            case .exercise:
                return "https://sites.google.com/view/bpartical-3/%E9%A6%96%E9%A0%81"
            case .burden:
                return "https://sites.google.com/view/bp-artical-4/%E9%A6%96%E9%A0%81"
            default:
                return ""
            }
        }
        var title: String {
            switch self {
            case .proportion:
                return "The proportion of normal blood pressure values"
            case .bp:
                return "BP Trends"
            case .map:
                return "MAP Trends"
            case .heart:
                return "Heart Rate"
            case .basic:
                return "Mastering the basics to protect cardiovascular health"
            case .balance:
                return "Eat a balanced diet to protect the cardiovascular system"
            case .exercise:
                return "Exercise regularly to strengthen your cardiovascular system"
            case .burden:
                return "Ease the burden, guard the heart"
            }
        }
        var count: Int {
            switch self {
            case .basic:
                return 1
            case .balance:
                return 2
            case .exercise:
                return 3
            case .burden:
                return 4
            default:
                return 0
            }
        }
        var isAnalytics: Bool {
            switch self {
            case .proportion, .bp, .map, .heart:
                return true
            default:
                return false
            }
        }
        var icon: String {
            return "reading_\(self.rawValue)"
        }
        var bg: String{
            return "reading_\(self.rawValue)_bg"
        }
    }
}


struct ChartsView: View {
    let store: StoreOf<ChartsReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            RootView(store: store)
                .fullScreenCover(store: store.scope(state: \.$proportion, action: ChartsReducer.Action.proportion)) { store in
                    ProportionView(store: store).onAppear {
                        Request.tbaRequest(event: .bpPorprotion)
                    }
                }
                .fullScreenCover(store: store.scope(state: \.$bp, action: ChartsReducer.Action.bp)) { store in
                    BPTrendsView(store: store).onAppear{
                        Request.tbaRequest(event: .bpTrends)
                    }
                }
                .fullScreenCover(store: store.scope(state: \.$map, action: ChartsReducer.Action.map)) { store in
                    MAPTrendsView(store: store).onAppear {
                        Request.tbaRequest(event: .mapTrends)
                    }
                }
                .fullScreenCover(store: store.scope(state: \.$heart, action: ChartsReducer.Action.heart)) { store in
                    HearView(store: store).onAppear {
                        Request.tbaRequest(event: .heartRate)
                    }
                }
                .fullScreenCover(store: store.scope(state: \.$detail, action: ChartsReducer.Action.detail)) { store in
                    ReadingDetailView(store: store)
                }
        }.onAppear{
            if CacheUtil.shared.isUserGo {
                GADUtil.share.load(.enter)
            }
            Request.tbaRequest(event: .analytics)
        }
    }
    
    struct RootView: View {
        let store: StoreOf<ChartsReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                VStack{
                    ZStack{
                        Text(LocalizedStringKey("Version")).font(.system(size: 18, weight: .medium))
                        HStack{
                            Spacer()
                            HistoryButtonView {
                                viewStore.send(.historyButtonTapped)
                            }
                        }.padding(.trailing, 20)
                    }.frame(height: 44)
                    ScrollView(showsIndicators: false){
                        VStack{
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach([ChartsReducer.State.Section.analytics], id:\.self) { section in
                                    Section {
                                        let items = viewStore.state.getItems(section)
                                        ForEach(items, id: \.self) { item in
                                            Button {
                                                viewStore.send(.showEnterAD(item))
                                            } label: {
                                                ItemCell(item: item, progress: viewStore.progress)
                                            }.foregroundStyle(Color("#0C2529"))
                                        }
                                    } header: {
                                        SectionHeader(section: section)
                                    }
                                }
                            }
                            LazyVGrid(columns: [GridItem(.flexible())], spacing: 15) {
                                ForEach([ChartsReducer.State.Section.reading], id:\.self) { section in
                                    Section {
                                        let items = viewStore.state.getItems(section)
                                        ForEach(items, id: \.self) { item in
                                            Button {
                                                viewStore.send(.showEnterAD(item))
                                            } label: {
                                                ItemCell(item: item, progress: viewStore.progress)
                                            }.foregroundStyle(Color("#0C2529"))
                                        }
                                    } header: {
                                        SectionHeader(section: section)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    Spacer()
                }.background(Color("#F3F8FB").ignoresSafeArea())
            }.foregroundStyle(Color("#0C2529"))
        }
        
        struct HistoryButtonView: View {
            let action: ()->Void
            var body: some View {
                Button(action: action, label: {
                    HStack(spacing: 5){
                        Image("history")
                        Text("History").foregroundStyle(Color("#43C4D7")).font(.system(size: 14.0))
                    }.padding(.horizontal, 9).padding(.vertical, 8)
                }).background(RoundedRectangle(cornerRadius: 16).stroke(Color("#43C4D7"), lineWidth: 1))
            }
        }
        
        struct SectionHeader: View {
            let section: ChartsReducer.State.Section
            var body: some View {
                HStack{
                    Text(LocalizedStringKey(section.title)).padding(.horizontal, 20).padding(.vertical, 16)
                    Spacer()
                }.font(.system(size: 16, weight: .medium))
            }
        }
        
        struct ItemCell: View {
            let item: ChartsReducer.State.Item
            let progress: Double
            var body: some View {
                VStack{
                    if item.isAnalytics {
                        if item == .proportion {
                            ProportionView(progress: progress, title: item.title)
                        } else {
                            AnalytcisView(item: item)
                        }
                    } else {
                        ReadingView(item: item)
                    }
                }
            }
            
            struct ProportionView: View {
                let progress: Double
                let title: String
                var progressString: String {
                    "\(Int(progress * 100))" + "%"
                }
                var body: some View {
                    VStack(spacing: 16){
                        ZStack{
                            CircleView(progress: [progress], colors: [UIColor(named: "#4BED80")!], lineWidth: 21).frame(width: 92, height: 92)
                            Text(progressString).font(.system(size: 13))
                        }
                        Text(LocalizedStringKey(title)).font(.system(size: 12)).lineLimit(2)
                    }.padding(.horizontal, 10).frame(height: 188).shadow
                }
            }
            
            struct AnalytcisView: View {
                let item: ChartsReducer.State.Item
                var body: some View {
                    VStack(spacing: 20){
                        Text(LocalizedStringKey(item.title)).font(.system(size: 14))
                        Image("charts_icon").padding(.horizontal, 32)
                    }.frame(height: 188).shadow
                }
            }
            
            struct ReadingView: View {
                let item: ChartsReducer.State.Item
                var body: some View {
                    VStack{
                        HStack{
                            Image(item.icon)
                            Spacer()
                            Text(LocalizedStringKey(item.title)).padding(.horizontal, 10).padding(.vertical, 20).font(.system(size: 14.0)).lineLimit(nil).truncationMode(.tail).multilineTextAlignment(.leading)
                        }.frame(height: 116).background(Image(item.bg).resizable().scaledToFill()).shadow(16.0).padding(.horizontal, 20)
                    }
                }
            }
        }
    }
}
