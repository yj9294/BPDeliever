//
//  PrivacyView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/8.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct PrivacyReducer: Reducer {
    struct State: Equatable {}
    enum Action: Equatable {
        case pop
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            return .none
        }
    }
}

struct PrivacyView: View {
    let store: StoreOf<PrivacyReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            ScrollView{
                VStack{
                    Text(LocalizedStringKey("privacy")).padding(.all).font(.system(size: 16)).foregroundColor(.black)
                    Spacer()
                }.toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            viewStore.send(.pop)
                        } label: {
                            Image("add_back")
                        }
                    }
                }
            }.navigationTitle(LocalizedStringKey(ProfileReducer.State.Item.privacy.title)).navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden()
        }.background(Color("#F3F8FB").ignoresSafeArea())
    }
}
