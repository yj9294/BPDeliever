//
//  LanguageView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/8.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct LanguageReducer: Reducer {
    struct State: Equatable {
        let items: [Language] = Language.allCases
        var item: Language = Language(rawValue: getDefaultLanguage()) ?? .en
    }
    enum Action: Equatable {
        case pop
        case update(State.Language)
        case itemSelected(State.Language)
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            if case let .itemSelected(language) = action {
                state.item = language
                
                Request.tbaRequest(event: .languageSelected, parameters: ["LO":"\((State.Language.allCases.firstIndex(of: language) ?? 0) + 1)"])
                return .run { [language = language] send in
                    await send(.update(language))
                }
            }
            return .none
        }
    }
}

extension LanguageReducer.State {
    enum Language: String, CaseIterable {
        init?(rawValue: String) {
            switch rawValue {
            case .en:
                self = .en
            case .pt:
                self = .po
            case .fr:
                self = .fr
            case .es:
                self = .es
            case .de:
                self = .de
            case .ar:
                self = .ar
            default:
                self = .en
            }
        }
        case en, po, fr, es, de, ar
        var title: String {
            switch self {
            case .en:
                return "English"
            case .po:
                return "Portuguese"
            case .fr:
                return "French"
            case .es:
                return "Spanish"
            case .de:
                return "German"
            case .ar:
                return "Arabic"
            }
        }
        var code: String {
            switch self {
            case .en:
                return .en
            case .po:
                return .pt
            case .fr:
                return .fr
            case .es:
                return .es
            case .de:
                return .de
            case .ar:
                return .ar
            }
        }
    }
}

struct LanguageView: View {
    let store: StoreOf<LanguageReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            ScrollView{
                VStack{
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                        ForEach(viewStore.items, id: \.self) { item in
                            Button {
                                viewStore.send(.itemSelected(item))
                            } label: {
                                if viewStore.item.code == item.code {
                                    HStack{
                                        Text(LocalizedStringKey(item.title)).foregroundStyle(Color("#48CCE0"))
                                        Spacer()
                                        Image("language_selected")
                                    }
                                } else {
                                    HStack{
                                        Text(LocalizedStringKey(item.title)).foregroundStyle(.black)
                                        Spacer()
                                        Image("language_normal")
                                    }
                                }
                            }.font(.system(size: 16)).padding(.horizontal, 20).padding(.vertical, 17)
                        }
                    }
                    Spacer()
                }
            }.onAppear{
                Request.tbaRequest(event: .language)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewStore.send(.pop)
                    } label: {
                        Image("add_back")
                    }
                }
            }.navigationTitle(LocalizedStringKey(ProfileReducer.State.Item.language.title)).navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden()
        }.background(Color("#F3F8FB").ignoresSafeArea())
    }
}
