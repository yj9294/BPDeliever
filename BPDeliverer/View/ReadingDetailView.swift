//
//  ReadingDetailView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/20.
//

import Foundation
import SwiftUI
import Combine
import ComposableArchitecture

struct ReadingDetailReducer: Reducer {
    struct State: Equatable {
        let item: ChartsReducer.State.Item
        var items: [ChartsReducer.State.Item] {
            ChartsReducer.State.Item.allCases.filter { i in
                i != item && !i.isAnalytics
            }
        }
    }
    enum Action: Equatable {
        case dismiss
        case showAD
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            if case .showAD = action {
                // 审核模式不需要返回广告广告
                if CacheUtil.shared.isUserGo {
                    GADUtil.share.load(.back)
                    let pulbisher = Future<Action, Never> { promise in
                        GADUtil.share.show(.back) {_ in
                            promise(.success(.dismiss))
                        }
                    }
                    return .publisher {
                        pulbisher
                    }
                } else {
                    return .run { send in
                        await send(.dismiss)
                    }
                }
            }
            return .none
        }
    }
}

struct ReadingDetailView: View {
    let store: StoreOf<ReadingDetailReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            VStack(spacing: 0){
                NavigationBarView(backAction: {viewStore.send(.showAD)}, title: "Details")
                WebView(urlString: viewStore.item.url).padding(.top, 5).padding(.horizontal, 20)
            }
        }.background(Color("#F3F8FB").ignoresSafeArea()).onAppear(perform: {
            if CacheUtil.shared.isUserGo {
                GADUtil.share.load(.back)
            }
        })
    }
}
