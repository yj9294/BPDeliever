//
//  ReadingDetailView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/20.
//

import Foundation
import SwiftUI
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
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            return .none
        }
    }
}

struct ReadingDetailView: View {
    let store: StoreOf<ReadingDetailReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            VStack(spacing: 0){
                NavigationBarView(backAction: {viewStore.send(.dismiss)}, title: "Details")
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 15){
                        VStack(spacing: 15){
                            HStack{
                                Text(LocalizedStringKey(viewStore.item.title)).font(.system(size: 16, weight: .medium)).foregroundStyle(Color("#272C2E"))
                                Spacer()
                            }
                            Text(LocalizedStringKey(viewStore.item.rawValue)).font(.system(size: 14.0)).foregroundStyle(Color("#30313C"))
                        }.padding(.horizontal, 20)
                        LazyVGrid(columns: [GridItem(.flexible())], spacing: 15) {
                            ForEach(viewStore.items, id:\.self) { item in
                                ChartsView.RootView.ItemCell.ReadingView(item: item)
                            }
                        }
                    }.lineLimit(nil).truncationMode(.tail).multilineTextAlignment(.leading)
                }.padding(.top, 15)
            }
            
        }.background(Color("#F3F8FB").ignoresSafeArea())
    }
}
