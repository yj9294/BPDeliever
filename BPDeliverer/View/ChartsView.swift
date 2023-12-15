//
//  ChartsView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import ComposableArchitecture

struct ChartsReducer: Reducer {
    struct State: Equatable {
        let items = Item.allCases
        @UserDefault("measures", defaultValue: [])
        var measures: [Measurement]
        
        @PresentationState var proportion: ProportionReducer.State? = nil
        @PresentationState var bp: BPTrendsReducer.State? = nil
        @PresentationState var map: MAPTrendsReducer.State? = nil
        @PresentationState var heart: HeartReducer.State? = nil
    }
    enum Action: Equatable {
        case proportion(PresentationAction<ProportionReducer.Action>)
        case bp(PresentationAction<BPTrendsReducer.Action>)
        case map(PresentationAction<MAPTrendsReducer.Action>)
        case heart(PresentationAction<HeartReducer.Action>)
        case itemDidSelected(State.Item)
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
            return .none
        }.ifLet(\.$proportion, action: /Action.proportion) {
            ProportionReducer()
        }.ifLet(\.$bp, action: /Action.bp) {
            BPTrendsReducer()
        }.ifLet(\.$map, action: /Action.map) {
            MAPTrendsReducer()
        }.ifLet(\.$heart, action: /Action.heart) {
            HeartReducer()
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
    
    var progressString: String {
        "\(Int(progress * 100))" + "%"
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
        }
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
}

extension ChartsReducer.State {
    enum Item: CaseIterable {
        case proportion, bp, map, heart
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
            }
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
        }
    }
    
    struct RootView: View {
        let store: StoreOf<ChartsReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                VStack{
                    Text(LocalizedStringKey("Analytics Data")).foregroundStyle(.black).font(.system(size: 18)).padding(.vertical, 10)
                    ScrollView{
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(viewStore.items, id: \.self) { item in
                                Button {
                                    viewStore.send(.itemDidSelected(item))
                                } label: {
                                    if item == .proportion {
                                        VStack(spacing: 36){
                                            ZStack{
                                                CircleView(progress: [viewStore.progress], colors: [UIColor(named: "#4BED80")!], lineWidth: 21).frame(width: 92, height: 92)
                                                Text(viewStore.progressString).foregroundStyle(.black).font(.system(size: 13))
                                            }
                                            Text(LocalizedStringKey(item.title)).font(.system(size: 12)).lineLimit(2)
                                        }.padding(.top, 45).padding(.bottom, 40).padding(.horizontal, 10).shadow
                                    } else {
                                        VStack(spacing: 20){
                                            Text(LocalizedStringKey(item.title)).font(.system(size: 14))
                                            Image("charts_icon").padding(.horizontal, 32)
                                        }.padding(.top, 20).padding(.bottom, 36).shadow
                                    }
                                }.foregroundStyle(Color("#0C2529"))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    Spacer()
                }.background(Color("#F3F8FB").ignoresSafeArea())
            }
        }
    }
}
