//
//  HistoryView.swift
//  BPDeliverer
//
//  Created by yangjian on 2024/1/30.
//

import Foundation
import SwiftUI

import ComposableArchitecture

struct HistoryReducer: Reducer {
    struct State: Equatable {
        @UserDefault("measures", defaultValue: [])
        var measures: [Measurement]
    }
    enum Action: Equatable {
        case itemSelected(Measurement)
        case dismiss
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            return .none
        }
    }
}

struct HistoryView: View {
    let store: StoreOf<HistoryReducer>
    var body: some View {
        NavigationView{
            WithViewStore(store, observe: {$0}) { viewStore in
                VStack{
                    ScrollView{
                        LazyVGrid(columns: [GridItem(.flexible())]) {
                            ForEach(viewStore.measures, id: \.self) { item in
                                VStack{
                                    Button {
                                        viewStore.send(.itemSelected(item))
                                    } label: {
                                        TrackerView.TrackerCell(measure: item, topMode: .last, isTop: false).shadow
                                    }
                                }.padding(.horizontal, 20)
                            }
                        }
                    }
                }.toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            viewStore.send(.dismiss)
                        } label: {
                            Image("add_back")
                        }
                    }
                }.navigationTitle("History").navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
