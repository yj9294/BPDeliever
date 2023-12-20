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
        case proportion(PresentationAction<ProportionReducer.Action>)
        case bp(PresentationAction<BPTrendsReducer.Action>)
        case map(PresentationAction<MAPTrendsReducer.Action>)
        case heart(PresentationAction<HeartReducer.Action>)
        case detail(PresentationAction<ReadingDetailReducer.Action>)
        case itemDidSelected(State.Item)
        case showAD(State.Item)
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            if case let .itemDidSelected(item) = action {
                state.itemDidSelected(item)
            }
            if case .proportion(.presented(.dismiss)) = action {
                state.dismissProportionView()
            }
            if case .bp(.presented(.dismiss)) = action {
                state.dismissBPView()
            }
            if case .map(.presented(.dismiss)) = action {
                state.dismissMAPView()
            }
            if case .heart(.presented(.dismiss)) = action {
                state.dismissHeartView()
            }
            if case .detail(.presented(.dismiss)) = action {
                state.dismissDetailView()
            }
            if case let .showAD(item) = action {
                GADUtil.share.load(.enter)
                let publisher = Future<Action, Never> { [item = item] promiss in
                    GADUtil.share.show(.enter) { _ in
                        promiss(.success(.itemDidSelected(item)))
                    }
                }
                return .publisher {
                    publisher
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
                    ProportionView(store: store)
                }
                .fullScreenCover(store: store.scope(state: \.$bp, action: ChartsReducer.Action.bp)) { store in
                    BPTrendsView(store: store)
                }
                .fullScreenCover(store: store.scope(state: \.$map, action: ChartsReducer.Action.map)) { store in
                    MAPTrendsView(store: store)
                }
                .fullScreenCover(store: store.scope(state: \.$heart, action: ChartsReducer.Action.heart)) { store in
                    HearView(store: store)
                }
                .fullScreenCover(store: store.scope(state: \.$detail, action: ChartsReducer.Action.detail)) { store in
                    ReadingDetailView(store: store)
                }
        }
    }
    
    struct RootView: View {
        let store: StoreOf<ChartsReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                VStack{
                    Text(LocalizedStringKey("Version")).font(.system(size: 18, weight: .medium)).padding(.vertical, 10)
                    ScrollView(showsIndicators: false){
                        VStack{
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach([ChartsReducer.State.Section.analytics], id:\.self) { section in
                                    Section {
                                        let items = viewStore.state.getItems(section)
                                        ForEach(items, id: \.self) { item in
                                            Button {
                                                viewStore.send(.showAD(item))
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
                                                viewStore.send(.showAD(item))
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
                    VStack(spacing: 36){
                        ZStack{
                            CircleView(progress: [progress], colors: [UIColor(named: "#4BED80")!], lineWidth: 21).frame(width: 92, height: 92)
                            Text(progressString).font(.system(size: 13))
                        }
                        Text(LocalizedStringKey(title)).font(.system(size: 12)).lineLimit(2)
                    }.padding(.top, 45).padding(.bottom, 40).padding(.horizontal, 10).shadow
                }
            }
            
            struct AnalytcisView: View {
                let item: ChartsReducer.State.Item
                var body: some View {
                    VStack(spacing: 20){
                        Text(LocalizedStringKey(item.title)).font(.system(size: 14))
                        Image("charts_icon").padding(.horizontal, 32)
                    }.padding(.top, 20).padding(.bottom, 36).shadow
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
